local hl = require("beadboard.highlight")
local util = require("beadboard.util")

local M = {}

local ns = vim.api.nvim_create_namespace("beadboard_preview")
local filetype = "beadboard_preview"

local separator = string.rep("\u{2500}", 52)

local function fmt_date(ts)
	if not ts or ts == "" then
		return "?"
	end
	return string.match(ts, "^(%d%d%d%d%-%d%d%-%d%d)") or ts
end

local function fmt_or_none(val)
	if not val or val == "" then
		return "(none)"
	end
	return val
end

local function fmt_labels(labels)
	if not labels or #labels == 0 then
		return "(none)"
	end
	return table.concat(labels, ", ")
end

local function split_lines(text)
	if not text or text == "" then
		return { "(empty)" }
	end
	local lines = {}
	for line in (text .. "\n"):gmatch("([^\n]*)\n") do
		lines[#lines + 1] = line
	end
	return lines
end

local function build_lines(bead)
	local lines = {}
	local highlights = {}

	local id_str = bead.id or "?"
	local title_line = id_str .. " \u{2014} " .. (bead.title or "")
	lines[#lines + 1] = title_line
	highlights[#highlights + 1] = { #lines - 1, "BeadboardId", 0, #id_str }

	local status_str = bead.status or "?"
	local priority_str = util.priority_label(bead.priority)
	local type_str = bead.issue_type or "?"
	local meta_line = "Status: " .. status_str .. " | Priority: " .. priority_str .. " | Type: " .. type_str
	lines[#lines + 1] = meta_line
	local row = #lines - 1
	local s_start = #"Status: "
	local s_end = s_start + #status_str
	highlights[#highlights + 1] = { row, hl.status_group(bead.status), s_start, s_end }
	local p_start = s_end + #" | Priority: "
	local p_end = p_start + #priority_str
	highlights[#highlights + 1] = { row, hl.priority_group(bead.priority), p_start, p_end }
	local t_start = p_end + #" | Type: "
	local t_end = t_start + #type_str
	highlights[#highlights + 1] = { row, "BeadboardType", t_start, t_end }

	lines[#lines + 1] = "Owner: " .. fmt_or_none(bead.owner) .. " | Assignee: " .. fmt_or_none(bead.assignee)

	lines[#lines + 1] = "Labels: " .. fmt_labels(bead.labels)

	lines[#lines + 1] = "Created: " .. fmt_date(bead.created_at) .. " | Updated: " .. fmt_date(bead.updated_at)

	lines[#lines + 1] = separator
	highlights[#highlights + 1] = { #lines - 1, "Comment", 0, -1 }

	local sections = {
		{ "## Description", bead.description },
		{ "## Notes", bead.notes },
	}
	for _, sec in ipairs(sections) do
		lines[#lines + 1] = ""
		lines[#lines + 1] = sec[1]
		highlights[#highlights + 1] = { #lines - 1, "BeadboardHeader", 0, -1 }
		for _, l in ipairs(split_lines(sec[2])) do
			lines[#lines + 1] = l
		end
	end

	return lines, highlights
end

local function render(buf, bead)
	local lines, highlights = build_lines(bead)

	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].modified = false

	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	for _, h in ipairs(highlights) do
		vim.api.nvim_buf_add_highlight(buf, ns, h[2], h[1], h[3], h[4])
	end
end

--- Close any existing beadboard preview float on the current tab.
---@return boolean true if a preview window was found and closed
local function close_existing()
	local found = false
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.api.nvim_win_is_valid(win) then
			local buf = vim.api.nvim_win_get_buf(win)
			if vim.bo[buf].filetype == filetype then
				vim.api.nvim_win_close(win, true)
				found = true
			end
		end
	end
	return found
end

--- Setup keymaps and autocmds for preview window.
--- @param buf number the preview buffer
--- @param source_buf number the buffer that triggered preview
--- @param close_win_fn function function to close the preview window
local function setup_preview_bindings(buf, source_buf, close_win_fn)
	vim.keymap.set("n", "q", close_win_fn, { buffer = buf, nowait = true, silent = true })
	vim.keymap.set("n", "<Esc>", close_win_fn, { buffer = buf, nowait = true, silent = true })

	local augroup = vim.api.nvim_create_augroup("beadboard_preview_" .. source_buf, { clear = true })
	vim.api.nvim_create_autocmd("BufWipeout", {
		group = augroup,
		buffer = source_buf,
		once = true,
		callback = function()
			close_win_fn()
			pcall(vim.api.nvim_del_augroup_by_id, augroup)
		end,
	})
end

local function open_snacks(bead, source_buf)
	local Snacks = require("snacks")
	local win = Snacks.win({
		show = false,
		focusable = true,
		position = "float",
		backdrop = 60,
		border = "rounded",
		width = 0.8,
		height = 0.7,
		zindex = 51,
		bo = { filetype = filetype },
	})

	win:show()
	render(win.buf, bead)

	setup_preview_bindings(win.buf, source_buf, function()
		if win:valid() then
			win:close()
		end
	end)
end

local function open_fallback(bead, source_buf)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = filetype

	render(buf, bead)

	local editor_width = vim.o.columns
	local editor_height = vim.o.lines - 2
	local win_width = math.floor(editor_width * 0.8)
	local win_height = math.floor(editor_height * 0.7)
	local row = math.floor((editor_height - win_height) / 2)
	local col = math.floor((editor_width - win_width) / 2)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		row = row,
		col = col,
		width = win_width,
		height = win_height,
		style = "minimal",
		border = "rounded",
		focusable = true,
		zindex = 51,
	})
	vim.wo[win].winhighlight = "Normal:NormalFloat"

	setup_preview_bindings(buf, source_buf, function()
		pcall(vim.api.nvim_win_close, win, true)
	end)
end

function M.close()
	return close_existing()
end

function M.open(bead, source_buf)
	close_existing()
	if util.has_snacks_win() then
		open_snacks(bead, source_buf)
	else
		open_fallback(bead, source_buf)
	end
end

function M.toggle(bead, source_buf)
	if close_existing() then
		return
	end
	M.open(bead, source_buf)
end

return M
