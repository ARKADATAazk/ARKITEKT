# Script Migration Plans

> Overview of migration patterns for restructuring ARKITEKT scripts.
>
> **Detailed per-script plans are in `TODO/scriptRefacto/`** - that's the source of truth for file-by-file migration steps. This doc provides the overview and target architecture.

## Table of Contents

1. [Target Architecture](#target-architecture)
2. [TemplateBrowser Migration](#templatebrowser-migration) ⬅ **START HERE**
3. [ItemPicker Migration](#itempicker-migration)
4. [ThemeAdjuster Migration](#themeadjuster-migration)
5. [RegionPlaylist Migration](#regionplaylist-migration)
6. [Cross-Script Comparison](#cross-script-comparison)

---

## Target Architecture

All scripts follow this canonical structure (see [SCRIPT_LAYERS.md](./SCRIPT_LAYERS.md) for the pragmatic approach):

```
[ScriptName]/
├── app/              # Application bootstrap, config, state container
│   ├── init.lua      # Dependency injection, startup sequence
│   └── state.lua     # Central state container (simplified)
│
├── domain/           # Business logic (can use reaper.* in scripts)
│   ├── [entity]/     # Grouped by business entity
│   │   ├── model.lua     # Data structures
│   │   ├── service.lua   # Business operations
│   │   └── repository.lua # Data access abstraction
│   └── ...
│
├── data/          # Persistence (ExtState, JSON)
│   ├── persistence.lua
│   └── undo.lua      # Undo system bridge
│
├── ui/               # Presentation layer
│   ├── init.lua      # Main GUI orchestrator
│   ├── state/        # UI-only state (animations, preferences)
│   ├── views/        # View components
│   └── ...
│
├── defs/             # Static definitions (constants, defaults, strings)
└── tests/            # Test files (integration tests in REAPER)
```

### Key Principles

| Principle | Description |
|-----------|-------------|
| **Separation of Concerns** | Domain logic grouped by concept |
| **Dependency Direction** | `ui/` → `domain/` → `data/` |
| **State Simplification** | `app/state.lua` is a container, not business logic |
| **UI State Isolation** | Animation, preferences → `ui/state/` |
| **Pragmatic Purity** | Scripts can use `reaper.*` in domain (see SCRIPT_LAYERS.md) |

---

## TemplateBrowser Migration

> **Priority: 1st** | **Effort: Low** | **Status: Reference Implementation**
>
> See `TODO/scriptRefacto/TemplateBrowser/` for detailed migration steps.

### Current Structure (39 files)

```
TemplateBrowser/
├── ARK_TemplateBrowser.lua          # Entry point
├── core/                            # ❌ Mixed concerns - needs splitting
│   ├── config.lua                   # → app/config.lua
│   ├── state.lua                    # → app/state.lua (simplified)
│   ├── shortcuts.lua                # → ui/shortcuts.lua (UI concern)
│   └── tooltips.lua                 # → ui/tooltips.lua (UI concern)
│
├── domain/                          # ✓ Exists but needs reorganization
│   ├── fx_parser.lua                # → domain/fx/parser.lua
│   ├── fx_queue.lua                 # → domain/fx/queue.lua
│   ├── scanner.lua                  # → domain/template/scanner.lua
│   ├── template_ops.lua             # → domain/template/ops.lua
│   ├── tags.lua                     # → domain/tags/service.lua
│   ├── file_ops.lua                 # → infra/file_ops.lua (I/O!)
│   ├── persistence.lua              # → infra/storage.lua (I/O!)
│   └── undo.lua                     # → infra/undo.lua (I/O!)
│
├── defs/                            # ✓ Keep as-is
│   ├── constants.lua
│   ├── defaults.lua
│   └── strings.lua
│
├── ui/
│   ├── gui.lua                      # → ui/init.lua
│   ├── status_bar.lua               # → ui/status.lua
│   ├── ui_constants.lua             # → ui/config/constants.lua
│   ├── left_panel_config.lua        # → ui/config/left_panel.lua
│   ├── template_container_config.lua # → ui/config/template.lua
│   ├── info_panel_config.lua        # → ui/config/info.lua
│   ├── convenience_panel_config.lua # → ui/config/convenience.lua
│   ├── recent_panel_config.lua      # → ui/config/recent.lua
│   ├── tiles/
│   │   ├── template_grid_factory.lua # → ui/tiles/factory.lua
│   │   ├── template_tile.lua         # → ui/tiles/tile.lua
│   │   └── template_tile_compact.lua # → ui/tiles/tile_compact.lua
│   └── views/
│       ├── helpers.lua
│       ├── tree_view.lua            # → ui/views/tree.lua
│       ├── left_panel_view.lua      # → ui/views/left_panel/init.lua
│       ├── template_panel_view.lua  # → ui/views/template_panel.lua
│       ├── info_panel_view.lua      # → ui/views/info_panel.lua
│       ├── convenience_panel_view.lua # → ui/views/convenience/init.lua
│       ├── template_modals_view.lua # → ui/views/modals/template.lua
│       ├── left_panel/
│       │   ├── directory_tab.lua    # Keep path
│       │   ├── tags_tab.lua         # Keep path
│       │   └── vsts_tab.lua         # Keep path
│       └── convenience_panel/
│           ├── tags_tab.lua         # Keep path
│           └── vsts_tab.lua         # Keep path
```

### Target Structure

```
TemplateBrowser/
├── ARK_TemplateBrowser.lua          # Entry point (minimal, calls app/init)
│
├── app/
│   ├── init.lua                     # NEW: Bootstrap, dependency injection
│   ├── config.lua                   # FROM: core/config.lua
│   └── state.lua                    # FROM: core/state.lua (simplified)
│
├── domain/
│   ├── template/
│   │   ├── scanner.lua              # FROM: domain/scanner.lua
│   │   └── ops.lua                  # FROM: domain/template_ops.lua
│   ├── tags/
│   │   └── service.lua              # FROM: domain/tags.lua
│   └── fx/
│       ├── parser.lua               # FROM: domain/fx_parser.lua
│       └── queue.lua                # FROM: domain/fx_queue.lua
│
├── infra/
│   ├── storage.lua                  # FROM: domain/persistence.lua
│   ├── undo.lua                     # FROM: domain/undo.lua
│   └── file_ops.lua                 # FROM: domain/file_ops.lua
│
├── ui/
│   ├── init.lua                     # FROM: ui/gui.lua
│   ├── shortcuts.lua                # FROM: core/shortcuts.lua
│   ├── tooltips.lua                 # FROM: core/tooltips.lua
│   ├── status.lua                   # FROM: ui/status_bar.lua
│   │
│   ├── state/
│   │   └── preferences.lua          # NEW: Extract UI prefs from state.lua
│   │
│   ├── config/
│   │   ├── constants.lua            # FROM: ui/ui_constants.lua
│   │   ├── left_panel.lua           # FROM: ui/left_panel_config.lua
│   │   ├── template.lua             # FROM: ui/template_container_config.lua
│   │   ├── info.lua                 # FROM: ui/info_panel_config.lua
│   │   ├── convenience.lua          # FROM: ui/convenience_panel_config.lua
│   │   └── recent.lua               # FROM: ui/recent_panel_config.lua
│   │
│   ├── views/
│   │   ├── helpers.lua              # Keep
│   │   ├── tree.lua                 # FROM: ui/views/tree_view.lua
│   │   ├── template_panel.lua       # FROM: ui/views/template_panel_view.lua
│   │   ├── info_panel.lua           # FROM: ui/views/info_panel_view.lua
│   │   ├── left_panel/
│   │   │   ├── init.lua             # FROM: ui/views/left_panel_view.lua
│   │   │   ├── directory.lua        # FROM: directory_tab.lua
│   │   │   ├── tags.lua             # FROM: tags_tab.lua
│   │   │   └── vsts.lua             # FROM: vsts_tab.lua
│   │   ├── convenience/
│   │   │   ├── init.lua             # FROM: ui/views/convenience_panel_view.lua
│   │   │   ├── tags.lua             # FROM: tags_tab.lua
│   │   │   └── vsts.lua             # FROM: vsts_tab.lua
│   │   └── modals/
│   │       └── template.lua         # FROM: ui/views/template_modals_view.lua
│   │
│   └── tiles/
│       ├── factory.lua              # FROM: template_grid_factory.lua
│       ├── tile.lua                 # FROM: template_tile.lua
│       └── tile_compact.lua         # FROM: template_tile_compact.lua
│
├── defs/                            # UNCHANGED
│   ├── constants.lua
│   ├── defaults.lua
│   └── strings.lua
│
└── tests/                           # NEW: Add test structure
    ├── domain/
    │   ├── template_test.lua
    │   ├── tags_test.lua
    │   └── fx_test.lua
    └── infra/
        └── storage_test.lua
```

### Step-by-Step Migration

#### Phase 1: Create New Folder Structure

```bash
# Create new directories
mkdir -p TemplateBrowser/app
mkdir -p TemplateBrowser/infra
mkdir -p TemplateBrowser/domain/template
mkdir -p TemplateBrowser/domain/tags
mkdir -p TemplateBrowser/domain/fx
mkdir -p TemplateBrowser/ui/state
mkdir -p TemplateBrowser/ui/config
mkdir -p TemplateBrowser/ui/views/modals
mkdir -p TemplateBrowser/tests/domain
mkdir -p TemplateBrowser/tests/infra
```

#### Phase 2: Move Files (with backward-compat re-exports)

**Step 2.1: Create `app/` folder**

| Action | File | Notes |
|--------|------|-------|
| CREATE | `app/init.lua` | Bootstrap, require all modules |
| MOVE | `core/config.lua` → `app/config.lua` | Update requires |
| MOVE | `core/state.lua` → `app/state.lua` | Simplify, extract UI state |
| ADD RE-EXPORT | `core/config.lua` | `return require("TemplateBrowser.app.config")` |
| ADD RE-EXPORT | `core/state.lua` | `return require("TemplateBrowser.app.state")` |

**Step 2.2: Create `infra/` folder (I/O operations)**

| Action | File | Notes |
|--------|------|-------|
| MOVE | `domain/persistence.lua` → `infra/storage.lua` | Rename to match convention |
| MOVE | `domain/undo.lua` → `infra/undo.lua` | Keep name |
| MOVE | `domain/file_ops.lua` → `infra/file_ops.lua` | Keep name |
| ADD RE-EXPORT | `domain/persistence.lua` | `return require("TemplateBrowser.infra.storage")` |
| ADD RE-EXPORT | `domain/undo.lua` | `return require("TemplateBrowser.infra.undo")` |
| ADD RE-EXPORT | `domain/file_ops.lua` | `return require("TemplateBrowser.infra.file_ops")` |

**Step 2.3: Reorganize `domain/` folder**

| Action | File | Notes |
|--------|------|-------|
| MOVE | `domain/scanner.lua` → `domain/template/scanner.lua` | |
| MOVE | `domain/template_ops.lua` → `domain/template/ops.lua` | |
| MOVE | `domain/tags.lua` → `domain/tags/service.lua` | |
| MOVE | `domain/fx_parser.lua` → `domain/fx/parser.lua` | |
| MOVE | `domain/fx_queue.lua` → `domain/fx/queue.lua` | |
| ADD RE-EXPORT | `domain/scanner.lua` | `return require("TemplateBrowser.domain.template.scanner")` |
| ADD RE-EXPORT | `domain/template_ops.lua` | `return require("TemplateBrowser.domain.template.ops")` |
| ADD RE-EXPORT | `domain/tags.lua` | `return require("TemplateBrowser.domain.tags.service")` |
| ADD RE-EXPORT | `domain/fx_parser.lua` | `return require("TemplateBrowser.domain.fx.parser")` |
| ADD RE-EXPORT | `domain/fx_queue.lua` | `return require("TemplateBrowser.domain.fx.queue")` |

**Step 2.4: Move UI-concern files from `core/` to `ui/`**

| Action | File | Notes |
|--------|------|-------|
| MOVE | `core/shortcuts.lua` → `ui/shortcuts.lua` | UI concern |
| MOVE | `core/tooltips.lua` → `ui/tooltips.lua` | UI concern |
| ADD RE-EXPORT | `core/shortcuts.lua` | `return require("TemplateBrowser.ui.shortcuts")` |
| ADD RE-EXPORT | `core/tooltips.lua` | `return require("TemplateBrowser.ui.tooltips")` |

**Step 2.5: Reorganize `ui/` folder**

| Action | File | Notes |
|--------|------|-------|
| MOVE | `ui/gui.lua` → `ui/init.lua` | Main orchestrator |
| MOVE | `ui/status_bar.lua` → `ui/status.lua` | Simplify name |
| MOVE | `ui/ui_constants.lua` → `ui/config/constants.lua` | |
| MOVE | `ui/left_panel_config.lua` → `ui/config/left_panel.lua` | |
| MOVE | `ui/template_container_config.lua` → `ui/config/template.lua` | |
| MOVE | `ui/info_panel_config.lua` → `ui/config/info.lua` | |
| MOVE | `ui/convenience_panel_config.lua` → `ui/config/convenience.lua` | |
| MOVE | `ui/recent_panel_config.lua` → `ui/config/recent.lua` | |
| ADD RE-EXPORT | All old locations | Point to new locations |

**Step 2.6: Reorganize `ui/views/`**

| Action | File | Notes |
|--------|------|-------|
| MOVE | `views/tree_view.lua` → `views/tree.lua` | Remove `_view` suffix |
| MOVE | `views/left_panel_view.lua` → `views/left_panel/init.lua` | |
| MOVE | `views/template_panel_view.lua` → `views/template_panel.lua` | |
| MOVE | `views/info_panel_view.lua` → `views/info_panel.lua` | |
| MOVE | `views/convenience_panel_view.lua` → `views/convenience/init.lua` | |
| MOVE | `views/template_modals_view.lua` → `views/modals/template.lua` | |
| RENAME | `left_panel/directory_tab.lua` → `left_panel/directory.lua` | |
| RENAME | `left_panel/tags_tab.lua` → `left_panel/tags.lua` | |
| RENAME | `left_panel/vsts_tab.lua` → `left_panel/vsts.lua` | |
| RENAME | `convenience_panel/tags_tab.lua` → `convenience/tags.lua` | |
| RENAME | `convenience_panel/vsts_tab.lua` → `convenience/vsts.lua` | |

**Step 2.7: Reorganize `ui/tiles/`**

| Action | File | Notes |
|--------|------|-------|
| MOVE | `tiles/template_grid_factory.lua` → `tiles/factory.lua` | |
| MOVE | `tiles/template_tile.lua` → `tiles/tile.lua` | |
| MOVE | `tiles/template_tile_compact.lua` → `tiles/tile_compact.lua` | |

#### Phase 3: Update All Requires

Update all `require()` statements to use new paths. Example:

```lua
-- OLD
local Persistence = require("TemplateBrowser.domain.persistence")

-- NEW
local Storage = require("TemplateBrowser.infra.storage")
```

#### Phase 4: Create New Files

**`app/init.lua`** - Bootstrap file:

```lua
--- TemplateBrowser Application Bootstrap
-- @module TemplateBrowser.app.init

local M = {}

-- Load configuration
M.config = require("TemplateBrowser.app.config")

-- Initialize state
M.state = require("TemplateBrowser.app.state")

-- Domain services
M.template = {
    scanner = require("TemplateBrowser.domain.template.scanner"),
    ops = require("TemplateBrowser.domain.template.ops"),
}
M.tags = require("TemplateBrowser.domain.tags.service")
M.fx = {
    parser = require("TemplateBrowser.domain.fx.parser"),
    queue = require("TemplateBrowser.domain.fx.queue"),
}

-- Infrastructure
M.infra = {
    storage = require("TemplateBrowser.infra.storage"),
    undo = require("TemplateBrowser.infra.undo"),
    file_ops = require("TemplateBrowser.infra.file_ops"),
}

return M
```

**`ui/state/preferences.lua`** - UI-only state:

```lua
--- UI Preferences State
-- @module TemplateBrowser.ui.state.preferences

local M = {}

-- Extract UI-specific state from app/state.lua
M.defaults = {
    left_panel_tab = "directory",
    separator1_ratio = 0.20,
    separator2_ratio = 0.75,
    show_compact_tiles = false,
}

return M
```

#### Phase 5: Cleanup

After confirming everything works:

1. Delete empty `core/` folder
2. Remove re-export shims (or keep for external compatibility)
3. Update `ARK_TemplateBrowser.lua` entry point to use `app/init.lua`

### File Migration Checklist

| # | Current Path | New Path | Status |
|---|--------------|----------|--------|
| 1 | `core/config.lua` | `app/config.lua` | ⬜ |
| 2 | `core/state.lua` | `app/state.lua` | ⬜ |
| 3 | `core/shortcuts.lua` | `ui/shortcuts.lua` | ⬜ |
| 4 | `core/tooltips.lua` | `ui/tooltips.lua` | ⬜ |
| 5 | `domain/persistence.lua` | `infra/storage.lua` | ⬜ |
| 6 | `domain/undo.lua` | `infra/undo.lua` | ⬜ |
| 7 | `domain/file_ops.lua` | `infra/file_ops.lua` | ⬜ |
| 8 | `domain/scanner.lua` | `domain/template/scanner.lua` | ⬜ |
| 9 | `domain/template_ops.lua` | `domain/template/ops.lua` | ⬜ |
| 10 | `domain/tags.lua` | `domain/tags/service.lua` | ⬜ |
| 11 | `domain/fx_parser.lua` | `domain/fx/parser.lua` | ⬜ |
| 12 | `domain/fx_queue.lua` | `domain/fx/queue.lua` | ⬜ |
| 13 | `ui/gui.lua` | `ui/init.lua` | ⬜ |
| 14 | `ui/status_bar.lua` | `ui/status.lua` | ⬜ |
| 15 | `ui/ui_constants.lua` | `ui/config/constants.lua` | ⬜ |
| 16 | `ui/left_panel_config.lua` | `ui/config/left_panel.lua` | ⬜ |
| 17 | `ui/template_container_config.lua` | `ui/config/template.lua` | ⬜ |
| 18 | `ui/info_panel_config.lua` | `ui/config/info.lua` | ⬜ |
| 19 | `ui/convenience_panel_config.lua` | `ui/config/convenience.lua` | ⬜ |
| 20 | `ui/recent_panel_config.lua` | `ui/config/recent.lua` | ⬜ |
| 21 | `ui/views/tree_view.lua` | `ui/views/tree.lua` | ⬜ |
| 22 | `ui/views/left_panel_view.lua` | `ui/views/left_panel/init.lua` | ⬜ |
| 23 | `ui/views/template_panel_view.lua` | `ui/views/template_panel.lua` | ⬜ |
| 24 | `ui/views/info_panel_view.lua` | `ui/views/info_panel.lua` | ⬜ |
| 25 | `ui/views/convenience_panel_view.lua` | `ui/views/convenience/init.lua` | ⬜ |
| 26 | `ui/views/template_modals_view.lua` | `ui/views/modals/template.lua` | ⬜ |
| 27 | `ui/tiles/template_grid_factory.lua` | `ui/tiles/factory.lua` | ⬜ |
| 28 | `ui/tiles/template_tile.lua` | `ui/tiles/tile.lua` | ⬜ |
| 29 | `ui/tiles/template_tile_compact.lua` | `ui/tiles/tile_compact.lua` | ⬜ |
| 30 | (none) | `app/init.lua` | ⬜ CREATE |
| 31 | (none) | `ui/state/preferences.lua` | ⬜ CREATE |

### Folders to Delete After Migration

- `core/` (empty after migration)

---

## ItemPicker Migration

> **Priority: 2nd** | **Effort: Medium**
>
> See `TODO/scriptRefacto/ItemPicker/` for detailed migration steps.

### Current Structure (32 files)

```
ItemPicker/
├── core/
│   ├── app_state.lua
│   ├── config.lua
│   ├── controller.lua
│   └── preview_manager.lua
├── data/
│   ├── reaper_api.lua
│   ├── disk_cache.lua
│   ├── persistence.lua
│   ├── job_queue.lua
│   └── loaders/
│       └── incremental_loader.lua
├── services/
│   ├── utils.lua
│   ├── pool_utils.lua
│   └── visualization.lua
├── utils/
│   └── logger.lua
├── defs/
│   ├── constants.lua
│   ├── defaults.lua
│   └── strings.lua
├── ui/
│   ├── main_window.lua
│   ├── components/
│   │   ├── status_bar.lua
│   │   ├── search_with_mode.lua
│   │   ├── drag_handler.lua
│   │   ├── region_filter_bar.lua
│   │   ├── track_filter_bar.lua
│   │   ├── track_filter.lua
│   │   └── layout_view.lua
│   └── grids/
│       ├── coordinator.lua
│       ├── factories/
│       │   ├── midi_grid_factory.lua
│       │   ├── audio_grid_factory.lua
│       │   └── grid_factory_shared.lua
│       └── renderers/
│           ├── midi.lua
│           ├── base.lua
│           └── audio.lua
└── init.lua
```

### Target Structure

```
ItemPicker/
├── app/
│   ├── init.lua              # FROM: init.lua (expanded)
│   └── state.lua             # FROM: core/app_state.lua (simplified)
│
├── domain/
│   ├── items/
│   │   ├── audio.lua         # NEW: Audio item domain logic
│   │   ├── midi.lua          # NEW: MIDI item domain logic
│   │   └── service.lua       # FROM: core/controller.lua
│   ├── preview/
│   │   └── manager.lua       # FROM: core/preview_manager.lua
│   └── pool/
│       └── utils.lua         # FROM: services/pool_utils.lua
│
├── infra/
│   ├── storage.lua           # FROM: data/persistence.lua
│   ├── cache.lua             # FROM: data/disk_cache.lua
│   ├── job_queue.lua         # FROM: data/job_queue.lua
│   ├── reaper_api.lua        # FROM: data/reaper_api.lua
│   └── loader.lua            # FROM: data/loaders/incremental_loader.lua
│
├── ui/
│   ├── init.lua              # FROM: ui/main_window.lua
│   │
│   ├── state/
│   │   └── preferences.lua   # EXTRACT FROM: core/app_state.lua
│   │
│   ├── components/
│   │   ├── search.lua        # FROM: ui/components/search_with_mode.lua
│   │   ├── status.lua        # FROM: ui/components/status_bar.lua
│   │   ├── drag.lua          # FROM: ui/components/drag_handler.lua
│   │   ├── layout.lua        # FROM: ui/components/layout_view.lua
│   │   └── filters/
│   │       ├── region.lua    # FROM: ui/components/region_filter_bar.lua
│   │       ├── track.lua     # FROM: ui/components/track_filter_bar.lua
│   │       └── track_detail.lua # FROM: ui/components/track_filter.lua
│   │
│   ├── grids/
│   │   ├── coordinator.lua   # FROM: ui/grids/coordinator.lua
│   │   ├── factories/
│   │   │   ├── audio.lua     # FROM: ui/grids/factories/audio_grid_factory.lua
│   │   │   ├── midi.lua      # FROM: ui/grids/factories/midi_grid_factory.lua
│   │   │   └── shared.lua    # FROM: ui/grids/factories/grid_factory_shared.lua
│   │   └── renderers/
│   │       ├── base.lua      # FROM: ui/grids/renderers/base.lua
│   │       ├── audio.lua     # FROM: ui/grids/renderers/audio.lua
│   │       └── midi.lua      # FROM: ui/grids/renderers/midi.lua
│   │
│   └── visualization.lua     # FROM: services/visualization.lua
│
├── defs/                     # UNCHANGED
│   ├── constants.lua
│   ├── defaults.lua
│   └── strings.lua
│
└── tests/
```

### File Migration Table

| Current Path | New Path | Action |
|--------------|----------|--------|
| `core/app_state.lua` | `app/state.lua` | Simplify |
| `core/config.lua` | `app/config.lua` | Move |
| `core/controller.lua` | `domain/items/service.lua` | Move + rename |
| `core/preview_manager.lua` | `domain/preview/manager.lua` | Move |
| `data/persistence.lua` | `infra/storage.lua` | Move + rename |
| `data/disk_cache.lua` | `infra/cache.lua` | Move + rename |
| `data/job_queue.lua` | `infra/job_queue.lua` | Move |
| `data/reaper_api.lua` | `infra/reaper_api.lua` | Move |
| `data/loaders/incremental_loader.lua` | `infra/loader.lua` | Move + flatten |
| `services/utils.lua` | Delete or merge | Evaluate necessity |
| `services/pool_utils.lua` | `domain/pool/utils.lua` | Move |
| `services/visualization.lua` | `ui/visualization.lua` | Move (UI concern) |
| `utils/logger.lua` | Delete | Use `arkitekt.debug.logger` |
| `ui/main_window.lua` | `ui/init.lua` | Rename |
| `ui/components/status_bar.lua` | `ui/components/status.lua` | Rename |
| `ui/components/search_with_mode.lua` | `ui/components/search.lua` | Rename |
| `ui/components/drag_handler.lua` | `ui/components/drag.lua` | Rename |
| `ui/components/*_filter*.lua` | `ui/components/filters/*.lua` | Move to filters/ |
| `init.lua` | `app/init.lua` | Move + expand |

### Folders to Delete

- `core/` (empty after migration)
- `data/` (empty after migration)
- `services/` (empty after migration)
- `utils/` (use arkitekt instead)

---

## ThemeAdjuster Migration

> **Priority: 3rd** | **Effort: Medium**
>
> See `TODO/scriptRefacto/ThemeAdjuster/` for detailed migration steps.

### Current Structure (40 files)

```
ThemeAdjuster/
├── core/
│   ├── config.lua
│   ├── state.lua
│   ├── theme.lua
│   ├── theme_mapper.lua
│   ├── theme_params.lua
│   ├── parameter_link_manager.lua
│   └── param_discovery.lua
├── packages/
│   ├── image_map.lua
│   ├── manager.lua
│   └── metadata.lua
├── defs/
│   ├── constants.lua
│   ├── defaults.lua
│   └── strings.lua
├── ui/
│   ├── gui.lua
│   ├── main_panel.lua
│   ├── status.lua
│   ├── tab_content.lua
│   ├── grids/
│   │   ├── templates_grid_factory.lua
│   │   ├── assignment_grid_factory.lua
│   │   ├── library_grid_factory.lua
│   │   └── renderers/
│   │       ├── library_tile.lua
│   │       ├── template_group_config.lua
│   │       ├── tile_visuals.lua
│   │       ├── additional_param_tile.lua
│   │       ├── assignment_tile.lua
│   │       └── template_tile.lua
│   └── views/
│       ├── assembler_view.lua
│       ├── package_modal.lua
│       ├── debug_view.lua
│       ├── packages_view.lua
│       ├── param_link_modal.lua
│       ├── global_view.lua
│       ├── colors_view.lua
│       ├── transport_view.lua
│       ├── additional_view.lua
│       ├── tcp_view.lua
│       ├── envelope_view.lua
│       └── mcp_view.lua
└── Default_6.0_theme_adjuster.lua
```

### Target Structure

```
ThemeAdjuster/
├── app/
│   ├── init.lua              # NEW: Bootstrap
│   └── state.lua             # FROM: core/state.lua (simplified)
│
├── domain/
│   ├── theme/
│   │   ├── reader.lua        # FROM: core/theme.lua
│   │   ├── mapper.lua        # FROM: core/theme_mapper.lua
│   │   ├── params.lua        # FROM: core/theme_params.lua
│   │   └── discovery.lua     # FROM: core/param_discovery.lua
│   └── links/
│       └── manager.lua       # FROM: core/parameter_link_manager.lua
│
├── infra/
│   ├── storage.lua           # NEW: Persistence abstraction
│   └── packages/
│       ├── manager.lua       # FROM: packages/manager.lua
│       ├── metadata.lua      # FROM: packages/metadata.lua
│       └── image_map.lua     # FROM: packages/image_map.lua
│
├── ui/
│   ├── init.lua              # FROM: ui/gui.lua
│   ├── status.lua            # FROM: ui/status.lua
│   │
│   ├── state/
│   │   └── preferences.lua   # EXTRACT FROM: core/state.lua
│   │
│   ├── views/
│   │   ├── main_panel.lua    # FROM: ui/main_panel.lua
│   │   ├── tab_content.lua   # FROM: ui/tab_content.lua
│   │   ├── assembler.lua     # FROM: ui/views/assembler_view.lua
│   │   ├── tcp.lua           # FROM: ui/views/tcp_view.lua
│   │   ├── mcp.lua           # FROM: ui/views/mcp_view.lua
│   │   ├── colors.lua        # FROM: ui/views/colors_view.lua
│   │   ├── transport.lua     # FROM: ui/views/transport_view.lua
│   │   ├── global.lua        # FROM: ui/views/global_view.lua
│   │   ├── envelope.lua      # FROM: ui/views/envelope_view.lua
│   │   ├── additional.lua    # FROM: ui/views/additional_view.lua
│   │   ├── packages.lua      # FROM: ui/views/packages_view.lua
│   │   ├── debug.lua         # FROM: ui/views/debug_view.lua
│   │   └── modals/
│   │       ├── package.lua   # FROM: ui/views/package_modal.lua
│   │       └── param_link.lua # FROM: ui/views/param_link_modal.lua
│   │
│   └── grids/
│       ├── factories/
│       │   ├── templates.lua # FROM: ui/grids/templates_grid_factory.lua
│       │   ├── assignment.lua # FROM: ui/grids/assignment_grid_factory.lua
│       │   └── library.lua   # FROM: ui/grids/library_grid_factory.lua
│       └── renderers/
│           ├── library.lua   # FROM: ui/grids/renderers/library_tile.lua
│           ├── template.lua  # FROM: ui/grids/renderers/template_tile.lua
│           ├── assignment.lua # FROM: ui/grids/renderers/assignment_tile.lua
│           ├── additional.lua # FROM: ui/grids/renderers/additional_param_tile.lua
│           ├── group_config.lua # FROM: ui/grids/renderers/template_group_config.lua
│           └── visuals.lua   # FROM: ui/grids/renderers/tile_visuals.lua
│
├── defs/                     # UNCHANGED
│   ├── constants.lua
│   ├── defaults.lua
│   └── strings.lua
│
└── tests/
```

### File Migration Table

| Current Path | New Path | Action |
|--------------|----------|--------|
| `core/config.lua` | `app/config.lua` | Move |
| `core/state.lua` | `app/state.lua` | Simplify; extract UI to ui/state/ |
| `core/theme.lua` | `domain/theme/reader.lua` | Move + rename |
| `core/theme_mapper.lua` | `domain/theme/mapper.lua` | Move |
| `core/theme_params.lua` | `domain/theme/params.lua` | Move |
| `core/param_discovery.lua` | `domain/theme/discovery.lua` | Move |
| `core/parameter_link_manager.lua` | `domain/links/manager.lua` | Move |
| `packages/manager.lua` | `infra/packages/manager.lua` | Move |
| `packages/metadata.lua` | `infra/packages/metadata.lua` | Move |
| `packages/image_map.lua` | `infra/packages/image_map.lua` | Move |
| `ui/gui.lua` | `ui/init.lua` | Rename |
| `ui/views/*_view.lua` | `ui/views/*.lua` | Remove `_view` suffix |
| `ui/views/*_modal.lua` | `ui/views/modals/*.lua` | Move to modals/ |
| `ui/grids/*_factory.lua` | `ui/grids/factories/*.lua` | Move to factories/ |
| (none) | `app/init.lua` | **CREATE** |
| (none) | `ui/state/preferences.lua` | **CREATE** (extract from state.lua) |

---

## RegionPlaylist Migration

> **Priority: 4th** | **Effort: High**
>
> See `TODO/scriptRefacto/RegionPlaylist/` for detailed migration steps.

### Current Structure (47 files)

```
RegionPlaylist/
├── core/
│   ├── app_state.lua
│   ├── config.lua
│   ├── controller.lua
│   ├── sequence_expander.lua
│   └── tile_utilities.lua
├── domains/
│   ├── playlist.lua
│   ├── region.lua
│   ├── dependency.lua
│   ├── animation.lua
│   ├── notification.lua
│   └── ui_preferences.lua
├── engine/
│   ├── core.lua
│   ├── engine_state.lua
│   ├── playback.lua
│   ├── transport.lua
│   ├── quantize.lua
│   ├── transitions.lua
│   └── coordinator_bridge.lua
├── data/
│   ├── persistence.lua
│   ├── sws_importer.lua
│   └── undo_bridge.lua
├── ui/
│   ├── gui.lua
│   ├── status.lua
│   ├── shortcuts.lua
│   ├── batch_operations.lua
│   ├── views/
│   │   ├── layout_view.lua
│   │   ├── overflow_modal_view.lua
│   │   └── transport/
│   │       ├── transport_view.lua
│   │       ├── transport_container.lua
│   │       ├── button_widgets.lua
│   │       ├── display_widget.lua
│   │       ├── transport_fx.lua
│   │       └── transport_icons.lua
│   └── tiles/
│       ├── coordinator.lua
│       ├── coordinator_render.lua
│       ├── selector.lua
│       ├── active_grid_factory.lua
│       ├── pool_grid_factory.lua
│       └── renderers/
│           ├── base.lua
│           ├── active.lua
│           └── pool.lua
├── defs/
│   ├── constants.lua
│   ├── defaults.lua
│   └── strings.lua
└── tests/
    ├── run_tests.lua
    ├── domain_tests.lua
    └── integration_tests.lua
```

### Target Structure

```
RegionPlaylist/
├── app/
│   ├── init.lua              # NEW: Bootstrap, dependency injection
│   └── state.lua             # FROM: core/app_state.lua (simplified)
│
├── domain/
│   ├── playlist/
│   │   ├── model.lua         # EXTRACT FROM: domains/playlist.lua
│   │   ├── repository.lua    # EXTRACT FROM: domains/playlist.lua
│   │   └── service.lua       # FROM: core/controller.lua
│   ├── region/
│   │   └── repository.lua    # FROM: domains/region.lua
│   ├── playback/
│   │   ├── engine.lua        # FROM: engine/core.lua
│   │   ├── state.lua         # FROM: engine/engine_state.lua
│   │   ├── sequence.lua      # FROM: core/sequence_expander.lua
│   │   ├── transport.lua     # FROM: engine/transport.lua
│   │   ├── quantize.lua      # FROM: engine/quantize.lua
│   │   └── transitions.lua   # FROM: engine/transitions.lua
│   └── dependency.lua        # FROM: domains/dependency.lua
│
├── infra/
│   ├── storage.lua           # FROM: data/persistence.lua
│   ├── sws_import.lua        # FROM: data/sws_importer.lua
│   ├── undo.lua              # FROM: data/undo_bridge.lua
│   └── bridge.lua            # FROM: engine/coordinator_bridge.lua
│
├── ui/
│   ├── init.lua              # FROM: ui/gui.lua
│   ├── shortcuts.lua         # FROM: ui/shortcuts.lua
│   ├── batch.lua             # FROM: ui/batch_operations.lua
│   │
│   ├── state/
│   │   ├── preferences.lua   # FROM: domains/ui_preferences.lua
│   │   ├── animation.lua     # FROM: domains/animation.lua
│   │   └── notification.lua  # FROM: domains/notification.lua
│   │
│   ├── views/
│   │   ├── layout.lua        # FROM: ui/views/layout_view.lua
│   │   ├── overflow.lua      # FROM: ui/views/overflow_modal_view.lua
│   │   ├── status.lua        # FROM: ui/status.lua
│   │   └── transport/
│   │       ├── init.lua      # FROM: ui/views/transport/transport_view.lua
│   │       ├── container.lua # FROM: ui/views/transport/transport_container.lua
│   │       ├── buttons.lua   # FROM: ui/views/transport/button_widgets.lua
│   │       ├── display.lua   # FROM: ui/views/transport/display_widget.lua
│   │       ├── fx.lua        # FROM: ui/views/transport/transport_fx.lua
│   │       └── icons.lua     # FROM: ui/views/transport/transport_icons.lua
│   │
│   └── tiles/
│       ├── coordinator.lua   # FROM: ui/tiles/coordinator.lua
│       ├── render.lua        # FROM: ui/tiles/coordinator_render.lua
│       ├── selector.lua      # FROM: ui/tiles/selector.lua
│       ├── utils.lua         # FROM: core/tile_utilities.lua
│       ├── factories/
│       │   ├── active.lua    # FROM: ui/tiles/active_grid_factory.lua
│       │   └── pool.lua      # FROM: ui/tiles/pool_grid_factory.lua
│       └── renderers/
│           ├── base.lua      # FROM: ui/tiles/renderers/base.lua
│           ├── active.lua    # FROM: ui/tiles/renderers/active.lua
│           └── pool.lua      # FROM: ui/tiles/renderers/pool.lua
│
├── defs/                     # UNCHANGED
│   ├── constants.lua
│   ├── defaults.lua
│   └── strings.lua
│
└── tests/
    ├── domain/
    │   ├── playlist_test.lua # FROM: tests/domain_tests.lua (split)
    │   ├── region_test.lua
    │   └── playback_test.lua
    ├── infra/
    │   └── storage_test.lua
    └── integration/
        └── workflow_test.lua # FROM: tests/integration_tests.lua
```

### File Migration Table

| Current Path | New Path | Action |
|--------------|----------|--------|
| `core/app_state.lua` | `app/state.lua` | Simplify to container |
| `core/config.lua` | `app/config.lua` | Move |
| `core/controller.lua` | `domain/playlist/service.lua` | Rename + refactor |
| `core/sequence_expander.lua` | `domain/playback/sequence.lua` | Move |
| `core/tile_utilities.lua` | `ui/tiles/utils.lua` | Move |
| `domains/playlist.lua` | `domain/playlist/model.lua` + `repository.lua` | Split |
| `domains/region.lua` | `domain/region/repository.lua` | Rename |
| `domains/dependency.lua` | `domain/dependency.lua` | Move |
| `domains/animation.lua` | `ui/state/animation.lua` | Move (UI state) |
| `domains/notification.lua` | `ui/state/notification.lua` | Move (UI state) |
| `domains/ui_preferences.lua` | `ui/state/preferences.lua` | Move (UI state) |
| `engine/core.lua` | `domain/playback/engine.lua` | Move |
| `engine/engine_state.lua` | `domain/playback/state.lua` | Move |
| `engine/playback.lua` | `domain/playback/loop.lua` | Move |
| `engine/transport.lua` | `domain/playback/transport.lua` | Move |
| `engine/quantize.lua` | `domain/playback/quantize.lua` | Move |
| `engine/transitions.lua` | `domain/playback/transitions.lua` | Move |
| `engine/coordinator_bridge.lua` | `infra/bridge.lua` | Move |
| `data/persistence.lua` | `infra/storage.lua` | Move |
| `data/sws_importer.lua` | `infra/sws_import.lua` | Move |
| `data/undo_bridge.lua` | `infra/undo.lua` | Move |
| `ui/gui.lua` | `ui/init.lua` | Rename |
| `ui/status.lua` | `ui/views/status.lua` | Move |
| `ui/shortcuts.lua` | `ui/shortcuts.lua` | Keep |
| `ui/batch_operations.lua` | `ui/batch.lua` | Rename |
| (none) | `app/init.lua` | **CREATE** |

### Folders to Delete

- `core/` (empty after migration)
- `domains/` (empty after migration)
- `engine/` (empty after migration)
- `data/` (empty after migration)

---

## Cross-Script Comparison

### Final Structure Alignment

```
                 TemplateBrowser    ItemPicker     ThemeAdjuster     RegionPlaylist
                 ===============    ==========     =============     ==============
app/
├── init.lua         ✓                ✓                 ✓                 ✓
└── state.lua        ✓                ✓                 ✓                 ✓

domain/
├── template/        ✓
├── tags/            ✓
├── fx/              ✓
├── items/                            ✓
├── preview/                          ✓
├── pool/                             ✓
├── theme/                                              ✓
├── links/                                              ✓
├── playlist/                                                             ✓
├── region/                                                               ✓
└── playback/                                                             ✓

infra/
├── storage.lua      ✓                ✓                 ✓                 ✓
├── undo.lua         ✓
├── file_ops.lua     ✓
├── cache.lua                         ✓
├── job_queue.lua                     ✓
├── reaper_api.lua                    ✓
├── loader.lua                        ✓
├── packages/                                           ✓
├── sws_import.lua                                                        ✓
├── bridge.lua                                                            ✓
└── undo.lua                                                              ✓

ui/
├── init.lua         ✓                ✓                 ✓                 ✓
├── shortcuts.lua    ✓                                                    ✓
├── tooltips.lua     ✓
├── status.lua       ✓                                  ✓                 ✓
├── visualization.lua                 ✓
├── state/           ✓                ✓                 ✓                 ✓
├── config/          ✓
├── views/           ✓                                  ✓                 ✓
├── tiles/           ✓                                                    ✓
├── grids/                            ✓                 ✓
├── components/                       ✓
└── batch.lua                                                             ✓

defs/                ✓                ✓                 ✓                 ✓
tests/               ✓                ✓                 ✓                 ✓
```

### Migration Effort Summary (by Priority)

| Priority | Script | Files to Move | Files to Create | Folders to Delete | Effort |
|----------|--------|---------------|-----------------|-------------------|--------|
| 1st | **TemplateBrowser** | 30 | 3 | 1 (`core/`) | Low |
| 2nd | **ItemPicker** | 28 | 4 | 4 | Medium |
| 3rd | **ThemeAdjuster** | 35 | 3 | 2 | Medium |
| 4th | **RegionPlaylist** | 42 | 5 | 4 | High |

---

## Migration Strategy

### Recommended Approach

1. **Phase 1: Create new folders**
   - Create `app/`, `domain/`, `infra/` folders
   - Add `init.lua` re-exports for backward compatibility

2. **Phase 2: Move files one at a time**
   - Move one file
   - Update its `require` statements
   - Update files that require it
   - Test
   - Commit

3. **Phase 3: Split large files**
   - Split `app_state.lua` into `app/state.lua` + `ui/state/preferences.lua`
   - Split `controller.lua` into `domain/*/service.lua`

4. **Phase 4: Cleanup**
   - Delete empty folders
   - Remove deprecated re-exports
   - Update entry point

### Each Phase Should Keep App Working

Never break the app between commits. Use this pattern for backward compatibility during migration:

```lua
-- OLD: core/app_state.lua (keep temporarily)
-- Re-export from new location for backward compatibility
return require("app.state")
```

---

## Next Steps

1. Review this plan and adjust as needed
2. Start with TemplateBrowser (lowest effort)
3. Apply lessons learned to other scripts
4. See [CONVENTIONS.md](./CONVENTIONS.md) for naming standards
