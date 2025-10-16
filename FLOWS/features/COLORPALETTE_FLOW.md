# COLORPALETTE FLOW
Generated: 2025-10-16 01:20:52

## Overview
- **Folders**: 1
- **Files**: 5
- **Total Lines**: 1,210
- **Code Lines**: 861
- **Exports**: 24
- **Classes**: 6

## Folder Organization

### ARKITEKT/scripts/ColorPalette
- Files: 5
- Lines: 861
- Exports: 24

## Orchestrators

**`ARKITEKT/scripts/ColorPalette/app/gui.lua`** (5 dependencies)
  Composes: colors + draw + color_grid + controller + sheet

**`ARKITEKT/scripts/ColorPalette/ARK_ColorPalette.lua`** (5 dependencies)
  Composes: shell + state + gui + manager + settings

## Module API

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
**Requires**: `rearkitekt.core.colors, rearkitekt.gui.draw, ColorPalette.widgets.color_grid, ColorPalette.app.controller, rearkitekt.gui.widgets.overlay.sheet`

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
**Requires**: `rearkitekt.core.colors`

### `ARKITEKT/scripts/ColorPalette/widgets/color_grid.lua` (143 lines)
> @noindex
**Modules**: `M, ColorGrid`
**Classes**: `ColorGrid, M`
**Exports**:
  - `M.new()` → Instance
**Requires**: `rearkitekt.core.colors, rearkitekt.gui.draw`

## Internal Dependencies

**`ARKITEKT/scripts/ColorPalette/app/gui.lua`**
  → `ARKITEKT/scripts/ColorPalette/widgets/color_grid.lua`
  → `ARKITEKT/scripts/ColorPalette/app/controller.lua`

**`ARKITEKT/scripts/ColorPalette/ARK_ColorPalette.lua`**
  → `ARKITEKT/scripts/ColorPalette/app/state.lua`
  → `ARKITEKT/scripts/ColorPalette/app/gui.lua`

## External Dependencies

**`ARKITEKT/rearkitekt/core/colors.lua`** (used by 3 files)
  ← `ARKITEKT/scripts/ColorPalette/app/gui.lua`
  ← `ARKITEKT/scripts/ColorPalette/app/state.lua`
  ← `ARKITEKT/scripts/ColorPalette/widgets/color_grid.lua`

**`ARKITEKT/rearkitekt/gui/draw.lua`** (used by 2 files)
  ← `ARKITEKT/scripts/ColorPalette/app/gui.lua`
  ← `ARKITEKT/scripts/ColorPalette/widgets/color_grid.lua`

**`ARKITEKT/rearkitekt/gui/widgets/overlay/sheet.lua`** (used by 1 files)
  ← `ARKITEKT/scripts/ColorPalette/app/gui.lua`

**`ARKITEKT/rearkitekt/core/settings.lua`** (used by 1 files)
  ← `ARKITEKT/scripts/ColorPalette/ARK_ColorPalette.lua`

**`ARKITEKT/rearkitekt/app/shell.lua`** (used by 1 files)
  ← `ARKITEKT/scripts/ColorPalette/ARK_ColorPalette.lua`

**`ARKITEKT/rearkitekt/gui/widgets/overlay/manager.lua`** (used by 1 files)
  ← `ARKITEKT/scripts/ColorPalette/ARK_ColorPalette.lua`
