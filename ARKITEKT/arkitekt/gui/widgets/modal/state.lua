-- @noindex
-- arkitekt/gui/widgets/modal/state.lua
-- Modal state management (animation, open/close tracking)

local Base = require('arkitekt.gui.widgets.base')

local M = {}

-- Instance storage (strong tables with access tracking for cleanup)
local instances = Base.create_instance_registry()

-- ============================================================================
-- ALPHA TRACKER (easing-based fade animation)
-- ============================================================================

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

-- Simple easing functions
local Easing = {
  linear = function(t) return t end,
  smoothstep = function(t) return t * t * (3 - 2 * t) end,
  smootherstep = function(t) return t * t * t * (t * (t * 6 - 15) + 10) end,
}

local function create_alpha_tracker(fade_in_duration, fade_out_duration, curve_name)
  local tracker = {
    current = 0.0,
    target = 0.0,
    start_value = 0.0,
    fade_in_duration = fade_in_duration or 1.0,
    fade_out_duration = fade_out_duration or 0.5,
    curve_name = curve_name or 'smootherstep',
    elapsed = 0.0,
  }

  function tracker:set_target(t)
    self.target = clamp(t, 0.0, 1.0)
    self.start_value = self.current
    self.elapsed = 0.0
  end

  function tracker:update(dt)
    if math.abs(self.target - self.current) < 0.001 then
      self.current = self.target
      return
    end

    -- Use different duration for fade in vs fade out
    local duration = self.target > self.start_value and self.fade_in_duration or self.fade_out_duration

    self.elapsed = self.elapsed + dt
    local t = clamp(self.elapsed / duration, 0.0, 1.0)

    -- Apply easing
    local easing_fn = Easing[self.curve_name] or Easing.smootherstep
    local curved = easing_fn(t)

    -- Lerp from start to target
    self.current = self.start_value + (self.target - self.start_value) * curved

    if self.elapsed >= duration then
      self.current = self.target
    end
  end

  function tracker:value()
    return clamp(self.current, 0.0, 1.0)
  end

  function tracker:is_complete()
    return math.abs(self.target - self.current) < 0.001
  end

  function tracker:is_fully_open()
    return self.target == 1.0 and self:is_complete()
  end

  function tracker:is_fully_closed()
    return self.target == 0.0 and self:is_complete()
  end

  return tracker
end

-- ============================================================================
-- MODAL STATE CLASS
-- ============================================================================

local ModalState = {}
ModalState.__index = ModalState

function ModalState.new(id, config)
  local fade_in = config.animation and config.animation.fade_in_duration or 1.0
  local fade_out = config.animation and config.animation.fade_out_duration or 0.5
  local curve = config.animation and config.animation.fade_curve or 'smootherstep'

  local self = setmetatable({
    id = id,
    alpha = create_alpha_tracker(fade_in, fade_out, curve),
    close_button_alpha = 0.0,
    close_button_hovered = false,
    is_closing = false,
    wants_close = false,
    last_frame_time = nil,
  }, ModalState)

  return self
end

function ModalState:open()
  self.alpha:set_target(1.0)
  self.is_closing = false
  self.wants_close = false
end

function ModalState:close()
  self.alpha:set_target(0.0)
  self.is_closing = true
end

function ModalState:request_close()
  self.wants_close = true
end

function ModalState:update(dt)
  self.alpha:update(dt)
end

function ModalState:get_alpha()
  return self.alpha:value()
end

function ModalState:is_visible()
  return self.alpha:value() > 0.001
end

function ModalState:should_remove()
  return self.is_closing and self.alpha:is_fully_closed()
end

function ModalState:update_close_button(dt, is_near, is_hovered)
  self.close_button_hovered = is_hovered
  local target = is_near and 1.0 or 0.3
  self.close_button_alpha = self.close_button_alpha + (target - self.close_button_alpha) * (1.0 - math.exp(-10.0 * dt))
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Get or create modal state for an ID
--- @param id string Modal identifier
--- @param config table Modal configuration
--- @return table ModalState instance
function M.get(id, config)
  local state = instances._instances[id]

  if not state then
    state = ModalState.new(id, config)
    instances._instances[id] = state
    if instances._access_times then
      instances._access_times[id] = reaper.time_precise()
    end
  else
    if instances._access_times then
      instances._access_times[id] = reaper.time_precise()
    end
  end

  return state
end

--- Remove modal state (cleanup)
--- @param id string Modal identifier
function M.remove(id)
  instances._instances[id] = nil
  if instances._access_times then
    instances._access_times[id] = nil
  end
end

--- Check if a modal state exists
--- @param id string Modal identifier
--- @return boolean
function M.exists(id)
  return instances._instances[id] ~= nil
end

return M
