-- @noindex
-- arkitekt/exploration/color_playground.lua
-- HSL-based color exploration utilities for button preset generation
--
-- These functions are used for exploratory/demo purposes to generate
-- colored button presets from HSL values. For production use, prefer
-- the explicit DSL definitions in defs/colors/theme.lua.
--
-- Usage:
--   local ColorPlayground = require('arkitekt.exploration.color_playground')
--   local red_button = ColorPlayground.create_colored_button_preset(0.0)
--   local color_set = ColorPlayground.create_triadic_button_set(0.55)

local Colors = require('arkitekt.core.colors')

local M = {}

-- ============================================================================
-- COLORED BUTTON PRESET GENERATOR (Algorithmic Hue Variations)
-- ============================================================================
-- Generate colored button presets from HSL values for visual consistency.
-- All variants maintain the same saturation/lightness relationships,
-- differing only in hue. This ensures mathematical harmony and allows
-- buttons to adapt to theme changes.
--
-- Examples:
--   Red button:    create_colored_button_preset(0.0)      -- 0° hue
--   Green button:  create_colored_button_preset(0.33)     -- 120° hue
--   Blue button:   create_colored_button_preset(0.66)     -- 240° hue
--   Theme accent:  create_colored_button_preset(nil)      -- Uses provided fallback hue
-- ============================================================================

--- Create a colored button preset from HSL values
--- @param hue number|nil Hue (0-1): 0=red, 0.33=green, 0.66=blue, nil=use fallback_hue
--- @param saturation number|nil Saturation intensity (0-1, default: 0.65)
--- @param lightness number|nil Brightness (0-1, default: 0.48)
--- @param fallback_hue number|nil Fallback hue when hue is nil (default: 0.55 blue)
--- @return table Button preset configuration with derived colors
function M.create_colored_button_preset(hue, saturation, lightness, fallback_hue)
  -- Use fallback hue if not specified
  hue = hue or fallback_hue or 0.55

  -- Default to vibrant, balanced colors
  saturation = saturation or 0.65
  lightness = lightness or 0.48

  -- Generate base color from HSL
  local r, g, b = Colors.hsl_to_rgb(hue, saturation, lightness)
  local base_color = Colors.components_to_rgba(r, g, b, 0xFF)

  -- Derive all button states with consistent relationships
  return {
    -- Base states
    bg_color = base_color,
    bg_hover_color = Colors.adjust_lightness(base_color, 0.08),   -- +8% lighter
    bg_active_color = Colors.adjust_lightness(base_color, -0.08), -- -8% darker
    bg_disabled_color = Colors.adjust_saturation(
      Colors.adjust_lightness(base_color, -0.1),
      -0.4
    ), -- Desaturated & darker

    -- Borders (darker/lighter variations)
    border_outer_color = Colors.adjust_lightness(base_color, -0.18),  -- Much darker
    border_inner_color = Colors.adjust_lightness(base_color, 0.15),   -- Lighter highlight
    border_hover_color = Colors.adjust_lightness(base_color, 0.22),   -- Even lighter
    border_active_color = Colors.adjust_lightness(base_color, -0.12), -- Darker when pressed
    border_inner_disabled_color = Colors.adjust_lightness(base_color, -0.15),
    border_outer_disabled_color = Colors.adjust_lightness(base_color, -0.20),

    -- Text (auto white/black based on background luminance)
    text_color = Colors.auto_text_color(base_color),
    text_hover_color = Colors.auto_text_color(base_color),
    text_active_color = Colors.auto_text_color(base_color),
    text_disabled_color = Colors.adjust_lightness(Colors.auto_text_color(base_color), -0.3),

    -- Geometry
    padding_x = 10,
    padding_y = 6,
    rounding = 0,
  }
end

--- Generate a full set of colored button presets with consistent HSL
--- @param base_hue number|nil Base hue (0-1), nil defaults to 0.55 (blue)
--- @return table Table of button presets (primary, secondary, tertiary, etc.)
function M.create_colored_button_set(base_hue)
  base_hue = base_hue or 0.55  -- Default blue

  return {
    primary = M.create_colored_button_preset(base_hue, 0.70, 0.50),        -- Vibrant
    secondary = M.create_colored_button_preset(base_hue, 0.45, 0.52),      -- Muted
    tertiary = M.create_colored_button_preset(base_hue, 0.30, 0.55),       -- Very muted
    danger = M.create_colored_button_preset(0.0, 0.70, 0.55),              -- Red (fixed)
    success = M.create_colored_button_preset(0.33, 0.65, 0.50),            -- Green (fixed)
    warning = M.create_colored_button_preset(0.08, 0.80, 0.60),            -- Orange (fixed)
    info = M.create_colored_button_preset(base_hue, 0.70, 0.50),           -- Theme hue
  }
end

--- Generate analogous colored buttons (adjacent hues on color wheel)
--- @param base_hue number Base hue (0-1)
--- @param angle number|nil Hue angle offset (0-1, default: 0.083 = 30°)
--- @return table Table with main, left, right button presets
function M.create_analogous_button_set(base_hue, angle)
  angle = angle or 0.083  -- 30° default

  return {
    main = M.create_colored_button_preset(base_hue, 0.70, 0.50),
    left = M.create_colored_button_preset((base_hue - angle) % 1, 0.70, 0.50),  -- -30°
    right = M.create_colored_button_preset((base_hue + angle) % 1, 0.70, 0.50), -- +30°
  }
end

--- Generate complementary colored button (opposite hue)
--- @param base_hue number Base hue (0-1)
--- @return table Button preset for complementary color
function M.create_complementary_button(base_hue)
  return M.create_colored_button_preset((base_hue + 0.5) % 1, 0.70, 0.50)  -- +180°
end

--- Generate triadic colored buttons (120° apart on color wheel)
--- @param base_hue number Base hue (0-1)
--- @return table Array of 3 button presets
function M.create_triadic_button_set(base_hue)
  return {
    M.create_colored_button_preset(base_hue, 0.70, 0.50),
    M.create_colored_button_preset((base_hue + 0.333) % 1, 0.70, 0.50),  -- +120°
    M.create_colored_button_preset((base_hue + 0.666) % 1, 0.70, 0.50),  -- +240°
  }
end

--- Generate saturation variants of same hue (muted to vivid)
--- @param base_hue number Base hue (0-1)
--- @param base_lightness number|nil Lightness (0-1, default: 0.48)
--- @return table Table with muted, normal, vivid variants
function M.create_saturation_variants(base_hue, base_lightness)
  base_lightness = base_lightness or 0.48

  return {
    muted = M.create_colored_button_preset(base_hue, 0.30, base_lightness),   -- Low saturation
    normal = M.create_colored_button_preset(base_hue, 0.65, base_lightness),  -- Default
    vivid = M.create_colored_button_preset(base_hue, 0.85, base_lightness),   -- High saturation
  }
end

--- Generate lightness variants of same hue (dark to light)
--- @param base_hue number Base hue (0-1)
--- @param base_saturation number|nil Saturation (0-1, default: 0.65)
--- @return table Table with dark, normal, light variants
function M.create_lightness_variants(base_hue, base_saturation)
  base_saturation = base_saturation or 0.65

  return {
    dark = M.create_colored_button_preset(base_hue, base_saturation, 0.35),   -- Dark
    normal = M.create_colored_button_preset(base_hue, base_saturation, 0.48), -- Default
    light = M.create_colored_button_preset(base_hue, base_saturation, 0.62),  -- Light
  }
end

--- Generate full matrix of saturation × lightness variants
--- Creates 9 button presets covering the full range
--- @param base_hue number Base hue (0-1)
--- @return table 2D table: variants[saturation][lightness]
function M.create_button_matrix(base_hue)
  return {
    muted = {
      dark = M.create_colored_button_preset(base_hue, 0.30, 0.35),
      normal = M.create_colored_button_preset(base_hue, 0.30, 0.48),
      light = M.create_colored_button_preset(base_hue, 0.30, 0.62),
    },
    normal = {
      dark = M.create_colored_button_preset(base_hue, 0.65, 0.35),
      normal = M.create_colored_button_preset(base_hue, 0.65, 0.48),
      light = M.create_colored_button_preset(base_hue, 0.65, 0.62),
    },
    vivid = {
      dark = M.create_colored_button_preset(base_hue, 0.85, 0.35),
      normal = M.create_colored_button_preset(base_hue, 0.85, 0.48),
      light = M.create_colored_button_preset(base_hue, 0.85, 0.62),
    },
  }
end

--- Generate monochromatic palette (same hue, varying saturation/lightness)
--- Creates a harmonious set of buttons from a single hue
--- @param base_hue number Base hue (0-1)
--- @return table Named preset variants
function M.create_monochromatic_set(base_hue)
  return {
    primary = M.create_colored_button_preset(base_hue, 0.70, 0.50),      -- Vibrant
    secondary = M.create_colored_button_preset(base_hue, 0.45, 0.52),    -- Muted
    subtle = M.create_colored_button_preset(base_hue, 0.25, 0.58),       -- Very muted, lighter
    bold = M.create_colored_button_preset(base_hue, 0.85, 0.42),         -- Very vivid, darker
    accent = M.create_colored_button_preset(base_hue, 0.75, 0.60),       -- Bright accent
  }
end

-- ============================================================================
-- PRE-GENERATED SEMANTIC PRESETS
-- ============================================================================
-- These use fixed hues for consistent meaning (red=danger, green=success, etc.)
-- Useful for quick demo/exploration without DSL setup.

M.PRESETS = {
  BUTTON_DANGER = M.create_colored_button_preset(0.0, 0.68, 0.55),     -- Red
  BUTTON_SUCCESS = M.create_colored_button_preset(0.33, 0.60, 0.50),   -- Green
  BUTTON_WARNING = M.create_colored_button_preset(0.08, 0.78, 0.62),   -- Orange
  BUTTON_INFO = M.create_colored_button_preset(0.55, 0.68, 0.52),      -- Blue
  BUTTON_PRIMARY = M.create_colored_button_preset(0.55, 0.70, 0.50),   -- Blue (default)
}

return M
