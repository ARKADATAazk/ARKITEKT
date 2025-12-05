-- @noindex
-- MediaContainer/ui/overlay.lua
-- Draw container bounds on arrange view with drag support
--
-- RESPONSIBILITY:
-- Draws container boundaries on the REAPER arrange view using JS_ReaScriptAPI.
-- Handles container dragging for repositioning.

local ImGui = require('arkitekt.core.imgui')
local Colors = require('arkitekt.core.colors')
local Constants = require('MediaContainer.config.constants')
local Logger = require('arkitekt.debug.logger')

-- =============================================================================
-- PERF: Localize frequently-used functions (30% faster per call)
-- =============================================================================

-- Math
local abs = math.abs
local max = math.max
local min = math.min

-- ImGui draw functions (called many times per frame)
local SetNextWindowPos = ImGui.SetNextWindowPos
local SetNextWindowSize = ImGui.SetNextWindowSize
local PushStyleVar = ImGui.PushStyleVar
local PopStyleVar = ImGui.PopStyleVar
local Begin = ImGui.Begin
local End = ImGui.End
local CalcTextSize = ImGui.CalcTextSize
local DrawList_AddRectFilled = ImGui.DrawList_AddRectFilled
local DrawList_AddRect = ImGui.DrawList_AddRect
local DrawList_AddLine = ImGui.DrawList_AddLine
local DrawList_AddText = ImGui.DrawList_AddText

-- REAPER functions (called per frame)
local JS_Window_Find = reaper.JS_Window_Find
local JS_Window_GetRect = reaper.JS_Window_GetRect
local JS_Mouse_GetState = reaper.JS_Mouse_GetState
local GetHZoomLevel = reaper.GetHZoomLevel
local GetSet_ArrangeView2 = reaper.GetSet_ArrangeView2
local GetMousePosition = reaper.GetMousePosition
local GetMediaTrackInfo_Value = reaper.GetMediaTrackInfo_Value
local GetMediaItemInfo_Value = reaper.GetMediaItemInfo_Value
local SetMediaItemInfo_Value = reaper.SetMediaItemInfo_Value
local SetMediaItemSelected = reaper.SetMediaItemSelected
local SelectAllMediaItems = reaper.SelectAllMediaItems
local PreventUIRefresh = reaper.PreventUIRefresh
local UpdateArrange = reaper.UpdateArrange
local Undo_BeginBlock = reaper.Undo_BeginBlock
local Undo_EndBlock = reaper.Undo_EndBlock

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

  local track_y = GetMediaTrackInfo_Value(track, 'I_TCPY')
  local track_h = GetMediaTrackInfo_Value(track, 'I_TCPH')

  return window_y + track_y, track_h
end

-- Check if point is inside rectangle
local function point_in_rect(px, py, x1, y1, x2, y2)
  return px >= x1 and px <= x2 and py >= y1 and py <= y2
end

-- Move all items in a container by time delta (container drag - does NOT sync to linked)
local function move_container_items(container, time_delta, State)
  if time_delta == 0 then return end

  PreventUIRefresh(1)

  -- Move items in this container ONLY
  -- PERF: Use numeric for loop instead of ipairs (20-30% faster)
  local items = container.items
  local n = #items
  for i = 1, n do
    local item_ref = items[i]
    local item = State.find_item_by_guid(item_ref.guid)
    if item then
      local pos = GetMediaItemInfo_Value(item, 'D_POSITION')
      SetMediaItemInfo_Value(item, 'D_POSITION', pos + time_delta)
    end
  end

  -- Update container bounds
  container.start_time = container.start_time + time_delta
  container.end_time = container.end_time + time_delta

  -- Update cache for this container's items only (using relative position)
  -- Since we updated container.start_time above, relative positions stay the same
  -- PERF: Reuse cached items array and count
  for i = 1, n do
    local item_ref = items[i]
    local item = State.find_item_by_guid(item_ref.guid)
    if item then
      local hash = State.get_item_state_hash(item, container)
      if hash then
        State.item_state_cache[item_ref.guid] = hash
      end
    end
  end

  State.persist()

  PreventUIRefresh(-1)
  UpdateArrange()
end

-- Draw container bounds on arrange view
function M.draw_containers(ctx, draw_list, State)
  local arrange_window = JS_Window_Find('trackview', true)
  if not arrange_window then return end

  local rv, w_x1, w_y1, w_x2, w_y2 = JS_Window_GetRect(arrange_window)
  if not rv then return end

  local w_width = w_x2 - w_x1
  local w_height = w_y2 - w_y1

  -- Get arrange view info
  local zoom_level = GetHZoomLevel()
  local arrange_start_time, arrange_end_time = GetSet_ArrangeView2(0, false, 0, 0)

  -- Get mouse state
  local mouse_x, mouse_y = GetMousePosition()
  local mouse_state = JS_Mouse_GetState(1)  -- 1 = left button
  local left_down = mouse_state == 1

  -- Handle dragging
  if M.dragging_container_id then
    if left_down then
      -- Continue drag - calculate delta and move
      local current_time = screen_x_to_timeline(mouse_x, arrange_start_time, zoom_level, w_x1)
      local time_delta = current_time - M.drag_start_time

      if abs(time_delta) > 0.001 then  -- Minimum threshold
        local container = State.get_container_by_id(M.dragging_container_id)
        if container then
          move_container_items(container, time_delta, State)
          M.drag_start_time = current_time
        end
      end
    else
      -- End drag
      Undo_EndBlock('Move Media Container', -1)
      M.dragging_container_id = nil
      M.drag_start_time = nil
      M.drag_start_mouse_x = nil
    end
  end

  -- Position window over arrange
  SetNextWindowPos(ctx, w_x1, w_y1)
  SetNextWindowSize(ctx, w_width, w_height - 17)  -- -17 for scrollbar
  PushStyleVar(ctx, ImGui.StyleVar_WindowBorderSize, 0)

  local visible = Begin(ctx, 'MediaContainer_Overlay', false,
    ImGui.WindowFlags_NoCollapse |
    ImGui.WindowFlags_NoInputs |
    ImGui.WindowFlags_NoTitleBar |
    ImGui.WindowFlags_NoFocusOnAppearing |
    ImGui.WindowFlags_NoBackground)

  if not visible then
    PopStyleVar(ctx, 1)
    End(ctx)
    return
  end

  local containers = State.get_all_containers()
  local num_containers = #containers
  if num_containers == 0 then
    PopStyleVar(ctx, 1)
    End(ctx)
    return
  end

  -- Track which container mouse is over (for click detection)
  local hovered_container = nil

  -- Draw each container
  -- PERF: Use numeric for loop instead of ipairs (20-30% faster)
  for idx = 1, num_containers do
    local container = containers[idx]

    -- Skip if outside visible range
    if container.end_time < arrange_start_time or container.start_time > arrange_end_time then
      goto next_container
    end

    -- Calculate screen coordinates
    local x1 = timeline_to_screen_x(container.start_time, arrange_start_time, zoom_level, w_x1)
    local x2 = timeline_to_screen_x(container.end_time, arrange_start_time, zoom_level, w_x1)

    -- Clamp to window bounds
    x1 = max(w_x1, min(w_x2, x1))
    x2 = max(w_x1, min(w_x2, x2))

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
    local fill_color = Colors.WithOpacity(base_color, fill_alpha)

    -- Border color
    local border_alpha = is_linked and 0.6 or 0.8
    if is_dragging then border_alpha = 1.0 end
    local border_color = Colors.WithOpacity(base_color, border_alpha)

    -- Dashed pattern for linked containers
    local border_thickness = is_linked and 1 or 2
    if is_dragging then border_thickness = 3 end

    -- Draw filled rectangle
    DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, fill_color)

    -- Draw border
    if is_linked and not is_dragging then
      -- Dashed border for linked containers
      local dash_len = 6
      local gap_len = 4

      -- Top edge
      local cx = x1
      while cx < x2 do
        local seg_end = min(cx + dash_len, x2)
        DrawList_AddLine(draw_list, cx, y1, seg_end, y1, border_color, border_thickness)
        cx = seg_end + gap_len
      end

      -- Bottom edge
      cx = x1
      while cx < x2 do
        local seg_end = min(cx + dash_len, x2)
        DrawList_AddLine(draw_list, cx, y2, seg_end, y2, border_color, border_thickness)
        cx = seg_end + gap_len
      end

      -- Left edge
      local cy = y1
      while cy < y2 do
        local seg_end = min(cy + dash_len, y2)
        DrawList_AddLine(draw_list, x1, cy, x1, seg_end, border_color, border_thickness)
        cy = seg_end + gap_len
      end

      -- Right edge
      cy = y1
      while cy < y2 do
        local seg_end = min(cy + dash_len, y2)
        DrawList_AddLine(draw_list, x2, cy, x2, seg_end, border_color, border_thickness)
        cy = seg_end + gap_len
      end
    else
      -- Solid border for master containers
      DrawList_AddRect(draw_list, x1, y1, x2, y2, border_color, 0, 0, border_thickness)
    end

    -- Draw container name label (this is the drag handle)
    local label = container.name
    if is_linked then
      label = label .. ' [linked]'
    end

    local text_color = Colors.WithOpacity(0xFFFFFFFF, 0.9)
    local label_bg = Colors.WithOpacity(0x000000FF, 0.6)
    if hovered_container == container and not M.dragging_container_id then
      label_bg = Colors.WithOpacity(0x333333FF, 0.8)  -- Highlight on hover
    end

    local text_w, text_h = CalcTextSize(ctx, label)
    local padding = 4
    local label_x = x1 + 4
    local label_y = y1 + 4

    -- Label background
    DrawList_AddRectFilled(draw_list,
      label_x - padding, label_y - padding,
      label_x + text_w + padding, label_y + text_h + padding,
      label_bg, 2)

    -- Label text
    DrawList_AddText(draw_list, label_x, label_y, text_color, label)

    ::next_container::
  end

  -- Handle click to start drag (only on mouse DOWN transition, not while held)
  local mouse_in_arrange = mouse_x >= w_x1 and mouse_x <= w_x2 and mouse_y >= w_y1 and mouse_y <= w_y2
  local click_started = left_down and not M.was_mouse_down  -- Detect transition from up to down

  if hovered_container and click_started and not M.dragging_container_id and mouse_in_arrange then
    Undo_BeginBlock()

    M.dragging_container_id = hovered_container.id
    M.drag_start_time = screen_x_to_timeline(mouse_x, arrange_start_time, zoom_level, w_x1)
    M.drag_start_mouse_x = mouse_x

    Logger.debug('OVERLAY', "Started dragging '%s' with %d items", hovered_container.name, #hovered_container.items)

    -- Select all items in container
    SelectAllMediaItems(0, false)
    local selected_count = 0
    -- PERF: Use numeric for loop
    local items = hovered_container.items
    local n = #items
    for i = 1, n do
      local item_ref = items[i]
      local item = State.find_item_by_guid(item_ref.guid)
      if item then
        SetMediaItemSelected(item, true)
        selected_count = selected_count + 1
      else
        Logger.warn('OVERLAY', 'Could not find item with GUID %s', item_ref.guid)
      end
    end
    Logger.debug('OVERLAY', 'Selected %d items', selected_count)
  end

  -- Update mouse state for next frame
  M.was_mouse_down = left_down

  PopStyleVar(ctx, 1)
  End(ctx)
end

return M
