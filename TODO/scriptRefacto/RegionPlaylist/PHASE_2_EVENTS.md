# Phase 2: Migrate to Event Bus Pattern

> Replace callback explosion with arkitekt.core.events

## Problem

### Callback Explosion in gui.lua

`ui/gui.lua:61-292` contains **40+ inline callbacks** in a single `RegionTiles.create()` call:

```lua
self.region_tiles = RegionTiles.create({
  on_playlist_changed = function(new_id) ... end,
  on_pool_search = function(text) ... end,
  on_pool_sort = function(mode) ... end,
  on_pool_sort_direction = function(direction) ... end,
  on_pool_mode_changed = function(mode) ... end,
  on_active_reorder = function(new_order) ... end,
  on_active_remove = function(item_key) ... end,
  on_active_toggle_enabled = function(item_key, new_state) ... end,
  on_active_delete = function(item_keys) ... end,
  on_active_rename = function(item_key, new_name) ... end,
  on_active_batch_rename = function(item_keys, pattern) ... end,
  -- ... 30 more callbacks
})
```

### Empty/No-op Callbacks

Several callbacks do nothing:

```lua
-- gui.lua:58-59
State.on_repeat_cycle = function(key, current_loop, total_reps)
end  -- Empty!

-- app_state.lua:124-128
on_region_change = function(rid, region, pointer) end,
on_playback_start = function(rid) end,
on_playback_stop = function() end,
```

### No Multi-listener Support

Current pattern only allows one listener per event:

```lua
State.on_state_restored = function() ... end
-- Can't add a second listener!
```

## Solution

Use `arkitekt.core.events` for decoupled pub/sub.

### Event Naming Convention

```
<domain>.<action>

Examples:
- playlist.created
- playlist.deleted
- playback.started
- playback.stopped
- playback.region_changed
- ui.selection_changed
- ui.search_changed
```

## Sub-Phases (Safe Migration Path)

Break Phase 2 into atomic steps. **Each sub-phase should be a separate commit.**

| Sub-Phase | Risk | Rollback | Test After |
|-----------|------|----------|------------|
| 2.1 Create events module | None | Delete file | Unit tests |
| 2.2 Add bus to app_state (inactive) | None | Revert | App starts |
| 2.3 Emit playback events | Low | Revert | Playback works |
| 2.4 Extract handlers module | Low | Revert | All callbacks work |
| 2.5 Migrate state callbacks | Medium | Revert | Undo/redo works |
| 2.6 Migrate playback callbacks | Medium | Revert | Playback events fire |
| 2.7 Remove direct callbacks | Low | Revert | Full test |

### Sub-Phase 2.1: Create Events Module (Zero Risk)

Create the module without wiring it.

**Files**: `app/events.lua` (new)
**Risk**: None - no existing code touched
**Rollback**: Delete the file
**Test**: Unit tests only

---

### Sub-Phase 2.2: Add Bus to app_state (Zero Risk)

Initialize event bus but don't use it yet.

**Files**: `core/app_state.lua`
**Changes**:
```lua
local AppEvents = require("RegionPlaylist.app.events")

function M.initialize(settings)
  -- Create event bus (unused for now)
  M.events = AppEvents.create_bus(DEBUG_APP_STATE)
  M.EVENTS = AppEvents.EVENTS

  -- ... existing initialization (unchanged)
end
```
**Risk**: None - bus exists but nothing emits/subscribes
**Rollback**: Remove the two lines
**Test**: App starts normally

---

### Sub-Phase 2.3: Emit Playback Events (Low Risk)

Start emitting events alongside existing callbacks.

**Files**: `engine/coordinator_bridge.lua`
**Changes**:
```lua
-- In existing callback handlers, ADD event emission
on_region_change = function(rid, region, pointer)
  -- Existing callback (keep for now)
  if opts.on_region_change then
    opts.on_region_change(rid, region, pointer)
  end

  -- NEW: Also emit event
  if app_state.events then
    app_state.events:emit(app_state.EVENTS.PLAYBACK_REGION_CHANGED, {
      rid = rid,
      region = region,
      pointer = pointer,
    })
  end
end
```
**Risk**: Low - adds emission, doesn't change behavior
**Rollback**: Remove the event emission lines
**Test**:
- Enable debug on event bus
- Verify events logged during playback

---

### Sub-Phase 2.4: Extract Handlers Module (Low Risk)

Create `ui/handlers.lua` with extracted callbacks.

**Files**: `ui/handlers.lua` (new)
**Changes**:
- Copy callbacks from gui.lua
- Wrap in factory function
- Don't change gui.lua yet

**Risk**: Low - new file, no existing code changed
**Rollback**: Delete the file
**Test**: Import and call `create_tile_handlers()` in console

---

### Sub-Phase 2.5: Migrate State Callbacks (Medium Risk)

Replace `on_state_restored` direct callback with event subscription.

**Files**: `core/app_state.lua`, `ui/gui.lua`
**Changes**:

```lua
-- app_state.lua: Emit event instead of calling callback
function M.undo()
  -- ... existing logic

  -- REMOVE: Direct callback
  -- if M.on_state_restored then M.on_state_restored() end

  -- ADD: Event emission
  if M.events then
    M.events:emit(M.EVENTS.STATE_RESTORED, { action = "undo", changes = changes })
  end
end

-- gui.lua: Subscribe to event
function M.create(State, AppConfig, settings)
  -- ... existing setup

  -- REMOVE: Direct callback assignment
  -- State.on_state_restored = function() self:refresh_tabs() end

  -- ADD: Event subscription
  self._unsub_state = State.events:on(State.EVENTS.STATE_RESTORED, function()
    self:refresh_tabs()
    -- ... rest of handler
  end)
end
```

**Risk**: Medium - changes how state restoration notifies GUI
**Rollback**: Revert both files
**Test**:
- Add items, undo → tabs refresh
- Undo/redo multiple times → no stale state

---

### Sub-Phase 2.6: Migrate Playback Callbacks (Medium Risk)

Replace `on_repeat_cycle` and other playback callbacks.

**Files**: `core/app_state.lua`, `ui/gui.lua`, `engine/coordinator_bridge.lua`
**Changes**: Similar pattern to 2.5

**Risk**: Medium - changes playback notification flow
**Rollback**: Revert files
**Test**:
- Play region with repeat → repeat cycle event fires
- UI updates on region change

---

### Sub-Phase 2.7: Use Extracted Handlers (Low Risk)

Replace inline callbacks in gui.lua with handlers module.

**Files**: `ui/gui.lua`
**Changes**:
```lua
local Handlers = require("RegionPlaylist.ui.handlers")

function M.create(State, AppConfig, settings)
  -- ...

  -- REPLACE 230 lines of callbacks with:
  local tile_handlers = Handlers.create_tile_handlers(
    self.controller, State, State.events
  )

  self.region_tiles = RegionTiles.create(tile_handlers)
end
```

**Risk**: Low (if handlers module tested)
**Rollback**: Revert gui.lua, keep handlers.lua
**Test**: All tile interactions work

---

### Sub-Phase 2.8: Cleanup Direct Callbacks (Low Risk)

Remove the now-unused direct callback properties.

**Files**: `core/app_state.lua`
**Changes**:
```lua
-- REMOVE these lines:
M.on_state_restored = nil
M.on_repeat_cycle = nil
```

**Risk**: Low (if event subscriptions verified)
**Rollback**: Re-add the lines
**Test**: Full regression test

---

## Integration Points (Risk Areas)

These are the connections between modules that could break:

| From | To | Via | Risk |
|------|-----|-----|------|
| coordinator_bridge | app_state | `on_repeat_cycle` callback | Medium |
| app_state | gui | `on_state_restored` callback | Medium |
| gui | region_tiles | 40+ callbacks | Low (extracted) |
| controller | app_state | Direct state mutation | Low |

### Safe Order

1. Wire events **alongside** existing callbacks first
2. Verify events fire correctly (debug mode)
3. Add event subscriptions **alongside** direct callbacks
4. Verify both paths work
5. Remove direct callbacks one at a time
6. Test after each removal

---

## Implementation Plan

### Step 1: Create app/events.lua

Central event bus factory with typed event names:

```lua
-- app/events.lua
-- Central event bus and event name constants

local Events = require("arkitekt.core.events")

local M = {}

-- =============================================================================
-- EVENT NAMES (type-safe constants)
-- =============================================================================

M.EVENTS = {
  -- Playlist events
  PLAYLIST_CREATED = "playlist.created",
  PLAYLIST_DELETED = "playlist.deleted",
  PLAYLIST_RENAMED = "playlist.renamed",
  PLAYLIST_REORDERED = "playlist.reordered",
  PLAYLIST_ACTIVE_CHANGED = "playlist.active_changed",

  -- Item events
  ITEM_ADDED = "item.added",
  ITEM_REMOVED = "item.removed",
  ITEM_REORDERED = "item.reordered",
  ITEM_ENABLED_CHANGED = "item.enabled_changed",
  ITEM_REPEATS_CHANGED = "item.repeats_changed",

  -- Playback events
  PLAYBACK_STARTED = "playback.started",
  PLAYBACK_STOPPED = "playback.stopped",
  PLAYBACK_PAUSED = "playback.paused",
  PLAYBACK_REGION_CHANGED = "playback.region_changed",
  PLAYBACK_TRANSITION = "playback.transition",
  PLAYBACK_REPEAT_CYCLE = "playback.repeat_cycle",

  -- UI events
  UI_SELECTION_CHANGED = "ui.selection_changed",
  UI_SEARCH_CHANGED = "ui.search_changed",
  UI_SORT_CHANGED = "ui.sort_changed",
  UI_LAYOUT_CHANGED = "ui.layout_changed",
  UI_POOL_MODE_CHANGED = "ui.pool_mode_changed",

  -- State events
  STATE_RESTORED = "state.restored",
  STATE_SAVED = "state.saved",

  -- Animation events
  ANIMATION_SPAWN = "animation.spawn",
  ANIMATION_DESTROY = "animation.destroy",
}

-- =============================================================================
-- BUS FACTORY
-- =============================================================================

--- Create the application event bus
--- @param debug boolean Enable debug logging
--- @return table bus Event bus instance
function M.create_bus(debug)
  return Events.new({
    debug = debug or false,
    max_history = 100,
  })
end

return M
```

### Step 2: Initialize in app_state.lua

```lua
-- app_state.lua (add to initialize())

local AppEvents = require("RegionPlaylist.app.events")

function M.initialize(settings)
  -- Create event bus
  M.events = AppEvents.create_bus(DEBUG_APP_STATE)
  M.EVENTS = AppEvents.EVENTS  -- Re-export for convenience

  -- ... existing initialization
end
```

### Step 3: Emit Events in Controller

```lua
-- controller.lua

function Controller:add_item(playlist_id, rid, insert_index)
  return self:_with_undo(function()
    -- ... existing logic

    -- Emit event
    if self.state.events then
      self.state.events:emit(self.state.EVENTS.ITEM_ADDED, {
        playlist_id = playlist_id,
        rid = rid,
        key = new_item.key,
        index = insert_index,
      })
    end

    return new_item.key
  end)
end
```

### Step 4: Extract Callbacks to ui/handlers.lua

```lua
-- ui/handlers.lua
-- Extracted event handlers from gui.lua

local M = {}

--- Create tile callback handlers
--- @param controller table Controller instance
--- @param state table State module
--- @param events table Event bus
--- @return table handlers Callback table for RegionTiles
function M.create_tile_handlers(controller, state, events)
  local E = state.EVENTS

  return {
    -- Playlist operations
    on_playlist_changed = function(new_id)
      state.set_active_playlist(new_id)
      events:emit(E.PLAYLIST_ACTIVE_CHANGED, { id = new_id })
    end,

    -- Search/filter (grouped)
    on_pool_search = function(text)
      state.set_search_filter(text)
      state.persist_ui_prefs()
      events:emit(E.UI_SEARCH_CHANGED, { text = text })
    end,

    on_pool_sort = function(mode)
      state.set_sort_mode(mode)
      if mode == nil then
        state.set_sort_direction("asc")
      end
      state.persist_ui_prefs()
      events:emit(E.UI_SORT_CHANGED, { mode = mode })
    end,

    -- Item operations (grouped)
    on_active_delete = function(item_keys)
      controller:delete_items(state.get_active_playlist_id(), item_keys)
      for _, key in ipairs(item_keys) do
        events:emit(E.ANIMATION_DESTROY, { key = key })
      end
    end,

    -- ... other handlers grouped by domain
  }
end

--- Create playback event subscriptions
--- @param gui table GUI instance
--- @param events table Event bus
--- @return function unsubscribe_all Function to remove all subscriptions
function M.subscribe_playback_events(gui, events)
  local E = gui.State.EVENTS
  local unsubs = {}

  unsubs[#unsubs + 1] = events:on(E.STATE_RESTORED, function()
    gui:refresh_tabs()
    if gui.region_tiles.active_grid and gui.region_tiles.active_grid.selection then
      gui.region_tiles.active_grid.selection:clear()
    end
    if gui.region_tiles.pool_grid and gui.region_tiles.pool_grid.selection then
      gui.region_tiles.pool_grid.selection:clear()
    end
  end)

  unsubs[#unsubs + 1] = events:on(E.PLAYBACK_REPEAT_CYCLE, function(data)
    -- Handle repeat cycle UI update
  end)

  -- Return cleanup function
  return function()
    for _, unsub in ipairs(unsubs) do
      unsub()
    end
  end
end

return M
```

### Step 5: Refactor gui.lua

```lua
-- gui.lua (simplified)

local Handlers = require("RegionPlaylist.ui.handlers")

function M.create(State, AppConfig, settings)
  local self = setmetatable({ ... }, GUI)

  -- Create handlers from extracted module
  local tile_handlers = Handlers.create_tile_handlers(
    self.controller,
    State,
    State.events
  )

  -- Much cleaner!
  self.region_tiles = RegionTiles.create(
    vim.tbl_extend("force", tile_handlers, {
      State = State,
      controller = self.controller,
      config = AppConfig.get_region_tiles_config(State.get_layout_mode()),
      settings = settings,
    })
  )

  -- Subscribe to events
  self._unsub_playback = Handlers.subscribe_playback_events(self, State.events)

  return self
end

-- Cleanup on destroy
function GUI:destroy()
  if self._unsub_playback then
    self._unsub_playback()
  end
end
```

### Step 6: Replace Direct Callbacks in app_state.lua

```lua
-- BEFORE
M.on_state_restored = nil  -- Set by GUI
M.on_repeat_cycle = nil    -- Set by GUI

-- AFTER (remove these, use events instead)
-- In coordinator_bridge:
on_repeat_cycle = function(key, current_loop, total_reps)
  if M.events then
    M.events:emit(M.EVENTS.PLAYBACK_REPEAT_CYCLE, {
      key = key,
      current_loop = current_loop,
      total_loops = total_reps,
    })
  end
end
```

## Migration Checklist

### Create New Files

- [ ] `app/events.lua` - Event bus factory and constants

### Modify Existing Files

- [ ] `core/app_state.lua`
  - [ ] Initialize event bus in `initialize()`
  - [ ] Remove `on_state_restored` callback
  - [ ] Remove `on_repeat_cycle` callback
  - [ ] Emit events in state-changing functions

- [ ] `core/controller.lua`
  - [ ] Emit events after mutations (item added, deleted, etc.)

- [ ] `ui/gui.lua`
  - [ ] Extract callbacks to `ui/handlers.lua`
  - [ ] Subscribe to events instead of direct callbacks
  - [ ] Add cleanup in destroy/close

- [ ] `engine/coordinator_bridge.lua`
  - [ ] Emit events instead of direct callbacks

### New File: ui/handlers.lua

- [ ] `create_tile_handlers()` - All tile callbacks
- [ ] `subscribe_playback_events()` - Playback subscriptions
- [ ] `subscribe_state_events()` - State change subscriptions

## Event Payload Reference

| Event | Payload |
|-------|---------|
| `playlist.created` | `{ id, name }` |
| `playlist.deleted` | `{ id }` |
| `playlist.active_changed` | `{ id, previous_id }` |
| `item.added` | `{ playlist_id, key, rid, index }` |
| `item.removed` | `{ playlist_id, keys }` |
| `playback.started` | `{ rid, pointer }` |
| `playback.stopped` | `{}` |
| `playback.region_changed` | `{ rid, region, pointer }` |
| `playback.repeat_cycle` | `{ key, current_loop, total_loops }` |
| `ui.selection_changed` | `{ keys, source }` |
| `state.restored` | `{ changes }` |

## Benefits

1. **Multiple Listeners**: Any module can subscribe to events
2. **Decoupled**: GUI doesn't need direct references to state callbacks
3. **Debuggable**: Event history available via `events:get_history()`
4. **Testable**: Can mock event bus in tests
5. **Organized**: Handlers grouped by domain in separate file
