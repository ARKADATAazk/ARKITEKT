# PROJECT FLOW: ARKITEKT-Project
Generated: 2025-10-13 15:09:44
Root: D:\Dropbox\REAPER\Scripts\ARKITEKT-Project

## Project Structure

```
└── ARKITEKT/
    ├── rearkitekt/
    │   ├── app/
    │   │   ├── chrome/
    │   │   │   └── status_bar/
    │   │   │       ├── config.lua         # (140 lines)
    │   │   │       ├── init.lua         # (3 lines)
    │   │   │       └── widget.lua         # (319 lines)
    │   │   ├── config.lua         # (90 lines)
    │   │   ├── hub.lua         # (93 lines)
    │   │   ├── icon.lua         # (124 lines)
    │   │   ├── runtime.lua         # (69 lines)
    │   │   ├── shell.lua         # (256 lines)
    │   │   ├── titlebar.lua         # (438 lines)
    │   │   └── window.lua         # (460 lines)
    │   ├── core/
    │   │   ├── colors.lua         # (550 lines)
    │   │   ├── json.lua         # (121 lines)
    │   │   ├── lifecycle.lua         # (81 lines)
    │   │   ├── math.lua         # (52 lines)
    │   │   ├── settings.lua         # (119 lines)
    │   │   └── undo_manager.lua         # (70 lines)
    │   ├── gui/
    │   │   ├── fx/
    │   │   │   ├── animation/
    │   │   │   │   ├── rect_track.lua         # (136 lines)
    │   │   │   │   └── track.lua         # (53 lines)
    │   │   │   ├── animations/
    │   │   │   │   ├── destroy.lua         # (149 lines)
    │   │   │   │   └── spawn.lua         # (58 lines)
    │   │   │   ├── dnd/
    │   │   │   │   ├── config.lua         # (91 lines)
    │   │   │   │   ├── drag_indicator.lua         # (219 lines)
    │   │   │   │   └── drop_indicator.lua         # (113 lines)
    │   │   │   ├── easing.lua         # (94 lines)
    │   │   │   ├── effects.lua         # (54 lines)
    │   │   │   ├── marching_ants.lua         # (142 lines)
    │   │   │   ├── tile_fx.lua         # (170 lines)
    │   │   │   ├── tile_fx_config.lua         # (79 lines)
    │   │   │   └── tile_motion.lua         # (58 lines)
    │   │   ├── systems/
    │   │   │   ├── height_stabilizer.lua         # (74 lines)
    │   │   │   ├── playback_manager.lua         # (22 lines)
    │   │   │   ├── reorder.lua         # (127 lines)
    │   │   │   ├── responsive_grid.lua         # (229 lines)
    │   │   │   ├── selection.lua         # (142 lines)
    │   │   │   └── tile_utilities.lua         # (49 lines)
    │   │   ├── widgets/
    │   │   │   ├── chip_list/
    │   │   │   │   └── list.lua         # (303 lines)
    │   │   │   ├── component/
    │   │   │   │   └── chip.lua         # (333 lines)
    │   │   │   ├── controls/
    │   │   │   │   ├── context_menu.lua         # (106 lines)
    │   │   │   │   ├── dropdown.lua         # (395 lines)
    │   │   │   │   ├── scrollbar.lua         # (239 lines)
    │   │   │   │   └── tooltip.lua         # (129 lines)
    │   │   │   ├── displays/
    │   │   │   │   └── status_pad.lua         # (192 lines)
    │   │   │   ├── grid/
    │   │   │   │   ├── animation.lua         # (101 lines)
    │   │   │   │   ├── core.lua         # (550 lines)
    │   │   │   │   ├── dnd_state.lua         # (113 lines)
    │   │   │   │   ├── drop_zones.lua         # (277 lines)
    │   │   │   │   ├── grid_bridge.lua         # (219 lines)
    │   │   │   │   ├── input.lua         # (237 lines)
    │   │   │   │   ├── layout.lua         # (101 lines)
    │   │   │   │   └── rendering.lua         # (90 lines)
    │   │   │   ├── navigation/
    │   │   │   │   └── menutabs.lua         # (269 lines)
    │   │   │   ├── overlay/
    │   │   │   │   ├── config.lua         # (139 lines)
    │   │   │   │   ├── manager.lua         # (178 lines)
    │   │   │   │   └── sheet.lua         # (125 lines)
    │   │   │   ├── package_tiles/
    │   │   │   │   ├── grid.lua         # (227 lines)
    │   │   │   │   ├── micromanage.lua         # (127 lines)
    │   │   │   │   └── renderer.lua         # (267 lines)
    │   │   │   ├── panel/
    │   │   │   │   ├── header/
    │   │   │   │   │   ├── button.lua         # (119 lines)
    │   │   │   │   │   ├── dropdown_field.lua         # (101 lines)
    │   │   │   │   │   ├── init.lua         # (46 lines)
    │   │   │   │   │   ├── layout.lua         # (305 lines)
    │   │   │   │   │   ├── search_field.lua         # (120 lines)
    │   │   │   │   │   ├── separator.lua         # (33 lines)
    │   │   │   │   │   └── tab_strip.lua         # (779 lines)
    │   │   │   │   ├── modes/
    │   │   │   │   │   ├── search_sort.lua         # (225 lines)
    │   │   │   │   │   └── tabs.lua         # (647 lines)
    │   │   │   │   ├── background.lua         # (61 lines)
    │   │   │   │   ├── config.lua         # (255 lines)
    │   │   │   │   ├── content.lua         # (44 lines)
    │   │   │   │   ├── header.lua         # (42 lines)
    │   │   │   │   ├── init.lua         # (403 lines)
    │   │   │   │   └── tab_animator.lua         # (107 lines)
    │   │   │   ├── sliders/
    │   │   │   │   └── hue.lua         # (276 lines)
    │   │   │   ├── transport/
    │   │   │   │   ├── transport_container.lua         # (137 lines)
    │   │   │   │   └── transport_fx.lua         # (107 lines)
    │   │   │   ├── selection_rectangle.lua         # (99 lines)
    │   │   │   └── tiles_container_old.lua         # (753 lines)
    │   │   ├── draw.lua         # (114 lines)
    │   │   ├── images.lua         # (285 lines)
    │   │   └── style.lua         # (146 lines)
    │   ├── input/
    │   │   └── wheel_guard.lua         # (43 lines)
    │   └── reaper/
    │       ├── regions.lua         # (83 lines)
    │       ├── timing.lua         # (113 lines)
    │       └── transport.lua         # (97 lines)
    ├── scripts/
    │   ├── ColorPalette/
    │   │   ├── app/
    │   │   │   ├── controller.lua         # (235 lines)
    │   │   │   ├── gui.lua         # (443 lines)
    │   │   │   └── state.lua         # (273 lines)
    │   │   ├── widgets/
    │   │   │   └── color_grid.lua         # (143 lines)
    │   │   └── ARK_ColorPalette.lua         # (116 lines)
    │   ├── Region_Playlist/
    │   │   ├── app/
    │   │   │   ├── config.lua         # (349 lines)
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
    │   │   │       ├── coordinator.lua         # (505 lines)
    │   │   │       ├── coordinator_render.lua         # (190 lines)
    │   │   │       ├── pool_grid_factory.lua         # (186 lines)
    │   │   │       └── selector.lua         # (98 lines)
    │   │   └── ARK_RegionPlaylist.lua         # (76 lines)
    │   └── demos/
    │       ├── demo.lua         # (383 lines)
    │       ├── demo2.lua         # (210 lines)
    │       ├── demo3.lua         # (148 lines)
    │       ├── demo_modal_overlay.lua         # (451 lines)
    │       └── widget_demo.lua         # (250 lines)
    └── ARKITEKT.lua         # (353 lines)
```

## Overview
- **Total Files**: 120
- **Total Lines**: 24,210
- **Code Lines**: 18,869
- **Public Functions**: 352
- **Classes**: 81
- **Modules**: 260

## Folder Structure
### ARKITEKT/
  - Files: 120
  - Lines: 18,869
  - Exports: 352

## Execution Flow Patterns

### Entry Points (Not Imported by Others)
- **`ARKITEKT/scripts/demos/widget_demo.lua`**
  → Imports: rearkitekt.app.shell, ReArkitekt.gui.widgets.colorblocks, rearkitekt.gui.draw (+2 more)
- **`ARKITEKT/scripts/demos/demo_modal_overlay.lua`**
  → Imports: rearkitekt.app.shell, rearkitekt.gui.widgets.overlay.sheet, rearkitekt.gui.widgets.chip_list.list (+1 more)
- **`ARKITEKT/scripts/Region_Playlist/ARK_RegionPlaylist.lua`**
  → Imports: rearkitekt.app.shell, Region_Playlist.app.config, Region_Playlist.app.state (+2 more)
- **`ARKITEKT/scripts/ColorPalette/ARK_ColorPalette.lua`**
  → Imports: rearkitekt.app.shell, ColorPalette.app.state, ColorPalette.app.gui (+2 more)
- **`ARKITEKT/rearkitekt/gui/widgets/navigation/menutabs.lua`**
- **`ARKITEKT/rearkitekt/app/icon.lua`**
- **`ARKITEKT/rearkitekt/gui/systems/reorder.lua`**
- **`ARKITEKT/rearkitekt/app/titlebar.lua`**
- **`ARKITEKT/ARKITEKT.lua`**
  → Imports: rearkitekt.app.shell, rearkitekt.app.hub, rearkitekt.gui.widgets.package_tiles.grid (+3 more)
- **`ARKITEKT/scripts/Region_Playlist/widgets/controls/controls_widget.lua`**

### Orchestration Pattern
**`ARKITEKT/rearkitekt/gui/widgets/grid/core.lua`** composes 13 modules:
  layout + rect_track + colors + selection + selection_rectangle (+8 more)
**`ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/coordinator.lua`** composes 13 modules:
  config + coordinator_render + draw + colors + tile_motion (+8 more)
**`ARKITEKT/scripts/Region_Playlist/app/gui.lua`** composes 9 modules:
  coordinator + colors + shortcuts + controller + transport_container (+4 more)
**`ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/base.lua`** composes 7 modules:
  draw + colors + tile_fx + tile_fx_config + marching_ants (+2 more)
**`ARKITEKT/ARKITEKT.lua`** composes 6 modules:
  shell + hub + grid + micromanage + panel (+1 more)

## Module API Surface

### `ARKITEKT/ARKITEKT.lua`
> @description ARKITEKT Toolkit Hub

**Modules**: `result, conflicts, asset_providers`
**Private Functions**: 7 helpers
**Dependencies**: `rearkitekt.app.shell, rearkitekt.app.hub, rearkitekt.gui.widgets.package_tiles.grid, rearkitekt.gui.widgets.package_tiles.micromanage, rearkitekt.gui.widgets.panel, (+1 more)`

### `ARKITEKT/rearkitekt/app/chrome/status_bar/config.lua`
> @noindex

**Modules**: `M, result`
**Public API**:
  - `M.deep_merge(base, override)`
  - `M.merge(user_config, preset_name)`
**Dependencies**: `rearkitekt.gui.widgets.component.chip`

### `ARKITEKT/rearkitekt/app/chrome/status_bar/widget.lua`
> @noindex

**Modules**: `M, right_items`
**Classes**: `M` (stateful objects)
**Public API**:
  - `M.new(config)` → Instance
**Private Functions**: 6 helpers
**Dependencies**: `rearkitekt.gui.widgets.component.chip, rearkitekt.app.chrome.status_bar.config`

### `ARKITEKT/rearkitekt/app/config.lua`
> @noindex

**Modules**: `M, keys`
**Public API**:
  - `M.get_defaults()`
  - `M.get(path)`

### `ARKITEKT/rearkitekt/app/hub.lua`
> @noindex

**Modules**: `M, apps`
**Public API**:
  - `M.launch_app(app_path)`
  - `M.render_hub(ctx, opts)`

### `ARKITEKT/rearkitekt/app/icon.lua`
> @noindex

**Modules**: `M`
**Public API**:
  - `M.draw_rearkitekt(ctx, x, y, size, color)`
  - `M.draw_rearkitekt_v2(ctx, x, y, size, color)`
  - `M.draw_simple_a(ctx, x, y, size, color)`

### `ARKITEKT/rearkitekt/app/runtime.lua`
> @noindex

**Modules**: `M`
**Classes**: `M` (stateful objects)
**Public API**:
  - `M.new(opts)` → Instance

### `ARKITEKT/rearkitekt/app/shell.lua`
> @noindex

**Modules**: `M, DEFAULTS`
**Public API**:
  - `M.run(opts)`
**Private Functions**: 4 helpers
**Dependencies**: `rearkitekt.app.runtime, rearkitekt.app.window`

### `ARKITEKT/rearkitekt/app/titlebar.lua`
> @noindex

**Modules**: `M, DEFAULTS`
**Classes**: `M` (stateful objects)
**Public API**:
  - `M.new(opts)` → Instance

### `ARKITEKT/rearkitekt/app/window.lua`
> @noindex

**Modules**: `M, DEFAULTS`
**Classes**: `M` (stateful objects)
**Public API**:
  - `M.new(opts)` → Instance

### `ARKITEKT/rearkitekt/core/colors.lua`
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

### `ARKITEKT/rearkitekt/core/json.lua`
> @noindex

**Modules**: `M, out, obj, arr`
**Public API**:
  - `M.encode(t)`
  - `M.decode(str)`
**Private Functions**: 5 helpers

### `ARKITEKT/rearkitekt/core/lifecycle.lua`
> @noindex

**Modules**: `M, Group`
**Classes**: `Group, M` (stateful objects)
**Public API**:
  - `M.new()` → Instance

### `ARKITEKT/rearkitekt/core/math.lua`
> @noindex

**Modules**: `M`
**Public API**:
  - `M.lerp(a, b, t)`
  - `M.clamp(value, min, max)`
  - `M.remap(value, in_min, in_max, out_min, out_max)`
  - `M.snap(value, step)`
  - `M.smoothdamp(current, target, velocity, smoothtime, maxspeed, dt)`
  - `M.approximately(a, b, epsilon)`

### `ARKITEKT/rearkitekt/core/settings.lua`
> @noindex

**Modules**: `Settings, out, M, t`
**Classes**: `Settings` (stateful objects)
**Public API**:
  - `M.open(cache_dir, filename)`
**Private Functions**: 7 helpers
**Dependencies**: `rearkitekt.core.json`

### `ARKITEKT/rearkitekt/core/undo_manager.lua`
> @noindex

**Modules**: `M`
**Classes**: `M` (stateful objects)
**Public API**:
  - `M.new(opts)` → Instance

### `ARKITEKT/rearkitekt/gui/draw.lua`
> @noindex

**Modules**: `M`
**Public API**:
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

### `ARKITEKT/rearkitekt/gui/fx/animation/rect_track.lua`
> @noindex

**Modules**: `M, RectTrack`
**Classes**: `RectTrack, M` (stateful objects)
**Public API**:
  - `M.new(speed, snap_epsilon, magnetic_threshold, magnetic_multiplier)` → Instance
**Dependencies**: `rearkitekt.core.math`

### `ARKITEKT/rearkitekt/gui/fx/animation/track.lua`
> @noindex

**Modules**: `M, Track`
**Classes**: `Track, M` (stateful objects)
**Public API**:
  - `M.new(initial_value, speed)` → Instance
**Dependencies**: `rearkitekt.core.math`

### `ARKITEKT/rearkitekt/gui/fx/animations/destroy.lua`
> @noindex

**Modules**: `M, DestroyAnim, completed`
**Classes**: `DestroyAnim, M` (stateful objects)
**Public API**:
  - `M.new(opts)` → Instance
**Dependencies**: `rearkitekt.gui.fx.easing`

### `ARKITEKT/rearkitekt/gui/fx/animations/spawn.lua`
> @noindex

**Modules**: `M, SpawnTracker`
**Classes**: `SpawnTracker, M` (stateful objects)
**Public API**:
  - `M.new(config)` → Instance
**Dependencies**: `rearkitekt.gui.fx.easing`

### `ARKITEKT/rearkitekt/gui/fx/dnd/config.lua`
> @noindex

**Modules**: `M`
**Public API**:
  - `M.get_mode_config(config, is_copy, is_delete)`

### `ARKITEKT/rearkitekt/gui/fx/dnd/drag_indicator.lua`
> @noindex

**Modules**: `M`
**Public API**:
  - `M.draw_badge(ctx, dl, mx, my, count, config, is_copy_mode, is_delete_mode)`
  - `M.draw(ctx, dl, mx, my, count, config, colors, is_copy_mode, is_delete_mode)`
**Private Functions**: 5 helpers
**Dependencies**: `rearkitekt.gui.draw, rearkitekt.core.colors, rearkitekt.gui.fx.dnd.config`

### `ARKITEKT/rearkitekt/gui/fx/dnd/drop_indicator.lua`
> @noindex

**Modules**: `M`
**Public API**:
  - `M.draw_vertical(ctx, dl, x, y1, y2, config, is_copy_mode)`
  - `M.draw_horizontal(ctx, dl, x1, x2, y, config, is_copy_mode)`
  - `M.draw(ctx, dl, config, is_copy_mode, orientation, ...)`
**Dependencies**: `rearkitekt.gui.fx.dnd.config`

### `ARKITEKT/rearkitekt/gui/fx/easing.lua`
> @noindex

**Modules**: `M`
**Public API**:
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

### `ARKITEKT/rearkitekt/gui/fx/effects.lua`
> @noindex

**Modules**: `M`
**Public API**:
  - `M.hover_shadow(dl, x1, y1, x2, y2, strength, radius)`
  - `M.soft_glow(dl, x1, y1, x2, y2, color, intensity, radius)`
  - `M.pulse_glow(dl, x1, y1, x2, y2, color, time, speed, radius)`

### `ARKITEKT/rearkitekt/gui/fx/marching_ants.lua`
> @noindex

**Modules**: `M`
**Public API**:
  - `M.draw(dl, x1, y1, x2, y2, color, thickness, radius, dash, gap, speed_px)`

### `ARKITEKT/rearkitekt/gui/fx/tile_fx.lua`
> @noindex

**Modules**: `M`
**Public API**:
  - `M.render_base_fill(dl, x1, y1, x2, y2, rounding)`
  - `M.render_color_fill(dl, x1, y1, x2, y2, base_color, opacity, saturation, brightness, rounding)`
  - `M.render_gradient(dl, x1, y1, x2, y2, base_color, intensity, opacity, rounding)`
  - `M.render_specular(dl, x1, y1, x2, y2, base_color, strength, coverage, rounding)`
  - `M.render_inner_shadow(dl, x1, y1, x2, y2, strength, rounding)`
  - `M.render_playback_progress(dl, x1, y1, x2, y2, base_color, progress, fade_alpha, rounding)`
  - `M.render_border(dl, x1, y1, x2, y2, base_color, saturation, brightness, opacity, thickness, rounding, is_selected, glow_strength, glow_layers)`
  - `M.render_complete(dl, x1, y1, x2, y2, base_color, config, is_selected, hover_factor, playback_progress, playback_fade)`
**Dependencies**: `rearkitekt.core.colors`

### `ARKITEKT/rearkitekt/gui/fx/tile_fx_config.lua`
> @noindex

**Modules**: `M, config`
**Public API**:
  - `M.get()`
  - `M.override(overrides)`

### `ARKITEKT/rearkitekt/gui/fx/tile_motion.lua`
> @noindex

**Modules**: `M, TileAnimator`
**Classes**: `TileAnimator, M` (stateful objects)
**Public API**:
  - `M.new(default_speed)` → Instance
**Dependencies**: `rearkitekt.gui.fx.animation.track`

### `ARKITEKT/rearkitekt/gui/images.lua`
> @noindex

**Modules**: `M, Cache`
**Classes**: `Cache, M` (stateful objects)
**Public API**:
  - `M.new(opts)` → Instance
**Private Functions**: 9 helpers

### `ARKITEKT/rearkitekt/gui/style.lua`
> @noindex

**Modules**: `M`
**Public API**:
  - `M.with_alpha(col, a)`
  - `M.PushMyStyle(ctx)`
  - `M.PopMyStyle(ctx)`
**Dependencies**: `rearkitekt.core.colors`

### `ARKITEKT/rearkitekt/gui/systems/height_stabilizer.lua`
> @noindex

**Modules**: `M, HeightStabilizer`
**Classes**: `HeightStabilizer, M` (stateful objects)
**Public API**:
  - `M.new(opts)` → Instance

### `ARKITEKT/rearkitekt/gui/systems/playback_manager.lua`
> @noindex

**Modules**: `M`
**Public API**:
  - `M.compute_fade_alpha(progress, fade_in_ratio, fade_out_ratio)`

### `ARKITEKT/rearkitekt/gui/systems/reorder.lua`
> @noindex

**Modules**: `M, t, base, new_order, new_order, new_order`
**Public API**:
  - `M.insert_relative(order_keys, dragged_keys, target_key, side)`
  - `M.move_up(order_keys, selected_keys)`
  - `M.move_down(order_keys, selected_keys)`

### `ARKITEKT/rearkitekt/gui/systems/responsive_grid.lua`
> @noindex

**Modules**: `M, rows, current_row, layout`
**Public API**:
  - `M.calculate_scaled_gap(tile_height, base_gap, base_height, min_height, responsive_config)`
  - `M.calculate_responsive_tile_height(opts)`
  - `M.calculate_grid_metrics(opts)`
  - `M.calculate_justified_layout(items, opts)`
  - `M.should_show_scrollbar(grid_height, available_height, buffer)`
  - `M.create_default_config()` → Instance

### `ARKITEKT/rearkitekt/gui/systems/selection.lua`
> @noindex

**Modules**: `M, Selection, out, out`
**Classes**: `Selection, M` (stateful objects)
**Public API**:
  - `M.new()` → Instance

### `ARKITEKT/rearkitekt/gui/systems/tile_utilities.lua`
> @noindex

**Modules**: `M`
**Public API**:
  - `M.format_bar_length(start_time, end_time, proj)`

### `ARKITEKT/rearkitekt/gui/widgets/chip_list/list.lua`
> @noindex

**Modules**: `M, filtered, min_widths, min_widths`
**Public API**:
  - `M.draw(ctx, items, opts)`
  - `M.draw_vertical(ctx, items, opts)`
  - `M.draw_columns(ctx, items, opts)`
  - `M.draw_grid(ctx, items, opts)`
  - `M.draw_auto(ctx, items, opts)`
**Dependencies**: `rearkitekt.gui.widgets.component.chip, rearkitekt.gui.systems.responsive_grid`

### `ARKITEKT/rearkitekt/gui/widgets/component/chip.lua`
> @noindex

**Modules**: `M`
**Public API**:
  - `M.calculate_width(ctx, label, opts)`
  - `M.draw(ctx, opts)`
**Private Functions**: 4 helpers
**Dependencies**: `rearkitekt.gui.draw, rearkitekt.core.colors, rearkitekt.gui.fx.tile_fx, rearkitekt.gui.fx.tile_fx_config`

### `ARKITEKT/rearkitekt/gui/widgets/controls/context_menu.lua`
> @noindex

**Modules**: `M`
**Public API**:
  - `M.begin(ctx, id, config)`
  - `M.end_menu(ctx)`
  - `M.item(ctx, label, config)`
  - `M.separator(ctx, config)`

### `ARKITEKT/rearkitekt/gui/widgets/controls/dropdown.lua`
> @noindex

**Modules**: `M, Dropdown`
**Classes**: `Dropdown, M` (stateful objects)
**Public API**:
  - `M.new(opts)` → Instance
**Dependencies**: `rearkitekt.gui.widgets.controls.tooltip`

### `ARKITEKT/rearkitekt/gui/widgets/controls/scrollbar.lua`
> @noindex

**Modules**: `M, Scrollbar`
**Classes**: `Scrollbar, M` (stateful objects)
**Public API**:
  - `M.new(opts)` → Instance

### `ARKITEKT/rearkitekt/gui/widgets/controls/tooltip.lua`
> @noindex

**Modules**: `M`
**Public API**:
  - `M.show(ctx, text, config)`
  - `M.show_delayed(ctx, text, config)`
  - `M.show_at_mouse(ctx, text, config)`
  - `M.reset()`

### `ARKITEKT/rearkitekt/gui/widgets/displays/status_pad.lua`
> @noindex

**Modules**: `M, FontPool, StatusPad`
**Classes**: `StatusPad, M` (stateful objects)
**Public API**:
  - `M.new(opts)` → Instance
**Private Functions**: 4 helpers
**Dependencies**: `rearkitekt.gui.draw, rearkitekt.core.colors, rearkitekt.gui.fx.tile_fx, rearkitekt.gui.fx.tile_fx_config`

### `ARKITEKT/rearkitekt/gui/widgets/grid/animation.lua`
> @noindex

**Modules**: `M, AnimationCoordinator`
**Classes**: `AnimationCoordinator, M` (stateful objects)
**Public API**:
  - `M.new(config)` → Instance
**Dependencies**: `rearkitekt.gui.fx.animations.spawn, rearkitekt.gui.fx.animations.destroy`

### `ARKITEKT/rearkitekt/gui/widgets/grid/core.lua`
> @noindex

**Modules**: `M, Grid, current_keys, new_keys, rect_map, rect_map, order, filtered_order, new_order`
**Classes**: `Grid, M` (stateful objects)
**Public API**:
  - `M.new(opts)` → Instance
**Dependencies**: `rearkitekt.gui.widgets.grid.layout, rearkitekt.gui.fx.animation.rect_track, rearkitekt.core.colors, rearkitekt.gui.systems.selection, rearkitekt.gui.widgets.selection_rectangle, (+8 more)`

### `ARKITEKT/rearkitekt/gui/widgets/grid/dnd_state.lua`
> @noindex

**Modules**: `M, DnDState`
**Classes**: `DnDState, M` (stateful objects)
**Public API**:
  - `M.new(opts)` → Instance

### `ARKITEKT/rearkitekt/gui/widgets/grid/drop_zones.lua`
> @noindex

**Modules**: `M, non_dragged, zones, zones, rows, sequential_items, set`
**Public API**:
  - `M.find_drop_target(mx, my, items, key_fn, dragged_set, rect_track, is_single_column, grid_bounds)`
  - `M.find_external_drop_target(mx, my, items, key_fn, rect_track, is_single_column, grid_bounds)`
  - `M.build_dragged_set(dragged_ids)`
**Private Functions**: 5 helpers

## State Ownership

### Stateful Modules (Classes/Objects)
- **`widget.lua`**: M
- **`runtime.lua`**: M
- **`titlebar.lua`**: M
- **`window.lua`**: M
- **`lifecycle.lua`**: Group, M
- **`settings.lua`**: Settings
- **`undo_manager.lua`**: M
- **`rect_track.lua`**: RectTrack, M
- **`track.lua`**: Track, M
- **`destroy.lua`**: DestroyAnim, M
- ... and 37 more

### Stateless Modules (Pure Functions)
- **61** stateless modules
- **34** with no dependencies (pure utility modules)

## Integration Essentials

### Module Creators
- `M.new(config)` in `widget.lua`
- `M.new(opts)` in `runtime.lua`
- `M.new(opts)` in `titlebar.lua`
- `M.new(opts)` in `window.lua`
- `M.new()` in `lifecycle.lua`
- `M.new(opts)` in `undo_manager.lua`
- `M.new(speed, snap_epsilon, magnetic_threshold, magnetic_multiplier)` in `rect_track.lua`
- `M.new(initial_value, speed)` in `track.lua`
- ... and 44 more

### Callback-Based APIs
- `M.find_drop_target()` expects: key_fn
- `M.find_external_drop_target()` expects: key_fn
- `Sheet.render()` expects: content_fn
- `M.draw()` expects: content_fn
- `M.draw()` expects: on_mode_changed
- ... and 9 more

## Module Classification

**Pure Modules** (no dependencies): 54
  - `ARKITEKT/rearkitekt/app/config.lua`
  - `ARKITEKT/rearkitekt/app/hub.lua`
  - `ARKITEKT/rearkitekt/app/icon.lua`
  - `ARKITEKT/rearkitekt/app/runtime.lua`
  - `ARKITEKT/rearkitekt/app/titlebar.lua`
  - ... and 49 more

**Class Modules** (OOP with metatables): 47
  - `widget.lua`: M
  - `runtime.lua`: M
  - `titlebar.lua`: M
  - `window.lua`: M
  - `lifecycle.lua`: Group, M
  - ... and 42 more

## Top 10 Largest Files

1. `ARKITEKT/scripts/Region_Playlist/app/gui.lua` (892 lines)
2. `ARKITEKT/rearkitekt/gui/widgets/panel/header/tab_strip.lua` (779 lines)
3. `ARKITEKT/rearkitekt/gui/widgets/tiles_container_old.lua` (753 lines)
4. `ARKITEKT/rearkitekt/gui/widgets/panel/modes/tabs.lua` (647 lines)
5. `ARKITEKT/scripts/Region_Playlist/app/state.lua` (597 lines)
6. `ARKITEKT/rearkitekt/core/colors.lua` (550 lines)
7. `ARKITEKT/rearkitekt/gui/widgets/grid/core.lua` (550 lines)
8. `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/coordinator.lua` (505 lines)
9. `ARKITEKT/rearkitekt/app/window.lua` (460 lines)
10. `ARKITEKT/scripts/demos/demo_modal_overlay.lua` (451 lines)

## Dependency Analysis

### Forward Dependencies (What Each File Imports)

**`ARKITEKT/rearkitekt/gui/widgets/grid/core.lua`** imports 13 modules:
  → `ARKITEKT/rearkitekt/core/colors.lua`
  → `ARKITEKT/rearkitekt/gui/draw.lua`
  → `ARKITEKT/rearkitekt/gui/fx/animation/rect_track.lua`
  → `ARKITEKT/rearkitekt/gui/fx/dnd/drag_indicator.lua`
  → `ARKITEKT/rearkitekt/gui/fx/dnd/drop_indicator.lua`
  → `ARKITEKT/rearkitekt/gui/systems/selection.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/grid/animation.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/grid/dnd_state.lua`
  → ... and 5 more

**`ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/coordinator.lua`** imports 12 modules:
  → `ARKITEKT/rearkitekt/core/colors.lua`
  → `ARKITEKT/rearkitekt/gui/draw.lua`
  → `ARKITEKT/rearkitekt/gui/fx/tile_motion.lua`
  → `ARKITEKT/rearkitekt/gui/systems/height_stabilizer.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/grid/grid_bridge.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/panel/config.lua`
  → `ARKITEKT/scripts/Region_Playlist/app/config.lua`
  → `ARKITEKT/scripts/Region_Playlist/app/state.lua`
  → ... and 4 more

**`ARKITEKT/scripts/Region_Playlist/app/gui.lua`** imports 9 modules:
  → `ARKITEKT/rearkitekt/core/colors.lua`
  → `ARKITEKT/rearkitekt/gui/fx/tile_motion.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/chip_list/list.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/overlay/sheet.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/transport/transport_container.lua`
  → `ARKITEKT/scripts/Region_Playlist/app/config.lua`
  → `ARKITEKT/scripts/Region_Playlist/app/controller.lua`
  → `ARKITEKT/scripts/Region_Playlist/app/shortcuts.lua`
  → ... and 1 more

**`ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/base.lua`** imports 7 modules:
  → `ARKITEKT/rearkitekt/core/colors.lua`
  → `ARKITEKT/rearkitekt/gui/draw.lua`
  → `ARKITEKT/rearkitekt/gui/fx/marching_ants.lua`
  → `ARKITEKT/rearkitekt/gui/fx/tile_fx.lua`
  → `ARKITEKT/rearkitekt/gui/fx/tile_fx_config.lua`
  → `ARKITEKT/rearkitekt/gui/systems/tile_utilities.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/component/chip.lua`

**`ARKITEKT/rearkitekt/gui/widgets/package_tiles/grid.lua`** imports 6 modules:
  → `ARKITEKT/rearkitekt/core/colors.lua`
  → `ARKITEKT/rearkitekt/gui/fx/tile_motion.lua`
  → `ARKITEKT/rearkitekt/gui/systems/height_stabilizer.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/grid/core.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/package_tiles/micromanage.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/package_tiles/renderer.lua`

**`ARKITEKT/rearkitekt/gui/widgets/panel/init.lua`** imports 6 modules:
  → `ARKITEKT/rearkitekt/gui/widgets/controls/scrollbar.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/panel/background.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/panel/config.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/panel/content.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/panel/header.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/panel/tab_animator.lua`

**`ARKITEKT/ARKITEKT.lua`** imports 5 modules:
  → `ARKITEKT/rearkitekt/app/hub.lua`
  → `ARKITEKT/rearkitekt/app/shell.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/package_tiles/grid.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/package_tiles/micromanage.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/selection_rectangle.lua`

**`ARKITEKT/rearkitekt/gui/widgets/panel/header/layout.lua`** imports 5 modules:
  → `ARKITEKT/rearkitekt/gui/widgets/panel/header/button.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/panel/header/dropdown_field.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/panel/header/search_field.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/panel/header/separator.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/panel/header/tab_strip.lua`

**`ARKITEKT/scripts/ColorPalette/app/gui.lua`** imports 5 modules:
  → `ARKITEKT/rearkitekt/core/colors.lua`
  → `ARKITEKT/rearkitekt/gui/draw.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/overlay/sheet.lua`
  → `ARKITEKT/scripts/ColorPalette/app/controller.lua`
  → `ARKITEKT/scripts/ColorPalette/widgets/color_grid.lua`

**`ARKITEKT/scripts/ColorPalette/ARK_ColorPalette.lua`** imports 5 modules:
  → `ARKITEKT/rearkitekt/app/shell.lua`
  → `ARKITEKT/rearkitekt/core/settings.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/overlay/manager.lua`
  → `ARKITEKT/scripts/ColorPalette/app/gui.lua`
  → `ARKITEKT/scripts/ColorPalette/app/state.lua`

**`ARKITEKT/scripts/Region_Playlist/app/state.lua`** imports 5 modules:
  → `ARKITEKT/rearkitekt/core/colors.lua`
  → `ARKITEKT/rearkitekt/core/undo_manager.lua`
  → `ARKITEKT/scripts/Region_Playlist/engine/coordinator_bridge.lua`
  → `ARKITEKT/scripts/Region_Playlist/storage/state.lua`
  → `ARKITEKT/scripts/Region_Playlist/storage/undo_bridge.lua`

**`ARKITEKT/scripts/Region_Playlist/ARK_RegionPlaylist.lua`** imports 5 modules:
  → `ARKITEKT/rearkitekt/app/shell.lua`
  → `ARKITEKT/scripts/Region_Playlist/app/config.lua`
  → `ARKITEKT/scripts/Region_Playlist/app/gui.lua`
  → `ARKITEKT/scripts/Region_Playlist/app/state.lua`
  → `ARKITEKT/scripts/Region_Playlist/app/status.lua`

**`ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/active.lua`** imports 5 modules:
  → `ARKITEKT/rearkitekt/core/colors.lua`
  → `ARKITEKT/rearkitekt/gui/draw.lua`
  → `ARKITEKT/rearkitekt/gui/fx/tile_fx_config.lua`
  → `ARKITEKT/rearkitekt/gui/systems/playback_manager.lua`
  → `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/base.lua`

**`ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/pool.lua`** imports 5 modules:
  → `ARKITEKT/rearkitekt/core/colors.lua`
  → `ARKITEKT/rearkitekt/gui/draw.lua`
  → `ARKITEKT/rearkitekt/gui/fx/tile_fx_config.lua`
  → `ARKITEKT/rearkitekt/gui/systems/tile_utilities.lua`
  → `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/base.lua`

**`ARKITEKT/rearkitekt/gui/widgets/component/chip.lua`** imports 4 modules:
  → `ARKITEKT/rearkitekt/core/colors.lua`
  → `ARKITEKT/rearkitekt/gui/draw.lua`
  → `ARKITEKT/rearkitekt/gui/fx/tile_fx.lua`
  → `ARKITEKT/rearkitekt/gui/fx/tile_fx_config.lua`

**`ARKITEKT/rearkitekt/gui/widgets/displays/status_pad.lua`** imports 4 modules:
  → `ARKITEKT/rearkitekt/core/colors.lua`
  → `ARKITEKT/rearkitekt/gui/draw.lua`
  → `ARKITEKT/rearkitekt/gui/fx/tile_fx.lua`
  → `ARKITEKT/rearkitekt/gui/fx/tile_fx_config.lua`

**`ARKITEKT/rearkitekt/gui/widgets/overlay/manager.lua`** imports 4 modules:
  → `ARKITEKT/rearkitekt/core/colors.lua`
  → `ARKITEKT/rearkitekt/gui/draw.lua`
  → `ARKITEKT/rearkitekt/gui/style.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/overlay/config.lua`

**`ARKITEKT/rearkitekt/gui/widgets/overlay/sheet.lua`** imports 4 modules:
  → `ARKITEKT/rearkitekt/core/colors.lua`
  → `ARKITEKT/rearkitekt/gui/draw.lua`
  → `ARKITEKT/rearkitekt/gui/style.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/overlay/config.lua`

**`ARKITEKT/scripts/demos/demo.lua`** imports 4 modules:
  → `ARKITEKT/rearkitekt/app/shell.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/package_tiles/grid.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/package_tiles/micromanage.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/selection_rectangle.lua`

**`ARKITEKT/scripts/demos/demo_modal_overlay.lua`** imports 4 modules:
  → `ARKITEKT/rearkitekt/app/shell.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/chip_list/list.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/overlay/config.lua`
  → `ARKITEKT/rearkitekt/gui/widgets/overlay/sheet.lua`

### Reverse Dependencies (What Imports Each File)

**`ARKITEKT/rearkitekt/core/colors.lua`** is imported by 23 files:
  ← `ARKITEKT/rearkitekt/gui/fx/dnd/drag_indicator.lua`
  ← `ARKITEKT/rearkitekt/gui/fx/tile_fx.lua`
  ← `ARKITEKT/rearkitekt/gui/style.lua`
  ← `ARKITEKT/rearkitekt/gui/widgets/component/chip.lua`
  ← `ARKITEKT/rearkitekt/gui/widgets/displays/status_pad.lua`
  ← `ARKITEKT/rearkitekt/gui/widgets/grid/core.lua`
  ← `ARKITEKT/rearkitekt/gui/widgets/grid/rendering.lua`
  ← `ARKITEKT/rearkitekt/gui/widgets/overlay/manager.lua`
  ← ... and 15 more

**`ARKITEKT/rearkitekt/gui/draw.lua`** is imported by 18 files:
  ← `ARKITEKT/rearkitekt/gui/fx/dnd/drag_indicator.lua`
  ← `ARKITEKT/rearkitekt/gui/widgets/component/chip.lua`
  ← `ARKITEKT/rearkitekt/gui/widgets/displays/status_pad.lua`
  ← `ARKITEKT/rearkitekt/gui/widgets/grid/core.lua`
  ← `ARKITEKT/rearkitekt/gui/widgets/grid/input.lua`
  ← `ARKITEKT/rearkitekt/gui/widgets/grid/rendering.lua`
  ← `ARKITEKT/rearkitekt/gui/widgets/overlay/manager.lua`
  ← `ARKITEKT/rearkitekt/gui/widgets/overlay/sheet.lua`
  ← ... and 10 more

**`ARKITEKT/rearkitekt/app/shell.lua`** is imported by 8 files:
  ← `ARKITEKT/ARKITEKT.lua`
  ← `ARKITEKT/scripts/ColorPalette/ARK_ColorPalette.lua`
  ← `ARKITEKT/scripts/Region_Playlist/ARK_RegionPlaylist.lua`
  ← `ARKITEKT/scripts/demos/demo.lua`
  ← `ARKITEKT/scripts/demos/demo2.lua`
  ← `ARKITEKT/scripts/demos/demo3.lua`
  ← `ARKITEKT/scripts/demos/demo_modal_overlay.lua`
  ← `ARKITEKT/scripts/demos/widget_demo.lua`

**`ARKITEKT/rearkitekt/gui/widgets/component/chip.lua`** is imported by 6 files:
  ← `ARKITEKT/rearkitekt/app/chrome/status_bar/config.lua`
  ← `ARKITEKT/rearkitekt/app/chrome/status_bar/widget.lua`
  ← `ARKITEKT/rearkitekt/gui/widgets/chip_list/list.lua`
  ← `ARKITEKT/rearkitekt/gui/widgets/panel/header/tab_strip.lua`
  ← `ARKITEKT/rearkitekt/gui/widgets/panel/modes/tabs.lua`
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/base.lua`

**`ARKITEKT/rearkitekt/gui/fx/tile_fx_config.lua`** is imported by 5 files:
  ← `ARKITEKT/rearkitekt/gui/widgets/component/chip.lua`
  ← `ARKITEKT/rearkitekt/gui/widgets/displays/status_pad.lua`
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/active.lua`
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/base.lua`
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/pool.lua`

**`ARKITEKT/rearkitekt/gui/fx/tile_motion.lua`** is imported by 4 files:
  ← `ARKITEKT/rearkitekt/gui/widgets/package_tiles/grid.lua`
  ← `ARKITEKT/scripts/Region_Playlist/app/gui.lua`
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/coordinator.lua`
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/selector.lua`

**`ARKITEKT/rearkitekt/gui/fx/easing.lua`** is imported by 3 files:
  ← `ARKITEKT/rearkitekt/gui/fx/animations/destroy.lua`
  ← `ARKITEKT/rearkitekt/gui/fx/animations/spawn.lua`
  ← `ARKITEKT/rearkitekt/gui/widgets/panel/tab_animator.lua`

**`ARKITEKT/rearkitekt/gui/fx/marching_ants.lua`** is imported by 3 files:
  ← `ARKITEKT/rearkitekt/gui/widgets/grid/rendering.lua`
  ← `ARKITEKT/rearkitekt/gui/widgets/package_tiles/renderer.lua`
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/base.lua`

**`ARKITEKT/rearkitekt/gui/fx/tile_fx.lua`** is imported by 3 files:
  ← `ARKITEKT/rearkitekt/gui/widgets/component/chip.lua`
  ← `ARKITEKT/rearkitekt/gui/widgets/displays/status_pad.lua`
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/base.lua`

**`ARKITEKT/rearkitekt/gui/widgets/controls/dropdown.lua`** is imported by 3 files:
  ← `ARKITEKT/rearkitekt/gui/widgets/panel/header/dropdown_field.lua`
  ← `ARKITEKT/rearkitekt/gui/widgets/panel/modes/search_sort.lua`
  ← `ARKITEKT/rearkitekt/gui/widgets/tiles_container_old.lua`

**`ARKITEKT/rearkitekt/gui/widgets/grid/core.lua`** is imported by 3 files:
  ← `ARKITEKT/rearkitekt/gui/widgets/package_tiles/grid.lua`
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/active_grid_factory.lua`
  ← `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/pool_grid_factory.lua`

**`ARKITEKT/rearkitekt/gui/widgets/overlay/config.lua`** is imported by 3 files:
  ← `ARKITEKT/rearkitekt/gui/widgets/overlay/manager.lua`
  ← `ARKITEKT/rearkitekt/gui/widgets/overlay/sheet.lua`
  ← `ARKITEKT/scripts/demos/demo_modal_overlay.lua`

**`ARKITEKT/rearkitekt/gui/widgets/overlay/sheet.lua`** is imported by 3 files:
  ← `ARKITEKT/scripts/ColorPalette/app/gui.lua`
  ← `ARKITEKT/scripts/Region_Playlist/app/gui.lua`
  ← `ARKITEKT/scripts/demos/demo_modal_overlay.lua`

**`ARKITEKT/rearkitekt/gui/widgets/package_tiles/micromanage.lua`** is imported by 3 files:
  ← `ARKITEKT/ARKITEKT.lua`
  ← `ARKITEKT/rearkitekt/gui/widgets/package_tiles/grid.lua`
  ← `ARKITEKT/scripts/demos/demo.lua`

**`ARKITEKT/rearkitekt/gui/widgets/selection_rectangle.lua`** is imported by 3 files:
  ← `ARKITEKT/ARKITEKT.lua`
  ← `ARKITEKT/rearkitekt/gui/widgets/grid/core.lua`
  ← `ARKITEKT/scripts/demos/demo.lua`

### Circular Dependencies

✓ No circular dependencies detected

### Isolated Files (No Imports or Exports)

- `ARKITEKT/rearkitekt/app/config.lua`
- `ARKITEKT/rearkitekt/app/icon.lua`
- `ARKITEKT/rearkitekt/app/titlebar.lua`
- `ARKITEKT/rearkitekt/core/lifecycle.lua`
- `ARKITEKT/rearkitekt/gui/images.lua`
- `ARKITEKT/rearkitekt/gui/systems/reorder.lua`
- `ARKITEKT/rearkitekt/gui/widgets/navigation/menutabs.lua`
- `ARKITEKT/rearkitekt/input/wheel_guard.lua`
- `ARKITEKT/rearkitekt/reaper/timing.lua`
- `ARKITEKT/scripts/Region_Playlist/widgets/controls/controls_widget.lua`

### Dependency Complexity Ranking

1. `ARKITEKT/rearkitekt/core/colors.lua`: 0 imports + 23 importers = 23 total
2. `ARKITEKT/rearkitekt/gui/draw.lua`: 0 imports + 18 importers = 18 total
3. `ARKITEKT/rearkitekt/gui/widgets/grid/core.lua`: 13 imports + 3 importers = 16 total
4. `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/coordinator.lua`: 12 imports + 1 importers = 13 total
5. `ARKITEKT/rearkitekt/app/shell.lua`: 2 imports + 8 importers = 10 total
6. `ARKITEKT/rearkitekt/gui/widgets/component/chip.lua`: 4 imports + 6 importers = 10 total
7. `ARKITEKT/scripts/Region_Playlist/app/gui.lua`: 9 imports + 1 importers = 10 total
8. `ARKITEKT/scripts/Region_Playlist/widgets/region_tiles/renderers/base.lua`: 7 imports + 2 importers = 9 total
9. `ARKITEKT/rearkitekt/gui/widgets/package_tiles/grid.lua`: 6 imports + 2 importers = 8 total
10. `ARKITEKT/scripts/Region_Playlist/app/state.lua`: 5 imports + 3 importers = 8 total

## Important Constraints

### Object Lifecycle
- Classes use metatable pattern: `ClassName.__index = ClassName`
- Constructor functions typically named `new()` or `create()`
- Always call constructor before using instance methods

### Callback Requirements
- 14 modules use callback patterns for extensibility
- Callbacks enable features like event handling and custom behavior
- Check function signatures for `on_*`, `*_callback`, or `*_handler` parameters
