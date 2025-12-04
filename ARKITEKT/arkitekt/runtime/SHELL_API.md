# Shell API - ImGui Flags & Chrome Configuration

## Overview

The ARKITEKT Shell supports three primary window modes, each with pre-configured ImGui flags and chrome components:

1. **Window Mode** - Standard application window with full chrome (titlebar, statusbar, controls)
2. **Overlay Mode** - Fullscreen overlay with no chrome, click-through background
3. **HUD Mode** - Always-on-top window with minimal chrome

## Usage

### Basic Mode Selection

```lua
local Shell = require('arkitekt.runtime.shell')

-- Window mode (default)
Shell.run({
  mode = "window",
  title = "My App",
  version = "1.0.0",
  draw = function(ctx, state)
    -- Your UI code here
  end
})

-- Overlay mode
Shell.run({
  mode = "overlay",
  title = "My Overlay",
  draw = function(ctx, state)
    -- Your overlay UI code here
  end
})

-- HUD mode
Shell.run({
  mode = "hud",
  title = "My HUD",
  draw = function(ctx, state)
    -- Your HUD UI code here
  end
})
```

## Mode Presets

### Window Mode
- **ImGui Flags**: `NoTitleBar`, `NoCollapse`, `NoScrollbar`, `NoScrollWithMouse`
- **Chrome**: Full chrome (titlebar, statusbar, icon, version, maximize)

### Overlay Mode
- **ImGui Flags**: `NoTitleBar`, `NoResize`, `NoMove`, `NoCollapse`, `NoScrollbar`, `NoScrollWithMouse`, `NoBackground`
- **Chrome**: No chrome (all disabled)

### HUD Mode
- **ImGui Flags**: `NoTitleBar`, `NoCollapse`, `NoScrollbar`, `NoScrollWithMouse`, `TopMost`
- **Chrome**: Minimal chrome (titlebar only, no controls)

## Custom Configuration

### Custom ImGui Flags

You can override the preset flags with custom ImGui flags:

```lua
-- Using preset name
Shell.run({
  imgui_flags = "hud",  -- Use HUD preset flags
  chrome = "window",     -- But use full chrome
  -- ...
})

-- Using custom flag list
Shell.run({
  imgui_flags = {
    "WindowFlags_NoTitleBar",
    "WindowFlags_NoResize",
    "WindowFlags_TopMost",
  },
  -- ...
})

-- Using raw flag value (legacy)
Shell.run({
  flags = ImGui.WindowFlags_NoTitleBar | ImGui.WindowFlags_NoResize,
  -- ...
})
```

### Custom Chrome Configuration

Control individual chrome components:

```lua
-- Using preset name
Shell.run({
  chrome = "hud",  -- Use HUD chrome preset
  -- ...
})

-- Using custom chrome config
Shell.run({
  chrome = {
    show_titlebar = true,
    show_statusbar = false,
    show_icon = false,
    show_version = false,
    enable_maximize = false,
  },
  -- ...
})
```

## Chrome Component Flags

| Flag | Description | Default |
|------|-------------|---------|
| `show_titlebar` | Show custom titlebar | `true` |
| `show_statusbar` | Show status bar at bottom | `true` |
| `show_icon` | Show icon in titlebar | `true` |
| `show_version` | Show version text in titlebar | `true` |
| `enable_maximize` | Enable maximize button | `true` |

## Examples

### Minimal Window (No Icon, No Version)
```lua
Shell.run({
  mode = "window",
  title = "Minimal Window",
  show_icon = false,
  show_version = false,
  draw = function(ctx, state)
    ImGui.Text(ctx, "Clean titlebar!")
  end
})
```

### Overlay with Custom Flags
```lua
Shell.run({
  imgui_flags = "overlay",
  chrome = "overlay",
  title = "My Overlay",
  draw = function(ctx, state)
    -- Overlay content
  end
})
```

### HUD with Status Bar
```lua
Shell.run({
  mode = "hud",
  show_statusbar = true,  -- Override HUD preset
  draw = function(ctx, state)
    -- HUD content
  end
})
```

## Examples

### Custom Chrome Configuration
```lua
Shell.run({
  chrome = {
    show_titlebar = true,
    show_statusbar = false,
  },
  imgui_flags = 'window',
  -- ...
})
```

## Implementation Details

### Flag Builder

The `build_imgui_flags` utility in `arkitekt.defs.app` handles flag construction:

```lua
local Constants = require('arkitekt.defs.app')

-- Build from preset
local flags = Constants.build_imgui_flags(ImGui, "window")

-- Build from list
local flags = Constants.build_imgui_flags(ImGui, {
  "WindowFlags_NoTitleBar",
  "WindowFlags_TopMost"
})

-- Pass through raw value
local flags = Constants.build_imgui_flags(ImGui, 123456)
```

### Chrome Presets

Chrome presets are defined in `arkitekt.defs.app.CHROME`:

```lua
CHROME = {
  window = {
    show_titlebar = true,
    show_statusbar = true,
    show_icon = true,
    show_version = true,
    enable_maximize = true,
  },
  overlay = {
    -- all false
  },
  hud = {
    show_titlebar = true,
    -- rest false
  },
}
```

## See Also

- `arkitekt.defs.app` - Constants and presets
- `arkitekt.runtime.chrome.window` - Window implementation
- `arkitekt.runtime.chrome.titlebar` - Titlebar implementation
