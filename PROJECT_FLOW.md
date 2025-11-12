# ARKITEKT-PROJECT FLOW
Generated: 2025-11-12 17:49:05

## Overview
- **Folders**: 2
- **Files**: 165
- **Total Lines**: 36,646
- **Code Lines**: 28,128
- **Exports**: 218
- **Classes**: 195

## Folder Organization

### ARKITEKT
- Files: 164
- Lines: 28,060
- Exports: 216

### Utils
- Files: 1
- Lines: 68
- Exports: 2

## Orchestrators

**`ARKITEKT\rearkitekt\gui\widgets\grid\core.lua`** (13 dependencies)
  Composes: animation + colors + dnd_state + drag_indicator + draw + drop_indicator + drop_zones + input + layout + rect_track + rendering + selection + selection_rectangle

**`ARKITEKT\rearkitekt\gui\widgets\nodal\canvas.lua`** (12 dependencies)
  Composes: auto_layout + background + colors + config + connection + connection_renderer + drag_indicator + drop_indicator + node + node_renderer + port + viewport

**`ARKITEKT\scripts\Region_Playlist\widgets\region_tiles\coordinator.lua`** (11 dependencies)
  Composes: active_grid_factory + colors + config + coordinator_render + draw + grid_bridge + height_stabilizer + pool_grid_factory + selector + state + tile_motion

**`ARKITEKT\rearkitekt\gui\widgets\nodal\rendering\node_renderer.lua`** (9 dependencies)
  Composes: auto_layout + chip + colors + draw + marching_ants + node + port + tile_fx + tile_fx_config

**`ARKITEKT\scripts\Region_Playlist\app\gui.lua`** (9 dependencies)
  Composes: _temp_transportwidgets + colors + config + controller + coordinator + list + sheet + shortcuts + transport_container

**`ARKITEKT\rearkitekt\gui\widgets\panel\init.lua`** (7 dependencies)
  Composes: background + button + config + content + corner_button + scrollbar + tab_animator

**`ARKITEKT\scripts\Region_Playlist\ARK_RegionPlaylist.lua`** (7 dependencies)
  Composes: colors + config + gui + profiler_init + shell + state + status

**`ARKITEKT\scripts\Sandbox\sandbox_1.lua`** (7 dependencies)
  Composes: arkit + canvas + colors + config + connection + node + shell

**`ARKITEKT\scripts\Region_Playlist\widgets\_temp_transportwidgets.lua`** (7 dependencies)
  Composes: button + chip + colors + layout + tile_fx_config + tooltip + transport_fx

**`ARKITEKT\scripts\Region_Playlist\widgets\region_tiles\renderers\base.lua`** (7 dependencies)
  Composes: chip + colors + draw + marching_ants + tile_fx + tile_fx_config + tile_utilities

## Module API

### `ARKITEKT\scripts\Region_Playlist\app\gui.lua` (1047 lines)
> @noindex
**Classes**: `M, GUI`
**Exports**:
  - `current`
**Requires**: `_temp_transportwidgets, colors, config, controller, coordinator, list, sheet, shortcuts`

### `ARKITEKT\rearkitekt\gui\widgets\panel\header\tab_strip.lua` (886 lines)
> @noindex
**Classes**: `M`
**Requires**: `chip, colors, context_menu`

### `ARKITEKT\scripts\Region_Playlist\widgets\_temp_transportwidgets.lua` (820 lines)
> @noindex
**Classes**: `M, TransportIcons, ViewModeButton, TransportDisplay, SimpleToggleButton, JumpControls, TransportButtonBar`
**Requires**: `button, chip, colors, layout, tile_fx_config, tooltip, transport_fx`

### `ARKITEKT\rearkitekt\app\window.lua` (786 lines)
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
**Requires**: `colors`

### `ARKITEKT\rearkitekt\gui\widgets\panel\init.lua` (698 lines)
> @noindex
**Classes**: `M, Panel`
**Requires**: `background, button, config, content, corner_button, scrollbar, tab_animator`

### `ARKITEKT\scripts\Region_Playlist\app\state.lua` (665 lines)
> @noindex
**Classes**: `M`
**Exports**:
  - `enabled`
  - `key`
  - `playlist_id`
  - `reps`
  - `type`
**Requires**: `colors, coordinator_bridge, state, undo_bridge, undo_manager`

### `ARKITEKT\rearkitekt\gui\widgets\grid\core.lua` (661 lines)
> @noindex
**Classes**: `M, Grid`
**Requires**: `animation, colors, dnd_state, drag_indicator, draw, drop_indicator, drop_zones, input`

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

### `ARKITEKT\rearkitekt\gui\widgets\nodal\canvas.lua` (530 lines)
> @noindex
**Classes**: `M`
**Exports**:
  - `values`
**Requires**: `auto_layout, background, colors, config, connection, connection_renderer, drag_indicator, drop_indicator`

### `ARKITEKT\scripts\Region_Playlist\widgets\region_tiles\coordinator.lua` (522 lines)
> @noindex
**Classes**: `M, RegionTiles`
**Requires**: `active_grid_factory, colors, config, coordinator_render, draw, grid_bridge, height_stabilizer, pool_grid_factory`

### `ARKITEKT\rearkitekt\app\titlebar.lua` (520 lines)
> @noindex
**Classes**: `M, DEFAULTS`
**Requires**: `colors`

### `ARKITEKT\scripts\Sandbox\sandbox_4.lua` (519 lines)
> @noindex
**Requires**: `button, colors, shell, style_defaults`

### `ARKITEKT\rearkitekt\gui\widgets\colored_text_view.lua` (500 lines)
> @noindex
**Classes**: `M, ColoredTextView`
**Exports**:
  - `col`
  - `line`
**Requires**: `colors`

### `ARKITEKT\rearkitekt\gui\widgets\panel\header\layout.lua` (494 lines)
> @noindex
**Classes**: `M`
**Requires**: `button, config, dropdown, search_input, separator, tab_strip`

### `ARKITEKT\scripts\Sandbox\sandbox_6.lua` (466 lines)
> @noindex
**Requires**: `arkit, shell`

### `ARKITEKT\scripts\demos\demo_modal_overlay.lua` (454 lines)
> @noindex
**Requires**: `colors, config, list, sheet, shell`

### `ARKITEKT\scripts\ItemPicker\app\tile_rendering.lua` (447 lines)
> @noindex
**Classes**: `M`
**Requires**: `colors`

### `ARKITEKT\scripts\ColorPalette\app\gui.lua` (443 lines)
> @noindex
**Classes**: `M, GUI`
**Requires**: `color_grid, colors, controller, draw, sheet`

### `ARKITEKT\scripts\Sandbox\sandbox_5.lua` (433 lines)
> @noindex
**Requires**: `arkit, button, colors, dropdown, search_input, shell`

### `ARKITEKT\scripts\Region_Playlist\engine\coordinator_bridge.lua` (429 lines)
> @noindex
**Classes**: `M`
**Exports**:
  - `context_depth`
  - `current_item_key`
  - `current_loop`
  - `is_playing`
  - `playlist_order`
  - `playlist_pointer`
  - `quantize_mode`
  - `sequence_length`
  - `total_loops`
**Requires**: `core, logger, playback, sequence_expander, state, transport`

### `ARKITEKT\rearkitekt\gui\widgets\controls\dropdown.lua` (425 lines)
> @noindex
**Classes**: `M, Dropdown`
**Requires**: `style_defaults, tooltip`

### `ARKITEKT\scripts\Region_Playlist\app\config.lua` (396 lines)
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
**Requires**: `colors`

### `ARKITEKT\scripts\demos\demo.lua` (386 lines)
> @noindex
**Exports**:
  - `color`
  - `text`
**Requires**: `colors, grid, micromanage, selection_rectangle, shell`

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

### `ARKITEKT\scripts\ItemPicker\app\visualization.lua` (373 lines)
> @noindex
**Classes**: `M`
**Requires**: `colors`

### `ARKITEKT\scripts\Region_Playlist\app\controller.lua` (368 lines)
> @noindex
**Classes**: `M, Controller`
**Requires**: `state`

### `ARKITEKT\rearkitekt\debug\_console_widget.lua` (364 lines)
> @noindex
**Classes**: `M`
**Requires**: `colored_text_view, colors, config, logger`

### `ARKITEKT\ARKITEKT.lua` (356 lines)
> ARKITEKT Toolkit Hub
**Exports**:
  - `color`
  - `text`
**Requires**: `colors, grid, hub, micromanage, selection_rectangle, shell`

### `ARKITEKT\scripts\Region_Playlist\widgets\region_tiles\renderers\pool.lua` (343 lines)
> @noindex
**Classes**: `M`
**Requires**: `base, colors, draw, tile_fx_config, tile_utilities`

### `ARKITEKT\scripts\Region_Playlist\engine\state.lua` (342 lines)
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
**Requires**: `logger, regions, transport`
