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
