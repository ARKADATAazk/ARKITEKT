# RegionPlaylist Domain Refactoring Plan

## Current State (Stable ✅)

**Branch:** `claude/refactor-regionplaylist-domains-01AE5CSHff5DeZPSfiXatWBG`
**Commit:** `eed2688` - "Refactor RegionPlaylist to use new arkitekt framework modules"

### What's Working
- ✅ All 7 framework modules extracted and working:
  - `arkitekt/core/callbacks.lua` - Safe callback execution
  - `arkitekt/core/composite_undo.lua` - Advanced undo system
  - `arkitekt/core/dependency_graph.lua` - Circular dependency detection
  - `arkitekt/core/shuffle.lua` - Fisher-Yates shuffle
  - `arkitekt/core/tree_expander.lua` - Nested structure expansion
  - `arkitekt/reaper/project_monitor.lua` - Project lifecycle monitoring
  - `arkitekt/reaper/project_state.lua` - ExtState with auto JSON encoding

- ✅ RegionPlaylist refactored to use framework modules
- ✅ Old `core/app_state.lua` (1,170 lines) still in use but FUNCTIONAL
- ✅ All features working correctly

### What's NOT Done (Yet)
- ❌ Domain extraction (app_state god object still exists)
- ❌ Separation of concerns (business logic still mixed)

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

## Phased Migration Plan (FUTURE)

### Phase 1: Foundation (Current - DONE ✅)
- Extract reusable framework modules
- Refactor to use new utilities
- Test and verify stability
- **Status:** COMPLETE

### Phase 2: Extract UI Preferences Domain (30 minutes)
**Why first:** Small, self-contained, easy to validate

**Domain:** `domains/ui_preferences.lua`

**Responsibilities:**
- Search filter (pool search text)
- Sort mode & direction (alpha, color, index, length)
- Layout mode (horizontal/vertical)
- Pool mode (regions/playlists/mixed)
- Separator positions (horizontal/vertical)

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
- [ ] Region spawn animation triggers
- [ ] Selection animation works
- [ ] Destroy animation plays
- [ ] Animations clear correctly

---

### Phase 4: Extract Notification Domain (30 minutes)
**Domain:** `domains/notification.lua`

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
- [ ] Circular dependency errors show and auto-clear
- [ ] Status notifications appear and timeout
- [ ] Selection info displays correctly
- [ ] Transport override messages work

---

### Phase 5: Extract Playlist Domain (1 hour)
**Domain:** `domains/playlist.lua`

**Responsibilities:**
- Manage playlist CRUD
- Track active playlist
- Maintain playlist lookup index

**State:**
```lua
{
  playlists = {},
  playlist_lookup = {},
  active_playlist_id = nil,
}
```

**Methods to implement:**
- `get_all()` / `replace_all(playlists)`
- `get(id)` / `exists(id)`
- `get_active()` / `get_active_id()` / `set_active(id)`
- `add(playlist)` / `remove(id)`
- `update(id, updates)`
- `reorder_by_ids(new_order)`
- `count_contents(id)` - Count regions vs playlists

**CRITICAL:** Controller must call `replace_all()` after modifications!

**Testing checklist:**
- [ ] Create playlist
- [ ] Duplicate playlist
- [ ] Delete playlist
- [ ] Rename playlist
- [ ] Reorder playlists
- [ ] Switch active playlist
- [ ] Add items to playlist
- [ ] Delete items from playlist

---

### Phase 6: Extract Region Domain (30 minutes)
**Domain:** `domains/region.lua`

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
- [ ] Regions load from project
- [ ] Pool displays correctly
- [ ] Drag & drop reorders pool
- [ ] Region search works

---

### Phase 7: Extract Dependency Domain (30 minutes)
**Domain:** `domains/dependency.lua`

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
- [ ] Detects circular dependencies correctly
- [ ] No false positives
- [ ] Graph rebuilds after changes
- [ ] Nested playlists work

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

| Phase | Domain | Time | Complexity |
|-------|--------|------|-----------|
| 1 | Foundation (framework modules) | ✅ DONE | Medium |
| 2 | UI Preferences | 30 min | Low |
| 3 | Animation | 30 min | Low |
| 4 | Notification | 30 min | Low |
| 5 | Playlist | 1 hour | High |
| 6 | Region | 30 min | Low |
| 7 | Dependency | 30 min | Medium |
| **Total** | | **4 hours** | |

---

## Notes

- Original app_state.lua: 1,170 lines, 97 functions
- Target: 6 domains averaging ~150-200 lines each
- All framework modules already extracted and tested
- This is a refactoring, not a rewrite - keep same behavior
- Test obsessively - REAPER is the source of truth
