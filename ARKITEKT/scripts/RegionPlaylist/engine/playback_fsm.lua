-- @noindex
-- engine/playback_fsm.lua
-- Explicit playback state machine using arkitekt.core.state_machine
--
-- States:
--   idle         - Not playing, at playlist start
--   playing      - Actively playing a region
--   paused       - Paused mid-playback (can resume)
--   transitioning - Seeking between regions
--
-- This FSM replaces the scattered boolean flags (is_playing, is_paused)
-- with explicit state management and transitions.

local StateMachine = require("arkitekt.core.state_machine")
local Logger = require("arkitekt.debug.logger")

local M = {}

-- =============================================================================
-- STATE DEFINITIONS
-- =============================================================================

local STATES = {
  IDLE = "idle",
  PLAYING = "playing",
  PAUSED = "paused",
  TRANSITIONING = "transitioning",
}

M.STATES = STATES

-- =============================================================================
-- FACTORY
-- =============================================================================

--- Create a new playback state machine
--- @param opts table Optional configuration
--- @param opts.events table Optional event bus for auto-emit on transitions
--- @param opts.debug boolean Enable debug logging (default false)
--- @return table fsm State machine instance
function M.new(opts)
  opts = opts or {}
  local debug = opts.debug or false

  local fsm = StateMachine.new({
    initial = STATES.IDLE,

    -- Context carries playback-related data
    context = {
      -- Current playlist position
      pointer = 1,
      -- Position when paused (for resume)
      pause_position = nil,
      -- Length of current sequence (for guard)
      sequence_length = 0,
      -- Region ID being played
      current_rid = nil,
      -- Transition target index
      transition_target = nil,
    },

    states = {
      -- IDLE: Not playing, at playlist start
      [STATES.IDLE] = {
        on_enter = function(ctx, action, from)
          ctx.pointer = 1
          ctx.pause_position = nil
          ctx.current_rid = nil
          ctx.transition_target = nil
          if debug then
            Logger.info("PLAYBACK_FSM", "Entered IDLE (from %s via %s)", tostring(from), tostring(action))
          end
        end,
      },

      -- PLAYING: Actively playing
      [STATES.PLAYING] = {
        on_enter = function(ctx, action, from)
          ctx.pause_position = nil  -- Clear pause position when playing
          if debug then
            if from == STATES.PAUSED then
              Logger.info("PLAYBACK_FSM", "RESUMED from pause")
            elseif from == STATES.TRANSITIONING then
              Logger.info("PLAYBACK_FSM", "Transition complete, now playing")
            else
              Logger.info("PLAYBACK_FSM", "Started playing (from %s)", tostring(from))
            end
          end
        end,
      },

      -- PAUSED: Paused mid-playback
      [STATES.PAUSED] = {
        on_enter = function(ctx, action, from)
          -- Pause position should be set by transport before sending pause action
          if debug then
            Logger.info("PLAYBACK_FSM", "PAUSED at position %.2fs", ctx.pause_position or -1)
          end
        end,
      },

      -- TRANSITIONING: Seeking between regions
      [STATES.TRANSITIONING] = {
        on_enter = function(ctx, action, from, payload)
          if payload and payload.target then
            ctx.transition_target = payload.target
          end
          if debug then
            Logger.info("PLAYBACK_FSM", "TRANSITIONING to target %s", tostring(ctx.transition_target))
          end
        end,
      },
    },

    transitions = {
      -- From IDLE
      [STATES.IDLE] = {
        play = function(ctx)
          -- Guard: must have sequence to play
          if ctx.sequence_length > 0 then
            return STATES.PLAYING
          end
          Logger.warn("PLAYBACK_FSM", "Cannot play: empty sequence")
          return nil
        end,
      },

      -- From PLAYING
      [STATES.PLAYING] = {
        pause = STATES.PAUSED,
        stop = STATES.IDLE,
        transition = STATES.TRANSITIONING,
      },

      -- From PAUSED
      [STATES.PAUSED] = {
        play = STATES.PLAYING,  -- Resume
        stop = STATES.IDLE,
      },

      -- From TRANSITIONING
      [STATES.TRANSITIONING] = {
        complete = STATES.PLAYING,
        stop = STATES.IDLE,
      },
    },

    on_transition = function(from, to, action, payload)
      if debug then
        Logger.debug("PLAYBACK_FSM", "%s -[%s]-> %s", from, action, to)
      end
    end,

    events = opts.events,
  })

  -- =============================================================================
  -- CONVENIENCE METHODS
  -- =============================================================================

  --- Check if currently in a playback state (playing or transitioning)
  --- @return boolean is_active True if actively playing or transitioning
  function fsm:is_active()
    return self:is(STATES.PLAYING, STATES.TRANSITIONING)
  end

  --- Check if playback can be resumed (either paused or idle with sequence)
  --- @return boolean can_resume
  function fsm:can_resume()
    if self:is(STATES.PAUSED) then
      return true
    end
    if self:is(STATES.IDLE) and self.context.sequence_length > 0 then
      return true
    end
    return false
  end

  --- Update sequence length (affects play guard)
  --- @param length number Number of items in sequence
  function fsm:set_sequence_length(length)
    self.context.sequence_length = length
  end

  --- Set pause position before pausing
  --- @param position number Playback position in seconds
  function fsm:set_pause_position(position)
    self.context.pause_position = position
  end

  --- Get pause position (for resume)
  --- @return number|nil pause_position Position in seconds or nil if not paused
  function fsm:get_pause_position()
    return self.context.pause_position
  end

  --- Set current region ID
  --- @param rid number Region ID
  function fsm:set_current_rid(rid)
    self.context.current_rid = rid
  end

  --- Get current region ID
  --- @return number|nil rid Current region ID
  function fsm:get_current_rid()
    return self.context.current_rid
  end

  --- Update pointer position
  --- @param pointer number Playlist position (1-indexed)
  function fsm:set_pointer(pointer)
    self.context.pointer = pointer
  end

  --- Get pointer position
  --- @return number pointer Current playlist position
  function fsm:get_pointer()
    return self.context.pointer
  end

  return fsm
end

return M
