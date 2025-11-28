# API Scope: What Gets Wrapped vs What Stays ImGui

> **Clear boundaries for the ARKITEKT API**

---

## The Rule

**Wrap in Ark.* if we add value. Keep as ImGui.* if we don't.**

---

## What STAYS ImGui.* (Don't Wrap)

### Flags & Constants
```lua
-- Just use these directly
ImGui.WindowFlags_NoTitleBar
ImGui.WindowFlags_NoResize
ImGui.Col_Button
ImGui.Cond_FirstUseEver
```

**Why:** Just constants. Renaming adds no value, creates maintenance burden, breaks ImGui documentation compatibility.

### Layout Basics
```lua
ImGui.SameLine(ctx)
ImGui.Separator(ctx)
ImGui.Spacing(ctx)
ImGui.Indent(ctx)
ImGui.Unindent(ctx)
ImGui.NewLine(ctx)
```

**Why:** Simple one-liners. No callbacks, tooltips, or extras possible.

### DrawList Primitives
```lua
ImGui.DrawList_AddLine(dl, x1, y1, x2, y2, color)
ImGui.DrawList_AddRect(dl, ...)
ImGui.DrawList_AddCircle(dl, ...)
ImGui.DrawList_AddText(dl, ...)
```

**Why:** Low-level drawing. Nothing to improve.

### Input Queries
```lua
ImGui.IsKeyPressed(ctx, key)
ImGui.IsMouseClicked(ctx, button)
ImGui.GetMousePos(ctx)
ImGui.GetKeyMods(ctx)
```

**Why:** Pure queries, no side effects, nothing to add.

### Cursor Manipulation
```lua
ImGui.SetCursorPos(ctx, x, y)
ImGui.GetCursorPos(ctx)
ImGui.SetCursorScreenPos(ctx, x, y)
```

**Why:** Low-level positioning. Simple pass-through.

### Context Management
```lua
ImGui.CreateContext(name)
ImGui.DestroyContext(ctx)
```

**Why:** One-time setup. Shell handles this anyway.

---

## What Gets Ark.* Treatment

### Widgets (Add: callbacks, tooltips, disabled, presets, animations)
```lua
Ark.Button(ctx, "Click")
Ark.Checkbox(ctx, "Enable", checked)
Ark.Slider(ctx, "Volume", value, 0, 100)
Ark.InputText(ctx, "Name", text)
Ark.Combo(ctx, "Theme", selected, items)
```

### Shell (Add: lifecycle, chrome, themes, boilerplate removal)
```lua
Shell.run({
  name = "MyApp",
  draw = render,
  chrome = { titlebar = true, statusbar = true },
})
```

### Theme (Add: hot-reload, presets, consistency)
```lua
Theme.COLORS.BG_BASE
Theme.apply_preset(config, "BUTTON_DANGER")
```

### High-Level Patterns (Add: simplified API over Begin/End)
```lua
Ark.Modal(ctx, {...}, content_fn)
Ark.Popup(ctx, {...})
Ark.Table(ctx, {...})
```

### REAPER-Specific (Add: DAW integration)
```lua
Ark.TrackPicker(ctx, {...})
Ark.FXPicker(ctx, {...})
Ark.Settings.bind("MyScript", state)
```

---

## Chrome Options: Positive Naming

### Don't Mirror ImGui's Negative Flags
```lua
-- BAD: Double negatives are confusing
chrome = {
  no_titlebar = false,   -- false means... show it?
  no_resize = true,      -- true means... can't resize?
}

-- GOOD: Positive, obvious meaning
chrome = {
  titlebar = true,       -- Show titlebar
  statusbar = true,      -- Show statusbar
  resizable = true,      -- Can resize
  maximize_button = true, -- Show maximize
  close_button = true,   -- Show close
}
```

**Why:** `titlebar = true` is instantly clear. `no_titlebar = false` requires mental gymnastics.

### Chrome vs ImGui Flags
```lua
Shell.run({
  name = "MyApp",

  -- Ark chrome (high-level, semantic)
  chrome = {
    titlebar = true,
    statusbar = true,
  },

  -- ImGui flags (low-level, escape hatch)
  imgui_flags = ImGui.WindowFlags_AlwaysAutoResize,
})
```

**Ark translates chrome to appropriate ImGui flags internally.**

---

## Shell: What It Provides

| Without Shell | With Shell |
|---------------|------------|
| Manual `CreateContext` | Automatic |
| Manual `defer` loop | Automatic |
| Manual `Begin`/`End` | Automatic |
| Manual font loading | Automatic |
| DIY titlebar/statusbar | Built-in chrome |
| Manual theme loading | Auto hot-reload |
| Manual cleanup | Automatic |
| Different code for Window/Overlay | Just change `mode` |

**Shell is NOT just wrapping Begin/End - it's application scaffolding.**

### Shell Could Add (Future)
```lua
Shell.run({
  name = "MyApp",

  -- Existing
  draw = render,
  initial_size = {800, 600},
  chrome = { titlebar = true },

  -- Future possibilities
  persist_position = true,     -- Remember window position
  persist_size = true,         -- Remember window size
  single_instance = true,      -- Only one window allowed
  keyboard_shortcuts = {
    ["Ctrl+S"] = save,
    ["Ctrl+Z"] = undo,
  },
})
```

---

## Decision Framework Checklist

**Wrap in Ark.* if ANY of these apply:**
- [ ] Can add callbacks/events
- [ ] Can add built-in tooltip
- [ ] Can add disabled state
- [ ] Can add presets/theming
- [ ] Can simplify complex pattern (Begin/End → single call)
- [ ] Can add smooth animations
- [ ] Is REAPER-specific

**Keep as ImGui.* if ALL of these apply:**
- [ ] Just a constant/flag
- [ ] Pure query (no side effects)
- [ ] Simple one-liner
- [ ] No extras possible
- [ ] Low-level drawing primitive

---

## Summary Diagram

```
┌────────────────────────────────────────────────────────┐
│                    USER CODE                           │
├────────────────────────────────────────────────────────┤
│  Ark.*              │  ImGui.*                         │
│  ──────             │  ────────                        │
│  Widgets            │  Flags/Constants                 │
│  Shell              │  Layout basics                   │
│  Theme              │  DrawList                        │
│  Chrome opts        │  Input queries                   │
│  REAPER helpers     │  Cursor manipulation             │
│                     │                                  │
│  "Make it easy"     │  "Make it possible"              │
├────────────────────────────────────────────────────────┤
│                    REAPER API                          │
└────────────────────────────────────────────────────────┘
```
