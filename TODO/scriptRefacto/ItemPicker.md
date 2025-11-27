# ItemPicker Refactoring Plan

> **Status:** Not Started
> **Priority:** 2nd (after TemplateBrowser)
> **Effort:** Medium (28 files to move, 4 folders to delete)
> **Target Architecture:** [MIGRATION_PLANS.md](../../cookbook/MIGRATION_PLANS.md#itempicker-migration)

---

## Executive Summary

ItemPicker has **excellent code quality (9/10)** but is **architecturally non-compliant (3/10)** with ARKITEKT's target structure. It represents the "before" state in the migration plan.

**Overall Rating: 7.0/10** - "Great code in the wrong house"

### What's Good ✅

- Centralized state management (single source of truth)
- Security-conscious (safe JSON, proper validation)
- Performance-aware (caching, O(1) lookups, incremental loading)
- Clean separation of concerns (within current structure)
- Theme-reactive constants with smart caching
- No globals, proper module pattern

### What Needs Fixing ❌

- Missing `domain/` layer entirely (business logic scattered)
- Uses `core/` instead of `app/`
- Uses `data/` instead of `infra/`
- Has `services/` folder (should be split/deleted)
- Has `utils/` folder (should use arkitekt.debug.logger)
- `init.lua` at root instead of `app/init.lua`

---

## Current vs Target Architecture

### Current Structure (32 files)

```
ItemPicker/
├── ARK_ItemPicker.lua
├── init.lua                          # ❌ Should be app/init.lua
│
├── core/                             # ❌ Should be "app/"
│   ├── app_state.lua
│   ├── config.lua
│   ├── controller.lua                # ❌ Should be domain/items/service.lua
│   └── preview_manager.lua           # ❌ Should be domain/preview/manager.lua
│
├── data/                             # ❌ Should be "infra/"
│   ├── reaper_api.lua
│   ├── persistence.lua               # ❌ Should be infra/storage.lua
│   ├── disk_cache.lua                # ❌ Should be infra/cache.lua
│   ├── job_queue.lua
│   └── loaders/
│       └── incremental_loader.lua    # ❌ Should be infra/loader.lua (flattened)
│
├── services/                         # ❌ Should NOT exist - split this!
│   ├── utils.lua                     # ❌ Delete or merge
│   ├── pool_utils.lua                # ❌ → domain/pool/utils.lua
│   └── visualization.lua             # ❌ → ui/visualization.lua
│
├── utils/                            # ❌ Should NOT exist
│   └── logger.lua                    # ❌ Delete (use arkitekt.debug.logger)
│
├── defs/                             # ✅ PERFECT - Keep as-is
│   ├── constants.lua                 # ✅ Best-in-class (theme-reactive)
│   ├── defaults.lua
│   └── strings.lua
│
└── ui/                               # ⚠️ Partial compliance
    ├── main_window.lua               # ❌ Should be ui/init.lua
    ├── components/
    │   ├── status_bar.lua            # ❌ Rename to status.lua
    │   ├── search_with_mode.lua      # ❌ Rename to search.lua
    │   ├── drag_handler.lua          # ❌ Rename to drag.lua
    │   ├── layout_view.lua           # ❌ Rename to layout.lua
    │   ├── region_filter_bar.lua     # ❌ → ui/components/filters/region.lua
    │   ├── track_filter_bar.lua      # ❌ → ui/components/filters/track.lua
    │   └── track_filter.lua          # ❌ → ui/components/filters/track_detail.lua
    └── grids/
        ├── coordinator.lua
        ├── factories/
        │   ├── midi_grid_factory.lua  # ❌ Rename to midi.lua
        │   ├── audio_grid_factory.lua # ❌ Rename to audio.lua
        │   └── grid_factory_shared.lua # ❌ Rename to shared.lua
        └── renderers/
            ├── base.lua
            ├── audio.lua
            └── midi.lua
```

### Target Structure (Post-Migration)

```
ItemPicker/
├── ARK_ItemPicker.lua               # Entry point (minimal, calls app/init)
│
├── app/                             # ✨ NEW: Application orchestration
│   ├── init.lua                     # ✨ NEW: Bootstrap with dependency injection
│   ├── config.lua                   # FROM: core/config.lua
│   └── state.lua                    # FROM: core/app_state.lua (simplified)
│
├── domain/                          # ✨ NEW: Pure business logic
│   ├── items/
│   │   ├── service.lua              # FROM: core/controller.lua
│   │   ├── audio.lua                # ✨ NEW: Extract audio-specific logic
│   │   └── midi.lua                 # ✨ NEW: Extract MIDI-specific logic
│   ├── preview/
│   │   └── manager.lua              # FROM: core/preview_manager.lua
│   └── pool/
│       └── utils.lua                # FROM: services/pool_utils.lua
│
├── infra/                           # Infrastructure (I/O, external systems)
│   ├── storage.lua                  # FROM: data/persistence.lua (renamed)
│   ├── cache.lua                    # FROM: data/disk_cache.lua (renamed)
│   ├── job_queue.lua                # FROM: data/job_queue.lua
│   ├── reaper_api.lua               # FROM: data/reaper_api.lua
│   └── loader.lua                   # FROM: data/loaders/incremental_loader.lua (flattened)
│
├── ui/                              # Presentation layer
│   ├── init.lua                     # FROM: ui/main_window.lua (renamed)
│   ├── visualization.lua            # FROM: services/visualization.lua
│   │
│   ├── state/                       # ✨ NEW: UI-only state
│   │   └── preferences.lua          # ✨ NEW: Extract from core/app_state.lua
│   │
│   ├── components/
│   │   ├── search.lua               # FROM: search_with_mode.lua
│   │   ├── status.lua               # FROM: status_bar.lua
│   │   ├── drag.lua                 # FROM: drag_handler.lua
│   │   ├── layout.lua               # FROM: layout_view.lua
│   │   └── filters/                 # ✨ NEW: Organized filter components
│   │       ├── region.lua           # FROM: region_filter_bar.lua
│   │       ├── track.lua            # FROM: track_filter_bar.lua
│   │       └── track_detail.lua     # FROM: track_filter.lua
│   │
│   └── grids/
│       ├── coordinator.lua
│       ├── factories/
│       │   ├── audio.lua            # FROM: audio_grid_factory.lua
│       │   ├── midi.lua             # FROM: midi_grid_factory.lua
│       │   └── shared.lua           # FROM: grid_factory_shared.lua
│       └── renderers/
│           ├── base.lua
│           ├── audio.lua
│           └── midi.lua
│
├── defs/                            # ✅ UNCHANGED - Already perfect
│   ├── constants.lua
│   ├── defaults.lua
│   └── strings.lua
│
└── tests/                           # ✨ NEW: Test infrastructure
    ├── domain/
    │   ├── items_test.lua
    │   ├── preview_test.lua
    │   └── pool_test.lua
    └── infra/
        └── storage_test.lua
```

---

## Migration Checklist (Phase-by-Phase)

### Phase 0: Preparation ⏳

**Before starting migration:**

- [ ] **Wait for TemplateBrowser migration to complete** (Priority 1)
- [ ] Review TemplateBrowser migration patterns
- [ ] Backup current working state
- [ ] Create feature branch: `refactor/itempicker-migration`
- [ ] Document any custom patterns specific to ItemPicker

**Estimated Time:** 1 hour

---

### Phase 1: Create Folder Structure 📁

**Create new directories without moving files yet:**

```bash
mkdir -p ItemPicker/app
mkdir -p ItemPicker/domain/items
mkdir -p ItemPicker/domain/preview
mkdir -p ItemPicker/domain/pool
mkdir -p ItemPicker/infra
mkdir -p ItemPicker/ui/state
mkdir -p ItemPicker/ui/components/filters
mkdir -p ItemPicker/tests/domain
mkdir -p ItemPicker/tests/infra
```

**Checklist:**

- [ ] Create `app/` folder
- [ ] Create `domain/` folder with subdirectories
- [ ] Create `infra/` folder
- [ ] Create `ui/state/` folder
- [ ] Create `ui/components/filters/` folder
- [ ] Create `tests/` folder structure
- [ ] Verify all folders exist

**Estimated Time:** 15 minutes

---

### Phase 2: Move App Layer Files 🏠

**Move orchestration and state files first:**

| File | Action | Notes |
|------|--------|-------|
| `init.lua` | → `app/init.lua` | Expand with proper DI pattern |
| `core/config.lua` | → `app/config.lua` | Direct move |
| `core/app_state.lua` | → `app/state.lua` | Simplify - extract UI prefs |

**Implementation Steps:**

1. **Move config (simple):**
   ```bash
   mv core/config.lua app/config.lua
   ```
   - [ ] Update file path comment
   - [ ] Update all `require('ItemPicker.core.config')` → `require('ItemPicker.app.config')`
   - [ ] Test: Run ItemPicker, verify no errors

2. **Move and simplify state:**
   ```bash
   mv core/app_state.lua app/state.lua
   ```
   - [ ] Update file path comment
   - [ ] Extract UI preferences to `ui/state/preferences.lua` (see Phase 3)
   - [ ] Remove `package.loaded["ItemPicker.core.app_state"] = M` hack (use DI in app/init.lua)
   - [ ] Update all requires: `core.app_state` → `app.state`
   - [ ] Test: Run ItemPicker, verify state loads correctly

3. **Create app/init.lua bootstrap:**
   ```lua
   -- app/init.lua
   local M = {}

   -- Load configuration
   M.config = require("ItemPicker.app.config")
   M.state = require("ItemPicker.app.state")

   -- Domain services
   M.items = require("ItemPicker.domain.items.service")
   M.preview = require("ItemPicker.domain.preview.manager")
   M.pool = require("ItemPicker.domain.pool.utils")

   -- Infrastructure
   M.infra = {
       storage = require("ItemPicker.infra.storage"),
       cache = require("ItemPicker.infra.cache"),
       job_queue = require("ItemPicker.infra.job_queue"),
       reaper_api = require("ItemPicker.infra.reaper_api"),
       loader = require("ItemPicker.infra.loader"),
   }

   return M
   ```
   - [ ] Create `app/init.lua` with DI pattern
   - [ ] Test: Can require app/init successfully

4. **Add backward-compat re-exports:**
   ```bash
   # Create shim in core/config.lua
   echo "return require('ItemPicker.app.config')" > core/config.lua
   ```
   - [ ] Create `core/config.lua` re-export
   - [ ] Create `core/app_state.lua` re-export
   - [ ] Test: Old requires still work

**Estimated Time:** 2 hours

---

### Phase 3: Create UI State Layer 🎨

**Extract UI-specific state from app/state.lua:**

**Create `ui/state/preferences.lua`:**

```lua
-- ui/state/preferences.lua
-- UI-only preferences (animations, visual settings, panel positions)

local M = {}

-- Extract from app_state.lua:
-- - tile_sizes (width, height)
-- - separator_position
-- - scroll_y (grid scroll state)
-- - Rename-related UI state
-- - Any animation state

M.defaults = {
    tile_width = nil,  -- nil = use config default
    tile_height = nil,
    separator_position = nil,
    separator_position_horizontal = nil,
}

function M.initialize()
    -- Initialize UI preferences
end

return M
```

**Steps:**

- [ ] Create `ui/state/preferences.lua`
- [ ] Extract tile sizing logic from `app/state.lua`
- [ ] Extract separator position logic
- [ ] Extract scroll state
- [ ] Extract rename UI state
- [ ] Update `app/state.lua` to delegate to `ui/state/preferences.lua`
- [ ] Test: Tile resizing still works
- [ ] Test: Separator dragging still works
- [ ] Test: Scroll positions preserved

**Estimated Time:** 1.5 hours

---

### Phase 4: Create Domain Layer 🧠

**Move business logic to domain/**

#### 4.1: Move Controller → domain/items/service.lua

```bash
mv core/controller.lua domain/items/service.lua
```

**Refactoring needed:**

- [ ] Rename file to `domain/items/service.lua`
- [ ] Update file path comment
- [ ] Split audio-specific logic → `domain/items/audio.lua` (optional)
- [ ] Split MIDI-specific logic → `domain/items/midi.lua` (optional)
- [ ] Update all requires: `core.controller` → `domain.items.service`
- [ ] Test: Item collection still works
- [ ] Test: Item insertion still works

**Time:** 1 hour

#### 4.2: Move Preview Manager

```bash
mv core/preview_manager.lua domain/preview/manager.lua
```

- [ ] Move file
- [ ] Update file path comment
- [ ] Update requires: `core.preview_manager` → `domain.preview.manager`
- [ ] Test: Preview playback works
- [ ] Test: Preview progress indicator works

**Time:** 30 minutes

#### 4.3: Move Pool Utils

```bash
mv services/pool_utils.lua domain/pool/utils.lua
```

- [ ] Move file
- [ ] Update file path comment
- [ ] Update requires: `services.pool_utils` → `domain.pool.utils`
- [ ] Test: Item filtering works
- [ ] Test: Pool cycling works

**Time:** 30 minutes

#### 4.4: Cleanup core/ folder

- [ ] Delete or keep `core/` as re-export shims (decision point)
- [ ] If keeping: Add DEPRECATED comments
- [ ] If deleting: Ensure all requires updated

**Time:** 15 minutes

**Total Phase 4 Time:** 2.5 hours

---

### Phase 5: Rename data/ → infra/ 🏗️

**Rename folder and reorganize files:**

#### 5.1: Rename folder

```bash
mv data/ infra/
```

**Note:** This is a bulk rename - all files move at once.

- [ ] Rename `data/` → `infra/`
- [ ] Update ALL requires: `ItemPicker.data.` → `ItemPicker.infra.`
- [ ] Test: Items still load
- [ ] Test: Settings persist correctly
- [ ] Test: Disk cache works

**Time:** 1 hour (mostly find/replace)

#### 5.2: Rename specific files

| Old Path | New Path | Action |
|----------|----------|--------|
| `infra/persistence.lua` | `infra/storage.lua` | Rename + update requires |
| `infra/disk_cache.lua` | `infra/cache.lua` | Rename + update requires |
| `infra/loaders/incremental_loader.lua` | `infra/loader.lua` | Flatten + update requires |

**Steps:**

1. **Rename persistence → storage:**
   ```bash
   mv infra/persistence.lua infra/storage.lua
   ```
   - [ ] Rename file
   - [ ] Update file path comment
   - [ ] Update requires: `data.persistence` → `infra.storage`
   - [ ] Test: Settings save/load works

2. **Rename disk_cache → cache:**
   ```bash
   mv infra/disk_cache.lua infra/cache.lua
   ```
   - [ ] Rename file
   - [ ] Update file path comment
   - [ ] Update requires: `data.disk_cache` → `infra.cache`
   - [ ] Test: Waveform caching works

3. **Flatten incremental_loader:**
   ```bash
   mv infra/loaders/incremental_loader.lua infra/loader.lua
   rmdir infra/loaders
   ```
   - [ ] Move file out of loaders/ subfolder
   - [ ] Update file path comment
   - [ ] Update requires: `data.loaders.incremental_loader` → `infra.loader`
   - [ ] Delete empty `loaders/` folder
   - [ ] Test: Incremental loading works

**Time:** 1.5 hours

**Total Phase 5 Time:** 2.5 hours

---

### Phase 6: Split/Delete services/ Folder ⚔️

**This folder should NOT exist in target architecture.**

#### 6.1: Move visualization to UI

```bash
mv services/visualization.lua ui/visualization.lua
```

- [ ] Move file to ui/
- [ ] Update file path comment
- [ ] Update requires: `services.visualization` → `ui.visualization`
- [ ] Test: Waveforms render correctly
- [ ] Test: MIDI thumbnails render correctly

**Time:** 30 minutes

#### 6.2: Evaluate services/utils.lua

**Migration Plan says: "Delete or merge"**

**Decision needed:**

- [ ] **Option A:** Delete if functionality duplicated in arkitekt core
- [ ] **Option B:** Merge useful functions into domain/items/service.lua
- [ ] **Option C:** Keep as `infra/utils.lua` if truly needed

**Action (choose one):**

- [ ] Audit `services/utils.lua` - what does it do?
- [ ] Check if arkitekt.core has equivalent functions
- [ ] If deleting: Remove file and update consumers
- [ ] If keeping: Move to appropriate layer

**Time:** 1 hour (includes audit)

#### 6.3: Move pool_utils (already done in Phase 4.3)

✅ Already moved to `domain/pool/utils.lua`

#### 6.4: Delete services/ folder

```bash
rmdir services/
```

- [ ] Ensure all files moved out
- [ ] Delete empty `services/` folder
- [ ] Verify no requires left referencing services/

**Time:** 15 minutes

**Total Phase 6 Time:** 1.75 hours

---

### Phase 7: Delete utils/ Folder 🗑️

**Migration Plan: Delete - use arkitekt.debug.logger**

#### 7.1: Audit logger.lua usage

- [ ] Find all uses of `require('ItemPicker.utils.logger')`
- [ ] Document what logging functionality is used
- [ ] Check if arkitekt.debug.logger has equivalent

#### 7.2: Replace with arkitekt logger

- [ ] Replace all logger requires: `ItemPicker.utils.logger` → `arkitekt.debug.logger`
- [ ] Update logging calls if API differs
- [ ] Test: Logging still works in console

#### 7.3: Delete utils/ folder

```bash
rm utils/logger.lua
rmdir utils/
```

- [ ] Delete `utils/logger.lua`
- [ ] Delete empty `utils/` folder

**Time:** 45 minutes

---

### Phase 8: Reorganize UI Components 🎯

**Rename and reorganize UI files:**

#### 8.1: Rename main_window → init

```bash
mv ui/main_window.lua ui/init.lua
```

- [ ] Rename file
- [ ] Update file path comment
- [ ] Update requires in ARK_ItemPicker.lua
- [ ] Test: GUI still launches

**Time:** 15 minutes

#### 8.2: Rename component files

| Old Name | New Name | Action |
|----------|----------|--------|
| `ui/components/status_bar.lua` | `ui/components/status.lua` | Remove `_bar` suffix |
| `ui/components/search_with_mode.lua` | `ui/components/search.lua` | Simplify name |
| `ui/components/drag_handler.lua` | `ui/components/drag.lua` | Remove `_handler` suffix |
| `ui/components/layout_view.lua` | `ui/components/layout.lua` | Remove `_view` suffix |

**Steps:**

- [ ] Rename status_bar → status
- [ ] Rename search_with_mode → search
- [ ] Rename drag_handler → drag
- [ ] Rename layout_view → layout
- [ ] Update all requires
- [ ] Update file path comments
- [ ] Test: All UI components render

**Time:** 1 hour

#### 8.3: Move filter components to filters/ subfolder

```bash
mv ui/components/region_filter_bar.lua ui/components/filters/region.lua
mv ui/components/track_filter_bar.lua ui/components/filters/track.lua
mv ui/components/track_filter.lua ui/components/filters/track_detail.lua
```

- [ ] Move region_filter_bar → filters/region.lua
- [ ] Move track_filter_bar → filters/track.lua
- [ ] Move track_filter → filters/track_detail.lua
- [ ] Update all requires
- [ ] Update file path comments
- [ ] Test: Region filtering works
- [ ] Test: Track filtering works

**Time:** 45 minutes

#### 8.4: Rename grid factory files

| Old Name | New Name |
|----------|----------|
| `ui/grids/factories/audio_grid_factory.lua` | `ui/grids/factories/audio.lua` |
| `ui/grids/factories/midi_grid_factory.lua` | `ui/grids/factories/midi.lua` |
| `ui/grids/factories/grid_factory_shared.lua` | `ui/grids/factories/shared.lua` |

- [ ] Rename audio_grid_factory → audio
- [ ] Rename midi_grid_factory → midi
- [ ] Rename grid_factory_shared → shared
- [ ] Update all requires
- [ ] Test: Grids render correctly

**Time:** 30 minutes

**Total Phase 8 Time:** 2.5 hours

---

### Phase 9: Update Entry Point 🚀

**Update ARK_ItemPicker.lua to use new structure:**

**Current (lines 27-35):**
```lua
local Config = require('ItemPicker.core.config')
local State = require('ItemPicker.core.app_state')
local Controller = require('ItemPicker.core.controller')
local GUI = require('ItemPicker.ui.main_window')
```

**Target:**
```lua
-- Use new app layer
local App = require('ItemPicker.app.init')
local GUI = require('ItemPicker.ui.init')

-- Initialize (using DI from app/init.lua)
App.state.initialize(App.config)
Controller.init(App.infra.reaper_api, App.utils)
```

**Steps:**

- [ ] Update requires to use `app.init`
- [ ] Update GUI require to `ui.init`
- [ ] Update initialization calls
- [ ] Test: Full application launches
- [ ] Test: All features work end-to-end

**Time:** 1 hour

---

### Phase 10: Add Documentation & Tests 📚

#### 10.1: Create app/init.lua docstring

```lua
--- ItemPicker Application Bootstrap
-- @module ItemPicker.app.init
--
-- Central dependency injection point for ItemPicker.
-- Loads and wires together all layers: app, domain, infra, ui.
--
-- @usage
--   local App = require('ItemPicker.app.init')
--   App.state.initialize(App.config)
```

- [ ] Add module docstring to app/init.lua
- [ ] Add inline docs for DI container

**Time:** 15 minutes

#### 10.2: Add migration notes

```lua
-- @file ItemPicker/app/state.lua
-- @migrated 2024-XX-XX from core/app_state.lua
-- @changes Simplified state container, extracted UI prefs to ui/state/preferences.lua
```

- [ ] Add migration notes to moved files
- [ ] Document major changes

**Time:** 30 minutes

#### 10.3: Create test stubs

```bash
# Create test file stubs
touch tests/domain/items_test.lua
touch tests/domain/preview_test.lua
touch tests/domain/pool_test.lua
touch tests/infra/storage_test.lua
```

- [ ] Create test file stubs
- [ ] Add basic test structure
- [ ] Document how to run tests

**Time:** 1 hour

#### 10.4: Update README

- [ ] Update ItemPicker README with new architecture
- [ ] Document new folder structure
- [ ] Add migration completion notes

**Time:** 30 minutes

**Total Phase 10 Time:** 2.25 hours

---

### Phase 11: Cleanup & Polish 🧹

#### 11.1: Remove re-export shims

**Decision point: Keep or remove?**

- [ ] **Option A:** Keep shims indefinitely for backward compat
- [ ] **Option B:** Remove shims (breaking change for external consumers)

**If removing:**

- [ ] Delete `core/` re-exports
- [ ] Delete `domain/` flat file re-exports
- [ ] Verify no external scripts depend on old paths

**Time:** 30 minutes

#### 11.2: Update constants.lua comment

**Line 2:**
```lua
-- ItemPicker/defs/constants.lua ✅ (already correct)
```

- [ ] Verify file path comments are correct
- [ ] Update any stale comments

**Time:** 15 minutes

#### 11.3: Final verification

- [ ] Run full ItemPicker session
- [ ] Test all features:
  - [ ] Item collection
  - [ ] Search and filtering
  - [ ] Preview playback
  - [ ] Drag and drop
  - [ ] Region filtering
  - [ ] Track filtering
  - [ ] Settings persistence
  - [ ] Tile resizing
  - [ ] Favorites system
  - [ ] Disabled items system
- [ ] Check for console errors
- [ ] Check performance (no regression)

**Time:** 1 hour

#### 11.4: Commit and document

```bash
git add .
git commit -m "refactor(ItemPicker): Migrate to target architecture

- Move core/ → app/
- Move data/ → infra/
- Create domain/ layer with items/, preview/, pool/
- Split services/ → domain/ and ui/
- Delete utils/ (use arkitekt logger)
- Reorganize ui/ components
- Add app/init.lua DI bootstrap
- Extract UI state to ui/state/preferences.lua

Follows MIGRATION_PLANS.md target architecture.
Fixes: #XXX"
```

- [ ] Stage all changes
- [ ] Write comprehensive commit message
- [ ] Push to feature branch
- [ ] Create PR with migration checklist

**Time:** 30 minutes

**Total Phase 11 Time:** 2.25 hours

---

## Time Estimates Summary

| Phase | Description | Time |
|-------|-------------|------|
| 0 | Preparation | 1h |
| 1 | Create folders | 0.25h |
| 2 | Move app layer | 2h |
| 3 | Create UI state | 1.5h |
| 4 | Create domain layer | 2.5h |
| 5 | Rename data/ → infra/ | 2.5h |
| 6 | Split/delete services/ | 1.75h |
| 7 | Delete utils/ | 0.75h |
| 8 | Reorganize UI | 2.5h |
| 9 | Update entry point | 1h |
| 10 | Documentation & tests | 2.25h |
| 11 | Cleanup & polish | 2.25h |
| **TOTAL** | **20.25 hours** | (~3 working days) |

---

## Risk Assessment

### High Risk 🔴

1. **State management changes** (Phase 2-3)
   - Risk: Breaking persistence, losing user settings
   - Mitigation: Extensive testing, backup current state files

2. **Folder renames** (Phase 5)
   - Risk: Missing require statements, runtime errors
   - Mitigation: Use IDE/grep to find all requires, systematic testing

3. **services/ deletion** (Phase 6)
   - Risk: Losing important utility functions
   - Mitigation: Audit thoroughly before deleting, keep backups

### Medium Risk 🟡

4. **Domain layer creation** (Phase 4)
   - Risk: Business logic bugs during refactor
   - Mitigation: Move files without changing logic initially

5. **UI reorganization** (Phase 8)
   - Risk: Breaking component references
   - Mitigation: Update all requires systematically

### Low Risk 🟢

6. **Documentation** (Phase 10)
   - Risk: Minimal - only docs
   - Mitigation: None needed

7. **Cleanup** (Phase 11)
   - Risk: Low if re-export shims kept
   - Mitigation: Keep shims if uncertain

---

## Testing Strategy

### Per-Phase Testing

After each phase, run this checklist:

- [ ] `dofile()` ARK_ItemPicker.lua - no errors
- [ ] Window opens successfully
- [ ] No console errors during first 10 seconds
- [ ] Basic interaction works (scroll, click)
- [ ] Settings persist after close/reopen

### Full Integration Testing (After Phase 9)

- [ ] **Item Collection:**
  - [ ] Audio items load
  - [ ] MIDI items load
  - [ ] Incremental loading shows progress
  - [ ] Items grouped correctly (if enabled)

- [ ] **Filtering:**
  - [ ] Search by name works
  - [ ] Region filter works
  - [ ] Track filter works
  - [ ] Muted items filter works
  - [ ] Favorites filter works

- [ ] **Interaction:**
  - [ ] Drag and drop to timeline
  - [ ] Preview playback works
  - [ ] Tile resizing works
  - [ ] Grid scrolling smooth

- [ ] **Persistence:**
  - [ ] Settings saved on close
  - [ ] Favorites persist
  - [ ] Disabled items persist
  - [ ] Tile sizes persist
  - [ ] Track filter persist

### Performance Testing

- [ ] Item collection time (should be <5s for 500 items)
- [ ] Waveform rendering (should be smooth 60fps)
- [ ] Memory usage (check for leaks)
- [ ] Disk cache performance (should reduce load time on reopen)

---

## Success Criteria

Migration is complete when:

- [x] All 28 files moved to correct locations
- [x] All 4 folders deleted (core/, data/, services/, utils/)
- [x] New folders created (app/, domain/, infra/, ui/state/)
- [x] Entry point uses new structure
- [x] All features work as before
- [x] No performance regression
- [x] Settings/favorites/cache persist correctly
- [x] Documentation updated
- [x] Test stubs created
- [x] Commit message documents migration

**Final Verification:**

```bash
# Should NOT exist:
ls core/        # ❌ Should fail (or be re-exports only)
ls data/        # ❌ Should fail
ls services/    # ❌ Should fail
ls utils/       # ❌ Should fail

# MUST exist:
ls app/         # ✅ Should contain: init.lua, config.lua, state.lua
ls domain/      # ✅ Should contain: items/, preview/, pool/
ls infra/       # ✅ Should contain: storage.lua, cache.lua, loader.lua, etc.
ls ui/state/    # ✅ Should contain: preferences.lua
```

---

## Open Questions

1. **services/utils.lua fate:**
   - [ ] Audit content - what functions exist?
   - [ ] Decision: Delete, merge, or keep as infra/utils.lua?
   - [ ] Document decision and rationale

2. **Re-export shims:**
   - [ ] Keep indefinitely for backward compat?
   - [ ] Remove after migration (breaking change)?
   - [ ] Time-bound removal (e.g., "remove in 6 months")?

3. **Split controller into audio/midi modules?**
   - [ ] Current controller.lua is 111 lines (not huge)
   - [ ] Worth splitting into domain/items/audio.lua and domain/items/midi.lua?
   - [ ] Or keep as single domain/items/service.lua?

4. **Extract pooling logic to domain?**
   - [ ] pool_utils.lua is business logic
   - [ ] Already planned move to domain/pool/utils.lua ✅
   - [ ] Any other pooling concerns to extract?

5. **constants.lua splitting:**
   - [ ] File is 582 lines (long but well-organized)
   - [ ] Split into defs/tile_render_config.lua, defs/colors.lua, etc.?
   - [ ] Or keep as single file with sections?
   - [ ] Migration plan says "UNCHANGED" - follow that or improve?

---

## Reference Implementation: TemplateBrowser

**Status:** ~70% migrated (as of 2024-11-27)

TemplateBrowser has completed:
- ✅ `app/` folder created
- ✅ `domain/` with subdirs (fx/, tags/, template/)
- ✅ `infra/` folder created
- ✅ `ui/config/` folder created
- ⚠️ Re-export shims in place (core/ still exists)
- ⚠️ Entry point still uses old paths

**Learn from TemplateBrowser:**
- Check their `app/init.lua` pattern (once created)
- See how they handle re-export shims
- Follow their naming conventions
- Use similar migration commit structure

---

## Related Documents

- [MIGRATION_PLANS.md](../../cookbook/MIGRATION_PLANS.md#itempicker-migration) - Official migration plan
- [CONVENTIONS.md](../../cookbook/CONVENTIONS.md) - Naming standards
- [PROJECT_STRUCTURE.md](../../cookbook/PROJECT_STRUCTURE.md) - Architecture guide
- [DEPRECATED.md](../../cookbook/DEPRECATED.md) - Deprecation tracker (add re-exports here)

---

## Approval Required

Before starting migration:

- [ ] Review this plan with team
- [ ] Confirm TemplateBrowser migration complete
- [ ] Get approval on time estimate (~3 days)
- [ ] Decide on open questions
- [ ] Confirm testing strategy adequate

---

## Migration Command Reference

**Useful commands during migration:**

```bash
# Find all requires for a module
grep -r "require.*ItemPicker\.core\.config" ARKITEKT/scripts/ItemPicker/

# Find all files in a layer
find ARKITEKT/scripts/ItemPicker/core -name "*.lua"

# Check folder structure
tree -L 3 ARKITEKT/scripts/ItemPicker/

# Count lines in moved file (verify no changes)
wc -l app/state.lua
wc -l core/app_state.lua

# List all re-export shims
find . -name "*.lua" -exec grep -l "DEPRECATED.*Re-export" {} \;
```

---

**Last Updated:** 2024-11-27
**Migration Status:** Not Started
**Next Action:** Wait for TemplateBrowser completion, then begin Phase 0
