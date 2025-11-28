# What Is ARKITEKT?

> **ARKITEKT is a UI Toolkit for building ReaImGui applications in REAPER.**

---

## The Umbrella Term

**UI Toolkit** — Similar to:
- Material-UI for React
- Qt for C++
- GTK for Linux apps

ARKITEKT provides the building blocks for polished ReaImGui applications without the boilerplate.

---

## Three Pillars

### 1. Application Framework
```
Shell.run() → Lifecycle, bootstrap, defer loop, cleanup
Chrome     → Titlebar, statusbar, window management
Settings   → Persistence, state management
```

### 2. Design System
```
ThemeManager → Hot-reloadable themes, presets
Theme.COLORS → Semantic color tokens (BG_BASE, TEXT_NORMAL)
Consistency  → All widgets share the same visual language
```

### 3. Component Library
```
Primitives  → Button, Checkbox, Slider, InputText, Combo
Containers  → Panel, SlidingZone, TileGroup
Complex     → Grid, Toolbar, MediaBrowser
```

---

## NOT a Wrapper

**Critical distinction**: ARKITEKT widgets are **custom implementations using ImGui primitives**, not wrappers around ImGui widgets.

| Widget | Implementation | Why |
|--------|----------------|-----|
| Button | DrawList + InvisibleButton | Full control over appearance, animations |
| Checkbox | DrawList + InvisibleButton | Custom checkmark, transitions |
| Slider | DrawList + InvisibleButton | Custom track/thumb styling |
| Combo | DrawList + custom popup | Custom dropdown behavior |
| InputText | **Hybrid**: DrawList frame + ImGui.InputText | Text editing is complex (clipboard, IME, undo) |

### What This Means

```lua
-- We don't do this:
function M.draw(ctx, opts)
  return ImGui.Button(ctx, opts.label)  -- Just a wrapper
end

-- We do this:
function M.draw(ctx, opts)
  local clicked = ImGui.InvisibleButton(ctx, id, w, h)
  local dl = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, bg_color, rounding)
  ImGui.DrawList_AddText(dl, tx, ty, text_color, opts.label)
  return { clicked = clicked, hovered = hovered }
end
```

**Benefits of custom rendering:**
- Full control over appearance
- Smooth hover/click animations
- Consistent styling across all widgets
- Theme changes affect everything uniformly

**Trade-off:**
- Must reimplement features that ImGui provides (disabled state, tooltips)
- Can't use ImGui flags directly (must map to opts)

---

## Relationship to ImGui

```
┌─────────────────────────────────────────────────┐
│                 USER SCRIPTS                     │
├─────────────────────────────────────────────────┤
│   ARKITEKT                                       │
│   ─────────                                      │
│   Ark.Button()     ← Custom DrawList widget      │
│   Ark.Slider()     ← Custom DrawList widget      │
│   Ark.InputText()  ← Hybrid (uses ImGui inside)  │
│   Shell.run()      ← Application framework       │
│   Theme.COLORS     ← Design system               │
├─────────────────────────────────────────────────┤
│   ImGui (Direct Use)                             │
│   ──────────────────                             │
│   ImGui.SameLine()         ← Layout utilities    │
│   ImGui.Separator()        ← Simple primitives   │
│   ImGui.DrawList_*()       ← Low-level drawing   │
│   ImGui.GetMousePos()      ← Input queries       │
│   ImGui.WindowFlags_*      ← Constants/flags     │
├─────────────────────────────────────────────────┤
│                   ReaImGui                       │
├─────────────────────────────────────────────────┤
│                   REAPER API                     │
└─────────────────────────────────────────────────┘
```

---

## When to Use What

| You want to... | Use... |
|---------------|--------|
| Draw a button with callbacks, tooltips, animations | `Ark.Button()` |
| Put widgets on the same line | `ImGui.SameLine()` |
| Draw a custom shape | `ImGui.DrawList_*()` |
| Check if key pressed | `ImGui.IsKeyPressed()` |
| Run an application with window management | `Shell.run()` |
| Apply consistent theming | `Theme.COLORS.*` |

---

## Summary

**ARKITEKT = UI Toolkit**

- **Application Framework**: Shell, lifecycle, chrome
- **Design System**: Themes, colors, presets
- **Component Library**: Custom-rendered widgets

**Key insight**: We use ImGui as a **rendering engine** and **input system**, not as a widget library. Our widgets are custom, giving us full control over appearance and behavior.
