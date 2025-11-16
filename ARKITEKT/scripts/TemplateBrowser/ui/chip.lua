-- @noindex
-- TemplateBrowser/ui/chip.lua
-- Simplified colored chip component for templates
-- Local version to avoid merge issues

local ImGui = require 'imgui' '0.10'
local M = {}

-- Convert hex color string to RGBA
local function hexrgb(hex)
  hex = hex:gsub("#", "")
  local r = tonumber(hex:sub(1, 2), 16)
  local g = tonumber(hex:sub(3, 4), 16)
  local b = tonumber(hex:sub(5, 6), 16)
  local a = 255
  return (r << 24) | (g << 16) | (b << 8) | a
end

-- Apply brightness adjustment
local function adjust_brightness(color, factor)
  local r = ((color >> 24) & 0xFF)
  local g = ((color >> 16) & 0xFF)
  local b = ((color >> 8) & 0xFF)
  local a = (color & 0xFF)

  r = math.min(255, math.floor(r * factor))
  g = math.min(255, math.floor(g * factor))
  b = math.min(255, math.floor(b * factor))

  return (r << 24) | (g << 16) | (b << 8) | a
end

-- Apply alpha to color
local function with_alpha(color, alpha)
  return (color & 0xFFFFFF00) | (alpha & 0xFF)
end

-- Render glow effect
local function render_glow(dl, center_x, center_y, radius, color, layers)
  layers = layers or 6
  local max_alpha = 90
  local spread = 5
  local base_color_rgb = color & 0xFFFFFF00

  for i = layers, 1, -1 do
    local t = i / layers
    local alpha_multiplier = (1.0 - t) * (1.0 - t)
    local current_alpha = math.floor(max_alpha * alpha_multiplier)
    local current_radius = radius + (t * spread)

    if current_alpha > 0 then
      local glow_color = base_color_rgb | current_alpha
      ImGui.DrawList_AddCircleFilled(dl, center_x, center_y, current_radius, glow_color)
    end
  end
end

-- Draw a colored indicator chip (circle)
-- opts: {
--   x, y: position
--   radius: circle radius (default 4)
--   color: 32-bit RGBA color
--   is_selected: highlight if selected
--   is_hovered: highlight if hovered
--   show_glow: show glow effect
--   glow_layers: number of glow layers (default 3)
-- }
function M.draw_indicator(ctx, opts)
  opts = opts or {}
  local dl = opts.draw_list or ImGui.GetWindowDrawList(ctx)
  local x = opts.x or 0
  local y = opts.y or 0
  local radius = opts.radius or 4
  local color = opts.color or hexrgb("#FF5733")
  local is_selected = opts.is_selected or false
  local is_hovered = opts.is_hovered or false
  local show_glow = opts.show_glow
  local glow_layers = opts.glow_layers or 3

  -- Adjust color based on state
  local draw_color = color
  if is_selected then
    draw_color = adjust_brightness(color, 1.15)
  elseif is_hovered then
    draw_color = adjust_brightness(color, 1.2)
  end

  -- Shadow
  ImGui.DrawList_AddCircleFilled(dl, x, y + 1, radius + 1, with_alpha(hexrgb("#000000"), 80))

  -- Glow
  if show_glow then
    render_glow(dl, x, y, radius, draw_color, glow_layers)
  end

  -- Main circle
  ImGui.DrawList_AddCircleFilled(dl, x, y, radius, draw_color)
end

-- Preset color palette (same as RegionPlaylist)
M.PRESET_COLORS = {
  hexrgb("#FF0000"), -- Red
  hexrgb("#FF6000"), -- Red-Orange
  hexrgb("#FF9900"), -- Orange
  hexrgb("#FFCC00"), -- Yellow-Orange
  hexrgb("#FFFF00"), -- Yellow
  hexrgb("#CCFF00"), -- Yellow-Green
  hexrgb("#66FF00"), -- Lime
  hexrgb("#00FF00"), -- Green
  hexrgb("#00FF66"), -- Green-Cyan
  hexrgb("#00FFCC"), -- Cyan-Green
  hexrgb("#00FFFF"), -- Cyan
  hexrgb("#00CCFF"), -- Cyan-Blue
  hexrgb("#0066FF"), -- Blue
  hexrgb("#0000FF"), -- Deep Blue
  hexrgb("#6600FF"), -- Blue-Purple
  hexrgb("#CC00FF"), -- Purple
}

M.hexrgb = hexrgb
M.adjust_brightness = adjust_brightness
M.with_alpha = with_alpha

return M
