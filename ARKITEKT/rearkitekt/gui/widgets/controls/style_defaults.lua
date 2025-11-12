-- @noindex
-- ReArkitekt/gui/widgets/controls/style_defaults.lua
-- Centralized styling and rendering utilities for all ReArkitekt controls

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb


local M = {}

-- Helper: Convert hex color to integer
local function hexrgb(hex)
  if hex:sub(1, 1) == "#" then hex = hex:sub(2) end
  local h = tonumber(hex, 16)
  if not h then return hexrgb("#FFFFFF") end
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

-- Toggle button style (for PLAY/LOOP/OVERRIDE/FOLLOW states)
M.BUTTON_TOGGLE = {
  -- Normal/OFF state (inherit from BUTTON)
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
  
  -- ON state (toggle active colors)
  bg_on_color = hexrgb("#434343FF"),
  bg_on_hover_color = hexrgb("#484848FF"),
  bg_on_active_color = hexrgb("#3E3E3EFF"),
  border_outer_on_color = hexrgb("#000000DD"),
  border_inner_on_color = hexrgb("#898989FF"),
  border_on_hover_color = hexrgb("#9A9A9AFF"),
  border_on_active_color = hexrgb("#7E7E7EFF"),
  text_on_color = hexrgb("#FFFFFFFF"),
  text_on_hover_color = hexrgb("#FFFFFFFF"),
  text_on_active_color = hexrgb("#FFFFFFFF"),
  
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
  tooltip_delay = 0.5,
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
  enable_mousewheel = true,
  tooltip_delay = 0.5,
  popup = {
    bg_color = hexrgb("#1E1E1EFF"),
    border_color = M.COLORS.BORDER_INNER,
    item_bg_color = hexrgb("#00000000"),
    item_hover_color = M.COLORS.BORDER_INNER,
    item_active_color = hexrgb("#4A4A4AFF"),
    item_text_color = M.COLORS.TEXT_NORMAL,
    item_text_hover_color = M.COLORS.TEXT_HOVER,
    item_selected_color = hexrgb("#3A3A3AFF"),
    item_selected_text_color = M.COLORS.TEXT_HOVER,
    rounding = 4,
    padding = 4,
    item_height = 24,
    item_padding_x = 10,
    border_thickness = 1,
  },
}

M.TOOLTIP = {
  bg_color = hexrgb("#2A2A2AFF"),
  border_color = M.COLORS.BORDER_INNER,
  text_color = hexrgb("#EEEEEEFF"),
  padding_x = 8,
  padding_y = 6,
  rounding = 4,
  border_thickness = 1,
  delay = 0.5,
}

-- ============================================================================
-- RENDERING UTILITIES
-- ============================================================================

M.RENDER = {}

--- Converts corner_rounding config to ImGui corner flags.
--- Logic:
---   - nil corner_rounding = standalone element, return 0 (caller handles default)
---   - corner_rounding exists with flags = specific corners rounded
---   - corner_rounding exists with no flags = middle element, explicitly no rounding
--- @param corner_rounding table|nil Corner rounding configuration from layout engine
--- @return integer ImGui DrawFlags for corner rounding
function M.RENDER.get_corner_flags(corner_rounding)
  -- No corner_rounding config = standalone element (not in panel header)
  -- Return 0 so caller can apply default behavior
  if not corner_rounding then
    return 0
  end
  
  -- Panel context: build flags from individual corner settings
  local flags = 0
  if corner_rounding.round_top_left then
    flags = flags | ImGui.DrawFlags_RoundCornersTopLeft
  end
  if corner_rounding.round_top_right then
    flags = flags | ImGui.DrawFlags_RoundCornersTopRight
  end
  if corner_rounding.round_bottom_left then
    flags = flags | ImGui.DrawFlags_RoundCornersBottomLeft
  end
  if corner_rounding.round_bottom_right then
    flags = flags | ImGui.DrawFlags_RoundCornersBottomRight
  end
  
  -- If flags == 0 here, it means we're in panel context but no corners should round
  -- (middle element in a group). Return RoundCornersNone to explicitly disable rounding.
  if flags == 0 then
    return ImGui.DrawFlags_RoundCornersNone
  end
  
  return flags
end

-- Draw standard double-border control background
function M.RENDER.draw_control_background(dl, x, y, w, h, bg_color, border_inner, border_outer, rounding, corner_flags)
  corner_flags = corner_flags or 0
  local inner_rounding = math.max(0, rounding - 2)
  
  -- Background
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, bg_color, inner_rounding, corner_flags)
  
  -- Inner border
  ImGui.DrawList_AddRect(dl, x + 1, y + 1, x + w - 1, y + h - 1, border_inner, inner_rounding, corner_flags, 1)
  
  -- Outer border
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, border_outer, inner_rounding, corner_flags, 1)
end

-- Get state-based colors for a control
function M.RENDER.get_state_colors(config, is_hovered, is_active)
  local colors = {
    bg = config.bg_color,
    border_inner = config.border_inner_color,
    border_outer = config.border_outer_color,
    text = config.text_color,
  }
  
  if is_active then
    colors.bg = config.bg_active_color or colors.bg
    colors.border_inner = config.border_active_color or colors.border_inner
    colors.text = config.text_active_color or colors.text
  elseif is_hovered then
    colors.bg = config.bg_hover_color or colors.bg
    colors.border_inner = config.border_hover_color or colors.border_inner
    colors.text = config.text_hover_color or colors.text
  end
  
  return colors
end

-- Lerp between two colors
function M.RENDER.lerp_color(a, b, t)
  local ar = (a >> 24) & 0xFF
  local ag = (a >> 16) & 0xFF
  local ab = (a >> 8) & 0xFF
  local aa = a & 0xFF
  
  local br = (b >> 24) & 0xFF
  local bg = (b >> 16) & 0xFF
  local bb = (b >> 8) & 0xFF
  local ba = b & 0xFF
  
  local r = math.floor(ar + (br - ar) * t)
  local g = math.floor(ag + (bg - ag) * t)
  local b = math.floor(ab + (bb - ab) * t)
  local a = math.floor(aa + (ba - aa) * t)
  
  return (r << 24) | (g << 16) | (b << 8) | a
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Apply defaults to user config
function M.apply_defaults(defaults, user_config)
  user_config = user_config or {}
  local result = {}
  
  -- Deep merge for nested tables (like popup config)
  for k, v in pairs(defaults) do
    if type(v) == "table" and type(user_config[k]) == "table" then
      result[k] = M.apply_defaults(v, user_config[k])
    else
      result[k] = user_config[k] ~= nil and user_config[k] or v
    end
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
  local active_key = color_key .. "_active"
  local hover_key = color_key .. "_hover"
  
  if is_active and colors[active_key] then
    return colors[active_key]
  elseif is_hovered and colors[hover_key] then
    return colors[hover_key]
  else
    return colors[color_key]
  end
end

return M
