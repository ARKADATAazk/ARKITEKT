-- @noindex
-- Arkitekt/core/theme_manager/init.lua
-- Dynamic theme system with algorithmic color palette generation
--
-- Generates entire UI color palettes from 1-3 base colors using HSL manipulation.
-- Supports REAPER theme auto-sync and manual theme presets.
--
-- ============================================================================
-- PRIMARY API (4 theme modes)
-- ============================================================================
--
--   local ThemeManager = require('arkitekt.core.theme_manager')
--
--   ThemeManager.set_dark()   -- Dark preset (~14% lightness)
--   ThemeManager.set_grey()   -- Grey preset (~24% lightness)
--   ThemeManager.set_light()  -- Light preset (~88% lightness)
--   ThemeManager.adapt()      -- Sync with REAPER's current theme
--
--   -- Or use set_mode() for UI selectors:
--   ThemeManager.set_mode("dark")   -- "dark", "grey", "light", or "adapt"
--
-- ============================================================================
-- RULE WRAPPERS (Unified Single-Definition System)
-- ============================================================================
--
-- Each rule is defined ONCE with a wrapper that describes its behavior:
--
--   offsetFromBase(delta)           - Fixed delta from BG_BASE (same both themes)
--   offsetFromBase(dark, light)     - Different deltas, SNAP at t=0.5
--   offsetFromBase(dark, light, t)  - Different deltas, SNAP at custom threshold
--
--   lerpDarkLight(dark, light)      - Smooth interpolation between values
--                                     (auto-detects numbers vs hex colors)
--
--   snapAtMidpoint(dark, light)     - Discrete snap at t=0.5
--   snapAt(threshold, dark, light)  - Discrete snap at custom threshold
--
-- The interpolation factor 't' is computed from current lightness:
--   t = (lightness - 0.14) / (0.88 - 0.14)
--   t=0.0 at dark anchor (14%), t=1.0 at light anchor (88%)
--
-- ============================================================================
-- ADVANCED API
-- ============================================================================
--
--   -- Apply named preset
--   ThemeManager.apply_theme("dark")
--
--   -- Generate from custom colors
--   ThemeManager.generate_and_apply(base_bg, base_text, base_accent)
--
--   -- Animated transitions
--   ThemeManager.transition_to_theme("light", 0.3)
--
--   -- Live REAPER sync (monitors theme changes)
--   local sync = ThemeManager.create_live_sync(1.0)
--   function main_loop() sync(); draw_ui() end

local Colors = require('arkitekt.core.colors')
local Style = require('arkitekt.gui.style')

local M = {}

-- Forward declaration for script rules cache (used by apply_palette)
local script_rules_cache = {}
local function clear_script_rules_cache()
  script_rules_cache = {}
end

-- ============================================================================
-- VALUE WRAPPERS - Unified Single-Definition System
-- ============================================================================
-- Each wrapper defines HOW a rule adapts to theme lightness.
-- All rules are defined once (not in separate dark/light presets).

--- Offset from BG_BASE color
--- Single arg: constant delta regardless of theme
--- Two args: SNAP between deltas at t=0.5 (no lerp - base already adapts)
--- Three args: SNAP between deltas at custom threshold
--- @param dark_delta number Delta for dark themes (or constant if only arg)
--- @param light_delta number|nil Delta for light themes (optional)
--- @param threshold number|nil Snap threshold in t-space (default 0.5)
--- @return table Wrapper with mode metadata
local function offsetFromBase(dark_delta, light_delta, threshold)
  if light_delta == nil then
    -- Single value: constant delta
    return { mode = "offset", dark = dark_delta, light = dark_delta, threshold = 0.5 }
  else
    -- Two values: snap between them
    return { mode = "offset", dark = dark_delta, light = light_delta, threshold = threshold or 0.5 }
  end
end

--- Smooth interpolation between dark and light values
--- Works with numbers (linear lerp) and hex colors (RGB lerp)
--- @param dark_val any Value for dark themes
--- @param light_val any Value for light themes
--- @return table Wrapper with mode metadata
local function lerpDarkLight(dark_val, light_val)
  return { mode = "lerp", dark = dark_val, light = light_val }
end

--- Snap between values at midpoint (t=0.5)
--- @param dark_val any Value for dark themes
--- @param light_val any Value for light themes
--- @return table Wrapper with mode metadata
local function snapAtMidpoint(dark_val, light_val)
  return { mode = "snap", dark = dark_val, light = light_val, threshold = 0.5 }
end

--- Snap between values at custom threshold
--- @param threshold number Threshold in t-space (0.0-1.0)
--- @param dark_val any Value for dark themes (t < threshold)
--- @param light_val any Value for light themes (t >= threshold)
--- @return table Wrapper with mode metadata
local function snapAt(threshold, dark_val, light_val)
  return { mode = "snap", dark = dark_val, light = light_val, threshold = threshold }
end

-- Export wrappers for external use
M.offsetFromBase = offsetFromBase
M.lerpDarkLight = lerpDarkLight
M.snapAtMidpoint = snapAtMidpoint
M.snapAt = snapAt

-- Legacy exports (for backward compatibility during transition)
M.blend = function(value) return lerpDarkLight(value, value) end
M.step = function(value) return snapAtMidpoint(value, value) end

-- ============================================================================
-- THEME RULES (Unified Single-Definition)
-- ============================================================================
-- All rules defined once. Each wrapper specifies behavior across dark↔light.
-- BG_BASE itself adapts to lightness; offsets are applied on top.

M.rules = {
  -- ========== BACKGROUND OFFSETS ==========
  -- offsetFromBase: delta applied to BG_BASE
  -- Different signs = snap at threshold (contrast-preserving)
  -- Same signs = constant offset
  bg_hover_delta = offsetFromBase(0.03, -0.04),      -- Lighter on dark, darker on light
  bg_active_delta = offsetFromBase(0.05, -0.07),     -- More pronounced for active state
  bg_header_delta = offsetFromBase(-0.024, -0.06),   -- Headers slightly darker
  bg_panel_delta = offsetFromBase(-0.04),            -- Panels always darker (same both)

  -- ========== CHROME (titlebar/statusbar) ==========
  -- Chrome is significantly darker than content area
  -- Formula: chrome_lightness = bg_lightness * factor + offset
  -- Dark: multiply by 0.42, no offset → chrome ≈ 6% lightness for 14% bg
  -- Light: keep full lightness, subtract 0.15 → chrome ≈ 73% for 88% bg
  chrome_lightness_factor = lerpDarkLight(0.42, 1.0),   -- Multiplier for bg_lightness
  chrome_lightness_offset = lerpDarkLight(0, -0.15),    -- Additive offset after multiply

  -- ========== PATTERN OFFSETS ==========
  -- Applied to BG_PANEL (which is derived from BG_BASE)
  pattern_primary_delta = offsetFromBase(-0.024, -0.06),
  pattern_secondary_delta = offsetFromBase(-0.004, -0.02),

  -- ========== BORDER COLORS ==========
  border_outer_color = snapAtMidpoint("#000000", "#404040"),  -- Black on dark, grey on light
  border_outer_opacity = lerpDarkLight(0.87, 0.60),           -- More opaque on dark

  -- Border offsets from BG_BASE
  border_inner_delta = offsetFromBase(0.05, -0.03),
  border_hover_delta = offsetFromBase(0.10, -0.08),
  border_active_delta = offsetFromBase(0.15, -0.12),
  border_focus_delta = offsetFromBase(0.20, -0.15),

  -- ========== TEXT OFFSETS ==========
  -- Applied to base_text color
  text_hover_delta = offsetFromBase(0.05, -0.05),
  text_dimmed_delta = offsetFromBase(-0.10, 0.15),
  text_dark_delta = offsetFromBase(-0.20, 0.25),
  text_bright_delta = offsetFromBase(0.10, -0.08),

  -- ========== ACCENT VALUES ==========
  accent_bright_delta = offsetFromBase(0.15, -0.12),
  accent_white_lightness = lerpDarkLight(0.25, 0.55),         -- Absolute lightness values
  accent_white_bright_lightness = lerpDarkLight(0.35, 0.45),

  -- ========== SEMANTIC STATUS COLORS ==========
  -- These lerp for better integration with theme
  status_success = lerpDarkLight("#4CAF50", "#2E7D32"),   -- Green (brighter on dark)
  status_warning = lerpDarkLight("#FFA726", "#F57C00"),   -- Orange (brighter on dark)
  status_danger = lerpDarkLight("#EF5350", "#C62828"),    -- Red (brighter on dark)

  -- ========== TILE RENDERING ==========
  -- Multipliers for user-colored elements
  tile_fill_brightness = lerpDarkLight(0.5, 1.4),
  tile_fill_saturation = lerpDarkLight(0.4, 0.5),
  tile_fill_opacity = lerpDarkLight(0.4, 0.5),
  tile_name_color = snapAtMidpoint("#DDE3E9", "#1A1A1A"),     -- Light text dark bg, dark text light bg

  -- ========== BADGES ==========
  badge_bg_color = snapAtMidpoint("#14181C", "#E8ECF0"),
  badge_bg_opacity = lerpDarkLight(0.85, 0.90),
  badge_text_color = snapAtMidpoint("#FFFFFF", "#1A1A1A"),
  badge_border_opacity = lerpDarkLight(0.20, 0.15),

  -- ========== PLAYLIST TILES ==========
  playlist_tile_color = snapAtMidpoint("#3A3A3A", "#D0D0D0"),
  playlist_name_color = snapAtMidpoint("#CCCCCC", "#2A2A2A"),
  playlist_badge_color = snapAtMidpoint("#999999", "#666666"),
}

-- ============================================================================
-- PRESET ANCHORS
-- ============================================================================
-- Lightness values defining the dark↔light interpolation range.
-- t=0.0 at dark anchor, t=1.0 at light anchor.

M.preset_anchors = {
  dark = 0.14,   -- ~14% lightness
  light = 0.88,  -- ~88% lightness
}

-- Legacy alias
M.theme_anchors = M.preset_anchors

-- ============================================================================
-- RULE COMPUTATION
-- ============================================================================
-- Core logic for computing rule values based on current lightness.

--- Get current theme's base lightness (0.0-1.0)
--- @return number Lightness of current BG_BASE
function M.get_theme_lightness()
  if not Style.COLORS.BG_BASE then return 0.14 end  -- Default to dark
  local _, _, l = Colors.rgb_to_hsl(Style.COLORS.BG_BASE)
  return l
end

--- Compute interpolation factor 't' from lightness
--- @param lightness number Background lightness (0.0-1.0)
--- @return number t value (0.0 at dark anchor, 1.0 at light anchor)
local function compute_t(lightness)
  local range = M.preset_anchors.light - M.preset_anchors.dark
  if range <= 0 then return 0 end
  local t = (lightness - M.preset_anchors.dark) / range
  return math.max(0, math.min(1, t))
end

--- Compute a single rule value based on wrapper type and current t
--- @param rule table Wrapped rule from M.rules
--- @param t number Interpolation factor (0.0-1.0)
--- @return any Computed value
local function compute_rule_value(rule, t)
  if type(rule) ~= "table" or not rule.mode then
    -- Raw value (not wrapped), return as-is
    return rule
  end

  local mode = rule.mode
  local dark_val = rule.dark
  local light_val = rule.light
  local threshold = rule.threshold or 0.5

  if mode == "offset" then
    -- Offset: snap between deltas at threshold
    -- (No lerp - BG_BASE already adapts, we just pick the right delta)
    return t < threshold and dark_val or light_val

  elseif mode == "snap" then
    -- Snap: discrete switch at threshold
    return t < threshold and dark_val or light_val

  elseif mode == "lerp" then
    -- Lerp: smooth interpolation
    if type(dark_val) == "number" and type(light_val) == "number" then
      return dark_val + (light_val - dark_val) * t
    elseif type(dark_val) == "string" and type(light_val) == "string" then
      -- RGB color lerp for hex strings
      local color_a = Colors.hexrgb(dark_val .. (dark_val:len() == 7 and "FF" or ""))
      local color_b = Colors.hexrgb(light_val .. (light_val:len() == 7 and "FF" or ""))
      local lerped = Colors.lerp(color_a, color_b, t)
      -- Convert back to hex string
      local r, g, b = Colors.rgba_to_components(lerped)
      return string.format("#%02X%02X%02X", r, g, b)
    else
      -- Non-interpolatable, snap at midpoint
      return t < 0.5 and dark_val or light_val
    end

  else
    -- Unknown mode, return dark value
    return dark_val
  end
end

--- Compute all rules for a given lightness value
--- @param lightness number Background lightness (0.0-1.0)
--- @param mode string|nil Theme mode ("dark", "grey", "light", "adapt", or nil)
--- @return table Computed rules (raw values ready for use)
local function compute_rules_for_lightness(lightness, mode)
  local t

  -- Determine t based on mode
  if mode == "dark" then
    t = 0  -- Force dark values
  elseif mode == "grey" then
    -- Grey is at ~24% lightness, compute its t value
    t = compute_t(0.24)
  elseif mode == "light" then
    t = 1  -- Force light values
  else
    -- "adapt" mode or nil: compute t from actual lightness
    t = compute_t(lightness)
  end

  -- Compute each rule value
  local result = {}
  for key, rule in pairs(M.rules) do
    result[key] = compute_rule_value(rule, t)
  end

  return result
end

--- Get derivation rules for current theme mode
--- @return table Rules table for the current theme (computed values)
function M.get_current_rules()
  return compute_rules_for_lightness(M.get_theme_lightness(), M.current_mode)
end

--- Get current interpolation factor t
--- @return number t value (0.0 at dark, 1.0 at light)
function M.get_current_t()
  local lightness = M.get_theme_lightness()
  if M.current_mode == "dark" then return 0 end
  if M.current_mode == "light" then return 1 end
  if M.current_mode == "grey" then return compute_t(0.24) end
  return compute_t(lightness)
end

-- ============================================================================
-- LEGACY COMPATIBILITY
-- ============================================================================
-- Backward compatibility for code using old two-preset system

-- Legacy presets structure (maps to new unified rules evaluated at endpoints)
M.presets = {
  dark = setmetatable({}, {
    __index = function(_, key)
      local rule = M.rules[key]
      if rule and type(rule) == "table" then
        return rule.dark
      end
      return rule
    end
  }),
  light = setmetatable({}, {
    __index = function(_, key)
      local rule = M.rules[key]
      if rule and type(rule) == "table" then
        return rule.light
      end
      return rule
    end
  }),
}

-- Legacy theme_rules map
M.theme_rules = M.presets

-- Legacy derivation_rules (returns dark values)
M.derivation_rules = setmetatable({}, {
  __index = function(_, key)
    local rule = M.rules[key]
    if rule and type(rule) == "table" then
      return rule.dark
    end
    return rule
  end
})

-- ============================================================================
-- CORE: ALGORITHMIC PALETTE GENERATION
-- ============================================================================

--- Generate complete UI color palette from 1-3 base colors
--- @param base_bg number Background color in RGBA format
--- @param base_text number Text color in RGBA format
--- @param base_accent number|nil Optional accent color (nil for neutral grayscale)
--- @param rules table|nil Optional rules override (defaults to interpolated rules for current mode)
--- @return table Color palette with all UI colors
function M.generate_palette(base_bg, base_text, base_accent, rules)
  -- Detect theme type from background lightness
  local _, _, bg_lightness = Colors.rgb_to_hsl(base_bg)
  local is_light = bg_lightness > 0.5

  -- Get rules: use provided, or compute interpolated rules
  -- In adapt mode this will interpolate between presets based on lightness
  if not rules then
    rules = compute_rules_for_lightness(bg_lightness, M.current_mode)
  end

  -- Calculate chrome color (titlebar/statusbar) - significantly darker than content
  -- Formula: chrome_lightness = bg_lightness * factor + offset
  -- This allows smooth interpolation for grey themes
  local chrome_lightness = bg_lightness * rules.chrome_lightness_factor + rules.chrome_lightness_offset
  chrome_lightness = math.max(0.04, math.min(0.85, chrome_lightness))
  local base_chrome = Colors.set_lightness(base_bg, chrome_lightness)

  -- For neutral themes (no accent), derive accents from background
  local neutral_accent
  if base_accent == nil then
    neutral_accent = Colors.adjust_lightness(base_bg, rules.accent_bright_delta)
  else
    neutral_accent = base_accent
  end

  -- Pre-compute BG_PANEL for pattern derivation
  local bg_panel = Colors.adjust_lightness(base_bg, rules.bg_panel_delta)

  -- Build BORDER_OUTER from rules (color + opacity as floats)
  local border_outer = Colors.with_alpha(
    Colors.hexrgb(rules.border_outer_color),
    Colors.opacity(rules.border_outer_opacity)
  )

  return {
    -- ============ BACKGROUNDS ============
    -- Deltas already have correct sign baked into rules
    BG_BASE = base_bg,
    BG_HOVER = Colors.adjust_lightness(base_bg, rules.bg_hover_delta),
    BG_ACTIVE = Colors.adjust_lightness(base_bg, rules.bg_active_delta),
    BG_HEADER = Colors.adjust_lightness(base_bg, rules.bg_header_delta),
    BG_PANEL = bg_panel,
    BG_CHROME = base_chrome,
    BG_TRANSPARENT = Colors.with_alpha(base_bg, 0x00),

    -- ============ BORDERS ============
    -- BORDER_OUTER uses theme-specific color and opacity from rules
    BORDER_OUTER = border_outer,
    BORDER_INNER = Colors.adjust_lightness(base_bg, rules.border_inner_delta),
    BORDER_HOVER = Colors.adjust_lightness(base_bg, rules.border_hover_delta),
    BORDER_ACTIVE = Colors.adjust_lightness(base_bg, rules.border_active_delta),
    BORDER_FOCUS = Colors.adjust_lightness(base_bg, rules.border_focus_delta),

    -- ============ TEXT ============
    -- Deltas already have correct sign baked into rules
    TEXT_NORMAL = base_text,
    TEXT_HOVER = Colors.adjust_lightness(base_text, rules.text_hover_delta),
    TEXT_ACTIVE = Colors.adjust_lightness(base_text, rules.text_hover_delta),
    TEXT_DIMMED = Colors.adjust_lightness(base_text, rules.text_dimmed_delta),
    TEXT_DARK = Colors.adjust_lightness(base_text, rules.text_dark_delta),
    TEXT_BRIGHT = Colors.adjust_lightness(base_text, rules.text_bright_delta),

    -- ============ ACCENTS ============
    ACCENT_PRIMARY = neutral_accent,
    ACCENT_TEAL = neutral_accent,
    ACCENT_TEAL_BRIGHT = Colors.adjust_lightness(neutral_accent, rules.accent_bright_delta),

    -- White/gray variant for toggle buttons (absolute lightness from rules)
    ACCENT_WHITE = Colors.set_lightness(base_bg, rules.accent_white_lightness),
    ACCENT_WHITE_BRIGHT = Colors.set_lightness(base_bg, rules.accent_white_bright_lightness),

    -- Transparent variant (for overlays)
    ACCENT_TRANSPARENT = Colors.with_alpha(neutral_accent, 0xAA),

    -- Status colors (theme-reactive for better integration)
    ACCENT_SUCCESS = Colors.hexrgb(rules.status_success),
    ACCENT_WARNING = Colors.hexrgb(rules.status_warning),
    ACCENT_DANGER = Colors.hexrgb(rules.status_danger),

    -- ============ PATTERNS ============
    -- Background grid patterns - SOLID colors darker than BG_PANEL
    -- Creates "etched" line effect (dark lines on slightly lighter background)
    -- Original design: BG_PANEL=26, Primary=20 (-6 RGB), Secondary=25 (-1 RGB)
    --
    -- Pattern colors are OPAQUE - the grid lines are solid, not transparent overlays
    PATTERN_PRIMARY = Colors.adjust_lightness(bg_panel, rules.pattern_primary_delta),
    PATTERN_SECONDARY = Colors.adjust_lightness(bg_panel, rules.pattern_secondary_delta),

    -- ============ TILES ============
    -- Rendering parameters for region tiles (user-colored elements)
    -- Dark themes: darken/desaturate fills, light text
    -- Light themes: brighten/whiten fills, dark text
    TILE_FILL_BRIGHTNESS = rules.tile_fill_brightness,
    TILE_FILL_SATURATION = rules.tile_fill_saturation,
    TILE_FILL_OPACITY = rules.tile_fill_opacity,
    TILE_NAME_COLOR = Colors.hexrgb(rules.tile_name_color),

    -- ============ BADGES ============
    -- Count indicators, playlist chips, status badges
    BADGE_BG = Colors.with_alpha(
      Colors.hexrgb(rules.badge_bg_color),
      Colors.opacity(rules.badge_bg_opacity)
    ),
    BADGE_TEXT = Colors.hexrgb(rules.badge_text_color),
    BADGE_BORDER_OPACITY = rules.badge_border_opacity,

    -- ============ PLAYLIST TILES ============
    -- Playlist tiles in pool/active views (distinct from region tiles)
    PLAYLIST_TILE_COLOR = Colors.hexrgb(rules.playlist_tile_color),
    PLAYLIST_NAME_COLOR = Colors.hexrgb(rules.playlist_name_color),
    PLAYLIST_BADGE_COLOR = Colors.hexrgb(rules.playlist_badge_color),
  }
end

--- Apply a color palette to Style.COLORS
--- @param palette table Color palette from generate_palette()
local function apply_palette(palette)
  for key, value in pairs(palette) do
    Style.COLORS[key] = value
  end

  -- Invalidate script rules cache (they depend on theme lightness)
  clear_script_rules_cache()

  -- NOTE: We intentionally do NOT clear the pattern texture cache here.
  -- Each unique color gets its own cache entry. When switching themes,
  -- different colors create new entries while old ones remain cached.
  -- This way, switching back to a previous theme reuses existing textures
  -- instead of creating duplicates (which would leak ImGui attachments).
end

--- Generate palette from base colors and apply to Style.COLORS
--- @param base_bg number Background color
--- @param base_text number Text color
--- @param base_accent number|nil Optional accent color
function M.generate_and_apply(base_bg, base_text, base_accent)
  local palette = M.generate_palette(base_bg, base_text, base_accent)
  apply_palette(palette)
end

-- ============================================================================
-- REAPER INTEGRATION
-- ============================================================================

--- Convert REAPER native color format to ImGui format (0xRRGGBBAA)
--- REAPER uses native OS format: Windows=0x00BBGGRR, macOS may differ
--- @param reaper_color number REAPER native color
--- @return number|nil ImGui color in RGBA format, or nil on error
local function reaper_to_imgui(reaper_color)
  if reaper_color == -1 then
    return nil  -- Failed to get color
  end
  -- REAPER native (Windows): 0x00BBGGRR
  -- ImGui:  0xRRGGBBAA
  local b = (reaper_color >> 16) & 0xFF
  local g = (reaper_color >> 8) & 0xFF
  local r = reaper_color & 0xFF
  return (r << 24) | (g << 16) | (b << 8) | 0xFF
end

--- Sync theme colors with REAPER's current theme (ultra-minimal approach)
--- Reads only 1 color (main_bg), applies slight offset for visual separation,
--- generates neutral grayscale palette for maximum theme compatibility
--- @return boolean Success (true if colors were read and applied)
function M.sync_with_reaper()
  -- Read single background color from REAPER
  local main_bg_raw = reaper.GetThemeColor("col_main_bg2", 0)

  if main_bg_raw == -1 then
    return false  -- Failed to read REAPER theme
  end

  -- Convert to ImGui format
  local main_bg = reaper_to_imgui(main_bg_raw)

  -- Apply -3 RGB offset (~-1.2% lightness) for subtle visual separation
  -- ARKITEKT sits slightly darker than REAPER, regardless of light/dark theme
  local offset_bg = Colors.adjust_lightness(main_bg, -0.012)

  -- Generate text color (auto white on dark, black on light)
  local base_text = Colors.auto_text_color(offset_bg)

  -- Generate neutral grayscale palette
  local palette = M.generate_palette(offset_bg, base_text, nil)

  -- Apply palette
  for key, value in pairs(palette) do
    Style.COLORS[key] = value
  end

  return true
end

--- Create a live sync function that polls REAPER theme changes
--- @param interval number|nil Check interval in seconds (default: 1.0)
--- @return function Function to call in main loop for live sync
function M.create_live_sync(interval)
  interval = interval or 1.0
  local last_check = 0
  local last_bg = nil

  return function()
    local now = reaper.time_precise()
    if now - last_check >= interval then
      -- Read current REAPER background color
      local current_bg = reaper.GetThemeColor("col_main_bg2", 0)

      -- Only update if color changed
      if current_bg ~= last_bg and current_bg ~= -1 then
        M.sync_with_reaper()
        last_bg = current_bg
      end

      last_check = now
    end
  end
end

-- ============================================================================
-- PRESET THEMES
-- ============================================================================

--- Built-in theme presets
--- Each returns a palette generator function
---
--- Primary presets: dark, grey, light (neutral, no accent colors)
--- ADAPT mode: Uses sync_with_reaper() to match REAPER's theme
M.themes = {
  -- DARK: Deep, high-contrast theme
  -- Best for: Low-light environments, OLED screens
  dark = function()
    return M.generate_palette(
      Colors.hexrgb("#242424FF"),  -- 36,36,36 RGB (~14% lightness)
      Colors.hexrgb("#CCCCCCFF"),  -- Light gray text (~80%)
      nil                          -- No accent (neutral grayscale)
    )
  end,

  -- GREY: Balanced neutral theme
  -- Best for: All-day use, reduces eye strain
  grey = function()
    return M.generate_palette(
      Colors.hexrgb("#3D3D3DFF"),  -- Medium gray (~24% lightness)
      Colors.hexrgb("#E0E0E0FF"),  -- Off-white text (~88%)
      nil                          -- No accent (neutral grayscale)
    )
  end,

  -- LIGHT: Bright, paper-like theme
  -- Best for: Bright environments, printable mockups
  light = function()
    return M.generate_palette(
      Colors.hexrgb("#E0E0E0FF"),  -- Light gray (~88% lightness)
      Colors.hexrgb("#2A2A2AFF"),  -- Dark text (~16%)
      nil                          -- No accent (neutral grayscale)
    )
  end,

  -- ===== Legacy presets (kept for backward compatibility) =====

  -- Midnight (very dark) - alias to dark
  midnight = function()
    return M.generate_palette(
      Colors.hexrgb("#0A0A0AFF"),  -- Almost black
      Colors.hexrgb("#AAAAAAFF"),  -- Medium gray text
      nil
    )
  end,

  -- Pro Tools inspired - alias to grey
  pro_tools = function()
    return M.generate_palette(
      Colors.hexrgb("#3D3D3DFF"),  -- Medium dark gray (PT background)
      Colors.hexrgb("#D4D4D4FF"),  -- Off-white text
      nil
    )
  end,

  -- Ableton inspired
  ableton = function()
    return M.generate_palette(
      Colors.hexrgb("#1A1A1AFF"),  -- Very dark gray
      Colors.hexrgb("#CCCCCCFF"),  -- Light text
      nil
    )
  end,

  -- FL Studio inspired
  fl_studio = function()
    return M.generate_palette(
      Colors.hexrgb("#2B2B2BFF"),  -- Dark gray
      Colors.hexrgb("#E0E0E0FF"),  -- Light text
      nil
    )
  end,
}

--- Apply a preset theme by name
--- @param name string Theme name from M.themes
--- @return boolean Success (true if theme exists and was applied)
function M.apply_theme(name)
  local theme = M.themes[name]
  if not theme then
    return false
  end

  local palette = theme()
  apply_palette(palette)

  return true
end

--- Get list of available theme names
--- @return table Array of theme names
function M.get_theme_names()
  local names = {}
  for name, _ in pairs(M.themes) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

--- Get primary preset names (Dark, Grey, Light)
--- @return table Array of primary theme names
function M.get_primary_presets()
  return { "dark", "grey", "light" }
end

-- ============================================================================
-- SIMPLE API: Primary Theme Selection
-- ============================================================================
-- Use these functions for the main theme selector UI
--
-- Example:
--   ThemeManager.set_dark()   -- Apply dark preset
--   ThemeManager.set_grey()   -- Apply grey preset
--   ThemeManager.set_light()  -- Apply light preset
--   ThemeManager.adapt()      -- Sync with REAPER theme
-- ============================================================================

--- Apply dark preset (deep gray, ~12% lightness)
function M.set_dark()
  return M.apply_theme("dark")
end

--- Apply grey preset (medium gray, ~24% lightness)
function M.set_grey()
  return M.apply_theme("grey")
end

--- Apply light preset (light gray, ~88% lightness)
function M.set_light()
  return M.apply_theme("light")
end

--- Adapt to REAPER's current theme
--- Reads main window + arrange backgrounds, generates neutral palette
--- @return boolean Success
function M.adapt()
  return M.sync_with_reaper()
end

--- Current active theme mode
--- @return string|nil "dark", "grey", "light", "adapt", or nil if custom
M.current_mode = nil

-- ============================================================================
-- THEME PERSISTENCE (via REAPER ExtState)
-- ============================================================================
-- Theme preferences are persisted across sessions using REAPER's ExtState API.
-- This ensures the user's theme choice is remembered without requiring settings.

local EXTSTATE_SECTION = "ARKITEKT"
local EXTSTATE_KEY = "theme_mode"

--- Save current theme mode to REAPER ExtState (persistent)
local function save_theme_preference(mode)
  if mode then
    reaper.SetExtState(EXTSTATE_SECTION, EXTSTATE_KEY, mode, true)  -- persist=true
  end
end

--- Load saved theme mode from REAPER ExtState
--- @return string|nil Saved theme mode or nil if not set
function M.load_saved_mode()
  local saved = reaper.GetExtState(EXTSTATE_SECTION, EXTSTATE_KEY)
  if saved and saved ~= "" then
    return saved
  end
  return nil
end

--- Set theme by mode name (for UI selectors)
--- @param mode string "dark", "grey", "light", or "adapt"
--- @param persist boolean|nil Whether to save preference (default: true)
--- @return boolean Success
function M.set_mode(mode, persist)
  if persist == nil then persist = true end
  local success = false

  if mode == "adapt" then
    success = M.sync_with_reaper()
  elseif M.themes[mode] then
    success = M.apply_theme(mode)
  end

  if success then
    M.current_mode = mode
    if persist then
      save_theme_preference(mode)
    end
  end

  return success
end

--- Get current theme mode
--- @return string|nil
function M.get_mode()
  return M.current_mode
end

--- Initialize theme from saved preference or default
--- Called automatically on first require, or can be called manually
--- @param default_mode string|nil Default mode if no saved preference ("adapt" if nil)
--- @return boolean Success
function M.init(default_mode)
  default_mode = default_mode or "adapt"

  -- Try to load saved preference
  local saved_mode = M.load_saved_mode()

  -- Use saved mode if valid, otherwise use default
  local mode_to_apply = saved_mode
  if not mode_to_apply or (mode_to_apply ~= "dark" and mode_to_apply ~= "grey" and mode_to_apply ~= "light" and mode_to_apply ~= "adapt") then
    mode_to_apply = default_mode
  end

  -- Apply theme (don't persist again if loading saved preference)
  return M.set_mode(mode_to_apply, saved_mode == nil)
end

-- ============================================================================
-- UTILITIES
-- ============================================================================

--- Get current color values (for debugging or transitions)
--- @return table Copy of current Style.COLORS
function M.get_current_colors()
  local current = {}
  for key, value in pairs(Style.COLORS) do
    current[key] = value
  end
  return current
end

--- Adapt a color to the current theme using a "pull factor"
--- The pull factor determines how much the color's lightness moves toward the theme's base lightness.
--- Use this for custom components that need to follow theme changes without using fixed Style.COLORS keys.
---
--- @param base_color number Base color in RGBA format
--- @param pull_factor number|nil How much to pull toward theme lightness (0.0-1.0, default 0.5)
---   - 0.0 = keep original lightness
---   - 0.5 = halfway between original and theme
---   - 1.0 = match theme lightness exactly
--- @return number Adapted color in RGBA format
---
--- Example usage:
---   local ready_bg = ThemeManager.adapt_color(hexrgb("#1A1A1A"), 0.9)  -- Strongly follows theme
---   local specular = ThemeManager.adapt_color(hexrgb("#FFFFFF"), 0.2)  -- Mostly white, slight theme influence
function M.adapt_color(base_color, pull_factor)
  pull_factor = pull_factor or 0.5

  -- Get current theme lightness
  local theme_l = M.get_theme_lightness()

  -- Get base color's HSL
  local base_h, base_s, base_l = Colors.rgb_to_hsl(base_color)

  -- Pull lightness toward theme
  local target_l = base_l + (theme_l - base_l) * pull_factor

  -- Clamp to valid range
  target_l = math.max(0, math.min(1, target_l))

  -- Convert back to RGBA, preserving original alpha
  local r, g, b = Colors.hsl_to_rgb(base_h, base_s, target_l)
  local _, _, _, a = Colors.rgba_to_components(base_color)

  return Colors.components_to_rgba(r, g, b, a)
end

--- Smooth transition between current colors and a new theme
--- @param target_palette table Target color palette
--- @param duration number Transition duration in seconds
--- @param on_complete function|nil Optional callback when complete
function M.transition_to_palette(target_palette, duration, on_complete)
  local start_colors = M.get_current_colors()
  local start_time = reaper.time_precise()

  local function animate()
    local elapsed = reaper.time_precise() - start_time
    local t = math.min(elapsed / duration, 1.0)

    -- Lerp each color
    for key, target_color in pairs(target_palette) do
      if start_colors[key] then
        Style.COLORS[key] = Colors.lerp(start_colors[key], target_color, t)
      end
    end

    -- Continue animating or finish
    if t < 1.0 then
      reaper.defer(animate)
    else
      -- Ensure final values are exact
      apply_palette(target_palette)
      if on_complete then
        on_complete()
      end
    end
  end

  animate()
end

--- Transition to a theme by name with smooth animation
--- @param name string Theme name
--- @param duration number|nil Transition duration in seconds (default: 0.3)
--- @param on_complete function|nil Optional callback
--- @return boolean Success (true if theme exists)
function M.transition_to_theme(name, duration, on_complete)
  local theme = M.themes[name]
  if not theme then
    return false
  end

  duration = duration or 0.3
  local palette = theme()
  M.transition_to_palette(palette, duration, on_complete)

  return true
end

-- ============================================================================
-- THEME VALIDATION
-- ============================================================================
-- Runtime checks to catch configuration errors early.
-- With the unified rules system, validation is simpler - just check wrappers.

--- Validate rules configuration
--- Checks that all rules are properly wrapped with valid dark/light values.
--- @return boolean valid True if configuration is valid
--- @return string|nil error_message Error details if invalid
function M.validate()
  local errors = {}

  for key, rule in pairs(M.rules) do
    -- Check: Rule is properly wrapped
    if type(rule) ~= "table" or not rule.mode then
      errors[#errors + 1] = string.format(
        "Rule '%s' is not wrapped (use offsetFromBase, lerpDarkLight, snapAtMidpoint, or snapAt)",
        key
      )
    else
      -- Check: Has dark and light values
      if rule.dark == nil then
        errors[#errors + 1] = string.format("Rule '%s' missing 'dark' value", key)
      end
      if rule.light == nil then
        errors[#errors + 1] = string.format("Rule '%s' missing 'light' value", key)
      end

      -- Check: Valid mode
      local valid_modes = { offset = true, lerp = true, snap = true }
      if not valid_modes[rule.mode] then
        errors[#errors + 1] = string.format(
          "Rule '%s' has invalid mode '%s' (expected: offset, lerp, snap)",
          key, tostring(rule.mode)
        )
      end

      -- Check: Dark and light have same type
      if rule.dark ~= nil and rule.light ~= nil then
        local dark_type = type(rule.dark)
        local light_type = type(rule.light)
        if dark_type ~= light_type then
          errors[#errors + 1] = string.format(
            "Rule '%s' has type mismatch: dark=%s (%s), light=%s (%s)",
            key, tostring(rule.dark), dark_type, tostring(rule.light), light_type
          )
        end
      end

      -- Check: Threshold in valid range (for snap modes)
      if rule.threshold ~= nil then
        if type(rule.threshold) ~= "number" or rule.threshold < 0 or rule.threshold > 1 then
          errors[#errors + 1] = string.format(
            "Rule '%s' has invalid threshold '%s' (expected: 0.0-1.0)",
            key, tostring(rule.threshold)
          )
        end
      end
    end
  end

  if #errors > 0 then
    return false, table.concat(errors, "\n")
  end

  return true, nil
end

--- Get validation status as a summary table
--- Useful for debug overlays and status displays
--- @return table Summary with counts and status
function M.get_validation_summary()
  local valid, err = M.validate()
  local rule_count = 0
  local mode_counts = { offset = 0, lerp = 0, snap = 0 }

  for _, rule in pairs(M.rules) do
    rule_count = rule_count + 1
    if type(rule) == "table" and rule.mode then
      mode_counts[rule.mode] = (mode_counts[rule.mode] or 0) + 1
    end
  end

  return {
    valid = valid,
    error_message = err,
    rule_count = rule_count,
    mode_counts = mode_counts,
    error_count = err and select(2, err:gsub("\n", "\n")) + 1 or 0,
  }
end

-- ============================================================================
-- DEBUG OVERLAY
-- ============================================================================
-- Visual debugging tool for tuning theme values in real-time.
-- Toggle with F12 or call ThemeManager.toggle_debug()

--- Debug mode state
M.debug_enabled = false

--- Toggle debug overlay visibility
function M.toggle_debug()
  M.debug_enabled = not M.debug_enabled
end

--- Enable debug overlay
function M.enable_debug()
  M.debug_enabled = true
end

--- Disable debug overlay
function M.disable_debug()
  M.debug_enabled = false
end

-- ============================================================================
-- SCRIPT COLOR REGISTRATION
-- ============================================================================
-- Scripts can register their color modules for display in the debug overlay.
-- This allows script-specific colors to be visible without modifying the library.
--
-- Usage in script init:
--   local ScriptColors = require('MyScript.defs.colors')
--   ThemeManager.register_script_colors("MyScript", {
--     CIRCULAR_BASE = hexrgb("#240C0CFF"),
--     CIRCULAR_TEXT = hexrgb("#901B1BFF"),
--     FALLBACK_CHIP = hexrgb("#FF5733FF"),
--   })

--- Registered script color modules
--- @type table<string, table<string, any>>
M.registered_script_colors = {}

--- Register a script's color table for debug display
--- @param script_name string Name of the script (e.g., "RegionPlaylist")
--- @param colors table Color table with key-value pairs
function M.register_script_colors(script_name, colors)
  if type(script_name) ~= "string" or type(colors) ~= "table" then
    return
  end
  M.registered_script_colors[script_name] = colors
end

--- Unregister a script's colors
--- @param script_name string Name of the script to unregister
function M.unregister_script_colors(script_name)
  M.registered_script_colors[script_name] = nil
end

--- Get all registered script colors
--- @return table<string, table<string, any>>
function M.get_registered_script_colors()
  return M.registered_script_colors
end

-- ============================================================================
-- SCRIPT RULES REGISTRATION
-- ============================================================================
-- Scripts can register their own theme-reactive rules using the same wrappers.
-- Unlike static colors, these rules adapt to theme lightness automatically.
--
-- Usage in script init:
--   local ThemeManager = require('arkitekt.core.theme_manager')
--   local offsetFromBase = ThemeManager.offsetFromBase
--   local lerpDarkLight = ThemeManager.lerpDarkLight
--   local snapAtMidpoint = ThemeManager.snapAtMidpoint
--
--   ThemeManager.register_script_rules("MyScript", {
--     panel_bg_delta = offsetFromBase(-0.06, -0.08),       -- Darker panels
--     highlight_color = lerpDarkLight("#FF6B6B", "#CC4444"), -- Theme-reactive red
--     badge_text = snapAtMidpoint("#FFFFFF", "#1A1A1A"),     -- Contrast text
--   })
--
--   -- Access computed values (after theme applies):
--   local rules = ThemeManager.get_script_rules("MyScript")
--   local my_color = rules.highlight_color  -- Already computed for current theme

--- Registered script rule definitions
--- @type table<string, table<string, table>>
M.registered_script_rules = {}

--- Register a script's theme-reactive rules
--- @param script_name string Name of the script (e.g., "RegionPlaylist")
--- @param rules table Rules table using wrappers (offsetFromBase, lerpDarkLight, etc.)
function M.register_script_rules(script_name, rules)
  if type(script_name) ~= "string" or type(rules) ~= "table" then
    return
  end
  M.registered_script_rules[script_name] = rules
  -- Invalidate cache for this script
  script_rules_cache[script_name] = nil
end

--- Unregister a script's rules
--- @param script_name string Name of the script to unregister
function M.unregister_script_rules(script_name)
  M.registered_script_rules[script_name] = nil
  script_rules_cache[script_name] = nil
end

--- Get computed rules for a script (computed for current theme)
--- @param script_name string Name of the script
--- @return table|nil Computed rules table, or nil if not registered
function M.get_script_rules(script_name)
  local rule_defs = M.registered_script_rules[script_name]
  if not rule_defs then
    return nil
  end

  -- Check cache
  local cached = script_rules_cache[script_name]
  local current_t = M.get_current_t()
  if cached and cached._t == current_t then
    return cached
  end

  -- Compute rules for current theme
  local computed = { _t = current_t }
  for key, rule in pairs(rule_defs) do
    computed[key] = compute_rule_value(rule, current_t)
  end

  script_rules_cache[script_name] = computed
  return computed
end

--- Get all registered script rules (definitions, not computed)
--- @return table<string, table<string, table>>
function M.get_registered_script_rules()
  return M.registered_script_rules
end

-- Mapping from preset rule keys to their corresponding Style.COLORS keys
local RULE_TO_STYLE_MAP = {
  -- Background deltas
  bg_hover_delta = "BG_HOVER",
  bg_active_delta = "BG_ACTIVE",
  bg_header_delta = "BG_HEADER",
  bg_panel_delta = "BG_PANEL",
  -- Chrome (derived)
  chrome_lightness_factor = "BG_CHROME",
  chrome_lightness_offset = "BG_CHROME",
  -- Patterns
  pattern_primary_delta = "PATTERN_PRIMARY",
  pattern_secondary_delta = "PATTERN_SECONDARY",
  -- Borders
  border_outer_color = "BORDER_OUTER",
  border_outer_opacity = "BORDER_OUTER",
  border_inner_delta = "BORDER_INNER",
  border_hover_delta = "BORDER_HOVER",
  border_active_delta = "BORDER_ACTIVE",
  border_focus_delta = "BORDER_FOCUS",
  -- Text
  text_hover_delta = "TEXT_HOVER",
  text_dimmed_delta = "TEXT_DIMMED",
  text_dark_delta = "TEXT_DARK",
  text_bright_delta = "TEXT_BRIGHT",
  -- Accents
  accent_bright_delta = "ACCENT_TEAL_BRIGHT",
  accent_white_lightness = "ACCENT_WHITE",
  accent_white_bright_lightness = "ACCENT_WHITE_BRIGHT",
  -- Status colors
  status_success = "ACCENT_SUCCESS",
  status_warning = "ACCENT_WARNING",
  status_danger = "ACCENT_DANGER",
  -- Tiles
  tile_fill_brightness = "TILE_FILL_BRIGHTNESS",
  tile_fill_saturation = "TILE_FILL_SATURATION",
  tile_fill_opacity = "TILE_FILL_OPACITY",
  tile_name_color = "TILE_NAME_COLOR",
  -- Badges
  badge_bg_color = "BADGE_BG",
  badge_bg_opacity = "BADGE_BG",
  badge_text_color = "BADGE_TEXT",
  badge_border_opacity = "BADGE_BORDER_OPACITY",
  -- Playlist tiles
  playlist_tile_color = "PLAYLIST_TILE_COLOR",
  playlist_name_color = "PLAYLIST_NAME_COLOR",
  playlist_badge_color = "PLAYLIST_BADGE_COLOR",
}

--- Render debug overlay showing current theme state
--- Call this from your main render loop after other UI
--- @param ctx userdata ImGui context
--- @param ImGui table ImGui library reference
function M.render_debug_overlay(ctx, ImGui)
  if not M.debug_enabled then return end
  if not ctx or not ImGui then return end

  local lightness = M.get_theme_lightness()
  local t = M.get_current_t()

  -- Window setup
  ImGui.SetNextWindowBgAlpha(ctx, 0.92)

  local window_flags = ImGui.WindowFlags_AlwaysAutoResize
  if ImGui.WindowFlags_NoSavedSettings then
    window_flags = window_flags | ImGui.WindowFlags_NoSavedSettings
  end

  local visible, open = ImGui.Begin(ctx, "Theme Debug", true, window_flags)
  if visible then
    -- Header info
    ImGui.Text(ctx, string.format("Lightness: %.3f", lightness))
    ImGui.Text(ctx, string.format("Interpolation t: %.3f", t))
    ImGui.Text(ctx, string.format("Mode: %s", M.current_mode or "nil"))

    -- Validation status
    local valid, err = M.validate()
    if valid then
      ImGui.TextColored(ctx, 0x4CAF50FF, "Validation: OK")
    else
      ImGui.TextColored(ctx, 0xEF5350FF, "Validation: ERRORS")
      if ImGui.IsItemHovered(ctx) then
        ImGui.SetTooltip(ctx, err)
      end
    end

    ImGui.Separator(ctx)

    -- Preset anchors
    ImGui.Text(ctx, string.format("Dark anchor: %.2f (t=0)", M.preset_anchors.dark))
    ImGui.Text(ctx, string.format("Light anchor: %.2f (t=1)", M.preset_anchors.light))
    ImGui.Separator(ctx)

    -- Show each rule with current computed result
    ImGui.Text(ctx, "Rules -> Style.COLORS:")
    ImGui.Separator(ctx)

    local computed_rules = M.get_current_rules()

    -- Sort keys for consistent display
    local sorted_keys = {}
    for key in pairs(M.rules) do
      sorted_keys[#sorted_keys + 1] = key
    end
    table.sort(sorted_keys)

    for _, key in ipairs(sorted_keys) do
      local rule = M.rules[key]
      local value = computed_rules[key]
      local mode = rule.mode or "?"
      local dark_val = rule.dark
      local light_val = rule.light
      local threshold = rule.threshold
      local style_key = RULE_TO_STYLE_MAP[key]

      -- Get final computed color from Style.COLORS if available
      local final_color = style_key and Style.COLORS[style_key]
      local has_final_color = final_color and type(final_color) == "number" and final_color == math.floor(final_color)

      -- Show final color swatch if it's a color value (integer)
      if has_final_color then
        ImGui.ColorButton(ctx, "final_" .. key, math.floor(final_color), 0, 12, 12)
        ImGui.SameLine(ctx)
      end

      -- Color swatch for hex color values in computed result
      if type(value) == "string" and value:match("^#") then
        local hex_len = #value
        local hex_with_alpha = value
        if hex_len == 4 then  -- #RGB
          hex_with_alpha = value .. "F"
        elseif hex_len == 7 then  -- #RRGGBB
          hex_with_alpha = value .. "FF"
        end
        local color = Colors.hexrgb(hex_with_alpha)
        ImGui.ColorButton(ctx, "computed_" .. key, color, 0, 12, 12)
        ImGui.SameLine(ctx)
      end

      -- Value display with mode indicator and Style.COLORS mapping
      local display_value
      if type(value) == "number" then
        display_value = string.format("%.3f", value)
      else
        display_value = tostring(value)
      end

      -- Mode indicator: O=offset, L=lerp, S=snap
      local mode_char = mode:sub(1, 1):upper()
      local style_suffix = style_key and (" -> " .. style_key) or ""
      ImGui.Text(ctx, string.format("[%s] %s: %s%s", mode_char, key, display_value, style_suffix))

      -- Show dark→light range and threshold on hover
      if ImGui.IsItemHovered(ctx) then
        local tooltip = string.format(
          "dark: %s\nlight: %s\nt=%.3f\nmode: %s",
          tostring(dark_val), tostring(light_val), t, mode
        )
        if threshold and threshold ~= 0.5 then
          tooltip = tooltip .. string.format("\nthreshold: %.2f", threshold)
        end
        if style_key then
          tooltip = tooltip .. "\n\nStyle.COLORS." .. style_key
          if has_final_color then
            tooltip = tooltip .. string.format(" = 0x%08X", final_color)
          end
        end
        ImGui.SetTooltip(ctx, tooltip)
      end
    end

    ImGui.Separator(ctx)

    -- Show all Style.COLORS with swatches
    if ImGui.CollapsingHeader(ctx, "All Style.COLORS") then
      local color_keys = {}
      for k in pairs(Style.COLORS) do
        color_keys[#color_keys + 1] = k
      end
      table.sort(color_keys)

      for _, k in ipairs(color_keys) do
        local v = Style.COLORS[k]
        -- Only show color swatch for integer color values (RGBA format)
        if type(v) == "number" and v == math.floor(v) then
          ImGui.ColorButton(ctx, "style_" .. k, math.floor(v), 0, 12, 12)
          ImGui.SameLine(ctx)
          ImGui.Text(ctx, string.format("%s: 0x%08X", k, math.floor(v)))
        elseif type(v) == "number" then
          -- Non-integer numbers (multipliers, opacities, etc.)
          ImGui.Text(ctx, string.format("%s: %.3f", k, v))
        else
          ImGui.Text(ctx, string.format("%s: %s", k, tostring(v)))
        end
      end
    end

    -- Show registered script colors
    for script_name, script_colors in pairs(M.registered_script_colors) do
      if ImGui.CollapsingHeader(ctx, "Script: " .. script_name) then
        local script_keys = {}
        for k in pairs(script_colors) do
          script_keys[#script_keys + 1] = k
        end
        table.sort(script_keys)

        for _, k in ipairs(script_keys) do
          local v = script_colors[k]
          -- Only show color swatch for integer color values (RGBA format)
          if type(v) == "number" and v == math.floor(v) then
            ImGui.ColorButton(ctx, script_name .. "_" .. k, math.floor(v), 0, 12, 12)
            ImGui.SameLine(ctx)
            ImGui.Text(ctx, string.format("%s: 0x%08X", k, math.floor(v)))
          elseif type(v) == "number" then
            -- Non-integer numbers (multipliers, opacities, etc.)
            ImGui.Text(ctx, string.format("%s: %.3f", k, v))
          elseif type(v) == "string" and v:match("^#") then
            -- Hex color strings
            local hex_with_alpha = v
            if #v == 7 then hex_with_alpha = v .. "FF" end
            local color = Colors.hexrgb(hex_with_alpha)
            ImGui.ColorButton(ctx, script_name .. "_" .. k, color, 0, 12, 12)
            ImGui.SameLine(ctx)
            ImGui.Text(ctx, string.format("%s: %s", k, v))
          else
            ImGui.Text(ctx, string.format("%s: %s", k, tostring(v)))
          end
        end
      end
    end

    ImGui.End(ctx)
  end

  -- Handle window close button
  if not open then
    M.debug_enabled = false
  end
end

--- Check for F12 key press to toggle debug overlay
--- Call this from your main loop
--- @param ctx userdata ImGui context
--- @param ImGui table ImGui library reference
function M.check_debug_hotkey(ctx, ImGui)
  if not ctx or not ImGui then return end

  -- F12 to toggle debug overlay
  if ImGui.IsKeyPressed and ImGui.Key_F12 then
    if ImGui.IsKeyPressed(ctx, ImGui.Key_F12) then
      M.toggle_debug()
    end
  end
end

-- ============================================================================
-- AUTO-VALIDATION (Dev Mode)
-- ============================================================================
-- Automatically validate presets on module load when in dev mode.
-- Enable dev mode via environment variable or REAPER ExtState.

local function run_auto_validation()
  local is_dev_mode = false

  -- Check environment variable
  if os.getenv("ARKITEKT_DEV") then
    is_dev_mode = true
  end

  -- Check REAPER ExtState
  if reaper and reaper.GetExtState then
    local dev_state = reaper.GetExtState("ARKITEKT", "dev_mode")
    if dev_state == "1" or dev_state == "true" then
      is_dev_mode = true
    end
  end

  if is_dev_mode then
    local valid, err = M.validate()
    if not valid then
      local msg = "[ThemeManager] Validation errors:\n" .. err .. "\n"
      if reaper and reaper.ShowConsoleMsg then
        reaper.ShowConsoleMsg(msg)
      else
        print(msg)
      end
    end
  end
end

-- Run auto-validation on module load
run_auto_validation()

return M
