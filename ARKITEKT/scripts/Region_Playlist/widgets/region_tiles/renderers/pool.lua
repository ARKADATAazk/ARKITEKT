-- @noindex
-- ReArkitekt/gui/widgets/region_tiles/renderers/pool.lua
-- MODIFIED: Lowered responsive threshold for text.

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
  disabled = { desaturate = 0.9, brightness = 0.5, alpha_multiplier = 0.6, min_lightness = 0.28 },
  responsive = { hide_length_below = 35, hide_text_below = 15 }, -- UPDATED
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
  badge_nudge_x = 0,
  badge_nudge_y = 0,
  badge_text_nudge_x = -1,
  badge_text_nudge_y = -1,
  circular = {
    base_color = 0x240C0CFF,
    stripe_color = 0x30101044,
    border_color = 0x6A0606FF,
    text_color = 0xF70000FF,
    lock_color = 0x6A0606FF,
    playlist_chip_color = 0x980404FF,
    lock_base_w = 11,
    lock_base_h = 7,
    lock_handle_w = 2,
    lock_handle_h = 5,
    lock_top_w = 9,
    lock_top_h = 2,
    stripe_width = 1.5,
    stripe_spacing = 14,
  },
}

local function clamp_min_lightness(color, min_l)
  local lum = Colors.luminance(color)
  if lum < (min_l or 0) then
    local factor = (min_l + 0.001) / math.max(lum, 0.001)
    return Colors.adjust_brightness(color, factor)
  end
  return color
end

local function draw_lock_icon(dl, cx, cy, config, color)
  local base_w = config.lock_base_w
  local base_h = config.lock_base_h
  local handle_w = config.lock_handle_w
  local handle_h = config.lock_handle_h
  local top_w = config.lock_top_w
  local top_h = config.lock_top_h
  
  -- Lock base (11w x 7h)
  local base_x1 = cx - base_w * 0.5
  local base_y1 = cy - base_h * 0.5 + 2
  local base_x2 = base_x1 + base_w
  local base_y2 = base_y1 + base_h
  ImGui.DrawList_AddRectFilled(dl, base_x1, base_y1, base_x2, base_y2, color, 0)
  
  -- Left handle (2w x 5h, 1px in from left)
  local left_handle_x1 = base_x1 + 1
  local left_handle_y1 = base_y1 - handle_h
  local left_handle_x2 = left_handle_x1 + handle_w
  local left_handle_y2 = base_y1
  ImGui.DrawList_AddRectFilled(dl, left_handle_x1, left_handle_y1, left_handle_x2, left_handle_y2, color, 0)
  
  -- Right handle (2w x 5h, 1px in from right)
  local right_handle_x1 = base_x2 - handle_w - 1
  local right_handle_y1 = base_y1 - handle_h
  local right_handle_x2 = base_x2 - 1
  local right_handle_y2 = base_y1
  ImGui.DrawList_AddRectFilled(dl, right_handle_x1, right_handle_y1, right_handle_x2, right_handle_y2, color, 0)
  
  -- Top handle (9w x 2h)
  local top_x1 = cx - top_w * 0.5
  local top_y1 = base_y1 - handle_h
  local top_x2 = top_x1 + top_w
  local top_y2 = top_y1 + top_h
  ImGui.DrawList_AddRectFilled(dl, top_x1, top_y1, top_x2, top_y2, color, 0)
end

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
  
  -- Special rendering for circular reference tiles
  if is_disabled then
    M.render_circular_playlist(ctx, rect, playlist, state, animator, hover_config, tile_height, border_thickness)
    return
  end
  
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
    local minL = M.CONFIG.disabled.min_lightness or 0.28
    base_color = clamp_min_lightness(base_color, minL)
    playlist_data.chip_color = clamp_min_lightness(playlist_data.chip_color, minL)
  end
  
  local fx_config = TileFXConfig.get()
  -- Use chip color for border (pool tiles don't have playback progress)
  BaseRenderer.draw_base_tile(dl, rect, base_color, fx_config, state, hover_factor, 0, 0, playlist_data.chip_color)
  
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
    Draw.text(dl, badge_x + M.CONFIG.badge_padding_x + M.CONFIG.badge_text_nudge_x, badge_y + M.CONFIG.badge_padding_y + M.CONFIG.badge_text_nudge_y, Colors.with_alpha(badge_text_color, text_alpha), badge_text)

    ImGui.SetCursorScreenPos(ctx, x1, y1)
    ImGui.InvisibleButton(ctx, key .. "_tooltip", x2 - x1, y2 - y1)
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, string.format("Playlist • %d items", item_count))
    end
  end
end

function M.render_circular_playlist(ctx, rect, playlist, state, animator, hover_config, tile_height, border_thickness)
  local dl = ImGui.GetWindowDrawList(ctx)
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local key = "pool_playlist_" .. tostring(playlist.id)
  
  animator:track(key, 'hover', 0, hover_config and hover_config.animation_speed_hover or 12.0)
  animator:track(key, 'disabled', 1.0, 12.0)
  
  local base_color = M.CONFIG.circular.base_color
  local playlist_data = {
    name = playlist.name or "Unnamed Playlist",
    chip_color = M.CONFIG.circular.playlist_chip_color
  }
  
  local fx_config = TileFXConfig.get()
  local border_color = M.CONFIG.circular.border_color
  
  -- Draw base tile with red border
  BaseRenderer.draw_base_tile(dl, rect, base_color, fx_config, state, 0, 0, 0, border_color)
  
  -- Draw diagonal stripe pattern
  local stripe_w = M.CONFIG.circular.stripe_width
  local stripe_spacing = M.CONFIG.circular.stripe_spacing
  local stripe_color = M.CONFIG.circular.stripe_color
  
  ImGui.DrawList_PushClipRect(dl, x1, y1, x2, y2, true)
  
  local tile_w = x2 - x1
  local tile_h = y2 - y1
  local diagonal_length = math.sqrt(tile_w * tile_w + tile_h * tile_h)
  local num_stripes = math.ceil(diagonal_length / stripe_spacing) + 2
  
  for i = -num_stripes, num_stripes do
    local offset = i * stripe_spacing
    local sx1 = x1 + offset
    local sy1 = y1
    local sx2 = x1 + offset + tile_h
    local sy2 = y2
    
    ImGui.DrawList_AddLine(dl, sx1, sy1, sx2, sy2, stripe_color, stripe_w)
  end
  
  ImGui.DrawList_PopClipRect(dl)
  
  local actual_height = tile_height or (y2 - y1)
  local show_text = actual_height >= M.CONFIG.responsive.hide_text_below
  local show_badge = actual_height >= M.CONFIG.responsive.hide_text_below
  
  local item_count = #playlist.items
  
  if show_text then
    local text_pos = BaseRenderer.calculate_text_position(ctx, rect, actual_height)
    
    -- Draw playlist name with original chip color
    BaseRenderer.draw_playlist_text(ctx, dl, text_pos, playlist_data, state, 0xFF, x2 - M.CONFIG.text_margin_right, M.CONFIG.playlist_tile.name_color)
  end
  
  if show_badge then
    -- Draw badge container with lock icon
    local lock_size = M.CONFIG.circular.lock_base_w
    local lock_margin = M.CONFIG.badge_margin + 2
    local badge_x = x2 - lock_size - lock_margin * 2 - 2
    local badge_y = y1 + M.CONFIG.badge_margin
    local badge_x2 = x2 - lock_margin
    local badge_y2 = badge_y + lock_size + M.CONFIG.badge_padding_y * 2
    local badge_bg = M.CONFIG.badge_bg
    
    ImGui.DrawList_AddRectFilled(dl, badge_x, badge_y, badge_x2, badge_y2, badge_bg, M.CONFIG.badge_rounding)
    
    local badge_border_color = M.CONFIG.circular.border_color
    ImGui.DrawList_AddRect(dl, badge_x, badge_y, badge_x2, badge_y2, Colors.with_alpha(badge_border_color, 0x88), M.CONFIG.badge_rounding, 0, 0.5)
    
    -- Draw lock icon centered in badge
    local lock_x = badge_x + (badge_x2 - badge_x) * 0.5
    local lock_y = badge_y + (badge_y2 - badge_y) * 0.5
    draw_lock_icon(dl, lock_x, lock_y, M.CONFIG.circular, M.CONFIG.circular.lock_color)
  end
  
  -- Draw "CIRCULAR" text centered
  local label = "CIRCULAR"
  local label_w, label_h = ImGui.CalcTextSize(ctx, label)
  local label_x = x1 + (x2 - x1 - label_w) * 0.5
  local label_y = y1 + (y2 - y1 - label_h) * 0.5
  ImGui.DrawList_AddText(dl, label_x, label_y, M.CONFIG.circular.text_color, label)
  
  -- Tooltip
  ImGui.SetCursorScreenPos(ctx, x1, y1)
  ImGui.InvisibleButton(ctx, key .. "_tooltip", x2 - x1, y2 - y1)
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "Cannot drag: would create circular reference")
  end
end

return M