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

vim.api.nvim_create_user_command('BdClaude', function(cmd)
  local args = vim.split(cmd.args, '%s+', { trimempty = true })
  if #args < 2 then
    vim.notify('Usage: :BdClaude <skill> <bead-id>', vim.log.levels.ERROR)
    return
  end
  require('beadboard.claude').run(args[1], args[2])
end, { nargs = '+', desc = 'Run Claude skill on a bead' })

vim.api.nvim_create_user_command('BdQuickExplore', function(cmd)
  if cmd.args == '' then
    vim.notify('Usage: :BdQuickExplore <topic>', vim.log.levels.ERROR)
    return
  end
  local cli = require('beadboard.cli')
  cli.run_raw({ 'q', 'Explore: ' .. cmd.args, '--type', 'task' }, function(err, output)
    if err then
      vim.notify('beadboard: ' .. err, vim.log.levels.ERROR)
      return
    end
    local bead_id = output:gsub('%s+$', '')
    if bead_id == '' then
      vim.notify('beadboard: failed to create bead', vim.log.levels.ERROR)
      return
    end
    require('beadboard.claude').run('explore', bead_id)
  end)
end, { nargs = '+', desc = 'Create bead and explore topic' })

vim.api.nvim_create_user_command('BdQuickFix', function(cmd)
  local feedback = cmd.args
  if feedback == '' then
    vim.ui.input({ prompt = 'Feedback: ' }, function(text)
      if not text or text == '' then return end
      require('beadboard.claude').run('fix', text)
    end)
    return
  end
  require('beadboard.claude').run('fix', feedback)
end, { nargs = '?', desc = 'Create issues from feedback' })
