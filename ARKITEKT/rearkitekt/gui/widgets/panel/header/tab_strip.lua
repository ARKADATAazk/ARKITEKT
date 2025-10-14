-- @noindex
-- ReArkitekt/gui/widgets/panel/header/tab_strip.lua
-- Clean, modular tab strip with improved animation control

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.9'
local ContextMenu = require('rearkitekt.gui.widgets.controls.context_menu')
local Chip = require('rearkitekt.gui.widgets.component.chip')

local M = {}

local TAB_SLIDE_SPEED = 15.0
local DRAG_THRESHOLD = 3.0

local DEFAULTS = {
  bg_color = 0x252525FF,
  bg_hover_color = 0x2A2A2AFF,
  bg_active_color = 0x303030FF,
  border_outer_color = 0x000000DD,
  border_inner_color = 0x404040FF,
  border_hover_color = 0x505050FF,
  border_active_color = 0x7B7B7BFF,
  text_color = 0xAAAAAAFF,
  text_hover_color = 0xFFFFFFFF,
  text_active_color = 0xFFFFFFFF,
}

local function get_corner_flags(corner_rounding)
  if not corner_rounding then
    return 0
  end
  
  local flags = 0
  if corner_rounding.round_top_left then
    flags = flags | ImGui.DrawFlags_RoundCornersTopLeft
  end
  if corner_rounding.round_top_right then
    flags = flags | ImGui.DrawFlags_RoundCornersTopRight
  end
  
  return flags
end

local function calculate_tab_width(ctx, label, config, has_chip)
  local text_w = ImGui.CalcTextSize(ctx, label)
  local chip_width = has_chip and 20 or 0
  local min_width = config.min_width or 60
  local max_width = config.max_width or 180
  local padding_x = config.padding_x or 5
  
  return math.min(max_width, math.max(min_width, text_w + padding_x * 2 + chip_width))
end

local function init_tab_positions(state, tabs, start_x, ctx, config)
  if not state.tab_positions then
    state.tab_positions = {}
  end
  
  if not state.tab_animation_enabled then
    state.tab_animation_enabled = {}
  end
  
  local cursor_x = start_x
  local spacing = config.spacing or 0
  
  for i, tab in ipairs(tabs) do
    if not state.tab_positions[tab.id] then
      local has_chip = tab.chip_color ~= nil
      local tab_width = calculate_tab_width(ctx, tab.label or "Tab", config, has_chip)
      
      state.tab_positions[tab.id] = {
        current_x = cursor_x,
        target_x = cursor_x,
      }
      
      state.tab_animation_enabled[tab.id] = false
      
      local effective_spacing = spacing
      if i < #tabs and spacing == 0 then
        effective_spacing = -1
      end
      
      cursor_x = cursor_x + tab_width + effective_spacing
    end
  end
end

local function update_tab_positions(ctx, state, config, tabs, start_x)
  local spacing = config.spacing or 0
  local dt = ImGui.GetDeltaTime(ctx)
  local cursor_x = start_x
  
  for i, tab in ipairs(tabs) do
    local has_chip = tab.chip_color ~= nil
    local tab_width = calculate_tab_width(ctx, tab.label or "Tab", config, has_chip)
    local pos = state.tab_positions[tab.id]
    
    if not pos then
      pos = { current_x = cursor_x, target_x = cursor_x }
      state.tab_positions[tab.id] = pos
      state.tab_animation_enabled[tab.id] = false
    end
    
    local new_target = cursor_x
    
    if math.abs(new_target - pos.target_x) > 0.5 then
      state.tab_animation_enabled[tab.id] = true
    end
    
    pos.target_x = new_target
    
    if state.tab_animation_enabled[tab.id] then
      local diff = pos.target_x - pos.current_x
      if math.abs(diff) > 0.5 then
        local move = diff * TAB_SLIDE_SPEED * dt
        pos.current_x = pos.current_x + move
      else
        pos.current_x = pos.target_x
        state.tab_animation_enabled[tab.id] = false
      end
    else
      pos.current_x = pos.target_x
    end
    
    local effective_spacing = spacing
    if i < #tabs and spacing == 0 then
      effective_spacing = -1
    end
    
    cursor_x = cursor_x + tab_width + effective_spacing
  end
end

local function enable_animation_for_affected_tabs(state, tabs, affected_index)
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

local function draw_plus_button(ctx, dl, x, y, width, height, config, unique_id, corner_rounding)
  local btn_cfg = config.plus_button or {}
  
  for k, v in pairs(DEFAULTS) do
    if btn_cfg[k] == nil then btn_cfg[k] = v end
  end
  
  local is_hovered = ImGui.IsMouseHoveringRect(ctx, x, y, x + width, y + height)
  local is_active = ImGui.IsMouseDown(ctx, 0) and is_hovered

  local bg_color = btn_cfg.bg_color
  local border_inner = btn_cfg.border_inner_color
  local icon_color = btn_cfg.text_color

  if is_active then
    bg_color = btn_cfg.bg_active_color
    border_inner = btn_cfg.border_active_color or btn_cfg.border_hover_color
    icon_color = btn_cfg.text_active_color or btn_cfg.text_hover_color
  elseif is_hovered then
    bg_color = btn_cfg.bg_hover_color
    border_inner = btn_cfg.border_hover_color
    icon_color = btn_cfg.text_hover_color
  end

  local rounding = corner_rounding and corner_rounding.rounding or 4
  local inner_rounding = math.max(0, rounding - 2)
  local corner_flags = get_corner_flags(corner_rounding)
  
  ImGui.DrawList_AddRectFilled(dl, x, y, x + width, y + height, bg_color, inner_rounding, corner_flags)
  
  ImGui.DrawList_AddRect(dl, x + 1, y + 1, x + width - 1, y + height - 1, border_inner, inner_rounding, corner_flags, 1)
  
  ImGui.DrawList_AddRect(dl, x, y, x + width, y + height, btn_cfg.border_outer_color or config.border_outer_color, inner_rounding, corner_flags, 1)

  local center_x = x + width * 0.5 
  local center_y = y + height * 0.5 - 1
  local cross_size = 7
  local cross_thickness = 1
  
  ImGui.DrawList_AddRectFilled(dl, 
    center_x - cross_size * 0.5, center_y - cross_thickness * 0.5,
    center_x + cross_size * 0.5, center_y + cross_thickness * 0.5,
    icon_color)
  
  ImGui.DrawList_AddRectFilled(dl,
    center_x - cross_thickness * 0.5, center_y - cross_size * 0.5,
    center_x + cross_thickness * 0.5, center_y + cross_size * 0.5,
    icon_color)

  ImGui.SetCursorScreenPos(ctx, x, y)
  local clicked = ImGui.InvisibleButton(ctx, "##plus_" .. unique_id, width, height)

  return clicked, width
end

local function draw_overflow_button(ctx, dl, x, y, width, height, config, hidden_count, unique_id, corner_rounding)
  local btn_cfg = config.overflow_button or {}
  
  for k, v in pairs(DEFAULTS) do
    if btn_cfg[k] == nil then btn_cfg[k] = v end
  end
  
  local count_text = tostring(hidden_count)
  
  local is_hovered = ImGui.IsMouseHoveringRect(ctx, x, y, x + width, y + height)
  local is_active = ImGui.IsMouseDown(ctx, 0) and is_hovered

  local bg_color = btn_cfg.bg_color
  local border_inner = btn_cfg.border_inner_color
  local text_color = btn_cfg.text_color

  if is_active then
    bg_color = btn_cfg.bg_active_color
    border_inner = btn_cfg.border_active_color or btn_cfg.border_hover_color
    text_color = btn_cfg.text_active_color or btn_cfg.text_hover_color
  elseif is_hovered then
    bg_color = btn_cfg.bg_hover_color
    border_inner = btn_cfg.border_hover_color
    text_color = btn_cfg.text_hover_color
  end

  local rounding = corner_rounding and corner_rounding.rounding or 4
  local inner_rounding = math.max(0, rounding - 2)
  local corner_flags = get_corner_flags(corner_rounding)
  
  ImGui.DrawList_AddRectFilled(dl, x, y, x + width, y + height, bg_color, inner_rounding, corner_flags)
  
  ImGui.DrawList_AddRect(dl, x + 1, y + 1, x + width - 1, y + height - 1, border_inner, inner_rounding, corner_flags, 1)
  
  ImGui.DrawList_AddRect(dl, x, y, x + width, y + height, btn_cfg.border_outer_color or config.border_outer_color, inner_rounding, corner_flags, 1)

  local text_w = ImGui.CalcTextSize(ctx, count_text)
  local text_x = x + (width - text_w) * 0.5
  local text_y = y + (height - ImGui.GetTextLineHeight(ctx)) * 0.5
  ImGui.DrawList_AddText(dl, text_x, text_y, text_color, count_text)

  ImGui.SetCursorScreenPos(ctx, x, y)
  local clicked = ImGui.InvisibleButton(ctx, "##overflow_" .. unique_id, width, height)

  return clicked
end

local function draw_track(ctx, dl, x, y, width, height, config, corner_rounding)
  local track_cfg = config.track
  if not track_cfg or not track_cfg.enabled then return end
  
  local track_x = x - track_cfg.extend_left
  local track_y = y - track_cfg.extend_top
  local track_width = width + track_cfg.extend_left + track_cfg.extend_right
  local track_height = height + track_cfg.extend_top + track_cfg.extend_bottom
  
  local rounding = corner_rounding and corner_rounding.rounding or (track_cfg.rounding or 6)
  local corner_flags = get_corner_flags(corner_rounding)
  
  ImGui.DrawList_AddRectFilled(
    dl,
    track_x, track_y,
    track_x + track_width, track_y + track_height,
    track_cfg.bg_color or 0x1A1A1AFF,
    rounding,
    corner_flags
  )
  
  if track_cfg.border_thickness and track_cfg.border_thickness > 0 then
    ImGui.DrawList_AddRect(
      dl,
      track_x, track_y,
      track_x + track_width, track_y + track_height,
      track_cfg.border_color or 0x0A0A0AFF,
      rounding,
      corner_flags,
      track_cfg.border_thickness
    )
  end
end

local function draw_tab(ctx, dl, tab_data, is_active, tab_index, x, y, width, height, state, config, unique_id, animator, corner_rounding)
  for k, v in pairs(DEFAULTS) do
    if config[k] == nil then config[k] = v end
  end
  
  local label = tab_data.label or "Tab"
  local id = tab_data.id
  local chip_color = tab_data.chip_color
  local has_chip = chip_color ~= nil
  
  local is_spawning = animator and animator:is_spawning(id)
  local is_destroying = animator and animator:is_destroying(id)
  
  local render_x, render_y, render_w, render_h = x, y, width, height
  local alpha_factor = 1.0
  
  if is_spawning and animator.get_spawn_factor then
    local spawn_factor = animator:get_spawn_factor(id)
    local target_w = width * spawn_factor
    local offset_x = (width - target_w) * 0.5
    render_x = x + offset_x
    render_w = target_w
    alpha_factor = spawn_factor
  elseif is_destroying and animator.get_destroy_factor then
    local destroy_factor = animator:get_destroy_factor(id)
    local scale = 1.0 - destroy_factor
    local new_w = width * scale
    local new_h = height * scale
    local offset_x = (width - new_w) * 0.5
    local offset_y = (height - new_h) * 0.5
    render_x = x + offset_x
    render_y = y + offset_y
    render_w = new_w
    render_h = new_h
    alpha_factor = 1.0 - destroy_factor
  end

  local is_hovered = ImGui.IsMouseHoveringRect(ctx, render_x, render_y, render_x + render_w, render_y + render_h)
  local is_pressed = ImGui.IsMouseDown(ctx, 0) and is_hovered and not state.dragging_tab

  local apply_alpha = function(color, factor)
    local a = color & 0xFF
    local new_a = math.floor(a * factor)
    return (color & 0xFFFFFF00) | new_a
  end

  local bg_color = config.bg_color
  local border_inner = config.border_inner_color
  local text_color = config.text_color
  
  if is_active then
    bg_color = config.bg_active_color
    border_inner = config.border_active_color
    text_color = config.text_active_color
  elseif is_pressed then
    bg_color = config.bg_active_color
    border_inner = config.border_hover_color
    text_color = config.text_hover_color
  elseif is_hovered then
    bg_color = config.bg_hover_color
    border_inner = config.border_hover_color
    text_color = config.text_hover_color
  end
  
  bg_color = apply_alpha(bg_color, alpha_factor)
  local border_outer = apply_alpha(config.border_outer_color, alpha_factor)
  border_inner = apply_alpha(border_inner, alpha_factor)
  text_color = apply_alpha(text_color, alpha_factor)

  local rounding = corner_rounding and corner_rounding.rounding or 0
  local inner_rounding = math.max(0, rounding - 2)
  local corner_flags = get_corner_flags(corner_rounding)

  ImGui.DrawList_AddRectFilled(dl, render_x, render_y, render_x + render_w, render_y + render_h, 
                                bg_color, inner_rounding, corner_flags)
  
  ImGui.DrawList_AddRect(dl, render_x + 1, render_y + 1, render_x + render_w - 1, render_y + render_h - 1, 
                         border_inner, inner_rounding, corner_flags, 1)
  
  ImGui.DrawList_AddRect(dl, render_x, render_y, render_x + render_w, render_y + render_h, 
                         border_outer, inner_rounding, corner_flags, 1)

  local content_x = render_x + (config.padding_x or 5)
  
  if has_chip then
    local chip_x = content_x + 2
    local chip_y = render_y + render_h * 0.5
    
    Chip.draw(ctx, {
      style = Chip.STYLE.INDICATOR,
      color = chip_color,
      draw_list = dl,
      x = chip_x,
      y = chip_y,
      radius = config.chip_radius or 4,
      is_selected = is_active,
      is_hovered = is_hovered,
      show_glow = is_active or is_hovered,
      glow_layers = 2,
      alpha_factor = alpha_factor,
    })
    
    content_x = content_x + 12
  end

  local text_w, text_h = ImGui.CalcTextSize(ctx, label)
  local text_x = content_x
  local text_y = render_y + (render_h - text_h) * 0.5

  local text_max_w = render_x + render_w - text_x - (config.padding_x or 5)
  if text_w > text_max_w then
    ImGui.DrawList_PushClipRect(dl, text_x, render_y, 
                                render_x + render_w - (config.padding_x or 5), render_y + render_h, true)
    ImGui.DrawList_AddText(dl, text_x, text_y, text_color, label)
    ImGui.DrawList_PopClipRect(dl)
  else
    ImGui.DrawList_AddText(dl, text_x, text_y, text_color, label)
  end

  ImGui.SetCursorScreenPos(ctx, render_x, render_y)
  ImGui.InvisibleButton(ctx, "##tab_" .. id .. "_" .. unique_id, render_w, render_h)

  local clicked = ImGui.IsItemClicked(ctx, 0)
  local right_clicked = ImGui.IsItemClicked(ctx, 1)

  if ImGui.IsItemActive(ctx) and not state.dragging_tab then
    local drag_delta_x, drag_delta_y = ImGui.GetMouseDragDelta(ctx, 0)
    local drag_distance = math.sqrt(drag_delta_x * drag_delta_x + drag_delta_y * drag_delta_y)
    
    if drag_distance > DRAG_THRESHOLD and ImGui.IsMouseDragging(ctx, 0) then
      local mx = ImGui.GetMousePos(ctx)
      state.dragging_tab = {
        id = id,
        index = tab_index,
        offset_x = mx - render_x,
        original_index = tab_index,
      }
    end
  end

  local delete_requested = false
  if right_clicked then
    ImGui.OpenPopup(ctx, "##tab_context_" .. id .. "_" .. unique_id)
  end

  if ContextMenu.begin(ctx, "##tab_context_" .. id .. "_" .. unique_id, config.context_menu) then
    if ContextMenu.item(ctx, "Delete Tab", config.context_menu) then
      delete_requested = true
    end
    ContextMenu.end_menu(ctx)
  end

  return clicked, delete_requested
end

local function calculate_visible_tabs(ctx, tabs, config, available_width)
  local visible_indices = {}
  local current_width = 0
  local spacing = config.spacing or 0
  
  for i, tab in ipairs(tabs) do
    local has_chip = tab.chip_color ~= nil
    local tab_width = calculate_tab_width(ctx, tab.label or "Tab", config, has_chip)
    local effective_spacing = (i > 1) and spacing or 0
    if i > 1 and i <= #tabs and spacing == 0 then
      effective_spacing = -1
    end
    local needed = tab_width + effective_spacing
    
    if current_width + needed <= available_width then
      visible_indices[#visible_indices + 1] = i
      current_width = current_width + needed
    else
      break
    end
  end
  
  local overflow_count = #tabs - #visible_indices
  
  return visible_indices, overflow_count, current_width
end

local function handle_drag_reorder(ctx, state, tabs, config, tabs_start_x)
  if not state.dragging_tab then return end
  if not ImGui.IsMouseDragging(ctx, 0) then return end
  
  local mx = ImGui.GetMousePos(ctx)
  local dragged_tab = tabs[state.dragging_tab.index]
  local has_chip = dragged_tab.chip_color ~= nil
  local dragged_width = calculate_tab_width(ctx, dragged_tab.label or "Tab", config, has_chip)
  local spacing = config.spacing or 0
  
  local drag_left = mx - state.dragging_tab.offset_x
  local drag_right = drag_left + dragged_width
  
  local positions = {}
  local current_x = tabs_start_x
  
  for i = 1, #tabs do
    local tab = tabs[i]
    local tab_has_chip = tab.chip_color ~= nil
    local tab_w = calculate_tab_width(ctx, tab.label or "Tab", config, tab_has_chip)
    
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

local function finalize_drag(ctx, state, config)
  if not state.dragging_tab then return end
  
  if not ImGui.IsMouseDown(ctx, 0) then
    local mx = ImGui.GetMousePos(ctx)
    if state.tab_positions and state.tab_positions[state.dragging_tab.id] then
      state.tab_positions[state.dragging_tab.id].current_x = mx - state.dragging_tab.offset_x
    end
    
    if config.on_tab_reorder and state.dragging_tab.original_index ~= state.dragging_tab.index then
      config.on_tab_reorder(state.dragging_tab.original_index, state.dragging_tab.index)
    end
    
    state.dragging_tab = nil
  end
end

function M.draw(ctx, dl, x, y, available_width, height, config, state)
  config = config or {}
  state = state or {}
  
  local element_id = state.id or "tabstrip"
  local unique_id = string.format("%s_%s", tostring(state._panel_id or "unknown"), element_id)
  
  local tabs = state.tabs or {}
  local active_tab_id = state.active_tab_id
  local animator = state.tab_animator
  local corner_rounding = config.corner_rounding
  
  if animator and animator.update then
    animator:update()
  end

  local plus_cfg = config.plus_button or {}
  local plus_width = plus_cfg.width or 23
  local spacing = config.spacing or 0

  local tabs_start_x = x + plus_width
  if spacing > 0 then
    tabs_start_x = tabs_start_x + spacing
  else
    tabs_start_x = tabs_start_x - 1
  end

  init_tab_positions(state, tabs, tabs_start_x, ctx, config)

  local tabs_available_width_no_overflow = available_width - plus_width
  if spacing > 0 then
    tabs_available_width_no_overflow = tabs_available_width_no_overflow - spacing
  else
    tabs_available_width_no_overflow = tabs_available_width_no_overflow + 1
  end
  
  local visible_indices, overflow_count, tabs_width = calculate_visible_tabs(
    ctx, tabs, config, tabs_available_width_no_overflow
  )
  
  local overflow_width = 0
  if overflow_count > 0 then
    local overflow_cfg = config.overflow_button or { min_width = 21, padding_x = 8 }
    local count_text = tostring(overflow_count)
    local text_w = ImGui.CalcTextSize(ctx, count_text)
    overflow_width = math.max(overflow_cfg.min_width or 21, text_w + (overflow_cfg.padding_x or 8) * 2)
    
    local tabs_available_width_with_overflow = available_width - plus_width - overflow_width
    if spacing > 0 then
      tabs_available_width_with_overflow = tabs_available_width_with_overflow - spacing - spacing
    else
      tabs_available_width_with_overflow = tabs_available_width_with_overflow + 1 + 1
    end
    
    visible_indices, overflow_count, tabs_width = calculate_visible_tabs(
      ctx, tabs, config, tabs_available_width_with_overflow
    )
  end
  
  local tabs_total_width = tabs_width
  if overflow_count > 0 then
    tabs_total_width = tabs_total_width + overflow_width
    if spacing > 0 then
      tabs_total_width = tabs_total_width + spacing
    else
      tabs_total_width = tabs_total_width - 1
    end
  end
  
  if config.track and config.track.enabled then
    local track_start_x = x
    if not config.track.include_plus_button then
      track_start_x = tabs_start_x
    end
    
    draw_track(ctx, dl, track_start_x, y, 
               tabs_start_x - track_start_x + tabs_total_width, 
               height, config, corner_rounding)
  end

  local plus_corner = corner_rounding and {
    round_top_left = corner_rounding.round_top_left,
    round_top_right = false,
    rounding = corner_rounding.rounding,
  } or nil
  
  local plus_clicked, _ = draw_plus_button(ctx, dl, x, y, plus_width, height, config, unique_id, plus_corner)
  
  if plus_clicked and config.on_tab_create then
    config.on_tab_create()
  end

  handle_drag_reorder(ctx, state, tabs, config, tabs_start_x)
  finalize_drag(ctx, state, config)

  update_tab_positions(ctx, state, config, tabs, tabs_start_x)
  
  local clicked_tab_id = nil
  local id_to_delete = nil

  for i, tab_data in ipairs(tabs) do
    local is_visible = false
    for _, vis_idx in ipairs(visible_indices) do
      if vis_idx == i then
        is_visible = true
        break
      end
    end
    
    if is_visible then
      local pos = state.tab_positions[tab_data.id]
      if pos then
        local has_chip = tab_data.chip_color ~= nil
        local tab_w = calculate_tab_width(ctx, tab_data.label or "Tab", config, has_chip)
        local tab_x = pos.current_x
        
        if state.dragging_tab and state.dragging_tab.id == tab_data.id then
          local mx = ImGui.GetMousePos(ctx)
          tab_x = mx - state.dragging_tab.offset_x
        end
        
        local is_active = (tab_data.id == active_tab_id)
        local clicked, delete_requested = draw_tab(
          ctx, dl, tab_data, is_active, 
          i, tab_x, y, tab_w, height, 
          state, config, unique_id, animator, nil
        )

        if clicked and not (state.dragging_tab or ImGui.IsMouseDragging(ctx, 0)) then
          clicked_tab_id = tab_data.id
        end

        if delete_requested then
          id_to_delete = tab_data.id
        end
      end
    end
  end
  
  if overflow_count > 0 then
    local overflow_x = tabs_start_x + tabs_width
    if spacing > 0 then
      overflow_x = overflow_x + spacing
    else
      overflow_x = overflow_x - 1
    end
    
    local overflow_corner = corner_rounding and {
      round_top_left = false,
      round_top_right = corner_rounding.round_top_right,
      rounding = corner_rounding.rounding,
    } or nil
    
    local overflow_clicked = draw_overflow_button(
      ctx, dl, overflow_x, y, overflow_width, height, 
      config, overflow_count, unique_id, overflow_corner
    )
    
    if overflow_clicked and config.on_overflow_clicked then
      config.on_overflow_clicked()
    end
  end

  if clicked_tab_id and config.on_tab_change then
    config.on_tab_change(clicked_tab_id)
  end

  if id_to_delete and #tabs > 1 then
    for i, tab in ipairs(tabs) do
      if tab.id == id_to_delete then
        enable_animation_for_affected_tabs(state, tabs, i + 1)
        break
      end
    end
    
    if animator then
      animator:destroy(id_to_delete)
      state.pending_delete_id = id_to_delete
      
      if id_to_delete == active_tab_id and config.on_tab_change then
        for i, tab in ipairs(tabs) do
          if tab.id ~= id_to_delete then
            config.on_tab_change(tab.id)
            break
          end
        end
      end
    else
      if id_to_delete == active_tab_id and config.on_tab_change then
        for i, tab in ipairs(tabs) do
          if tab.id ~= id_to_delete then
            config.on_tab_change(tab.id)
            break
          end
        end
      end
      
      if config.on_tab_delete then
        config.on_tab_delete(id_to_delete)
      end
    end
  end

  if state.pending_delete_id and animator then
    if not animator:is_destroying(state.pending_delete_id) then
      if config.on_tab_delete then
        config.on_tab_delete(state.pending_delete_id)
      end
      state.pending_delete_id = nil
    end
  end

  return plus_width + (spacing > 0 and spacing or -1) + tabs_total_width
end

function M.measure(ctx, config, state)
  state = state or {}
  config = config or {}
  
  local plus_width = (config.plus_button and config.plus_button.width) or 23
  local spacing = config.spacing or 0
  
  local tabs = state.tabs or {}
  
  if #tabs == 0 then
    return plus_width
  end
  
  local total = plus_width
  if spacing > 0 then
    total = total + spacing
  else
    total = total - 1
  end
  
  for i, tab in ipairs(tabs) do
    local has_chip = tab.chip_color ~= nil
    local tab_w = calculate_tab_width(ctx, tab.label or "Tab", config, has_chip)
    total = total + tab_w
    local effective_spacing = spacing
    if i < #tabs then
      if spacing == 0 then
        effective_spacing = -1
      end
      total = total + effective_spacing
    end
  end
  
  return total
end

return M