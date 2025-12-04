# Hot Reload Design

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Shell.run({ dev_mode = true })                          │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Frame Loop                                             │
│  ├── Check Ctrl+Shift+R                                 │
│  │   └── DevReload.reload(patterns)                     │
│  │       ├── Clear package.loaded[matching]             │
│  │       ├── Re-require entry points                    │
│  │       └── Return reload count                        │
│  │                                                      │
│  └── Show toast if reloaded                             │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## API

### Shell Integration

```lua
Shell.run({
  title = 'My App',
  dev_mode = true,  -- Enables all dev features

  -- Optional: customize dev behavior
  dev = {
    reload_shortcut = 'Ctrl+Shift+R',  -- Default
    reload_patterns = nil,  -- Auto-detect from app name
    show_badge = true,  -- [DEV] in titlebar
  },
})
```

### Manual Usage

```lua
local DevReload = require('arkitekt.debug.reload')

-- Reload all modules matching patterns
local count = DevReload.reload({
  '^ItemPicker%.ui',
  '^ItemPicker%.app%.views',
})

-- Reload with callback (for re-initialization)
DevReload.reload(patterns, function(reloaded_modules)
  -- Recreate UI instances if needed
  app.gui = require('ItemPicker.ui').create(app.state)
end)
```

## Module: arkitekt/debug/reload.lua

```lua
local M = {}

--- Reload modules matching patterns
--- @param patterns string[] Lua patterns to match against package.loaded keys
--- @param on_reload? function Callback after clearing, before re-require
--- @return number count Number of modules cleared
function M.reload(patterns, on_reload)
  local cleared = {}

  for key in pairs(package.loaded) do
    for _, pattern in ipairs(patterns) do
      if key:match(pattern) then
        package.loaded[key] = nil
        cleared[#cleared + 1] = key
        break
      end
    end
  end

  if on_reload then
    on_reload(cleared)
  end

  return #cleared
end

--- Get default patterns for an app
--- @param app_name string e.g., 'ItemPicker'
--- @return string[] patterns
function M.default_patterns(app_name)
  return {
    '^' .. app_name .. '%.ui',
    '^' .. app_name .. '%.app%.views',
    '^' .. app_name .. '%.app%.components',
  }
end

return M
```

## Shell Changes

Location: `arkitekt/runtime/shell.lua`

```lua
-- Near top of file
local DevReload = nil  -- Lazy load

-- In run() function, after context creation
local dev_mode = opts.dev_mode or false
local dev_config = opts.dev or {}

if dev_mode then
  DevReload = require('arkitekt.debug.reload')
end

-- In frame loop, before draw()
if dev_mode then
  -- Check reload shortcut
  local ctrl = ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl)
  local shift = ImGui.IsKeyDown(ctx, ImGui.Mod_Shift)
  local r_pressed = ImGui.IsKeyPressed(ctx, ImGui.Key_R, false)  -- no repeat

  if ctrl and shift and r_pressed then
    local patterns = dev_config.reload_patterns
      or DevReload.default_patterns(opts.title:gsub('%s+', ''))

    local count = DevReload.reload(patterns, function()
      -- Allow app to reinitialize
      if opts.on_reload then
        opts.on_reload()
      end
    end)

    -- Show toast
    if count > 0 then
      show_dev_toast(ctx, string.format('Reloaded %d modules', count))
    end
  end
end

-- Titlebar modification for dev badge
if dev_mode and dev_config.show_badge ~= false then
  window_title = '[DEV] ' .. window_title
end
```

## Toast Implementation

Simple overlay text that fades out:

```lua
local dev_toast = {
  message = nil,
  start_time = 0,
  duration = 1.5,
}

local function show_dev_toast(ctx, message)
  dev_toast.message = message
  dev_toast.start_time = reaper.time_precise()
end

local function draw_dev_toast(ctx)
  if not dev_toast.message then return end

  local elapsed = reaper.time_precise() - dev_toast.start_time
  if elapsed > dev_toast.duration then
    dev_toast.message = nil
    return
  end

  -- Fade out in last 0.3 seconds
  local alpha = 1.0
  local fade_start = dev_toast.duration - 0.3
  if elapsed > fade_start then
    alpha = 1.0 - (elapsed - fade_start) / 0.3
  end

  -- Draw at top center of window
  local vp_w, vp_h = ImGui.GetWindowSize(ctx)
  local text_w = ImGui.CalcTextSize(ctx, dev_toast.message)
  local x = (vp_w - text_w) / 2
  local y = 40

  local dl = ImGui.GetForegroundDrawList(ctx)
  local bg_color = 0x000000B0  -- Semi-transparent black
  local text_color = (0xFFFFFF00 | math.floor(alpha * 255))

  ImGui.DrawList_AddRectFilled(dl, x - 8, y - 4, x + text_w + 8, y + 20, bg_color, 4)
  ImGui.DrawList_AddText(dl, x, y, text_color, dev_toast.message)
end
```

## State Preservation Strategy

For full state preservation across reloads:

```lua
-- App entry point pattern
local function create_app()
  -- State survives in closure or external table
  local state = _G._APP_STATE or require('MyApp.app.state').create()
  _G._APP_STATE = state

  -- UI is recreated on reload
  local ui = require('MyApp.ui').create(state)

  return {
    state = state,
    ui = ui,
    draw = function(ctx) ui.draw(ctx) end,
  }
end
```

## What Gets Reloaded vs Preserved

| Layer | Reloaded | Preserved |
|-------|----------|-----------|
| UI views | Yes | - |
| UI components | Yes | - |
| App state | No | Yes |
| Domain logic | No | Yes |
| Config | No | Yes |
| Theme | Depends | - |

## Edge Cases

### Circular Dependencies
If A requires B and B requires A, clearing A but not B leaves B with stale reference.

**Solution:** Clear entire UI layer together, not individual files.

### Event Listeners
Old callbacks stay registered with event bus.

**Solution:** UI should re-register on reload, or use weak references.

### ImGui State
Widget state (scroll position, selection) lives in ImGui, survives Lua reload.

**Benefit:** This is actually good - UI rebuilds but feels continuous.
