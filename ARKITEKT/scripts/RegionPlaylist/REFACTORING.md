# RegionPlaylist Domain Refactoring Plan

## Current State (✅ REFACTORING COMPLETE!)

**Branch:** `claude/refactor-regionplaylist-domains-01AE5CSHff5DeZPSfiXatWBG`
**Latest Commit:** `5599ddf` - "Add generic event bus to arkitekt/core"

### ✅ What's Complete

**Framework Modules (Phase 1):**
- ✅ `arkitekt/core/callbacks.lua` - Safe callback execution
- ✅ `arkitekt/core/composite_undo.lua` - Advanced undo system
- ✅ `arkitekt/core/dependency_graph.lua` - Circular dependency detection
- ✅ `arkitekt/core/shuffle.lua` - Fisher-Yates shuffle
- ✅ `arkitekt/core/tree_expander.lua` - Nested structure expansion
- ✅ `arkitekt/core/events.lua` - Generic event bus (pub/sub)
- ✅ `arkitekt/reaper/project_monitor.lua` - Project lifecycle monitoring
- ✅ `arkitekt/reaper/project_state.lua` - ExtState with auto JSON encoding

**Domain Modules (Phases 2-7):**
- ✅ `domains/animation.lua` (70 lines) - UI animation queues
- ✅ `domains/notification.lua` (114 lines) - Status bar notifications
- ✅ `domains/ui_preferences.lua` (170 lines) - UI state & settings
- ✅ `domains/region.lua` (75 lines) - Region cache & pool order
- ✅ `domains/dependency.lua` (203 lines) - Dependency graph management
- ✅ `domains/playlist.lua` (180 lines) - Playlist CRUD & active state

**Results:**
- ✅ `core/app_state.lua` reduced from **1,170 lines → ~500 lines**
- ✅ Extracted **~812 lines** to focused domain modules
- ✅ All features working correctly
- ✅ Clean separation of concerns
- ✅ Backward compatibility maintained

---

## Failed Attempt - Lessons Learned

**What went wrong:** Full domain migration attempted in one go without adequate testing

**Key Issues Found:**
1. **Method call notation** - Changed 200+ calls from `State.method()` to `State:method()`
   - Required understanding difference between:
     - Existence checks: `State.method` (dot)
     - Method calls: `State:method()` (colon)
     - Callbacks: `function(x) return State:method(x) end`

2. **Backward compatibility incomplete**
   - Many methods missing from compatibility layer
   - Controller methods modified arrays without updating domains
   - Data synchronization issues

3. **Circular references in JSON encoding**
   - Needed deep copy to break circular refs before persistence

4. **Dependency graph not rebuilding**
   - Graph marked dirty but never rebuilt after playlist changes

**Backup branch:** `backup-domain-refactoring-attempt` (for reference)

---

## Phased Migration Plan (✅ COMPLETE)

### Phase 1: Foundation (DONE ✅)
- Extract reusable framework modules
- Refactor to use new utilities
- Test and verify stability
- **Status:** COMPLETE (commit: eed2688)

### Phase 2: Animation Domain (DONE ✅)
**Commit:** `4b8d67f` - "Extract animation domain - Phase 2 complete"

**Domain:** `domains/animation.lua` (70 lines)

**Responsibilities:**
- Track pending UI animations (spawn/select/destroy)
- Queue animation events for tile rendering

**State:**
```lua
{
  search_filter = "",
  sort_mode = "",
  sort_direction = "asc",
  layout_mode = "horizontal",
  pool_mode = "regions",
  separator_position_horizontal = 0.5,
  separator_position_vertical = 0.5,
  settings = nil,
}
```

**Methods to implement:**
- `get_search_filter()` / `set_search_filter(text)`
- `get_sort_mode()` / `set_sort_mode(mode)`
- `get_sort_direction()` / `set_sort_direction(dir)`
- `get_layout_mode()` / `set_layout_mode(mode)`
- `get_pool_mode()` / `set_pool_mode(mode)`
- `get_separator_position_horizontal()` / `set_separator_position_horizontal(pos)`
- `get_separator_position_vertical()` / `set_separator_position_vertical(pos)`
- `load_from_settings()` / `save_to_settings()`

**Testing checklist:**
- [ ] Search filter works
- [ ] Sort mode changes
- [ ] Layout toggle works
- [ ] Pool mode switches
- [ ] Separator drag & drop
- [ ] Settings persist across sessions

---

### Phase 3: Extract Animation Domain (30 minutes)
**Domain:** `domains/animation.lua`

**Responsibilities:**
- Track pending UI animations
- Queue spawn/select/destroy events

**State:**
```lua
{
  pending_spawn = {},
  pending_select = {},
  pending_destroy = {},
}
```

**Methods to implement:**
- `queue_spawn(key)` / `get_pending_spawn()`
- `queue_select(key)` / `get_pending_select()`
- `queue_destroy(key)` / `get_pending_destroy()`
- `clear_all()`

**Testing checklist:**
- [x] Region spawn animation triggers
- [x] Selection animation works
- [x] Destroy animation plays
- [x] Animations clear correctly

---

### Phase 3: Notification Domain (DONE ✅)
**Commit:** `b59a784` - "Extract notification domain - Phase 3 complete"

**Domain:** `domains/notification.lua` (114 lines)

**Responsibilities:**
- Manage timed notifications (status bar messages)
- Track circular dependency errors
- Handle transport override state changes

**State:**
```lua
{
  circular_dependency_error = nil,
  circular_dependency_error_timestamp = nil,
  state_change_notification = nil,
  state_change_notification_timestamp = nil,
  selection_info = nil,
  last_override_state = nil,
}
```

**Methods to implement:**
- `get/set/clear_circular_dependency_error()`
- `get/set/clear_state_change_notification()`
- `get/set_selection_info()`
- `check_override_state_change(state)`

**Testing checklist:**
- [x] Circular dependency errors show and auto-clear
- [x] Status notifications appear and timeout
- [x] Selection info displays correctly
- [x] Transport override messages work

---

### Phase 4: UI Preferences Domain (DONE ✅)
**Commit:** `21bc307` - "Extract UI preferences domain - Phase 4 complete"

**Domain:** `domains/ui_preferences.lua` (170 lines)

**Responsibilities:**
- Search filter, sort mode, layout mode, pool mode
- Separator positions
- Load/save from settings

**Testing checklist:**
- [x] Search filter works
- [x] Sort mode changes
- [x] Layout toggle works
- [x] Pool mode switches
- [x] Separator drag & drop
- [x] Settings persist across sessions

---

### Phase 5: Region Domain (DONE ✅)
**Commit:** `fcc08ba` - "Extract region domain - Phase 5 complete"

**Domain:** `domains/region.lua` (75 lines)

**Responsibilities:**
- Cache region data from bridge
- Manage pool order
- Provide region lookups

**State:**
```lua
{
  region_index = {},
  pool_order = {},
}
```

**Methods to implement:**
- `get(rid)` - Get region by ID
- `get_index()` - Get full region index
- `get_pool_order()` / `set_pool_order(order)`
- `refresh_from_bridge(regions)` - Update from bridge

**Testing checklist:**
- [x] Regions load from project
- [x] Pool displays correctly
- [x] Drag & drop reorders pool
- [x] Region search works

---

### Phase 6: Dependency Domain (DONE ✅)
**Commit:** `4e229a4` - "Extract dependency domain - Phase 6 complete"

**Domain:** `domains/dependency.lua` (203 lines)

**Responsibilities:**
- Wrap `arkitekt.core.dependency_graph`
- Track playlist dependencies
- Detect circular references

**State:**
```lua
{
  graph = DependencyGraph.new(),
  dirty = true,
}
```

**Methods to implement:**
- `mark_dirty()` / `rebuild(playlists)`
- `ensure_fresh(playlists)`
- `would_create_cycle(target_id, source_id)`
- `is_safe_to_add(target_id, source_id)`
- `has_cycles()` / `topological_sort()`

**CRITICAL:** Must rebuild after every playlist modification!

**Testing checklist:**
- [x] Detects circular dependencies correctly
- [x] No false positives
- [x] Graph rebuilds after changes
- [x] Nested playlists work

---

### Phase 7: Playlist Domain (DONE ✅)
**Commit:** `7a7e782` - "Extract playlist domain - Phase 7 complete"

**Domain:** `domains/playlist.lua` (180 lines)

**Responsibilities:**
- Manage playlist CRUD operations
- Track active playlist
- Maintain playlist lookup index
- Handle playlist reordering

**Testing checklist:**
- [x] Create playlist
- [x] Duplicate playlist
- [x] Delete playlist
- [x] Rename playlist
- [x] Reorder playlists
- [x] Switch active playlist
- [x] Add items to playlist
- [x] Delete items from playlist

---

## Implementation Checklist (For Each Phase)

### Before Starting
1. [ ] Ensure previous phase is 100% working
2. [ ] Commit current state
3. [ ] Create new branch for this phase

### During Implementation
1. [ ] Create `domains/X.lua` with ALL methods from app_state
2. [ ] Create domain instance in `main.lua` initialization
3. [ ] Add backward compatibility wrappers in `main.lua`
4. [ ] Update controller if needed (especially for playlist domain)
5. [ ] Test EVERY feature in the domain

### After Implementation
1. [ ] Run full regression test
2. [ ] Check for console errors
3. [ ] Verify persistence works
4. [ ] Only commit if 100% working
5. [ ] Update this document with status

---

## Critical Lessons - DO NOT FORGET!

### 1. Method Call Notation
```lua
-- Checking if method exists (use dot):
if State.method_name then

-- Calling method (use colon):
State:method_name(args)

-- Passing method as callback:
callback = function(x) return State:method_name(x) end
```

### 2. Controller Must Update Domain
```lua
-- WRONG - modifies array but domain doesn't know:
local playlists = state:get_playlists()
table.insert(playlists, new_playlist)

-- CORRECT - updates domain:
local playlists = state:get_playlists()
table.insert(playlists, new_playlist)
state.domains.playlist:replace_all(playlists)  -- ✅
```

### 3. Dependency Graph Must Rebuild
```lua
-- Add to controller _commit():
function Controller:_commit()
  self.state:persist()
  self.state:rebuild_dependency_graph()  -- ✅
  -- ... rest
end
```

### 4. Avoid Circular References in Persistence
```lua
-- Deep copy before JSON encoding:
function save_playlists(playlists)
  local safe = deep_copy_only_needed_fields(playlists)
  save_to_json(safe)  -- Won't stack overflow
end
```

### 5. Test Everything After Each Change
- Don't assume it works
- Don't fix multiple things at once
- Test in REAPER after every domain
- Commit only when 100% working

---

## Completion Criteria

**Phase is complete when:**
1. ✅ All features in domain work identically to before
2. ✅ No console errors
3. ✅ State persists correctly across sessions
4. ✅ Undo/redo works
5. ✅ No regressions in other areas
6. ✅ Code is committed and pushed

**DO NOT PROCEED** to next phase until current phase meets all criteria.

---

## Timeline Estimate

| Phase | Domain | Estimated | Actual | Status |
|-------|--------|-----------|--------|--------|
| 1 | Foundation | N/A | N/A | ✅ DONE (eed2688) |
| 2 | Animation | 30 min | ~45 min | ✅ DONE (4b8d67f) |
| 3 | Notification | 30 min | ~45 min | ✅ DONE (b59a784) |
| 4 | UI Preferences | 30 min | ~45 min | ✅ DONE (21bc307) |
| 5 | Region | 30 min | ~30 min | ✅ DONE (fcc08ba) |
| 6 | Dependency | 30 min | ~30 min | ✅ DONE (4e229a4) |
| 7 | Playlist | 1 hour | ~1 hour | ✅ DONE (7a7e782) |
| **Total** | | **4 hours** | **~4.5 hours** | ✅ COMPLETE |

---

## Notes

- Original app_state.lua: 1,170 lines, 97 functions
- Target: 6 domains averaging ~150-200 lines each
- All framework modules already extracted and tested
- This is a refactoring, not a rewrite - keep same behavior
- Test obsessively - REAPER is the source of truth
