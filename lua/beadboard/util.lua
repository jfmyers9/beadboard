local M = {}

local priority_labels = { "P0", "P1", "P2", "P3", "P4" }

function M.priority_label(n)
	return priority_labels[(n or 4) + 1] or "P?"
end

function M.pad(s, width)
	s = tostring(s or "")
	if #s >= width then
		return s:sub(1, width)
	end
	return s .. string.rep(" ", width - #s)
end

function M.format_bead_line(bead, col_widths)
	local id = M.pad(bead.id or "", col_widths.id)
	local pri = M.pad(M.priority_label(bead.priority), col_widths.priority)
	local status = M.pad(bead.status or "", col_widths.status)
	local btype = M.pad(bead.issue_type or "", col_widths.type)
	local title = bead.title or ""
	return id .. "  " .. pri .. "  " .. status .. "  " .. btype .. "  " .. title
end

local function compute_offsets(start, col_widths, title)
	local id_start = start
	local id_end = id_start + col_widths.id

	local pri_start = id_end + 2
	local pri_end = pri_start + col_widths.priority

	local status_start = pri_end + 2
	local status_end = status_start + col_widths.status

	local type_start = status_end + 2
	local type_end = type_start + col_widths.type

	local title_start = type_end + 2
	local title_end = title_start + #(title or "")

	return {
		id = { id_start, id_end },
		priority = { pri_start, pri_end },
		status = { status_start, status_end },
		type = { type_start, type_end },
		title = { title_start, title_end },
	}
end

-- Returns byte offsets for each column in a formatted line.
-- Used for applying per-cell highlights.
function M.column_offsets(bead, col_widths)
	return compute_offsets(0, col_widths, bead.title)
end

-- Compute column widths from a list of beads or tree entries.
function M.compute_col_widths(items)
	local widths = { id = 4, priority = 2, status = 6, type = 4 }
	for _, item in ipairs(items) do
		local bead = item.bead or item
		widths.id = math.max(widths.id, #(bead.id or ""))
		widths.status = math.max(widths.status, #(bead.status or ""))
		widths.type = math.max(widths.type, #(bead.issue_type or ""))
	end
	return widths
end

function M.compute_col_widths_tree(entries)
	return M.compute_col_widths(entries)
end

local function tree_prefix(depth, is_last, ancestors)
	if depth == 0 then
		return ""
	end
	local parts = {}
	for i = 1, depth - 1 do
		if ancestors[i] then
			parts[#parts + 1] = "    "
		else
			parts[#parts + 1] = "│   "
		end
	end
	parts[#parts + 1] = is_last and "└── " or "├── "
	return table.concat(parts)
end

function M.format_tree_line(entry, col_widths)
	local prefix = tree_prefix(entry.depth, entry.is_last, entry.ancestors)
	return prefix .. M.format_bead_line(entry.bead, col_widths)
end

function M.tree_column_offsets(entry, col_widths)
	local prefix_len = #tree_prefix(entry.depth, entry.is_last, entry.ancestors)
	return compute_offsets(prefix_len, col_widths, entry.bead.title)
end

return M
