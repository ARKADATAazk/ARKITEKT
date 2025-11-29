-- @noindex
-- panel/scrolling.lua
-- Scrollbar management and anti-jitter logic

local ImGui = require('arkitekt.platform.imgui')
local Scrollbar = require('arkitekt.gui.widgets.primitives.scrollbar')

local M = {}

-- ============================================================================
-- ANTI-JITTER LOGIC
-- ============================================================================

--- Calculate effective child width with anti-jitter (prevents content reflow when scrollbar appears)
--- @param ctx userdata ImGui context
--- @param panel table Panel instance
--- @param base_width number Base content width
--- @return number Effective width (with scrollbar space reserved if needed)
function M.get_effective_child_width(ctx, panel, base_width)
  local anti_jitter = panel.config.anti_jitter

  if not anti_jitter or not anti_jitter.enabled or not anti_jitter.track_scrollbar then
    return base_width
  end

  -- Cache scrollbar size
  if panel.scrollbar_size == 0 then
    panel.scrollbar_size = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ScrollbarSize) or 14
  end

  -- Reserve space if scrollbar was visible last frame
  if panel.had_scrollbar_last_frame then
    return base_width - panel.scrollbar_size
  end

  return base_width
end

-- ============================================================================
-- SCROLLBAR INITIALIZATION
-- ============================================================================

--- Create custom scrollbar if enabled
--- @param panel_id string Panel ID
--- @param config table Panel config
--- @return table|nil Scrollbar instance or nil
function M.create_scrollbar(panel_id, config)
  if not config.scroll or not config.scroll.custom_scrollbar then
    return nil
  end

  return Scrollbar.new({
    id = panel_id .. "_scrollbar",
    config = config.scroll.scrollbar_config,
    on_scroll = function(scroll_pos)
      -- Callback handled in panel update
    end,
  })
end

-- ============================================================================
-- SCROLLBAR UPDATE
-- ============================================================================

--- Update scrollbar state and sync with ImGui scroll
--- @param ctx userdata ImGui context
--- @param panel table Panel instance
function M.update_scrollbar(ctx, panel)
  if not panel.scrollbar or not panel._child_began_successfully then
    return
  end

  local content_height = ImGui.GetCursorPosY(ctx)
  local scroll_y = ImGui.GetScrollY(ctx)

  panel.scrollbar:set_content_height(content_height)
  panel.scrollbar:set_visible_height(panel.child_height)
  panel.scrollbar:set_scroll_pos(scroll_y)

  -- Sync scroll position if user is dragging scrollbar
  if panel.scrollbar.is_dragging then
    ImGui.SetScrollY(ctx, panel.scrollbar:get_scroll_pos())
  end
end

-- ============================================================================
-- SCROLLBAR RENDERING
-- ============================================================================

--- Draw custom scrollbar if enabled and scrollable
--- @param ctx userdata ImGui context
--- @param panel table Panel instance
function M.draw_scrollbar(ctx, panel)
  if not panel.scrollbar or not panel.scrollbar:is_scrollable() then
    return
  end

  local scrollbar_x = panel.child_x + panel.child_width - panel.config.scroll.scrollbar_config.width
  local scrollbar_y = panel.child_y

  panel.scrollbar:draw(ctx, scrollbar_x, scrollbar_y, panel.child_height)
end

-- ============================================================================
-- SCROLLBAR WIDTH CALCULATION
-- ============================================================================

--- Get scrollbar width for layout calculations
--- @param panel table Panel instance
--- @return number Scrollbar width (0 if disabled)
function M.get_scrollbar_width(panel)
  if not panel.scrollbar then
    return 0
  end
  return panel.config.scroll.scrollbar_config.width or 0
end

return M
