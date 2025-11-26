-- @noindex
-- arkitekt/defs/colors/theme.lua
-- Theme-reactive color definitions (DSL)
--
-- Single source of truth for:
--   - Presets (dark/light base colors)
--   - Anchors (lightness values)
--   - All theme-reactive color definitions

local M = {}

-- =============================================================================
-- PRESETS
-- =============================================================================
-- Base colors for dark/light themes. Anchors are computed from these.

M.presets = {
  dark       = "#242424",  -- ~14% lightness (t=0)
  grey       = "#333333",  -- ~31% lightness
  light_grey = "#505050",  -- ~56% lightness
  light      = "#E0E0E0",  -- ~88% lightness (t=1)
}

-- Anchors: lightness values for dark/light presets
-- These match the preset hex values above
M.anchors = {
  dark  = 0.14,  -- #242424
  light = 0.88,  -- #E0E0E0
}

-- =============================================================================
-- DSL WRAPPERS
-- =============================================================================
-- Short names with optional threshold parameter:
--   snap(dark, light, [threshold=0.5]) - discrete snap
--   lerp(dark, light)                  - smooth interpolation
--   offset(dark, [light], [threshold=0.5]) - delta from BG_BASE
--   bg() - use BG_BASE directly (passthrough)

local function snap(dark_val, light_val, threshold)
  return { mode = "snap", dark = dark_val, light = light_val, threshold = threshold or 0.5 }
end

local function lerp(dark_val, light_val)
  return { mode = "lerp", dark = dark_val, light = light_val }
end

local function offset(dark_delta, light_delta, threshold)
  if light_delta == nil then
    return { mode = "offset", dark = dark_delta, light = dark_delta, threshold = 0.5 }
  elseif type(light_delta) == "number" and light_delta <= 1 and light_delta >= 0 and threshold == nil then
    -- Could be threshold if light_delta looks like a threshold (0-1) and no third arg
    -- But for clarity, require explicit: offset(0.03) or offset(0.03, -0.04) or offset(0.03, -0.04, 0.3)
    return { mode = "offset", dark = dark_delta, light = light_delta, threshold = 0.5 }
  end
  return { mode = "offset", dark = dark_delta, light = light_delta, threshold = threshold or 0.5 }
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
  BG_HOVER        = offset(0.03, -0.04),
  BG_ACTIVE       = offset(0.05, -0.07),
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
  TILE_FILL_BRIGHTNESS = lerp(0.5, 1.4),
  TILE_FILL_SATURATION = lerp(0.4, 0.5),
  TILE_FILL_OPACITY    = lerp(0.4, 0.5),

  -- === BADGES ===
  BADGE_BG             = snap("#14181C", "#E8ECF0"),
  BADGE_TEXT           = snap("#FFFFFF", "#1A1A1A"),
  BADGE_BG_OPACITY     = lerp(0.85, 0.90),
  BADGE_BORDER_OPACITY = lerp(0.20, 0.15),

  -- === PLAYLIST ===
  PLAYLIST_TILE_COLOR  = snap("#3A3A3A", "#D0D0D0"),
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

return M
