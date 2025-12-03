-- @noindex
-- ItemPicker/defs/palette.lua
-- Theme-reactive color palette for ItemPicker
--
-- Uses the Theme script palette registry DSL:
--   snap2(dark, light)  - Hard switch at theme boundary
--   lerp2(dark, light)  - Smooth interpolation
--   offset2(dark, light) - Relative to BG_BASE
--
-- Register this palette once at startup, then access via:
--   local palette = Theme.get_script_palette('ItemPicker')
--   local color = palette.favorite_star

local Theme = require('arkitekt.theme')

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
  favorite_star = Theme.snap2(0xFFE87CFF, 0xE5C84AFF),

  -- Rename input field colors
  rename_input_bg = Theme.snap2(0x1A1A1AFF, 0xF0F0F0FF),
  rename_input_text = Theme.snap2(0xFFFFFFFF, 0x1A1A1AFF),

  -- Badge text color (cycle badge N/M) - note: use 6-char hex, alpha handled separately
  badge_text = Theme.snap2(0xFFFFFFFF, 0x000000FF),

  -- Pool badge text - note: use 6-char hex, alpha handled separately
  pool_badge_text = Theme.snap2(0xFFFFFFFF, 0x000000FF),

  -- Region chip default color (when region has no color)
  region_chip_default = Theme.snap2(0x4A5A6AFF, 0x8A9AAAFF),

  -- Default tile color (when item has no color)
  default_tile_color = Theme.snap2(0x555555FF, 0xAAAAAAFF),

  -- Placeholder spinner color
  placeholder_spinner = Theme.snap2(0x808080FF, 0x606060FF),

  -- Loading indicator
  loading_indicator = Theme.snap2(0x4A9EFFFF, 0x2A7EDFFF),

  -- Muted text color (red)
  muted_text = Theme.snap2(0x22CCCCFF, 0xDD3333FF),

  -- Drag handler default color (teal)
  drag_handle = Theme.snap2(0x42E896FF, 0x32D886FF),

  -- =========================================================================
  -- LIGHTNESS/SATURATION OFFSETS (applied to dynamic tile colors)
  -- =========================================================================
  -- NORMALIZED SCALE: 0.0 = off, 0.5 = neutral/unchanged, 1.0 = maximum
  -- The theme engine auto-transforms keys ending in _brightness/_saturation

  -- Tile base fill adjustments
  tile_saturation = Theme.snap2(0.45, 0.42),       -- Base saturation (0.5 = unchanged)
  tile_brightness = Theme.snap2(0.30, 0.75),       -- Base brightness (0.5 = unchanged)
  tile_compact_saturation = Theme.snap2(0.35, 0.30), -- Compact mode saturation
  tile_compact_brightness = Theme.snap2(0.20, 0.95), -- Compact mode brightness

  -- Header overlay adjustments
  header_saturation = Theme.snap2(0.35, 0.30),     -- Header saturation
  header_brightness = Theme.snap2(0.50, 0.45),     -- Header brightness (0.5 = unchanged)

  -- Marching ants selection border
  ants_saturation = Theme.snap2(0.50, 0.40),       -- Selection border saturation
  ants_brightness = Theme.snap2(1.0, 0.0),         -- Selection border brightness (1.0 = max boost)

  -- Hover brightness boost
  hover_brightness = Theme.snap2(0.75, 0.65),      -- How much brighter on hover

  -- Waveform/MIDI visualization (dark lines on tile)
  viz_saturation = Theme.snap2(0.15, 0.0),         -- Visualization saturation (low = desaturated)
  viz_brightness = Theme.snap2(0.05, 1.0),         -- Visualization brightness (dark→light)

  -- =========================================================================
  -- SECONDARY UI COLORS
  -- =========================================================================

  -- Panel backgrounds
  panel_bg = Theme.snap2(0x1A1A1AFF, 0xF5F5F5FF),
  panel_bg_alt = Theme.snap2(0x2A2A2AFF, 0xE8E8E8FF),
  panel_bg_hover = Theme.snap2(0x3A3A3AFF, 0xDDDDDDFF),
  panel_border = Theme.snap2(0x404040FF, 0xC0C0C0FF),

  -- Scrim/overlay
  scrim = Theme.snap2(0x000000FF, 0x000000FF),

  -- Text colors
  text_primary = Theme.snap2(0xFFFFFFFF, 0x1A1A1AFF),
  text_secondary = Theme.snap2(0xAAAAAAFF, 0x666666FF),
  text_dimmed = Theme.snap2(0x888888FF, 0x999999FF),
  text_label = Theme.snap2(0x888888FF, 0x777777FF),

  -- Accent colors
  accent_primary = Theme.snap2(0x4A9EFFFF, 0x2A7EDFFF),
  accent_primary_hover = Theme.snap2(0x5AAFFFFF, 0x3A8EEFFF),
  accent_teal = Theme.snap2(0x42E896FF, 0x32D886FF),
  accent_teal_dark = Theme.snap2(0x008B8BFF, 0x006B6BFF),

  -- Track filter indicator
  filter_indicator = Theme.snap2(0x42E896FF, 0x32D886FF),

  -- Slider colors
  slider_track = Theme.snap2(0x1A1A1AFF, 0xE0E0E0FF),
  slider_fill = Theme.snap2(0x4A9EFFFF, 0x2A7EDFFF),
  slider_thumb = Theme.snap2(0x4A9EFFFF, 0x2A7EDFFF),
  slider_thumb_hover = Theme.snap2(0x5AAFFFFF, 0x3A8EEFFF),

  -- Sort label
  sort_label = Theme.snap2(0xAAAAAAFF, 0x666666FF),

  -- Drag preview
  drag_shadow = Theme.snap2(0x000000FF, 0x000000FF),
  drag_header = Theme.snap2(0x000000FF, 0xFFFFFFFF),
  drag_text = Theme.snap2(0xFFFFFFFF, 0x1A1A1AFF),
  drag_badge_bg = Theme.snap2(0x1A1A1AFF, 0xE8E8E8FF),
  drag_badge_border = Theme.snap2(0xFFFFFFFF, 0x888888FF),
  drag_pool_bg = Theme.snap2(0x008B8BFF, 0x20B2AAFF),
  drag_pool_border = Theme.snap2(0x20B2AAFF, 0x40D0D0FF),
  drag_fallback = Theme.snap2(0x555B5BFF, 0xAAAAAAFF),

  -- Tooltip
  tooltip_bg = Theme.snap2(0x1A1A1AFF, 0xF5F5F5FF),
  tooltip_border = Theme.snap2(0x505050FF, 0xC0C0C0FF),
  tooltip_text = Theme.snap2(0xCCCCCCFF, 0x444444FF),

  -- Arrow/chevron
  arrow = Theme.snap2(0x888888FF, 0x666666FF),

  -- Loading strip pattern
  loading_strip = Theme.snap2(0x3A3A3AFF, 0xD0D0D0FF),

  -- Waveform zero line (debug/viz)
  viz_zero_line = Theme.snap2(0xFFFFFFFF, 0x000000FF),
}

-- =============================================================================
-- REGISTRATION
-- =============================================================================

--- Register the ItemPicker palette with the theme system
--- Call this once during app initialization
function M.register()
  Theme.register_script_palette('ItemPicker', M.definition)
end

--- Unregister the palette (for cleanup)
function M.unregister()
  Theme.unregister_script_palette('ItemPicker')
end

--- Get the computed palette for the current theme
--- @return table Computed palette with resolved colors
function M.get()
  local t = Theme.get_t and Theme.get_t() or 0
  return Theme.get_script_palette and Theme.get_script_palette('ItemPicker', t) or {}
end

return M
