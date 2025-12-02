-- @noindex
-- arkitekt/gui/widgets/containers/panel/header/tab_strip/animations.lua
-- Tab animation logic: position tracking, slide animations, drag reorder

local ImGui = require('arkitekt.platform.imgui')
local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

-- Animation constants
M.TAB_SLIDE_SPEED = 15.0
M.DRAG_THRESHOLD = 3.0

-- Forward declaration for calculate_responsive_tab_widths (injected from rendering module)
local calculate_responsive_tab_widths
local calculate_tab_width

function M.set_width_calculators(responsive_fn, single_fn)
  calculate_responsive_tab_widths = responsive_fn
  calculate_tab_width = single_fn
end

function M.init_tab_positions(state, tabs, start_x, ctx, config, available_width, should_extend)
  if not state.tab_positions then
    state.tab_positions = {}
  end

  if not state.tab_animation_enabled then
    state.tab_animation_enabled = {}
  end

  -- Use cached widths if available, otherwise calculate
  local tab_widths
  if state._cached_tab_widths then
    tab_widths = state._cached_tab_widths
  else
    tab_widths, _ = calculate_responsive_tab_widths(ctx, tabs, config, available_width, should_extend)
  end

  local cursor_x = start_x
  local spacing = config.spacing or 0
  local key_fn = config.key or function(tab) return tab.id end

  for i, tab in ipairs(tabs) do
    local tab_id = key_fn(tab)
    if not state.tab_positions[tab_id] then
      local tab_width = tab_widths[i] or calculate_tab_width(ctx, tab.label or 'Tab', config, tab.chip_color ~= nil)

      state.tab_positions[tab_id] = {
        current_x = cursor_x,
        target_x = cursor_x,
      }

      state.tab_animation_enabled[tab_id] = false

      local effective_spacing = spacing
      if i < #tabs and spacing == 0 then
        effective_spacing = -1
      end

      cursor_x = cursor_x + tab_width + effective_spacing
    end
  end
end

function M.update_tab_positions(ctx, state, config, tabs, start_x, available_width, should_extend)
  local spacing = config.spacing or 0
  local dt = ImGui.GetDeltaTime(ctx)
  local cursor_x = start_x
  local key_fn = config.key or function(tab) return tab.id end

  -- Use cached widths if available, otherwise calculate
  local tab_widths
  if state._cached_tab_widths then
    tab_widths = state._cached_tab_widths
  else
    tab_widths, _ = calculate_responsive_tab_widths(ctx, tabs, config, available_width, should_extend)
  end

  -- First pass: calculate all new targets and detect if this is a uniform shift (window move)
  local new_targets = {}
  local deltas = {}
  local is_uniform_shift = true
  local first_delta = nil

  for i, tab in ipairs(tabs) do
    local tab_id = key_fn(tab)
    local tab_width = tab_widths[i] or calculate_tab_width(ctx, tab.label or 'Tab', config, tab.chip_color ~= nil)
    local pos = state.tab_positions[tab_id]

    if not pos then
      pos = { current_x = cursor_x, target_x = cursor_x }
      state.tab_positions[tab_id] = pos
      state.tab_animation_enabled[tab_id] = false
    end

    new_targets[tab_id] = cursor_x
    local delta = cursor_x - pos.target_x
    deltas[tab_id] = delta

    -- Check if all tabs are shifting by the same amount (window drag)
    if first_delta == nil then
      first_delta = delta
    elseif math.abs(delta - first_delta) > 0.1 then
      is_uniform_shift = false
    end

    local effective_spacing = spacing
    if i < #tabs and spacing == 0 then
      effective_spacing = -1
    end

    cursor_x = cursor_x + tab_width + effective_spacing
  end

  -- Second pass: update positions, snap instantly if uniform shift (window move)
  for i, tab in ipairs(tabs) do
    local tab_id = key_fn(tab)
    local pos = state.tab_positions[tab_id]
    local new_target = new_targets[tab_id]
    local delta = deltas[tab_id]

    if is_uniform_shift and math.abs(delta) > 0.01 then
      -- Window is being dragged: snap all tabs instantly, no animation
      pos.current_x = new_target
      pos.target_x = new_target
      state.tab_animation_enabled[tab_id] = false
    else
      -- Individual tab repositioning (reorder): use smooth animation
      if math.abs(new_target - pos.target_x) > 0.5 then
        state.tab_animation_enabled[tab_id] = true
      end

      pos.target_x = new_target

      if state.tab_animation_enabled[tab_id] then
        local diff = pos.target_x - pos.current_x
        if math.abs(diff) > 0.5 then
          local move = diff * M.TAB_SLIDE_SPEED * dt
          pos.current_x = pos.current_x + move
        else
          pos.current_x = pos.target_x
          state.tab_animation_enabled[tab_id] = false
        end
      else
        pos.current_x = pos.target_x
      end
    end
  end
end

function M.enable_animation_for_affected_tabs(state, tabs, affected_index)
  if not state.tab_animation_enabled then
    state.tab_animation_enabled = {}
  end

  for i = affected_index, #tabs do
    local tab = tabs[i]
    if tab then
      state.tab_animation_enabled[tab.id] = true
    end
  end
end

-- >>> INLINE EDITING (BEGIN)

function M.is_editing_inline(state)
  return state.editing_state and state.editing_state.active
end

function M.start_inline_edit(state, id, initial_text)
  state.editing_state = {
    active = true,
    id = id,
    text = initial_text or '',
    focus_next_frame = true,
    frames_active = 0,
  }
end

function M.stop_inline_edit(state, commit, config)
  if not state.editing_state or not state.editing_state.active then return end

  local id = state.editing_state.id
  local new_text = state.editing_state.text

  state.editing_state = nil

  if commit and config.on_tab_rename then
    config.on_tab_rename(id, new_text)
  end
end

function M.handle_inline_edit_input(ctx, dl, state, id, x, y, width, height, chip_color)
  if not state.editing_state or state.editing_state.id ~= id then
    return false  -- Not editing this tab
  end

  local edit_state = state.editing_state

  -- Increment frame counter
  edit_state.frames_active = (edit_state.frames_active or 0) + 1

  -- Calculate text line dimensions
  local text_height = ImGui.GetTextLineHeight(ctx)

  -- Calculate vertical position (vertically centered)
  local y_pos = y + (height - text_height) / 2

  -- Input field bounds
  local padding_x = 6
  local padding_y = 1
  local input_x1 = x + padding_x
  local input_y1 = y_pos - padding_y
  local input_x2 = x + width - padding_x
  local input_y2 = y_pos + text_height + padding_y

  -- Draw custom backdrop
  local bg_color
  if chip_color then
    -- Create darker version of chip color for backdrop
    bg_color = Colors.adjust_brightness(chip_color, 0.15)
    bg_color = Colors.with_opacity(bg_color, 0.88)
  else
    bg_color = hexrgb('#1A1A1AE0')
  end

  -- Draw backdrop with rounded corners
  ImGui.DrawList_AddRectFilled(dl, input_x1, input_y1, input_x2, input_y2, bg_color, 2, 0)

  -- Position and size the input field
  ImGui.SetCursorScreenPos(ctx, input_x1 + 4, y_pos - 1)
  ImGui.SetNextItemWidth(ctx, input_x2 - input_x1 - 8)

  -- Focus input on first frame
  if edit_state.focus_next_frame then
    ImGui.SetKeyboardFocusHere(ctx)
    edit_state.focus_next_frame = false
  end

  -- Calculate text and selection colors
  local text_color, selection_color
  if chip_color then
    text_color = Colors.adjust_brightness(chip_color, 1.8)
    selection_color = Colors.adjust_brightness(chip_color, 0.8)
    selection_color = Colors.with_opacity(selection_color, 0.67)
  else
    text_color = hexrgb('#FFFFFFDD')
    selection_color = hexrgb('#4444AAAA')
  end

  -- Style the input field to be transparent
  ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, hexrgb('#00000000'))
  ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgHovered, hexrgb('#00000000'))
  ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgActive, hexrgb('#00000000'))
  ImGui.PushStyleColor(ctx, ImGui.Col_Border, hexrgb('#00000000'))
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, text_color)
  ImGui.PushStyleColor(ctx, ImGui.Col_TextSelectedBg, selection_color)

  -- Draw input field
  local changed, new_text = ImGui.InputText(
    ctx,
    '##tab_inline_edit_' .. id,
    edit_state.text,
    ImGui.InputTextFlags_AutoSelectAll
  )

  ImGui.PopStyleColor(ctx, 6)

  if changed then
    edit_state.text = new_text
  end

  -- Track if item is hovered
  local is_item_hovered = ImGui.IsItemHovered(ctx)
  local is_active = ImGui.IsItemActive(ctx)

  -- Check for Enter (commit) or Escape (cancel)
  local enter_pressed = ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) or ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadEnter)
  local escape_pressed = ImGui.IsKeyPressed(ctx, ImGui.Key_Escape)

  if enter_pressed then
    return true, true  -- editing_active, should_commit
  elseif escape_pressed then
    return true, false  -- editing_active, should_cancel
  elseif ImGui.IsMouseClicked(ctx, 0) and edit_state.frames_active > 2 and not is_item_hovered and not is_active then
    -- Cancel if clicked outside
    return true, false  -- editing_active, should_cancel
  end

  return true, nil  -- Still editing, no action
end

-- <<< INLINE EDITING (END)

-- >>> DRAG REORDER (BEGIN)

function M.handle_drag_reorder(ctx, state, tabs, config, tabs_start_x, available_width, should_extend, overflow_x)
  if not state.dragging_tab then return end
  if not ImGui.IsMouseDragging(ctx, 0) then return end

  local mx = ImGui.GetMousePos(ctx)

  -- Use cached widths if available, otherwise calculate
  local tab_widths
  if state._cached_tab_widths then
    tab_widths = state._cached_tab_widths
  else
    tab_widths, _ = calculate_responsive_tab_widths(ctx, tabs, config, available_width, should_extend)
  end

  local dragged_tab = tabs[state.dragging_tab.index]
  local dragged_width = tab_widths[state.dragging_tab.index] or calculate_tab_width(ctx, dragged_tab.label or 'Tab', config, dragged_tab.chip_color ~= nil)
  local spacing = config.spacing or 0

  -- Clamp drag position to stay within bounds
  local unclamped_drag_left = mx - state.dragging_tab.offset_x
  local min_x = tabs_start_x
  local max_x = overflow_x and (overflow_x - dragged_width) or (tabs_start_x + available_width - dragged_width)
  local drag_left = math.max(min_x, math.min(max_x, unclamped_drag_left))
  local drag_right = drag_left + dragged_width

  -- Store clamped position for use in draw loop
  state.dragging_tab.clamped_x = drag_left

  local positions = {}
  local current_x = tabs_start_x

  for i = 1, #tabs do
    local tab = tabs[i]
    local tab_w = tab_widths[i] or calculate_tab_width(ctx, tab.label or 'Tab', config, tab.chip_color ~= nil)

    positions[i] = {
      index = i,
      left = current_x,
      center = current_x + tab_w * 0.5,
      right = current_x + tab_w,
      width = tab_w,
    }

    local effective_spacing = spacing
    if i < #tabs and spacing == 0 then
      effective_spacing = -1
    end

    current_x = current_x + tab_w + effective_spacing
  end

  local current_index = state.dragging_tab.index
  local target_index = current_index

  if current_index > 1 then
    local left_neighbor = positions[current_index - 1]
    if drag_left < left_neighbor.center then
      target_index = current_index - 1
    end
  end

  if current_index < #tabs then
    local right_neighbor = positions[current_index + 1]
    if drag_right > right_neighbor.center then
      target_index = current_index + 1
    end
  end

  if target_index ~= state.dragging_tab.index then
    local dragged_tab_data = table.remove(tabs, state.dragging_tab.index)
    table.insert(tabs, target_index, dragged_tab_data)

    local min_affected = math.min(state.dragging_tab.index, target_index)
    local max_affected = math.max(state.dragging_tab.index, target_index)

    for i = min_affected, max_affected do
      if tabs[i] then
        state.tab_animation_enabled[tabs[i].id] = true
      end
    end

    state.dragging_tab.index = target_index
  end
end

function M.finalize_drag(ctx, state, config, tabs, tabs_start_x, overflow_x, responsive_widths)
  if not state.dragging_tab then return end

  if not ImGui.IsMouseDown(ctx, 0) then
    local mx = ImGui.GetMousePos(ctx)
    if state.tab_positions and state.tab_positions[state.dragging_tab.id] then
      local dragged_tab_w = responsive_widths and responsive_widths[state.dragging_tab.index] or 50
      local unclamped_x = mx - state.dragging_tab.offset_x
      -- Clamp final position between plus button and overflow button
      local min_x = tabs_start_x
      local max_x = overflow_x - dragged_tab_w
      state.tab_positions[state.dragging_tab.id].current_x = math.max(min_x, math.min(max_x, unclamped_x))
    end

    if config.on_tab_reorder and state.dragging_tab.original_index ~= state.dragging_tab.index then
      config.on_tab_reorder(state.dragging_tab.original_index, state.dragging_tab.index)
    end

    state.dragging_tab = nil
  end
end

-- <<< DRAG REORDER (END)

return M
