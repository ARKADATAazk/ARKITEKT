# FOLDER FLOW: apps
Generated: 2025-10-13 01:20:19
Location: D:\Dropbox\REAPER\Scripts\ARKITEKT\apps

## Overview
- **Files**: 35
- **Total Lines**: 8,425
- **Public Functions**: 103
- **Classes**: 30

## Files

### ARK_ColorPalette.lua (98 lines)
  **Requires**: arkitekt.app.shell, apps.ColorPalette.app.state, apps.ColorPalette.app.gui, arkitekt.gui.widgets.overlay.manager, arkitekt.core.settings

### ARK_RegionPlaylist.lua (60 lines)
  **Requires**: arkitekt.app.shell, apps.Region_Playlist.app.config, apps.Region_Playlist.app.state, apps.Region_Playlist.app.gui, apps.Region_Playlist.app.status

### active.lua (187 lines)
  **Modules**: M, right_elements, right_elements
  **Exports**:
    - `M.render(ctx, rect, item, state, get_region_by_rid, animator, on_repeat_cycle, hover_config, tile_height, border_thickness, bridge, get_playlist_by_id)`
    - `M.render_region(ctx, rect, item, state, get_region_by_rid, animator, on_repeat_cycle, hover_config, tile_height, border_thickness, bridge)`
    - `M.render_playlist(ctx, rect, item, state, animator, on_repeat_cycle, hover_config, tile_height, border_thickness, get_playlist_by_id)`
  **Requires**: arkitekt.core.colors, arkitekt.gui.draw, arkitekt.gui.fx.tile_fx_config, apps.Region_Playlist.widgets.region_tiles.renderers.base, arkitekt.gui.systems.playback_manager

### active_grid_factory.lua (213 lines)
  **Modules**: M, item_map, items_by_key, dragged_items, items_by_key, new_items
  **Classes**: M
  **Exports**:
    - `M.create(rt, config)`
  **Requires**: arkitekt.gui.widgets.grid.core, apps.Region_Playlist.widgets.region_tiles.renderers.active

### base.lua (187 lines)
  **Modules**: M
  **Exports**:
    - `M.calculate_right_elements_width(ctx, elements)`
    - `M.create_element(visible, width, margin)`
    - `M.calculate_text_right_bound(ctx, x2, text_margin, right_elements)`
    - `M.draw_base_tile(dl, rect, base_color, fx_config, state, hover_factor, playback_progress, playback_fade)`
    - `M.draw_marching_ants(dl, rect, color, fx_config)`
    - `M.draw_region_text(ctx, dl, pos, region, base_color, text_alpha, right_bound_x)`
    - `M.draw_playlist_text(ctx, dl, pos, playlist_data, state, text_alpha, right_bound_x, name_color_override)`
    - `M.draw_length_display(ctx, dl, rect, region, base_color, text_alpha)`
  **Requires**: arkitekt.gui.draw, arkitekt.core.colors, arkitekt.gui.fx.tile_fx, arkitekt.gui.fx.tile_fx_config, arkitekt.gui.fx.marching_ants

### color_grid.lua (143 lines)
  **Modules**: M, ColorGrid
  **Classes**: ColorGrid, M
  **Exports**:
    - `M.new()`
  **Requires**: arkitekt.core.colors, arkitekt.gui.draw

### config.lua (344 lines)
  **Modules**: M
  **Exports**:
    - `M.get_active_container_config(callbacks)`
    - `M.get_pool_container_config(callbacks)`
    - `M.get_region_tiles_config(layout_mode)`

### controller.lua (235 lines)
  **Modules**: M, Controller, targets, colors
  **Classes**: Controller, M
  **Exports**:
    - `M.new()`

### controller.lua (363 lines)
  **Modules**: M, Controller, keys, keys, keys_set, new_items, keys_set, keys_set
  **Classes**: Controller, M
  **Exports**:
    - `M.new(state_module, settings, undo_manager)`
  **Requires**: apps.Region_Playlist.storage.state

### controls_widget.lua (151 lines)
  **Modules**: M
  **Exports**:
    - `M.draw_transport_controls(ctx, bridge, x, y)`
    - `M.draw_quantize_selector(ctx, bridge, x, y, width)`
    - `M.draw_playback_info(ctx, bridge, x, y, width)`
    - `M.draw_complete_controls(ctx, bridge, x, y, available_width)`

### coordinator.lua (503 lines)
  **Modules**: M, RegionTiles, playlist_cache, spawned_keys, payload, colors
  **Classes**: RegionTiles, M
  **Exports**:
    - `M.create(opts)`
  **Requires**: apps.Region_Playlist.app.config, apps.Region_Playlist.widgets.region_tiles.coordinator_render, arkitekt.gui.draw, arkitekt.core.colors, arkitekt.gui.fx.tile_motion

### coordinator_bridge.lua (171 lines)
  **Modules**: M, order, regions
  **Classes**: M
  **Exports**:
    - `M.create(opts)`
  **Requires**: apps.Region_Playlist.engine.core, apps.Region_Playlist.engine.playback, apps.Region_Playlist.storage.state

### coordinator_render.lua (190 lines)
  **Modules**: M, keys_to_adjust
  **Exports**:
    - `M.draw_selector(self, ctx, playlists, active_id, height)`
    - `M.draw_active(self, ctx, playlist, height)`
    - `M.draw_pool(self, ctx, regions, height)`
    - `M.draw_ghosts(self, ctx)`
  **Requires**: arkitekt.gui.fx.dnd.drag_indicator, apps.Region_Playlist.widgets.region_tiles.renderers.active, apps.Region_Playlist.widgets.region_tiles.renderers.pool, arkitekt.gui.systems.responsive_grid

### core.lua (168 lines)
  **Modules**: M, Engine
  **Classes**: Engine, M
  **Exports**:
    - `M.new(opts)`
  **Requires**: apps.Region_Playlist.engine.state, apps.Region_Playlist.engine.transport, apps.Region_Playlist.engine.transitions, apps.Region_Playlist.engine.quantize

### demo.lua (365 lines)
  **Modules**: result, conflicts, asset_providers
  **Requires**: arkitekt.app.shell, arkitekt.gui.widgets.package_tiles.grid, arkitekt.gui.widgets.package_tiles.micromanage, arkitekt.gui.widgets.panel, arkitekt.gui.widgets.selection_rectangle

### demo2.lua (192 lines)
  **Requires**: arkitekt.app.shell, arkitekt.gui.widgets.sliders.hue, arkitekt.gui.widgets.panel

### demo3.lua (130 lines)
  **Modules**: pads
  **Requires**: arkitekt.app.shell, arkitekt.gui.widgets.displays.status_pad, arkitekt.app.chrome.status_bar

### demo_modal_overlay.lua (433 lines)
  **Modules**: selected_tag_items
  **Requires**: arkitekt.app.shell, arkitekt.gui.widgets.overlay.sheet, arkitekt.gui.widgets.chip_list.list, arkitekt.gui.widgets.overlay.config

### gui.lua (443 lines)
  **Modules**: M, GUI
  **Classes**: GUI, M
  **Exports**:
    - `M.create(State, settings, overlay_manager)`
  **Requires**: arkitekt.core.colors, arkitekt.gui.draw, apps.ColorPalette.widgets.color_grid, apps.ColorPalette.app.controller, arkitekt.gui.widgets.overlay.sheet

### gui.lua (892 lines)
  **Modules**: M, GUI, tab_items, selected_ids, filtered
  **Classes**: GUI, M
  **Exports**:
    - `M.create(State, AppConfig, settings)`
  **Requires**: apps.Region_Playlist.widgets.region_tiles.coordinator, arkitekt.core.colors, apps.Region_Playlist.app.shortcuts, apps.Region_Playlist.app.controller, arkitekt.gui.widgets.transport.transport_container

### playback.lua (103 lines)
  **Modules**: M, Playback
  **Classes**: Playback, M
  **Exports**:
    - `M.new(engine, opts)`
  **Requires**: arkitekt.reaper.transport

### pool.lua (148 lines)
  **Modules**: M, right_elements, right_elements
  **Exports**:
    - `M.render(ctx, rect, item, state, animator, hover_config, tile_height, border_thickness)`
    - `M.render_region(ctx, rect, region, state, animator, hover_config, tile_height, border_thickness)`
    - `M.render_playlist(ctx, rect, playlist, state, animator, hover_config, tile_height, border_thickness)`
  **Requires**: arkitekt.core.colors, arkitekt.gui.draw, arkitekt.gui.fx.tile_fx_config, arkitekt.gui.systems.tile_utilities, apps.Region_Playlist.widgets.region_tiles.renderers.base

### pool_grid_factory.lua (186 lines)
  **Modules**: M, items_by_key, filtered_keys, rids, rids, items_by_key
  **Classes**: M
  **Exports**:
    - `M.create(rt, config)`
  **Requires**: arkitekt.gui.widgets.grid.core, apps.Region_Playlist.widgets.region_tiles.renderers.pool

### quantize.lua (337 lines)
  **Modules**: M, Quantize
  **Classes**: Quantize, M
  **Exports**:
    - `M.new(opts)`

### selector.lua (98 lines)
  **Modules**: M, Selector
  **Classes**: Selector, M
  **Exports**:
    - `M.new(config)`
  **Requires**: arkitekt.gui.draw, arkitekt.core.colors, arkitekt.gui.fx.tile_motion

### shortcuts.lua (83 lines)
  **Modules**: M
  **Exports**:
    - `M.handle_keyboard_shortcuts(ctx, state, region_tiles)`
  **Requires**: apps.Region_Playlist.app.state

### state.lua (273 lines)
  **Modules**: M
  **Exports**:
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
  **Requires**: arkitekt.core.colors

### state.lua (597 lines)
  **Modules**: M, tabs, result, reversed, all_deps, visited, pool_playlists, filtered, reversed, new_path, path_array
  **Exports**:
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
  **Requires**: apps.Region_Playlist.engine.coordinator_bridge, apps.Region_Playlist.storage.state, arkitekt.core.undo_manager, apps.Region_Playlist.storage.undo_bridge, arkitekt.core.colors

### state.lua (148 lines)
  **Modules**: M, State
  **Classes**: State, M
  **Exports**:
    - `M.new(opts)`
  **Requires**: arkitekt.reaper.regions, arkitekt.reaper.transport

### state.lua (152 lines)
  **Modules**: M, default_items
  **Exports**:
    - `M.save_playlists(playlists, proj)`
    - `M.load_playlists(proj)`
    - `M.save_active_playlist(playlist_id, proj)`
    - `M.load_active_playlist(proj)`
    - `M.save_settings(settings, proj)`
    - `M.load_settings(proj)`
    - `M.clear_all(proj)`
    - `M.get_or_create_default_playlist(playlists, regions)`
    - `M.generate_chip_color()`
  **Requires**: arkitekt.core.json, arkitekt.core.colors

### status.lua (59 lines)
  **Modules**: M
  **Classes**: M
  **Exports**:
    - `M.create(State, Style)`
  **Requires**: arkitekt.app.chrome.status_bar

### transitions.lua (211 lines)
  **Modules**: M, Transitions
  **Classes**: Transitions, M
  **Exports**:
    - `M.new(opts)`

### transport.lua (239 lines)
  **Modules**: M, Transport
  **Classes**: Transport, M
  **Exports**:
    - `M.new(opts)`

### undo_bridge.lua (91 lines)
  **Modules**: M, restored_playlists
  **Exports**:
    - `M.capture_snapshot(playlists, active_playlist_id)`
    - `M.restore_snapshot(snapshot, region_index)`
    - `M.should_capture(old_playlists, new_playlists)`

### widget_demo.lua (232 lines)
  **Modules**: t, arr
  **Requires**: arkitekt.app.shell, ReArkitekt.gui.widgets.colorblocks, arkitekt.gui.draw, arkitekt.gui.fx.effects, ReArkitekt.*

## Internal Dependencies

### gui.lua
  → apps.ColorPalette.widgets.color_grid
  → apps.ColorPalette.app.controller

### ARK_ColorPalette.lua
  → apps.ColorPalette.app.state
  → apps.ColorPalette.app.gui

### demo_modal_overlay.lua
  → arkitekt.gui.widgets.overlay.config

### controller.lua
  → apps.Region_Playlist.storage.state

### gui.lua
  → apps.Region_Playlist.widgets.region_tiles.coordinator
  → apps.Region_Playlist.app.shortcuts
  → apps.Region_Playlist.app.controller
  → apps.Region_Playlist.app.config

### shortcuts.lua
  → apps.Region_Playlist.app.state

### state.lua
  → apps.Region_Playlist.engine.coordinator_bridge
  → apps.Region_Playlist.storage.state
  → apps.Region_Playlist.storage.undo_bridge

### ARK_RegionPlaylist.lua
  → apps.Region_Playlist.app.config
  → apps.Region_Playlist.app.state
  → apps.Region_Playlist.app.gui
  → apps.Region_Playlist.app.status

### coordinator_bridge.lua
  → apps.Region_Playlist.engine.core
  → apps.Region_Playlist.engine.playback
  → apps.Region_Playlist.storage.state

### core.lua
  → apps.Region_Playlist.engine.state
  → apps.Region_Playlist.engine.transport
  → apps.Region_Playlist.engine.transitions
  → apps.Region_Playlist.engine.quantize

### playback.lua
  → arkitekt.reaper.transport

### state.lua
  → arkitekt.reaper.transport

### active_grid_factory.lua
  → arkitekt.gui.widgets.grid.core
  → apps.Region_Playlist.widgets.region_tiles.renderers.active

### coordinator.lua
  → apps.Region_Playlist.app.config
  → apps.Region_Playlist.widgets.region_tiles.coordinator_render
  → apps.Region_Playlist.widgets.region_tiles.selector
  → apps.Region_Playlist.widgets.region_tiles.active_grid_factory
  → apps.Region_Playlist.widgets.region_tiles.pool_grid_factory
  → apps.Region_Playlist.app.state

### coordinator_render.lua
  → apps.Region_Playlist.widgets.region_tiles.renderers.active
  → apps.Region_Playlist.widgets.region_tiles.renderers.pool

### pool_grid_factory.lua
  → arkitekt.gui.widgets.grid.core
  → apps.Region_Playlist.widgets.region_tiles.renderers.pool

### active.lua
  → apps.Region_Playlist.widgets.region_tiles.renderers.base

### pool.lua
  → apps.Region_Playlist.widgets.region_tiles.renderers.base
