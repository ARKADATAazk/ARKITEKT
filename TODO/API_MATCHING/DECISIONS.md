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

## Decision 10: Simple Alignment Option

### Choice
Add `align` option to widgets for easy centering/right-alignment:

```lua
Ark.Button(ctx, {label = "Centered", align = "center"})
Ark.Button(ctx, {label = "Close", align = "right"})
```

### Implementation
```lua
-- ~10 lines, trivial
if opts.align == "center" then
  local win_w = ImGui.GetWindowWidth(ctx)
  x = (win_w - width) * 0.5
elseif opts.align == "right" then
  local win_w = ImGui.GetWindowWidth(ctx)
  x = win_w - width
end
```

### Rejected Alternatives
- Container layouts (Row, flex) - Too complex, low demand
- Percentage widths - Overengineering
- CSS-style justify/stretch - Overkill for REAPER scripts

### Rationale
- Covers 80% use case with minimal code
- No container system needed
- Simple mental model

---

## Decision 11: Match ImGui Cursor Advance

### Choice
Change default `advance` from `"vertical"` to `"horizontal"` to match ImGui:

```lua
-- Current (different from ImGui):
Ark.Button(ctx, "A")
Ark.Button(ctx, "B")  -- Below A (vertical)

-- Target (matches ImGui):
Ark.Button(ctx, "A")
Ark.Button(ctx, "B")  -- Next to A (horizontal)
```

### Keep Option for Override
```lua
Ark.Button(ctx, {label = "A", advance = "vertical"})
Ark.Button(ctx, "B")  -- Below A
```

### Rationale
- Matches ImGui default behavior
- Easier migration from ImGui code
- Less surprise for ImGui users

---

## Decision 12: No Animation Toggle (Uniform UX)

### Choice
Keep animations always enabled. No `animated = false` option.

### Rationale
- Uniform look/feel across all ARKITEKT scripts in REAPER
- Overhead is minimal (just alpha lerp per frame)
- Consistency > customization for this case
- Users expect polished UX from ARKITEKT apps

### Rejected Alternative
```lua
Ark.Button(ctx, {label = "X", animated = false})  -- NOT adding this
```

---

## Decision 13: Clear Error Messages

### Choice
Provide helpful error messages for invalid inputs:

```lua
-- If user passes wrong type:
Ark.Button(ctx, 123)
-- Error: "Ark.Button: expected string or table, got number"

-- If user forgets required field:
Ark.Slider(ctx, {label = "Vol"})  -- missing value, min, max
-- Error: "Ark.Slider: missing required field 'value'"
```

### Implementation
```lua
function M.draw(ctx, label_or_opts, ...)
  if type(label_or_opts) ~= "string" and type(label_or_opts) ~= "table" then
    error("Ark.Button: expected string or table, got " .. type(label_or_opts), 2)
  end
  -- ...
end
```

### Rationale
- Catch mistakes early with clear message
- Better than silent failure or cryptic Lua errors
- Level 2 error shows caller's line, not widget internals

---

## Decision 14: Ark + ImGui Interop Rules

### What Works
```lua
-- SameLine: WORKS
Ark.Button(ctx, "A")
ImGui.SameLine(ctx)
Ark.Button(ctx, "B")

-- IsItemHovered: WORKS (but redundant)
Ark.Button(ctx, "X")
if ImGui.IsItemHovered(ctx) then ... end  -- Works, but use result.hovered instead
```

### What Doesn't Work
```lua
-- SetNextItemWidth: MAY NOT WORK
ImGui.SetNextItemWidth(ctx, 200)
Ark.Slider(ctx, "Vol", v, 0, 100)  -- May ignore, use opts.width instead
```

### Guidance
- Use `ImGui.SameLine()`, `ImGui.Separator()`, etc. freely between Ark widgets
- Don't rely on `ImGui.SetNextItem*()` - use opts instead
- Don't use `ImGui.IsItem*()` - use result object fields

---

## Decision 15: Presets Only, No Raw Color Overrides

### Choice
Widget styling uses **semantic presets only**, not raw color values:

```lua
-- CORRECT: Semantic presets
Ark.Button(ctx, {label = "Delete", preset = "danger"})
Ark.Button(ctx, {label = "Save", preset = "success"})
Ark.Button(ctx, {label = "Toggle", preset = "toggle_white"})

-- DEPRECATED: Raw color overrides (to be removed)
Ark.Button(ctx, {label = "X", bg_color = 0xFF0000FF})  -- NO
```

### Available Presets
- `danger` - Red (destructive actions)
- `success` - Green (confirmations)
- `warning` - Amber (caution)
- `info` - Blue (informational)
- `toggle_white` - Toggle button variant
- `toggle_teal` - Toggle button variant

### Theme Customization Levels
| Level | How | Who |
|-------|-----|-----|
| **App-wide** | `Theme.set_mode("dark"/"light"/"adapt")` | User preference |
| **Custom BG** | `Theme.set_custom(color)` | Power users |
| **Widget** | `preset = "danger"` | Developer (semantic only) |

### Rationale
- All ARKITEKT scripts look uniform
- Auto-adapts to REAPER dark/light themes
- Semantic meaning ("danger" vs arbitrary red)
- Prevents inconsistent "Christmas tree" UIs
- Simpler API surface

### Migration
Raw color options (`bg_color`, `text_color`, etc.) are legacy from pre-theme-manager code. These will be:
1. Deprecated (warn in docs)
2. Eventually removed

---

## Decision 16: Hidden State for Complex Widgets

### Insight
ImGui itself is NOT purely stateless - it maintains internal state keyed by widget ID:

| ImGui Widget | Hidden Internal State |
|--------------|----------------------|
| `InputText` | Cursor position, selection, undo history |
| `BeginChild` | Scroll position X/Y |
| `TreeNode` | Open/closed state |
| `CollapsingHeader` | Collapsed state |
| `BeginCombo` | Open state, scroll position |
| `Slider/Drag` | Active drag state |

Users don't see this - they just call `InputText()` and it "just works".

### Choice
ARKITEKT follows the same pattern - **appear simple, hide complexity**:

```lua
-- User sees simple API
local r = Ark.Grid(ctx, {
  items = playlist.items,
  render = render_tile,
  -- Optional complexity:
  selectable = true,      -- Enables selection state
  draggable = true,       -- Enables drag state
  animated = true,        -- Enables animation state (default)
})

if r.selected then ... end
if r.dropped then ... end
```

### Implementation
```lua
-- Under the hood (user never sees this)
function M.draw(ctx, opts)
  local id = opts.id or ImGui.GetID(ctx, "grid")
  local state = Base.get_state(id)  -- ID-keyed hash table

  -- State persists between frames
  state.selection = state.selection or {}
  state.scroll_y = state.scroll_y or 0
  state.hover_anim = state.hover_anim or {}

  -- ... use state throughout draw
end
```

### Rejected Alternative
```lua
-- Explicit retained mode API
local grid = Ark.Grid.create({items = items})  -- Create once
grid:draw(ctx)                                  -- Draw each frame
grid:destroy()                                  -- Manual cleanup
```

### Rationale
- **Matches ImGui mental model** - users expect stateless-looking API
- **Complexity scales with config** - simple config = simple behavior
- **No lifecycle management** - framework handles cleanup via 30s stale check
- **Familiar to ImGui users** - just like `InputText()` magically remembers cursor

### The Spectrum

```
Pure Immediate          ImGui Widgets           Full Retained
      │                      │                       │
      ▼                      ▼                       ▼
   No state           Minimal hidden         Heavy hidden
   at all             state (ID-keyed)       state (ID-keyed)

   Raw drawing        Button, Slider         Grid, TreeView
   ImGui.Line()       InputText              Selection state
                      TreeNode               Drag-drop state
                                             Animation state
```

All use the **same pattern** (ID-keyed state), just with different amounts of hidden state.

---

## Decision 17: Panel Callback Regions + Context Injection

### Problem
Panel uses **declarative config** for UI elements:

```lua
-- Current: Declarative (inconsistent with rest of API)
Panel.new("my_panel", {
  header = {
    elements = {
      { id = "title", type = "button", config = { label = "Title" }},
    },
  },
  corner_buttons = {
    bottom_right = { icon = "⚙", on_click = fn },
  },
})
```

This creates a duplicate type system (`type = "button"` vs `Ark.Button`), config tunneling, and inconsistency with Grid's `render` callback pattern.

### Choice
Panel uses **callback-based regions**. User calls real widgets inside callbacks:

```lua
-- New: Callback regions (consistent with Grid)
Ark.Panel(ctx, {
  id = "my_panel",

  header = {
    height = 30,
    draw = function(ctx)
      Ark.Button(ctx, { label = "Title" })
    end,
  },

  corner = {
    bottom_right = function(ctx)
      Ark.Button(ctx, { icon = "⚙" })  -- Auto corner-shaped!
    end,
  },

  draw = function(ctx)
    -- Main content
  end,
})
```

### Context Injection
Panel injects rendering context before calling region callbacks. Button reads this and auto-adapts:

- **Header buttons**: Corners auto-rounded based on position (first/middle/last)
- **Corner buttons**: Asymmetric rounding auto-applied based on which corner
- **No manual config**: User just calls `Ark.Button`, Panel guardrails everything

```
Panel                              Button
  │                                  │
  ├─ Sets context:                   │
  │   _corner_position = "br"        │
  │   _corner_outer = 8              │
  │   _corner_inner = 3              │
  │                                  │
  └─ Calls draw callback ───────────►│
                                     │
     Ark.Button(ctx, {icon="⚙"}) ───►│
                                     │
                                     ├─ Reads context
                                     └─ Renders corner-shaped
```

### CornerButton Deprecation
`Ark.CornerButton` becomes unnecessary. Button handles all cases via context injection.

### Rationale
- **Consistent** with Grid's `render` callback pattern
- **No duplicate type system** - user calls real `Ark.Button`
- **Panel guardrails everything** - no manual `corner_rounding` config
- **Simpler user code** - just call widgets, Panel handles the rest

**See:** `TODO/API_MATCHING/PANEL_REWORK.md` for full spec.

---

## Decision 18: Dual Return for Simple Widgets

### Problem
Result objects are powerful but make simple cases verbose:

```lua
-- ImGui: clean
if ImGui.Button(ctx, "OK") then save() end

-- Ark with result only: verbose
if Ark.Button(ctx, "OK").clicked then save() end
```

### Choice
Simple widgets return **two values**: primary boolean + result object.

```lua
-- Button: clicked, result
if Ark.Button(ctx, "OK") then save() end  -- First return = clicked
local clicked, r = Ark.Button(ctx, "OK")  -- Full access when needed

-- Checkbox: changed, result
if Ark.Checkbox(ctx, "Enable", val) then val = not val end
local changed, r = Ark.Checkbox(ctx, "Enable", val)

-- Slider: changed, result
if Ark.Slider(ctx, "Vol", vol, 0, 1) then vol = r.value end
local changed, r = Ark.Slider(ctx, "Vol", vol, 0, 1)
```

### Primary Return by Widget Type

| Widget | Primary Return | Why |
|--------|----------------|-----|
| Button | `clicked` | Action trigger, no state |
| Checkbox | `changed` | Value changed this frame |
| Slider | `changed` | Value changed this frame |
| InputText | `changed` | Text changed this frame |
| Combo | `changed` | Selection changed this frame |
| Grid | N/A (result only) | Multiple possible actions |
| TreeView | N/A (result only) | Multiple possible actions |

### Implementation

```lua
function M.draw(ctx, opts)
  -- ... render widget ...

  local result = {
    clicked = clicked,  -- or changed for stateful widgets
    value = new_value,
    hovered = hovered,
    width = width,
    height = height,
  }

  return clicked, result  -- Dual return
end
```

### Rationale
- **Matches ImGui simplicity** for simple cases
- **Full power available** via second return
- **No reason to use ImGui.Button** - Ark is now just as clean AND has theming/presets

---

## Decision 19: Opts Naming Conventions

### Problem
Opts field names were inconsistent and verbose:
- `on_click` / `on_right_click` - redundant `on_` prefix
- `is_toggled` - redundant `is_` prefix
- `preset_name` - unclear name
- `width` / `height` - no terse alternative

### Choice
Cleaner names with terse aliases for common fields:

```lua
Ark.Button(ctx, {
  label = "Save",

  -- Size (both forms work)
  width = 120,    -- or: w = 120
  height = 32,    -- or: h = 32

  -- State (cleaner names)
  disabled = false,
  toggled = false,     -- was: is_toggled

  -- Styling
  style = "success",   -- was: preset_name

  -- Callbacks (no on_ prefix)
  click = save_file,        -- was: on_click
  right_click = show_menu,  -- was: on_right_click

  -- Extras
  tooltip = "Save file",
  icon = "",
})
```

### Aliases

| Verbose | Terse |
|---------|-------|
| `width` | `w` |
| `height` | `h` |

### Renames (no aliases, just better names)

| Old | New |
|-----|-----|
| `on_click` | `click` |
| `on_right_click` | `right_click` |
| `is_toggled` | `toggled` |
| `preset_name` | `style` |

### Implementation
```lua
local w = opts.w or opts.width
local h = opts.h or opts.height
local click = opts.click        -- old on_click deprecated
local toggled = opts.toggled    -- old is_toggled deprecated
local style = opts.style        -- old preset_name deprecated
```

### Rationale
- **Shorter**: Less typing, less noise
- **Flexible**: Verbose or terse, user's choice
- **Cleaner callbacks**: `click` is obvious in context (it's a function)
- **Cleaner state**: `toggled` is simpler than `is_toggled`
- **Semantic styling**: `style = "danger"` reads better than `preset_name = "danger"`

---

## Summary Table

| Aspect | ImGui | ARKITEKT Current | ARKITEKT Target |
|--------|-------|------------------|-----------------|
| Namespace | `ImGui.X` | `Ark.X.draw()` | `Ark.X()` |
| Parameters | Positional only | Opts only | Hybrid |
| Returns | Boolean | Result object | Dual (bool, result) |
| Callbacks | None | Available | Available |
| Internal funcs | Hidden | Exposed | Hidden |
| Animations | None | Smooth | Smooth (always, no toggle) |
| Icons | N/A | UTF-8 + font | UTF-8 + font (+ optional LuaCATS) |
| Result fields | N/A | Mixed (`.text`, `.value`) | `.value` everywhere |
| Alignment | Manual calc | Manual calc | `align = "center"/"right"` |
| Cursor advance | Horizontal | Vertical | Horizontal (match ImGui) |
| Error messages | Cryptic | Cryptic | Clear, helpful errors |
| ImGui interop | N/A | Undocumented | SameLine works, SetNext* doesn't |
| Widget colors | N/A | Raw + presets | Presets only (semantic) |
| Complex widgets | ID-keyed state | Explicit retained | Hidden state (like ImGui) |
| Panel regions | N/A | Declarative config | Callback + context injection |
