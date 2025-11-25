-- @noindex
-- Arkitekt/core/theme_manager/init.lua
-- Dynamic theme system with algorithmic color palette generation
--
-- Generates entire UI color palettes from 1-3 base colors using HSL manipulation.
-- Supports REAPER theme auto-sync and manual theme presets.
--
-- Usage:
--   local ThemeManager = require('arkitekt.core.theme_manager')
--
--   -- Sync with REAPER's current theme (auto-generates 25+ colors from 2-3 base colors)
--   ThemeManager.sync_with_reaper()
--
--   -- Or apply a manual theme preset
--   ThemeManager.apply_theme("dark")
--
--   -- Or generate from custom colors
--   ThemeManager.generate_and_apply(base_bg, base_text, base_accent)

local Colors = require('arkitekt.core.colors')
local Style = require('arkitekt.gui.style.defaults')

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
  bg_panel_delta = -0.02,       -- -2% darker for panels

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
--- @param base_accent number|nil Optional accent color (defaults to teal)
--- @return table Color palette with all UI colors
function M.generate_palette(base_bg, base_text, base_accent)
  base_accent = base_accent or Colors.hexrgb("#41E0A3FF")  -- Default teal

  local rules = M.derivation_rules

  return {
    -- ============ BACKGROUNDS ============
    -- All derived from base_bg with lightness adjustments
    BG_BASE = base_bg,
    BG_HOVER = Colors.adjust_lightness(base_bg, rules.bg_hover_delta),
    BG_ACTIVE = Colors.adjust_lightness(base_bg, rules.bg_active_delta),
    BG_PANEL = Colors.adjust_lightness(base_bg, rules.bg_panel_delta),
    BG_TRANSPARENT = Colors.with_alpha(base_bg, 0x00),

    -- ============ BORDERS ============
    -- Derived from base_bg with different lightness
    BORDER_OUTER = Colors.adjust_lightness(base_bg, rules.border_outer_delta),
    BORDER_INNER = Colors.adjust_lightness(base_bg, rules.border_inner_delta),
    BORDER_HOVER = Colors.adjust_lightness(base_bg, rules.border_hover_delta),
    BORDER_ACTIVE = Colors.adjust_lightness(base_bg, rules.border_active_delta),
    BORDER_FOCUS = Colors.adjust_lightness(base_bg, rules.border_focus_delta),

    -- ============ TEXT ============
    -- All derived from base_text with lightness adjustments
    TEXT_NORMAL = base_text,
    TEXT_HOVER = Colors.adjust_lightness(base_text, rules.text_hover_delta),
    TEXT_ACTIVE = Colors.adjust_lightness(base_text, rules.text_hover_delta),
    TEXT_DIMMED = Colors.adjust_lightness(base_text, rules.text_dimmed_delta),
    TEXT_DARK = Colors.adjust_lightness(base_text, rules.text_dark_delta),
    TEXT_BRIGHT = Colors.adjust_lightness(base_text, rules.text_bright_delta),

    -- ============ ACCENTS ============
    -- Derived from base_accent with saturation/lightness adjustments
    ACCENT_PRIMARY = base_accent,
    ACCENT_TEAL = base_accent,
    ACCENT_TEAL_BRIGHT = Colors.adjust_lightness(base_accent, rules.accent_bright_delta),

    -- White/gray variant (fully desaturated accent)
    ACCENT_WHITE = Colors.adjust_saturation(base_accent, rules.accent_desaturate),
    ACCENT_WHITE_BRIGHT = Colors.adjust_lightness(
      Colors.adjust_saturation(base_accent, rules.accent_desaturate),
      0.20
    ),

    -- Transparent variant (for overlays)
    ACCENT_TRANSPARENT = Colors.with_alpha(base_accent, 0xAA),

    -- Status colors (fixed for semantic meaning, could be derived in future)
    ACCENT_SUCCESS = Colors.hexrgb("#4CAF50"),
    ACCENT_WARNING = Colors.hexrgb("#FFA726"),
    ACCENT_DANGER = Colors.hexrgb("#EF5350"),
  }
end

--- Apply a color palette to Style.COLORS
--- @param palette table Color palette from generate_palette()
local function apply_palette(palette)
  for key, value in pairs(palette) do
    Style.COLORS[key] = value
  end
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

--- Convert REAPER color format (0xRRGGBB) to ImGui format (0xRRGGBBAA)
--- @param reaper_color number REAPER color in RGB format
--- @return number|nil ImGui color in RGBA format, or nil on error
local function reaper_to_imgui(reaper_color)
  if reaper_color == -1 then
    return nil  -- Failed to get color
  end
  -- REAPER: 0x00RRGGBB (no alpha)
  -- ImGui:  0xRRGGBBAA (with alpha)
  return (reaper_color << 8) | 0xFF  -- Shift left 8 bits, add full opacity
end

--- Sync theme colors with REAPER's current theme (minimal approach)
--- Reads only 2 colors (main_bg + arrange_bg), extracts contrast intent,
--- generates neutral grayscale palette for maximum theme compatibility
--- @return boolean Success (true if colors were read and applied)
function M.sync_with_reaper()
  -- Read only 2 background colors
  local main_bg_raw = reaper.GetThemeColor("col_main_bg2", 0)      -- Main window bg
  local arrange_bg_raw = reaper.GetThemeColor("col_arrangebg", 0)  -- Arrange view bg

  if main_bg_raw == -1 then
    return false  -- Failed to read REAPER theme
  end

  -- Convert to ImGui format
  local main_bg = reaper_to_imgui(main_bg_raw)
  local arrange_bg = arrange_bg_raw ~= -1 and reaper_to_imgui(arrange_bg_raw) or main_bg

  -- Extract lightness values
  local main_h, main_s, main_l = Colors.rgb_to_hsl(main_bg)
  local arrange_h, arrange_s, arrange_l = Colors.rgb_to_hsl(arrange_bg)

  -- Calculate contrast delta between main and arrange
  -- Some themes have white arrange + gray main (extreme), clamp to reasonable range
  local contrast_delta = arrange_l - main_l
  local max_delta = 0.10  -- Clamp to ±10% lightness difference
  contrast_delta = math.max(-max_delta, math.min(max_delta, contrast_delta))

  -- Determine theme type
  local is_dark = main_l < 0.5

  -- Generate text color (auto white on dark, black on light)
  local base_text = Colors.auto_text_color(main_bg)

  -- Generate palette with NO accent (neutral grayscale)
  -- This keeps ARKITEKT theme-agnostic, works with any REAPER theme
  local palette = M.generate_palette(main_bg, base_text, nil)

  -- Override BG_PANEL with extracted arrange bg (respects REAPER's actual delta)
  palette.BG_PANEL = Colors.adjust_lightness(main_bg, contrast_delta)

  -- Adjust hover/active using contrast preference
  local hover_delta = is_dark and 0.02 or -0.02  -- Lighter on dark, darker on light
  palette.BG_HOVER = Colors.adjust_lightness(main_bg, hover_delta)
  palette.BG_ACTIVE = Colors.adjust_lightness(main_bg, hover_delta * 2)

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
M.themes = {
  -- Default dark theme (current ARKITEKT colors)
  dark = function()
    return M.generate_palette(
      Colors.hexrgb("#252525FF"),  -- Dark gray background
      Colors.hexrgb("#CCCCCCFF"),  -- Light gray text
      Colors.hexrgb("#41E0A3FF")   -- Teal accent
    )
  end,

  -- Light theme
  light = function()
    return M.generate_palette(
      Colors.hexrgb("#E5E5E5FF"),  -- Light gray background
      Colors.hexrgb("#333333FF"),  -- Dark text
      Colors.hexrgb("#2F9984FF")   -- Darker teal for better contrast on light bg
    )
  end,

  -- Midnight (very dark)
  midnight = function()
    return M.generate_palette(
      Colors.hexrgb("#0A0A0AFF"),  -- Almost black
      Colors.hexrgb("#AAAAAAFF"),  -- Medium gray text
      Colors.hexrgb("#6B9EFF")     -- Blue accent
    )
  end,

  -- Pro Tools inspired
  pro_tools = function()
    return M.generate_palette(
      Colors.hexrgb("#3D3D3DFF"),  -- Medium dark gray (PT background)
      Colors.hexrgb("#D4D4D4FF"),  -- Off-white text
      Colors.hexrgb("#5FB4F0FF")   -- PT blue
    )
  end,

  -- Ableton inspired (dark with warm accent)
  ableton = function()
    return M.generate_palette(
      Colors.hexrgb("#1A1A1AFF"),  -- Very dark gray
      Colors.hexrgb("#CCCCCCFF"),  -- Light text
      Colors.hexrgb("#FF764D")     -- Ableton orange
    )
  end,

  -- FL Studio inspired (dark with purple)
  fl_studio = function()
    return M.generate_palette(
      Colors.hexrgb("#2B2B2BFF"),  -- Dark gray
      Colors.hexrgb("#E0E0E0FF"),  -- Light text
      Colors.hexrgb("#B24BF3")     -- FL purple
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
