# Implementation Guide

> **Step-by-step guide to implement the new API**

---

## Overview

Each widget needs these changes:

1. Add `__call` metamethod (make module callable)
2. Add parameter detection (string/table)
3. Map positional params to opts
4. Remove/hide internal functions
5. Update return statement

---

## Step 1: Make Module Callable

### Before
```lua
local M = {}

function M.draw(ctx, opts)
  -- implementation
end

return M
```

### After
```lua
local M = {}

function M.draw(ctx, opts)
  -- implementation
end

-- Make module callable: Ark.Button(ctx, ...) calls M.draw(ctx, ...)
return setmetatable(M, {
  __call = function(_, ctx, ...)
    return M.draw(ctx, ...)
  end
})
```

---

## Step 2: Add Hybrid Parameter Detection

### Before
```lua
function M.draw(ctx, opts)
  opts = opts or {}
  -- assumes opts is always a table
end
```

### After
```lua
function M.draw(ctx, label_or_opts, width, height)
  local opts

  if type(label_or_opts) == "table" then
    -- Opts table passed directly
    opts = label_or_opts
  elseif type(label_or_opts) == "string" then
    -- Positional params - map to opts
    opts = {
      label = label_or_opts,
      width = width,
      height = height,
    }
  else
    -- No params or just ctx - empty opts
    opts = {}
  end

  -- Rest of implementation uses opts...
end
```

---

## Step 3: Widget-Specific Parameter Mapping

### Button
```lua
function M.draw(ctx, label_or_opts, width, height)
  local opts
  if type(label_or_opts) == "table" then
    opts = label_or_opts
  else
    opts = {
      label = label_or_opts,
      width = width,
      height = height,
    }
  end
  -- ...
end
```

### Checkbox
```lua
function M.draw(ctx, label_or_opts, checked)
  local opts
  if type(label_or_opts) == "table" then
    opts = label_or_opts
  else
    opts = {
      label = label_or_opts,
      checked = checked,
    }
  end
  -- ...
end
```

### Slider
```lua
function M.draw(ctx, label_or_opts, value, min, max)
  local opts
  if type(label_or_opts) == "table" then
    opts = label_or_opts
  else
    opts = {
      label = label_or_opts,
      value = value,
      min = min,
      max = max,
    }
  end
  -- ...
end
```

### InputText
```lua
function M.draw(ctx, label_or_opts, text, width)
  local opts
  if type(label_or_opts) == "table" then
    opts = label_or_opts
  else
    opts = {
      label = label_or_opts,
      text = text,
      width = width,
    }
  end
  -- ...
end
```

### Combo
```lua
function M.draw(ctx, label_or_opts, selected, items)
  local opts
  if type(label_or_opts) == "table" then
    opts = label_or_opts
  else
    opts = {
      label = label_or_opts,
      selected = selected,
      items = items,
    }
  end
  -- ...
end
```

---

## Step 4: Hide Internal Functions

### Before
```lua
function M.measure(ctx, opts)
  -- public
end

function M.cleanup()
  -- public
end

function M.draw_at_cursor(ctx, opts)
  -- public
end
```

### After
```lua
-- Internal: used by draw(), not exposed
local function measure(ctx, opts)
  -- ...
end

-- Internal: automatic via periodic GC
local function cleanup()
  -- ...
end

-- Removed: redundant, draw() uses cursor by default
-- draw_at_cursor removed entirely

-- Only M.draw is public (and callable via __call)
```

---

## Step 5: Complete Example (Button)

```lua
-- @noindex
-- arkitekt/gui/widgets/primitives/button.lua

local ImGui = require('arkitekt.platform.imgui')
local Theme = require('arkitekt.core.theme')
local Base = require('arkitekt.gui.widgets.base')

local M = {}

-- ============================================================================
-- INSTANCE MANAGEMENT (internal)
-- ============================================================================

local instances = Base.create_instance_registry()

-- ============================================================================
-- INTERNAL HELPERS
-- ============================================================================

local function measure(ctx, opts)
  -- Calculate width from label + padding
  local label = opts.label or ""
  local text_w = ImGui.CalcTextSize(ctx, label)
  local padding = opts.padding_x or 10
  return text_w + padding * 2
end

local function render(ctx, opts, instance)
  -- ... rendering implementation ...
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Draw a button widget
--- @param ctx userdata ImGui context
--- @param label_or_opts string|table Label string or opts table
--- @param width number|nil Button width (positional)
--- @param height number|nil Button height (positional)
--- @return table Result {clicked, right_clicked, hovered, active, width, height}
function M.draw(ctx, label_or_opts, width, height)
  -- Hybrid parameter detection
  local opts
  if type(label_or_opts) == "table" then
    opts = label_or_opts
  else
    opts = {
      label = label_or_opts,
      width = width,
      height = height,
    }
  end

  -- Apply defaults
  opts = Base.parse_opts(opts, DEFAULTS)

  -- Calculate size
  local w = opts.width or measure(ctx, opts)
  local h = opts.height or 24

  -- Get/create instance for animation
  local id = Base.resolve_id(opts, "button")
  local instance = Base.get_or_create_instance(instances, id, Button.new)

  -- Render and get interaction state
  local clicked, right_clicked, hovered, active = render(ctx, opts, instance)

  -- Handle callbacks
  if clicked and opts.on_click then opts.on_click() end
  if right_clicked and opts.on_right_click then opts.on_right_click() end
  if hovered and opts.tooltip then ImGui.SetTooltip(ctx, opts.tooltip) end

  -- Return result object
  return {
    clicked = clicked,
    right_clicked = right_clicked,
    hovered = hovered,
    active = active,
    width = w,
    height = h,
  }
end

-- ============================================================================
-- MODULE EXPORT
-- ============================================================================

-- Make callable: Ark.Button(ctx, ...) → M.draw(ctx, ...)
return setmetatable(M, {
  __call = function(_, ctx, ...)
    return M.draw(ctx, ...)
  end
})
```

---

## Migration Strategy

### Phase 1: Add New API (Non-Breaking)
1. Add `__call` to each widget
2. Add hybrid parameter detection
3. Keep `.draw()` working (backward compatible)
4. Keep internal functions (will hide later)

### Phase 2: Update Scripts
1. Find all `Ark.Button.draw(` calls
2. Replace with `Ark.Button(`
3. Update opts-only to positional where simpler

### Phase 3: Hide Internals
1. Make `measure()` local
2. Make `cleanup()` local (or remove if unused)
3. Remove `draw_at_cursor()`

### Regex for Finding Usage
```bash
# Find all .draw( calls
grep -r "Ark\.\w\+\.draw(" scripts/

# Find all widget usage
grep -rE "Ark\.(Button|Checkbox|Slider|InputText|Combo)" scripts/
```

---

## Testing Checklist

For each widget:

- [ ] Positional params work: `Ark.Button(ctx, "OK")`
- [ ] Positional with size works: `Ark.Button(ctx, "OK", 100, 30)`
- [ ] Opts table works: `Ark.Button(ctx, {label = "OK"})`
- [ ] Old `.draw()` still works: `Ark.Button.draw(ctx, {label = "OK"})`
- [ ] Result object has all fields
- [ ] Callbacks fire correctly
- [ ] Tooltip shows on hover
- [ ] Disabled state works
