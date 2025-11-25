# Script Migration Plans

> Detailed file-by-file migration plans for restructuring ARKITEKT scripts.

## Table of Contents

1. [Migration Overview](#migration-overview)
2. [Migration Priority](#migration-priority)
3. [RegionPlaylist Migration](#regionplaylist-migration)
4. [ThemeAdjuster Migration](#themeadjuster-migration)
5. [TemplateBrowser Migration](#templatebrowser-migration)
6. [ItemPicker Migration](#itempicker-migration)
7. [Cross-Script Comparison](#cross-script-comparison)

---

## Migration Overview

### Current State Analysis

| Script | Files | Current Folders | Key Issues |
|--------|-------|-----------------|------------|
| **RegionPlaylist** | 47 | core, domains, engine, storage, ui, defs | `core/` is mixed; `domains/` has UI state |
| **ThemeAdjuster** | 40 | core, packages, ui, defs | `core/` mixes state + theme logic |
| **TemplateBrowser** | 38 | core, domain, ui, defs | Already has `domain/` - most aligned |
| **ItemPicker** | 32 | core, data, services, utils, ui, defs | Most fragmented; `services/` unclear |

### Target State

All scripts will follow this structure:

```
[ScriptName]/
├── app/              # Application bootstrap and state
├── domain/           # Business logic
├── infra/            # External I/O
├── ui/               # Presentation
├── defs/             # Static definitions
└── tests/            # Tests
```

---

## Migration Priority

| Priority | Script | Effort | Rationale |
|----------|--------|--------|-----------|
| 1st | **TemplateBrowser** | Low | Already has `domain/`; minimal changes |
| 2nd | **ItemPicker** | Medium | Most fragmented; clear wins |
| 3rd | **ThemeAdjuster** | Medium | Clear domain (theme); straightforward |
| 4th | **RegionPlaylist** | High | Most complex; do last with lessons learned |

---

## RegionPlaylist Migration

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
├── storage/
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
│   ├── storage.lua           # FROM: storage/persistence.lua
│   ├── sws_import.lua        # FROM: storage/sws_importer.lua
│   ├── undo.lua              # FROM: storage/undo_bridge.lua
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
| `storage/persistence.lua` | `infra/storage.lua` | Move |
| `storage/sws_importer.lua` | `infra/sws_import.lua` | Move |
| `storage/undo_bridge.lua` | `infra/undo.lua` | Move |
| `ui/gui.lua` | `ui/init.lua` | Rename |
| `ui/status.lua` | `ui/views/status.lua` | Move |
| `ui/shortcuts.lua` | `ui/shortcuts.lua` | Keep |
| `ui/batch_operations.lua` | `ui/batch.lua` | Rename |
| (none) | `app/init.lua` | **CREATE** |

### Folders to Delete

- `core/` (empty after migration)
- `domains/` (empty after migration)
- `engine/` (empty after migration)
- `storage/` (empty after migration)

---

## ThemeAdjuster Migration

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

## TemplateBrowser Migration

### Current Structure (38 files)

```
TemplateBrowser/
├── core/
│   ├── config.lua
│   ├── state.lua
│   ├── tooltips.lua
│   └── shortcuts.lua
├── domain/                   # ALREADY EXISTS! (closest to target)
│   ├── fx_parser.lua
│   ├── file_ops.lua
│   ├── scanner.lua
│   ├── undo.lua
│   ├── persistence.lua
│   ├── tags.lua
│   ├── fx_queue.lua
│   └── template_ops.lua
├── defs/
│   ├── constants.lua
│   ├── defaults.lua
│   └── strings.lua
├── ui/
│   ├── gui.lua
│   ├── status_bar.lua
│   ├── convenience_panel_config.lua
│   ├── template_container_config.lua
│   ├── recent_panel_config.lua
│   ├── info_panel_config.lua
│   ├── ui_constants.lua
│   ├── left_panel_config.lua
│   ├── tiles/
│   │   ├── template_tile_compact.lua
│   │   ├── template_grid_factory.lua
│   │   └── template_tile.lua
│   └── views/
│       ├── helpers.lua
│       ├── left_panel_view.lua
│       ├── info_panel_view.lua
│       ├── template_panel_view.lua
│       ├── tree_view.lua
│       ├── convenience_panel_view.lua
│       ├── template_modals_view.lua
│       ├── left_panel/
│       │   ├── tags_tab.lua
│       │   ├── directory_tab.lua
│       │   └── vsts_tab.lua
│       └── convenience_panel/
│           ├── tags_tab.lua
│           └── vsts_tab.lua
```

### Target Structure

```
TemplateBrowser/
├── app/
│   ├── init.lua              # NEW: Bootstrap
│   └── state.lua             # FROM: core/state.lua (simplified)
│
├── domain/
│   ├── template/
│   │   ├── model.lua         # EXTRACT FROM: template_ops.lua
│   │   ├── scanner.lua       # FROM: domain/scanner.lua
│   │   └── ops.lua           # FROM: domain/template_ops.lua
│   ├── tags/
│   │   └── service.lua       # FROM: domain/tags.lua
│   └── fx/
│       ├── parser.lua        # FROM: domain/fx_parser.lua
│       └── queue.lua         # FROM: domain/fx_queue.lua
│
├── infra/
│   ├── storage.lua           # FROM: domain/persistence.lua
│   ├── undo.lua              # FROM: domain/undo.lua
│   └── file_ops.lua          # FROM: domain/file_ops.lua
│
├── ui/
│   ├── init.lua              # FROM: ui/gui.lua
│   ├── shortcuts.lua         # FROM: core/shortcuts.lua
│   ├── tooltips.lua          # FROM: core/tooltips.lua
│   ├── status.lua            # FROM: ui/status_bar.lua
│   │
│   ├── state/
│   │   └── preferences.lua   # EXTRACT FROM: core/state.lua
│   │
│   ├── config/               # Panel configurations
│   │   ├── left_panel.lua    # FROM: ui/left_panel_config.lua
│   │   ├── template.lua      # FROM: ui/template_container_config.lua
│   │   ├── info.lua          # FROM: ui/info_panel_config.lua
│   │   ├── convenience.lua   # FROM: ui/convenience_panel_config.lua
│   │   ├── recent.lua        # FROM: ui/recent_panel_config.lua
│   │   └── constants.lua     # FROM: ui/ui_constants.lua
│   │
│   ├── views/
│   │   ├── helpers.lua       # FROM: ui/views/helpers.lua
│   │   ├── left_panel/
│   │   │   ├── init.lua      # FROM: ui/views/left_panel_view.lua
│   │   │   ├── tags.lua      # FROM: ui/views/left_panel/tags_tab.lua
│   │   │   ├── directory.lua # FROM: ui/views/left_panel/directory_tab.lua
│   │   │   └── vsts.lua      # FROM: ui/views/left_panel/vsts_tab.lua
│   │   ├── template_panel.lua # FROM: ui/views/template_panel_view.lua
│   │   ├── info_panel.lua    # FROM: ui/views/info_panel_view.lua
│   │   ├── tree.lua          # FROM: ui/views/tree_view.lua
│   │   ├── convenience/
│   │   │   ├── init.lua      # FROM: ui/views/convenience_panel_view.lua
│   │   │   ├── tags.lua      # FROM: ui/views/convenience_panel/tags_tab.lua
│   │   │   └── vsts.lua      # FROM: ui/views/convenience_panel/vsts_tab.lua
│   │   └── modals/
│   │       └── template.lua  # FROM: ui/views/template_modals_view.lua
│   │
│   └── tiles/
│       ├── factory.lua       # FROM: ui/tiles/template_grid_factory.lua
│       ├── tile.lua          # FROM: ui/tiles/template_tile.lua
│       └── tile_compact.lua  # FROM: ui/tiles/template_tile_compact.lua
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
| `core/state.lua` | `app/state.lua` | Simplify |
| `core/shortcuts.lua` | `ui/shortcuts.lua` | Move (UI concern) |
| `core/tooltips.lua` | `ui/tooltips.lua` | Move (UI concern) |
| `domain/persistence.lua` | `infra/storage.lua` | Move (I/O) |
| `domain/undo.lua` | `infra/undo.lua` | Move (I/O) |
| `domain/file_ops.lua` | `infra/file_ops.lua` | Move (I/O) |
| `domain/scanner.lua` | `domain/template/scanner.lua` | Reorganize |
| `domain/template_ops.lua` | `domain/template/ops.lua` | Reorganize |
| `domain/tags.lua` | `domain/tags/service.lua` | Reorganize |
| `domain/fx_parser.lua` | `domain/fx/parser.lua` | Reorganize |
| `domain/fx_queue.lua` | `domain/fx/queue.lua` | Reorganize |
| `ui/gui.lua` | `ui/init.lua` | Rename |
| `ui/status_bar.lua` | `ui/status.lua` | Rename |
| `ui/*_config.lua` | `ui/config/*.lua` | Move to config/ |
| `ui/views/*_view.lua` | `ui/views/*.lua` | Remove `_view` suffix |
| (none) | `app/init.lua` | **CREATE** |
| (none) | `ui/state/preferences.lua` | **CREATE** |

---

## ItemPicker Migration

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

## Cross-Script Comparison

### Final Structure Alignment

```
                 RegionPlaylist    ThemeAdjuster     TemplateBrowser    ItemPicker
                 ==============    =============     ===============    ==========
app/
├── init.lua         ✓                 ✓                  ✓                ✓
└── state.lua        ✓                 ✓                  ✓                ✓

domain/
├── playlist/        ✓
├── region/          ✓
├── playback/        ✓
├── theme/                             ✓
├── links/                             ✓
├── template/                                             ✓
├── tags/                                                 ✓
├── fx/                                                   ✓
├── items/                                                                  ✓
├── preview/                                                                ✓
└── pool/                                                                   ✓

infra/
├── storage.lua      ✓                 ✓                  ✓                ✓
├── undo.lua         ✓                                    ✓
├── sws_import.lua   ✓
├── bridge.lua       ✓
├── packages/                          ✓
├── file_ops.lua                                          ✓
├── cache.lua                                                              ✓
├── job_queue.lua                                                          ✓
├── reaper_api.lua                                                         ✓
└── loader.lua                                                             ✓

ui/
├── init.lua         ✓                 ✓                  ✓                ✓
├── shortcuts.lua    ✓                                    ✓
├── tooltips.lua                                          ✓
├── status.lua       ✓                 ✓                  ✓
├── visualization.lua                                                      ✓
├── state/           ✓                 ✓                  ✓                ✓
├── config/                                               ✓
├── views/           ✓                 ✓                  ✓
├── tiles/           ✓                                    ✓
├── grids/                             ✓                                   ✓
└── components/                                                            ✓

defs/                ✓                 ✓                  ✓                ✓
tests/               ✓                 ✓                  ✓                ✓
```

### Migration Effort Summary

| Script | Files to Move | Files to Create | Files to Delete | Estimated Effort |
|--------|---------------|-----------------|-----------------|------------------|
| **TemplateBrowser** | 30 | 3 | 0 | Low (2-3 hours) |
| **ItemPicker** | 28 | 4 | 2 | Medium (3-4 hours) |
| **ThemeAdjuster** | 35 | 3 | 0 | Medium (3-4 hours) |
| **RegionPlaylist** | 42 | 5 | 0 | High (5-6 hours) |

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
