# Grid Rework: ImGui-Style API

> **Goal**: Migrate Grid from explicit retained mode to ImGui-style hidden state

---

## Current API (Explicit Retained)

```lua
-- 1. Create once (where? when? who stores it?)
local grid = Grid.new({
  id = "pool_grid",
  gap = 8,
  behaviors = create_behaviors(rt),
  render_tile = render_fn,
  key = function(item) return "pool_" .. item.rid end,
  get_items = function() return {} end,
  ...
})

-- 2. Store somewhere
rt.pool_grid = grid

-- 3. Draw every frame
rt.pool_grid:draw(ctx)

-- 4. Access state
local selected = rt.pool_grid.selection:selected_keys()

-- 5. Cleanup (often forgotten = memory leak)
-- rt.pool_grid:destroy() -- ???
```

**Problems:**
- User must manage lifecycle
- Where to store the grid object?
- When to create? (not in draw loop)
- Cleanup often forgotten
- Different pattern from simple widgets

---

## Target API (ImGui-Style Hidden State)

```lua
-- Every frame - just call it
local r = Ark.Grid(ctx, {
  id = "pool_grid",
  items = get_pool_items(),
  render = render_tile,
  key = function(item) return "pool_" .. item.rid end,

  -- Features enabled via opts
  selectable = true,
  draggable = true,
  reorderable = true,
})

-- Access state via result
if r.selection_changed then
  handle_selection(r.selected_keys)
end

if r.dropped then
  handle_drop(r.drop_target, r.dropped_items)
end

if r.reordered then
  handle_reorder(r.new_order)
end
```

**Benefits:**
- No lifecycle to manage
- No object to store
- Consistent with all Ark widgets
- Auto-cleanup after 30s of no access

---

## Config Caching Strategy

### Option A: User Caches Opts (Recommended)

```lua
-- Module level (created once)
local pool_opts = {
  id = "pool_grid",
  gap = 8,
  render = render_tile,
  key = function(item) return "pool_" .. item.rid end,
  selectable = true,
  draggable = true,
}

-- Every frame
function M.draw(ctx, items)
  pool_opts.items = items  -- Mutate cached table
  return Ark.Grid(ctx, pool_opts)
end
```

Zero allocations per frame. User controls caching.

### Option B: Grid Auto-Caches by ID

```lua
-- Frame 1: Full config stored by ID
Ark.Grid(ctx, {
  id = "pool_grid",
  render = render_tile,  -- Stored
  key = key_fn,          -- Stored
  items = items_v1,
})

-- Frame 2+: Only items needed, rest merged from cache
Ark.Grid(ctx, {
  id = "pool_grid",
  items = items_v2,
})
```

More magic, but even simpler for users. Could cause confusion if config "sticks" unexpectedly.

### Recommendation: Option A

User caches opts explicitly. Clear, no magic, zero overhead.

---

## Result Object

```lua
local r = Ark.Grid(ctx, opts)

-- Layout info
r.visible_count     -- number: items currently visible
r.total_count       -- number: total items
r.columns           -- number: current column count
r.scroll_y          -- number: current scroll position

-- Selection (if selectable = true)
r.selected_keys     -- table: currently selected keys
r.selection_changed -- boolean: selection changed this frame
r.clicked_key       -- string|nil: key that was clicked
r.double_clicked_key -- string|nil: key that was double-clicked

-- Drag (if draggable = true)
r.dragging          -- boolean: currently dragging
r.drag_keys         -- table: keys being dragged
r.dropped           -- boolean: drop occurred this frame
r.drop_target_key   -- string|nil: key of drop target
r.drop_index        -- number|nil: index where dropped

-- Reorder (if reorderable = true)
r.reordered         -- boolean: reorder occurred this frame
r.new_order         -- table: new key order

-- Inline edit
r.editing_key       -- string|nil: key being edited
r.edit_completed    -- boolean: edit finished this frame
r.edit_value        -- string|nil: new value from edit

-- Hover
r.hovered_key       -- string|nil: currently hovered key
```

---

## Behaviors Migration

### Current: Behaviors Object

```lua
Grid.new({
  behaviors = {
    drag_start = function(grid, item_keys) ... end,
    reorder = function(grid, new_order) ... end,
    ['click:right'] = function(grid, key, selected) ... end,
    f2 = function(grid, selected_keys) ... end,
  }
})
```

### Target: Callbacks in Opts

```lua
Ark.Grid(ctx, {
  on_drag_start = function(keys) ... end,
  on_reorder = function(new_order) ... end,
  on_right_click = function(key, selected) ... end,
  on_f2 = function(selected) ... end,

  -- OR: single handler with event type
  on_event = function(event_type, ...) ... end,
})
```

### Alternative: Poll via Result (ImGui-style)

```lua
local r = Ark.Grid(ctx, opts)

if r.right_clicked_key then
  show_context_menu(r.right_clicked_key, r.selected_keys)
end

if r.f2_pressed and #r.selected_keys > 0 then
  start_rename(r.selected_keys)
end
```

**Recommendation**: Support both callbacks AND polling via result.

---

## Migration Path

### Phase 1: Add ImGui-Style API (Parallel)

```lua
-- Old API still works
local grid = Grid.new(opts)
grid:draw(ctx)

-- New API added
local r = Ark.Grid(ctx, opts)
```

Both coexist. `Grid.new()` becomes thin wrapper.

### Phase 2: Migrate Apps

Update RegionPlaylist, ItemPicker, etc. to new API:

| App | File | Status |
|-----|------|--------|
| RegionPlaylist | `pool_grid_factory.lua` | TODO |
| RegionPlaylist | `active_grid_factory.lua` | TODO |
| ItemPicker | TBD | TODO |

### Phase 3: Deprecate Old API

```lua
function Grid.new(opts)
  Logger.warn_once("Grid.new() is deprecated, use Ark.Grid(ctx, opts)")
  -- ... shim to new implementation
end
```

### Phase 4: Remove Old API

Delete `Grid.new()`, keep only `Ark.Grid()`.

---

## ID Collision Prevention

### Auto-Generate from Call Location

```lua
function M.draw(ctx, opts)
  local id = opts.id
  if not id then
    local info = debug.getinfo(2, "Sl")
    id = info.source .. ":" .. info.currentline
  end
  -- ...
end
```

### Debug Warning

```lua
if DEBUG then
  local frame_grids = _G._ark_grid_frame_ids or {}
  if frame_grids[id] then
    Logger.warn("Ark.Grid: duplicate ID '%s' in frame - state will be shared!", id)
  end
  frame_grids[id] = true
  _G._ark_grid_frame_ids = frame_grids
end
```

### Clear Docs

Document that:
- Each Grid needs unique ID
- Same ID = shared state (intentional for some use cases)
- Use `opts.id` to disambiguate if needed

---

## Open Questions

1. **Should Grid auto-cache config by ID?** (Option B above)
   - Pro: Even simpler API
   - Con: Magic, config "sticks" unexpectedly

2. **Callback vs polling for events?**
   - Recommend: Both. Callbacks for convenience, polling always available.

3. **How to access selection state between frames?**
   - Store last result: `last_result = Ark.Grid(ctx, opts)`
   - Access: `last_result.selected_keys`

4. **Virtual scrolling API?**
   - Current: `get_items()` callback, Grid decides what to render
   - Target: Pass all items, Grid handles virtualization internally

---

## Files to Modify

| File | Changes |
|------|---------|
| `arkitekt/gui/widgets/containers/grid/core.lua` | Add `M.draw()` callable API |
| `arkitekt/gui/widgets/containers/grid/init.lua` | Export callable module |
| `arkitekt/loader.lua` | Register `Ark.Grid` |
| `scripts/RegionPlaylist/ui/tiles/pool_grid_factory.lua` | Migrate to new API |
| `scripts/RegionPlaylist/ui/tiles/active_grid_factory.lua` | Migrate to new API |
| `scripts/RegionPlaylist/ui/tiles/coordinator*.lua` | Update draw calls |

---

## Example: RegionPlaylist Pool Grid Migration

### Before

```lua
-- pool_grid_factory.lua
function M.create(rt, config)
  return Grid.new({
    id = "pool_grid",
    gap = PoolTile.CONFIG.gap,
    behaviors = create_behaviors(rt),
    render_tile = create_render_tile(rt, config),
    ...
  })
end

-- coordinator.lua
rt.pool_grid = PoolGridFactory.create(rt, config)

-- coordinator_render.lua
self.pool_grid:draw(ctx)
```

### After

```lua
-- pool_grid_config.lua
local M = {}

function M.create_opts(rt, config)
  return {
    id = "pool_grid",
    gap = PoolTile.CONFIG.gap,
    render = create_render_tile(rt, config),
    key = function(item)
      return item.id and ("pool_playlist_" .. item.id) or ("pool_" .. item.rid)
    end,
    selectable = true,
    draggable = true,
    reorderable = rt.allow_pool_reorder,
    on_drag_start = function(keys) ... end,
    on_reorder = function(order) ... end,
    on_right_click = function(key, selected) ... end,
  }
end

return M

-- coordinator.lua
local pool_opts = PoolGridConfig.create_opts(rt, config)

-- coordinator_render.lua
pool_opts.items = get_pool_items()
local r = Ark.Grid(ctx, pool_opts)

if r.right_clicked_key then
  rt._pool_context_keys = r.selected_keys
  rt._pool_context_visible = true
end
```

**Result**: No `Grid.new()`, no stored object, no lifecycle management.
