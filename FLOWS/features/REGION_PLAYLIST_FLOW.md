# REGION_PLAYLIST FLOW
Generated: 2025-10-16 01:20:52

## Overview
- **Folders**: 1
- **Files**: 26
- **Total Lines**: 6,450
- **Code Lines**: 5,120
- **Exports**: 81
- **Classes**: 24

## Folder Organization

### ARKITEKT/scripts/Region_Playlist
- Files: 26
- Lines: 5,120
- Exports: 81

## Orchestrators

**`ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/coordinator.lua`** (13 dependencies)
  Composes: config + coordinator_render + draw + colors + tile_motion + height_stabilizer + selector + active_grid_factory + pool_grid_factory + grid_bridge + panel + config + state

**`ARKITEKT/scripts/Region_Playlist/app/gui.lua`** (9 dependencies)
  Composes: coordinator + colors + shortcuts + controller + transport_container + sheet + list + config + tile_motion

**`ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/base.lua`** (7 dependencies)
  Composes: draw + colors + tile_fx + tile_fx_config + marching_ants + tile_utilities + chip

**`ARKITEKT/scripts/Region_Playlist/ARK_RegionPlaylist.lua`** (6 dependencies)
  Composes: shell + config + state + gui + status + colors

**`ARKITEKT/scripts/Region_Playlist/app/state.lua`** (5 dependencies)
  Composes: coordinator_bridge + state + undo_manager + undo_bridge + colors

## Module API

### `ARKITEKT/scripts/Region_Playlist/app/config.lua` (349 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.get_active_container_config(callbacks)`
  - `M.get_pool_container_config(callbacks)`
  - `M.get_region_tiles_config(layout_mode)`

### `ARKITEKT/scripts/Region_Playlist/app/controller.lua` (368 lines)
> @noindex
**Modules**: `M, Controller, keys, keys, keys_set, new_items, keys_set, keys_set`
**Classes**: `Controller, M`
**Exports**:
  - `M.new(state_module, settings, undo_manager)` → Instance
**Requires**: `Region_Playlist.storage.state`

### `ARKITEKT/scripts/Region_Playlist/app/gui.lua` (919 lines)
> @noindex
**Modules**: `M, GUI, tab_items, selected_ids, filtered`
**Classes**: `GUI, M`
**Exports**:
  - `M.create(State, AppConfig, settings)` → Instance
**Requires**: `Region_Playlist.widgets.region_tiles.coordinator, rearkitekt.core.colors, Region_Playlist.app.shortcuts, Region_Playlist.app.controller, rearkitekt.gui.widgets.transport.transport_container, rearkitekt.gui.widgets.overlay.sheet, rearkitekt.gui.widgets.chip_list.list, Region_Playlist.app.config, rearkitekt.gui.fx.tile_motion`

### `ARKITEKT/scripts/Region_Playlist/app/sequence_expander.lua` (104 lines)
> @noindex
**Modules**: `SequenceExpander, nested_sequence, sequence`
**Exports**:
  - `SequenceExpander.expand_playlist(playlist, get_playlist_by_id)`
  - `SequenceExpander.debug_print_sequence(sequence, get_region_by_rid)`

### `ARKITEKT/scripts/Region_Playlist/app/shortcuts.lua` (81 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.handle_keyboard_shortcuts(ctx, state, region_tiles)`
**Requires**: `Region_Playlist.app.state`

### `ARKITEKT/scripts/Region_Playlist/app/state.lua` (618 lines)
> @noindex
**Modules**: `M, tabs, result, reversed, all_deps, visited, pool_playlists, filtered, reversed, new_path, path_array`
**Exports**:
  - `M.initialize(settings)`
  - `M.load_project_state()`
  - `M.reload_project_data()`
  - `M.get_active_playlist()`
  - `M.get_playlist_by_id(playlist_id)`
  - `M.get_tabs()`
  - `M.refresh_regions()`
  - `M.persist()`
  - `M.persist_ui_prefs()`
  - `M.capture_undo_snapshot()`
  - `M.clear_pending()`
  - `M.restore_snapshot(snapshot)`
  - `M.undo()`
  - `M.redo()`
  - `M.can_undo()`
  - `M.can_redo()`
  - `M.set_active_playlist(playlist_id)`
  - `M.get_filtered_pool_regions()`
  - `M.mark_graph_dirty()`
  - `M.rebuild_dependency_graph()`
  - `M.is_playlist_draggable_to(playlist_id, target_playlist_id)`
  - `M.get_playlists_for_pool()`
  - `M.detect_circular_reference(target_playlist_id, playlist_id_to_add)`
  - `M.create_playlist_item(playlist_id, reps)` → Instance
  - `M.cleanup_deleted_regions()`
  - `M.update()`
**Private**: 9 helpers
**Requires**: `Region_Playlist.engine.coordinator_bridge, Region_Playlist.storage.state, rearkitekt.core.undo_manager, Region_Playlist.storage.undo_bridge, rearkitekt.core.colors`

### `ARKITEKT/scripts/Region_Playlist/app/status.lua` (59 lines)
> @noindex
**Modules**: `M`
**Classes**: `M`
**Exports**:
  - `M.create(State, Style)` → Instance
**Requires**: `rearkitekt.app.chrome.status_bar`

### `ARKITEKT/scripts/Region_Playlist/engine/coordinator_bridge.lua` (290 lines)
> @noindex
**Modules**: `M, sequence, regions`
**Classes**: `M`
**Exports**:
  - `M.create(opts)` → Instance
**Requires**: `Region_Playlist.engine.core, Region_Playlist.engine.playback, Region_Playlist.storage.state, Region_Playlist.app.sequence_expander`

### `ARKITEKT/scripts/Region_Playlist/engine/core.lua` (194 lines)
> @noindex
**Modules**: `M, Engine, order`
**Classes**: `Engine, M`
**Exports**:
  - `M.new(opts)` → Instance
**Requires**: `Region_Playlist.engine.state, Region_Playlist.engine.transport, Region_Playlist.engine.transitions, Region_Playlist.engine.quantize`

### `ARKITEKT/scripts/Region_Playlist/engine/playback.lua` (103 lines)
> @noindex
**Modules**: `M, Playback`
**Classes**: `Playback, M`
**Exports**:
  - `M.new(engine, opts)` → Instance
**Requires**: `rearkitekt.reaper.transport`

### `ARKITEKT/scripts/Region_Playlist/engine/quantize.lua` (337 lines)
> @noindex
**Modules**: `M, Quantize`
**Classes**: `Quantize, M`
**Exports**:
  - `M.new(opts)` → Instance

### `ARKITEKT/scripts/Region_Playlist/engine/state.lua` (324 lines)
> @noindex
**Modules**: `M, State, sequence_copy, sequence`
**Classes**: `State, M`
**Exports**:
  - `M.new(opts)` → Instance
**Requires**: `rearkitekt.reaper.regions, rearkitekt.reaper.transport`

### `ARKITEKT/scripts/Region_Playlist/engine/transitions.lua` (211 lines)
> @noindex
**Modules**: `M, Transitions`
**Classes**: `Transitions, M`
**Exports**:
  - `M.new(opts)` → Instance

### `ARKITEKT/scripts/Region_Playlist/engine/transport.lua` (239 lines)
> @noindex
**Modules**: `M, Transport`
**Classes**: `Transport, M`
**Exports**:
  - `M.new(opts)` → Instance

### `ARKITEKT/scripts/Region_Playlist/storage/state.lua` (152 lines)
> @noindex
**Modules**: `M, default_items`
**Exports**:
  - `M.save_playlists(playlists, proj)`
  - `M.load_playlists(proj)`
  - `M.save_active_playlist(playlist_id, proj)`
  - `M.load_active_playlist(proj)`
  - `M.save_settings(settings, proj)`
  - `M.load_settings(proj)`
  - `M.clear_all(proj)`
  - `M.get_or_create_default_playlist(playlists, regions)` → Instance
  - `M.generate_chip_color()`
**Requires**: `rearkitekt.core.json, rearkitekt.core.colors`

### `ARKITEKT/scripts/Region_Playlist/storage/undo_bridge.lua` (91 lines)
> @noindex
**Modules**: `M, restored_playlists`
**Exports**:
  - `M.capture_snapshot(playlists, active_playlist_id)`
  - `M.restore_snapshot(snapshot, region_index)`
  - `M.should_capture(old_playlists, new_playlists)`

### `ARKITEKT/scripts/Region_Playlist/widgets/controls/controls_widget.lua` (151 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.draw_transport_controls(ctx, bridge, x, y)`
  - `M.draw_quantize_selector(ctx, bridge, x, y, width)`
  - `M.draw_playback_info(ctx, bridge, x, y, width)`
  - `M.draw_complete_controls(ctx, bridge, x, y, available_width)`

### `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/active_grid_factory.lua` (220 lines)
> @noindex
**Modules**: `M, item_map, items_by_key, dragged_items, items_by_key, new_items`
**Classes**: `M`
**Exports**:
  - `M.create(rt, config)` → Instance
**Private**: 6 helpers
**Requires**: `rearkitekt.gui.widgets.grid.core, Region_Playlist.widgets.region_tiles.renderers.active`

### `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/coordinator.lua` (505 lines)
> @noindex
**Modules**: `M, RegionTiles, playlist_cache, spawned_keys, payload, colors`
**Classes**: `RegionTiles, M`
**Exports**:
  - `M.create(opts)` → Instance
**Requires**: `Region_Playlist.app.config, Region_Playlist.widgets.region_tiles.coordinator_render, rearkitekt.gui.draw, rearkitekt.core.colors, rearkitekt.gui.fx.tile_motion, rearkitekt.gui.systems.height_stabilizer, Region_Playlist.widgets.region_tiles.selector, Region_Playlist.widgets.region_tiles.active_grid_factory, Region_Playlist.widgets.region_tiles.pool_grid_factory, rearkitekt.gui.widgets.grid.grid_bridge, rearkitekt.gui.widgets.panel, rearkitekt.gui.widgets.panel.config, Region_Playlist.app.state`

### `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/coordinator_render.lua` (190 lines)
> @noindex
**Modules**: `M, keys_to_adjust`
**Exports**:
  - `M.draw_selector(self, ctx, playlists, active_id, height)`
  - `M.draw_active(self, ctx, playlist, height)`
  - `M.draw_pool(self, ctx, regions, height)`
  - `M.draw_ghosts(self, ctx)`
**Requires**: `rearkitekt.gui.fx.dnd.drag_indicator, Region_Playlist.widgets.region_tiles.renderers.active, Region_Playlist.widgets.region_tiles.renderers.pool, rearkitekt.gui.systems.responsive_grid`

### `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/pool_grid_factory.lua` (193 lines)
> @noindex
**Modules**: `M, items_by_key, filtered_keys, rids, rids, items_by_key`
**Classes**: `M`
**Exports**:
  - `M.create(rt, config)` → Instance
**Private**: 5 helpers
**Requires**: `rearkitekt.gui.widgets.grid.core, Region_Playlist.widgets.region_tiles.renderers.pool`

### `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/active.lua` (186 lines)
> @noindex
**Modules**: `M, right_elements, right_elements`
**Exports**:
  - `M.render(ctx, rect, item, state, get_region_by_rid, animator, on_repeat_cycle, hover_config, tile_height, border_thickness, bridge, get_playlist_by_id)`
  - `M.render_region(ctx, rect, item, state, get_region_by_rid, animator, on_repeat_cycle, hover_config, tile_height, border_thickness, bridge)`
  - `M.render_playlist(ctx, rect, item, state, animator, on_repeat_cycle, hover_config, tile_height, border_thickness, get_playlist_by_id)`
**Requires**: `rearkitekt.core.colors, rearkitekt.gui.draw, rearkitekt.gui.fx.tile_fx_config, Region_Playlist.widgets.region_tiles.renderers.base, rearkitekt.gui.systems.playback_manager`

### `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/base.lua` (207 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.calculate_right_elements_width(ctx, elements)`
  - `M.create_element(visible, width, margin)` → Instance
  - `M.calculate_text_right_bound(ctx, x2, text_margin, right_elements)`
  - `M.calculate_text_position(ctx, rect, actual_height, text_sample)`
  - `M.draw_base_tile(dl, rect, base_color, fx_config, state, hover_factor, playback_progress, playback_fade)`
  - `M.draw_marching_ants(dl, rect, color, fx_config)`
  - `M.draw_region_text(ctx, dl, pos, region, base_color, text_alpha, right_bound_x)`
  - `M.draw_playlist_text(ctx, dl, pos, playlist_data, state, text_alpha, right_bound_x, name_color_override)`
  - `M.draw_length_display(ctx, dl, rect, region, base_color, text_alpha)`
**Requires**: `rearkitekt.gui.draw, rearkitekt.core.colors, rearkitekt.gui.fx.tile_fx, rearkitekt.gui.fx.tile_fx_config, rearkitekt.gui.fx.marching_ants, rearkitekt.gui.systems.tile_utilities, rearkitekt.gui.widgets.component.chip`

### `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/pool.lua` (180 lines)
> @noindex
**Modules**: `M, right_elements, right_elements`
**Exports**:
  - `M.render(ctx, rect, item, state, animator, hover_config, tile_height, border_thickness)`
  - `M.render_region(ctx, rect, region, state, animator, hover_config, tile_height, border_thickness)`
  - `M.render_playlist(ctx, rect, playlist, state, animator, hover_config, tile_height, border_thickness)`
**Requires**: `rearkitekt.core.colors, rearkitekt.gui.draw, rearkitekt.gui.fx.tile_fx_config, rearkitekt.gui.systems.tile_utilities, Region_Playlist.widgets.region_tiles.renderers.base`

### `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/selector.lua` (98 lines)
> @noindex
**Modules**: `M, Selector`
**Classes**: `Selector, M`
**Exports**:
  - `M.new(config)` → Instance
**Requires**: `rearkitekt.gui.draw, rearkitekt.core.colors, rearkitekt.gui.fx.tile_motion`

## Internal Dependencies

**`ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/coordinator.lua`**
  → `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/active_grid_factory.lua`
  → `ARKITEKT/scripts/Region_Playlist/app/state.lua`
  → `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/pool_grid_factory.lua`
  → `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/selector.lua`
  → `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/coordinator_render.lua`
  → `ARKITEKT/scripts/Region_Playlist/app/config.lua`

**`ARKITEKT/scripts/Region_Playlist/app/gui.lua`**
  → `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/coordinator.lua`
  → `ARKITEKT/scripts/Region_Playlist/app/shortcuts.lua`
  → `ARKITEKT/scripts/Region_Playlist/app/config.lua`
  → `ARKITEKT/scripts/Region_Playlist/app/controller.lua`

**`ARKITEKT/scripts/Region_Playlist/ARK_RegionPlaylist.lua`**
  → `ARKITEKT/scripts/Region_Playlist/app/status.lua`
  → `ARKITEKT/scripts/Region_Playlist/app/gui.lua`
  → `ARKITEKT/scripts/Region_Playlist/app/config.lua`
  → `ARKITEKT/scripts/Region_Playlist/app/state.lua`

**`ARKITEKT/scripts/Region_Playlist/app/state.lua`**
  → `ARKITEKT/scripts/Region_Playlist/engine/coordinator_bridge.lua`
  → `ARKITEKT/scripts/Region_Playlist/storage/undo_bridge.lua`
  → `ARKITEKT/scripts/Region_Playlist/storage/state.lua`

**`ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/active.lua`**
  → `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/base.lua`

**`ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/pool.lua`**
  → `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/base.lua`

**`ARKITEKT/scripts/Region_Playlist/engine/coordinator_bridge.lua`**
  → `ARKITEKT/scripts/Region_Playlist/storage/state.lua`
  → `ARKITEKT/scripts/Region_Playlist/engine/playback.lua`
  → `ARKITEKT/scripts/Region_Playlist/engine/core.lua`
  → `ARKITEKT/scripts/Region_Playlist/app/sequence_expander.lua`

**`ARKITEKT/scripts/Region_Playlist/engine/core.lua`**
  → `ARKITEKT/scripts/Region_Playlist/engine/transport.lua`
  → `ARKITEKT/scripts/Region_Playlist/engine/state.lua`
  → `ARKITEKT/scripts/Region_Playlist/engine/quantize.lua`
  → `ARKITEKT/scripts/Region_Playlist/engine/transitions.lua`

**`ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/coordinator_render.lua`**
  → `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/active.lua`
  → `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/pool.lua`

**`ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/active_grid_factory.lua`**
  → `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/active.lua`

**`ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/pool_grid_factory.lua`**
  → `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/pool.lua`

**`ARKITEKT/scripts/Region_Playlist/app/controller.lua`**
  → `ARKITEKT/scripts/Region_Playlist/storage/state.lua`

**`ARKITEKT/scripts/Region_Playlist/app/shortcuts.lua`**
  → `ARKITEKT/scripts/Region_Playlist/app/state.lua`

## External Dependencies

**`ARKITEKT/rearkitekt/core/colors.lua`** (used by 9 files)
  ← `ARKITEKT/scripts/Region_Playlist/app/gui.lua`
  ← `ARKITEKT/scripts/Region_Playlist/app/state.lua`
  ← `ARKITEKT/scripts/Region_Playlist/ARK_RegionPlaylist.lua`
  ← `ARKITEKT/scripts/Region_Playlist/storage/state.lua`
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/coordinator.lua`
  ← ... +4 more

**`ARKITEKT/rearkitekt/gui/draw.lua`** (used by 5 files)
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/coordinator.lua`
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/active.lua`
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/base.lua`
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/pool.lua`
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/selector.lua`

**`ARKITEKT/rearkitekt/gui/fx/tile_motion.lua`** (used by 3 files)
  ← `ARKITEKT/scripts/Region_Playlist/app/gui.lua`
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/coordinator.lua`
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/selector.lua`

**`ARKITEKT/rearkitekt/gui/fx/tile_fx_config.lua`** (used by 3 files)
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/active.lua`
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/base.lua`
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/pool.lua`

**`ARKITEKT/rearkitekt/reaper/transport.lua`** (used by 2 files)
  ← `ARKITEKT/scripts/Region_Playlist/engine/playback.lua`
  ← `ARKITEKT/scripts/Region_Playlist/engine/state.lua`

**`ARKITEKT/rearkitekt/gui/widgets/grid/core.lua`** (used by 2 files)
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/active_grid_factory.lua`
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/pool_grid_factory.lua`

**`ARKITEKT/rearkitekt/gui/systems/tile_utilities.lua`** (used by 2 files)
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/base.lua`
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/pool.lua`

**`ARKITEKT/rearkitekt/gui/widgets/transport/transport_container.lua`** (used by 1 files)
  ← `ARKITEKT/scripts/Region_Playlist/app/gui.lua`

**`ARKITEKT/rearkitekt/gui/widgets/chip_list/list.lua`** (used by 1 files)
  ← `ARKITEKT/scripts/Region_Playlist/app/gui.lua`

**`ARKITEKT/rearkitekt/gui/widgets/overlay/sheet.lua`** (used by 1 files)
  ← `ARKITEKT/scripts/Region_Playlist/app/gui.lua`

**`ARKITEKT/rearkitekt/core/undo_manager.lua`** (used by 1 files)
  ← `ARKITEKT/scripts/Region_Playlist/app/state.lua`

**`ARKITEKT/rearkitekt/app/shell.lua`** (used by 1 files)
  ← `ARKITEKT/scripts/Region_Playlist/ARK_RegionPlaylist.lua`

**`ARKITEKT/rearkitekt/reaper/regions.lua`** (used by 1 files)
  ← `ARKITEKT/scripts/Region_Playlist/engine/state.lua`

**`ARKITEKT/rearkitekt/core/json.lua`** (used by 1 files)
  ← `ARKITEKT/scripts/Region_Playlist/storage/state.lua`

**`ARKITEKT/rearkitekt/gui/widgets/grid/grid_bridge.lua`** (used by 1 files)
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/coordinator.lua`

**`ARKITEKT/rearkitekt/gui/widgets/panel/config.lua`** (used by 1 files)
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/coordinator.lua`

**`ARKITEKT/rearkitekt/gui/systems/height_stabilizer.lua`** (used by 1 files)
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/coordinator.lua`

**`ARKITEKT/rearkitekt/gui/fx/dnd/drag_indicator.lua`** (used by 1 files)
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/coordinator_render.lua`

**`ARKITEKT/rearkitekt/gui/systems/responsive_grid.lua`** (used by 1 files)
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/coordinator_render.lua`

**`ARKITEKT/rearkitekt/gui/systems/playback_manager.lua`** (used by 1 files)
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/active.lua`
