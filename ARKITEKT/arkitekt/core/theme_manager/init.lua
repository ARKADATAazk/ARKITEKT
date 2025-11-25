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
--   ThemeManager.set_dark()   -- Dark preset (~12% lightness)
--   ThemeManager.set_grey()   -- Grey preset (~24% lightness)
--   ThemeManager.set_light()  -- Light preset (~88% lightness)
--   ThemeManager.adapt()      -- Sync with REAPER's current theme
--
--   -- Or use set_mode() for UI selectors:
--   ThemeManager.set_mode("dark")   -- "dark", "grey", "light", or "adapt"
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

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

-- ============================================================================
-- VALUE WRAPPERS - Define interpolation behavior
-- ============================================================================
-- These wrappers tell the system HOW to transition between preset values:
--   blend(value)        - smooth gradient across black→grey→white
--   step(value)         - discrete zones, no interpolation
--   flipAt(0.5, value)  - binary flip at lightness threshold (for contrast)

--- Smooth gradient between preset values
--- @param value any The value for this preset
--- @return table Wrapper with mode metadata
local function blend(value)
  return { value = value, mode = "blend" }
end

--- Discrete steps - use value from current zone (no interpolation)
--- @param value any The value for this preset
--- @return table Wrapper with mode metadata
local function step(value)
  return { value = value, mode = "step" }
end

--- Binary flip at lightness threshold (used in M.contrast)
--- @param threshold number Lightness threshold (0.0-1.0) to flip at
--- @param value any The value for this contrast mode
--- @return table Wrapper with mode metadata
local function flipAt(threshold, value)
  return { value = value, mode = "flip", threshold = threshold }
end

-- Export wrappers for external use
M.blend = blend
M.step = step
M.flipAt = flipAt

-- ============================================================================
-- THEME PRESETS (black/grey/white)
-- ============================================================================
-- Concrete theme presets for blend() and step() interpolation.
-- Values wrapped with blend() will smoothly interpolate between presets.
-- Values wrapped with step() will snap to the nearest preset's value.
-- Raw values (no wrapper) are treated as blend() for backwards compatibility.

M.presets = {
  -- BLACK preset (very dark, ~14% lightness)
  black = {
    -- Background deltas (positive = lighter)
    bg_hover_delta = blend(0.03),
    bg_active_delta = blend(0.05),
    bg_header_delta = blend(-0.024),
    bg_panel_delta = blend(-0.04),

    -- Pattern visibility
    pattern_primary_delta = blend(-0.024),
    pattern_secondary_delta = blend(-0.004),

    -- Borders
    border_outer_color = step("#000000"),
    border_outer_opacity = blend(0.87),
    border_inner_delta = blend(0.05),
    border_hover_delta = blend(0.10),
    border_active_delta = blend(0.15),
    border_focus_delta = blend(0.20),

    -- Text
    text_hover_delta = blend(0.05),
    text_dimmed_delta = blend(-0.10),
    text_dark_delta = blend(-0.20),
    text_bright_delta = blend(0.10),

    -- Accents
    accent_bright_delta = blend(0.15),
    accent_white_lightness = blend(0.25),
    accent_white_bright_lightness = blend(0.35),

    -- Tile rendering
    tile_fill_brightness = blend(0.5),
    tile_fill_saturation = blend(0.4),
    tile_fill_opacity = blend(0.4),
  },

  -- GREY preset (medium, ~24% lightness)
  grey = {
    bg_hover_delta = blend(0.025),
    bg_active_delta = blend(0.04),
    bg_header_delta = blend(-0.024),
    bg_panel_delta = blend(-0.04),

    pattern_primary_delta = blend(-0.03),
    pattern_secondary_delta = blend(-0.006),

    border_outer_color = step("#000000"),
    border_outer_opacity = blend(0.75),
    border_inner_delta = blend(0.05),
    border_hover_delta = blend(0.10),
    border_active_delta = blend(0.15),
    border_focus_delta = blend(0.20),

    text_hover_delta = blend(0.05),
    text_dimmed_delta = blend(-0.10),
    text_dark_delta = blend(-0.20),
    text_bright_delta = blend(0.10),

    accent_bright_delta = blend(0.15),
    accent_white_lightness = blend(0.30),
    accent_white_bright_lightness = blend(0.40),

    tile_fill_brightness = blend(0.55),
    tile_fill_saturation = blend(0.45),
    tile_fill_opacity = blend(0.45),
  },

  -- WHITE preset (bright, ~88% lightness)
  white = {
    bg_hover_delta = blend(-0.04),
    bg_active_delta = blend(-0.07),
    bg_header_delta = blend(-0.06),
    bg_panel_delta = blend(-0.04),

    pattern_primary_delta = blend(-0.06),
    pattern_secondary_delta = blend(-0.02),

    border_outer_color = step("#404040"),
    border_outer_opacity = blend(0.60),
    border_inner_delta = blend(-0.03),
    border_hover_delta = blend(-0.08),
    border_active_delta = blend(-0.12),
    border_focus_delta = blend(-0.15),

    text_hover_delta = blend(-0.05),
    text_dimmed_delta = blend(0.15),
    text_dark_delta = blend(0.25),
    text_bright_delta = blend(-0.08),

    accent_bright_delta = blend(-0.12),
    accent_white_lightness = blend(0.55),
    accent_white_bright_lightness = blend(0.45),

    tile_fill_brightness = blend(1.4),
    tile_fill_saturation = blend(0.5),
    tile_fill_opacity = blend(0.5),
  },
}

-- ============================================================================
-- CONTRAST MODES (dark/light)
-- ============================================================================
-- Binary contrast modes for flipAt() - used for values that need hard contrast
-- (like text colors that must be readable regardless of background).
-- flipAt(threshold, value) flips between dark/light when bg crosses threshold.

M.contrast = {
  -- DARK contrast mode (bg lightness < threshold)
  dark = {
    tile_name_color = flipAt(0.5, "#DDE3E9"),  -- Light text on dark
  },

  -- LIGHT contrast mode (bg lightness >= threshold)
  light = {
    tile_name_color = flipAt(0.5, "#1A1A1A"),  -- Dark text on light
  },
}

-- ============================================================================
-- LEGACY COMPATIBILITY
-- ============================================================================
-- Map old theme_rules to new presets for backwards compatibility
M.theme_rules = {
  dark = M.presets.black,
  grey = M.presets.grey,
  light = M.presets.white,
}

-- Anchor lightness values for each theme preset
-- Used for interpolation in adapt mode
M.preset_anchors = {
  black = 0.14,  -- ~14% lightness (black preset)
  grey = 0.24,   -- ~24% lightness (grey preset)
  white = 0.88,  -- ~88% lightness (white preset)
}

-- Legacy alias
M.theme_anchors = M.preset_anchors

--- Extract raw value from wrapper or return as-is
--- @param wrapped any Wrapped value or raw value
--- @return any Raw value
local function unwrap(wrapped)
  if type(wrapped) == "table" and wrapped.mode then
    return wrapped.value
  end
  return wrapped
end

--- Get interpolation mode from wrapper
--- @param wrapped any Wrapped value or raw value
--- @return string Mode ("blend", "step", or "blend" for raw values)
local function get_mode(wrapped)
  if type(wrapped) == "table" and wrapped.mode then
    return wrapped.mode
  end
  return "blend"  -- Default: raw values blend
end

--- Interpolate between two rule sets respecting wrapper modes
--- @param rules_a table First rule set (preset)
--- @param rules_b table Second rule set (preset)
--- @param t number Interpolation factor (0.0 = rules_a, 1.0 = rules_b)
--- @return table Interpolated rules (unwrapped raw values)
local function lerp_rules(rules_a, rules_b, t)
  local result = {}

  for key, wrapped_a in pairs(rules_a) do
    local wrapped_b = rules_b[key]
    local value_a = unwrap(wrapped_a)
    local value_b = unwrap(wrapped_b)
    local mode = get_mode(wrapped_a)

    if mode == "step" then
      -- Step: no interpolation, use closest preset's value
      result[key] = t < 0.5 and value_a or value_b

    elseif mode == "blend" then
      -- Blend: smooth interpolation
      if type(value_a) == "number" and type(value_b) == "number" then
        result[key] = value_a + (value_b - value_a) * t
      elseif type(value_a) == "string" and type(value_b) == "string" then
        -- Lerp colors (hex strings like "#RRGGBB")
        local color_a = Colors.hexrgb(value_a)
        local color_b = Colors.hexrgb(value_b)
        result[key] = Colors.lerp(color_a, color_b, t)
        -- Convert back to hex string for consistency
        local r, g, b = Colors.rgba_to_components(result[key])
        result[key] = string.format("#%02X%02X%02X", r, g, b)
      else
        -- Non-interpolatable, use closest
        result[key] = t < 0.5 and value_a or value_b
      end

    else
      -- Unknown mode, treat as blend
      result[key] = t < 0.5 and value_a or value_b
    end
  end

  return result
end

--- Resolve contrast values (flipAt) based on current lightness
--- @param lightness number Current background lightness (0.0-1.0)
--- @return table Resolved contrast values (unwrapped)
local function resolve_contrast(lightness)
  local result = {}

  for key, wrapped_dark in pairs(M.contrast.dark) do
    local wrapped_light = M.contrast.light[key]
    local value_dark = unwrap(wrapped_dark)
    local value_light = unwrap(wrapped_light)

    -- Get threshold from the wrapper (default 0.5)
    local threshold = 0.5
    if type(wrapped_dark) == "table" and wrapped_dark.threshold then
      threshold = wrapped_dark.threshold
    end

    -- Flip at threshold
    result[key] = lightness < threshold and value_dark or value_light
  end

  return result
end

--- Unwrap all values in a preset (for non-interpolated access)
--- @param preset table Preset with wrapped values
--- @return table Unwrapped raw values
local function unwrap_preset(preset)
  local result = {}
  for key, wrapped in pairs(preset) do
    result[key] = unwrap(wrapped)
  end
  return result
end

--- Get derivation rules for current theme mode
--- For explicit modes (dark/grey/light), returns those rules directly.
--- For "adapt" mode, interpolates between anchor rules based on current lightness.
--- Also merges in contrast values (flipAt) for contrast-critical keys.
--- @return table Rules table for the current theme (unwrapped raw values)
function M.get_current_rules()
  return compute_rules_for_lightness(M.get_theme_lightness(), M.current_mode)
end

--- Get current theme's base lightness (0.0-1.0)
--- @return number Lightness of current BG_BASE
function M.get_theme_lightness()
  if not Style.COLORS.BG_BASE then return 0.14 end  -- Default to dark
  local _, _, l = Colors.rgb_to_hsl(Style.COLORS.BG_BASE)
  return l
end

--- Compute interpolated rules for a given lightness value
--- This is the core interpolation logic used by both generate_palette and get_current_rules
--- @param lightness number Background lightness (0.0-1.0)
--- @param mode string|nil Theme mode ("dark", "grey", "light", "adapt", or nil for adapt)
--- @return table Interpolated rules (unwrapped raw values)
local function compute_rules_for_lightness(lightness, mode)
  local preset_rules

  -- Get preset rules based on mode
  if mode == "dark" then
    preset_rules = unwrap_preset(M.presets.black)
  elseif mode == "grey" then
    preset_rules = unwrap_preset(M.presets.grey)
  elseif mode == "light" then
    preset_rules = unwrap_preset(M.presets.white)
  else
    -- "adapt" mode or nil: interpolate based on lightness
    if lightness <= M.preset_anchors.black then
      preset_rules = unwrap_preset(M.presets.black)
    elseif lightness >= M.preset_anchors.white then
      preset_rules = unwrap_preset(M.presets.white)
    elseif lightness <= M.preset_anchors.grey then
      local range = M.preset_anchors.grey - M.preset_anchors.black
      local t = (lightness - M.preset_anchors.black) / range
      preset_rules = lerp_rules(M.presets.black, M.presets.grey, t)
    else
      local range = M.preset_anchors.white - M.preset_anchors.grey
      local t = (lightness - M.preset_anchors.grey) / range
      preset_rules = lerp_rules(M.presets.grey, M.presets.white, t)
    end
  end

  -- Merge in contrast values (flipAt) based on lightness
  local contrast_values = resolve_contrast(lightness)
  for key, value in pairs(contrast_values) do
    preset_rules[key] = value
  end

  return preset_rules
end

-- Legacy compatibility: keep derivation_rules pointing to black preset
M.derivation_rules = unwrap_preset(M.presets.black)

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
  -- Contrast values (flipAt) are automatically merged in
  if not rules then
    rules = compute_rules_for_lightness(bg_lightness, M.current_mode)
  end

  -- Calculate chrome color (titlebar/statusbar) - always significantly darker than content
  local chrome_lightness
  if is_light then
    chrome_lightness = bg_lightness - 0.15  -- 15% darker for light themes
  else
    chrome_lightness = bg_lightness * 0.42  -- ~42% of content brightness for dark/grey
  end
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

    -- Status colors (fixed for semantic meaning)
    ACCENT_SUCCESS = Colors.hexrgb("#4CAF50"),
    ACCENT_WARNING = Colors.hexrgb("#FFA726"),
    ACCENT_DANGER = Colors.hexrgb("#EF5350"),

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
  }
end

--- Apply a color palette to Style.COLORS
--- @param palette table Color palette from generate_palette()
local function apply_palette(palette)
  for key, value in pairs(palette) do
    Style.COLORS[key] = value
  end
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

return M
