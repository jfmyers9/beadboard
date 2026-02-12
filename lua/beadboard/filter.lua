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
      label_any = nil,
      parent = nil,
      sort = nil,
      reverse = false,
      search = nil,
      query = nil,
      stale_days = nil,
      mode = 'list',
      created_after = nil,
      created_before = nil,
      updated_after = nil,
      updated_before = nil,
      show_all = false,
      empty_description = false,
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
  elseif f.mode == 'stale' then
    args = { 'stale' }
    if f.stale_days then
      table.insert(args, '--days')
      table.insert(args, f.stale_days)
    end
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
    if f.label_any then
      table.insert(args, '--label-any')
      table.insert(args, f.label_any)
    end
    if f.parent then
      table.insert(args, '--parent')
      table.insert(args, f.parent)
    end
    if f.created_after then
      table.insert(args, '--created-after')
      table.insert(args, f.created_after)
    end
    if f.created_before then
      table.insert(args, '--created-before')
      table.insert(args, f.created_before)
    end
    if f.updated_after then
      table.insert(args, '--updated-after')
      table.insert(args, f.updated_after)
    end
    if f.updated_before then
      table.insert(args, '--updated-before')
      table.insert(args, f.updated_before)
    end
    if f.show_all then
      table.insert(args, '--all')
    end
    if f.empty_description then
      table.insert(args, '--empty-description')
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
  elseif f.mode == 'stale' then
    table.insert(parts, 'stale' .. (f.stale_days and (':' .. f.stale_days .. 'd') or ''))
  elseif f.mode == 'children' then
    table.insert(parts, 'children:' .. (f.parent or '?'))
  end

  if f.status then table.insert(parts, 'status:' .. f.status) end
  if f.type then table.insert(parts, 'type:' .. f.type) end
  if f.priority then table.insert(parts, 'priority:P' .. f.priority) end
  if f.assignee then table.insert(parts, 'assignee:' .. f.assignee) end
  if f.label then table.insert(parts, 'label:' .. f.label) end
  if f.label_any then table.insert(parts, 'label-any:' .. f.label_any) end
  if f.created_after then table.insert(parts, 'after:' .. f.created_after) end
  if f.created_before then table.insert(parts, 'before:' .. f.created_before) end
  if f.updated_after then table.insert(parts, 'updated>:' .. f.updated_after) end
  if f.updated_before then table.insert(parts, 'updated<:' .. f.updated_before) end
  if f.show_all then table.insert(parts, 'all') end
  if f.empty_description then table.insert(parts, 'empty-desc') end

  local sort = f.sort or cfg.default_sort
  table.insert(parts, 'sort:' .. sort .. (f.reverse and '(rev)' or ''))

  return table.concat(parts, ' | ')
end

function M.cleanup(buf)
  buf_filters[buf] = nil
end

return M
