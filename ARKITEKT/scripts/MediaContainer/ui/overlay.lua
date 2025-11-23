-- @noindex
-- MediaContainer/ui/overlay.lua
-- Draw container bounds on arrange view

local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')

local M = {}

-- Convert timeline position to screen X coordinate
local function timeline_to_screen_x(time_pos, arrange_start_time, zoom_level, window_x)
  return window_x + (time_pos - arrange_start_time) * zoom_level
end

-- Get track screen Y position and height
local function get_track_screen_pos(track, window_y)
  if not track then return nil, nil end

  local track_y = reaper.GetMediaTrackInfo_Value(track, "I_TCPY")
  local track_h = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")

  return window_y + track_y, track_h
end

-- Draw container bounds on arrange view
function M.draw_containers(ctx, draw_list, State)
  local arrange_window = reaper.JS_Window_Find("trackview", true)
  if not arrange_window then return end

  local rv, w_x1, w_y1, w_x2, w_y2 = reaper.JS_Window_GetRect(arrange_window)
  if not rv then return end

  local w_width = w_x2 - w_x1
  local w_height = w_y2 - w_y1

  -- Get arrange view info
  local zoom_level = reaper.GetHZoomLevel()
  local arrange_start_time, arrange_end_time = reaper.GetSet_ArrangeView2(0, false, 0, 0)

  -- Position window over arrange
  ImGui.SetNextWindowPos(ctx, w_x1, w_y1)
  ImGui.SetNextWindowSize(ctx, w_width, w_height - 17)  -- -17 for scrollbar
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowBorderSize, 0)

  local visible = ImGui.Begin(ctx, "MediaContainer_Overlay", false,
    ImGui.WindowFlags_NoCollapse |
    ImGui.WindowFlags_NoInputs |
    ImGui.WindowFlags_NoTitleBar |
    ImGui.WindowFlags_NoFocusOnAppearing |
    ImGui.WindowFlags_NoBackground |
    ImGui.WindowFlags_NoBringToFrontOnFocus)

  if not visible then
    ImGui.PopStyleVar(ctx, 1)
    ImGui.End(ctx)
    return
  end

  local containers = State.get_all_containers()
  if #containers == 0 then
    ImGui.PopStyleVar(ctx, 1)
    ImGui.End(ctx)
    return
  end

  -- Draw each container
  for _, container in ipairs(containers) do
    -- Skip if outside visible range
    if container.end_time < arrange_start_time or container.start_time > arrange_end_time then
      goto next_container
    end

    -- Calculate screen coordinates
    local x1 = timeline_to_screen_x(container.start_time, arrange_start_time, zoom_level, w_x1)
    local x2 = timeline_to_screen_x(container.end_time, arrange_start_time, zoom_level, w_x1)

    -- Clamp to window bounds
    x1 = math.max(w_x1, math.min(w_x2, x1))
    x2 = math.max(w_x1, math.min(w_x2, x2))

    -- Get track Y bounds
    local top_track = State.find_track_by_guid(container.top_track_guid)
    local bottom_track = State.find_track_by_guid(container.bottom_track_guid)

    local y1, top_h = get_track_screen_pos(top_track, w_y1)
    local y2, bottom_h = get_track_screen_pos(bottom_track, w_y1)

    if not y1 or not y2 then
      goto next_container
    end

    y2 = y2 + bottom_h  -- Bottom of bottom track

    -- Determine colors based on master/linked status
    local base_color = container.color or 0xFF6600FF
    local is_linked = container.master_id ~= nil

    -- Fill color (semi-transparent)
    local fill_alpha = is_linked and 0.15 or 0.20
    local r, g, b, a = Colors.rgba_to_components(base_color)
    local fill_color = ImGui.ColorConvertDouble4ToU32(r/255, g/255, b/255, fill_alpha)

    -- Border color
    local border_alpha = is_linked and 0.6 or 0.8
    local border_color = ImGui.ColorConvertDouble4ToU32(r/255, g/255, b/255, border_alpha)

    -- Dashed pattern for linked containers
    local border_thickness = is_linked and 1 or 2

    -- Draw filled rectangle
    ImGui.DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, fill_color)

    -- Draw border
    if is_linked then
      -- Dashed border for linked containers
      local dash_len = 6
      local gap_len = 4

      -- Top edge
      local cx = x1
      while cx < x2 do
        local seg_end = math.min(cx + dash_len, x2)
        ImGui.DrawList_AddLine(draw_list, cx, y1, seg_end, y1, border_color, border_thickness)
        cx = seg_end + gap_len
      end

      -- Bottom edge
      cx = x1
      while cx < x2 do
        local seg_end = math.min(cx + dash_len, x2)
        ImGui.DrawList_AddLine(draw_list, cx, y2, seg_end, y2, border_color, border_thickness)
        cx = seg_end + gap_len
      end

      -- Left edge
      local cy = y1
      while cy < y2 do
        local seg_end = math.min(cy + dash_len, y2)
        ImGui.DrawList_AddLine(draw_list, x1, cy, x1, seg_end, border_color, border_thickness)
        cy = seg_end + gap_len
      end

      -- Right edge
      cy = y1
      while cy < y2 do
        local seg_end = math.min(cy + dash_len, y2)
        ImGui.DrawList_AddLine(draw_list, x2, cy, x2, seg_end, border_color, border_thickness)
        cy = seg_end + gap_len
      end
    else
      -- Solid border for master containers
      ImGui.DrawList_AddRect(draw_list, x1, y1, x2, y2, border_color, 0, 0, border_thickness)
    end

    -- Draw container name label
    local label = container.name
    if is_linked then
      label = label .. " [linked]"
    end

    local text_color = ImGui.ColorConvertDouble4ToU32(1, 1, 1, 0.9)
    local label_bg = ImGui.ColorConvertDouble4ToU32(0, 0, 0, 0.6)

    local text_w, text_h = ImGui.CalcTextSize(ctx, label)
    local padding = 4
    local label_x = x1 + 4
    local label_y = y1 + 4

    -- Label background
    ImGui.DrawList_AddRectFilled(draw_list,
      label_x - padding, label_y - padding,
      label_x + text_w + padding, label_y + text_h + padding,
      label_bg, 2)

    -- Label text
    ImGui.DrawList_AddText(draw_list, label_x, label_y, text_color, label)

    ::next_container::
  end

  ImGui.PopStyleVar(ctx, 1)
  ImGui.End(ctx)
end

return M
