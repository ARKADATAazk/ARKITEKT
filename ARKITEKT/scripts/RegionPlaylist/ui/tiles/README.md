# Tile Rendering System

> Orchestrated tile rendering for active and pool grids

The tile system renders region and playlist tiles in two grids: the active playlist grid (top) and the pool/browser grid (bottom). It handles animations, drag-drop, selection, and per-frame optimizations.

---

## Architecture

```
ui/tiles/
├── coordinator.lua              → Main orchestrator (1235 lines)
│   - Creates and manages grid instances
│   - Per-frame caching (playlist lookups)
│   - Animation state management
│   - Height stabilization
│   - Bridge registration
│   - Rendering methods (draw_active, draw_pool, draw_ghosts)
│   - Context menu logic (SWS import, batch operations)
│
├── active_grid_factory.lua      → Active grid configuration (444 lines)
│   - Builds opts for active Grid widget
│   - Wires interaction callbacks
│   - Configures animations
│
├── pool_grid_factory.lua        → Pool grid configuration (334 lines)
│   - Builds opts for pool Grid widget
│   - Handles mixed regions/playlists
│   - Configures drag-to-active
│
├── selector.lua                 → Playlist selector dropdown
│   - Switches between playlists
│   - Smooth animation
│
├── tile_utilities.lua           → Shared tile utilities
│
└── renderers/
    ├── active.lua               → Active tile renderer
    │   - Renders region/playlist tiles
    │   - Hover effects, repeat badges
    │   - Enabled/disabled states
    │
    ├── pool.lua                 → Pool tile renderer
    │   - Renders browser tiles
    │   - Region count badges
    │
    └── base.lua                 → Shared rendering utilities
```

---

## Key Components

### Coordinator (coordinator.lua)

**Role:** Orchestrator that manages both grids and coordinates rendering.

**Responsibilities:**
- Create grid instances (active + pool)
- Manage per-frame caching (playlist lookups)
- Update animations (hover, spawn, destroy)
- Handle height stabilization (responsive sizing)
- Register grids with bridge (drag-drop coordination)
- Detect modal blocking state

**Pattern:** Object-oriented coordinator with split rendering methods.

**Key Methods:**
- `create(opts)` - Factory function that creates coordinator instance
- `set_layout_mode(mode)` - Switch between horizontal/vertical layouts
- `update_animations(dt)` - Update all animation states
- `draw_active()` - Render active grid with responsive sizing
- `draw_pool()` - Render pool grid with responsive sizing
- `draw_ghosts()` - Render drag ghosts with copy/delete indicators

**Per-Frame Caching:**
```lua
local playlist_cache = {}
local cache_frame_time = 0

local function cached_get_playlist_by_id(get_fn, playlist_id)
  local current_time = reaper.time_precise()

  -- Invalidate cache on new frame
  if current_time ~= cache_frame_time then
    playlist_cache = {}
    cache_frame_time = current_time
  end

  if not playlist_cache[playlist_id] then
    playlist_cache[playlist_id] = get_fn(playlist_id)
  end

  return playlist_cache[playlist_id]
end
```

This optimizes rendering when multiple tiles reference the same playlist (nested playlists).

---

### Factories (active_grid_factory.lua, pool_grid_factory.lua)

**Role:** Build Grid widget configuration objects (opts tables).

**Why Factories?**
- Grid configuration is complex (400+ lines of callbacks and options)
- Separates concerns: state management vs widget configuration
- Makes coordinator readable (delegates config building)
- Follows ARKITEKT opts-based API pattern

**Pattern:**
```lua
-- Coordinator calls factory each frame
local opts = ActiveGridFactory.create_opts(self, self.config)
local result = Ark.Grid(ctx, opts)

-- Factory returns fresh opts table
return {
  id = "active_grid",
  items = rt._active_items,
  behaviors = create_behaviors(rt),
  render_item = create_render_tile(rt, tile_config),
  -- ... 30+ more options
}
```

**Key Configuration:**
- `items` - Array of tile data (from state)
- `behaviors` - Callback table (drag, drop, reorder, select, delete, etc.)
- `render_item` - Tile rendering function
- `config` - Animation and visual config (spawn, destroy, dim, ghost)
- `min_col_w` - Column width function (changes with layout mode)
- `fixed_tile_h` - Tile height (responsive per frame)

---

### Renderers (renderers/active.lua, renderers/pool.lua)

**Role:** Draw individual tiles to ImGui draw lists.

**Pattern:** Stateless rendering functions that take opts table.

**Active Tile Renderer:**
```lua
function M.render(ctx, rect, item, state, get_region_by_rid, animator,
                  on_repeat_cycle, hover_config, tile_height, border_thickness,
                  bridge, get_playlist_by_id, grid)
  -- Render region or playlist tile
  -- Show hover effects, repeat badges, enabled/disabled states
  -- Draw repeat cycle button
  -- Handle playlist nesting indicators
end
```

**Pool Tile Renderer:**
```lua
function M.render(ctx, rect, item, state, get_region_by_rid, animator,
                  hover_config, tile_height, border_thickness, get_playlist_by_id)
  -- Render browser tile (region or playlist)
  -- Show region count badges for playlists
  -- Simpler than active tiles (no repeat controls)
end
```

**Rendering Flow:**
```
Grid widget iterates items
  → Calls render_item(ctx, rect, item, state, grid)
  → Factory's render_item wrapper adds context (animator, config, etc.)
  → Calls ActiveTile.render() or PoolTile.render()
  → Renderer draws to ImGui draw list
```

---

## Data Flow

### Frame Rendering Flow

```
1. GUI:draw(ctx, window, shell_state)
   ↓
2. layout_view:draw(ctx, region_tiles, shell_state)
   ↓ (decides horizontal or vertical layout)
   ↓
3. region_tiles:draw_active(ctx, playlist, height, shell_state)
   ↓ (calculates responsive tile height)
   ↓
4. ActiveGridFactory.create_opts(self, self.config)
   ↓ (builds opts with behaviors, render_item, etc.)
   ↓
5. Ark.Grid(ctx, opts)
   ↓ (Grid widget processes items)
   ↓
6. For each item: opts.render_item(ctx, rect, item, state, grid)
   ↓
7. ActiveTile.render() draws tile to draw list
```

### Interaction Flow (Drag-Drop)

```
1. User drags tile from pool grid
   ↓
2. Grid calls behaviors.drag_start(grid, item_keys)
   ↓
3. Factory's drag_start calls bridge:start_drag('pool', payload)
   ↓
4. Bridge stores drag state
   ↓
5. User drops over active grid
   ↓
6. Grid detects external drop
   ↓
7. Calls on_external_drop(insert_index)
   ↓
8. Factory handler calls bridge:handle_drop('active', insert_index)
   ↓
9. Bridge calls on_cross_grid_drop callback
   ↓
10. Coordinator calls controller:add_item(rid, insert_index)
    ↓
11. Controller modifies state, commits, invalidates bridge
    ↓
12. Next frame: Grid renders with new item (spawn animation)
```

---

## Responsive Sizing

### Height Stabilization

Tiles use responsive height calculation to fit available space:

```lua
-- Calculate ideal height for current item count
local raw_height = ResponsiveGrid.calculate_responsive_tile_height({
  item_count = #items,
  avail_width = child_w,
  avail_height = child_h,
  base_tile_height = 72,
  min_tile_height = 20,
})

-- Stabilize to prevent jitter (requires N stable frames)
local responsive_height = height_stabilizer:update(raw_height)
```

**Why Stabilize?**
- Raw height can fluctuate frame-to-frame (layout changes, window resize)
- Jitter is distracting and hurts UX
- Stabilizer requires 2-3 consecutive frames of same height before committing

### Column Width (Layout Modes)

**Horizontal/Timeline Mode:**
```lua
min_col_w = function() return ActiveTile.CONFIG.tile_width end  -- 200px
-- Result: Multiple columns
```

**Vertical/List Mode:**
```lua
min_col_w = function() return 9999 end  -- Force single column
-- Result: One wide column
```

Coordinator's `set_layout_mode()` updates the min_col_w function:

```lua
function Coordinator:set_layout_mode(mode)
  self.layout_mode = mode
  if mode == 'vertical' then
    self._active_min_col_w_fn = function() return 9999 end
  else
    self._active_min_col_w_fn = function() return ActiveTile.CONFIG.tile_width end
  end

  -- Update grid instance directly for immediate effect
  if self.active_grid and self.active_grid.min_col_w_fn then
    self.active_grid.min_col_w_fn = self._active_min_col_w_fn
  end
end
```

---

## Animation System

### Animation Types

**Spawn Animation:**
- Triggered when new items added to active grid
- Fade in + scale up effect
- Managed by Grid widget's spawn config

**Destroy Animation:**
- Triggered when items deleted
- Fade out + scale down effect
- Items marked as destroyed, then removed after animation completes

**Hover Animation:**
- Smooth brightness/border lerp on mouse hover
- Managed by TileAnimator
- Per-tile state tracked by coordinator

**Spawn Flow:**
```
1. User drops region from pool to active
   ↓
2. Controller adds item, returns key
   ↓
3. State.add_pending_spawn(key)
   ↓
4. Next frame: GUI.update_state() processes pending_spawn
   ↓
5. Calls active_grid:mark_spawned([key])
   ↓
6. Grid triggers spawn animation for that tile
   ↓
7. Tile renders with spawn effect (fade/scale)
```

---

## Coordinator Responsibilities Breakdown

### Creation & Initialization
- Create grid instances (via factories)
- Initialize animators (TileAnimator for hover effects)
- Initialize height stabilizers (prevent jitter)
- Register grids with bridge (for drag-drop coordination)

### Per-Frame Updates
- Update animations (selector, hover states)
- Cache playlist lookups (per-frame cache invalidation)
- Calculate responsive tile heights
- Build opts for grids (via factories)
- Render grids (draw_active, draw_pool, draw_ghosts)

### State Management
- Track active/pool bounds (for bridge mouse detection)
- Track modal blocking state
- Store grid references (for external access)
- Manage wheel consumption (repeat adjustment)

### Bridge Integration
- Register grids with GridBridge
- Provide drag payload extraction
- Handle cross-grid drops
- Compute copy/delete modes

---

## Grid Configuration Deep Dive

### Active Grid Config (Highlights)

```lua
{
  id = "active_grid",
  gap = 12,
  min_col_w = function() return 200 end,  -- or 9999 for vertical
  fixed_tile_h = 72,  -- responsive
  items = playlist.items,
  key = function(item) return item.key end,

  -- Interaction behaviors
  behaviors = {
    drag_start = ...,
    ['click:right'] = ...,  -- Toggle enabled
    delete = ...,
    reorder = ...,
    on_select = ...,
    start_inline_edit = ...,  -- Double-click name
    on_inline_edit_complete = ...,
    double_click_seek = ...,  -- Double-click tile body
    f2 = ...,  -- Batch rename
  },

  -- External drag-drop
  accept_external_drops = true,
  external_drag_check = function() ... end,
  on_external_drop = function(insert_index) ... end,
  is_copy_mode_check = function() ... end,

  -- Rendering
  render_item = function(ctx, rect, item, state, grid) ... end,

  -- Animations
  config = {
    spawn = { enabled = true, duration = 0.3 },
    destroy = { enabled = true },
    dim = { fill_color = ..., stroke_color = ... },
    ghost = { ... },
    drop = { ... },
  },
}
```

### Pool Grid Config (Highlights)

```lua
{
  id = "pool_grid",
  gap = 12,
  min_col_w = function() return 200 end,
  fixed_tile_h = 72,
  items = filtered_regions,  -- or playlists, or mixed
  key = pool_key,  -- "pool_123" or "pool_playlist_abc"

  -- Interaction behaviors
  behaviors = {
    drag_start = ...,
    on_select = ...,
    double_click = ...,  -- Add to active
    ['click:right'] = ...,  -- Context menu
    f2 = ...,  -- Batch rename
  },

  -- No reordering by default (unless allow_pool_reorder = true)
  -- No external drops accepted

  -- Rendering (handles both regions and playlists)
  render_item = function(ctx, rect, item, state, grid) ... end,
}
```

---

## Performance Optimizations

### Per-Frame Caching
- Playlist lookups cached per frame (invalidated via time_precise())
- Prevents redundant queries when multiple tiles reference same playlist

### Config Caching
- TileFXConfig.begin_frame() caches theme colors per frame
- Reduces theme lookups from 100+ to 1 per frame

### Height Stabilization
- Prevents unnecessary layout recalculations
- Reduces jitter and improves perceived performance

### Lazy Grid Updates
- Grid widget only updates on actual state changes
- Selection, hover, drag state tracked efficiently

---

## Common Tasks

### Add a New Tile Type

1. **Define in constants:**
```lua
-- defs/constants.lua
ITEM_TYPES = {
  REGION = "region",
  PLAYLIST = "playlist",
  MY_NEW_TYPE = "my_type",
}
```

2. **Handle in renderer:**
```lua
-- renderers/active.lua or pool.lua
function M.render(ctx, rect, item, state, ...)
  if item.type == "my_type" then
    -- Render my custom tile
  elseif item.type == "region" then
    -- Existing region tile
  end
end
```

3. **Update factory if needed:**
```lua
-- active_grid_factory.lua
-- Add behaviors for new type
```

### Add a New Interaction Behavior

1. **Define behavior in factory:**
```lua
-- active_grid_factory.lua
local function create_behaviors(rt)
  return {
    -- ... existing behaviors

    my_new_behavior = function(grid, key, selected_keys)
      -- Handle behavior
      if rt.on_my_action then
        rt.on_my_action(key)
      end
    end,
  }
end
```

2. **Wire callback in coordinator:**
```lua
-- coordinator.lua
M.create({
  -- ... other opts

  on_my_action = function(key)
    -- Handle in app layer
    controller:do_something(key)
  end,
})
```

### Modify Tile Appearance

**Colors/Theme:**
```lua
-- defs/palette.lua or defs/defaults.lua
TILE_COLORS = {
  background = hexrgba("#1e1e2e"),
  hover = hexrgba("#313244"),
  selected = hexrgba("#89b4fa"),
}
```

**Sizes:**
```lua
-- renderers/active.lua or pool.lua
M.CONFIG = {
  tile_width = 200,
  gap = 12,
  border_thickness = 1,
  rounding = 6,
}
```

**Hover Effects:**
```lua
-- defs/defaults.lua
hover = {
  animation_speed = 0.15,
  brightness_factor = 1.4,
  border_lerp = 0.7,
}
```

---

## Debugging

### Enable Debug Logging

```lua
-- coordinator.lua (top of file)
local DEBUG_COORDINATOR = true

-- Then check console for:
-- "COORDINATOR: Processing pending spawn [key]"
-- "COORDINATOR: Grid reference stored"
```

### Check Grid State

```lua
-- In REAPER Developer Console:
local State = require('RegionPlaylist.app.state')
local gui = State.gui  -- If GUI stored in state

-- Check grid references
print("Active grid:", gui.region_tiles.active_grid)
print("Pool grid:", gui.region_tiles.pool_grid)

-- Check selection
if gui.region_tiles.active_grid then
  local sel = gui.region_tiles.active_grid.selection
  print("Selected:", table.concat(sel:selected_keys(), ", "))
end
```

### Trace Rendering Flow

Add temporary logs:

```lua
-- coordinator.lua draw_active()
Logger.debug("RENDER", "draw_active: %d items, height=%d", #playlist.items, height)

-- active_grid_factory.lua create_opts()
Logger.debug("FACTORY", "create_opts: min_col_w=%d, tile_h=%d",
  rt._active_min_col_w_fn(), rt._active_tile_height)
```

---

## See Also

- **Main README** - App architecture overview
- **cookbook/WIDGETS.md** - ARKITEKT Grid widget API
- **coordinator.lua** - Main orchestrator implementation
- **active_grid_factory.lua** - Active grid configuration details
- **pool_grid_factory.lua** - Pool grid configuration details
- **renderers/active.lua** - Tile rendering implementation
