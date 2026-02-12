local M = {}

local function get_config()
  return require('beadboard').config
end

-- Build the full command table from args.
-- Appends --json automatically.
local function build_cmd(args)
  local cfg = get_config()
  local cmd = { cfg.bd_cmd }
  for _, a in ipairs(args) do
    cmd[#cmd + 1] = a
  end
  cmd[#cmd + 1] = '--json'
  return cmd
end

-- Async run: calls callback(err, data) on completion.
-- err is a string on failure, nil on success.
-- data is the parsed JSON table on success.
function M.run(args, callback)
  local cmd = build_cmd(args)

  vim.system(cmd, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        local msg = (result.stderr or ''):gsub('%s+$', '')
        if msg == '' then
          msg = 'bd exited with code ' .. result.code
        end
        callback(msg, nil)
        return
      end

      local stdout = result.stdout or ''
      local ok, parsed = pcall(vim.json.decode, stdout)
      if not ok then
        callback('Failed to parse JSON: ' .. tostring(parsed), nil)
        return
      end

      callback(nil, parsed)
    end)
  end)
end

-- Synchronous run: returns (data, err).
-- On success err is nil. On failure data is nil.
function M.run_sync(args)
  local cmd = build_cmd(args)
  local result = vim.system(cmd, { text = true }):wait()

  if result.code ~= 0 then
    local msg = (result.stderr or ''):gsub('%s+$', '')
    if msg == '' then
      msg = 'bd exited with code ' .. result.code
    end
    return nil, msg
  end

  local stdout = result.stdout or ''
  local ok, parsed = pcall(vim.json.decode, stdout)
  if not ok then
    return nil, 'Failed to parse JSON: ' .. tostring(parsed)
  end

  return parsed, nil
end

return M
