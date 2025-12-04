# ArkContext Guide

> Frame-scoped context for ARKITEKT widgets. Provides centralized caching so widgets automatically benefit without individual optimization work.

## Table of Contents

1. [Overview](#overview)
2. [Quick Reference](#quick-reference)
3. [For Widget Authors](#for-widget-authors)
4. [For App Developers](#for-app-developers)
5. [Disabled Stack](#disabled-stack)
6. [API Reference](#api-reference)
7. [Limitations & Caveats](#limitations--caveats)

---

## Overview

**ArkContext (`actx`)** wraps ImGui's `ctx` to provide ARKITEKT-specific frame state and cached values. The relationship mirrors ImGui's pattern:

```
ctx  (ImGui)     <->    actx (ARKITEKT)
```

**Key benefits:**
- **Automatic caching**: Draw lists, mouse position, delta time cached per-frame
- **Zero user API change**: Users pass `ctx` as always; widgets use `actx` internally
- **Per-frame memoization**: `actx:cache()` for expensive computations
- **ID stack integration**: Delegates to `arkitekt/core/id_stack.lua`
- **Disabled stack**: Scope-based disabled regions with `Ark.BeginDisabled/EndDisabled`

---

## Quick Reference

| Need | Before | After |
|------|--------|-------|
| Draw list | `ImGui.GetWindowDrawList(ctx)` | `actx:draw_list()` |
| Mouse position | `ImGui.GetMousePos(ctx)` | `actx:mouse_pos()` |
| Delta time | `ImGui.GetDeltaTime(ctx)` | `actx:delta_time()` |
| Precise time | `reaper.time_precise()` | `actx.time` |
| Frame number | `ImGui.GetFrameCount(ctx)` | `actx.frame` |
| Expensive calc | (compute every call) | `actx:cache(key, fn)` |
| Disable region | `is_disabled = x` on each widget | `Ark.BeginDisabled(ctx, x)` |

---

## For Widget Authors

### Getting ArkContext

Inside framework widgets, use `Base.get_context()`:

```lua
local Base = require('arkitekt.gui.widgets.base')

function M.Draw(ctx, opts)
  local actx = Base.get_context(ctx)
  local dl = actx:draw_list()
  -- ...
end
```

Or for files that don't use Base:

```lua
local Context = require('arkitekt.core.context')

function M.render(ctx, ...)
  local actx = Context.get(ctx)
  local dl = actx:draw_list()
  -- ...
end
```

### Using Cached Draw List

The most common use case - get the window draw list:

```lua
-- ✅ CORRECT: Uses cached draw list
function M.Draw(ctx, opts)
  local actx = Base.get_context(ctx)
  local dl = actx:draw_list()
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, color)
end

-- ✅ ALSO CORRECT: Via Base helper (handles opts.draw_list override)
function M.Draw(ctx, opts)
  local dl = Base.get_draw_list(ctx, opts)
  -- ...
end
```

### Per-Frame Memoization

Use `actx:cache()` for expensive computations that should only run once per frame:

```lua
function M.Draw(ctx, opts)
  local actx = Base.get_context(ctx)

  -- Gradient computed once per frame, reused by all instances
  local gradient = actx:cache('hue_gradient_256', function()
    local colors = {}
    for i = 0, 255 do
      colors[i] = compute_hue_color(i / 255)
    end
    return colors
  end)

  -- Use cached gradient
  for i, color in ipairs(gradient) do
    draw_segment(dl, i, color)
  end
end
```

**Cache key best practices:**
- Use descriptive, unique keys: `'hue_gradient_256'`, not `'gradient'`
- Include parameters in key if computation varies: `'font_metrics_' .. font_size`

### When NOT to Use actx:cache()

Don't use cache for:
- Simple value lookups (already fast)
- Values that change per-widget (use widget state instead)
- Values that need per-instance variation

```lua
-- ❌ BAD: Config lookup is already O(1)
local padding = actx:cache('padding', function()
  return config.node.padding
end)

-- ✅ GOOD: Just access directly
local padding = config.node.padding
```

---

## For App Developers

### User API Unchanged

Apps continue passing `ctx` to ARKITEKT widgets:

```lua
function MyApp:draw(ctx)
  if Ark.Button(ctx, 'Save') then
    self:save()
  end

  Ark.Grid(ctx, {
    items = self.items,
    columns = 4,
  })
end
```

Widgets handle ArkContext internally - no changes needed.

### Accessing ArkContext in App Code

For app-level rendering that needs caching:

```lua
local Ark = require('arkitekt')

function MyApp:draw_custom_overlay(ctx)
  local actx = Ark.GetContext(ctx)

  -- Cache expensive app-specific computation
  local layout = actx:cache('my_app_layout', function()
    return self:compute_complex_layout()
  end)

  -- Use cached layout for rendering
  for _, item in ipairs(layout.items) do
    self:draw_item(actx:draw_list(), item)
  end
end
```

### Example: Tile Rendering Optimization

For apps rendering many similar items (grids, lists, tiles):

```lua
function TileRenderer:draw_all(ctx, tiles, config)
  local actx = Ark.GetContext(ctx)
  local dl = actx:draw_list()

  -- Cache shared computations
  local colors = actx:cache('tile_colors', function()
    return {
      bg = Colors.WithAlpha(config.bg, 0.9),
      border = Colors.WithAlpha(config.accent, 0.5),
      text = config.text_color,
    }
  end)

  -- Render all tiles using cached colors
  for _, tile in ipairs(tiles) do
    self:draw_tile(dl, tile, colors)
  end
end
```

---

## API Reference

### M.get(ctx) / Ark.GetContext(ctx)

Get or create ArkContext for an ImGui context.

```lua
local actx = Context.get(ctx)
local actx = Ark.GetContext(ctx)
```

### actx.ctx

Raw ImGui context reference.

### actx.frame

Current frame number (integer).

### actx.time

`reaper.time_precise()` sampled once at frame start.

### actx:draw_list()

Get window draw list (cached). **Must be called after Begin()**.

```lua
local dl = actx:draw_list()
```

### actx:foreground_draw_list()

Get foreground draw list (not cached, for overlays/tooltips).

### actx:background_draw_list()

Get background draw list (not cached, for window backgrounds).

### actx:mouse_pos()

Get mouse position (cached per-frame).

```lua
local mx, my = actx:mouse_pos()
```

### actx:delta_time()

Get delta time since last frame (cached).

```lua
local dt = actx:delta_time()
```

### actx:cache(key, compute_fn)

Per-frame memoization. Value computed once per frame.

```lua
local result = actx:cache('expensive_computation', function()
  return compute_something_expensive()
end)
```

### actx:clear_cache(key?)

Force cache invalidation (rare).

```lua
actx:clear_cache('specific_key')  -- Clear one
actx:clear_cache()                 -- Clear all
```

### ID Stack Methods

Delegates to `arkitekt/core/id_stack.lua`:

```lua
actx:push_id(id)           -- Push ID onto stack
actx:pop_id()              -- Pop ID from stack
actx:resolve_id(base_id)   -- Get full ID with stack prefix
actx:id_depth()            -- Get current stack depth
```

### Disabled Stack Methods

Scope-based disabled regions (see [Disabled Stack](#disabled-stack) for full docs):

```lua
-- Via Ark namespace (preferred for apps)
Ark.BeginDisabled(ctx, condition)  -- Begin disabled region
Ark.EndDisabled(ctx)               -- End disabled region

-- Via ArkContext (for widgets)
actx:begin_disabled(condition)     -- Begin disabled region
actx:end_disabled()                -- End disabled region
actx:is_disabled()                 -- Check if currently disabled
```

---

## Limitations & Caveats

### Child Windows

**`actx:draw_list()` caches the parent window's draw list.** Inside `BeginChild`, you must get the child's draw list directly:

```lua
-- ✅ CORRECT for child windows
if ImGui.BeginChild(ctx, 'child_region', w, h) then
  local child_dl = ImGui.GetWindowDrawList(ctx)  -- NOT actx:draw_list()
  -- draw to child_dl...
  ImGui.EndChild(ctx)
end
```

### Multiple ImGui Contexts

Each ImGui `ctx` gets its own `actx`. The weak table automatically cleans up when `ctx` is garbage collected.

### Performance Reality Check

The direct performance gain from caching `GetWindowDrawList` is minimal (it's already O(1)). The real value is:

1. **Cleaner code**: No repeated boilerplate
2. **Future optimization**: `actx:cache()` for genuinely expensive computations
3. **Consistent patterns**: All widgets use the same approach

### When App-Specific Caching is Better

For apps with very specific optimization needs (like ItemPicker), app-level caching patterns may be more appropriate:

```lua
-- ItemPicker uses its own _frame_config pattern
-- This is MORE specific than ArkContext and that's fine
function ItemPicker:_get_frame_config()
  local frame = ImGui.GetFrameCount(self._ctx)
  if self._frame_config_frame ~= frame then
    self._frame_config = self:_build_config()
    self._frame_config_frame = frame
  end
  return self._frame_config
end
```

ArkContext and app-specific patterns coexist - use what fits the situation.

---

## Disabled Stack

ArkContext includes a **Disabled Stack** for scope-based disabled regions. This eliminates repetitive `is_disabled = condition` passing to every widget.

### Basic Usage

```lua
-- Disable all widgets in a region
Ark.BeginDisabled(ctx, is_loading)
  Ark.Button(ctx, 'Save')           -- Disabled when is_loading is true
  Ark.Button(ctx, 'Cancel')         -- Also disabled
  Ark.InputText(ctx, { id = 'name' }) -- Also disabled
  Ark.Slider(ctx, { id = 'volume' })  -- Also disabled
Ark.EndDisabled(ctx)
```

### Conditional Disabling

The condition is evaluated at `BeginDisabled` time:

```lua
-- Disable during async operation
Ark.BeginDisabled(ctx, self.is_saving)
  if Ark.Button(ctx, 'Save') then
    self:start_save()
  end
Ark.EndDisabled(ctx)

-- Disable based on validation
Ark.BeginDisabled(ctx, not self:is_form_valid())
  if Ark.Button(ctx, 'Submit') then
    self:submit()
  end
Ark.EndDisabled(ctx)
```

### Nesting

Disabled regions can be nested. Once disabled, stays disabled until the corresponding `EndDisabled`:

```lua
Ark.BeginDisabled(ctx, false)  -- Not disabled
  Ark.Button(ctx, 'A')         -- Enabled

  Ark.BeginDisabled(ctx, true) -- Now disabled
    Ark.Button(ctx, 'B')       -- Disabled
    Ark.Button(ctx, 'C')       -- Disabled
  Ark.EndDisabled(ctx)

  Ark.Button(ctx, 'D')         -- Back to enabled
Ark.EndDisabled(ctx)
```

### Widget-Level Override

Individual widgets can still use `is_disabled` in opts, which takes precedence:

```lua
Ark.BeginDisabled(ctx, false)  -- Region is enabled
  Ark.Button(ctx, 'A')         -- Enabled
  Ark.Button(ctx, { label = 'B', is_disabled = true })  -- Explicitly disabled
  Ark.Button(ctx, 'C')         -- Enabled
Ark.EndDisabled(ctx)
```

### Supported Widgets

All primitive widgets respect the disabled stack:
- Button, Checkbox, InputText, Slider
- Spinner, Knob, RadioButton, CornerButton, Splitter

### For Widget Authors

Widgets should check both `opts.is_disabled` and `actx:is_disabled()`:

```lua
function M.Draw(ctx, opts)
  local actx = Base.get_context(ctx)
  local is_disabled = opts.is_disabled or actx:is_disabled()

  if is_disabled then
    -- Render disabled appearance, skip interactions
  end
end
```

---

## Migration Checklist

When updating existing widgets to use ArkContext:

- [ ] Replace `ImGui.GetWindowDrawList(ctx)` with `Base.get_draw_list(ctx, opts)` or `actx:draw_list()`
- [ ] Check for child windows - keep direct `GetWindowDrawList` calls there
- [ ] Consider if any expensive computations could use `actx:cache()`
- [ ] Test that draw list is accessed AFTER the window's Begin() call
