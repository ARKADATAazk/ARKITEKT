-- @noindex
-- ReArkitekt/gui/widgets/controls/style_defaults.lua
-- Centralized styling for all ReArkitekt controls

local M = {}

-- Helper: Convert hex color to integer
local function hexrgb(hex)
  if hex:sub(1, 1) == "#" then hex = hex:sub(2) end
  local h = tonumber(hex, 16)
  if not h then return 0xFFFFFFFF end
  return (#hex == 8) and h or ((h << 8) | 0xFF)
end

-- ============================================================================
-- CORE COLORS (ReArkitekt Palette)
-- ============================================================================

M.COLORS = {
  -- Backgrounds
  BG_BASE = hexrgb("#252525FF"),
  BG_HOVER = hexrgb("#2A2A2AFF"),
  BG_ACTIVE = hexrgb("#303030FF"),
  BG_PANEL = hexrgb("#1A1A1AFF"),
  
  -- Borders
  BORDER_OUTER = hexrgb("#000000DD"),
  BORDER_INNER = hexrgb("#404040FF"),
  BORDER_HOVER = hexrgb("#505050FF"),
  BORDER_ACTIVE = hexrgb("#B0B0B077"),
  BORDER_FOCUS = hexrgb("#7B7B7BFF"),
  
  -- Text
  TEXT_NORMAL = hexrgb("#CCCCCCFF"),
  TEXT_HOVER = hexrgb("#FFFFFFFF"),
  TEXT_ACTIVE = hexrgb("#FFFFFFFF"),
  TEXT_DIMMED = hexrgb("#AAAAAAFF"),
  TEXT_DARK = hexrgb("#707070FF"),
  
  -- Accents
  ACCENT_PRIMARY = hexrgb("#4A9EFF"),
  ACCENT_SUCCESS = hexrgb("#4CAF50"),
  ACCENT_WARNING = hexrgb("#FFA726"),
  ACCENT_DANGER = hexrgb("#EF5350"),
}

-- ============================================================================
-- COMPONENT STYLE PRESETS
-- ============================================================================

M.BUTTON = {
  bg_color = M.COLORS.BG_BASE,
  bg_hover_color = M.COLORS.BG_HOVER,
  bg_active_color = M.COLORS.BG_ACTIVE,
  border_outer_color = M.COLORS.BORDER_OUTER,
  border_inner_color = M.COLORS.BORDER_INNER,
  border_hover_color = M.COLORS.BORDER_HOVER,
  border_active_color = M.COLORS.BORDER_ACTIVE,
  text_color = M.COLORS.TEXT_NORMAL,
  text_hover_color = M.COLORS.TEXT_HOVER,
  text_active_color = M.COLORS.TEXT_ACTIVE,
  padding_x = 10,
  padding_y = 6,
  rounding = 0,
}

M.SEARCH_INPUT = {
  placeholder = "Search...",
  fade_speed = 8.0,
  bg_color = M.COLORS.BG_BASE,
  bg_hover_color = M.COLORS.BG_HOVER,
  bg_active_color = M.COLORS.BG_ACTIVE,
  border_outer_color = M.COLORS.BORDER_OUTER,
  border_inner_color = M.COLORS.BORDER_INNER,
  border_hover_color = M.COLORS.BORDER_HOVER,
  border_active_color = M.COLORS.BORDER_ACTIVE,
  text_color = M.COLORS.TEXT_NORMAL,
  padding_x = 6,
  rounding = 0,
}

M.DROPDOWN = {
  bg_color = M.COLORS.BG_BASE,
  bg_hover_color = M.COLORS.BG_HOVER,
  bg_active_color = M.COLORS.BG_ACTIVE,
  border_outer_color = M.COLORS.BORDER_OUTER,
  border_inner_color = M.COLORS.BORDER_INNER,
  border_hover_color = M.COLORS.BORDER_HOVER,
  border_active_color = M.COLORS.BORDER_ACTIVE,
  text_color = M.COLORS.TEXT_NORMAL,
  text_hover_color = M.COLORS.TEXT_HOVER,
  text_active_color = M.COLORS.TEXT_ACTIVE,
  rounding = 0,
  padding_x = 10,
  padding_y = 6,
  arrow_size = 6,
  arrow_color = M.COLORS.TEXT_NORMAL,
  arrow_hover_color = M.COLORS.TEXT_HOVER,
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Apply defaults to user config
function M.apply_defaults(defaults, user_config)
  user_config = user_config or {}
  local result = {}
  
  for k, v in pairs(defaults) do
    result[k] = user_config[k] ~= nil and user_config[k] or v
  end
  
  -- Add any extra user configs not in defaults
  for k, v in pairs(user_config) do
    if result[k] == nil then
      result[k] = v
    end
  end
  
  return result
end

-- Apply alpha to color
function M.apply_alpha(color, alpha_factor)
  local a = color & 0xFF
  local new_a = math.floor(a * alpha_factor)
  return (color & 0xFFFFFF00) | new_a
end

-- Get state-based color (normal, hover, active)
function M.get_state_color(colors, is_hovered, is_active, color_key)
  if is_active and colors[color_key .. "_active"] then
    return colors[color_key .. "_active"]
  elseif is_hovered and colors[color_key .. "_hover"] then
    return colors[color_key .. "_hover"]
  else
    return colors[color_key]
  end
end

return M