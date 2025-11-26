-- @noindex
-- arkitekt/core/theme_manager/rules.lua
-- Theme rule DSL and definitions
--
-- Provides wrapper functions for defining theme-reactive values and
-- contains all rule definitions as single source of truth.

local M = {}

-- =============================================================================
-- VALUE WRAPPERS (DSL for rule definitions)
-- =============================================================================
-- Each wrapper defines HOW a rule adapts to theme lightness.
-- The interpolation factor 't' is computed from current lightness:
--   t = (lightness - 0.14) / (0.88 - 0.14)
--   t=0.0 at dark anchor (14%), t=1.0 at light anchor (88%)

--- Snap between delta values (semantic alias for snap, used for numeric offsets)
--- Single arg: constant delta regardless of theme
--- Two args: snap between deltas at t=0.5
--- Three args: snap between deltas at custom threshold
--- @param dark_delta number Delta for dark themes (or constant if only arg)
--- @param light_delta number|nil Delta for light themes (optional)
--- @param threshold number|nil Snap threshold in t-space (default 0.5)
--- @return table Wrapper with mode metadata
function M.offsetFromBase(dark_delta, light_delta, threshold)
  if light_delta == nil then
    return { mode = "offset", dark = dark_delta, light = dark_delta, threshold = 0.5 }
  end
  return { mode = "offset", dark = dark_delta, light = light_delta, threshold = threshold or 0.5 }
end

--- Smooth interpolation between dark and light values
--- Works with numbers (linear lerp) and hex colors (RGB lerp)
--- @param dark_val any Value for dark themes
--- @param light_val any Value for light themes
--- @return table Wrapper with mode metadata
function M.lerpDarkLight(dark_val, light_val)
  return { mode = "lerp", dark = dark_val, light = light_val }
end

--- Snap between values at midpoint (t=0.5)
--- @param dark_val any Value for dark themes
--- @param light_val any Value for light themes
--- @return table Wrapper with mode metadata
function M.snapAtMidpoint(dark_val, light_val)
  return { mode = "offset", dark = dark_val, light = light_val, threshold = 0.5 }
end

--- Snap between values at custom threshold
--- @param threshold number Threshold in t-space (0.0-1.0)
--- @param dark_val any Value for dark themes (t < threshold)
--- @param light_val any Value for light themes (t >= threshold)
--- @return table Wrapper with mode metadata
function M.snapAt(threshold, dark_val, light_val)
  return { mode = "offset", dark = dark_val, light = light_val, threshold = threshold }
end

-- =============================================================================
-- PRESET ANCHORS
-- =============================================================================
-- Lightness values defining the dark<->light interpolation range.

M.anchors = {
  dark = 0.14,   -- ~14% lightness (t=0.0)
  light = 0.88,  -- ~88% lightness (t=1.0)
}

-- =============================================================================
-- RULE DEFINITIONS (Single Source of Truth)
-- =============================================================================
-- All rules defined once. Each wrapper specifies behavior across dark<->light.

local W = M  -- Alias for brevity

M.definitions = {
  -- ========== REAPER SYNC ==========
  -- Lightness offset when syncing from REAPER theme (subtle visual separation)
  reaper_sync_offset = W.offsetFromBase(-0.012),

  -- ========== TEXT DERIVATION ==========
  -- Threshold for auto text color (below = white text, above = black text)
  text_luminance_threshold = W.lerpDarkLight(0.5, 0.5),  -- Could vary by theme if needed

  -- ========== BACKGROUND OFFSETS ==========
  bg_hover_delta = W.offsetFromBase(0.03, -0.04),
  bg_active_delta = W.offsetFromBase(0.05, -0.07),
  bg_header_delta = W.offsetFromBase(-0.024, -0.06),
  bg_panel_delta = W.offsetFromBase(-0.04),

  -- ========== CHROME (titlebar/statusbar) ==========
  chrome_lightness_factor = W.lerpDarkLight(0.42, 1.0),
  chrome_lightness_offset = W.lerpDarkLight(0, -0.15),
  chrome_lightness_min = W.lerpDarkLight(0.04, 0.04),
  chrome_lightness_max = W.lerpDarkLight(0.85, 0.85),

  -- ========== PATTERN OFFSETS ==========
  pattern_primary_delta = W.offsetFromBase(-0.024, -0.06),
  pattern_secondary_delta = W.offsetFromBase(-0.004, -0.02),

  -- ========== BORDER COLORS ==========
  border_outer_color = W.snapAtMidpoint("#000000", "#404040"),
  border_outer_opacity = W.lerpDarkLight(0.87, 0.60),
  border_inner_delta = W.offsetFromBase(0.05, -0.03),
  border_hover_delta = W.offsetFromBase(0.10, -0.08),
  border_active_delta = W.offsetFromBase(0.15, -0.12),
  border_focus_delta = W.offsetFromBase(0.20, -0.15),

  -- ========== TEXT OFFSETS ==========
  text_hover_delta = W.offsetFromBase(0.05, -0.05),
  text_dimmed_delta = W.offsetFromBase(-0.10, 0.15),
  text_dark_delta = W.offsetFromBase(-0.20, 0.25),
  text_bright_delta = W.offsetFromBase(0.10, -0.08),

  -- ========== ACCENT VALUES ==========
  accent_bright_delta = W.offsetFromBase(0.15, -0.12),
  accent_white_lightness = W.lerpDarkLight(0.25, 0.55),
  accent_white_bright_lightness = W.lerpDarkLight(0.35, 0.45),

  -- ========== SEMANTIC STATUS COLORS ==========
  status_success = W.lerpDarkLight("#4CAF50", "#2E7D32"),
  status_warning = W.lerpDarkLight("#FFA726", "#F57C00"),
  status_danger = W.lerpDarkLight("#EF5350", "#C62828"),

  -- ========== TILE RENDERING ==========
  tile_fill_brightness = W.lerpDarkLight(0.5, 1.4),
  tile_fill_saturation = W.lerpDarkLight(0.4, 0.5),
  tile_fill_opacity = W.lerpDarkLight(0.4, 0.5),
  tile_name_color = W.snapAtMidpoint("#DDE3E9", "#1A1A1A"),

  -- ========== BADGES ==========
  badge_bg_color = W.snapAtMidpoint("#14181C", "#E8ECF0"),
  badge_bg_opacity = W.lerpDarkLight(0.85, 0.90),
  badge_text_color = W.snapAtMidpoint("#FFFFFF", "#1A1A1A"),
  badge_border_opacity = W.lerpDarkLight(0.20, 0.15),

  -- ========== PLAYLIST TILES ==========
  playlist_tile_color = W.snapAtMidpoint("#3A3A3A", "#D0D0D0"),
  playlist_name_color = W.snapAtMidpoint("#CCCCCC", "#2A2A2A"),
  playlist_badge_color = W.snapAtMidpoint("#999999", "#666666"),
}

return M
