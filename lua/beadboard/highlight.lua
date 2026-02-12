local M = {}

local links = {
  BeadboardPriorityCritical = 'DiagnosticError',
  BeadboardPriorityHigh     = 'DiagnosticError',
  BeadboardPriorityMedium   = 'DiagnosticWarn',
  BeadboardPriorityLow      = 'DiagnosticHint',
  BeadboardPriorityBacklog  = 'Comment',

  BeadboardStatusOpen       = 'DiagnosticOk',
  BeadboardStatusInProgress = 'DiagnosticInfo',
  BeadboardStatusBlocked    = 'DiagnosticError',
  BeadboardStatusDeferred   = 'Comment',
  BeadboardStatusClosed     = 'Comment',

  BeadboardHeader           = 'Title',
  BeadboardId               = 'Identifier',
  BeadboardType             = 'Type',
}

function M.setup()
  for group, target in pairs(links) do
    vim.api.nvim_set_hl(0, group, { link = target, default = true })
  end
end

-- Map priority int to highlight group name.
local priority_hl = {
  [0] = 'BeadboardPriorityCritical',
  [1] = 'BeadboardPriorityHigh',
  [2] = 'BeadboardPriorityMedium',
  [3] = 'BeadboardPriorityLow',
  [4] = 'BeadboardPriorityBacklog',
}

function M.priority_group(n)
  return priority_hl[n] or 'BeadboardPriorityBacklog'
end

-- Map status string to highlight group name.
local status_hl = {
  open        = 'BeadboardStatusOpen',
  in_progress = 'BeadboardStatusInProgress',
  blocked     = 'BeadboardStatusBlocked',
  deferred    = 'BeadboardStatusDeferred',
  closed      = 'BeadboardStatusClosed',
}

function M.status_group(s)
  return status_hl[s] or 'Comment'
end

return M
