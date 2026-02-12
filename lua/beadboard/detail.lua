local cli = require('beadboard.cli')
local util = require('beadboard.util')
local hl = require('beadboard.highlight')

local M = {}

local ns = vim.api.nvim_create_namespace('beadboard_detail')

-- Per-buffer state: buf -> { bead_id, bead, comments, deps }
local buf_state = {}

local status_cycle = { 'open', 'in_progress', 'blocked', 'deferred', 'closed' }
local status_index = {}
for i, s in ipairs(status_cycle) do
  status_index[s] = i
end

local separator = string.rep('\u{2500}', 52)

local function fmt_date(ts)
  if not ts or ts == '' then
    return '?'
  end
  return string.match(ts, '^(%d%d%d%d%-%d%d%-%d%d)') or ts
end

local function fmt_or_none(val)
  if not val or val == '' then
    return '(none)'
  end
  return val
end

local function fmt_labels(labels)
  if not labels or #labels == 0 then
    return '(none)'
  end
  return table.concat(labels, ', ')
end

local function split_lines(text)
  if not text or text == '' then
    return { '(empty)' }
  end
  local lines = {}
  for line in (text .. '\n'):gmatch('([^\n]*)\n') do
    lines[#lines + 1] = line
  end
  return lines
end

local function count_deps(deps)
  local blocking, blocked_by = 0, 0
  if not deps then
    return blocking, blocked_by
  end
  for _, dep in ipairs(deps) do
    if dep.blocks then
      blocking = blocking + 1
    end
    if dep.blocked_by then
      blocked_by = blocked_by + 1
    end
  end
  return blocking, blocked_by
end

local function build_lines(bead, comments, deps)
  local lines = {}
  local highlights = {} -- { {row, group, col_start, col_end}, ... }

  -- Line 1: <id> — <title>
  local id_str = bead.id or '?'
  local title_line = id_str .. ' \u{2014} ' .. (bead.title or '')
  lines[#lines + 1] = title_line
  highlights[#highlights + 1] = {
    #lines - 1, 'BeadboardId', 0, #id_str,
  }

  -- Line 2: Status | Priority | Type
  local status_str = bead.status or '?'
  local priority_str = util.priority_label(bead.priority)
  local type_str = bead.issue_type or '?'
  local meta_line = 'Status: ' .. status_str
    .. ' | Priority: ' .. priority_str
    .. ' | Type: ' .. type_str
  lines[#lines + 1] = meta_line
  local row = #lines - 1
  local s_start = #'Status: '
  local s_end = s_start + #status_str
  highlights[#highlights + 1] = { row, hl.status_group(bead.status), s_start, s_end }
  local p_start = s_end + #' | Priority: '
  local p_end = p_start + #priority_str
  highlights[#highlights + 1] = { row, hl.priority_group(bead.priority), p_start, p_end }
  local t_start = p_end + #' | Type: '
  local t_end = t_start + #type_str
  highlights[#highlights + 1] = { row, 'BeadboardType', t_start, t_end }

  -- Line 3: Owner | Assignee
  lines[#lines + 1] = 'Owner: ' .. fmt_or_none(bead.owner)
    .. ' | Assignee: ' .. fmt_or_none(bead.assignee)

  -- Line 4: Labels
  lines[#lines + 1] = 'Labels: ' .. fmt_labels(bead.labels)

  -- Line 5: Created | Updated
  lines[#lines + 1] = 'Created: ' .. fmt_date(bead.created_at)
    .. ' | Updated: ' .. fmt_date(bead.updated_at)

  -- Line 6: Dependencies
  local blocking, blocked_by = count_deps(deps)
  lines[#lines + 1] = 'Dependencies: '
    .. blocking .. ' blocking, '
    .. blocked_by .. ' blocked by'

  -- Separator
  lines[#lines + 1] = separator
  highlights[#highlights + 1] = { #lines - 1, 'Comment', 0, -1 }

  -- Sections
  local sections = {
    { '## Description', bead.description },
    { '## Design', bead.design },
    { '## Notes', bead.notes },
    { '## Acceptance Criteria', bead.acceptance },
  }
  for _, sec in ipairs(sections) do
    lines[#lines + 1] = ''
    lines[#lines + 1] = sec[1]
    highlights[#highlights + 1] = { #lines - 1, 'BeadboardHeader', 0, -1 }
    for _, l in ipairs(split_lines(sec[2])) do
      lines[#lines + 1] = l
    end
  end

  -- Comments
  comments = comments or {}
  lines[#lines + 1] = ''
  local comments_header = '## Comments (' .. #comments .. ')'
  lines[#lines + 1] = comments_header
  highlights[#highlights + 1] = { #lines - 1, 'BeadboardHeader', 0, -1 }

  if #comments == 0 then
    lines[#lines + 1] = '(none)'
  else
    for _, c in ipairs(comments) do
      lines[#lines + 1] = (c.author or '?') .. ' (' .. fmt_date(c.created_at) .. '):'
      for _, l in ipairs(split_lines(c.body)) do
        lines[#lines + 1] = l
      end
      lines[#lines + 1] = ''
    end
  end

  return lines, highlights
end

local function render(buf, bead, comments, deps)
  local lines, highlights = build_lines(bead, comments, deps)

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, h in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(buf, ns, h[2], h[1], h[3], h[4])
  end
end

local function refresh_detail(buf, bead_id)
  local bead, comments, deps
  local pending = 3

  local function try_render()
    pending = pending - 1
    if pending > 0 then
      return
    end
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    if not bead then
      vim.notify('beadboard: failed to load bead ' .. bead_id, vim.log.levels.ERROR)
      return
    end
    local state = buf_state[buf]
    if state then
      state.bead = bead
      state.comments = comments
      state.deps = deps
    end
    render(buf, bead, comments, deps)
  end

  cli.run({ 'show', bead_id }, function(err, data)
    if not err and data and #data > 0 then
      bead = data[1]
    elseif err then
      vim.notify('beadboard: ' .. err, vim.log.levels.ERROR)
    end
    try_render()
  end)

  cli.run({ 'comments', bead_id }, function(err, data)
    if not err and data then
      comments = data
    end
    try_render()
  end)

  cli.run({ 'dep', 'list', bead_id }, function(err, data)
    if not err and data then
      deps = data
    end
    try_render()
  end)
end

local function mutate_and_refresh(buf, bead_id, args)
  cli.run(args, function(err)
    if err then
      vim.notify('beadboard: ' .. err, vim.log.levels.ERROR)
      return
    end
    refresh_detail(buf, bead_id)
  end)
end

local function setup_keymaps(buf)
  local opts = { buffer = buf, nowait = true, silent = true }

  local function state()
    return buf_state[buf]
  end

  vim.keymap.set('n', 'q', function()
    vim.api.nvim_buf_delete(buf, { force = true })
  end, opts)

  vim.keymap.set('n', '<BS>', function()
    vim.api.nvim_buf_delete(buf, { force = true })
  end, opts)

  vim.keymap.set('n', 'R', function()
    local s = state()
    if s then refresh_detail(buf, s.bead_id) end
  end, opts)

  -- Status cycle forward
  vim.keymap.set('n', 's', function()
    local s = state()
    if not s or not s.bead then return end
    local idx = status_index[s.bead.status] or 1
    local next = status_cycle[(idx % #status_cycle) + 1]
    mutate_and_refresh(buf, s.bead_id, { 'update', s.bead_id, '--status', next })
  end, opts)

  -- Status pick
  vim.keymap.set('n', 'S', function()
    local s = state()
    if not s or not s.bead then return end
    vim.ui.select(status_cycle, { prompt = 'Status:' }, function(choice)
      if not choice then return end
      mutate_and_refresh(buf, s.bead_id, { 'update', s.bead_id, '--status', choice })
    end)
  end, opts)

  -- Priority cycle up
  vim.keymap.set('n', 'p', function()
    local s = state()
    if not s or not s.bead then return end
    local cur = s.bead.priority or 4
    local next = (cur - 1) % 5
    mutate_and_refresh(buf, s.bead_id, { 'update', s.bead_id, '--priority', tostring(next) })
  end, opts)

  -- Priority cycle down
  vim.keymap.set('n', 'P', function()
    local s = state()
    if not s or not s.bead then return end
    local cur = s.bead.priority or 0
    local next = (cur + 1) % 5
    mutate_and_refresh(buf, s.bead_id, { 'update', s.bead_id, '--priority', tostring(next) })
  end, opts)

  -- Close
  vim.keymap.set('n', 'c', function()
    local s = state()
    if not s then return end
    mutate_and_refresh(buf, s.bead_id, { 'close', s.bead_id })
  end, opts)

  -- Reopen
  vim.keymap.set('n', 'o', function()
    local s = state()
    if not s then return end
    mutate_and_refresh(buf, s.bead_id, { 'reopen', s.bead_id })
  end, opts)

  -- Claim
  vim.keymap.set('n', 'K', function()
    local s = state()
    if not s then return end
    mutate_and_refresh(buf, s.bead_id, { 'update', s.bead_id, '--claim' })
  end, opts)

  -- Assignee
  vim.keymap.set('n', 'a', function()
    local s = state()
    if not s then return end
    vim.ui.input({ prompt = 'Assignee: ' }, function(val)
      if not val or val == '' then return end
      mutate_and_refresh(buf, s.bead_id, { 'update', s.bead_id, '--assignee', val })
    end)
  end, opts)

  -- Add label
  vim.keymap.set('n', 'l', function()
    local s = state()
    if not s then return end
    vim.ui.input({ prompt = 'Add label: ' }, function(val)
      if not val or val == '' then return end
      mutate_and_refresh(buf, s.bead_id, { 'update', s.bead_id, '--add-label', val })
    end)
  end, opts)

  -- Remove label
  vim.keymap.set('n', 'L', function()
    local s = state()
    if not s then return end
    vim.ui.input({ prompt = 'Remove label: ' }, function(val)
      if not val or val == '' then return end
      mutate_and_refresh(buf, s.bead_id, { 'update', s.bead_id, '--remove-label', val })
    end)
  end, opts)

  -- Add comment
  vim.keymap.set('n', '<C-c>', function()
    local s = state()
    if not s then return end
    vim.ui.input({ prompt = 'Comment: ' }, function(text)
      if not text or text == '' then return end
      mutate_and_refresh(buf, s.bead_id, { 'comments', 'add', s.bead_id, text })
    end)
  end, opts)

  -- Field editing via scratch buffer
  local edit_fields = {
    { key = 'ed', field = 'description' },
    { key = 'eD', field = 'design' },
    { key = 'en', field = 'notes' },
    { key = 'ea', field = 'acceptance' },
    { key = 'et', field = 'title' },
  }
  for _, f in ipairs(edit_fields) do
    vim.keymap.set('n', f.key, function()
      local s = state()
      if not s or not s.bead then return end
      local current = s.bead[f.field] or ''
      require('beadboard.edit').open(s.bead_id, f.field, current, function()
        refresh_detail(buf, s.bead_id)
      end)
    end, opts)
  end

  -- Show dependencies picker
  vim.keymap.set('n', 'gd', function()
    local s = state()
    if not s or not s.deps or #s.deps == 0 then
      vim.notify('beadboard: no dependencies')
      return
    end
    local items = {}
    for _, d in ipairs(s.deps) do
      local label = d.id or d.blocks or d.blocked_by or tostring(d)
      table.insert(items, label)
    end
    vim.ui.select(items, { prompt = 'Dependency:' }, function(choice)
      if choice then
        require('beadboard.detail').open(choice)
      end
    end)
  end, opts)

  -- Go to parent
  vim.keymap.set('n', 'gp', function()
    local s = state()
    if not s or not s.bead or not s.bead.parent or s.bead.parent == '' then
      vim.notify('beadboard: no parent')
      return
    end
    require('beadboard.detail').open(s.bead.parent)
  end, opts)

  -- Show children
  vim.keymap.set('n', 'gc', function()
    local s = state()
    if not s or not s.bead then return end
    require('beadboard.list').open_with_mode('children', s.bead_id)
  end, opts)

  -- Help
  vim.keymap.set('n', '?', function()
    require('beadboard.help').open()
  end, opts)
end

function M.open(bead_id)
  local buf = vim.api.nvim_create_buf(false, true)

  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'beadboard-detail'

  buf_state[buf] = { bead_id = bead_id }

  vim.api.nvim_create_autocmd('BufWipeout', {
    buffer = buf,
    callback = function()
      buf_state[buf] = nil
    end,
  })

  vim.api.nvim_set_current_buf(buf)
  setup_keymaps(buf)

  -- Loading message
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '[beadboard] Loading ' .. bead_id .. '...' })
  vim.bo[buf].modifiable = false

  refresh_detail(buf, bead_id)
end

return M
