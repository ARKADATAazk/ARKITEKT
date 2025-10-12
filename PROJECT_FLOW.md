# PROJECT FLOW: ARKITEKT
Generated: 2025-10-13 01:20:19
Root: D:\Dropbox\REAPER\Scripts\ARKITEKT

## Project Structure

```
├── apps/
│   ├── ColorPalette/
│   │   ├── app/
│   │   │   ├── controller.lua         # (235 lines)
│   │   │   ├── gui.lua         # (443 lines)
│   │   │   └── state.lua         # (273 lines)
│   │   ├── widgets/
│   │   │   └── color_grid.lua         # (143 lines)
│   │   └── ARK_ColorPalette.lua         # (98 lines)
│   ├── Region_Playlist/
│   │   ├── app/
│   │   │   ├── config.lua         # (344 lines)
│   │   │   ├── controller.lua         # (363 lines)
│   │   │   ├── gui.lua         # (892 lines)
│   │   │   ├── shortcuts.lua         # (83 lines)
│   │   │   ├── state.lua         # (597 lines)
│   │   │   └── status.lua         # (59 lines)
│   │   ├── engine/
│   │   │   ├── coordinator_bridge.lua         # (171 lines)
│   │   │   ├── core.lua         # (168 lines)
│   │   │   ├── playback.lua         # (103 lines)
│   │   │   ├── quantize.lua         # (337 lines)
│   │   │   ├── state.lua         # (148 lines)
│   │   │   ├── transitions.lua         # (211 lines)
│   │   │   └── transport.lua         # (239 lines)
│   │   ├── storage/
│   │   │   ├── state.lua         # (152 lines)
│   │   │   └── undo_bridge.lua         # (91 lines)
│   │   ├── widgets/
│   │   │   ├── controls/
│   │   │   │   └── controls_widget.lua         # (151 lines)
│   │   │   └── region_tiles/
│   │   │       ├── renderers/
│   │   │       │   ├── active.lua         # (187 lines)
│   │   │       │   ├── base.lua         # (187 lines)
│   │   │       │   └── pool.lua         # (148 lines)
│   │   │       ├── active_grid_factory.lua         # (213 lines)
│   │   │       ├── coordinator.lua         # (503 lines)
│   │   │       ├── coordinator_render.lua         # (190 lines)
│   │   │       ├── pool_grid_factory.lua         # (186 lines)
│   │   │       └── selector.lua         # (98 lines)
│   │   └── ARK_RegionPlaylist.lua         # (60 lines)
│   └── demos/
│       ├── demo.lua         # (365 lines)
│       ├── demo2.lua         # (192 lines)
│       ├── demo3.lua         # (130 lines)
│       ├── demo_modal_overlay.lua         # (433 lines)
│       └── widget_demo.lua         # (232 lines)
└── arkitekt/
    ├── app/
    │   ├── chrome/
    │   │   └── status_bar/
    │   │       ├── config.lua         # (140 lines)
    │   │       ├── init.lua         # (3 lines)
    │   │       └── widget.lua         # (319 lines)
    │   ├── config.lua         # (86 lines)
    │   ├── icon.lua         # (124 lines)
    │   ├── runtime.lua         # (69 lines)
    │   ├── shell.lua         # (256 lines)
    │   ├── titlebar.lua         # (454 lines)
    │   └── window.lua         # (560 lines)
    ├── core/
    │   ├── colors.lua         # (550 lines)
    │   ├── json.lua         # (121 lines)
    │   ├── lifecycle.lua         # (81 lines)
    │   ├── math.lua         # (52 lines)
    │   ├── settings.lua         # (119 lines)
    │   └── undo_manager.lua         # (70 lines)
    ├── gui/
    │   ├── fx/
    │   │   ├── animation/
    │   │   │   ├── rect_track.lua         # (136 lines)
    │   │   │   └── track.lua         # (53 lines)
    │   │   ├── animations/
    │   │   │   ├── destroy.lua         # (149 lines)
    │   │   │   └── spawn.lua         # (58 lines)
    │   │   ├── dnd/
    │   │   │   ├── config.lua         # (91 lines)
    │   │   │   ├── drag_indicator.lua         # (219 lines)
    │   │   │   └── drop_indicator.lua         # (113 lines)
    │   │   ├── easing.lua         # (94 lines)
    │   │   ├── effects.lua         # (54 lines)
    │   │   ├── marching_ants.lua         # (142 lines)
    │   │   ├── tile_fx.lua         # (170 lines)
    │   │   ├── tile_fx_config.lua         # (79 lines)
    │   │   └── tile_motion.lua         # (58 lines)
    │   ├── systems/
    │   │   ├── height_stabilizer.lua         # (74 lines)
    │   │   ├── playback_manager.lua         # (22 lines)
    │   │   ├── reorder.lua         # (127 lines)
    │   │   ├── responsive_grid.lua         # (229 lines)
    │   │   ├── selection.lua         # (142 lines)
    │   │   └── tile_utilities.lua         # (49 lines)
    │   ├── widgets/
    │   │   ├── chip_list/
    │   │   │   └── list.lua         # (303 lines)
    │   │   ├── component/
    │   │   │   └── chip.lua         # (333 lines)
    │   │   ├── controls/
    │   │   │   ├── context_menu.lua         # (106 lines)
    │   │   │   ├── dropdown.lua         # (356 lines)
    │   │   │   ├── scrollbar.lua         # (239 lines)
    │   │   │   └── tooltip.lua         # (129 lines)
    │   │   ├── displays/
    │   │   │   └── status_pad.lua         # (192 lines)
    │   │   ├── grid/
    │   │   │   ├── animation.lua         # (101 lines)
    │   │   │   ├── core.lua         # (550 lines)
    │   │   │   ├── dnd_state.lua         # (113 lines)
    │   │   │   ├── drop_zones.lua         # (277 lines)
    │   │   │   ├── grid_bridge.lua         # (219 lines)
    │   │   │   ├── input.lua         # (237 lines)
    │   │   │   ├── layout.lua         # (101 lines)
    │   │   │   └── rendering.lua         # (90 lines)
    │   │   ├── navigation/
    │   │   │   └── menutabs.lua         # (269 lines)
    │   │   ├── overlay/
    │   │   │   ├── config.lua         # (139 lines)
    │   │   │   ├── manager.lua         # (178 lines)
    │   │   │   └── sheet.lua         # (125 lines)
    │   │   ├── package_tiles/
    │   │   │   ├── grid.lua         # (227 lines)
    │   │   │   ├── micromanage.lua         # (127 lines)
    │   │   │   └── renderer.lua         # (267 lines)
    │   │   ├── panel/
    │   │   │   ├── header/
    │   │   │   │   ├── button.lua         # (105 lines)
    │   │   │   │   ├── dropdown_field.lua         # (79 lines)
    │   │   │   │   ├── init.lua         # (36 lines)
    │   │   │   │   ├── layout.lua         # (298 lines)
    │   │   │   │   ├── search_field.lua         # (119 lines)
    │   │   │   │   ├── separator.lua         # (33 lines)
    │   │   │   │   └── tab_strip.lua         # (731 lines)
    │   │   │   ├── modes/
    │   │   │   │   ├── search_sort.lua         # (225 lines)
    │   │   │   │   └── tabs.lua         # (647 lines)
    │   │   │   ├── background.lua         # (61 lines)
    │   │   │   ├── config.lua         # (233 lines)
    │   │   │   ├── content.lua         # (44 lines)
    │   │   │   ├── header.lua         # (42 lines)
    │   │   │   ├── init.lua         # (406 lines)
    │   │   │   └── tab_animator.lua         # (107 lines)
    │   │   ├── sliders/
    │   │   │   └── hue.lua         # (276 lines)
    │   │   ├── transport/
    │   │   │   ├── transport_container.lua         # (137 lines)
    │   │   │   └── transport_fx.lua         # (107 lines)
    │   │   ├── selection_rectangle.lua         # (99 lines)
    │   │   └── tiles_container_old.lua         # (753 lines)
    │   ├── draw.lua         # (114 lines)
    │   ├── images.lua         # (285 lines)
    │   └── style.lua         # (146 lines)
    ├── input/
    │   └── wheel_guard.lua         # (43 lines)
    └── reaper/
        ├── regions.lua         # (83 lines)
        ├── timing.lua         # (113 lines)
        └── transport.lua         # (97 lines)
```

## Overview
- **Total Files**: 118
- **Total Lines**: 23,585
- **Code Lines**: 18,342
- **Public Functions**: 348
- **Classes**: 81
- **Modules**: 255

## Folder Structure
### apps/
  - Files: 35
  - Lines: 6,594
  - Exports: 103

### arkitekt/
  - Files: 83
  - Lines: 11,748
  - Exports: 245

## Execution Flow Patterns

### Entry Points (Not Imported by Others)
- **`arkitekt/gui/widgets/panel/header/init.lua`**
  → Imports: arkitekt.gui.widgets.panel.header.layout
- **`arkitekt/reaper/timing.lua`**
- **`arkitekt/core/lifecycle.lua`**
- **`apps/ColorPalette/ARK_ColorPalette.lua`**
  → Imports: arkitekt.app.shell, apps.ColorPalette.app.state, apps.ColorPalette.app.gui (+2 more)
- **`apps/demos/demo_modal_overlay.lua`**
  → Imports: arkitekt.app.shell, arkitekt.gui.widgets.overlay.sheet, arkitekt.gui.widgets.chip_list.list (+1 more)
- **`arkitekt/gui/widgets/navigation/menutabs.lua`**
- **`apps/demos/widget_demo.lua`**
  → Imports: arkitekt.app.shell, ReArkitekt.gui.widgets.colorblocks, arkitekt.gui.draw (+2 more)
- **`arkitekt/input/wheel_guard.lua`**
  → Imports: imgui
- **`apps/Region_Playlist/widgets/controls/controls_widget.lua`**
- **`arkitekt/gui/widgets/tiles_container_old.lua`**
  → Imports: arkitekt.gui.widgets.controls.dropdown

### Orchestration Pattern
**`arkitekt/gui/widgets/grid/core.lua`** composes 13 modules:
  layout + rect_track + colors + selection + selection_rectangle (+8 more)
**`apps/Region_Playlist/widgets/region_tiles/coordinator.lua`** composes 12 modules:
  config + coordinator_render + draw + colors + tile_motion (+7 more)
**`apps/Region_Playlist/app/gui.lua`** composes 9 modules:
  coordinator + colors + shortcuts + controller + transport_container (+4 more)
**`apps/Region_Playlist/widgets/region_tiles/renderers/base.lua`** composes 7 modules:
  draw + colors + tile_fx + tile_fx_config + marching_ants (+2 more)
**`arkitekt/gui/widgets/package_tiles/grid.lua`** composes 6 modules:
  core + colors + tile_motion + renderer + micromanage (+1 more)

## Module API Surface

### `apps/ColorPalette/app/controller.lua`
> @noindex

**Modules**: `M, Controller, targets, colors`
**Classes**: `Controller, M` (stateful objects)
**Public API**:
  - `M.new()` → Instance

### `apps/ColorPalette/app/gui.lua`
> @noindex

**Modules**: `M, GUI`
**Classes**: `GUI, M` (stateful objects)
**Public API**:
  - `M.create(State, settings, overlay_manager)` → Instance
**Dependencies**: `arkitekt.core.colors, arkitekt.gui.draw, apps.ColorPalette.widgets.color_grid, apps.ColorPalette.app.controller, arkitekt.gui.widgets.overlay.sheet`

### `apps/ColorPalette/app/state.lua`
> @noindex

**Modules**: `M`
**Public API**:
  - `M.initialize(settings)`
  - `M.recalculate_palette()`
  - `M.get_palette_colors()`
  - `M.get_palette_config()`
  - `M.get_target_type()`
  - `M.set_target_type(index)`
  - `M.get_action_type()`
  - `M.set_action_type(index)`
  - `M.set_auto_close(value)`
  - `M.get_auto_close()`
**Dependencies**: `arkitekt.core.colors`

### `apps/ColorPalette/widgets/color_grid.lua`
> @noindex

**Modules**: `M, ColorGrid`
**Classes**: `ColorGrid, M` (stateful objects)
**Public API**:
  - `M.new()` → Instance
**Dependencies**: `arkitekt.core.colors, arkitekt.gui.draw`

### `apps/Region_Playlist/app/config.lua`
> @noindex

**Modules**: `M`
**Public API**:
  - `M.get_active_container_config(callbacks)`
  - `M.get_pool_container_config(callbacks)`
  - `M.get_region_tiles_config(layout_mode)`

### `apps/Region_Playlist/app/controller.lua`
> @noindex

**Modules**: `M, Controller, keys, keys, keys_set, new_items, keys_set, keys_set`
**Classes**: `Controller, M` (stateful objects)
**Public API**:
  - `M.new(state_module, settings, undo_manager)` → Instance
**Dependencies**: `apps.Region_Playlist.storage.state`

### `apps/Region_Playlist/app/gui.lua`
> @noindex

**Modules**: `M, GUI, tab_items, selected_ids, filtered`
**Classes**: `GUI, M` (stateful objects)
**Public API**:
  - `M.create(State, AppConfig, settings)` → Instance
**Dependencies**: `apps.Region_Playlist.widgets.region_tiles.coordinator, arkitekt.core.colors, apps.Region_Playlist.app.shortcuts, apps.Region_Playlist.app.controller, arkitekt.gui.widgets.transport.transport_container, (+4 more)`

### `apps/Region_Playlist/app/shortcuts.lua`
> @noindex

**Modules**: `M`
**Public API**:
  - `M.handle_keyboard_shortcuts(ctx, state, region_tiles)`
**Dependencies**: `apps.Region_Playlist.app.state`

### `apps/Region_Playlist/app/state.lua`
> @noindex

**Modules**: `M, tabs, result, reversed, all_deps, visited, pool_playlists, filtered, reversed, new_path, path_array`
**Public API**:
  - `M.initialize(settings)`
  - `M.load_project_state()`
  - `M.reload_project_data()`
  - `M.get_active_playlist()`
  - `M.get_playlist_by_id(playlist_id)`
  - `M.get_tabs()`
  - `M.refresh_regions()`
  - `M.sync_playlist_to_engine()`
  - `M.persist()`
  - `M.persist_ui_prefs()`
**Private Functions**: 9 helpers
**Dependencies**: `apps.Region_Playlist.engine.coordinator_bridge, apps.Region_Playlist.storage.state, arkitekt.core.undo_manager, apps.Region_Playlist.storage.undo_bridge, arkitekt.core.colors`

### `apps/Region_Playlist/app/status.lua`
> @noindex

**Modules**: `M`
**Classes**: `M` (stateful objects)
**Public API**:
  - `M.create(State, Style)` → Instance
**Dependencies**: `arkitekt.app.chrome.status_bar`

### `apps/Region_Playlist/engine/coordinator_bridge.lua`
> @noindex

**Modules**: `M, order, regions`
**Classes**: `M` (stateful objects)
**Public API**:
  - `M.create(opts)` → Instance
**Dependencies**: `apps.Region_Playlist.engine.core, apps.Region_Playlist.engine.playback, apps.Region_Playlist.storage.state`

### `apps/Region_Playlist/engine/core.lua`
> @noindex

**Modules**: `M, Engine`
**Classes**: `Engine, M` (stateful objects)
**Public API**:
  - `M.new(opts)` → Instance
**Dependencies**: `apps.Region_Playlist.engine.state, apps.Region_Playlist.engine.transport, apps.Region_Playlist.engine.transitions, apps.Region_Playlist.engine.quantize`

### `apps/Region_Playlist/engine/playback.lua`
> @noindex

**Modules**: `M, Playback`
**Classes**: `Playback, M` (stateful objects)
**Public API**:
  - `M.new(engine, opts)` → Instance
**Dependencies**: `arkitekt.reaper.transport`

### `apps/Region_Playlist/engine/quantize.lua`
> @noindex

**Modules**: `M, Quantize`
**Classes**: `Quantize, M` (stateful objects)
**Public API**:
  - `M.new(opts)` → Instance

### `apps/Region_Playlist/engine/state.lua`
> @noindex

**Modules**: `M, State`
**Classes**: `State, M` (stateful objects)
**Public API**:
  - `M.new(opts)` → Instance
**Dependencies**: `arkitekt.reaper.regions, arkitekt.reaper.transport`

### `apps/Region_Playlist/engine/transitions.lua`
> @noindex

**Modules**: `M, Transitions`
**Classes**: `Transitions, M` (stateful objects)
**Public API**:
  - `M.new(opts)` → Instance

### `apps/Region_Playlist/engine/transport.lua`
> @noindex

**Modules**: `M, Transport`
**Classes**: `Transport, M` (stateful objects)
**Public API**:
  - `M.new(opts)` → Instance

### `apps/Region_Playlist/storage/state.lua`
> @noindex

**Modules**: `M, default_items`
**Public API**:
  - `M.save_playlists(playlists, proj)`
  - `M.load_playlists(proj)`
  - `M.save_active_playlist(playlist_id, proj)`
  - `M.load_active_playlist(proj)`
  - `M.save_settings(settings, proj)`
  - `M.load_settings(proj)`
  - `M.clear_all(proj)`
  - `M.get_or_create_default_playlist(playlists, regions)` → Instance
  - `M.generate_chip_color()`
**Dependencies**: `arkitekt.core.json, arkitekt.core.colors`

### `apps/Region_Playlist/storage/undo_bridge.lua`
> @noindex

**Modules**: `M, restored_playlists`
**Public API**:
  - `M.capture_snapshot(playlists, active_playlist_id)`
  - `M.restore_snapshot(snapshot, region_index)`
  - `M.should_capture(old_playlists, new_playlists)`

### `apps/Region_Playlist/widgets/controls/controls_widget.lua`
> @noindex

**Modules**: `M`
**Public API**:
  - `M.draw_transport_controls(ctx, bridge, x, y)`
  - `M.draw_quantize_selector(ctx, bridge, x, y, width)`
  - `M.draw_playback_info(ctx, bridge, x, y, width)`
  - `M.draw_complete_controls(ctx, bridge, x, y, available_width)`

### `apps/Region_Playlist/widgets/region_tiles/active_grid_factory.lua`
> @noindex

**Modules**: `M, item_map, items_by_key, dragged_items, items_by_key, new_items`
**Classes**: `M` (stateful objects)
**Public API**:
  - `M.create(rt, config)` → Instance
**Private Functions**: 6 helpers
**Dependencies**: `arkitekt.gui.widgets.grid.core, apps.Region_Playlist.widgets.region_tiles.renderers.active`

### `apps/Region_Playlist/widgets/region_tiles/coordinator.lua`
> @noindex

**Modules**: `M, RegionTiles, playlist_cache, spawned_keys, payload, colors`
**Classes**: `RegionTiles, M` (stateful objects)
**Public API**:
  - `M.create(opts)` → Instance
**Dependencies**: `apps.Region_Playlist.app.config, apps.Region_Playlist.widgets.region_tiles.coordinator_render, arkitekt.gui.draw, arkitekt.core.colors, arkitekt.gui.fx.tile_motion, (+7 more)`

### `apps/Region_Playlist/widgets/region_tiles/coordinator_render.lua`
> @noindex

**Modules**: `M, keys_to_adjust`
**Public API**:
  - `M.draw_selector(self, ctx, playlists, active_id, height)`
  - `M.draw_active(self, ctx, playlist, height)`
  - `M.draw_pool(self, ctx, regions, height)`
  - `M.draw_ghosts(self, ctx)`
**Dependencies**: `arkitekt.gui.fx.dnd.drag_indicator, apps.Region_Playlist.widgets.region_tiles.renderers.active, apps.Region_Playlist.widgets.region_tiles.renderers.pool, arkitekt.gui.systems.responsive_grid`

### `apps/Region_Playlist/widgets/region_tiles/pool_grid_factory.lua`
> @noindex

**Modules**: `M, items_by_key, filtered_keys, rids, rids, items_by_key`
**Classes**: `M` (stateful objects)
**Public API**:
  - `M.create(rt, config)` → Instance
**Private Functions**: 5 helpers
**Dependencies**: `arkitekt.gui.widgets.grid.core, apps.Region_Playlist.widgets.region_tiles.renderers.pool`

### `apps/Region_Playlist/widgets/region_tiles/renderers/active.lua`
> @noindex

**Modules**: `M, right_elements, right_elements`
**Public API**:
  - `M.render(ctx, rect, item, state, get_region_by_rid, animator, on_repeat_cycle, hover_config, tile_height, border_thickness, bridge, get_playlist_by_id)`
  - `M.render_region(ctx, rect, item, state, get_region_by_rid, animator, on_repeat_cycle, hover_config, tile_height, border_thickness, bridge)`
  - `M.render_playlist(ctx, rect, item, state, animator, on_repeat_cycle, hover_config, tile_height, border_thickness, get_playlist_by_id)`
**Dependencies**: `arkitekt.core.colors, arkitekt.gui.draw, arkitekt.gui.fx.tile_fx_config, apps.Region_Playlist.widgets.region_tiles.renderers.base, arkitekt.gui.systems.playback_manager`

### `apps/Region_Playlist/widgets/region_tiles/renderers/base.lua`
> @noindex

**Modules**: `M`
**Public API**:
  - `M.calculate_right_elements_width(ctx, elements)`
  - `M.create_element(visible, width, margin)` → Instance
  - `M.calculate_text_right_bound(ctx, x2, text_margin, right_elements)`
  - `M.draw_base_tile(dl, rect, base_color, fx_config, state, hover_factor, playback_progress, playback_fade)`
  - `M.draw_marching_ants(dl, rect, color, fx_config)`
  - `M.draw_region_text(ctx, dl, pos, region, base_color, text_alpha, right_bound_x)`
  - `M.draw_playlist_text(ctx, dl, pos, playlist_data, state, text_alpha, right_bound_x, name_color_override)`
  - `M.draw_length_display(ctx, dl, rect, region, base_color, text_alpha)`
**Dependencies**: `arkitekt.gui.draw, arkitekt.core.colors, arkitekt.gui.fx.tile_fx, arkitekt.gui.fx.tile_fx_config, arkitekt.gui.fx.marching_ants, (+2 more)`

### `apps/Region_Playlist/widgets/region_tiles/renderers/pool.lua`
> @noindex

**Modules**: `M, right_elements, right_elements`
**Public API**:
  - `M.render(ctx, rect, item, state, animator, hover_config, tile_height, border_thickness)`
  - `M.render_region(ctx, rect, region, state, animator, hover_config, tile_height, border_thickness)`
  - `M.render_playlist(ctx, rect, playlist, state, animator, hover_config, tile_height, border_thickness)`
**Dependencies**: `arkitekt.core.colors, arkitekt.gui.draw, arkitekt.gui.fx.tile_fx_config, arkitekt.gui.systems.tile_utilities, apps.Region_Playlist.widgets.region_tiles.renderers.base`

### `apps/Region_Playlist/widgets/region_tiles/selector.lua`
> @noindex

**Modules**: `M, Selector`
**Classes**: `Selector, M` (stateful objects)
**Public API**:
  - `M.new(config)` → Instance
**Dependencies**: `arkitekt.gui.draw, arkitekt.core.colors, arkitekt.gui.fx.tile_motion`

### `apps/demos/demo.lua`
> @noindex

**Modules**: `result, conflicts, asset_providers`
**Private Functions**: 8 helpers
**Dependencies**: `arkitekt.app.shell, arkitekt.gui.widgets.package_tiles.grid, arkitekt.gui.widgets.package_tiles.micromanage, arkitekt.gui.widgets.panel, arkitekt.gui.widgets.selection_rectangle`

### `apps/demos/demo3.lua`
> @noindex

**Modules**: `pads`
**Private Functions**: 6 helpers
**Dependencies**: `arkitekt.app.shell, arkitekt.gui.widgets.displays.status_pad, arkitekt.app.chrome.status_bar`

### `apps/demos/demo_modal_overlay.lua`
> @noindex

**Modules**: `selected_tag_items`
**Private Functions**: 7 helpers
**Dependencies**: `arkitekt.app.shell, arkitekt.gui.widgets.overlay.sheet, arkitekt.gui.widgets.chip_list.list, arkitekt.gui.widgets.overlay.config`

### `apps/demos/widget_demo.lua`
> @noindex

**Modules**: `t, arr`
**Private Functions**: 12 helpers
**Dependencies**: `arkitekt.app.shell, ReArkitekt.gui.widgets.colorblocks, arkitekt.gui.draw, arkitekt.gui.fx.effects, ReArkitekt.*`

### `arkitekt/app/chrome/status_bar/config.lua`
> @noindex

**Modules**: `M, result`
**Public API**:
  - `M.deep_merge(base, override)`
  - `M.merge(user_config, preset_name)`
**Dependencies**: `arkitekt.gui.widgets.component.chip`

### `arkitekt/app/chrome/status_bar/widget.lua`
> @noindex

**Modules**: `M, right_items`
**Classes**: `M` (stateful objects)
**Public API**:
  - `M.new(config)` → Instance
**Private Functions**: 6 helpers
**Dependencies**: `arkitekt.gui.widgets.component.chip, arkitekt.app.chrome.status_bar.config`

### `arkitekt/app/config.lua`
> @noindex

**Modules**: `M, keys`
**Public API**:
  - `M.get_defaults()`
  - `M.get(path)`

### `arkitekt/app/icon.lua`
> @noindex

**Modules**: `M`
**Public API**:
  - `M.draw_rearkitekt(ctx, x, y, size, color)`
  - `M.draw_rearkitekt_v2(ctx, x, y, size, color)`
  - `M.draw_simple_a(ctx, x, y, size, color)`

### `arkitekt/app/runtime.lua`
> @noindex

**Modules**: `M`
**Classes**: `M` (stateful objects)
**Public API**:
  - `M.new(opts)` → Instance

### `arkitekt/app/shell.lua`
> @noindex

**Modules**: `M, DEFAULTS`
**Public API**:
  - `M.run(opts)`
**Private Functions**: 4 helpers
**Dependencies**: `arkitekt.app.runtime, arkitekt.app.window`

### `arkitekt/app/titlebar.lua`
> @noindex

**Modules**: `M, DEFAULTS`
**Classes**: `M` (stateful objects)
**Public API**:
  - `M.new(opts)` → Instance

### `arkitekt/app/window.lua`
> @noindex

**Modules**: `M, DEFAULTS`
**Classes**: `M` (stateful objects)
**Public API**:
  - `M.new(opts)` → Instance

### `arkitekt/core/colors.lua`
> @noindex

**Modules**: `M`
**Public API**:
  - `M.hexrgb(hex_string)`
  - `M.rgba_to_components(color)`
  - `M.components_to_rgba(r, g, b, a)`
  - `M.with_alpha(color, alpha)`
  - `M.adjust_brightness(color, factor)`
  - `M.desaturate(color, amount)`
  - `M.saturate(color, amount)`
  - `M.luminance(color)`
  - `M.lerp_component(a, b, t)`
  - `M.lerp(color_a, color_b, t)`

### `arkitekt/core/json.lua`
> @noindex

**Modules**: `M, out, obj, arr`
**Public API**:
  - `M.encode(t)`
  - `M.decode(str)`
**Private Functions**: 5 helpers

### `arkitekt/core/lifecycle.lua`
> @noindex

**Modules**: `M, Group`
**Classes**: `Group, M` (stateful objects)
**Public API**:
  - `M.new()` → Instance

### `arkitekt/core/math.lua`
> @noindex

**Modules**: `M`
**Public API**:
  - `M.lerp(a, b, t)`
  - `M.clamp(value, min, max)`
  - `M.remap(value, in_min, in_max, out_min, out_max)`
  - `M.snap(value, step)`
  - `M.smoothdamp(current, target, velocity, smoothtime, maxspeed, dt)`
  - `M.approximately(a, b, epsilon)`

### `arkitekt/core/settings.lua`
> @noindex

**Modules**: `Settings, out, M, t`
**Classes**: `Settings` (stateful objects)
**Public API**:
  - `M.open(cache_dir, filename)`
**Private Functions**: 7 helpers
**Dependencies**: `arkitekt.core.json`

### `arkitekt/core/undo_manager.lua`
> @noindex

**Modules**: `M`
**Classes**: `M` (stateful objects)
**Public API**:
  - `M.new(opts)` → Instance

## State Ownership

### Stateful Modules (Classes/Objects)
- **`controller.lua`**: Controller, M
- **`gui.lua`**: GUI, M
- **`color_grid.lua`**: ColorGrid, M
- **`controller.lua`**: Controller, M
- **`gui.lua`**: GUI, M
- **`status.lua`**: M
- **`coordinator_bridge.lua`**: M
- **`core.lua`**: Engine, M
- **`playback.lua`**: Playback, M
- **`quantize.lua`**: Quantize, M
- ... and 37 more

### Stateless Modules (Pure Functions)
- **60** stateless modules
- **33** with no dependencies (pure utility modules)

## Integration Essentials

### Module Creators
- `M.new()` in `controller.lua`
- `M.create(State, settings, overlay_manager)` in `gui.lua`
- `M.initialize(settings)` in `state.lua`
- `M.new()` in `color_grid.lua`
- `M.new(state_module, settings, undo_manager)` in `controller.lua`
- `M.create(State, AppConfig, settings)` in `gui.lua`
- `M.initialize(settings)` in `state.lua`
- `M.create_playlist_item(playlist_id, reps)` in `state.lua`
- ... and 44 more

### Callback-Based APIs
- `M.get_active_container_config()` expects: callbacks
- `M.get_pool_container_config()` expects: callbacks
- `M.render()` expects: on_repeat_cycle
- `M.render_region()` expects: on_repeat_cycle
- `M.render_playlist()` expects: on_repeat_cycle
- ... and 9 more

## Module Classification

**Pure Modules** (no dependencies): 53
  - `apps/ColorPalette/app/controller.lua`
  - `apps/Region_Playlist/app/config.lua`
  - `apps/Region_Playlist/app/status.lua`
  - `apps/Region_Playlist/engine/quantize.lua`
  - `apps/Region_Playlist/engine/transitions.lua`
  - ... and 48 more

**Class Modules** (OOP with metatables): 47
  - `controller.lua`: Controller, M
  - `gui.lua`: GUI, M
  - `color_grid.lua`: ColorGrid, M
  - `controller.lua`: Controller, M
  - `gui.lua`: GUI, M
  - ... and 42 more

## Top 10 Largest Files

1. `apps/Region_Playlist/app/gui.lua` (892 lines)
2. `arkitekt/gui/widgets/tiles_container_old.lua` (753 lines)
3. `arkitekt/gui/widgets/panel/header/tab_strip.lua` (731 lines)
4. `arkitekt/gui/widgets/panel/modes/tabs.lua` (647 lines)
5. `apps/Region_Playlist/app/state.lua` (597 lines)
6. `arkitekt/app/window.lua` (560 lines)
7. `arkitekt/core/colors.lua` (550 lines)
8. `arkitekt/gui/widgets/grid/core.lua` (550 lines)
9. `apps/Region_Playlist/widgets/region_tiles/coordinator.lua` (503 lines)
10. `arkitekt/app/titlebar.lua` (454 lines)

## Dependency Analysis

### Forward Dependencies (What Each File Imports)

**`arkitekt/gui/widgets/grid/core.lua`** imports 13 modules:
  → `arkitekt/core/colors.lua`
  → `arkitekt/gui/draw.lua`
  → `arkitekt/gui/fx/animation/rect_track.lua`
  → `arkitekt/gui/fx/dnd/drag_indicator.lua`
  → `arkitekt/gui/fx/dnd/drop_indicator.lua`
  → `arkitekt/gui/systems/selection.lua`
  → `arkitekt/gui/widgets/grid/animation.lua`
  → `arkitekt/gui/widgets/grid/dnd_state.lua`
  → ... and 5 more

**`apps/Region_Playlist/widgets/region_tiles/coordinator.lua`** imports 11 modules:
  → `apps/Region_Playlist/app/config.lua`
  → `apps/Region_Playlist/app/state.lua`
  → `apps/Region_Playlist/widgets/region_tiles/active_grid_factory.lua`
  → `apps/Region_Playlist/widgets/region_tiles/coordinator_render.lua`
  → `apps/Region_Playlist/widgets/region_tiles/pool_grid_factory.lua`
  → `apps/Region_Playlist/widgets/region_tiles/selector.lua`
  → `arkitekt/core/colors.lua`
  → `arkitekt/gui/draw.lua`
  → ... and 3 more

**`apps/Region_Playlist/app/gui.lua`** imports 9 modules:
  → `apps/Region_Playlist/app/config.lua`
  → `apps/Region_Playlist/app/controller.lua`
  → `apps/Region_Playlist/app/shortcuts.lua`
  → `apps/Region_Playlist/widgets/region_tiles/coordinator.lua`
  → `arkitekt/core/colors.lua`
  → `arkitekt/gui/fx/tile_motion.lua`
  → `arkitekt/gui/widgets/chip_list/list.lua`
  → `arkitekt/gui/widgets/overlay/sheet.lua`
  → ... and 1 more

**`apps/Region_Playlist/widgets/region_tiles/renderers/base.lua`** imports 7 modules:
  → `arkitekt/core/colors.lua`
  → `arkitekt/gui/draw.lua`
  → `arkitekt/gui/fx/marching_ants.lua`
  → `arkitekt/gui/fx/tile_fx.lua`
  → `arkitekt/gui/fx/tile_fx_config.lua`
  → `arkitekt/gui/systems/tile_utilities.lua`
  → `arkitekt/gui/widgets/component/chip.lua`

**`arkitekt/gui/widgets/package_tiles/grid.lua`** imports 6 modules:
  → `arkitekt/core/colors.lua`
  → `arkitekt/gui/fx/tile_motion.lua`
  → `arkitekt/gui/systems/height_stabilizer.lua`
  → `arkitekt/gui/widgets/grid/core.lua`
  → `arkitekt/gui/widgets/package_tiles/micromanage.lua`
  → `arkitekt/gui/widgets/package_tiles/renderer.lua`

**`arkitekt/gui/widgets/panel/init.lua`** imports 6 modules:
  → `arkitekt/gui/widgets/controls/scrollbar.lua`
  → `arkitekt/gui/widgets/panel/background.lua`
  → `arkitekt/gui/widgets/panel/config.lua`
  → `arkitekt/gui/widgets/panel/content.lua`
  → `arkitekt/gui/widgets/panel/header.lua`
  → `arkitekt/gui/widgets/panel/tab_animator.lua`

**`apps/ColorPalette/app/gui.lua`** imports 5 modules:
  → `apps/ColorPalette/app/controller.lua`
  → `apps/ColorPalette/widgets/color_grid.lua`
  → `arkitekt/core/colors.lua`
  → `arkitekt/gui/draw.lua`
  → `arkitekt/gui/widgets/overlay/sheet.lua`

**`apps/ColorPalette/ARK_ColorPalette.lua`** imports 5 modules:
  → `apps/ColorPalette/app/gui.lua`
  → `apps/ColorPalette/app/state.lua`
  → `arkitekt/app/shell.lua`
  → `arkitekt/core/settings.lua`
  → `arkitekt/gui/widgets/overlay/manager.lua`

**`apps/Region_Playlist/app/state.lua`** imports 5 modules:
  → `apps/Region_Playlist/engine/coordinator_bridge.lua`
  → `apps/Region_Playlist/storage/state.lua`
  → `apps/Region_Playlist/storage/undo_bridge.lua`
  → `arkitekt/core/colors.lua`
  → `arkitekt/core/undo_manager.lua`

**`apps/Region_Playlist/ARK_RegionPlaylist.lua`** imports 5 modules:
  → `apps/Region_Playlist/app/config.lua`
  → `apps/Region_Playlist/app/gui.lua`
  → `apps/Region_Playlist/app/state.lua`
  → `apps/Region_Playlist/app/status.lua`
  → `arkitekt/app/shell.lua`

**`apps/Region_Playlist/widgets/region_tiles/renderers/active.lua`** imports 5 modules:
  → `apps/Region_Playlist/widgets/region_tiles/renderers/base.lua`
  → `arkitekt/core/colors.lua`
  → `arkitekt/gui/draw.lua`
  → `arkitekt/gui/fx/tile_fx_config.lua`
  → `arkitekt/gui/systems/playback_manager.lua`

**`apps/Region_Playlist/widgets/region_tiles/renderers/pool.lua`** imports 5 modules:
  → `apps/Region_Playlist/widgets/region_tiles/renderers/base.lua`
  → `arkitekt/core/colors.lua`
  → `arkitekt/gui/draw.lua`
  → `arkitekt/gui/fx/tile_fx_config.lua`
  → `arkitekt/gui/systems/tile_utilities.lua`

**`arkitekt/gui/widgets/panel/header/layout.lua`** imports 5 modules:
  → `arkitekt/gui/widgets/panel/header/button.lua`
  → `arkitekt/gui/widgets/panel/header/dropdown_field.lua`
  → `arkitekt/gui/widgets/panel/header/search_field.lua`
  → `arkitekt/gui/widgets/panel/header/separator.lua`
  → `arkitekt/gui/widgets/panel/header/tab_strip.lua`

**`apps/demos/demo.lua`** imports 4 modules:
  → `arkitekt/app/shell.lua`
  → `arkitekt/gui/widgets/package_tiles/grid.lua`
  → `arkitekt/gui/widgets/package_tiles/micromanage.lua`
  → `arkitekt/gui/widgets/selection_rectangle.lua`

**`apps/demos/demo_modal_overlay.lua`** imports 4 modules:
  → `arkitekt/app/shell.lua`
  → `arkitekt/gui/widgets/chip_list/list.lua`
  → `arkitekt/gui/widgets/overlay/config.lua`
  → `arkitekt/gui/widgets/overlay/sheet.lua`

**`apps/Region_Playlist/engine/core.lua`** imports 4 modules:
  → `apps/Region_Playlist/engine/quantize.lua`
  → `apps/Region_Playlist/engine/state.lua`
  → `apps/Region_Playlist/engine/transitions.lua`
  → `apps/Region_Playlist/engine/transport.lua`

**`apps/Region_Playlist/widgets/region_tiles/coordinator_render.lua`** imports 4 modules:
  → `apps/Region_Playlist/widgets/region_tiles/renderers/active.lua`
  → `apps/Region_Playlist/widgets/region_tiles/renderers/pool.lua`
  → `arkitekt/gui/fx/dnd/drag_indicator.lua`
  → `arkitekt/gui/systems/responsive_grid.lua`

**`arkitekt/gui/widgets/component/chip.lua`** imports 4 modules:
  → `arkitekt/core/colors.lua`
  → `arkitekt/gui/draw.lua`
  → `arkitekt/gui/fx/tile_fx.lua`
  → `arkitekt/gui/fx/tile_fx_config.lua`

**`arkitekt/gui/widgets/displays/status_pad.lua`** imports 4 modules:
  → `arkitekt/core/colors.lua`
  → `arkitekt/gui/draw.lua`
  → `arkitekt/gui/fx/tile_fx.lua`
  → `arkitekt/gui/fx/tile_fx_config.lua`

**`arkitekt/gui/widgets/overlay/manager.lua`** imports 4 modules:
  → `arkitekt/core/colors.lua`
  → `arkitekt/gui/draw.lua`
  → `arkitekt/gui/style.lua`
  → `arkitekt/gui/widgets/overlay/config.lua`

### Reverse Dependencies (What Imports Each File)

**`arkitekt/core/colors.lua`** is imported by 23 files:
  ← `apps/ColorPalette/app/gui.lua`
  ← `apps/ColorPalette/app/state.lua`
  ← `apps/ColorPalette/widgets/color_grid.lua`
  ← `apps/Region_Playlist/app/gui.lua`
  ← `apps/Region_Playlist/app/state.lua`
  ← `apps/Region_Playlist/storage/state.lua`
  ← `apps/Region_Playlist/widgets/region_tiles/coordinator.lua`
  ← `apps/Region_Playlist/widgets/region_tiles/renderers/active.lua`
  ← ... and 15 more

**`arkitekt/gui/draw.lua`** is imported by 18 files:
  ← `apps/ColorPalette/app/gui.lua`
  ← `apps/ColorPalette/widgets/color_grid.lua`
  ← `apps/Region_Playlist/widgets/region_tiles/coordinator.lua`
  ← `apps/Region_Playlist/widgets/region_tiles/renderers/active.lua`
  ← `apps/Region_Playlist/widgets/region_tiles/renderers/base.lua`
  ← `apps/Region_Playlist/widgets/region_tiles/renderers/pool.lua`
  ← `apps/Region_Playlist/widgets/region_tiles/selector.lua`
  ← `apps/demos/widget_demo.lua`
  ← ... and 10 more

**`arkitekt/app/shell.lua`** is imported by 7 files:
  ← `apps/ColorPalette/ARK_ColorPalette.lua`
  ← `apps/Region_Playlist/ARK_RegionPlaylist.lua`
  ← `apps/demos/demo.lua`
  ← `apps/demos/demo2.lua`
  ← `apps/demos/demo3.lua`
  ← `apps/demos/demo_modal_overlay.lua`
  ← `apps/demos/widget_demo.lua`

**`arkitekt/gui/widgets/component/chip.lua`** is imported by 6 files:
  ← `apps/Region_Playlist/widgets/region_tiles/renderers/base.lua`
  ← `arkitekt/app/chrome/status_bar/config.lua`
  ← `arkitekt/app/chrome/status_bar/widget.lua`
  ← `arkitekt/gui/widgets/chip_list/list.lua`
  ← `arkitekt/gui/widgets/panel/header/tab_strip.lua`
  ← `arkitekt/gui/widgets/panel/modes/tabs.lua`

**`arkitekt/gui/fx/tile_fx_config.lua`** is imported by 5 files:
  ← `apps/Region_Playlist/widgets/region_tiles/renderers/active.lua`
  ← `apps/Region_Playlist/widgets/region_tiles/renderers/base.lua`
  ← `apps/Region_Playlist/widgets/region_tiles/renderers/pool.lua`
  ← `arkitekt/gui/widgets/component/chip.lua`
  ← `arkitekt/gui/widgets/displays/status_pad.lua`

**`arkitekt/gui/fx/tile_motion.lua`** is imported by 4 files:
  ← `apps/Region_Playlist/app/gui.lua`
  ← `apps/Region_Playlist/widgets/region_tiles/coordinator.lua`
  ← `apps/Region_Playlist/widgets/region_tiles/selector.lua`
  ← `arkitekt/gui/widgets/package_tiles/grid.lua`

**`apps/Region_Playlist/app/config.lua`** is imported by 3 files:
  ← `apps/Region_Playlist/ARK_RegionPlaylist.lua`
  ← `apps/Region_Playlist/app/gui.lua`
  ← `apps/Region_Playlist/widgets/region_tiles/coordinator.lua`

**`apps/Region_Playlist/app/state.lua`** is imported by 3 files:
  ← `apps/Region_Playlist/ARK_RegionPlaylist.lua`
  ← `apps/Region_Playlist/app/shortcuts.lua`
  ← `apps/Region_Playlist/widgets/region_tiles/coordinator.lua`

**`apps/Region_Playlist/storage/state.lua`** is imported by 3 files:
  ← `apps/Region_Playlist/app/controller.lua`
  ← `apps/Region_Playlist/app/state.lua`
  ← `apps/Region_Playlist/engine/coordinator_bridge.lua`

**`arkitekt/gui/fx/easing.lua`** is imported by 3 files:
  ← `arkitekt/gui/fx/animations/destroy.lua`
  ← `arkitekt/gui/fx/animations/spawn.lua`
  ← `arkitekt/gui/widgets/panel/tab_animator.lua`

**`arkitekt/gui/fx/marching_ants.lua`** is imported by 3 files:
  ← `apps/Region_Playlist/widgets/region_tiles/renderers/base.lua`
  ← `arkitekt/gui/widgets/grid/rendering.lua`
  ← `arkitekt/gui/widgets/package_tiles/renderer.lua`

**`arkitekt/gui/fx/tile_fx.lua`** is imported by 3 files:
  ← `apps/Region_Playlist/widgets/region_tiles/renderers/base.lua`
  ← `arkitekt/gui/widgets/component/chip.lua`
  ← `arkitekt/gui/widgets/displays/status_pad.lua`

**`arkitekt/gui/widgets/controls/dropdown.lua`** is imported by 3 files:
  ← `arkitekt/gui/widgets/panel/header/dropdown_field.lua`
  ← `arkitekt/gui/widgets/panel/modes/search_sort.lua`
  ← `arkitekt/gui/widgets/tiles_container_old.lua`

**`arkitekt/gui/widgets/grid/core.lua`** is imported by 3 files:
  ← `apps/Region_Playlist/widgets/region_tiles/active_grid_factory.lua`
  ← `apps/Region_Playlist/widgets/region_tiles/pool_grid_factory.lua`
  ← `arkitekt/gui/widgets/package_tiles/grid.lua`

**`arkitekt/gui/widgets/overlay/config.lua`** is imported by 3 files:
  ← `apps/demos/demo_modal_overlay.lua`
  ← `arkitekt/gui/widgets/overlay/manager.lua`
  ← `arkitekt/gui/widgets/overlay/sheet.lua`

### Circular Dependencies

✓ No circular dependencies detected

### Isolated Files (No Imports or Exports)

- `apps/Region_Playlist/widgets/controls/controls_widget.lua`
- `arkitekt/app/config.lua`
- `arkitekt/app/icon.lua`
- `arkitekt/app/titlebar.lua`
- `arkitekt/core/lifecycle.lua`
- `arkitekt/gui/images.lua`
- `arkitekt/gui/systems/reorder.lua`
- `arkitekt/gui/widgets/navigation/menutabs.lua`
- `arkitekt/input/wheel_guard.lua`
- `arkitekt/reaper/timing.lua`

### Dependency Complexity Ranking

1. `arkitekt/core/colors.lua`: 0 imports + 23 importers = 23 total
2. `arkitekt/gui/draw.lua`: 0 imports + 18 importers = 18 total
3. `arkitekt/gui/widgets/grid/core.lua`: 13 imports + 3 importers = 16 total
4. `apps/Region_Playlist/widgets/region_tiles/coordinator.lua`: 11 imports + 1 importers = 12 total
5. `apps/Region_Playlist/app/gui.lua`: 9 imports + 1 importers = 10 total
6. `arkitekt/gui/widgets/component/chip.lua`: 4 imports + 6 importers = 10 total
7. `apps/Region_Playlist/widgets/region_tiles/renderers/base.lua`: 7 imports + 2 importers = 9 total
8. `arkitekt/app/shell.lua`: 2 imports + 7 importers = 9 total
9. `apps/Region_Playlist/app/state.lua`: 5 imports + 3 importers = 8 total
10. `apps/Region_Playlist/widgets/region_tiles/renderers/active.lua`: 5 imports + 2 importers = 7 total

## Important Constraints

### Object Lifecycle
- Classes use metatable pattern: `ClassName.__index = ClassName`
- Constructor functions typically named `new()` or `create()`
- Always call constructor before using instance methods

### Callback Requirements
- 14 modules use callback patterns for extensibility
- Callbacks enable features like event handling and custom behavior
- Check function signatures for `on_*`, `*_callback`, or `*_handler` parameters
