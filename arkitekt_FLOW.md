# ARKITEKT FLOW
Generated: 2025-10-15 19:22:52

## Overview
- **Folders**: 1
- **Files**: 137
- **Total Lines**: 25,412
- **Code Lines**: 19,942
- **Exports**: 375
- **Classes**: 93

## Folder Organization

### ARKITEKT
- Files: 137
- Lines: 19,942
- Exports: 375

## Orchestrators

**`ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/coordinator.lua`** (14 dependencies)
  Composes: config + coordinator_render + draw + colors + tile_motion + height_stabilizer + selector + active_grid_factory + pool_grid_factory + grid_bridge + panel + config + state + state

**`ARKITEKT/arkitekt/gui/widgets/grid/core.lua`** (13 dependencies)
  Composes: layout + rect_track + colors + selection + selection_rectangle + draw + drag_indicator + drop_indicator + rendering + animation + input + dnd_state + drop_zones

**`ARKITEKT/scripts/RegionPlaylist/views/main.lua`** (11 dependencies)
  Composes: coordinator + controller + config + transport_bar + active_panel + pool_panel + status_bar + modal_manager + separator_manager + shortcuts + state

**`ARKITEKT/scripts/RegionPlaylist/ARK_RegionPlaylist.lua`** (10 dependencies)
  Composes: shell + config + state + status + colors + events + state + main + coordinator + sequencer

**`ARKITEKT/scripts/RegionPlaylist/app/state.lua`** (8 dependencies)
  Composes: state + persistence + undo_manager + undo_bridge + colors + events + sequencer + coordinator

## Module API

### `ARKITEKT/ARKITEKT.lua` (353 lines)
> @description ARKITEKT Toolkit Hub
**Modules**: `result, conflicts, asset_providers`
**Private**: 7 helpers
**Requires**: `arkitekt.app.shell, arkitekt.app.hub, arkitekt.gui.widgets.package_tiles.grid, arkitekt.gui.widgets.package_tiles.micromanage, arkitekt.gui.widgets.panel, arkitekt.gui.widgets.selection_rectangle`

### `ARKITEKT/arkitekt/app/chrome/status_bar/config.lua` (140 lines)
> @noindex
**Modules**: `M, result`
**Exports**:
  - `M.deepMerge(base, override)`
  - `M.merge(user_config, preset_name)`
**Requires**: `arkitekt.gui.widgets.component.chip`

### `ARKITEKT/arkitekt/app/chrome/status_bar/widget.lua` (319 lines)
> @noindex
**Modules**: `M, right_items`
**Classes**: `M`
**Exports**:
  - `M.new(config)` → Instance
**Private**: 6 helpers
**Requires**: `arkitekt.gui.widgets.component.chip, arkitekt.app.chrome.status_bar.config`

### `ARKITEKT/arkitekt/app/config.lua` (95 lines)
> @noindex
**Modules**: `M, keys`
**Exports**:
  - `M.get_defaults()`
  - `M.get(path)`

### `ARKITEKT/arkitekt/app/hub.lua` (93 lines)
> @noindex
**Modules**: `M, apps`
**Exports**:
  - `M.launch_app(app_path)`
  - `M.render_hub(ctx, opts)`

### `ARKITEKT/arkitekt/app/icon.lua` (124 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.draw_arkitekt(ctx, x, y, size, color)`
  - `M.draw_arkitekt_v2(ctx, x, y, size, color)`
  - `M.draw_simple_a(ctx, x, y, size, color)`

### `ARKITEKT/arkitekt/app/runtime.lua` (69 lines)
> @noindex
**Modules**: `M`
**Classes**: `M`
**Exports**:
  - `M.new(opts)` → Instance

### `ARKITEKT/arkitekt/app/shell.lua` (289 lines)
> @noindex
**Modules**: `M, DEFAULTS`
**Exports**:
  - `M.run(opts)`
**Private**: 4 helpers
**Requires**: `arkitekt.app.runtime, arkitekt.app.window`

### `ARKITEKT/arkitekt/app/titlebar.lua` (507 lines)
> @noindex
**Modules**: `M, DEFAULTS`
**Classes**: `M`
**Exports**:
  - `M.new(opts)` → Instance

### `ARKITEKT/arkitekt/app/window.lua` (481 lines)
> @noindex
**Modules**: `M, DEFAULTS`
**Classes**: `M`
**Exports**:
  - `M.new(opts)` → Instance

### `ARKITEKT/arkitekt/core/colors.lua` (550 lines)
> @noindex
**Modules**: `M`
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
  - `M.auto_text_color(bg_color)`
  - `M.rgb_to_reaper(rgb_color)`
  - `M.rgb_to_hsl(color)`
  - `M.hsl_to_rgb(h, s, l)`
  - `M.get_color_sort_key(color)`
  - `M.compare_colors(color_a, color_b)`
  - `M.analyze_color(color)`
  - `M.derive_normalized(color, pullback)`
  - `M.derive_brightened(color, factor)`
  - `M.derive_intensified(color, sat_boost, bright_boost)`
  - `M.derive_muted(color, desat_amt, dark_amt)`
  - `M.derive_fill(base_color, opts)`
  - `M.derive_border(base_color, opts)`
  - `M.derive_hover(base_color, opts)`
  - `M.derive_selection(base_color, opts)`
  - `M.derive_marching_ants(base_color, opts)`
  - `M.derive_palette(base_color, opts)`
  - `M.derive_palette_adaptive(base_color, preset)`
  - `M.generate_border(base_color, desaturate_amt, brightness_factor)`
  - `M.generate_hover(base_color, brightness_factor)`
  - `M.generate_active_border(base_color, saturation_boost, brightness_boost)`
  - `M.generate_selection_color(base_color, brightness_boost, saturation_boost)`
  - `M.generate_marching_ants_color(base_color, brightness_factor, saturation_factor)`
  - `M.auto_palette(base_color)`
  - `M.flashy_palette(base_color)`
  - `M.same_hue_variant(col, s_mult, v_mult, new_a)`
  - `M.tile_text_colors(base_color)`
  - `M.tile_meta_color(name_color, alpha)`

### `ARKITEKT/arkitekt/core/events.lua` (67 lines)
**Modules**: `Bus, M`
**Classes**: `Bus, M`
**Exports**:
  - `Bus.new()` → Instance
  - `M.new()` → Instance

### `ARKITEKT/arkitekt/core/json.lua` (121 lines)
> @noindex
**Modules**: `M, out, obj, arr`
**Exports**:
  - `M.encode(t)`
  - `M.decode(str)`
**Private**: 5 helpers

### `ARKITEKT/arkitekt/core/lifecycle.lua` (81 lines)
> @noindex
**Modules**: `M, Group`
**Classes**: `Group, M`
**Exports**:
  - `M.new()` → Instance

### `ARKITEKT/arkitekt/core/math.lua` (52 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.lerp(a, b, t)`
  - `M.clamp(value, min, max)`
  - `M.remap(value, in_min, in_max, out_min, out_max)`
  - `M.snap(value, step)`
  - `M.smoothdamp(current, target, velocity, smoothtime, maxspeed, dt)`
  - `M.approximately(a, b, epsilon)`

### `ARKITEKT/arkitekt/core/settings.lua` (119 lines)
> @noindex
**Modules**: `Settings, out, M, t`
**Classes**: `Settings`
**Exports**:
  - `M.open(cache_dir, filename)`
**Private**: 7 helpers
**Requires**: `arkitekt.core.json`

### `ARKITEKT/arkitekt/core/undo_manager.lua` (70 lines)
> @noindex
**Modules**: `M`
**Classes**: `M`
**Exports**:
  - `M.new(opts)` → Instance

### `ARKITEKT/arkitekt/gui/draw.lua` (114 lines)
> @noindex
**Modules**: `M`
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

### `ARKITEKT/arkitekt/gui/fx/animation/rect_track.lua` (136 lines)
> @noindex
**Modules**: `M, RectTrack`
**Classes**: `RectTrack, M`
**Exports**:
  - `M.new(speed, snap_epsilon, magnetic_threshold, magnetic_multiplier)` → Instance
**Requires**: `arkitekt.core.math`

### `ARKITEKT/arkitekt/gui/fx/animation/track.lua` (53 lines)
> @noindex
**Modules**: `M, Track`
**Classes**: `Track, M`
**Exports**:
  - `M.new(initial_value, speed)` → Instance
**Requires**: `arkitekt.core.math`

### `ARKITEKT/arkitekt/gui/fx/animations/destroy.lua` (149 lines)
> @noindex
**Modules**: `M, DestroyAnim, completed`
**Classes**: `DestroyAnim, M`
**Exports**:
  - `M.new(opts)` → Instance
**Requires**: `arkitekt.gui.fx.easing`

### `ARKITEKT/arkitekt/gui/fx/animations/spawn.lua` (58 lines)
> @noindex
**Modules**: `M, SpawnTracker`
**Classes**: `SpawnTracker, M`
**Exports**:
  - `M.new(config)` → Instance
**Requires**: `arkitekt.gui.fx.easing`

### `ARKITEKT/arkitekt/gui/fx/dnd/config.lua` (91 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.get_mode_config(config, is_copy, is_delete)`

### `ARKITEKT/arkitekt/gui/fx/dnd/drag_indicator.lua` (219 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.draw_badge(ctx, dl, mx, my, count, config, is_copy_mode, is_delete_mode)`
  - `M.draw(ctx, dl, mx, my, count, config, colors, is_copy_mode, is_delete_mode)`
**Private**: 5 helpers
**Requires**: `arkitekt.gui.draw, arkitekt.core.colors, arkitekt.gui.fx.dnd.config`

### `ARKITEKT/arkitekt/gui/fx/dnd/drop_indicator.lua` (113 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.draw_vertical(ctx, dl, x, y1, y2, config, is_copy_mode)`
  - `M.draw_horizontal(ctx, dl, x1, x2, y, config, is_copy_mode)`
  - `M.draw(ctx, dl, config, is_copy_mode, orientation, ...)`
**Requires**: `arkitekt.gui.fx.dnd.config`

### `ARKITEKT/arkitekt/gui/fx/easing.lua` (94 lines)
> @noindex
**Modules**: `M`
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
  - `M.smoothstep(t)`
  - `M.smootherstep(t)`
  - `M.ease_in_expo(t)`
  - `M.ease_out_expo(t)`
  - `M.ease_in_out_expo(t)`
  - `M.ease_in_back(t)`
  - `M.ease_out_back(t)`

### `ARKITEKT/arkitekt/gui/fx/effects.lua` (54 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.hover_shadow(dl, x1, y1, x2, y2, strength, radius)`
  - `M.soft_glow(dl, x1, y1, x2, y2, color, intensity, radius)`
  - `M.pulse_glow(dl, x1, y1, x2, y2, color, time, speed, radius)`

### `ARKITEKT/arkitekt/gui/fx/marching_ants.lua` (100 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.draw(dl, x1, y1, x2, y2, color, thickness, radius, dash, gap, speed_px)`
**Requires**: `arkitekt.gui.draw`

### `ARKITEKT/arkitekt/gui/fx/tile_fx.lua` (170 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.render_base_fill(dl, x1, y1, x2, y2, rounding)`
  - `M.render_color_fill(dl, x1, y1, x2, y2, base_color, opacity, saturation, brightness, rounding)`
  - `M.render_gradient(dl, x1, y1, x2, y2, base_color, intensity, opacity, rounding)`
  - `M.render_specular(dl, x1, y1, x2, y2, base_color, strength, coverage, rounding)`
  - `M.render_inner_shadow(dl, x1, y1, x2, y2, strength, rounding)`
  - `M.render_playback_progress(dl, x1, y1, x2, y2, base_color, progress, fade_alpha, rounding)`
  - `M.render_border(dl, x1, y1, x2, y2, base_color, saturation, brightness, opacity, thickness, rounding, is_selected, glow_strength, glow_layers)`
  - `M.render_complete(dl, x1, y1, x2, y2, base_color, config, is_selected, hover_factor, playback_progress, playback_fade)`
**Requires**: `arkitekt.core.colors`

### `ARKITEKT/arkitekt/gui/fx/tile_fx_config.lua` (79 lines)
> @noindex
**Modules**: `M, config`
**Exports**:
  - `M.get()`
  - `M.override(overrides)`

### `ARKITEKT/arkitekt/gui/fx/tile_motion.lua` (58 lines)
> @noindex
**Modules**: `M, TileAnimator`
**Classes**: `TileAnimator, M`
**Exports**:
  - `M.new(default_speed)` → Instance
**Requires**: `arkitekt.gui.fx.animation.track`

### `ARKITEKT/arkitekt/gui/images.lua` (285 lines)
> @noindex
**Modules**: `M, Cache`
**Classes**: `Cache, M`
**Exports**:
  - `M.new(opts)` → Instance
**Private**: 9 helpers

### `ARKITEKT/arkitekt/gui/style.lua` (146 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.with_alpha(col, a)`
  - `M.PushMyStyle(ctx)`
  - `M.PopMyStyle(ctx)`
**Requires**: `arkitekt.core.colors`

### `ARKITEKT/arkitekt/gui/systems/height_stabilizer.lua` (74 lines)
> @noindex
**Modules**: `M, HeightStabilizer`
**Classes**: `HeightStabilizer, M`
**Exports**:
  - `M.new(opts)` → Instance

### `ARKITEKT/arkitekt/gui/systems/playback_manager.lua` (22 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.compute_fade_alpha(progress, fade_in_ratio, fade_out_ratio)`

### `ARKITEKT/arkitekt/gui/systems/reorder.lua` (127 lines)
> @noindex
**Modules**: `M, t, base, new_order, new_order, new_order`
**Exports**:
  - `M.insert_relative(order_keys, dragged_keys, target_key, side)`
  - `M.move_up(order_keys, selected_keys)`
  - `M.move_down(order_keys, selected_keys)`

### `ARKITEKT/arkitekt/gui/systems/responsive_grid.lua` (228 lines)
> @noindex
**Modules**: `M, rows, current_row, layout`
**Exports**:
  - `M.calculate_scaled_gap(tile_height, base_gap, base_height, min_height, responsive_config)`
  - `M.calculate_responsive_tile_height(opts)`
  - `M.calculate_grid_metrics(opts)`
  - `M.calculate_justified_layout(items, opts)`
  - `M.should_show_scrollbar(grid_height, available_height, buffer)`
  - `M.create_default_config()` → Instance

### `ARKITEKT/arkitekt/gui/systems/selection.lua` (142 lines)
> @noindex
**Modules**: `M, Selection, out, out`
**Classes**: `Selection, M`
**Exports**:
  - `M.new()` → Instance

### `ARKITEKT/arkitekt/gui/systems/tile_utilities.lua` (49 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.format_bar_length(start_time, end_time, proj)`

### `ARKITEKT/arkitekt/gui/widgets/chip_list/list.lua` (303 lines)
> @noindex
**Modules**: `M, filtered, min_widths, min_widths`
**Exports**:
  - `M.draw(ctx, items, opts)`
  - `M.draw_vertical(ctx, items, opts)`
  - `M.draw_columns(ctx, items, opts)`
  - `M.draw_grid(ctx, items, opts)`
  - `M.draw_auto(ctx, items, opts)`
**Requires**: `arkitekt.gui.widgets.component.chip, arkitekt.gui.systems.responsive_grid`

### `ARKITEKT/arkitekt/gui/widgets/component/chip.lua` (333 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.calculate_width(ctx, label, opts)`
  - `M.draw(ctx, opts)`
**Private**: 4 helpers
**Requires**: `arkitekt.gui.draw, arkitekt.core.colors, arkitekt.gui.fx.tile_fx, arkitekt.gui.fx.tile_fx_config`

### `ARKITEKT/arkitekt/gui/widgets/controls/context_menu.lua` (106 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.begin(ctx, id, config)`
  - `M.end_menu(ctx)`
  - `M.item(ctx, label, config)`
  - `M.separator(ctx, config)`

### `ARKITEKT/arkitekt/gui/widgets/controls/dropdown.lua` (395 lines)
> @noindex
**Modules**: `M, Dropdown`
**Classes**: `Dropdown, M`
**Exports**:
  - `M.new(opts)` → Instance
**Requires**: `arkitekt.gui.widgets.controls.tooltip`

### `ARKITEKT/arkitekt/gui/widgets/controls/scrollbar.lua` (239 lines)
> @noindex
**Modules**: `M, Scrollbar`
**Classes**: `Scrollbar, M`
**Exports**:
  - `M.new(opts)` → Instance

### `ARKITEKT/arkitekt/gui/widgets/controls/tooltip.lua` (129 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.show(ctx, text, config)`
  - `M.show_delayed(ctx, text, config)`
  - `M.show_at_mouse(ctx, text, config)`
  - `M.reset()`

### `ARKITEKT/arkitekt/gui/widgets/displays/status_pad.lua` (192 lines)
> @noindex
**Modules**: `M, FontPool, StatusPad`
**Classes**: `StatusPad, M`
**Exports**:
  - `M.new(opts)` → Instance
**Private**: 4 helpers
**Requires**: `arkitekt.gui.draw, arkitekt.core.colors, arkitekt.gui.fx.tile_fx, arkitekt.gui.fx.tile_fx_config`

### `ARKITEKT/arkitekt/gui/widgets/grid/animation.lua` (101 lines)
> @noindex
**Modules**: `M, AnimationCoordinator`
**Classes**: `AnimationCoordinator, M`
**Exports**:
  - `M.new(config)` → Instance
**Requires**: `arkitekt.gui.fx.animations.spawn, arkitekt.gui.fx.animations.destroy`

### `ARKITEKT/arkitekt/gui/widgets/grid/core.lua` (569 lines)
> @noindex
**Modules**: `M, Grid, current_keys, new_keys, rect_map, rect_map, order, filtered_order, new_order`
**Classes**: `Grid, M`
**Exports**:
  - `M.new(opts)` → Instance
**Requires**: `arkitekt.gui.widgets.grid.layout, arkitekt.gui.fx.animation.rect_track, arkitekt.core.colors, arkitekt.gui.systems.selection, arkitekt.gui.widgets.selection_rectangle, arkitekt.gui.draw, arkitekt.gui.fx.dnd.drag_indicator, arkitekt.gui.fx.dnd.drop_indicator, arkitekt.gui.widgets.grid.rendering, arkitekt.gui.widgets.grid.animation, arkitekt.gui.widgets.grid.input, arkitekt.gui.widgets.grid.dnd_state, arkitekt.gui.widgets.grid.drop_zones`

### `ARKITEKT/arkitekt/gui/widgets/grid/dnd_state.lua` (113 lines)
> @noindex
**Modules**: `M, DnDState`
**Classes**: `DnDState, M`
**Exports**:
  - `M.new(opts)` → Instance

### `ARKITEKT/arkitekt/gui/widgets/grid/drop_zones.lua` (277 lines)
> @noindex
**Modules**: `M, non_dragged, zones, zones, rows, sequential_items, set`
**Exports**:
  - `M.find_drop_target(mx, my, items, key_fn, dragged_set, rect_track, is_single_column, grid_bounds)`
  - `M.find_external_drop_target(mx, my, items, key_fn, rect_track, is_single_column, grid_bounds)`
  - `M.build_dragged_set(dragged_ids)`
**Private**: 5 helpers

### `ARKITEKT/arkitekt/gui/widgets/grid/grid_bridge.lua` (219 lines)
> @noindex
**Modules**: `M, GridBridge`
**Classes**: `GridBridge, M`
**Exports**:
  - `M.new(config)` → Instance

### `ARKITEKT/arkitekt/gui/widgets/grid/input.lua` (237 lines)
> @noindex
**Modules**: `M, keys_to_adjust, order, order`
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
**Requires**: `arkitekt.gui.draw`

### `ARKITEKT/arkitekt/gui/widgets/grid/layout.lua` (101 lines)
> @noindex
**Modules**: `M, rects`
**Exports**:
  - `M.calculate(avail_w, min_col_w, gap, n_items, origin_x, origin_y, fixed_tile_h)`
  - `M.get_height(rows, tile_h, gap)`

### `ARKITEKT/arkitekt/gui/widgets/grid/rendering.lua` (92 lines)
> @noindex
**Modules**: `M`
**Requires**: `arkitekt.gui.draw, arkitekt.core.colors, arkitekt.gui.fx.marching_ants`

### `ARKITEKT/arkitekt/gui/widgets/navigation/menutabs.lua` (269 lines)
> @noindex
**Modules**: `M, o, o, edges`
**Classes**: `M`
**Exports**:
  - `M.new(opts)` → Instance
**Private**: 4 helpers

### `ARKITEKT/arkitekt/gui/widgets/overlay/config.lua` (139 lines)
> @noindex
**Modules**: `M, new_config`
**Exports**:
  - `M.get()`
  - `M.override(overrides)`
  - `M.reset()`

### `ARKITEKT/arkitekt/gui/widgets/overlay/manager.lua` (178 lines)
> @noindex
**Modules**: `M`
**Classes**: `M`
**Exports**:
  - `M.new()` → Instance
**Requires**: `arkitekt.gui.draw, arkitekt.core.colors, arkitekt.gui.style, arkitekt.gui.widgets.overlay.config`

### `ARKITEKT/arkitekt/gui/widgets/overlay/sheet.lua` (125 lines)
> @noindex
**Modules**: `Sheet`
**Exports**:
  - `Sheet.render(ctx, alpha, bounds, content_fn, opts)`
**Requires**: `arkitekt.gui.draw, arkitekt.core.colors, arkitekt.gui.style, arkitekt.gui.widgets.overlay.config`

### `ARKITEKT/arkitekt/gui/widgets/package_tiles/grid.lua` (227 lines)
> @noindex
**Modules**: `M`
**Classes**: `M`
**Exports**:
  - `M.create(pkg, settings, theme)` → Instance
**Requires**: `arkitekt.gui.widgets.grid.core, arkitekt.core.colors, arkitekt.gui.fx.tile_motion, arkitekt.gui.widgets.package_tiles.renderer, arkitekt.gui.widgets.package_tiles.micromanage, arkitekt.gui.systems.height_stabilizer`

### `ARKITEKT/arkitekt/gui/widgets/package_tiles/micromanage.lua` (127 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.open(pkg_id)`
  - `M.close()`
  - `M.is_open()`
  - `M.get_package_id()`
  - `M.draw_window(ctx, pkg, settings)`
  - `M.reset()`

### `ARKITEKT/arkitekt/gui/widgets/package_tiles/renderer.lua` (267 lines)
> @noindex
**Modules**: `M`
**Requires**: `arkitekt.gui.draw, arkitekt.gui.fx.marching_ants, arkitekt.core.colors`

### `ARKITEKT/arkitekt/gui/widgets/panel/background.lua` (61 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.draw(dl, x1, y1, x2, y2, pattern_cfg)`

### `ARKITEKT/arkitekt/gui/widgets/panel/config.lua` (257 lines)
> @noindex
**Modules**: `M`

### `ARKITEKT/arkitekt/gui/widgets/panel/content.lua` (44 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.begin_child(ctx, id, width, height, scroll_config)`
  - `M.end_child(ctx, container)`

### `ARKITEKT/arkitekt/gui/widgets/panel/header/button.lua` (119 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.draw(ctx, dl, x, y, width, height, config, state)`
  - `M.measure(ctx, config)`

### `ARKITEKT/arkitekt/gui/widgets/panel/header/dropdown_field.lua` (101 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.draw(ctx, dl, x, y, width, height, config, state)`
  - `M.measure(ctx, config)`
**Requires**: `arkitekt.gui.widgets.controls.dropdown`

### `ARKITEKT/arkitekt/gui/widgets/panel/header/init.lua` (46 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.draw(ctx, dl, x, y, w, h, state, config, rounding)`
  - `M.draw_elements(ctx, dl, x, y, w, h, state, config)`
**Requires**: `arkitekt.gui.widgets.panel.header.layout`

### `ARKITEKT/arkitekt/gui/widgets/panel/header/layout.lua` (305 lines)
> @noindex
**Modules**: `M, layout, rounding_info, element_config`
**Exports**:
  - `M.draw(ctx, dl, x, y, width, height, state, config)`
**Private**: 8 helpers
**Requires**: `arkitekt.gui.widgets.panel.header.tab_strip, arkitekt.gui.widgets.panel.header.search_field, arkitekt.gui.widgets.panel.header.dropdown_field, arkitekt.gui.widgets.panel.header.button, arkitekt.gui.widgets.panel.header.separator`

### `ARKITEKT/arkitekt/gui/widgets/panel/header/search_field.lua` (120 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.draw(ctx, dl, x, y, width, height, config, state)`
  - `M.measure(ctx, config)`

### `ARKITEKT/arkitekt/gui/widgets/panel/header/separator.lua` (33 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.draw(ctx, dl, x, y, width, height, config)`
  - `M.measure(ctx, config)`

### `ARKITEKT/arkitekt/gui/widgets/panel/header/tab_strip.lua` (804 lines)
> @noindex
**Modules**: `M, visible_indices, positions`
**Exports**:
  - `M.draw(ctx, dl, x, y, available_width, height, config, state)`
  - `M.measure(ctx, config, state)`
**Private**: 12 helpers
**Requires**: `arkitekt.gui.widgets.controls.context_menu, arkitekt.gui.widgets.component.chip`

### `ARKITEKT/arkitekt/gui/widgets/panel/init.lua` (416 lines)
> @noindex
**Modules**: `M, result, Panel`
**Classes**: `Panel, M`
**Exports**:
  - `M.new(opts)` → Instance
  - `M.draw(ctx, id, width, height, content_fn, config)`
**Requires**: `arkitekt.gui.widgets.panel.header, arkitekt.gui.widgets.panel.content, arkitekt.gui.widgets.panel.background, arkitekt.gui.widgets.panel.tab_animator, arkitekt.gui.widgets.controls.scrollbar, arkitekt.gui.widgets.panel.config`

### `ARKITEKT/arkitekt/gui/widgets/panel/tab_animator.lua` (107 lines)
> @noindex
**Modules**: `M, TabAnimator, spawn_complete, destroy_complete`
**Classes**: `TabAnimator, M`
**Exports**:
  - `M.new(opts)` → Instance
**Requires**: `arkitekt.gui.fx.easing`

### `ARKITEKT/arkitekt/gui/widgets/selection_rectangle.lua` (99 lines)
> @noindex
**Modules**: `M, SelRect`
**Classes**: `SelRect, M`
**Exports**:
  - `M.new(opts)` → Instance

### `ARKITEKT/arkitekt/gui/widgets/sliders/hue.lua` (276 lines)
> @noindex
**Modules**: `M, _locks`
**Exports**:
  - `M.draw_hue(ctx, id, hue, opt)`
  - `M.draw_saturation(ctx, id, saturation, base_hue, opt)`
  - `M.draw_gamma(ctx, id, gamma, opt)`
  - `M.draw(ctx, id, hue, opt)`
**Private**: 5 helpers

### `ARKITEKT/arkitekt/gui/widgets/transport/transport_container.lua` (137 lines)
> @noindex
**Modules**: `M, TransportContainer`
**Classes**: `TransportContainer, M`
**Exports**:
  - `M.new(opts)` → Instance
  - `M.draw(ctx, id, width, height, content_fn, config)`
**Requires**: `arkitekt.gui.widgets.transport.transport_fx`

### `ARKITEKT/arkitekt/gui/widgets/transport/transport_fx.lua` (107 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.render_base(dl, x1, y1, x2, y2, config)`
  - `M.render_specular(dl, x1, y1, x2, y2, config, hover_factor)`
  - `M.render_inner_glow(dl, x1, y1, x2, y2, config, hover_factor)`
  - `M.render_border(dl, x1, y1, x2, y2, config)`
  - `M.render_complete(dl, x1, y1, x2, y2, config, hover_factor)`
**Requires**: `arkitekt.core.colors`

### `ARKITEKT/arkitekt/patterns/controller.lua` (25 lines)
**Modules**: `M`
**Classes**: `M`

### `ARKITEKT/arkitekt/reaper/regions.lua` (83 lines)
> @noindex
**Modules**: `M, regions`
**Exports**:
  - `M.scan_project_regions(proj)`
  - `M.get_region_by_rid(proj, target_rid)`
  - `M.go_to_region(proj, target_rid)`

### `ARKITEKT/arkitekt/reaper/timing.lua` (113 lines)
> @noindex
**Modules**: `M`
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

### `ARKITEKT/arkitekt/reaper/transport.lua` (97 lines)
> @noindex
**Modules**: `M`
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
  - `M.get_project_length(proj)`
  - `M.get_project_state_change_count(proj)`
  - `M.update_timeline()`
  - `M.get_pdc_offset(proj)`

### `ARKITEKT/scripts/ColorPalette/app/controller.lua` (235 lines)
> @noindex
**Modules**: `M, Controller, targets, colors`
**Classes**: `Controller, M`
**Exports**:
  - `M.new()` → Instance

### `ARKITEKT/scripts/ColorPalette/app/gui.lua` (443 lines)
> @noindex
**Modules**: `M, GUI`
**Classes**: `GUI, M`
**Exports**:
  - `M.create(State, settings, overlay_manager)` → Instance
**Requires**: `arkitekt.core.colors, arkitekt.gui.draw, ColorPalette.widgets.color_grid, ColorPalette.app.controller, arkitekt.gui.widgets.overlay.sheet`

### `ARKITEKT/scripts/ColorPalette/app/state.lua` (273 lines)
> @noindex
**Modules**: `M`
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
  - `M.set_children(value)`
  - `M.get_set_children()`
  - `M.update_palette_hue(hue)`
  - `M.update_palette_sat(sat_array)`
  - `M.update_palette_lum(lum_array)`
  - `M.update_palette_grey(include_grey)`
  - `M.update_palette_size(cols, rows)`
  - `M.update_palette_spacing(spacing)`
  - `M.restore_default_colors()`
  - `M.restore_default_sizes()`
  - `M.save()`
**Requires**: `arkitekt.core.colors`

### `ARKITEKT/scripts/ColorPalette/widgets/color_grid.lua` (143 lines)
> @noindex
**Modules**: `M, ColorGrid`
**Classes**: `ColorGrid, M`
**Exports**:
  - `M.new()` → Instance
**Requires**: `arkitekt.core.colors, arkitekt.gui.draw`

### `ARKITEKT/scripts/RegionPlaylist/app/config.lua` (349 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.get_active_container_config(callbacks)`
  - `M.get_pool_container_config(callbacks)`
  - `M.get_region_tiles_config(layout_mode)`

### `ARKITEKT/scripts/RegionPlaylist/app/controller.lua` (368 lines)
> @noindex
**Modules**: `M, Controller, keys, keys, keys_set, new_items, keys_set, keys_set`
**Classes**: `Controller, M`
**Exports**:
  - `M.new(state_module, settings, undo_manager)` → Instance
**Requires**: `RegionPlaylist.storage.state`

### `ARKITEKT/scripts/RegionPlaylist/app/sequence_expander.lua` (104 lines)
> @noindex
**Modules**: `SequenceExpander, nested_sequence, sequence`
**Exports**:
  - `SequenceExpander.expand_playlist(playlist, get_playlist_by_id)`
  - `SequenceExpander.debug_print_sequence(sequence, get_region_by_rid)`

### `ARKITEKT/scripts/RegionPlaylist/app/shortcuts.lua` (81 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.handle_keyboard_shortcuts(ctx, state, region_tiles)`
**Requires**: `RegionPlaylist.app.state`

### `ARKITEKT/scripts/RegionPlaylist/app/state.lua` (631 lines)
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
**Requires**: `RegionPlaylist.storage.state, RegionPlaylist.storage.persistence, arkitekt.core.undo_manager, RegionPlaylist.storage.undo_bridge, arkitekt.core.colors, arkitekt.core.events, RegionPlaylist.playlists.sequencer, RegionPlaylist.playback.coordinator`

### `ARKITEKT/scripts/RegionPlaylist/app/status.lua` (59 lines)
> @noindex
**Modules**: `M`
**Classes**: `M`
**Exports**:
  - `M.create(State, Style)` → Instance
**Requires**: `arkitekt.app.chrome.status_bar.widget`

### `ARKITEKT/scripts/RegionPlaylist/components/modal_manager.lua` (214 lines)
**Modules**: `ModalManager, tab_items, selected_ids`
**Classes**: `ModalManager`
**Exports**:
  - `ModalManager.new(deps)` → Instance
**Private**: 5 helpers
**Requires**: `arkitekt.gui.widgets.chip_list.list, arkitekt.gui.widgets.overlay.sheet, RegionPlaylist.core.state`

### `ARKITEKT/scripts/RegionPlaylist/components/separator_manager.lua` (106 lines)
**Modules**: `SeparatorManager`
**Classes**: `SeparatorManager`
**Exports**:
  - `SeparatorManager.new(deps)` → Instance

### `ARKITEKT/scripts/RegionPlaylist/components/tiles/active.lua` (206 lines)
**Modules**: `M`
**Exports**:
  - `M.render_region(ctx, dl, rect, region, opts)`
  - `M.render_playlist(ctx, dl, rect, playlist, opts)`
**Private**: 5 helpers
**Requires**: `RegionPlaylist.components.tiles.base, RegionPlaylist.components.tiles.config`

### `ARKITEKT/scripts/RegionPlaylist/components/tiles/base.lua` (252 lines)
**Modules**: `M, commands, commands, commands`
**Exports**:
  - `M.draw_tile_background(dl, rect, color, state)`
  - `M.draw_text_with_truncation(ctx, dl, text, bounds)`
  - `M.draw_repeat_badge(ctx, dl, rect, reps, enabled)`
  - `M.calculate_responsive_elements(tile_height)`
**Private**: 5 helpers
**Requires**: `RegionPlaylist.components.tiles.config`

### `ARKITEKT/scripts/RegionPlaylist/components/tiles/pool.lua` (214 lines)
**Modules**: `M`
**Exports**:
  - `M.render_region(ctx, dl, rect, region, opts)`
  - `M.render_playlist(ctx, dl, rect, playlist, opts)`
**Private**: 5 helpers
**Requires**: `RegionPlaylist.components.tiles.base, RegionPlaylist.components.tiles.config`

### `ARKITEKT/scripts/RegionPlaylist/core/colors.lua` (21 lines)
**Modules**: `M`
**Exports**:
  - `M.generate_chip_color(random_fn)`
**Requires**: `arkitekt.core.colors`

### `ARKITEKT/scripts/RegionPlaylist/core/keys.lua` (21 lines)
**Modules**: `Keys`
**Exports**:
  - `Keys.generate_item_key(kind, id)`

### `ARKITEKT/scripts/RegionPlaylist/core/state.lua` (133 lines)
**Modules**: `State, instances, t, out, Instance, t, snapshot`
**Classes**: `Instance`
**Exports**:
  - `State.for_project(project_id)`
**Private**: 4 helpers

### `ARKITEKT/scripts/RegionPlaylist/engine/coordinator_bridge.lua` (310 lines)
> @noindex
**Modules**: `M, sequence, regions`
**Classes**: `M`
**Exports**:
  - `M.create(opts)` → Instance
**Requires**: `RegionPlaylist.engine.core, RegionPlaylist.engine.playback, RegionPlaylist.storage.state, RegionPlaylist.core.state, RegionPlaylist.app.sequence_expander`

### `ARKITEKT/scripts/RegionPlaylist/engine/core.lua` (194 lines)
> @noindex
**Modules**: `M, Engine, order`
**Classes**: `Engine, M`
**Exports**:
  - `M.new(opts)` → Instance
**Requires**: `RegionPlaylist.engine.state, RegionPlaylist.engine.transport, RegionPlaylist.engine.transitions, RegionPlaylist.engine.quantize`

### `ARKITEKT/scripts/RegionPlaylist/engine/playback.lua` (103 lines)
> @noindex
**Modules**: `M, Playback`
**Classes**: `Playback, M`
**Exports**:
  - `M.new(engine, opts)` → Instance
**Requires**: `arkitekt.reaper.transport`

### `ARKITEKT/scripts/RegionPlaylist/engine/quantize.lua` (337 lines)
> @noindex
**Modules**: `M, Quantize`
**Classes**: `Quantize, M`
**Exports**:
  - `M.new(opts)` → Instance

### `ARKITEKT/scripts/RegionPlaylist/engine/state.lua` (324 lines)
> @noindex
**Modules**: `M, State, sequence_copy, sequence`
**Classes**: `State, M`
**Exports**:
  - `M.new(opts)` → Instance
**Requires**: `arkitekt.reaper.regions, arkitekt.reaper.transport`

### `ARKITEKT/scripts/RegionPlaylist/engine/transitions.lua` (211 lines)
> @noindex
**Modules**: `M, Transitions`
**Classes**: `Transitions, M`
**Exports**:
  - `M.new(opts)` → Instance

### `ARKITEKT/scripts/RegionPlaylist/engine/transport.lua` (239 lines)
> @noindex
**Modules**: `M, Transport`
**Classes**: `Transport, M`
**Exports**:
  - `M.new(opts)` → Instance

### `ARKITEKT/scripts/RegionPlaylist/playback/coordinator.lua` (422 lines)
> @noindex
**Modules**: `Coordinator, cache, M`
**Classes**: `Coordinator, M`
**Exports**:
  - `Coordinator.new(opts)` → Instance
  - `M.new(opts)` → Instance
**Private**: 6 helpers
**Requires**: `RegionPlaylist.engine.core, RegionPlaylist.engine.playback, RegionPlaylist.storage.state, arkitekt.core.events`

### `ARKITEKT/scripts/RegionPlaylist/playlists/manager.lua` (37 lines)
**Classes**: `M`
**Exports**:
  - `M.new(state)` → Instance
**Requires**: `arkitekt.patterns.controller`

### `ARKITEKT/scripts/RegionPlaylist/playlists/sequencer.lua` (123 lines)
**Modules**: `Sequencer, sequence, lookup, M`
**Classes**: `Sequencer, M`
**Exports**:
  - `Sequencer.new(opts)` → Instance
  - `M.new(opts)` → Instance
**Requires**: `RegionPlaylist.app.sequence_expander, RegionPlaylist.core.state`

### `ARKITEKT/scripts/RegionPlaylist/storage/migration.lua` (9 lines)
**Modules**: `M`
**Exports**:
  - `M.migrate_playlists(data)`

### `ARKITEKT/scripts/RegionPlaylist/storage/persistence.lua` (75 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.save_playlists(playlists, proj)`
  - `M.load_playlists(proj)`
  - `M.save_active_playlist(playlist_id, proj)`
  - `M.load_active_playlist(proj)`
**Requires**: `arkitekt.core.json`

### `ARKITEKT/scripts/RegionPlaylist/storage/settings.lua` (24 lines)
**Modules**: `M`
**Exports**:
  - `M.get_default()`
  - `M.save(settings, proj)`
  - `M.load(proj)`
**Requires**: `arkitekt.core.json`

### `ARKITEKT/scripts/RegionPlaylist/storage/state.lua` (152 lines)
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
**Requires**: `arkitekt.core.json, arkitekt.core.colors`

### `ARKITEKT/scripts/RegionPlaylist/storage/undo_bridge.lua` (91 lines)
> @noindex
**Modules**: `M, restored_playlists`
**Exports**:
  - `M.capture_snapshot(playlists, active_playlist_id)`
  - `M.restore_snapshot(snapshot, region_index)`
  - `M.should_capture(old_playlists, new_playlists)`

### `ARKITEKT/scripts/RegionPlaylist/views/active_panel.lua` (71 lines)
**Modules**: `ActivePanel, filtered`
**Classes**: `ActivePanel`
**Exports**:
  - `ActivePanel.new(deps)` → Instance

### `ARKITEKT/scripts/RegionPlaylist/views/main.lua` (554 lines)
**Modules**: `M, bundle`
**Classes**: `M`
**Exports**:
  - `M.new(arg1, coordinator, events, extras)` → Instance
**Private**: 8 helpers
**Requires**: `RegionPlaylist.widgets.region_tiles.coordinator, RegionPlaylist.app.controller, RegionPlaylist.app.config, RegionPlaylist.views.transport_bar, RegionPlaylist.views.active_panel, RegionPlaylist.views.pool_panel, RegionPlaylist.views.status_bar, RegionPlaylist.components.modal_manager, RegionPlaylist.components.separator_manager, RegionPlaylist.app.shortcuts, RegionPlaylist.core.state`

### `ARKITEKT/scripts/RegionPlaylist/views/pool_panel.lua` (46 lines)
**Modules**: `PoolPanel`
**Classes**: `PoolPanel`
**Exports**:
  - `PoolPanel.new(deps)` → Instance

### `ARKITEKT/scripts/RegionPlaylist/views/status_bar.lua` (16 lines)
**Modules**: `M`
**Classes**: `M`
**Exports**:
  - `M.new(deps)` → Instance

### `ARKITEKT/scripts/RegionPlaylist/views/transport_bar.lua` (308 lines)
**Modules**: `TransportBar`
**Classes**: `TransportBar`
**Exports**:
  - `TransportBar.new(deps)` → Instance
**Requires**: `arkitekt.core.colors, arkitekt.gui.fx.tile_motion, arkitekt.gui.widgets.transport.transport_container`

### `ARKITEKT/scripts/RegionPlaylist/widgets/controls/controls_widget.lua` (151 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.draw_transport_controls(ctx, bridge, x, y)`
  - `M.draw_quantize_selector(ctx, bridge, x, y, width)`
  - `M.draw_playback_info(ctx, bridge, x, y, width)`
  - `M.draw_complete_controls(ctx, bridge, x, y, available_width)`

### `ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/active_grid_factory.lua` (220 lines)
> @noindex
**Modules**: `M, item_map, items_by_key, dragged_items, items_by_key, new_items`
**Classes**: `M`
**Exports**:
  - `M.create(rt, config)` → Instance
**Private**: 6 helpers
**Requires**: `arkitekt.gui.widgets.grid.core, RegionPlaylist.widgets.region_tiles.renderers.active`

### `ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/coordinator.lua` (557 lines)
> @noindex
**Modules**: `M, RegionTiles, playlist_cache, spawned_keys, payload, colors`
**Classes**: `RegionTiles, M`
**Exports**:
  - `M.create(opts)` → Instance
**Private**: 8 helpers
**Requires**: `RegionPlaylist.app.config, RegionPlaylist.widgets.region_tiles.coordinator_render, arkitekt.gui.draw, arkitekt.core.colors, arkitekt.gui.fx.tile_motion, arkitekt.gui.systems.height_stabilizer, RegionPlaylist.widgets.region_tiles.selector, RegionPlaylist.widgets.region_tiles.active_grid_factory, RegionPlaylist.widgets.region_tiles.pool_grid_factory, arkitekt.gui.widgets.grid.grid_bridge, arkitekt.gui.widgets.panel, arkitekt.gui.widgets.panel.config, RegionPlaylist.app.state, RegionPlaylist.core.state`

### `ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/coordinator_render.lua` (190 lines)
> @noindex
**Modules**: `M, keys_to_adjust`
**Exports**:
  - `M.draw_selector(self, ctx, playlists, active_id, height)`
  - `M.draw_active(self, ctx, playlist, height)`
  - `M.draw_pool(self, ctx, regions, height)`
  - `M.draw_ghosts(self, ctx)`
**Requires**: `arkitekt.gui.fx.dnd.drag_indicator, RegionPlaylist.widgets.region_tiles.renderers.active, RegionPlaylist.widgets.region_tiles.renderers.pool, arkitekt.gui.systems.responsive_grid`

### `ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/pool_grid_factory.lua` (193 lines)
> @noindex
**Modules**: `M, items_by_key, filtered_keys, rids, rids, items_by_key`
**Classes**: `M`
**Exports**:
  - `M.create(rt, config)` → Instance
**Private**: 5 helpers
**Requires**: `arkitekt.gui.widgets.grid.core, RegionPlaylist.widgets.region_tiles.renderers.pool`

### `ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/renderers/active.lua` (186 lines)
> @noindex
**Modules**: `M, right_elements, right_elements`
**Exports**:
  - `M.render(ctx, rect, item, state, get_region_by_rid, animator, on_repeat_cycle, hover_config, tile_height, border_thickness, bridge, get_playlist_by_id)`
  - `M.render_region(ctx, rect, item, state, get_region_by_rid, animator, on_repeat_cycle, hover_config, tile_height, border_thickness, bridge)`
  - `M.render_playlist(ctx, rect, item, state, animator, on_repeat_cycle, hover_config, tile_height, border_thickness, get_playlist_by_id)`
**Requires**: `arkitekt.core.colors, arkitekt.gui.draw, arkitekt.gui.fx.tile_fx_config, RegionPlaylist.widgets.region_tiles.renderers.base, arkitekt.gui.systems.playback_manager`

### `ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/renderers/base.lua` (207 lines)
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
**Requires**: `arkitekt.gui.draw, arkitekt.core.colors, arkitekt.gui.fx.tile_fx, arkitekt.gui.fx.tile_fx_config, arkitekt.gui.fx.marching_ants, arkitekt.gui.systems.tile_utilities, arkitekt.gui.widgets.component.chip`

### `ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/renderers/pool.lua` (180 lines)
> @noindex
**Modules**: `M, right_elements, right_elements`
**Exports**:
  - `M.render(ctx, rect, item, state, animator, hover_config, tile_height, border_thickness)`
  - `M.render_region(ctx, rect, region, state, animator, hover_config, tile_height, border_thickness)`
  - `M.render_playlist(ctx, rect, playlist, state, animator, hover_config, tile_height, border_thickness)`
**Requires**: `arkitekt.core.colors, arkitekt.gui.draw, arkitekt.gui.fx.tile_fx_config, arkitekt.gui.systems.tile_utilities, RegionPlaylist.widgets.region_tiles.renderers.base`

### `ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/selector.lua` (98 lines)
> @noindex
**Modules**: `M, Selector`
**Classes**: `Selector, M`
**Exports**:
  - `M.new(config)` → Instance
**Requires**: `arkitekt.gui.draw, arkitekt.core.colors, arkitekt.gui.fx.tile_motion`

### `ARKITEKT/scripts/demos/demo.lua` (383 lines)
> @noindex
**Modules**: `result, conflicts, asset_providers`
**Private**: 8 helpers
**Requires**: `arkitekt.app.shell, arkitekt.gui.widgets.package_tiles.grid, arkitekt.gui.widgets.package_tiles.micromanage, arkitekt.gui.widgets.panel, arkitekt.gui.widgets.selection_rectangle`

### `ARKITEKT/scripts/demos/demo3.lua` (148 lines)
> @noindex
**Modules**: `pads`
**Private**: 6 helpers
**Requires**: `arkitekt.app.shell, arkitekt.gui.widgets.displays.status_pad, arkitekt.app.chrome.status_bar.widget`

### `ARKITEKT/scripts/demos/demo_modal_overlay.lua` (451 lines)
> @noindex
**Modules**: `selected_tag_items`
**Private**: 7 helpers
**Requires**: `arkitekt.app.shell, arkitekt.gui.widgets.overlay.sheet, arkitekt.gui.widgets.chip_list.list, arkitekt.gui.widgets.overlay.config`

### `ARKITEKT/scripts/demos/widget_demo.lua` (250 lines)
> @noindex
**Modules**: `t, arr`
**Private**: 12 helpers
**Requires**: `arkitekt.app.shell, Arkitekt.gui.widgets.colorblocks, arkitekt.gui.draw, arkitekt.gui.fx.effects, Arkitekt.*`

## Internal Dependencies

**`ARKITEKT/arkitekt/gui/widgets/grid/core.lua`**
  → `ARKITEKT/arkitekt/gui/widgets/grid/drop_zones.lua`
  → `ARKITEKT/arkitekt/gui/fx/dnd/drag_indicator.lua`
  → `ARKITEKT/arkitekt/gui/widgets/grid/layout.lua`
  → `ARKITEKT/arkitekt/gui/widgets/grid/animation.lua`
  → `ARKITEKT/arkitekt/gui/widgets/grid/input.lua`
  → `ARKITEKT/arkitekt/gui/widgets/selection_rectangle.lua`
  → `ARKITEKT/arkitekt/gui/widgets/grid/rendering.lua`
  → `ARKITEKT/arkitekt/gui/widgets/grid/dnd_state.lua`
  → `ARKITEKT/arkitekt/gui/draw.lua`
  → `ARKITEKT/arkitekt/gui/fx/dnd/drop_indicator.lua`
  → `ARKITEKT/arkitekt/gui/fx/animation/rect_track.lua`
  → `ARKITEKT/arkitekt/core/colors.lua`
  → `ARKITEKT/arkitekt/gui/systems/selection.lua`

**`ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/coordinator.lua`**
  → `ARKITEKT/scripts/RegionPlaylist/app/config.lua`
  → `ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/selector.lua`
  → `ARKITEKT/arkitekt/gui/fx/tile_motion.lua`
  → `ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/active_grid_factory.lua`
  → `ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/coordinator_render.lua`
  → `ARKITEKT/arkitekt/gui/widgets/grid/grid_bridge.lua`
  → `ARKITEKT/arkitekt/gui/draw.lua`
  → `ARKITEKT/scripts/RegionPlaylist/app/state.lua`
  → `ARKITEKT/arkitekt/gui/widgets/panel/config.lua`
  → `ARKITEKT/scripts/RegionPlaylist/core/state.lua`
  → `ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/pool_grid_factory.lua`
  → `ARKITEKT/arkitekt/gui/systems/height_stabilizer.lua`
  → `ARKITEKT/arkitekt/core/colors.lua`

**`ARKITEKT/scripts/RegionPlaylist/views/main.lua`**
  → `ARKITEKT/scripts/RegionPlaylist/views/transport_bar.lua`
  → `ARKITEKT/scripts/RegionPlaylist/app/controller.lua`
  → `ARKITEKT/scripts/RegionPlaylist/components/separator_manager.lua`
  → `ARKITEKT/scripts/RegionPlaylist/app/config.lua`
  → `ARKITEKT/scripts/RegionPlaylist/core/state.lua`
  → `ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/coordinator.lua`
  → `ARKITEKT/scripts/RegionPlaylist/views/status_bar.lua`
  → `ARKITEKT/scripts/RegionPlaylist/views/active_panel.lua`
  → `ARKITEKT/scripts/RegionPlaylist/app/shortcuts.lua`
  → `ARKITEKT/scripts/RegionPlaylist/components/modal_manager.lua`
  → `ARKITEKT/scripts/RegionPlaylist/views/pool_panel.lua`

**`ARKITEKT/scripts/RegionPlaylist/ARK_RegionPlaylist.lua`**
  → `ARKITEKT/arkitekt/app/shell.lua`
  → `ARKITEKT/scripts/RegionPlaylist/app/config.lua`
  → `ARKITEKT/scripts/RegionPlaylist/core/state.lua`
  → `ARKITEKT/scripts/RegionPlaylist/app/state.lua`
  → `ARKITEKT/arkitekt/core/events.lua`
  → `ARKITEKT/scripts/RegionPlaylist/views/main.lua`
  → `ARKITEKT/scripts/RegionPlaylist/playlists/sequencer.lua`
  → `ARKITEKT/scripts/RegionPlaylist/playback/coordinator.lua`
  → `ARKITEKT/scripts/RegionPlaylist/app/status.lua`
  → `ARKITEKT/arkitekt/core/colors.lua`

**`ARKITEKT/scripts/RegionPlaylist/app/state.lua`**
  → `ARKITEKT/scripts/RegionPlaylist/storage/state.lua`
  → `ARKITEKT/scripts/RegionPlaylist/playlists/sequencer.lua`
  → `ARKITEKT/arkitekt/core/events.lua`
  → `ARKITEKT/scripts/RegionPlaylist/storage/undo_bridge.lua`
  → `ARKITEKT/arkitekt/core/undo_manager.lua`
  → `ARKITEKT/scripts/RegionPlaylist/playback/coordinator.lua`
  → `ARKITEKT/scripts/RegionPlaylist/storage/persistence.lua`
  → `ARKITEKT/arkitekt/core/colors.lua`

**`ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/renderers/base.lua`**
  → `ARKITEKT/arkitekt/gui/widgets/component/chip.lua`
  → `ARKITEKT/arkitekt/gui/draw.lua`
  → `ARKITEKT/arkitekt/gui/fx/tile_fx.lua`
  → `ARKITEKT/arkitekt/gui/systems/tile_utilities.lua`
  → `ARKITEKT/arkitekt/gui/fx/marching_ants.lua`
  → `ARKITEKT/arkitekt/gui/fx/tile_fx_config.lua`
  → `ARKITEKT/arkitekt/core/colors.lua`

**`ARKITEKT/arkitekt/gui/widgets/package_tiles/grid.lua`**
  → `ARKITEKT/arkitekt/gui/systems/height_stabilizer.lua`
  → `ARKITEKT/arkitekt/gui/fx/tile_motion.lua`
  → `ARKITEKT/arkitekt/gui/widgets/package_tiles/renderer.lua`
  → `ARKITEKT/arkitekt/gui/widgets/package_tiles/micromanage.lua`
  → `ARKITEKT/arkitekt/gui/widgets/grid/core.lua`
  → `ARKITEKT/arkitekt/core/colors.lua`

**`ARKITEKT/ARKITEKT.lua`**
  → `ARKITEKT/arkitekt/app/shell.lua`
  → `ARKITEKT/arkitekt/gui/widgets/selection_rectangle.lua`
  → `ARKITEKT/arkitekt/gui/widgets/package_tiles/grid.lua`
  → `ARKITEKT/arkitekt/app/hub.lua`
  → `ARKITEKT/arkitekt/gui/widgets/package_tiles/micromanage.lua`

**`ARKITEKT/arkitekt/gui/widgets/panel/header/layout.lua`**
  → `ARKITEKT/arkitekt/gui/widgets/panel/header/separator.lua`
  → `ARKITEKT/arkitekt/gui/widgets/panel/header/dropdown_field.lua`
  → `ARKITEKT/arkitekt/gui/widgets/panel/header/tab_strip.lua`
  → `ARKITEKT/arkitekt/gui/widgets/panel/header/button.lua`
  → `ARKITEKT/arkitekt/gui/widgets/panel/header/search_field.lua`

**`ARKITEKT/arkitekt/gui/widgets/panel/init.lua`**
  → `ARKITEKT/arkitekt/gui/widgets/panel/tab_animator.lua`
  → `ARKITEKT/arkitekt/gui/widgets/panel/background.lua`
  → `ARKITEKT/arkitekt/gui/widgets/panel/content.lua`
  → `ARKITEKT/arkitekt/gui/widgets/panel/config.lua`
  → `ARKITEKT/arkitekt/gui/widgets/controls/scrollbar.lua`

**`ARKITEKT/scripts/ColorPalette/app/gui.lua`**
  → `ARKITEKT/scripts/ColorPalette/widgets/color_grid.lua`
  → `ARKITEKT/scripts/ColorPalette/app/controller.lua`
  → `ARKITEKT/arkitekt/gui/draw.lua`
  → `ARKITEKT/arkitekt/core/colors.lua`
  → `ARKITEKT/arkitekt/gui/widgets/overlay/sheet.lua`

**`ARKITEKT/scripts/ColorPalette/ARK_ColorPalette.lua`**
  → `ARKITEKT/arkitekt/app/shell.lua`
  → `ARKITEKT/arkitekt/core/settings.lua`
  → `ARKITEKT/arkitekt/gui/widgets/overlay/manager.lua`
  → `ARKITEKT/scripts/ColorPalette/app/gui.lua`
  → `ARKITEKT/scripts/ColorPalette/app/state.lua`

**`ARKITEKT/scripts/RegionPlaylist/engine/coordinator_bridge.lua`**
  → `ARKITEKT/scripts/RegionPlaylist/storage/state.lua`
  → `ARKITEKT/scripts/RegionPlaylist/engine/playback.lua`
  → `ARKITEKT/scripts/RegionPlaylist/core/state.lua`
  → `ARKITEKT/scripts/RegionPlaylist/engine/core.lua`
  → `ARKITEKT/scripts/RegionPlaylist/app/sequence_expander.lua`

**`ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/renderers/active.lua`**
  → `ARKITEKT/arkitekt/gui/systems/playback_manager.lua`
  → `ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/renderers/base.lua`
  → `ARKITEKT/arkitekt/gui/draw.lua`
  → `ARKITEKT/arkitekt/gui/fx/tile_fx_config.lua`
  → `ARKITEKT/arkitekt/core/colors.lua`

**`ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/renderers/pool.lua`**
  → `ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/renderers/base.lua`
  → `ARKITEKT/arkitekt/gui/draw.lua`
  → `ARKITEKT/arkitekt/gui/systems/tile_utilities.lua`
  → `ARKITEKT/arkitekt/gui/fx/tile_fx_config.lua`
  → `ARKITEKT/arkitekt/core/colors.lua`

**`ARKITEKT/arkitekt/gui/widgets/component/chip.lua`**
  → `ARKITEKT/arkitekt/gui/draw.lua`
  → `ARKITEKT/arkitekt/gui/fx/tile_fx.lua`
  → `ARKITEKT/arkitekt/gui/fx/tile_fx_config.lua`
  → `ARKITEKT/arkitekt/core/colors.lua`

**`ARKITEKT/arkitekt/gui/widgets/displays/status_pad.lua`**
  → `ARKITEKT/arkitekt/gui/draw.lua`
  → `ARKITEKT/arkitekt/gui/fx/tile_fx.lua`
  → `ARKITEKT/arkitekt/gui/fx/tile_fx_config.lua`
  → `ARKITEKT/arkitekt/core/colors.lua`

**`ARKITEKT/arkitekt/gui/widgets/overlay/manager.lua`**
  → `ARKITEKT/arkitekt/gui/draw.lua`
  → `ARKITEKT/arkitekt/gui/widgets/overlay/config.lua`
  → `ARKITEKT/arkitekt/gui/style.lua`
  → `ARKITEKT/arkitekt/core/colors.lua`

**`ARKITEKT/arkitekt/gui/widgets/overlay/sheet.lua`**
  → `ARKITEKT/arkitekt/gui/draw.lua`
  → `ARKITEKT/arkitekt/gui/widgets/overlay/config.lua`
  → `ARKITEKT/arkitekt/gui/style.lua`
  → `ARKITEKT/arkitekt/core/colors.lua`

**`ARKITEKT/scripts/demos/demo.lua`**
  → `ARKITEKT/arkitekt/gui/widgets/package_tiles/micromanage.lua`
  → `ARKITEKT/arkitekt/gui/widgets/package_tiles/grid.lua`
  → `ARKITEKT/arkitekt/app/shell.lua`
  → `ARKITEKT/arkitekt/gui/widgets/selection_rectangle.lua`

**`ARKITEKT/scripts/demos/demo_modal_overlay.lua`**
  → `ARKITEKT/arkitekt/app/shell.lua`
  → `ARKITEKT/arkitekt/gui/widgets/overlay/config.lua`
  → `ARKITEKT/arkitekt/gui/widgets/chip_list/list.lua`
  → `ARKITEKT/arkitekt/gui/widgets/overlay/sheet.lua`

**`ARKITEKT/scripts/RegionPlaylist/engine/core.lua`**
  → `ARKITEKT/scripts/RegionPlaylist/engine/state.lua`
  → `ARKITEKT/scripts/RegionPlaylist/engine/transitions.lua`
  → `ARKITEKT/scripts/RegionPlaylist/engine/quantize.lua`
  → `ARKITEKT/scripts/RegionPlaylist/engine/transport.lua`

**`ARKITEKT/scripts/RegionPlaylist/playback/coordinator.lua`**
  → `ARKITEKT/scripts/RegionPlaylist/engine/playback.lua`
  → `ARKITEKT/scripts/RegionPlaylist/storage/state.lua`
  → `ARKITEKT/arkitekt/core/events.lua`
  → `ARKITEKT/scripts/RegionPlaylist/engine/core.lua`

**`ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/coordinator_render.lua`**
  → `ARKITEKT/arkitekt/gui/systems/responsive_grid.lua`
  → `ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/renderers/active.lua`
  → `ARKITEKT/arkitekt/gui/fx/dnd/drag_indicator.lua`
  → `ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/renderers/pool.lua`

**`ARKITEKT/arkitekt/gui/fx/dnd/drag_indicator.lua`**
  → `ARKITEKT/arkitekt/gui/draw.lua`
  → `ARKITEKT/arkitekt/gui/fx/dnd/config.lua`
  → `ARKITEKT/arkitekt/core/colors.lua`

**`ARKITEKT/arkitekt/gui/widgets/grid/rendering.lua`**
  → `ARKITEKT/arkitekt/gui/draw.lua`
  → `ARKITEKT/arkitekt/gui/fx/marching_ants.lua`
  → `ARKITEKT/arkitekt/core/colors.lua`

**`ARKITEKT/arkitekt/gui/widgets/package_tiles/renderer.lua`**
  → `ARKITEKT/arkitekt/gui/draw.lua`
  → `ARKITEKT/arkitekt/gui/fx/marching_ants.lua`
  → `ARKITEKT/arkitekt/core/colors.lua`

**`ARKITEKT/scripts/demos/widget_demo.lua`**
  → `ARKITEKT/arkitekt/gui/draw.lua`
  → `ARKITEKT/arkitekt/app/shell.lua`
  → `ARKITEKT/arkitekt/gui/fx/effects.lua`

**`ARKITEKT/scripts/RegionPlaylist/components/modal_manager.lua`**
  → `ARKITEKT/scripts/RegionPlaylist/core/state.lua`
  → `ARKITEKT/arkitekt/gui/widgets/chip_list/list.lua`
  → `ARKITEKT/arkitekt/gui/widgets/overlay/sheet.lua`

**`ARKITEKT/scripts/RegionPlaylist/views/transport_bar.lua`**
  → `ARKITEKT/arkitekt/gui/widgets/transport/transport_container.lua`
  → `ARKITEKT/arkitekt/gui/fx/tile_motion.lua`
  → `ARKITEKT/arkitekt/core/colors.lua`

**`ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/selector.lua`**
  → `ARKITEKT/arkitekt/gui/draw.lua`
  → `ARKITEKT/arkitekt/gui/fx/tile_motion.lua`
  → `ARKITEKT/arkitekt/core/colors.lua`

**`ARKITEKT/arkitekt/app/chrome/status_bar/widget.lua`**
  → `ARKITEKT/arkitekt/app/chrome/status_bar/config.lua`
  → `ARKITEKT/arkitekt/gui/widgets/component/chip.lua`

**`ARKITEKT/arkitekt/app/shell.lua`**
  → `ARKITEKT/arkitekt/app/runtime.lua`
  → `ARKITEKT/arkitekt/app/window.lua`

**`ARKITEKT/arkitekt/gui/widgets/chip_list/list.lua`**
  → `ARKITEKT/arkitekt/gui/widgets/component/chip.lua`
  → `ARKITEKT/arkitekt/gui/systems/responsive_grid.lua`

**`ARKITEKT/arkitekt/gui/widgets/grid/animation.lua`**
  → `ARKITEKT/arkitekt/gui/fx/animations/destroy.lua`
  → `ARKITEKT/arkitekt/gui/fx/animations/spawn.lua`

**`ARKITEKT/arkitekt/gui/widgets/panel/header/tab_strip.lua`**
  → `ARKITEKT/arkitekt/gui/widgets/controls/context_menu.lua`
  → `ARKITEKT/arkitekt/gui/widgets/component/chip.lua`

**`ARKITEKT/scripts/ColorPalette/widgets/color_grid.lua`**
  → `ARKITEKT/arkitekt/gui/draw.lua`
  → `ARKITEKT/arkitekt/core/colors.lua`

**`ARKITEKT/scripts/demos/demo2.lua`**
  → `ARKITEKT/arkitekt/app/shell.lua`
  → `ARKITEKT/arkitekt/gui/widgets/sliders/hue.lua`

**`ARKITEKT/scripts/demos/demo3.lua`**
  → `ARKITEKT/arkitekt/gui/widgets/displays/status_pad.lua`
  → `ARKITEKT/arkitekt/app/shell.lua`

**`ARKITEKT/scripts/RegionPlaylist/components/tiles/active.lua`**
  → `ARKITEKT/scripts/RegionPlaylist/components/tiles/base.lua`
  → `ARKITEKT/scripts/RegionPlaylist/components/tiles/config.lua`

**`ARKITEKT/scripts/RegionPlaylist/components/tiles/pool.lua`**
  → `ARKITEKT/scripts/RegionPlaylist/components/tiles/base.lua`
  → `ARKITEKT/scripts/RegionPlaylist/components/tiles/config.lua`

**`ARKITEKT/scripts/RegionPlaylist/engine/state.lua`**
  → `ARKITEKT/arkitekt/reaper/transport.lua`
  → `ARKITEKT/arkitekt/reaper/regions.lua`

**`ARKITEKT/scripts/RegionPlaylist/playlists/sequencer.lua`**
  → `ARKITEKT/scripts/RegionPlaylist/app/sequence_expander.lua`
  → `ARKITEKT/scripts/RegionPlaylist/core/state.lua`

**`ARKITEKT/scripts/RegionPlaylist/storage/state.lua`**
  → `ARKITEKT/arkitekt/core/json.lua`
  → `ARKITEKT/arkitekt/core/colors.lua`

**`ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/active_grid_factory.lua`**
  → `ARKITEKT/arkitekt/gui/widgets/grid/core.lua`
  → `ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/renderers/active.lua`

**`ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/pool_grid_factory.lua`**
  → `ARKITEKT/arkitekt/gui/widgets/grid/core.lua`
  → `ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/renderers/pool.lua`

**`ARKITEKT/arkitekt/app/chrome/status_bar/config.lua`**
  → `ARKITEKT/arkitekt/gui/widgets/component/chip.lua`

**`ARKITEKT/arkitekt/app/chrome/status_bar/init.lua`**
  → `ARKITEKT/arkitekt/app/chrome/status_bar/widget.lua`

**`ARKITEKT/arkitekt/core/settings.lua`**
  → `ARKITEKT/arkitekt/core/json.lua`

**`ARKITEKT/arkitekt/gui/fx/animation/rect_track.lua`**
  → `ARKITEKT/arkitekt/core/math.lua`

**`ARKITEKT/arkitekt/gui/fx/animation/track.lua`**
  → `ARKITEKT/arkitekt/core/math.lua`

**`ARKITEKT/arkitekt/gui/fx/animations/destroy.lua`**
  → `ARKITEKT/arkitekt/gui/fx/easing.lua`

**`ARKITEKT/arkitekt/gui/fx/animations/spawn.lua`**
  → `ARKITEKT/arkitekt/gui/fx/easing.lua`

**`ARKITEKT/arkitekt/gui/fx/dnd/drop_indicator.lua`**
  → `ARKITEKT/arkitekt/gui/fx/dnd/config.lua`

**`ARKITEKT/arkitekt/gui/fx/marching_ants.lua`**
  → `ARKITEKT/arkitekt/gui/draw.lua`

**`ARKITEKT/arkitekt/gui/fx/tile_fx.lua`**
  → `ARKITEKT/arkitekt/core/colors.lua`

**`ARKITEKT/arkitekt/gui/fx/tile_motion.lua`**
  → `ARKITEKT/arkitekt/gui/fx/animation/track.lua`

**`ARKITEKT/arkitekt/gui/style.lua`**
  → `ARKITEKT/arkitekt/core/colors.lua`

**`ARKITEKT/arkitekt/gui/widgets/controls/dropdown.lua`**
  → `ARKITEKT/arkitekt/gui/widgets/controls/tooltip.lua`

**`ARKITEKT/arkitekt/gui/widgets/grid/input.lua`**
  → `ARKITEKT/arkitekt/gui/draw.lua`

**`ARKITEKT/arkitekt/gui/widgets/panel/header/dropdown_field.lua`**
  → `ARKITEKT/arkitekt/gui/widgets/controls/dropdown.lua`

**`ARKITEKT/arkitekt/gui/widgets/panel/header/init.lua`**
  → `ARKITEKT/arkitekt/gui/widgets/panel/header/layout.lua`

**`ARKITEKT/arkitekt/gui/widgets/panel/tab_animator.lua`**
  → `ARKITEKT/arkitekt/gui/fx/easing.lua`

**`ARKITEKT/arkitekt/gui/widgets/transport/transport_container.lua`**
  → `ARKITEKT/arkitekt/gui/widgets/transport/transport_fx.lua`

**`ARKITEKT/arkitekt/gui/widgets/transport/transport_fx.lua`**
  → `ARKITEKT/arkitekt/core/colors.lua`

**`ARKITEKT/scripts/ColorPalette/app/state.lua`**
  → `ARKITEKT/arkitekt/core/colors.lua`

**`ARKITEKT/scripts/RegionPlaylist/app/controller.lua`**
  → `ARKITEKT/scripts/RegionPlaylist/storage/state.lua`

**`ARKITEKT/scripts/RegionPlaylist/app/shortcuts.lua`**
  → `ARKITEKT/scripts/RegionPlaylist/app/state.lua`

**`ARKITEKT/scripts/RegionPlaylist/components/tiles/base.lua`**
  → `ARKITEKT/scripts/RegionPlaylist/components/tiles/config.lua`

**`ARKITEKT/scripts/RegionPlaylist/core/colors.lua`**
  → `ARKITEKT/arkitekt/core/colors.lua`

**`ARKITEKT/scripts/RegionPlaylist/engine/playback.lua`**
  → `ARKITEKT/arkitekt/reaper/transport.lua`

**`ARKITEKT/scripts/RegionPlaylist/playlists/manager.lua`**
  → `ARKITEKT/arkitekt/patterns/controller.lua`

**`ARKITEKT/scripts/RegionPlaylist/storage/persistence.lua`**
  → `ARKITEKT/arkitekt/core/json.lua`

**`ARKITEKT/scripts/RegionPlaylist/storage/settings.lua`**
  → `ARKITEKT/arkitekt/core/json.lua`

## External Dependencies
