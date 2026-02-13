local cli = require('beadboard.cli')

local M = {}

--- Basic picker: text input then vim.ui.select on search results.
function M._basic_pick(prompt_text, callback)
  vim.ui.input({ prompt = prompt_text .. ' (search or ID): ' }, function(input)
    if not input or input == '' then
      callback(nil)
      return
    end

    -- If input contains a dash, treat as direct issue ID
    if input:match('%-') then
      callback(input)
      return
    end

    -- Otherwise search and present a picker
    cli.run({ 'search', input }, function(err, data)
      if err or not data or #data == 0 then
        -- Fallback: treat raw input as an ID
        callback(input)
        return
      end

      local items = {}
      local id_map = {}
      for _, bead in ipairs(data) do
        local label = bead.id .. ' — ' .. (bead.title or '')
        items[#items + 1] = label
        id_map[label] = bead.id
      end

      vim.ui.select(items, { prompt = prompt_text .. ':' }, function(choice)
        if not choice then
          callback(nil)
          return
        end
        callback(id_map[choice])
      end)
    end)
  end)
end

--- Telescope picker: fuzzy find over all open issues.
function M._telescope_pick(prompt_text, callback)
  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')

  cli.run({ 'list', '--limit', '100' }, function(err, data)
    if err or not data then
      M._basic_pick(prompt_text, callback)
      return
    end

    local items = {}
    for _, bead in ipairs(data) do
      items[#items + 1] = {
        display = bead.id .. ' \u{2014} ' .. (bead.title or ''),
        id = bead.id,
        ordinal = bead.id .. ' ' .. (bead.title or ''),
      }
    end

    pickers.new({}, {
      prompt_title = prompt_text,
      finder = finders.new_table({
        results = items,
        entry_maker = function(item)
          return {
            value = item.id,
            display = item.display,
            ordinal = item.ordinal,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection then
            callback(selection.value)
          else
            callback(nil)
          end
        end)
        return true
      end,
    }):find()
  end)
end

--- Snacks picker: fuzzy find over all open issues.
function M._snacks_pick(prompt_text, callback)
  cli.run({ 'list', '--limit', '100' }, function(err, data)
    if err or not data then
      M._basic_pick(prompt_text, callback)
      return
    end

    local items = {}
    for _, bead in ipairs(data) do
      items[#items + 1] = {
        text = bead.id .. ' ' .. (bead.title or ''),
        id = bead.id,
        display = bead.id .. ' — ' .. (bead.title or ''),
      }
    end

    local completed = false
    Snacks.picker.pick({
      source = 'beadboard',
      title = prompt_text,
      items = items,
      format = function(item)
        return { { item.display } }
      end,
      actions = {
        confirm = function(picker, item)
          if completed then
            return
          end
          completed = true
          picker:close()
          vim.schedule(function()
            if item then
              callback(item.id)
            else
              callback(nil)
            end
          end)
        end,
      },
      on_close = function()
        if completed then
          return
        end
        completed = true
        vim.schedule(function()
          callback(nil)
        end)
      end,
    })
  end)
end

--- Check if Snacks.picker is available and callable.
local function _has_snacks()
  local ok, snacks = pcall(require, 'snacks')
  return ok and snacks.picker and type(snacks.picker.pick) == 'function'
end

--- Check if telescope is available.
local function _has_telescope()
  return pcall(require, 'telescope')
end

--- Pick an issue.
--- Respects `require('beadboard').config.picker`:
---   'snacks'    — force Snacks picker
---   'telescope' — force Telescope picker
---   'basic'     — force basic (vim.ui) picker
---   'auto'      — snacks > telescope > basic
function M.pick_issue(prompt_text, callback)
  local pref = require('beadboard').config.picker or 'auto'

  if pref == 'snacks' or (pref == 'auto' and _has_snacks()) then
    M._snacks_pick(prompt_text, callback)
    return
  end

  if pref == 'telescope' or (pref == 'auto' and _has_telescope()) then
    M._telescope_pick(prompt_text, callback)
    return
  end

  M._basic_pick(prompt_text, callback)
end

return M
