# Renderer Pattern with ArkContext

Optimized tile/grid rendering using per-frame caching.

## The Problem

Naive renderers repeat expensive calls for every tile:

```lua
function M.render(ctx, rect, item, state, grid)
  local dl = ImGui.GetWindowDrawList(ctx)  -- FFI call x1000
  local fx = TileFXConfig.get()             -- Function call x1000
  -- ... render tile
end
```

For 1000 tiles, that's 1000 FFI calls and 1000 function calls per frame.

## The Solution: ArkContext

ArkContext provides per-frame caching. Values computed once are reused for all tiles:

```lua
local Context = require('arkitekt.core.context')
local TileFXConfig = require('arkitekt.gui.renderers.tile.defaults')

function M.render(ctx, rect, item, state, grid)
  local actx = Context.get(ctx)  -- Cheap: table lookup + frame check

  -- These are cached per-frame (computed once, reused 999 times)
  local dl = actx:draw_list()
  local fx_config = actx:cache('tile_fx', TileFXConfig.get)
  local now = actx.time

  -- ... render tile using dl, fx_config, now
end
```

## What ArkContext Provides

| Method | Description | Use Case |
|--------|-------------|----------|
| `actx:draw_list()` | Cached window draw list | All drawing |
| `actx:cache(key, fn)` | Per-frame memoization | Config, theme lookups |
| `actx.time` | Frame timestamp | Animations |
| `actx:mouse_pos()` | Cached mouse position | Hit testing |
| `actx:delta_time()` | Frame delta | Animations |

## Overhead

`Context.get(ctx)` per tile costs:
- One weak table lookup
- One integer comparison (frame count)
- Returns already-cached instance

This is **cheaper** than a single FFI call, so calling it per-tile is fine.

## Full Example

```lua
-- my_renderer.lua
local ImGui = require('arkitekt.core.imgui')
local Context = require('arkitekt.core.context')
local TileFXConfig = require('arkitekt.gui.renderers.tile.defaults')
local Theme = require('arkitekt.theme')

-- Localize for hot path (optional, additional ~5% gain)
local DrawList_AddRectFilled = ImGui.DrawList_AddRectFilled

function M.render(ctx, rect, item, state, grid)
  -- Get cached context
  local actx = Context.get(ctx)
  local dl = actx:draw_list()

  -- Cache expensive lookups
  local fx = actx:cache('fx_config', TileFXConfig.get)
  local colors = actx:cache('theme_colors', function()
    return Theme.COLORS
  end)

  -- Render using cached values
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local bg_color = item.color or colors.BG_BASE

  DrawList_AddRectFilled(dl, x1, y1, x2, y2, bg_color, fx.rounding)
end
```

## When NOT to Use

1. **Hyper-optimized renderers** (ItemPicker) - Already fully inlined, any abstraction is overhead
2. **Single-item rendering** - No benefit from caching if only rendering once
3. **Outside render loop** - ArkContext is for per-frame caching, not cross-frame

## Cross-Frame Caching

For values that persist across frames (truncated text, computed layouts), use a separate cache:

```lua
-- Module-level cache (persists across frames)
local _text_cache = {}

function M.render(ctx, rect, item, state, grid)
  local actx = Context.get(ctx)

  -- Per-frame: fx_config might change if theme changes
  local fx = actx:cache('fx', TileFXConfig.get)

  -- Cross-frame: truncated text rarely changes
  local cache_key = item.id .. '_' .. item.name
  local truncated = _text_cache[cache_key]
  if not truncated then
    truncated = truncate_text(ctx, item.name, rect[3] - rect[1])
    _text_cache[cache_key] = truncated
  end
end
```

## Summary

- Use `Context.get(ctx)` at start of render function
- Use `actx:draw_list()` instead of `ImGui.GetWindowDrawList(ctx)`
- Use `actx:cache(key, fn)` for config/theme lookups
- Localize ImGui functions for additional gains in hot paths
- Use module-level caches for cross-frame data
