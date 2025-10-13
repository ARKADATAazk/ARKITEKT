# FOLDER FLOW: arkitekt
Generated: 2025-10-13 02:51:26
Location: D:\Dropbox\REAPER\Scripts\ARKITEKT\arkitekt

## Overview
- **Files**: 84
- **Total Lines**: 15,484
- **Public Functions**: 245
- **Classes**: 51

## Files

### ARKITEKT.lua (324 lines)
  **Requires**: arkitekt.app.shell

### animation.lua (101 lines)
  **Modules**: M, AnimationCoordinator
  **Classes**: AnimationCoordinator, M
  **Exports**:
    - `M.new(config)`
  **Requires**: arkitekt.gui.fx.animations.spawn, arkitekt.gui.fx.animations.destroy

### background.lua (61 lines)
  **Modules**: M
  **Exports**:
    - `M.draw(dl, x1, y1, x2, y2, pattern_cfg)`

### button.lua (105 lines)
  **Modules**: M
  **Exports**:
    - `M.draw(ctx, dl, x, y, width, height, config, state)`
    - `M.measure(ctx, config)`

### chip.lua (333 lines)
  **Modules**: M
  **Exports**:
    - `M.calculate_width(ctx, label, opts)`
    - `M.draw(ctx, opts)`
  **Requires**: arkitekt.gui.draw, arkitekt.core.colors, arkitekt.gui.fx.tile_fx, arkitekt.gui.fx.tile_fx_config

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
  **Requires**: arkitekt.gui.widgets.component.chip

### config.lua (86 lines)
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

### config.lua (233 lines)
  **Modules**: M

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

### core.lua (550 lines)
  **Modules**: M, Grid, current_keys, new_keys, rect_map, rect_map, order, filtered_order, new_order
  **Classes**: Grid, M
  **Exports**:
    - `M.new(opts)`
  **Requires**: arkitekt.gui.widgets.grid.layout, arkitekt.gui.fx.animation.rect_track, arkitekt.core.colors, arkitekt.gui.systems.selection, arkitekt.gui.widgets.selection_rectangle

### destroy.lua (149 lines)
  **Modules**: M, DestroyAnim, completed
  **Classes**: DestroyAnim, M
  **Exports**:
    - `M.new(opts)`
  **Requires**: arkitekt.gui.fx.easing

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
  **Requires**: arkitekt.gui.draw, arkitekt.core.colors, arkitekt.gui.fx.dnd.config

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
  **Requires**: arkitekt.gui.fx.dnd.config

### drop_zones.lua (277 lines)
  **Modules**: M, non_dragged, zones, zones, rows, sequential_items, set
  **Exports**:
    - `M.find_drop_target(mx, my, items, key_fn, dragged_set, rect_track, is_single_column, grid_bounds)`
    - `M.find_external_drop_target(mx, my, items, key_fn, rect_track, is_single_column, grid_bounds)`
    - `M.build_dragged_set(dragged_ids)`

### dropdown.lua (356 lines)
  **Modules**: M, Dropdown
  **Classes**: Dropdown, M
  **Exports**:
    - `M.new(opts)`
  **Requires**: arkitekt.gui.widgets.controls.tooltip

### dropdown_field.lua (79 lines)
  **Modules**: M
  **Exports**:
    - `M.draw(ctx, dl, x, y, width, height, config, state)`
    - `M.measure(ctx, config)`
  **Requires**: arkitekt.gui.widgets.controls.dropdown

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
  **Requires**: arkitekt.gui.widgets.grid.core, arkitekt.core.colors, arkitekt.gui.fx.tile_motion, arkitekt.gui.widgets.package_tiles.renderer, arkitekt.gui.widgets.package_tiles.micromanage

### grid_bridge.lua (219 lines)
  **Modules**: M, GridBridge
  **Classes**: GridBridge, M
  **Exports**:
    - `M.new(config)`

### header.lua (42 lines)
  **Modules**: M
  **Exports**:
    - `M.draw(ctx, dl, x, y, w, h, state, config, rounding)`
  **Requires**: arkitekt.gui.widgets.panel.modes.search_sort, arkitekt.gui.widgets.panel.modes.tabs

### height_stabilizer.lua (74 lines)
  **Modules**: M, HeightStabilizer
  **Classes**: HeightStabilizer, M
  **Exports**:
    - `M.new(opts)`

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
  **Requires**: arkitekt.app.chrome.status_bar.widget

### init.lua (36 lines)
  **Modules**: M
  **Exports**:
    - `M.draw(ctx, dl, x, y, w, h, state, config, rounding)`
  **Requires**: arkitekt.gui.widgets.panel.header.layout

### init.lua (406 lines)
  **Modules**: M, result, Panel
  **Classes**: Panel, M
  **Exports**:
    - `M.new(opts)`
    - `M.draw(ctx, id, width, height, content_fn, config)`
  **Requires**: arkitekt.gui.widgets.panel.header, arkitekt.gui.widgets.panel.content, arkitekt.gui.widgets.panel.background, arkitekt.gui.widgets.panel.tab_animator, arkitekt.gui.widgets.controls.scrollbar

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
  **Requires**: arkitekt.gui.draw

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

### layout.lua (298 lines)
  **Modules**: M, layout, rounding_info, element_config
  **Exports**:
    - `M.draw(ctx, dl, x, y, width, height, state, config)`
  **Requires**: arkitekt.gui.widgets.panel.header.tab_strip, arkitekt.gui.widgets.panel.header.search_field, arkitekt.gui.widgets.panel.header.dropdown_field, arkitekt.gui.widgets.panel.header.button, arkitekt.gui.widgets.panel.header.separator

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
  **Requires**: arkitekt.gui.widgets.component.chip, arkitekt.gui.systems.responsive_grid

### manager.lua (178 lines)
  **Modules**: M
  **Classes**: M
  **Exports**:
    - `M.new()`
  **Requires**: arkitekt.gui.draw, arkitekt.core.colors, arkitekt.gui.style, arkitekt.gui.widgets.overlay.config

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

### playback_manager.lua (22 lines)
  **Modules**: M
  **Exports**:
    - `M.compute_fade_alpha(progress, fade_in_ratio, fade_out_ratio)`

### rect_track.lua (136 lines)
  **Modules**: M, RectTrack
  **Classes**: RectTrack, M
  **Exports**:
    - `M.new(speed, snap_epsilon, magnetic_threshold, magnetic_multiplier)`
  **Requires**: arkitekt.core.math

### regions.lua (83 lines)
  **Modules**: M, regions
  **Exports**:
    - `M.scan_project_regions(proj)`
    - `M.get_region_by_rid(proj, target_rid)`
    - `M.go_to_region(proj, target_rid)`

### renderer.lua (267 lines)
  **Modules**: M
  **Requires**: arkitekt.gui.draw, arkitekt.gui.fx.marching_ants, arkitekt.core.colors

### rendering.lua (90 lines)
  **Modules**: M
  **Requires**: arkitekt.gui.draw, arkitekt.core.colors, arkitekt.gui.fx.marching_ants

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

### search_field.lua (119 lines)
  **Modules**: M
  **Exports**:
    - `M.draw(ctx, dl, x, y, width, height, config, state)`
    - `M.measure(ctx, config)`

### search_sort.lua (225 lines)
  **Modules**: M
  **Exports**:
    - `M.draw(ctx, dl, x, y, width, height, state, cfg, current_mode, on_mode_changed)`
  **Requires**: arkitekt.gui.draw, arkitekt.gui.widgets.controls.dropdown

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
  **Requires**: arkitekt.core.json

### sheet.lua (125 lines)
  **Modules**: Sheet
  **Exports**:
    - `Sheet.render(ctx, alpha, bounds, content_fn, opts)`
  **Requires**: arkitekt.gui.draw, arkitekt.core.colors, arkitekt.gui.style, arkitekt.gui.widgets.overlay.config

### shell.lua (256 lines)
  **Modules**: M, DEFAULTS
  **Exports**:
    - `M.run(opts)`
  **Requires**: arkitekt.app.runtime, arkitekt.app.window

### spawn.lua (58 lines)
  **Modules**: M, SpawnTracker
  **Classes**: SpawnTracker, M
  **Exports**:
    - `M.new(config)`
  **Requires**: arkitekt.gui.fx.easing

### status_pad.lua (192 lines)
  **Modules**: M, FontPool, StatusPad
  **Classes**: StatusPad, M
  **Exports**:
    - `M.new(opts)`
  **Requires**: arkitekt.gui.draw, arkitekt.core.colors, arkitekt.gui.fx.tile_fx, arkitekt.gui.fx.tile_fx_config

### style.lua (146 lines)
  **Modules**: M
  **Exports**:
    - `M.with_alpha(col, a)`
    - `M.PushMyStyle(ctx)`
    - `M.PopMyStyle(ctx)`
  **Requires**: arkitekt.core.colors

### tab_animator.lua (107 lines)
  **Modules**: M, TabAnimator, spawn_complete, destroy_complete
  **Classes**: TabAnimator, M
  **Exports**:
    - `M.new(opts)`
  **Requires**: arkitekt.gui.fx.easing

### tab_strip.lua (731 lines)
  **Modules**: M, visible_indices, positions
  **Exports**:
    - `M.draw(ctx, dl, x, y, available_width, height, config, state)`
    - `M.measure(ctx, config, state)`
  **Requires**: arkitekt.gui.widgets.controls.context_menu, arkitekt.gui.widgets.component.chip

### tabs.lua (647 lines)
  **Modules**: M, visible_tabs, positions
  **Exports**:
    - `M.assign_random_color(tab)`
    - `M.draw(ctx, dl, x, y, width, height, state, cfg)`
  **Requires**: arkitekt.gui.widgets.controls.context_menu, arkitekt.gui.widgets.component.chip

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
  **Requires**: arkitekt.core.colors

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
  **Requires**: arkitekt.gui.fx.animation.track

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
  **Requires**: arkitekt.gui.widgets.controls.dropdown

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

### titlebar.lua (454 lines)
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
  **Requires**: arkitekt.core.math

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

### transport_container.lua (137 lines)
  **Modules**: M, TransportContainer
  **Classes**: TransportContainer, M
  **Exports**:
    - `M.new(opts)`
    - `M.draw(ctx, id, width, height, content_fn, config)`
  **Requires**: arkitekt.gui.widgets.transport.transport_fx

### transport_fx.lua (107 lines)
  **Modules**: M
  **Exports**:
    - `M.render_base(dl, x1, y1, x2, y2, config)`
    - `M.render_specular(dl, x1, y1, x2, y2, config, hover_factor)`
    - `M.render_inner_glow(dl, x1, y1, x2, y2, config, hover_factor)`
    - `M.render_border(dl, x1, y1, x2, y2, config)`
    - `M.render_complete(dl, x1, y1, x2, y2, config, hover_factor)`
  **Requires**: arkitekt.core.colors

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
  **Requires**: arkitekt.gui.widgets.component.chip, arkitekt.app.chrome.status_bar.config

### window.lua (560 lines)
  **Modules**: M, DEFAULTS
  **Classes**: M
  **Exports**:
    - `M.new(opts)`

## Internal Dependencies

### config.lua
  → arkitekt.gui.widgets.component.chip

### init.lua
  → arkitekt.app.chrome.status_bar.widget

### widget.lua
  → arkitekt.gui.widgets.component.chip
  → arkitekt.app.chrome.status_bar.config

### shell.lua
  → arkitekt.app.runtime
  → arkitekt.app.window

### ARKITEKT.lua
  → arkitekt.app.shell

### settings.lua
  → arkitekt.core.json

### rect_track.lua
  → arkitekt.core.math

### track.lua
  → arkitekt.core.math

### destroy.lua
  → arkitekt.gui.fx.easing

### spawn.lua
  → arkitekt.gui.fx.easing

### drag_indicator.lua
  → arkitekt.gui.draw
  → arkitekt.core.colors
  → arkitekt.gui.fx.dnd.config

### drop_indicator.lua
  → arkitekt.gui.fx.dnd.config

### tile_fx.lua
  → arkitekt.core.colors

### tile_motion.lua
  → arkitekt.gui.fx.animation.track

### style.lua
  → arkitekt.core.colors

### list.lua
  → arkitekt.gui.widgets.component.chip
  → arkitekt.gui.systems.responsive_grid

### chip.lua
  → arkitekt.gui.draw
  → arkitekt.core.colors
  → arkitekt.gui.fx.tile_fx
  → arkitekt.gui.fx.tile_fx_config

### dropdown.lua
  → arkitekt.gui.widgets.controls.tooltip

### status_pad.lua
  → arkitekt.gui.draw
  → arkitekt.core.colors
  → arkitekt.gui.fx.tile_fx
  → arkitekt.gui.fx.tile_fx_config

### animation.lua
  → arkitekt.gui.fx.animations.spawn
  → arkitekt.gui.fx.animations.destroy

### core.lua
  → arkitekt.gui.widgets.grid.layout
  → arkitekt.gui.fx.animation.rect_track
  → arkitekt.core.colors
  → arkitekt.gui.systems.selection
  → arkitekt.gui.widgets.selection_rectangle
  → arkitekt.gui.draw
  → arkitekt.gui.fx.dnd.drag_indicator
  → arkitekt.gui.fx.dnd.drop_indicator
  → arkitekt.gui.widgets.grid.rendering
  → arkitekt.gui.widgets.grid.animation
  → arkitekt.gui.widgets.grid.input
  → arkitekt.gui.widgets.grid.dnd_state
  → arkitekt.gui.widgets.grid.drop_zones

### input.lua
  → arkitekt.gui.draw

### rendering.lua
  → arkitekt.gui.draw
  → arkitekt.core.colors
  → arkitekt.gui.fx.marching_ants

### manager.lua
  → arkitekt.gui.draw
  → arkitekt.core.colors
  → arkitekt.gui.style
  → arkitekt.gui.widgets.overlay.config

### sheet.lua
  → arkitekt.gui.draw
  → arkitekt.core.colors
  → arkitekt.gui.style
  → arkitekt.gui.widgets.overlay.config

### grid.lua
  → arkitekt.gui.widgets.grid.core
  → arkitekt.core.colors
  → arkitekt.gui.fx.tile_motion
  → arkitekt.gui.widgets.package_tiles.renderer
  → arkitekt.gui.widgets.package_tiles.micromanage
  → arkitekt.gui.systems.height_stabilizer

### renderer.lua
  → arkitekt.gui.draw
  → arkitekt.gui.fx.marching_ants
  → arkitekt.core.colors

### dropdown_field.lua
  → arkitekt.gui.widgets.controls.dropdown

### init.lua
  → arkitekt.gui.widgets.panel.header.layout

### layout.lua
  → arkitekt.gui.widgets.panel.header.tab_strip
  → arkitekt.gui.widgets.panel.header.search_field
  → arkitekt.gui.widgets.panel.header.dropdown_field
  → arkitekt.gui.widgets.panel.header.button
  → arkitekt.gui.widgets.panel.header.separator

### tab_strip.lua
  → arkitekt.gui.widgets.controls.context_menu
  → arkitekt.gui.widgets.component.chip

### header.lua
  → arkitekt.gui.widgets.panel.modes.search_sort
  → arkitekt.gui.widgets.panel.modes.tabs

### init.lua
  → arkitekt.gui.widgets.panel.header
  → arkitekt.gui.widgets.panel.content
  → arkitekt.gui.widgets.panel.background
  → arkitekt.gui.widgets.panel.tab_animator
  → arkitekt.gui.widgets.controls.scrollbar
  → arkitekt.gui.widgets.panel.config

### search_sort.lua
  → arkitekt.gui.draw
  → arkitekt.gui.widgets.controls.dropdown

### tabs.lua
  → arkitekt.gui.widgets.controls.context_menu
  → arkitekt.gui.widgets.component.chip

### tab_animator.lua
  → arkitekt.gui.fx.easing

### tiles_container_old.lua
  → arkitekt.gui.widgets.controls.dropdown

### transport_container.lua
  → arkitekt.gui.widgets.transport.transport_fx

### transport_fx.lua
  → arkitekt.core.colors
