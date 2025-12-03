# ARKITEKT Quickstart Guide

> Create a new ARKITEKT app in 5 minutes.

---

## 1. Create App Structure

```
scripts/MyApp/
├── ARK_MyApp.lua           # Entry point
├── app/
│   ├── config.lua          # App configuration
│   └── state.lua           # App state management
├── data/                   # Persistence, API calls
│   └── storage.lua
├── config/
│   ├── constants.lua       # App constants
│   └── defaults.lua        # Default values
├── domain/                 # Business logic (no UI)
│   └── service.lua
├── ui/
│   ├── init.lua            # Main UI entry
│   └── views/              # View components
└── tests/                  # Unit tests
```

---

## 2. Entry Point - Window Mode

Based on **RegionPlaylist** - standard windowed application.

Create `scripts/MyApp/ARK_MyApp.lua`:

```lua
-- @noindex
-- MyApp - Brief description

-- ============================================================================
-- LOAD ARKITEKT FRAMEWORK
-- ============================================================================
local Ark = dofile(debug.getinfo(1,"S").source:sub(2):match("(.-ARKITEKT[/\\])") .. "arkitekt" .. package.config:sub(1,1) .. "init.lua")

-- ============================================================================
-- IMPORTS
-- ============================================================================
local Shell = require('arkitekt.app.shell')
local Settings = require('arkitekt.core.settings')
local Config = require('MyApp.app.config')
local State = require('MyApp.app.state')
local GUI = require('MyApp.ui.init')

-- ============================================================================
-- SETTINGS & STATE INITIALIZATION
-- ============================================================================
local data_dir = Ark._bootstrap.get_data_dir("MyApp")
local settings = Settings.new(data_dir, "settings.json")

State.initialize(settings)

-- Create GUI instance
local gui = GUI.create(State, Config, settings)

-- ============================================================================
-- RUN APPLICATION
-- ============================================================================
Shell.run({
  title        = "My App",
  version      = "v1.0.0",
  settings     = settings,
  initial_pos  = { x = 100, y = 100 },
  initial_size = { w = 900, h = 600 },
  min_size     = { w = 600, h = 400 },
  icon_color   = Ark.Colors.Hexrgb('#4A90D9'),

  draw = function(ctx, shell_state)
    gui:draw(ctx, shell_state.window, shell_state)
  end,

  on_close = function()
    State.save()
  end,
})
```

---

## 2b. Entry Point - Overlay Mode

Based on **ItemPicker** - fullscreen overlay with transparency.

```lua
-- @noindex
-- MyOverlayApp - Fullscreen overlay tool

-- ============================================================================
-- LOAD ARKITEKT FRAMEWORK
-- ============================================================================
local Ark = dofile(debug.getinfo(1,"S").source:sub(2):match("(.-ARKITEKT[/\\])") .. "arkitekt" .. package.config:sub(1,1) .. "init.lua")

-- ============================================================================
-- IMPORTS
-- ============================================================================
local Shell = require('arkitekt.app.shell')
local Config = require('MyOverlayApp.app.config')
local State = require('MyOverlayApp.app.state')
local GUI = require('MyOverlayApp.ui.init')

-- ============================================================================
-- TOOLBAR TOGGLE
-- ============================================================================
local function SetButtonState(set)
  local _, _, sec, cmd = reaper.get_action_context()
  reaper.SetToggleCommandState(sec, cmd, set or 0)
  reaper.RefreshToolbar2(sec, cmd)
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
State.initialize(Config)
local gui = GUI.new(Config, State)

local function cleanup()
  SetButtonState(0)
  State.cleanup()
end

SetButtonState(1)

-- ============================================================================
-- RUN OVERLAY
-- ============================================================================
Shell.run({
  mode = "overlay",
  title = "My Overlay App",
  toggle_button = true,
  app_name = "my_overlay_app",

  overlay = {
    esc_to_close = true,
    close_on_background_right_click = true,
    -- Optional: bypass overlay chrome during drag operations
    should_passthrough = function() return State.is_dragging end,
  },

  draw = function(ctx, state)
    -- Return false to close the overlay
    if State.should_close then
      return false
    end

    gui:draw(ctx, {
      fonts = state.fonts,
      overlay_state = state.overlay or {},
      is_overlay_mode = true,
    })

    return true  -- Keep running
  end,

  on_close = cleanup,
})
```

---

## 3. Config Module

Create `scripts/MyApp/app/config.lua`:

```lua
-- @noindex
local M = {}

-- Window settings
M.WINDOW_TITLE = "My App"
M.WINDOW_WIDTH = 800
M.WINDOW_HEIGHT = 600

-- App-specific settings
M.DEFAULT_SETTING = true
M.MAX_ITEMS = 100

return M
```

---

## 4. State Module

Create `scripts/MyApp/app/state.lua`:

```lua
-- @noindex
local M = {}

-- Private state
local settings = nil
local state = {
  initialized = false,
  -- Add your state fields here
  selected_item = nil,
  items = {},
}

-- Settings passed from entry point (already created there)
function M.initialize(settings_instance)
  if state.initialized then return end

  settings = settings_instance

  -- Load saved state from settings
  state.selected_item = settings:get("selected_item")

  state.initialized = true
end

function M.save()
  if settings then
    settings:set("selected_item", state.selected_item)
    settings:save()
  end
end

function M.cleanup()
  M.save()
  -- Any other cleanup needed
end

-- Getters/setters
function M.get_selected_item()
  return state.selected_item
end

function M.set_selected_item(item)
  state.selected_item = item
end

function M.get_items()
  return state.items
end

function M.set_items(items)
  state.items = items
end

return M
```

---

## 5. UI Module

Create `scripts/MyApp/ui/init.lua`:

```lua
-- @noindex
local M = {}

local Ark = require('arkitekt')
local ImGui = Ark.ImGui

-- Factory function - creates GUI instance with dependencies
function M.create(state, config, settings)
  local self = {
    state = state,
    config = config,
    settings = settings,
  }
  return setmetatable(self, { __index = M })
end

-- Draw function receives ctx and shell_state
function M:draw(ctx, window, shell_state)
  -- Use Ark widgets - positional mode (ImGui-style)
  if Ark.Button(ctx, "Click Me", 120) then
    reaper.ShowConsoleMsg("Button clicked!\n")
  end

  ImGui.SameLine(ctx)

  -- Or use ImGui directly
  ImGui.Text(ctx, "Hello from MyApp!")

  -- Access state through self
  local selected = self.state.get_selected_item()
  if selected then
    ImGui.Text(ctx, "Selected: " .. tostring(selected))
  end

  -- Access window dimensions if needed
  if window then
    ImGui.Text(ctx, string.format("Window: %dx%d", window.w, window.h))
  end
end

return M
```

---

## 6. Constants

Create `scripts/MyApp/config/constants.lua`:

```lua
-- @noindex
local Ark = require('arkitekt')

local M = {}

-- Colors (use theme colors when possible)
M.COLORS = {
  HIGHLIGHT = Ark.Colors.Hexrgb('#4A90D9'),
  WARNING = Ark.Colors.Hexrgb('#D9A84A'),
}

-- Sizes
M.SIZES = {
  TILE_WIDTH = 120,
  TILE_HEIGHT = 80,
  PADDING = 8,
}

-- Timing
M.TIMING = {
  FADE_DURATION = 0.2,
  DEBOUNCE_MS = 100,
}

return M
```

---

## 7. Using Ark Widgets

### Common Widgets

```lua
local Ark = require('arkitekt')

-- Button - Simple positional mode (ImGui-style)
if Ark.Button(ctx, "Save") then
  -- Button was clicked
end

-- Button - With width
if Ark.Button(ctx, "Save", 100) then
  -- Button was clicked
end

-- Button - Opts mode with semantic presets
if Ark.Button(ctx, { label = "Delete", preset = "danger" }) then
  -- Danger-styled button clicked
end

-- Button - Full opts mode returns result object
local result = Ark.Button(ctx, {
  label = "Options",
  preset = "primary",  -- or "danger", "success", "secondary"
  tooltip = "Show options",
  on_click = function() ... end,
  on_right_click = function() ... end,
})
if result.clicked then ... end
if result.right_clicked then ... end

-- Input text - positional mode
local r = Ark.InputText(ctx, 'Search', current_value, 200)
if r.changed then
  current_value = r.value
end

-- Input text - opts mode
local r = Ark.InputText(ctx, {
  id = 'search',
  text = current_value,
  hint = 'Search...',
  width = 200,
})
if r.changed then
  current_value = r.value
end

-- Checkbox - positional mode
local r = Ark.Checkbox(ctx, 'Enable feature', is_enabled)
if r.changed then
  is_enabled = r.value
end

-- Checkbox - opts mode
local r = Ark.Checkbox(ctx, {
  label = 'Enable feature',
  is_checked = is_enabled,
})
if r.changed then
  is_enabled = r.value
end

-- Combo/Dropdown - positional mode
local r = Ark.Combo(ctx, 'Mode', selected_index, {'Option A', 'Option B', 'Option C'})
if r.changed then
  selected_index = r.value
end

-- Combo - opts mode
local r = Ark.Combo(ctx, {
  id = 'mode',
  options = {
    { value = 'a', label = 'Option A' },
    { value = 'b', label = 'Option B' },
  },
  get_value = function() return selected_value end,
  on_change = function(v) selected_value = v end,
})
-- No need to check r.changed when using on_change callback

-- Panel container
local panel = Ark.Panel.new({
  width = 300,
  height = 200,
  title = "My Panel",
})
panel:begin_draw(ctx)
  -- Draw content inside panel
  ImGui.Text(ctx, "Panel content")
panel:end_draw(ctx)

-- Colors
local color = Ark.Colors.Hexrgb('#FF5500')
local with_alpha = Ark.Colors.Hexrgba('#FF5500', 0.5)

-- ID Stack (ImGui-style PushID/PopID)
-- Useful for loops with multiple widgets
for i, track in ipairs(tracks) do
  Ark.PushID(ctx, i)
    if Ark.Button(ctx, "M") then ... end  -- ID = "1/M", "2/M", ...
    if Ark.Button(ctx, "S") then ... end  -- ID = "1/S", "2/S", ...
    Ark.Grid(ctx, { items = track.items })  -- ID = "1/grid", "2/grid", ...
  Ark.PopID(ctx)
end

-- Explicit ID always bypasses stack
Ark.PushID(ctx, "section")
  if Ark.Button(ctx, "Auto") then ... end  -- ID = "section/Auto"
  if Ark.Button(ctx, { id = "fixed", label = "Override" }) then ... end  -- ID = "fixed"
Ark.PopID(ctx)
```

---

## 8. File Organization Rules

| Layer | Purpose | Can Use |
|-------|---------|---------|
| `app/` | Orchestration, state, config | Everything |
| `data/` | Persistence, external APIs | `reaper.*`, no ImGui |
| `domain/` | Business logic | `reaper.*`, no ImGui |
| `ui/` | Views, components | Everything |
| `config/` | Constants only | Nothing (pure data) |

**Key Rule:** Keep ImGui/UI code out of `domain/` - business logic should be testable without UI.

---

## 9. Minimal Example (Single File)

For simple tools, everything can be in one file:

```lua
-- @noindex
-- Simple Tool

local Ark = dofile(debug.getinfo(1,"S").source:sub(2):match("(.-ARKITEKT[/\\])") .. "arkitekt" .. package.config:sub(1,1) .. "init.lua")
local Shell = require('arkitekt.app.shell')
local ImGui = Ark.ImGui

local state = {
  counter = 0,
}

Shell.run({
  title = "Simple Tool",
  initial_size = { w = 300, h = 150 },

  draw = function(ctx, shell_state)
    ImGui.Text(ctx, "Counter: " .. state.counter)

    if Ark.Button(ctx, "Increment") then
      state.counter = state.counter + 1
    end
  end,
})
```

---

## 10. Shell.run Options Reference

### Window Mode (default)

```lua
Shell.run({
  -- Required
  title = "App Name",
  draw = function(ctx, shell_state) end,

  -- Optional - Window
  version = "v1.0.0",
  initial_pos = { x = 100, y = 100 },
  initial_size = { w = 800, h = 600 },
  min_size = { w = 400, h = 300 },

  -- Optional - Appearance
  icon_color = Ark.Colors.Hexrgb('#4A90D9'),
  icon_size = 18,

  -- Optional - Persistence
  settings = settings_instance,  -- Auto-saves window pos/size

  -- Optional - Status bar
  get_status_func = function() return "Status text" end,

  -- Optional - Custom fonts
  fonts = {
    title_size = 24,
    icons = 20,
  },

  -- Optional - Lifecycle
  on_close = function() end,
})
```

### Overlay Mode

```lua
Shell.run({
  mode = "overlay",
  title = "Overlay App",
  toggle_button = true,
  app_name = "my_app",  -- Used for settings storage

  overlay = {
    esc_to_close = true,
    close_on_background_right_click = true,
    should_passthrough = function() return is_dragging end,
  },

  draw = function(ctx, state)
    -- Return false to close overlay
    return true
  end,

  on_close = function() end,
})
```

---

## 11. Next Steps

1. **Study the reference apps:**
   - `scripts/RegionPlaylist/` - **Window mode** reference (state, settings, status bar)
   - `scripts/ItemPicker/` - **Overlay mode** reference (drag handling, passthrough)
   - `scripts/Sandbox/` - Widget experimentation

2. **Read the guides:**
   - [CONVENTIONS.md](CONVENTIONS.md) - Naming and patterns
   - [WIDGETS.md](WIDGETS.md) - Full widget API
   - [ARCHITECTURE.md](ARCHITECTURE.md) - Architecture details

3. **Use the Ark namespace:**
   - `Ark.Button`, `Ark.Panel`, `Ark.Colors`, etc.
   - Lazy-loaded, just access and use

4. **Check CLAUDE.md** for quick reference while coding

---

## Common Patterns

### Persistent Settings

```lua
local Settings = require('arkitekt.core.settings')
local Ark = require('arkitekt')

local data_dir = Ark._bootstrap.get_data_dir("MyApp")
local settings = Settings.new(data_dir, "settings.json")

-- Get/set values
local value = settings:get("key", default_value)
settings:set("key", new_value)
settings:save()
```

### Theme-Aware Colors

```lua
local Theme = require('arkitekt.theme')

-- Read colors every frame (they may change)
local bg = Theme.COLORS.BG_BASE
local text = Theme.COLORS.TEXT_NORMAL
local accent = Theme.COLORS.ACCENT
```

### Frame-Based Image Loading

```lua
local cache = Ark.Images.new({budget = 20, max_cache = 100})

-- In your draw loop
cache:begin_frame()
cache:draw_thumb(ctx, image_path, 64)  -- Handles loading/caching
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Module not found" | Check `package.path` - bootstrap should set it up |
| Widget not rendering | Ensure you're inside `Shell.run` `draw` callback |
| State not persisting | Call `settings:save()` in `on_close` |
| Colors wrong | Read `Theme.COLORS` every frame, not at module load |
| Overlay not closing | Return `false` from `draw` function |
| Window size not working | Use `initial_size = { w = X, h = Y }` not `width`/`height` |
