# REARKITEKT FLOW
Generated: 2025-10-16 01:20:52

## Overview
- **Folders**: 1
- **Files**: 79
- **Total Lines**: 13,737
- **Code Lines**: 10,670
- **Exports**: 238
- **Classes**: 49

## Folder Organization

### ARKITEKT/rearkitekt
- Files: 79
- Lines: 10,670
- Exports: 238

## Orchestrators

**`ARKITEKT/rearkitekt/gui/widgets/grid/core.lua`** (13 dependencies)
  Composes: layout + rect_track + colors + selection + selection_rectangle + draw + drag_indicator + drop_indicator + rendering + animation + input + dnd_state + drop_zones

**`ARKITEKT/rearkitekt/gui/widgets/package_tiles/grid.lua`** (6 dependencies)
  Composes: core + colors + tile_motion + renderer + micromanage + height_stabilizer

**`ARKITEKT/rearkitekt/gui/widgets/panel/init.lua`** (6 dependencies)
  Composes: header + content + background + tab_animator + scrollbar + config

**`ARKITEKT/rearkitekt/gui/widgets/panel/header/layout.lua`** (5 dependencies)
  Composes: tab_strip + search_field + dropdown_field + button + separator

## Module API

### `ARKITEKT/rearkitekt/app/chrome/status_bar/config.lua` (140 lines)
> @noindex
**Modules**: `M, result`
**Exports**:
  - `M.deep_merge(base, override)`
  - `M.merge(user_config, preset_name)`
**Requires**: `rearkitekt.gui.widgets.component.chip`

### `ARKITEKT/rearkitekt/app/chrome/status_bar/widget.lua` (319 lines)
> @noindex
**Modules**: `M, right_items`
**Classes**: `M`
**Exports**:
  - `M.new(config)` → Instance
**Private**: 6 helpers
**Requires**: `rearkitekt.gui.widgets.component.chip, rearkitekt.app.chrome.status_bar.config`

### `ARKITEKT/rearkitekt/app/config.lua` (95 lines)
> @noindex
**Modules**: `M, keys`
**Exports**:
  - `M.get_defaults()`
  - `M.get(path)`

### `ARKITEKT/rearkitekt/app/hub.lua` (93 lines)
> @noindex
**Modules**: `M, apps`
**Exports**:
  - `M.launch_app(app_path)`
  - `M.render_hub(ctx, opts)`

### `ARKITEKT/rearkitekt/app/icon.lua` (124 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.draw_rearkitekt(ctx, x, y, size, color)`
  - `M.draw_rearkitekt_v2(ctx, x, y, size, color)`
  - `M.draw_simple_a(ctx, x, y, size, color)`

### `ARKITEKT/rearkitekt/app/runtime.lua` (69 lines)
> @noindex
**Modules**: `M`
**Classes**: `M`
**Exports**:
  - `M.new(opts)` → Instance

### `ARKITEKT/rearkitekt/app/shell.lua` (289 lines)
> @noindex
**Modules**: `M, DEFAULTS`
**Exports**:
  - `M.run(opts)`
**Private**: 4 helpers
**Requires**: `rearkitekt.app.runtime, rearkitekt.app.window`

### `ARKITEKT/rearkitekt/app/titlebar.lua` (507 lines)
> @noindex
**Modules**: `M, DEFAULTS`
**Classes**: `M`
**Exports**:
  - `M.new(opts)` → Instance

### `ARKITEKT/rearkitekt/app/window.lua` (481 lines)
> @noindex
**Modules**: `M, DEFAULTS`
**Classes**: `M`
**Exports**:
  - `M.new(opts)` → Instance

### `ARKITEKT/rearkitekt/core/colors.lua` (550 lines)
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

### `ARKITEKT/rearkitekt/core/json.lua` (121 lines)
> @noindex
**Modules**: `M, out, obj, arr`
**Exports**:
  - `M.encode(t)`
  - `M.decode(str)`
**Private**: 5 helpers

### `ARKITEKT/rearkitekt/core/lifecycle.lua` (81 lines)
> @noindex
**Modules**: `M, Group`
**Classes**: `Group, M`
**Exports**:
  - `M.new()` → Instance

### `ARKITEKT/rearkitekt/core/math.lua` (52 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.lerp(a, b, t)`
  - `M.clamp(value, min, max)`
  - `M.remap(value, in_min, in_max, out_min, out_max)`
  - `M.snap(value, step)`
  - `M.smoothdamp(current, target, velocity, smoothtime, maxspeed, dt)`
  - `M.approximately(a, b, epsilon)`

### `ARKITEKT/rearkitekt/core/settings.lua` (119 lines)
> @noindex
**Modules**: `Settings, out, M, t`
**Classes**: `Settings`
**Exports**:
  - `M.open(cache_dir, filename)`
**Private**: 7 helpers
**Requires**: `rearkitekt.core.json`

### `ARKITEKT/rearkitekt/core/undo_manager.lua` (70 lines)
> @noindex
**Modules**: `M`
**Classes**: `M`
**Exports**:
  - `M.new(opts)` → Instance

### `ARKITEKT/rearkitekt/gui/draw.lua` (114 lines)
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

### `ARKITEKT/rearkitekt/gui/fx/animation/rect_track.lua` (136 lines)
> @noindex
**Modules**: `M, RectTrack`
**Classes**: `RectTrack, M`
**Exports**:
  - `M.new(speed, snap_epsilon, magnetic_threshold, magnetic_multiplier)` → Instance
**Requires**: `rearkitekt.core.math`

### `ARKITEKT/rearkitekt/gui/fx/animation/track.lua` (53 lines)
> @noindex
**Modules**: `M, Track`
**Classes**: `Track, M`
**Exports**:
  - `M.new(initial_value, speed)` → Instance
**Requires**: `rearkitekt.core.math`

### `ARKITEKT/rearkitekt/gui/fx/animations/destroy.lua` (149 lines)
> @noindex
**Modules**: `M, DestroyAnim, completed`
**Classes**: `DestroyAnim, M`
**Exports**:
  - `M.new(opts)` → Instance
**Requires**: `rearkitekt.gui.fx.easing`

### `ARKITEKT/rearkitekt/gui/fx/animations/spawn.lua` (58 lines)
> @noindex
**Modules**: `M, SpawnTracker`
**Classes**: `SpawnTracker, M`
**Exports**:
  - `M.new(config)` → Instance
**Requires**: `rearkitekt.gui.fx.easing`

### `ARKITEKT/rearkitekt/gui/fx/dnd/config.lua` (91 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.get_mode_config(config, is_copy, is_delete)`

### `ARKITEKT/rearkitekt/gui/fx/dnd/drag_indicator.lua` (219 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.draw_badge(ctx, dl, mx, my, count, config, is_copy_mode, is_delete_mode)`
  - `M.draw(ctx, dl, mx, my, count, config, colors, is_copy_mode, is_delete_mode)`
**Private**: 5 helpers
**Requires**: `rearkitekt.gui.draw, rearkitekt.core.colors, rearkitekt.gui.fx.dnd.config`

### `ARKITEKT/rearkitekt/gui/fx/dnd/drop_indicator.lua` (113 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.draw_vertical(ctx, dl, x, y1, y2, config, is_copy_mode)`
  - `M.draw_horizontal(ctx, dl, x1, x2, y, config, is_copy_mode)`
  - `M.draw(ctx, dl, config, is_copy_mode, orientation, ...)`
**Requires**: `rearkitekt.gui.fx.dnd.config`

### `ARKITEKT/rearkitekt/gui/fx/easing.lua` (94 lines)
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

### `ARKITEKT/rearkitekt/gui/fx/effects.lua` (54 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.hover_shadow(dl, x1, y1, x2, y2, strength, radius)`
  - `M.soft_glow(dl, x1, y1, x2, y2, color, intensity, radius)`
  - `M.pulse_glow(dl, x1, y1, x2, y2, color, time, speed, radius)`

### `ARKITEKT/rearkitekt/gui/fx/marching_ants.lua` (100 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.draw(dl, x1, y1, x2, y2, color, thickness, radius, dash, gap, speed_px)`
**Requires**: `rearkitekt.gui.draw`

### `ARKITEKT/rearkitekt/gui/fx/tile_fx.lua` (170 lines)
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
**Requires**: `rearkitekt.core.colors`

### `ARKITEKT/rearkitekt/gui/fx/tile_fx_config.lua` (79 lines)
> @noindex
**Modules**: `M, config`
**Exports**:
  - `M.get()`
  - `M.override(overrides)`

### `ARKITEKT/rearkitekt/gui/fx/tile_motion.lua` (58 lines)
> @noindex
**Modules**: `M, TileAnimator`
**Classes**: `TileAnimator, M`
**Exports**:
  - `M.new(default_speed)` → Instance
**Requires**: `rearkitekt.gui.fx.animation.track`

### `ARKITEKT/rearkitekt/gui/images.lua` (285 lines)
> @noindex
**Modules**: `M, Cache`
**Classes**: `Cache, M`
**Exports**:
  - `M.new(opts)` → Instance
**Private**: 9 helpers

### `ARKITEKT/rearkitekt/gui/style.lua` (146 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.with_alpha(col, a)`
  - `M.PushMyStyle(ctx)`
  - `M.PopMyStyle(ctx)`
**Requires**: `rearkitekt.core.colors`

### `ARKITEKT/rearkitekt/gui/systems/height_stabilizer.lua` (74 lines)
> @noindex
**Modules**: `M, HeightStabilizer`
**Classes**: `HeightStabilizer, M`
**Exports**:
  - `M.new(opts)` → Instance

### `ARKITEKT/rearkitekt/gui/systems/playback_manager.lua` (22 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.compute_fade_alpha(progress, fade_in_ratio, fade_out_ratio)`

### `ARKITEKT/rearkitekt/gui/systems/reorder.lua` (127 lines)
> @noindex
**Modules**: `M, t, base, new_order, new_order, new_order`
**Exports**:
  - `M.insert_relative(order_keys, dragged_keys, target_key, side)`
  - `M.move_up(order_keys, selected_keys)`
  - `M.move_down(order_keys, selected_keys)`

### `ARKITEKT/rearkitekt/gui/systems/responsive_grid.lua` (228 lines)
> @noindex
**Modules**: `M, rows, current_row, layout`
**Exports**:
  - `M.calculate_scaled_gap(tile_height, base_gap, base_height, min_height, responsive_config)`
  - `M.calculate_responsive_tile_height(opts)`
  - `M.calculate_grid_metrics(opts)`
  - `M.calculate_justified_layout(items, opts)`
  - `M.should_show_scrollbar(grid_height, available_height, buffer)`
  - `M.create_default_config()` → Instance

### `ARKITEKT/rearkitekt/gui/systems/selection.lua` (142 lines)
> @noindex
**Modules**: `M, Selection, out, out`
**Classes**: `Selection, M`
**Exports**:
  - `M.new()` → Instance

### `ARKITEKT/rearkitekt/gui/systems/tile_utilities.lua` (49 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.format_bar_length(start_time, end_time, proj)`

### `ARKITEKT/rearkitekt/gui/widgets/chip_list/list.lua` (303 lines)
> @noindex
**Modules**: `M, filtered, min_widths, min_widths`
**Exports**:
  - `M.draw(ctx, items, opts)`
  - `M.draw_vertical(ctx, items, opts)`
  - `M.draw_columns(ctx, items, opts)`
  - `M.draw_grid(ctx, items, opts)`
  - `M.draw_auto(ctx, items, opts)`
**Requires**: `rearkitekt.gui.widgets.component.chip, rearkitekt.gui.systems.responsive_grid`

### `ARKITEKT/rearkitekt/gui/widgets/component/chip.lua` (333 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.calculate_width(ctx, label, opts)`
  - `M.draw(ctx, opts)`
**Private**: 4 helpers
**Requires**: `rearkitekt.gui.draw, rearkitekt.core.colors, rearkitekt.gui.fx.tile_fx, rearkitekt.gui.fx.tile_fx_config`

### `ARKITEKT/rearkitekt/gui/widgets/controls/context_menu.lua` (106 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.begin(ctx, id, config)`
  - `M.end_menu(ctx)`
  - `M.item(ctx, label, config)`
  - `M.separator(ctx, config)`

### `ARKITEKT/rearkitekt/gui/widgets/controls/dropdown.lua` (395 lines)
> @noindex
**Modules**: `M, Dropdown`
**Classes**: `Dropdown, M`
**Exports**:
  - `M.new(opts)` → Instance
**Requires**: `rearkitekt.gui.widgets.controls.tooltip`

### `ARKITEKT/rearkitekt/gui/widgets/controls/scrollbar.lua` (239 lines)
> @noindex
**Modules**: `M, Scrollbar`
**Classes**: `Scrollbar, M`
**Exports**:
  - `M.new(opts)` → Instance

### `ARKITEKT/rearkitekt/gui/widgets/controls/tooltip.lua` (129 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.show(ctx, text, config)`
  - `M.show_delayed(ctx, text, config)`
  - `M.show_at_mouse(ctx, text, config)`
  - `M.reset()`

### `ARKITEKT/rearkitekt/gui/widgets/displays/status_pad.lua` (192 lines)
> @noindex
**Modules**: `M, FontPool, StatusPad`
**Classes**: `StatusPad, M`
**Exports**:
  - `M.new(opts)` → Instance
**Private**: 4 helpers
**Requires**: `rearkitekt.gui.draw, rearkitekt.core.colors, rearkitekt.gui.fx.tile_fx, rearkitekt.gui.fx.tile_fx_config`

### `ARKITEKT/rearkitekt/gui/widgets/grid/animation.lua` (101 lines)
> @noindex
**Modules**: `M, AnimationCoordinator`
**Classes**: `AnimationCoordinator, M`
**Exports**:
  - `M.new(config)` → Instance
**Requires**: `rearkitekt.gui.fx.animations.spawn, rearkitekt.gui.fx.animations.destroy`

### `ARKITEKT/rearkitekt/gui/widgets/grid/core.lua` (569 lines)
> @noindex
**Modules**: `M, Grid, current_keys, new_keys, rect_map, rect_map, order, filtered_order, new_order`
**Classes**: `Grid, M`
**Exports**:
  - `M.new(opts)` → Instance
**Requires**: `rearkitekt.gui.widgets.grid.layout, rearkitekt.gui.fx.animation.rect_track, rearkitekt.core.colors, rearkitekt.gui.systems.selection, rearkitekt.gui.widgets.selection_rectangle, rearkitekt.gui.draw, rearkitekt.gui.fx.dnd.drag_indicator, rearkitekt.gui.fx.dnd.drop_indicator, rearkitekt.gui.widgets.grid.rendering, rearkitekt.gui.widgets.grid.animation, rearkitekt.gui.widgets.grid.input, rearkitekt.gui.widgets.grid.dnd_state, rearkitekt.gui.widgets.grid.drop_zones`

### `ARKITEKT/rearkitekt/gui/widgets/grid/dnd_state.lua` (113 lines)
> @noindex
**Modules**: `M, DnDState`
**Classes**: `DnDState, M`
**Exports**:
  - `M.new(opts)` → Instance

### `ARKITEKT/rearkitekt/gui/widgets/grid/drop_zones.lua` (277 lines)
> @noindex
**Modules**: `M, non_dragged, zones, zones, rows, sequential_items, set`
**Exports**:
  - `M.find_drop_target(mx, my, items, key_fn, dragged_set, rect_track, is_single_column, grid_bounds)`
  - `M.find_external_drop_target(mx, my, items, key_fn, rect_track, is_single_column, grid_bounds)`
  - `M.build_dragged_set(dragged_ids)`
**Private**: 5 helpers

### `ARKITEKT/rearkitekt/gui/widgets/grid/grid_bridge.lua` (219 lines)
> @noindex
**Modules**: `M, GridBridge`
**Classes**: `GridBridge, M`
**Exports**:
  - `M.new(config)` → Instance

### `ARKITEKT/rearkitekt/gui/widgets/grid/input.lua` (237 lines)
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
**Requires**: `rearkitekt.gui.draw`

### `ARKITEKT/rearkitekt/gui/widgets/grid/layout.lua` (101 lines)
> @noindex
**Modules**: `M, rects`
**Exports**:
  - `M.calculate(avail_w, min_col_w, gap, n_items, origin_x, origin_y, fixed_tile_h)`
  - `M.get_height(rows, tile_h, gap)`

### `ARKITEKT/rearkitekt/gui/widgets/grid/rendering.lua` (92 lines)
> @noindex
**Modules**: `M`
**Requires**: `rearkitekt.gui.draw, rearkitekt.core.colors, rearkitekt.gui.fx.marching_ants`

### `ARKITEKT/rearkitekt/gui/widgets/navigation/menutabs.lua` (269 lines)
> @noindex
**Modules**: `M, o, o, edges`
**Classes**: `M`
**Exports**:
  - `M.new(opts)` → Instance
**Private**: 4 helpers

### `ARKITEKT/rearkitekt/gui/widgets/overlay/config.lua` (139 lines)
> @noindex
**Modules**: `M, new_config`
**Exports**:
  - `M.get()`
  - `M.override(overrides)`
  - `M.reset()`

### `ARKITEKT/rearkitekt/gui/widgets/overlay/manager.lua` (178 lines)
> @noindex
**Modules**: `M`
**Classes**: `M`
**Exports**:
  - `M.new()` → Instance
**Requires**: `rearkitekt.gui.draw, rearkitekt.core.colors, rearkitekt.gui.style, rearkitekt.gui.widgets.overlay.config`

### `ARKITEKT/rearkitekt/gui/widgets/overlay/sheet.lua` (125 lines)
> @noindex
**Modules**: `Sheet`
**Exports**:
  - `Sheet.render(ctx, alpha, bounds, content_fn, opts)`
**Requires**: `rearkitekt.gui.draw, rearkitekt.core.colors, rearkitekt.gui.style, rearkitekt.gui.widgets.overlay.config`

### `ARKITEKT/rearkitekt/gui/widgets/package_tiles/grid.lua` (227 lines)
> @noindex
**Modules**: `M`
**Classes**: `M`
**Exports**:
  - `M.create(pkg, settings, theme)` → Instance
**Requires**: `rearkitekt.gui.widgets.grid.core, rearkitekt.core.colors, rearkitekt.gui.fx.tile_motion, rearkitekt.gui.widgets.package_tiles.renderer, rearkitekt.gui.widgets.package_tiles.micromanage, rearkitekt.gui.systems.height_stabilizer`

### `ARKITEKT/rearkitekt/gui/widgets/package_tiles/micromanage.lua` (127 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.open(pkg_id)`
  - `M.close()`
  - `M.is_open()`
  - `M.get_package_id()`
  - `M.draw_window(ctx, pkg, settings)`
  - `M.reset()`

### `ARKITEKT/rearkitekt/gui/widgets/package_tiles/renderer.lua` (267 lines)
> @noindex
**Modules**: `M`
**Requires**: `rearkitekt.gui.draw, rearkitekt.gui.fx.marching_ants, rearkitekt.core.colors`

### `ARKITEKT/rearkitekt/gui/widgets/panel/background.lua` (61 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.draw(dl, x1, y1, x2, y2, pattern_cfg)`

### `ARKITEKT/rearkitekt/gui/widgets/panel/config.lua` (257 lines)
> @noindex
**Modules**: `M`

### `ARKITEKT/rearkitekt/gui/widgets/panel/content.lua` (44 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.begin_child(ctx, id, width, height, scroll_config)`
  - `M.end_child(ctx, container)`

### `ARKITEKT/rearkitekt/gui/widgets/panel/header/button.lua` (119 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.draw(ctx, dl, x, y, width, height, config, state)`
  - `M.measure(ctx, config)`

### `ARKITEKT/rearkitekt/gui/widgets/panel/header/dropdown_field.lua` (101 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.draw(ctx, dl, x, y, width, height, config, state)`
  - `M.measure(ctx, config)`
**Requires**: `rearkitekt.gui.widgets.controls.dropdown`

### `ARKITEKT/rearkitekt/gui/widgets/panel/header/init.lua` (46 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.draw(ctx, dl, x, y, w, h, state, config, rounding)`
  - `M.draw_elements(ctx, dl, x, y, w, h, state, config)`
**Requires**: `rearkitekt.gui.widgets.panel.header.layout`

### `ARKITEKT/rearkitekt/gui/widgets/panel/header/layout.lua` (305 lines)
> @noindex
**Modules**: `M, layout, rounding_info, element_config`
**Exports**:
  - `M.draw(ctx, dl, x, y, width, height, state, config)`
**Private**: 8 helpers
**Requires**: `rearkitekt.gui.widgets.panel.header.tab_strip, rearkitekt.gui.widgets.panel.header.search_field, rearkitekt.gui.widgets.panel.header.dropdown_field, rearkitekt.gui.widgets.panel.header.button, rearkitekt.gui.widgets.panel.header.separator`

### `ARKITEKT/rearkitekt/gui/widgets/panel/header/search_field.lua` (120 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.draw(ctx, dl, x, y, width, height, config, state)`
  - `M.measure(ctx, config)`

### `ARKITEKT/rearkitekt/gui/widgets/panel/header/separator.lua` (33 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.draw(ctx, dl, x, y, width, height, config)`
  - `M.measure(ctx, config)`

### `ARKITEKT/rearkitekt/gui/widgets/panel/header/tab_strip.lua` (804 lines)
> @noindex
**Modules**: `M, visible_indices, positions`
**Exports**:
  - `M.draw(ctx, dl, x, y, available_width, height, config, state)`
  - `M.measure(ctx, config, state)`
**Private**: 12 helpers
**Requires**: `rearkitekt.gui.widgets.controls.context_menu, rearkitekt.gui.widgets.component.chip`

### `ARKITEKT/rearkitekt/gui/widgets/panel/init.lua` (416 lines)
> @noindex
**Modules**: `M, result, Panel`
**Classes**: `Panel, M`
**Exports**:
  - `M.new(opts)` → Instance
  - `M.draw(ctx, id, width, height, content_fn, config)`
**Requires**: `rearkitekt.gui.widgets.panel.header, rearkitekt.gui.widgets.panel.content, rearkitekt.gui.widgets.panel.background, rearkitekt.gui.widgets.panel.tab_animator, rearkitekt.gui.widgets.controls.scrollbar, rearkitekt.gui.widgets.panel.config`

### `ARKITEKT/rearkitekt/gui/widgets/panel/tab_animator.lua` (107 lines)
> @noindex
**Modules**: `M, TabAnimator, spawn_complete, destroy_complete`
**Classes**: `TabAnimator, M`
**Exports**:
  - `M.new(opts)` → Instance
**Requires**: `rearkitekt.gui.fx.easing`

### `ARKITEKT/rearkitekt/gui/widgets/selection_rectangle.lua` (99 lines)
> @noindex
**Modules**: `M, SelRect`
**Classes**: `SelRect, M`
**Exports**:
  - `M.new(opts)` → Instance

### `ARKITEKT/rearkitekt/gui/widgets/sliders/hue.lua` (276 lines)
> @noindex
**Modules**: `M, _locks`
**Exports**:
  - `M.draw_hue(ctx, id, hue, opt)`
  - `M.draw_saturation(ctx, id, saturation, base_hue, opt)`
  - `M.draw_gamma(ctx, id, gamma, opt)`
  - `M.draw(ctx, id, hue, opt)`
**Private**: 5 helpers

### `ARKITEKT/rearkitekt/gui/widgets/transport/transport_container.lua` (137 lines)
> @noindex
**Modules**: `M, TransportContainer`
**Classes**: `TransportContainer, M`
**Exports**:
  - `M.new(opts)` → Instance
  - `M.draw(ctx, id, width, height, content_fn, config)`
**Requires**: `rearkitekt.gui.widgets.transport.transport_fx`

### `ARKITEKT/rearkitekt/gui/widgets/transport/transport_fx.lua` (107 lines)
> @noindex
**Modules**: `M`
**Exports**:
  - `M.render_base(dl, x1, y1, x2, y2, config)`
  - `M.render_specular(dl, x1, y1, x2, y2, config, hover_factor)`
  - `M.render_inner_glow(dl, x1, y1, x2, y2, config, hover_factor)`
  - `M.render_border(dl, x1, y1, x2, y2, config)`
  - `M.render_complete(dl, x1, y1, x2, y2, config, hover_factor)`
**Requires**: `rearkitekt.core.colors`

### `ARKITEKT/rearkitekt/reaper/regions.lua` (83 lines)
> @noindex
**Modules**: `M, regions`
**Exports**:
  - `M.scan_project_regions(proj)`
  - `M.get_region_by_rid(proj, target_rid)`
  - `M.go_to_region(proj, target_rid)`

### `ARKITEKT/rearkitekt/reaper/timing.lua` (113 lines)
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

### `ARKITEKT/rearkitekt/reaper/transport.lua` (97 lines)
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

## Internal Dependencies

**`ARKITEKT/rearkitekt/gui/widgets/grid/core.lua`**
  → `ARKITEKT/rearkitekt/gui/widgets/grid/rendering.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/grid/dnd_state.lua`
  → `ARKITEKT/rearkitekt/gui/fx/animation/rect_track.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/grid/layout.lua`
  → `ARKITEKT/rearkitekt/gui/fx/dnd/drag_indicator.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/grid/animation.lua`
  → `ARKITEKT/rearkitekt/gui/draw.lua`
  → `ARKITEKT/rearkitekt/gui/systems/selection.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/grid/input.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/grid/drop_zones.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/selection_rectangle.lua`
  → `ARKITEKT/rearkitekt/core/colors.lua`
  → `ARKITEKT/rearkitekt/gui/fx/dnd/drop_indicator.lua`

**`ARKITEKT/rearkitekt/gui/widgets/package_tiles/grid.lua`**
  → `ARKITEKT/rearkitekt/gui/fx/tile_motion.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/grid/core.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/package_tiles/micromanage.lua`
  → `ARKITEKT/rearkitekt/core/colors.lua`
  → `ARKITEKT/rearkitekt/gui/systems/height_stabilizer.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/package_tiles/renderer.lua`

**`ARKITEKT/rearkitekt/gui/widgets/panel/header/layout.lua`**
  → `ARKITEKT/rearkitekt/gui/widgets/panel/header/separator.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/panel/header/tab_strip.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/panel/header/button.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/panel/header/dropdown_field.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/panel/header/search_field.lua`

**`ARKITEKT/rearkitekt/gui/widgets/panel/init.lua`**
  → `ARKITEKT/rearkitekt/gui/widgets/panel/tab_animator.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/panel/background.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/panel/config.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/panel/content.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/controls/scrollbar.lua`

**`ARKITEKT/rearkitekt/gui/widgets/component/chip.lua`**
  → `ARKITEKT/rearkitekt/gui/fx/tile_fx_config.lua`
  → `ARKITEKT/rearkitekt/core/colors.lua`
  → `ARKITEKT/rearkitekt/gui/draw.lua`
  → `ARKITEKT/rearkitekt/gui/fx/tile_fx.lua`

**`ARKITEKT/rearkitekt/gui/widgets/displays/status_pad.lua`**
  → `ARKITEKT/rearkitekt/gui/fx/tile_fx_config.lua`
  → `ARKITEKT/rearkitekt/core/colors.lua`
  → `ARKITEKT/rearkitekt/gui/draw.lua`
  → `ARKITEKT/rearkitekt/gui/fx/tile_fx.lua`

**`ARKITEKT/rearkitekt/gui/widgets/overlay/manager.lua`**
  → `ARKITEKT/rearkitekt/gui/widgets/overlay/config.lua`
  → `ARKITEKT/rearkitekt/gui/style.lua`
  → `ARKITEKT/rearkitekt/core/colors.lua`
  → `ARKITEKT/rearkitekt/gui/draw.lua`

**`ARKITEKT/rearkitekt/gui/widgets/overlay/sheet.lua`**
  → `ARKITEKT/rearkitekt/gui/widgets/overlay/config.lua`
  → `ARKITEKT/rearkitekt/gui/style.lua`
  → `ARKITEKT/rearkitekt/core/colors.lua`
  → `ARKITEKT/rearkitekt/gui/draw.lua`

**`ARKITEKT/rearkitekt/gui/fx/dnd/drag_indicator.lua`**
  → `ARKITEKT/rearkitekt/gui/fx/dnd/config.lua`
  → `ARKITEKT/rearkitekt/core/colors.lua`
  → `ARKITEKT/rearkitekt/gui/draw.lua`

**`ARKITEKT/rearkitekt/gui/widgets/grid/rendering.lua`**
  → `ARKITEKT/rearkitekt/core/colors.lua`
  → `ARKITEKT/rearkitekt/gui/draw.lua`
  → `ARKITEKT/rearkitekt/gui/fx/marching_ants.lua`

**`ARKITEKT/rearkitekt/gui/widgets/package_tiles/renderer.lua`**
  → `ARKITEKT/rearkitekt/core/colors.lua`
  → `ARKITEKT/rearkitekt/gui/draw.lua`
  → `ARKITEKT/rearkitekt/gui/fx/marching_ants.lua`

**`ARKITEKT/rearkitekt/app/chrome/status_bar/widget.lua`**
  → `ARKITEKT/rearkitekt/app/chrome/status_bar/config.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/component/chip.lua`

**`ARKITEKT/rearkitekt/app/shell.lua`**
  → `ARKITEKT/rearkitekt/app/window.lua`
  → `ARKITEKT/rearkitekt/app/runtime.lua`

**`ARKITEKT/rearkitekt/gui/widgets/chip_list/list.lua`**
  → `ARKITEKT/rearkitekt/gui/systems/responsive_grid.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/component/chip.lua`

**`ARKITEKT/rearkitekt/gui/widgets/grid/animation.lua`**
  → `ARKITEKT/rearkitekt/gui/fx/animations/spawn.lua`
  → `ARKITEKT/rearkitekt/gui/fx/animations/destroy.lua`

**`ARKITEKT/rearkitekt/gui/widgets/panel/header/tab_strip.lua`**
  → `ARKITEKT/rearkitekt/gui/widgets/controls/context_menu.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/component/chip.lua`

**`ARKITEKT/rearkitekt/app/chrome/status_bar/config.lua`**
  → `ARKITEKT/rearkitekt/gui/widgets/component/chip.lua`

**`ARKITEKT/rearkitekt/app/chrome/status_bar/init.lua`**
  → `ARKITEKT/rearkitekt/app/chrome/status_bar/widget.lua`

**`ARKITEKT/rearkitekt/core/settings.lua`**
  → `ARKITEKT/rearkitekt/core/json.lua`

**`ARKITEKT/rearkitekt/gui/fx/animation/rect_track.lua`**
  → `ARKITEKT/rearkitekt/core/math.lua`

**`ARKITEKT/rearkitekt/gui/fx/animation/track.lua`**
  → `ARKITEKT/rearkitekt/core/math.lua`

**`ARKITEKT/rearkitekt/gui/fx/animations/destroy.lua`**
  → `ARKITEKT/rearkitekt/gui/fx/easing.lua`

**`ARKITEKT/rearkitekt/gui/fx/animations/spawn.lua`**
  → `ARKITEKT/rearkitekt/gui/fx/easing.lua`

**`ARKITEKT/rearkitekt/gui/fx/dnd/drop_indicator.lua`**
  → `ARKITEKT/rearkitekt/gui/fx/dnd/config.lua`

**`ARKITEKT/rearkitekt/gui/fx/marching_ants.lua`**
  → `ARKITEKT/rearkitekt/gui/draw.lua`

**`ARKITEKT/rearkitekt/gui/fx/tile_fx.lua`**
  → `ARKITEKT/rearkitekt/core/colors.lua`

**`ARKITEKT/rearkitekt/gui/fx/tile_motion.lua`**
  → `ARKITEKT/rearkitekt/gui/fx/animation/track.lua`

**`ARKITEKT/rearkitekt/gui/style.lua`**
  → `ARKITEKT/rearkitekt/core/colors.lua`

**`ARKITEKT/rearkitekt/gui/widgets/controls/dropdown.lua`**
  → `ARKITEKT/rearkitekt/gui/widgets/controls/tooltip.lua`

**`ARKITEKT/rearkitekt/gui/widgets/grid/input.lua`**
  → `ARKITEKT/rearkitekt/gui/draw.lua`

**`ARKITEKT/rearkitekt/gui/widgets/panel/header/dropdown_field.lua`**
  → `ARKITEKT/rearkitekt/gui/widgets/controls/dropdown.lua`

**`ARKITEKT/rearkitekt/gui/widgets/panel/header/init.lua`**
  → `ARKITEKT/rearkitekt/gui/widgets/panel/header/layout.lua`

**`ARKITEKT/rearkitekt/gui/widgets/panel/tab_animator.lua`**
  → `ARKITEKT/rearkitekt/gui/fx/easing.lua`

**`ARKITEKT/rearkitekt/gui/widgets/transport/transport_container.lua`**
  → `ARKITEKT/rearkitekt/gui/widgets/transport/transport_fx.lua`

**`ARKITEKT/rearkitekt/gui/widgets/transport/transport_fx.lua`**
  → `ARKITEKT/rearkitekt/core/colors.lua`

## External Dependencies
