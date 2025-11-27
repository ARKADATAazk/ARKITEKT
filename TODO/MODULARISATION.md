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
| **Reorder** | `gui/interaction/reorder.lua` | ? | Audit needed |

### ⚠️ Exists but UNUSED

| Component | Location | Notes |
|-----------|----------|-------|
| **Selection** | `gui/interaction/selection.lua` | Full API (single, toggle, range). NO script uses it! |
| **Selection Rectangle** | `gui/widgets/data/selection_rectangle.lua` | Visual component |
| **Marching Ants** | `gui/interaction/marching_ants.lua` | Selection visual |
| **Blocking** | `gui/interaction/blocking.lua` | Modal blocking |

### ❌ Needs Extraction

| Component | Target Location | Found In |
|-----------|-----------------|----------|
| Search/Filter | `core/filter.lua` | All scripts |
| Search Toolbar | `gui/widgets/search_toolbar.lua` | ItemPicker, TemplateBrowser |
| Notification/Toast | `gui/widgets/notification.lua` | RegionPlaylist, TemplateBrowser |

---

## Migration Tasks

### High Priority: Use Existing Components

#### Selection Manager Migration
- [ ] **Migrate scripts to use `arkitekt/gui/interaction/selection.lua`**
  - Framework has full implementation with single/toggle/range select
  - RegionPlaylist: ❌ Reimplements selection in tiles/coordinator
  - TemplateBrowser: ❌ Reimplements in app/state.lua
  - ItemPicker: ❌ Reimplements in app_state.lua
  - **Action**: Audit each script's selection needs, migrate to framework

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
- [ ] **arkitekt/gui/widgets/notification.lua** - Temporary notifications
  - Timed auto-dismiss
  - Priority levels (error > warning > info)
  - **Found in**: RegionPlaylist (ui/state/notification.lua)

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
- [ ] **arkitekt/core/incremental_loader.lua** - Progressive loading
  - Batch processing with progress callbacks
  - **Found in**: ItemPicker (data/loaders/incremental_loader.lua)

---

## Script Audit Summary

| Script | Uses Framework | Reimplements |
|--------|---------------|--------------|
| **RegionPlaylist** | sorting, status_bar, drag_visual | selection |
| **TemplateBrowser** | drag_drop | sorting, status_bar, selection |
| **ItemPicker** | - | sorting, status_bar, selection, drag |
| **ThemeAdjuster** | ? | ? |
| **WalterBuilder** | ? | ? |

---

## Next Actions

1. [ ] Migrate TemplateBrowser sorting to `arkitekt/core/sorting.lua`
2. [ ] Migrate ItemPicker sorting to `arkitekt/core/sorting.lua`
3. [ ] Audit why `gui/interaction/selection.lua` is unused - API mismatch?
4. [ ] Migrate TemplateBrowser status bar to framework
5. [ ] Migrate ItemPicker status bar to framework
6. [ ] Extract search/filter pattern after sorting migrations complete

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
