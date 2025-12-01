# Grid System

> **See [docs/widgets/grid/README.md](../../../../../../../docs/widgets/grid/README.md) for the current API documentation.**

This folder contains the grid implementation. The recommended API is `Ark.Grid(ctx, opts)`.

## Files

- **core.lua** - Main Grid class, rendering, selection, drag-drop
- **input.lua** - Input handling, shortcuts, mouse behaviors
- **grid_bridge.lua** - Cross-grid drag-drop coordination
- **selection.lua** - Selection state management
- **drag.lua** - Drag state management

## Quick Example

```lua
local Ark = require('arkitekt')

local result = Ark.Grid(ctx, {
  id = "my_grid",
  items = items,
  key = function(item) return item.id end,
  render_item = function(ctx, rect, item, state)
    -- Draw tile
  end,
  on_select = function(keys) ... end,
  on_reorder = function(new_order) ... end,
})
```

## Migration Note

The instance-based API (`Grid.new()` + `grid:draw()`) is deprecated. Use the opts-based `Ark.Grid(ctx, opts)` API instead. RegionPlaylist and ThemeAdjuster are being migrated.
