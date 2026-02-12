local cli = require('beadboard.cli')
local util = require('beadboard.util')
local hl = require('beadboard.highlight')
local filter = require('beadboard.filter')

local M = {}

local ns = vim.api.nvim_create_namespace('beadboard_list')

-- Store bead data per-buffer for keymap access.
local buf_beads = {}

local function get_config()
  return require('beadboard').config
end

local function build_header(buf, count)
  return '[beadboard] ' .. count .. ' issues | ' .. filter.describe(buf) .. ' | <?>help'
end

local function apply_highlights(buf, beads, col_widths)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  -- Header line highlight
  vim.api.nvim_buf_add_highlight(buf, ns, 'BeadboardHeader', 0, 0, -1)

  -- Per-bead highlights (lines 1..N, 0-indexed)
  for i, bead in ipairs(beads) do
    local row = i -- 0-indexed line = i (header is line 0)
    local offsets = util.column_offsets(bead, col_widths)

    vim.api.nvim_buf_add_highlight(
      buf, ns, 'BeadboardId',
      row, offsets.id[1], offsets.id[2]
    )
    vim.api.nvim_buf_add_highlight(
      buf, ns, hl.priority_group(bead.priority),
      row, offsets.priority[1], offsets.priority[2]
    )
    vim.api.nvim_buf_add_highlight(
      buf, ns, hl.status_group(bead.status),
      row, offsets.status[1], offsets.status[2]
    )
    vim.api.nvim_buf_add_highlight(
      buf, ns, 'BeadboardType',
      row, offsets.type[1], offsets.type[2]
    )
  end
end

local function render(buf, beads)
  local col_widths = util.compute_col_widths(beads)

  local lines = { build_header(buf, #beads) }
  for _, bead in ipairs(beads) do
    lines[#lines + 1] = util.format_bead_line(bead, col_widths)
  end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false

  buf_beads[buf] = { beads = beads, col_widths = col_widths }
  apply_highlights(buf, beads, col_widths)
end

local function refresh(buf)
  local args = filter.build_args(buf)

  cli.run(args, function(err, data)
    if err then
      vim.notify('beadboard: ' .. err, vim.log.levels.ERROR)
      return
    end
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    render(buf, data)
  end)
end

local function get_bead_under_cursor(buf)
  local row = vim.api.nvim_win_get_cursor(0)[1] -- 1-indexed
  if row <= 1 then
    return nil -- header line
  end
  local bd = buf_beads[buf]
  if not bd then
    return nil
  end
  return bd.beads[row - 1] -- row 2 = bead index 1
end

local function mutate_and_refresh(buf, args)
  cli.run(args, function(err)
    if err then
      vim.notify('beadboard: ' .. err, vim.log.levels.ERROR)
      return
    end
    refresh(buf)
  end)
end

local status_cycle = { 'open', 'in_progress', 'blocked', 'deferred', 'closed' }
local status_index = {}
for i, s in ipairs(status_cycle) do
  status_index[s] = i
end

local sort_fields = {
  'priority', 'created', 'updated', 'status', 'id', 'title', 'type', 'assignee',
}

local function setup_keymaps(buf)
  local opts = { buffer = buf, nowait = true, silent = true }

  vim.keymap.set('n', 'R', function()
    refresh(buf)
  end, opts)

  vim.keymap.set('n', '<CR>', function()
    local bead = get_bead_under_cursor(buf)
    if bead then
      require('beadboard.detail').open(bead.id)
    end
  end, opts)

  vim.keymap.set('n', 'q', function()
    vim.api.nvim_buf_delete(buf, { force = true })
  end, opts)

  -- Status cycle forward
  vim.keymap.set('n', 's', function()
    local bead = get_bead_under_cursor(buf)
    if not bead then return end
    local idx = status_index[bead.status] or 1
    local next = status_cycle[(idx % #status_cycle) + 1]
    mutate_and_refresh(buf, { 'update', bead.id, '--status', next })
  end, opts)

  -- Status pick
  vim.keymap.set('n', 'S', function()
    local bead = get_bead_under_cursor(buf)
    if not bead then return end
    vim.ui.select(status_cycle, { prompt = 'Status:' }, function(choice)
      if not choice then return end
      mutate_and_refresh(buf, { 'update', bead.id, '--status', choice })
    end)
  end, opts)

  -- Priority cycle up (lower number = higher priority)
  vim.keymap.set('n', 'p', function()
    local bead = get_bead_under_cursor(buf)
    if not bead then return end
    local cur = bead.priority or 4
    local next = (cur - 1) % 5
    mutate_and_refresh(buf, { 'update', bead.id, '--priority', tostring(next) })
  end, opts)

  -- Priority cycle down (higher number = lower priority)
  vim.keymap.set('n', 'P', function()
    local bead = get_bead_under_cursor(buf)
    if not bead then return end
    local cur = bead.priority or 0
    local next = (cur + 1) % 5
    mutate_and_refresh(buf, { 'update', bead.id, '--priority', tostring(next) })
  end, opts)

  -- Close
  vim.keymap.set('n', 'c', function()
    local bead = get_bead_under_cursor(buf)
    if not bead then return end
    mutate_and_refresh(buf, { 'close', bead.id })
  end, opts)

  -- Reopen
  vim.keymap.set('n', 'o', function()
    local bead = get_bead_under_cursor(buf)
    if not bead then return end
    mutate_and_refresh(buf, { 'reopen', bead.id })
  end, opts)

  -- Claim
  vim.keymap.set('n', 'K', function()
    local bead = get_bead_under_cursor(buf)
    if not bead then return end
    mutate_and_refresh(buf, { 'update', bead.id, '--claim' })
  end, opts)

  -- Create
  vim.keymap.set('n', 'C', function()
    vim.ui.input({ prompt = 'New bead title: ' }, function(title)
      if not title or title == '' then return end
      mutate_and_refresh(buf, { 'create', title })
    end)
  end, opts)

  -- Delete with confirmation
  vim.keymap.set('n', 'dd', function()
    local bead = get_bead_under_cursor(buf)
    if not bead then return end
    vim.ui.select({ 'Yes', 'No' }, { prompt = 'Delete ' .. bead.id .. '?' }, function(choice)
      if choice ~= 'Yes' then return end
      mutate_and_refresh(buf, { 'delete', bead.id })
    end)
  end, opts)

  -- Filter
  vim.keymap.set('n', 'f', function()
    vim.ui.select(
      { 'status', 'type', 'priority', 'assignee', 'label' },
      { prompt = 'Filter by:' },
      function(dim)
        if not dim then return end
        if dim == 'status' then
          vim.ui.select(status_cycle, { prompt = 'Status:' }, function(v)
            if v then filter.get(buf).status = v; refresh(buf) end
          end)
        elseif dim == 'type' then
          vim.ui.select(
            { 'task', 'bug', 'feature', 'chore', 'epic' },
            { prompt = 'Type:' },
            function(v)
              if v then filter.get(buf).type = v; refresh(buf) end
            end
          )
        elseif dim == 'priority' then
          vim.ui.select(
            { '0', '1', '2', '3', '4' },
            { prompt = 'Priority:', format_item = function(i) return 'P' .. i end },
            function(v)
              if v then filter.get(buf).priority = v; refresh(buf) end
            end
          )
        elseif dim == 'assignee' then
          vim.ui.input({ prompt = 'Assignee: ' }, function(v)
            if v and v ~= '' then filter.get(buf).assignee = v; refresh(buf) end
          end)
        elseif dim == 'label' then
          vim.ui.input({ prompt = 'Label: ' }, function(v)
            if v and v ~= '' then filter.get(buf).label = v; refresh(buf) end
          end)
        end
      end
    )
  end, opts)

  -- Clear all filters
  vim.keymap.set('n', 'F', function()
    filter.clear(buf)
    refresh(buf)
  end, opts)

  -- Sort
  vim.keymap.set('n', 'gs', function()
    vim.ui.select(sort_fields, { prompt = 'Sort by:' }, function(v)
      if v then filter.get(buf).sort = v; refresh(buf) end
    end)
  end, opts)

  -- Reverse sort
  vim.keymap.set('n', 'gS', function()
    filter.get(buf).reverse = not filter.get(buf).reverse
    refresh(buf)
  end, opts)

  -- Search
  vim.keymap.set('n', '/', function()
    vim.ui.input({ prompt = 'Search: ' }, function(q)
      if q and q ~= '' then
        local f = filter.get(buf)
        f.mode = 'search'
        f.search = q
        refresh(buf)
      end
    end)
  end, opts)

  -- Query
  vim.keymap.set('n', 'gq', function()
    vim.ui.input({ prompt = 'Query: ' }, function(q)
      if q and q ~= '' then
        local f = filter.get(buf)
        f.mode = 'query'
        f.query = q
        refresh(buf)
      end
    end)
  end, opts)

  -- Help
  vim.keymap.set('n', '?', function()
    require('beadboard.help').open()
  end, opts)
end

local function create_list_buf()
  local buf = vim.api.nvim_create_buf(false, true)

  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'beadboard-list'

  vim.api.nvim_set_current_buf(buf)

  vim.api.nvim_create_autocmd('BufWipeout', {
    buffer = buf,
    callback = function()
      buf_beads[buf] = nil
      filter.cleanup(buf)
    end,
  })

  setup_keymaps(buf)

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '[beadboard] Loading...' })
  vim.bo[buf].modifiable = false

  return buf
end

function M.open()
  local buf = create_list_buf()
  refresh(buf)
end

function M.open_with_mode(mode, value)
  local buf = create_list_buf()
  local f = filter.get(buf)
  f.mode = mode
  if mode == 'search' then
    f.search = value
  elseif mode == 'query' then
    f.query = value
  elseif mode == 'children' then
    f.parent = value
  end
  refresh(buf)
end

return M
