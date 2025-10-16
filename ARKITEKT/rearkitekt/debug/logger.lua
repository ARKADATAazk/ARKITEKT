-- @noindex
-- rearkitekt/debug/logger.lua
-- Simple logging API for debug console

local M = {}

local buffer = {}
local max_entries = 1000
local start_index = 1
local count = 0

local function add_entry(level, category, message, data)
  local entry = {
    time = reaper.time_precise(),
    level = level,
    category = category or "SYSTEM",
    message = message or "",
    data = data,
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

function M.info(category, message, data)
  add_entry("INFO", category, message, data)
end

function M.debug(category, message, data)
  add_entry("DEBUG", category, message, data)
end

function M.warn(category, message, data)
  add_entry("WARN", category, message, data)
end

function M.error(category, message, data)
  add_entry("ERROR", category, message, data)
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

return M