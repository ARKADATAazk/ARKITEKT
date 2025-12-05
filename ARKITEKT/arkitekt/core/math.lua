-- @noindex
-- Arkitekt/core/math.lua
-- Math utility functions

-- Performance: Localize math functions
local max = math.max
local min = math.min
local abs = math.abs

local M = {}

function M.lerp(a, b, t)
  t = math.max(0, math.min(1, t))
  return a + (b - a) * t
end

function M.clamp(value, min_val, max_val)
  if not value then return min_val or 0 end
  min_val = min_val or value
  max_val = max_val or value
  return math.max(min_val, math.min(max_val, value))
end

function M.remap(value, in_min, in_max, out_min, out_max)
  if in_max == in_min then
    return (out_min + out_max) * 0.5  -- Return midpoint to avoid divide-by-zero
  end
  return out_min + (value - in_min) * (out_max - out_min) / (in_max - in_min)
end

function M.Snap(value, step)
  if not step or step == 0 then return value end
  return (value / step + 0.5) // 1 * step
end

function M.smoothdamp(current, target, velocity, smoothtime, maxspeed, dt)
  -- Guard against zero/nil dt
  if not dt or dt <= 0 then
    return current, velocity or 0
  end

  smoothtime = math.max(0.0001, smoothtime or 0.1)
  maxspeed = maxspeed or math.huge
  velocity = velocity or 0

  local omega = 2.0 / smoothtime
  local x = omega * dt
  local exp = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
  local change = current - target
  local original_to = target

  local maxChange = maxspeed * smoothtime
  change = M.clamp(change, -maxChange, maxChange)
  target = current - change

  local temp = (velocity + omega * change) * dt
  velocity = (velocity - omega * temp) * exp
  local output = target + (change + temp) * exp

  if (original_to - current > 0.0) == (output > original_to) then
    output = original_to
    velocity = (output - original_to) / dt
  end

  return output, velocity
end

function M.approximately(a, b, epsilon)
  epsilon = epsilon or 0.0001
  return abs(a - b) < epsilon
end

return M