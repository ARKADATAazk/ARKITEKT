# Storage & Persistence Guide

> How to save and load data in ARKITEKT scripts.

---

## Storage Options

| Method | Use For | Scope | Format |
|--------|---------|-------|--------|
| **ExtState** | Simple key-value, per-project | Project-specific | String |
| **JSON Files** | Complex data structures | App-wide or project | Structured |
| **Settings Module** | App preferences, window state | App-wide | JSON |

---

## ExtState (REAPER Native)

### When to Use
- Project-specific data
- Simple values (strings, numbers)
- Data that should save with project

### API
```lua
-- Save
reaper.SetExtState("AppName", "key", "value", true)  -- true = persist

-- Load
local value = reaper.GetExtState("AppName", "key")

-- Delete
reaper.DeleteExtState("AppName", "key", true)

-- Check if exists
local exists = reaper.HasExtState("AppName", "key")
```

### Pattern
```lua
local M = {}

local SECTION = "MyApp"

function M.save_active_playlist(playlist_id, proj)
  proj = proj or 0
  reaper.SetExtState(SECTION, "active_playlist_" .. proj, playlist_id, true)
end

function M.load_active_playlist(proj)
  proj = proj or 0
  return reaper.GetExtState(SECTION, "active_playlist_" .. proj)
end

return M
```

### Limitations
- Strings only (must serialize numbers, booleans)
- No nested structures
- Cleanup required on uninstall

---

## JSON Files

### When to Use
- Complex data (tables, arrays, nested objects)
- App-wide state (not project-specific)
- Data portability needed

### Location
```lua
local Ark = require('arkitekt')
local data_dir = Ark._bootstrap.get_data_dir("MyApp")
-- Returns: [REAPER]/Scripts/ARKITEKT/data/MyApp/
```

### Pattern
```lua
local json = require('arkitekt.core.json')
local fs = require('arkitekt.core.fs')

local M = {}

function M.save_playlists(playlists, proj)
  local path = data_dir .. "/playlists_" .. proj .. ".json"
  local content = json.encode(playlists)
  fs.write_file(path, content)
end

function M.load_playlists(proj)
  local path = data_dir .. "/playlists_" .. proj .. ".json"
  if not fs.file_exists(path) then return nil end

  local content = fs.read_file(path)
  return json.decode(content)
end

return M
```

### Atomic Writes
```lua
function M.save_safe(filename, data)
  local path = data_dir .. "/" .. filename .. ".json"
  local tmp = path .. ".tmp"

  -- Write to temp
  fs.write_file(tmp, json.encode(data))

  -- Atomic rename
  os.rename(tmp, path)
end
```

---

## Settings Module (ARKITEKT)

### When to Use
- App preferences (theme, layout mode)
- Window position/size
- UI state that persists across sessions

### API
```lua
local Settings = require('arkitekt.core.settings')

-- Create (auto-saves to JSON)
local settings = Settings.new(data_dir, "settings.json")

-- Get/set
local value = settings:get("key", default_value)
settings:set("key", new_value)

-- Save (usually on app close)
settings:save()
```

### Pattern
```lua
-- In app initialization
local Settings = require('arkitekt.core.settings')
local data_dir = Ark._bootstrap.get_data_dir("MyApp")
local settings = Settings.new(data_dir, "settings.json")

-- Load UI state
local layout = settings:get("layout_mode", "horizontal")
local theme = settings:get("theme", "adapt")

-- Save on close
Shell.run({
  -- ...
  on_close = function()
    settings:set("layout_mode", current_layout)
    settings:save()
  end,
})
```

---

## Choosing Storage

| Requirement | Use This |
|-------------|----------|
| Per-project data | ExtState |
| Complex structures | JSON |
| App preferences | Settings module |
| Window pos/size | Settings module (auto-handled by Shell) |
| Large binary data | Not supported (use file paths) |
| Cross-project data | JSON in app data dir |

---

## Data Directory Structure

```
[REAPER]/Scripts/ARKITEKT/data/
└── MyApp/
    ├── settings.json          # Settings module
    ├── playlists_0.json       # Project 0 playlists
    ├── playlists_1.json       # Project 1 playlists
    └── cache/                 # Optional cache dir
        └── thumbnails/
```

---

## Best Practices

### Versioning
```lua
local DATA_VERSION = 2

function M.save(data)
  data._version = DATA_VERSION
  -- save
end

function M.load()
  local data = -- load
  if not data._version or data._version < DATA_VERSION then
    data = M.migrate(data)
  end
  return data
end
```

### Error Handling
```lua
function M.load_safe(proj)
  local ok, result = pcall(function()
    return M.load_playlists(proj)
  end)

  if not ok then
    Logger.error("STORAGE", "Failed to load: %s", result)
    return nil
  end

  return result
end
```

### Cleanup
```lua
-- On uninstall or reset
function M.clear_all()
  -- ExtState
  reaper.DeleteExtState("MyApp", "", true)  -- All keys

  -- JSON files
  for file in fs.list_files(data_dir) do
    os.remove(data_dir .. "/" .. file)
  end
end
```

---

## Quick Reference

```lua
-- ExtState (project-specific, simple)
reaper.SetExtState("App", "key", value, true)
local val = reaper.GetExtState("App", "key")

-- JSON (complex data)
local json = require('arkitekt.core.json')
fs.write_file(path, json.encode(data))
local data = json.decode(fs.read_file(path))

-- Settings (app preferences)
local Settings = require('arkitekt.core.settings')
local s = Settings.new(dir, "settings.json")
s:set("key", value)
s:save()
```

---

## See Also

- `arkitekt/core/settings.lua` - Settings implementation
- `arkitekt/core/json.lua` - JSON encoder/decoder
- `arkitekt/core/fs.lua` - File system utilities
