# ARKITEKT Coding Conventions

> Naming conventions, file organization rules, and coding patterns for ARKITEKT scripts.

## Table of Contents

1. [Naming Conventions](#naming-conventions)
2. [File Organization Rules](#file-organization-rules)
3. [Module Patterns](#module-patterns)
4. [API Design Patterns](#api-design-patterns)
5. [Error Handling](#error-handling)
6. [Documentation Standards](#documentation-standards)

---

## Naming Conventions

### File Naming

| Rule | Good | Bad |
|------|------|-----|
| Use lowercase with underscores | `playlist_service.lua` | `PlaylistService.lua` |
| No redundant prefixes in folders | `ui/views/layout.lua` | `ui/views/layout_view.lua` |
| Entry points are `init.lua` | `ui/init.lua` | `ui/gui.lua`, `ui/main.lua` |
| Remove obvious suffixes | `domain/playlist/service.lua` | `domain/playlist/playlist_service.lua` |

### Folder Naming

| Rule | Good | Bad |
|------|------|-----|
| Plural for collections | `views/`, `renderers/` | `view/`, `renderer/` |
| Singular for aggregates | `domain/playlist/` | `domain/playlists/` |
| Lowercase, no spaces | `left_panel/` | `LeftPanel/`, `left-panel/` |

### Variable Naming

```lua
-- Local variables: snake_case
local playlist_count = 0
local is_playing = false
local current_region = nil

-- Module tables: PascalCase or single uppercase letter
local M = {}
local Playlist = {}
local PlaylistService = {}

-- Constants: SCREAMING_SNAKE_CASE
local MAX_PLAYLISTS = 100
local DEFAULT_COLOR = 0xFF0000FF

-- Private functions: prefix with underscore
local function _calculate_layout() end
local function _validate_input() end
```

### Function Naming

```lua
-- Public functions: snake_case (Lua convention)
function M.get_playlist_by_id(id) end
function M.create_new_playlist(name) end

-- Boolean getters: is_, has_, can_
function M.is_playing() end
function M.has_items() end
function M.can_delete() end

-- Actions: verb_noun
function M.add_item(item) end
function M.remove_region(rid) end
function M.save_settings() end

-- Factories: new or create
function M.new(opts) end
function M.create(config) end
```

---

## File Organization Rules

### Universal Rules

| Rule | Description |
|------|-------------|
| **app/ always has 2 files** | `init.lua` (bootstrap), `state.lua` (container) |
| **domain/ has no I/O** | Never `require` storage, never call REAPER API |
| **infra/ handles all I/O** | Persistence, caching, REAPER API wrappers |
| **ui/init.lua** | Always the UI orchestrator entry point |
| **ui/state/** | UI-only state (preferences, animation, NOT business data) |
| **Keep defs/** | This name is clear and doesn't collide |

### Forbidden Folder Names

| Folder | Why | Use Instead |
|--------|-----|-------------|
| `core/` | Becomes dumping ground | Distribute to proper layers |
| `utils/` | Too vague | Use arkitekt utilities or specific layer |
| `services/` | Ambiguous | `domain/*/service.lua` or `infra/` |
| `helpers/` | Too vague | Put in specific layer |
| `lib/` | Unclear scope | `domain/` for logic, `infra/` for I/O |
| `common/` | Everything is "common" | Be specific |

### File Size Guidelines

| Size | Status | Action |
|------|--------|--------|
| < 200 lines | Excellent | No action needed |
| 200-400 lines | Good | Monitor |
| 400-700 lines | Warning | Consider splitting |
| > 700 lines | **Must split** | Break into modules |

### Flattening Deep Nesting

```lua
-- BAD: Redundant nesting
ui/views/transport/transport_view.lua
ui/views/transport/transport_container.lua
ui/views/transport/transport_buttons.lua

-- GOOD: Flat within folder
ui/views/transport/init.lua      -- Main view (was transport_view.lua)
ui/views/transport/container.lua -- Was transport_container.lua
ui/views/transport/buttons.lua   -- Was transport_buttons.lua

-- BETTER: If small, just one file
ui/views/transport.lua           -- All transport UI in one file
```

---

## Module Patterns

### Standard Module Template

```lua
-- @noindex
-- [ScriptName]/[layer]/[module].lua
-- Brief description of what this module does

local M = {}

-- =============================================================================
-- DEPENDENCIES
-- =============================================================================

local Logger = require('arkitekt.debug.logger')
-- Group requires by layer: arkitekt first, then domain, then local

-- =============================================================================
-- CONSTANTS
-- =============================================================================

local DEFAULT_VALUE = 100
local MAX_ITEMS = 50

-- =============================================================================
-- PRIVATE FUNCTIONS
-- =============================================================================

local function _validate_input(input)
  -- Implementation
end

local function _calculate_result(data)
  -- Implementation
end

-- =============================================================================
-- PUBLIC API
-- =============================================================================

--- Brief description
--- @param param1 type Description
--- @param param2 type Description
--- @return type Description
function M.public_function(param1, param2)
  -- Implementation
end

--- Another public function
--- @param opts table Options table
--- @return table Result
function M.another_function(opts)
  opts = opts or {}
  -- Implementation
end

return M
```

### Factory Pattern (for stateful objects)

```lua
-- domain/playlist/service.lua

local M = {}

--- Create a new playlist service
--- @param repository table Playlist repository
--- @param undo_manager table Undo manager
--- @param events table Event bus
--- @return table service Playlist service instance
function M.new(repository, undo_manager, events)
  local service = {}

  --- Create a new playlist
  --- @param name string Playlist name
  --- @return string|nil id Created playlist ID or nil
  --- @return string|nil error Error message if failed
  function service:create(name)
    if not name or name == "" then
      return nil, "Name is required"
    end

    return undo_manager:with_undo(function()
      local playlist = Playlist.new(uuid.generate(), name)
      repository:save(playlist)
      events:emit("playlist.created", { id = playlist.id })
      return playlist.id
    end)
  end

  --- Delete a playlist
  --- @param id string Playlist ID
  --- @return boolean success
  function service:delete(id)
    return undo_manager:with_undo(function()
      repository:delete(id)
      events:emit("playlist.deleted", { id = id })
      return true
    end)
  end

  return service
end

return M
```

### State Container Pattern

```lua
-- app/state.lua
-- Pure state container - NO LOGIC HERE

local M = {
  -- Domain services (injected by init.lua)
  services = {
    playlist = nil,
    region = nil,
  },

  -- Infrastructure (injected)
  infra = {
    storage = nil,
    undo = nil,
  },

  -- Event bus
  events = nil,

  -- Reference to UI state
  ui = nil,
}

--- Initialize state with dependencies
--- @param deps table Dependencies to inject
function M.initialize(deps)
  M.services = deps.services or M.services
  M.infra = deps.infra or M.infra
  M.events = deps.events
  M.ui = deps.ui
end

--- Reset state (for testing)
function M.reset()
  M.services = { playlist = nil, region = nil }
  M.infra = { storage = nil, undo = nil }
  M.events = nil
  M.ui = nil
end

return M
```

### Index File Pattern (for clean imports)

```lua
-- domain/playlist/init.lua
-- Re-exports for clean imports

return {
  Model = require("domain.playlist.model"),
  Repository = require("domain.playlist.repository"),
  Service = require("domain.playlist.service"),
}

-- Usage:
local Playlist = require("domain.playlist")
local service = Playlist.Service.new(repo, undo, events)
local model = Playlist.Model.new(id, name)
```

---

## API Design Patterns

### Options Table Pattern

```lua
-- GOOD: Options table for multiple optional parameters
function M.create(opts)
  opts = opts or {}
  local name = opts.name or "Untitled"
  local color = opts.color or DEFAULT_COLOR
  local items = opts.items or {}
  -- ...
end

-- Usage:
M.create({ name = "My Playlist", color = 0xFF0000FF })
M.create({ name = "Another" })  -- Uses defaults for color, items
M.create()  -- Uses all defaults

-- BAD: Long parameter lists
function M.create(name, color, items, is_active, parent_id)
  -- Hard to remember order, hard to skip optional params
end
```

### Result Pattern (for operations that can fail)

```lua
-- Define a simple Result type
local Result = {}
function Result.ok(value) return { ok = true, value = value } end
function Result.err(message) return { ok = false, error = message } end

-- Use in service functions
function service:create(name)
  if not name or name == "" then
    return Result.err("Name is required")
  end

  if #name > 100 then
    return Result.err("Name too long (max 100 characters)")
  end

  local id = repository:save(Playlist.new(name))
  return Result.ok(id)
end

-- Caller handles uniformly
local result = service:create(name)
if result.ok then
  events:emit("playlist.created", { id = result.value })
else
  notification:show_error(result.error)
end
```

### Callback Extraction Pattern

```lua
-- BAD: 30 inline callbacks
self.tiles = Tiles.create({
  on_drop = function(rid, index)
    local success, key = self.controller:add_item(...)
    if success then
      State.add_pending_spawn(key)
    end
    return success and key or nil
  end,
  on_select = function(keys)
    -- ...
  end,
  -- ... 28 more callbacks
})

-- GOOD: Extract to separate module
-- ui/tile_callbacks.lua
local M = {}

function M.create(controller, state, events)
  return {
    on_drop = function(rid, index)
      local result = controller:add_item(rid, index)
      if result.ok then
        events:emit("tile.spawned", { key = result.value })
      end
      return result.ok and result.value or nil
    end,

    on_select = function(keys)
      state.ui.selection:set(keys)
    end,

    -- Group related callbacks together
  }
end

return M

-- Usage in main UI
local TileCallbacks = require("ui.tile_callbacks")
self.tiles = Tiles.create(TileCallbacks.create(controller, state, events))
```

---

## Error Handling

### Validation Pattern

```lua
--- Validate input at system boundaries
--- @param input table Input to validate
--- @return boolean valid
--- @return string|nil error Error message if invalid
local function validate_playlist_input(input)
  if not input then
    return false, "Input is required"
  end

  if not input.name or input.name == "" then
    return false, "Name is required"
  end

  if type(input.name) ~= "string" then
    return false, "Name must be a string"
  end

  if #input.name > 100 then
    return false, "Name too long (max 100 characters)"
  end

  return true
end

-- Usage
function service:create(input)
  local valid, err = validate_playlist_input(input)
  if not valid then
    return Result.err(err)
  end

  -- Proceed with validated input
end
```

### Logging Pattern

```lua
local Logger = require('arkitekt.debug.logger')

-- Log levels: debug, info, warn, error
Logger.debug("MODULE", "Processing %d items", count)
Logger.info("MODULE", "Playlist created: %s", playlist.name)
Logger.warn("MODULE", "Deprecated function called: %s", func_name)
Logger.error("MODULE", "Failed to save: %s", error_message)

-- Use consistent module tags
-- "PLAYLIST" for playlist operations
-- "STORAGE" for persistence
-- "UI" for UI-related logs
```

### Safe REAPER API Calls

```lua
-- Wrap REAPER API calls that might fail
local function safe_get_region(proj, rid)
  local ok, result = pcall(function()
    return reaper.EnumProjectMarkers3(proj, rid)
  end)

  if not ok then
    Logger.error("REAPER", "Failed to get region %d: %s", rid, result)
    return nil
  end

  return result
end
```

---

## Documentation Standards

### File Headers

```lua
-- @noindex
-- [ScriptName]/[layer]/[module].lua
-- Brief description of what this module does
--
-- This module handles [specific responsibility].
-- It is part of the [layer] layer and depends on [dependencies].
```

### Function Documentation

```lua
--- Brief description of the function
---
--- Longer description if needed. Explain what the function does,
--- any important behavior, and edge cases.
---
--- @param param1 type Description of param1
--- @param param2 type|nil Description of param2 (optional)
--- @param opts table Options table
--- @param opts.name string Name option
--- @param opts.color number|nil Color option (optional)
--- @return type Description of return value
--- @return nil, string Returns nil and error message on failure
---
--- @example
--- local result = M.my_function("value", nil, { name = "test" })
function M.my_function(param1, param2, opts)
  -- Implementation
end
```

### Section Comments

```lua
-- =============================================================================
-- SECTION NAME
-- =============================================================================

-- Use these to organize larger files into logical sections:
-- DEPENDENCIES
-- CONSTANTS
-- PRIVATE FUNCTIONS
-- PUBLIC API
-- INITIALIZATION
```

### Inline Comments

```lua
-- GOOD: Explain WHY, not WHAT
-- Clamp playpos within region bounds to handle transition jitter
-- When looping the same region, pointer updates before playpos resets
local clamped_pos = max(region.start, min(playpos, region["end"]))

-- BAD: Explains what the code does (obvious from reading it)
-- Set clamped_pos to the max of region.start and min of playpos and region.end
local clamped_pos = max(region.start, min(playpos, region["end"]))
```

---

## Quick Reference Card

### File Naming Checklist

- [ ] Lowercase with underscores
- [ ] No redundant prefixes/suffixes
- [ ] Entry points are `init.lua`
- [ ] Under 400 lines (warning) / 700 lines (must split)

### Module Checklist

- [ ] Has `-- @noindex` header
- [ ] Has file description comment
- [ ] Dependencies grouped at top
- [ ] Constants defined before functions
- [ ] Private functions prefixed with `_`
- [ ] Public API documented with `@param` and `@return`
- [ ] Returns module table at end

### Layer Checklist

- [ ] `app/` has only `init.lua` and `state.lua`
- [ ] `domain/` has no `require` for storage or REAPER API
- [ ] `infra/` handles all I/O operations
- [ ] `ui/state/` contains only UI preferences, not business data
- [ ] No `core/`, `utils/`, or `services/` folders

---

## Appendix: Lua Style Guide Summary

Based on the [Lua Style Guide](http://lua-users.org/wiki/LuaStyleGuide):

1. **Indentation**: 2 spaces (no tabs)
2. **Line length**: Max 100 characters
3. **Strings**: Double quotes for display strings, single quotes for identifiers
4. **Tables**: Trailing comma on multi-line tables
5. **Operators**: Spaces around binary operators
6. **Comments**: Space after `--`

```lua
-- Example following all conventions
local M = {}

local DEFAULT_NAME = "Untitled"
local MAX_ITEMS = 100

local function _validate(input)
  return input ~= nil and input ~= ""
end

--- Create a new item
--- @param name string Item name
--- @param opts table|nil Options
--- @return table item
function M.create(name, opts)
  opts = opts or {}

  if not _validate(name) then
    name = DEFAULT_NAME
  end

  return {
    name = name,
    color = opts.color or 0xFFFFFFFF,
    items = {},
  }
end

return M
```
