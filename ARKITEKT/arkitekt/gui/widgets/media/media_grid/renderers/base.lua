-- @noindex
-- arkitekt/gui/widgets/media_grid/renderers/base.lua
-- Base media tile renderer with shared functionality
-- Used by ItemPicker and other media browsing components
--
-- PERF: Call cache_config() once per frame before rendering tiles.
-- Render functions use cached values directly - no fallbacks.

local ImGui = require('arkitekt.platform.imgui')
local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb
local Draw = require('arkitekt.gui.draw.primitives')
local TileFX = require('arkitekt.gui.renderers.tile.renderer')
local MarchingAnts = require('arkitekt.gui.interaction.marching_ants')
local Easing = require('arkitekt.gui.animation.easing')

local M = {}

-- =============================================================================
-- PERF: Per-frame config cache
-- =============================================================================
-- Cache config values once per frame to avoid repeated table lookups.
-- With 1000+ tiles, config.X.Y.Z lookups can consume 30-50% of frame time.

local _cfg = {}
M.cfg = _cfg  -- Expose for render functions

--- Cache config values for the current frame
--- Call once per frame before rendering tiles
--- @param config table The config table to cache values from
function M.cache_config(config)
  -- Responsive thresholds
  if config.responsive then
    _cfg.hide_text_below = config.responsive.hide_text_below
    _cfg.hide_badge_below = config.responsive.hide_badge_below
  end

  -- Header config
  if config.header then
    _cfg.header_min_height = config.header.min_height
    _cfg.header_alpha = config.header.alpha
    _cfg.header_saturation_factor = config.header.saturation_factor
    _cfg.header_brightness_factor = config.header.brightness_factor
    _cfg.header_text_shadow = config.header.text_shadow
  end

  -- Text config
  if config.text then
    _cfg.text_padding_left = config.text.padding_left
    _cfg.text_margin_right = config.text.margin_right
    _cfg.text_primary_color = config.text.primary_color
  end

  -- Badge config
  if config.badge then
    _cfg.badge_padding_x = config.badge.padding_x
    _cfg.badge_padding_y = config.badge.padding_y
    _cfg.badge_margin = config.badge.margin
    _cfg.badge_bg = config.badge.bg
    _cfg.badge_rounding = config.badge.rounding
    _cfg.badge_border_alpha = config.badge.border_alpha
  end

  -- Waveform config
  if config.waveform then
    _cfg.waveform_saturation = config.waveform.saturation
    _cfg.waveform_brightness = config.waveform.brightness
    _cfg.waveform_line_alpha = config.waveform.line_alpha
  end

  -- Cascade config
  if config.cascade then
    _cfg.cascade_stagger_delay = config.cascade.stagger_delay
  end

  -- TILE config
  if config.TILE then
    _cfg.tile_rounding = config.TILE.ROUNDING
  end
end

M.tile_spawn_times = {}

-- Calculate cascade animation factor based on overlay alpha and position
function M.calculate_cascade_factor(rect, overlay_alpha)
  if overlay_alpha >= 0.999 then return 1.0 end
  if overlay_alpha <= 0.001 then return 0.0 end

  local x1, y1 = rect[1], rect[2]
  local key = string.format('%.0f_%.0f', x1, y1)

  if not M.tile_spawn_times[key] then
    local grid_x = (x1 / 150) // 1
    local grid_y = (y1 / 150) // 1
    local grid_distance = math.sqrt(grid_x * grid_x + grid_y * grid_y)
    M.tile_spawn_times[key] = grid_distance * (_cfg.cascade_stagger_delay or 0.02)
  end

  local delay = M.tile_spawn_times[key]
  local adjusted_progress = (overlay_alpha - delay) / (1.0 - delay)
  adjusted_progress = math.max(0.0, math.min(1.0, adjusted_progress))

  return Easing.ease_out_back(adjusted_progress)
end

-- Truncate text to fit width
function M.truncate_text(ctx, text, max_width)
  if not text or max_width <= 0 then return '' end
  local text_width = ImGui.CalcTextSize(ctx, text)
  if text_width <= max_width then return text end

  local ellipsis = '...'
  local ellipsis_width = ImGui.CalcTextSize(ctx, ellipsis)
  if max_width <= ellipsis_width then return '' end

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
function M.get_dark_waveform_color(base_color)
  local r, g, b = ImGui.ColorConvertU32ToDouble4(base_color)
  local h, s, v = ImGui.ColorConvertRGBtoHSV(r, g, b)

  s = _cfg.waveform_saturation
  v = _cfg.waveform_brightness

  r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, _cfg.waveform_line_alpha)
end

-- Render header bar
function M.render_header_bar(dl, x1, y1, x2, header_height, base_color, alpha)
  local r, g, b = ImGui.ColorConvertU32ToDouble4(base_color)
  local h, s, v = ImGui.ColorConvertRGBtoHSV(r, g, b)

  s = s * _cfg.header_saturation_factor
  v = v * _cfg.header_brightness_factor

  r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)

  local final_alpha = Colors.opacity((_cfg.header_alpha / 255) * alpha)
  local header_color = ImGui.ColorConvertDouble4ToU32(r, g, b, final_alpha / 255)

  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y1 + header_height, header_color, _cfg.tile_rounding or 0)
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y1 + header_height, _cfg.header_text_shadow, _cfg.tile_rounding or 0)
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

  local spinner_alpha = (alpha * 128) // 1
  local spinner_color = Colors.with_alpha(hexrgb('#FFFFFF'), spinner_alpha)

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
function M.render_tile_text(ctx, dl, x1, y1, x2, header_height, item_name, index, total, base_color, text_alpha)
  local show_text = header_height >= (_cfg.hide_text_below - _cfg.header_min_height)
  local show_badge = header_height >= (_cfg.hide_badge_below - _cfg.header_min_height)

  if not show_text then return end

  local text_x = x1 + _cfg.text_padding_left
  local text_y = y1 + (header_height - ImGui.GetTextLineHeight(ctx)) / 2

  local right_bound_x = x2 - _cfg.text_margin_right
  if show_badge and total and total > 1 then
    local badge_text = string.format('%d/%d', index or 1, total)
    local bw, _ = ImGui.CalcTextSize(ctx, badge_text)
    right_bound_x = right_bound_x - (bw + _cfg.badge_padding_x * 2 + _cfg.badge_margin)
  end

  local available_width = right_bound_x - text_x
  local truncated_name = M.truncate_text(ctx, item_name, available_width)

  Draw.text(dl, text_x, text_y, Colors.with_alpha(_cfg.text_primary_color, text_alpha), truncated_name)

  -- Render badge
  if show_badge and total and total > 1 then
    local badge_text = string.format('%d/%d', index or 1, total)
    local bw, bh = ImGui.CalcTextSize(ctx, badge_text)

    local badge_x = x2 - bw - _cfg.badge_padding_x * 2 - _cfg.badge_margin
    local badge_y = y1 + (header_height - (bh + _cfg.badge_padding_y * 2)) / 2
    local badge_x2 = badge_x + bw + _cfg.badge_padding_x * 2
    local badge_y2 = badge_y + bh + _cfg.badge_padding_y * 2

    local badge_bg_alpha = ((_cfg.badge_bg & 0xFF) * (text_alpha / 255)) // 1
    local badge_bg_color = (_cfg.badge_bg & 0xFFFFFF00) | badge_bg_alpha

    ImGui.DrawList_AddRectFilled(dl, badge_x, badge_y, badge_x2, badge_y2, badge_bg_color, _cfg.badge_rounding)
    ImGui.DrawList_AddRect(dl, badge_x, badge_y, badge_x2, badge_y2,
      Colors.with_alpha(base_color, _cfg.badge_border_alpha),
      _cfg.badge_rounding, 0, 0.5)

    Draw.text(dl, badge_x + _cfg.badge_padding_x, badge_y + _cfg.badge_padding_y,
      Colors.with_alpha(hexrgb('#FFFFFFDD'), text_alpha), badge_text)
  end
end

return M
