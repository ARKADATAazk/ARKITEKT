# ARKITEKT Script Project Structure

> A comprehensive guide to organizing ARKITEKT scripts using Clean Architecture principles adapted for REAPER/Lua.

## Table of Contents

1. [Design Philosophy](#design-philosophy)
2. [Layer Overview](#layer-overview)
3. [Canonical Structure](#canonical-structure)
4. [Layer Definitions](#layer-definitions)
5. [Domain vs Features](#domain-vs-features)
6. [Universal Rules](#universal-rules)
7. [Anti-Patterns to Avoid](#anti-patterns-to-avoid)

---

## Design Philosophy

### Why This Structure?

The previous organization used vague folders like `core/`, `utils/`, and `services/` which became dumping grounds for unrelated code. This new structure follows **Clean Architecture** principles:

```
┌─────────────────────────────────────────────────────────┐
│                         UI                               │
│   (views, tiles, shortcuts - knows about everything)    │
└─────────────────────────┬───────────────────────────────┘
                          │ depends on
┌─────────────────────────▼───────────────────────────────┐
│                        APP                               │
│   (state container, config - orchestrates domains)      │
└─────────────────────────┬───────────────────────────────┘
                          │ depends on
┌─────────────────────────▼───────────────────────────────┐
│                      DOMAIN                              │
│   (business logic - NO UI/storage dependencies)         │
└─────────────────────────┬───────────────────────────────┘
                          │ depends on
┌─────────────────────────▼───────────────────────────────┐
│                       INFRA                              │
│   (persistence, REAPER API - implementation details)    │
└─────────────────────────────────────────────────────────┘
```

### Key Benefits

| Benefit | Description |
|---------|-------------|
| **Testability** | Domain layer has no UI/storage deps → easy to unit test |
| **Clarity** | Clear where every file belongs |
| **Reusability** | Domain logic could be used by different UIs |
| **Maintainability** | Changes in one layer don't ripple to others |
| **Onboarding** | New developers understand structure faster |

---

## Layer Overview

| Layer | Purpose | Dependencies | Example Files |
|-------|---------|--------------|---------------|
| `app/` | Bootstrap, wire dependencies, hold state | domain, infra | `init.lua`, `state.lua` |
| `domain/` | Business logic, rules, validation | None (pure) | `playlist/service.lua` |
| `infra/` | External I/O, REAPER API, caching | domain (interfaces) | `storage.lua`, `cache.lua` |
| `ui/` | Presentation, user interaction | app, domain | `init.lua`, `views/` |
| `defs/` | Static constants, defaults, strings | None | `constants.lua` |
| `tests/` | Test files | Mirrors source | `domain/playlist_test.lua` |

---

## Canonical Structure

```
[ScriptName]/
│
├── app/                      # APPLICATION LAYER
│   ├── init.lua              # Bootstrap: dependency injection, wiring
│   └── state.lua             # Global state container (thin, no logic)
│
├── domain/                   # DOMAIN LAYER (business logic)
│   ├── [aggregate]/          # Group by business concept
│   │   ├── model.lua         # Data structures, validation
│   │   ├── repository.lua    # Data access abstraction
│   │   └── service.lua       # Business operations (use cases)
│   └── [shared]/             # Cross-cutting domain concerns
│       └── *.lua
│
├── infra/                    # INFRASTRUCTURE LAYER
│   ├── storage.lua           # JSON/ExtState persistence
│   ├── undo.lua              # Undo system integration
│   ├── cache.lua             # Disk/memory caching (optional)
│   └── [adapters]/           # External service adapters
│       └── *.lua
│
├── ui/                       # PRESENTATION LAYER
│   ├── init.lua              # UI orchestrator (main entry point)
│   ├── shortcuts.lua         # Keyboard handling
│   │
│   ├── state/                # UI-specific state (NOT business state)
│   │   ├── preferences.lua   # Layout, sort, filter preferences
│   │   ├── animation.lua     # Spawn/destroy animations
│   │   └── notification.lua  # Status messages, toasts
│   │
│   ├── views/                # View components
│   │   ├── layout.lua        # Main layout structure
│   │   ├── [feature].lua     # Feature-specific views
│   │   └── modals/           # Modal dialogs
│   │       └── *.lua
│   │
│   └── tiles/                # Tile/grid components (or grids/)
│       ├── coordinator.lua   # Grid orchestration
│       ├── factories/        # Grid factory functions
│       └── renderers/        # Tile rendering
│
├── defs/                     # STATIC DEFINITIONS
│   ├── constants.lua         # Enums, magic numbers, limits
│   ├── defaults.lua          # Default configuration values
│   └── strings.lua           # UI text, labels, messages
│
└── tests/                    # TEST FILES
    ├── domain/               # Domain unit tests
    │   └── [aggregate]_test.lua
    ├── infra/                # Infrastructure tests
    │   └── storage_test.lua
    └── integration/          # End-to-end tests
        └── workflow_test.lua
```

---

## Layer Definitions

### `app/` - Application Layer

**Purpose:** Bootstrap the application, wire dependencies, provide state container.

**Files:**

| File | Responsibility |
|------|----------------|
| `init.lua` | Create instances, inject dependencies, return configured app |
| `state.lua` | Hold references to domain services, infra, UI state (container only) |

**Example `app/init.lua`:**

```lua
-- app/init.lua
local Storage = require("infra.storage")
local PlaylistService = require("domain.playlist.service")
local PlaylistRepository = require("domain.playlist.repository")
local State = require("app.state")
local EventBus = require("arkitekt.core.events")

local function bootstrap(settings)
  -- Create infrastructure
  local storage = Storage.new("RegionPlaylist")
  local undo = UndoManager.new()
  local events = EventBus.new()

  -- Create repositories (data access)
  local playlist_repo = PlaylistRepository.new(storage)

  -- Create services (business logic)
  local playlist_service = PlaylistService.new(playlist_repo, undo, events)

  -- Wire up state container
  State.initialize({
    services = { playlist = playlist_service },
    infra = { storage = storage, undo = undo },
    events = events,
  })

  return State
end

return { bootstrap = bootstrap }
```

**Example `app/state.lua`:**

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

  -- Reference to UI state (set by UI layer)
  ui = nil,
}

function M.initialize(deps)
  M.services = deps.services
  M.infra = deps.infra
  M.events = deps.events
end

return M
```

---

### `domain/` - Domain Layer

**Purpose:** Pure business logic. No I/O, no UI dependencies.

**Organization:** Group by **aggregate root** (main business concept).

```
domain/
├── playlist/           # Playlist aggregate
│   ├── model.lua       # Playlist data structure
│   ├── repository.lua  # Playlist data access interface
│   └── service.lua     # Playlist business operations
│
├── region/             # Region aggregate
│   └── repository.lua  # Region data access
│
├── playback/           # Playback aggregate
│   ├── engine.lua      # Playback state machine
│   ├── sequence.lua    # Sequence expansion
│   └── transport.lua   # Transport control
│
└── dependency.lua      # Shared: circular reference detection
```

**Example `domain/playlist/model.lua`:**

```lua
-- domain/playlist/model.lua
-- Pure data structure with validation

local Playlist = {}

function Playlist.new(id, name)
  assert(id, "Playlist requires id")
  assert(name and name ~= "", "Playlist requires name")

  return {
    id = id,
    name = name,
    items = {},
    chip_color = nil,
    created_at = os.time(),
  }
end

function Playlist.add_item(playlist, item, index)
  index = index or (#playlist.items + 1)
  table.insert(playlist.items, index, item)
end

function Playlist.remove_item(playlist, key)
  for i, item in ipairs(playlist.items) do
    if item.key == key then
      table.remove(playlist.items, i)
      return true
    end
  end
  return false
end

function Playlist.validate(playlist)
  if not playlist.id then return false, "Missing id" end
  if not playlist.name then return false, "Missing name" end
  return true
end

return Playlist
```

**Example `domain/playlist/service.lua`:**

```lua
-- domain/playlist/service.lua
-- Business operations (use cases)

local Playlist = require("domain.playlist.model")
local uuid = require("arkitekt.core.uuid")

local M = {}

function M.new(repository, undo_manager, events)
  local service = {}

  function service:create(name)
    return undo_manager:with_undo(function()
      local playlist = Playlist.new(uuid.generate(), name)
      repository:save(playlist)
      events:emit("playlist.created", { id = playlist.id })
      return playlist.id
    end)
  end

  function service:duplicate(id)
    return undo_manager:with_undo(function()
      local source = repository:find_by_id(id)
      if not source then return nil, "Playlist not found" end

      local copy = deep_copy(source)
      copy.id = uuid.generate()
      copy.name = source.name .. " (Copy)"
      repository:save(copy)
      events:emit("playlist.created", { id = copy.id })
      return copy.id
    end)
  end

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

---

### `infra/` - Infrastructure Layer

**Purpose:** External I/O, REAPER API wrappers, caching, file operations.

**Files:**

| File | Responsibility |
|------|----------------|
| `storage.lua` | JSON file and ExtState persistence |
| `undo.lua` | REAPER undo system bridge |
| `cache.lua` | Disk/memory caching |
| `bridge.lua` | Cross-component coordination (e.g., engine-UI sync) |
| `[adapters]/` | External service adapters |

**Example `infra/storage.lua`:**

```lua
-- infra/storage.lua
local json = require("arkitekt.core.json")
local Logger = require("arkitekt.debug.logger")

local M = {}

function M.new(app_name)
  local data_dir = reaper.GetResourcePath() .. "/Scripts/ARKITEKT/data/" .. app_name

  local storage = {}

  function storage:load(filename)
    local path = data_dir .. "/" .. filename .. ".json"
    local file = io.open(path, "r")
    if not file then return nil end

    local content = file:read("*a")
    file:close()

    local ok, data = pcall(json.decode, content)
    if not ok then
      Logger.error("STORAGE", "Failed to parse %s: %s", filename, data)
      return nil
    end
    return data
  end

  function storage:save(filename, data)
    local path = data_dir .. "/" .. filename .. ".json"
    local content = json.encode(data)

    -- Atomic write
    local tmp_path = path .. ".tmp"
    local file = io.open(tmp_path, "w")
    if not file then return false, "Cannot open file" end

    file:write(content)
    file:close()
    os.rename(tmp_path, path)
    return true
  end

  return storage
end

return M
```

---

### `ui/` - Presentation Layer

**Purpose:** All user interaction, rendering, event handling.

**Structure:**

```
ui/
├── init.lua              # Main orchestrator (entry point)
├── shortcuts.lua         # Keyboard handling
│
├── state/                # UI-SPECIFIC state only
│   ├── preferences.lua   # Layout mode, sort, filters
│   ├── animation.lua     # Spawn/destroy effects
│   └── notification.lua  # Status messages
│
├── views/                # View components
│   ├── layout.lua        # Main layout
│   └── modals/           # Modal dialogs
│
└── tiles/                # Grid/tile system
    ├── coordinator.lua
    └── renderers/
```

**Critical Rule:** `ui/state/` contains UI-only state, NOT business data.

| Belongs in `ui/state/` | Does NOT belong |
|------------------------|-----------------|
| Layout mode (horizontal/vertical) | Playlist data |
| Sort direction | Region data |
| Search filter text | Playback state |
| Animation timers | Business rules |
| Panel separator positions | Undo history |

**Example `ui/state/preferences.lua`:**

```lua
-- ui/state/preferences.lua
-- UI preferences only - NOT business data

local Constants = require("defs.constants")

local M = {}

function M.new(settings)
  local prefs = {
    layout_mode = "horizontal",
    pool_mode = "regions",
    sort_mode = nil,
    sort_direction = "asc",
    search_filter = "",
    separator_positions = {
      horizontal = nil,
      vertical = nil,
    },
  }

  function prefs:load_from_settings()
    if settings then
      self.layout_mode = settings:get("layout_mode", self.layout_mode)
      self.pool_mode = settings:get("pool_mode", self.pool_mode)
      -- ...
    end
  end

  function prefs:save_to_settings()
    if settings then
      settings:set("layout_mode", self.layout_mode)
      settings:set("pool_mode", self.pool_mode)
      -- ...
    end
  end

  return prefs
end

return M
```

---

### `defs/` - Static Definitions

**Purpose:** Constants, default values, UI strings. Never changes at runtime.

**Files:**

| File | Contents |
|------|----------|
| `constants.lua` | Enums, limits, magic numbers |
| `defaults.lua` | Default configuration values |
| `strings.lua` | UI text, labels, error messages |

**Keep this folder name:** It's clear, consistent, and doesn't collide with anything.

---

## Domain vs Features

### When to Use `domain/` (Recommended for ARKITEKT)

Group by **business concept** when:
- Concepts are shared across UI features
- There's significant cross-cutting logic
- You want to test business logic in isolation

```
domain/
├── playlist/     # Used by active-grid, pool-grid, transport
├── region/       # Used everywhere
└── playback/     # Used by transport, tiles
```

### When to Use `features/`

Group by **user-facing feature** when:
- Features are truly independent
- Little shared logic between features
- Each feature could be removed without affecting others

```
features/
├── transport/
│   ├── ui/
│   ├── logic/
│   └── index.lua
├── active-grid/
└── pool-grid/
```

### Recommendation for ARKITEKT Scripts

**Use `domain/`** because:
- Playlists/regions are shared across multiple UI features
- Playback engine needs access to both
- Features would lead to code duplication

**Consider `features/`** only for truly isolated additions (e.g., a standalone settings panel).

---

## Universal Rules

| Rule | Description |
|------|-------------|
| **app/ always has 2 files** | `init.lua` (bootstrap), `state.lua` (container) |
| **domain/ has no I/O** | Never `require` storage, never call REAPER API |
| **infra/ handles all I/O** | Persistence, caching, REAPER API wrappers |
| **ui/init.lua** | Always the UI orchestrator entry point |
| **ui/state/** | UI-only state (preferences, animation, NOT business data) |
| **Keep defs/** | This name is clear and doesn't collide |
| **No core/** | Eliminated - distribute to proper layers |
| **No utils/** | Use arkitekt utilities or put in appropriate layer |
| **No services/** | Too vague - use `domain/` for logic, `infra/` for I/O |

---

## Anti-Patterns to Avoid

### 1. The "Core" Dumping Ground

```lua
-- BAD: core/ becomes a catch-all
core/
├── app_state.lua      -- Should be: app/state.lua
├── config.lua         -- Should be: app/config.lua
├── controller.lua     -- Should be: domain/*/service.lua
├── utils.lua          -- Should be: arkitekt.core.* or domain/
└── helpers.lua        -- Should be: specific layer
```

### 2. UI State in Domain

```lua
-- BAD: domains/ui_preferences.lua
-- This is UI state, not business domain!

-- GOOD: ui/state/preferences.lua
```

### 3. God Objects

```lua
-- BAD: app_state.lua with 50+ functions
M.get_playlists()
M.get_active_playlist_id()
M.set_active_playlist()
M.get_region_by_rid()
-- ... 40+ more

-- GOOD: Delegate to domain services
State.services.playlist:get_active()
State.services.region:find_by_rid(rid)
```

### 4. Callback Chains

```lua
-- BAD: 30 inline callbacks
self.tiles = Tiles.create({
  on_drop = function(rid) ... end,
  on_select = function(key) ... end,
  -- ... 28 more
})

-- GOOD: Extract to separate module
local callbacks = require("ui.tile_callbacks")
self.tiles = Tiles.create(callbacks.create(self, State))
```

### 5. Deep Nesting

```lua
-- BAD: ui/views/transport/transport_view.lua
-- Redundant "transport" in path and filename

-- GOOD: ui/views/transport.lua
-- Or if complex: ui/views/transport/init.lua
```

---

## Next Steps

1. See [MIGRATION_PLANS.md](./MIGRATION_PLANS.md) for per-script migration details
2. See [CONVENTIONS.md](./CONVENTIONS.md) for naming and coding standards
