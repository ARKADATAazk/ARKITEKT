-- @noindex
-- ItemPicker/ui/tiles/renderers/midi.lua
-- MIDI tile renderer with piano roll visualization

local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local TileFX = require('rearkitekt.gui.rendering.tile.renderer')
local MarchingAnts = require('rearkitekt.gui.fx.interactions.marching_ants')
local BaseRenderer = require('ItemPicker.ui.grids.renderers.base')
local Shapes = require('rearkitekt.gui.rendering.shapes')

local M = {}

function M.render(ctx, dl, rect, item_data, tile_state, config, animator, visualization, state)
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

  -- Track playback progress
  local playback_progress, playback_fade = 0, 0
  if state.is_previewing and state.is_previewing(item_data.item) then
    playback_progress = state.get_preview_progress and state.get_preview_progress() or 0
    -- Store progress for fade out
    if animator and item_data.key then
      animator:track(item_data.key, 'last_progress', playback_progress, 999)  -- Instant update
      -- Time-based fade: fade in when playing, fade out at 100% or when stopped
      local target_fade = (playback_progress > 0 and playback_progress < 1.0) and 1.0 or 0.0
      local current_fade = animator:get(item_data.key, 'progress_fade') or 0
      -- Fast fade in (8.0), fade out in 1 second (1.0)
      local fade_speed = (target_fade > current_fade) and 8.0 or 1.0
      animator:track(item_data.key, 'progress_fade', target_fade, fade_speed)
      playback_fade = animator:get(item_data.key, 'progress_fade')
    else
      playback_fade = 1.0
    end
  else
    -- Not currently playing this item, fade out at last known progress
    if animator and item_data.key then
      playback_progress = animator:get(item_data.key, 'last_progress') or 0
      animator:track(item_data.key, 'progress_fade', 0.0, 1.0)  -- 1 second fade out
      playback_fade = animator:get(item_data.key, 'progress_fade')
    end
  end

  -- Get base color from item
  local base_color = item_data.color or 0xFF555555

  -- Apply disabled state
  local render_color = base_color
  if enabled_factor < 1.0 then
    render_color = Colors.desaturate(render_color, config.TILE_RENDER.disabled.desaturate * (1.0 - enabled_factor))
    render_color = Colors.adjust_brightness(render_color,
      1.0 - (1.0 - config.TILE_RENDER.disabled.brightness) * (1.0 - enabled_factor))
  end

  -- Apply cascade/enabled alpha with minimum for disabled items
  local min_alpha_factor = (config.TILE_RENDER.disabled.min_alpha or 0x33) / 255
  local alpha_factor = min_alpha_factor + (1.0 - min_alpha_factor) * enabled_factor
  local combined_alpha = cascade_factor * alpha_factor
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

  -- Apply TileFX (optimized: reuse config table instead of copying)
  local fx_config = config.TILE_RENDER.tile_fx
  local saved_rounding = fx_config.rounding
  local saved_ants_replace = fx_config.ants_replace_border
  fx_config.rounding = config.TILE.ROUNDING
  fx_config.ants_replace_border = false

  TileFX.render_complete(dl, scaled_x1, scaled_y1, scaled_x2, scaled_y2, render_color,
    fx_config, tile_state.selected, hover_factor, playback_progress, playback_fade)

  -- Restore original values
  fx_config.rounding = saved_rounding
  fx_config.ants_replace_border = saved_ants_replace

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

  -- Check if item is favorited
  local is_favorite = state.favorites and state.favorites.midi and state.favorites.midi[item_data.track_guid]

  -- Calculate star badge space
  local star_badge_size = 18
  local star_padding = 4
  local text_right_margin = is_favorite and (star_badge_size + star_padding * 2) or 0

  -- Check if this tile is being renamed
  local is_renaming = state.rename_active and state.rename_uuid == item_data.uuid and not state.rename_is_audio

  -- Populate rename text if it's empty (happens when moving to next item in batch)
  if is_renaming and (not state.rename_text or state.rename_text == "") then
    state.rename_text = item_data.name
  end

  -- Render text and badge (with reduced width if star is present)
  if cascade_factor > 0.3 then
    if is_renaming then
      -- Render inline rename input
      local input_x = scaled_x1 + 8
      local input_y = scaled_y1 + 4
      local input_w = (scaled_x2 - text_right_margin) - input_x - 4
      local input_h = header_height - 8

      ImGui.SetCursorScreenPos(ctx, input_x, input_y)
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, 2, 2)
      ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, Colors.hexrgb("#1A1A1A"))
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, Colors.hexrgb("#FFFFFF"))
      ImGui.SetNextItemWidth(ctx, input_w)

      -- Auto-focus on first frame
      if not state.rename_focused then
        ImGui.SetKeyboardFocusHere(ctx)
        state.rename_focused = true
        state.rename_focus_frame = true  -- Mark this as the focus frame
      end

      local changed, new_text = ImGui.InputText(ctx, "##rename", state.rename_text, ImGui.InputTextFlags_EnterReturnsTrue)

      -- Update rename text in real-time (even if not committed with Enter)
      if not changed then
        state.rename_text = new_text
      end

      if changed then
        -- Get fresh item data from lookup
        local lookup_data = state.midi_item_lookup[item_data.uuid]
        if not lookup_data then
          -- Fallback: try to use item_data.item directly
          lookup_data = item_data
        end

        local item = lookup_data.item or lookup_data[1]

        -- Validate item pointer
        if not item or not reaper.ValidatePtr2(0, item, "MediaItem*") then
          reaper.ShowConsoleMsg("[RENAME ERROR] Invalid MediaItem pointer for UUID: " .. tostring(item_data.uuid) .. "\n")
          state.rename_active = false
          state.rename_uuid = nil
          state.rename_focused = false
          state.rename_queue = nil
          state.rename_queue_index = 0
          state.rename_focus_frame = false
          ImGui.PopStyleColor(ctx, 2)
          ImGui.PopStyleVar(ctx)
          return
        end

        -- Apply rename to the item
        reaper.Undo_BeginBlock()
        local take = reaper.GetActiveTake(item)
        if take then
          reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", new_text, true)

          -- Update the name in the lookup immediately so tile reflects change
          if state.midi_item_lookup[item_data.uuid] then
            -- Update array format: {item, name, track_muted, item_muted, uuid, pool_count}
            if type(state.midi_item_lookup[item_data.uuid]) == "table" then
              state.midi_item_lookup[item_data.uuid][2] = new_text
            end
          end

          -- Also update in the midi_items array
          if state.midi_items then
            for track_guid, items_array in pairs(state.midi_items) do
              for _, entry in ipairs(items_array) do
                if entry.uuid == item_data.uuid then
                  entry[2] = new_text  -- Update name in array
                  break
                end
              end
            end
          end

          -- Update the current item_data name for immediate display
          item_data.name = new_text

          reaper.UpdateArrange()
        end
        reaper.Undo_EndBlock("Rename item take", -1)

        -- Check if there are more items in the batch rename queue
        if state.rename_queue and state.rename_queue_index < #state.rename_queue then
          -- Move to next item in queue
          state.rename_queue_index = state.rename_queue_index + 1
          local next_uuid = state.rename_queue[state.rename_queue_index]

          -- Find the next item to rename
          state.rename_uuid = next_uuid
          state.rename_focused = false
          state.rename_text = ""  -- Will be populated on next frame
          state.rename_focus_frame = false
        else
          -- No more items in queue, end rename session
          state.rename_active = false
          state.rename_uuid = nil
          state.rename_focused = false
          state.rename_queue = nil
          state.rename_queue_index = 0
          state.rename_focus_frame = false
        end
      end

      -- Cancel on Escape or focus loss (but NOT on the frame we just set focus)
      if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
        -- Cancel entire rename session on Escape
        state.rename_active = false
        state.rename_uuid = nil
        state.rename_focused = false
        state.rename_queue = nil
        state.rename_queue_index = 0
        state.rename_focus_frame = false
      elseif state.rename_focused and not ImGui.IsItemActive(ctx) and not state.rename_focus_frame then
        -- Only cancel on focus loss if not in batch mode AND not on focus frame
        if not state.rename_queue or #state.rename_queue <= 1 then
          state.rename_active = false
          state.rename_uuid = nil
          state.rename_focused = false
          state.rename_focus_frame = false
        end
      end

      -- Clear focus frame flag after first frame
      if state.rename_focus_frame then
        state.rename_focus_frame = false
      end

      ImGui.PopStyleColor(ctx, 2)
      ImGui.PopStyleVar(ctx)
    else
      -- Normal text rendering
      local text_x2 = scaled_x2 - text_right_margin
      BaseRenderer.render_tile_text(ctx, dl, scaled_x1, scaled_y1, text_x2, header_height,
        item_data.name, item_data.index, item_data.total, base_color, text_alpha, config)
    end
  end

  -- Render favorite star badge
  if cascade_factor > 0.5 and is_favorite then
    local star_x = scaled_x2 - star_badge_size - star_padding
    local star_y = scaled_y1 + star_padding
    Shapes.draw_favorite_star(ctx, dl, star_x, star_y, star_badge_size, combined_alpha, is_favorite)
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

    -- Skip all MIDI thumbnail rendering if skip_visualizations is enabled (fast mode)
    if not state.skip_visualizations then
      -- Check runtime cache for MIDI thumbnail
      local thumbnail = state.runtime_cache and state.runtime_cache.midi_thumbnails[item_data.uuid]
      if thumbnail then
        if visualization.DisplayMidiItemTransparent then
          ImGui.SetCursorScreenPos(ctx, scaled_x1, content_y1)
          ImGui.Dummy(ctx, content_w, content_h)
          visualization.DisplayMidiItemTransparent(ctx, thumbnail, dark_color, dl)
        end
      else
        -- Show placeholder and queue thumbnail generation
        BaseRenderer.render_placeholder(dl, scaled_x1, content_y1, scaled_x2, scaled_y2, render_color, combined_alpha)

        -- Queue MIDI job
        if state.job_queue and state.job_queue.add_midi_job then
          state.job_queue.add_midi_job(item_data.item, content_w, content_h, item_data.uuid)
        end
      end
    end
  end

  -- Render pool count badge (bottom right) if more than 1 instance
  if item_data.pool_count and item_data.pool_count > 1 and cascade_factor > 0.5 then
    local pool_text = "×" .. tostring(item_data.pool_count)
    local text_w, text_h = ImGui.CalcTextSize(ctx, pool_text)
    local badge_padding = 4
    local badge_w = text_w + badge_padding * 2
    local badge_h = text_h + badge_padding * 2
    local badge_x = scaled_x2 - badge_w - 4
    local badge_y = scaled_y2 - badge_h - 4
    local badge_rounding = 3

    -- Badge background
    local badge_bg = Colors.hexrgb("#14181C")
    badge_bg = Colors.with_alpha(badge_bg, math.floor(combined_alpha * 200))
    ImGui.DrawList_AddRectFilled(dl, badge_x, badge_y, badge_x + badge_w, badge_y + badge_h, badge_bg, badge_rounding)

    -- Badge border
    local badge_border = Colors.hexrgb("#2A2A2A")
    badge_border = Colors.with_alpha(badge_border, math.floor(combined_alpha * 100))
    ImGui.DrawList_AddRect(dl, badge_x, badge_y, badge_x + badge_w, badge_y + badge_h, badge_border, badge_rounding, 0, 1)

    -- Pool count text
    local text_color = Colors.hexrgb("#AAAAAA")
    text_color = Colors.with_alpha(text_color, math.floor(combined_alpha * 255))
    ImGui.DrawList_AddText(dl, badge_x + badge_padding, badge_y + badge_padding, text_color, pool_text)
  end
end

return M
