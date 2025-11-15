-- @noindex
-- ItemPicker/ui/tiles/renderers/base.lua
-- Base tile renderer with shared functionality

local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb
local Draw = require('rearkitekt.gui.draw')
local TileFX = require('rearkitekt.gui.fx.tile_fx')
local MarchingAnts = require('rearkitekt.gui.fx.marching_ants')

local M = {}

M.tile_spawn_times = {}

-- Easing functions
local function ease_out_back(t)
  local c1 = 1.70158
  local c3 = c1 + 1
  return 1 + c3 * (t - 1)^3 + c1 * (t - 1)^2
end

-- Calculate cascade animation factor based on overlay alpha and position
function M.calculate_cascade_factor(rect, overlay_alpha, config)
  if overlay_alpha >= 0.999 then return 1.0 end
  if overlay_alpha <= 0.001 then return 0.0 end

  local x1, y1 = rect[1], rect[2]
  local key = string.format("%.0f_%.0f", x1, y1)

  if not M.tile_spawn_times[key] then
    local grid_x = math.floor(x1 / 150)
    local grid_y = math.floor(y1 / 150)
    local grid_distance = math.sqrt(grid_x * grid_x + grid_y * grid_y)
    M.tile_spawn_times[key] = grid_distance * config.TILE_RENDER.cascade.stagger_delay
  end

  local delay = M.tile_spawn_times[key]
  local adjusted_progress = (overlay_alpha - delay) / (1.0 - delay)
  adjusted_progress = math.max(0.0, math.min(1.0, adjusted_progress))

  return ease_out_back(adjusted_progress)
end

-- Truncate text to fit width
function M.truncate_text(ctx, text, max_width)
  if not text or max_width <= 0 then return "" end
  local text_width = ImGui.CalcTextSize(ctx, text)
  if text_width <= max_width then return text end

  local ellipsis = "..."
  local ellipsis_width = ImGui.CalcTextSize(ctx, ellipsis)
  if max_width <= ellipsis_width then return "" end

  local available_width = max_width - ellipsis_width
  for i = #text, 1, -1 do
    local truncated = text:sub(1, i)
    if ImGui.CalcTextSize(ctx, truncated) <= available_width then
      return truncated .. ellipsis
    end
  end
  return ellipsis
end

-- Get dark waveform color from base color
function M.get_dark_waveform_color(base_color, config)
  local r, g, b = ImGui.ColorConvertU32ToDouble4(base_color)
  local h, s, v = ImGui.ColorConvertRGBtoHSV(r, g, b)

  s = config.TILE_RENDER.waveform.saturation
  v = config.TILE_RENDER.waveform.brightness

  r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, config.TILE_RENDER.waveform.line_alpha)
end

-- Render header bar
function M.render_header_bar(dl, x1, y1, x2, header_height, base_color, alpha, config)
  local r, g, b = ImGui.ColorConvertU32ToDouble4(base_color)
  local h, s, v = ImGui.ColorConvertRGBtoHSV(r, g, b)

  s = s * config.TILE_RENDER.header.saturation_factor
  v = v * config.TILE_RENDER.header.brightness_factor

  r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)

  local final_alpha = math.floor((config.TILE_RENDER.header.alpha / 255) * alpha * 255)
  local header_color = ImGui.ColorConvertDouble4ToU32(r, g, b, final_alpha / 255)

  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y1 + header_height, header_color, config.TILE.ROUNDING)
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y1 + header_height, config.TILE_RENDER.header.text_shadow, config.TILE.ROUNDING)
end

-- Render placeholder with loading spinner
function M.render_placeholder(dl, x1, y1, x2, y2, base_color, alpha)
  local r, g, b = ImGui.ColorConvertU32ToDouble4(base_color)
  local h, s, v = ImGui.ColorConvertRGBtoHSV(r, g, b)

  s = s * 0.3
  v = v * 0.2

  r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)
  local placeholder_color = ImGui.ColorConvertDouble4ToU32(r, g, b, alpha)

  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, placeholder_color)

  -- Spinner
  local center_x = (x1 + x2) / 2
  local center_y = (y1 + y2) / 2
  local size = math.min(x2 - x1, y2 - y1) * 0.15

  local spinner_alpha = math.floor(alpha * 128)
  local spinner_color = Colors.with_alpha(hexrgb("#FFFFFF"), spinner_alpha)

  local time = reaper.time_precise()
  local angle = (time * 2) % (math.pi * 2)

  for i = 0, 7 do
    local a = angle + (i * math.pi / 4)
    local radius = size * (0.3 + 0.7 * ((i + 1) / 8))
    local px = center_x + math.cos(a) * size
    local py = center_y + math.sin(a) * size
    ImGui.DrawList_AddCircleFilled(dl, px, py, radius, spinner_color)
  end
end

-- Render text with badge
function M.render_tile_text(ctx, dl, x1, y1, x2, header_height, item_name, index, total, base_color, text_alpha, config)
  local tile_render = config.TILE_RENDER
  local show_text = header_height >= (tile_render.responsive.hide_text_below - tile_render.header.min_height)
  local show_badge = header_height >= (tile_render.responsive.hide_badge_below - tile_render.header.min_height)

  if not show_text then return end

  local text_x = x1 + tile_render.text.padding_left
  local text_y = y1 + (header_height - ImGui.GetTextLineHeight(ctx)) / 2

  local right_bound_x = x2 - tile_render.text.margin_right
  if show_badge and total and total > 1 then
    local badge_text = string.format("%d/%d", index or 1, total)
    local bw, _ = ImGui.CalcTextSize(ctx, badge_text)
    right_bound_x = right_bound_x - (bw + tile_render.badge.padding_x * 2 + tile_render.badge.margin)
  end

  local available_width = right_bound_x - text_x
  local truncated_name = M.truncate_text(ctx, item_name, available_width)

  Draw.text(dl, text_x, text_y, Colors.with_alpha(tile_render.text.primary_color, text_alpha), truncated_name)

  -- Render badge
  if show_badge and total and total > 1 then
    local badge_text = string.format("%d/%d", index or 1, total)
    local bw, bh = ImGui.CalcTextSize(ctx, badge_text)

    local badge_x = x2 - bw - tile_render.badge.padding_x * 2 - tile_render.badge.margin
    local badge_y = y1 + (header_height - (bh + tile_render.badge.padding_y * 2)) / 2
    local badge_x2 = badge_x + bw + tile_render.badge.padding_x * 2
    local badge_y2 = badge_y + bh + tile_render.badge.padding_y * 2

    local badge_bg_alpha = math.floor((tile_render.badge.bg & 0xFF) * (text_alpha / 255))
    local badge_bg = (tile_render.badge.bg & 0xFFFFFF00) | badge_bg_alpha

    ImGui.DrawList_AddRectFilled(dl, badge_x, badge_y, badge_x2, badge_y2, badge_bg, tile_render.badge.rounding)
    ImGui.DrawList_AddRect(dl, badge_x, badge_y, badge_x2, badge_y2,
      Colors.with_alpha(base_color, tile_render.badge.border_alpha),
      tile_render.badge.rounding, 0, 0.5)

    Draw.text(dl, badge_x + tile_render.badge.padding_x, badge_y + tile_render.badge.padding_y,
      Colors.with_alpha(hexrgb("#FFFFFFDD"), text_alpha), badge_text)
  end
end

return M
