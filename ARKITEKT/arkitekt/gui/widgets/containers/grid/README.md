# Grid System

A flexible, extensible grid widget system for displaying and interacting with tile-based content.

## Architecture

The grid system consists of:
- **core.lua** - Main Grid class, rendering, selection, drag-drop
- **input.lua** - Input handling, shortcuts, mouse behaviors, defaults
- **grid_bridge.lua** - Cross-grid drag-drop coordination
- **selection.lua** - Selection state management
- **drag.lua** - Drag state management

## Quick Start

```lua
local Grid = require('arkitekt.gui.widgets.containers.grid.core')

local grid = Grid.new({
  id = "my_grid",
  gap = 8,
  min_col_w = function() return 200 end,
  fixed_tile_h = 100,

  get_items = function() return my_items end,
  key = function(item) return item.id end,
  render_tile = function(ctx, rect, item, state, grid) ... end,

  behaviors = {
    space = function(grid, selected_keys)
      -- Toggle play
    end,
    delete = function(grid, selected_keys)
      -- Delete items
    end,
  },
})
```

## Behavior System

All behaviors receive `grid` as the first parameter.

### Keyboard Behaviors

Triggered by keyboard shortcuts. Signature: `(grid, selected_keys)`

```lua
behaviors = {
  -- Basic keys
  space = function(grid, selected_keys) end,
  ['space:ctrl'] = function(grid, selected_keys) end,
  ['space:shift'] = function(grid, selected_keys) end,
  delete = function(grid, selected_keys) end,
  f2 = function(grid, selected_keys) end,
  f = function(grid, selected_keys) end,
  enter = function(grid, selected_keys) end,
  escape = function(grid, selected_keys) end,

  -- Selection (have defaults)
  select_all = function(grid) end,
  deselect_all = function(grid) end,
  invert_selection = function(grid) end,

  -- Undo/Redo
  undo = function(grid, selected_keys) end,
  redo = function(grid, selected_keys) end,
}
```

### Mouse Behaviors

Different signatures based on the interaction type.

```lua
behaviors = {
  -- Click behaviors: (grid, key, selected_keys)
  ['click:right'] = function(grid, key, selected_keys) end,
  ['click:alt'] = function(grid, key, selected_keys) end,

  -- Double-click: (grid, key)
  ['double_click'] = function(grid, key) end,
  double_click_seek = function(grid, key) end,
  start_inline_edit = function(grid, key) end,

  -- Wheel behaviors: (grid, target_key, delta)
  ['wheel:ctrl'] = function(grid, target_key, delta) end,
  ['wheel:shift'] = function(grid, target_key, delta) end,
  ['wheel:alt'] = function(grid, target_key, delta) end,
  wheel_cycle = function(grid, uuids, delta) end,
  wheel_resize = function(grid, direction, delta) end,

  -- Drag/reorder: (grid, keys/order)
  drag_start = function(grid, item_keys) end,
  reorder = function(grid, new_order) end,

  -- Selection callback
  on_select = function(grid, selected_keys) end,

  -- Inline edit callback
  on_inline_edit_complete = function(grid, key, new_text) end,
}
```

## Default Shortcuts

These are registered by default for all grids:

| Key | Name | Description |
|-----|------|-------------|
| Delete | `delete` | Delete selected items |
| Space | `space` | Primary action (play, toggle) |
| Ctrl+Space | `space:ctrl` | Secondary action |
| Shift+Space | `space:shift` | Tertiary action |
| F2 | `f2` | Rename/edit |
| F | `f` | Favorite/flag |
| Enter | `enter` | Confirm |
| Escape | `escape` | Cancel |
| Ctrl+A | `select_all` | Select all (has default) |
| Ctrl+D | `deselect_all` | Deselect all (has default) |
| Ctrl+I | `invert_selection` | Invert selection (has default) |
| Ctrl+Z | `undo` | Undo |
| Ctrl+Shift+Z | `redo` | Redo |
| Ctrl+Y | `redo` | Redo (alternate) |

## Default Mouse Behaviors

| Input | Name | Fallback |
|-------|------|----------|
| Right-click | `click:right` | - |
| Alt+click | `click:alt` | Falls back to `delete` |
| Double-click | `double_click` | Falls back to `double_click_seek` |
| Double-click text | `double_click:text` | Calls `start_inline_edit` |
| Ctrl+wheel | `wheel:ctrl` | Falls back to `wheel_resize` vertical |
| Shift+wheel | `wheel:shift` | Falls back to `wheel_cycle` |
| Alt+wheel | `wheel:alt` | Falls back to `wheel_resize` horizontal |

## Custom Shortcuts

Add grid-specific shortcuts:

```lua
Grid.new({
  shortcuts = {
    { key = ImGui.Key_P, name = 'preview' },
    { key = ImGui.Key_R, ctrl = true, name = 'refresh' },
  },
  behaviors = {
    preview = function(grid, selected_keys) ... end,
    refresh = function(grid, selected_keys) ... end,
  },
})
```

## Overriding Defaults

### Override a default behavior
```lua
behaviors = {
  select_all = function(grid)
    -- Custom select all logic
    for _, item in ipairs(my_visible_items) do
      grid.selection.selected[item.id] = true
    end
  end,
}
```

### Disable a default behavior
```lua
behaviors = {
  select_all = false,  -- Disables Ctrl+A
}
```

### Override a mouse behavior directly
```lua
behaviors = {
  ['wheel:shift'] = function(grid, target_key, delta)
    -- Custom shift+wheel behavior
    -- (bypasses the default wheel_cycle lookup)
  end,
}
```

## GridBridge

Coordinates drag-drop between multiple grids.

```lua
local GridBridge = require('arkitekt.gui.widgets.containers.grid.grid_bridge')

local bridge = GridBridge.new({
  on_cross_grid_drop = function(drop_info)
    -- drop_info.source_grid, target_grid, payload, insert_index, is_copy_mode
  end,
  copy_mode_detector = function(source_id, target_id, payload)
    return ImGui.IsKeyDown(ctx, ImGui.Key_LeftCtrl)
  end,
})

-- Register grids
bridge:register_grid('source', source_grid, {
  accepts_drops_from = {},
  on_drag_start = function(item_keys)
    bridge:start_drag('source', build_payload(item_keys))
  end,
})

bridge:register_grid('target', target_grid, {
  accepts_drops_from = {'source'},
})
```

## Grid Configuration

```lua
Grid.new({
  -- Required
  id = "unique_id",
  get_items = function() return items end,
  key = function(item) return item.id end,
  render_tile = function(ctx, rect, item, state, grid) end,

  -- Layout
  gap = 8,
  min_col_w = function() return 200 end,
  fixed_tile_h = 100,  -- or nil for auto

  -- Performance (for large datasets 1000+)
  virtual = true,  -- Enable virtual list mode
  virtual_buffer_rows = 2,  -- Extra rows above/below viewport

  -- Behaviors
  behaviors = { ... },

  -- External drops
  accept_external_drops = true,
  on_external_drop = function(insert_index) end,
  external_drag_check = function() return false end,

  -- Visual config
  config = {
    marquee = { fill_color = 0x..., stroke_color = 0x... },
    ghost = { enabled = true, opacity = 0.5 },
    dim = { fill_color = 0x..., stroke_color = 0x... },
    drop = { indicator_color = 0x..., indicator_thickness = 2 },
    drag = { threshold = 6 },
    spawn = { enabled = true, duration = 0.25 },
    destroy = { enabled = true, duration = 0.2 },
  },

  -- Input area extension
  extend_input_area = { left = 8, right = 8, top = 8, bottom = 8 },

  -- Exclusion zones (prevent clicks on controls)
  get_exclusion_zones = function(item, rect)
    return { {x1, y1, x2, y2}, ... }
  end,
})
```

## Virtual List Mode

For grids with 1000+ items, enable virtual list mode for optimal performance:

```lua
Grid.new({
  virtual = true,
  fixed_tile_h = 100,  -- Required for virtual mode
  virtual_buffer_rows = 2,  -- Optional: extra rows to pre-render (default: 2)
  -- ...
})
```

### How It Works

- Only calculates layout for visible items (plus buffer rows)
- Estimates total scroll height from `fixed_tile_h` and item count
- Teleports item positions directly (no animation)
- Marquee selection still works (calculates all rects when needed)

### Trade-offs

| Feature | Regular Mode | Virtual Mode |
|---------|-------------|--------------|
| Layout calculation | All items | Visible only |
| Position animation | Smooth transitions | Instant teleport |
| Spawn/destroy effects | Animated | None |
| Memory usage | Higher | Lower |
| Best for | < 500 items | 1000+ items |

### Requirements

- `fixed_tile_h` must be set (not nil)
- Items should have uniform heights

If `fixed_tile_h` is not set, virtual mode falls back to regular rendering.

## Naming Convention

Behavior names follow a consistent pattern:

- **Keyboard shortcuts**: Named after the input, not the action
  - `space`, `delete`, `f2` (not `play`, `remove`, `rename`)
  - Modifiers: `space:ctrl`, `space:shift`

- **Mouse behaviors**: Named after the input
  - `click:right`, `click:alt`
  - `wheel:ctrl`, `wheel:shift`, `wheel:alt`
  - `double_click`

This allows different grids to map the same input to different actions.

## Examples

### Audio Item Grid
```lua
behaviors = {
  space = function(grid, selected_keys) play_items(selected_keys) end,
  ['space:ctrl'] = function(grid, selected_keys) play_through_track(selected_keys) end,
  delete = function(grid, selected_keys) toggle_disabled(selected_keys) end,
  f = function(grid, selected_keys) toggle_favorite(selected_keys) end,
  f2 = function(grid, selected_keys) open_rename_dialog(selected_keys) end,
  ['click:right'] = function(grid, key, selected_keys) show_context_menu(key) end,
  wheel_cycle = function(grid, uuids, delta) cycle_variant(uuids[1], delta) end,
}
```

### Package Tile Grid
```lua
behaviors = {
  space = function(grid, selected_keys) toggle_active(selected_keys) end,
  delete = function(grid, selected_keys) remove_packages(selected_keys) end,
  ['click:right'] = function(grid, key, selected_keys) toggle_active_batch(selected_keys) end,
  ['double_click'] = function(grid, key) open_micromanage(key) end,
  ['wheel:ctrl'] = function(grid, target_key, delta) resize_tiles(delta) end,
}
```

### Region Playlist Grid
```lua
behaviors = {
  space = function(grid, selected_keys) play_region(selected_keys) end,
  delete = function(grid, selected_keys) remove_from_playlist(selected_keys) end,
  f2 = function(grid, selected_keys) batch_rename(selected_keys) end,
  ['click:right'] = function(grid, key, selected_keys) toggle_enabled(key) end,
  double_click_seek = function(grid, key) seek_to_region(key) end,
  start_inline_edit = function(grid, key) start_rename(key) end,
  on_inline_edit_complete = function(grid, key, new_text) apply_rename(key, new_text) end,
  reorder = function(grid, new_order) update_playlist_order(new_order) end,
}
```
