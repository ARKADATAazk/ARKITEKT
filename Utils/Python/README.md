# ARKITEKT Python Utilities

Python scripts for ARKITEKT development workflows.

## svg_to_lua.py

Converts SVG path elements to ReaImGui DrawList API calls for vector icon rendering.

### Features

- ✅ Full SVG path command support (M, L, H, V, C, Q, Z and relative variants)
- ✅ Automatic coordinate normalization to 0-1 range
- ✅ DPI-aware rendering code generation
- ✅ Handles both fill and stroke
- ✅ Supports cubic and quadratic bezier curves
- ✅ Multiple path support
- ✅ Bounding box calculation

### Usage

```bash
# Basic conversion (outputs to stdout)
python svg_to_lua.py icon.svg

# Generate complete Lua module file
python svg_to_lua.py arkitekt_logo.svg \
    --output ../ARKITEKT/rearkitekt/app/icon_generated.lua \
    --function-name draw_arkitekt_accurate

# Without coordinate normalization
python svg_to_lua.py icon.svg --no-normalize
```

### Example Workflow

1. **Export your logo as SVG** (from design tool)
   ```
   arkitekt_logo.svg
   ```

2. **Convert to Lua**
   ```bash
   python svg_to_lua.py arkitekt_logo.svg \
       --output icon_accurate.lua \
       --function-name draw_arkitekt_v3
   ```

3. **Use in your code**
   ```lua
   local Icon = require('rearkitekt.app.icon_accurate')
   Icon.draw_arkitekt_v3(ctx, x, y, size, color)
   ```

### Generated Code Structure

```lua
function M.draw_icon(ctx, x, y, size, color)
  local dl = ImGui.GetWindowDrawList(ctx)
  local dpi = ImGui.GetWindowDpiScale(ctx)
  local s = size * dpi

  -- Path commands
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathLineTo(dl, x + s*0.5, y + s*0.1)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, ...)
  ImGui.DrawList_PathFillConvex(dl, color)
end
```

### Supported SVG Commands

| SVG | Description | ImGui API |
|-----|-------------|-----------|
| M/m | Move to | `DrawList_PathLineTo` |
| L/l | Line to | `DrawList_PathLineTo` |
| H/h | Horizontal line | `DrawList_PathLineTo` |
| V/v | Vertical line | `DrawList_PathLineTo` |
| C/c | Cubic bezier | `DrawList_PathBezierCubicCurveTo` |
| Q/q | Quadratic bezier | `DrawList_PathBezierQuadraticCurveTo` |
| Z/z | Close path | Handled by fill/stroke flags |

### Notes

- **Normalization**: By default, coordinates are normalized to 0-1 range for consistent scaling
- **DPI Scaling**: All coordinates are multiplied by `size * dpi` for proper multi-DPI support
- **Color**: Uses single color parameter (can be extended for multi-color icons)
- **Transforms**: SVG transforms are not yet supported - flatten paths in your SVG editor first

---

## hexrgb.py

Converts hex color literals (`0xRRGGBBAA`) to `hexrgb()` function calls in Lua files.

### Usage

```bash
python hexrgb.py
```

Processes all `.lua` files in ARKITEKT directory with dry-run first, then prompts for confirmation.

### What it does

- Finds `0xRRGGBBAA` hex literals
- Converts to `hexrgb("#RRGGBB")` or `hexrgb("#RRGGBBAA")`
- Adds `local Colors = require('rearkitekt.core.colors')` if needed
- Adds `local hexrgb = Colors.hexrgb` local binding

---

## Requirements

All scripts use Python 3.6+ standard library only (no external dependencies).
