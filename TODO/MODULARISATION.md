# Modularisation TODO

> Track opportunities to extract reusable components from scripts into the framework.
> This is an evolving document - update it as you discover new patterns.

## Status Legend
- [ ] Not started
- [~] In progress
- [x] Completed

---

## Recently Completed

### Sorting Module
- [x] **arkitekt/core/sorting.lua** - Extracted from RegionPlaylist
  - Built-in comparators: alpha, index, length, color (hue-based)
  - `Sorting.apply(list, {mode, direction, get_value})`
  - Custom comparator registration
  - **Consumers**: RegionPlaylist (migrated), TemplateBrowser (pending), ItemPicker (pending)

---

## High Priority (Common across 3+ scripts)

### Search/Filter Component
- [ ] **arkitekt/core/filter.lua** - Text filtering utilities
  - Case-insensitive substring matching
  - Multi-field search (name, tags, etc.)
  - Filter predicate composition
  - **Found in**: RegionPlaylist, TemplateBrowser, ItemPicker
  - **Pattern**: `search:lower():find(text, 1, true)`

### Selection Manager
- [ ] **arkitekt/gui/interaction/selection.lua** - Selection state management
  - Single/multi-select modes
  - Shift-click range selection
  - Ctrl-click toggle selection
  - Selection persistence
  - **Found in**: RegionPlaylist (tiles), TemplateBrowser (templates, folders), ItemPicker (items)

### Drag Handler
- [ ] **arkitekt/gui/interaction/drag_handler.lua** - Drag operation management
  - Drag threshold detection
  - Drag preview rendering
  - Drop target validation
  - Operation types (move, copy, reorder)
  - **Found in**: ItemPicker (ui/components/drag_handler.lua), RegionPlaylist (tiles)

### Status Bar Migration
- [ ] **Migrate scripts to use arkitekt/app/chrome/status_bar.lua**
  - Framework component already exists with full features
  - RegionPlaylist: ✅ Already uses it (just provides `get_status` callback)
  - TemplateBrowser: ❌ Reimplements with raw ImGui - needs migration
  - ItemPicker: ❌ Reimplements with raw ImGui - needs migration
  - **Pattern**: Script provides `get_status()` callback, framework handles rendering

---

## Medium Priority (Common across 2 scripts)

### Search Toolbar Widget
- [ ] **arkitekt/gui/widgets/search_toolbar.lua** - Search input with options
  - Clear button
  - Search mode dropdown
  - Sort mode dropdown
  - Sort direction toggle
  - **Found in**: ItemPicker (search_toolbar.lua), TemplateBrowser

### Pool/Grid Query Pattern
- [ ] **arkitekt/core/pool_query.lua** - Generic pool query builder
  - Filter → Sort → Paginate pipeline
  - Memoization for expensive queries
  - **Found in**: RegionPlaylist (pool_queries.lua), ItemPicker (grid_factory_shared.lua)

### Tile/Grid Coordinator Pattern
- [ ] **arkitekt/gui/grids/coordinator.lua** - Grid rendering coordinator
  - Tile factory pattern
  - Renderer delegation
  - Layout calculation
  - **Found in**: RegionPlaylist (tiles/coordinator.lua), ItemPicker (grids/coordinator.lua)

### Notification/Toast System
- [ ] **arkitekt/gui/widgets/notification.lua** - Temporary notifications
  - Timed auto-dismiss
  - Stacking multiple notifications
  - Animation support
  - **Found in**: RegionPlaylist (ui/state/notification.lua), TemplateBrowser

---

## Lower Priority (Script-specific but generalizable)

### Quantize Options
- [ ] **arkitekt/defs/quantize.lua** - Musical quantization values
  - Bar-based options (4bar, 2bar, measure)
  - Beat divisions (1/4, 1/8, etc.)
  - Label generation
  - **Found in**: RegionPlaylist (defs/constants.lua QUANTIZE_OPTIONS)

### Color Picker/Generator
- [ ] **arkitekt/core/color_generator.lua** - Deterministic color generation
  - Hash-based color from ID/string
  - Palette generation
  - **Found in**: RegionPlaylist (pool_queries.lua deterministic_color_from_id)

### Duration Formatter
- [ ] **arkitekt/core/duration.lua** - Time/duration formatting
  - Seconds to MM:SS
  - Seconds to bars/beats
  - Human-readable durations
  - **Found in**: RegionPlaylist (transport display), ItemPicker

### Incremental Loader
- [ ] **arkitekt/core/incremental_loader.lua** - Progressive data loading
  - Batch processing
  - Progress callbacks
  - Cancellation support
  - **Found in**: ItemPicker (data/loaders/incremental_loader.lua)

---

## Patterns to Watch For

When reviewing scripts, look for these extraction opportunities:

1. **Repeated utility functions** - Same helper appearing in multiple files
2. **Copy-pasted logic** - Similar code blocks across scripts
3. **UI patterns** - Widgets/components that could be shared
4. **State patterns** - Common state management approaches
5. **Data patterns** - Similar data structures or transformations

---

## Script Inventory

### RegionPlaylist (47 files)
- **Unique**: Playback engine, sequence expansion, nested playlists
- **Extractable**: Sorting (done), selection, drag-drop, status bar

### TemplateBrowser
- **Unique**: Template scanning, folder tree, metadata management
- **Extractable**: Search toolbar, multi-select folders, sorting

### ItemPicker
- **Unique**: Item pool scanning, audio/MIDI grids, region filtering
- **Extractable**: Drag handler, search toolbar, incremental loader, sorting

### ThemeAdjuster
- **Unique**: Theme color editing, live preview
- **Extractable**: Color utilities

### WalterBuilder
- **Unique**: Custom window building
- **Extractable**: Layout builder patterns

### ColorPalette
- **Unique**: Color palette management
- **Extractable**: Palette storage format

---

## How to Extract a Component

1. **Identify** the pattern across scripts
2. **Compare** implementations to find common interface
3. **Design** API that works for all use cases
4. **Create** module in appropriate arkitekt/ location
5. **Migrate** one script as reference implementation
6. **Document** in cookbook/
7. **Update** this TODO with status
8. **Migrate** remaining scripts

---

## Next Actions

1. [ ] Migrate TemplateBrowser to use arkitekt/core/sorting.lua
2. [ ] Migrate ItemPicker to use arkitekt/core/sorting.lua
3. [ ] Extract search/filter pattern
4. [ ] Extract selection manager

---

*Last updated: 2025-11-27*
