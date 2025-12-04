-- @noindex
-- arkitekt/core/state_machine.lua
-- Generic finite state machine with event integration
--
-- A composable FSM that can optionally integrate with arkitekt.core.events.
-- Supports guards, context, history, and per-state lifecycle hooks.
--
-- Usage:
--   local StateMachine = require('arkitekt.core.state_machine')
--   local fsm = StateMachine.new({
--     initial = 'idle',
--     states = { idle = {}, playing = {}, paused = {} },
--     transitions = {
--       idle = { play = 'playing' },
--       playing = { pause = 'paused', stop = 'idle' },
--       paused = { play = 'playing', stop = 'idle' },
--     },
--   })
--
--   fsm:send('play')  -- idle → playing
--   fsm:is('playing') -- true

local M = {}

-- =============================================================================
-- CONSTANTS
-- =============================================================================

local DEFAULT_MAX_HISTORY = 20

-- =============================================================================
-- PRIVATE FUNCTIONS
-- =============================================================================

--- Resolve a transition target (handles guards/functions)
--- @param target string|function|table Target state or guard function
--- @param context table State machine context
--- @param payload any Payload from send()
--- @return string|nil resolved_target Resolved target state or nil if guard fails
local function _resolve_target(target, context, payload)
  if type(target) == 'function' then
    -- Guard function: returns target state or nil to block
    return target(context, payload)
  elseif type(target) == 'table' then
    -- Table with guard: { target = 'state', guard = fn }
    if target.guard then
      local allowed = target.guard(context, payload)
      if not allowed then
        return nil
      end
    end
    return target.target
  else
    -- Simple string target
    return target
  end
end

--- Record a transition in history
--- @param history table History array
--- @param max_history number Maximum history entries
--- @param from string Previous state
--- @param to string New state
--- @param action string Action that triggered transition
local function _record_history(history, max_history, from, to, action)
  table.insert(history, 1, {
    from = from,
    to = to,
    action = action,
    timestamp = os.clock(),
  })

  -- Trim history to max size
  while #history > max_history do
    table.remove(history)
  end
end

-- =============================================================================
-- PUBLIC API
-- =============================================================================

--- Create a new state machine
--- @param config table Configuration options
--- @param config.initial string Initial state (required)
--- @param config.states table State definitions with lifecycle hooks
--- @param config.transitions table Transition definitions { from_state = { action = to_state } }
--- @param config.context table Arbitrary data carried through transitions
--- @param config.events table Optional arkitekt.core.events bus for auto-emit
--- @param config.max_history number Max history entries (default 20)
--- @param config.on_transition function Global transition callback(from, to, action, payload)
--- @return table fsm State machine instance
function M.new(config)
  config = config or {}

  if not config.initial then
    error('StateMachine requires \'initial\' state')
  end

  local fsm = {
    -- Current state
    state = config.initial,

    -- State definitions: { state_name = { on_enter, on_exit, on_update } }
    states = config.states or {},

    -- Transition map: { from_state = { action = to_state | guard_fn | {target, guard} } }
    transitions = config.transitions or {},

    -- Arbitrary context data
    context = config.context or {},

    -- Optional event bus integration
    events = config.events,

    -- Global transition callback
    on_transition = config.on_transition,

    -- History tracking
    _history = {},
    _max_history = config.max_history or DEFAULT_MAX_HISTORY,
  }

  -- >>> PUBLIC METHODS (BEGIN)

  --- Check if an action is valid from current state
  --- @param action string Action to check
  --- @return boolean can_transition True if action is valid
  function fsm:can(action)
    local from_transitions = self.transitions[self.state]
    if not from_transitions then
      return false
    end
    return from_transitions[action] ~= nil
  end

  --- Get all valid actions from current state
  --- @return string[] actions Array of valid action names
  function fsm:available_actions()
    local from_transitions = self.transitions[self.state]
    if not from_transitions then
      return {}
    end

    local actions = {}
    for action in pairs(from_transitions) do
      actions[#actions + 1] = action
    end
    return actions
  end

  --- Send an action to trigger a state transition
  --- @param action string Action to send
  --- @param payload any Optional payload passed to hooks and guards
  --- @return boolean success True if transition occurred
  --- @return string|nil error Error message if transition failed
  function fsm:send(action, payload)
    local from_transitions = self.transitions[self.state]
    if not from_transitions then
      return false, string.format('No transitions defined for state \'%s\'', self.state)
    end

    local target_def = from_transitions[action]
    if not target_def then
      return false, string.format('No transition \'%s\' from state \'%s\'', action, self.state)
    end

    -- Resolve target (handles guards)
    local target = _resolve_target(target_def, self.context, payload)
    if not target then
      return false, string.format('Guard blocked transition \'%s\' from \'%s\'', action, self.state)
    end

    -- Validate target state exists (if states are defined)
    if next(self.states) and not self.states[target] then
      return false, string.format('Target state \'%s\' not defined', target)
    end

    local prev_state = self.state
    local state_def = self.states[prev_state]

    -- Exit current state
    if state_def and state_def.on_exit then
      local ok, err = xpcall(state_def.on_exit, debug.traceback, self.context, action, target, payload)
      if not ok then
        return false, string.format('on_exit error:\n%s', err)
      end
    end

    -- Transition
    self.state = target

    -- Record history
    _record_history(self._history, self._max_history, prev_state, target, action)

    -- Enter new state
    local new_state_def = self.states[target]
    if new_state_def and new_state_def.on_enter then
      local ok, err = xpcall(new_state_def.on_enter, debug.traceback, self.context, action, prev_state, payload)
      if not ok then
        -- State already changed, log error but don't revert
        local Logger = package.loaded['arkitekt.debug.logger']
        if Logger then
          Logger.error('FSM', 'on_enter error for state \'%s\':\n%s', target, err)
        end
      end
    end

    -- Global transition callback
    if self.on_transition then
      xpcall(self.on_transition, debug.traceback, prev_state, target, action, payload)
    end

    -- Emit event if bus connected
    if self.events then
      self.events:emit('state.changed', {
        from = prev_state,
        to = target,
        action = action,
        payload = payload,
      })
    end

    return true
  end

  --- Force transition to a state (bypasses guards and transitions)
  --- Use sparingly - mainly for initialization or error recovery
  --- @param target string Target state
  --- @param payload any Optional payload for hooks
  --- @return boolean success
  function fsm:force(target, payload)
    local prev_state = self.state
    local state_def = self.states[prev_state]

    -- Exit current state
    if state_def and state_def.on_exit then
      local ok, err = xpcall(state_def.on_exit, debug.traceback, self.context, '_force', target, payload)
      if not ok then
        local Logger = package.loaded['arkitekt.debug.logger']
        if Logger then
          Logger.error('FSM', 'on_exit error for state \'%s\' (force):\n%s', prev_state, err)
        end
      end
    end

    -- Transition
    self.state = target

    -- Record history
    _record_history(self._history, self._max_history, prev_state, target, '_force')

    -- Enter new state
    local new_state_def = self.states[target]
    if new_state_def and new_state_def.on_enter then
      local ok, err = xpcall(new_state_def.on_enter, debug.traceback, self.context, '_force', prev_state, payload)
      if not ok then
        local Logger = package.loaded['arkitekt.debug.logger']
        if Logger then
          Logger.error('FSM', 'on_enter error for state \'%s\' (force):\n%s', target, err)
        end
      end
    end

    return true
  end

  --- Update current state (call per-frame for states with on_update)
  --- @param dt number Delta time since last update
  function fsm:update(dt)
    local state_def = self.states[self.state]
    if state_def and state_def.on_update then
      state_def.on_update(self.context, dt)
    end
  end

  --- Check if in specific state(s)
  --- @param ... string State names to check
  --- @return boolean is_match True if current state matches any argument
  function fsm:is(...)
    for _, s in ipairs({...}) do
      if self.state == s then
        return true
      end
    end
    return false
  end

  --- Check if NOT in specific state(s)
  --- @param ... string State names to check
  --- @return boolean is_not True if current state doesn't match any argument
  function fsm:is_not(...)
    return not self:is(...)
  end

  --- Get current state name
  --- @return string state Current state
  function fsm:get_state()
    return self.state
  end

  --- Get transition history
  --- @param count number|nil Max entries to return (default all)
  --- @return table[] history Array of { from, to, action, timestamp }
  function fsm:get_history(count)
    count = count or #self._history
    local result = {}
    for i = 1, math.min(count, #self._history) do
      result[i] = self._history[i]
    end
    return result
  end

  --- Get the previous state (from history)
  --- @return string|nil prev_state Previous state or nil if no history
  function fsm:get_previous_state()
    if #self._history > 0 then
      return self._history[1].from
    end
    return nil
  end

  --- Clear transition history
  function fsm:clear_history()
    self._history = {}
  end

  --- Connect an event bus for auto-emit on transitions
  --- @param events table arkitekt.core.events bus instance
  function fsm:connect_events(events)
    self.events = events
  end

  --- Disconnect event bus
  function fsm:disconnect_events()
    self.events = nil
  end

  --- Get a snapshot of current FSM state (for debugging/serialization)
  --- @return table snapshot { state, context, history_length }
  function fsm:snapshot()
    return {
      state = self.state,
      context = self.context,
      history_length = #self._history,
      available_actions = self:available_actions(),
    }
  end

  -- <<< PUBLIC METHODS (END)

  return fsm
end

--- Create a simple state machine from a transition table
--- Shorthand for common use case without lifecycle hooks
--- @param initial string Initial state
--- @param transitions table Transition map
--- @return table fsm State machine instance
function M.simple(initial, transitions)
  return M.new({
    initial = initial,
    transitions = transitions,
  })
end

return M
