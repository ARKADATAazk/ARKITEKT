# PROJECT FLOW: ARKITEKT-Project
Generated: 2025-10-17 00:44:31
Root: D:\Dropbox\REAPER\Scripts\ARKITEKT-Project

## Project Structure

```
└── ARKITEKT/
    ├── arkitekt/
    │   ├── app/
    │   │   ├── chrome/
    │   │   │   └── status_bar/
    │   │   │       ├── config.lua         # (140 lines)
    │   │   │       ├── init.lua         # (3 lines)
    │   │   │       └── widget.lua         # (319 lines)
    │   │   ├── config.lua         # (139 lines)
    │   │   ├── hub.lua         # (93 lines)
    │   │   ├── icon.lua         # (124 lines)
    │   │   ├── overlay.lua         # (381 lines)
    │   │   ├── runtime.lua         # (69 lines)
    │   │   ├── shell.lua         # (300 lines)
    │   │   ├── titlebar.lua         # (508 lines)
    │   │   └── window.lua         # (779 lines)
    │   ├── core/
    │   │   ├── colors.lua         # (550 lines)
    │   │   ├── json.lua         # (121 lines)
    │   │   ├── lifecycle.lua         # (81 lines)
    │   │   ├── math.lua         # (52 lines)
    │   │   ├── settings.lua         # (119 lines)
    │   │   └── undo_manager.lua         # (70 lines)
    │   ├── debug/
    │   │   ├── _console_widget.lua         # (335 lines)
    │   │   ├── console.lua         # (130 lines)
    │   │   ├── logger.lua         # (80 lines)
    │   │   └── profiler_init.lua         # (97 lines)
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
    │   │   │   ├── marching_ants.lua         # (100 lines)
    │   │   │   ├── tile_fx.lua         # (170 lines)
    │   │   │   ├── tile_fx_config.lua         # (79 lines)
    │   │   │   └── tile_motion.lua         # (58 lines)
    │   │   ├── systems/
    │   │   │   ├── height_stabilizer.lua         # (74 lines)
    │   │   │   ├── playback_manager.lua         # (22 lines)
    │   │   │   ├── reorder.lua         # (127 lines)
    │   │   │   ├── responsive_grid.lua         # (228 lines)
    │   │   │   ├── selection.lua         # (142 lines)
    │   │   │   └── tile_utilities.lua         # (49 lines)
    │   │   ├── widgets/
    │   │   │   ├── chip_list/
    │   │   │   │   └── list.lua         # (303 lines)
    │   │   │   ├── component/
    │   │   │   │   └── chip.lua         # (333 lines)
    │   │   │   ├── controls/
    │   │   │   │   ├── button.lua         # (192 lines)
    │   │   │   │   ├── context_menu.lua         # (106 lines)
    │   │   │   │   ├── dropdown.lua         # (395 lines)
    │   │   │   │   ├── scrollbar.lua         # (239 lines)
    │   │   │   │   ├── style_defaults.lua         # (142 lines)
    │   │   │   │   └── tooltip.lua         # (129 lines)
    │   │   │   ├── displays/
    │   │   │   │   └── status_pad.lua         # (192 lines)
    │   │   │   ├── grid/
    │   │   │   │   ├── animation.lua         # (101 lines)
    │   │   │   │   ├── core.lua         # (595 lines)
    │   │   │   │   ├── dnd_state.lua         # (113 lines)
    │   │   │   │   ├── drop_zones.lua         # (277 lines)
    │   │   │   │   ├── grid_bridge.lua         # (219 lines)
    │   │   │   │   ├── input.lua         # (248 lines)
    │   │   │   │   ├── layout.lua         # (101 lines)
    │   │   │   │   └── rendering.lua         # (92 lines)
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
    │   │   │   │   │   ├── button.lua         # (42 lines)
    │   │   │   │   │   ├── dropdown_field.lua         # (101 lines)
    │   │   │   │   │   ├── init.lua         # (46 lines)
    │   │   │   │   │   ├── layout.lua         # (305 lines)
    │   │   │   │   │   ├── search_field.lua         # (120 lines)
    │   │   │   │   │   ├── separator.lua         # (33 lines)
    │   │   │   │   │   └── tab_strip.lua         # (804 lines)
    │   │   │   │   ├── background.lua         # (61 lines)
    │   │   │   │   ├── config.lua         # (234 lines)
    │   │   │   │   ├── content.lua         # (44 lines)
    │   │   │   │   ├── init.lua         # (416 lines)
    │   │   │   │   └── tab_animator.lua         # (107 lines)
    │   │   │   ├── sliders/
    │   │   │   │   └── hue.lua         # (276 lines)
    │   │   │   ├── transport/
    │   │   │   │   ├── transport_container.lua         # (137 lines)
    │   │   │   │   └── transport_fx.lua         # (107 lines)
    │   │   │   ├── close_button.lua         # (148 lines)
    │   │   │   └── selection_rectangle.lua         # (99 lines)
    │   │   ├── draw.lua         # (114 lines)
    │   │   ├── images.lua         # (285 lines)
    │   │   └── style.lua         # (146 lines)
    │   ├── reaper/
    │   │   ├── regions.lua         # (83 lines)
    │   │   ├── timing.lua         # (113 lines)
    │   │   └── transport.lua         # (97 lines)
    │   └── arkit.lua         # (213 lines)
    ├── scripts/
    │   ├── ColorPalette/
    │   │   ├── app/
    │   │   │   ├── controller.lua         # (235 lines)
    │   │   │   ├── gui.lua         # (443 lines)
    │   │   │   └── state.lua         # (273 lines)
    │   │   ├── widgets/
    │   │   │   └── color_grid.lua         # (143 lines)
    │   │   └── ARK_ColorPalette.lua         # (116 lines)
    │   ├── ItemPicker/
    │   │   ├── app/
    │   │   │   ├── cache_manager.lua         # (170 lines)
    │   │   │   ├── config.lua         # (59 lines)
    │   │   │   ├── disabled_items.lua         # (62 lines)
    │   │   │   ├── drag_drop.lua         # (145 lines)
    │   │   │   ├── grid_adapter.lua         # (333 lines)
    │   │   │   ├── gui.lua         # (153 lines)
    │   │   │   ├── job_queue.lua         # (121 lines)
    │   │   │   ├── main_ui.lua         # (146 lines)
    │   │   │   ├── pickle.lua         # (85 lines)
    │   │   │   ├── reaper_interface.lua         # (224 lines)
    │   │   │   ├── shortcuts.lua         # (91 lines)
    │   │   │   ├── tile_rendering.lua         # (444 lines)
    │   │   │   ├── ui_content.lua         # (212 lines)
    │   │   │   ├── utils.lua         # (35 lines)
    │   │   │   └── visualization.lua         # (406 lines)
    │   │   └── ARK_ItemPicker.lua         # (226 lines)
    │   ├── RegionPlaylist/
    │   │   ├── app/
    │   │   │   ├── config.lua         # (349 lines)
    │   │   │   ├── controller.lua         # (368 lines)
    │   │   │   ├── gui.lua         # (919 lines)
    │   │   │   ├── sequence_expander.lua         # (104 lines)
    │   │   │   ├── shortcuts.lua         # (81 lines)
    │   │   │   ├── state.lua         # (618 lines)
    │   │   │   └── status.lua         # (59 lines)
    │   │   ├── engine/
    │   │   │   ├── coordinator_bridge.lua         # (290 lines)
    │   │   │   ├── core.lua         # (194 lines)
    │   │   │   ├── playback.lua         # (103 lines)
    │   │   │   ├── quantize.lua         # (337 lines)
    │   │   │   ├── state.lua         # (324 lines)
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
    │   │   │       │   ├── active.lua         # (186 lines)
    │   │   │       │   ├── base.lua         # (207 lines)
    │   │   │       │   └── pool.lua         # (180 lines)
    │   │   │       ├── active_grid_factory.lua         # (220 lines)
    │   │   │       ├── coordinator.lua         # (505 lines)
    │   │   │       ├── coordinator_render.lua         # (190 lines)
    │   │   │       ├── pool_grid_factory.lua         # (193 lines)
    │   │   │       └── selector.lua         # (98 lines)
    │   │   └── ARK_RegionPlaylist.lua         # (103 lines)
    │   ├── Sandbox/
    │   │   ├── sandbox_1.lua         # (39 lines)
    │   │   ├── sandbox_2.lua         # (181 lines)
    │   │   ├── sandbox_3.lua         # (178 lines)
    │   │   ├── sandbox_4.lua         # (519 lines)
    │   │   ├── sandbox_5.lua         # (1 lines)
    │   │   ├── sandbox_6.lua         # (1 lines)
    │   │   ├── sandbox_7.lua         # (1 lines)
    │   │   ├── sandbox_8.lua         # (1 lines)
    │   │   └── sandbox_9.lua         # (1 lines)
    │   └── demos/
    │       ├── demo.lua         # (383 lines)
    │       ├── demo2.lua         # (210 lines)
    │       ├── demo3.lua         # (148 lines)
    │       ├── demo_modal_overlay.lua         # (451 lines)
    │       └── widget_demo.lua         # (250 lines)
    └── ARKITEKT.lua         # (353 lines)
```

## Overview
- **Total Files**: 150
- **Total Lines**: 29,057
- **Code Lines**: 22,653
- **Public Functions**: 488
- **Classes**: 88

## Application Entry Points

**`ARKITEKT/ARKITEKT.lua`** (calls Shell.run())
  → Dependencies: arkitekt.app.shell, arkitekt.app.hub, arkitekt.gui.widgets.package_tiles.grid, arkitekt.gui.widgets.package_tiles.micromanage, arkitekt.gui.widgets.panel, ... +1 more
**`ARKITEKT/arkitekt/app/runtime.lua`** (uses reaper.defer())
**`ARKITEKT/arkitekt/app/shell.lua`** (calls Shell.run())
  → Dependencies: arkitekt.app.runtime, arkitekt.app.window
**`ARKITEKT/arkitekt/debug/profiler_init.lua`** (uses reaper.defer())
  → Dependencies: arkitekt.dev.profiler_init
**`ARKITEKT/scripts/ColorPalette/ARK_ColorPalette.lua`** (calls Shell.run())
  → Dependencies: arkitekt.app.shell, ColorPalette.app.state, ColorPalette.app.gui, arkitekt.gui.widgets.overlay.manager, arkitekt.core.settings
**`ARKITEKT/scripts/demos/demo.lua`** (calls Shell.run())
  → Dependencies: arkitekt.app.shell, arkitekt.gui.widgets.package_tiles.grid, arkitekt.gui.widgets.package_tiles.micromanage, arkitekt.gui.widgets.panel, arkitekt.gui.widgets.selection_rectangle
**`ARKITEKT/scripts/demos/demo2.lua`** (calls Shell.run())
  → Dependencies: arkitekt.app.shell, arkitekt.gui.widgets.sliders.hue, arkitekt.gui.widgets.panel
**`ARKITEKT/scripts/demos/demo3.lua`** (calls Shell.run())
  → Dependencies: arkitekt.app.shell, arkitekt.gui.widgets.displays.status_pad, arkitekt.app.chrome.status_bar
**`ARKITEKT/scripts/demos/demo_modal_overlay.lua`** (calls Shell.run())
  → Dependencies: arkitekt.app.shell, arkitekt.gui.widgets.overlay.sheet, arkitekt.gui.widgets.chip_list.list, arkitekt.gui.widgets.overlay.config
**`ARKITEKT/scripts/demos/widget_demo.lua`** (calls Shell.run())
  → Dependencies: arkitekt.app.shell, Arkitekt.gui.widgets.colorblocks, arkitekt.gui.draw, arkitekt.gui.fx.effects, Arkitekt.*
**`ARKITEKT/scripts/ItemPicker/ARK_ItemPicker.lua`** (calls Shell.run())
  → Dependencies: arkitekt.app.runtime, arkitekt.app.overlay, arkitekt.app.shell
**`ARKITEKT/scripts/RegionPlaylist/ARK_RegionPlaylist.lua`** (calls Shell.run())
  → Dependencies: arkitekt.debug.profiler_init, arkitekt.app.shell, RegionPlaylist.app.config, RegionPlaylist.app.state, RegionPlaylist.app.gui, ... +2 more
**`ARKITEKT/scripts/Sandbox/sandbox_1.lua`** (uses reaper.defer())
  → Dependencies: imgui
**`ARKITEKT/scripts/Sandbox/sandbox_2.lua`** (calls Shell.run())
  → Dependencies: arkitekt.app.shell, arkitekt.arkit, arkitekt.debug.console, arkitekt.debug.logger
**`ARKITEKT/scripts/Sandbox/sandbox_3.lua`** (calls Shell.run())
  → Dependencies: arkitekt.app.shell, arkitekt.arkit, arkitekt.debug.console, arkitekt.debug.logger
**`ARKITEKT/scripts/Sandbox/sandbox_4.lua`** (calls Shell.run())
  → Dependencies: imgui, arkitekt.app.shell, arkitekt.gui.widgets.controls.button, arkitekt.gui.widgets.controls.style_defaults, arkitekt.core.colors

## Top 10 Largest Files

1. `ARKITEKT/scripts/RegionPlaylist/app/gui.lua` (919 lines)
2. `ARKITEKT/arkitekt/gui/widgets/panel/header/tab_strip.lua` (804 lines)
3. `ARKITEKT/arkitekt/app/window.lua` (779 lines)
4. `ARKITEKT/scripts/RegionPlaylist/app/state.lua` (618 lines)
5. `ARKITEKT/arkitekt/gui/widgets/grid/core.lua` (595 lines)
6. `ARKITEKT/arkitekt/core/colors.lua` (550 lines)
7. `ARKITEKT/scripts/Sandbox/sandbox_4.lua` (519 lines)
8. `ARKITEKT/arkitekt/app/titlebar.lua` (508 lines)
9. `ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/coordinator.lua` (505 lines)
10. `ARKITEKT/scripts/demos/demo_modal_overlay.lua` (451 lines)

## Cross-Feature Dependencies

No cross-feature dependencies detected

## Dependency Complexity (Top 10)

1. `ARKITEKT/arkitekt/core/colors.lua`: 0 imports + 29 importers = 29 total
2. `ARKITEKT/arkitekt/gui/draw.lua`: 0 imports + 20 importers = 20 total
3. `ARKITEKT/arkitekt/gui/widgets/grid/core.lua`: 13 imports + 4 importers = 17 total
4. `ARKITEKT/arkitekt/app/shell.lua`: 2 imports + 12 importers = 14 total
5. `ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/coordinator.lua`: 12 imports + 1 importers = 13 total
6. `ARKITEKT/scripts/RegionPlaylist/app/gui.lua`: 9 imports + 1 importers = 10 total
7. `ARKITEKT/arkitekt/gui/widgets/component/chip.lua`: 4 imports + 5 importers = 9 total
8. `ARKITEKT/scripts/RegionPlaylist/widgets/region_tiles/renderers/base.lua`: 7 imports + 2 importers = 9 total
9. `ARKITEKT/arkitekt/gui/widgets/package_tiles/grid.lua`: 6 imports + 2 importers = 8 total
10. `ARKITEKT/scripts/RegionPlaylist/app/state.lua`: 5 imports + 3 importers = 8 total