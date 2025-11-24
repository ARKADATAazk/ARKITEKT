# ARKITEKT Namespace (`ark.*`)

The ARKITEKT namespace provides ImGui-style access to all widgets and utilities through a single, clean interface.

## Quick Start

```lua
local ark = require('arkitekt')

-- Access widgets directly
ark.Button.draw(ctx, {label = "Click"})
ark.Checkbox.draw(ctx, {checked = true})
ark.Panel.draw(ctx, {title = "Panel", body = ...})

-- Access utilities
local color = ark.Colors.hex_to_rgba("#3B82F6")
local eased = ark.Easing.ease_out_cubic(0.5)
local random_id = ark.UUID.generate()
```

## Design Philosophy

Following ImGui's namespace pattern:
- **Single import**: `local ark = require('arkitekt')` gives access to everything
- **Lazy loading**: Modules only load when first accessed
- **No circular dependencies**: Widgets use direct requires internally
- **Familiar syntax**: `ark.Widget.method()` mirrors `ImGui.Widget()`

## Available Modules

### Primitives (14)
- `ark.Badge`
- `ark.Button`
- `ark.Checkbox`
- `ark.CloseButton`
- `ark.Combo`
- `ark.CornerButton`
- `ark.HueSlider`
- `ark.InputText`
- `ark.MarkdownField`
- `ark.RadioButton`
- `ark.Scrollbar`
- `ark.Separator`
- `ark.Slider`
- `ark.Spinner`

### Containers (2)
- `ark.Panel`
- `ark.TileGroup`

### Utilities (6)
- `ark.Colors` - Color manipulation and conversion
- `ark.Style` - Default styling configuration
- `ark.Draw` - Drawing utilities
- `ark.Easing` - Animation easing functions
- `ark.Math` - Math utilities
- `ark.UUID` - UUID generation

## Comparison: Old vs New

### Old Approach (Still Works!)
```lua
local Button = require('arkitekt.gui.widgets.primitives.button')
local Checkbox = require('arkitekt.gui.widgets.primitives.checkbox')
local Panel = require('arkitekt.gui.widgets.containers.panel')
local Colors = require('arkitekt.core.colors')

Button.draw(ctx, {label = "Click"})
Checkbox.draw(ctx, {checked = true})
```

**Pros**: Explicit, LSP-friendly, minimal overhead
**Cons**: Verbose imports, many require statements

### New Approach (Recommended!)
```lua
local ark = require('arkitekt')

ark.Button.draw(ctx, {label = "Click"})
ark.Checkbox.draw(ctx, {checked = true})
```

**Pros**: Clean, consistent, one import, lazy loaded
**Cons**: Extra `ark.` prefix (but matches ImGui style!)

## Implementation Details

### Lazy Loading
Modules are loaded **only when first accessed**:

```lua
local ark = require('arkitekt')
-- At this point: NO widgets are loaded yet!

ark.Button.draw(...)  -- Now button.lua loads
ark.Button.draw(...)  -- Cached! No reload
ark.Checkbox.draw(...) -- Now checkbox.lua loads
```

This means:
- ✅ Fast startup - only loads what you use
- ✅ Low memory - unused modules never load
- ✅ No performance penalty for large namespace

### Caching
After first access, modules are cached:

```lua
local ark = require('arkitekt')

-- First access: loads and caches button.lua
local btn1 = ark.Button
-- Second access: returns cached module (instant!)
local btn2 = ark.Button

assert(btn1 == btn2)  -- true! Same table
```

### Error Handling
Invalid widgets produce clear errors:

```lua
local ark = require('arkitekt')

ark.InvalidWidget.draw(...)
-- Error: ark.InvalidWidget is not a valid widget.
--        See MODULES table in arkitekt/init.lua
```

## Migration Guide

### For New Projects
Use `ark.*` namespace everywhere:

```lua
local ark = require('arkitekt')

-- Widgets
ark.Button.draw(ctx, {...})
ark.Panel.draw(ctx, {...})

-- Utilities
local color = ark.Colors.hex_to_rgba("#FF0000")
local eased = ark.Easing.ease_in_out_quad(t)
```

### For Existing Projects
No breaking changes! Mix and match as needed:

```lua
-- Keep existing requires
local Button = require('arkitekt.gui.widgets.primitives.button')

-- Add namespace for new code
local ark = require('arkitekt')

-- Both work fine together!
Button.draw(ctx, {...})
ark.Checkbox.draw(ctx, {...})
```

## Why "ark"?

- **Short**: 3 letters (like `std`, `os`, `io` in Lua)
- **Memorable**: Abbreviation of ARKITEKT
- **No conflicts**: Unlikely to clash with user code
- **Consistent**: Matches ImGui's lowercase namespace style

## Performance

✅ **No overhead**: Lazy loading means zero cost for unused modules
✅ **One-time cost**: First access loads module, then cached forever
✅ **Same speed**: After loading, `ark.Button` is identical to direct require

Benchmark (after first access):
```lua
local ark = require('arkitekt')
local Button = require('arkitekt.gui.widgets.primitives.button')

-- These are IDENTICAL after first access:
ark.Button.draw(...)    -- Just a table lookup!
Button.draw(...)        -- Direct reference
```

## Examples

See:
- `examples/namespace_demo.lua` - Basic usage
- `examples/namespace_full_demo.lua` - Complete feature showcase

## Internal Note

Widgets still use direct `require()` internally:

```lua
-- arkitekt/gui/widgets/containers/panel/init.lua
local Button = require('arkitekt.gui.widgets.primitives.button')
-- Panel NEVER uses the namespace!
```

This prevents circular dependencies:
- User code → `ark` namespace → widgets
- Panel → direct require → Button
- No cycle! ✅
