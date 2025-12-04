-- @noindex
-- arkitekt/gui/widgets/tree/core/drag_drop.lua
-- Drag and drop handling for Tree widgets

local ImGui = require('arkitekt.core.imgui')
local State = require('arkitekt.gui.widgets.tree.core.state')

local M = {}

-- ============================================================================
-- DRAG START
-- ============================================================================

--- Start drag operation
--- @param state table Tree state
--- @param node_id string Node being dragged
--- @param mx number Mouse X
--- @param my number Mouse Y
function M.start_drag(state, node_id, mx, my)
  state.drag_active = true
  state.drag_node_id = node_id
  state.drag_start_x = mx
  state.drag_start_y = my

  -- Multi-drag: if dragged node is selected, drag all selected nodes
  if State.is_selected(state, node_id) then
    state.drag_node_ids = State.get_selected_ids(state)
  else
    -- Single drag: only drag this node
    state.drag_node_ids = { node_id }
  end
end

--- Check if drag should start (mouse moved past threshold)
--- @param ctx userdata ImGui context
--- @param state table Tree state
--- @param cfg table Configuration
--- @param node_id string Potential drag node
--- @return boolean Should start drag
function M.check_drag_start(ctx, state, cfg, node_id)
  if state.drag_active then return false end

  local mx, my = ImGui.GetMousePos(ctx)
  if ImGui.IsMouseDragging(ctx, 0, 0) then
    M.start_drag(state, node_id, mx, my)
    return true
  end

  return false
end

-- ============================================================================
-- DROP TARGET DETECTION
-- ============================================================================

--- Update drop target based on mouse position
--- @param state table Tree state
--- @param node_id string Potential drop target node ID
--- @param has_children boolean Whether target node has children
--- @param y number Node Y position
--- @param item_h number Item height
--- @param my number Mouse Y position
function M.update_drop_target(state, node_id, has_children, y, item_h, my)
  -- Don't allow drop on self or nodes being dragged
  for _, drag_id in ipairs(state.drag_node_ids) do
    if drag_id == node_id then
      return
    end
  end

  local relative_y = my - y

  if relative_y < item_h * 0.25 then
    state.drop_target_id = node_id
    state.drop_position = 'before'
  elseif relative_y > item_h * 0.75 then
    state.drop_target_id = node_id
    state.drop_position = 'after'
  elseif has_children then
    state.drop_target_id = node_id
    state.drop_position = 'into'
  else
    state.drop_target_id = node_id
    state.drop_position = 'after'
  end
end

--- Clear drop target when not hovering
--- @param state table Tree state
function M.clear_drop_target(state)
  if not state.hovered then
    state.drop_target_id = nil
    state.drop_position = nil
  end
end

-- ============================================================================
-- DRAG COMPLETION
-- ============================================================================

--- Complete drag operation
--- @param ctx userdata ImGui context
--- @param state table Tree state
--- @param opts table Tree options
--- @param result table Result object
function M.complete_drag(ctx, state, opts, result)
  if not state.drag_active then return end

  if ImGui.IsMouseReleased(ctx, 0) then
    -- Perform drop
    if state.drop_target_id and state.drop_position then
      result.dropped = true
      result.drop_source_ids = state.drag_node_ids
      result.drop_target_id = state.drop_target_id
      result.drop_position = state.drop_position
      result.drop_is_copy = state.drag_is_copy

      if opts.on_drop then
        opts.on_drop({
          source_ids = state.drag_node_ids,
          target_id = state.drop_target_id,
          position = state.drop_position,
          is_copy = state.drag_is_copy,
        })
      end
    end

    -- Reset drag state
    M.reset_drag(state)
  else
    -- Update copy mode (CTRL held = copy)
    state.drag_is_copy = ImGui.GetKeyMods(ctx) & ImGui.Mod_Ctrl ~= 0
  end
end

--- Reset drag state
--- @param state table Tree state
function M.reset_drag(state)
  state.drag_active = false
  state.drag_node_id = nil
  state.drag_node_ids = {}
  state.drag_is_copy = false
  state.drop_target_id = nil
  state.drop_position = nil
end

-- ============================================================================
-- AUTO-SCROLL DURING DRAG
-- ============================================================================

--- Handle auto-scroll when dragging near edges
--- @param ctx userdata ImGui context
--- @param state table Tree state
--- @param cfg table Configuration
--- @param bounds table Tree bounds { x, y, w, h }
function M.handle_auto_scroll(ctx, state, cfg, bounds)
  if not state.drag_active then return end

  local _, my = ImGui.GetMousePos(ctx)

  if my < bounds.y + cfg.auto_scroll_zone then
    -- Near top edge - scroll up
    state.scroll_y = math.max(0, state.scroll_y - cfg.auto_scroll_speed)
  elseif my > bounds.y + bounds.h - cfg.auto_scroll_zone then
    -- Near bottom edge - scroll down
    local max_scroll = math.max(0, state.total_content_height - bounds.h + cfg.padding_top)
    state.scroll_y = math.min(max_scroll, state.scroll_y + cfg.auto_scroll_speed)
  end
end

-- ============================================================================
-- DRAG PREVIEW (VS Code style)
-- ============================================================================

--- Draw drag preview
--- @param ctx userdata ImGui context
--- @param dl userdata DrawList
--- @param node table Primary drag node
--- @param count number Total drag count
--- @param is_copy boolean Whether copy mode
function M.draw_preview(ctx, dl, node, count, is_copy)
  if not node then return end

  local mx, my = ImGui.GetMousePos(ctx)

  -- Layout
  local padding = 8
  local icon_size = 16
  local badge_size = 18
  local copy_indicator_size = 14
  local spacing = 6

  -- Measure text
  local text = node.name
  local text_w = ImGui.CalcTextSize(ctx, text)
  local text_h = 14  -- Approximate

  -- Calculate preview dimensions
  local preview_w = padding + icon_size + spacing + text_w + padding
  local preview_h = math.max(icon_size, text_h) + padding * 2

  -- Add badge width if multiple items
  local show_badge = count > 1
  if show_badge then
    preview_w = preview_w + spacing + badge_size
  end

  -- Add copy indicator if in copy mode
  if is_copy then
    preview_w = preview_w + spacing + copy_indicator_size
  end

  -- Position offset from cursor
  local offset_x = 16
  local offset_y = 16
  local preview_x = mx + offset_x
  local preview_y = my + offset_y

  -- Colors
  local bg_color = 0x252526E6
  local border_color = 0x454545FF
  local text_color = 0xCCCCCCFF
  local badge_bg = 0x007ACCFF
  local badge_text = 0xFFFFFFFF

  -- Shadow
  local shadow_offset = 2
  local shadow_color = 0x00000040
  ImGui.DrawList_AddRectFilled(dl,
    preview_x + shadow_offset, preview_y + shadow_offset,
    preview_x + preview_w + shadow_offset, preview_y + preview_h + shadow_offset,
    shadow_color, 4)

  -- Background
  ImGui.DrawList_AddRectFilled(dl, preview_x, preview_y, preview_x + preview_w, preview_y + preview_h, bg_color, 4)

  -- Border
  ImGui.DrawList_AddRect(dl, preview_x, preview_y, preview_x + preview_w, preview_y + preview_h, border_color, 4, 0, 1)

  -- Icon (simple rectangle for now)
  local icon_x = preview_x + padding
  local icon_y = preview_y + (preview_h - icon_size) / 2
  local has_children = node.children and #node.children > 0
  local icon_color = 0xCCCCCCFF

  if has_children then
    -- Folder shape
    local scale = icon_size / 13
    local folder_w = (13 * scale) // 1
    local folder_h = (7 * scale) // 1
    local tab_w = (5 * scale) // 1
    local tab_h = (2 * scale) // 1
    icon_x = (icon_x + 0.5) // 1
    icon_y = (icon_y + 0.5) // 1
    ImGui.DrawList_AddRectFilled(dl, icon_x, icon_y, icon_x + tab_w, icon_y + tab_h, icon_color, 0)
    ImGui.DrawList_AddRectFilled(dl, icon_x, icon_y + tab_h, icon_x + folder_w, icon_y + tab_h + folder_h, icon_color, 0)
  else
    -- File shape
    local scale = icon_size / 12
    local file_w = (10 * scale) // 1
    local file_h = (12 * scale) // 1
    icon_x = (icon_x + 0.5) // 1
    icon_y = (icon_y + 0.5) // 1
    ImGui.DrawList_AddRectFilled(dl, icon_x, icon_y, icon_x + file_w, icon_y + file_h, icon_color, 0)
  end

  -- Text
  local text_x = icon_x + icon_size + spacing
  local text_y = preview_y + (preview_h - text_h) / 2
  ImGui.DrawList_AddText(dl, text_x, text_y, text_color, text)

  -- Count badge
  local content_end_x = text_x + text_w
  if show_badge then
    local badge_x = content_end_x + spacing
    local badge_y = preview_y + (preview_h - badge_size) / 2
    local badge_radius = badge_size / 2

    ImGui.DrawList_AddCircleFilled(dl, badge_x + badge_radius, badge_y + badge_radius, badge_radius, badge_bg)

    local count_text = tostring(count)
    local count_w = ImGui.CalcTextSize(ctx, count_text)
    local count_x = badge_x + (badge_size - count_w) / 2
    local count_y = badge_y + (badge_size - 14) / 2
    ImGui.DrawList_AddText(dl, count_x, count_y, badge_text, count_text)

    content_end_x = badge_x + badge_size
  end

  -- Copy indicator (+)
  if is_copy then
    local plus_x = content_end_x + spacing
    local plus_y = preview_y + (preview_h - copy_indicator_size) / 2
    local plus_size = copy_indicator_size
    local plus_color = 0x00FF00FF

    ImGui.DrawList_AddCircleFilled(dl, plus_x + plus_size / 2, plus_y + plus_size / 2, plus_size / 2, 0x00000080)

    local plus_w = plus_size * 0.5
    local center_x = plus_x + plus_size / 2
    local center_y = plus_y + plus_size / 2

    ImGui.DrawList_AddLine(dl, center_x - plus_w / 2, center_y, center_x + plus_w / 2, center_y, plus_color, 2)
    ImGui.DrawList_AddLine(dl, center_x, center_y - plus_w / 2, center_x, center_y + plus_w / 2, plus_color, 2)
  end
end

return M
