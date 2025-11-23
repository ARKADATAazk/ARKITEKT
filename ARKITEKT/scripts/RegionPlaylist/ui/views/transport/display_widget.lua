-- @noindex
-- RegionPlaylist/ui/views/transport/display_widget.lua
-- Transport display widget showing time, regions, and progress

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local Colors = require('arkitekt.core.colors')
local TileFXConfig = require('arkitekt.gui.rendering.tile.defaults')
local TransportFX = require('RegionPlaylist.ui.views.transport.transport_fx')
local Chip = require('arkitekt.gui.widgets.data.chip')
local hexrgb = Colors.hexrgb

-- Performance: Localize math functions for hot path (30% faster in loops)
local max = math.max
local min = math.min

local M = {}

local TRANSPORT_LAYOUT_CONFIG = {
  global_offset_y = -5,
  padding = 48,
  padding_top = 8,
  spacing_horizontal = 12,
  spacing_progress = 8,
  progress_height = 3,
  progress_bottom_offset = 12,
  progress_padding_left = 56,
  progress_padding_right = 56,  -- Equal padding now that corner button balances view mode button
  playlist_chip_size = 8,
  playlist_chip_offset_x = 4,
  playlist_chip_offset_y = 2,
  playlist_name_offset_x = 12,
  playlist_name_offset_y = 0,
  time_offset_x = 0,
  time_offset_y = 0,
  region_label_spacing = 4,
  current_region_offset_x = 0,
  current_region_offset_y = 0,
  next_region_offset_x = 0,
  next_region_offset_y = 0,
  content_vertical_offset = -2,

  -- Responsive breakpoints
  hide_playlist_width = 500,  -- Hide playlist name below this width
  truncate_region_width = 450,  -- Start truncating region names below this
  hide_region_width = 300,  -- Hide region names below this width
  region_name_max_chars = 15,  -- Max chars before truncation starts
  region_name_min_chars = 8,  -- Min chars when fully truncated
}

local TransportDisplay = {}
TransportDisplay.__index = TransportDisplay

function M.new(config)
  return setmetatable({
    config = config or {},
  }, TransportDisplay)
end

-- Truncate text with ellipsis based on character count
local function truncate_text(text, max_chars)
  if #text <= max_chars then
    return text
  end
  return text:sub(1, max_chars - 1) .. "…"
end

-- Calculate truncation length based on available width
local function get_truncate_length(width, min_width, max_width, min_chars, max_chars)
  if width >= max_width then
    return max_chars
  end
  if width <= min_width then
    return min_chars
  end
  -- Linear interpolation
  local factor = (width - min_width) / (max_width - min_width)
  return min_chars + (max_chars - min_chars) * factor
end

local function ensure_minimum_brightness(color, min_luminance)
  min_luminance = min_luminance or 0.15

  local lum = Colors.luminance(color)
  if lum >= min_luminance then
    return color
  end

  local boost_factor = min_luminance / max(lum, 0.01)
  return Colors.adjust_brightness(color, boost_factor)
end

local function ensure_progress_bar_brightness(color)
  -- Ensure progress bar is never too dark (min 30% brightness)
  local r, g, b, a = Colors.rgba_to_components(color)
  local lum = (r * 0.299 + g * 0.587 + b * 0.114) / 255.0

  if lum < 0.30 then
    local boost = 0.30 / max(lum, 0.01)
    r = min(255, (r * boost)//1)
    g = min(255, (g * boost)//1)
    b = min(255, (b * boost)//1)
  end

  return Colors.components_to_rgba(r, g, b, a)
end

function TransportDisplay:draw(ctx, x, y, width, height, bridge_state, current_region, next_region, playlist_data, region_colors, time_font)
  local dl = ImGui.GetWindowDrawList(ctx)
  local cfg = self.config
  local fx_config = TileFXConfig.get()
  
  local LC = TRANSPORT_LAYOUT_CONFIG
  
  y = y + LC.global_offset_y
  
  local progress = bridge_state.progress or 0
  local bar_x = x + LC.progress_padding_left
  local bar_y = y + height - LC.progress_height - LC.progress_bottom_offset
  local bar_w = width - LC.progress_padding_left - LC.progress_padding_right
  local bar_h = LC.progress_height
  
  local track_color = cfg.track_color or hexrgb("#1D1D1D")
  ImGui.DrawList_AddRectFilled(dl, bar_x, bar_y, bar_x + bar_w, bar_y + bar_h, track_color, 1.5)
  
  if progress > 0 and region_colors and region_colors.current then
    -- Full-width gradient, clipped to progress
    local fill_w = bar_w * progress

    local color_left, color_right
    if region_colors.next then
      color_left = ensure_progress_bar_brightness(region_colors.current)
      color_right = ensure_progress_bar_brightness(region_colors.next)
    else
      color_left = ensure_progress_bar_brightness(region_colors.current)
      color_right = ensure_progress_bar_brightness(region_colors.current)
    end

    -- Clip to reveal only the filled portion of the full-width gradient
    ImGui.DrawList_PushClipRect(dl, bar_x, bar_y, bar_x + fill_w, bar_y + bar_h, true)
    TransportFX.render_progress_gradient(dl, bar_x, bar_y, bar_x + bar_w, bar_y + bar_h,
      color_left, color_right, 1.5)
    ImGui.DrawList_PopClipRect(dl)
  end
  
  local content_bottom = bar_y - LC.spacing_progress
  local content_top = y + (LC.padding_top or 8)

  local time_text = "READY"
  local time_color = cfg.time_color or hexrgb("#CCCCCC")

  if bridge_state.is_playing then
    local time_remaining = bridge_state.time_remaining or 0

    -- Format time as H:M:S:ms (using VM floor operation for performance)
    local hours = (time_remaining / 3600)//1
    local mins = ((time_remaining % 3600) / 60)//1
    local secs = (time_remaining % 60)//1
    local ms = ((time_remaining % 1) * 100)//1  -- centiseconds

    if hours > 0 then
      time_text = string.format("%d:%02d:%02d:%02d", hours, mins, secs, ms)
    else
      time_text = string.format("%02d:%02d:%02d", mins, secs, ms)
    end

    time_color = cfg.time_playing_color or hexrgb("#FFFFFF")
  end
  
  if time_font then
    ImGui.PushFont(ctx, time_font, 20)
  end
  local time_w, time_h = ImGui.CalcTextSize(ctx, time_text)
  if time_font then
    ImGui.PopFont(ctx)
  end
  
  local text_line_h = ImGui.CalcTextSize(ctx, "Tg")
  
  local row_height = math.max(text_line_h, time_h)
  
  local row_y = content_top + ((content_bottom - content_top) - row_height) / 2 + LC.content_vertical_offset

  -- Responsive: Only show playlist name if width is sufficient
  if playlist_data and width >= LC.hide_playlist_width then
    local chip_x = x + LC.padding + LC.playlist_chip_offset_x
    local chip_y = row_y + row_height / 2 + LC.playlist_chip_offset_y

    Chip.draw(ctx, {
      style = Chip.STYLE.INDICATOR,
      color = playlist_data.color,
      draw_list = dl,
      x = chip_x,
      y = chip_y,
      radius = 4,
      is_selected = false,
      is_hovered = false,
      show_glow = false,
      alpha_factor = 1.0,
    })

    local playlist_name_x = x + LC.padding + LC.playlist_name_offset_x
    local playlist_name_y = row_y + (row_height - text_line_h) / 2 + LC.playlist_name_offset_y
    local playlist_name_color = hexrgb("#CCCCCC")
    ImGui.DrawList_AddText(dl, playlist_name_x, playlist_name_y, playlist_name_color, playlist_data.name)
  end
  
  local center_x = x + width / 2
  
  if time_font then
    ImGui.PushFont(ctx, time_font, 20)
  end
  
  local time_x = center_x - time_w / 2 + LC.time_offset_x
  local time_y = row_y + (row_height - time_h) / 2 + LC.time_offset_y
  
  ImGui.DrawList_AddText(dl, time_x, time_y, time_color, time_text)
  
  if time_font then
    ImGui.PopFont(ctx)
  end
  
  -- Responsive: Only show current region if width is sufficient
  if bridge_state.is_playing and current_region and width >= LC.hide_region_width then
    local index_str = string.format("%d", current_region.rid)
    local name_str = current_region.name or "Unknown"

    -- Apply responsive truncation
    if width < LC.truncate_region_width then
      local truncate_len = get_truncate_length(
        width,
        LC.hide_region_width,
        LC.truncate_region_width,
        LC.region_name_min_chars,
        LC.region_name_max_chars
      )
      name_str = truncate_text(name_str, truncate_len)
    end

    local index_color = Colors.same_hue_variant(current_region.color, fx_config.index_saturation, fx_config.index_brightness, 0xFF)
    local name_color = hexrgb("#FFFFFF")

    local index_w = ImGui.CalcTextSize(ctx, index_str)
    local name_w = ImGui.CalcTextSize(ctx, name_str)

    local total_w = index_w + LC.region_label_spacing + name_w
    local current_x = time_x - total_w - LC.spacing_horizontal + LC.current_region_offset_x
    local current_y = row_y + (row_height - text_line_h) / 2 + LC.current_region_offset_y

    ImGui.DrawList_AddText(dl, current_x, current_y, index_color, index_str)
    ImGui.DrawList_AddText(dl, current_x + index_w + LC.region_label_spacing, current_y, name_color, name_str)
  end
  
  -- Responsive: Only show next region if width is sufficient
  if bridge_state.is_playing and next_region and width >= LC.hide_region_width then
    local index_str = string.format("%d", next_region.rid)
    local name_str = next_region.name or "Unknown"

    -- Apply responsive truncation
    if width < LC.truncate_region_width then
      local truncate_len = get_truncate_length(
        width,
        LC.hide_region_width,
        LC.truncate_region_width,
        LC.region_name_min_chars,
        LC.region_name_max_chars
      )
      name_str = truncate_text(name_str, truncate_len)
    end

    local index_color = Colors.same_hue_variant(next_region.color, fx_config.index_saturation, fx_config.index_brightness, 0xFF)
    local name_color = hexrgb("#FFFFFF")

    local index_w = ImGui.CalcTextSize(ctx, index_str)

    local next_x = time_x + time_w + LC.spacing_horizontal + LC.next_region_offset_x
    local next_y = row_y + (row_height - text_line_h) / 2 + LC.next_region_offset_y

    ImGui.DrawList_AddText(dl, next_x, next_y, index_color, index_str)
    ImGui.DrawList_AddText(dl, next_x + index_w + LC.region_label_spacing, next_y, name_color, name_str)
  end
end

return M
