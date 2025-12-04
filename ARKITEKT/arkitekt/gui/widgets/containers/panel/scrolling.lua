-- @noindex
-- panel/scrolling.lua
-- Scrollbar anti-jitter logic for native ImGui scrollbars

local ImGui = require('arkitekt.core.imgui')

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
-- SCROLLBAR STUBS (custom scrollbar removed - use native ImGui)
-- ============================================================================

--- Stub: Custom scrollbar creation disabled
function M.create_scrollbar(panel_id, config)
  return nil
end

--- Stub: No-op for custom scrollbar update
function M.update_scrollbar(ctx, panel)
end

--- Stub: No-op for custom scrollbar draw
function M.draw_scrollbar(ctx, panel)
end

--- Stub: Returns 0 (native scrollbar width handled by ImGui)
function M.get_scrollbar_width(panel)
  return 0
end

return M
