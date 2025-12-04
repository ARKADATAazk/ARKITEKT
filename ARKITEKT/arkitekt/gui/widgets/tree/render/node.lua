-- @noindex
-- arkitekt/gui/widgets/tree/render/node.lua
-- Single node rendering for Tree widget

local ImGui = require('arkitekt.core.imgui')
local Icons = require('arkitekt.gui.widgets.tree.render.icons')
local Lines = require('arkitekt.gui.widgets.tree.render.lines')
local State = require('arkitekt.gui.widgets.tree.core.state')

local M = {}

-- ============================================================================
-- NODE BACKGROUNDS
-- ============================================================================

--- Draw node background (selection, hover, alternating)
--- @param dl userdata DrawList
--- @param cfg table Configuration
--- @param x number Left X
--- @param y number Top Y
--- @param w number Width
--- @param h number Height
--- @param is_selected boolean
--- @param is_hovered boolean
--- @param is_focused boolean
--- @param row_index number Row index for alternating bg
--- @param search_match boolean Whether node matches search
function M.draw_background(dl, cfg, x, y, w, h, is_selected, is_hovered, is_focused, row_index, search_match)
  local colors = cfg.colors

  -- Alternating background
  if cfg.show_alternating_bg and row_index % 2 == 0 then
    ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, colors.bg_alternate)
  end

  -- Search highlight
  if search_match then
    ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, 0x4A4A1AFF)
  end

  -- Selection background
  if is_selected then
    local bg = is_hovered and colors.bg_selected_hover or colors.bg_selected
    ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, bg)
  elseif is_hovered then
    ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, colors.bg_hover)
  end

  -- Focus ring
  if is_focused then
    ImGui.DrawList_AddRect(dl, x + 1, y, x + w - 1, y + h, colors.focus_ring, 0, 0, 1)
  end
end

--- Draw drag overlay for nodes being dragged
--- @param dl userdata DrawList
--- @param cfg table Configuration
--- @param x number Left X
--- @param y number Top Y
--- @param w number Width
--- @param h number Height
function M.draw_drag_overlay(dl, cfg, x, y, w, h)
  local colors = cfg.colors
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, colors.drag_overlay)
  ImGui.DrawList_AddRect(dl, x + 1, y + 1, x + w - 1, y + h - 1, colors.drag_border, 0, 0, 1)
end

--- Draw drop indicator
--- @param dl userdata DrawList
--- @param cfg table Configuration
--- @param x number Left X
--- @param y number Top Y
--- @param w number Width
--- @param h number Height
--- @param position string 'before', 'into', or 'after'
function M.draw_drop_indicator(dl, cfg, x, y, w, h, position)
  local color = cfg.colors.drop_indicator

  if position == 'before' then
    ImGui.DrawList_AddLine(dl, x, y, x + w, y, color, 2)
  elseif position == 'after' then
    ImGui.DrawList_AddLine(dl, x, y + h, x + w, y + h, color, 2)
  elseif position == 'into' then
    ImGui.DrawList_AddRect(dl, x + 2, y + 1, x + w - 2, y + h - 1, color, 0, 0, 2)
  end
end

-- ============================================================================
-- TEXT RENDERING
-- ============================================================================

--- Draw node text with truncation
--- @param ctx userdata ImGui context
--- @param dl userdata DrawList
--- @param text string Text to draw
--- @param x number X position
--- @param y number Y position
--- @param max_width number Maximum width before truncation
--- @param color number Text color (RRGGBBAA)
--- @return boolean is_truncated Whether text was truncated
function M.draw_text(ctx, dl, text, x, y, max_width, color)
  local text_w = ImGui.CalcTextSize(ctx, text)

  if text_w > max_width then
    local truncated = text
    while text_w > max_width - 10 and #truncated > 3 do
      truncated = truncated:sub(1, -2)
      text_w = ImGui.CalcTextSize(ctx, truncated .. '...')
    end
    ImGui.DrawList_AddText(dl, x, y, color, truncated .. '...')
    return true
  else
    ImGui.DrawList_AddText(dl, x, y, color, text)
    return false
  end
end

-- ============================================================================
-- COMPLETE NODE RENDERING
-- ============================================================================

--- Calculate node layout positions
--- @param cfg table Configuration
--- @param x number Tree left X
--- @param y number Node top Y
--- @param w number Tree width
--- @param depth number Node depth
--- @return table Layout with all positions
function M.calculate_layout(cfg, x, y, w, depth)
  local item_h = cfg.item_height

  local indent_x = x + cfg.padding_left + depth * cfg.indent_width
  local arrow_x = indent_x
  local arrow_y = y + (item_h - cfg.arrow_size) / 2
  local icon_x = arrow_x + cfg.arrow_size + cfg.arrow_margin
  local icon_y = y + (item_h - 9) / 2  -- 9 = approximate icon height
  local text_x = icon_x + cfg.icon_width + cfg.icon_margin + cfg.item_padding_left
  local item_right = x + w - cfg.padding_right

  return {
    item_h = item_h,
    indent_x = indent_x,
    arrow_x = arrow_x,
    arrow_y = arrow_y,
    icon_x = icon_x,
    icon_y = icon_y,
    text_x = text_x,
    item_right = item_right,
  }
end

--- Render a single tree node (without children)
--- @param ctx userdata ImGui context
--- @param dl userdata DrawList
--- @param node table Node data
--- @param state table Tree state
--- @param cfg table Configuration
--- @param layout table Layout positions from calculate_layout
--- @param x number Tree left X
--- @param y number Node top Y
--- @param w number Tree width
--- @param depth number Node depth
--- @param is_last_child boolean
--- @param parent_lines table Parent line flags
--- @param row_index number Row index
--- @param result table Result object to populate
--- @return boolean is_truncated Whether text was truncated
function M.render(ctx, dl, node, state, cfg, layout, x, y, w, depth, is_last_child, parent_lines, row_index, result)
  local colors = cfg.colors
  local item_h = layout.item_h

  local has_children = node.children and #node.children > 0
  local is_open = State.is_open(state, node.id)
  local is_selected = State.is_selected(state, node.id)
  local is_focused = state.focused == node.id
  local is_hovered = false

  -- Check hover
  local mx, my = ImGui.GetMousePos(ctx)
  if mx >= x and mx < x + w and my >= y and my < y + item_h then
    is_hovered = true
    state.hovered = node.id
    result.hovered_id = node.id
  end

  -- Check if being dragged
  local is_being_dragged = false
  if state.drag_active then
    for _, drag_id in ipairs(state.drag_node_ids) do
      if drag_id == node.id then
        is_being_dragged = true
        break
      end
    end
  end

  -- Draw background
  local search_match = result._search_text and result._search_text ~= '' and
    node.name:lower():find(result._search_text:lower(), 1, true)
  M.draw_background(dl, cfg, x, y, w, item_h, is_selected, is_hovered, is_focused, row_index, search_match)

  -- Draw drag overlay
  if is_being_dragged then
    M.draw_drag_overlay(dl, cfg, x, y, w, item_h)
  end

  -- Draw drop indicator
  if state.drag_active and state.drop_target_id == node.id and state.drop_position then
    M.draw_drop_indicator(dl, cfg, x, y, w, item_h, state.drop_position)
  end

  -- Draw tree lines
  Lines.draw(dl, cfg, layout.indent_x, y, depth, item_h, has_children, is_last_child, parent_lines)

  -- Draw arrow
  if has_children then
    Icons.arrow(dl, layout.arrow_x, layout.arrow_y, is_open, colors.arrow, cfg.arrow_size)
  end

  -- Draw icon
  local icon_color = node.color or (is_open and colors.icon_open or colors.icon)
  Icons.draw(dl, layout.icon_x, layout.icon_y, node, is_open, icon_color)

  -- Draw text
  local text_y = y + (item_h - ImGui.CalcTextSize(ctx, 'Tg')) / 2
  local text_color = (is_hovered or is_selected) and colors.text_hover or colors.text_normal
  local available_w = layout.item_right - layout.text_x
  local is_truncated = M.draw_text(ctx, dl, node.name, layout.text_x, text_y, available_w, text_color)

  return is_truncated
end

return M
