-- @noindex
-- arkitekt/core/theme_manager/engine.lua
-- Rule computation and palette generation
--
-- Core engine that computes rule values based on theme lightness
-- and generates complete UI color palettes from base colors.

local Colors = require('arkitekt.core.colors')
local Style = require('arkitekt.gui.style')
local Rules = require('arkitekt.core.theme_manager.rules')

local M = {}

-- =============================================================================
-- RULE COMPUTATION
-- =============================================================================

--- Compute interpolation factor 't' from lightness
--- @param lightness number Background lightness (0.0-1.0)
--- @return number t value (0.0 at dark anchor, 1.0 at light anchor)
function M.compute_t(lightness)
  local range = Rules.anchors.light - Rules.anchors.dark
  if range <= 0 then return 0 end
  local t = (lightness - Rules.anchors.dark) / range
  return math.max(0, math.min(1, t))
end

--- Compute a single rule value based on wrapper type and current t
--- @param rule table Wrapped rule from Rules.definitions
--- @param t number Interpolation factor (0.0-1.0)
--- @return any Computed value
function M.compute_rule_value(rule, t)
  if type(rule) ~= "table" or not rule.mode then
    return rule  -- Raw value (not wrapped), return as-is
  end

  local mode = rule.mode
  local dark_val = rule.dark
  local light_val = rule.light
  local threshold = rule.threshold or 0.5

  if mode == "offset" or mode == "snap" then
    -- Discrete switch at threshold
    return t < threshold and dark_val or light_val

  elseif mode == "lerp" then
    -- Smooth interpolation
    if type(dark_val) == "number" and type(light_val) == "number" then
      return dark_val + (light_val - dark_val) * t

    elseif type(dark_val) == "string" and type(light_val) == "string" then
      -- RGB color lerp for hex strings
      local color_a = Colors.hexrgb(dark_val .. (#dark_val == 7 and "FF" or ""))
      local color_b = Colors.hexrgb(light_val .. (#light_val == 7 and "FF" or ""))
      local lerped = Colors.lerp(color_a, color_b, t)
      local r, g, b = Colors.rgba_to_components(lerped)
      return string.format("#%02X%02X%02X", r, g, b)

    else
      -- Non-interpolatable, snap at midpoint
      return t < 0.5 and dark_val or light_val
    end
  end

  return dark_val
end

--- Compute all rules for a given lightness value
--- @param lightness number Background lightness (0.0-1.0)
--- @param mode string|nil Theme mode ("dark", "light", "adapt", or nil)
--- @return table Computed rules (raw values ready for use)
function M.compute_rules(lightness, mode)
  local t

  -- Determine t based on mode
  if mode == "dark" then
    t = 0  -- Force dark values
  elseif mode == "light" then
    t = 1  -- Force light values
  else
    -- "adapt" mode or nil: compute t from actual lightness
    t = M.compute_t(lightness)
  end

  -- Compute each rule value
  local result = {}
  for key, rule in pairs(Rules.definitions) do
    result[key] = M.compute_rule_value(rule, t)
  end

  return result
end

-- =============================================================================
-- PALETTE GENERATION
-- =============================================================================

--- Generate complete UI color palette from a single base color
--- Text color and accent are automatically derived from background
--- @param base_bg number Background color in RGBA format
--- @param rules table|nil Optional rules override (defaults to computed rules)
--- @return table Color palette with all UI colors
function M.generate_palette(base_bg, rules)
  local _, _, bg_lightness = Colors.rgb_to_hsl(base_bg)

  -- Get rules: use provided, or compute from lightness
  rules = rules or M.compute_rules(bg_lightness, nil)

  -- Derive text color from background (white on dark, black on light)
  local base_text = Colors.auto_text_color(base_bg)

  -- Calculate chrome color (titlebar/statusbar)
  local chrome_lightness = bg_lightness * rules.chrome_lightness_factor + rules.chrome_lightness_offset
  chrome_lightness = math.max(0.04, math.min(0.85, chrome_lightness))
  local base_chrome = Colors.set_lightness(base_bg, chrome_lightness)

  -- Derive accent from background
  local accent = Colors.adjust_lightness(base_bg, rules.accent_bright_delta)

  -- Pre-compute BG_PANEL for pattern derivation
  local bg_panel = Colors.adjust_lightness(base_bg, rules.bg_panel_delta)

  -- Build BORDER_OUTER from rules
  local border_outer = Colors.with_alpha(
    Colors.hexrgb(rules.border_outer_color),
    Colors.opacity(rules.border_outer_opacity)
  )

  return {
    -- ============ BACKGROUNDS ============
    BG_BASE = base_bg,
    BG_HOVER = Colors.adjust_lightness(base_bg, rules.bg_hover_delta),
    BG_ACTIVE = Colors.adjust_lightness(base_bg, rules.bg_active_delta),
    BG_HEADER = Colors.adjust_lightness(base_bg, rules.bg_header_delta),
    BG_PANEL = bg_panel,
    BG_CHROME = base_chrome,
    BG_TRANSPARENT = Colors.with_alpha(base_bg, 0x00),

    -- ============ BORDERS ============
    BORDER_OUTER = border_outer,
    BORDER_INNER = Colors.adjust_lightness(base_bg, rules.border_inner_delta),
    BORDER_HOVER = Colors.adjust_lightness(base_bg, rules.border_hover_delta),
    BORDER_ACTIVE = Colors.adjust_lightness(base_bg, rules.border_active_delta),
    BORDER_FOCUS = Colors.adjust_lightness(base_bg, rules.border_focus_delta),

    -- ============ TEXT ============
    TEXT_NORMAL = base_text,
    TEXT_HOVER = Colors.adjust_lightness(base_text, rules.text_hover_delta),
    TEXT_ACTIVE = Colors.adjust_lightness(base_text, rules.text_hover_delta),
    TEXT_DIMMED = Colors.adjust_lightness(base_text, rules.text_dimmed_delta),
    TEXT_DARK = Colors.adjust_lightness(base_text, rules.text_dark_delta),
    TEXT_BRIGHT = Colors.adjust_lightness(base_text, rules.text_bright_delta),

    -- ============ ACCENTS ============
    ACCENT_PRIMARY = accent,
    ACCENT_TEAL = accent,
    ACCENT_TEAL_BRIGHT = Colors.adjust_lightness(accent, rules.accent_bright_delta),
    ACCENT_WHITE = Colors.set_lightness(base_bg, rules.accent_white_lightness),
    ACCENT_WHITE_BRIGHT = Colors.set_lightness(base_bg, rules.accent_white_bright_lightness),
    ACCENT_TRANSPARENT = Colors.with_opacity(accent, 0.67),
    ACCENT_SUCCESS = Colors.hexrgb(rules.status_success),
    ACCENT_WARNING = Colors.hexrgb(rules.status_warning),
    ACCENT_DANGER = Colors.hexrgb(rules.status_danger),

    -- ============ PATTERNS ============
    PATTERN_PRIMARY = Colors.adjust_lightness(bg_panel, rules.pattern_primary_delta),
    PATTERN_SECONDARY = Colors.adjust_lightness(bg_panel, rules.pattern_secondary_delta),

    -- ============ TILES ============
    TILE_FILL_BRIGHTNESS = rules.tile_fill_brightness,
    TILE_FILL_SATURATION = rules.tile_fill_saturation,
    TILE_FILL_OPACITY = rules.tile_fill_opacity,
    TILE_NAME_COLOR = Colors.hexrgb(rules.tile_name_color),

    -- ============ BADGES ============
    BADGE_BG = Colors.with_alpha(
      Colors.hexrgb(rules.badge_bg_color),
      Colors.opacity(rules.badge_bg_opacity)
    ),
    BADGE_TEXT = Colors.hexrgb(rules.badge_text_color),
    BADGE_BORDER_OPACITY = rules.badge_border_opacity,

    -- ============ PLAYLIST TILES ============
    PLAYLIST_TILE_COLOR = Colors.hexrgb(rules.playlist_tile_color),
    PLAYLIST_NAME_COLOR = Colors.hexrgb(rules.playlist_name_color),
    PLAYLIST_BADGE_COLOR = Colors.hexrgb(rules.playlist_badge_color),
  }
end

--- Apply a color palette to Style.COLORS
--- @param palette table Color palette from generate_palette()
function M.apply_palette(palette)
  for key, value in pairs(palette) do
    Style.COLORS[key] = value
  end
end

--- Generate palette from base color and apply to Style.COLORS
--- @param base_bg number Background color
function M.generate_and_apply(base_bg)
  local palette = M.generate_palette(base_bg)
  M.apply_palette(palette)
end

--- Get current color values (for transitions)
--- @return table Copy of current Style.COLORS
function M.get_current_colors()
  local current = {}
  for key, value in pairs(Style.COLORS) do
    current[key] = value
  end
  return current
end

return M
