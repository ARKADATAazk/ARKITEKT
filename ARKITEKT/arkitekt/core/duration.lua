-- @noindex
-- arkitekt/core/duration.lua
-- Duration formatting utilities for converting seconds to readable time strings

local M = {}

-- Ensure seconds is a valid non-negative number
local function sanitize(seconds)
  seconds = tonumber(seconds) or 0
  return seconds < 0 and 0 or seconds
end

--- Format seconds as H:MM:SS or M:SS
--- @param seconds number Duration in seconds (nil/negative treated as 0)
--- @return string Formatted duration string
function M.format_hms(seconds)
  seconds = sanitize(seconds)
  if seconds >= 3600 then
    local hours = (seconds / 3600) // 1
    local minutes = (seconds % 3600) // 60
    local secs = (seconds % 60) // 1
    return string.format('%d:%02d:%02d', hours, minutes, secs)
  else
    local minutes = (seconds / 60) // 1
    local secs = (seconds % 60) // 1
    return string.format('%d:%02d', minutes, secs)
  end
end

--- Format seconds as H:MM:SS:CC (with centiseconds) or MM:SS:CC
--- @param seconds number Duration in seconds (nil/negative treated as 0)
--- @return string Formatted duration string with centiseconds
function M.format_hms_centiseconds(seconds)
  seconds = sanitize(seconds)
  local hours = (seconds / 3600) // 1
  local mins = ((seconds % 3600) / 60) // 1
  local secs = (seconds % 60) // 1
  local cs = ((seconds % 1) * 100) // 1  -- centiseconds

  if hours > 0 then
    return string.format('%d:%02d:%02d:%02d', hours, mins, secs, cs)
  else
    return string.format('%02d:%02d:%02d', mins, secs, cs)
  end
end

--- Format seconds as MM:SS (always 2 digits for minutes)
--- @param seconds number Duration in seconds (nil/negative treated as 0)
--- @return string Formatted duration string
function M.format_mmss(seconds)
  seconds = sanitize(seconds)
  local minutes = (seconds / 60) // 1
  local secs = (seconds % 60) // 1
  return string.format('%02d:%02d', minutes, secs)
end

return M
