-- @noindex
-- ReArkitekt/gui/widgets/panel/header/layout.lua
-- Layout engine for header elements with corner detection
-- Enhanced with left/right alignment support

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local PanelConfig = require('rearkitekt.gui.widgets.containers.panel.defaults')
local ConfigUtil = require('rearkitekt.core.config')

local M = {}

-- Component registry - imports from controls/ directly for reusable components
local COMPONENTS = {
  button = require('rearkitekt.gui.widgets.primitives.button'),
  search_field = require('rearkitekt.gui.widgets.inputs.search_input'),
  dropdown_field = require('rearkitekt.gui.widgets.inputs.dropdown'),
  tab_strip = require('rearkitekt.gui.widgets.containers.panel.header.tab_strip'),
  separator = require('rearkitekt.gui.widgets.containers.panel.header.separator'),
}

-- Inline component for filter chip lists
local ChipList = require('rearkitekt.gui.widgets.data.chip_list')
local Chip = require('rearkitekt.gui.widgets.data.chip')

-- Custom compound element for template browser header with search/sort + filter chips
local SearchInput = require('rearkitekt.gui.widgets.inputs.search_input')
local Dropdown = require('rearkitekt.gui.widgets.inputs.dropdown')
local Button = require('rearkitekt.gui.widgets.primitives.button')

COMPONENTS.template_header_controls = {
  draw = function(ctx, dl, x, y, width, height, config, state)
    local row1_height = 26
    local row_spacing = 4
    local row2_y = y + row1_height + row_spacing

    -- ROW 1: Template count + Search + Sort
    local cursor_x = x

    -- Template count (120px)
    if config.get_template_count then
      local count = config.get_template_count()
      local label = string.format("%d template%s", count, count == 1 and "" or "s")

      Button.draw(ctx, dl, cursor_x, y, 120, row1_height, {
        label = label,
        interactive = false,
        style = {
          bg_color = 0x00000000,  -- Transparent
          text_color = 0xAAAAAAFF,
        },
      }, state)
      cursor_x = cursor_x + 128
    end

    -- Search field (200px, positioned before sort)
    local sort_width = 140
    local search_width = 200
    local search_x = x + width - sort_width - search_width - 8

    if config.get_search_query and config.on_search_changed then
      SearchInput.draw(ctx, dl, search_x, y, search_width, row1_height, {
        placeholder = "Search templates...",
        get_value = config.get_search_query,
        on_change = config.on_search_changed,
      }, state)
    end

    -- Sort dropdown (140px, right side)
    if config.get_sort_mode and config.on_sort_changed then
      local sort_x = search_x + search_width + 8
      Dropdown.draw(ctx, dl, sort_x, y, sort_width, row1_height, {
        tooltip = "Sort by",
        tooltip_delay = 0.5,
        enable_sort = false,
        get_value = config.get_sort_mode,
        options = {
          { value = "alphabetical", label = "Alphabetical" },
          { value = "usage", label = "Most Used" },
          { value = "insertion", label = "Recently Added" },
          { value = "color", label = "Color" },
        },
        enable_mousewheel = true,
        on_change = config.on_sort_changed,
      }, state)
    end

    -- ROW 2: Filter chips
    if config.get_filter_items and config.on_filter_remove then
      local items = config.get_filter_items()
      if #items > 0 then
        ImGui.SetCursorScreenPos(ctx, x, row2_y)
        local clicked_id = ChipList.draw(ctx, items, {
          max_width = width,
          chip_height = 18,
          chip_spacing = 4,
          line_spacing = 2,
          use_dot_style = true,
        })

        if clicked_id then
          config.on_filter_remove(clicked_id)
        end
      end
    end

    return width
  end,

  measure = function(ctx, config, state)
    return 0  -- Dynamic width
  end,
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
  local center = {}
  local right = {}
  
  for _, element in ipairs(elements) do
    local align = element.align or "left"
    if align == "right" then
      table.insert(right, element)
    elseif align == "center" then
      table.insert(center, element)
    else
      table.insert(left, element)
    end
  end
  
  return left, center, right
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
      -- Separators never have rounding
      rounding_info[i] = {
        round_top_left = false,
        round_top_right = false,
        round_bottom_left = false,
        round_bottom_right = false,
      }
    else
      -- Default: no rounding (buttons in the middle of a group)
      local round_left = false
      local round_right = false
      
      -- Round left edge if: first element OR right neighbor of a separator
      if i == first_idx then
        round_left = true
      end
      
      -- Round right edge if: last element OR left neighbor of a separator
      if i == last_idx then
        round_right = true
      end
      
      -- Check if this element is adjacent to any separator
      for j = 1, #layout do
        if is_separator(layout[j].element.type) then
          local left_neighbor, right_neighbor = find_separator_neighbors(layout, j)
          if left_neighbor == i then
            -- This element is to the left of a separator
            round_right = true
          end
          if right_neighbor == i then
            -- This element is to the right of a separator
            round_left = true
          end
        end
      end
      
      -- Apply rounding based on header position (top vs bottom)
      -- Distinguish rounding caused by separators vs group edges (first/last)
      local left_due_to_sep, right_due_to_sep = false, false
      for j = 1, #layout do
        if is_separator(layout[j].element.type) then
          local ln, rn = find_separator_neighbors(layout, j)
          if ln == i then right_due_to_sep = true end
          if rn == i then left_due_to_sep = true end
        end
      end
      
      if is_bottom then
        -- Footer: round TOP corners only for elements adjacent to separators
        -- Corner-most elements (first/last) keep original BOTTOM rounding
        rounding_info[i] = {
          round_top_left = left_due_to_sep,
          round_top_right = right_due_to_sep,
          round_bottom_left = round_left and not left_due_to_sep,
          round_bottom_right = round_right and not right_due_to_sep,
          rounding = header_rounding,
        }
      else
        -- Header (top): standard behavior is top corners
        -- Special case: if this is a transport panel, use bottom corners instead
        local use_bottom_rounding = false
        -- Detect transport panel by checking if any element has transport-specific IDs
        for _, layout_item in ipairs(layout) do
          if layout_item.element.id and layout_item.element.id:match("^transport_") then
            use_bottom_rounding = true
            break
          end
        end
        
        if use_bottom_rounding then
          -- Transport special case: round BOTTOM corners for all buttons
          rounding_info[i] = {
            round_top_left = false,
            round_top_right = false,
            round_bottom_left = round_left,
            round_bottom_right = round_right,
            rounding = header_rounding,
          }
        else
          -- Standard top header: round TOP corners
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
      -- Merge panel ELEMENT_STYLE as fallback (won't override preset colors)
      local style_defaults = PanelConfig.ELEMENT_STYLE[element.type] or {}
      local element_config = ConfigUtil.merge_safe(element.config or {}, style_defaults)
      
      -- Pass element ID to config for unique identification
      element_config.id = element.id
      
      if rounding_info[i] then
        element_config.corner_rounding = rounding_info[i]
      end
      
      -- Update button label from panel current_mode if this is a mode_toggle button
      if element.type == "button" and element.id == "mode_toggle" and state.current_mode then
        if state.current_mode == "regions" then
          element_config.label = "Regions"
        elseif state.current_mode == "playlists" then
          element_config.label = "Playlists"
        elseif state.current_mode == "mixed" then
          element_config.label = "Mixed"
        end
      end

      -- Evaluate function-based labels (for dynamic content)
      if element_config.label and type(element_config.label) == "function" then
        element_config.label = element_config.label(state)
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
  local left_elements, center_elements, right_elements = separate_by_alignment(config.elements)
  
  -- Handle center elements
  if #center_elements > 0 then
    local center_layout = layout_elements(ctx, center_elements, content_width, state)
    local center_width = 0
    for _, item in ipairs(center_layout) do
      center_width = center_width + item.width
      if item.element.spacing_before then
        center_width = center_width + item.element.spacing_before
      end
    end
    
    local valign = config.valign or "top"
    -- Pixel snap center position to prevent blurry borders
    local center_x = math.floor(content_x + (content_width - center_width) / 2 + 0.5)
    render_elements(ctx, dl, center_x, content_y, center_width, content_height, center_elements, state, header_rounding, is_bottom, valign)
    return height
  end
  
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
