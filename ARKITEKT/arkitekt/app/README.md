# arkitekt/app — Framework Application Layer

**Purpose:** Core framework components for bootstrapping, runtime execution, and window chrome.

The `app/` folder contains the foundation that all ARKITEKT applications are built on. It handles initialization, the main defer loop, and window management.

---

## Folder Structure

```
app/
├── bootstrap.lua          # Framework initialization (finds itself, sets up paths, validates deps)
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
local ARK = dofile(debug.getinfo(1,"S").source:sub(2):match("(.-ARKITEKT[/\\])") .. "arkitekt/app/bootstrap.lua").init()
if not ARK then return end

-- Load framework modules
local Shell = require('arkitekt.app.shell')

-- Your app code...
```

### Simple App Example

```lua
local Shell = require('arkitekt.app.shell')

Shell.run({
  title = "My App",
  version = "1.0.0",
  app_name = "my_app",  -- For settings persistence

  draw = function(ctx, shell_state)
    ImGui.Text(ctx, "Hello, ARKITEKT!")
  end,
})
```

---

## File Descriptions

### `bootstrap.lua` (200 lines)

**Framework initialization.** Scans upward to find itself, sets up `package.path`, validates dependencies (ReaImGui, SWS, JS API), returns ARK context.

**Key features:**
- Self-discovering (no hardcoded paths)
- Dependency validation with helpful error messages
- Sets up package paths for framework and scripts
- Returns utility functions and pre-loaded ImGui

**API:**
```lua
local ARK = dofile("path/to/bootstrap.lua").init()

-- ARK context contains:
{
  root_path = string,            -- Absolute path to ARKITEKT root
  sep = string,                  -- Platform path separator ("/" or "\\")
  ImGui = module,                -- Pre-loaded ReaImGui 0.10
  dirname = function(path),      -- Get directory from path
  join = function(a, b),         -- Join path segments
  get_data_dir = function(name), -- Get app data directory
  require_framework = function(module), -- Load framework module
}
```

---

### `shell.lua` (424 lines)

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
Shell.run({
  -- Basic
  title = "My App",              -- Window title (required)
  version = "1.0.0",             -- Version string (optional)
  app_name = "my_app",           -- For settings file (optional)
  draw = function(ctx, state),   -- Draw callback (required)

  -- Window config
  initial_size = { w = 900, h = 600 },
  min_size = { w = 400, h = 300 },
  show_titlebar = true,
  show_status_bar = true,
  show_icon = true,

  -- Advanced
  settings = settings_instance,  -- Custom settings (optional)
  tabs = tab_config,             -- Tab system config (optional)
  overlay = overlay_config,      -- Overlay mode config (optional)
  get_status_func = function(),  -- Status bar text (optional)

  -- Callbacks
  on_close = function(),         -- Cleanup callback (optional)
})
```

**Also provides:**
```lua
Shell.run_loop({
  ctx = ctx,                     -- ImGui context
  on_frame = function(ctx),      -- Frame callback
  on_close = function(),         -- Cleanup callback
})
```

---

## Chrome Components

### `chrome/window.lua` (~600 lines)

**Main window management.** Handles window lifecycle, titlebar, status bar, tabs, fullscreen mode, and profiling.

Used internally by `Shell.run()`. Most apps don't interact with this directly.

### `chrome/titlebar.lua` (590 lines)

**Custom titlebar widget.** Draggable window, app icon, title/version text, branding, maximize/close buttons, and context menu.

Features:
- Branding text (configurable via `Constants.TITLEBAR.branding_text`)
- Custom fonts (Orbitron for branding)
- Icon with context menu (Hub, Metrics, Console, Profiler)
- DPI-aware rendering

### `chrome/status_bar.lua` (275 lines)

**Status bar widget.** Shows status text, optional buttons, and resize handle.

Features:
- Left-aligned status text
- Optional button widgets (right-aligned)
- Resize handle (bottom-right corner)

### `chrome/fonts.lua` (90 lines)

**Font loading utility.** Loads framework fonts and attaches to ImGui context.

**Fonts:**
- Noto Sans (regular, bold) - Baseline for all text
- JetBrains Mono - Monospace/code
- Orbitron Bold - Branding text
- Remix Icon - Icon font

**API:**
```lua
local Fonts = require('arkitekt.app.chrome.fonts')

local fonts = Fonts.load(ImGui, ctx, {
  default_size = 13,
  title_size = 16,
  monospace_size = 12,
  orbitron_size = 22,
  icons_size = 14,
})

-- fonts.default, fonts.title, fonts.monospace, fonts.orbitron, fonts.icons
```

### `chrome/icon.lua` (247 lines)

**App icon drawing.** Supports DPI-aware PNG loading and vector fallbacks.

**Features:**
- PNG icon loading with DPI variants (@2x, @4x, @8x, @16x)
- Vector fallbacks (arkitekt logo, simple "A")
- 22×22 logical pixel size

**API:**
```lua
local Icon = require('arkitekt.app.chrome.icon')

-- Load PNG icon
local image = Icon.load_image(ctx, "ARKITEKT", dpi_scale)
Icon.draw_png(ctx, x, y, size, image)

-- Vector fallbacks
Icon.draw_arkitekt(ctx, x, y, size, color)     -- Original logo
Icon.draw_arkitekt_v2(ctx, x, y, size, color)  -- Refined logo
Icon.draw_simple_a(ctx, x, y, size, color)     -- Simple "A"
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
Constants.TITLEBAR.branding_text = "AZK"  -- Stylized branding

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

Typography.FAMILY.regular = "NotoSans-Regular.ttf"
Typography.FAMILY.bold = "NotoSans-Bold.ttf"
Typography.FAMILY.mono = "JetBrainsMono-Regular.ttf"
```

---

## Migration Notes

### From Old Structure (Pre-2025-01)

**Bootstrap:**
```lua
-- Old
local ARK = dofile("arkitekt/app/init/init.lua").bootstrap()

-- New
local ARK = dofile("arkitekt/app/bootstrap.lua").init()
```

**Require Paths:**
```lua
-- Old
require('arkitekt.app.runtime.shell')
require('arkitekt.app.assets.fonts')
require('arkitekt.app.assets.icon')
require('arkitekt.app.chrome.window.window')
require('arkitekt.app.chrome.titlebar.titlebar')
require('arkitekt.app.chrome.status_bar.widget')

-- New
require('arkitekt.app.shell')
require('arkitekt.app.chrome.fonts')
require('arkitekt.app.chrome.icon')
require('arkitekt.app.chrome.window')
require('arkitekt.app.chrome.titlebar')
require('arkitekt.app.chrome.status_bar')
```

**Fonts:**
```lua
-- Old (Inter/DejaVu)
Typography.FAMILY.regular = "Inter_18pt-Regular.ttf"

-- New (Noto Sans)
Typography.FAMILY.regular = "NotoSans-Regular.ttf"
```

---

## Design Principles

1. **Flat hierarchy** - No single-file subdirectories
2. **Self-discovering bootstrap** - No hardcoded paths
3. **Centralized configuration** - Use `defs/` modules
4. **Minimal API surface** - Most apps only need `Shell.run()`
5. **Font consistency** - Noto Sans + Remix icons as baseline

---

## See Also

- `arkitekt/defs/app.lua` - Framework constants and defaults
- `arkitekt/defs/typography.lua` - Font sizes and families
- `arkitekt/core/config.lua` - Configuration merging utilities
- `arkitekt/core/settings.lua` - Persistent settings system
