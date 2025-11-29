# Keyboard Shortcuts Guide

> How to handle keyboard input in ARKITEKT scripts.

---

## Input Handling Approaches

| Method | Use For | Example |
|--------|---------|---------|
| **ImGui shortcuts** | Widget-specific (focused) | Text input, lists |
| **Global polling** | App-wide shortcuts | Ctrl+N, Esc, F-keys |
| **Action context** | REAPER action toolbar | Toggle button state |

---

## ImGui Keyboard Input

### Focused Widget Input

```lua
-- Check if widget has keyboard focus
if ImGui.IsItemFocused(ctx) then
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
    -- Handle Enter
  end

  if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
    -- Handle Esc
  end
end
```

### Common Keys

```lua
ImGui.Key_Enter
ImGui.Key_Escape
ImGui.Key_Tab
ImGui.Key_Backspace
ImGui.Key_Delete
ImGui.Key_Space
ImGui.Key_LeftArrow
ImGui.Key_RightArrow
ImGui.Key_UpArrow
ImGui.Key_DownArrow
ImGui.Key_Home
ImGui.Key_End
```

### Modifiers

```lua
local ctrl = ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl)
local shift = ImGui.IsKeyDown(ctx, ImGui.Mod_Shift)
local alt = ImGui.IsKeyDown(ctx, ImGui.Mod_Alt)

if ctrl and ImGui.IsKeyPressed(ctx, ImGui.Key_S) then
  -- Ctrl+S: Save
end
```

---

## Global Shortcuts (Polling)

### Pattern

```lua
-- In main draw loop or shortcuts module
local function handle_shortcuts(ctx)
  -- Skip if typing in input field
  if ImGui.IsAnyItemActive(ctx) then return end

  local ctrl = ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl)
  local shift = ImGui.IsKeyDown(ctx, ImGui.Mod_Shift)

  -- Ctrl+N: New item
  if ctrl and ImGui.IsKeyPressed(ctx, ImGui.Key_N) then
    create_new_item()
  end

  -- Delete: Remove selected
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Delete) then
    delete_selected()
  end

  -- Esc: Clear selection or close
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
    if has_selection() then
      clear_selection()
    else
      close_app()
    end
  end
end

-- Call in draw function
function draw(ctx)
  handle_shortcuts(ctx)
  -- ... rest of UI
end
```

### Skip When Typing

```lua
-- Don't trigger shortcuts when user is typing
if ImGui.IsAnyItemActive(ctx) then
  return  -- Skip shortcut handling
end
```

---

## Shortcut Module Pattern

### Organize Shortcuts

```lua
-- ui/shortcuts.lua
local M = {}

function M.handle(ctx, state)
  -- Skip if typing
  if ImGui.IsAnyItemActive(ctx) then return end

  local ctrl = ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl)
  local shift = ImGui.IsKeyDown(ctx, ImGui.Mod_Shift)

  -- File operations
  if ctrl and ImGui.IsKeyPressed(ctx, ImGui.Key_N) then
    state.callbacks.new_playlist()
  end

  if ctrl and ImGui.IsKeyPressed(ctx, ImGui.Key_S) then
    state.callbacks.save()
  end

  -- Navigation
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Tab) then
    state.callbacks.next_item()
  end

  if shift and ImGui.IsKeyPressed(ctx, ImGui.Key_Tab) then
    state.callbacks.prev_item()
  end

  -- Deletion
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Delete) then
    state.callbacks.delete_selected()
  end
end

return M
```

### Usage

```lua
local Shortcuts = require('MyApp.ui.shortcuts')

function draw(ctx)
  Shortcuts.handle(ctx, {
    callbacks = {
      new_playlist = function() ... end,
      save = function() ... end,
      next_item = function() ... end,
      prev_item = function() ... end,
      delete_selected = function() ... end,
    }
  })

  -- ... rest of UI
end
```

---

## Overlay Mode Shortcuts

### ESC to Close

```lua
Shell.run({
  mode = "overlay",
  overlay = {
    esc_to_close = true,  -- Built-in ESC handling
  },

  draw = function(ctx, state)
    -- Custom ESC handling (if needed)
    if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
      return false  -- Close overlay
    end

    -- ... UI
    return true  -- Keep running
  end,
})
```

---

## Toolbar Button Toggle

### Action Context Pattern

```lua
-- Toggle button state in REAPER toolbar
local function SetButtonState(set)
  local _, _, sec, cmd = reaper.get_action_context()
  reaper.SetToggleCommandState(sec, cmd, set or 0)
  reaper.RefreshToolbar2(sec, cmd)
end

-- On script start
SetButtonState(1)

-- On script close
local function cleanup()
  SetButtonState(0)
end

Shell.run({
  on_close = cleanup,
  -- ...
})
```

---

## Common Patterns

### Shortcut Help Display

```lua
local SHORTCUTS = {
  {"Ctrl+N", "New playlist"},
  {"Ctrl+S", "Save"},
  {"Delete", "Remove selected"},
  {"Tab", "Next item"},
  {"Shift+Tab", "Previous item"},
  {"Esc", "Clear selection / Close"},
}

function draw_help(ctx)
  for _, s in ipairs(SHORTCUTS) do
    ImGui.Text(ctx, string.format("%-12s %s", s[1], s[2]))
  end
end
```

### Prevent Conflict with REAPER

```lua
-- For overlays, use `should_passthrough` to let REAPER handle input
Shell.run({
  mode = "overlay",
  overlay = {
    should_passthrough = function()
      -- Pass input to REAPER during specific states
      return is_dragging or user_wants_reaper_input
    end,
  },
})
```

### Debounce Rapid Key Presses

```lua
local last_press_time = 0
local DEBOUNCE_MS = 200

function handle_shortcut(ctx)
  local now = reaper.time_precise()

  if ImGui.IsKeyPressed(ctx, ImGui.Key_Space) then
    if now - last_press_time > DEBOUNCE_MS / 1000 then
      last_press_time = now
      toggle_playback()
    end
  end
end
```

---

## Key Code Reference

### Letters
```lua
ImGui.Key_A .. ImGui.Key_Z
```

### Numbers
```lua
ImGui.Key_0 .. ImGui.Key_9
```

### Function Keys
```lua
ImGui.Key_F1 .. ImGui.Key_F12
```

### Modifiers
```lua
ImGui.Mod_Ctrl
ImGui.Mod_Shift
ImGui.Mod_Alt
ImGui.Mod_Super  -- Windows/Cmd key
```

### Combination Example
```lua
local ctrl = ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl)
local shift = ImGui.IsKeyDown(ctx, ImGui.Mod_Shift)

if ctrl and shift and ImGui.IsKeyPressed(ctx, ImGui.Key_S) then
  -- Ctrl+Shift+S: Save As
end
```

---

## Best Practices

**Do:**
- Skip shortcuts when `IsAnyItemActive()` (user is typing)
- Use dedicated shortcuts module for complex apps
- Document shortcuts (help menu or tooltip)
- Test on both Windows and Mac (Cmd vs Ctrl)

**Don't:**
- Override standard shortcuts (Ctrl+C/V/X/Z) unless necessary
- Forget to check modifiers (prevent accidental triggers)
- Use shortcuts that conflict with REAPER's global shortcuts
- Handle shortcuts in multiple places (centralize)

---

## Quick Reference

```lua
-- Global shortcuts (in draw loop)
if not ImGui.IsAnyItemActive(ctx) then
  local ctrl = ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl)

  if ctrl and ImGui.IsKeyPressed(ctx, ImGui.Key_N) then
    create_new()
  end
end

-- Focused widget
if ImGui.IsItemFocused(ctx) then
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
    submit()
  end
end

-- Overlay ESC
Shell.run({
  mode = "overlay",
  overlay = { esc_to_close = true },
})
```

---

## See Also

- [QUICKSTART.md](./QUICKSTART.md) - App structure examples
- `references/imgui/ReaImGui_Demo.lua` - ImGui input examples
- `references/imgui/imgui_defs.lua` - Full key code list
