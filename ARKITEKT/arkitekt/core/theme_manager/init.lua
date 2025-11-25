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

-- Derivation rules: how much to adjust colors for different UI states
-- Users can customize these to change the overall theme "feel"
M.derivation_rules = {
  -- Background variations (lightness deltas)
  bg_hover_delta = 0.02,        -- +2% lighter on hover
  bg_active_delta = 0.04,       -- +4% lighter when active/pressed
  bg_panel_delta = -0.04,       -- -4% darker for panels (BG_BASE 36 → BG_PANEL 26)

  -- Pattern variations (relative to BG_PANEL, DARKER = etched lines)
  -- Original design: BG_PANEL=26, Primary=20 (-6 RGB), Secondary=25 (-1 RGB)
  pattern_primary_delta = -0.024,   -- ~-6 RGB units = -2.4% lightness
  pattern_secondary_delta = -0.004, -- ~-1 RGB unit = -0.4% lightness

  -- Border variations
  border_outer_delta = -0.10,   -- -10% darker for outer borders (strong contrast)
  border_inner_delta = 0.05,    -- +5% lighter for inner borders (subtle highlight)
  border_hover_delta = 0.10,    -- +10% lighter on hover
  border_active_delta = 0.15,   -- +15% lighter when active
  border_focus_delta = 0.20,    -- +20% lighter when focused

  -- Text variations
  text_hover_delta = 0.05,      -- +5% lighter on hover
  text_dimmed_delta = -0.10,    -- -10% darker for dimmed/secondary text
  text_dark_delta = -0.20,      -- -20% darker for dark text
  text_bright_delta = 0.10,     -- +10% lighter for bright text

  -- Accent variations
  accent_bright_delta = 0.15,   -- +15% lighter for bright accent variant
  accent_desaturate = -1.0,     -- Fully desaturate for white/gray variant
}

-- ============================================================================
-- CORE: ALGORITHMIC PALETTE GENERATION
-- ============================================================================

--- Generate complete UI color palette from 1-3 base colors
--- @param base_bg number Background color in RGBA format
--- @param base_text number Text color in RGBA format
--- @param base_accent number|nil Optional accent color (nil for neutral grayscale)
--- @return table Color palette with all UI colors
function M.generate_palette(base_bg, base_text, base_accent)
  local rules = M.derivation_rules

  -- Detect if this is a light theme (background lightness > 50%)
  local _, _, bg_lightness = Colors.rgb_to_hsl(base_bg)
  local is_light = bg_lightness > 0.5

  -- Invert deltas for light themes (hover goes darker instead of lighter)
  local sign = is_light and -1 or 1

  -- Calculate chrome color (titlebar/statusbar) - always significantly darker than content
  -- Dark themes (14%): chrome at ~6% (ratio ~0.42)
  -- Grey themes (~24%): chrome at ~10%
  -- Light themes (~88%): chrome at ~73%
  local chrome_lightness
  if is_light then
    chrome_lightness = bg_lightness - 0.15  -- 15% darker for light themes
  else
    chrome_lightness = bg_lightness * 0.42  -- ~42% of content brightness for dark/grey
  end
  chrome_lightness = math.max(0.04, math.min(0.85, chrome_lightness))  -- Clamp
  local base_chrome = Colors.set_lightness(base_bg, chrome_lightness)

  -- For neutral themes (no accent), derive accents from background
  local neutral_accent
  if base_accent == nil then
    -- Create neutral gray "accent" from background
    neutral_accent = Colors.adjust_lightness(base_bg, sign * 0.08)
  else
    neutral_accent = base_accent
  end

  -- Pre-compute BG_PANEL for pattern derivation
  -- Original design: BG_BASE=36 → BG_PANEL=26 (delta -4%)
  local bg_panel = Colors.adjust_lightness(base_bg, rules.bg_panel_delta)

  return {
    -- ============ BACKGROUNDS ============
    -- All derived from base_bg with lightness adjustments
    -- For light themes, hover/active go darker; for dark themes, they go lighter
    BG_BASE = base_bg,
    BG_HOVER = Colors.adjust_lightness(base_bg, sign * rules.bg_hover_delta),
    BG_ACTIVE = Colors.adjust_lightness(base_bg, sign * rules.bg_active_delta),
    BG_PANEL = bg_panel,  -- Slightly darker (used as base for patterns)
    BG_CHROME = base_chrome,  -- Titlebar/statusbar - significantly darker than content
    BG_TRANSPARENT = Colors.with_alpha(base_bg, 0x00),

    -- ============ BORDERS ============
    -- BORDER_OUTER provides contrast - dark for dark themes, medium-dark for light themes
    BORDER_OUTER = is_light
      and Colors.hexrgb("#606060DD")  -- Medium gray for light themes (visible but not harsh)
      or Colors.hexrgb("#000000DD"),   -- Black for dark themes
    BORDER_INNER = Colors.adjust_lightness(base_bg, sign * rules.border_inner_delta),
    BORDER_HOVER = Colors.adjust_lightness(base_bg, sign * rules.border_hover_delta),
    BORDER_ACTIVE = Colors.adjust_lightness(base_bg, sign * rules.border_active_delta),
    BORDER_FOCUS = Colors.adjust_lightness(base_bg, sign * rules.border_focus_delta),

    -- ============ TEXT ============
    -- Text deltas adapt to light/dark context
    TEXT_NORMAL = base_text,
    TEXT_HOVER = Colors.adjust_lightness(base_text, sign * rules.text_hover_delta),
    TEXT_ACTIVE = Colors.adjust_lightness(base_text, sign * rules.text_hover_delta),
    TEXT_DIMMED = Colors.adjust_lightness(base_text, -sign * math.abs(rules.text_dimmed_delta)),
    TEXT_DARK = Colors.adjust_lightness(base_text, -sign * math.abs(rules.text_dark_delta)),
    TEXT_BRIGHT = Colors.adjust_lightness(base_text, sign * rules.text_bright_delta),

    -- ============ ACCENTS ============
    -- Neutral or colored depending on base_accent parameter
    ACCENT_PRIMARY = neutral_accent,
    ACCENT_TEAL = neutral_accent,
    ACCENT_TEAL_BRIGHT = Colors.adjust_lightness(neutral_accent, sign * rules.accent_bright_delta),

    -- White/gray variant for toggle buttons
    -- On dark themes: lighter gray for ON state (contrast against dark bg)
    -- On light themes: darker gray for ON state (contrast against light bg)
    ACCENT_WHITE = is_light
      and Colors.set_lightness(base_bg, 0.55)  -- Medium gray for light themes
      or Colors.set_lightness(base_bg, 0.25),   -- Dark gray for dark themes
    ACCENT_WHITE_BRIGHT = is_light
      and Colors.set_lightness(base_bg, 0.45)  -- Darker on hover for light themes
      or Colors.set_lightness(base_bg, 0.35),   -- Lighter on hover for dark themes

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

--- Set theme by mode name (for UI selectors)
--- @param mode string "dark", "grey", "light", or "adapt"
--- @return boolean Success
function M.set_mode(mode)
  local success = false

  if mode == "adapt" then
    success = M.sync_with_reaper()
  elseif M.themes[mode] then
    success = M.apply_theme(mode)
  end

  if success then
    M.current_mode = mode
  end

  return success
end

--- Get current theme mode
--- @return string|nil
function M.get_mode()
  return M.current_mode
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
