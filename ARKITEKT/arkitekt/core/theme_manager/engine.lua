-- @noindex
-- arkitekt/core/theme_manager/engine.lua
-- Rule computation and palette generation
--
-- Core engine that computes rule values based on theme lightness
-- and generates color palettes using the palette definition.

local Colors = require('arkitekt.core.colors')
local Style = require('arkitekt.gui.style')
local Rules = require('arkitekt.core.theme_manager.rules')
local Palette = require('arkitekt.defs.palette')

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
-- SOURCE COMPUTATION
-- =============================================================================

--- Compute derived source colors from base background
--- All derivation uses rules - no hardcoded values
--- @param base_bg number Background color in RGBA format
--- @param rules table Computed rules
--- @return table Source colors { bg, text, accent, chrome, panel }
local function compute_sources(base_bg, rules)
  local _, _, bg_lightness = Colors.rgb_to_hsl(base_bg)

  -- Text: white on dark, black on light (threshold from rules)
  local threshold = rules.text_luminance_threshold or 0.5
  local text = bg_lightness < threshold
    and Colors.hexrgb("#FFFFFFFF")
    or Colors.hexrgb("#000000FF")

  -- Accent: derived from background using rule
  local accent = Colors.adjust_lightness(base_bg, rules.accent_bright_delta)

  -- Chrome: factor + offset calculation, clamped by rules
  local chrome_l = bg_lightness * rules.chrome_lightness_factor + rules.chrome_lightness_offset
  local min_l = rules.chrome_lightness_min or 0.04
  local max_l = rules.chrome_lightness_max or 0.85
  chrome_l = math.max(min_l, math.min(max_l, chrome_l))
  local chrome = Colors.set_lightness(base_bg, chrome_l)

  -- Panel: derived from background using rule
  local panel = Colors.adjust_lightness(base_bg, rules.bg_panel_delta)

  return {
    bg = base_bg,
    text = text,
    accent = accent,
    chrome = chrome,
    panel = panel,
  }
end

-- =============================================================================
-- COLOR DERIVATION
-- =============================================================================

--- Derive a single color from the palette definition
--- @param def table Derivation definition { source, type, rule_key(s) }
--- @param sources table Source colors
--- @param rules table Computed rules
--- @return any Derived color or value
local function derive_color(def, sources, rules)
  local source_key = def[1]
  local derive_type = def[2]
  local rule_key = def[3]
  local rule_key2 = def[4]

  local source = source_key and sources[source_key]

  if derive_type == "base" then
    return source

  elseif derive_type == "lightness" then
    local delta = rules[rule_key]
    return Colors.adjust_lightness(source, delta)

  elseif derive_type == "set_light" then
    local lightness = rules[rule_key]
    return Colors.set_lightness(source, lightness)

  elseif derive_type == "opacity" then
    local opacity = type(rule_key) == "number" and rule_key or rules[rule_key]
    return Colors.with_opacity(source, opacity)

  elseif derive_type == "alpha" then
    -- Combine hex color rule with opacity rule
    local hex_color = Colors.hexrgb(rules[rule_key])
    local opacity = Colors.opacity(rules[rule_key2])
    return Colors.with_alpha(hex_color, opacity)

  elseif derive_type == "hex" then
    return Colors.hexrgb(rules[rule_key])

  elseif derive_type == "value" then
    return rules[rule_key]

  elseif derive_type == "chrome" then
    return sources.chrome
  end

  return nil
end

-- =============================================================================
-- PALETTE GENERATION
-- =============================================================================

--- Generate complete UI color palette from a single base color
--- Uses palette definition - no hardcoded palette structure here
--- @param base_bg number Background color in RGBA format
--- @param rules table|nil Optional rules override (defaults to computed rules)
--- @return table Color palette with all UI colors
function M.generate_palette(base_bg, rules)
  local _, _, bg_lightness = Colors.rgb_to_hsl(base_bg)

  -- Get rules: use provided, or compute from lightness
  rules = rules or M.compute_rules(bg_lightness, nil)

  -- Compute source colors (all rule-based)
  local sources = compute_sources(base_bg, rules)

  -- Generate palette from definition
  local palette = {}
  for key, def in pairs(Palette.definition) do
    palette[key] = derive_color(def, sources, rules)
  end

  return palette
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
