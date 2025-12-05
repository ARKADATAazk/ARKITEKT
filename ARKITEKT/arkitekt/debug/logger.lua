-- @noindex
-- arkitekt/debug/logger.lua
-- Simple logging API for debug console

local M = {}

-- Standard log buffer (circular)
local buffer = {}
local max_entries = 1000
local start_index = 1
local count = 0

-- Live slots for high-frequency updating logs
local live_slots = {}
local live_slot_count = 0  -- Cached count for O(1) lookup
local live_slot_version = 0  -- Increments on any change (for cache invalidation)
local LIVE_HISTORY_MAX = 50
local LIVE_STALE_TIMEOUT = 10.0  -- Seconds before slot is considered stale

local function add_entry(level, category, message, ...)
  -- Format message with varargs if provided
  local formatted_message = message or ''
  if select('#', ...) > 0 then
    formatted_message = string.format(message, ...)
  end
  
  local entry = {
    time = reaper.time_precise(),
    level = level,
    category = category or 'SYSTEM',
    message = formatted_message,
    data = nil,
    expanded = false,
  }
  
  if count < max_entries then
    count = count + 1
    buffer[count] = entry
  else
    buffer[start_index] = entry
    start_index = (start_index % max_entries) + 1
  end
end

function M.info(category, message, ...)
  add_entry('INFO', category, message, ...)
end

function M.debug(category, message, ...)
  add_entry('DEBUG', category, message, ...)
end

function M.warn(category, message, ...)
  add_entry('WARN', category, message, ...)
end

function M.error(category, message, ...)
  add_entry('ERROR', category, message, ...)
end

function M.profile(category, duration_ms)
  add_entry('PROFILE', category, string.format('%.2fms', duration_ms))
end

function M.Clear()
  buffer = {}
  start_index = 1
  count = 0
end

function M.get_entries()
  local result = {}
  if count < max_entries then
    -- Buffer not full yet - entries are at indices 1..count in order
    for i = 1, count do
      result[i] = buffer[i]
    end
  else
    -- Buffer is full and wrapping - oldest entry is at start_index
    local j = 1
    for i = start_index, max_entries do
      result[j] = buffer[i]
      j = j + 1
    end
    for i = 1, start_index - 1 do
      result[j] = buffer[i]
      j = j + 1
    end
  end
  return result
end

function M.get_count()
  return count
end

function M.get_max()
  return max_entries
end

function M.set_max(max)
  max_entries = math.max(100, math.min(10000, max))
end

-- ============================================================================
-- LIVE SLOTS - High-frequency updating logs
-- ============================================================================

--- Create or update a live log slot
--- @param category string Category name (e.g., 'TRANSPORT')
--- @param key string Unique key within category (e.g., 'position')
--- @param message string Message with optional format specifiers
--- @param ... any Format arguments
function M.live(category, key, message, ...)
  local slot_key = category .. ':' .. key
  local formatted = select('#', ...) > 0 and string.format(message, ...) or message
  local now = reaper.time_precise()

  local slot = live_slots[slot_key]
  if not slot then
    -- Create new slot
    slot = {
      category = category,
      key = key,
      message = formatted,
      created = now,
      last_update = now,
      update_count = 1,
      history = {},
      expanded = false,
    }
    live_slots[slot_key] = slot
    live_slot_count = live_slot_count + 1
    live_slot_version = live_slot_version + 1
  else
    -- Add current message to history before updating
    table.insert(slot.history, 1, {
      time = slot.last_update,
      message = slot.message,
    })

    -- Trim history to max size (bulk removal)
    local excess = #slot.history - LIVE_HISTORY_MAX
    if excess > 0 then
      for i = LIVE_HISTORY_MAX + 1, #slot.history do
        slot.history[i] = nil
      end
    end

    -- Update slot
    slot.message = formatted
    slot.last_update = now
    slot.update_count = slot.update_count + 1
    live_slot_version = live_slot_version + 1
  end
end

--- Get all live slots
--- @return table slots Table of slot_key -> slot data
function M.get_live_slots()
  return live_slots
end

--- Get a specific live slot
--- @param category string Category name
--- @param key string Slot key
--- @return table|nil slot The slot data or nil
function M.get_live_slot(category, key)
  return live_slots[category .. ':' .. key]
end

--- Clear a specific live slot
--- @param category string Category name
--- @param key string Slot key
function M.clear_live_slot(category, key)
  local slot_key = category .. ':' .. key
  if live_slots[slot_key] then
    live_slots[slot_key] = nil
    live_slot_count = live_slot_count - 1
    live_slot_version = live_slot_version + 1
  end
end

--- Clear all live slots
function M.clear_all_live()
  live_slots = {}
  live_slot_count = 0
  live_slot_version = live_slot_version + 1
end

--- Get count of active live slots
--- @return number count Number of live slots
function M.get_live_count()
  return live_slot_count
end

--- Get live slot version (for cache invalidation)
--- @return number version Increments on any live slot change
function M.get_live_version()
  return live_slot_version
end

--- Check if a slot is stale (no updates for LIVE_STALE_TIMEOUT)
--- @param category string Category name
--- @param key string Slot key
--- @return boolean stale True if slot is stale or doesn't exist
function M.is_live_stale(category, key)
  local slot = live_slots[category .. ':' .. key]
  if not slot then return true end
  return (reaper.time_precise() - slot.last_update) > LIVE_STALE_TIMEOUT
end

--- Remove all stale live slots
--- @return number removed Number of slots removed
function M.prune_stale_live()
  local now = reaper.time_precise()
  local removed = 0
  local to_remove = {}

  for slot_key, slot in pairs(live_slots) do
    if (now - slot.last_update) > LIVE_STALE_TIMEOUT then
      to_remove[#to_remove + 1] = slot_key
    end
  end

  for _, slot_key in ipairs(to_remove) do
    live_slots[slot_key] = nil
  end
  removed = #to_remove
  if removed > 0 then
    live_slot_count = live_slot_count - removed
    live_slot_version = live_slot_version + 1
  end

  return removed
end

--- Set the stale timeout for live slots
--- @param seconds number Timeout in seconds
function M.set_live_stale_timeout(seconds)
  LIVE_STALE_TIMEOUT = math.max(1.0, seconds)
end

--- Set the max history size for live slots
--- @param max number Maximum history entries per slot
function M.set_live_history_max(max)
  LIVE_HISTORY_MAX = math.max(10, math.min(500, max))
end

-- ============================================================================
-- CATEGORY LOGGER INSTANCES
-- ============================================================================

--- Create a logger instance bound to a specific category
--- Usage:
---   local log = Logger.new('MyCategory')
---   log:info('message')
---   log:debug('value: %d', 42)
---   log:warn('warning')
---   log:error('error occurred')
---
--- @param category string The category name for all logs from this instance
--- @return table logger Logger instance with :info, :debug, :warn, :error methods
function M.new(category)
  local instance = {}

  function instance:info(message, ...)
    M.info(category, message, ...)
  end

  function instance:debug(message, ...)
    M.debug(category, message, ...)
  end

  function instance:warn(message, ...)
    M.warn(category, message, ...)
  end

  function instance:error(message, ...)
    M.error(category, message, ...)
  end

  function instance:profile(duration_ms)
    M.profile(category, duration_ms)
  end

  function instance:live(key, message, ...)
    M.live(category, key, message, ...)
  end

  return instance
end

return M