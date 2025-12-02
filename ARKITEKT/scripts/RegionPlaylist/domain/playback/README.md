# Playback Engine

> Sequence-driven playback engine for region playlists

The playback engine manages sequential region playback with looping, transitions, quantization, and shuffle. It consumes flat sequences from the bridge and coordinates with REAPER's transport.

---

## Architecture

```
domain/playback/
├── controller.lua      → Main engine coordinator (239 lines)
│   - Orchestrates state, transport, transitions, quantize
│   - Delegates to specialized modules
│   - Public API for play/stop/seek
│
├── state.lua          → Engine state machine (480 lines)
│   - Sequence management
│   - Current/next region tracking
│   - Shuffle logic (true shuffle + random mode)
│   - Region cache
│
├── transport.lua      → Transport operations (285 lines)
│   - Play/stop/seek coordination with REAPER
│   - Loop playlist mode
│   - Viewport following
│   - Playhead following
│
├── transitions.lua    → Region boundary detection (218 lines)
│   - Per-frame playback position monitoring
│   - Region crossing detection
│   - Repeat cycle callbacks
│
├── quantize.lua       → Beat quantization (140 lines)
│   - Measure/beat/project-time snap
│   - Lookahead calculation
│
├── loop.lua           → Loop boundary utilities (105 lines)
│   - Loop start/end detection
│   - Region boundary helpers
│
└── expander.lua       → Sequence expansion (240 lines)
    - Flattens nested playlists
    - Circular reference detection
    - Repeat multiplication
```

---

## Engine Flow

### Startup/Initialization

```
1. Bridge.new() creates Engine via Controller.new(opts)
   ↓
2. Controller creates submodules:
   - State (sequence, region cache, pointer)
   - Transport (play/stop/seek)
   - Transitions (boundary detection)
   - Quantize (beat alignment)
   ↓
3. State.new() rescans project regions
   ↓
4. Engine ready, waiting for sequence
```

### Sequence Loading

```
1. UI edits playlist (add/remove/reorder)
   ↓
2. Controller commits → bridge.invalidate_sequence()
   ↓
3. Bridge sets sequence_stale = true
   ↓
4. User clicks Play
   ↓
5. Bridge.play() checks sequence_stale
   ↓
6. If stale: Expander.expand(playlists) → flat sequence
   ↓
7. Bridge calls engine:load_sequence(sequence)
   ↓
8. State stores sequence, builds lookup tables
   ↓
9. State updates playlist_pointer (current position in sequence)
```

### Playback Loop (Per Frame)

```
1. Main loop calls engine:update(dt)
   ↓
2. Transitions:advance() checks play position
   ↓
3. If crossed region boundary:
   ↓ a. Detect which boundary (start, loop end, region end)
   ↓ b. Update current_idx, next_idx pointers
   ↓ c. Trigger repeat_cycle callback if looping
   ↓ d. Seek to next region start
   ↓
4. If reached end of sequence:
   ↓ a. If loop_playlist: restart from beginning
   ↓ b. Else: stop playback
   ↓
5. Transport:update() handles viewport following
```

---

## State Machine

### States

The engine doesn't have explicit state enums but operates on pointers and bounds:

| Condition | Meaning |
|-----------|---------|
| `current_idx == -1` | No active region (stopped or before first region) |
| `current_idx >= 0` | Playing region at sequence[current_idx] |
| `next_idx == -1` | No next region (last in sequence) |
| `next_idx >= 0` | Next region queued at sequence[next_idx] |
| `goto_region_queued` | Seek pending (will jump on next boundary) |

### Key Fields

**state.lua:**
```lua
{
  -- Sequence data
  sequence = {
    {rid = 1, item_key = "abc", loop = 1, total_loops = 2},
    {rid = 1, item_key = "abc", loop = 2, total_loops = 2},
    {rid = 2, item_key = "def", loop = 1, total_loops = 1},
  },
  sequence_lookup_by_key = { abc = {1, 2}, def = {3} },

  -- Pointers
  current_idx = 1,  -- Currently playing sequence[1]
  next_idx = 2,     -- Will play sequence[2] next

  -- Region bounds (cached)
  current_bounds = {start_pos = 0.0, end_pos = 4.5},
  next_bounds = {start_pos = 4.5, end_pos = 9.0},

  -- Playlist tracking
  playlist_pointer = 1,  -- Position in original playlist (before shuffle)

  -- Shuffle state
  _shuffle_enabled = false,
  _shuffle_mode = "true_shuffle",  -- or "random"
  _shuffle_seed = 12345,
  _last_random_index = nil,

  -- Region cache
  region_cache = {
    [1] = {rid = 1, start_pos = 0.0, end_pos = 4.5, ...},
    [2] = {rid = 2, start_pos = 4.5, end_pos = 9.0, ...},
  },
}
```

---

## Sequence Format

### Flat Sequence Structure

After expansion by `expander.lua`, the sequence is a flat array:

```lua
sequence = {
  {
    rid = 1,              -- REAPER region ID
    item_key = "abc-123", -- Unique UI key (for animations)
    loop = 1,             -- Current loop number (1-based)
    total_loops = 3,      -- Total loops for this region
  },
  {
    rid = 1,              -- Same region, loop 2
    item_key = "abc-123",
    loop = 2,
    total_loops = 3,
  },
  {
    rid = 1,              -- Same region, loop 3
    item_key = "abc-123",
    loop = 3,
    total_loops = 3,
  },
  {
    rid = 2,              -- Next region
    item_key = "def-456",
    loop = 1,
    total_loops = 1,
  },
}
```

### Lookup Table

`sequence_lookup_by_key` maps item keys to sequence indices:

```lua
sequence_lookup_by_key = {
  ["abc-123"] = {1, 2, 3},  -- Indices 1, 2, 3
  ["def-456"] = {4},        -- Index 4
}
```

Used for:
- Highlighting current tile in UI
- Seeking to specific item
- Finding all repeats of a region

---

## Boundary Detection

### Loop Detection (loop.lua)

Determines if play position crossed a region boundary:

```lua
function Playback.has_crossed_loop_boundary(last_pos, current_pos, loop_start, loop_end)
  -- Handles forward play, REAPER loop wrapping, transport jitter
  if current_pos >= loop_end then
    return true  -- Crossed end
  end

  if last_pos > current_pos and current_pos < loop_start then
    return true  -- Wrapped around (REAPER loop active)
  end

  return false
end
```

**Edge cases handled:**
- REAPER loop wrapping (playpos jumps backward)
- Transport jitter (playpos slightly beyond boundary)
- Paused playback (no crossing)

### Transition Detection (transitions.lua)

Per-frame monitoring in `advance()`:

```lua
function Transitions:advance()
  local playpos = reaper.GetPlayPosition()

  -- Skip if not actually playing
  if not Transport.is_playing() then return end

  local last_playpos = self.state.last_play_pos
  self.state.last_play_pos = playpos

  -- Get current region bounds
  local current = self.state:get_current_entry()
  if not current then return end

  local region = self.state.region_cache[current.rid]
  local loop_start = region.start_pos
  local loop_end = region.end_pos

  -- Check for boundary crossing
  if has_crossed_loop_boundary(last_playpos, playpos, loop_start, loop_end) then
    -- Handle crossing (increment loop, seek to next region, etc.)
    self:handle_boundary_cross(current)
  end
end
```

---

## Quantization

### Modes

**Measure:**
```lua
-- Snap to next measure boundary
local next_measure = calculate_next_measure(playpos, tempo, time_sig)
transport:seek(next_measure)
```

**Beat:**
```lua
-- Snap to next beat
local next_beat = calculate_next_beat(playpos, tempo)
transport:seek(next_beat)
```

**Project Time:**
```lua
-- Play immediately (no quantization)
transport:play()
```

### Lookahead

Quantize module provides lookahead time for UI feedback:

```lua
function Quantize:get_lookahead_time()
  if self.quantize_mode == "measure" then
    return time_until_next_measure()
  elseif self.quantize_mode == "beat" then
    return time_until_next_beat()
  else
    return 0  -- Immediate
  end
end
```

Used by UI to show "Starting in X beats" countdown.

---

## Shuffle Modes

### True Shuffle

- Fisher-Yates shuffle with fixed seed
- Deterministic (same seed = same order)
- No consecutive repeats of same item

```lua
function State:shuffle_sequence()
  local shuffled = {}
  local available = {}

  -- Build available pool (exclude first if same as last)
  for i, entry in ipairs(self.sequence) do
    if not (i == 1 and self._last_index and entry.rid == self.sequence[self._last_index].rid) then
      available[#available + 1] = entry
    end
  end

  -- Fisher-Yates shuffle
  for i = #available, 2, -1 do
    local j = random(1, i)
    available[i], available[j] = available[j], available[i]
  end

  self.sequence = available
end
```

### Random Mode

- Truly random selection each time
- Avoids consecutive repeats
- Non-deterministic

```lua
function State:next_random_index()
  if #self.sequence == 1 then
    return 1
  end

  -- Pick random index, avoiding last
  local idx
  repeat
    idx = random(1, #self.sequence)
  until idx ~= self._last_random_index

  self._last_random_index = idx
  return idx
end
```

---

## Transport Coordination

### Follow Modes

**Follow Playhead (default on):**
- Engine follows REAPER transport
- If user manually seeks, engine detects and updates

**Follow Viewport:**
- REAPER viewport scrolls to follow current region
- Smooth scrolling (set_scroll with smooth=true)

**Loop Playlist:**
- When sequence ends, restart from beginning
- Infinite playback loop

### Transport Override

Engine can override REAPER transport for testing:

```lua
-- Test transport (for unit tests)
local test_transport = {
  is_playing = function() return mock_playing end,
  get_play_position = function() return mock_position end,
  play = function() mock_playing = true end,
  stop = function() mock_playing = false end,
}

local engine = Engine.new({
  transport_override = test_transport,
})
```

---

## Module Responsibilities

### Controller (coordinator)

**Role:** Main API facade. Delegates to submodules.

**Methods:**
- `play()` - Start playback (with quantization)
- `stop()` - Stop playback
- `stop_immediate()` - Stop without transition
- `update(dt)` - Per-frame update
- `load_sequence(sequence)` - Set playback sequence
- `seek_to_item(key)` - Seek to specific item
- `get_current_key()` - Get currently playing item key
- `toggle_shuffle()` - Toggle shuffle on/off
- `next_shuffle_mode()` - Cycle shuffle mode

### State (state machine)

**Role:** Sequence management, pointer tracking, shuffle.

**Methods:**
- `load_sequence(sequence)` - Store and index sequence
- `get_current_entry()` - Get current sequence entry
- `get_next_entry()` - Get next sequence entry
- `advance_to_next()` - Increment pointer to next region
- `seek_to_item_key(key)` - Seek to item by key
- `shuffle_sequence()` - Shuffle sequence (true shuffle)
- `next_random_index()` - Get next random index (random mode)
- `rescan()` - Refresh region cache from project

### Transport (REAPER coordination)

**Role:** Play/stop/seek operations.

**Methods:**
- `play()` - Start REAPER transport
- `stop()` - Stop REAPER transport
- `seek(position)` - Seek to time position
- `update()` - Per-frame viewport following

### Transitions (boundary detection)

**Role:** Monitor playback position, detect crossings.

**Methods:**
- `advance()` - Per-frame boundary check
- `handle_boundary_cross(entry)` - Process crossing (internal)

### Quantize (beat alignment)

**Role:** Calculate quantized start times.

**Methods:**
- `get_lookahead_time()` - Time until next quantize point
- `set_quantize_mode(mode)` - Set quantization mode
- `quantize_play()` - Start playback at next quantize point

### Loop (utilities)

**Role:** Low-level boundary detection math.

**Methods:**
- `has_crossed_loop_boundary(last, current, start, end)` - Detect crossing
- Static helper functions

### Expander (sequence builder)

**Role:** Flatten nested playlists into linear sequence.

**Methods:**
- `expand(playlists, active_id, get_playlist_fn)` - Expand to flat sequence
- `detect_circular_reference(playlists, target_id, source_id)` - Check cycles

---

## Data Flow: Play Button Click

```
1. User clicks Play in transport bar
   ↓
2. TransportView calls bridge:play()
   ↓
3. Bridge checks if sequence_stale
   ↓
4. If stale:
   ↓ a. Bridge calls expander.expand(playlists)
   ↓ b. Get flat sequence
   ↓ c. Bridge calls engine:load_sequence(sequence)
   ↓ d. State stores and indexes sequence
   ↓
5. Bridge calls engine:play()
   ↓
6. Controller delegates to quantize:quantize_play()
   ↓
7. Quantize calculates next measure/beat
   ↓
8. Transport:play() at quantized time
   ↓
9. REAPER starts playback
   ↓
10. Per frame: GUI calls bridge:update()
    ↓
11. Bridge calls engine:update(dt)
    ↓
12. Transitions:advance() monitors playback
    ↓
13. When boundary crossed:
    ↓ a. Update pointers (current_idx, next_idx)
    ↓ b. Call on_repeat_cycle callback (UI update)
    ↓ c. Seek to next region
    ↓
14. UI polls bridge:get_current_key()
    ↓
15. Active grid highlights current tile
```

---

## Performance Optimizations

### Region Cache

- Regions scanned once at init, cached in `region_cache`
- Rescanned only when project state changes
- Indexed by rid for O(1) lookup

### Sequence Lookup Table

- `sequence_lookup_by_key` maps keys to indices
- O(1) lookup for current tile highlighting
- Built once when sequence loaded

### Math Localization

```lua
-- At module top
local max = math.max
local min = math.min
local floor = math.floor

-- In hot loop
local clamped = max(0, min(playpos, region_end))  -- Fast!
```

### Boundary Epsilon

```lua
self.boundary_epsilon = 0.01  -- 10ms tolerance

-- Handles REAPER timing jitter
if abs(playpos - boundary) < epsilon then
  -- Consider crossed
end
```

---

## Testing

### Unit Tests

```lua
-- Mock transport for deterministic testing
local test_transport = {
  is_playing = function() return true end,
  get_play_position = function() return mock_position end,
}

local engine = Engine.new({
  transport_override = test_transport,
})

-- Test sequence playback
engine:load_sequence(test_sequence)
engine:play()

-- Simulate time passing
mock_position = 5.0
engine:update(0.016)

-- Assert pointer advanced
assert(engine.state.current_idx == 2)
```

### Integration Tests

```lua
-- Full playback test with real REAPER regions
local regions = create_test_regions()
local sequence = expander.expand(test_playlists)
engine:load_sequence(sequence)
engine:play()

-- Wait for region boundary
wait_for_region_cross()

-- Verify callback fired
assert(on_repeat_cycle_called)
```

---

## Debugging

### Enable Debug Logging

```lua
-- state.lua
local DEBUG_SEQUENCE = true

-- Then check console for:
-- "STATE: Loaded sequence with 15 entries"
-- "STATE: Advanced pointer: 3 → 4"
```

### Check Engine State

```lua
-- REAPER Developer Console
local bridge = State.get_bridge()
local engine = bridge.engine

print("Current idx:", engine.state.current_idx)
print("Next idx:", engine.state.next_idx)
print("Sequence length:", #engine.state.sequence)
print("Shuffle enabled:", engine.state._shuffle_enabled)

-- Current region
local current = engine.state:get_current_entry()
if current then
  print("Playing RID:", current.rid, "Loop:", current.loop, "/", current.total_loops)
end
```

### Trace Transitions

```lua
-- transitions.lua
local DEBUG_TRANSITIONS = true

-- Console output:
-- "TRANSITION: Crossed boundary at 4.5s"
-- "TRANSITION: Loop 2/3 complete"
-- "TRANSITION: Advancing to next region"
```

---

## Common Issues

### Playback Not Advancing

**Symptom:** First region plays, never advances to second.

**Cause:** Boundary detection not triggering.

**Check:**
1. `transitions:advance()` being called each frame?
2. Region boundaries cached correctly? (print `current_bounds`)
3. Epsilon too tight? (try increasing `boundary_epsilon`)

### Shuffle Not Working

**Symptom:** Sequence plays in original order despite shuffle enabled.

**Cause:** Sequence shuffled but not reloaded.

**Fix:** After toggling shuffle, call `load_sequence()` again to re-shuffle.

### Quantize Delayed

**Symptom:** Play button click delayed by several beats.

**Cause:** Quantize lookahead calculated at wrong tempo.

**Check:**
1. Tempo correct? (`reaper.TimeMap2_GetDividedBpmAtTime`)
2. Time signature correct?
3. Measure boundaries aligned with project start?

---

## See Also

- **Main README** - App architecture overview
- **data/bridge.lua** - Bridge documentation (lazy expansion)
- **app/controller.lua** - How app layer calls engine
- **cookbook/TESTING.md** - Testing guidelines
