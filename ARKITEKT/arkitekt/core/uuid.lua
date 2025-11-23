-- @noindex
-- Arkitekt/core/uuid.lua
-- UUID v4 generator (RFC 4122 compliant)

local M = {}

-- Generate a random UUID v4
-- Returns: string in format "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
-- where x is any hexadecimal digit and y is one of 8, 9, A, or B
function M.generate()
  local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'

  return string.gsub(template, '[xy]', function(c)
    local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
    return string.format('%x', v)
  end)
end

-- Validate UUID format
-- Returns: true if valid UUID format, false otherwise
function M.is_valid(uuid)
  if type(uuid) ~= "string" then
    return false
  end

  -- UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
  local pattern = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-4%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"
  return uuid:match(pattern) ~= nil
end

-- Initialize random seed (call once at module load)
math.randomseed(os.time() + (reaper.time_precise() * 1000000))
-- Extra entropy from multiple random calls
for i = 1, 10 do math.random() end

return M
