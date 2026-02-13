local M = {}

-- bead_id -> buf number of active terminal
local active_sessions = {}

local function get_config()
  return require('beadboard').config
end

local function claude_cmd()
  return get_config().claude_cmd or 'claude'
end

local function refresh_beadboard_views(bead_id)
  local detail = require('beadboard.detail')
  if detail.refresh then
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == 'beadboard-detail' then
        if not bead_id then
          local state = detail.get_state and detail.get_state(buf)
          if state then detail.refresh(buf, state.bead_id) end
        else
          detail.refresh(buf, bead_id)
        end
      end
    end
  end

  local list = require('beadboard.list')
  if list.refresh_buf then
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == 'beadboard-list' then
        list.refresh_buf(buf)
      end
    end
  end
end

local function run_terminal(cmd, opts)
  local bead_id = opts.bead_id

  -- Focus existing session instead of opening a duplicate
  if bead_id and active_sessions[bead_id] then
    local existing = active_sessions[bead_id]
    if vim.api.nvim_buf_is_valid(existing) then
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(win) == existing then
          vim.api.nvim_set_current_win(win)
          vim.cmd('startinsert')
          return existing
        end
      end
      vim.cmd('botright split')
      vim.api.nvim_win_set_buf(0, existing)
      vim.cmd('startinsert')
      return existing
    else
      active_sessions[bead_id] = nil
    end
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.cmd('botright split')
  vim.api.nvim_win_set_buf(0, buf)
  vim.bo[buf].bufhidden = 'wipe'

  if bead_id then
    active_sessions[bead_id] = buf
  end

  vim.fn.termopen(cmd, {
    env = { CLAUDECODE = vim.NIL },
    on_exit = function(_, code)
      vim.schedule(function()
        if bead_id then
          active_sessions[bead_id] = nil
        end
        refresh_beadboard_views(bead_id)
        if opts.on_exit then
          opts.on_exit(code)
        end
      end)
    end,
  })

  vim.cmd('startinsert')
  return buf
end

local function run_print(cmd, opts)
  vim.system(cmd, { text = true, env = { CLAUDECODE = vim.NIL } }, function(result)
    vim.schedule(function()
      if not opts.on_complete then
        return
      end
      if result.code ~= 0 then
        local msg = (result.stderr or ''):gsub('%s+$', '')
        if msg == '' then
          msg = 'claude exited with code ' .. result.code
        end
        opts.on_complete(msg, nil)
      else
        opts.on_complete(nil, result.stdout or '')
      end
    end)
  end)
end

local skills_cache = nil

local function discover_skills()
  if skills_cache then return skills_cache end

  local home = vim.env.HOME or ''
  local pattern = home .. '/.claude/skills/*/SKILL.md'
  local files = vim.fn.glob(pattern, false, true)

  local skills = {}
  for _, file in ipairs(files) do
    local lines = vim.fn.readfile(file)
    if #lines > 0 and lines[1]:match('^%-%-%-') then
      local name, desc, invocable
      for i = 2, #lines do
        if lines[i]:match('^%-%-%-') then break end
        local k, v = lines[i]:match('^(%S+):%s*(.+)')
        if k == 'name' then name = v:gsub('^"(.*)"$', '%1')
        elseif k == 'description' then desc = v:gsub('^"(.*)"$', '%1')
        elseif k == 'user-invocable' then invocable = v:match('true')
        end
      end
      if name then
        skills[#skills + 1] = { name = name, desc = desc or '' }
      end
    end
  end

  skills_cache = skills
  return skills
end

function M.refresh_skills()
  skills_cache = nil
end

local function build_skill_list(bead)
  local relevant = {}
  local other = {}
  local title = (bead.title or ''):lower()

  for _, s in ipairs(discover_skills()) do
    local is_relevant = false
    if s.name == 'explore' or s.name == 'implement' or s.name == 'review'
        or s.name == 'debug' or s.name == 'fix' then
      is_relevant = true
    elseif s.name == 'prepare' and bead.design and bead.design ~= '' then
      is_relevant = true
    elseif s.name == 'start' and bead.status == 'open' then
      is_relevant = true
    elseif s.name == 'respond' and (title:match('^respond:') or title:match('^pr')) then
      is_relevant = true
    end

    if is_relevant then
      relevant[#relevant + 1] = s
    else
      other[#other + 1] = s
    end
  end

  for _, s in ipairs(other) do
    relevant[#relevant + 1] = s
  end
  return relevant
end

function M.pick_and_run(bead, opts)
  opts = opts or {}
  -- Accept either a bead object or a plain ID string
  if type(bead) == 'string' then
    bead = { id = bead, title = '' }
  end
  local skills = build_skill_list(bead)

  vim.ui.select(skills, {
    prompt = 'Claude skill:',
    format_item = function(s)
      return '/' .. s.name .. ' \u{2014} ' .. s.desc
    end,
  }, function(choice)
    if not choice then return end

    -- Continuation: prompt to edit notes before dispatching
    local is_continuation = (choice.name == 'explore' and (bead.title or ''):match('^Explore:'))
      or (choice.name == 'review' and (bead.title or ''):match('^Review:'))
    if is_continuation then
      vim.ui.select({ 'Yes', 'No', 'Cancel' }, {
        prompt = 'Edit notes to guide continuation?',
      }, function(answer)
        if not answer or answer == 'Cancel' then return end
        if answer == 'No' then
          M.run(choice.name, bead.id, opts)
          return
        end
        -- Fetch current notes, open editor, dispatch after save
        local bead_cli = require('beadboard.cli')
        bead_cli.run({ 'show', bead.id }, function(err, data)
          if err or not data or #data == 0 then
            vim.notify('beadboard: failed to load bead', vim.log.levels.ERROR)
            return
          end
          local notes = (data[1].notes or '')
          require('beadboard.edit').open(bead.id, 'notes', notes, function()
            M.run(choice.name, bead.id, opts)
          end)
        end)
      end)
      return
    end

    M.run(choice.name, bead.id, opts)
  end)
end

function M.pick_and_run_multi(beads, opts)
  opts = opts or {}
  local skills = build_skill_list(beads[1])
  local ids = {}
  for _, b in ipairs(beads) do ids[#ids + 1] = type(b) == 'string' and b or b.id end
  local joined = table.concat(ids, ' ')

  vim.ui.select(skills, {
    prompt = 'Claude skill (' .. #beads .. ' beads):',
    format_item = function(s)
      return '/' .. s.name .. ' \u{2014} ' .. s.desc
    end,
  }, function(choice)
    if not choice then return end
    M.run(choice.name, joined, opts)
  end)
end

local refresh_registered = false

function M.setup_autocmds()
  if refresh_registered then return end
  refresh_registered = true

  vim.api.nvim_create_autocmd('BufEnter', {
    pattern = '*',
    callback = function(ev)
      local buf = ev.buf
      local ft = vim.bo[buf].filetype

      if ft == 'beadboard-detail' then
        local detail = require('beadboard.detail')
        if detail.should_refresh and detail.should_refresh(buf) then
          local state = detail.get_state(buf)
          if state then
            detail.refresh(buf, state.bead_id)
          end
        end
      elseif ft == 'beadboard-list' then
        local list = require('beadboard.list')
        if list.should_refresh and list.should_refresh(buf) then
          list.refresh_buf(buf)
        end
      end
    end,
  })
end

function M.run(skill, bead_id, opts)
  M.setup_autocmds()
  opts = opts or {}
  if not bead_id then
    vim.notify('beadboard: no bead ID for claude skill', vim.log.levels.WARN)
    return
  end
  local mode = opts.mode or get_config().claude_default_mode or 'terminal'
  local cmd_name = claude_cmd()

  if vim.fn.executable(cmd_name) ~= 1 then
    vim.notify('beadboard: claude not found on PATH', vim.log.levels.ERROR)
    return
  end

  local model = get_config().claude_model
  local config = get_config()
  local perm_mode = config.claude_permission_mode
  local extra_args = config.claude_extra_args or {}

  if mode == 'print' then
    local cmd = { cmd_name, '-p' }
    if model then
      cmd[#cmd + 1] = '--model'
      cmd[#cmd + 1] = model
    end
    cmd[#cmd + 1] = '--permission-mode'
    cmd[#cmd + 1] = perm_mode or 'bypassPermissions'
    for _, arg in ipairs(extra_args) do
      cmd[#cmd + 1] = arg
    end
    local allowed_tools = config.claude_allowed_tools
    if allowed_tools and #allowed_tools > 0 then
      cmd[#cmd + 1] = '--allowedTools'
      for _, tool in ipairs(allowed_tools) do
        cmd[#cmd + 1] = tool
      end
    end
    cmd[#cmd + 1] = '/' .. skill .. ' ' .. bead_id
    run_print(cmd, opts)
  else
    opts.bead_id = bead_id
    local cmd = { cmd_name }
    if model then
      cmd[#cmd + 1] = '--model'
      cmd[#cmd + 1] = model
    end
    if perm_mode then
      cmd[#cmd + 1] = '--permission-mode'
      cmd[#cmd + 1] = perm_mode
    end
    for _, arg in ipairs(extra_args) do
      cmd[#cmd + 1] = arg
    end
    local allowed_tools = config.claude_allowed_tools
    if allowed_tools and #allowed_tools > 0 then
      cmd[#cmd + 1] = '--allowedTools'
      for _, tool in ipairs(allowed_tools) do
        cmd[#cmd + 1] = tool
      end
    end
    cmd[#cmd + 1] = '/' .. skill .. ' ' .. bead_id
    return run_terminal(cmd, opts)
  end
end

function M.focus(bead_id)
  local buf = active_sessions[bead_id]
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    vim.notify('beadboard: no active Claude session for ' .. bead_id)
    active_sessions[bead_id] = nil
    return false
  end
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then
      vim.api.nvim_set_current_win(win)
      vim.cmd('startinsert')
      return true
    end
  end
  vim.cmd('botright split')
  vim.api.nvim_win_set_buf(0, buf)
  vim.cmd('startinsert')
  return true
end

return M
