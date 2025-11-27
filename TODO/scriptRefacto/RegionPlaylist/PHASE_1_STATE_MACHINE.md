# Phase 1: Introduce Explicit State Machine

> Replace scattered boolean flags with arkitekt.core.state_machine

## Problem

Current playback state is tracked via scattered boolean flags:

```lua
-- engine/transport.lua:37-43
self.is_playing = false
self.is_paused = false
self._playlist_mode = false

-- engine/engine_state.lua:43-47
self.current_idx = -1
self.next_idx = -1
self.goto_region_queued = false
```

This leads to:
- Complex conditional logic (`if self.is_playing and not self.is_paused`)
- Defensive checks scattered throughout code
- Difficult to reason about valid state combinations
- No clear transitions or guards

## Solution

Introduce `arkitekt.core.state_machine` for playback state.

### Playback States

```
┌─────────┐
│  IDLE   │ ←─────────────────────────────┐
└────┬────┘                               │
     │ play                               │ stop
     ▼                                    │
┌─────────┐    pause    ┌─────────┐       │
│ PLAYING │ ──────────► │ PAUSED  │ ──────┤
└────┬────┘             └────┬────┘       │
     │                       │            │
     │ transition            │ play       │
     ▼                       │            │
┌─────────────┐              │            │
│TRANSITIONING│──────────────┴────────────┘
└─────────────┘   complete
```

### State Definitions

| State | Description | Entry Action | Exit Action |
|-------|-------------|--------------|-------------|
| `idle` | Not playing, at playlist start | Reset pointer to 1 | - |
| `playing` | Actively playing | Start REAPER transport | - |
| `paused` | Paused mid-playback | Record pause position | - |
| `transitioning` | Seeking between regions | Queue GoToRegion | - |

### Valid Transitions

| From | Action | To | Guard |
|------|--------|-----|-------|
| `idle` | `play` | `playing` | Has sequence |
| `playing` | `pause` | `paused` | - |
| `playing` | `stop` | `idle` | - |
| `playing` | `transition` | `transitioning` | Near region end |
| `paused` | `play` | `playing` | - |
| `paused` | `stop` | `idle` | - |
| `transitioning` | `complete` | `playing` | - |
| `transitioning` | `stop` | `idle` | - |

## Implementation Plan

### Step 1: Create engine/playback_fsm.lua

```lua
-- engine/playback_fsm.lua
-- Playback state machine using arkitekt.core.state_machine

local StateMachine = require("arkitekt.core.state_machine")
local Logger = require("arkitekt.debug.logger")

local M = {}

function M.new(opts)
  opts = opts or {}

  return StateMachine.new({
    initial = "idle",

    context = {
      pointer = 1,
      pause_position = nil,
      sequence_length = 0,
    },

    states = {
      idle = {
        on_enter = function(ctx)
          ctx.pointer = 1
          ctx.pause_position = nil
          Logger.info("PLAYBACK_FSM", "Entered IDLE")
        end,
      },

      playing = {
        on_enter = function(ctx, action, from)
          if from == "paused" then
            Logger.info("PLAYBACK_FSM", "Resuming from pause")
          else
            Logger.info("PLAYBACK_FSM", "Starting playback")
          end
        end,
        on_update = function(ctx, dt)
          -- Per-frame playback logic can go here
        end,
      },

      paused = {
        on_enter = function(ctx)
          ctx.pause_position = reaper.GetPlayPositionEx(0)
          Logger.info("PLAYBACK_FSM", "Paused at %.2fs", ctx.pause_position)
        end,
      },

      transitioning = {
        on_enter = function(ctx)
          Logger.info("PLAYBACK_FSM", "Transitioning to next region")
        end,
      },
    },

    transitions = {
      idle = {
        play = function(ctx)
          -- Guard: must have sequence
          if ctx.sequence_length > 0 then
            return "playing"
          end
          Logger.warn("PLAYBACK_FSM", "Cannot play: empty sequence")
          return nil
        end,
      },

      playing = {
        pause = "paused",
        stop = "idle",
        transition = "transitioning",
      },

      paused = {
        play = "playing",
        stop = "idle",
      },

      transitioning = {
        complete = "playing",
        stop = "idle",
      },
    },

    on_transition = function(from, to, action)
      Logger.debug("PLAYBACK_FSM", "%s -[%s]-> %s", from, action, to)
    end,

    events = opts.events,  -- Optional event bus integration
  })
end

return M
```

### Step 2: Integrate into engine/transport.lua

Replace boolean flags with FSM queries:

```lua
-- BEFORE
function Transport:play()
  if self.is_playing then return end
  self.is_playing = true
  self.is_paused = false
  -- ...
end

-- AFTER
function Transport:play()
  if self.fsm:is("playing") then return end
  local ok = self.fsm:send("play")
  if not ok then return false end
  -- ...
end
```

### Step 3: Update check_stopped()

```lua
-- BEFORE (transport.lua:362-372)
function Transport:check_stopped()
  if not _is_playing(self.proj) then
    if self.is_playing and not self.is_paused then
      self.is_playing = false
      -- ...
    end
  end
end

-- AFTER
function Transport:check_stopped()
  if not _is_playing(self.proj) then
    if self.fsm:is("playing") then
      self.fsm:send("stop")
    end
  end
end
```

### Step 4: Update transitions.lua

Replace complex conditionals with state checks:

```lua
-- BEFORE (transitions.lua:43-44)
if not _is_playing(self.proj) then return end
if #self.state.playlist_order == 0 then return end

-- AFTER
if self.fsm:is_not("playing", "transitioning") then return end
```

## Files Changed

| File | Changes |
|------|---------|
| `engine/playback_fsm.lua` | **CREATE** - New FSM module |
| `engine/core.lua` | Add FSM to engine, pass to transport |
| `engine/transport.lua` | Replace boolean flags with FSM |
| `engine/transitions.lua` | Use FSM state checks |
| `engine/coordinator_bridge.lua` | Query FSM for is_playing |

## Backward Compatibility

Keep the old boolean accessors as computed properties during migration:

```lua
-- Computed property for backward compat
function Transport:get_is_playing()
  return self.fsm:is("playing", "transitioning")
end

-- Deprecation warning
function Transport:set_is_playing(value)
  Logger.warn("TRANSPORT", "Direct is_playing assignment deprecated, use FSM")
  if value then
    self.fsm:send("play")
  else
    self.fsm:send("stop")
  end
end
```

## Testing

After migration:

```lua
-- Test state transitions
local fsm = require("RegionPlaylist.engine.playback_fsm").new()

assert(fsm:is("idle"))
assert(fsm:can("play") == false)  -- Empty sequence guard

fsm.context.sequence_length = 5
assert(fsm:can("play") == true)

fsm:send("play")
assert(fsm:is("playing"))

fsm:send("pause")
assert(fsm:is("paused"))
assert(fsm.context.pause_position ~= nil)

fsm:send("stop")
assert(fsm:is("idle"))
assert(fsm.context.pointer == 1)  -- Reset on stop
```

## Checklist

- [ ] Create `engine/playback_fsm.lua`
- [ ] Add FSM to `engine/core.lua`
- [ ] Refactor `engine/transport.lua` to use FSM
- [ ] Refactor `engine/transitions.lua` to use FSM
- [ ] Update `coordinator_bridge.lua` FSM queries
- [ ] Add backward-compat computed properties
- [ ] Add unit tests for FSM transitions
- [ ] Remove deprecated boolean flags (after testing)
