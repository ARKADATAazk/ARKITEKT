-- @noindex
local ImGui = require 'imgui' '0.10'

local M = {}
local visualization

function M.init(visualization_module)
  visualization = visualization_module
end

function M.DragDropLogic(ctx, state, mini_font)
  local mouse_key = reaper.JS_Mouse_GetState(-1)
  local left_mouse_key = mouse_key & 1 == 1
  if not left_mouse_key then
    return true
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

  if state.dragging then
    local mouse_x, mouse_y = reaper.GetMousePosition()
    local m_window, m_segment, m_details = reaper.BR_GetMouseCursorContext()
    local track, str = reaper.GetThingFromPoint(mouse_x, mouse_y)
    local last_track
    for i = reaper.CountTracks(0) - 1, 0, -1 do
      local track = reaper.GetTrack(0, i)
      if reaper.IsTrackVisible(track, false) then
        last_track = track
        break
      end
    end
    local track_height
    local track_y

    if reaper.GetToggleCommandState(1157) then
      local mouse_position_in_arrange = reaper.BR_GetMouseCursorContext_Position()
      local snapped_position = reaper.SnapToGrid(0, mouse_position_in_arrange)
      local snap_factor = snapped_position - mouse_position_in_arrange
      snap_factor = snap_factor * arrange_zoom_level
      mouse_x = mouse_x + snap_factor
    end

    local rect_x1
    local rect_y1
    local rect_x2
    local rect_y2

    local item_length = reaper.GetMediaSourceLength(reaper.GetMediaItemTake_Source(reaper.GetActiveTake(state.item_to_add)))
    if track and (str == "arrange" or str:find('envelope')) then
      track_height = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")
      track_y = reaper.GetMediaTrackInfo_Value(track, "I_TCPY")

      rect_x1 = mouse_x
      rect_y1 = w_y1 + track_y
      rect_x2 = mouse_x + item_length * arrange_zoom_level
      rect_y2 = rect_y1 + track_height

      state.out_of_bounds = nil
    elseif m_window == "arrange" and m_segment == "empty" then
      track_height = reaper.GetMediaTrackInfo_Value(last_track, "I_WNDH")
      track_y = reaper.GetMediaTrackInfo_Value(last_track, "I_TCPY")

      rect_x1 = mouse_x
      rect_y1 = w_y1 + track_y + track_height
      rect_x2 = mouse_x + item_length * arrange_zoom_level
      rect_y2 = w_y1 + track_y + track_height + 17

      state.out_of_bounds = true
    else
      state.out_of_bounds = nil
    end

    if rect_x1 then
      ImGui.DrawList_AddRectFilled(state.draw_list, rect_x1, rect_y1, rect_x2, rect_y2,
        ImGui.ColorConvertDouble4ToU32(177 / 256, 180 / 256, 180 / 256, 1))

      local line_color = ImGui.ColorConvertDouble4ToU32(16 / 256, 133 / 256, 130 / 256, 1)

      ImGui.DrawList_AddLine(state.draw_list, rect_x1, w_y1, rect_x1, w_y2, line_color)
      ImGui.DrawList_AddLine(state.draw_list, rect_x2, w_y1, rect_x2, w_y2, line_color)

      ImGui.DrawList_AddLine(state.draw_list, w_x1, rect_y1, w_x2, rect_y1, line_color)
      ImGui.DrawList_AddLine(state.draw_list, w_x1, rect_y2, w_x2, rect_y2, line_color)
    end
  end

  ImGui.PopStyleVar(ctx, 1)
  ImGui.End(ctx)
  
  return false
end

function M.DraggingThumbnailWindow(ctx, state, mini_font)
  if not state.item_to_add_width or not state.item_to_add_height then
    return
  end
  
  local mouse_x, mouse_y = reaper.GetMousePosition()
  ImGui.SetNextWindowPos(ctx, mouse_x, mouse_y)

  if ImGui.Begin(ctx, "MouseFollower", false, ImGui.WindowFlags_NoInputs | ImGui.WindowFlags_TopMost | ImGui.WindowFlags_NoTitleBar | ImGui.WindowFlags_NoBackground | ImGui.WindowFlags_AlwaysAutoResize) then
    ImGui.PushFont(ctx, mini_font, 13)
    local cursor_x, cursor_y = ImGui.GetItemRectMin(ctx)
    local x1, y1 = cursor_x + ImGui.StyleVar_ChildBorderSize, cursor_y + ImGui.StyleVar_ChildBorderSize
    ImGui.DrawList_AddRectFilled(state.draw_list, x1 - 8, y1 - 8, x1 + state.item_to_add_width + 8,
      y1 + state.item_to_add_height + 8, 0x00000050)

    ImGui.DrawList_AddRectFilled(state.draw_list, x1, y1, x1 + state.item_to_add_width,
      y1 + ImGui.GetTextLineHeightWithSpacing(ctx), state.item_to_add_color)
    ImGui.DrawList_AddRectFilled(state.draw_list, x1, y1, x1 + state.item_to_add_width,
      y1 + ImGui.GetTextLineHeightWithSpacing(ctx), ImGui.ColorConvertDouble4ToU32(0, 0, 0, 0.3))
    ImGui.Text(ctx, " " .. state.item_to_add_name)
    ImGui.Dummy(ctx, state.item_to_add_width, state.item_to_add_height - ImGui.GetTextLineHeightWithSpacing(ctx))
    if reaper.TakeIsMIDI(reaper.GetActiveTake(state.item_to_add)) then
local thumbnail = visualization.GetMidiThumbnail(ctx, state.cache, state.item_to_add)
if thumbnail then
  visualization.DisplayMidiItem(ctx, thumbnail, state.item_to_add_color, state.draw_list)
end
    else
      if not state.drag_waveform then
        state.drag_waveform = visualization.GetItemWaveform(state.cache, state.item_to_add)
      end
      if state.drag_waveform then
        visualization.DisplayWaveform(ctx, state.drag_waveform, state.item_to_add_color, state.draw_list, state.item_to_add_width)
      end
    end
    ImGui.PopFont(ctx)
    ImGui.End(ctx)
  end
end

return M