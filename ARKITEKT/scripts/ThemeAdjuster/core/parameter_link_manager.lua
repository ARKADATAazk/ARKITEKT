-- @noindex
-- ThemeAdjuster/core/parameter_link_manager.lua
-- Parameter linking and synchronization system (GROUP-BASED)

local M = {}

-- ============================================================================
-- CONSTANTS
-- ============================================================================

M.LINK_MODE = {
  UNLINKED = "unlinked",
  LINK = "link",        -- Delta-based: parameters move together by same value
  SYNC = "sync",        -- Absolute: parameter syncs to group's source value
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
  -- Link groups: { [group_id] = { params = {param1, param2, ...}, type = "float|int|bool" } }
  groups = {},

  -- Parameter to group mapping: { [param_name] = group_id }
  param_to_group = {},

  -- Link modes per parameter: { [param_name] = "unlinked|link|sync" }
  link_modes = {},

  -- Virtual values (can exceed Reaper limits for LINK mode)
  -- { [param_name] = virtual_value }
  virtual_values = {},

  -- Next group ID
  next_group_id = 1,

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
-- GROUP MANAGEMENT
-- ============================================================================

-- Add a parameter to a link group (creates group if needed)
function M.add_to_group(param_name, param_type, target_param_name)
  -- Get normalized type
  local norm_type = normalize_param_type(param_type)
  if not norm_type then
    return false, "Invalid parameter type"
  end

  -- Check if target is in a group
  local target_group_id = state.param_to_group[target_param_name]

  if target_group_id then
    -- Add to existing group
    local group = state.groups[target_group_id]

    -- Verify type compatibility
    if group.type ~= norm_type then
      return false, "Type mismatch with group"
    end

    -- Remove from old group if exists
    M.remove_from_group(param_name)

    -- Add to group
    table.insert(group.params, param_name)
    state.param_to_group[param_name] = target_group_id

    -- Set default mode to LINK
    if not state.link_modes[param_name] then
      state.link_modes[param_name] = M.LINK_MODE.LINK
    end

    M.notify_listeners('param_added_to_group', { param = param_name, group_id = target_group_id })
    return true
  else
    -- Create new group with both parameters
    local group_id = state.next_group_id
    state.next_group_id = state.next_group_id + 1

    state.groups[group_id] = {
      params = { target_param_name, param_name },
      type = norm_type,
    }

    -- Remove from old groups if exist
    M.remove_from_group(target_param_name)
    M.remove_from_group(param_name)

    -- Map both to new group
    state.param_to_group[target_param_name] = group_id
    state.param_to_group[param_name] = group_id

    -- Set default modes
    if not state.link_modes[target_param_name] then
      state.link_modes[target_param_name] = M.LINK_MODE.LINK
    end
    if not state.link_modes[param_name] then
      state.link_modes[param_name] = M.LINK_MODE.LINK
    end

    M.notify_listeners('group_created', { group_id = group_id, params = { target_param_name, param_name } })
    return true
  end
end

-- Remove a parameter from its group
function M.remove_from_group(param_name)
  local group_id = state.param_to_group[param_name]
  if not group_id then return false end

  local group = state.groups[group_id]
  if not group then return false end

  -- Remove from group params list
  for i, p in ipairs(group.params) do
    if p == param_name then
      table.remove(group.params, i)
      break
    end
  end

  -- Remove mapping
  state.param_to_group[param_name] = nil

  -- Set mode to UNLINKED
  state.link_modes[param_name] = M.LINK_MODE.UNLINKED

  -- Clear virtual value
  state.virtual_values[param_name] = nil

  -- If group is now empty or has only one param, delete it
  if #group.params <= 1 then
    if #group.params == 1 then
      local last_param = group.params[1]
      state.param_to_group[last_param] = nil
      state.link_modes[last_param] = M.LINK_MODE.UNLINKED
      state.virtual_values[last_param] = nil
    end
    state.groups[group_id] = nil
  end

  M.notify_listeners('param_removed_from_group', { param = param_name, group_id = group_id })
  return true
end

-- Get group ID for a parameter
function M.get_group_id(param_name)
  return state.param_to_group[param_name]
end

-- Get all parameters in the same group as param_name
function M.get_group_params(param_name)
  local group_id = state.param_to_group[param_name]
  if not group_id then return {} end

  local group = state.groups[group_id]
  if not group then return {} end

  return group.params
end

-- Get all parameters in a group except param_name
function M.get_other_group_params(param_name)
  local all_params = M.get_group_params(param_name)
  local others = {}

  for _, p in ipairs(all_params) do
    if p ~= param_name then
      table.insert(others, p)
    end
  end

  return others
end

-- Check if parameter is in a group
function M.is_in_group(param_name)
  return state.param_to_group[param_name] ~= nil
end

-- ============================================================================
-- LINK MODE MANAGEMENT
-- ============================================================================

-- Get link mode for a parameter
function M.get_link_mode(param_name)
  return state.link_modes[param_name] or M.LINK_MODE.UNLINKED
end

-- Set link mode for a parameter
function M.set_link_mode(param_name, mode)
  -- Validate mode
  if mode ~= M.LINK_MODE.UNLINKED and
     mode ~= M.LINK_MODE.LINK and
     mode ~= M.LINK_MODE.SYNC then
    return false
  end

  -- If setting to UNLINKED, remove from group
  if mode == M.LINK_MODE.UNLINKED then
    M.remove_from_group(param_name)
    return true
  end

  -- Otherwise just set the mode
  state.link_modes[param_name] = mode

  M.notify_listeners('link_mode_changed', { param = param_name, mode = mode })
  return true
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

-- ============================================================================
-- VALUE PROPAGATION
-- ============================================================================

-- Propagate value change to other parameters in the group
-- Returns: array of { param_name, new_value, clamped_value }
function M.propagate_value_change(param_name, old_value, new_value)
  local propagations = {}

  -- Get group
  local group_id = state.param_to_group[param_name]
  if not group_id then return propagations end

  local group = state.groups[group_id]
  if not group then return propagations end

  local delta = new_value - old_value

  -- Propagate to other parameters in group
  for _, other_param in ipairs(group.params) do
    if other_param ~= param_name then
      local mode = state.link_modes[other_param]

      if mode == M.LINK_MODE.SYNC then
        -- SYNC: Match exact value
        table.insert(propagations, {
          param_name = other_param,
          new_value = new_value,
          clamped_value = new_value,
        })

      elseif mode == M.LINK_MODE.LINK then
        -- LINK: Apply delta
        local other_virtual = state.virtual_values[other_param]
        local other_current = other_virtual or old_value  -- Assume same starting value if no virtual
        local other_new = other_current + delta

        -- Store unclamped virtual value
        state.virtual_values[other_param] = other_new

        table.insert(propagations, {
          param_name = other_param,
          new_value = other_new,
          clamped_value = other_new,
          virtual_value = other_new,
        })
      end
      -- UNLINKED mode: do nothing
    end
  end

  return propagations
end

-- ============================================================================
-- SERIALIZATION
-- ============================================================================

-- Get all data for serialization
function M.get_all_data()
  return {
    groups = state.groups,
    param_to_group = state.param_to_group,
    link_modes = state.link_modes,
    virtual_values = state.virtual_values,
    next_group_id = state.next_group_id,
  }
end

-- Set all data from deserialization
function M.set_all_data(data)
  if data then
    state.groups = data.groups or {}
    state.param_to_group = data.param_to_group or {}
    state.link_modes = data.link_modes or {}
    state.virtual_values = data.virtual_values or {}
    state.next_group_id = data.next_group_id or 1
  end
  M.notify_listeners('data_loaded', {})
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
  state.groups = {}
  state.param_to_group = {}
  state.link_modes = {}
  state.virtual_values = {}
  state.next_group_id = 1
  M.notify_listeners('reset', {})
end

return M
