-- @noindex
-- panel/state.lua
-- Panel state management (search, sort, tabs, mode)

local M = {}

-- ============================================================================
-- SEARCH TEXT STATE
-- ============================================================================

--- Get search text from panel state
--- @param panel table Panel instance
--- @return string Search text or empty string
function M.get_search_text(panel)
  if not panel.config.header or not panel.config.header.elements then
    return ""
  end

  for _, element in ipairs(panel.config.header.elements) do
    if element.type == "inputtext" then
      local element_state = panel[element.id]
      if element_state and element_state.search_text then
        return element_state.search_text
      end
    end
  end

  return ""
end

--- Set search text in panel state
--- @param panel table Panel instance
--- @param text string Search text
function M.set_search_text(panel, text)
  if not panel.config.header or not panel.config.header.elements then
    return
  end

  for _, element in ipairs(panel.config.header.elements) do
    if element.type == "inputtext" then
      if not panel[element.id] then
        panel[element.id] = {}
      end
      panel[element.id].search_text = text or ""
      return
    end
  end
end

-- ============================================================================
-- SORT MODE STATE
-- ============================================================================

--- Get sort mode from panel state
--- @param panel table Panel instance
--- @return string|nil Sort mode or nil
function M.get_sort_mode(panel)
  if not panel.config.header or not panel.config.header.elements then
    return nil
  end

  for _, element in ipairs(panel.config.header.elements) do
    if element.type == "combo" and element.id == "sort" then
      local element_state = panel[element.id]
      if element_state and element_state.dropdown_value ~= nil then
        return element_state.dropdown_value
      end
    end
  end

  return nil
end

--- Set sort mode in panel state
--- @param panel table Panel instance
--- @param mode string Sort mode
function M.set_sort_mode(panel, mode)
  if not panel.config.header or not panel.config.header.elements then
    return
  end

  for _, element in ipairs(panel.config.header.elements) do
    if element.type == "combo" and element.id == "sort" then
      if not panel[element.id] then
        panel[element.id] = {}
      end
      panel[element.id].dropdown_value = mode
      return
    end
  end
end

-- ============================================================================
-- SORT DIRECTION STATE
-- ============================================================================

--- Get sort direction from panel state
--- @param panel table Panel instance
--- @return string Sort direction ("asc" or "desc")
function M.get_sort_direction(panel)
  if not panel.config.header or not panel.config.header.elements then
    return "asc"
  end

  for _, element in ipairs(panel.config.header.elements) do
    if element.type == "combo" and element.id == "sort" then
      local element_state = panel[element.id]
      if element_state and element_state.dropdown_direction then
        return element_state.dropdown_direction
      end
    end
  end

  return "asc"
end

--- Set sort direction in panel state
--- @param panel table Panel instance
--- @param direction string Sort direction ("asc" or "desc")
function M.set_sort_direction(panel, direction)
  if not panel.config.header or not panel.config.header.elements then
    return
  end

  for _, element in ipairs(panel.config.header.elements) do
    if element.type == "combo" and element.id == "sort" then
      if not panel[element.id] then
        panel[element.id] = {}
      end
      panel[element.id].dropdown_direction = direction or "asc"
      return
    end
  end
end

-- ============================================================================
-- TAB STATE
-- ============================================================================

--- Set tabs configuration
--- @param panel table Panel instance
--- @param tabs table Tab list
--- @param active_id string|nil Active tab ID
function M.set_tabs(panel, tabs, active_id)
  panel.tabs = tabs or {}
  if active_id ~= nil then
    panel.active_tab_id = active_id
  end
end

--- Get tabs configuration
--- @param panel table Panel instance
--- @return table Tab list
function M.get_tabs(panel)
  return panel.tabs or {}
end

--- Get active tab ID
--- @param panel table Panel instance
--- @return string|nil Active tab ID
function M.get_active_tab_id(panel)
  return panel.active_tab_id
end

--- Set active tab ID
--- @param panel table Panel instance
--- @param id string Tab ID
function M.set_active_tab_id(panel, id)
  panel.active_tab_id = id
end

-- ============================================================================
-- MODE STATE
-- ============================================================================

--- Get current mode
--- @param panel table Panel instance
--- @return string|nil Current mode
function M.get_current_mode(panel)
  return panel.current_mode
end

--- Set current mode
--- @param panel table Panel instance
--- @param mode string Mode name
function M.set_current_mode(panel, mode)
  panel.current_mode = mode
end

-- ============================================================================
-- OVERFLOW MODAL STATE
-- ============================================================================

--- Check if overflow modal is visible
--- @param panel table Panel instance
--- @return boolean True if visible
function M.is_overflow_visible(panel)
  return panel._overflow_visible or false
end

--- Show overflow modal
--- @param panel table Panel instance
function M.show_overflow_modal(panel)
  panel._overflow_visible = true
end

--- Close overflow modal
--- @param panel table Panel instance
function M.close_overflow_modal(panel)
  panel._overflow_visible = false
end

return M
