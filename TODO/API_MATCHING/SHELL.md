# Shell Features

> **What Shell provides and what could be added**

---

## Already Implemented ✅

### Window Lifecycle
```lua
Shell.run({
  name = "MyApp",
  draw = function(ctx, state) ... end,
  on_close = function() ... end,
})
```
- ✅ Context creation/destruction
- ✅ Defer loop management
- ✅ Begin/End wrapping
- ✅ Cleanup on close

### Persistence (Custom, Overrides ImGui .ini)
```lua
Shell.run({
  app_name = "MyApp",  -- Enables persistence
  initial_size = {800, 600},
  initial_pos = {100, 100},
})
```
- ✅ Window position saved/restored
- ✅ Window size saved/restored
- ✅ Maximize state saved/restored
- ✅ Pre-maximize position (for proper un-maximize)
- ✅ Multi-monitor maximize support (js_extension)

**Storage:** `REAPER/Scripts/ARKITEKT/data/<app_name>/settings.json`

### Chrome (Custom Titlebar/Statusbar)
```lua
Shell.run({
  chrome = "window",  -- or "hud", or custom table
  show_titlebar = true,
  show_statusbar = true,
  enable_maximize = true,
})
```
- ✅ Custom titlebar with close/maximize buttons
- ✅ Status bar with custom content
- ✅ Branding text
- ✅ Icon click → Hub launch
- ✅ Version display

### Modes
```lua
Shell.run({
  mode = "window",   -- Standard window with chrome
  -- or
  mode = "overlay",  -- Fullscreen overlay with scrim
  -- or
  mode = "hud",      -- Minimal chrome
})
```
- ✅ Window mode (full chrome)
- ✅ Overlay mode (fullscreen, scrim, close on click)
- ✅ HUD mode (minimal)

### Theme Integration
- ✅ ThemeManager.init() on startup
- ✅ Theme hot-reload support
- ✅ Dock adapt (sync theme when docking)
- ✅ Debug overlay (F12)

### Fonts
- ✅ Auto font loading
- ✅ Multiple font sizes (title, version, monospace, icons)
- ✅ Shared font directory

### Style
- ✅ Auto style loading
- ✅ PushMyStyle/PopMyStyle integration

### Profiling
- ✅ Built-in profiler support
- ✅ Timer tracking for draw/style/settings

### Toolbar Button
```lua
Shell.run({
  toggle_button = true,  -- Manage REAPER toolbar state
})
```

---

## Could Add (Future) 🔮

### Single Instance
```lua
Shell.run({
  single_instance = true,  -- Only one window allowed
})
```
**Use case:** Prevent user from opening multiple instances of same script.

### Keyboard Shortcuts
```lua
Shell.run({
  shortcuts = {
    ["Ctrl+S"] = save_function,
    ["Ctrl+Z"] = undo_function,
    ["Escape"] = close_window,
  },
})
```
**Use case:** Global shortcuts without manual IsKeyPressed checks.

### Menu Bar
```lua
Shell.run({
  menu_bar = {
    File = {
      {"New", new_file},
      {"Open", open_file},
      {"---"},  -- Separator
      {"Exit", close_window},
    },
    Edit = {
      {"Undo", undo, "Ctrl+Z"},
      {"Redo", redo, "Ctrl+Y"},
    },
  },
})
```
**Use case:** Standard app menu bar integrated with chrome.

### Declarative Persistence
```lua
Shell.run({
  persist = {
    position = true,    -- Already works via app_name
    size = true,        -- Already works
    maximize = true,    -- Already works
    custom = {          -- NEW: App-specific data
      last_tab = "settings",
      recent_files = {},
    },
  },
})
```
**Use case:** Declarative custom data persistence.

---

## Current API Reference

### Shell.run(opts)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `name` / `title` | string | "ARKITEKT" | Window title |
| `app_name` | string | nil | Enables persistence |
| `version` | string | nil | Version in titlebar |
| `draw` | function | required | `function(ctx, state)` |
| `on_close` | function | nil | Cleanup callback |
| `mode` | string | "window" | "window", "overlay", "hud" |
| `initial_size` | table | {800,600} | `{w, h}` |
| `initial_pos` | table | nil | `{x, y}` |
| `min_size` | table | nil | `{w, h}` |
| `chrome` | string/table | "window" | Chrome preset or config |
| `show_titlebar` | bool | true | Show custom titlebar |
| `show_statusbar` | bool | true | Show status bar |
| `enable_maximize` | bool | true | Show maximize button |
| `toggle_button` | bool | false | Manage toolbar state |
| `topmost` | bool | false | Always on top |
| `style` | table | auto | Style module |
| `fonts` | table | auto | Font configuration |

### State Object (passed to draw)

```lua
function draw(ctx, state)
  state.window    -- Window instance
  state.settings  -- Settings instance (if app_name provided)
  state.fonts     -- Font handles
  state.style     -- Style module
  state.overlay   -- Overlay manager
  state.profiling -- Profiling data
end
```

---

## Notes

### Why Custom Persistence?

ImGui's .ini persistence doesn't support:
1. **Maximize state** - ImGui has no concept of "maximized"
2. **Pre-maximize position** - Can't restore to original size
3. **Per-app isolation** - ImGui's .ini is shared

Our custom chrome (maximize button) requires custom persistence.

### Override Strategy

```lua
-- window.lua uses Cond_Once to override ImGui's .ini
ImGui.SetNextWindowPos(ctx, pos.x, pos.y, ImGui.Cond_Once)
ImGui.SetNextWindowSize(ctx, size.w, size.h, ImGui.Cond_Once)
```

This applies our saved position ONCE per session, then lets ImGui handle within-session changes.
