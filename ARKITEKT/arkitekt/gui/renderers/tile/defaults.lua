-- @noindex
-- Arkitekt/gui/fx/tile_fx_config.lua
-- Granular tile visual configuration
-- Theme-aware: reads from ThemeManager.get_current_rules() when available

local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

-- Static defaults (used as fallback when ThemeManager not available)
M.STATIC_DEFAULTS = {
  -- Fill layer (dark theme defaults)
  fill_opacity = 0.4,
  fill_saturation = 0.4,
  fill_brightness = 0.5,

  -- Border
  border_opacity = 1.0,
  border_saturation = 1,
  border_brightness = 1.6,
  border_thickness = 1.0,

  -- Index number (#1, #2, etc.) - region-colored
  index_saturation = 1,
  index_brightness = 1.6,

  -- Separator bullet (•) - region-colored
  separator_saturation = 1,
  separator_brightness = 1.6,
  separator_alpha = 0x99,

  -- Region name text - neutral white/gray (brightness adjusts the base neutral color)
  name_brightness = 1.0,
  name_base_color = hexrgb("#DDE3E9"),

  -- Duration/bars text - region-colored
  duration_saturation = 0.3,
  duration_brightness = 1,
  duration_alpha = 0x88,

  -- Gradient
  gradient_intensity = 0.16,
  gradient_opacity = 0.03,

  -- Specular
  specular_strength = 0.06,
  specular_coverage = 0.25,

  -- Inner shadow
  inner_shadow_strength = 0.20,

  -- Marching ants (uses border_saturation and border_brightness for color)
  ants_enabled = true,
  ants_replace_border = true,
  ants_thickness = 1,
  ants_dash = 8,
  ants_gap = 6,
  ants_speed = 20,
  ants_inset = 0,
  ants_alpha = 0xFF,

  -- Selection glow
  glow_strength = 0.4,
  glow_layers = 3,

  -- Hover
  hover_fill_boost = 0.06,
  hover_specular_boost = 0.5,

  -- Diagonal stripes (for playlists)
  stripe_enabled = true,  -- Toggle on/off
  stripe_spacing = 10,     -- Distance between stripes in pixels
  stripe_thickness = 4,    -- Line thickness
  stripe_opacity = 0.02,   -- Opacity (0.0 to 1.0)
}

-- Legacy alias
M.DEFAULT = M.STATIC_DEFAULTS

--- Get theme-aware tile config
--- Reads tile values from Theme.COLORS (set by ThemeManager.generate_palette)
--- Falls back to STATIC_DEFAULTS if Theme not available
--- @return table Tile config with theme-appropriate values
function M.get()
  -- Try to get Theme (may not be loaded yet on first frame)
  local ok, Theme = pcall(require, 'arkitekt.core.theme')
  if not ok or not Theme or not Theme.COLORS then
    return M.STATIC_DEFAULTS
  end

  -- Build config: start with static defaults, override with Theme.COLORS values
  local config = {}
  for k, v in pairs(M.STATIC_DEFAULTS) do
    config[k] = v
  end

  -- Apply theme values from Theme.COLORS (single source of truth)
  if Theme.COLORS.TILE_FILL_BRIGHTNESS then
    config.fill_brightness = Theme.COLORS.TILE_FILL_BRIGHTNESS
  end
  if Theme.COLORS.TILE_FILL_SATURATION then
    config.fill_saturation = Theme.COLORS.TILE_FILL_SATURATION
  end
  if Theme.COLORS.TILE_FILL_OPACITY then
    config.fill_opacity = Theme.COLORS.TILE_FILL_OPACITY
  end
  if Theme.COLORS.TILE_NAME_COLOR then
    config.name_base_color = Theme.COLORS.TILE_NAME_COLOR
  end

  return config
end

--- Get theme-aware config with custom overrides
--- @param overrides table Values to override from theme-aware defaults
--- @return table Merged config
function M.override(overrides)
  local base = M.get()  -- Use theme-aware values as base
  local config = {}
  for k, v in pairs(base) do
    config[k] = overrides[k] == nil and v or overrides[k]
  end
  return config
end

return M