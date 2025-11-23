-- @noindex
-- RegionPlaylist/ui/views/transport/transport_fx.lua
-- Glass transport effects with region gradient background
-- MOVED FROM LIBRARY: Project-specific visual effects for RegionPlaylist

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local Colors = require('arkitekt.core.colors')
local TileFXConfig = require('arkitekt.gui.rendering.tile.defaults')
local hexrgb = Colors.hexrgb

-- Performance: Localize math functions for hot path (30% faster in loops)
local max = math.max
local min = math.min

local M = {}

M.DEFAULT_CONFIG = {
  rounding = 8,
  
  specular = {
    height = 40,
    strength = 0.02,
  },
  
  inner_glow = {
    size = 20,
    strength = 0.08,
  },
  
  border = {
    color = hexrgb("#000000"),
    thickness = 1,
  },
  
  hover = {
    specular_boost = 1.5,
    glow_boost = 1.3,
    transition_speed = 6.0,
  },
  
  gradient = {
    fade_speed = 8.0,
    ready_color = hexrgb("#1A1A1A"),
    fill_opacity = 0.18,
    fill_saturation = 0.35,
    fill_brightness = 0.45,
  },
  
  progress = {
    height = 3,
    track_color = hexrgb("#1D1D1D"),
  },
}

local function process_tile_fill_color(base_color, opacity, saturation, brightness)
  local r, g, b, _ = Colors.rgba_to_components(base_color)

  if saturation ~= 1.0 then
    local gray = r * 0.299 + g * 0.587 + b * 0.114
    r = (r + (gray - r) * (1 - saturation))//1
    g = (g + (gray - g) * (1 - saturation))//1
    b = (b + (gray - b) * (1 - saturation))//1
  end

  if brightness ~= 1.0 then
    r = min(255, max(0, (r * brightness)//1))
    g = min(255, max(0, (g * brightness)//1))
    b = min(255, max(0, (b * brightness)//1))
  end

  local alpha = (255 * opacity)//1
  return Colors.components_to_rgba(r, g, b, alpha)
end

local function process_tile_border_color(base_color)
  local fx_config = TileFXConfig.get()
  local saturation = fx_config.border_saturation
  local brightness = fx_config.border_brightness
  local alpha = 0xFF
  
  return Colors.same_hue_variant(base_color, saturation, brightness, alpha)
end

function M.render_gradient_background(dl, x1, y1, x2, y2, color_left, color_right, rounding, gradient_config, jump_flash_alpha, jump_flash_config)
  jump_flash_alpha = jump_flash_alpha or 0.0
  jump_flash_config = jump_flash_config or {}

  local base_opacity = gradient_config.fill_opacity or 0.25
  local saturation = gradient_config.fill_saturation or 0.35
  local brightness = gradient_config.fill_brightness or 0.45
  local max_opacity = jump_flash_config.max_opacity or 0.85

  -- Boost opacity heavily during jump flash (base -> max)
  local opacity = base_opacity + (max_opacity - base_opacity) * jump_flash_alpha

  local processed_left = process_tile_fill_color(color_left, opacity, saturation, brightness)
  local processed_right = process_tile_fill_color(color_right, opacity, saturation, brightness)

  local r1, g1, b1, a1 = Colors.rgba_to_components(processed_left)
  local r2, g2, b2, a2 = Colors.rgba_to_components(processed_right)

  local color_tl = Colors.components_to_rgba(r1, g1, b1, a1)
  local color_tr = Colors.components_to_rgba(r2, g2, b2, a2)
  local color_bl = Colors.components_to_rgba(r1, g1, b1, a1)
  local color_br = Colors.components_to_rgba(r2, g2, b2, a2)

  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, color_tl, rounding, ImGui.DrawFlags_RoundCornersAll)

  local inset = min(2, rounding * 0.3)
  ImGui.DrawList_PushClipRect(dl, x1, y1, x2, y2, true)
  ImGui.DrawList_AddRectFilledMultiColor(dl, x1 + inset, y1 + inset, x2 - inset, y2 - inset, color_tl, color_tr, color_br, color_bl)
  ImGui.DrawList_PopClipRect(dl)
end

function M.render_progress_gradient(dl, x1, y1, x2, y2, color_left, color_right, rounding)
  local processed_left = process_tile_border_color(color_left)
  local processed_right = process_tile_border_color(color_right)
  
  local r1, g1, b1, a1 = Colors.rgba_to_components(processed_left)
  local r2, g2, b2, a2 = Colors.rgba_to_components(processed_right)

  local boost_factor = 1.15
  r2 = min(255, (r2 * boost_factor)//1)
  g2 = min(255, (g2 * boost_factor)//1)
  b2 = min(255, (b2 * boost_factor)//1)
  
  local color_tl = Colors.components_to_rgba(r1, g1, b1, a1)
  local color_tr = Colors.components_to_rgba(r2, g2, b2, a2)
  local color_bl = Colors.components_to_rgba(r1, g1, b1, a1)
  local color_br = Colors.components_to_rgba(r2, g2, b2, a2)
  
  ImGui.DrawList_AddRectFilledMultiColor(dl, x1, y1, x2, y2, color_tl, color_tr, color_br, color_bl)
end

function M.render_specular(dl, x1, y1, x2, y2, config, hover_factor)
  hover_factor = hover_factor or 0
  local spec_cfg = config.specular
  
  local strength = spec_cfg.strength * (1.0 + hover_factor * (config.hover.specular_boost - 1.0))
  local spec_y2 = y1 + spec_cfg.height

  local alpha_top = (255 * strength)//1
  local color_top = Colors.components_to_rgba(255, 255, 255, alpha_top)
  local color_bottom = Colors.components_to_rgba(255, 255, 255, 0)
  
  ImGui.DrawList_PushClipRect(dl, x1, y1, x2, y2, true)
  ImGui.DrawList_AddRectFilledMultiColor(dl, x1, y1, x2, spec_y2,
    color_top, color_top, color_bottom, color_bottom)
  ImGui.DrawList_PopClipRect(dl)
end

function M.render_inner_glow(dl, x1, y1, x2, y2, config, hover_factor)
  hover_factor = hover_factor or 0
  local glow_cfg = config.inner_glow
  
  local strength = glow_cfg.strength * (1.0 + hover_factor * (config.hover.glow_boost - 1.0))
  local size = glow_cfg.size
  local alpha = (255 * strength)//1
  
  local shadow_color = Colors.components_to_rgba(0, 0, 0, alpha)
  local transparent = Colors.components_to_rgba(0, 0, 0, 0)
  
  ImGui.DrawList_PushClipRect(dl, x1, y1, x2, y2, true)
  
  ImGui.DrawList_AddRectFilledMultiColor(dl,
    x1, y1,
    x2, y1 + size,
    shadow_color, shadow_color, transparent, transparent)
  
  ImGui.DrawList_AddRectFilledMultiColor(dl,
    x1, y1,
    x1 + size, y2,
    shadow_color, transparent, transparent, shadow_color)
  
  ImGui.DrawList_AddRectFilledMultiColor(dl,
    x2 - size, y1,
    x2, y2,
    transparent, shadow_color, shadow_color, transparent)
  
  ImGui.DrawList_AddRectFilledMultiColor(dl,
    x1, y2 - size,
    x2, y2,
    transparent, transparent, shadow_color, shadow_color)
  
  ImGui.DrawList_PopClipRect(dl)
end

function M.render_border(dl, x1, y1, x2, y2, config)
  local border_cfg = config.border
  ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, border_cfg.color, config.rounding, ImGui.DrawFlags_RoundCornersAll, border_cfg.thickness)
end

---Renders complete transport FX including gradient, specular, glow, and border
---@param dl any ImGui DrawList
---@param x1 number Left position
---@param y1 number Top position
---@param x2 number Right position
---@param y2 number Bottom position
---@param config table FX configuration
---@param hover_factor number Hover alpha (0-1)
---@param current_region_color number Current region color (RGBA)
---@param next_region_color number|nil Next region color (RGBA) or nil
---@param jump_flash_alpha number Jump flash alpha (0-1)
function M.render_complete(dl, x1, y1, x2, y2, config, hover_factor, current_region_color, next_region_color, jump_flash_alpha)
  config = config or M.DEFAULT_CONFIG
  hover_factor = hover_factor or 0
  jump_flash_alpha = jump_flash_alpha or 0

  local color_left, color_right

  if current_region_color and next_region_color then
    color_left = current_region_color
    color_right = next_region_color
  elseif current_region_color then
    color_left = current_region_color
    color_right = hexrgb("#000000")
  else
    local ready_color = config.gradient.ready_color or hexrgb("#1A1A1A")
    color_left = ready_color
    color_right = ready_color
  end

  M.render_gradient_background(dl, x1, y1, x2, y2, color_left, color_right, config.rounding, config.gradient, jump_flash_alpha, config.jump_flash)

  M.render_specular(dl, x1, y1, x2, y2, config, hover_factor)
  M.render_inner_glow(dl, x1, y1, x2, y2, config, hover_factor)
  M.render_border(dl, x1, y1, x2, y2, config)
end

return M
