local M = {}

local priority_labels = { 'P0', 'P1', 'P2', 'P3', 'P4' }

function M.priority_label(n)
  return priority_labels[(n or 4) + 1] or 'P?'
end

function M.pad(s, width)
  s = tostring(s or '')
  if #s >= width then
    return s:sub(1, width)
  end
  return s .. string.rep(' ', width - #s)
end

function M.format_bead_line(bead, col_widths)
  local id = M.pad(bead.id or '', col_widths.id)
  local pri = M.pad(M.priority_label(bead.priority), col_widths.priority)
  local status = M.pad(bead.status or '', col_widths.status)
  local btype = M.pad(bead.issue_type or '', col_widths.type)
  local title = bead.title or ''
  return id .. '  ' .. pri .. '  ' .. status .. '  ' .. btype .. '  ' .. title
end

-- Returns byte offsets for each column in a formatted line.
-- Used for applying per-cell highlights.
function M.column_offsets(bead, col_widths)
  local id_start = 0
  local id_end = col_widths.id

  local pri_start = id_end + 2
  local pri_end = pri_start + col_widths.priority

  local status_start = pri_end + 2
  local status_end = status_start + col_widths.status

  local type_start = status_end + 2
  local type_end = type_start + col_widths.type

  local title_start = type_end + 2
  local title_end = title_start + #(bead.title or '')

  return {
    id = { id_start, id_end },
    priority = { pri_start, pri_end },
    status = { status_start, status_end },
    type = { type_start, type_end },
    title = { title_start, title_end },
  }
end

-- Compute column widths from a list of beads.
function M.compute_col_widths(beads)
  local widths = { id = 4, priority = 2, status = 6, type = 4 }
  for _, bead in ipairs(beads) do
    widths.id = math.max(widths.id, #(bead.id or ''))
    widths.status = math.max(widths.status, #(bead.status or ''))
    widths.type = math.max(widths.type, #(bead.issue_type or ''))
  end
  return widths
end

return M
