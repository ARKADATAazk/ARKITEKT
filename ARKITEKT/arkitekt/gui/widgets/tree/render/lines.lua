-- @noindex
-- arkitekt/gui/widgets/tree/render/lines.lua
-- Tree line rendering (dotted/solid connectors)

local ImGui = require('arkitekt.core.imgui')

local M = {}

-- ============================================================================
-- DOTTED LINE
-- ============================================================================

--- Draw a dotted line
--- @param dl userdata DrawList
--- @param x1 number Start X
--- @param y1 number Start Y
--- @param x2 number End X
--- @param y2 number End Y
--- @param color number Line color (RRGGBBAA)
--- @param thickness number Dot size
--- @param spacing number Space between dots
function M.dotted(dl, x1, y1, x2, y2, color, thickness, spacing)
  -- Round to whole pixels for crisp rendering
  x1 = (x1 + 0.5) // 1
  y1 = (y1 + 0.5) // 1
  x2 = (x2 + 0.5) // 1
  y2 = (y2 + 0.5) // 1

  local dx = x2 - x1
  local dy = y2 - y1
  local length = math.sqrt(dx * dx + dy * dy)
  local num_dots = (length / spacing) // 1

  if num_dots == 0 then return end

  for i = 0, num_dots do
    local t = i / num_dots
    local x = (x1 + dx * t + 0.5) // 1
    local y = (y1 + dy * t + 0.5) // 1
    ImGui.DrawList_AddCircleFilled(dl, x, y, thickness / 2, color)
  end
end

-- ============================================================================
-- TREE LINES
-- ============================================================================

--- Draw tree connector lines for a node
--- @param dl userdata DrawList
--- @param cfg table Tree configuration
--- @param x number Indent X position
--- @param y number Node Y position
--- @param depth number Node depth (0 = root)
--- @param item_h number Item height
--- @param has_children boolean Whether node has children
--- @param is_last_child boolean Whether this is the last sibling
--- @param parent_lines table Array of booleans indicating which parent levels need vertical lines
function M.draw(dl, cfg, x, y, depth, item_h, has_children, is_last_child, parent_lines)
  if not cfg.show_tree_lines or depth == 0 then return end

  local line_color = cfg.colors.tree_line
  local is_dotted = cfg.tree_line_style == 'dotted'
  local thickness = cfg.tree_line_thickness
  local dot_spacing = cfg.tree_line_dot_spacing

  -- Line positioning - align with arrow center
  local base_x = x - cfg.indent_width / 2
  local mid_y = y + item_h / 2

  if depth > 0 then
    -- Horizontal line to item
    local h_start_x = base_x
    local h_end_x = x + cfg.arrow_size / 2

    if is_dotted then
      M.dotted(dl, h_start_x, mid_y, h_end_x, mid_y, line_color, thickness, dot_spacing)
    else
      ImGui.DrawList_AddLine(dl, h_start_x, mid_y, h_end_x, mid_y, line_color, thickness)
    end

    -- Vertical line segment
    if not is_last_child then
      -- Full height (continues to next sibling)
      local v_start_y = y
      local v_end_y = y + item_h
      if is_dotted then
        M.dotted(dl, base_x, v_start_y, base_x, v_end_y, line_color, thickness, dot_spacing)
      else
        ImGui.DrawList_AddLine(dl, base_x, v_start_y, base_x, v_end_y, line_color, thickness)
      end
    else
      -- Only to mid point (last child, no continuation)
      if is_dotted then
        M.dotted(dl, base_x, y, base_x, mid_y, line_color, thickness, dot_spacing)
      else
        ImGui.DrawList_AddLine(dl, base_x, y, base_x, mid_y, line_color, thickness)
      end
    end
  end

  -- Parent level vertical lines (for deeper nesting)
  for i = 1, depth - 1 do
    if parent_lines[i] then
      local parent_x = base_x - (depth - i) * cfg.indent_width
      if is_dotted then
        M.dotted(dl, parent_x, y, parent_x, y + item_h, line_color, thickness, dot_spacing)
      else
        ImGui.DrawList_AddLine(dl, parent_x, y, parent_x, y + item_h, line_color, thickness)
      end
    end
  end
end

return M
