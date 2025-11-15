-- @noindex
-- ItemPicker/ui/tiles/renderers/midi.lua
-- MIDI tile renderer with piano roll visualization

local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local TileFX = require('rearkitekt.gui.fx.tile_fx')
local MarchingAnts = require('rearkitekt.gui.fx.marching_ants')
local BaseRenderer = require('ItemPicker.ui.tiles.renderers.base')

local M = {}

function M.render(ctx, dl, rect, item_data, tile_state, config, animator, visualization, cache_mgr, state)
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local tile_w, tile_h = x2 - x1, y2 - y1
  local center_x, center_y = (x1 + x2) / 2, (y1 + y2) / 2

  local overlay_alpha = state.overlay_alpha or 1.0
  local cascade_factor = BaseRenderer.calculate_cascade_factor(rect, overlay_alpha, config)

  if cascade_factor < 0.001 then return end

  -- Apply cascade animation transform
  local scale = config.TILE_RENDER.cascade.scale_from + (1.0 - config.TILE_RENDER.cascade.scale_from) * cascade_factor
  local y_offset = config.TILE_RENDER.cascade.y_offset * (1.0 - cascade_factor)

  local scaled_w = tile_w * scale
  local scaled_h = tile_h * scale
  local scaled_x1 = center_x - scaled_w / 2
  local scaled_y1 = center_y - scaled_h / 2 + y_offset
  local scaled_x2 = center_x + scaled_w / 2
  local scaled_y2 = center_y + scaled_h / 2 + y_offset

  -- Track animations
  local is_disabled = state.disabled and state.disabled.midi and state.disabled.midi[item_data.track_guid]

  if animator and item_data.key then
    animator:track(item_data.key, 'hover', tile_state.hover and 1.0 or 0.0, config.TILE_RENDER.animation_speed_hover)
    animator:track(item_data.key, 'enabled', is_disabled and 0.0 or 1.0, config.TILE_RENDER.disabled.fade_speed)
  end

  local hover_factor = animator and animator:get(item_data.key, 'hover') or (tile_state.hover and 1.0 or 0.0)
  local enabled_factor = animator and animator:get(item_data.key, 'enabled') or (is_disabled and 0.0 or 1.0)

  -- Get base color from item
  local base_color = item_data.color or 0xFF555555

  -- Apply disabled state
  local render_color = base_color
  if enabled_factor < 1.0 then
    render_color = Colors.desaturate(render_color, config.TILE_RENDER.disabled.desaturate * (1.0 - enabled_factor))
    render_color = Colors.adjust_brightness(render_color,
      1.0 - (1.0 - config.TILE_RENDER.disabled.brightness) * (1.0 - enabled_factor))
  end

  -- Apply cascade/enabled alpha
  local combined_alpha = cascade_factor * enabled_factor
  local base_alpha = (render_color & 0xFF) / 255
  local final_alpha = base_alpha * combined_alpha
  render_color = Colors.with_alpha(render_color, math.floor(final_alpha * 255))

  local text_alpha = math.floor(0xFF * combined_alpha)

  -- Calculate header height
  local header_height = math.max(
    config.TILE_RENDER.header.min_height,
    scaled_h * config.TILE_RENDER.header.height_ratio
  )

  -- Render base tile fill
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathLineTo(dl, scaled_x1, scaled_y1)
  ImGui.DrawList_PathLineTo(dl, scaled_x2, scaled_y1)
  ImGui.DrawList_PathLineTo(dl, scaled_x2, scaled_y2)
  ImGui.DrawList_PathLineTo(dl, scaled_x1, scaled_y2)
  ImGui.DrawList_PathFillConvex(dl, render_color)

  -- Apply TileFX
  local fx_config = {}
  for k, v in pairs(config.TILE_RENDER.tile_fx) do fx_config[k] = v end
  fx_config.rounding = config.TILE.ROUNDING
  fx_config.ants_replace_border = false

  TileFX.render_complete(dl, scaled_x1, scaled_y1, scaled_x2, scaled_y2, render_color,
    fx_config, tile_state.selected, hover_factor, 0, 0)

  -- Render header
  BaseRenderer.render_header_bar(dl, scaled_x1, scaled_y1, scaled_x2, header_height,
    base_color, combined_alpha, config)

  -- Render marching ants for selection
  if tile_state.selected and cascade_factor > 0.5 then
    local ant_color = Colors.same_hue_variant(
      base_color,
      config.TILE_RENDER.tile_fx.border_saturation,
      config.TILE_RENDER.tile_fx.border_brightness,
      math.floor(config.TILE_RENDER.tile_fx.ants_alpha * combined_alpha)
    )

    local inset = config.TILE_RENDER.tile_fx.ants_inset
    MarchingAnts.draw(
      dl,
      scaled_x1 + inset, scaled_y1 + inset, scaled_x2 - inset, scaled_y2 - inset,
      ant_color,
      config.TILE_RENDER.tile_fx.ants_thickness,
      config.TILE.ROUNDING,
      config.TILE_RENDER.tile_fx.ants_dash,
      config.TILE_RENDER.tile_fx.ants_gap,
      config.TILE_RENDER.tile_fx.ants_speed
    )
  end

  -- Render text and badge
  if cascade_factor > 0.3 then
    BaseRenderer.render_tile_text(ctx, dl, scaled_x1, scaled_y1, scaled_x2, header_height,
      item_data.name, item_data.index, item_data.total, base_color, text_alpha, config)
  end

  -- Render MIDI visualization (show even when disabled, just with toned down color)
  if item_data.item and cascade_factor > 0.2 then
    local content_y1 = scaled_y1 + header_height
    local content_w = scaled_w
    local content_h = scaled_y2 - content_y1

    ImGui.SetCursorScreenPos(ctx, scaled_x1, content_y1)
    ImGui.Dummy(ctx, content_w, content_h)

    local dark_color = BaseRenderer.get_dark_waveform_color(base_color, config)
    local midi_alpha = combined_alpha * config.TILE_RENDER.waveform.line_alpha
    dark_color = Colors.with_alpha(dark_color, math.floor(midi_alpha * 255))

    local thumbnail = cache_mgr and cache_mgr.get_midi_thumbnail(state.cache, item_data.item, content_w, content_h)
    if thumbnail then
      if visualization.DisplayMidiItemTransparent then
        ImGui.SetCursorScreenPos(ctx, scaled_x1, content_y1)
        ImGui.Dummy(ctx, content_w, content_h)
        visualization.DisplayMidiItemTransparent(ctx, thumbnail, dark_color, dl)
      end
    else
      BaseRenderer.render_placeholder(dl, scaled_x1, content_y1, scaled_x2, scaled_y2, render_color, combined_alpha)
      if state.job_queue and state.job_queue.add_midi_job then
        state.job_queue.add_midi_job(state.cache, item_data.item, content_w, content_h, item_data.key)
      end
    end
  end
end

return M
