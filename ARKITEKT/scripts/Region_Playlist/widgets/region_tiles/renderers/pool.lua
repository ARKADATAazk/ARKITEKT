-- @noindex
-- ReArkitekt/gui/widgets/region_tiles/renderers/pool.lua

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local Colors = require('rearkitekt.core.colors')
local Draw = require('rearkitekt.gui.draw')
local TileFXConfig = require('rearkitekt.gui.fx.tile_fx_config')
local TileUtil = require('rearkitekt.gui.systems.tile_utilities')
local BaseRenderer = require('Region_Playlist.widgets.region_tiles.renderers.base')

local M = {}

M.CONFIG = {
  bg_base = 0x1A1A1AFF,
  disabled = { desaturate = 0.9, brightness = 0.5, alpha_multiplier = 0.6 },
  responsive = { hide_length_below = 35, hide_text_below = 17 },
  playlist_tile = { 
    base_color = 0x3A3A3AFF, 
    name_color = 0xCCCCCCFF, 
    badge_color = 0x999999FF 
  },
  text_margin_right = 6,
  badge_margin = 6,
  badge_padding_x = 6,
  badge_padding_y = 3,
  badge_rounding = 4,
  badge_bg = 0x14181CFF,
  badge_border_alpha = 0x33,
}

function M.render(ctx, rect, item, state, animator, hover_config, tile_height, border_thickness)
  if item.id and item.items then
    M.render_playlist(ctx, rect, item, state, animator, hover_config, tile_height, border_thickness)
  else
    M.render_region(ctx, rect, item, state, animator, hover_config, tile_height, border_thickness)
  end
end

function M.render_region(ctx, rect, region, state, animator, hover_config, tile_height, border_thickness)
  local dl = ImGui.GetWindowDrawList(ctx)
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local key = "pool_" .. tostring(region.rid)
  
  animator:track(key, 'hover', state.hover and 1.0 or 0.0, hover_config and hover_config.animation_speed_hover or 12.0)
  local hover_factor = animator:get(key, 'hover')
  local base_color = region.color or M.CONFIG.bg_base
  local fx_config = TileFXConfig.get()
  
  BaseRenderer.draw_base_tile(dl, rect, base_color, fx_config, state, hover_factor)
  if state.selected and fx_config.ants_enabled then BaseRenderer.draw_marching_ants(dl, rect, base_color, fx_config) end
  
  local actual_height = tile_height or (y2 - y1)
  local show_text = actual_height >= M.CONFIG.responsive.hide_text_below
  local show_length = actual_height >= M.CONFIG.responsive.hide_length_below
  
  local right_elements = {}
  
  if show_text then
    local right_bound_x = BaseRenderer.calculate_text_right_bound(ctx, x2, M.CONFIG.text_margin_right, right_elements)
    local text_pos = BaseRenderer.calculate_text_position(ctx, rect, actual_height)
    BaseRenderer.draw_region_text(ctx, dl, text_pos, region, base_color, 0xFF, right_bound_x)
  end
  
  if show_length then BaseRenderer.draw_length_display(ctx, dl, rect, region, base_color, 0xFF) end
end

function M.render_playlist(ctx, rect, playlist, state, animator, hover_config, tile_height, border_thickness)
  local dl = ImGui.GetWindowDrawList(ctx)
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local key = "pool_playlist_" .. tostring(playlist.id)
  local is_disabled = playlist.is_disabled or false
  
  animator:track(key, 'hover', (state.hover and not is_disabled) and 1.0 or 0.0, hover_config and hover_config.animation_speed_hover or 12.0)
  animator:track(key, 'disabled', is_disabled and 1.0 or 0.0, 12.0)
  local hover_factor = animator:get(key, 'hover')
  local disabled_factor = animator:get(key, 'disabled')
  
  local base_color = M.CONFIG.playlist_tile.base_color
  local playlist_data = {
    name = playlist.name or "Unnamed Playlist",
    chip_color = playlist.chip_color or 0xFF5733FF
  }

  if disabled_factor > 0 then
    base_color = Colors.desaturate(base_color, M.CONFIG.disabled.desaturate * disabled_factor)
    base_color = Colors.adjust_brightness(base_color, 1.0 - ((1.0 - M.CONFIG.disabled.brightness) * disabled_factor))
    playlist_data.chip_color = Colors.desaturate(playlist_data.chip_color, M.CONFIG.disabled.desaturate * disabled_factor)
    playlist_data.chip_color = Colors.adjust_brightness(playlist_data.chip_color, 1.0 - ((1.0 - M.CONFIG.disabled.brightness) * disabled_factor))
  end
  
  local fx_config = TileFXConfig.get()
  BaseRenderer.draw_base_tile(dl, rect, base_color, fx_config, state, hover_factor)
  
  if is_disabled and disabled_factor > 0.5 then
    ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, 0x00000000 | math.floor(120 * disabled_factor), BaseRenderer.CONFIG.rounding)
  end
  
  if state.selected and fx_config.ants_enabled then BaseRenderer.draw_marching_ants(dl, rect, playlist_data.chip_color, fx_config) end
  
  local actual_height = tile_height or (y2 - y1)
  local show_text = actual_height >= M.CONFIG.responsive.hide_text_below
  local show_badge = actual_height >= M.CONFIG.responsive.hide_text_below
  local text_alpha_factor = 1.0 - (disabled_factor * (1.0 - M.CONFIG.disabled.alpha_multiplier))
  local text_alpha = math.floor(0xFF * text_alpha_factor)
  
  local item_count = #playlist.items
  
  local right_elements = {}
  
  if show_badge then
    local badge_text = string.format("[%d]", item_count)
    local badge_w, _ = ImGui.CalcTextSize(ctx, badge_text)
    table.insert(right_elements, BaseRenderer.create_element(
      true,
      (badge_w * BaseRenderer.CONFIG.badge_font_scale) + (M.CONFIG.badge_padding_x * 2),
      M.CONFIG.badge_margin
    ))
  end
  
  if show_text then
    local right_bound_x = BaseRenderer.calculate_text_right_bound(ctx, x2, M.CONFIG.text_margin_right, right_elements)
    local text_pos = BaseRenderer.calculate_text_position(ctx, rect, actual_height)
    
    local name_color = M.CONFIG.playlist_tile.name_color
    if disabled_factor > 0 then
      name_color = Colors.adjust_brightness(name_color, 1.0 - ((1.0 - M.CONFIG.disabled.brightness) * disabled_factor))
    end
    if (state.hover or state.selected) and not is_disabled then
      name_color = 0xFFFFFFFF
    end

    BaseRenderer.draw_playlist_text(ctx, dl, text_pos, playlist_data, state, text_alpha, right_bound_x, name_color)
  end
  
  if show_badge then
    local badge_text = string.format("[%d]", item_count)
    local bw, bh = ImGui.CalcTextSize(ctx, badge_text)
    bw, bh = bw * BaseRenderer.CONFIG.badge_font_scale, bh * BaseRenderer.CONFIG.badge_font_scale
    local badge_x = x2 - bw - M.CONFIG.badge_padding_x * 2 - M.CONFIG.badge_margin
    local badge_y = y1 + M.CONFIG.badge_margin
    local badge_x2, badge_y2 = badge_x + bw + M.CONFIG.badge_padding_x * 2, badge_y + bh + M.CONFIG.badge_padding_y * 2
    local badge_bg = (M.CONFIG.badge_bg & 0xFFFFFF00) | math.floor(((M.CONFIG.badge_bg & 0xFF) * text_alpha_factor))
    
    ImGui.DrawList_AddRectFilled(dl, badge_x, badge_y, badge_x2, badge_y2, badge_bg, M.CONFIG.badge_rounding)
    
    local badge_border_color = M.CONFIG.playlist_tile.badge_color
    if disabled_factor > 0 then
      badge_border_color = Colors.adjust_brightness(badge_border_color, 1.0 - ((1.0 - M.CONFIG.disabled.brightness) * disabled_factor))
    end
    if (state.hover or state.selected) and not is_disabled then
      badge_border_color = playlist_data.chip_color
    end
    
    ImGui.DrawList_AddRect(dl, badge_x, badge_y, badge_x2, badge_y2, Colors.with_alpha(badge_border_color, M.CONFIG.badge_border_alpha), M.CONFIG.badge_rounding, 0, 0.5)
    
    local badge_text_color = M.CONFIG.playlist_tile.badge_color
    if disabled_factor > 0 then
      badge_text_color = Colors.adjust_brightness(badge_text_color, 1.0 - ((1.0 - M.CONFIG.disabled.brightness) * disabled_factor))
    end
    if (state.hover or state.selected) and not is_disabled then
      badge_text_color = 0xAAAAAAFF
    end
    Draw.text(dl, badge_x + M.CONFIG.badge_padding_x, badge_y + M.CONFIG.badge_padding_y, Colors.with_alpha(badge_text_color, text_alpha), badge_text)

    ImGui.SetCursorScreenPos(ctx, x1, y1)
    ImGui.InvisibleButton(ctx, key .. "_tooltip", x2 - x1, y2 - y1)
    if ImGui.IsItemHovered(ctx) then
      if is_disabled then
        ImGui.SetTooltip(ctx, "Cannot drag: would create circular reference")
      else
        ImGui.SetTooltip(ctx, string.format("Playlist • %d items", item_count))
      end
    end
  end
end

return M