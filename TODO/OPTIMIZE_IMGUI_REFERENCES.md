# Optimize ImGui References for AI Reading

## Problem

Current reference files are **too large** for AI assistants to use effectively:

- `imgui_defs.lua` - **824KB, 22,000 lines** (type definitions)
- `ReaImGui_Demo.lua` - **439KB** (demo code)

**Issues:**
- ❌ AI can't read entire file (token limits)
- ❌ Waste context on irrelevant content
- ❌ Can't find important patterns in the noise
- ❌ Need to grep multiple times to find what's needed

## Solution: Create AI-Friendly Summaries

### Structure
```
reference/imgui/
├── ReaImGui_Demo.lua           # Original (keep for manual reference)
├── imgui_defs.lua              # Original (keep for LSP)
├── README.md                   # Usage guide
├── patterns/                   # ← NEW: Extracted patterns (AI-friendly)
│   ├── INDEX.md               # Quick index of all patterns
│   ├── widgets.md             # Widget patterns (Button, Checkbox, etc.)
│   ├── menus.md               # Menu/MenuItem patterns
│   ├── popups.md              # Popup patterns
│   ├── tables.md              # Table API patterns
│   ├── trees.md               # TreeNode patterns
│   ├── layout.md              # Layout helpers (SameLine, Spacing, etc.)
│   └── begin_end.md           # All Begin/End pairs
└── signatures/                 # ← NEW: Common function signatures (AI-friendly)
    ├── INDEX.md               # Quick lookup
    ├── widgets.md             # Button, Checkbox, Slider, etc.
    ├── containers.md          # BeginChild, BeginGroup, etc.
    └── utilities.md           # Text, SameLine, Separator, etc.
```

---

## reference/imgui/patterns/INDEX.md

```markdown
# ImGui Pattern Index

Quick reference for finding patterns in the full demo.

## Widgets (Single-Frame)

| Widget | Pattern | Line | See |
|--------|---------|------|-----|
| Button | `if Button() then` | ~800 | [widgets.md](./widgets.md#button) |
| Checkbox | `rv, val = Checkbox()` | ~850 | [widgets.md](./widgets.md#checkbox) |
| InputText | `rv, text = InputText()` | ~1200 | [widgets.md](./widgets.md#inputtext) |
| Slider | `rv, val = SliderInt()` | ~1400 | [widgets.md](./widgets.md#slider) |
| Combo | `BeginCombo/EndCombo` | ~1300 | [widgets.md](./widgets.md#combo) |

## Multi-Frame (Begin/End)

| Pattern | Usage | Line | See |
|---------|-------|------|-----|
| BeginMenu/EndMenu | Nested menus | ~690 | [menus.md](./menus.md) |
| BeginPopup/EndPopup | Simple popup | ~1090 | [popups.md](./popups.md) |
| BeginTable/EndTable | Data tables | ~2500 | [tables.md](./tables.md) |
| TreeNode/TreePop | Hierarchies | ~1800 | [trees.md](./trees.md) |
| BeginChild/EndChild | Scrollable region | ~1500 | [begin_end.md](./begin_end.md#child) |

## Layout Helpers

| Function | Purpose | See |
|----------|---------|-----|
| SameLine | Horizontal layout | [layout.md](./layout.md#sameline) |
| Separator | Visual divider | [layout.md](./layout.md#separator) |
| Spacing | Add vertical space | [layout.md](./layout.md#spacing) |
| Indent/Unindent | Indentation | [layout.md](./layout.md#indent) |
| BeginGroup/EndGroup | Lock layout | [layout.md](./layout.md#group) |
```

---

## reference/imgui/patterns/widgets.md

```markdown
# Widget Patterns

Extracted from ReaImGui_Demo.lua for AI reading.

## Button

### Simple Button
```lua
if ImGui.Button(ctx, "Click Me") then
    handle_click()
end
```

**Returns:** `boolean` - true if clicked

### Button with Size
```lua
if ImGui.Button(ctx, "Click Me", 100, 30) then
    handle_click()
end
```

**Signature:** `Button(ctx, label, size_x, size_y) -> boolean`

### ARKITEKT Equivalent
```lua
-- Positional (after hybrid API)
if Ark.Button.draw(ctx, "Click Me", 100, 30).clicked then
    handle_click()
end

-- Opts table
if Ark.Button.draw(ctx, {
    label = "Click Me",
    width = 100,
    height = 30,
    on_click = handle_click,  -- Improvement!
}).clicked then end
```

---

## Checkbox

### Basic Usage
```lua
local changed, value = ImGui.Checkbox(ctx, "Enable", current_value)
if changed then
    config.enabled = value
end
```

**Returns:** `boolean, boolean` - (changed, new_value)

### ARKITEKT Equivalent
```lua
local result = Ark.Checkbox.draw(ctx, "Enable", current_value)
if result.changed then
    config.enabled = result.value
end
```

---

## InputText

### Basic Usage
```lua
local changed, text = ImGui.InputText(ctx, "Name", current_text)
if changed then
    name = text
end
```

**Returns:** `boolean, string` - (changed, new_text)

### With Flags
```lua
local changed, text = ImGui.InputText(ctx, "Name", current_text,
    ImGui.InputTextFlags_EnterReturnsTrue)
```

### ARKITEKT Equivalent
```lua
local result = Ark.InputText.draw(ctx, "Name", current_text)
if result.changed then
    name = result.text
end

-- With options
local result = Ark.InputText.draw(ctx, {
    label = "Name",
    text = current_text,
    hint = "Enter your name",
    on_enter = submit_form,  -- Improvement!
})
```

---

## Slider

### SliderInt
```lua
local changed, value = ImGui.SliderInt(ctx, "Volume", current, 0, 100)
if changed then
    volume = value
end
```

**Returns:** `boolean, number`

### SliderFloat
```lua
local changed, value = ImGui.SliderFloat(ctx, "Speed", current, 0.0, 1.0, "%.2f")
```

### ARKITEKT Equivalent
```lua
local result = Ark.Slider.draw(ctx, "Volume", current, 0, 100)
if result.changed then
    volume = result.value
end

-- With format
local result = Ark.Slider.draw(ctx, {
    label = "Speed",
    value = current,
    min = 0.0,
    max = 1.0,
    format = "%.2f",
})
```

---

## Combo

### Basic Combo
```lua
if ImGui.BeginCombo(ctx, "##combo", preview_value) then
    for _, item in ipairs(items) do
        local is_selected = (item == current)
        if ImGui.Selectable(ctx, item, is_selected) then
            current = item
        end
    end
    ImGui.EndCombo(ctx)
end
```

**Pattern:** Begin/End pair

### ARKITEKT Equivalent
```lua
local result = Ark.Combo.draw(ctx, {
    label = "##combo",
    preview = preview_value,
    items = items,
    selected = current,
})
if result.changed then
    current = result.selected
end
```

**Improvement:** No manual Selectable loop, auto-handled!
```

---

## reference/imgui/patterns/menus.md

```markdown
# Menu Patterns

## MenuBar

### Basic Menu Bar
```lua
if ImGui.BeginMenuBar(ctx) then
    if ImGui.BeginMenu(ctx, "File") then
        if ImGui.MenuItem(ctx, "Open") then open_file() end
        if ImGui.MenuItem(ctx, "Save") then save_file() end
        ImGui.EndMenu(ctx)
    end
    ImGui.EndMenuBar(ctx)
end
```

**Pattern:** `BeginMenuBar/EndMenuBar` wraps `BeginMenu/EndMenu`

### ARKITEKT Target
```lua
if Ark.Menu.begin_menu_bar(ctx) then
    if Ark.Menu.begin_menu(ctx, "File") then
        Ark.Menu.item(ctx, {label = "Open", on_click = open_file})
        Ark.Menu.item(ctx, {label = "Save", on_click = save_file})
        Ark.Menu.end_menu(ctx)
    end
    Ark.Menu.end_menu_bar(ctx)
end
```

**Decision:** Match Begin/End pattern (stateful operation)

---

## Nested Menus

### ImGui
```lua
if ImGui.BeginMenu(ctx, "File") then
    if ImGui.BeginMenu(ctx, "Recent") then  -- Nested!
        ImGui.MenuItem(ctx, "file1.txt")
        ImGui.MenuItem(ctx, "file2.txt")
        ImGui.EndMenu(ctx)
    end
    ImGui.EndMenu(ctx)
end
```

**Key:** BeginMenu can nest inside BeginMenu

---

## MenuItem

### Simple
```lua
if ImGui.MenuItem(ctx, "Open") then
    open_file()
end
```

### With Shortcut
```lua
if ImGui.MenuItem(ctx, "Save", "Ctrl+S") then
    save_file()
end
```

### With Selected State
```lua
local clicked, selected = ImGui.MenuItem(ctx, "Option", nil, is_selected)
if clicked then
    is_selected = selected
end
```

**Returns:** `boolean, boolean` - (clicked, new_selected)
```

---

## reference/imgui/signatures/INDEX.md

```markdown
# Function Signature Quick Reference

Condensed from imgui_defs.lua (22,000 lines → readable)

## Widgets

```lua
-- Button
Button(ctx, label) -> boolean
Button(ctx, label, size_x, size_y) -> boolean

-- Checkbox
Checkbox(ctx, label, checked) -> boolean, boolean  -- (changed, new_value)

-- InputText
InputText(ctx, label, text) -> boolean, string  -- (changed, new_text)
InputText(ctx, label, text, flags) -> boolean, string

-- Slider
SliderInt(ctx, label, value, min, max) -> boolean, number
SliderInt(ctx, label, value, min, max, format, flags) -> boolean, number
SliderFloat(ctx, label, value, min, max) -> boolean, number

-- Combo
BeginCombo(ctx, label, preview_value) -> boolean
BeginCombo(ctx, label, preview_value, flags) -> boolean
EndCombo(ctx)

-- Selectable
Selectable(ctx, label) -> boolean
Selectable(ctx, label, selected) -> boolean
Selectable(ctx, label, selected, flags, size_x, size_y) -> boolean
```

## Menus

```lua
BeginMenuBar(ctx) -> boolean
EndMenuBar(ctx)

BeginMenu(ctx, label) -> boolean
BeginMenu(ctx, label, enabled) -> boolean
EndMenu(ctx)

MenuItem(ctx, label) -> boolean
MenuItem(ctx, label, shortcut) -> boolean
MenuItem(ctx, label, shortcut, selected) -> boolean, boolean
```

## Popups

```lua
OpenPopup(ctx, str_id)
OpenPopup(ctx, str_id, popup_flags)

BeginPopup(ctx, str_id) -> boolean
BeginPopup(ctx, str_id, window_flags) -> boolean
EndPopup(ctx)

BeginPopupModal(ctx, name) -> boolean, boolean  -- (visible, open)
```

## Tables

```lua
BeginTable(ctx, str_id, column_count) -> boolean
BeginTable(ctx, str_id, column_count, flags) -> boolean
EndTable(ctx)

TableNextRow(ctx)
TableNextColumn(ctx) -> boolean

TableSetupColumn(ctx, label)
TableSetupColumn(ctx, label, flags, init_width_or_weight, user_id)

TableHeadersRow(ctx)
```

## Layout

```lua
SameLine(ctx)
SameLine(ctx, offset_from_start_x, spacing)

Separator(ctx)

Spacing(ctx)

Indent(ctx)
Indent(ctx, indent_w)
Unindent(ctx)
Unindent(ctx, indent_w)

BeginGroup(ctx)
EndGroup(ctx)

Dummy(ctx, size_x, size_y)
```

## Trees

```lua
TreeNode(ctx, label) -> boolean
TreeNode(ctx, label, flags) -> boolean
TreePop(ctx)

CollapsingHeader(ctx, label) -> boolean
CollapsingHeader(ctx, label, visible) -> boolean, boolean
CollapsingHeader(ctx, label, flags) -> boolean
```

## Child Windows

```lua
BeginChild(ctx, str_id) -> boolean
BeginChild(ctx, str_id, size_x, size_y) -> boolean
BeginChild(ctx, str_id, size_x, size_y, child_flags, window_flags) -> boolean
EndChild(ctx)
```
```

---

## Benefits

### For AI Assistants
- ✅ Can read entire pattern file in one request (~500 lines vs 22,000)
- ✅ All relevant examples in one place
- ✅ Quick reference without grepping
- ✅ Includes ARKITEKT equivalents/decisions

### For Developers
- ✅ Quick lookup without opening massive files
- ✅ Organized by category
- ✅ See ImGui + ARKITEKT side-by-side
- ✅ Index for fast navigation

### Maintenance
- ✅ Patterns don't change often (stable)
- ✅ Original files still available (complete reference)
- ✅ Can regenerate summaries if ImGui updates

---

## Implementation

1. Create `reference/imgui/patterns/` directory
2. Extract patterns from ReaImGui_Demo.lua
3. Create `reference/imgui/signatures/` directory
4. Extract common signatures from imgui_defs.lua
5. Create INDEX.md files for quick lookup
6. Update CLAUDE.md to reference patterns/ first

---

## CLAUDE.md Update

```markdown
## ImGui Reference Materials

### Quick Patterns (AI-Friendly)
**Location**: `reference/imgui/patterns/`

Extracted patterns from the demo (500 lines vs 439KB):
- [patterns/INDEX.md](reference/imgui/patterns/INDEX.md) - Quick lookup
- [patterns/widgets.md](reference/imgui/patterns/widgets.md) - Button, Checkbox, etc.
- [patterns/menus.md](reference/imgui/patterns/menus.md) - Menu bar, MenuItem
- [patterns/tables.md](reference/imgui/patterns/tables.md) - Table API
- [patterns/layout.md](reference/imgui/patterns/layout.md) - SameLine, Spacing, etc.

### Function Signatures (AI-Friendly)
**Location**: `reference/imgui/signatures/`

Condensed signatures (500 lines vs 22,000):
- [signatures/INDEX.md](reference/imgui/signatures/INDEX.md) - All signatures at a glance
- [signatures/widgets.md](reference/imgui/signatures/widgets.md)
- [signatures/containers.md](reference/imgui/signatures/containers.md)

### Full References (Manual Use)
- `helpers/ReaImGui_Demo.lua` - Complete demo (439KB)
- `helpers/imgui_defs.lua` - All type definitions (824KB)
```

---

## Success Metrics

- ✅ AI can read pattern file in one request
- ✅ Find widget pattern in <5 seconds
- ✅ See ARKITEKT equivalent immediately
- ✅ No grepping needed for common cases
- ✅ Complete reference still available for edge cases
