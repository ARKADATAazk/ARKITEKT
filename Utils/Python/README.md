# ARKITEKT Python Utilities

Python scripts for ARKITEKT development workflows.

## svg_to_lua.py

Converts SVG files to ReaImGui DrawList API calls for vector icon rendering using the battle-tested `svgpathtools` library.

### Features

- ✅ **Complete SVG support** via svgpathtools (handles ALL path commands including S, T, A)
- ✅ **ViewBox parsing** for correct scaling
- ✅ **Basic shapes** (circle, rect, polygon) automatically converted to paths
- ✅ **Arc approximation** using cubic bezier curves
- ✅ **Smooth bezier** (S/s, T/t commands) fully supported
- ✅ **Automatic normalization** to 0-1 range based on viewBox or bounds
- ✅ **DPI-aware** rendering code generation
- ✅ **Fill and stroke** handling with proper color mapping
- ✅ **Multi-path** support

### Installation

```bash
pip install svgpathtools
```

This will also install dependencies: `numpy`, `scipy`, `svgwrite`

### Usage

```bash
# Basic conversion (outputs to stdout)
python svg_to_lua.py icon.svg

# Generate complete Lua module file
python svg_to_lua.py arkitekt_logo.svg \
    -o ../ARKITEKT/rearkitekt/app/icon_generated.lua \
    -f draw_arkitekt_accurate

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

### Supported SVG Features

| Feature | Support | Implementation |
|---------|---------|----------------|
| **Path Commands** | ✅ Full | All M, L, H, V, C, S, Q, T, A, Z (absolute & relative) |
| **Smooth Bezier** (S/s, T/t) | ✅ Yes | Handled by svgpathtools |
| **Arcs** (A/a) | ✅ Yes | Approximated with cubic bezier curves |
| **Basic Shapes** | ✅ Yes | Circle, rect, polygon → converted to paths |
| **ViewBox** | ✅ Yes | Used for normalization |
| **Fill/Stroke** | ✅ Yes | Mapped to color parameter |
| **Multiple Paths** | ✅ Yes | Each path rendered separately |
| **Transforms** | ⚠️ Limited | Basic transforms handled by svgpathtools |

### Conversion Details

**ImGui DrawList Mapping:**
- Lines → `DrawList_PathLineTo()`
- Cubic Bezier → `DrawList_PathBezierCubicCurveTo()`
- Quadratic Bezier → `DrawList_PathBezierQuadraticCurveTo()`
- Arcs → Approximated with 4 cubic bezier segments
- Fill → `DrawList_PathFillConvex()`
- Stroke → `DrawList_PathStroke()`

**Coordinate Normalization:**
- Uses ViewBox if present in SVG
- Otherwise calculates bounding box from all paths
- Normalizes to 0-1 range for consistent scaling at any DPI
- All coordinates multiplied by `size * dpi` at runtime

**Color Handling:**
- SVG fills and strokes mapped to single `color` parameter in Lua
- Multi-color icons: generate separate functions for each color layer

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
