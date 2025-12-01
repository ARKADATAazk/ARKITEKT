-- @noindex
-- ItemPicker/defs/palette.lua
-- Theme-reactive color palette for ItemPicker
--
-- Uses the Theme script palette registry DSL:
--   snap(dark, light)  - Hard switch at theme boundary
--   lerp(dark, light)  - Smooth interpolation
--   offset(dark, light) - Relative to BG_BASE
--
-- Register this palette once at startup, then access via:
--   local palette = Theme.get_script_palette("ItemPicker")
--   local color = palette.favorite_star

local Theme = require('arkitekt.core.theme')

local M = {}

-- =============================================================================
-- PALETTE DEFINITION
-- =============================================================================
-- All colors ItemPicker uses, centralized for theme reactivity

M.definition = {
  -- =========================================================================
  -- COLORS
  -- =========================================================================

  -- Favorite star color (yellow/gold)
  favorite_star = Theme.snap("#FFE87C", "#E5C84A"),

  -- Rename input field colors
  rename_input_bg = Theme.snap("#1A1A1A", "#F0F0F0"),
  rename_input_text = Theme.snap("#FFFFFF", "#1A1A1A"),

  -- Badge text color (cycle badge N/M) - note: use 6-char hex, alpha handled separately
  badge_text = Theme.snap("#FFFFFF", "#000000"),

  -- Pool badge text - note: use 6-char hex, alpha handled separately
  pool_badge_text = Theme.snap("#FFFFFF", "#000000"),

  -- Region chip default color (when region has no color)
  region_chip_default = Theme.snap("#4A5A6A", "#8A9AAA"),

  -- Default tile color (when item has no color)
  default_tile_color = Theme.snap("#555555", "#AAAAAA"),

  -- Placeholder spinner color
  placeholder_spinner = Theme.snap("#808080", "#606060"),

  -- Loading indicator
  loading_indicator = Theme.snap("#4A9EFF", "#2A7EDF"),

  -- Muted text color (red)
  muted_text = Theme.snap("#22cccc", "#DD3333"),

  -- Drag handler default color (teal)
  drag_handle = Theme.snap("#42E896", "#32D886"),

  -- =========================================================================
  -- LIGHTNESS/SATURATION OFFSETS (applied to dynamic tile colors)
  -- =========================================================================
  -- NORMALIZED SCALE: 0.0 = off, 0.5 = neutral/unchanged, 1.0 = maximum
  -- The theme engine auto-transforms keys ending in _brightness/_saturation

  -- Tile base fill adjustments
  tile_saturation = Theme.snap(0.45, 0.42),       -- Base saturation (0.5 = unchanged)
  tile_brightness = Theme.snap(0.30, 0.75),       -- Base brightness (0.5 = unchanged)
  tile_compact_saturation = Theme.snap(0.35, 0.30), -- Compact mode saturation
  tile_compact_brightness = Theme.snap(0.20, 0.95), -- Compact mode brightness

  -- Header overlay adjustments
  header_saturation = Theme.snap(0.35, 0.30),     -- Header saturation
  header_brightness = Theme.snap(0.50, 0.45),     -- Header brightness (0.5 = unchanged)

  -- Marching ants selection border
  ants_saturation = Theme.snap(0.50, 0.40),       -- Selection border saturation
  ants_brightness = Theme.snap(1.0, 0.0),         -- Selection border brightness (1.0 = max boost)

  -- Hover brightness boost
  hover_brightness = Theme.snap(0.75, 0.65),      -- How much brighter on hover

  -- Waveform/MIDI visualization (dark lines on tile)
  viz_saturation = Theme.snap(0.15, 0.0),         -- Visualization saturation (low = desaturated)
  viz_brightness = Theme.snap(0.05, 1.0),         -- Visualization brightness (dark→light)

  -- =========================================================================
  -- SECONDARY UI COLORS
  -- =========================================================================

  -- Panel backgrounds
  panel_bg = Theme.snap("#1A1A1A", "#F5F5F5"),
  panel_bg_alt = Theme.snap("#2A2A2A", "#E8E8E8"),
  panel_bg_hover = Theme.snap("#3A3A3A", "#DDDDDD"),
  panel_border = Theme.snap("#404040", "#C0C0C0"),

  -- Scrim/overlay
  scrim = Theme.snap("#000000", "#000000"),

  -- Text colors
  text_primary = Theme.snap("#FFFFFF", "#1A1A1A"),
  text_secondary = Theme.snap("#AAAAAA", "#666666"),
  text_dimmed = Theme.snap("#888888", "#999999"),
  text_label = Theme.snap("#888888", "#777777"),

  -- Accent colors
  accent_primary = Theme.snap("#4A9EFF", "#2A7EDF"),
  accent_primary_hover = Theme.snap("#5AAFFF", "#3A8EEF"),
  accent_teal = Theme.snap("#42E896", "#32D886"),
  accent_teal_dark = Theme.snap("#008B8B", "#006B6B"),

  -- Track filter indicator
  filter_indicator = Theme.snap("#42E896", "#32D886"),

  -- Slider colors
  slider_track = Theme.snap("#1A1A1A", "#E0E0E0"),
  slider_fill = Theme.snap("#4A9EFF", "#2A7EDF"),
  slider_thumb = Theme.snap("#4A9EFF", "#2A7EDF"),
  slider_thumb_hover = Theme.snap("#5AAFFF", "#3A8EEF"),

  -- Sort label
  sort_label = Theme.snap("#AAAAAA", "#666666"),

  -- Drag preview
  drag_shadow = Theme.snap("#000000", "#000000"),
  drag_header = Theme.snap("#000000", "#FFFFFF"),
  drag_text = Theme.snap("#FFFFFF", "#1A1A1A"),
  drag_badge_bg = Theme.snap("#1A1A1A", "#E8E8E8"),
  drag_badge_border = Theme.snap("#FFFFFF", "#888888"),
  drag_pool_bg = Theme.snap("#008B8B", "#20B2AA"),
  drag_pool_border = Theme.snap("#20B2AA", "#40D0D0"),
  drag_fallback = Theme.snap("#555B5B", "#AAAAAA"),

  -- Tooltip
  tooltip_bg = Theme.snap("#1A1A1A", "#F5F5F5"),
  tooltip_border = Theme.snap("#505050", "#C0C0C0"),
  tooltip_text = Theme.snap("#CCCCCC", "#444444"),

  -- Arrow/chevron
  arrow = Theme.snap("#888888", "#666666"),

  -- Loading strip pattern
  loading_strip = Theme.snap("#3A3A3A", "#D0D0D0"),

  -- Waveform zero line (debug/viz)
  viz_zero_line = Theme.snap("#FFFFFF", "#000000"),
}

-- =============================================================================
-- REGISTRATION
-- =============================================================================

--- Register the ItemPicker palette with the theme system
--- Call this once during app initialization
function M.register()
  Theme.register_script_palette("ItemPicker", M.definition)
end

--- Unregister the palette (for cleanup)
function M.unregister()
  Theme.unregister_script_palette("ItemPicker")
end

--- Get the computed palette for the current theme
--- @return table Computed palette with resolved colors
function M.get()
  local t = Theme.get_t and Theme.get_t() or 0
  return Theme.get_script_palette and Theme.get_script_palette("ItemPicker", t) or {}
end

return M
