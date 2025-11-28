# API Design Decisions

> **Detailed rationale for each choice in the ARKITEKT API**

---

## Decision 1: Two Namespaces (Ark + ImGui)

### Choice
```lua
Ark.Button(ctx, "Click")      -- Ark widgets
ImGui.SameLine(ctx)           -- ImGui utilities
```

### Rejected Alternative
```lua
Ark.Button(ctx, "Click")
Ark.ImGui.SameLine(ctx)       -- More typing, no benefit
-- or --
Ark.SameLine(ctx)             -- Wrapping 200+ ImGui functions
```

### Rationale
- `Ark.ImGui.X` is longer than `ImGui.X` for no benefit
- Wrapping all ImGui utilities = maintenance nightmare
- Users familiar with ImGui already know `ImGui.X`
- Clear separation: **Ark = our widgets**, **ImGui = raw utilities**

---

## Decision 2: No `.draw()` (Callable Modules)

### Choice
```lua
Ark.Button(ctx, "Click")
```

### Rejected Alternative
```lua
Ark.Button.draw(ctx, {label = "Click"})
```

### Rationale
- ImGui uses `ImGui.Button()` not `ImGui.Button.draw()`
- `.draw` is unnecessary verbosity
- Callable modules via `__call` metamethod:
  ```lua
  return setmetatable(M, {
    __call = function(_, ctx, ...)
      return M.draw(ctx, ...)
    end
  })
  ```

---

## Decision 3: Hybrid Parameters (Positional + Opts)

### Choice
```lua
-- Both work:
Ark.Button(ctx, "Click")                    -- Positional (simple)
Ark.Button(ctx, "Click", 100, 30)           -- Positional with size
Ark.Button(ctx, {label = "Click", ...})     -- Opts table (complex)
```

### Rejected Alternatives
```lua
-- Opts only (current)
Ark.Button(ctx, {label = "Click"})          -- Verbose for simple cases

-- Positional only
Ark.Button(ctx, "Click", 100, 30, true, handler, "tooltip")  -- Unreadable
```

### Rationale

**Problems with ImGui's positional-only:**
- Must memorize parameter order
- Can't skip middle parameters: `Button(ctx, "X", nil, nil, true)`
- Adding features = parameter explosion
- No self-documentation: `SliderFloat(ctx, "X", 0.5, 0.0, 1.0, "%.2f", 1.0)` - what's that last 1.0?

**Problems with opts-only:**
- Verbose for simple cases
- Different from ImGui docs
- Migration friction

**Hybrid wins:**
- Simple cases stay simple: `Ark.Button(ctx, "OK")`
- Complex cases are clear: `{label = "OK", disabled = true, on_click = fn}`
- Easy migration from ImGui
- Easy upgrade path to opts when needed

### Implementation
```lua
function M.draw(ctx, label_or_opts, width, height)
  local opts
  if type(label_or_opts) == "table" then
    opts = label_or_opts
  else
    opts = {label = label_or_opts, width = width, height = height}
  end
  -- ... rest uses opts
end
```

---

## Decision 4: Result Objects (Not Booleans)

### Choice
```lua
local result = Ark.Button(ctx, "Click")
result.clicked        -- true/false
result.right_clicked  -- true/false
result.hovered        -- true/false
result.active         -- true/false (being pressed)
result.width          -- actual rendered width
result.height         -- actual rendered height

-- Still works inline:
if Ark.Button(ctx, "Click").clicked then ... end
```

### Rejected Alternative
```lua
-- ImGui style: just boolean
if Ark.Button(ctx, "Click") then ... end
```

### Rationale
- ImGui's boolean return only tells you "was clicked"
- No way to know right-click, hover state, actual size
- ImGui requires separate calls: `IsItemHovered()`, `IsItemClicked(1)`, `GetItemRectSize()`
- Result object gives everything in one call
- **Still works inline** for simple `if clicked then` pattern

### Why Not Just Boolean?
```lua
-- ImGui pattern requires multiple calls:
if ImGui.Button(ctx, "X") then handle_click() end
if ImGui.IsItemHovered(ctx) then show_tooltip() end
if ImGui.IsItemClicked(ctx, 1) then show_context_menu() end

-- ARKITEKT pattern - one call, all info:
local r = Ark.Button(ctx, "X")
if r.clicked then handle_click() end
if r.hovered then show_tooltip() end
if r.right_clicked then show_context_menu() end
```

---

## Decision 5: Hide Internal Functions

### Choice
```lua
-- Public API (what users see):
Ark.Button(ctx, ...)

-- Internal (not exposed):
-- M.measure()        -- used internally for auto-sizing
-- M.cleanup()        -- automatic via periodic GC
-- M.draw_at_cursor() -- redundant, draw() uses cursor by default
```

### Rejected Alternative
```lua
Ark.Button.draw(ctx, ...)
Ark.Button.measure(ctx, ...)     -- "for layout calculations"
Ark.Button.cleanup()              -- "for memory management"
Ark.Button.draw_at_cursor(ctx, ...)
```

### Rationale

**`cleanup()` - Why hide:**
- Automatic via 30-second stale instance cleanup
- Exposing it invites premature optimization
- Users calling `cleanup()` every frame = performance disaster
- ImGui doesn't expose cleanup (it's stateless)

**`measure()` - Why hide:**
- Only used internally for auto-sizing
- Users can use `ImGui.CalcTextSize()` for text
- Users can use `ImGui.GetItemRectSize()` after drawing
- Not common enough to justify public API

**`draw_at_cursor()` - Why remove:**
- `draw()` already uses cursor position by default
- Completely redundant

---

## Decision 6: Keep Hover Animations (Strong Tables)

### Choice
- Smooth hover fade animations (not instant on/off)
- Strong tables with access-time tracking
- Automatic cleanup of stale instances (30s)

### Rejected Alternative
- Weak tables (caused flickering due to inter-frame GC)
- No animations (instant state changes like raw ImGui)

### Rationale
- Smooth animations = polished UX
- Strong tables prevent GC flickering
- 30-second cleanup prevents memory leaks
- Memory overhead is minimal (~24 bytes per button instance)

### Technical Detail
```lua
-- Weak tables don't work:
local instances = setmetatable({}, {__mode = 'v'})
-- GC can collect between frames → hover_alpha resets → FLICKER

-- Strong tables with cleanup:
local instances = Base.create_instance_registry()
-- Instances persist, cleaned after 30s of no access
```

---

## Decision 7: Callbacks Are Optional Enhancement

### Choice
```lua
-- Polling (ImGui-style) always works:
if Ark.Button(ctx, "Save").clicked then
  save()
end

-- Callbacks available for convenience:
Ark.Button(ctx, {
  label = "Save",
  on_click = save,
})
```

### Rationale
- Don't force callback pattern on users
- Polling is familiar to ImGui users
- Callbacks reduce boilerplate when desired
- Both patterns coexist

---

## Decision 8: Keep Icons Simple (No Magic)

### Choice
```lua
Ark.Button(ctx, {
  icon = "\xEF\x83\x87",     -- Direct UTF-8 from icon font site
  icon_font = fonts.icons,   -- User provides font object
  label = "Save",
})
```

### Rejected Alternative
```lua
Ark.Button(ctx, {
  icon = "save",  -- Symbolic name → framework lookup
  label = "Save",
  -- Framework auto-switches to icon font
})
```

### Rationale
- Coders copy UTF-8 directly from FontAwesome/RemixIcon/etc websites
- No framework magic to maintain
- Works with any icon font (not locked to one)
- Less runtime overhead (no lookup table)
- IDE autocomplete via optional LuaCATS definitions (see `TODO/ICON_LUACATS.md`)

### Enhancement
Optional `helpers/icon_defs.lua` for IDE convenience:
```lua
local Icons = require('helpers.icon_defs')
icon = Icons.SAVE  -- IDE shows glyph, autocomplete works
```

---

## Decision 9: Result Field Standardization

### Choice
All value-holding widgets use `.value` for their primary value:

```lua
-- Consistent pattern
local r = Ark.Checkbox(ctx, "Enable", checked)
if r.changed then config.enabled = r.value end

local r = Ark.Slider(ctx, "Volume", vol, 0, 100)
if r.changed then config.volume = r.value end

local r = Ark.InputText(ctx, "Name", name)
if r.changed then config.name = r.value end  -- NOT .text

local r = Ark.Combo(ctx, "Theme", idx, items)
if r.changed then config.theme = r.value end
r.item  -- Still available for selected item text
```

### Current State (Inconsistent)
| Widget | Value field |
|--------|-------------|
| Button | N/A |
| Checkbox | `.value` ✓ |
| Slider | `.value` ✓ |
| InputText | `.text` ← fix to `.value` |
| Combo | `.value` ✓ (+ `.item` for text) |

### Fix
- InputText: Change `.text` → `.value`
- Add `.text` as alias for backward compat (temporary)

### Rationale
- Predictable: "value changed? check `.value`"
- Muscle memory across widgets
- Reduces cognitive load

---

## Summary Table

| Aspect | ImGui | ARKITEKT Current | ARKITEKT Target |
|--------|-------|------------------|-----------------|
| Namespace | `ImGui.X` | `Ark.X.draw()` | `Ark.X()` + `ImGui.X()` |
| Parameters | Positional only | Opts only | Hybrid |
| Returns | Boolean | Result object | Result object |
| Callbacks | None | Available | Available |
| Internal funcs | Hidden | Exposed | Hidden |
| Animations | None | Smooth | Smooth |
| Icons | N/A | UTF-8 + font | UTF-8 + font (+ optional LuaCATS) |
