# ARKITEKT Namespace (`Ark.*`)

The ARKITEKT namespace provides ImGui-style access to all widgets and utilities through a single, clean interface.

## Quick Start

```lua
local Ark = require('arkitekt')

-- Access widgets directly
Ark.Button.draw(ctx, {label = "Click"})
Ark.Checkbox.draw(ctx, {checked = true})
Ark.Panel.draw(ctx, {title = "Panel", body = ...})

-- Access utilities
local color = Ark.Colors.hex_to_rgba("#3B82F6")
local eased = Ark.Easing.ease_out_cubic(0.5)
local random_id = Ark.UUID.generate()
```

## Design Philosophy

Following ImGui's namespace pattern:
- **Single import**: `local Ark = require('arkitekt')` gives access to everything
- **Lazy loading**: Modules only load when first accessed
- **No circular dependencies**: Widgets use direct requires internally
- **Familiar syntax**: `Ark.Widget.method()` mirrors `ImGui.Widget()`

## Available Modules

### Primitives (14)
- `Ark.Badge`
- `Ark.Button`
- `Ark.Checkbox`
- `Ark.CloseButton`
- `Ark.Combo`
- `Ark.CornerButton`
- `Ark.HueSlider`
- `Ark.InputText`
- `Ark.MarkdownField`
- `Ark.RadioButton`
- `Ark.Scrollbar`
- `Ark.Separator`
- `Ark.Slider`
- `Ark.Spinner`

### Containers (2)
- `Ark.Panel`
- `Ark.TileGroup`

### Utilities (6)
- `Ark.Colors` - Color manipulation and conversion
- `Ark.Style` - Default styling configuration
- `Ark.Draw` - Drawing utilities
- `Ark.Easing` - Animation easing functions
- `Ark.Math` - Math utilities
- `Ark.UUID` - UUID generation

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
local Ark = require('arkitekt')

Ark.Button.draw(ctx, {label = "Click"})
Ark.Checkbox.draw(ctx, {checked = true})
```

**Pros**: Clean, consistent, one import, lazy loaded
**Cons**: Extra `Ark.` prefix (but matches ImGui style!)

## Implementation Details

### Lazy Loading
Modules are loaded **only when first accessed**:

```lua
local Ark = require('arkitekt')
-- At this point: NO widgets are loaded yet!

Ark.Button.draw(...)  -- Now button.lua loads
Ark.Button.draw(...)  -- Cached! No reload
Ark.Checkbox.draw(...) -- Now checkbox.lua loads
```

This means:
- ✅ Fast startup - only loads what you use
- ✅ Low memory - unused modules never load
- ✅ No performance penalty for large namespace

### Caching
After first access, modules are cached:

```lua
local Ark = require('arkitekt')

-- First access: loads and caches button.lua
local btn1 = Ark.Button
-- Second access: returns cached module (instant!)
local btn2 = Ark.Button

assert(btn1 == btn2)  -- true! Same table
```

### Error Handling
Invalid widgets produce clear errors:

```lua
local Ark = require('arkitekt')

Ark.InvalidWidget.draw(...)
-- Error: Ark.InvalidWidget is not a valid widget.
--        See MODULES table in arkitekt/init.lua
```

## Migration Guide

### For New Projects
Use `Ark.*` namespace everywhere:

```lua
local Ark = require('arkitekt')

-- Widgets
Ark.Button.draw(ctx, {...})
Ark.Panel.draw(ctx, {...})

-- Utilities
local color = Ark.Colors.hex_to_rgba("#FF0000")
local eased = Ark.Easing.ease_in_out_quad(t)
```

### For Existing Projects
No breaking changes! Mix and match as needed:

```lua
-- Keep existing requires
local Button = require('arkitekt.gui.widgets.primitives.button')

-- Add namespace for new code
local Ark = require('arkitekt')

-- Both work fine together!
Button.draw(ctx, {...})
Ark.Checkbox.draw(ctx, {...})
```

## Why "Ark"?

- **Short**: 3 letters (like `os`, `io` in Lua)
- **Memorable**: Abbreviation of ARKITEKT
- **No conflicts**: Unlikely to clash with user code
- **Consistent**: Matches ImGui's PascalCase namespace style and module naming convention

## Performance

✅ **No overhead**: Lazy loading means zero cost for unused modules
✅ **One-time cost**: First access loads module, then cached forever
✅ **Same speed**: After loading, `Ark.Button` is identical to direct require

Benchmark (after first access):
```lua
local Ark = require('arkitekt')
local Button = require('arkitekt.gui.widgets.primitives.button')

-- These are IDENTICAL after first access:
Ark.Button.draw(...)    -- Just a table lookup!
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
- User code → `Ark` namespace → widgets
- Panel → direct require → Button
- No cycle! ✅
