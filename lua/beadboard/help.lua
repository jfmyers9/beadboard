local M = {}

local ns = vim.api.nvim_create_namespace('beadboard_help')

local separator = string.rep('\u{2500}', 32)

local content = {
  'beadboard.nvim — Keybinding Reference',
  '',
  'LIST BUFFER',
  separator,
  '<CR>     Open bead detail',
  'R        Refresh',
  'q        Close buffer',
  's        Cycle status forward',
  'S        Pick status',
  'p        Priority up (higher)',
  'P        Priority down (lower)',
  'c        Close bead',
  'o        Reopen bead',
  'K        Claim bead',
  'C        Create new bead',
  'dd       Delete bead',
  'f        Filter by dimension',
  'F        Clear all filters',
  'gs       Sort by field',
  'gS       Reverse sort',
  '/        Text search',
  'gq       Query expression',
  '',
  'DETAIL BUFFER',
  separator,
  'q / <BS> Back to list',
  'R        Refresh',
  's / S    Status cycle / pick',
  'p / P    Priority up / down',
  'c        Close bead',
  'o        Reopen bead',
  'K        Claim bead',
  'a        Set assignee',
  'l        Add label',
  'L        Remove label',
  '<C-c>    Add comment',
  'ed       Edit description',
  'eD       Edit design',
  'en       Edit notes',
  'ea       Edit acceptance',
  'et       Edit title',
  'gd       Show dependencies',
  'gp       Go to parent',
  'gc       Show children',
  '',
  'EDIT BUFFER',
  separator,
  ':w       Save changes',
  'q        Close without saving',
  '',
  'COMMANDS',
  separator,
  ':Beadboard        Open list',
  ':BdSearch <term>  Search beads',
  ':BdQuery <expr>   Query beads',
  ':BdReady          Show ready beads',
  ':BdBlocked        Show blocked beads',
  ':BdStatus         Project dashboard',
}

-- Line indices (0-based) that are section headers
local header_lines = { 0, 2, 23, 45, 50 }
local header_set = {}
for _, i in ipairs(header_lines) do
  header_set[i] = true
end

-- Line indices (0-based) that are separator lines
local sep_lines = { 3, 24, 46, 51 }
local sep_set = {}
for _, i in ipairs(sep_lines) do
  sep_set[i] = true
end

function M.open()
  local buf = vim.api.nvim_create_buf(false, true)

  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'beadboard-help'

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for i = 0, #content - 1 do
    if header_set[i] then
      vim.api.nvim_buf_add_highlight(buf, ns, 'BeadboardHeader', i, 0, -1)
    elseif sep_set[i] then
      vim.api.nvim_buf_add_highlight(buf, ns, 'Comment', i, 0, -1)
    end
  end

  vim.api.nvim_set_current_buf(buf)

  vim.keymap.set('n', 'q', function()
    vim.api.nvim_buf_delete(buf, { force = true })
  end, { buffer = buf, nowait = true, silent = true })
end

return M
