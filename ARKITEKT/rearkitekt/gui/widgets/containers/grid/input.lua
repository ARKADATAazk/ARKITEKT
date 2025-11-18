-- @noindex
-- ReArkitekt/gui/widgets/grid/input.lua
-- Input handling for grid widgets - unified shortcut system
-- FIXED: Tiles outside grid bounds are no longer interactive

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local Draw = require('rearkitekt.gui.draw')

local M = {}

M.SHORTCUT_REGISTRY = {
  { key = ImGui.Key_Delete, name = 'delete' },
  { key = ImGui.Key_Space, name = 'play' },
  { key = ImGui.Key_F2, name = 'rename' },
  { key = ImGui.Key_F, name = 'favorite' },
  { key = ImGui.Key_A, ctrl = true, name = 'select_all' },
  { key = ImGui.Key_D, ctrl = true, name = 'deselect_all' },
  { key = ImGui.Key_I, ctrl = true, name = 'invert_selection' },
}

function M.is_external_drag_active(grid)
  if not grid.external_drag_check then return false end
  return grid.external_drag_check() == true
end

function M.is_rect_in_grid_bounds(grid, rect)
  if not grid.visual_bounds then return true end
  local vb = grid.visual_bounds
  return not (rect[3] < vb[1] or rect[1] > vb[3] or rect[4] < vb[2] or rect[2] > vb[4])
end

function M.is_mouse_in_exclusion(grid, ctx, item, rect)
  if not grid.get_exclusion_zones then return false end

  local zones = grid.get_exclusion_zones(item, rect)
  if not zones or #zones == 0 then return false end

  local mx, my = ImGui.GetMousePos(ctx)
  for _, z in ipairs(zones) do
    if Draw.point_in_rect(mx, my, z[1], z[2], z[3], z[4]) then
      return true
    end
  end
  return false
end

function M.find_hovered_item(grid, ctx, items)
  local mx, my = ImGui.GetMousePos(ctx)
  if grid.visual_bounds then
    if not Draw.point_in_rect(mx, my, grid.visual_bounds[1], grid.visual_bounds[2], grid.visual_bounds[3], grid.visual_bounds[4]) then
      return nil, nil, false
    end
  end
  for _, item in ipairs(items) do
    local key = grid.key(item)
    local rect = grid.rect_track:get(key)
    if rect and M.is_rect_in_grid_bounds(grid, rect) and Draw.point_in_rect(mx, my, rect[1], rect[2], rect[3], rect[4]) then
      if not M.is_mouse_in_exclusion(grid, ctx, item, rect) then
        return item, key, grid.selection:is_selected(key)
      end
    end
  end
  return nil, nil, false
end

function M.is_shortcut_pressed(ctx, shortcut, state)
  if not ImGui.IsKeyPressed(ctx, shortcut.key) then return false end
  
  local ctrl_required = shortcut.ctrl or false
  local shift_required = shortcut.shift or false
  local alt_required = shortcut.alt or false
  
  local ctrl_down = ImGui.IsKeyDown(ctx, ImGui.Key_LeftCtrl) or ImGui.IsKeyDown(ctx, ImGui.Key_RightCtrl)
  local shift_down = ImGui.IsKeyDown(ctx, ImGui.Key_LeftShift) or ImGui.IsKeyDown(ctx, ImGui.Key_RightShift)
  local alt_down = ImGui.IsKeyDown(ctx, ImGui.Key_LeftAlt) or ImGui.IsKeyDown(ctx, ImGui.Key_RightAlt)
  
  if ctrl_required and not ctrl_down then return false end
  if not ctrl_required and ctrl_down then return false end
  
  if shift_required and not shift_down then return false end
  if not shift_required and shift_down then return false end
  
  if alt_required and not alt_down then return false end
  if not alt_required and alt_down then return false end
  
  local state_key = shortcut.name .. '_pressed_last_frame'
  if state[state_key] then return false end
  
  state[state_key] = true
  return true
end

function M.reset_shortcut_states(ctx, state)
  for _, shortcut in ipairs(M.SHORTCUT_REGISTRY) do
    local is_down = ImGui.IsKeyDown(ctx, shortcut.key)
    local state_key = shortcut.name .. '_pressed_last_frame'
    if not is_down then
      state[state_key] = false
    end
  end
end

function M.handle_shortcuts(grid, ctx)
  if not grid.behaviors then return false end

  -- Block shortcuts when mouse is over a DIFFERENT window (e.g., popup on top of this grid)
  local is_current_window_hovered = ImGui.IsWindowHovered(ctx)
  local is_any_window_hovered = ImGui.IsWindowHovered(ctx, ImGui.HoveredFlags_AnyWindow)
  if is_any_window_hovered and not is_current_window_hovered then
    return false
  end

  grid.shortcut_state = grid.shortcut_state or {}

  for _, shortcut in ipairs(M.SHORTCUT_REGISTRY) do
    if M.is_shortcut_pressed(ctx, shortcut, grid.shortcut_state) then
      local behavior = grid.behaviors[shortcut.name]
      if behavior then
        local selected_keys = grid.selection:selected_keys()
        behavior(selected_keys)
        return true
      end
    end
  end

  M.reset_shortcut_states(ctx, grid.shortcut_state)
  return false
end

function M.handle_wheel_input(grid, ctx, items)
  if not grid.behaviors or not grid.behaviors.wheel_adjust then return false end

  -- Block wheel input when mouse is over a DIFFERENT window (e.g., popup on top of this grid)
  local is_current_window_hovered = ImGui.IsWindowHovered(ctx)
  local is_any_window_hovered = ImGui.IsWindowHovered(ctx, ImGui.HoveredFlags_AnyWindow)
  if is_any_window_hovered and not is_current_window_hovered then
    return false
  end

  local wheel_y = ImGui.GetMouseWheel(ctx)
  if wheel_y == 0 then return false end

  -- Check modifiers
  local ctrl = ImGui.IsKeyDown(ctx, ImGui.Key_LeftCtrl) or ImGui.IsKeyDown(ctx, ImGui.Key_RightCtrl)
  local alt = ImGui.IsKeyDown(ctx, ImGui.Key_LeftAlt) or ImGui.IsKeyDown(ctx, ImGui.Key_RightAlt)
  local shift = ImGui.IsKeyDown(ctx, ImGui.Key_LeftShift) or ImGui.IsKeyDown(ctx, ImGui.Key_RightShift)

  -- SHIFT+Scroll: Cycle through item group (1/3, 2/3, 3/3)
  -- Uses hovered item instead of selection
  if shift and not ctrl and not alt then
    -- Use hovered item if available
    local target_key = grid.hover_id

    if target_key and grid.behaviors and grid.behaviors.wheel_adjust then
      local wheel_step = (grid.config and grid.config.wheel and grid.config.wheel.step) or 1
      local delta = (wheel_y > 0) and wheel_step or -wheel_step

      -- Call wheel_adjust which will cycle and return the new UUID
      local new_uuid = grid.behaviors.wheel_adjust({target_key}, delta)

      -- Update selection to the new item if cycling succeeded
      if new_uuid and new_uuid ~= target_key then
        grid.selection:single(new_uuid)
        if grid.behaviors and grid.behaviors.on_select then
          grid.behaviors.on_select(grid.selection:selected_keys())
        end
      end

      return true  -- Consume wheel to prevent scrolling
    end
    return false
  end

  -- CTRL or ALT: Tile resize operation (works anywhere in grid)
  if ctrl or alt then
    local wheel_step = (grid.config and grid.config.wheel and grid.config.wheel.step) or 1
    local delta = (wheel_y > 0) and wheel_step or -wheel_step

    -- Global resize: pass empty keys array to signal "adjust all tiles"
    grid.behaviors.wheel_adjust({}, delta)
    return true  -- Consume wheel to prevent scrolling
  end

  return false
end

function M.handle_tile_input(grid, ctx, item, rect)
  -- Block tile input when mouse is over a DIFFERENT window (e.g., popup on top of this grid)
  local is_current_window_hovered = ImGui.IsWindowHovered(ctx)
  local is_any_window_hovered = ImGui.IsWindowHovered(ctx, ImGui.HoveredFlags_AnyWindow)
  if is_any_window_hovered and not is_current_window_hovered then
    return false
  end

  if not M.is_rect_in_grid_bounds(grid, rect) then
    return false
  end

  if grid.visual_bounds then
    local mx, my = ImGui.GetMousePos(ctx)
    if not Draw.point_in_rect(mx, my, grid.visual_bounds[1], grid.visual_bounds[2], grid.visual_bounds[3], grid.visual_bounds[4]) then
      return false
    end
  end
  
  local key = grid.key(item)
  
  if M.is_mouse_in_exclusion(grid, ctx, item, rect) then
    return false
  end

  local mx, my = ImGui.GetMousePos(ctx)
  local is_hovered = Draw.point_in_rect(mx, my, rect[1], rect[2], rect[3], rect[4])
  if is_hovered then grid.hover_id = key end

  if is_hovered and not grid.sel_rect:is_active() and not grid.drag.active and not M.is_external_drag_active(grid) then
    if ImGui.IsMouseClicked(ctx, 0) then
      local shift = ImGui.IsKeyDown(ctx, ImGui.Key_LeftShift) or ImGui.IsKeyDown(ctx, ImGui.Key_RightShift)
      local ctrl  = ImGui.IsKeyDown(ctx, ImGui.Key_LeftCtrl)  or ImGui.IsKeyDown(ctx, ImGui.Key_RightCtrl)
      local was_selected = grid.selection:is_selected(key)

      if ctrl then
        grid.selection:toggle(key)
        if grid.behaviors and grid.behaviors.on_select then
          grid.behaviors.on_select(grid.selection:selected_keys())
        end
      elseif shift and grid.selection.last_clicked then
        local items = grid.get_items()
        local order = {}
        for _, it in ipairs(items) do order[#order+1] = grid.key(it) end
        grid.selection:range(order, grid.selection.last_clicked, key)
        if grid.behaviors and grid.behaviors.on_select then
          grid.behaviors.on_select(grid.selection:selected_keys())
        end
      else
        if not was_selected then
          grid.drag.pending_selection = key
        end
      end

      grid.drag.pressed_id = key
      grid.drag.pressed_was_selected = was_selected
      grid.drag.press_pos = {mx, my}
    end

    -- Right-click: Disable items (was: Toggle favorite)
    if ImGui.IsMouseClicked(ctx, 1) then
      if grid.behaviors and grid.behaviors.delete then
        local selected_keys = grid.selection:selected_keys()
        if grid.selection:is_selected(key) and #selected_keys > 1 then
          -- Multi-select: disable all selected
          grid.behaviors.delete(selected_keys)
        else
          -- Single item: disable just this one
          grid.behaviors.delete({key})
        end
      end
    end

    if ImGui.IsMouseDoubleClicked(ctx, 0) then
      -- Double-click triggers inline editing for single tile
      if grid.behaviors and grid.behaviors.start_inline_edit then
        grid.behaviors.start_inline_edit(key)
      elseif grid.behaviors and grid.behaviors.double_click then
        grid.behaviors.double_click(key)
      end
    end
  end

  return is_hovered
end

-- Check if currently editing a tile inline
function M.is_editing_inline(grid)
  return grid.editing_state and grid.editing_state.active
end

-- Get the key being edited
function M.get_editing_key(grid)
  if not M.is_editing_inline(grid) then return nil end
  return grid.editing_state.key
end

-- Start inline editing for a single tile
function M.start_inline_edit(grid, key, initial_text)
  grid.editing_state = {
    active = true,
    key = key,
    text = initial_text or "",
    focus_next_frame = true,
  }
end

-- Stop inline editing (commit or cancel)
function M.stop_inline_edit(grid, commit)
  if not grid.editing_state or not grid.editing_state.active then return end

  local key = grid.editing_state.key
  local new_text = grid.editing_state.text

  grid.editing_state = nil

  if commit and grid.behaviors and grid.behaviors.on_inline_edit_complete then
    grid.behaviors.on_inline_edit_complete(key, new_text)
  end
end

-- Handle inline editing input (call this during tile rendering)
function M.handle_inline_edit_input(grid, ctx, key, rect, current_text)
  if not grid.editing_state or grid.editing_state.key ~= key then
    return false, current_text  -- Not editing this tile
  end

  local state = grid.editing_state

  -- Set up input field position
  local padding = 6
  ImGui.SetCursorScreenPos(ctx, rect[1] + padding, rect[2] + padding)
  ImGui.SetNextItemWidth(ctx, rect[3] - rect[1] - padding * 2)

  -- Focus input on first frame
  if state.focus_next_frame then
    ImGui.SetKeyboardFocusHere(ctx)
    state.focus_next_frame = false
  end

  -- Draw input field
  local changed, new_text = ImGui.InputText(
    ctx,
    "##inline_edit_" .. key,
    state.text,
    ImGui.InputTextFlags_None
  )

  if changed then
    state.text = new_text
  end

  -- Check for Enter (commit) or Escape (cancel)
  local is_active = ImGui.IsItemActive(ctx)
  local enter_pressed = ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) or ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadEnter)
  local escape_pressed = ImGui.IsKeyPressed(ctx, ImGui.Key_Escape)

  if enter_pressed and is_active then
    M.stop_inline_edit(grid, true)  -- Commit
    return true, state.text
  elseif escape_pressed or (not is_active and ImGui.IsMouseClicked(ctx, 0)) then
    M.stop_inline_edit(grid, false)  -- Cancel
    return true, current_text
  end

  return true, state.text  -- Still editing
end

function M.check_start_drag(grid, ctx)
  if not grid.drag.pressed_id or grid.drag.active or M.is_external_drag_active(grid) then return end

  local threshold = (grid.config and grid.config.drag and grid.config.drag.threshold) or 5
  if ImGui.IsMouseDragging(ctx, 0, threshold) then
    grid.drag.pending_selection = nil
    grid.drag.active = true

    if grid.selection:count() > 0 and grid.selection:is_selected(grid.drag.pressed_id) then
      local items = grid.get_items()
      local order = {}
      for _, item in ipairs(items) do order[#order+1] = grid.key(item) end
      grid.drag.ids = grid.selection:selected_keys_in(order)
    else
      grid.drag.ids = { grid.drag.pressed_id }
      grid.selection:single(grid.drag.pressed_id)
      if grid.behaviors and grid.behaviors.on_select then 
        grid.behaviors.on_select(grid.selection:selected_keys()) 
      end
    end

    if grid.behaviors and grid.behaviors.drag_start then
      grid.behaviors.drag_start(grid.drag.ids)
    end
  end
end

return M