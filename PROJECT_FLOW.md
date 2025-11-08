# ARKITEKT FLOW
Generated: 2025-11-07 02:19:13

## Overview
- **Folders**: 1
- **Files**: 161
- **Total Lines**: 31,526
- **Code Lines**: 24,514
- **Exports**: 211
- **Classes**: 185

## Folder Organization

### ARKITEKT
- Files: 161
- Lines: 24,514
- Exports: 211

## Orchestrators

**`ARKITEKT\rearkitekt\gui\widgets\grid\core.lua`** (13 dependencies)
  Composes: animation + colors + dnd_state + drag_indicator + draw + drop_indicator + drop_zones + input + layout + rect_track + rendering + selection + selection_rectangle

**`ARKITEKT\rearkitekt\gui\widgets\nodal\canvas.lua`** (11 dependencies)
  Composes: auto_layout + background + config + connection + connection_renderer + drag_indicator + drop_indicator + node + node_renderer + port + viewport

**`ARKITEKT\scripts\Region_Playlist\widgets\region_tiles\coordinator.lua`** (11 dependencies)
  Composes: active_grid_factory + colors + config + coordinator_render + draw + grid_bridge + height_stabilizer + pool_grid_factory + selector + state + tile_motion

**`ARKITEKT\rearkitekt\gui\widgets\nodal\rendering\node_renderer.lua`** (9 dependencies)
  Composes: auto_layout + chip + colors + draw + marching_ants + node + port + tile_fx + tile_fx_config

**`ARKITEKT\scripts\Region_Playlist\app\gui.lua`** (9 dependencies)
  Composes: colors + config + controller + coordinator + list + sheet + shortcuts + tile_motion + transport_container

**`ARKITEKT\scripts\Region_Playlist\ARK_RegionPlaylist.lua`** (7 dependencies)
  Composes: colors + config + gui + profiler_init + shell + state + status

**`ARKITEKT\scripts\Region_Playlist\widgets\region_tiles\renderers\base.lua`** (7 dependencies)
  Composes: chip + colors + draw + marching_ants + tile_fx + tile_fx_config + tile_utilities

**`ARKITEKT\rearkitekt\gui\widgets\package_tiles\grid.lua`** (6 dependencies)
  Composes: colors + core + height_stabilizer + micromanage + renderer + tile_motion

**`ARKITEKT\scripts\Sandbox\sandbox_1.lua`** (6 dependencies)
  Composes: arkit + canvas + config + connection + node + shell

**`ARKITEKT\scripts\ItemPicker\app\gui.lua`** (6 dependencies)
  Composes: colors + core + draw + marching_ants + tile_fx + tile_motion

## Module API

### `ARKITEKT\scripts\Region_Playlist\app\gui.lua` (919 lines)
> @noindex
**Classes**: `M, GUI`
**Requires**: `colors, config, controller, coordinator, list, sheet, shortcuts, tile_motion`

### `ARKITEKT\rearkitekt\gui\widgets\panel\header\tab_strip.lua` (804 lines)
> @noindex
**Classes**: `M`
**Requires**: `chip, context_menu`

### `ARKITEKT\rearkitekt\app\window.lua` (779 lines)
> @noindex
**Classes**: `M, DEFAULTS`
**Exports**:
  - `current`
  - `duration`
  - `elapsed`
  - `is_complete`
  - `set_target`
  - `smoothed`
  - `t`
  - `target`
  - `update`
  - `value`

### `ARKITEKT\rearkitekt\gui\widgets\grid\core.lua` (642 lines)
> @noindex
**Classes**: `M, Grid`
**Requires**: `animation, colors, dnd_state, drag_indicator, draw, drop_indicator, drop_zones, input`

### `ARKITEKT\scripts\Region_Playlist\app\state.lua` (618 lines)
> @noindex
**Classes**: `M`
**Exports**:
  - `enabled`
  - `key`
  - `playlist_id`
  - `reps`
  - `type`
**Requires**: `colors, coordinator_bridge, state, undo_bridge, undo_manager`

### `ARKITEKT\rearkitekt\core\colors.lua` (550 lines)
> @noindex
**Classes**: `M`
**Exports**:
  - `is_bright`
  - `is_dark`
  - `is_gray`
  - `is_vivid`
  - `luminance`
  - `max_channel`
  - `min_channel`
  - `saturation`

### `ARKITEKT\rearkitekt\gui\widgets\nodal\canvas.lua` (527 lines)
> @noindex
**Classes**: `M`
**Exports**:
  - `values`
**Requires**: `auto_layout, background, config, connection, connection_renderer, drag_indicator, drop_indicator, node`

### `ARKITEKT\scripts\Sandbox\sandbox_4.lua` (519 lines)
> @noindex
**Requires**: `button, colors, shell, style_defaults`

### `ARKITEKT\scripts\Region_Playlist\widgets\region_tiles\coordinator.lua` (516 lines)
> @noindex
**Classes**: `M, RegionTiles`
**Requires**: `active_grid_factory, colors, config, coordinator_render, draw, grid_bridge, height_stabilizer, pool_grid_factory`

### `ARKITEKT\rearkitekt\app\titlebar.lua` (508 lines)
> @noindex
**Classes**: `M, DEFAULTS`

### `ARKITEKT\scripts\demos\demo_modal_overlay.lua` (451 lines)
> @noindex
**Requires**: `config, list, sheet, shell`

### `ARKITEKT\scripts\ItemPicker\app\tile_rendering.lua` (444 lines)
> @noindex
**Classes**: `M`

### `ARKITEKT\scripts\ColorPalette\app\gui.lua` (443 lines)
> @noindex
**Classes**: `M, GUI`
**Requires**: `color_grid, colors, controller, draw, sheet`

### `ARKITEKT\rearkitekt\gui\widgets\panel\init.lua` (423 lines)
> @noindex
**Classes**: `M, Panel`
**Requires**: `background, config, content, scrollbar, tab_animator`

### `ARKITEKT\rearkitekt\gui\widgets\controls\dropdown.lua` (395 lines)
> @noindex
**Classes**: `M, Dropdown`
**Requires**: `tooltip`

### `ARKITEKT\scripts\demos\demo.lua` (383 lines)
> @noindex
**Exports**:
  - `color`
  - `text`
**Requires**: `grid, micromanage, selection_rectangle, shell`

### `ARKITEKT\rearkitekt\app\overlay.lua` (381 lines)
> @noindex
**Classes**: `M`
**Exports**:
  - `current`
  - `curve_type`
  - `curved`
  - `duration`
  - `elapsed`
  - `is_complete`
  - `set_target`
  - `t`
  - `target`
  - `update`
**Requires**: `colors`

### `ARKITEKT\scripts\ItemPicker\app\visualization.lua` (370 lines)
> @noindex
**Classes**: `M`

### `ARKITEKT\scripts\Region_Playlist\app\controller.lua` (368 lines)
> @noindex
**Classes**: `M, Controller`
**Requires**: `state`

### `ARKITEKT\ARKITEKT.lua` (353 lines)
> ARKITEKT Toolkit Hub
**Exports**:
  - `color`
  - `text`
**Requires**: `grid, hub, micromanage, selection_rectangle, shell`

### `ARKITEKT\scripts\Region_Playlist\app\config.lua` (349 lines)
> @noindex
**Classes**: `M`
**Exports**:
  - `chip_radius`
  - `config`
  - `elements`
  - `enabled`
  - `flex`
  - `header`
  - `height`
  - `id`
  - `max_width`
  - `min_width`

### `ARKITEKT\scripts\Region_Playlist\engine\quantize.lua` (337 lines)
> @noindex
**Classes**: `M, Quantize`

### `ARKITEKT\rearkitekt\debug\_console_widget.lua` (335 lines)
> @noindex
**Classes**: `M`
**Requires**: `config, logger`

### `ARKITEKT\rearkitekt\gui\widgets\nodal\rendering\node_renderer.lua` (334 lines)
> @noindex
**Classes**: `M`
**Requires**: `auto_layout, chip, colors, draw, marching_ants, node, port, tile_fx`

### `ARKITEKT\rearkitekt\gui\widgets\component\chip.lua` (333 lines)
> @noindex
**Classes**: `M`
**Requires**: `colors, draw, tile_fx, tile_fx_config`

### `ARKITEKT\scripts\ItemPicker\app\grid_adapter.lua` (333 lines)
> @noindex
**Classes**: `M`

### `ARKITEKT\scripts\Region_Playlist\engine\state.lua` (324 lines)
> @noindex
**Classes**: `M, State`
**Exports**:
  - `current_idx`
  - `next_idx`
  - `playlist_order`
  - `playlist_pointer`
  - `proj`
  - `region_cache`
  - `sequence_length`
  - `sequence_version`
**Requires**: `regions, transport`

### `ARKITEKT\rearkitekt\app\chrome\status_bar\widget.lua` (319 lines)
> @noindex
**Classes**: `M`
**Exports**:
  - `apply_pending_resize`
  - `height`
  - `render`
  - `set_right_text`
**Requires**: `chip, config`

### `ARKITEKT\rearkitekt\gui\widgets\panel\header\layout.lua` (305 lines)
> @noindex
**Classes**: `M`
**Requires**: `button, dropdown_field, search_field, separator, tab_strip`

### `ARKITEKT\rearkitekt\gui\widgets\chip_list\list.lua` (303 lines)
> @noindex
**Classes**: `M`
**Requires**: `chip, responsive_grid`
