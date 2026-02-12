local M = {}

local buf_filters = {}

function M.get(buf)
  if not buf_filters[buf] then
    buf_filters[buf] = {
      status = nil,
      type = nil,
      priority = nil,
      assignee = nil,
      label = nil,
      parent = nil,
      sort = nil,
      reverse = false,
      search = nil,
      query = nil,
      mode = 'list',
    }
  end
  return buf_filters[buf]
end

function M.clear(buf)
  buf_filters[buf] = nil
end

function M.build_args(buf)
  local f = M.get(buf)
  local cfg = require('beadboard').config
  local args = {}

  if f.mode == 'search' and f.search then
    args = { 'search', f.search }
  elseif f.mode == 'query' and f.query then
    args = { 'query', f.query }
  elseif f.mode == 'ready' then
    args = { 'ready' }
  elseif f.mode == 'blocked' then
    args = { 'blocked' }
  elseif f.mode == 'children' and f.parent then
    args = { 'list', '--parent', f.parent }
  else
    args = { 'list' }
  end

  if f.mode == 'list' or f.mode == 'search' then
    if f.status then
      table.insert(args, '--status')
      table.insert(args, f.status)
    end
    if f.type then
      table.insert(args, '--type')
      table.insert(args, f.type)
    end
    if f.priority then
      table.insert(args, '--priority')
      table.insert(args, f.priority)
    end
    if f.assignee then
      table.insert(args, '--assignee')
      table.insert(args, f.assignee)
    end
    if f.label then
      table.insert(args, '--label')
      table.insert(args, f.label)
    end
    if f.parent then
      table.insert(args, '--parent')
      table.insert(args, f.parent)
    end
  end

  if f.mode == 'list' then
    local sort = f.sort or cfg.default_sort
    table.insert(args, '--sort')
    table.insert(args, sort)
    if f.reverse then
      table.insert(args, '--reverse')
    end
  end

  table.insert(args, '--limit')
  table.insert(args, tostring(cfg.default_limit))

  return args
end

function M.describe(buf)
  local f = M.get(buf)
  local cfg = require('beadboard').config
  local parts = {}

  if f.mode == 'search' then
    table.insert(parts, 'search:' .. f.search)
  elseif f.mode == 'query' then
    table.insert(parts, 'query:' .. f.query)
  elseif f.mode == 'ready' then
    table.insert(parts, 'ready')
  elseif f.mode == 'blocked' then
    table.insert(parts, 'blocked')
  elseif f.mode == 'children' then
    table.insert(parts, 'children:' .. (f.parent or '?'))
  end

  if f.status then table.insert(parts, 'status:' .. f.status) end
  if f.type then table.insert(parts, 'type:' .. f.type) end
  if f.priority then table.insert(parts, 'priority:P' .. f.priority) end
  if f.assignee then table.insert(parts, 'assignee:' .. f.assignee) end
  if f.label then table.insert(parts, 'label:' .. f.label) end

  local sort = f.sort or cfg.default_sort
  table.insert(parts, 'sort:' .. sort .. (f.reverse and '(rev)' or ''))

  return table.concat(parts, ' | ')
end

function M.cleanup(buf)
  buf_filters[buf] = nil
end

return M
