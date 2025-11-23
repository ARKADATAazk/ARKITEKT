-- @noindex
-- MediaContainer/ui/overlay.lua
-- Draw container bounds on arrange view with drag support

local ImGui = require 'imgui' '0.10'
local Colors = require('arkitekt.core.colors')

local M = {}

-- Drag state
M.dragging_container_id = nil
M.drag_start_time = nil
M.drag_start_mouse_x = nil
M.was_mouse_down = false  -- Track previous mouse state to detect click start

-- Convert timeline position to screen X coordinate
local function timeline_to_screen_x(time_pos, arrange_start_time, zoom_level, window_x)
  return window_x + (time_pos - arrange_start_time) * zoom_level
end

-- Convert screen X to timeline position
local function screen_x_to_timeline(screen_x, arrange_start_time, zoom_level, window_x)
  return arrange_start_time + (screen_x - window_x) / zoom_level
end

-- Get track screen Y position and height
local function get_track_screen_pos(track, window_y)
  if not track then return nil, nil end

  local track_y = reaper.GetMediaTrackInfo_Value(track, "I_TCPY")
  local track_h = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")

  return window_y + track_y, track_h
end

-- Check if point is inside rectangle
local function point_in_rect(px, py, x1, y1, x2, y2)
  return px >= x1 and px <= x2 and py >= y1 and py <= y2
end

-- Move all items in a container by time delta (container drag - does NOT sync to linked)
local function move_container_items(container, time_delta, State)
  if time_delta == 0 then return end

  reaper.PreventUIRefresh(1)

  -- Move items in this container ONLY
  for _, item_ref in ipairs(container.items) do
    local item = State.find_item_by_guid(item_ref.guid)
    if item then
      local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      reaper.SetMediaItemInfo_Value(item, "D_POSITION", pos + time_delta)
    end
  end

  -- Update container bounds
  container.start_time = container.start_time + time_delta
  container.end_time = container.end_time + time_delta

  -- Update cache for this container's items only (using relative position)
  -- Since we updated container.start_time above, relative positions stay the same
  for _, item_ref in ipairs(container.items) do
    local item = State.find_item_by_guid(item_ref.guid)
    if item then
      local hash = State.get_item_state_hash(item, container)
      if hash then
        State.item_state_cache[item_ref.guid] = hash
      end
    end
  end

  State.persist()

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
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

  -- Get mouse state
  local mouse_x, mouse_y = reaper.GetMousePosition()
  local mouse_state = reaper.JS_Mouse_GetState(1)  -- 1 = left button
  local left_down = mouse_state == 1

  -- Handle dragging
  if M.dragging_container_id then
    if left_down then
      -- Continue drag - calculate delta and move
      local current_time = screen_x_to_timeline(mouse_x, arrange_start_time, zoom_level, w_x1)
      local time_delta = current_time - M.drag_start_time

      if math.abs(time_delta) > 0.001 then  -- Minimum threshold
        local container = State.get_container_by_id(M.dragging_container_id)
        if container then
          move_container_items(container, time_delta, State)
          M.drag_start_time = current_time
        end
      end
    else
      -- End drag
      reaper.Undo_EndBlock("Move Media Container", -1)
      M.dragging_container_id = nil
      M.drag_start_time = nil
      M.drag_start_mouse_x = nil
    end
  end

  -- Position window over arrange
  ImGui.SetNextWindowPos(ctx, w_x1, w_y1)
  ImGui.SetNextWindowSize(ctx, w_width, w_height - 17)  -- -17 for scrollbar
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowBorderSize, 0)

  local visible = ImGui.Begin(ctx, "MediaContainer_Overlay", false,
    ImGui.WindowFlags_NoCollapse |
    ImGui.WindowFlags_NoInputs |
    ImGui.WindowFlags_NoTitleBar |
    ImGui.WindowFlags_NoFocusOnAppearing |
    ImGui.WindowFlags_NoBackground)

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

  -- Track which container mouse is over (for click detection)
  local hovered_container = nil

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

    -- Check if mouse is over this container's label area (top bar for dragging)
    local label_height = 20
    if point_in_rect(mouse_x, mouse_y, x1, y1, x2, y1 + label_height) then
      hovered_container = container
    end

    -- Determine colors based on master/linked status
    local base_color = container.color or 0xFF6600FF
    local is_linked = container.master_id ~= nil
    local is_dragging = M.dragging_container_id == container.id

    -- Fill color (semi-transparent)
    local fill_alpha = is_linked and 0.15 or 0.20
    if is_dragging then fill_alpha = fill_alpha + 0.1 end
    local r, g, b, a = Colors.rgba_to_components(base_color)
    local fill_color = ImGui.ColorConvertDouble4ToU32(r/255, g/255, b/255, fill_alpha)

    -- Border color
    local border_alpha = is_linked and 0.6 or 0.8
    if is_dragging then border_alpha = 1.0 end
    local border_color = ImGui.ColorConvertDouble4ToU32(r/255, g/255, b/255, border_alpha)

    -- Dashed pattern for linked containers
    local border_thickness = is_linked and 1 or 2
    if is_dragging then border_thickness = 3 end

    -- Draw filled rectangle
    ImGui.DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, fill_color)

    -- Draw border
    if is_linked and not is_dragging then
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

    -- Draw container name label (this is the drag handle)
    local label = container.name
    if is_linked then
      label = label .. " [linked]"
    end

    local text_color = ImGui.ColorConvertDouble4ToU32(1, 1, 1, 0.9)
    local label_bg = ImGui.ColorConvertDouble4ToU32(0, 0, 0, 0.6)
    if hovered_container == container and not M.dragging_container_id then
      label_bg = ImGui.ColorConvertDouble4ToU32(0.2, 0.2, 0.2, 0.8)  -- Highlight on hover
    end

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

  -- Handle click to start drag (only on mouse DOWN transition, not while held)
  local mouse_in_arrange = mouse_x >= w_x1 and mouse_x <= w_x2 and mouse_y >= w_y1 and mouse_y <= w_y2
  local click_started = left_down and not M.was_mouse_down  -- Detect transition from up to down

  if hovered_container and click_started and not M.dragging_container_id and mouse_in_arrange then
    reaper.Undo_BeginBlock()

    M.dragging_container_id = hovered_container.id
    M.drag_start_time = screen_x_to_timeline(mouse_x, arrange_start_time, zoom_level, w_x1)
    M.drag_start_mouse_x = mouse_x

    reaper.ShowConsoleMsg(string.format("[MediaContainer] Started dragging '%s' with %d items\n",
      hovered_container.name, #hovered_container.items))

    -- Select all items in container
    reaper.SelectAllMediaItems(0, false)
    local selected_count = 0
    for _, item_ref in ipairs(hovered_container.items) do
      local item = State.find_item_by_guid(item_ref.guid)
      if item then
        reaper.SetMediaItemSelected(item, true)
        selected_count = selected_count + 1
      else
        reaper.ShowConsoleMsg(string.format("[MediaContainer] WARNING: Could not find item with GUID %s\n", item_ref.guid))
      end
    end
    reaper.ShowConsoleMsg(string.format("[MediaContainer] Selected %d items\n", selected_count))
  end

  -- Update mouse state for next frame
  M.was_mouse_down = left_down

  ImGui.PopStyleVar(ctx, 1)
  ImGui.End(ctx)
end

return M
