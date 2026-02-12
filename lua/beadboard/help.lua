local M = {}

local ns = vim.api.nvim_create_namespace('beadboard_help')

local separator = string.rep('\u{2500}', 32)

local content = {
  'beadboard.nvim — Keybinding Reference',       -- 0
  '',                                              -- 1
  'LIST BUFFER',                                   -- 2
  separator,                                       -- 3
  '<CR>     Open bead detail',                     -- 4
  'R        Refresh',                              -- 5
  'q        Close buffer',                         -- 6
  's        Cycle status forward',                 -- 7
  'S        Pick status',                          -- 8
  'p        Priority up (higher)',                 -- 9
  'P        Priority down (lower)',                -- 10
  'c        Close bead',                           -- 11
  'o        Reopen bead',                          -- 12
  'K        Claim bead',                           -- 13
  'C        Create new bead (wizard)',             -- 14
  'dd       Delete bead',                          -- 15
  'gD       Defer bead (optional until date)',     -- 16
  'gU       Undefer bead (reopen)',                -- 17
  'f        Filter by dimension',                  -- 18
  '           status, type, priority, assignee, label,',  -- 19
  '           label-any, created-after, created-before,', -- 20
  '           updated-after, updated-before,',     -- 21
  '           show-all, empty-description',        -- 22
  'F        Clear all filters',                    -- 23
  'gs       Sort by field',                        -- 24
  'gS       Reverse sort',                         -- 25
  '/        Text search',                          -- 26
  'gq       Query expression',                     -- 27
  '',                                              -- 28
  'LIST BUFFER (visual mode)',                     -- 29
  separator,                                       -- 30
  'V+c      Bulk close selected',                  -- 31
  'V+dd     Bulk delete selected',                 -- 32
  'V+gD     Bulk defer selected',                  -- 33
  'V+s      Bulk status update selected',          -- 34
  '',                                              -- 35
  'DETAIL BUFFER',                                 -- 36
  separator,                                       -- 37
  'q / <BS> Back to list',                         -- 38
  'R        Refresh',                              -- 39
  's / S    Status cycle / pick',                  -- 40
  'p / P    Priority up / down',                   -- 41
  'c        Close bead',                           -- 42
  'o        Reopen bead',                          -- 43
  'K        Claim bead',                           -- 44
  'a        Set assignee',                         -- 45
  'l        Add label (picker + custom)',          -- 46
  'L        Remove label',                         -- 47
  '<C-c>    Add comment',                          -- 48
  'gD       Defer bead (optional until date)',     -- 49
  'gU       Undefer bead (reopen)',                -- 50
  'ed       Edit description',                     -- 51
  'eD       Edit design',                          -- 52
  'en       Edit notes',                           -- 53
  'ea       Edit acceptance',                      -- 54
  'et       Edit title',                           -- 55
  'eU       Edit due date',                        -- 56
  'eE       Edit estimate (minutes)',              -- 57
  'eI       Rename issue ID',                      -- 58
  'gP       Set parent (picker)',                  -- 59
  'gd       Show dependencies',                    -- 60
  'gp       Go to parent',                         -- 61
  'gc       Show children',                        -- 62
  'gg       Dependency graph',                     -- 63
  'gx       Mark as duplicate',                    -- 64
  'gX       Supersede with issue',                 -- 65
  'gW       Promote wisp to bead',                 -- 66
  'da       Add dependency (depends on)',          -- 67
  'db       Add blocking dep (this blocks)',       -- 68
  'dr       Remove dependency',                    -- 69
  'dR       Relate to issue',                      -- 70
  'dU       Unrelate from issue',                  -- 71
  '',                                              -- 72
  'ACTIVITY BUFFER',                               -- 73
  separator,                                       -- 74
  '<CR>     Open issue under cursor',              -- 75
  'R        Refresh',                              -- 76
  'a        Toggle auto-refresh (10s)',            -- 77
  'q        Close buffer',                         -- 78
  '?        Show help',                            -- 79
  '',                                              -- 80
  'GRAPH BUFFER',                                  -- 81
  separator,                                       -- 82
  '<CR>     Open issue under cursor',              -- 83
  'R        Refresh',                              -- 84
  'q        Close buffer',                         -- 85
  '?        Show help',                            -- 86
  '',                                              -- 87
  'EDIT BUFFER',                                   -- 88
  separator,                                       -- 89
  ':w       Save changes',                         -- 90
  'q        Close without saving',                 -- 91
  '',                                              -- 92
  'COMMANDS',                                      -- 93
  separator,                                       -- 94
  ':Beadboard        Open list',                   -- 95
  ':BdSearch <term>  Search beads',                -- 96
  ':BdQuery <expr>   Query beads',                 -- 97
  ':BdReady          Show ready beads',            -- 98
  ':BdBlocked        Show blocked beads',          -- 99
  ':BdStale [days]   Show stale beads',            -- 100
  ':BdCreate         Create bead (wizard)',        -- 101
  ':BdStatus         Project dashboard',           -- 102
  ':BdEpicStatus     Epic progress',               -- 103
  ':BdGraph [id]     Dependency graph',            -- 104
  ':BdActivity       Activity feed',               -- 105
}

-- Line indices (0-based) that are section headers
local header_lines = { 0, 2, 29, 36, 73, 81, 88, 93 }
local header_set = {}
for _, i in ipairs(header_lines) do
  header_set[i] = true
end

-- Line indices (0-based) that are separator lines
local sep_lines = { 3, 30, 37, 74, 82, 89, 94 }
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
