local M = {}

M.config = {
  bd_cmd = 'bd',
  default_limit = 50,
  default_sort = 'priority',
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})
  require('beadboard.highlight').setup()
end

function M.statusline()
  local cli = require('beadboard.cli')
  local data, err = cli.run_sync({ 'status' })
  if err or not data or not data.summary then
    return ''
  end
  local s = data.summary
  return string.format('beads: %d open, %d wip', s.open_issues or 0, s.in_progress_issues or 0)
end

return M
