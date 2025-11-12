-- @noindex
-- ReArkitekt/gui/widgets/transport/transport_fx.lua
-- Glass transport effects with region gradient background

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local Colors = require('rearkitekt.core.colors')
local TileFXConfig = require('rearkitekt.gui.fx.tile_fx_config')
local hexrgb = Colors.hexrgb

local M = {}

M.DEFAULT_CONFIG = {
  rounding = 8,
  
  specular = {
    height = 40,
    strength = 0.02,
  },
  
  inner_glow = {
    size = 20,
    strength = 0.08,  -- Reduced from 0.15 for subtler shadows
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
    fill_opacity = 0.18,  -- Reduced from 0.25 for more transparency
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
  
  -- Apply saturation
  if saturation ~= 1.0 then
    local gray = r * 0.299 + g * 0.587 + b * 0.114
    r = math.floor(r + (gray - r) * (1 - saturation))
    g = math.floor(g + (gray - g) * (1 - saturation))
    b = math.floor(b + (gray - b) * (1 - saturation))
  end
  
  -- Apply brightness
  if brightness ~= 1.0 then
    r = math.min(255, math.max(0, math.floor(r * brightness)))
    g = math.min(255, math.max(0, math.floor(g * brightness)))
    b = math.min(255, math.max(0, math.floor(b * brightness)))
  end
  
  local alpha = math.floor(255 * opacity)
  return Colors.components_to_rgba(r, g, b, alpha)
end

local function process_tile_border_color(base_color)
  local fx_config = TileFXConfig.get()
  local saturation = fx_config.border_saturation
  local brightness = fx_config.border_brightness
  local alpha = 0xFF
  
  return Colors.same_hue_variant(base_color, saturation, brightness, alpha)
end

function M.render_gradient_background(dl, x1, y1, x2, y2, color_left, color_right, rounding, gradient_config)
  -- Process colors using tile fill parameters
  local opacity = gradient_config.fill_opacity or 0.25
  local saturation = gradient_config.fill_saturation or 0.35
  local brightness = gradient_config.fill_brightness or 0.45
  
  local processed_left = process_tile_fill_color(color_left, opacity, saturation, brightness)
  local processed_right = process_tile_fill_color(color_right, opacity, saturation, brightness)
  
  local r1, g1, b1, a1 = Colors.rgba_to_components(processed_left)
  local r2, g2, b2, a2 = Colors.rgba_to_components(processed_right)
  
  local color_tl = Colors.components_to_rgba(r1, g1, b1, a1)
  local color_tr = Colors.components_to_rgba(r2, g2, b2, a2)
  local color_bl = Colors.components_to_rgba(r1, g1, b1, a1)
  local color_br = Colors.components_to_rgba(r2, g2, b2, a2)
  
  -- Draw rounded rectangle background first with proper corner flags
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, color_tl, rounding, ImGui.DrawFlags_RoundCornersAll)
  
  -- Inset gradient on all sides to stay inside rounded corners
  local inset = math.min(2, rounding * 0.3)
  ImGui.DrawList_PushClipRect(dl, x1, y1, x2, y2, true)
  ImGui.DrawList_AddRectFilledMultiColor(dl, x1 + inset, y1 + inset, x2 - inset, y2 - inset, color_tl, color_tr, color_br, color_bl)
  ImGui.DrawList_PopClipRect(dl)
end

function M.render_progress_gradient(dl, x1, y1, x2, y2, color_left, color_right, rounding)
  -- Process colors using tile border parameters (brighter/saturated)
  local processed_left = process_tile_border_color(color_left)
  local processed_right = process_tile_border_color(color_right)
  
  local r1, g1, b1, a1 = Colors.rgba_to_components(processed_left)
  local r2, g2, b2, a2 = Colors.rgba_to_components(processed_right)
  
  -- Balance the gradient by boosting the right side (next region) slightly
  -- This compensates for the visual perception that left appears stronger
  local boost_factor = 1.15  -- 15% boost to right side
  r2 = math.min(255, math.floor(r2 * boost_factor))
  g2 = math.min(255, math.floor(g2 * boost_factor))
  b2 = math.min(255, math.floor(b2 * boost_factor))
  
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
  
  local alpha_top = math.floor(255 * strength)
  local color_top = Colors.components_to_rgba(255, 255, 255, alpha_top)
  local color_bottom = Colors.components_to_rgba(255, 255, 255, 0)
  
  -- Clip specular to rounded rect
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
  local alpha = math.floor(255 * strength)
  
  local shadow_color = Colors.components_to_rgba(0, 0, 0, alpha)
  local transparent = Colors.components_to_rgba(0, 0, 0, 0)
  
  -- Clip inner glow to rounded rect
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

function M.render_complete(dl, x1, y1, x2, y2, config, hover_factor, current_region_color, next_region_color)
  config = config or M.DEFAULT_CONFIG
  hover_factor = hover_factor or 0
  
  -- Determine gradient colors
  local color_left, color_right
  
  if current_region_color and next_region_color then
    -- Playing: gradient from current to next region
    color_left = current_region_color
    color_right = next_region_color
  elseif current_region_color then
    -- Last region: gradient to black
    color_left = current_region_color
    color_right = hexrgb("#000000")
  else
    -- Ready state: dark grey
    local ready_color = config.gradient.ready_color or hexrgb("#1A1A1A")
    color_left = ready_color
    color_right = ready_color
  end
  
  -- Render gradient background (this replaces base fill)
  M.render_gradient_background(dl, x1, y1, x2, y2, color_left, color_right, config.rounding, config.gradient)
  
  -- Overlay tile-style effects
  M.render_specular(dl, x1, y1, x2, y2, config, hover_factor)
  M.render_inner_glow(dl, x1, y1, x2, y2, config, hover_factor)
  M.render_border(dl, x1, y1, x2, y2, config)
end

return M
