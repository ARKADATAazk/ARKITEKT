# API Design Philosophy

> **Balancing familiarity with ReaImGui and ARKITEKT improvements**

---

## Core Principle

**Make ARKITEKT feel familiar to ImGui users while improving where it matters.**

Users should be able to:
1. **Transition easily** from ImGui to ARKITEKT
2. **Understand patterns** by mapping ImGui knowledge to ARKITEKT
3. **Benefit from improvements** without learning a completely foreign API

---

## ReaImGui API Patterns (What Users Know)

### 1. Begin/End Pairs
```lua
-- ImGui uses explicit Begin/End for stateful operations
if ImGui.BeginMenu(ctx, 'File') then
  ImGui.MenuItem(ctx, 'Open')
  ImGui.MenuItem(ctx, 'Save')
  ImGui.EndMenu(ctx)
end

if ImGui.BeginCombo(ctx, 'combo', preview) then
  ImGui.Selectable(ctx, 'Option 1')
  ImGui.Selectable(ctx, 'Option 2')
  ImGui.EndCombo(ctx)
end

if ImGui.BeginTable(ctx, 'table', 3) then
  -- table rows
  ImGui.EndTable(ctx)
end
```

**Pattern**: `BeginXXX()` returns boolean, content goes inside, always call `EndXXX()`

### 2. Simple Widgets (Positional Parameters)
```lua
-- ImGui uses positional parameters
if ImGui.Button(ctx, 'Click Me', 100, 30) then
  -- clicked
end

local rv, value = ImGui.Checkbox(ctx, 'Enable', current_value)
local rv, text = ImGui.InputText(ctx, 'Name', current_text)
local rv, num = ImGui.SliderInt(ctx, 'Count', current, 0, 100)
```

**Pattern**: `ctx` first, then label/id, then state (if stateful), then optional params

### 3. Return Values
```lua
-- Boolean for "was interacted with"
if ImGui.Button(ctx, 'Click') then end

-- Multiple returns for stateful widgets
local changed, new_value = ImGui.Checkbox(ctx, 'Toggle', value)
```

### 4. Flags for Configuration
```lua
-- ImGui uses bitwise flags for options
local flags = ImGui.WindowFlags_NoTitleBar | ImGui.WindowFlags_NoResize
ImGui.Begin(ctx, 'Window', true, flags)

local combo_flags = ImGui.ComboFlags_PopupAlignLeft
ImGui.BeginCombo(ctx, 'combo', preview, combo_flags)
```

---

## ARKITEKT Improvements (What We Add)

### 1. Opts-Based API for Widgets
```lua
-- ARKITEKT uses opts tables for clarity and extensibility
Ark.Button.draw(ctx, {
  label = "Click Me",
  width = 100,
  height = 30,
  on_click = function() end,
  tooltip = "Click this button",
  disabled = false,
  preset_name = "BUTTON_SUCCESS",
})
```

**Why better**:
- ✅ Named parameters = self-documenting code
- ✅ Optional parameters don't need nil placeholders
- ✅ Easy to extend without breaking existing code
- ✅ Can add callbacks, tooltips, styling inline

### 2. Standardized Result Objects
```lua
-- ARKITEKT returns structured results
local result = Ark.Button.draw(ctx, {...})
-- result.clicked, result.hovered, result.width, result.height

local result = Ark.Checkbox.draw(ctx, {...})
-- result.changed, result.value, result.clicked
```

**Why better**:
- ✅ Clear what each return value means
- ✅ Can add fields without breaking tuple unpacking
- ✅ Optional access (don't need all values)

### 3. Automatic State Management
```lua
-- ARKITEKT manages widget state internally
Ark.Button.draw(ctx, {
  id = "my_button",
  -- state (hover, animation) handled automatically
})
```

**Why better**:
- ✅ No manual state tracking in user code
- ✅ Animations work out of the box
- ✅ Persistent state across frames

---

## When to Match ImGui vs When to Improve

### ✅ MATCH ImGui Pattern When:

#### 1. Stateful Operations with Explicit Control
**Use Begin/End pairs for operations that span multiple frames or need cleanup**

```lua
-- ✅ GOOD: Match ImGui for menus
function M.begin_menu(ctx, label, opts)
  -- Returns boolean like ImGui
  return ImGui.BeginMenu(ctx, label)
end

function M.end_menu(ctx)
  ImGui.EndMenu(ctx)
end

-- Usage (familiar to ImGui users)
if Ark.Menu.begin_menu(ctx, 'File') then
  Ark.Menu.item(ctx, 'Open')
  Ark.Menu.item(ctx, 'Save')
  Ark.Menu.end_menu(ctx)
end
```

**When**: Dropdowns, popups, menus, tables, trees, drag-drop contexts

#### 2. Function Naming Conventions
```lua
-- ✅ GOOD: Use ImGui-like names for similar concepts
Ark.Window.begin(ctx, title, opts)     -- like ImGui.Begin
Ark.Window.end(ctx)                    -- like ImGui.End

Ark.Menu.begin_menu(ctx, label)        -- like ImGui.BeginMenu
Ark.Menu.end_menu(ctx)                 -- like ImGui.EndMenu

Ark.Layout.same_line(ctx, offset)      -- like ImGui.SameLine
Ark.Layout.separator(ctx)              -- like ImGui.Separator
```

**Why**: Users can map their ImGui knowledge directly

#### 3. Immediate Mode Behavior
```lua
-- ✅ GOOD: Call every frame like ImGui
function my_app(ctx)
  -- Immediate mode: draw every frame
  Ark.Button.draw(ctx, {label = "Click"})
  Ark.Checkbox.draw(ctx, {checked = app.enabled})
end
```

**Why**: Core immediate mode paradigm should stay the same

### ⚡ IMPROVE Over ImGui When:

#### 1. Widgets with Many Optional Parameters
**Use opts table instead of long positional parameter lists**

```lua
-- ❌ BAD: Mimicking ImGui's positional params
Ark.Button.draw(ctx, "Click", 100, 30, false, nil, nil, on_click)
                                      -- ^ lots of nils for optional params

-- ✅ GOOD: Use opts for clarity
Ark.Button.draw(ctx, {
  label = "Click",
  width = 100,
  height = 30,
  on_click = on_click,
})
```

**When**: Buttons, inputs, sliders, checkboxes (most primitives)

#### 2. Styling and Theming
**Use presets and named colors instead of raw values**

```lua
-- ❌ BAD: Raw color values like ImGui
ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0xFF0000FF)
ImGui.Button(ctx, 'Click')
ImGui.PopStyleColor(ctx)

-- ✅ GOOD: Use presets and theme-aware colors
Ark.Button.draw(ctx, {
  label = 'Click',
  preset_name = 'BUTTON_DANGER',
  -- Colors automatically adapt to theme
})
```

**When**: All widgets should support theming out of the box

#### 3. Callbacks Over Polling
**Provide callback opts in addition to return values**

```lua
-- ImGui: Must poll every frame
if ImGui.Button(ctx, 'Click') then
  handle_click()
end

-- ARKITEKT: Can use callback OR poll
Ark.Button.draw(ctx, {
  label = 'Click',
  on_click = handle_click,  -- Callback style
})

-- OR poll the result
local result = Ark.Button.draw(ctx, {label = 'Click'})
if result.clicked then
  handle_click()
end
```

**When**: All interactive widgets

#### 4. Auto-Positioning and Layout
**Provide smart defaults, make manual positioning optional**

```lua
-- ImGui: Must manage cursor manually
ImGui.SetCursorPos(ctx, x, y)
ImGui.Button(ctx, 'Click')

-- ARKITEKT: Auto-cursor by default, manual when needed
Ark.Button.draw(ctx, {
  label = 'Click',
  -- x, y optional - uses cursor by default
})

Ark.Button.draw(ctx, {
  label = 'Positioned',
  x = 100, y = 50,  -- Manual override when needed
})
```

**When**: All drawable widgets

---

## API Design Checklist

When creating or refactoring a widget, ask:

### 1. Is it stateful with lifecycle?
- ✅ YES → Use `begin_xxx()` / `end_xxx()` pattern (match ImGui)
- ❌ NO → Use single `draw()` call (ARKITEKT style)

### 2. Does it have >3 optional parameters?
- ✅ YES → Use opts table (ARKITEKT style)
- ❌ NO → Consider positional params (match ImGui)
  - **Exception**: Still use opts for consistency with other ARKITEKT widgets

### 3. Would users need to write boilerplate every time?
- ✅ YES → Add convenience wrappers or smart defaults (ARKITEKT improvement)
- ❌ NO → Keep it simple (match ImGui)

### 4. Does ImGui have an equivalent?
- ✅ YES → Keep naming similar (e.g., `same_line` not `nextHorizontal`)
- ❌ NO → Use ARKITEKT conventions

### 5. Does it involve complex state management?
- ✅ YES → Handle internally, expose simple API (ARKITEKT improvement)
- ❌ NO → Explicit control (match ImGui)

---

## Examples: Good Balances

### Button (Single-Frame Widget)
```lua
-- ✅ GOOD: opts-based, but return value still boolean-like
local result = Ark.Button.draw(ctx, {
  label = "Click",
  on_click = function() end,  -- ARKITEKT: convenience callback
})
if result.clicked then end  -- Still can poll like ImGui
```

### Menu (Multi-Frame Stateful)
```lua
-- ✅ GOOD: Begin/End like ImGui, but with opts improvements
if Ark.Menu.begin_menu(ctx, 'File', {enabled = can_save}) then
  Ark.Menu.item(ctx, {label = 'Open', on_click = open_file})
  Ark.Menu.item(ctx, {label = 'Save', on_click = save_file})
  Ark.Menu.end_menu(ctx)
end
```

### Splitter (Utility Widget)
```lua
-- ✅ GOOD: Single draw call, clear result
local result = Ark.Splitter.draw(ctx, {
  orientation = "horizontal",
  width = 400,
  thickness = 8,
  on_drag = function(new_pos) end,  -- ARKITEKT: callback
})
-- result.action = "drag" | "reset" | "none"
-- result.position = new position
```

### Table (Complex Multi-Frame)
```lua
-- ✅ GOOD: Match ImGui's Begin/End, enhance with opts
if Ark.Table.begin_table(ctx, 'data', {
  column_count = 3,
  flags = Ark.Table.Flags.Resizable | Ark.Table.Flags.Sortable,
}) then
  Ark.Table.setup_column(ctx, {label = 'Name'})
  Ark.Table.setup_column(ctx, {label = 'Size'})
  Ark.Table.setup_column(ctx, {label = 'Type'})
  Ark.Table.headers_row(ctx)

  for _, item in ipairs(items) do
    Ark.Table.next_row(ctx)
    Ark.Table.next_column(ctx)
    Ark.Text.draw(ctx, {text = item.name})
    -- ...
  end

  Ark.Table.end_table(ctx)
end
```

---

## Documentation Standards

When documenting ARKITEKT APIs:

### 1. Show ImGui Comparison
```lua
--- Draw a button widget
---
--- **ImGui equivalent:**
--- ```lua
--- if ImGui.Button(ctx, 'Click', 100, 30) then
---   handle_click()
--- end
--- ```
---
--- **ARKITEKT improvement:**
--- ```lua
--- local result = Ark.Button.draw(ctx, {
---   label = 'Click',
---   width = 100,
---   height = 30,
---   on_click = handle_click,
--- })
--- ```
```

### 2. Highlight Improvements
```lua
--- @param opts table Widget options
---   - Supports named parameters (no nil placeholders)
---   - Optional callback: on_click = function() end
---   - Auto-positioning: x, y optional
---   - Theme integration: preset_name for styling
```

### 3. Migration Notes
For widgets that diverge significantly, add migration notes:
```lua
--- **Migrating from ImGui:**
--- - Instead of: `ImGui.Button(ctx, label, w, h)`
--- - Use: `Ark.Button.draw(ctx, {label = label, width = w, height = h})`
--- - Optional: Add `on_click` callback to avoid polling
```

---

## Summary

| Aspect | Match ImGui | Improve |
|--------|------------|---------|
| **Naming** | ✅ Similar names (`begin_menu`, `same_line`) | ❌ Don't invent new terms |
| **Begin/End** | ✅ For stateful/lifecycle operations | ❌ Not for single-frame widgets |
| **Return values** | ✅ Boolean for interaction | ⚡ Add result object for details |
| **Parameters** | ❌ Not long positional lists | ✅ Use opts tables |
| **State** | ❌ Don't require manual tracking | ✅ Handle internally |
| **Styling** | ❌ Don't use raw color values | ✅ Use presets and themes |
| **Callbacks** | ⚡ Support both polling and callbacks | ✅ Provide callback opts |
| **Layout** | ✅ Manual positioning available | ⚡ Auto-cursor by default |

**Golden Rule**: If an ImGui user would be confused or lost, you've diverged too far. If they don't benefit from ARKITEKT's improvements, you haven't diverged enough.

---

## References

- [ReaImGui Demo](/helpers/ReaImGui_Demo.lua) - Official ImGui patterns
- [WIDGETS.md](./WIDGETS.md) - ARKITEKT widget standards
- [CONVENTIONS.md](./CONVENTIONS.md) - Code style guide
