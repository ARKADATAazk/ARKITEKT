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

### Constructor Patterns

**Standard: Use `M.new(opts)` for most cases**

```lua
-- ✅ RECOMMENDED: opts-based (extensible, clear)
function M.new(opts)
  opts = opts or {}
  return setmetatable({
    config = opts.config,
    state = opts.state,
    id = opts.id,
  }, { __index = M })
end

-- Usage: Widget.new({ config = cfg, state = state, id = "widget1" })
```

**Valid alternatives based on context:**

```lua
-- ✅ VALID: No dependencies (domain objects)
function M.new()
  return setmetatable({ items = {} }, { __index = M })
end

-- ✅ VALID: Single config dependency only
function M.new(config)
  return setmetatable({ config = config }, { __index = M })
end

-- ❌ AVOID: Multiple direct params (hard to extend)
function M.new(config, state, controller, animator)
  -- Hard to add dependencies, unclear parameter order
end
```

**When to use each:**
- `M.new(opts)` → Framework widgets, 3+ dependencies, extensible modules
- `M.new()` → Domain objects, self-contained modules
- `M.new(config)` → Simple renderers, single dependency only

### M.new() vs M.create() - Critical Distinction

**ALWAYS use `M.new()` for constructors (returns object with methods):**

```lua
-- ✅ CORRECT: Constructor pattern
function M.new(opts)
  local self = setmetatable({}, { __index = M })
  -- ... initialization ...
  return self
end

-- Usage:
local coordinator = Coordinator.new({ config = cfg })
coordinator:draw(ctx)        -- Has methods
coordinator:update(dt)       -- Has lifetime & state
```

**ONLY use `M.create_*()` for factory/builder functions (returns data):**

```lua
-- ✅ CORRECT: Factory pattern (returns data/config)
function M.create_opts(rt, config)
  return {
    items = rt._items,
    tile_height = rt._tile_height,
    -- ... configuration data ...
  }
end

-- Usage:
local opts = Factory.create_opts(rt, config)
Ark.Grid(ctx, opts)  -- Data passed to another function
```

**Why this matters:**

| Pattern | Returns | Has Methods | Use Case |
|---------|---------|-------------|----------|
| `M.new()` | Instance | ✅ Yes | Stateful objects (coordinators, managers, services) |
| `M.create_*()` | Data/Config | ❌ No | Configuration tables, options, builders |

**Common mistakes:**

```lua
-- ❌ WRONG: Using create() for constructor
function M.create(opts)
  return setmetatable({}, M)  -- Returns instance → should be M.new()
end

-- ❌ WRONG: Using new() for factory
function M.new_options(config)
  return { items = {}, height = 150 }  -- Returns data → should be M.create_options()
end
```

**ARKITEKT framework evidence:** 42+ core modules use `M.new()` for constructors (TileAnim, HeightStabilizer, GridBridge, Selection, etc.). Only 1 uses `M.create()` and it's for a factory pattern.

### Local Variable Standards

**Authoritative abbreviations** (based on framework analysis):

| Full Name | Local Variable | Usage | Never Use |
|-----------|---------------|-------|-----------|
| `config` | `cfg` | `local cfg = self.config` | `configuration` |
| `context` (ImGui) | `ctx` | `function M.draw(ctx)` | `context` |
| `options` | `opts` | `function M.new(opts)` | `options` |
| `state` | `state` | `local state = self.state` | `st` ❌ |

```lua
-- ✅ CORRECT - Framework standard
function M:draw(ctx)
  local cfg = self.config  -- Use 'cfg' for locals
  local state = self.state -- NEVER abbreviate 'state'

  ImGui.Button(ctx, cfg.labels.save)
end

-- ❌ WRONG - Verbose or wrong abbreviations
function M:draw(context)
  local config = self.config  -- Use 'cfg'
  local st = self.state       -- NEVER 'st'
end
```

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
| **domain/ organization** | Group by business concept (see note below) |
| **data/ handles persistence** | ExtState, JSON files |
| **ui/init.lua** | Always the UI orchestrator entry point |
| **ui/state/** | UI-only state (preferences, animation, NOT business data) |
| **Keep defs/** | This name is clear and doesn't collide |

> **Note:** Scripts take a pragmatic approach - `domain/` can use `reaper.*` directly since all code runs in REAPER anyway. See [ARCHITECTURE.md](./ARCHITECTURE.md) for the framework vs scripts distinction.

### Forbidden Folder Names

| Folder | Why | Use Instead |
|--------|-----|-------------|
| `core/` | Becomes dumping ground | Distribute to proper layers |
| `utils/` | Too vague | Use arkitekt utilities or specific layer |
| `services/` | Ambiguous | `domain/*/service.lua` or `data/` |
| `helpers/` | Too vague | Put in specific layer |
| `lib/` | Unclear scope | `domain/` for logic, `data/` for persistence |
| `common/` | Everything is "common" | Be specific |

### File Size Guidelines

| Size | Status | Action |
|------|--------|--------|
| < 200 lines | Excellent | No action needed |
| 200-400 lines | Good | Monitor |
| 400-700 lines | Warning | Consider splitting |
| 700-1000 lines | **Avoid** | Split if logical boundaries exist |
| > 1000 lines | **God file** | Must refactor (exceptions rare) |

**Avoid god files (800-1000+ lines).** Split when it makes logical sense (extract menus, helpers, initialization). If splitting creates artificial complexity, exceptions can be made - but 1000+ lines is almost always a code smell.

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

  -- Data layer (injected)
  data = {
    persistence = nil,
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
  M.data = deps.data or M.data
  M.events = deps.events
  M.ui = deps.ui
end

--- Reset state (for testing)
function M.reset()
  M.services = { playlist = nil, region = nil }
  M.data = { persistence = nil, undo = nil }
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

### Naming Standards Checklist

- [ ] Constructor: `M.new(opts)` for 3+ deps, `M.new(config)` for 1 dep, `M.new()` for 0 deps
- [ ] Local variables: `cfg` (not `config`), `state` (never `st`), `ctx`, `opts`
- [ ] Parameters: `ctx` for ImGui, `opts` for options tables
- [ ] Avoid multi-param constructors (use `opts` instead)

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

- [ ] `app/` has `init.lua` and `state.lua`
- [ ] `domain/` groups by business concept
- [ ] `data/` handles persistence (ExtState, JSON)
- [ ] `ui/state/` contains only UI preferences, not business data
- [ ] No `core/`, `utils/`, or `services/` folders

> See [ARCHITECTURE.md](./ARCHITECTURE.md) for pragmatic vs strict purity guidance.

---

## Lua Idioms & Gotchas

### Falsy Values in Lua

**Critical for LLMs:** Only `false` and `nil` are falsy in Lua. Zero and empty strings are truthy!

```lua
-- ⚠️ GOTCHA: These are ALL truthy in Lua
if 0 then        -- TRUE (unlike C, JavaScript, Python)
if "" then       -- TRUE (unlike Python, JavaScript)
if {} then       -- TRUE (always)

-- ✅ CORRECT: Only false and nil are falsy
if false then    -- FALSE
if nil then      -- FALSE

-- Use explicit checks when needed
if value ~= nil then      -- Distinguishes false from nil
if value ~= "" then       -- Check for empty string
if value ~= 0 then        -- Check for zero
if #items > 0 then        -- Check for non-empty table
```

### Ternary Pattern (Use with Caution)

```lua
-- ✅ SAFE: When truthy value can't be false/nil
local label = is_active and "Active" or "Inactive"
local count = items and #items or 0

-- ⚠️ UNSAFE: Fails if truthy value can be false
local value = condition and false or "default"  -- Always returns "default"!

-- ✅ SAFE: Use explicit if/else for complex cases
local value
if condition then
  value = get_value()  -- Might return false
else
  value = "default"
end
```

### Tables with Holes (Sparse Arrays)

```lua
-- ⚠️ GOTCHA: # operator undefined for tables with nils
local items = { "a", "b", nil, "d" }
local count = #items  -- Might be 2, 3, or 4 (undefined!)

-- ✅ SOLUTION 1: Store explicit count
local items = { "a", "b", nil, "d" }
items.n = 4  -- Explicit count

-- ✅ SOLUTION 2: Use table.maxn (Lua 5.1/5.2)
local count = table.maxn(items)

-- ✅ SOLUTION 3: Avoid holes - use index tables
local items = {
  [1] = "a",
  [2] = "b",
  [4] = "d",  -- Gap at 3
}
-- Track valid indices separately
local valid_indices = {1, 2, 4}
```

---

## Appendix: Lua Style Guide Summary

Based on the [Lua Style Guide](http://lua-users.org/wiki/LuaStyleGuide):

1. **Indentation**: 2 spaces (no tabs)
2. **Line length**: Max 100 characters (flexible, break at 120 for readability)
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
