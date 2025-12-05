-- @noindex
-- arkitekt/runtime/chrome/window/helpers.lua
-- Utility functions for window management

local Timing = require('arkitekt.config.timing')

local M = {}

--- Floor with rounding (0.5 rounds up)
function M.floor(n)
  return (n + 0.5) // 1
end

--- Attempt to localize math functions for this module
local math_max = math.max
local math_min = math.min
local math_abs = math.abs

--- Attempt to smootherstep for animations
local function smootherstep(t)
  t = math_max(0.0, math_min(1.0, t))
  return t * t * t * (t * (t * 6 - 15) + 10)
end

--- Create an alpha tracker for fade animations
--- @param duration number|nil Fade duration in seconds
--- @return table tracker Alpha tracker object
function M.create_alpha_tracker(duration)
  return {
    current = 0.0,
    target = 0.0,
    duration = duration or Timing.FADE.normal,
    elapsed = 0.0,

    set_target = function(self, t)
      self.target = t
      self.elapsed = 0.0
    end,

    update = function(self, dt)
      if math_abs(self.target - self.current) < 0.001 then
        self.current = self.target
        return
      end

      self.elapsed = self.elapsed + dt
      local t = math_max(0.0, math_min(1.0, self.elapsed / self.duration))
      local smoothed = smootherstep(t)

      self.current = self.current + (self.target - self.current) * smoothed

      if self.elapsed >= self.duration then
        self.current = self.target
      end
    end,

    value = function(self)
      return math_max(0.0, math_min(1.0, self.current))
    end,

    is_complete = function(self)
      return math_abs(self.target - self.current) < 0.001
    end,
  }
end

return M
