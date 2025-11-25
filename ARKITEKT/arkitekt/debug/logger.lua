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
local LIVE_HISTORY_MAX = 50
local LIVE_STALE_TIMEOUT = 10.0  -- Seconds before slot is considered stale

local function add_entry(level, category, message, ...)
  -- Format message with varargs if provided
  local formatted_message = message or ""
  if select('#', ...) > 0 then
    formatted_message = string.format(message, ...)
  end
  
  local entry = {
    time = reaper.time_precise(),
    level = level,
    category = category or "SYSTEM",
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
  add_entry("INFO", category, message, ...)
end

function M.debug(category, message, ...)
  add_entry("DEBUG", category, message, ...)
end

function M.warn(category, message, ...)
  add_entry("WARN", category, message, ...)
end

function M.error(category, message, ...)
  add_entry("ERROR", category, message, ...)
end

function M.profile(category, duration_ms)
  add_entry("PROFILE", category, string.format("%.2fms", duration_ms))
end

function M.clear()
  buffer = {}
  start_index = 1
  count = 0
end

function M.get_entries()
  local result = {}
  for i = 1, count do
    local idx = ((start_index + i - 2) % max_entries) + 1
    if buffer[idx] then
      table.insert(result, buffer[idx])
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
--- @param category string Category name (e.g., "TRANSPORT")
--- @param key string Unique key within category (e.g., "position")
--- @param message string Message with optional format specifiers
--- @param ... any Format arguments
function M.live(category, key, message, ...)
  local slot_key = category .. ":" .. key
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
  else
    -- Add current message to history before updating
    table.insert(slot.history, 1, {
      time = slot.last_update,
      message = slot.message,
    })

    -- Trim history to max size
    while #slot.history > LIVE_HISTORY_MAX do
      table.remove(slot.history)
    end

    -- Update slot
    slot.message = formatted
    slot.last_update = now
    slot.update_count = slot.update_count + 1
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
  return live_slots[category .. ":" .. key]
end

--- Clear a specific live slot
--- @param category string Category name
--- @param key string Slot key
function M.clear_live_slot(category, key)
  live_slots[category .. ":" .. key] = nil
end

--- Clear all live slots
function M.clear_all_live()
  live_slots = {}
end

--- Get count of active live slots
--- @return number count Number of live slots
function M.get_live_count()
  local n = 0
  for _ in pairs(live_slots) do n = n + 1 end
  return n
end

--- Check if a slot is stale (no updates for LIVE_STALE_TIMEOUT)
--- @param category string Category name
--- @param key string Slot key
--- @return boolean stale True if slot is stale or doesn't exist
function M.is_live_stale(category, key)
  local slot = live_slots[category .. ":" .. key]
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
    removed = removed + 1
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

return M