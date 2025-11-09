-- @noindex
-- ReArkitekt/gui/widgets/panel/header/layout.lua
-- Layout engine for header elements with corner detection
-- Enhanced with left/right alignment support

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local M = {}

-- Component registry - imports from controls/ directly for reusable components
local COMPONENTS = {
  button = require('rearkitekt.gui.widgets.controls.button'),
  search_field = require('rearkitekt.gui.widgets.controls.search_input'),
  dropdown_field = require('rearkitekt.gui.widgets.controls.dropdown'),
  tab_strip = require('rearkitekt.gui.widgets.panel.header.tab_strip'),
  separator = require('rearkitekt.gui.widgets.panel.header.separator'),
}

-- ============================================================================
-- WIDTH CALCULATION
-- ============================================================================

local function calculate_element_width(ctx, element, state)
  local component = COMPONENTS[element.type]
  if not component then return 0 end
  
  if element.width then
    return element.width
  end
  
  if element.flex then
    return nil
  end
  
  if component.measure then
    return component.measure(ctx, element.config or {}, state)
  end
  
  return 0
end

-- ============================================================================
-- LEFT/RIGHT ALIGNMENT
-- ============================================================================

local function separate_by_alignment(elements)
  local left = {}
  local right = {}
  
  for _, element in ipairs(elements) do
    local align = element.align or "left"
    if align == "right" then
      table.insert(right, element)
    else
      table.insert(left, element)
    end
  end
  
  return left, right
end

local function layout_elements(ctx, elements, available_width, state)
  local layout = {}
  local fixed_total = 0
  local flex_total = 0
  local spacing = 0
  
  for i, element in ipairs(elements) do
    local width = calculate_element_width(ctx, element, state)
    
    if width then
      fixed_total = fixed_total + width
    else
      flex_total = flex_total + (element.flex or 1)
    end
    
    if i > 1 then
      spacing = spacing + (element.spacing_before or 0)
    end
    
    layout[i] = {
      element = element,
      fixed_width = width,
      flex = element.flex,
    }
  end
  
  local remaining = available_width - fixed_total - spacing
  local flex_unit = flex_total > 0 and (remaining / flex_total) or 0
  
  for i, item in ipairs(layout) do
    if not item.fixed_width then
      item.width = math.max(0, item.flex * flex_unit)
    else
      item.width = item.fixed_width
    end
  end
  
  return layout
end

-- ============================================================================
-- CORNER & SEPARATOR DETECTION
-- ============================================================================

local function is_separator(element_type)
  return element_type == 'separator'
end

local function find_first_non_separator(layout)
  for i = 1, #layout do
    if not is_separator(layout[i].element.type) then
      return i
    end
  end
  return nil
end

local function find_last_non_separator(layout)
  for i = #layout, 1, -1 do
    if not is_separator(layout[i].element.type) then
      return i
    end
  end
  return nil
end

local function find_separator_neighbors(elements, separator_index)
  local left_neighbor = nil
  local right_neighbor = nil
  
  for i = separator_index - 1, 1, -1 do
    if not is_separator(elements[i].element.type) then
      left_neighbor = i
      break
    end
  end
  
  for i = separator_index + 1, #elements do
    if not is_separator(elements[i].element.type) then
      right_neighbor = i
      break
    end
  end
  
  return left_neighbor, right_neighbor
end

local function calculate_corner_rounding(layout, header_rounding, is_bottom)
  local rounding_info = {}
  
  local first_idx = find_first_non_separator(layout)
  local last_idx = find_last_non_separator(layout)
  
  for i, item in ipairs(layout) do
    if is_separator(item.element.type) then
      rounding_info[i] = {
        round_top_left = false,
        round_top_right = false,
        round_bottom_left = false,
        round_bottom_right = false,
      }
    else
      local round_left = false
      local round_right = false
      
      if i == first_idx then
        round_left = true
      end
      
      if i == last_idx then
        round_right = true
      end
      
      for j = 1, #layout do
        if is_separator(layout[j].element.type) then
          local left_neighbor, right_neighbor = find_separator_neighbors(layout, j)
          if left_neighbor == i then
            round_right = true
          end
          if right_neighbor == i then
            round_left = true
          end
        end
      end
      
      -- Apply rounding based on header position
      if is_bottom then
        rounding_info[i] = {
          round_top_left = false,
          round_top_right = false,
          round_bottom_left = round_left,
          round_bottom_right = round_right,
          rounding = header_rounding,
        }
      else
        rounding_info[i] = {
          round_top_left = round_left,
          round_top_right = round_right,
          round_bottom_left = false,
          round_bottom_right = false,
          rounding = header_rounding,
        }
      end
    end
  end
  
  return rounding_info
end

-- ============================================================================
-- ELEMENT STATE MANAGEMENT
-- ============================================================================

local function get_or_create_element_state(state, element)
  if element.type == "tab_strip" then
    local element_state = state[element.id]
    if not element_state then
      element_state = {
        tabs = {},
        active_tab_id = nil,
        tab_positions = {},
        dragging_tab = nil,
        pending_delete_id = nil,
        _tabs_version = 0,
      }
      state[element.id] = element_state
    end
    
    if not element_state.dragging_tab then
      if state.tabs and type(state.tabs) == "table" then
        if element_state.tabs ~= state.tabs then
          element_state.tabs = state.tabs
          element_state._tabs_version = (element_state._tabs_version or 0) + 1
        end
        element_state.active_tab_id = state.active_tab_id
      end
    end
    
    if state.tab_animator then
      element_state.tab_animator = state.tab_animator
    end
    
    element_state.id = element.id
    element_state._panel_id = state.id
    
    return element_state
  else
    local element_state = state[element.id]
    if not element_state then
      element_state = {}
      state[element.id] = element_state
    end
    element_state.id = element.id
    element_state._panel_id = state.id
    
    return element_state
  end
end

-- ============================================================================
-- ELEMENT RENDERING
-- ============================================================================

local function render_elements(ctx, dl, x, y, width, height, elements, state, header_rounding, is_bottom)
  if not elements or #elements == 0 then
    return 0
  end
  
  local layout = layout_elements(ctx, elements, width, state)
  local rounding_info = calculate_corner_rounding(layout, header_rounding, is_bottom)
  
  local border_overlap = 1
  local cursor_x = x
  local last_non_sep_idx = find_last_non_separator(layout)
  
  for i, item in ipairs(layout) do
    local element = item.element
    local element_width = item.width
    local spacing_before = element.spacing_before or 0
    
    if i > 1 then
      local prev_element = layout[i - 1].element
      if prev_element.type ~= 'separator' and element.type ~= 'separator' then
        spacing_before = spacing_before - border_overlap
      end
    end
    
    cursor_x = cursor_x + spacing_before
    
    if i == last_non_sep_idx and element.type ~= 'separator' then
      local remaining_space = (x + width) - cursor_x
      if remaining_space > element_width then
        element_width = remaining_space
      end
    end
    
    local component = COMPONENTS[element.type]
    if component and component.draw then
      local element_config = {}
      for k, v in pairs(element.config or {}) do
        element_config[k] = v
      end
      
      if rounding_info[i] then
        element_config.corner_rounding = rounding_info[i]
      end
      
      local element_state = get_or_create_element_state(state, element)
      
      local used_width = component.draw(
        ctx, dl,
        cursor_x, y,
        element_width, height,
        element_config,
        element_state
      )
      
      cursor_x = cursor_x + (used_width or element_width)
    else
      cursor_x = cursor_x + element_width
    end
  end
  
  return height
end

-- ============================================================================
-- MAIN DRAW FUNCTION
-- ============================================================================

function M.draw(ctx, dl, x, y, width, height, state, config)
  if not config or not config.elements or #config.elements == 0 then
    return 0
  end
  
  local padding = config.padding or {}
  local padding_left = padding.left or 0
  local padding_right = padding.right or 0
  
  local content_width = width - padding_left - padding_right
  local content_height = height
  local content_x = x + padding_left
  local content_y = y
  
  local header_rounding = config.rounding or 8
  local is_bottom = config.position == "bottom"
  
  -- Separate elements by alignment
  local left_elements, right_elements = separate_by_alignment(config.elements)
  
  if #left_elements > 0 and #right_elements > 0 then
    -- Both left and right elements: calculate available space
    local left_layout = layout_elements(ctx, left_elements, content_width, state)
    local right_layout = layout_elements(ctx, right_elements, content_width, state)
    
    -- Calculate total width needed
    local left_width = 0
    for _, item in ipairs(left_layout) do
      left_width = left_width + item.width
      if item.element.spacing_before then
        left_width = left_width + item.element.spacing_before
      end
    end
    
    local right_width = 0
    for _, item in ipairs(right_layout) do
      right_width = right_width + item.width
      if item.element.spacing_before then
        right_width = right_width + item.element.spacing_before
      end
    end
    
    -- Render left-aligned elements
    render_elements(ctx, dl, content_x, content_y, left_width, content_height, left_elements, state, header_rounding, is_bottom)
    
    -- Render right-aligned elements
    local right_x = content_x + content_width - right_width
    render_elements(ctx, dl, right_x, content_y, right_width, content_height, right_elements, state, header_rounding, is_bottom)
    
  elseif #right_elements > 0 then
    -- Only right-aligned elements
    local right_layout = layout_elements(ctx, right_elements, content_width, state)
    local right_width = 0
    for _, item in ipairs(right_layout) do
      right_width = right_width + item.width
      if item.element.spacing_before then
        right_width = right_width + item.element.spacing_before
      end
    end
    
    local right_x = content_x + content_width - right_width
    render_elements(ctx, dl, right_x, content_y, right_width, content_height, right_elements, state, header_rounding, is_bottom)
    
  else
    -- Only left-aligned elements (default)
    render_elements(ctx, dl, content_x, content_y, content_width, content_height, left_elements, state, header_rounding, is_bottom)
  end
  
  return height
end

return M
