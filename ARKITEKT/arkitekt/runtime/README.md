# arkitekt/runtime — Framework Runtime Layer

**Purpose:** Application shell, window chrome, and runtime components.

The `runtime/` folder contains the execution environment that all ARKITEKT applications are built on. It handles the main defer loop, window management, and UI chrome.

---

## Folder Structure

```
runtime/
├── shell.lua              # High-level app runner (main entry point for most apps)
└── chrome/                # Window chrome components
    ├── fonts.lua          # Font loading (Noto Sans + JetBrains Mono + icons)
    ├── icon.lua           # App icon drawing (DPI-aware PNG + vector fallbacks)
    ├── window.lua         # Main window management (Begin/End, body, tabs, fullscreen)
    ├── titlebar.lua       # Custom titlebar (draggable, version, buttons, branding)
    └── status_bar.lua     # Status bar (status text, buttons, resize handle)
```

---

## Getting Started

### Entry Point Pattern

All ARKITEKT apps start with this bootstrap pattern:

```lua
-- Bootstrap ARKITEKT framework
local Ark = dofile(debug.getinfo(1,'S').source:sub(2):match('(.-ARKITEKT[/\\])') .. 'arkitekt' .. package.config:sub(1,1) .. 'init.lua')

-- Use Shell directly from Ark namespace
Ark.Shell.run({
  title = 'My App',
  draw = function(ctx) end,
})

-- Or require explicitly
local Shell = require('arkitekt.runtime.shell')
```

### Simple App Example

```lua
local Ark = dofile(debug.getinfo(1,'S').source:sub(2):match('(.-ARKITEKT[/\\])') .. 'arkitekt' .. package.config:sub(1,1) .. 'init.lua')

Ark.Shell.run({
  title = 'My App',
  version = '1.0.0',

  draw = function(ctx, shell_state)
    Ark.ImGui.Text(ctx, 'Hello, ARKITEKT!')
  end,
})
```

---

## File Descriptions

### `shell.lua`

**High-level app runner.** Main entry point for most ARKITEKT apps. Integrates window, fonts, settings, profiling, and runtime loop.

**Features:**
- Automatic font loading (Noto Sans, JetBrains Mono, Orbitron, Remix icons)
- Window chrome integration (titlebar, status bar)
- Settings persistence (auto-loads from REAPER Data directory)
- Profiling support (optional)
- Tab system support
- Fullscreen/overlay mode

**API:**
```lua
local Shell = require('arkitekt.runtime.shell')

Shell.run({
  -- Basic
  title = 'My App',              -- Window title (required)
  version = '1.0.0',             -- Version string (optional)
  app_name = 'my_app',           -- For settings file (optional)
  draw = function(ctx, state),   -- Draw callback (required)

  -- Window config
  initial_size = { w = 900, h = 600 },
  min_size = { w = 400, h = 300 },

  -- Chrome presets: 'window', 'overlay', 'hud'
  chrome = 'window',

  -- Advanced
  settings = settings_instance,  -- Custom settings (optional)
  tabs = tab_config,             -- Tab system config (optional)
  overlay = overlay_config,      -- Overlay mode config (optional)
  get_status_func = function(),  -- Status bar text (optional)

  -- Callbacks
  on_close = function(),         -- Cleanup callback (optional)
})
```

---

## Chrome Components

### `chrome/window.lua`

**Main window management.** Handles window lifecycle, titlebar, status bar, tabs, fullscreen mode, and profiling.

Used internally by `Shell.run()`. Most apps don't interact with this directly.

### `chrome/titlebar.lua`

**Custom titlebar widget.** Draggable window, app icon, title/version text, branding, maximize/close buttons, and context menu.

Features:
- Branding text (configurable via `Constants.TITLEBAR.branding_text`)
- Custom fonts (Orbitron for branding)
- Icon with context menu (Hub, Metrics, Console, Profiler)
- DPI-aware rendering

### `chrome/status_bar.lua`

**Status bar widget.** Shows status text, optional buttons, and resize handle.

Features:
- Left-aligned status text
- Optional button widgets (right-aligned)
- Resize handle (bottom-right corner)

### `chrome/fonts.lua`

**Font loading utility.** Loads framework fonts and attaches to ImGui context.

**Fonts:**
- Noto Sans (regular, bold) - Baseline for all text
- JetBrains Mono - Monospace/code
- Orbitron Bold - Branding text
- Remix Icon - Icon font

**API:**
```lua
local Fonts = require('arkitekt.runtime.chrome.fonts')

local fonts = Fonts.load(ImGui, ctx, {
  default_size = 13,
  title_size = 16,
  monospace_size = 12,
  orbitron_size = 22,
  icons_size = 14,
})

-- fonts.default, fonts.title, fonts.monospace, fonts.orbitron, fonts.icons
```

### `chrome/icon.lua`

**App icon drawing.** Supports DPI-aware PNG loading and vector fallbacks.

**Features:**
- PNG icon loading with DPI variants (@2x, @4x, @8x, @16x)
- Vector fallbacks (arkitekt logo, simple 'A')
- 22×22 logical pixel size

**API:**
```lua
local Icon = require('arkitekt.runtime.chrome.icon')

-- Load PNG icon
local image = Icon.load_image(ctx, 'ARKITEKT', dpi_scale)
Icon.draw_png(ctx, x, y, size, image)

-- Vector fallbacks
Icon.draw_arkitekt(ctx, x, y, size, color)     -- Original logo
Icon.draw_arkitekt_v2(ctx, x, y, size, color)  -- Refined logo
Icon.draw_simple_a(ctx, x, y, size, color)     -- Simple 'A'
```

---

## Configuration

Framework configuration is centralized in `arkitekt/defs/app.lua`:

```lua
local Constants = require('arkitekt.defs.app')

-- Window defaults
Constants.WINDOW.SMALL = { w = 800, h = 600, min_w = 600, min_h = 400 }
Constants.WINDOW.content_padding = 12

-- Titlebar
Constants.TITLEBAR.height = 26
Constants.TITLEBAR.branding_text = 'AZK'  -- Stylized branding

-- Status bar
Constants.STATUS_BAR.height = 20

-- Overlay
Constants.OVERLAY.SCRIM_OPACITY = 0.99
```

Typography configuration in `arkitekt/defs/typography.lua`:

```lua
local Typography = require('arkitekt.defs.typography')

Typography.SIZE.md = 13        -- Default body text
Typography.SIZE.lg = 16        -- Headings
Typography.SEMANTIC.code = 12  -- Code/monospace

Typography.FAMILY.regular = 'NotoSans-Regular.ttf'
Typography.FAMILY.bold = 'NotoSans-Bold.ttf'
Typography.FAMILY.mono = 'JetBrainsMono-Regular.ttf'
```

---

## Design Principles

1. **Flat hierarchy** - No single-file subdirectories
2. **Self-discovering bootstrap** - Merged into init.lua
3. **Centralized configuration** - Use `defs/` modules
4. **Minimal API surface** - Most apps only need `Ark.Shell.run()`
5. **Font consistency** - Noto Sans + Remix icons as baseline

---

## See Also

- `arkitekt/defs/app.lua` - Framework constants and defaults
- `arkitekt/defs/typography.lua` - Font sizes and families
- `arkitekt/core/config.lua` - Configuration merging utilities
- `arkitekt/core/settings.lua` - Persistent settings system
