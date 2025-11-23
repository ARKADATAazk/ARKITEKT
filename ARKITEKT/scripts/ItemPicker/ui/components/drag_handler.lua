-- @noindex
-- ItemPicker/ui/views/drag_handler.lua
-- Drag and drop handler with visual preview

local ImGui = require 'imgui' '0.10'
local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

-- Helper function to apply alpha to color
local function apply_alpha(color, alpha_factor)
  local current_alpha = color & 0xFF
  local new_alpha = math.floor(current_alpha * alpha_factor)
  return (color & 0xFFFFFF00) | math.min(255, math.max(0, new_alpha))
end

-- Get item data and color for stacked items
local function get_item_data(state, item_index)
  if not state.dragging_keys or item_index > #state.dragging_keys then
    -- Return data for the primary dragged item
    local take = state.item_to_add and reaper.GetActiveTake(state.item_to_add)
    return {
      media_item = state.item_to_add,
      name = state.item_to_add_name,
      color = state.item_to_add_color or hexrgb("#42E896FF"),
      is_midi = take and reaper.TakeIsMIDI(take) or false,
    }
  end

  -- Get item from lookup table
  local uuid = state.dragging_keys[item_index]
  local lookup = state.dragging_is_audio and state.audio_item_lookup or state.midi_item_lookup
  local item_data = lookup and lookup[uuid]

  if not item_data then
    return {
      media_item = state.item_to_add,
      name = state.item_to_add_name,
      color = state.item_to_add_color or hexrgb("#42E896FF"),
      is_midi = false,
    }
  end

  -- Extract color from track_color field
  local color
  local track_color = item_data.track_color or 0
  if (track_color & 0x01000000) ~= 0 then
    -- Has color: extract RGB from COLORREF (0x00BBGGRR)
    local colorref = track_color & 0x00FFFFFF
    local R = colorref & 255
    local G = (colorref >> 8) & 255
    local B = (colorref >> 16) & 255
    color = ImGui.ColorConvertDouble4ToU32(R/255, G/255, B/255, 1)
  else
    -- No color flag: use default grey
    color = ImGui.ColorConvertDouble4ToU32(85/255, 91/255, 91/255, 1)
  end

  local media_item = item_data[1]  -- MediaItem pointer
  local name = item_data[2] or "Unknown"
  local take = media_item and reaper.GetActiveTake(media_item)

  return {
    media_item = media_item,
    name = name,
    color = color,
    is_midi = take and reaper.TakeIsMIDI(take) or false,
  }
end

function M.handle_drag_logic(ctx, state, mini_font, visualization)
  local mouse_key = reaper.JS_Mouse_GetState(-1)
  local left_mouse_down = (mouse_key & 1) == 1
  local right_mouse_down = (mouse_key & 2) == 2

  -- Right-click closes the script instantly
  if right_mouse_down then
    state.should_close_after_drop = true
    return false
  end

  -- Check ALT modifier for toggling pooled MIDI copy mode
  -- Use JS_Mouse_GetState to detect ALT even after ImGui loses focus (during multi-drop)
  local mouse_state = reaper.JS_Mouse_GetState(0xFF)
  local alt_pressed = (mouse_state & 16) ~= 0  -- Bit 4 = Alt
  -- Only relevant for MIDI items
  local is_midi_drag = state.dragging_is_audio == false

  -- ALT toggles the current pooled state (XOR logic)
  -- If source is pooled, ALT unpools; if source is not pooled, ALT pools
  local original_pooled = state.original_pooled_midi_state or false
  local effective_pooled = (original_pooled and not alt_pressed) or (not original_pooled and alt_pressed)
  state.alt_pool_mode = is_midi_drag and effective_pooled

  -- Track mouse state for SHIFT multi-drop behavior
  if left_mouse_down then
    state.mouse_was_pressed_after_drop = true
  end

  if not left_mouse_down then
    -- Only allow drop if mouse was pressed since last drop (or this is the first drop)
    if state.waiting_for_new_click then
      return false  -- Continue dragging, don't drop yet
    end
    return true  -- Mouse released, insert item
  end

  local arrange_window = reaper.JS_Window_Find("trackview", true)
  local rv, w_x1, w_y1, w_x2, w_y2 = reaper.JS_Window_GetRect(arrange_window)
  local w_width, w_height = w_x2 - w_x1, w_y2 - w_y1

  ImGui.SetNextWindowPos(ctx, w_x1, w_y1)
  ImGui.SetNextWindowSize(ctx, w_width, w_height - 17)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowBorderSize, 0)

  local _, _ = ImGui.Begin(ctx, "drag_target_window", false,
    ImGui.WindowFlags_NoCollapse | ImGui.WindowFlags_NoInputs | ImGui.WindowFlags_NoTitleBar |
    ImGui.WindowFlags_NoFocusOnAppearing | ImGui.WindowFlags_NoBackground)

  local arrange_zoom_level = reaper.GetHZoomLevel()
  local mouse_x, mouse_y = reaper.GetMousePosition()
  local m_window, m_segment, m_details = reaper.BR_GetMouseCursorContext()
  local track, str = reaper.GetThingFromPoint(mouse_x, mouse_y)

  -- Find last visible track
  local last_track
  for i = reaper.CountTracks(0) - 1, 0, -1 do
    local tr = reaper.GetTrack(0, i)
    if tr and reaper.IsTrackVisible(tr, false) then
      last_track = tr
      break
    end
  end

  -- Apply snap to grid if enabled
  if reaper.GetToggleCommandState(1157) ~= 0 then
    local mouse_position_in_arrange = reaper.BR_GetMouseCursorContext_Position()
    local snapped_position = reaper.SnapToGrid(0, mouse_position_in_arrange)
    local snap_factor = snapped_position - mouse_position_in_arrange
    snap_factor = snap_factor * arrange_zoom_level
    mouse_x = mouse_x + snap_factor
  end

  local rect_x1, rect_y1, rect_x2, rect_y2

  -- Validate state.item_to_add is a valid MediaItem
  if not state.item_to_add or not reaper.ValidatePtr2(0, state.item_to_add, "MediaItem*") then
    ImGui.PopStyleVar(ctx, 1)
    ImGui.End(ctx)
    return false
  end

  local take = reaper.GetActiveTake(state.item_to_add)
  if not take then
    ImGui.PopStyleVar(ctx, 1)
    ImGui.End(ctx)
    return false
  end

  local source = reaper.GetMediaItemTake_Source(take)
  local item_length = source and reaper.GetMediaSourceLength(source) or 0

  if track and (str == "arrange" or (str and str:find('envelope'))) then
    -- Over existing track
    local track_height = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")
    local track_y = reaper.GetMediaTrackInfo_Value(track, "I_TCPY")

    rect_x1 = mouse_x
    rect_y1 = w_y1 + track_y
    rect_x2 = mouse_x + item_length * arrange_zoom_level
    rect_y2 = rect_y1 + track_height

    state.out_of_bounds = nil
  elseif m_window == "arrange" and m_segment == "empty" and last_track then
    -- Over empty space below tracks
    local track_height = reaper.GetMediaTrackInfo_Value(last_track, "I_WNDH")
    local track_y = reaper.GetMediaTrackInfo_Value(last_track, "I_TCPY")

    rect_x1 = mouse_x
    rect_y1 = w_y1 + track_y + track_height
    rect_x2 = mouse_x + item_length * arrange_zoom_level
    rect_y2 = w_y1 + track_y + track_height + 17

    state.out_of_bounds = true
  else
    state.out_of_bounds = nil
  end

  -- Draw insertion preview
  if rect_x1 then
    -- Grey crosshair lines instead of blue
    local line_color = ImGui.ColorConvertDouble4ToU32(0.5, 0.5, 0.5, 0.8)

    -- Get the items being dragged
    local dragging_count = (state.dragging_keys and #state.dragging_keys) or 1
    local current_x = rect_x1

    -- Draw each item being dragged with its actual color and visualization
    for i = 1, dragging_count do
      local item_data = get_item_data(state, i)
      local media_item = item_data.media_item

      if media_item and reaper.ValidatePtr2(0, media_item, "MediaItem*") then
        -- Get actual item length (works correctly for both audio and MIDI)
        local item_len = reaper.GetMediaItemInfo_Value(media_item, "D_LENGTH")
        local item_width = item_len * arrange_zoom_level

        local item_take = reaper.GetActiveTake(media_item)
        if item_take then
          -- Get the item's actual color
          local base_color = item_data.color
          local item_color = base_color

          -- Apply base fill adjustments for consistency with tiles
          if item_color then
            -- Convert to RGB components and desaturate/adjust brightness
            local r, g, b = ImGui.ColorConvertU32ToDouble4(item_color)
            local h, s, v = ImGui.ColorConvertRGBtoHSV(r, g, b)
            s = s * 0.7  -- Desaturate a bit
            v = v * 0.5  -- Darken for preview
            r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)
            item_color = ImGui.ColorConvertDouble4ToU32(r, g, b, 0.8)  -- 80% opacity
          else
            -- Fallback to grey
            item_color = ImGui.ColorConvertDouble4ToU32(177 / 256, 180 / 256, 180 / 256, 0.8)
          end

          -- Draw base rectangle with item color
          ImGui.DrawList_AddRectFilled(state.draw_list,
            current_x, rect_y1,
            current_x + item_width, rect_y2,
            item_color)

          -- Add visualization if available
          local item_uuid = state.dragging_keys and state.dragging_keys[i]
          if item_uuid and state.runtime_cache and not state.skip_visualizations then
            -- Get dark waveform color for visualization
            local r, g, b = ImGui.ColorConvertU32ToDouble4(base_color)
            local h, s, v = ImGui.ColorConvertRGBtoHSV(r, g, b)
            s = 0.3
            v = 0.15
            r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)
            local viz_color = ImGui.ColorConvertDouble4ToU32(r, g, b, 0.7)

            if item_data.is_midi then
              -- MIDI visualization
              local thumbnail = state.runtime_cache.midi_thumbnails and state.runtime_cache.midi_thumbnails[item_uuid]
              if thumbnail and visualization.DisplayMidiItemTransparent then
                ImGui.SetCursorScreenPos(ctx, current_x, rect_y1)
                ImGui.Dummy(ctx, item_width, rect_y2 - rect_y1)
                visualization.DisplayMidiItemTransparent(ctx, thumbnail, viz_color, state.draw_list)
              end
            else
              -- Audio waveform visualization
              local waveform = state.runtime_cache.waveforms and state.runtime_cache.waveforms[item_uuid]
              if waveform and visualization.DisplayWaveformTransparent then
                ImGui.SetCursorScreenPos(ctx, current_x, rect_y1)
                ImGui.Dummy(ctx, item_width, rect_y2 - rect_y1)
                visualization.DisplayWaveformTransparent(ctx, waveform, viz_color, state.draw_list,
                  math.floor(item_width), item_uuid, state.runtime_cache, true, false)
              end
            end
          end

          current_x = current_x + item_width
        end
      end
    end

    -- Calculate total width for crosshair placement
    local total_x2 = current_x

    -- Crosshair lines (grey)
    ImGui.DrawList_AddLine(state.draw_list, rect_x1, w_y1, rect_x1, w_y2, line_color, 2)
    ImGui.DrawList_AddLine(state.draw_list, total_x2, w_y1, total_x2, w_y2, line_color, 2)
    ImGui.DrawList_AddLine(state.draw_list, w_x1, rect_y1, w_x2, rect_y1, line_color, 2)
    ImGui.DrawList_AddLine(state.draw_list, w_x1, rect_y2, w_x2, rect_y2, line_color, 2)
  end

  ImGui.PopStyleVar(ctx, 1)
  ImGui.End(ctx)

  return false  -- Continue dragging
end

function M.render_drag_preview(ctx, state, mini_font, visualization, config)
  if not state.item_to_add_width or not state.item_to_add_height then
    return
  end

  -- Validate state.item_to_add is a valid MediaItem
  if not state.item_to_add or not reaper.ValidatePtr2(0, state.item_to_add, "MediaItem*") then
    return
  end

  local mouse_x, mouse_y = reaper.GetMousePosition()
  ImGui.SetNextWindowPos(ctx, mouse_x, mouse_y)

  if ImGui.Begin(ctx, "MouseFollower", false,
    ImGui.WindowFlags_NoInputs | ImGui.WindowFlags_TopMost | ImGui.WindowFlags_NoTitleBar |
    ImGui.WindowFlags_NoBackground | ImGui.WindowFlags_AlwaysAutoResize) then

    ImGui.PushFont(ctx, mini_font, 13)

    local dragging_count = (state.dragging_keys and #state.dragging_keys) or 1
    local visible_count = math.min(dragging_count, 4)  -- Show max 4 stacked items

    -- Reserve space at top for badge if dragging multiples (so it doesn't get clipped)
    if dragging_count > 1 then
      ImGui.Dummy(ctx, 1, 12)  -- Reserve 12px at top for half the badge
    end

    local cursor_x, cursor_y = ImGui.GetItemRectMin(ctx)
    local base_x = cursor_x + ImGui.StyleVar_ChildBorderSize
    local base_y = cursor_y + ImGui.StyleVar_ChildBorderSize

    -- Configuration for stacking (matching original tile design)
    local stack_offset_x = 8
    local stack_offset_y = 8
    -- When dragging multiples, make front tile slightly transparent so you can see others behind
    local opacity_levels = visible_count > 1 and {0.85, 0.70, 0.50, 0.35} or {1.0, 0.75, 0.55, 0.40}
    local tile_rounding = config and config.TILE.ROUNDING or 4
    local glow_size = 4

    -- Calculate total bounds including stacking
    local total_width = state.item_to_add_width + (visible_count - 1) * stack_offset_x
    local total_height = state.item_to_add_height + (visible_count - 1) * stack_offset_y

    -- Draw stacked tiles from back to front
    for i = visible_count, 1, -1 do
      local offset_x = (i - 1) * stack_offset_x
      local offset_y = (i - 1) * stack_offset_y
      local x1 = base_x + offset_x
      local y1 = base_y + offset_y
      local x2 = x1 + state.item_to_add_width
      local y2 = y1 + state.item_to_add_height

      -- Front tile (i=1) should be fully opaque, back tiles should fade
      local opacity = opacity_levels[i] or 0.3

      -- Get item data with proper color and info
      local item_data = get_item_data(state, i)
      local base_color = item_data.color

      -- Apply base tile fill adjustments (matching original tiles)
      -- Note: We skip muted/disabled effects - always show items as normal
      local render_color = base_color
      if config and config.TILE_RENDER then
        local sat_factor = config.TILE_RENDER.base_fill.saturation_factor
        local bright_factor = config.TILE_RENDER.base_fill.brightness_factor
        render_color = Colors.desaturate(render_color, 1.0 - sat_factor)
        render_color = Colors.adjust_brightness(render_color, bright_factor)
      end

      -- Apply opacity to the tile fill color
      local tile_fill_color = apply_alpha(render_color, opacity)

      -- Draw halo/glow shadow around the tile (all sides)
      local shadow_layers = 5

      -- Multiple shadow layers for soft glow effect
      for layer = shadow_layers, 1, -1 do
        local shadow_alpha = (0.12 / layer) * opacity  -- Softer shadows for back tiles
        local shadow_color = apply_alpha(hexrgb("#000000FF"), shadow_alpha)
        local expand = layer * 1.5

        ImGui.DrawList_AddRectFilled(state.draw_list,
          x1 - expand, y1 - expand,
          x2 + expand, y2 + expand,
          shadow_color, tile_rounding + expand)
      end

      -- Base tile fill (matching original: just filled rectangle with rounding)
      ImGui.DrawList_AddRectFilled(state.draw_list, x1, y1, x2, y2, tile_fill_color, tile_rounding)

      -- Calculate header height
      local header_height = ImGui.GetTextLineHeightWithSpacing(ctx)
      local content_y = y1 + header_height
      local content_h = y2 - content_y
      local content_w = x2 - x1

      -- Render visualization BEFORE header (so header overlays it, matching original tiles)
      -- Get the UUID for this item to look up in runtime cache
      local item_uuid = state.dragging_keys and state.dragging_keys[i]

      if item_uuid and state.runtime_cache and not state.skip_visualizations then
        -- Get dark waveform color for visualization (matching original tiles)
        local r, g, b = ImGui.ColorConvertU32ToDouble4(base_color)
        local h, s, v = ImGui.ColorConvertRGBtoHSV(r, g, b)
        -- Use config values or defaults
        local waveform_sat = (config and config.TILE_RENDER and config.TILE_RENDER.waveform.saturation) or 0.3
        local waveform_bright = (config and config.TILE_RENDER and config.TILE_RENDER.waveform.brightness) or 0.15
        local waveform_alpha = (config and config.TILE_RENDER and config.TILE_RENDER.waveform.line_alpha) or 0.8
        s = waveform_sat
        v = waveform_bright
        r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)
        local dark_color = ImGui.ColorConvertDouble4ToU32(r, g, b, opacity * waveform_alpha)

        if item_data.is_midi then
          -- MIDI visualization from runtime cache
          local thumbnail = state.runtime_cache.midi_thumbnails and state.runtime_cache.midi_thumbnails[item_uuid]
          if thumbnail and visualization.DisplayMidiItemTransparent then
            ImGui.SetCursorScreenPos(ctx, x1, content_y)
            ImGui.Dummy(ctx, content_w, content_h)
            visualization.DisplayMidiItemTransparent(ctx, thumbnail, dark_color, state.draw_list)
          end
        else
          -- Audio waveform visualization from runtime cache
          local waveform = state.runtime_cache.waveforms and state.runtime_cache.waveforms[item_uuid]
          if waveform and visualization.DisplayWaveformTransparent then
            ImGui.SetCursorScreenPos(ctx, x1, content_y)
            ImGui.Dummy(ctx, content_w, content_h)
            local use_filled = true
            local show_zero_line = false
            visualization.DisplayWaveformTransparent(ctx, waveform, dark_color, state.draw_list,
              math.floor(content_w), item_uuid, state.runtime_cache, use_filled, show_zero_line)
          end
        end
      end

      -- Render header bar overlay (matching original tile rendering)
      -- Calculate header color with saturation/brightness adjustments
      local header_color = render_color
      if config and config.TILE_RENDER and config.TILE_RENDER.header then
        local r, g, b = ImGui.ColorConvertU32ToDouble4(render_color)
        local h, s, v = ImGui.ColorConvertRGBtoHSV(r, g, b)
        s = s * config.TILE_RENDER.header.saturation_factor
        v = v * config.TILE_RENDER.header.brightness_factor
        r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)
        local header_alpha = (config.TILE_RENDER.header.alpha / 255) * opacity
        header_color = ImGui.ColorConvertDouble4ToU32(r, g, b, header_alpha)
      else
        -- Fallback: dark overlay
        header_color = apply_alpha(hexrgb("#00000040"), opacity)
      end

      -- Add text shadow overlay
      local text_shadow = hexrgb("#00000000")
      if config and config.TILE_RENDER and config.TILE_RENDER.header then
        text_shadow = apply_alpha(config.TILE_RENDER.header.text_shadow, opacity)
      end

      local round_flags = ImGui.DrawFlags_RoundCornersTop
      ImGui.DrawList_AddRectFilled(state.draw_list, x1, y1, x2, y1 + header_height, header_color, tile_rounding, round_flags)
      ImGui.DrawList_AddRectFilled(state.draw_list, x1, y1, x2, y1 + header_height, text_shadow, tile_rounding, round_flags)

      -- Item name (use config text color or default white)
      local text_color = (config and config.TILE_RENDER and config.TILE_RENDER.text.primary_color) or hexrgb("#FFFFFFFF")
      local name_color = apply_alpha(text_color, opacity)
      local text_x = x1 + 8
      local text_y = y1 + (header_height - ImGui.GetTextLineHeight(ctx)) / 2
      ImGui.DrawList_AddText(state.draw_list, text_x, text_y, name_color, item_data.name)
    end

    -- Count badge (top-right, matching tile badge style)
    if dragging_count > 1 then
      local badge_text = tostring(dragging_count)
      local badge_w, badge_h = ImGui.CalcTextSize(ctx, badge_text)

      -- Badge styling (matching tile badges)
      local padding_x = 8
      local padding_y = 4
      local badge_width = badge_w + padding_x * 2
      local badge_height = badge_h + padding_y * 2
      local rounding = 4

      -- Position at top-right corner
      local badge_x = base_x + total_width - badge_width - 4
      local badge_y = base_y - badge_height / 2

      -- Badge shadow
      ImGui.DrawList_AddRectFilled(state.draw_list,
        badge_x + 2, badge_y + 2,
        badge_x + badge_width + 2, badge_y + badge_height + 2,
        hexrgb("#00000066"), rounding)

      -- Badge background (90% opacity dark grey)
      ImGui.DrawList_AddRectFilled(state.draw_list,
        badge_x, badge_y,
        badge_x + badge_width, badge_y + badge_height,
        hexrgb("#1A1A1AE6"), rounding)

      -- Badge border (subtle)
      ImGui.DrawList_AddRect(state.draw_list,
        badge_x, badge_y,
        badge_x + badge_width, badge_y + badge_height,
        hexrgb("#FFFFFF33"), rounding, 0, 1)

      -- Badge text (centered)
      local text_x = badge_x + padding_x
      local text_y = badge_y + padding_y
      ImGui.DrawList_AddText(state.draw_list, text_x, text_y, hexrgb("#FFFFFFFF"), badge_text)
    end

    -- ALT + MIDI pooled badge (teal, shown when ALT is held for MIDI items)
    if state.alt_pool_mode then
      local pool_badge_text = tostring(dragging_count) .. " midi pooled"
      local pool_badge_w, pool_badge_h = ImGui.CalcTextSize(ctx, pool_badge_text)

      -- Badge styling
      local padding_x = 8
      local padding_y = 4
      local pool_badge_width = pool_badge_w + padding_x * 2
      local pool_badge_height = pool_badge_h + padding_y * 2
      local rounding = 4

      -- Position below the tiles (centered)
      local pool_badge_x = base_x + (total_width - pool_badge_width) / 2
      local pool_badge_y = base_y + total_height + 8

      -- Badge shadow
      ImGui.DrawList_AddRectFilled(state.draw_list,
        pool_badge_x + 2, pool_badge_y + 2,
        pool_badge_x + pool_badge_width + 2, pool_badge_y + pool_badge_height + 2,
        hexrgb("#00000066"), rounding)

      -- Badge background (teal color)
      ImGui.DrawList_AddRectFilled(state.draw_list,
        pool_badge_x, pool_badge_y,
        pool_badge_x + pool_badge_width, pool_badge_y + pool_badge_height,
        hexrgb("#008B8BE6"), rounding)

      -- Badge border (lighter teal)
      ImGui.DrawList_AddRect(state.draw_list,
        pool_badge_x, pool_badge_y,
        pool_badge_x + pool_badge_width, pool_badge_y + pool_badge_height,
        hexrgb("#20B2AA66"), rounding, 0, 1)

      -- Badge text (white, centered)
      local text_x = pool_badge_x + padding_x
      local text_y = pool_badge_y + padding_y
      ImGui.DrawList_AddText(state.draw_list, text_x, text_y, hexrgb("#FFFFFFFF"), pool_badge_text)
    end

    -- Dummy to reserve space
    ImGui.Dummy(ctx, total_width, total_height)

    ImGui.PopFont(ctx)
    ImGui.End(ctx)
  end
end

return M
