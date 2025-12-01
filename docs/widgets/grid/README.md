# Grid Widget

> Flexible tile grid with selection, drag-drop, reordering, and keyboard navigation.

---

## Quick Start

```lua
local Ark = require('arkitekt')

local result = Ark.Grid(ctx, {
  id = "my_items",
  items = my_items,
  key = function(item) return item.id end,
  render_item = function(ctx, rect, item, state)
    -- Draw your tile
  end,
})

if result.clicked then
  -- Handle click
end
```

---

## API

Single function call per frame. State is managed internally by ID.

```lua
local result = Ark.Grid(ctx, {
  id = "items",
  items = items,
  key = function(item) return item.id end,
  render_item = function(ctx, rect, item, state) ... end,

  -- Layout
  gap = 8,
  min_col_w = 200,
  fixed_tile_h = 100,

  -- Callbacks
  on_select = function(keys) ... end,
  on_double_click = function(key) ... end,
  on_reorder = function(new_order) ... end,
})
```

---

## Options Reference

### Required

| Option | Type | Description |
|--------|------|-------------|
| `id` | string | Unique identifier for the grid |
| `items` or `get_items` | table/function | Items to display |
| `key` | function | `(item) -> string` unique key |
| `render_item` | function | `(ctx, rect, item, state)` draw callback |

### Layout

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `gap` | number | 12 | Gap between tiles |
| `min_col_w` | number/function | 160 | Minimum column width |
| `fixed_tile_h` | number/function | nil | Fixed tile height (nil = auto) |
| `extend_input_area` | table | `{0,0,0,0}` | `{left, right, top, bottom}` padding |
| `clip_rendering` | boolean | false | Clip tiles outside bounds |

### Behavior Callbacks

| Option | Type | Description |
|--------|------|-------------|
| `on_select` | function | `(keys)` selection changed |
| `on_double_click` | function | `(key)` item double-clicked |
| `on_right_click` | function | `(key, selected)` right-click |
| `on_reorder` | function | `(new_order)` items reordered |
| `on_drag_start` | function | `(keys)` drag started |
| `on_click_empty` | function | `()` clicked empty area |

### Features

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `selectable` | boolean | true | Enable selection |
| `draggable` | boolean | true | Enable drag |
| `reorderable` | boolean | true | Enable reorder |
| `virtual` | boolean | false | Virtual scrolling (1000+ items) |
| `virtual_buffer_rows` | number | 2 | Extra rows to render |

### External Drops

| Option | Type | Description |
|--------|------|-------------|
| `accept_external_drops` | boolean | Accept drops from other grids |
| `external_drag_check` | function | `() -> boolean` is external drag active |
| `on_external_drop` | function | `(insert_index)` handle external drop |
| `is_copy_mode_check` | function | `() -> boolean` is copy mode |

### Exclusion Zones

| Option | Type | Description |
|--------|------|-------------|
| `get_exclusion_zones` | function | `(item, rect) -> {{x1,y1,x2,y2},...}` |

Exclusion zones prevent selection/drag on specific areas (e.g., buttons inside tiles).

---

## Result Object

The `Ark.Grid()` call returns a result object:

```lua
local result = Ark.Grid(ctx, opts)

result.selected_keys      -- table: currently selected keys
result.selection_changed  -- boolean: selection changed this frame
result.clicked            -- string|nil: key of clicked item
result.double_clicked     -- string|nil: key of double-clicked item
result.right_clicked      -- string|nil: key of right-clicked item
result.reordered          -- boolean: reorder occurred this frame
result.new_order          -- table|nil: new order after reorder
result.hover_key          -- string|nil: key of hovered item
result.drag_active        -- boolean: drag in progress
result.dragged_keys       -- table: keys being dragged
```

---

## Tile State

The `state` parameter in `render_item` contains:

```lua
state.selected   -- boolean: is selected
state.hover      -- boolean: is hovered
state.dragging   -- boolean: is being dragged
state.drop_target -- boolean: is drop target
state.spawn_alpha -- number: 0-1 spawn animation progress
state.destroy_alpha -- number: 0-1 destroy animation progress
```

---

## Behaviors

Map keyboard/mouse inputs to actions:

```lua
Ark.Grid(ctx, {
  behaviors = {
    -- Keyboard (receives: grid, selected_keys)
    space = function(grid, keys) play(keys) end,
    delete = function(grid, keys) remove(keys) end,
    f2 = function(grid, keys) rename(keys) end,

    -- Mouse (receives: grid, key, selected_keys)
    ['click:right'] = function(grid, key, selected) show_menu(key) end,

    -- Wheel (receives: grid, target_key, delta)
    ['wheel:ctrl'] = function(grid, key, delta) resize(delta) end,

    -- Double-click (receives: grid, key)
    double_click = function(grid, key) open(key) end,

    -- Reorder (receives: grid, new_order)
    reorder = function(grid, order) save(order) end,

    -- Drag (receives: grid, keys)
    drag_start = function(grid, keys) start_drag(keys) end,
  },
})
```

### Default Shortcuts

| Key | Behavior | Description |
|-----|----------|-------------|
| Space | `space` | Primary action |
| Delete | `delete` | Delete selected |
| Ctrl+A | `select_all` | Select all |
| Ctrl+D | `deselect_all` | Deselect all |
| F2 | `f2` | Edit/rename |
| Enter | `enter` | Confirm |
| Escape | `escape` | Cancel |

### Custom Shortcuts

```lua
Ark.Grid(ctx, {
  shortcuts = {
    { key = ImGui.Key_P, name = 'preview' },
    { key = ImGui.Key_R, ctrl = true, name = 'refresh' },
  },
  behaviors = {
    preview = function(grid, keys) ... end,
    refresh = function(grid, keys) ... end,
  },
})
```

---

## Performance

### Virtual Mode

For 1000+ items, enable virtual scrolling:

```lua
Ark.Grid(ctx, {
  virtual = true,
  fixed_tile_h = 100,  -- Required for virtual mode
  virtual_buffer_rows = 2,
})
```

Virtual mode only calculates/renders visible tiles.

### Tile Rendering Performance

Tile rendering is the hot path. Use per-frame caching for config values.

**Problem**: Deep config lookups repeated per-tile add up:
```lua
-- BAD: 3 table lookups × 500 tiles = 1500 lookups per frame
local rounding = config.tile.visual.rounding
```

**Solution**: Cache config values once per frame:

```lua
-- In your renderer module
local _cfg = {}

function M.cache_config(config)
  _cfg.rounding = config.tile.visual.rounding
  _cfg.padding = config.tile.visual.padding
  -- Cache all values used in render
end

function M.render(ctx, rect, item, state)
  -- Fast: single local lookup
  local rounding = _cfg.rounding
end
```

**Call cache before rendering**:
```lua
-- Before Ark.Grid() or grid:draw()
MyRenderer.cache_config(config)
local result = Ark.Grid(ctx, opts)
```

### TileFXConfig Caching

If using `TileFXConfig.get()` (theme-aware tile visuals), call `begin_frame` once:

```lua
local TileFXConfig = require('arkitekt.gui.renderers.tile.defaults')

-- Once per frame, before any grids
TileFXConfig.begin_frame(ctx)

-- Now TileFXConfig.get() returns cached config
local result = Ark.Grid(ctx, opts)
```

This avoids per-tile `pcall(require, ...)` and table iteration.

---

## GridBridge

Coordinate drag-drop between multiple grids:

```lua
local GridBridge = require('arkitekt.gui.widgets.containers.grid.grid_bridge')

local bridge = GridBridge.new({
  on_cross_grid_drop = function(info)
    -- info.source_grid, target_grid, payload, insert_index, is_copy_mode
  end,
})

-- Register grids
bridge:register_grid('source', source_grid, {
  accepts_drops_from = {},
  on_drag_start = function(keys)
    bridge:start_drag('source', { items = keys })
  end,
})

bridge:register_grid('target', target_grid, {
  accepts_drops_from = {'source'},
})
```

---

## Examples

### Basic Item Grid

```lua
local result = Ark.Grid(ctx, {
  id = "files",
  items = files,
  key = function(f) return f.path end,
  render_item = function(ctx, rect, file, state)
    local dl = ImGui.GetWindowDrawList(ctx)
    local color = state.selected and 0xFFFFFFFF or 0xAAAAAAFF
    ImGui.DrawList_AddRectFilled(dl, rect[1], rect[2], rect[3], rect[4], color)
    ImGui.DrawList_AddText(dl, rect[1] + 4, rect[2] + 4, 0x000000FF, file.name)
  end,
  on_double_click = function(path) open_file(path) end,
})
```

### With Custom Renderer

```lua
local MyRenderer = require('MyApp.ui.renderers.item')

-- Before rendering
MyRenderer.cache_config(config)

local result = Ark.Grid(ctx, {
  id = "items",
  items = items,
  key = function(item) return item.id end,
  render_item = function(ctx, rect, item, state)
    MyRenderer.render(ctx, rect, item, state)
  end,
})
```

### Reorderable Playlist

```lua
local result = Ark.Grid(ctx, {
  id = "playlist",
  items = playlist.items,
  key = function(item) return item.key end,
  render_item = render_playlist_item,

  on_reorder = function(new_order)
    playlist.items = reorder_items(playlist.items, new_order)
    save_playlist(playlist)
  end,

  behaviors = {
    delete = function(grid, keys)
      remove_from_playlist(keys)
    end,
    ['click:right'] = function(grid, key, selected)
      toggle_enabled(key)
    end,
  },
})
```

---

## See Also

- [Behavior System](./behaviors.md) - Keyboard/mouse behavior details
- [GridBridge](./grid_bridge.md) - Cross-grid drag-drop
- [Performance Guide](../../../cookbook/LUA_PERFORMANCE_GUIDE.md) - Optimization patterns
- [Widget Selection](../WIDGET_SELECTION.md) - When to use Grid vs Panel
