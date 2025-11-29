# Code Quality Nitpicks

> Small improvements that can be done independently of the phased migration.

## Priority: High

### 1. Magic Numbers in Engine Code

**Location**: Multiple engine files

**Problem**:
```lua
-- engine/transitions.lua:128
if time_to_end <= 0.05 and time_to_end >= -0.01 then

-- engine/transport.lua:39
self.seek_throttle = 0.06

-- engine/engine_state.lua:49
self.boundary_epsilon = 0.01

-- engine/transitions.lua:241
if time_to_end < 0.5 and time_to_end > 0 then
```

**Fix**: Move to `defs/constants.lua`:

```lua
-- defs/constants.lua (add section)
PLAYBACK = {
  -- Time thresholds (in seconds)
  TRANSITION_WINDOW_START = 0.05,   -- Start transition this close to end
  TRANSITION_WINDOW_END = -0.01,    -- Allow slight overshoot
  SEEK_THROTTLE = 0.06,             -- Min time between seeks
  BOUNDARY_EPSILON = 0.01,          -- Position comparison tolerance
  QUEUE_LOOKAHEAD = 0.5,            -- Queue next region this early
}
```

**Files to update**:
- `engine/transitions.lua`
- `engine/transport.lua`
- `engine/engine_state.lua`

---

### 2. Duplicate Undo/Redo Status Message Building

**Location**: `core/app_state.lua:422-441` and `454-475`

**Problem**: Identical code block duplicated:

```lua
-- In undo():
local parts = {}
if changes.playlists_count > 0 then
  parts[#parts + 1] = string.format("%d playlist%s", changes.playlists_count, changes.playlists_count ~= 1 and "s" or "")
end
if changes.items_count > 0 then
  parts[#parts + 1] = string.format("%d item%s", changes.items_count, changes.items_count ~= 1 and "s" or "")
end
-- ... same in redo()
```

**Fix**: Extract helper function:

```lua
-- Add near top of app_state.lua
local function _format_change_message(prefix, changes)
  local parts = {}

  if changes.playlists_count > 0 then
    parts[#parts + 1] = string.format("%d playlist%s",
      changes.playlists_count,
      changes.playlists_count ~= 1 and "s" or "")
  end

  if changes.items_count > 0 then
    parts[#parts + 1] = string.format("%d item%s",
      changes.items_count,
      changes.items_count ~= 1 and "s" or "")
  end

  if changes.regions_renamed > 0 then
    parts[#parts + 1] = string.format("%d region%s renamed",
      changes.regions_renamed,
      changes.regions_renamed ~= 1 and "s" or "")
  end

  if changes.regions_recolored > 0 then
    parts[#parts + 1] = string.format("%d region%s recolored",
      changes.regions_recolored,
      changes.regions_recolored ~= 1 and "s" or "")
  end

  if #parts > 0 then
    return prefix .. ": " .. table.concat(parts, ", ")
  end
  return prefix
end

-- Usage:
function M.undo()
  -- ...
  if success and changes then
    M.set_state_change_notification(_format_change_message("Undo", changes))
  end
end
```

---

### 3. Empty/No-op Callbacks

**Location**: Multiple files

**Problem**: Callbacks that do nothing:

```lua
-- gui.lua:58-59
State.on_repeat_cycle = function(key, current_loop, total_reps)
end  -- Empty!

-- app_state.lua:124-128
on_region_change = function(rid, region, pointer) end,
on_playback_start = function(rid) end,
on_playback_stop = function() end,
on_transition_scheduled = function(rid, region_end, transition_time) end,
```

**Fix**: Either:
1. Remove if not needed
2. Add `-- TODO: implement` comment
3. Replace with event emission (Phase 2)

---

## Priority: Medium

### 4. Inconsistent Error Handling Patterns

**Location**: Various files

**Problem**: Mix of `pcall`, `safe_call`, and raw calls:

```lua
-- coordinator_bridge.lua uses safe_call
local playlist = safe_call(bridge.get_active_playlist)

-- controller.lua uses pcall directly
local success, result = pcall(fn)

-- Some places use neither
```

**Fix**: Standardize on `arkitekt.core.callbacks.safe_call`:

```lua
local Callbacks = require('arkitekt.core.callbacks')
local safe_call = Callbacks.safe_call

-- Use consistently
local result = safe_call(potentially_failing_fn)
```

---

### 5. Large Function: handle_smooth_transitions()

**Location**: `engine/transitions.lua:43-236` (194 lines)

**Problem**: Single function with 3 major branches, deeply nested:

```lua
function Transitions:handle_smooth_transitions()
  -- Branch 1: In next_bounds (different region) - lines 69-119
  -- Branch 2: In current_bounds (same region repeat) - lines 121-165
  -- Branch 3: Out of bounds sync - lines 167-232
end
```

**Fix**: Extract to helper methods:

```lua
function Transitions:handle_smooth_transitions()
  if not _is_playing(self.proj) then return end
  if #self.state.playlist_order == 0 then return end

  local playpos = _get_play_pos(self.proj)

  -- Log current position
  self:_log_playback_position(playpos)

  -- Determine which branch to execute
  if self:_should_transition_to_next(playpos) then
    self:_handle_different_region_transition(playpos)
  elseif self:_is_within_current_bounds(playpos) then
    self:_handle_same_region_or_queue(playpos)
  else
    self:_sync_to_playhead_position(playpos)
  end

  self.state.last_play_pos = playpos
end

-- Extract each branch to its own method
function Transitions:_handle_different_region_transition(playpos)
  -- Lines 69-119 logic
end

function Transitions:_handle_same_region_or_queue(playpos)
  -- Lines 121-165 logic
end

function Transitions:_sync_to_playhead_position(playpos)
  -- Lines 167-232 logic
end
```

---

### 6. resolve_active_playlist() Fallback Chain

**Location**: `engine/coordinator_bridge.lua:94-120`

**Problem**: Complex fallback chain that's hard to follow:

```lua
local function resolve_active_playlist()
  local playlist = safe_call(bridge.get_active_playlist)
  if playlist then return playlist end

  if bridge.controller and bridge.controller.state and bridge.controller.state.get_active_playlist then
    playlist = safe_call(function()
      return bridge.controller.state.get_active_playlist()
    end)
    if playlist then return playlist end
  end

  if bridge.get_active_playlist_id and bridge.get_playlist_by_id then
    local playlist_id = safe_call(bridge.get_active_playlist_id)
    if playlist_id then
      return bridge.get_playlist_by_id(playlist_id)
    end
  end

  -- ... more fallbacks
end
```

**Fix**: Simplify by requiring proper initialization:

```lua
-- Fail fast if not properly initialized
local function resolve_active_playlist()
  if not bridge.get_active_playlist then
    Logger.error("BRIDGE", "get_active_playlist not configured")
    return nil
  end
  return safe_call(bridge.get_active_playlist)
end
```

Or use a resolver pattern:

```lua
local RESOLVERS = {
  function() return safe_call(bridge.get_active_playlist) end,
  function()
    local id = safe_call(bridge.get_active_playlist_id)
    return id and bridge.get_playlist_by_id(id)
  end,
}

local function resolve_active_playlist()
  for _, resolver in ipairs(RESOLVERS) do
    local result = resolver()
    if result then return result end
  end
  return nil
end
```

---

### 7. Index -1 as "Uninitialized" Sentinel

**Location**: `engine/engine_state.lua`

**Problem**: Using -1 as sentinel value, requires checks everywhere:

```lua
self.current_idx = -1
self.next_idx = -1

-- Then everywhere:
if self.state.current_idx == -1 then ...
if found_idx >= 1 then ...
```

**Fix**: Use `nil` or explicit state:

```lua
-- Option A: Use nil
self.current_idx = nil
self.next_idx = nil

-- Check with:
if self.current_idx then ...

-- Option B: Wrap in state object
self.position = {
  current = nil,  -- nil = not set
  next = nil,
  is_valid = function(self)
    return self.current ~= nil
  end,
}
```

---

## Priority: Low

### 8. Callback Configuration Block in gui.lua

**Location**: `ui/gui.lua:61-292`

**Problem**: 230-line callback configuration block. Even after Phase 2, this should be cleaned up.

**Fix**: Group related callbacks and add section comments:

```lua
self.region_tiles = RegionTiles.create({
  -- >>> CORE CONFIGURATION
  State = State,
  controller = self.controller,
  config = AppConfig.get_region_tiles_config(State.get_layout_mode()),

  -- >>> PLAYLIST OPERATIONS
  on_playlist_changed = handlers.on_playlist_changed,

  -- >>> SEARCH & FILTER
  on_pool_search = handlers.on_pool_search,
  on_pool_sort = handlers.on_pool_sort,
  on_pool_sort_direction = handlers.on_pool_sort_direction,
  on_pool_mode_changed = handlers.on_pool_mode_changed,

  -- >>> ACTIVE GRID MUTATIONS
  on_active_reorder = handlers.on_active_reorder,
  on_active_delete = handlers.on_active_delete,
  -- ...
})
```

---

### 9. Unused DEBUG Flags

**Location**: Multiple files

**Problem**: Debug flags that may never be toggled:

```lua
-- engine/engine_state.lua:18
local DEBUG_SEQUENCE = false

-- engine/coordinator_bridge.lua:14
local DEBUG_BRIDGE = false

-- engine/transitions.lua:15
local DEBUG_PLAYPOS = false

-- core/app_state.lua:31
local DEBUG_APP_STATE = false
```

**Fix**: Consider:
1. Using Logger's built-in level filtering instead
2. Environment variable or settings-based debug
3. Remove if truly unused

---

### 10. Mixed require() Styles

**Location**: Various files

**Problem**: Inconsistent require patterns:

```lua
-- Some files use full path
local Logger = require('arkitekt.debug.logger')

-- Some use relative-ish
local Engine = require("RegionPlaylist.engine.core")

-- Some cache at top
local Transport = require('arkitekt.reaper.transport')

-- Some require inline
local RegionState = require("RegionPlaylist.storage.persistence")
```

**Fix**: Standardize:
1. All requires at module top (after `local M = {}`)
2. Framework requires first, then local requires
3. Consistent quote style (single for requires)

```lua
local M = {}

-- =============================================================================
-- DEPENDENCIES
-- =============================================================================

-- Framework
local Logger = require('arkitekt.debug.logger')
local Callbacks = require('arkitekt.core.callbacks')

-- Local
local Engine = require('RegionPlaylist.engine.core')
local Playback = require('RegionPlaylist.engine.playback')
```

---

## Checklist

### High Priority
- [ ] Extract magic numbers to `defs/constants.lua`
- [ ] Create `_format_change_message()` helper
- [ ] Remove or document empty callbacks

### Medium Priority
- [ ] Standardize on `safe_call` pattern
- [ ] Split `handle_smooth_transitions()` into helpers
- [ ] Simplify `resolve_active_playlist()` fallbacks
- [ ] Replace -1 sentinel with nil or state object

### Low Priority
- [ ] Add section comments to callback block
- [ ] Review DEBUG flags usage
- [ ] Standardize require() patterns
