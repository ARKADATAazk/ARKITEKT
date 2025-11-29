# ImGui API Coverage Analysis

> **Status of ARKITEKT's coverage of core ImGui patterns**
>
> Generated: 2025-11-27

---

## Purpose

This document tracks which ImGui API patterns ARKITEKT currently matches, which are missing, and which are intentionally improved. It helps answer: **"Can an ImGui user transition to ARKITEKT easily?"**

---

## Summary

| Category | ImGui Pattern | ARKITEKT Status | Notes |
|----------|---------------|-----------------|-------|
| **Primitives** | ✅ | ✅ Improved | Opts-based API, better than ImGui |
| **Menus** | ✅ | ⚠️ Partial | context_menu exists, menu bar missing |
| **Popups** | ✅ | ❌ Missing | No BeginPopup/EndPopup |
| **Tables** | ✅ | ❌ Missing | No table widget |
| **Layout** | ✅ | ⚠️ Unknown | Need to verify helpers exist |
| **Trees** | ✅ | ❌ Missing | No TreeNode/CollapsingHeader |
| **Tabs** | ✅ | ⚠️ Unclear | menutabs.lua exists, unsure if ImGui-like |

---

## Detailed Analysis

### ✅ Well Covered (Improved over ImGui)

#### Primitives (Single-frame widgets)
All use **opts-based API** instead of positional parameters - this is an intentional improvement.

| ImGui | ARKITEKT | Status |
|-------|----------|--------|
| `Button(ctx, label, w, h)` | `Ark.Button.draw(ctx, {label, width, height})` | ✅ Improved |
| `Checkbox(ctx, label, val)` | `Ark.Checkbox.draw(ctx, {label, checked})` | ✅ Improved |
| `InputText(ctx, label, text)` | `Ark.InputText.draw(ctx, {label, text})` | ✅ Improved |
| `SliderInt(ctx, label, v, min, max)` | `Ark.Slider.draw(ctx, {label, value, min, max})` | ✅ Improved |
| `Combo(ctx, label, preview)` | `Ark.Combo.draw(ctx, {label, preview})` | ✅ Improved |

**Philosophy**:
- ✅ Keeps immediate-mode paradigm
- ✅ Return values similar (boolean/result object)
- ✅ Improves with named parameters and callbacks
- ✅ Transition is easy (just switch to opts table)

---

### ⚠️ Partially Covered (Needs Enhancement)

#### Menus

| ImGui Pattern | ARKITEKT | Gap |
|--------------|----------|-----|
| `BeginMenuBar()` / `EndMenuBar()` | ❌ Missing | Need menu bar widget |
| `BeginMenu(label)` / `EndMenu()` | ⚠️ Unclear | Check if context_menu supports this |
| `MenuItem(label, shortcut, selected)` | ⚠️ Unclear | Check context_menu.lua implementation |

**Current State**:
- ✅ Has `arkitekt/gui/widgets/overlays/context_menu.lua` with `M.begin()` / `M.end()`
- ❌ Unknown if it supports nested menus (BeginMenu/EndMenu)
- ❌ Unknown if it has MenuItem equivalent
- ❌ Missing menu bar for main application menus

**What's Needed**:
```lua
-- Match ImGui pattern
if Ark.Menu.begin_menu_bar(ctx) then
  if Ark.Menu.begin_menu(ctx, 'File') then
    Ark.Menu.item(ctx, {label = 'Open', on_click = open_file})
    Ark.Menu.item(ctx, {label = 'Save', on_click = save_file})
    Ark.Menu.separator(ctx)
    Ark.Menu.item(ctx, {label = 'Exit', on_click = exit_app})
    Ark.Menu.end_menu(ctx)
  end
  Ark.Menu.end_menu_bar(ctx)
end
```

**User Story**: "I'm building an app with File/Edit/View menus. In ImGui I use BeginMenuBar, but ARKITEKT doesn't have this."

---

#### Layout Helpers

| ImGui Function | ARKITEKT Equivalent | Status |
|----------------|---------------------|--------|
| `SameLine(offset, spacing)` | ❓ Unknown | Need to verify |
| `Separator()` | ❓ Unknown | Need to verify |
| `Spacing()` | ❓ Unknown | Need to verify |
| `Indent()` / `Unindent()` | ❓ Unknown | Need to verify |
| `BeginGroup()` / `EndGroup()` | ❓ Unknown | Need to verify |
| `Dummy(w, h)` | ❓ Unknown | Need to verify |

**Action Required**: Check if these exist, document them, or create them.

**What's Needed** (if missing):
```lua
-- Match ImGui pattern
Ark.Layout.same_line(ctx, offset, spacing)
Ark.Layout.separator(ctx)
Ark.Layout.spacing(ctx)
Ark.Layout.indent(ctx, amount)
Ark.Layout.unindent(ctx, amount)
```

---

### ❌ Missing (High Priority for ImGui Familiarity)

#### Popups

| ImGui Pattern | ARKITEKT | Impact |
|--------------|----------|--------|
| `OpenPopup(id)` | ❌ Missing | HIGH |
| `BeginPopup(id)` / `EndPopup()` | ❌ Missing | HIGH |
| `BeginPopupModal(title)` / `EndPopup()` | ⚠️ Has overlays | Different API |
| `BeginPopupContextItem()` | ❌ Missing | MEDIUM |

**Current State**:
- ✅ Has overlay system (more complex, higher-level)
- ❌ No simple popup API matching ImGui
- ❌ User can't easily port popup code from ImGui

**What's Needed**:
```lua
-- Match ImGui pattern
if Ark.Button.draw(ctx, {label = 'Open Popup'}).clicked then
  Ark.Popup.open(ctx, 'my_popup')
end

if Ark.Popup.begin_popup(ctx, 'my_popup') then
  Ark.Text.draw(ctx, {text = 'Hello from popup!'})
  if Ark.Button.draw(ctx, {label = 'Close'}).clicked then
    Ark.Popup.close_current(ctx)
  end
  Ark.Popup.end_popup(ctx)
end
```

**User Story**: "I have ImGui code with BeginPopup. ARKITEKT only has overlays which are too complex for a simple confirmation dialog."

---

#### Tables

| ImGui Pattern | ARKITEKT | Impact |
|--------------|----------|--------|
| `BeginTable(id, cols, flags)` | ❌ Missing | HIGH |
| `TableNextRow()` | ❌ Missing | HIGH |
| `TableNextColumn()` | ❌ Missing | HIGH |
| `TableSetupColumn(label)` | ❌ Missing | HIGH |
| `TableHeadersRow()` | ❌ Missing | HIGH |
| `EndTable()` | ❌ Missing | HIGH |

**Current State**:
- ❌ No table widget at all
- ❌ Major blocker for users with data-heavy UIs

**What's Needed**:
```lua
-- Match ImGui pattern
if Ark.Table.begin_table(ctx, 'data', {
  column_count = 3,
  flags = Ark.Table.Flags.Resizable | Ark.Table.Flags.Sortable,
}) then
  Ark.Table.setup_column(ctx, {label = 'Name', flags = Ark.Table.ColumnFlags.WidthFixed, width = 100})
  Ark.Table.setup_column(ctx, {label = 'Size'})
  Ark.Table.setup_column(ctx, {label = 'Type'})
  Ark.Table.headers_row(ctx)

  for _, item in ipairs(items) do
    Ark.Table.next_row(ctx)
    Ark.Table.next_column(ctx)
    Ark.Text.draw(ctx, {text = item.name})
    Ark.Table.next_column(ctx)
    Ark.Text.draw(ctx, {text = tostring(item.size)})
    Ark.Table.next_column(ctx)
    Ark.Text.draw(ctx, {text = item.type})
  end

  Ark.Table.end_table(ctx)
end
```

**User Story**: "I need to display a data table with sortable columns. ImGui has BeginTable, but ARKITEKT has nothing."

---

#### Trees / CollapsingHeader

| ImGui Pattern | ARKITEKT | Impact |
|--------------|----------|--------|
| `TreeNode(label)` / `TreePop()` | ❌ Missing | MEDIUM |
| `CollapsingHeader(label)` | ❌ Missing | MEDIUM |
| `TreeNodeEx(label, flags)` | ❌ Missing | LOW |

**What's Needed**:
```lua
-- Match ImGui pattern
if Ark.Tree.node(ctx, {label = 'Root'}) then
  Ark.Text.draw(ctx, {text = 'Child item 1'})

  if Ark.Tree.node(ctx, {label = 'Subtree'}) then
    Ark.Text.draw(ctx, {text = 'Nested item'})
    Ark.Tree.pop(ctx)
  end

  Ark.Tree.pop(ctx)
end

-- Simpler version for sections
if Ark.Tree.collapsing_header(ctx, {label = 'Section 1'}) then
  Ark.Text.draw(ctx, {text = 'Section content'})
end
```

**User Story**: "I'm building a file browser. ImGui has TreeNode for hierarchies, but ARKITEKT doesn't."

---

#### Child Windows

| ImGui Pattern | ARKITEKT | Impact |
|--------------|----------|--------|
| `BeginChild(id, w, h, border, flags)` | ⚠️ Panel? | Unclear |
| `EndChild()` | ⚠️ Panel? | Unclear |

**Current State**:
- ✅ Has `Panel` widget (complex, high-level)
- ❌ Unknown if simple BeginChild/EndChild exists

**What's Needed** (if Panel doesn't match):
```lua
-- Match ImGui pattern
if Ark.Child.begin_child(ctx, 'child1', {width = 200, height = 300, border = true}) then
  -- Child content with its own scrolling
  for i = 1, 50 do
    Ark.Text.draw(ctx, {text = 'Item ' .. i})
  end
  Ark.Child.end_child(ctx)
end
```

---

### 🎯 Intentionally Different (ARKITEKT is Better)

These diverge from ImGui, but for good reasons:

| ImGui | ARKITEKT | Why Different |
|-------|----------|---------------|
| Style push/pop | Theme system | More maintainable, hot-reload support |
| Manual color values | Presets + theme-aware colors | Consistent, adapts to theme |
| Polling return values only | Callbacks + polling | Convenience, less boilerplate |
| Manual state tracking | Automatic instance management | Simpler user code |
| Positional params (Button) | Opts table | Self-documenting, extensible |

---

## Priority Recommendations

### 🔴 Critical (Blocks Common Use Cases)

1. **Tables** - Major UI pattern, no workaround
2. **Menu Bar** - Essential for desktop apps
3. **Popups** - Common pattern, current overlays are overkill

### 🟡 Important (Frequent Use Cases)

4. **Layout Helpers** - If missing, very inconvenient (SameLine, Separator, etc.)
5. **Trees** - Common for hierarchical data
6. **Nested Menus** - If context_menu doesn't support BeginMenu/EndMenu

### 🟢 Nice to Have

7. **Child Windows** - Panel might already cover this
8. **Tooltips** - Likely already have this
9. **Drag/Drop** - Complex but valuable

---

## How to Use This Document

### For AI Assistants:
When implementing new widgets:
1. Check this document for ImGui equivalent
2. Follow API_DESIGN_PHILOSOPHY.md for design decisions
3. Update this document when adding new widgets
4. Mark items as ✅ when implemented

### For Users:
If you're migrating from ImGui:
1. Check this document to see if the pattern exists
2. Look at the "What's Needed" examples for intended API
3. File issues for missing patterns

### For Maintainers:
When prioritizing work:
1. Focus on 🔴 Critical items first
2. Reference user requests to adjust priorities
3. Consider implementing as Begin/End pairs (match ImGui) for multi-frame stateful operations

---

## Next Steps

1. **Audit**: Verify layout helper status (SameLine, Separator, etc.)
2. **Document**: If they exist, document them clearly
3. **Implement**: Start with critical items (Tables, Menu Bar, Popups)
4. **Test**: Create migration examples showing ImGui → ARKITEKT

---

## References

- [API_DESIGN_PHILOSOPHY.md](../cookbook/API_DESIGN_PHILOSOPHY.md) - When to match vs improve
- [ReaImGui Demo](/helpers/ReaImGui_Demo.lua) - Official ImGui patterns
- [WIDGETS.md](../cookbook/WIDGETS.md) - ARKITEKT widget standards
