# Testing & Verification Strategy

> How to verify each phase doesn't break anything

## Manual Test Checklist

Run these tests after each sub-phase:

### Core Playback Tests

- [ ] **Play from start**: Click play on empty playlist → nothing happens
- [ ] **Play with items**: Add regions, click play → plays first region
- [ ] **Pause/Resume**: Pause during playback → resumes from same position
- [ ] **Stop**: Stop during playback → resets to beginning
- [ ] **Next/Prev**: Navigate through playlist items
- [ ] **Loop playlist**: Enable loop, play to end → loops to start
- [ ] **Shuffle**: Enable shuffle → randomized order

### Transition Tests

- [ ] **Region-to-region**: Plays region A, transitions to region B
- [ ] **Same region repeat**: Region with reps=3 → plays 3 times
- [ ] **Nested playlist**: Playlist containing another playlist expands correctly
- [ ] **Transport override**: External play in region → playlist takes over

### UI State Tests

- [ ] **Tab switching**: Switch playlists, items update correctly
- [ ] **Tab switching during playback**: Doesn't interrupt current playback
- [ ] **Undo/Redo**: Add items, undo → items removed, redo → items back
- [ ] **Selection**: Multi-select with Shift/Ctrl works
- [ ] **Drag reorder**: Reorder items in active playlist
- [ ] **Pool to active**: Drag from pool adds to playlist

### Edge Cases

- [ ] **Empty playlist**: All operations graceful with no items
- [ ] **Deleted region**: Region deleted in REAPER → removed from playlist
- [ ] **Project switch**: Switch projects → reloads correct playlist data
- [ ] **Rapid clicks**: Spam play/stop/pause → no crashes

## Automated Tests

Location: `scripts/RegionPlaylist/tests/`

### Existing Tests

```bash
# Run domain tests (mock-based, no REAPER needed)
-- In REAPER console:
dofile("/path/to/RegionPlaylist/tests/domain_tests.lua")

# Run integration tests (requires REAPER project with regions)
dofile("/path/to/RegionPlaylist/tests/integration_tests.lua")
```

### New Tests to Add

#### Phase 1: StateMachine Tests

```lua
-- tests/engine/playback_fsm_test.lua

local function test_initial_state()
  local fsm = PlaybackFSM.new()
  assert(fsm:is("idle"), "Should start in idle state")
end

local function test_play_guard_empty_sequence()
  local fsm = PlaybackFSM.new()
  fsm.context.sequence_length = 0
  local ok = fsm:send("play")
  assert(not ok, "Should not play with empty sequence")
  assert(fsm:is("idle"), "Should remain in idle")
end

local function test_play_guard_with_sequence()
  local fsm = PlaybackFSM.new()
  fsm.context.sequence_length = 5
  local ok = fsm:send("play")
  assert(ok, "Should play with sequence")
  assert(fsm:is("playing"), "Should be in playing state")
end

local function test_pause_resume()
  local fsm = PlaybackFSM.new()
  fsm.context.sequence_length = 5
  fsm:send("play")
  fsm:send("pause")
  assert(fsm:is("paused"), "Should be paused")
  fsm:send("play")
  assert(fsm:is("playing"), "Should resume playing")
end

local function test_invalid_transition()
  local fsm = PlaybackFSM.new()
  local ok = fsm:send("pause")  -- Can't pause from idle
  assert(not ok, "Should reject invalid transition")
  assert(fsm:is("idle"), "Should remain in idle")
end

local function test_history_tracking()
  local fsm = PlaybackFSM.new()
  fsm.context.sequence_length = 5
  fsm:send("play")
  fsm:send("pause")
  fsm:send("stop")

  local history = fsm:get_history()
  assert(#history == 3, "Should have 3 transitions")
  assert(history[1].from == "paused" and history[1].to == "idle")
  assert(history[2].from == "playing" and history[2].to == "paused")
  assert(history[3].from == "idle" and history[3].to == "playing")
end
```

#### Phase 2: Event Tests

```lua
-- tests/app/events_test.lua

local function test_event_emission()
  local bus = Events.new()
  local received = nil

  bus:on("test.event", function(data)
    received = data
  end)

  bus:emit("test.event", { value = 42 })
  assert(received and received.value == 42)
end

local function test_multiple_listeners()
  local bus = Events.new()
  local count = 0

  bus:on("test.event", function() count = count + 1 end)
  bus:on("test.event", function() count = count + 1 end)

  bus:emit("test.event", {})
  assert(count == 2, "Both listeners should fire")
end

local function test_unsubscribe()
  local bus = Events.new()
  local count = 0

  local unsub = bus:on("test.event", function() count = count + 1 end)
  bus:emit("test.event", {})
  assert(count == 1)

  unsub()
  bus:emit("test.event", {})
  assert(count == 1, "Should not fire after unsubscribe")
end
```

## Regression Detection

### Before Starting Migration

1. Record current behavior for comparison:
   ```lua
   -- Create a test project with:
   -- - 5 regions
   -- - 2 playlists (one nested in the other)
   -- - Various repeat counts
   -- Save as "regression_test_project.rpp"
   ```

2. Document expected behavior:
   - Play order for each playlist
   - Transition timing
   - UI state after operations

### After Each Phase

1. Load regression test project
2. Run through manual test checklist
3. Compare behavior to documented expectations
4. Run automated tests

## Rollback Plan

### If Phase Breaks Something

1. **Identify the breaking commit**:
   ```bash
   git log --oneline -10
   git bisect start
   git bisect bad HEAD
   git bisect good <last-known-good-commit>
   ```

2. **Revert if needed**:
   ```bash
   git revert <breaking-commit>
   ```

3. **Keep backward-compat shims longer**:
   - Don't remove old code paths until fully verified
   - Use feature flags if needed

### Backward Compatibility Shim Pattern

```lua
-- OLD: transport.lua
self.is_playing = false

-- MIGRATION: Add FSM but keep old property
function Transport:get_is_playing()
  -- New: Query FSM
  if self.fsm then
    return self.fsm:is("playing", "transitioning")
  end
  -- Fallback: Old boolean (remove after verified)
  return self._legacy_is_playing
end

-- Allow gradual migration
function Transport:set_is_playing(value)
  Logger.warn("TRANSPORT", "DEPRECATED: Direct is_playing assignment")
  self._legacy_is_playing = value
  -- Also update FSM if present
  if self.fsm then
    if value then self.fsm:force("playing")
    else self.fsm:force("idle") end
  end
end
```

## CI/CD Integration (Future)

If automated testing is added:

```yaml
# .github/workflows/test.yml
test-regionplaylist:
  steps:
    - run: reaper -nosplash -nonewinst scripts/RegionPlaylist/tests/run_tests.lua
    - run: assert exit code 0
```
