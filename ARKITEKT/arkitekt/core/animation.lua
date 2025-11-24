-- @noindex
-- arkitekt/core/animation.lua
-- Global animation configuration
-- Provides centralized control over animation speeds and behaviors

local M = {}

-- ============================================================================
-- ANIMATION SPEEDS
-- ============================================================================

-- Hover animations (used by buttons, widgets, etc.)
M.HOVER_SPEED = 12.0

-- Fade animations (used by overlays, tooltips, etc.)
M.FADE_SPEED = 8.0

-- Check/toggle animations (used by checkbox, radio button, etc.)
M.CHECK_SPEED = 15.0

-- Smooth scrolling and value changes
M.SMOOTH_SPEED = 10.0

-- ============================================================================
-- EASING
-- ============================================================================

-- Linear interpolation helper
function M.lerp(a, b, t)
  return a + (b - a) * t
end

-- Smooth step (ease in/out)
function M.smoothstep(t)
  return t * t * (3 - 2 * t)
end

-- ============================================================================
-- ANIMATION HELPERS
-- ============================================================================

--- Update a single animated value
--- @param current number Current value
--- @param target number Target value
--- @param dt number Delta time
--- @param speed number Animation speed
--- @return number Updated value
function M.animate_value(current, target, dt, speed)
  local new_value = current + (target - current) * speed * dt
  return math.max(0, math.min(1, new_value))
end

--- Update hover animation for a state field
--- @param state table Widget state
--- @param dt number Delta time
--- @param is_hovered boolean Current hover state
--- @param is_active boolean Current active/pressed state
--- @param field string Field name to animate
--- @param speed number Optional animation speed (defaults to HOVER_SPEED)
function M.update_hover(state, dt, is_hovered, is_active, field, speed)
  speed = speed or M.HOVER_SPEED
  local target = (is_hovered or is_active) and 1.0 or 0.0
  state[field] = M.animate_value(state[field], target, dt, speed)
end

return M
