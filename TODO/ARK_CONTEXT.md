# ArkContext Architecture

**Priority:** HIGH
**Created:** 2025-12-03
**Status:** Planned

## Summary

Implement an `ArkContext` (`actx`) system that wraps/pairs with ImGui's `ctx`, providing ARKITEKT-specific frame state, pre-computed config, and cached values. This eliminates per-widget optimization needs - widgets automatically benefit from centralized caching.

## Naming

- **`ArkContext`** - Full name, mirrors ImGui's context pattern
- **`actx`** - Short form, parallels `ctx`
- Relationship: `ctx` (ImGui) ↔ `actx` (ARKITEKT)

## Problem

Currently, each widget must be individually optimized:
- Localize functions at module level
- Cache config lookups via `_frame_config`
- Reuse result tables to avoid allocations
- Pre-compute values per frame

This is repetitive, error-prone, and requires optimizing every widget separately.

## Solution

Create an `ArkContext` that:
1. Is looked up from `ctx` via a mapping table (one hash lookup)
2. Refreshes once per frame (detected via `GetFrameCount`)
3. Holds all pre-computed config, cached values, draw list, palette, etc.
4. Is used by all widgets internally

### API Design (Internal)

```lua
-- Lookup/create context (one table lookup per call)
local actx = Ark.GetContext(ctx)  -- or Ark.actx(ctx)

-- Access pre-computed values
local cfg = actx.config          -- All widget configs
local dl = actx.draw_list        -- Cached draw list
local palette = actx.palette     -- Theme colors
local time = actx.time           -- Frame time
local frame = actx.frame         -- Frame count
```

### User API

**No change!** Users continue to pass `ctx`:

```lua
function my_app:draw(ctx)
  if Ark.Button(ctx, 'Save') then ... end
  Ark.Badge(ctx, { x = 10, y = 10, text = '5' })
end
```

Internally, widgets call `Ark.GetContext(ctx)` to get the cached state.

## Implementation

### Core Structure

```lua
-- arkitekt/core/context.lua

local M = {}

local _contexts = setmetatable({}, { __mode = 'k' })  -- Weak keys for cleanup

function M.get(ctx)
  local actx = _contexts[ctx]
  if not actx then
    actx = M.create(ctx)
    _contexts[ctx] = actx
  end

  -- Refresh if new frame
  local frame = ImGui.GetFrameCount(ctx)
  if actx.frame ~= frame then
    actx:refresh(ctx)
    actx.frame = frame
  end

  return actx
end

function M.create(ctx)
  return {
    ctx = ctx,              -- Reference to imgui context
    frame = -1,
    draw_list = nil,
    config = {},            -- Pre-computed widget configs
    palette = {},           -- Theme colors
    time = 0,
    -- ... other cached state
  }
end

function M:refresh(ctx)
  self.draw_list = ImGui.GetWindowDrawList(ctx)
  self.time = reaper.time_precise()
  -- Refresh config, palette, etc.
end

return M
```

### Widget Usage

```lua
-- Before (current):
function M.Text(ctx, opts)
  opts = Base.parse_opts(opts, M.DEFAULTS)
  local dl = opts.draw_list or ImGui.GetWindowDrawList(ctx)
  local padding_x = opts.padding_x  -- Metatable lookup
  -- ...
end

-- After (with ArkContext):
function M.Text(ctx, opts)
  local actx = Ark.GetContext(ctx)
  opts = Base.parse_opts(opts, M.DEFAULTS)
  local dl = opts.draw_list or actx.draw_list
  local cfg = actx.config.badge
  -- Use cfg.padding_x, cfg.rounding, etc. directly
end
```

## Benefits

| Aspect | Before | After |
|--------|--------|-------|
| Per-widget optimization | Required for each | Automatic |
| Config access | Metatable/lookup chain | Direct table access |
| Draw list | `GetWindowDrawList` per call | Cached |
| New widget effort | Must copy optimization patterns | Just use `actx.*` |
| Code complexity | Scattered caching | Centralized |

## Migration Path

1. **Phase 1:** Create ArkContext core (`arkitekt/core/context.lua`)
2. **Phase 2:** Add `Ark.GetContext(ctx)` / `Ark.actx(ctx)` helper
3. **Phase 3:** Migrate Badge to use ArkContext (test case)
4. **Phase 4:** Migrate other hot-path widgets
5. **Phase 5:** Update widget authoring docs

## Considerations

- **Multiple imgui contexts:** Handled naturally (one actx per ctx)
- **Context cleanup:** Use weak table keys - GC handles it
- **Thread safety:** Not an issue (Lua single-threaded)
- **Backwards compatibility:** 100% - user API unchanged
- **Naming clarity:** `actx` parallels `ctx`, intuitive for community

## Related

- Current `_frame_config` pattern in `base.lua`
- Badge optimization work (2025-12-03)
- BenTalagan's "bentô box" / context pattern suggestion

## Credit

Architecture discussion with BenTalagan - the "ark_ctx wrapping imgui_ctx" insight.
