local cli = require("beadboard.cli")
local util = require("beadboard.util")
local hl = require("beadboard.highlight")
local filter = require("beadboard.filter")
local tree = require("beadboard.tree")

local M = {}

local ns = vim.api.nvim_create_namespace("beadboard_list")

-- Store bead data per-buffer for keymap access.
local buf_beads = {}
local buf_collapsed = {}

local function get_config()
	return require("beadboard").config
end

local function build_header(buf, count)
	return "[beadboard] " .. count .. " issues | " .. filter.describe(buf) .. " | <?>help"
end

local function apply_highlights(buf, items, col_widths, offset_fn)
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	vim.api.nvim_buf_add_highlight(buf, ns, "BeadboardHeader", 0, 0, -1)

	for i, item in ipairs(items) do
		local row = i
		local offsets = offset_fn(item, col_widths)
		local bead = item.bead or item

		vim.api.nvim_buf_add_highlight(buf, ns, "BeadboardId", row, offsets.id[1], offsets.id[2])
		vim.api.nvim_buf_add_highlight(
			buf,
			ns,
			hl.priority_group(bead.priority),
			row,
			offsets.priority[1],
			offsets.priority[2]
		)
		vim.api.nvim_buf_add_highlight(buf, ns, hl.status_group(bead.status), row, offsets.status[1], offsets.status[2])
		vim.api.nvim_buf_add_highlight(buf, ns, "BeadboardType", row, offsets.type[1], offsets.type[2])
	end
end

local function render(buf, beads)
	local f = filter.get(buf)
	local is_tree = f.tree

	if is_tree then
		local collapsed = buf_collapsed[buf] or {}
		local entries = tree.build(beads, collapsed)
		local col_widths = util.compute_col_widths_tree(entries)
		local lines = { build_header(buf, #entries) }
		local ordered_beads = {}
		for _, entry in ipairs(entries) do
			lines[#lines + 1] = util.format_tree_line(entry, col_widths)
			ordered_beads[#ordered_beads + 1] = entry.bead
		end

		vim.bo[buf].modifiable = true
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.bo[buf].modifiable = false
		vim.bo[buf].modified = false

		buf_beads[buf] = { beads = ordered_beads, col_widths = col_widths, tree_entries = entries }
		apply_highlights(buf, entries, col_widths, util.tree_column_offsets)
	else
		local col_widths = util.compute_col_widths(beads)
		local lines = { build_header(buf, #beads) }
		for _, bead in ipairs(beads) do
			lines[#lines + 1] = util.format_bead_line(bead, col_widths)
		end

		vim.bo[buf].modifiable = true
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.bo[buf].modifiable = false
		vim.bo[buf].modified = false

		buf_beads[buf] = { beads = beads, col_widths = col_widths }
		apply_highlights(buf, beads, col_widths, util.column_offsets)
	end
end

local last_refresh_time = {}

local function refresh(buf)
	last_refresh_time[buf] = vim.uv.now()
	local args = filter.build_args(buf)

	cli.run(args, function(err, data)
		if err then
			vim.notify("beadboard: " .. err, vim.log.levels.ERROR)
			return
		end
		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end
		render(buf, data)
	end)
end

local function get_bead_under_cursor(buf)
	local row = vim.api.nvim_win_get_cursor(0)[1] -- 1-indexed
	if row <= 1 then
		return nil -- header line
	end
	local bd = buf_beads[buf]
	if not bd then
		return nil
	end
	return bd.beads[row - 1] -- row 2 = bead index 1
end

local function get_beads_in_range(buf, start_row, end_row)
	local bd = buf_beads[buf]
	if not bd then
		return {}
	end
	local beads = {}
	for row = start_row, end_row do
		local idx = row - 1 -- header is row 1, bead index starts at 1
		if idx >= 1 and idx <= #bd.beads then
			beads[#beads + 1] = bd.beads[idx]
		end
	end
	return beads
end

local function bulk_mutate(buf, beads, build_args_fn)
	local pending = #beads
	if pending == 0 then
		return
	end
	for _, bead in ipairs(beads) do
		cli.run(build_args_fn(bead), function(err)
			if err then
				vim.notify("beadboard: " .. bead.id .. ": " .. err, vim.log.levels.WARN)
			end
			pending = pending - 1
			if pending == 0 then
				refresh(buf)
			end
		end)
	end
end

local function mutate_and_refresh(buf, args)
	cli.run(args, function(err)
		if err then
			vim.notify("beadboard: " .. err, vim.log.levels.ERROR)
			return
		end
		refresh(buf)
	end)
end

local status_cycle = { "open", "in_progress", "blocked", "deferred", "closed" }
local status_index = {}
for i, s in ipairs(status_cycle) do
	status_index[s] = i
end

local sort_fields = {
	"priority",
	"created",
	"updated",
	"status",
	"id",
	"title",
	"type",
	"assignee",
}

local function setup_keymaps(buf)
	local opts = { buffer = buf, nowait = true, silent = true }

	vim.keymap.set("n", "R", function()
		refresh(buf)
	end, vim.tbl_extend("force", opts, { desc = "Refresh" }))

	vim.keymap.set("n", "<CR>", function()
		local bead = get_bead_under_cursor(buf)
		if bead then
			require("beadboard.detail").open(bead.id, buf, bead)
		end
	end, vim.tbl_extend("force", opts, { desc = "Open bead detail" }))

	vim.keymap.set("n", "K", function()
		local bead = get_bead_under_cursor(buf)
		if bead then
			require("beadboard.preview").toggle(bead, buf)
		end
	end, vim.tbl_extend("force", opts, { desc = "Preview bead" }))

	vim.keymap.set("n", "q", function()
		vim.api.nvim_buf_delete(buf, { force = true })
	end, vim.tbl_extend("force", opts, { desc = "Close buffer" }))

	-- Status cycle forward
	vim.keymap.set("n", "s", function()
		local bead = get_bead_under_cursor(buf)
		if not bead then
			return
		end
		local idx = status_index[bead.status] or 1
		local next = status_cycle[(idx % #status_cycle) + 1]
		mutate_and_refresh(buf, { "update", bead.id, "--status", next })
	end, vim.tbl_extend("force", opts, { desc = "Cycle status forward" }))

	-- Status pick
	vim.keymap.set("n", "S", function()
		local bead = get_bead_under_cursor(buf)
		if not bead then
			return
		end
		vim.ui.select(status_cycle, { prompt = "Status:" }, function(choice)
			if not choice then
				return
			end
			mutate_and_refresh(buf, { "update", bead.id, "--status", choice })
		end)
	end, vim.tbl_extend("force", opts, { desc = "Pick status" }))

	-- Priority cycle up (lower number = higher priority)
	vim.keymap.set("n", "p", function()
		local bead = get_bead_under_cursor(buf)
		if not bead then
			return
		end
		local cur = bead.priority or 4
		local next = (cur - 1) % 5
		mutate_and_refresh(buf, { "update", bead.id, "--priority", tostring(next) })
	end, vim.tbl_extend("force", opts, { desc = "Priority up" }))

	-- Priority cycle down (higher number = lower priority)
	vim.keymap.set("n", "P", function()
		local bead = get_bead_under_cursor(buf)
		if not bead then
			return
		end
		local cur = bead.priority or 0
		local next = (cur + 1) % 5
		mutate_and_refresh(buf, { "update", bead.id, "--priority", tostring(next) })
	end, vim.tbl_extend("force", opts, { desc = "Priority down" }))

	-- Close
	vim.keymap.set("n", "c", function()
		local bead = get_bead_under_cursor(buf)
		if not bead then
			return
		end
		mutate_and_refresh(buf, { "close", bead.id })
	end, vim.tbl_extend("force", opts, { desc = "Close bead" }))

	-- Reopen
	vim.keymap.set("n", "o", function()
		local bead = get_bead_under_cursor(buf)
		if not bead then
			return
		end
		mutate_and_refresh(buf, { "reopen", bead.id })
	end, vim.tbl_extend("force", opts, { desc = "Reopen bead" }))

	-- Claim
	vim.keymap.set("n", "gK", function()
		local bead = get_bead_under_cursor(buf)
		if not bead then
			return
		end
		mutate_and_refresh(buf, { "update", bead.id, "--claim" })
	end, vim.tbl_extend("force", opts, { desc = "Claim bead" }))

	-- Create
	vim.keymap.set("n", "C", function()
		require("beadboard.create").open(function()
			refresh(buf)
		end)
	end, vim.tbl_extend("force", opts, { desc = "Create bead" }))

	-- Delete with confirmation
	vim.keymap.set("n", "dd", function()
		local bead = get_bead_under_cursor(buf)
		if not bead then
			return
		end
		vim.ui.select({ "Yes", "No" }, { prompt = "Delete " .. bead.id .. "?" }, function(choice)
			if choice ~= "Yes" then
				return
			end
			mutate_and_refresh(buf, { "delete", bead.id })
		end)
	end, vim.tbl_extend("force", opts, { desc = "Delete bead" }))

	-- Filter
	vim.keymap.set("n", "f", function()
		vim.ui.select({
			"status",
			"type",
			"priority",
			"assignee",
			"label",
			"label-any",
			"created-after",
			"created-before",
			"updated-after",
			"updated-before",
			"show-all",
			"empty-description",
		}, { prompt = "Filter by:" }, function(dim)
			if not dim then
				return
			end
			if dim == "status" then
				vim.ui.select(status_cycle, { prompt = "Status:" }, function(v)
					if v then
						filter.get(buf).status = v
						refresh(buf)
					end
				end)
			elseif dim == "type" then
				cli.run({ "types" }, function(err, data)
					local types = { "task", "bug", "feature", "chore", "epic" }
					if not err and data then
						local fetched = {}
						for _, list in ipairs({ data.core_types or {}, data.custom_types or {} }) do
							for _, t in ipairs(list) do
								fetched[#fetched + 1] = t.name
							end
						end
						if #fetched > 0 then
							types = fetched
						end
					end
					vim.ui.select(types, { prompt = "Type:" }, function(v)
						if v then
							filter.get(buf).type = v
							refresh(buf)
						end
					end)
				end)
			elseif dim == "priority" then
				vim.ui.select({ "0", "1", "2", "3", "4" }, {
					prompt = "Priority:",
					format_item = function(i)
						return "P" .. i
					end,
				}, function(v)
					if v then
						filter.get(buf).priority = v
						refresh(buf)
					end
				end)
			elseif dim == "assignee" then
				vim.ui.input({ prompt = "Assignee: " }, function(v)
					if v and v ~= "" then
						filter.get(buf).assignee = v
						refresh(buf)
					end
				end)
			elseif dim == "label" then
				vim.ui.input({ prompt = "Label: " }, function(v)
					if v and v ~= "" then
						filter.get(buf).label = v
						refresh(buf)
					end
				end)
			elseif dim == "label-any" then
				vim.ui.input({ prompt = "Labels (comma-separated, OR logic): " }, function(v)
					if v and v ~= "" then
						filter.get(buf).label_any = v
						refresh(buf)
					end
				end)
			elseif dim == "created-after" then
				vim.ui.input({ prompt = "Created after (YYYY-MM-DD): " }, function(v)
					if v and v ~= "" then
						filter.get(buf).created_after = v
						refresh(buf)
					end
				end)
			elseif dim == "created-before" then
				vim.ui.input({ prompt = "Created before (YYYY-MM-DD): " }, function(v)
					if v and v ~= "" then
						filter.get(buf).created_before = v
						refresh(buf)
					end
				end)
			elseif dim == "updated-after" then
				vim.ui.input({ prompt = "Updated after (YYYY-MM-DD): " }, function(v)
					if v and v ~= "" then
						filter.get(buf).updated_after = v
						refresh(buf)
					end
				end)
			elseif dim == "updated-before" then
				vim.ui.input({ prompt = "Updated before (YYYY-MM-DD): " }, function(v)
					if v and v ~= "" then
						filter.get(buf).updated_before = v
						refresh(buf)
					end
				end)
			elseif dim == "show-all" then
				filter.get(buf).show_all = not filter.get(buf).show_all
				refresh(buf)
			elseif dim == "empty-description" then
				filter.get(buf).empty_description = not filter.get(buf).empty_description
				refresh(buf)
			end
		end)
	end, vim.tbl_extend("force", opts, { desc = "Filter" }))

	-- Clear all filters
	vim.keymap.set("n", "F", function()
		local was_tree = filter.get(buf).tree
		filter.clear(buf)
		filter.get(buf).tree = was_tree
		refresh(buf)
	end, vim.tbl_extend("force", opts, { desc = "Clear filters" }))

	-- Sort
	vim.keymap.set("n", "gs", function()
		vim.ui.select(sort_fields, { prompt = "Sort by:" }, function(v)
			if v then
				filter.get(buf).sort = v
				refresh(buf)
			end
		end)
	end, vim.tbl_extend("force", opts, { desc = "Sort by field" }))

	-- Reverse sort
	vim.keymap.set("n", "gS", function()
		filter.get(buf).reverse = not filter.get(buf).reverse
		refresh(buf)
	end, vim.tbl_extend("force", opts, { desc = "Reverse sort" }))

	-- Search
	vim.keymap.set("n", "/", function()
		vim.ui.input({ prompt = "Search: " }, function(q)
			if q and q ~= "" then
				local f = filter.get(buf)
				f.mode = "search"
				f.search = q
				refresh(buf)
			end
		end)
	end, vim.tbl_extend("force", opts, { desc = "Text search" }))

	-- Query
	vim.keymap.set("n", "gq", function()
		vim.ui.input({ prompt = "Query: " }, function(q)
			if q and q ~= "" then
				local f = filter.get(buf)
				f.mode = "query"
				f.query = q
				refresh(buf)
			end
		end)
	end, vim.tbl_extend("force", opts, { desc = "Query expression" }))

	-- Defer
	vim.keymap.set("n", "gD", function()
		local bead = get_bead_under_cursor(buf)
		if not bead then
			return
		end
		vim.ui.input({ prompt = "Defer until (optional, empty to defer now): " }, function(val)
			local args = { "defer", bead.id }
			if val and val ~= "" then
				table.insert(args, "--until")
				table.insert(args, val)
			end
			cli.run(args, function(err)
				if err then
					vim.notify("beadboard: " .. err, vim.log.levels.ERROR)
					return
				end
				refresh(buf)
			end)
		end)
	end, vim.tbl_extend("force", opts, { desc = "Defer bead" }))

	-- Undefer
	vim.keymap.set("n", "gU", function()
		local bead = get_bead_under_cursor(buf)
		if not bead then
			return
		end
		mutate_and_refresh(buf, { "update", bead.id, "--status", "open" })
	end, vim.tbl_extend("force", opts, { desc = "Undefer bead" }))

	-- Visual-mode bulk close
	vim.keymap.set("x", "c", function()
		local start_row = vim.fn.line("v")
		local end_row = vim.fn.line(".")
		if start_row > end_row then
			start_row, end_row = end_row, start_row
		end
		local beads = get_beads_in_range(buf, start_row, end_row)
		if #beads == 0 then
			return
		end
		vim.ui.select({ "Yes", "No" }, { prompt = "Close " .. #beads .. " beads?" }, function(choice)
			if choice ~= "Yes" then
				return
			end
			bulk_mutate(buf, beads, function(bead)
				return { "close", bead.id }
			end)
		end)
	end, vim.tbl_extend("force", opts, { desc = "Bulk close selected" }))

	-- Visual-mode bulk delete
	vim.keymap.set("x", "dd", function()
		local start_row = vim.fn.line("v")
		local end_row = vim.fn.line(".")
		if start_row > end_row then
			start_row, end_row = end_row, start_row
		end
		local beads = get_beads_in_range(buf, start_row, end_row)
		if #beads == 0 then
			return
		end
		vim.ui.select({ "Yes", "No" }, { prompt = "Delete " .. #beads .. " beads?" }, function(choice)
			if choice ~= "Yes" then
				return
			end
			bulk_mutate(buf, beads, function(bead)
				return { "delete", bead.id }
			end)
		end)
	end, vim.tbl_extend("force", opts, { desc = "Bulk delete selected" }))

	-- Visual-mode bulk defer
	vim.keymap.set("x", "gD", function()
		local start_row = vim.fn.line("v")
		local end_row = vim.fn.line(".")
		if start_row > end_row then
			start_row, end_row = end_row, start_row
		end
		local beads = get_beads_in_range(buf, start_row, end_row)
		if #beads == 0 then
			return
		end
		vim.ui.select({ "Yes", "No" }, { prompt = "Defer " .. #beads .. " beads?" }, function(choice)
			if choice ~= "Yes" then
				return
			end
			bulk_mutate(buf, beads, function(bead)
				return { "defer", bead.id }
			end)
		end)
	end, vim.tbl_extend("force", opts, { desc = "Bulk defer selected" }))

	-- Visual-mode bulk status update
	vim.keymap.set("x", "s", function()
		local start_row = vim.fn.line("v")
		local end_row = vim.fn.line(".")
		if start_row > end_row then
			start_row, end_row = end_row, start_row
		end
		local beads = get_beads_in_range(buf, start_row, end_row)
		if #beads == 0 then
			return
		end
		vim.ui.select(status_cycle, { prompt = "Status for " .. #beads .. " beads:" }, function(choice)
			if not choice then
				return
			end
			bulk_mutate(buf, beads, function(bead)
				return { "update", bead.id, "--status", choice }
			end)
		end)
	end, vim.tbl_extend("force", opts, { desc = "Bulk status update" }))

	-- Claude skill picker
	vim.keymap.set("n", "gC", function()
		local bead = get_bead_under_cursor(buf)
		if not bead then
			return
		end
		require("beadboard.claude").pick_and_run(bead)
	end, vim.tbl_extend("force", opts, { desc = "Claude skill picker" }))

	-- Visual-mode Claude skill picker (multi-bead)
	vim.keymap.set("x", "gC", function()
		local start_row = vim.fn.line("v")
		local end_row = vim.fn.line(".")
		if start_row > end_row then
			start_row, end_row = end_row, start_row
		end
		local beads = get_beads_in_range(buf, start_row, end_row)
		if #beads == 0 then
			return
		end
		require("beadboard.claude").pick_and_run_multi(beads)
	end, vim.tbl_extend("force", opts, { desc = "Claude skill picker" }))

	-- Tree mode toggle
	vim.keymap.set("n", "t", function()
		local f = filter.get(buf)
		f.tree = not f.tree
		refresh(buf)
	end, vim.tbl_extend("force", opts, { desc = "Toggle tree mode" }))

	-- Collapse tree node
	vim.keymap.set("n", "<", function()
		if not filter.get(buf).tree then
			return
		end
		local bd = buf_beads[buf]
		if not bd or not bd.tree_entries then
			return
		end
		local row = vim.api.nvim_win_get_cursor(0)[1]
		if row <= 1 then
			return
		end
		local entry = bd.tree_entries[row - 1]
		if not entry then
			return
		end
		if not buf_collapsed[buf] then
			buf_collapsed[buf] = {}
		end
		local changed = false
		if entry.has_children then
			if not entry.collapsed then
				buf_collapsed[buf][entry.bead.id] = true
				changed = true
			end
		elseif entry.depth > 0 then
			for j = row - 2, 1, -1 do
				local parent = bd.tree_entries[j]
				if parent and parent.depth == entry.depth - 1 then
					if not parent.collapsed then
						buf_collapsed[buf][parent.bead.id] = true
						changed = true
					end
					break
				end
			end
		end
		if changed then
			refresh(buf)
		end
	end, vim.tbl_extend("force", opts, { desc = "Collapse tree node" }))

	-- Expand tree node
	vim.keymap.set("n", ">", function()
		if not filter.get(buf).tree then
			return
		end
		local bead = get_bead_under_cursor(buf)
		if not bead then
			return
		end
		if buf_collapsed[buf] and buf_collapsed[buf][bead.id] then
			buf_collapsed[buf][bead.id] = nil
			refresh(buf)
		end
	end, vim.tbl_extend("force", opts, { desc = "Expand tree node" }))

	-- Help
	vim.keymap.set("n", "?", function()
		require("beadboard.help").toggle()
	end, vim.tbl_extend("force", opts, { desc = "Show help" }))
end

local function create_list_buf()
	local buf = vim.api.nvim_create_buf(false, true)

	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "beadboard-list"

	vim.api.nvim_set_current_buf(buf)

	vim.api.nvim_create_autocmd("BufWipeout", {
		buffer = buf,
		callback = function()
			buf_beads[buf] = nil
			buf_collapsed[buf] = nil
			last_refresh_time[buf] = nil
			filter.cleanup(buf)
		end,
	})

	setup_keymaps(buf)

	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "[beadboard] Loading..." })
	vim.bo[buf].modifiable = false

	return buf
end

function M.open()
	local buf = create_list_buf()
	local cfg = get_config()
	if cfg.default_tree then
		filter.get(buf).tree = true
	end
	refresh(buf)
end

function M.open_tree()
	local buf = create_list_buf()
	filter.get(buf).tree = true
	refresh(buf)
end

function M.open_with_mode(mode, value)
	local buf = create_list_buf()
	local f = filter.get(buf)
	f.mode = mode
	if mode == "search" then
		f.search = value
	elseif mode == "query" then
		f.query = value
	elseif mode == "children" then
		f.parent = value
	elseif mode == "stale" then
		f.mode = "stale"
		f.stale_days = value
	end
	refresh(buf)
end

function M.refresh_buf(buf)
	refresh(buf)
end

function M.should_refresh(buf)
	local last = last_refresh_time[buf]
	if not last then
		return true
	end
	return (vim.uv.now() - last) > 5000
end

return M
