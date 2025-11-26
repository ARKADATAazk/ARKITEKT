-- @noindex
-- arkitekt/defs/colors/theme.lua
-- Theme-reactive color definitions (DSL)
--
-- Single source of truth for:
--   - Presets (dark/light base colors)
--   - Anchors (lightness values)
--   - All theme-reactive color definitions

local Colors = require('arkitekt.core.colors')

local M = {}

-- =============================================================================
-- PRESETS
-- =============================================================================
-- Base colors for dark/light themes. Anchors are auto-computed from these.

M.presets = {
  dark       = "#242424",  -- t=0 anchor
  grey       = "#333333",
  light_grey = "#505050",
  light      = "#E0E0E0",  -- t=1 anchor
}

-- =============================================================================
-- VALIDATION
-- =============================================================================

--- Validate hex color format
--- @param hex string Hex color string
--- @param name string Variable name for error messages
--- @return boolean valid, string|nil error_message
local function validate_hex(hex, name)
  if type(hex) ~= "string" then
    return false, string.format("%s: expected string, got %s", name, type(hex))
  end
  if not hex:match("^#[0-9A-Fa-f]+$") then
    return false, string.format("%s: invalid hex format '%s'", name, hex)
  end
  local len = #hex - 1  -- minus the #
  if len ~= 6 and len ~= 8 then
    return false, string.format("%s: hex must be 6 or 8 chars, got %d", name, len)
  end
  return true
end

--- Compute contrast ratio between two colors (WCAG formula)
--- @param color1 number RGBA color
--- @param color2 number RGBA color
--- @return number Contrast ratio (1.0 to 21.0)
local function contrast_ratio(color1, color2)
  local l1 = Colors.luminance(color1)
  local l2 = Colors.luminance(color2)
  local lighter = math.max(l1, l2)
  local darker = math.min(l1, l2)
  return (lighter + 0.05) / (darker + 0.05)
end

--- Warn if contrast ratio is too low for text readability
--- @param fg_hex string Foreground hex color
--- @param bg_hex string Background hex color
--- @param name string Variable name for warning
--- @param min_ratio number Minimum contrast ratio (default 4.5 for WCAG AA)
local function warn_low_contrast(fg_hex, bg_hex, name, min_ratio)
  min_ratio = min_ratio or 4.5
  local fg = Colors.hexrgb(fg_hex)
  local bg = Colors.hexrgb(bg_hex)
  local ratio = contrast_ratio(fg, bg)
  if ratio < min_ratio then
    reaper.ShowConsoleMsg(string.format(
      "[Theme] Warning: %s has low contrast (%.1f:1, need %.1f:1)\n",
      name, ratio, min_ratio
    ))
  end
end

-- Validate presets on load
for name, hex in pairs(M.presets) do
  local valid, err = validate_hex(hex, "presets." .. name)
  if not valid then
    reaper.ShowConsoleMsg("[Theme] " .. err .. "\n")
  end
end

-- =============================================================================
-- ANCHORS (auto-computed from presets)
-- =============================================================================

local function compute_lightness(hex)
  local color = Colors.hexrgb(hex)
  local _, _, l = Colors.rgb_to_hsl(color)
  return l
end

M.anchors = {
  dark  = compute_lightness(M.presets.dark),
  light = compute_lightness(M.presets.light),
}

-- =============================================================================
-- DSL WRAPPERS
-- =============================================================================
-- Simple DSL - all snap/offset at midpoint (t=0.5):
--   snap(dark, light)        - discrete snap at midpoint
--   lerp(dark, light)        - smooth interpolation
--   offset(dark, [light])    - delta from BG_BASE (light defaults to dark)
--   bg()                     - use BG_BASE directly

local function snap(dark_val, light_val)
  return { mode = "snap", dark = dark_val, light = light_val }
end

local function lerp(dark_val, light_val)
  return { mode = "lerp", dark = dark_val, light = light_val }
end

local function offset(dark_delta, light_delta)
  return { mode = "offset", dark = dark_delta, light = light_delta or dark_delta }
end

local function bg()
  return { mode = "bg" }
end

-- Export wrappers
M.snap = snap
M.lerp = lerp
M.offset = offset
M.bg = bg

-- =============================================================================
-- COLORS (flat structure)
-- =============================================================================
-- The mode determines processing:
--   bg      → use input BG directly
--   offset  → BG-derived (apply delta to BG_BASE)
--   snap    → hex strings = color, numbers = value
--   lerp    → hex strings = color, numbers = value

M.colors = {
  -- === BACKGROUNDS (from BG_BASE) ===
  BG_BASE         = bg(),
  BG_HOVER        = offset(0.03, -0.06),   -- Light: more contrast (was -0.04)
  BG_ACTIVE       = offset(0.05, -0.10),   -- Light: more contrast (was -0.07)
  BG_HEADER       = offset(-0.024, -0.06),
  BG_PANEL        = offset(-0.04),
  BG_CHROME       = offset(-0.08, -0.15),

  -- === BORDERS (from BG_BASE) ===
  -- Increased offsets for more visible contrast (matching older visual style)
  BORDER_INNER    = offset(0.05, -0.03),
  BORDER_HOVER    = offset(0.18, -0.14),   -- was 0.10/-0.08, increased for visible pop
  BORDER_ACTIVE   = offset(0.30, -0.22),   -- was 0.15/-0.12, much brighter on click
  BORDER_FOCUS    = offset(0.25, -0.18),   -- was 0.20/-0.15
  BORDER_OUTER    = snap("#000000", "#404040"),
  BORDER_OUTER_OPACITY = lerp(0.87, 0.60),

  -- === ACCENTS (from BG_BASE) ===
  ACCENT_PRIMARY       = offset(0.15, -0.12),
  ACCENT_TEAL          = offset(0.15, -0.12),
  ACCENT_TEAL_BRIGHT   = offset(0.25, -0.20),
  ACCENT_TRANSPARENT   = offset(0.15, -0.12),
  ACCENT_TRANSPARENT_OPACITY = lerp(0.67, 0.67),

  -- === ACCENTS (standalone) ===
  -- Changed from lerp to offset to guarantee visible contrast from BG_BASE
  -- (lerp created a "dead zone" in mid-range themes like light_grey)
  ACCENT_WHITE        = offset(0.12, -0.15),
  ACCENT_WHITE_BRIGHT = offset(0.20, -0.22),
  ACCENT_SUCCESS = lerp("#4CAF50", "#2E7D32"),
  ACCENT_WARNING = lerp("#FFA726", "#F57C00"),
  ACCENT_DANGER  = lerp("#EF5350", "#C62828"),

  -- === TEXT ===
  TEXT_NORMAL = snap("#FFFFFF", "#000000"),
  TEXT_HOVER  = snap("#F0F0F0", "#1A1A1A"),
  TEXT_ACTIVE = snap("#E8E8E8", "#222222"),
  TEXT_DIMMED = snap("#A0A0A0", "#606060"),
  TEXT_DARK   = snap("#808080", "#808080"),
  TEXT_BRIGHT = snap("#FFFFFF", "#000000"),

  -- === PATTERNS (from BG_BASE, includes panel offset) ===
  PATTERN_PRIMARY   = offset(-0.064, -0.10),
  PATTERN_SECONDARY = offset(-0.044, -0.06),

  -- === TILES ===
  TILE_NAME_COLOR      = snap("#DDE3E9", "#1A1A1A"),
  TILE_FILL_BRIGHTNESS = lerp(0.5, 0.7),   -- Light: darker tiles (was 1.4)
  TILE_FILL_SATURATION = lerp(0.4, 0.7),   -- Light: more saturated (was 0.5)
  TILE_FILL_OPACITY    = lerp(0.4, 0.6),   -- Light: slightly more opaque (was 0.5)

  -- === BADGES ===
  BADGE_BG             = snap("#14181C", "#E8ECF0"),
  BADGE_TEXT           = snap("#FFFFFF", "#1A1A1A"),
  BADGE_BG_OPACITY     = lerp(0.85, 0.90),
  BADGE_BORDER_OPACITY = lerp(0.20, 0.15),

  -- === PLAYLIST ===
  PLAYLIST_TILE_COLOR  = snap("#3A3A3A", "#A0A0A0"),  -- Light: darker for contrast (was #D0D0D0)
  PLAYLIST_NAME_COLOR  = snap("#CCCCCC", "#2A2A2A"),
  PLAYLIST_BADGE_COLOR = snap("#999999", "#666666"),

  -- === OPERATIONS (drag/drop feedback) ===
  OP_MOVE   = snap("#CCCCCC", "#444444"),  -- Gray - move operation
  OP_COPY   = snap("#06B6D4", "#0891B2"),  -- Cyan - copy operation
  OP_DELETE = snap("#E84A4A", "#DC2626"),  -- Red - delete operation
  OP_LINK   = snap("#4A9EFF", "#2563EB"),  -- Blue - link/reference

  -- === COLORED BUTTONS ===
  -- Each variant: BG (base), HOVER (+lightness), ACTIVE (-lightness), TEXT (auto contrast)

  -- Danger (red)
  BUTTON_DANGER_BG     = lerp("#B91C1C", "#FCA5A5"),
  BUTTON_DANGER_HOVER  = lerp("#DC2626", "#FEE2E2"),
  BUTTON_DANGER_ACTIVE = lerp("#991B1B", "#F87171"),
  BUTTON_DANGER_TEXT   = snap("#FFFFFF", "#7F1D1D"),

  -- Success (green)
  BUTTON_SUCCESS_BG     = lerp("#15803D", "#86EFAC"),
  BUTTON_SUCCESS_HOVER  = lerp("#16A34A", "#BBF7D0"),
  BUTTON_SUCCESS_ACTIVE = lerp("#166534", "#4ADE80"),
  BUTTON_SUCCESS_TEXT   = snap("#FFFFFF", "#14532D"),

  -- Warning (amber/orange)
  BUTTON_WARNING_BG     = lerp("#B45309", "#FCD34D"),
  BUTTON_WARNING_HOVER  = lerp("#D97706", "#FDE68A"),
  BUTTON_WARNING_ACTIVE = lerp("#92400E", "#FBBF24"),
  BUTTON_WARNING_TEXT   = snap("#FFFFFF", "#78350F"),

  -- Info (blue)
  BUTTON_INFO_BG     = lerp("#1D4ED8", "#93C5FD"),
  BUTTON_INFO_HOVER  = lerp("#2563EB", "#BFDBFE"),
  BUTTON_INFO_ACTIVE = lerp("#1E40AF", "#60A5FA"),
  BUTTON_INFO_TEXT   = snap("#FFFFFF", "#1E3A8A"),
}

-- =============================================================================
-- UTILITIES
-- =============================================================================

--- Get all color keys
function M.get_all_keys()
  local keys = {}
  for key in pairs(M.colors) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

-- Export validation utilities
M.validate_hex = validate_hex
M.contrast_ratio = contrast_ratio
M.warn_low_contrast = warn_low_contrast

return M
