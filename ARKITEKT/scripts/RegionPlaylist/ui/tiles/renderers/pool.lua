-- @noindex
-- RegionPlaylist/ui/tiles/renderers/pool.lua
-- MODIFIED: Using theme colors from ScriptColors and Style.COLORS

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local ark = require('arkitekt')
local Style = require('arkitekt.gui.style')

local TileFXConfig = require('arkitekt.gui.rendering.tile.defaults')
local TileUtil = require('RegionPlaylist.core.tile_utilities')
local BaseRenderer = require('RegionPlaylist.ui.tiles.renderers.base')
local Background = require('arkitekt.gui.draw.pattern')
local ScriptColors = require('RegionPlaylist.defs.colors')

-- Performance: Localize math functions for hot path (30% faster in loops)
local max = math.max
local sqrt = math.sqrt

local M = {}

-- Static config (dimensions, timing, behavior)
M.CONFIG = {
  disabled = { desaturate = 0.9, brightness = 0.5, alpha_multiplier = 0.6, min_lightness = 0.28 },
  responsive = { hide_length_below = 35, hide_text_below = 15 },
  text_margin_right = 6,
  badge_margin = 6,
  badge_padding_x = 6,
  badge_padding_y = 3,
  badge_rounding = 4,
  badge_nudge_x = 0,
  badge_nudge_y = 0,
  badge_text_nudge_x = -1,
  badge_text_nudge_y = -2,
  -- Lock icon dimensions (for circular dependency tiles)
  lock_base_w = 11,
  lock_base_h = 7,
  lock_handle_w = 2,
  lock_handle_h = 5,
  lock_top_w = 9,
  lock_top_h = 2,
}

--- Get current colors (theme-reactive for badges/tiles, fixed for circular)
--- @return table Colors for rendering
local function get_colors()
  local ok, badge = pcall(ScriptColors.get_badge)
  if not ok then badge = { bg = 0x14181CDD, text = 0xFFFFFFDD, border_opacity = 0.20 } end

  local ok2, playlist = pcall(ScriptColors.get_playlist_tile)
  if not ok2 then playlist = { base_color = 0x3A3A3AFF, name_color = 0xCCCCCCFF, badge_color = 0x999999FF } end

  local ok3, circular = pcall(ScriptColors.get_circular)
  if not ok3 then circular = {
    base_color = 0x240C0CFF, stripe_color = 0x430D0D33, border_color = 0x240F0FFF,
    text_color = 0x901B1BFF, lock_color = 0x901B1BFF, chip_color = 0x901B1BFF,
    badge_bg = 0x240C0CFF, badge_border_color = 0x652A2AFF,
    stripe_width = 8, stripe_spacing = 16,
  } end

  local ok4, fallback = pcall(ScriptColors.get_fallback_chip)
  if not ok4 then fallback = 0xFF5733FF end

  return {
    -- Badge colors (theme-reactive via Style.COLORS)
    badge_bg = badge.bg,
    badge_text = badge.text,
    badge_border_opacity = badge.border_opacity,

    -- Playlist tile colors (theme-reactive via Style.COLORS)
    playlist_tile = playlist,

    -- Circular dependency colors (fixed red - semantic error state)
    circular = circular,

    -- Fallback chip color
    fallback_chip = fallback,
  }
end

local function clamp_min_lightness(color, min_l)
  local lum = ark.Colors.luminance(color)
  if lum < (min_l or 0) then
    local factor = (min_l + 0.001) / max(lum, 0.001)
    return ark.Colors.adjust_brightness(color, factor)
  end
  return color
end

local function draw_lock_icon(dl, cx, cy, color)
  local base_w = M.CONFIG.lock_base_w
  local base_h = M.CONFIG.lock_base_h
  local handle_w = M.CONFIG.lock_handle_w
  local handle_h = M.CONFIG.lock_handle_h
  local top_w = M.CONFIG.lock_top_w
  local top_h = M.CONFIG.lock_top_h
  
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

function M.render(ctx, rect, item, state, animator, hover_config, tile_height, border_thickness, grid)
  if item.id and item.items then
    M.render_playlist(ctx, rect, item, state, animator, hover_config, tile_height, border_thickness, grid)
  else
    M.render_region(ctx, rect, item, state, animator, hover_config, tile_height, border_thickness, grid)
  end
end

function M.render_region(ctx, rect, region, state, animator, hover_config, tile_height, border_thickness, grid)
  local dl = ImGui.GetWindowDrawList(ctx)
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local key = "pool_" .. tostring(region.rid)

  animator:track(key, 'hover', state.hover and 1.0 or 0.0, hover_config and hover_config.animation_speed_hover or 12.0)
  local hover_factor = animator:get(key, 'hover')
  local base_color = region.color or M.CONFIG.bg_base
  local fx_config = TileFXConfig.get()

  BaseRenderer.draw_base_tile(ctx, dl, rect, base_color, fx_config, state, hover_factor)
  if state.selected and fx_config.ants_enabled then BaseRenderer.draw_marching_ants(dl, rect, base_color, fx_config) end

  local actual_height = tile_height or (y2 - y1)
  local show_text = actual_height >= M.CONFIG.responsive.hide_text_below
  local show_length = actual_height >= M.CONFIG.responsive.hide_length_below

  local right_elements = {}

  if show_text then
    local right_bound_x = BaseRenderer.calculate_text_right_bound(ctx, x2, M.CONFIG.text_margin_right, right_elements)
    local text_pos = BaseRenderer.calculate_text_position(ctx, rect, actual_height)
    BaseRenderer.draw_region_text(ctx, dl, text_pos, region, base_color, 0xFF, right_bound_x, grid, rect, key)
  end

  if show_length then BaseRenderer.draw_length_display(ctx, dl, rect, region, base_color, 0xFF) end
end

function M.render_playlist(ctx, rect, playlist, state, animator, hover_config, tile_height, border_thickness, grid)
  local dl = ImGui.GetWindowDrawList(ctx)
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local key = "pool_playlist_" .. tostring(playlist.id)
  local is_disabled = playlist.is_disabled or false

  -- Special rendering for circular reference tiles
  if is_disabled then
    M.render_circular_playlist(ctx, rect, playlist, state, animator, hover_config, tile_height, border_thickness, grid)
    return
  end

  -- Get theme-reactive colors
  local colors = get_colors()

  animator:track(key, 'hover', (state.hover and not is_disabled) and 1.0 or 0.0, hover_config and hover_config.animation_speed_hover or 12.0)
  animator:track(key, 'disabled', is_disabled and 1.0 or 0.0, 12.0)
  local hover_factor = animator:get(key, 'hover')
  local disabled_factor = animator:get(key, 'disabled')

  local base_color = colors.playlist_tile.base_color
  local playlist_data = {
    name = playlist.name or "Unnamed Playlist",
    chip_color = playlist.chip_color or colors.fallback_chip,
    total_duration = playlist.total_duration or 0
  }

  if disabled_factor > 0 then
    base_color = ark.Colors.desaturate(base_color, M.CONFIG.disabled.desaturate * disabled_factor)
    base_color = ark.Colors.adjust_brightness(base_color, 1.0 - ((1.0 - M.CONFIG.disabled.brightness) * disabled_factor))
    playlist_data.chip_color = ark.Colors.desaturate(playlist_data.chip_color, M.CONFIG.disabled.desaturate * disabled_factor)
    playlist_data.chip_color = ark.Colors.adjust_brightness(playlist_data.chip_color, 1.0 - ((1.0 - M.CONFIG.disabled.brightness) * disabled_factor))
    local minL = M.CONFIG.disabled.min_lightness or 0.28
    base_color = clamp_min_lightness(base_color, minL)
    playlist_data.chip_color = clamp_min_lightness(playlist_data.chip_color, minL)
  end

  local fx_config = TileFXConfig.get()
  -- Use chip color for border (pool tiles don't have playback progress)
  BaseRenderer.draw_base_tile(ctx, dl, rect, base_color, fx_config, state, hover_factor, 0, 0, playlist_data.chip_color)

  if state.selected and fx_config.ants_enabled then BaseRenderer.draw_marching_ants(dl, rect, playlist_data.chip_color, fx_config) end

  local actual_height = tile_height or (y2 - y1)
  local show_text = actual_height >= M.CONFIG.responsive.hide_text_below
  local show_badge = actual_height >= M.CONFIG.responsive.hide_text_below
  local show_length = actual_height >= M.CONFIG.responsive.hide_length_below
  local text_alpha_factor = 1.0 - (disabled_factor * (1.0 - M.CONFIG.disabled.alpha_multiplier))
  local text_alpha = (0xFF * text_alpha_factor)//1

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

    local name_color = colors.playlist_tile.name_color
    if disabled_factor > 0 then
      name_color = ark.Colors.adjust_brightness(name_color, 1.0 - ((1.0 - M.CONFIG.disabled.brightness) * disabled_factor))
    end
    if (state.hover or state.selected) and not is_disabled then
      name_color = Style.COLORS.TEXT_HOVER or ark.Colors.hexrgb("#FFFFFF")
    end

    BaseRenderer.draw_playlist_text(ctx, dl, text_pos, playlist_data, state, text_alpha, right_bound_x, name_color, actual_height, rect, grid, base_color, key)
  end

  if show_badge then
    local badge_text = string.format("[%d]", item_count)
    local bw, bh = ImGui.CalcTextSize(ctx, badge_text)
    bw, bh = bw * BaseRenderer.CONFIG.badge_font_scale, bh * BaseRenderer.CONFIG.badge_font_scale
    -- Calculate badge height with padding for positioning
    local badge_height = bh + M.CONFIG.badge_padding_y * 2
    local badge_x = x2 - bw - M.CONFIG.badge_padding_x * 2 - M.CONFIG.badge_margin
    local badge_y = BaseRenderer.calculate_badge_position(ctx, rect, badge_height, actual_height)
    local badge_x2, badge_y2 = badge_x + bw + M.CONFIG.badge_padding_x * 2, badge_y + bh + M.CONFIG.badge_padding_y * 2

    -- Badge background with alpha factor
    local badge_bg_alpha = (colors.badge_bg & 0xFF)
    local adjusted_alpha = ((badge_bg_alpha * text_alpha_factor) // 1)
    local badge_bg = (colors.badge_bg & 0xFFFFFF00) | adjusted_alpha

    ImGui.DrawList_AddRectFilled(dl, badge_x, badge_y, badge_x2, badge_y2, badge_bg, M.CONFIG.badge_rounding)

    local badge_border_color = playlist_data.chip_color
    if disabled_factor > 0 then
      badge_border_color = ark.Colors.adjust_brightness(badge_border_color, 1.0 - ((1.0 - M.CONFIG.disabled.brightness) * disabled_factor))
    end
    if (state.hover or state.selected) and not is_disabled then
      badge_border_color = playlist_data.chip_color
    end

    local border_opacity = colors.badge_border_opacity or 0.20
    ImGui.DrawList_AddRect(dl, badge_x, badge_y, badge_x2, badge_y2, ark.Colors.with_alpha(badge_border_color, border_opacity * 0xFF), M.CONFIG.badge_rounding, 0, 0.5)

    -- Badge text
    ark.Draw.text(dl, badge_x + M.CONFIG.badge_padding_x + M.CONFIG.badge_text_nudge_x, badge_y + M.CONFIG.badge_padding_y + M.CONFIG.badge_text_nudge_y, ark.Colors.with_alpha(colors.badge_text, text_alpha), badge_text)
  end

  -- Draw playlist duration in bottom right (like regions)
  if show_length then
    BaseRenderer.draw_playlist_length_display(ctx, dl, rect, playlist_data, base_color, text_alpha)
  end

  ImGui.SetCursorScreenPos(ctx, x1, y1)
  ImGui.InvisibleButton(ctx, key .. "_tooltip", x2 - x1, y2 - y1)
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, string.format("Playlist • %d items", item_count))
  end
end

function M.render_circular_playlist(ctx, rect, playlist, state, animator, hover_config, tile_height, border_thickness, grid)
  local dl = ImGui.GetWindowDrawList(ctx)
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local key = "pool_playlist_" .. tostring(playlist.id)

  -- Get circular dependency colors (semantic error state - stays red)
  local colors = get_colors()
  local circ = colors.circular

  animator:track(key, 'hover', 0, hover_config and hover_config.animation_speed_hover or 12.0)
  animator:track(key, 'disabled', 1.0, 12.0)

  local base_color = circ.base_color
  local playlist_data = {
    name = playlist.name or "Unnamed Playlist",
    chip_color = circ.chip_color
  }

  local fx_config = TileFXConfig.get()
  local border_color = circ.border_color

  -- Draw base tile with red border
  BaseRenderer.draw_base_tile(ctx, dl, rect, base_color, fx_config, state, 0, 0, 0, border_color)

  -- Draw marching ants if selected
  if state.selected and fx_config.ants_enabled then
    BaseRenderer.draw_marching_ants(dl, rect, border_color, fx_config)
  end

  -- Draw diagonal stripe pattern (baked to texture for performance)
  Background.draw_diagonal_stripes(ctx, dl, x1, y1, x2, y2, circ.stripe_spacing, circ.stripe_color, circ.stripe_width)

  local actual_height = tile_height or (y2 - y1)
  local show_text = actual_height >= M.CONFIG.responsive.hide_text_below
  local show_badge = actual_height >= M.CONFIG.responsive.hide_text_below

  local item_count = #playlist.items

  if show_text then
    local text_pos = BaseRenderer.calculate_text_position(ctx, rect, actual_height)

    -- Override playlist data to use red color for circular tiles
    local circular_playlist_data = {
      name = playlist_data.name,
      chip_color = circ.chip_color
    }

    -- Draw playlist name with red color
    BaseRenderer.draw_playlist_text(ctx, dl, text_pos, circular_playlist_data, state, 0xFF, x2 - M.CONFIG.text_margin_right, circ.text_color, nil, rect, grid, base_color, key)
  end

  if show_badge then
    -- Draw badge container with lock icon (same size as normal badge)
    local badge_text = string.format("[%d]", item_count)
    local bw, bh = ImGui.CalcTextSize(ctx, badge_text)
    bw, bh = bw * BaseRenderer.CONFIG.badge_font_scale, bh * BaseRenderer.CONFIG.badge_font_scale
    local badge_x = x2 - 25 - M.CONFIG.badge_margin
    local badge_y = y1 + M.CONFIG.badge_margin
    local badge_x2, badge_y2 = badge_x + 25, badge_y + 25

    ImGui.DrawList_AddRectFilled(dl, badge_x, badge_y, badge_x2, badge_y2, circ.badge_bg, M.CONFIG.badge_rounding)
    ImGui.DrawList_AddRect(dl, badge_x, badge_y, badge_x2, badge_y2, ark.Colors.with_alpha(circ.badge_border_color, 0x33), M.CONFIG.badge_rounding, 0, 0.5)

    -- Draw lock icon centered in badge
    local lock_x = badge_x + (badge_x2 - badge_x) * 0.5
    local lock_y = badge_y + (badge_y2 - badge_y) * 0.5
    draw_lock_icon(dl, lock_x, lock_y, circ.lock_color)
  end
  
  -- Tooltip
  ImGui.SetCursorScreenPos(ctx, x1, y1)
  ImGui.InvisibleButton(ctx, key .. "_tooltip", x2 - x1, y2 - y1)
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "Cannot drag to Active Grid: would create circular reference")
  end
end

return M