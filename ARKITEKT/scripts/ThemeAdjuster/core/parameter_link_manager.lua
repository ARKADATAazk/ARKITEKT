-- @noindex
-- ThemeAdjuster/core/parameter_link_manager.lua
-- Parameter linking and synchronization system

local M = {}

-- ============================================================================
-- CONSTANTS
-- ============================================================================

M.LINK_MODE = {
  UNLINKED = "unlinked",
  LINK = "link",        -- Delta-based: parameters move together by same value
  SYNC = "sync",        -- Absolute: child mirrors parent's exact value
}

M.PARAM_TYPE = {
  FLOAT = "float",
  INT = "int",
  BOOL = "bool",
}

-- ============================================================================
-- STATE STORAGE
-- ============================================================================

local state = {
  -- Link relationships: { [child_param_name] = { parent = "parent_name", mode = "link|sync" } }
  links = {},

  -- Virtual values (can exceed Reaper limits for LINK mode)
  -- { [param_name] = virtual_value }
  virtual_values = {},

  -- Change listeners for UI updates
  listeners = {},
}

-- ============================================================================
-- TYPE COMPATIBILITY
-- ============================================================================

-- Maps parameter type strings to our internal types
local function normalize_param_type(param_type)
  if param_type == "slider" then
    return M.PARAM_TYPE.FLOAT
  elseif param_type == "spinner" then
    return M.PARAM_TYPE.INT
  elseif param_type == "toggle" then
    return M.PARAM_TYPE.BOOL
  end
  return nil
end

-- Check if two parameters can be linked based on their types
function M.are_types_compatible(type_a, type_b)
  local norm_a = normalize_param_type(type_a)
  local norm_b = normalize_param_type(type_b)

  if not norm_a or not norm_b then return false end

  -- FLOAT can only link with FLOAT
  -- INT can link with INT
  -- BOOL can only link with BOOL
  return norm_a == norm_b
end

-- ============================================================================
-- LINK MANAGEMENT
-- ============================================================================

-- Create a link from parent to child
function M.create_link(parent_name, child_name, mode)
  mode = mode or M.LINK_MODE.SYNC

  -- Validate mode
  if mode ~= M.LINK_MODE.LINK and mode ~= M.LINK_MODE.SYNC then
    return false, "Invalid link mode"
  end

  -- Prevent self-linking
  if parent_name == child_name then
    return false, "Cannot link parameter to itself"
  end

  -- Prevent circular links
  if M.get_parent(parent_name) then
    return false, "Parent is already a child of another parameter"
  end

  -- Check if child is already a parent
  for child_param, link_data in pairs(state.links) do
    if link_data.parent == child_name then
      return false, "Child is already a parent of another parameter"
    end
  end

  -- Remove existing link if any
  M.remove_link(child_name)

  -- Create the link
  state.links[child_name] = {
    parent = parent_name,
    mode = mode,
  }

  -- Notify listeners
  M.notify_listeners('link_created', { parent = parent_name, child = child_name, mode = mode })

  return true
end

-- Remove a link
function M.remove_link(child_name)
  local link_data = state.links[child_name]
  if not link_data then return false end

  local parent_name = link_data.parent
  state.links[child_name] = nil

  -- Clear virtual value
  state.virtual_values[child_name] = nil

  -- Notify listeners
  M.notify_listeners('link_removed', { parent = parent_name, child = child_name })

  return true
end

-- Get parent of a parameter (if linked)
function M.get_parent(child_name)
  local link_data = state.links[child_name]
  return link_data and link_data.parent or nil
end

-- Get all children of a parameter
function M.get_children(parent_name)
  local children = {}
  for child_name, link_data in pairs(state.links) do
    if link_data.parent == parent_name then
      table.insert(children, {
        name = child_name,
        mode = link_data.mode,
      })
    end
  end
  return children
end

-- Get link mode for a parameter
function M.get_link_mode(param_name)
  local link_data = state.links[param_name]
  if not link_data then return M.LINK_MODE.UNLINKED end
  return link_data.mode
end

-- Set link mode (without changing parent)
function M.set_link_mode(child_name, mode)
  local link_data = state.links[child_name]
  if not link_data then return false end

  -- Validate mode
  if mode ~= M.LINK_MODE.LINK and mode ~= M.LINK_MODE.SYNC then
    return false
  end

  link_data.mode = mode

  -- Notify listeners
  M.notify_listeners('link_mode_changed', {
    parent = link_data.parent,
    child = child_name,
    mode = mode
  })

  return true
end

-- Check if a parameter is linked (as child)
function M.is_linked(param_name)
  return state.links[param_name] ~= nil
end

-- Check if a parameter is a parent
function M.is_parent(param_name)
  for _, link_data in pairs(state.links) do
    if link_data.parent == param_name then
      return true
    end
  end
  return false
end

-- Get all links (for serialization)
function M.get_all_links()
  return state.links
end

-- Set all links (for deserialization)
function M.set_all_links(links)
  state.links = links or {}
  M.notify_listeners('links_loaded', {})
end

-- ============================================================================
-- VIRTUAL VALUES (Extended Range for LINK mode)
-- ============================================================================

-- Get virtual value (may exceed Reaper limits)
function M.get_virtual_value(param_name)
  return state.virtual_values[param_name]
end

-- Set virtual value
function M.set_virtual_value(param_name, value)
  state.virtual_values[param_name] = value
end

-- Clear virtual value
function M.clear_virtual_value(param_name)
  state.virtual_values[param_name] = nil
end

-- Get all virtual values (for serialization)
function M.get_all_virtual_values()
  return state.virtual_values
end

-- Set all virtual values (for deserialization)
function M.set_all_virtual_values(values)
  state.virtual_values = values or {}
end

-- ============================================================================
-- VALUE PROPAGATION
-- ============================================================================

-- Propagate value change from parent to children
-- Returns: array of { param_name, new_value, clamped_value }
function M.propagate_value_change(parent_name, old_value, new_value, param_def)
  local propagations = {}

  local children = M.get_children(parent_name)
  if #children == 0 then return propagations end

  local delta = new_value - old_value

  for _, child_info in ipairs(children) do
    local child_name = child_info.name
    local mode = child_info.mode

    if mode == M.LINK_MODE.SYNC then
      -- SYNC: Child mirrors parent's exact value
      table.insert(propagations, {
        param_name = child_name,
        new_value = new_value,
        clamped_value = new_value,  -- Will be clamped by caller if needed
      })

    elseif mode == M.LINK_MODE.LINK then
      -- LINK: Apply delta to child's current value
      local child_virtual = state.virtual_values[child_name]
      local child_current = child_virtual or param_def.value  -- Use virtual or actual
      local child_new = child_current + delta

      -- Store unclamped virtual value
      state.virtual_values[child_name] = child_new

      table.insert(propagations, {
        param_name = child_name,
        new_value = child_new,
        clamped_value = child_new,  -- Will be clamped by caller if needed
        virtual_value = child_new,
      })
    end
  end

  return propagations
end

-- ============================================================================
-- FILTERING (For UI)
-- ============================================================================

-- Filter parameters by type compatibility
function M.filter_compatible_parameters(source_param, all_params)
  local compatible = {}
  local source_type = source_param.type

  for _, param in ipairs(all_params) do
    -- Skip self
    if param.name ~= source_param.name then
      -- Check type compatibility
      if M.are_types_compatible(source_type, param.type) then
        table.insert(compatible, param)
      end
    end
  end

  return compatible
end

-- ============================================================================
-- CHANGE LISTENERS
-- ============================================================================

function M.add_listener(callback)
  table.insert(state.listeners, callback)
end

function M.remove_listener(callback)
  for i, cb in ipairs(state.listeners) do
    if cb == callback then
      table.remove(state.listeners, i)
      return
    end
  end
end

function M.notify_listeners(event_type, data)
  for _, callback in ipairs(state.listeners) do
    callback(event_type, data)
  end
end

-- ============================================================================
-- RESET
-- ============================================================================

function M.reset()
  state.links = {}
  state.virtual_values = {}
  M.notify_listeners('reset', {})
end

return M
