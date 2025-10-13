# FOLDER FLOW: ARKITEKT
Generated: 2025-10-13 15:09:44
Location: D:\Dropbox\REAPER\Scripts\ARKITEKT-Project\ARKITEKT

## Overview
- **Files**: 120
- **Total Lines**: 24,210
- **Public Functions**: 352
- **Classes**: 81

## Files

### ARKITEKT.lua (353 lines)
  **Modules**: result, conflicts, asset_providers
  **Requires**: rearkitekt.app.shell, rearkitekt.app.hub, rearkitekt.gui.widgets.package_tiles.grid, rearkitekt.gui.widgets.package_tiles.micromanage, rearkitekt.gui.widgets.panel

### ARK_ColorPalette.lua (116 lines)
  **Requires**: rearkitekt.app.shell, ColorPalette.app.state, ColorPalette.app.gui, rearkitekt.gui.widgets.overlay.manager, rearkitekt.core.settings

### ARK_RegionPlaylist.lua (76 lines)
  **Requires**: rearkitekt.app.shell, Region_Playlist.app.config, Region_Playlist.app.state, Region_Playlist.app.gui, Region_Playlist.app.status

### active.lua (187 lines)
  **Modules**: M, right_elements, right_elements
  **Exports**:
    - `M.render(ctx, rect, item, state, get_region_by_rid, animator, on_repeat_cycle, hover_config, tile_height, border_thickness, bridge, get_playlist_by_id)`
    - `M.render_region(ctx, rect, item, state, get_region_by_rid, animator, on_repeat_cycle, hover_config, tile_height, border_thickness, bridge)`
    - `M.render_playlist(ctx, rect, item, state, animator, on_repeat_cycle, hover_config, tile_height, border_thickness, get_playlist_by_id)`
  **Requires**: rearkitekt.core.colors, rearkitekt.gui.draw, rearkitekt.gui.fx.tile_fx_config, Region_Playlist.widgets.region_tiles.renderers.base, rearkitekt.gui.systems.playback_manager

### active_grid_factory.lua (213 lines)
  **Modules**: M, item_map, items_by_key, dragged_items, items_by_key, new_items
  **Classes**: M
  **Exports**:
    - `M.create(rt, config)`
  **Requires**: rearkitekt.gui.widgets.grid.core, Region_Playlist.widgets.region_tiles.renderers.active

### animation.lua (101 lines)
  **Modules**: M, AnimationCoordinator
  **Classes**: AnimationCoordinator, M
  **Exports**:
    - `M.new(config)`
  **Requires**: rearkitekt.gui.fx.animations.spawn, rearkitekt.gui.fx.animations.destroy

### background.lua (61 lines)
  **Modules**: M
  **Exports**:
    - `M.draw(dl, x1, y1, x2, y2, pattern_cfg)`

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
  **Requires**: rearkitekt.gui.draw, rearkitekt.core.colors, rearkitekt.gui.fx.tile_fx, rearkitekt.gui.fx.tile_fx_config, rearkitekt.gui.fx.marching_ants

### button.lua (119 lines)
  **Modules**: M
  **Exports**:
    - `M.draw(ctx, dl, x, y, width, height, config, state)`
    - `M.measure(ctx, config)`

### chip.lua (333 lines)
  **Modules**: M
  **Exports**:
    - `M.calculate_width(ctx, label, opts)`
    - `M.draw(ctx, opts)`
  **Requires**: rearkitekt.gui.draw, rearkitekt.core.colors, rearkitekt.gui.fx.tile_fx, rearkitekt.gui.fx.tile_fx_config

### color_grid.lua (143 lines)
  **Modules**: M, ColorGrid
  **Classes**: ColorGrid, M
  **Exports**:
    - `M.new()`
  **Requires**: rearkitekt.core.colors, rearkitekt.gui.draw

### colors.lua (550 lines)
  **Modules**: M
  **Exports**:
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

### config.lua (140 lines)
  **Modules**: M, result
  **Exports**:
    - `M.deep_merge(base, override)`
    - `M.merge(user_config, preset_name)`
  **Requires**: rearkitekt.gui.widgets.component.chip

### config.lua (90 lines)
  **Modules**: M, keys
  **Exports**:
    - `M.get_defaults()`
    - `M.get(path)`

### config.lua (91 lines)
  **Modules**: M
  **Exports**:
    - `M.get_mode_config(config, is_copy, is_delete)`

### config.lua (139 lines)
  **Modules**: M, new_config
  **Exports**:
    - `M.get()`
    - `M.override(overrides)`
    - `M.reset()`

### config.lua (255 lines)
  **Modules**: M

### config.lua (349 lines)
  **Modules**: M
  **Exports**:
    - `M.get_active_container_config(callbacks)`
    - `M.get_pool_container_config(callbacks)`
    - `M.get_region_tiles_config(layout_mode)`

### content.lua (44 lines)
  **Modules**: M
  **Exports**:
    - `M.begin_child(ctx, id, width, height, scroll_config)`
    - `M.end_child(ctx, container)`

### context_menu.lua (106 lines)
  **Modules**: M
  **Exports**:
    - `M.begin(ctx, id, config)`
    - `M.end_menu(ctx)`
    - `M.item(ctx, label, config)`
    - `M.separator(ctx, config)`

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
  **Requires**: Region_Playlist.storage.state

### controls_widget.lua (151 lines)
  **Modules**: M
  **Exports**:
    - `M.draw_transport_controls(ctx, bridge, x, y)`
    - `M.draw_quantize_selector(ctx, bridge, x, y, width)`
    - `M.draw_playback_info(ctx, bridge, x, y, width)`
    - `M.draw_complete_controls(ctx, bridge, x, y, available_width)`

### coordinator.lua (505 lines)
  **Modules**: M, RegionTiles, playlist_cache, spawned_keys, payload, colors
  **Classes**: RegionTiles, M
  **Exports**:
    - `M.create(opts)`
  **Requires**: Region_Playlist.app.config, Region_Playlist.widgets.region_tiles.coordinator_render, rearkitekt.gui.draw, rearkitekt.core.colors, rearkitekt.gui.fx.tile_motion

### coordinator_bridge.lua (171 lines)
  **Modules**: M, order, regions
  **Classes**: M
  **Exports**:
    - `M.create(opts)`
  **Requires**: Region_Playlist.engine.core, Region_Playlist.engine.playback, Region_Playlist.storage.state

### coordinator_render.lua (190 lines)
  **Modules**: M, keys_to_adjust
  **Exports**:
    - `M.draw_selector(self, ctx, playlists, active_id, height)`
    - `M.draw_active(self, ctx, playlist, height)`
    - `M.draw_pool(self, ctx, regions, height)`
    - `M.draw_ghosts(self, ctx)`
  **Requires**: rearkitekt.gui.fx.dnd.drag_indicator, Region_Playlist.widgets.region_tiles.renderers.active, Region_Playlist.widgets.region_tiles.renderers.pool, rearkitekt.gui.systems.responsive_grid

### core.lua (550 lines)
  **Modules**: M, Grid, current_keys, new_keys, rect_map, rect_map, order, filtered_order, new_order
  **Classes**: Grid, M
  **Exports**:
    - `M.new(opts)`
  **Requires**: rearkitekt.gui.widgets.grid.layout, rearkitekt.gui.fx.animation.rect_track, rearkitekt.core.colors, rearkitekt.gui.systems.selection, rearkitekt.gui.widgets.selection_rectangle

### core.lua (168 lines)
  **Modules**: M, Engine
  **Classes**: Engine, M
  **Exports**:
    - `M.new(opts)`
  **Requires**: Region_Playlist.engine.state, Region_Playlist.engine.transport, Region_Playlist.engine.transitions, Region_Playlist.engine.quantize

### demo.lua (383 lines)
  **Modules**: result, conflicts, asset_providers
  **Requires**: rearkitekt.app.shell, rearkitekt.gui.widgets.package_tiles.grid, rearkitekt.gui.widgets.package_tiles.micromanage, rearkitekt.gui.widgets.panel, rearkitekt.gui.widgets.selection_rectangle

### demo2.lua (210 lines)
  **Requires**: rearkitekt.app.shell, rearkitekt.gui.widgets.sliders.hue, rearkitekt.gui.widgets.panel

### demo3.lua (148 lines)
  **Modules**: pads
  **Requires**: rearkitekt.app.shell, rearkitekt.gui.widgets.displays.status_pad, rearkitekt.app.chrome.status_bar

### demo_modal_overlay.lua (451 lines)
  **Modules**: selected_tag_items
  **Requires**: rearkitekt.app.shell, rearkitekt.gui.widgets.overlay.sheet, rearkitekt.gui.widgets.chip_list.list, rearkitekt.gui.widgets.overlay.config

### destroy.lua (149 lines)
  **Modules**: M, DestroyAnim, completed
  **Classes**: DestroyAnim, M
  **Exports**:
    - `M.new(opts)`
  **Requires**: rearkitekt.gui.fx.easing

### dnd_state.lua (113 lines)
  **Modules**: M, DnDState
  **Classes**: DnDState, M
  **Exports**:
    - `M.new(opts)`

### drag_indicator.lua (219 lines)
  **Modules**: M
  **Exports**:
    - `M.draw_badge(ctx, dl, mx, my, count, config, is_copy_mode, is_delete_mode)`
    - `M.draw(ctx, dl, mx, my, count, config, colors, is_copy_mode, is_delete_mode)`
  **Requires**: rearkitekt.gui.draw, rearkitekt.core.colors, rearkitekt.gui.fx.dnd.config

### draw.lua (114 lines)
  **Modules**: M
  **Exports**:
    - `M.snap(x)`
    - `M.centered_text(ctx, text, x1, y1, x2, y2, color)`
    - `M.rect(dl, x1, y1, x2, y2, color, rounding, thickness)`
    - `M.rect_filled(dl, x1, y1, x2, y2, color, rounding)`
    - `M.line(dl, x1, y1, x2, y2, color, thickness)`
    - `M.text(dl, x, y, color, text)`
    - `M.text_right(ctx, x, y, color, text)`
    - `M.point_in_rect(x, y, x1, y1, x2, y2)`
    - `M.rects_intersect(ax1, ay1, ax2, ay2, bx1, by1, bx2, by2)`
    - `M.text_clipped(ctx, text, x, y, max_width, color)`

### drop_indicator.lua (113 lines)
  **Modules**: M
  **Exports**:
    - `M.draw_vertical(ctx, dl, x, y1, y2, config, is_copy_mode)`
    - `M.draw_horizontal(ctx, dl, x1, x2, y, config, is_copy_mode)`
    - `M.draw(ctx, dl, config, is_copy_mode, orientation, ...)`
  **Requires**: rearkitekt.gui.fx.dnd.config

### drop_zones.lua (277 lines)
  **Modules**: M, non_dragged, zones, zones, rows, sequential_items, set
  **Exports**:
    - `M.find_drop_target(mx, my, items, key_fn, dragged_set, rect_track, is_single_column, grid_bounds)`
    - `M.find_external_drop_target(mx, my, items, key_fn, rect_track, is_single_column, grid_bounds)`
    - `M.build_dragged_set(dragged_ids)`

### dropdown.lua (395 lines)
  **Modules**: M, Dropdown
  **Classes**: Dropdown, M
  **Exports**:
    - `M.new(opts)`
  **Requires**: rearkitekt.gui.widgets.controls.tooltip

### dropdown_field.lua (101 lines)
  **Modules**: M
  **Exports**:
    - `M.draw(ctx, dl, x, y, width, height, config, state)`
    - `M.measure(ctx, config)`
  **Requires**: rearkitekt.gui.widgets.controls.dropdown

### easing.lua (94 lines)
  **Modules**: M
  **Exports**:
    - `M.linear(t)`
    - `M.ease_in_quad(t)`
    - `M.ease_out_quad(t)`
    - `M.ease_in_out_quad(t)`
    - `M.ease_in_cubic(t)`
    - `M.ease_out_cubic(t)`
    - `M.ease_in_out_cubic(t)`
    - `M.ease_in_sine(t)`
    - `M.ease_out_sine(t)`
    - `M.ease_in_out_sine(t)`

### effects.lua (54 lines)
  **Modules**: M
  **Exports**:
    - `M.hover_shadow(dl, x1, y1, x2, y2, strength, radius)`
    - `M.soft_glow(dl, x1, y1, x2, y2, color, intensity, radius)`
    - `M.pulse_glow(dl, x1, y1, x2, y2, color, time, speed, radius)`

### grid.lua (227 lines)
  **Modules**: M
  **Classes**: M
  **Exports**:
    - `M.create(pkg, settings, theme)`
  **Requires**: rearkitekt.gui.widgets.grid.core, rearkitekt.core.colors, rearkitekt.gui.fx.tile_motion, rearkitekt.gui.widgets.package_tiles.renderer, rearkitekt.gui.widgets.package_tiles.micromanage

### grid_bridge.lua (219 lines)
  **Modules**: M, GridBridge
  **Classes**: GridBridge, M
  **Exports**:
    - `M.new(config)`

### gui.lua (443 lines)
  **Modules**: M, GUI
  **Classes**: GUI, M
  **Exports**:
    - `M.create(State, settings, overlay_manager)`
  **Requires**: rearkitekt.core.colors, rearkitekt.gui.draw, ColorPalette.widgets.color_grid, ColorPalette.app.controller, rearkitekt.gui.widgets.overlay.sheet

### gui.lua (892 lines)
  **Modules**: M, GUI, tab_items, selected_ids, filtered
  **Classes**: GUI, M
  **Exports**:
    - `M.create(State, AppConfig, settings)`
  **Requires**: Region_Playlist.widgets.region_tiles.coordinator, rearkitekt.core.colors, Region_Playlist.app.shortcuts, Region_Playlist.app.controller, rearkitekt.gui.widgets.transport.transport_container

### header.lua (42 lines)
  **Modules**: M
  **Exports**:
    - `M.draw(ctx, dl, x, y, w, h, state, config, rounding)`
  **Requires**: rearkitekt.gui.widgets.panel.modes.search_sort, rearkitekt.gui.widgets.panel.modes.tabs

### height_stabilizer.lua (74 lines)
  **Modules**: M, HeightStabilizer
  **Classes**: HeightStabilizer, M
  **Exports**:
    - `M.new(opts)`

### hub.lua (93 lines)
  **Modules**: M, apps
  **Exports**:
    - `M.launch_app(app_path)`
    - `M.render_hub(ctx, opts)`

### hue.lua (276 lines)
  **Modules**: M, _locks
  **Exports**:
    - `M.draw_hue(ctx, id, hue, opt)`
    - `M.draw_saturation(ctx, id, saturation, base_hue, opt)`
    - `M.draw_gamma(ctx, id, gamma, opt)`
    - `M.draw(ctx, id, hue, opt)`

### icon.lua (124 lines)
  **Modules**: M
  **Exports**:
    - `M.draw_rearkitekt(ctx, x, y, size, color)`
    - `M.draw_rearkitekt_v2(ctx, x, y, size, color)`
    - `M.draw_simple_a(ctx, x, y, size, color)`

### images.lua (285 lines)
  **Modules**: M, Cache
  **Classes**: Cache, M
  **Exports**:
    - `M.new(opts)`

### init.lua (3 lines)
  **Requires**: rearkitekt.app.chrome.status_bar.widget

### init.lua (46 lines)
  **Modules**: M
  **Exports**:
    - `M.draw(ctx, dl, x, y, w, h, state, config, rounding)`
    - `M.draw_elements(ctx, dl, x, y, w, h, state, config)`
  **Requires**: rearkitekt.gui.widgets.panel.header.layout

### init.lua (403 lines)
  **Modules**: M, result, Panel
  **Classes**: Panel, M
  **Exports**:
    - `M.new(opts)`
    - `M.draw(ctx, id, width, height, content_fn, config)`
  **Requires**: rearkitekt.gui.widgets.panel.header, rearkitekt.gui.widgets.panel.content, rearkitekt.gui.widgets.panel.background, rearkitekt.gui.widgets.panel.tab_animator, rearkitekt.gui.widgets.controls.scrollbar

### input.lua (237 lines)
  **Modules**: M, keys_to_adjust, order, order
  **Exports**:
    - `M.is_external_drag_active(grid)`
    - `M.is_mouse_in_exclusion(grid, ctx, item, rect)`
    - `M.find_hovered_item(grid, ctx, items)`
    - `M.is_shortcut_pressed(ctx, shortcut, state)`
    - `M.reset_shortcut_states(ctx, state)`
    - `M.handle_shortcuts(grid, ctx)`
    - `M.handle_wheel_input(grid, ctx, items)`
    - `M.handle_tile_input(grid, ctx, item, rect)`
    - `M.check_start_drag(grid, ctx)`
  **Requires**: rearkitekt.gui.draw

### json.lua (121 lines)
  **Modules**: M, out, obj, arr
  **Exports**:
    - `M.encode(t)`
    - `M.decode(str)`

### layout.lua (101 lines)
  **Modules**: M, rects
  **Exports**:
    - `M.calculate(avail_w, min_col_w, gap, n_items, origin_x, origin_y, fixed_tile_h)`
    - `M.get_height(rows, tile_h, gap)`

### layout.lua (305 lines)
  **Modules**: M, layout, rounding_info, element_config
  **Exports**:
    - `M.draw(ctx, dl, x, y, width, height, state, config)`
  **Requires**: rearkitekt.gui.widgets.panel.header.tab_strip, rearkitekt.gui.widgets.panel.header.search_field, rearkitekt.gui.widgets.panel.header.dropdown_field, rearkitekt.gui.widgets.panel.header.button, rearkitekt.gui.widgets.panel.header.separator

### lifecycle.lua (81 lines)
  **Modules**: M, Group
  **Classes**: Group, M
  **Exports**:
    - `M.new()`

### list.lua (303 lines)
  **Modules**: M, filtered, min_widths, min_widths
  **Exports**:
    - `M.draw(ctx, items, opts)`
    - `M.draw_vertical(ctx, items, opts)`
    - `M.draw_columns(ctx, items, opts)`
    - `M.draw_grid(ctx, items, opts)`
    - `M.draw_auto(ctx, items, opts)`
  **Requires**: rearkitekt.gui.widgets.component.chip, rearkitekt.gui.systems.responsive_grid

### manager.lua (178 lines)
  **Modules**: M
  **Classes**: M
  **Exports**:
    - `M.new()`
  **Requires**: rearkitekt.gui.draw, rearkitekt.core.colors, rearkitekt.gui.style, rearkitekt.gui.widgets.overlay.config

### marching_ants.lua (142 lines)
  **Modules**: M
  **Exports**:
    - `M.draw(dl, x1, y1, x2, y2, color, thickness, radius, dash, gap, speed_px)`

### math.lua (52 lines)
  **Modules**: M
  **Exports**:
    - `M.lerp(a, b, t)`
    - `M.clamp(value, min, max)`
    - `M.remap(value, in_min, in_max, out_min, out_max)`
    - `M.snap(value, step)`
    - `M.smoothdamp(current, target, velocity, smoothtime, maxspeed, dt)`
    - `M.approximately(a, b, epsilon)`

### menutabs.lua (269 lines)
  **Modules**: M, o, o, edges
  **Classes**: M
  **Exports**:
    - `M.new(opts)`

### micromanage.lua (127 lines)
  **Modules**: M
  **Exports**:
    - `M.open(pkg_id)`
    - `M.close()`
    - `M.is_open()`
    - `M.get_package_id()`
    - `M.draw_window(ctx, pkg, settings)`
    - `M.reset()`

### playback.lua (103 lines)
  **Modules**: M, Playback
  **Classes**: Playback, M
  **Exports**:
    - `M.new(engine, opts)`
  **Requires**: rearkitekt.reaper.transport

### playback_manager.lua (22 lines)
  **Modules**: M
  **Exports**:
    - `M.compute_fade_alpha(progress, fade_in_ratio, fade_out_ratio)`

### pool.lua (148 lines)
  **Modules**: M, right_elements, right_elements
  **Exports**:
    - `M.render(ctx, rect, item, state, animator, hover_config, tile_height, border_thickness)`
    - `M.render_region(ctx, rect, region, state, animator, hover_config, tile_height, border_thickness)`
    - `M.render_playlist(ctx, rect, playlist, state, animator, hover_config, tile_height, border_thickness)`
  **Requires**: rearkitekt.core.colors, rearkitekt.gui.draw, rearkitekt.gui.fx.tile_fx_config, rearkitekt.gui.systems.tile_utilities, Region_Playlist.widgets.region_tiles.renderers.base

### pool_grid_factory.lua (186 lines)
  **Modules**: M, items_by_key, filtered_keys, rids, rids, items_by_key
  **Classes**: M
  **Exports**:
    - `M.create(rt, config)`
  **Requires**: rearkitekt.gui.widgets.grid.core, Region_Playlist.widgets.region_tiles.renderers.pool

### quantize.lua (337 lines)
  **Modules**: M, Quantize
  **Classes**: Quantize, M
  **Exports**:
    - `M.new(opts)`

### rect_track.lua (136 lines)
  **Modules**: M, RectTrack
  **Classes**: RectTrack, M
  **Exports**:
    - `M.new(speed, snap_epsilon, magnetic_threshold, magnetic_multiplier)`
  **Requires**: rearkitekt.core.math

### regions.lua (83 lines)
  **Modules**: M, regions
  **Exports**:
    - `M.scan_project_regions(proj)`
    - `M.get_region_by_rid(proj, target_rid)`
    - `M.go_to_region(proj, target_rid)`

### renderer.lua (267 lines)
  **Modules**: M
  **Requires**: rearkitekt.gui.draw, rearkitekt.gui.fx.marching_ants, rearkitekt.core.colors

### rendering.lua (90 lines)
  **Modules**: M
  **Requires**: rearkitekt.gui.draw, rearkitekt.core.colors, rearkitekt.gui.fx.marching_ants

### reorder.lua (127 lines)
  **Modules**: M, t, base, new_order, new_order, new_order
  **Exports**:
    - `M.insert_relative(order_keys, dragged_keys, target_key, side)`
    - `M.move_up(order_keys, selected_keys)`
    - `M.move_down(order_keys, selected_keys)`

### responsive_grid.lua (229 lines)
  **Modules**: M, rows, current_row, layout
  **Exports**:
    - `M.calculate_scaled_gap(tile_height, base_gap, base_height, min_height, responsive_config)`
    - `M.calculate_responsive_tile_height(opts)`
    - `M.calculate_grid_metrics(opts)`
    - `M.calculate_justified_layout(items, opts)`
    - `M.should_show_scrollbar(grid_height, available_height, buffer)`
    - `M.create_default_config()`

### runtime.lua (69 lines)
  **Modules**: M
  **Classes**: M
  **Exports**:
    - `M.new(opts)`

### scrollbar.lua (239 lines)
  **Modules**: M, Scrollbar
  **Classes**: Scrollbar, M
  **Exports**:
    - `M.new(opts)`

### search_field.lua (120 lines)
  **Modules**: M
  **Exports**:
    - `M.draw(ctx, dl, x, y, width, height, config, state)`
    - `M.measure(ctx, config)`

### search_sort.lua (225 lines)
  **Modules**: M
  **Exports**:
    - `M.draw(ctx, dl, x, y, width, height, state, cfg, current_mode, on_mode_changed)`
  **Requires**: rearkitekt.gui.draw, rearkitekt.gui.widgets.controls.dropdown

### selection.lua (142 lines)
  **Modules**: M, Selection, out, out
  **Classes**: Selection, M
  **Exports**:
    - `M.new()`

### selection_rectangle.lua (99 lines)
  **Modules**: M, SelRect
  **Classes**: SelRect, M
  **Exports**:
    - `M.new(opts)`

### selector.lua (98 lines)
  **Modules**: M, Selector
  **Classes**: Selector, M
  **Exports**:
    - `M.new(config)`
  **Requires**: rearkitekt.gui.draw, rearkitekt.core.colors, rearkitekt.gui.fx.tile_motion

### separator.lua (33 lines)
  **Modules**: M
  **Exports**:
    - `M.draw(ctx, dl, x, y, width, height, config)`
    - `M.measure(ctx, config)`

### settings.lua (119 lines)
  **Modules**: Settings, out, M, t
  **Classes**: Settings
  **Exports**:
    - `M.open(cache_dir, filename)`
  **Requires**: rearkitekt.core.json

### sheet.lua (125 lines)
  **Modules**: Sheet
  **Exports**:
    - `Sheet.render(ctx, alpha, bounds, content_fn, opts)`
  **Requires**: rearkitekt.gui.draw, rearkitekt.core.colors, rearkitekt.gui.style, rearkitekt.gui.widgets.overlay.config

### shell.lua (256 lines)
  **Modules**: M, DEFAULTS
  **Exports**:
    - `M.run(opts)`
  **Requires**: rearkitekt.app.runtime, rearkitekt.app.window

### shortcuts.lua (83 lines)
  **Modules**: M
  **Exports**:
    - `M.handle_keyboard_shortcuts(ctx, state, region_tiles)`
  **Requires**: Region_Playlist.app.state

### spawn.lua (58 lines)
  **Modules**: M, SpawnTracker
  **Classes**: SpawnTracker, M
  **Exports**:
    - `M.new(config)`
  **Requires**: rearkitekt.gui.fx.easing

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
  **Requires**: rearkitekt.core.colors

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
  **Requires**: Region_Playlist.engine.coordinator_bridge, Region_Playlist.storage.state, rearkitekt.core.undo_manager, Region_Playlist.storage.undo_bridge, rearkitekt.core.colors

### state.lua (148 lines)
  **Modules**: M, State
  **Classes**: State, M
  **Exports**:
    - `M.new(opts)`
  **Requires**: rearkitekt.reaper.regions, rearkitekt.reaper.transport

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
  **Requires**: rearkitekt.core.json, rearkitekt.core.colors

### status.lua (59 lines)
  **Modules**: M
  **Classes**: M
  **Exports**:
    - `M.create(State, Style)`
  **Requires**: rearkitekt.app.chrome.status_bar

### status_pad.lua (192 lines)
  **Modules**: M, FontPool, StatusPad
  **Classes**: StatusPad, M
  **Exports**:
    - `M.new(opts)`
  **Requires**: rearkitekt.gui.draw, rearkitekt.core.colors, rearkitekt.gui.fx.tile_fx, rearkitekt.gui.fx.tile_fx_config

### style.lua (146 lines)
  **Modules**: M
  **Exports**:
    - `M.with_alpha(col, a)`
    - `M.PushMyStyle(ctx)`
    - `M.PopMyStyle(ctx)`
  **Requires**: rearkitekt.core.colors

### tab_animator.lua (107 lines)
  **Modules**: M, TabAnimator, spawn_complete, destroy_complete
  **Classes**: TabAnimator, M
  **Exports**:
    - `M.new(opts)`
  **Requires**: rearkitekt.gui.fx.easing

### tab_strip.lua (779 lines)
  **Modules**: M, visible_indices, positions
  **Exports**:
    - `M.draw(ctx, dl, x, y, available_width, height, config, state)`
    - `M.draw_elements(ctx, dl, x, y, available_width, height, config, state)`
    - `M.measure(ctx, config, state)`
  **Requires**: rearkitekt.gui.widgets.controls.context_menu, rearkitekt.gui.widgets.component.chip

### tabs.lua (647 lines)
  **Modules**: M, visible_tabs, positions
  **Exports**:
    - `M.assign_random_color(tab)`
    - `M.draw(ctx, dl, x, y, width, height, state, cfg)`
  **Requires**: rearkitekt.gui.widgets.controls.context_menu, rearkitekt.gui.widgets.component.chip

### tile_fx.lua (170 lines)
  **Modules**: M
  **Exports**:
    - `M.render_base_fill(dl, x1, y1, x2, y2, rounding)`
    - `M.render_color_fill(dl, x1, y1, x2, y2, base_color, opacity, saturation, brightness, rounding)`
    - `M.render_gradient(dl, x1, y1, x2, y2, base_color, intensity, opacity, rounding)`
    - `M.render_specular(dl, x1, y1, x2, y2, base_color, strength, coverage, rounding)`
    - `M.render_inner_shadow(dl, x1, y1, x2, y2, strength, rounding)`
    - `M.render_playback_progress(dl, x1, y1, x2, y2, base_color, progress, fade_alpha, rounding)`
    - `M.render_border(dl, x1, y1, x2, y2, base_color, saturation, brightness, opacity, thickness, rounding, is_selected, glow_strength, glow_layers)`
    - `M.render_complete(dl, x1, y1, x2, y2, base_color, config, is_selected, hover_factor, playback_progress, playback_fade)`
  **Requires**: rearkitekt.core.colors

### tile_fx_config.lua (79 lines)
  **Modules**: M, config
  **Exports**:
    - `M.get()`
    - `M.override(overrides)`

### tile_motion.lua (58 lines)
  **Modules**: M, TileAnimator
  **Classes**: TileAnimator, M
  **Exports**:
    - `M.new(default_speed)`
  **Requires**: rearkitekt.gui.fx.animation.track

### tile_utilities.lua (49 lines)
  **Modules**: M
  **Exports**:
    - `M.format_bar_length(start_time, end_time, proj)`

### tiles_container_old.lua (753 lines)
  **Modules**: M, Container
  **Classes**: Container, M
  **Exports**:
    - `M.new(opts)`
    - `M.draw(ctx, id, width, height, content_fn, config, on_search_changed, on_sort_changed)`
  **Requires**: rearkitekt.gui.widgets.controls.dropdown

### timing.lua (113 lines)
  **Modules**: M
  **Exports**:
    - `M.time_to_qn(time, proj)`
    - `M.qn_to_time(qn, proj)`
    - `M.get_tempo_at_time(time, proj)`
    - `M.get_time_signature_at_time(time, proj)`
    - `M.quantize_to_beat(time, proj, allow_backward)`
    - `M.quantize_to_bar(time, proj, allow_backward)`
    - `M.quantize_to_grid(time, proj, allow_backward)`
    - `M.calculate_next_transition(region_end, mode, max_lookahead, proj)`
    - `M.get_beats_in_region(start_time, end_time, proj)`

### titlebar.lua (438 lines)
  **Modules**: M, DEFAULTS
  **Classes**: M
  **Exports**:
    - `M.new(opts)`

### tooltip.lua (129 lines)
  **Modules**: M
  **Exports**:
    - `M.show(ctx, text, config)`
    - `M.show_delayed(ctx, text, config)`
    - `M.show_at_mouse(ctx, text, config)`
    - `M.reset()`

### track.lua (53 lines)
  **Modules**: M, Track
  **Classes**: Track, M
  **Exports**:
    - `M.new(initial_value, speed)`
  **Requires**: rearkitekt.core.math

### transitions.lua (211 lines)
  **Modules**: M, Transitions
  **Classes**: Transitions, M
  **Exports**:
    - `M.new(opts)`

### transport.lua (97 lines)
  **Modules**: M
  **Exports**:
    - `M.is_playing(proj)`
    - `M.is_paused(proj)`
    - `M.is_recording(proj)`
    - `M.play(proj)`
    - `M.stop(proj)`
    - `M.pause(proj)`
    - `M.get_play_position(proj)`
    - `M.get_cursor_position(proj)`
    - `M.set_edit_cursor(pos, move_view, seek_play, proj)`
    - `M.set_play_position(pos, move_view, proj)`

### transport.lua (239 lines)
  **Modules**: M, Transport
  **Classes**: Transport, M
  **Exports**:
    - `M.new(opts)`

### transport_container.lua (137 lines)
  **Modules**: M, TransportContainer
  **Classes**: TransportContainer, M
  **Exports**:
    - `M.new(opts)`
    - `M.draw(ctx, id, width, height, content_fn, config)`
  **Requires**: rearkitekt.gui.widgets.transport.transport_fx

### transport_fx.lua (107 lines)
  **Modules**: M
  **Exports**:
    - `M.render_base(dl, x1, y1, x2, y2, config)`
    - `M.render_specular(dl, x1, y1, x2, y2, config, hover_factor)`
    - `M.render_inner_glow(dl, x1, y1, x2, y2, config, hover_factor)`
    - `M.render_border(dl, x1, y1, x2, y2, config)`
    - `M.render_complete(dl, x1, y1, x2, y2, config, hover_factor)`
  **Requires**: rearkitekt.core.colors

### undo_bridge.lua (91 lines)
  **Modules**: M, restored_playlists
  **Exports**:
    - `M.capture_snapshot(playlists, active_playlist_id)`
    - `M.restore_snapshot(snapshot, region_index)`
    - `M.should_capture(old_playlists, new_playlists)`

### undo_manager.lua (70 lines)
  **Modules**: M
  **Classes**: M
  **Exports**:
    - `M.new(opts)`

### wheel_guard.lua (43 lines)
  **Exports**:
    - `M.begin(ctx)`
    - `M.capture_over_last_item(ctx, on_delta)`
    - `M.capture_if(ctx, condition, on_delta)`
    - `M.finish(ctx)`
  **Requires**: imgui

### widget.lua (319 lines)
  **Modules**: M, right_items
  **Classes**: M
  **Exports**:
    - `M.new(config)`
  **Requires**: rearkitekt.gui.widgets.component.chip, rearkitekt.app.chrome.status_bar.config

### widget_demo.lua (250 lines)
  **Modules**: t, arr
  **Requires**: rearkitekt.app.shell, ReArkitekt.gui.widgets.colorblocks, rearkitekt.gui.draw, rearkitekt.gui.fx.effects, ReArkitekt.*

### window.lua (460 lines)
  **Modules**: M, DEFAULTS
  **Classes**: M
  **Exports**:
    - `M.new(opts)`

## Internal Dependencies

### ARKITEKT.lua
  → rearkitekt.app.shell
  → rearkitekt.app.hub
  → rearkitekt.gui.widgets.package_tiles.grid
  → rearkitekt.gui.widgets.package_tiles.micromanage
  → rearkitekt.gui.widgets.selection_rectangle

### config.lua
  → rearkitekt.gui.widgets.component.chip

### init.lua
  → rearkitekt.app.chrome.status_bar.widget

### widget.lua
  → rearkitekt.gui.widgets.component.chip
  → rearkitekt.app.chrome.status_bar.config

### shell.lua
  → rearkitekt.app.runtime
  → rearkitekt.app.window

### settings.lua
  → rearkitekt.core.json

### rect_track.lua
  → rearkitekt.core.math

### track.lua
  → rearkitekt.core.math

### destroy.lua
  → rearkitekt.gui.fx.easing

### spawn.lua
  → rearkitekt.gui.fx.easing

### drag_indicator.lua
  → rearkitekt.gui.draw
  → rearkitekt.core.colors
  → rearkitekt.gui.fx.dnd.config

### drop_indicator.lua
  → rearkitekt.gui.fx.dnd.config

### tile_fx.lua
  → rearkitekt.core.colors

### tile_motion.lua
  → rearkitekt.gui.fx.animation.track

### style.lua
  → rearkitekt.core.colors

### list.lua
  → rearkitekt.gui.widgets.component.chip
  → rearkitekt.gui.systems.responsive_grid

### chip.lua
  → rearkitekt.gui.draw
  → rearkitekt.core.colors
  → rearkitekt.gui.fx.tile_fx
  → rearkitekt.gui.fx.tile_fx_config

### dropdown.lua
  → rearkitekt.gui.widgets.controls.tooltip

### status_pad.lua
  → rearkitekt.gui.draw
  → rearkitekt.core.colors
  → rearkitekt.gui.fx.tile_fx
  → rearkitekt.gui.fx.tile_fx_config

### animation.lua
  → rearkitekt.gui.fx.animations.spawn
  → rearkitekt.gui.fx.animations.destroy

### core.lua
  → rearkitekt.gui.widgets.grid.layout
  → rearkitekt.gui.fx.animation.rect_track
  → rearkitekt.core.colors
  → rearkitekt.gui.systems.selection
  → rearkitekt.gui.widgets.selection_rectangle
  → rearkitekt.gui.draw
  → rearkitekt.gui.fx.dnd.drag_indicator
  → rearkitekt.gui.fx.dnd.drop_indicator
  → rearkitekt.gui.widgets.grid.rendering
  → rearkitekt.gui.widgets.grid.animation
  → rearkitekt.gui.widgets.grid.input
  → rearkitekt.gui.widgets.grid.dnd_state
  → rearkitekt.gui.widgets.grid.drop_zones

### input.lua
  → rearkitekt.gui.draw

### rendering.lua
  → rearkitekt.gui.draw
  → rearkitekt.core.colors
  → rearkitekt.gui.fx.marching_ants

### manager.lua
  → rearkitekt.gui.draw
  → rearkitekt.core.colors
  → rearkitekt.gui.style
  → rearkitekt.gui.widgets.overlay.config

### sheet.lua
  → rearkitekt.gui.draw
  → rearkitekt.core.colors
  → rearkitekt.gui.style
  → rearkitekt.gui.widgets.overlay.config

### grid.lua
  → rearkitekt.gui.widgets.grid.core
  → rearkitekt.core.colors
  → rearkitekt.gui.fx.tile_motion
  → rearkitekt.gui.widgets.package_tiles.renderer
  → rearkitekt.gui.widgets.package_tiles.micromanage
  → rearkitekt.gui.systems.height_stabilizer

### renderer.lua
  → rearkitekt.gui.draw
  → rearkitekt.gui.fx.marching_ants
  → rearkitekt.core.colors

### dropdown_field.lua
  → rearkitekt.gui.widgets.controls.dropdown

### init.lua
  → rearkitekt.gui.widgets.panel.header.layout

### layout.lua
  → rearkitekt.gui.widgets.panel.header.tab_strip
  → rearkitekt.gui.widgets.panel.header.search_field
  → rearkitekt.gui.widgets.panel.header.dropdown_field
  → rearkitekt.gui.widgets.panel.header.button
  → rearkitekt.gui.widgets.panel.header.separator

### tab_strip.lua
  → rearkitekt.gui.widgets.controls.context_menu
  → rearkitekt.gui.widgets.component.chip

### header.lua
  → rearkitekt.gui.widgets.panel.modes.search_sort
  → rearkitekt.gui.widgets.panel.modes.tabs

### init.lua
  → rearkitekt.gui.widgets.panel.header
  → rearkitekt.gui.widgets.panel.content
  → rearkitekt.gui.widgets.panel.background
  → rearkitekt.gui.widgets.panel.tab_animator
  → rearkitekt.gui.widgets.controls.scrollbar
  → rearkitekt.gui.widgets.panel.config

### search_sort.lua
  → rearkitekt.gui.draw
  → rearkitekt.gui.widgets.controls.dropdown

### tabs.lua
  → rearkitekt.gui.widgets.controls.context_menu
  → rearkitekt.gui.widgets.component.chip

### tab_animator.lua
  → rearkitekt.gui.fx.easing

### tiles_container_old.lua
  → rearkitekt.gui.widgets.controls.dropdown

### transport_container.lua
  → rearkitekt.gui.widgets.transport.transport_fx

### transport_fx.lua
  → rearkitekt.core.colors

### gui.lua
  → rearkitekt.core.colors
  → rearkitekt.gui.draw
  → ColorPalette.widgets.color_grid
  → ColorPalette.app.controller
  → rearkitekt.gui.widgets.overlay.sheet

### state.lua
  → rearkitekt.core.colors

### ARK_ColorPalette.lua
  → rearkitekt.app.shell
  → ColorPalette.app.state
  → ColorPalette.app.gui
  → rearkitekt.gui.widgets.overlay.manager
  → rearkitekt.core.settings

### color_grid.lua
  → rearkitekt.core.colors
  → rearkitekt.gui.draw

### demo.lua
  → rearkitekt.app.shell
  → rearkitekt.gui.widgets.package_tiles.grid
  → rearkitekt.gui.widgets.package_tiles.micromanage
  → rearkitekt.gui.widgets.selection_rectangle

### demo2.lua
  → rearkitekt.app.shell
  → rearkitekt.gui.widgets.sliders.hue

### demo3.lua
  → rearkitekt.app.shell
  → rearkitekt.gui.widgets.displays.status_pad

### demo_modal_overlay.lua
  → rearkitekt.app.shell
  → rearkitekt.gui.widgets.overlay.sheet
  → rearkitekt.gui.widgets.chip_list.list
  → rearkitekt.gui.widgets.overlay.config

### widget_demo.lua
  → rearkitekt.app.shell
  → rearkitekt.gui.draw
  → rearkitekt.gui.fx.effects

### controller.lua
  → Region_Playlist.storage.state

### gui.lua
  → Region_Playlist.widgets.region_tiles.coordinator
  → rearkitekt.core.colors
  → Region_Playlist.app.shortcuts
  → Region_Playlist.app.controller
  → rearkitekt.gui.widgets.transport.transport_container
  → rearkitekt.gui.widgets.overlay.sheet
  → rearkitekt.gui.widgets.chip_list.list
  → Region_Playlist.app.config
  → rearkitekt.gui.fx.tile_motion

### shortcuts.lua
  → Region_Playlist.app.state

### state.lua
  → Region_Playlist.engine.coordinator_bridge
  → Region_Playlist.storage.state
  → rearkitekt.core.undo_manager
  → Region_Playlist.storage.undo_bridge
  → rearkitekt.core.colors

### ARK_RegionPlaylist.lua
  → rearkitekt.app.shell
  → Region_Playlist.app.config
  → Region_Playlist.app.state
  → Region_Playlist.app.gui
  → Region_Playlist.app.status

### coordinator_bridge.lua
  → Region_Playlist.engine.core
  → Region_Playlist.engine.playback
  → Region_Playlist.storage.state

### core.lua
  → Region_Playlist.engine.state
  → Region_Playlist.engine.transport
  → Region_Playlist.engine.transitions
  → Region_Playlist.engine.quantize

### playback.lua
  → rearkitekt.reaper.transport

### state.lua
  → rearkitekt.reaper.regions
  → rearkitekt.reaper.transport

### state.lua
  → rearkitekt.core.json
  → rearkitekt.core.colors

### active_grid_factory.lua
  → rearkitekt.gui.widgets.grid.core
  → Region_Playlist.widgets.region_tiles.renderers.active

### coordinator.lua
  → Region_Playlist.app.config
  → Region_Playlist.widgets.region_tiles.coordinator_render
  → rearkitekt.gui.draw
  → rearkitekt.core.colors
  → rearkitekt.gui.fx.tile_motion
  → rearkitekt.gui.systems.height_stabilizer
  → Region_Playlist.widgets.region_tiles.selector
  → Region_Playlist.widgets.region_tiles.active_grid_factory
  → Region_Playlist.widgets.region_tiles.pool_grid_factory
  → rearkitekt.gui.widgets.grid.grid_bridge
  → rearkitekt.gui.widgets.panel.config
  → Region_Playlist.app.state

### coordinator_render.lua
  → rearkitekt.gui.fx.dnd.drag_indicator
  → Region_Playlist.widgets.region_tiles.renderers.active
  → Region_Playlist.widgets.region_tiles.renderers.pool
  → rearkitekt.gui.systems.responsive_grid

### pool_grid_factory.lua
  → rearkitekt.gui.widgets.grid.core
  → Region_Playlist.widgets.region_tiles.renderers.pool

### active.lua
  → rearkitekt.core.colors
  → rearkitekt.gui.draw
  → rearkitekt.gui.fx.tile_fx_config
  → Region_Playlist.widgets.region_tiles.renderers.base
  → rearkitekt.gui.systems.playback_manager

### base.lua
  → rearkitekt.gui.draw
  → rearkitekt.core.colors
  → rearkitekt.gui.fx.tile_fx
  → rearkitekt.gui.fx.tile_fx_config
  → rearkitekt.gui.fx.marching_ants
  → rearkitekt.gui.systems.tile_utilities
  → rearkitekt.gui.widgets.component.chip

### pool.lua
  → rearkitekt.core.colors
  → rearkitekt.gui.draw
  → rearkitekt.gui.fx.tile_fx_config
  → rearkitekt.gui.systems.tile_utilities
  → Region_Playlist.widgets.region_tiles.renderers.base

### selector.lua
  → rearkitekt.gui.draw
  → rearkitekt.core.colors
  → rearkitekt.gui.fx.tile_motion
