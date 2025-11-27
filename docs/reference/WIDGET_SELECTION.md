# Widget Selection Guide

> When to use Panel, Grid, or TileGroup for your ARKITEKT application.

---

## Quick Decision Tree

```
Need to display items?
├─ Fixed layout (forms, toolbars) → Panel
├─ List/grid of similar items → Grid
│   └─ Items need grouping? → Grid + TileGroup
└─ Custom arrangement → Panel with manual layout
```

---

## Container Comparison

| Feature | Panel | Grid | TileGroup |
|---------|-------|------|-----------|
| **Purpose** | General container | Tile-based item display | Group headers for Grid |
| **Layout** | Manual (you control) | Automatic (responsive columns) | Integrates with Grid |
| **Scrolling** | Built-in | Built-in | Via parent Grid |
| **Selection** | Manual | Built-in (multi-select, marquee) | Via parent Grid |
| **Drag & Drop** | Manual | Built-in (reorder, cross-grid) | Via parent Grid |
| **Best for** | Forms, sidebars, toolbars | Item browsers, playlists | Categorized items |

---

## Panel

### When to Use

- **General container** with toolbars, headers, or footers
- **Forms and settings** with labels and inputs
- **Sidebars** with navigation or tools
- **Custom layouts** where you control element positioning
- **Scrollable content** that isn't a list of similar items

### Key Features

- Configurable toolbars (top, bottom, left, right)
- Built-in scrolling with custom scrollbar
- Background patterns and theming
- Tab support in header
- Corner buttons
- Overlay toolbars (hover-reveal)

### Basic Usage

```lua
local Panel = require('arkitekt.gui.widgets.containers.panel')

local my_panel = Panel.new({
  id = "my_panel",
  width = 300,
  height = 400,
  config = {
    padding = 8,
    rounding = 4,
    -- Top toolbar with tabs
    toolbars = {
      top = {
        height = 30,
        tabs = my_tabs,
        search = true,
      }
    }
  }
})

-- In render loop
if my_panel:begin_draw(ctx) then
  -- Your content here
  ImGui.Text(ctx, "Panel content")
end
my_panel:end_draw(ctx)
```

### Configuration Options

```lua
config = {
  -- Dimensions
  padding = 8,
  rounding = 4,
  border_thickness = 1,

  -- Colors (optional - uses theme defaults)
  bg_color = 0x1A1A1AFF,
  border_color = 0x333333FF,

  -- Toolbars
  toolbars = {
    top = { height = 30, tabs = {...}, search = true },
    bottom = { height = 24, elements = {...} },
    left = { width = 36, elements = {...} },
    right = { width = 36, elements = {...} },
  },

  -- Background pattern
  background_pattern = {
    enabled = true,
    primary = { type = "dots", spacing = 20 },
  },

  -- Scrolling
  scroll = {
    flags = ImGui.WindowFlags_None,
  },
}
```

---

## Grid

### When to Use

- **Item browsers** (files, samples, presets)
- **Playlists** (regions, markers, cues)
- **Tile displays** (packages, thumbnails)
- **Any list** with selection, reordering, or keyboard navigation

### Key Features

- Responsive column layout (auto-calculates columns from available width)
- Selection system (click, shift-click, ctrl-click, marquee)
- Keyboard shortcuts (delete, space, enter, F2, etc.)
- Drag and drop (reorder within grid, cross-grid transfers)
- Virtual mode for large datasets (1000+ items)
- Spawn/destroy animations
- Inline editing

### Basic Usage

```lua
local Grid = require('arkitekt.gui.widgets.containers.grid.core')

local my_grid = Grid.new({
  id = "my_grid",
  gap = 8,
  min_col_w = function() return 200 end,
  fixed_tile_h = 80,

  -- Data source
  get_items = function() return items end,
  key = function(item) return item.id end,

  -- Rendering
  render_tile = function(ctx, rect, item, state, grid)
    local dl = ImGui.GetWindowDrawList(ctx)
    local x1, y1, x2, y2 = rect.x1, rect.y1, rect.x2, rect.y2

    -- Background
    local bg = state.selected and 0x3A3A3AFF or 0x252525FF
    ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, bg, 4)

    -- Content
    ImGui.DrawList_AddText(dl, x1 + 8, y1 + 8, 0xFFFFFFFF, item.name)
  end,

  -- Behaviors
  behaviors = {
    space = function(grid, selected_keys) play_items(selected_keys) end,
    delete = function(grid, selected_keys) delete_items(selected_keys) end,
    ['click:right'] = function(grid, key, selected_keys)
      show_context_menu(key, selected_keys)
    end,
  },
})

-- In render loop
my_grid:draw(ctx)
```

### Configuration Options

```lua
Grid.new({
  -- Identity
  id = "unique_id",

  -- Layout
  gap = 8,
  min_col_w = function() return 200 end,  -- Function for responsive sizing
  fixed_tile_h = 100,  -- Required for virtual mode

  -- Data
  get_items = function() return items end,
  key = function(item) return item.id end,
  render_tile = function(ctx, rect, item, state, grid) end,

  -- Performance
  virtual = true,  -- Enable for 1000+ items
  virtual_buffer_rows = 2,

  -- Behaviors
  behaviors = {
    space = function(grid, selected_keys) end,
    delete = function(grid, selected_keys) end,
    f2 = function(grid, selected_keys) end,
    ['click:right'] = function(grid, key, selected_keys) end,
    ['double_click'] = function(grid, key) end,
    reorder = function(grid, new_order) end,
  },

  -- Custom shortcuts
  shortcuts = {
    { key = ImGui.Key_P, name = 'preview' },
    { key = ImGui.Key_R, ctrl = true, name = 'refresh' },
  },

  -- External drops (from outside the grid)
  accept_external_drops = true,
  on_external_drop = function(insert_index) end,

  -- Visual config
  config = {
    marquee = { fill_color = 0x4488FF33, stroke_color = 0x4488FFFF },
    ghost = { enabled = true, opacity = 0.5 },
    drop = { indicator_color = 0x44FF44FF, indicator_thickness = 2 },
    spawn = { enabled = true, duration = 0.25 },
  },
})
```

### Default Keyboard Shortcuts

| Key | Behavior Name | Default Action |
|-----|---------------|----------------|
| Space | `space` | (user-defined) |
| Delete | `delete` | (user-defined) |
| F2 | `f2` | (user-defined) |
| Enter | `enter` | (user-defined) |
| Escape | `escape` | Clear selection |
| Ctrl+A | `select_all` | Select all items |
| Ctrl+D | `deselect_all` | Deselect all |
| Ctrl+I | `invert_selection` | Invert selection |
| Ctrl+Z | `undo` | (user-defined) |
| Ctrl+Shift+Z | `redo` | (user-defined) |

### Default Mouse Behaviors

| Input | Behavior Name | Fallback |
|-------|---------------|----------|
| Right-click | `click:right` | - |
| Alt+click | `click:alt` | `delete` |
| Double-click | `double_click` | `double_click_seek` |
| Ctrl+wheel | `wheel:ctrl` | `wheel_resize` vertical |
| Shift+wheel | `wheel:shift` | `wheel_cycle` |
| Alt+wheel | `wheel:alt` | `wheel_resize` horizontal |

---

## TileGroup

### When to Use

- **Categorized items** in a Grid (by type, folder, tag)
- **Collapsible sections** within a tile display
- **Visual grouping** with colored headers

### Key Features

- Collapsible group headers
- Colored group indicators
- Integrates seamlessly with Grid
- Automatic item flattening for Grid consumption

### How It Works

TileGroup adds structure to Grid by:
1. Wrapping items with group metadata
2. Injecting group header "items" into the flat list
3. Providing header rendering and collapse logic

### Basic Usage

```lua
local Grid = require('arkitekt.gui.widgets.containers.grid.core')
local TileGroup = require('arkitekt.gui.widgets.containers.tile_group')

-- Create groups
local groups = {
  TileGroup.create_group({
    id = "favorites",
    name = "Favorites",
    color = "#FFD700",
    collapsed = false,
    items = favorite_items
  }),
  TileGroup.create_group({
    id = "recent",
    name = "Recent",
    color = "#4488FF",
    collapsed = false,
    items = recent_items
  }),
}

-- Ungrouped items
local ungrouped = other_items

-- Create grid with grouped items
local grid = Grid.new({
  id = "grouped_grid",
  -- ...

  get_items = function()
    return TileGroup.flatten_groups(groups, ungrouped)
  end,

  key = function(item)
    if TileGroup.is_group_header(item) then
      return "header_" .. item.__group_id
    end
    return item.id
  end,

  render_tile = function(ctx, rect, item, state, grid)
    if TileGroup.is_group_header(item) then
      -- Render group header
      local clicked = TileGroup.render_header(ctx, rect, item, state)
      if clicked then
        TileGroup.toggle_group(item)
      end
    else
      -- Render regular tile
      render_regular_tile(ctx, rect, item, state)
    end
  end,
})
```

### Auto-Grouping

Group items automatically by a property:

```lua
local groups, ungrouped = TileGroup.organize_items(all_items, function(item)
  if item.folder then
    return {
      id = item.folder,
      name = item.folder,
      color = folder_colors[item.folder],
    }
  end
  return nil  -- Ungrouped
end)
```

### Group Control

```lua
-- Collapse/expand all
TileGroup.collapse_all(groups)
TileGroup.expand_all(groups)

-- Find specific group
local group = TileGroup.find_group(groups, "favorites")

-- Check item type
if TileGroup.is_grouped_item(item) then
  local original = TileGroup.get_original_item(item)
  local group_id = TileGroup.get_group_id(item)
end
```

---

## Cross-Grid Drag & Drop (GridBridge)

### When to Use

- **Transfer items** between two grids
- **Copy/move operations** with modifier key detection
- **Multi-grid layouts** (source/target panels)

### Basic Usage

```lua
local GridBridge = require('arkitekt.gui.widgets.containers.grid.grid_bridge')

local bridge = GridBridge.new({
  on_cross_grid_drop = function(drop_info)
    local source = drop_info.source_grid
    local target = drop_info.target_grid
    local payload = drop_info.payload
    local index = drop_info.insert_index
    local is_copy = drop_info.is_copy_mode

    if is_copy then
      copy_items(payload, target, index)
    else
      move_items(payload, source, target, index)
    end
  end,

  copy_mode_detector = function(source_id, target_id, payload)
    return ImGui.IsKeyDown(ctx, ImGui.Key_LeftCtrl)
  end,
})

-- Register grids
bridge:register_grid('library', library_grid, {
  accepts_drops_from = {},  -- Can't receive drops
  on_drag_start = function(item_keys)
    bridge:start_drag('library', build_payload(item_keys))
  end,
})

bridge:register_grid('playlist', playlist_grid, {
  accepts_drops_from = {'library'},  -- Accepts from library
  on_drag_start = function(item_keys)
    bridge:start_drag('playlist', build_payload(item_keys))
  end,
})
```

---

## Decision Examples

### Audio Sample Browser

**Choice: Grid**

- Displays many similar items
- Needs selection, preview, add to project
- Benefits from keyboard shortcuts (space=preview)

```lua
Grid.new({
  render_tile = render_sample_tile,
  behaviors = {
    space = preview_sample,
    enter = add_to_project,
    delete = remove_from_favorites,
  },
})
```

### Plugin Settings Panel

**Choice: Panel**

- Mixed content (labels, sliders, checkboxes)
- Custom layout requirements
- Not a list of similar items

```lua
local panel = Panel.new({
  config = { padding = 12, toolbars = { top = { height = 30 } } }
})

if panel:begin_draw(ctx) then
  ImGui.Text(ctx, "Volume")
  ImGui.SliderFloat(ctx, "##vol", volume, 0, 1)
  ImGui.Text(ctx, "Pan")
  ImGui.SliderFloat(ctx, "##pan", pan, -1, 1)
end
panel:end_draw(ctx)
```

### Categorized Preset Browser

**Choice: Grid + TileGroup**

- Items grouped by category
- Collapsible sections
- Selection and preview

```lua
local groups = organize_presets_by_category(presets)

Grid.new({
  get_items = function() return TileGroup.flatten_groups(groups) end,
  render_tile = function(ctx, rect, item, state, grid)
    if TileGroup.is_group_header(item) then
      TileGroup.render_header(ctx, rect, item, state)
    else
      render_preset_tile(ctx, rect, item, state)
    end
  end,
})
```

### Playlist with Source Panel

**Choice: Two Grids + GridBridge**

- Source grid (library) on left
- Target grid (playlist) on right
- Drag from library to playlist

```lua
-- Left panel: Library grid
local library_grid = Grid.new({ id = "library", ... })

-- Right panel: Playlist grid
local playlist_grid = Grid.new({ id = "playlist", ... })

-- Bridge for drag-drop
local bridge = GridBridge.new({
  on_cross_grid_drop = handle_transfer,
})

bridge:register_grid('library', library_grid, { accepts_drops_from = {} })
bridge:register_grid('playlist', playlist_grid, { accepts_drops_from = {'library'} })
```

---

## See Also

- [WIDGETS.md](../../cookbook/WIDGETS.md) - Widget development guide
- [Grid README](../../ARKITEKT/arkitekt/gui/widgets/containers/grid/README.md) - Full Grid API
- [Panel defaults](../../ARKITEKT/arkitekt/gui/widgets/containers/panel/defaults.lua) - Panel configuration
