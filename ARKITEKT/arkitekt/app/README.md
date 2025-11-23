# arkitekt/app — Framework Application Layer

**Purpose:** Core framework components for bootstrapping, runtime execution, window chrome, and asset loading.

The `app/` folder contains the foundation that all ARKITEKT applications are built on. It handles initialization, the main defer loop, window management, and visual resources.

---

## Folder Structure

```
app/
├── init/                  # Bootstrap & Configuration
│   ├── init.lua           # Entry point finder (scans upward for bootstrap.lua)
│   ├── bootstrap.lua      # Framework initialization (sets up package.path, validates ImGui)
│   └── constants.lua      # Single source of truth for ALL framework constants
│
├── runtime/               # Execution Layer
│   ├── runtime.lua        # Low-level defer loop manager (owns ImGui context)
│   └── shell.lua          # High-level app runner (integrates everything)
│
├── chrome/                # Window Chrome Components
│   ├── titlebar/
│   │   └── titlebar.lua   # Custom titlebar widget (draggable, buttons, icon)
│   ├── window/
│   │   └── window.lua     # Main window management (Begin/End, body, tabs, docking)
│   └── status_bar/
│       └── widget.lua     # Status bar widget (status text, buttons, resize handle)
│
└── assets/                # Visual Resources
    ├── fonts.lua          # Simple font loader (Inter + JetBrains Mono)
    └── icon.lua           # App icon drawing functions (3 logo variations)
```

---

## File Descriptions

### `init/init.lua` (37 lines)
**Entry point finder.** Scans upward from the calling script's location to find `bootstrap.lua`, then calls it with the root path.

**Why it exists:** Eliminates duplication of the 20-line `init_arkitekt()` function across all entry points.

**API:**
```lua
local Init = dofile(path_to_init_lua)
local ARK = Init.bootstrap()  -- Returns context table or nil
```

### `init/bootstrap.lua` (95 lines)
**Framework initialization.** Sets up `package.path`, validates ReaImGui dependency, loads ImGui module, returns ARK context with utilities.

**Returns:**
```lua
{
  root_path = string,            -- Absolute path to ARKITEKT root
  sep = string,                  -- Platform path separator
  ImGui = module,                -- Pre-loaded ReaImGui module
  dirname = function,            -- Path utility
  join = function,               -- Path utility
  require_framework = function,  -- Helper for loading framework modules
}
```

### `init/constants.lua` (302 lines)
**Single source of truth** for ALL framework configuration. Includes:
- Window sizes, padding, colors
- Typography sizes (body, heading, code, caption)
- Titlebar config (height, buttons, colors)
- Status bar config (height, padding, resize handle)
- Overlay config (animations, positioning, scrim)
- Animation timings (fade, slide, elastic)

**Anti-pattern:** Don't hardcode magic numbers. Use `Constants.OVERLAY.FADE_DURATION` instead of `0.3`.

**API:**
```lua
local Constants = require('arkitekt.defs.app')
local height = Constants.STATUS_BAR.height
local fade_speed = Constants.ANIMATION.FADE_NORMAL
```

### `runtime/runtime.lua` (69 lines)
**Low-level defer loop manager.** Creates ImGui context, owns the main defer loop, calls frame callback.

**API:**
```lua
local Runtime = require('arkitekt.app.runtime.runtime')
local runtime = Runtime.new({
  title = "My App",
  ctx = ctx,  -- Optional: provide existing context
  on_frame = function(ctx) return true end,  -- Return false to close
  on_destroy = function() end,  -- Optional cleanup
})
runtime:start()
runtime:request_close()
```

### `runtime/shell.lua` (341 lines)
**High-level app runner.** Integrates everything: loads fonts, creates window, sets up runtime, handles profiling. This is what most apps use.

**API:**
```lua
local Shell = require('arkitekt.app.runtime.shell')
Shell.run({
  title = "My App",
  version = "1.0.0",
  draw = function(ctx, state) ... end,
  style = MyStyle,       -- Optional
  settings = settings,   -- Optional
  overlay = overlay_mgr, -- Optional
  tabs = {...},          -- Optional
  -- window/font overrides...
})
```

**Two font loading systems:**
- **Simple:** `assets/fonts.lua` - For custom entry points that don't use Shell
- **Advanced:** `shell.lua:load_fonts()` - Supports icons, time_display, titlebar_version, profiling

### `chrome/titlebar/titlebar.lua` (~400 lines)
**Custom titlebar widget.** Draggable area, title/version display, minimize/maximize/close buttons, icon support.

**Features:**
- Draggable area for window movement
- CTRL+ALT+CLICK on icon: Opens debug console
- CTRL+SHIFT+ALT+CLICK on icon: Opens Lua profiler
- Text truncation for long titles
- Configurable button styles (minimal, filled)

**API:**
```lua
local Titlebar = require('arkitekt.app.chrome.titlebar.titlebar')
local titlebar = Titlebar.new({
  title = "My App",
  version = "1.0.0",
  title_font = font_obj,
  version_font = font_obj,
  on_close = function() end,
  on_maximize = function() end,
})
titlebar:render(ctx, is_docked, palette)
```

### `chrome/window/window.lua` (795 lines)
**Main window management.** Handles window Begin/End, body content area, tabs support, docking detection, overlay manager integration.

**Features:**
- Window positioning and sizing
- Tab management (positioning + state sync)
- Docking detection (adjusts background color)
- Overlay integration
- Background color management

**Known Tech Debt:** Contains ~82 lines of unused fullscreen/scrim/fade logic (replaced by OverlayManager system). Should be removed in future cleanup.

**API:**
```lua
local Window = require('arkitekt.app.chrome.window.window')
local window = Window.new({
  title = "My App",
  version = "1.0.0",
  initial_pos = {x = 100, y = 100},
  initial_size = {w = 900, h = 600},
  min_size = {w = 400, h = 300},
  show_titlebar = true,
  show_status_bar = true,
  tabs = {...},  -- Optional
})

local visible, open = window:Begin(ctx)
if visible then
  if window:BeginBody(ctx) then
    -- Draw content here
    window:EndBody(ctx)
  end
end
window:End(ctx)
```

### `chrome/status_bar/widget.lua` (277 lines)
**Status bar widget.** Status text, buttons, resize handle, popup support.

**Features:**
- Left-aligned status text with color
- Status buttons (inline actions)
- Right-aligned text and buttons
- Resize handle (bottom-right corner grip)
- Popup support for complex interactions

**API:**
```lua
local StatusBar = require('arkitekt.app.chrome.status_bar.widget')
local status_bar = StatusBar.new({
  get_status = function()
    return {
      text = "READY",
      color = 0xff6f00ff,  -- Teal
      buttons = {{label = "Action", action = function() end}},
      right_buttons = {{label = "Settings", width = 80, action = function() end}},
    }
  end,
  show_resize_handle = true,
  style = MyStyle,  -- Optional
})

status_bar:render(ctx)
status_bar:set_right_text("Project: MyProject")
status_bar:apply_pending_resize(ctx)  -- Call before window Begin
```

### `assets/fonts.lua` (70 lines)
**Simple font loader.** Loads Inter + JetBrains Mono fonts with size overrides.

**API:**
```lua
local Fonts = require('arkitekt.app.assets.fonts')
local fonts = Fonts.load(ImGui, ctx, {
  default_size = 13,      -- Optional override
  title_size = 16,        -- Optional override
  monospace_size = 13,    -- Optional override
})
-- Returns: {default, default_size, title, title_size, monospace, monospace_size}
```

### `assets/icon.lua` (124 lines)
**App icon drawing functions.** Three Arkitekt logo variations (DPI-aware vector graphics).

**API:**
```lua
local Icon = require('arkitekt.app.assets.icon')
Icon.draw_arkitekt(ctx, x, y, size, color)     -- Original (smaller circles)
Icon.draw_arkitekt_v2(ctx, x, y, size, color)  -- Refined (larger bulbs, faders)
Icon.draw_simple_a(ctx, x, y, size, color)       -- Simple "A" monogram
```

---

## Bootstrap Pattern

**All entry points must use the dofile bootstrap pattern:**

```lua
local ARK
do
  local sep = package.config:sub(1,1)
  local src = debug.getinfo(1, "S").source:sub(2)
  local path = src:match("(.*"..sep..")")
  while path and #path > 3 do
    local init = path .. "arkitekt" .. sep .. "app" .. sep .. "init" .. sep .. "init.lua"
    local f = io.open(init, "r")
    if f then
      f:close()
      local Init = dofile(init)
      ARK = Init.bootstrap()
      break
    end
    path = path:match("(.*"..sep..")[^"..sep.."]-"..sep.."$")
  end
  if not ARK then
    reaper.MB("ARKITEKT framework not found!", "FATAL ERROR", 0)
    return
  end
end
```

**Why dofile, not require?**
The init.lua module can't be `require()`'d until after bootstrap runs and sets up package.path. This creates a chicken-and-egg problem, so we use `dofile()` to load it directly.

---

## Usage Patterns

### Simple App (Shell.run)
```lua
local Shell = require('arkitekt.app.runtime.shell')
Shell.run({
  title = "My App",
  version = "1.0.0",
  draw = function(ctx, state)
    ImGui.Text(ctx, "Hello World")
  end,
})
```

### Advanced App (Custom Runtime)
```lua
local Runtime = require('arkitekt.app.runtime.runtime')
local Window = require('arkitekt.app.chrome.window.window')

local ctx = ImGui.CreateContext("My App")
local window = Window.new({...})

local runtime = Runtime.new({
  ctx = ctx,
  on_frame = function(ctx)
    local visible, open = window:Begin(ctx)
    if visible then
      if window:BeginBody(ctx) then
        -- Custom rendering
        window:EndBody(ctx)
      end
    end
    window:End(ctx)
    return open ~= false
  end,
})
runtime:start()
```

---

## Recent Changes

### 2025-01-19: Status Bar Config Consolidation
- **Deleted:** `chrome/status_bar/constants.lua` (143 lines)
  - Removed dead code: chip config and presets (never used by widget.lua)
  - Removed duplicate `deepMerge`/`merge` functions (already in `core/config`)
- **Updated:** `status_bar/widget.lua` now uses `core/config.deepMerge()` and loads constants from `init/constants.lua`
- **Impact:** -143 lines, single source of truth for config

### 2025-01-19: App Folder Reorganization
- **Reorganized by concern:** init/, runtime/, chrome/, assets/
- **Updated 40+ files** with new require paths
- **Bootstrap path changed:** `app/init.lua` → `app/init/init.lua`
- **Impact:** Clear structure, easier navigation, scalable

### 2025-01-19: Bootstrap Pattern Fix
- **Changed:** Entry points from `require('arkitekt.app.init')` to `dofile()` pattern
- **Reason:** Chicken-and-egg problem (can't require before package.path is configured)
- **Impact:** Fixed "module not found" errors, all 7 entry points now work

### 2025-01-19: Config Files Consolidation
- **Deleted:** `app/config.lua` (orphaned), `app/app_defaults.lua` (duplicate)
- **Consolidated:** All framework defaults into `init/constants.lua`
- **Impact:** -268 lines, single source of truth

---

## Configuration Best Practices

### ✅ DO:
- Use `Constants` for all framework defaults
- Override only when truly app-specific
- Use `core/config.deepMerge()` for config merging
- Document why you're overriding a default

### ❌ DON'T:
- Hardcode magic numbers (use Constants instead)
- Duplicate merge functions (use `core/config`)
- Create app-specific config files for framework concepts
- Override without understanding the default

---

## Known Issues

1. **window.lua fullscreen code** (~82 lines)
   - Unused fullscreen/scrim/fade logic
   - Replaced by OverlayManager system
   - Should be removed in future cleanup

2. **Font loading duplication**
   - Two systems: `assets/fonts.lua` (simple) and `shell.lua:load_fonts()` (advanced)
   - Both exist for different use cases
   - Consider consolidating in future if all apps use Shell

---

## Dependencies

**Required:**
- ReaImGui extension (via ReaPack)
- Lua 5.3 runtime (provided by REAPER)

**Framework modules used:**
- `arkitekt.core.colors` - Color utilities
- `arkitekt.core.config` - Config merging utilities
- `arkitekt.core.settings` - Persistent settings
- `arkitekt.gui.style.*` - Style presets

---

## Testing

To verify app/ components work correctly:

1. **Bootstrap test:** Run any entry point (e.g., `ARK_TemplateBrowser.lua`)
   - Should see framework bootstrap without errors
   - Should see window with titlebar and status bar

2. **Constants test:** Check that magic numbers are eliminated
   ```lua
   -- Bad: ImGui.SetNextWindowSize(ctx, 900, 600)
   -- Good: ImGui.SetNextWindowSize(ctx, Constants.WINDOW.initial_size.w, Constants.WINDOW.initial_size.h)
   ```

3. **Config merging test:** Verify user config overrides work
   ```lua
   Shell.run({
     title = "Test",
     initial_size = {w = 1200, h = 800},  -- Override default
   })
   ```

---

## Future Improvements

1. Remove window.lua fullscreen dead code
2. Consider consolidating font loading systems
3. Add unit tests for bootstrap path scanning
4. Document window.lua tab coordination system better
5. Add examples/ folder with minimal app templates
