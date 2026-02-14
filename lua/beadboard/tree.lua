local M = {}

local MAX_DEPTH = 10

local function sort_by_priority(list)
	table.sort(list, function(a, b)
		local pa = a.priority or 4
		local pb = b.priority or 4
		if pa == pb then
			return (a.id or "") < (b.id or "")
		end
		return pa < pb
	end)
end

local function find_parent_id(bead)
	local deps = bead.dependencies
	if deps then
		for _, dep in ipairs(deps) do
			if dep.type == "parent-child" then
				return dep.depends_on_id
			end
		end
	end
	if bead.parent and bead.parent ~= "" then
		return bead.parent
	end
	return nil
end

function M.build(beads, collapsed)
	if not beads or #beads == 0 then
		return {}
	end
	collapsed = collapsed or {}

	local by_id = {}
	for _, bead in ipairs(beads) do
		by_id[bead.id] = bead
	end

	local children = {}
	local roots = {}
	for _, bead in ipairs(beads) do
		local pid = find_parent_id(bead)
		if pid and by_id[pid] then
			if not children[pid] then
				children[pid] = {}
			end
			children[pid][#children[pid] + 1] = bead
		else
			-- When parent is filtered out but child is present, child appears as root.
			-- This is expected tree view behavior.
			roots[#roots + 1] = bead
		end
	end

	sort_by_priority(roots)
	for _, kids in pairs(children) do
		sort_by_priority(kids)
	end

	local result = {}
	local visited = {}

	local function walk(list, depth, ancestors)
		if depth > MAX_DEPTH then
			return
		end
		for i, bead in ipairs(list) do
			if not visited[bead.id] then
				visited[bead.id] = true
				local kids = children[bead.id]
				local has_children = kids ~= nil
				local is_collapsed = has_children and collapsed[bead.id]
				result[#result + 1] = {
					bead = bead,
					depth = depth,
					is_last = (i == #list),
					ancestors = ancestors,
					has_children = has_children,
					collapsed = is_collapsed or false,
				}
				if kids and not is_collapsed then
					local next_ancestors = {}
					for j = 1, #ancestors do
						next_ancestors[j] = ancestors[j]
					end
					next_ancestors[#next_ancestors + 1] = (i == #list)
					walk(kids, depth + 1, next_ancestors)
				end
			end
		end
	end

	walk(roots, 0, {})
	return result
end

return M
