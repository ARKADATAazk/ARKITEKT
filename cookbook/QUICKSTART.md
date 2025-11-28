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
├── defs/
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

## 2. Entry Point Template

Create `scripts/MyApp/ARK_MyApp.lua`:

```lua
-- @noindex
-- MyApp - Brief description

-- ============================================================================
-- LOAD ARKITEKT FRAMEWORK
-- ============================================================================
local Ark = dofile(debug.getinfo(1,"S").source:sub(2):match("(.-ARKITEKT[/\\])") .. "loader.lua")

-- ============================================================================
-- IMPORTS
-- ============================================================================
local Shell = require('arkitekt.app.shell')
local Config = require('MyApp.app.config')
local State = require('MyApp.app.state')
local GUI = require('MyApp.ui.init')

-- ============================================================================
-- TOOLBAR STATE (optional - for toggle scripts)
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

-- ============================================================================
-- RUN APPLICATION
-- ============================================================================
SetButtonState(1)

Shell.run({
  title = Config.WINDOW_TITLE,
  width = Config.WINDOW_WIDTH,
  height = Config.WINDOW_HEIGHT,

  on_frame = function(ctx)
    GUI.draw(ctx)
  end,

  on_close = function()
    SetButtonState(0)
    State.save()
  end,
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

local Settings = require('arkitekt.core.settings')
local Ark = require('arkitekt')

-- Private state
local settings = nil
local state = {
  initialized = false,
  -- Add your state fields here
  selected_item = nil,
  items = {},
}

function M.initialize(config)
  if state.initialized then return end

  -- Initialize persistent settings
  local data_dir = Ark._bootstrap.get_data_dir("MyApp")
  settings = Settings.new(data_dir, "settings.json")

  -- Load saved state
  state.selected_item = settings:get("selected_item")

  state.initialized = true
end

function M.save()
  if settings then
    settings:set("selected_item", state.selected_item)
    settings:save()
  end
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
local State = require('MyApp.app.state')

function M.draw(ctx)
  -- Use Ark widgets
  local button_result = Ark.Button.draw(ctx, {
    label = "Click Me",
    width = 120,
  })

  if button_result.clicked then
    reaper.ShowConsoleMsg("Button clicked!\n")
  end

  ImGui.SameLine(ctx)

  -- Or use ImGui directly
  ImGui.Text(ctx, "Hello from MyApp!")

  -- Show selected item
  local selected = State.get_selected_item()
  if selected then
    ImGui.Text(ctx, "Selected: " .. tostring(selected))
  end
end

return M
```

---

## 6. Constants

Create `scripts/MyApp/defs/constants.lua`:

```lua
-- @noindex
local Ark = require('arkitekt')

local M = {}

-- Colors (use theme colors when possible)
M.COLORS = {
  HIGHLIGHT = Ark.Colors.hexrgb("#4A90D9"),
  WARNING = Ark.Colors.hexrgb("#D9A84A"),
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

-- Button
local result = Ark.Button.draw(ctx, {
  label = "Save",
  width = 100,
  tooltip = "Save changes",
})
if result.clicked then ... end

-- Input text
local result = Ark.InputText.draw(ctx, {
  id = "search",
  value = current_value,
  hint = "Search...",
  width = 200,
})
if result.changed then
  current_value = result.value
end

-- Checkbox
local result = Ark.Checkbox.draw(ctx, {
  label = "Enable feature",
  value = is_enabled,
})
if result.changed then
  is_enabled = result.value
end

-- Combo/Dropdown
local result = Ark.Combo.draw(ctx, {
  id = "mode",
  items = {"Option A", "Option B", "Option C"},
  selected = selected_index,
  width = 150,
})
if result.changed then
  selected_index = result.selected
end

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
local color = Ark.Colors.hexrgb("#FF5500")
local with_alpha = Ark.Colors.hexrgba("#FF5500", 0.5)
```

---

## 8. File Organization Rules

| Layer | Purpose | Can Use |
|-------|---------|---------|
| `app/` | Orchestration, state, config | Everything |
| `data/` | Persistence, external APIs | `reaper.*`, no ImGui |
| `domain/` | Business logic | `reaper.*`, no ImGui |
| `ui/` | Views, components | Everything |
| `defs/` | Constants only | Nothing (pure data) |

**Key Rule:** Keep ImGui/UI code out of `domain/` - business logic should be testable without UI.

---

## 9. Minimal Example (Single File)

For simple tools, everything can be in one file:

```lua
-- @noindex
-- Simple Tool

local Ark = dofile(debug.getinfo(1,"S").source:sub(2):match("(.-ARKITEKT[/\\])") .. "loader.lua")
local Shell = require('arkitekt.app.shell')
local ImGui = Ark.ImGui

local state = {
  counter = 0,
}

Shell.run({
  title = "Simple Tool",
  width = 300,
  height = 150,

  on_frame = function(ctx)
    ImGui.Text(ctx, "Counter: " .. state.counter)

    local result = Ark.Button.draw(ctx, {label = "Increment"})
    if result.clicked then
      state.counter = state.counter + 1
    end
  end,
})
```

---

## 10. Next Steps

1. **Read the guides:**
   - [CONVENTIONS.md](CONVENTIONS.md) - Naming and patterns
   - [WIDGETS.md](WIDGETS.md) - Full widget API
   - [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) - Architecture details

2. **Study existing apps:**
   - `scripts/ItemPicker/` - Good example of full structure
   - `scripts/RegionPlaylist/` - Complex state management
   - `scripts/Sandbox/` - Widget experimentation

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
local Theme = require('arkitekt.core.theme')

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
| Widget not rendering | Ensure you're inside `Shell.run` `on_frame` callback |
| State not persisting | Call `settings:save()` in `on_close` |
| Colors wrong | Read `Theme.COLORS` every frame, not at module load |
