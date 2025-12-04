# ArkContext Architecture

**Priority:** HIGH
**Created:** 2025-12-03
**Status:** COMPLETE

## Summary

`ArkContext` (`actx`) wraps/pairs with ImGui's `ctx`, providing ARKITEKT-specific frame state and cached values. This eliminates per-widget optimization needs - widgets automatically benefit from centralized caching.

## Naming

- **`ArkContext`** - Full name, mirrors ImGui's context pattern
- **`actx`** - Short form, parallels `ctx`
- Relationship: `ctx` (ImGui) <-> `actx` (ARKITEKT)

## Implementation

**Location:** `arkitekt/core/context.lua`

### Core API

```lua
local Context = require('arkitekt.core.context')
local actx = Context.get(ctx)

-- Or via Ark namespace (eager-loaded):
local actx = Ark.GetContext(ctx)
local actx = Ark.Context.get(ctx)
```

### Available Properties & Methods

```lua
-- Core
actx.ctx              -- Raw ImGui context
actx.frame            -- Current frame number
actx.time             -- reaper.time_precise() (sampled once per frame)

-- Draw Lists (lazy, cached per-frame)
actx:draw_list()          -- GetWindowDrawList (call AFTER Begin)
actx:foreground_draw_list()
actx:background_draw_list()

-- Input (lazy, cached per-frame)
actx:mouse_pos()      -- x, y screen coordinates
actx:delta_time()     -- Time since last frame

-- ID Stack (delegates to arkitekt.core.id_stack)
actx:push_id(id)
actx:pop_id()
actx:resolve_id(base_id)
actx:id_depth()

-- Per-Frame Memoization
actx:cache(key, compute_fn)  -- Compute once per frame, reuse
actx:clear_cache(key)        -- Force recomputation (rare)
```

### User API

**No change!** Users continue to pass `ctx`:

```lua
function my_app:draw(ctx)
  if Ark.Button(ctx, 'Save') then ... end
  Ark.Badge(ctx, { x = 10, y = 10, text = '5' })
end
```

Internally, widgets call `Ark.GetContext(ctx)` to get cached state.

## Widget Migration Example

```lua
-- Before (current):
function M.Text(ctx, opts)
  opts = Base.parse_opts(opts, M.DEFAULTS)
  local dl = opts.draw_list or ImGui.GetWindowDrawList(ctx)
  -- ...
end

-- After (with ArkContext):
function M.Text(ctx, opts)
  local actx = Ark.GetContext(ctx)
  opts = Base.parse_opts(opts, M.DEFAULTS)
  local dl = opts.draw_list or actx:draw_list()
  local dt = actx:delta_time()
  -- ...
end
```

## Per-Frame Memoization Example

```lua
-- Expensive computation done once per frame, reused by all widgets
function M.Draw(ctx, opts)
  local actx = Ark.GetContext(ctx)

  -- Gradient computed once per frame, reused 100+ times
  local gradient = actx:cache('hue_gradient', function()
    return compute_hue_gradient()
  end)

  -- Use cached gradient
  draw_with_gradient(gradient)
end
```

## Benefits

| Aspect | Before | After |
|--------|--------|-------|
| Per-widget optimization | Required for each | Automatic |
| Draw list | `GetWindowDrawList` per call | Cached |
| Frame time | `time_precise()` per call | Cached |
| Mouse position | `GetMousePos` per call | Cached |
| New widget effort | Must copy optimization patterns | Just use `actx.*` |
| Code complexity | Scattered caching | Centralized |

## Migration Path

- [x] **Phase 1:** Create ArkContext core (`arkitekt/core/context.lua`)
- [x] **Phase 2:** Expose `Ark.GetContext(ctx)` and `Ark.Context`
- [x] **Phase 3:** Update `Base.get_draw_list()` to use ArkContext
- [x] **Phase 4:** Migrate ALL widgets to use ArkContext (~48 locations across 28 files)
- [x] **Phase 5:** Update widget authoring docs (see `cookbook/ARKCONTEXT.md`)

## Architecture

```
                    +-------------------+
                    |   _contexts       |
                    | (weak table)      |
                    +--------+----------+
                             |
         ctx1 ---------------+----------> actx1
         ctx2 ---------------+----------> actx2
                             |
                    +--------v----------+
                    |   ArkContext      |
                    +-------------------+
                    | ctx               |
                    | frame             |
                    | time              |
                    | _draw_list        |
                    | _mouse_x/y        |
                    | _delta_time       |
                    | _cache            |
                    +-------------------+
                    | :draw_list()      |
                    | :mouse_pos()      |
                    | :delta_time()     |
                    | :cache(k, fn)     |
                    | :push_id(id)      |
                    | :pop_id()         |
                    | :resolve_id(id)   |
                    +-------------------+
```

## Considerations

- **Multiple imgui contexts:** Handled naturally (one actx per ctx)
- **Context cleanup:** Weak table keys - GC handles it automatically
- **Thread safety:** Not an issue (Lua single-threaded)
- **Backwards compatibility:** 100% - user API unchanged
- **Naming clarity:** `actx` parallels `ctx`, intuitive for community

## Credit

Architecture discussion with BenTalagan - the "ark_ctx wrapping imgui_ctx" insight.
