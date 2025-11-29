# Modularisation TODO

> Track reusable components: what exists, what's used, what needs migration/extraction.
> This is an evolving document - update it as you discover new patterns.

## Status Legend
- [ ] Not started
- [~] In progress
- [x] Completed

---

## Framework Components: Usage Audit

### ✅ Exists AND Used

| Component | Location | Used By | Pending Migration |
|-----------|----------|---------|-------------------|
| **Sorting** | `core/sorting.lua` | RegionPlaylist | TemplateBrowser, ItemPicker |
| **Status Bar** | `app/chrome/status_bar.lua` | RegionPlaylist | TemplateBrowser, ItemPicker |
| **Drag Drop** | `gui/interaction/drag_drop.lua` | TemplateBrowser | - |
| **Drag Visual** | `gui/interaction/drag_visual.lua` | RegionPlaylist | - |
| **Marching Ants** | `gui/interaction/marching_ants.lua` | TemplateBrowser, ItemPicker, RegionPlaylist | - |
| **Blocking** | `gui/interaction/blocking.lua` | Framework (tab_strip) | - |
| **Sliding Zone** | `gui/widgets/containers/sliding_zone.lua` | - | ItemPicker (has local impl) |
| **Tree View** | `gui/widgets/navigation/tree_view.lua` | TemplateBrowser | - |
| **Grid** | `gui/widgets/containers/grid/` | ThemeAdjuster | - |
| **Primitives** | `gui/widgets/primitives/` | WalterBuilder (button, slider, checkbox, chip) | - |

### ⚠️ Exists but UNUSED (scripts have own copies)

These were "extracted from RegionPlaylist" but RegionPlaylist still uses its own local implementations!

| Component | Framework Location | Script Copy | Notes |
|-----------|-------------------|-------------|-------|
| **Dependency Graph** | `core/dependency_graph.lua` | `RegionPlaylist/domain/dependency.lua` | Circular ref detection |
| **Tree Expander** | `core/tree_expander.lua` | `RegionPlaylist/engine/` | Nested structure → flat sequence |
| **Shuffle** | `core/shuffle.lua` | `RegionPlaylist/engine/` | Fisher-Yates shuffle |
| **Composite Undo** | `core/composite_undo.lua` | `RegionPlaylist/data/undo.lua` | App + external state undo |

### ⚠️ Exists but COMPLETELY UNUSED

Nobody uses these - not even internally:

| Component | Location | Notes |
|-----------|----------|-------|
| **Selection** | `gui/interaction/selection.lua` | Full API (single, toggle, range, rect). NO script uses it! |
| **Reorder** | `gui/interaction/reorder.lua` | Array reordering for DnD |
| **Selection Rectangle** | `gui/widgets/data/selection_rectangle.lua` | Visual component (only in demos) |
| **Events** | `core/events.lua` | Pub/sub event bus |
| **State Machine** | `core/state_machine.lua` | FSM with guards, lifecycle hooks |

### ❌ Needs Extraction

| Component | Target Location | Found In |
|-----------|-----------------|----------|
| Search/Filter | `core/filter.lua` | All scripts |
| Search Toolbar | `gui/widgets/search_toolbar.lua` | ItemPicker, TemplateBrowser |
| ~~**Notification Service**~~ | ✅ `core/notification.lua` | ~~WalterBuilder, RegionPlaylist, TemplateBrowser~~ **COMPLETED** |

---

## Migration Tasks

### High Priority: Use Existing Components

#### Selection Manager Migration
- [ ] **Migrate scripts to use `arkitekt/gui/interaction/selection.lua`**
  - Framework has full implementation with single/toggle/range/rectangle select
  - RegionPlaylist: ❌ Reimplements selection in tiles/coordinator
  - TemplateBrowser: ❌ Reimplements in app/state.lua
  - ItemPicker: ❌ Reimplements in app_state.lua
  - **Action**: Audit each script's selection needs, migrate to framework

##### Framework Selection API (what exists)

```lua
local Selection = require('arkitekt.gui.interaction.selection')
local sel = Selection.new()

-- Core operations
sel:single(id)                         -- Click: select one, clear others
sel:toggle(id)                         -- Ctrl+click: add/remove
sel:range(order, from_id, to_id)       -- Shift+click: select range
sel:apply_rect(aabb, rects_by_key, mode)  -- Rectangle/marquee select

-- Queries
sel:is_selected(id)                    -- Check if selected
sel:count()                            -- Number selected
sel:selected_keys()                    -- Unordered list
sel:selected_keys_in(order)            -- Selected in display order

-- Bulk operations
sel:clear()                            -- Deselect all
sel:select_all(order)                  -- Ctrl+A
sel:invert(order)                      -- Flip selection
```

##### Audit Checklist

- [ ] **RegionPlaylist** - Audit `ui/tiles/` selection logic
  - Where is selection state stored?
  - What modifiers are supported (Ctrl/Shift)?
  - Does it need rectangle selection?
  - Does coordinator have special selection needs?

- [ ] **TemplateBrowser** - Audit `app/state.lua` selection logic
  - Where is selection state stored?
  - What modifiers are supported?
  - Grid layout - rectangle selection useful?

- [ ] **ItemPicker** - Audit `app_state.lua` selection logic
  - Where is selection state stored?
  - What modifiers are supported?
  - List vs grid view - different selection needs?

##### Migration Blockers to Check

1. **API mismatch**: Does framework API cover all use cases?
2. **State location**: Can `sel.selected` map integrate with script state?
3. **Order requirement**: Scripts must provide display order for range/select_all
4. **Modifier detection**: UI layer must detect Ctrl/Shift (not in selection.lua)

#### Sorting Migration
- [x] **arkitekt/core/sorting.lua** - Created
  - RegionPlaylist: ✅ Migrated
  - TemplateBrowser: ❌ Needs migration
  - ItemPicker: ❌ Needs migration (uses grid_factory_shared.lua)

#### Status Bar Migration
- [ ] **Migrate scripts to use `arkitekt/app/chrome/status_bar.lua`**
  - RegionPlaylist: ✅ Uses it (provides `get_status` callback)
  - TemplateBrowser: ❌ Reimplements in ui/status.lua
  - ItemPicker: ❌ Reimplements in ui/components/status_bar.lua

#### RegionPlaylist → Framework Migrations

These modules were extracted to framework but RegionPlaylist never migrated to use them:

- [ ] **Dependency Graph** - `domain/dependency.lua` → `arkitekt/core/dependency_graph.lua`
  - Compare APIs, ensure framework version covers all use cases
  - Migrate RegionPlaylist to use framework version
  - Delete local copy

- [ ] **Tree Expander** - `engine/sequence_expander.lua` → `arkitekt/core/tree_expander.lua`
  - Used for: nested playlist → flat sequence expansion
  - Compare implementations

- [ ] **Shuffle** - engine code → `arkitekt/core/shuffle.lua`
  - Fisher-Yates algorithm
  - Check if RegionPlaylist engine can use framework version

- [ ] **Composite Undo** - `data/undo.lua` → `arkitekt/core/composite_undo.lua`
  - Combines app state + REAPER state
  - May have script-specific extensions

---

## Extraction Tasks

### Search/Filter Component
- [ ] **arkitekt/core/filter.lua** - Text filtering utilities
  - Case-insensitive substring matching: `text:lower():find(search, 1, true)`
  - Multi-field search (search name OR tags)
  - Filter predicate composition
  - **Found in**: RegionPlaylist (pool_queries), TemplateBrowser, ItemPicker

### Search Toolbar Widget
- [ ] **arkitekt/gui/widgets/search_toolbar.lua** - Search input with options
  - Input field with clear button
  - Sort mode dropdown
  - Sort direction toggle
  - **Found in**: ItemPicker (search_toolbar.lua), TemplateBrowser

### Notification/Toast System
- [x] **arkitekt/core/notification.lua** - Temporary notifications ✅ **COMPLETED**
  - Timed auto-dismiss
  - Priority levels (error > warning > info/success)
  - Color based on type
  - **Framework implementation**: Based on WalterBuilder (cleanest), with improvements:
    - Built-in `get_status()` adapter for status_bar integration
    - Convenience methods (`:success()`, `:error()`, `:warning()`, `:info()`)
    - Per-type configurable timeouts (errors stay longer)
    - Available in Ark namespace: `Ark.Notification`

### Track Filter (High Value)
- [ ] **arkitekt/gui/widgets/track_filter.lua** - Hierarchical track tree filter
  - Build track tree from REAPER project (folder hierarchy)
  - Whitelist/blacklist with parent inheritance
  - Paint-to-select interaction (left=enable, right=disable)
  - Depth slider for expand/collapse levels
  - "All" / "None" buttons
  - ~780 lines (`track_filter.lua` + `track_filter_bar.lua`)
  - **Found in**: ItemPicker (`ui/components/track_filter.lua`, `track_filter_bar.lua`)
  - **Reuse potential**: Any script needing track-based filtering (RegionPlaylist, TemplateBrowser)

---

## Lower Priority

### Quantize Options
- [ ] **arkitekt/defs/quantize.lua** - Musical quantization values
  - RegionPlaylist-specific but could benefit other music scripts
  - **Found in**: RegionPlaylist (defs/constants.lua)

### Color Generator
- [ ] **arkitekt/core/color_generator.lua** - Deterministic color from ID
  - Hash string → HSL → RGBA
  - **Found in**: RegionPlaylist (pool_queries.lua)

### Duration Formatter
- [ ] **arkitekt/core/duration.lua** - Time formatting
  - Seconds → MM:SS, bars/beats
  - **Found in**: RegionPlaylist, ItemPicker

### Incremental Loader
- [ ] **arkitekt/core/incremental_loader.lua** - Progressive batch loading
  - Process large datasets in small batches per frame (avoid UI blocking)
  - Progress callbacks (`is_complete`, `progress 0-1`)
  - Configurable batch size
  - Hash-based duplicate detection
  - ~650 lines
  - **Found in**: ItemPicker (`data/loaders/incremental_loader.lua`)
  - **Reuse potential**: Any script loading large datasets (templates, samples, items)

### Preset Management System (Framework-Wide)
- [ ] **arkitekt/core/preset_registry.lua** - Central preset management
  - Default presets ship with framework (read-only)
  - User derivations (append, delete, modify without destroying defaults)
  - User-created custom lists
  - Persistence via REAPER ExtState
  - **See**: `TODO/TAGGING_SERVICE.md` for full design
  - **Affects**: Common names (batch rename), wildcards, tags, any future presets

### Action Chip Palette (High Value)
- [ ] **arkitekt/gui/widgets/data/action_chip_palette.lua** - Interactive chip palette
  - Superior design from `batch_rename_modal.lua`
  - Semantic color-coding by category
  - Click-to-insert with modifier keys (Shift, Ctrl)
  - Right-click context menus
  - Automatic flow layout (wrapping)
  - ~200 lines to extract from 983-line modal
  - **Part of**: Preset Management System (uses PresetRegistry for data)
  - **See**: `TODO/TAGGING_SERVICE.md` for full design

### Batch Processor (Configurable)
- [ ] **Make `batch_rename_modal.lua` configurable** - Not a new module, just parameterize existing
  - Enable/disable rename section, recolor section
  - Custom wildcard sets, custom common names presets
  - Already works well - just needs config options for reuse
  - **Maybe later**: add more operations (retag, properties) if needed
  - **Current**: `arkitekt/gui/widgets/overlays/batch_rename_modal.lua` (983 lines)
  - **See**: `TODO/BATCH_PROCESSOR.md` for details

### Notification Service (High Value)
- [x] **arkitekt/core/notification.lua** - Timed status messages with status_bar integration ✅ **COMPLETED**
  - **Based on**: WalterBuilder `domain/notification.lua` (86 lines, cleanest)
  - **Solution**: Framework implementation with built-in status_bar integration
  - Scripts can now migrate from local implementations to framework

  **Implemented unified API:**
  ```lua
  local Notification = require('arkitekt.core.notification')
  local notif = Notification.new({
    timeouts = {info = 3, success = 3, warning = 5, error = 8}
  })

  -- Simple API
  notif:show("Processing...", "info")
  notif:success("Saved 5 regions")
  notif:warning("No items selected")
  notif:error("Failed to load file")

  -- Built-in status_bar adapter
  local status_bar = StatusBar.new({
    get_status = function() return notif:get_status() end,
  })
  ```

  **Current implementations:**
  | Script | File | Lines | Notes |
  |--------|------|-------|-------|
  | WalterBuilder | `domain/notification.lua` | 86 | Generic, clean API, configurable timeouts |
  | RegionPlaylist | `ui/state/notification.lua` | 112 | Domain-specific fields, more coupled |
  | TemplateBrowser | `ui/status.lua` | 49 | UI component with inline logic, no domain |

  **Improvements over WalterBuilder:**
  - `get_status()` adapter built-in for status_bar integration
  - Convenience methods (`:success()`, `:error()`, `:warning()`)
  - Per-type configurable timeouts (errors stay longer)
  - Future: message queue for sequential display

---

## Script Audit Summary

| Script | Uses Framework | Has Local Copy (should migrate) | Extraction Candidates |
|--------|---------------|--------------------------------|----------------------|
| **RegionPlaylist** | sorting, status_bar, drag_visual, marching_ants | dependency, tree_expander, shuffle, undo | notification |
| **TemplateBrowser** | tree_view, drag_drop, marching_ants | - | sorting, status_bar, selection, tags_service |
| **ItemPicker** | marching_ants | sliding_zone (partial) | track_filter, incremental_loader, search_toolbar |
| **ThemeAdjuster** | grid, GridBridge | - | *(domain-specific: param_link_manager, packages)* |
| **WalterBuilder** | button, slider, checkbox, chip | - | notification *(generic 86 lines)* |

### Script-Specific (Not Reusable)

These are domain-specific and unlikely to be extracted:

| Script | Module | Why Not Extract |
|--------|--------|-----------------|
| ThemeAdjuster | `parameter_link_manager.lua` | Theme param linking (slider/spinner types) |
| ThemeAdjuster | `packages/manager.lua` | Theme package management |
| TemplateBrowser | `domain/template/scanner.lua` | REAPER TrackTemplate scanning |
| WalterBuilder | `domain/rtconfig_parser.lua` | Walter theme config parsing |
| WalterBuilder | `domain/simulator.lua` | Theme element simulation |

---

## Next Actions

### Quick Wins (Low Risk)
1. [ ] Migrate TemplateBrowser sorting to `arkitekt/core/sorting.lua`
2. [ ] Migrate ItemPicker sorting to `arkitekt/core/sorting.lua`

### Medium Priority
3. [ ] Migrate TemplateBrowser status bar to framework
4. [ ] Migrate ItemPicker status bar to framework
5. [ ] Audit `gui/interaction/selection.lua` - why unused? API mismatch?

### RegionPlaylist Consolidation
6. [ ] Compare `domain/dependency.lua` vs `core/dependency_graph.lua` - migrate if equivalent
7. [ ] Compare shuffle implementations - migrate if equivalent
8. [ ] Audit tree_expander and composite_undo for migration feasibility

### ItemPicker Migrations
9. [ ] Migrate ItemPicker to use framework `sliding_zone.lua`
   - Framework version is 907 lines, feature-rich
   - Supports: 4 edges, hover trigger, directional retract delays, group coordination
   - ItemPicker has partial local implementation

### Future Extraction
10. [ ] Extract search/filter pattern to `core/filter.lua` after sorting migrations complete
11. [ ] Extract track_filter from ItemPicker (high value, reusable)

---

## New Extraction Candidates (2025-11-27)

### Transport Icon Library (HIGH VALUE - Quick Win)
- [ ] **arkitekt/gui/draw/icon_library.lua** - Generic icon drawing functions
  - **Source**: `RegionPlaylist/ui/views/transport/transport_icons.lua` (312 lines)
  - **Functions**: `draw_play()`, `draw_stop()`, `draw_pause()`, `draw_jump()`, `draw_bolt()`, `draw_gear()`, `draw_tool()`, `draw_timeline()`, `draw_list()`, `draw_close()`
  - **Dependencies**: Only ImGui (clean extraction)
  - **Reuse potential**: Very high - any script needing control/action icons
  - **Effort**: Low (copy + cleanup)

### Animated Button Widget (MEDIUM VALUE)
- [ ] **arkitekt/gui/widgets/primitives/animated_button.lua** - Button with hover animation
  - **Source**: `RegionPlaylist/ui/views/transport/button_widgets.lua` (159 lines)
  - **Features**: Hover color lerp, icon slot, border/background styling
  - **Reuse potential**: Medium - enables animated buttons elsewhere
  - **Effort**: Medium (needs generalization)

### Text Truncation Utility (HIGH VALUE - Critical Consolidation)
- [ ] **arkitekt/core/text_utils.lua** - Centralized text fitting utilities
  - **Problem**: 9+ duplicate implementations across codebase!

  **Framework copies (5):**
  - `gui/renderers/grid.lua:15` - `truncate_text(ctx, text, max_width, ellipsis)`
  - `gui/widgets/base.lua:51` - `truncate_text(ctx, text, max_width, suffix)`
  - `app/chrome/titlebar.lua:116` - `_truncate_text(ctx, text, max_width, font, font_size)`
  - `gui/widgets/media/media_grid/renderers/base.lua:47`
  - `gui/widgets/media/package_tiles/renderer.lua:199`

  **Script copies (4+):**
  - `RegionPlaylist/ui/tiles/renderers/base.lua:138`
  - `RegionPlaylist/ui/views/transport/display_widget.lua:63` (char-based variant)
  - `ItemPicker/ui/grids/renderers/base.lua:54`
  - `TemplateBrowser/ui/tiles/helpers.lua:11`

  **Variations to unify:**
  - Ellipsis: `"…"` vs `"..."`
  - Algorithm: binary search vs linear char count
  - Font handling: some support font push/pop
  - Responsive: one scales chars based on width

  **Proposed unified API:**
  ```lua
  local Text = require('arkitekt.core.text_utils')

  -- Core truncation (binary search, most common)
  Text.truncate(ctx, text, max_width)
  Text.truncate(ctx, text, max_width, {ellipsis = "..."})

  -- Char-based (fixed-width contexts)
  Text.truncate_chars(text, max_chars)
  Text.truncate_chars(text, max_chars, {ellipsis = "…"})

  -- With font (titlebar use case)
  Text.truncate(ctx, text, max_width, {font = font, font_size = 14})

  -- Draw directly to DrawList
  Text.draw_truncated(ctx, dl, x, y, text, max_width, color)
  ```

  - **Effort**: Low-Medium (consolidate existing implementations)
  - **Impact**: High (eliminates 9+ duplicates, single source of truth)

### Easing Functions - UNDERUSED (Migration Needed)
- [ ] **Migrate to `arkitekt/gui/animation/easing.lua`**
  - **Framework provides**: 16 easing functions (linear, quad, cubic, sine, expo, back variants)
  - **Currently used by**: lifecycle.lua, overlay/manager.lua, tab_animator.lua (only 3!)

  **Duplications found:**
  | File | Function | Notes |
  |------|----------|-------|
  | `gui/widgets/media/media_grid/renderers/base.lua:18` | `ease_out_back()` | **Exact duplicate** |
  | `ItemPicker/ui/grids/renderers/base.lua:25` | `ease_out_back()` | **Exact duplicate** |

  - **Effort**: Trivial (add require, delete local function)
  - **Impact**: Removes 2 duplicates, increases framework usage

### Cascade Animation - DUPLICATED (Migration Needed)
- [ ] **Consolidate cascade animation helpers**
  - Both `media_grid` and `ItemPicker` have identical `calculate_cascade_factor()` functions

  **Duplications found:**
  | File | Notes |
  |------|-------|
  | `gui/widgets/media/media_grid/renderers/base.lua:25-44` | Original in framework |
  | `ItemPicker/ui/grids/renderers/base.lua:32-51` | **Near-identical copy** |

  - **Shared**: spawn time tracking, stagger delay, easing application
  - **Option A**: ItemPicker imports from media_grid/renderers/base
  - **Option B**: Extract to shared animation utilities
  - **Effort**: Low
  - **Impact**: Removes duplicate, single source of truth

### Duration Formatting - DUPLICATED
- [ ] **arkitekt/core/duration.lua** - Time duration display
  - **Problem**: Multiple scripts format seconds as `HH:MM:SS` or `MM:SS`

  **Duplications found:**
  | File | Format | Notes |
  |------|--------|-------|
  | `RegionPlaylist/ui/views/transport/display_widget.lua:166` | `%d:%02d:%02d:%02d` | With milliseconds |
  | `ItemPicker/ui/grids/renderers/audio.lua:519-667` | `%d:%02d:%02d` / `%d:%02d` | Dual format |
  | `ItemPicker/ui/grids/renderers/midi.lua:516-520` | `%d:%02d:%02d` / `%d:%02d` | Dual format |

  **Proposed API:**
  ```lua
  local Duration = require('arkitekt.core.duration')
  Duration.format(seconds)                    -- "1:23" or "1:23:45"
  Duration.format(seconds, {ms = true})       -- "1:23:45:123"
  Duration.format(seconds, {always_hours = true})  -- "0:01:23"
  ```

  - **Effort**: Low
  - **Impact**: Removes 3+ duplicates

### Music Time Formatting (LOW-MEDIUM VALUE)
- [ ] **arkitekt/core/music_formatting.lua** - Musical time display
  - **Source**: `RegionPlaylist/ui/tile_utilities.lua` (61 lines)
  - **Function**: Format bar length with musical notation (bars:beats:hundredths)
  - **Reuse potential**: Medium - useful for music-focused scripts
  - **Effort**: Low

### Job Queue (MEDIUM VALUE)
- [ ] **arkitekt/core/job_queue.lua** - Background task processing
  - **Source**: `ItemPicker/data/job_queue.lua` (369 lines)
  - **Features**: Queue jobs, process in batches, progress tracking
  - **Reuse potential**: Medium - useful for heavy async operations
  - **Effort**: Medium (review for generalization)

### Disk Cache Abstraction (LOW-MEDIUM VALUE)
- [ ] **arkitekt/core/disk_cache.lua** - File-based caching
  - **Source**: `ItemPicker/data/disk_cache.lua`
  - **Features**: Cache data to disk, invalidation, size limits
  - **Reuse potential**: Medium - useful for expensive computations
  - **Effort**: Medium

---

## Substantial Systems (100+ lines) - Consolidation Needed

### Undo/History Systems (CRITICAL - 3 COMPETING IMPLEMENTATIONS)

**Problem**: 3 different undo philosophies coexist, with `composite_undo.lua` extracted but unused.

| Implementation | Location | Lines | Approach |
|---------------|----------|-------|----------|
| **Snapshot-based** | `RegionPlaylist/data/undo.lua` | 171 | Captures full state (playlists, regions) |
| **Operation-based** | `TemplateBrowser/infra/undo.lua` | 104 | Stores undo_fn/redo_fn callbacks |
| **State-based** | `arkitekt/core/undo_manager.lua` | 69 | Returns states, no REAPER integration |
| **Composite** | `arkitekt/core/composite_undo.lua` | 161 | **EXTRACTED from RegionPlaylist but UNUSED** |

**Action**: Unify into framework with multi-mode support. RegionPlaylist should migrate to composite_undo.

---

### Keyboard Shortcut Systems (2 PATTERNS)

| Implementation | Location | Lines | Pattern |
|---------------|----------|-------|---------|
| **Inline checks** | `RegionPlaylist/ui/shortcuts.lua` | 86 | Direct `IsKeyPressed()` calls |
| **Declarative table** | `TemplateBrowser/ui/shortcuts.lua` | 209 | `{key, mods, action, description}` format |

**Proposed**: Create `arkitekt/gui/interaction/shortcut_manager.lua`
- Support both inline and declarative patterns
- Auto-generate help dialog from declarative shortcuts
- Modal blocking integration

---

### Search/Filter Systems (VERY HIGH VALUE - DISTRIBUTED)

**Problem**: Search/filter logic scattered across domain, UI, and modals.

| Component | Location | Lines | Purpose |
|-----------|----------|-------|---------|
| **Domain filter** | `RegionPlaylist/app/pool_queries.lua` | 220 | Text search, sorting wrapper |
| **Search UI** | `ItemPicker/ui/components/search_toolbar.lua` | 261 | Input + sort buttons + layout toggle |
| **Filter modal** | `ItemPicker/ui/components/track_filter.lua` | 777 | Tree-based whitelist filtering |

**Proposed extraction**:
1. `arkitekt/core/search_filter.lua` - Pure search/filter logic
2. `arkitekt/gui/widgets/search_toolbar.lua` - Reusable search input with sort
3. `arkitekt/gui/widgets/modals/filter_tree_modal.lua` - Whitelist tree UI

---

### Persistence/Settings (4 DIFFERENT APPROACHES)

| Approach | Location | Lines | Backend |
|----------|----------|-------|---------|
| **File-based** | `arkitekt/core/settings.lua` | 159 | JSON file in /cache/ |
| **Project state** | `ItemPicker/data/persistence.lua` | 160 | `GetProjExtState()` |
| **Domain object** | `RegionPlaylist/ui/state/preferences.lua` | 176 | Wraps Settings |
| **Inline ExtState** | `batch_rename_modal.lua:33-90` | 57 | Raw REAPER API |

**Proposed**: Create abstraction layer supporting all three backends:
```lua
local Persistence = require('arkitekt.core.persistence')
local store = Persistence.file("app_name")  -- JSON file
local store = Persistence.project("app_name")  -- Project state
local store = Persistence.extstate("SECTION")  -- Global REAPER state
```

---

### Modal Dialog Patterns (5+ IMPLEMENTATIONS)

**Problem**: Each app rolls its own modals.

| Modal | Location | Lines |
|-------|----------|-------|
| **Batch rename** | `arkitekt/gui/widgets/overlays/batch_rename_modal.lua` | 982 |
| **Package modal** | `ThemeAdjuster/ui/views/package_modal.lua` | 1036 |
| **Template modals** | `TemplateBrowser/ui/views/template_modals_view.lua` | 486 |
| **Param link** | `ThemeAdjuster/ui/views/param_link_modal.lua` | 244 |
| **Overflow** | `RegionPlaylist/ui/views/overflow_modal_view.lua` | 212 |

**Proposed**:
1. `arkitekt/gui/widgets/overlays/modal_base.lua` - Common modal structure
2. `arkitekt/gui/widgets/overlays/confirm_dialog.lua` - Simple OK/Cancel
3. `arkitekt/gui/widgets/overlays/input_dialog.lua` - Text input with validation

---

## Substantial Systems Priority

| # | System | Size | Duplicates | Effort | Value |
|---|--------|------|------------|--------|-------|
| 1 | **Search/Filter** | 1200+ lines | Distributed | High | **Very High** |
| 2 | **Undo Systems** | 500+ lines | 3 approaches | Medium | **High** |
| 3 | **Persistence** | 600+ lines | 4 approaches | Medium | **High** |
| 4 | **Modals** | 3000+ lines | Per-app | High | High |
| 5 | **Shortcuts** | 300 lines | 2 patterns | Low | Medium-High |

---

## Pattern Documentation (No Code Extraction)

### Renderer Factory Pattern
- [ ] **cookbook/RENDERER_PATTERN.md** - Document common renderer pattern
  - **Found in**: ItemPicker (3 renderers), RegionPlaylist (3 renderers), TemplateBrowser (tile renderers), ThemeAdjuster (5+ renderers), WalterBuilder (2 renderers)
  - **Pattern**: `M.draw(ctx, data, config) → result`
  - **Value**: Consistency, easier onboarding
  - **No code extraction** - too app-specific, but pattern should be documented

---

## Quick Win Priority List

| # | Task | Effort | Value | Duplicates |
|---|------|--------|-------|------------|
| 1 | **Consolidate text truncation** | Low-Med | **Critical** | 9+ copies |
| 2 | Extract transport icons | Low | High | 1 |
| 3 | Migrate TemplateBrowser sorting | Low | Medium | - |
| 4 | Migrate ItemPicker sorting | Low | Medium | - |
| 5 | Extract music time formatting | Low | Low-Med | 1 |

---

## Underutilized Framework Components (2025-11-27 Audit)

These framework utilities exist but scripts duplicate them locally instead of importing.

### Math Utilities - `arkitekt/core/math.lua` (UNDERUSED)

**Framework provides:**
```lua
local Math = require('arkitekt.core.math')
Math.lerp(a, b, t)         -- Linear interpolation
Math.clamp(value, min, max) -- Clamp to range
Math.remap(value, in_min, in_max, out_min, out_max)
Math.snap(value, step)      -- Snap to grid
Math.smoothdamp(...)        -- Smooth movement
Math.approximately(a, b, epsilon)
```

**Current usage**: Only 6 files use it (animation.lua, hue_slider.lua, tracks.lua, base.lua, manager.lua, sliding_zone.lua)

**Duplications found:**
| File | Function | Notes |
|------|----------|-------|
| `ThemeAdjuster/ui/grids/renderers/tile_visuals.lua:153` | `M.lerp(a, b, t)` | Exact duplicate |
| `ThemeAdjuster/ui/grids/renderers/tile_visuals.lua:134` | `M.color_lerp(c1, c2, t)` | Should use Colors.lerp |
| `scripts/demos/widget_demo.lua:64` | `clamp(x, a, b)` | Inline function |
| `RegionPlaylist/ui/views/transport/button_widgets.lua:114` | `ViewModeButton:lerp_color()` | Should use Colors.lerp |
| `RegionPlaylist/ui/views/transport/transport_container.lua:172` | `lerp_color()` | Should use Colors.lerp |

**Action**: Migrate scripts to use `arkitekt.core.math` or `arkitekt.core.colors` (for color lerp)

---

### UUID - `arkitekt/core/uuid.lua` (UNDERUSED)

**Framework provides:**
```lua
local UUID = require('arkitekt.core.uuid')
UUID.generate()   -- Returns "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
UUID.is_valid(uuid)  -- Validates format
```

**Current usage**: Only 2 files use it (region_operations.lua, RegionPlaylist/app/state.lua)

**Duplications found:**
| File | Notes |
|------|-------|
| `TemplateBrowser/infra/storage.lua:52-60` | **Exact duplicate** of generate() function! |

**Action**: Migrate TemplateBrowser to use `arkitekt.core.uuid`

---

### JSON - `arkitekt/core/json.lua` (PARTIALLY USED)

**Framework provides:**
```lua
local JSON = require('arkitekt.core.json')
JSON.encode(table)    -- Table → JSON string
JSON.decode(string)   -- JSON string → table
```

**Current usage**: 7 files use it (project_state, ItemPicker persistence/disk_cache, ThemeAdjuster mapper/manager, MediaContainer, settings)

**Duplications found:**
| File | Lines | Notes |
|------|-------|-------|
| `TemplateBrowser/infra/storage.lua:62-190` | ~130 | **Complete JSON encoder/decoder** with pretty printing |

**Action**: Migrate TemplateBrowser to use `arkitekt.core.json` (add pretty-print option if needed)

---

### File Utilities - MISSING FROM FRAMEWORK (Extraction Needed)

**Problem**: Multiple scripts implement the same file utilities:

| Utility | ThemeAdjuster | WalterBuilder | fonts.lua | packages/manager |
|---------|---------------|---------------|-----------|------------------|
| `file_exists(path)` | ✅ line 9 | ✅ line 29 | ✅ line 10 | ✅ line 340 |
| `dir_exists(path)` | ✅ line 10 | ✅ line 39 | ❌ | ✅ line 558 |
| `read_text(path)` | ✅ line 11 | ❌ | ❌ | ❌ |
| `write_text(path, s)` | ✅ line 12 | ❌ | ❌ | ❌ |
| `dirname(path)` | ✅ line 13 | ❌ | ❌ | ❌ |
| `basename_no_ext(path)` | ✅ line 14 | ❌ | ❌ | ❌ |
| `join(a, b)` | ✅ line 8 | ❌ | ❌ | ❌ |
| `list_files(dir, ext)` | ✅ line 17 | ❌ | ❌ | ❌ |
| `list_files_recursive()` | ✅ line 27 | ❌ | ❌ | ❌ |
| `list_subdirs(dir)` | ✅ line 37 | ❌ | ❌ | ❌ |

**Best source**: `ThemeAdjuster/core/theme.lua` lines 8-44 (most complete)

**Proposed extraction**: `arkitekt/core/file_utils.lua`
```lua
local File = require('arkitekt.core.file_utils')

-- Basic operations
File.exists(path)        -- io.open check
File.dir_exists(path)    -- reaper.EnumerateFiles check
File.read(path)          -- Read entire file
File.write(path, content) -- Write entire file

-- Path manipulation
File.join(a, b)          -- Platform-aware path join
File.dirname(path)       -- Get directory part
File.basename(path)      -- Get filename
File.basename_no_ext(path) -- Get filename without extension
File.extension(path)     -- Get extension

-- Directory listing
File.list(dir, ext)      -- List files (optional extension filter)
File.list_recursive(dir, ext)  -- Recursive file listing
File.list_subdirs(dir)   -- List subdirectories
```

**Effort**: Medium (consolidate from ThemeAdjuster)
**Value**: High (eliminates 4+ duplications, standardizes file ops)

---

### Colors - `arkitekt/core/colors.lua` (WELL ADOPTED but with gaps)

**Framework provides** (732 lines, comprehensive):
- `Colors.lerp(color_a, color_b, t)` - Color interpolation
- `Colors.hexrgb("#RRGGBB")` - Parse hex strings
- `Colors.adjust_brightness()`, `Colors.desaturate()`, etc.
- HSL/HSV conversions
- Palette generation

**Current usage**: 95+ files use it (excellent adoption!)

**Gaps found**:
- ThemeAdjuster's `tile_visuals.lua` has its own `color_lerp()` instead of using `Colors.lerp()`

---

## Updated Quick Win Priority List

| # | Task | Effort | Value | Duplicates | Status |
|---|------|--------|-------|------------|--------|
| 1 | **Consolidate text truncation** | Low-Med | **Critical** | 9+ copies | |
| 2 | **Migrate TemplateBrowser to core/uuid** | **Trivial** | Medium | 1 exact copy | |
| 3 | **Migrate TemplateBrowser to core/json** | Low | Medium | 1 copy (130 lines) | |
| 4 | **Migrate ease_out_back to Easing** | **Trivial** | Low | 2 exact copies | |
| 5 | **Extract file utilities** | Medium | High | 4+ copies | |
| 6 | **Migrate lerp/clamp usage to core/math** | Low | Medium | 5+ copies | |
| 7 | **Consolidate cascade animation** | Low | Medium | 2 copies | |
| 8 | **Extract duration formatting** | Low | Medium | 3+ copies | |
| 9 | Extract transport icons | Low | High | 1 | |
| 10 | Migrate TemplateBrowser sorting | Low | Medium | - | |
| 11 | Migrate ItemPicker sorting | Low | Medium | - | |

---

## Discovery Commands

```bash
# Find what framework components exist
ls arkitekt/gui/interaction/
ls arkitekt/gui/widgets/
ls arkitekt/app/chrome/

# Check if scripts use framework components
grep -r "require.*interaction" scripts/
grep -r "require.*chrome" scripts/

# Find reimplemented patterns
grep -r "selected.*=" scripts/*/
grep -r "\.find.*true" scripts/*/  # Text search pattern
```

---

*Last updated: 2025-11-27*
