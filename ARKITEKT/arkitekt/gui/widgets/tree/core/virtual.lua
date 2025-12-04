-- @noindex
-- arkitekt/gui/widgets/tree/core/virtual.lua
-- Virtual scrolling calculations for Tree widgets

local ImGui = require('arkitekt.core.imgui')

local M = {}

-- ============================================================================
-- VISIBILITY CALCULATIONS
-- ============================================================================

--- Check if a node is visible in the current scroll region
--- @param y number Node Y position
--- @param height number Node height
--- @param visible_top number Top of visible region
--- @param visible_bottom number Bottom of visible region
--- @return boolean
function M.is_visible(y, height, visible_top, visible_bottom)
  return y + height >= visible_top and y <= visible_bottom
end

--- Calculate visible region bounds
--- @param bounds table Tree bounds { x, y, w, h }
--- @param cfg table Configuration
--- @return number visible_top
--- @return number visible_bottom
function M.get_visible_region(bounds, cfg)
  local visible_top = bounds.y
  local visible_bottom = bounds.y + bounds.h
  return visible_top, visible_bottom
end

-- ============================================================================
-- SCROLL HANDLING
-- ============================================================================

--- Handle mouse wheel scrolling
--- @param ctx userdata ImGui context
--- @param state table Tree state
--- @param cfg table Configuration
--- @param bounds table Tree bounds
function M.handle_wheel(ctx, state, cfg, bounds)
  if not ImGui.IsWindowHovered(ctx) then return end

  local mx, my = ImGui.GetMousePos(ctx)
  local in_bounds = mx >= bounds.x and mx < bounds.x + bounds.w and
                    my >= bounds.y and my < bounds.y + bounds.h

  if not in_bounds then return end

  local wheel = ImGui.GetMouseWheel(ctx)
  if wheel ~= 0 then
    state.scroll_y = state.scroll_y - wheel * cfg.item_height * 3
    state.scroll_y = math.max(0, state.scroll_y)

    -- Clamp to max scroll
    local max_scroll = math.max(0, state.total_content_height - bounds.h + cfg.padding_top + cfg.padding_bottom)
    state.scroll_y = math.min(state.scroll_y, max_scroll)
  end
end

--- Clamp scroll position to valid range
--- @param state table Tree state
--- @param cfg table Configuration
--- @param bounds table Tree bounds
function M.clamp_scroll(state, cfg, bounds)
  state.scroll_y = math.max(0, state.scroll_y)
  local max_scroll = math.max(0, state.total_content_height - bounds.h + cfg.padding_top + cfg.padding_bottom)
  state.scroll_y = math.min(state.scroll_y, max_scroll)
end

-- ============================================================================
-- CONTENT HEIGHT TRACKING
-- ============================================================================

--- Update total content height after rendering (with stabilization)
--- @param state table Tree state
--- @param cfg table Configuration
--- @param start_y number Starting Y position
--- @param end_y number Ending Y position after all nodes
function M.update_content_height(state, cfg, start_y, end_y)
  local raw_height = end_y - start_y + cfg.padding_bottom

  -- Use height stabilizer to prevent scrollbar flicker
  if state.height_stabilizer then
    state.total_content_height = state.height_stabilizer:update(raw_height)
  else
    state.total_content_height = raw_height
  end
end

-- ============================================================================
-- FLAT LIST BUILDING
-- ============================================================================

--- Add node to flat list for keyboard navigation
--- @param state table Tree state
--- @param node table Node data
--- @param parent_id string|nil Parent node ID
--- @param y_pos number Node Y position
--- @param height number Node height
function M.add_to_flat_list(state, node, parent_id, y_pos, height)
  state.flat_list[#state.flat_list + 1] = {
    id = node.id,
    node = node,
    parent_id = parent_id,
    y_pos = y_pos,
    height = height,
  }
end

--- Clear flat list before rebuilding
--- @param state table Tree state
function M.clear_flat_list(state)
  state.flat_list = {}
end

--- Initialize focus if not set
--- @param state table Tree state
function M.init_focus(state)
  if not state.focused and #state.flat_list > 0 then
    state.focused = state.flat_list[1].id
  end
end

return M
