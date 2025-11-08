-- @noindex
-- ReArkitekt/gui/widgets/region_tiles/renderers/base.lua
-- MODIFIED: Chip offset now uses a single {x, y} table for 2D positioning.

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local Draw = require('rearkitekt.gui.draw')
local Colors = require('rearkitekt.core.colors')
local TileFX = require('rearkitekt.gui.fx.tile_fx')
local TileFXConfig = require('rearkitekt.gui.fx.tile_fx_config')
local MarchingAnts = require('rearkitekt.gui.fx.marching_ants')
local TileUtil = require('rearkitekt.gui.systems.tile_utilities')
local Chip = require('rearkitekt.gui.widgets.component.chip')

local M = {}

M.CONFIG = {
  rounding = 6,
  badge_font_scale = 0.88,
  length_margin = 6,
  length_padding_x = 4,
  length_padding_y = 2,
  length_font_size = 0.82,
  length_offset_x = 3,
  playlist_chip_radius = 4,
  prefix_width = 24,
  chip_offset = { x = 0, y = 0 }, -- NEW: Nudge chip with X and Y values
  text_padding_left = 6,
  text_padding_top = 6,
  vertical_center_threshold = 40,
}

-- ========================================
-- AUTOMATED TEXT OVERFLOW SYSTEM
-- ========================================

function M.calculate_right_elements_width(ctx, elements)
  local total_width = 0
  for _, element in ipairs(elements) do
    if element.visible then
      total_width = total_width + element.width + element.margin
    end
  end
  return total_width
end

function M.create_element(visible, width, margin)
  return {
    visible = visible,
    width = width,
    margin = margin or 0
  }
end

function M.calculate_text_right_bound(ctx, x2, text_margin, right_elements)
  local right_occupied = M.calculate_right_elements_width(ctx, right_elements)
  return x2 - text_margin - right_occupied
end

-- ========================================
-- UNIFIED POSITIONING SYSTEM
-- ========================================

function M.calculate_text_position(ctx, rect, actual_height, text_sample)
  local x1, y1 = rect[1], rect[2]
  local text_height = ImGui.CalcTextSize(ctx, text_sample or "Tg")
  
  local x = x1 + M.CONFIG.text_padding_left
  local y
  
  if actual_height < M.CONFIG.vertical_center_threshold then
    y = y1 + (actual_height - text_height) / 2 - 1
  else
    y = y1 + M.CONFIG.text_padding_top
  end
  
  return { x = x, y = y }
end

-- ========================================
-- TEXT TRUNCATION
-- ========================================

local function truncate_text(ctx, text, max_width)
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
M.truncate_text = truncate_text

-- ========================================
-- TILE RENDERING FUNCTIONS
-- ========================================

function M.draw_base_tile(dl, rect, base_color, fx_config, state, hover_factor, playback_progress, playback_fade, override_color)
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  -- Use override_color for border/progress if provided (for playlist tiles)
  local border_color = override_color or base_color
  local progress_color = override_color or base_color
  TileFX.render_complete(dl, x1, y1, x2, y2, base_color, fx_config, state.selected, hover_factor, playback_progress or 0, playback_fade or 0, border_color, progress_color)
end

function M.draw_marching_ants(dl, rect, color, fx_config)
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local ants_color = Colors.same_hue_variant(color, fx_config.border_saturation, fx_config.border_brightness, fx_config.ants_alpha or 0xFF)
  local inset = fx_config.ants_inset or 0   -- was 0.5
  MarchingAnts.draw(dl, x1 + inset, y1 + inset, x2 - inset, y2 - inset, ants_color,
    fx_config.ants_thickness or 1, M.CONFIG.rounding, fx_config.ants_dash, fx_config.ants_gap, fx_config.ants_speed)
end


function M.draw_region_text(ctx, dl, pos, region, base_color, text_alpha, right_bound_x)
  local fx_config = TileFXConfig.get()
  local accent_color = Colors.with_alpha(Colors.same_hue_variant(base_color, fx_config.index_saturation, fx_config.index_brightness, 0xFF), text_alpha)
  local name_color = Colors.with_alpha(Colors.adjust_brightness(fx_config.name_base_color, fx_config.name_brightness), text_alpha)
  
  local index_str = string.format("%d", region.rid)
  local name_str = region.name or "Unknown"

  local index_w = ImGui.CalcTextSize(ctx, index_str)
  local separator = " "
  local sep_w = ImGui.CalcTextSize(ctx, separator)
  
  local index_start_x = pos.x + (M.CONFIG.prefix_width - index_w - sep_w)
  Draw.text(dl, index_start_x, pos.y, accent_color, index_str)
  
  local separator_color = Colors.with_alpha(Colors.same_hue_variant(base_color, fx_config.separator_saturation, fx_config.separator_brightness, fx_config.separator_alpha), text_alpha)
  Draw.text(dl, pos.x + M.CONFIG.prefix_width - sep_w, pos.y, separator_color, separator)
  
  local name_start_x = pos.x + M.CONFIG.prefix_width
  local name_width = right_bound_x - name_start_x
  local truncated_name = truncate_text(ctx, name_str, name_width)
  Draw.text(dl, name_start_x, pos.y, name_color, truncated_name)
end

function M.draw_playlist_text(ctx, dl, pos, playlist_data, state, text_alpha, right_bound_x, name_color_override)
  local fx_config = TileFXConfig.get()
  
  local text_height = ImGui.CalcTextSize(ctx, "Tg")
  
  -- The chip is centered, then adjusted by the new X and Y offsets
  local chip_x = pos.x + (M.CONFIG.prefix_width / 2) + M.CONFIG.chip_offset.x
  local chip_center_y = pos.y + (text_height / 2) + M.CONFIG.chip_offset.y
  
  Chip.draw(ctx, {
    style = Chip.STYLE.INDICATOR,
    color = playlist_data.chip_color,
    draw_list = dl,
    x = chip_x,
    y = chip_center_y,
    radius = M.CONFIG.playlist_chip_radius,
    is_selected = state.selected,
    is_hovered = state.hover,
    show_glow = state.selected or state.hover,
    glow_layers = 2,
    alpha_factor = text_alpha / 255,
  })

  local name_color
  if name_color_override then
    name_color = Colors.with_alpha(name_color_override, text_alpha)
  else
    name_color = Colors.with_alpha(Colors.adjust_brightness(fx_config.name_base_color, fx_config.name_brightness), text_alpha)
    if state.hover or state.selected then
      name_color = Colors.with_alpha(0xFFFFFFFF, text_alpha)
    end
  end

  local name_start_x = pos.x + M.CONFIG.prefix_width
  local name_width = right_bound_x - name_start_x
  local truncated_name = truncate_text(ctx, playlist_data.name, name_width)
  Draw.text(dl, name_start_x, pos.y, name_color, truncated_name)
end

function M.draw_length_display(ctx, dl, rect, region, base_color, text_alpha)
    local x2, y2 = rect[3], rect[4]
    local height_factor = math.min(1.0, math.max(0.0, ((y2 - rect[2]) - 20) / (72 - 20)))
    local fx_config = TileFXConfig.get()

    local length_str = TileUtil.format_bar_length(region.start, region["end"], 0)
    local scale = M.CONFIG.length_font_size
    local length_w, length_h = ImGui.CalcTextSize(ctx, length_str)
    length_w, length_h = length_w * scale, length_h * scale
    
    local scaled_padding_x = M.CONFIG.length_padding_x * (0.5 + 0.5 * height_factor)
    local scaled_padding_y = M.CONFIG.length_padding_y * (0.5 + 0.5 * height_factor)
    local scaled_margin = M.CONFIG.length_margin * (0.3 + 0.7 * height_factor)
    
    local length_x = x2 - length_w - scaled_padding_x * 2 - scaled_margin - M.CONFIG.length_offset_x
    local length_y = y2 - length_h - scaled_padding_y * 2 - scaled_margin
    
    local length_color = Colors.same_hue_variant(base_color, fx_config.duration_saturation, fx_config.duration_brightness, fx_config.duration_alpha)
    length_color = Colors.with_alpha(length_color, text_alpha)
    
    Draw.text(dl, length_x + scaled_padding_x, length_y + scaled_padding_y, length_color, length_str)
end

return M