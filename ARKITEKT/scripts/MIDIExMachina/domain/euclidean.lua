-- @noindex
-- MIDIExMachina/domain/euclidean.lua
-- Bjorklund algorithm for Euclidean rhythm generation

local M = {}

--- Generate Euclidean rhythm pattern using Bjorklund algorithm
-- @param pulses number Number of pulses (hits) in the pattern
-- @param steps number Total number of steps
-- @param rotation number Optional rotation offset (default 0)
-- @return table Array of 1s (pulse) and 0s (rest)
function M.generate(pulses, steps, rotation)
  rotation = rotation or 0

  -- Validate inputs
  if pulses < 0 or steps < 1 or pulses > steps then
    return {}
  end

  -- Special cases
  if pulses == 0 then
    local pattern = {}
    for i = 1, steps do
      pattern[i] = 0
    end
    return pattern
  end

  if pulses == steps then
    local pattern = {}
    for i = 1, steps do
      pattern[i] = 1
    end
    return pattern
  end

  -- Bjorklund algorithm
  local pattern = {}
  local counts = {}
  local remainders = {}
  local divisor = steps - pulses
  remainders[1] = pulses
  local level = 0

  repeat
    counts[level] = math.floor(divisor / remainders[level])
    remainders[level + 1] = divisor % remainders[level]
    divisor = remainders[level]
    level = level + 1
  until remainders[level] <= 1

  counts[level] = divisor

  -- Build pattern
  local function build(level_idx)
    if level_idx == -1 then
      table.insert(pattern, 0)
    elseif level_idx == -2 then
      table.insert(pattern, 1)
    else
      for i = 1, counts[level_idx] do
        build(level_idx - 1)
      end
      if remainders[level_idx] ~= 0 then
        build(level_idx - 2)
      end
    end
  end

  build(level)

  -- Apply rotation
  if rotation ~= 0 then
    rotation = rotation % steps
    local rotated = {}
    for i = 1, steps do
      local idx = ((i - 1 + rotation) % steps) + 1
      rotated[i] = pattern[idx]
    end
    pattern = rotated
  end

  return pattern
end

--- Get human-readable description of a Euclidean pattern
-- @param pulses number Number of pulses
-- @param steps number Total steps
-- @return string Description like "E(5,8)" or "E(3,8,2)" with rotation
function M.describe(pulses, steps, rotation)
  if rotation and rotation ~= 0 then
    return string.format("E(%d,%d,%d)", pulses, steps, rotation)
  else
    return string.format("E(%d,%d)", pulses, steps)
  end
end

--- Convert pattern to visual representation
-- @param pattern table Array of 1s and 0s
-- @return string Visual like "x..x..x." where x=pulse, .=rest
function M.visualize(pattern)
  local visual = {}
  for i, v in ipairs(pattern) do
    visual[i] = (v == 1) and "x" or "."
  end
  return table.concat(visual)
end

return M
