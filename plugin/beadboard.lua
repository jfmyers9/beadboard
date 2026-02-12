vim.api.nvim_create_user_command('Beadboard', function()
  require('beadboard.list').open()
end, { desc = 'Open beadboard list' })

vim.api.nvim_create_user_command('BdSearch', function(cmd)
  require('beadboard.list').open_with_mode('search', cmd.args)
end, { nargs = 1, desc = 'Search beads' })

vim.api.nvim_create_user_command('BdQuery', function(cmd)
  require('beadboard.list').open_with_mode('query', cmd.args)
end, { nargs = 1, desc = 'Query beads' })

vim.api.nvim_create_user_command('BdReady', function()
  require('beadboard.list').open_with_mode('ready')
end, { desc = 'Show ready beads' })

vim.api.nvim_create_user_command('BdBlocked', function()
  require('beadboard.list').open_with_mode('blocked')
end, { desc = 'Show blocked beads' })

vim.api.nvim_create_user_command('BdStatus', function()
  require('beadboard.status').open()
end, { desc = 'Project dashboard' })

vim.api.nvim_create_user_command('BdCreate', function()
  require('beadboard.create').open()
end, { desc = 'Create bead (wizard)' })

vim.api.nvim_create_user_command('BdStale', function(cmd)
  local days = cmd.args ~= '' and cmd.args or nil
  require('beadboard.list').open_with_mode('stale', days)
end, { nargs = '?', desc = 'Show stale beads' })

vim.api.nvim_create_user_command('BdEpicStatus', function()
  require('beadboard.epic').open()
end, { desc = 'Show epic status' })

vim.api.nvim_create_user_command('BdGraph', function(cmd)
  local id = cmd.args ~= '' and cmd.args or nil
  require('beadboard.graph').open(id)
end, { nargs = '?', desc = 'Show dependency graph' })

vim.api.nvim_create_user_command('BdActivity', function()
  require('beadboard.activity').open()
end, { desc = 'Activity feed' })
