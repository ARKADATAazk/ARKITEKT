-- @noindex
-- ItemPicker/ui/views/drag_handler.lua
-- Drag and drop handler with visual preview

local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

function M.handle_drag_logic(ctx, state, mini_font)
  local mouse_key = reaper.JS_Mouse_GetState(-1)
  local left_mouse_down = (mouse_key & 1) == 1

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
    if reaper.IsTrackVisible(tr, false) then
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
    local preview_color = ImGui.ColorConvertDouble4ToU32(177 / 256, 180 / 256, 180 / 256, 1)
    local line_color = ImGui.ColorConvertDouble4ToU32(16 / 256, 133 / 256, 130 / 256, 1)

    ImGui.DrawList_AddRectFilled(state.draw_list, rect_x1, rect_y1, rect_x2, rect_y2, preview_color)

    -- Crosshair lines
    ImGui.DrawList_AddLine(state.draw_list, rect_x1, w_y1, rect_x1, w_y2, line_color, 2)
    ImGui.DrawList_AddLine(state.draw_list, rect_x2, w_y1, rect_x2, w_y2, line_color, 2)
    ImGui.DrawList_AddLine(state.draw_list, w_x1, rect_y1, w_x2, rect_y1, line_color, 2)
    ImGui.DrawList_AddLine(state.draw_list, w_x1, rect_y2, w_x2, rect_y2, line_color, 2)
  end

  ImGui.PopStyleVar(ctx, 1)
  ImGui.End(ctx)

  return false  -- Continue dragging
end

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

function M.render_drag_preview(ctx, state, mini_font, visualization)
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

    local cursor_x, cursor_y = ImGui.GetItemRectMin(ctx)
    local base_x = cursor_x + ImGui.StyleVar_ChildBorderSize
    local base_y = cursor_y + ImGui.StyleVar_ChildBorderSize

    local dragging_count = (state.dragging_keys and #state.dragging_keys) or 1
    local visible_count = math.min(dragging_count, 4)  -- Show max 4 stacked items

    -- Configuration for stacking (matching original tile design)
    local stack_offset_x = 8
    local stack_offset_y = 8
    local opacity_levels = {1.0, 0.75, 0.55, 0.40}  -- Opacity for each layer
    local tile_rounding = 4  -- Match config.TILE.ROUNDING
    local glow_size = 4

    -- Calculate total bounds including stacking
    local total_width = state.item_to_add_width + (visible_count - 1) * stack_offset_x
    local total_height = state.item_to_add_height + (visible_count - 1) * stack_offset_y

    -- Draw shadow for the entire stack (subtle, like original tiles)
    local shadow_color = hexrgb("#00000040")
    ImGui.DrawList_AddRectFilled(state.draw_list,
      base_x - glow_size, base_y - glow_size,
      base_x + total_width + glow_size, base_y + total_height + glow_size,
      shadow_color, tile_rounding + 2)

    -- Draw stacked tiles from back to front
    for i = visible_count, 1, -1 do
      local offset_x = (i - 1) * stack_offset_x
      local offset_y = (i - 1) * stack_offset_y
      local x1 = base_x + offset_x
      local y1 = base_y + offset_y
      local x2 = x1 + state.item_to_add_width
      local y2 = y1 + state.item_to_add_height

      local opacity = opacity_levels[visible_count - i + 1] or 0.3

      -- Get item data with proper color and info
      local item_data = get_item_data(state, i)
      local item_color = item_data.color

      -- Apply opacity to the entire tile color (matching original tile rendering)
      local tile_fill_color = apply_alpha(item_color, opacity)

      -- Base tile fill (matching original: just filled rectangle with rounding)
      ImGui.DrawList_AddRectFilled(state.draw_list, x1, y1, x2, y2, tile_fill_color, tile_rounding)

      -- Calculate header height
      local header_height = ImGui.GetTextLineHeightWithSpacing(ctx)
      local content_y = y1 + header_height

      -- Render visualization BEFORE header (so header overlays it, matching original tiles)
      if item_data.media_item and reaper.ValidatePtr2(0, item_data.media_item, "MediaItem*") then
        if item_data.is_midi then
          -- MIDI visualization
          local thumbnail = visualization.GetMidiThumbnail(ctx, state.cache, item_data.media_item)
          if thumbnail then
            local saved_cursor_x, saved_cursor_y = ImGui.GetCursorPos(ctx)
            ImGui.DrawList_PushClipRect(state.draw_list, x1, content_y, x2, y2)
            ImGui.SetCursorPos(ctx, x1 - cursor_x, content_y - cursor_y)

            -- Visualization uses base color with opacity
            local viz_color = apply_alpha(item_color, opacity * 0.8)
            visualization.DisplayMidiItem(ctx, thumbnail, viz_color, state.draw_list)

            ImGui.DrawList_PopClipRect(state.draw_list)
            ImGui.SetCursorPos(ctx, saved_cursor_x, saved_cursor_y)
          end
        else
          -- Audio waveform visualization
          local waveform = visualization.GetItemWaveform(state.cache, item_data.media_item)
          if waveform then
            local saved_cursor_x, saved_cursor_y = ImGui.GetCursorPos(ctx)
            ImGui.DrawList_PushClipRect(state.draw_list, x1, content_y, x2, y2)
            ImGui.SetCursorPos(ctx, x1 - cursor_x, content_y - cursor_y)

            -- Visualization uses base color with opacity
            local viz_color = apply_alpha(item_color, opacity * 0.8)
            visualization.DisplayWaveform(ctx, waveform, viz_color, state.draw_list, state.item_to_add_width)

            ImGui.DrawList_PopClipRect(state.draw_list)
            ImGui.SetCursorPos(ctx, saved_cursor_x, saved_cursor_y)
          end
        end
      end

      -- Render header bar overlay (matching original tile style with transparency)
      -- This creates a darker overlay on top of the base color, with rounded top corners
      local header_overlay = apply_alpha(hexrgb("#00000040"), opacity)
      local round_flags = ImGui.DrawFlags_RoundCornersTop
      ImGui.DrawList_AddRectFilled(state.draw_list, x1, y1, x2, y1 + header_height, header_overlay, tile_rounding, round_flags)

      -- Item name
      local name_color = apply_alpha(hexrgb("#FFFFFFFF"), opacity)
      local text_x = x1 + 8
      local text_y = y1 + (header_height - ImGui.GetTextLineHeight(ctx)) / 2
      ImGui.DrawList_AddText(state.draw_list, text_x, text_y, name_color, item_data.name)
    end

    -- Optional: subtle outer glow for multi-item stacks (very minimal, not a heavy border)
    if visible_count > 1 then
      -- Just a very subtle glow to show multiple items are stacked
      local glow_color = apply_alpha(hexrgb("#FFFFFF"), 0.08)
      ImGui.DrawList_AddRect(state.draw_list, base_x - 1, base_y - 1,
        base_x + total_width + 1, base_y + total_height + 1,
        glow_color, tile_rounding + 1, 0, 2)
    end

    -- Count badge (small, subtle, positioned at top-right)
    if dragging_count > 1 then
      local badge_text = tostring(dragging_count)
      local badge_w, badge_h = ImGui.CalcTextSize(ctx, badge_text)
      local padding = 6
      local badge_size = math.max(badge_w, badge_h) + padding * 2
      local badge_x = base_x + total_width - badge_size / 2
      local badge_y = base_y - badge_size / 2

      -- Subtle shadow
      ImGui.DrawList_AddCircleFilled(state.draw_list, badge_x + 1, badge_y + 1, badge_size / 2 + 2, hexrgb("#00000066"))

      -- Badge background (dark, semi-transparent)
      ImGui.DrawList_AddCircleFilled(state.draw_list, badge_x, badge_y, badge_size / 2, hexrgb("#1A1A1ADD"))

      -- Subtle accent ring
      ImGui.DrawList_AddCircle(state.draw_list, badge_x, badge_y, badge_size / 2, hexrgb("#FFFFFF66"), 0, 1.5)

      -- Badge text
      local text_x = badge_x - badge_w / 2
      local text_y = badge_y - badge_h / 2
      ImGui.DrawList_AddText(state.draw_list, text_x, text_y, hexrgb("#FFFFFFEE"), badge_text)
    end

    -- Dummy to reserve space
    ImGui.Dummy(ctx, total_width, total_height)

    ImGui.PopFont(ctx)
    ImGui.End(ctx)
  end
end

return M
