# ARKITEKT Architecture Guide

> Framework vs script organization, Clean Architecture layers, and pragmatic patterns.

---

## Framework vs Scripts

ARKITEKT code runs **exclusively inside REAPER**. This shapes our architecture philosophy.

| Level | Purity Rules | Why |
|-------|--------------|-----|
| **Framework** (`arkitekt/`) | Strict in `core/` | Utilities must be stable and reusable |
| **Scripts** (`scripts/X/`) | Pragmatic | App-specific, always in REAPER anyway |

**Key insight:** Scripts can use `reaper.*` directly in `domain/` - we don't enforce strict purity since all code (including tests) runs inside REAPER anyway.

---

## Framework Structure: `arkitekt/`

```
arkitekt/
├── core/           # General utilities (fs, json, settings, colors, etc.)
│   ├── context.lua   # ArkContext - frame-scoped state & caching
│   ├── id_stack.lua  # ID stack for widget scoping
│   ├── json.lua
│   ├── uuid.lua
│   ├── settings.lua
│   ├── colors.lua
│   ├── images.lua
│   └── imgui.lua
│
├── config/         # Constants and configuration
│   ├── animation.lua
│   ├── colors/
│   └── typography.lua
│
├── theme/          # Theming system
│   ├── init.lua
│   └── manager/
│
├── gui/            # Widgets and rendering
│   ├── widgets/
│   ├── animation/
│   └── interaction/
│
├── runtime/        # Bootstrap and runtime
│   ├── shell.lua
│   └── chrome/
│
├── assets/         # Fonts and icons
│
├── vendor/         # External dependencies
│
└── debug/          # Logger, test runner
```

**Note:** Since ARKITEKT runs exclusively in REAPER, strict "purity" in `core/` isn't enforced. All modules may use `reaper.*` and `ImGui.*` as needed.

---

## Script Structure: `scripts/X/`

Scripts organize by **responsibility**, not strict purity.

### Typical Structure

```
scripts/MyApp/
├── ARK_MyApp.lua         # Entry point (bootstrap)
│
├── app/                  # Orchestration
│   ├── init.lua          # Dependency injection, wiring
│   └── state.lua         # State container (thin)
│
├── domain/               # Business logic
│   ├── playlist/         # Grouped by concept
│   │   ├── model.lua
│   │   ├── service.lua
│   │   └── repository.lua
│   ├── region/
│   └── playback/
│
├── ui/                   # Presentation
│   ├── init.lua          # Main UI orchestrator
│   ├── views/
│   └── state/            # UI-only state (preferences, animation)
│
├── data/                 # Persistence
│   └── persistence.lua   # JSON/ExtState
│
├── config/               # Constants
│   └── constants.lua
│
└── tests/                # Integration tests (run in REAPER)
```

### Multiple Domains

Scripts can have multiple `domain/` subfolders for different concerns:

| Script | Domains | Purpose |
|--------|---------|---------|
| RegionPlaylist | `playlist/`, `region/`, `playback/` | Data + playback logic |
| ThemeAdjuster | `theme/`, `packages/` | Theme + package management |

---

## Layer Definitions

### `app/` - Application Layer

**Purpose:** Bootstrap, dependency injection, state container.

**Files:**
- `init.lua` - Wire dependencies, return configured app
- `state.lua` - Hold service references (container only, no logic)
- `config.lua` - Pure re-exports of constants from `config/`
- `config_factory.lua` - Factory functions for dynamic configs (optional)

**Example `app/state.lua`:**
```lua
local M = {
  services = {
    playlist = nil,
    region = nil,
  },
  data = {
    persistence = nil,
  },
  ui = nil,
}

function M.initialize(deps)
  M.services = deps.services
  M.data = deps.data
end

return M
```

**Config Organization:**

Split static constants from dynamic factories for clarity:

```lua
-- app/config.lua (pure re-exports)
local Constants = require('MyApp.config.constants')
local Defaults = require('MyApp.config.defaults')

local M = {}
M.ANIMATION = Constants.ANIMATION
M.TRANSPORT = Defaults.TRANSPORT
return M

-- app/config_factory.lua (dynamic configs)
local M = {}

function M.get_transport_config(state_module)
  return {
    height = Defaults.TRANSPORT.height,
    corner_buttons = {
      bottom_left = create_viewmode_button(state_module), -- Needs state!
    },
  }
end

function M.get_container_config(callbacks)
  return {
    header = { ... },
    on_tab_create = callbacks.on_create, -- Needs callbacks!
  }
end

return M
```

**Why split?**
- Clarity: Static vs dynamic at a glance
- Dependency tracking: Factories show runtime deps explicitly
- Cleaner imports: `config` for constants, `config_factory` for builders

---

### `domain/` - Business Logic

**Purpose:** Business rules, validation, operations. Group by concept.

**Can use `reaper.*` in scripts** (pragmatic approach).

**Example `domain/playlist/service.lua`:**
```lua
local M = {}

function M.new(repository, undo_manager)
  local service = {}

  function service:create(name)
    return undo_manager:with_undo(function()
      local playlist = Playlist.new(uuid.generate(), name)
      repository:save(playlist)
      return playlist.id
    end)
  end

  function service:delete(id)
    return undo_manager:with_undo(function()
      repository:delete(id)
      return true
    end)
  end

  return service
end

return M
```

**Organization:**
```
domain/
├── [concept]/        # Group by business concept
│   ├── model.lua     # Data structures, validation
│   ├── service.lua   # Business operations
│   └── repository.lua
```

---

### `data/` - Persistence Layer

**Purpose:** Storage, caching, undo integration.

**See [STORAGE.md](./STORAGE.md) for details.**

**Example:**
```lua
local M = {}

function M.new(app_name)
  local storage = {}

  function storage:save(filename, data)
    local path = data_dir .. "/" .. filename .. ".json"
    fs.write_file(path, json.encode(data))
  end

  function storage:load(filename)
    local path = data_dir .. "/" .. filename .. ".json"
    if not fs.file_exists(path) then return nil end
    return json.decode(fs.read_file(path))
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
├── init.lua          # Main UI orchestrator
├── views/            # View components
│   └── layout.lua
└── state/            # UI-ONLY state
    ├── preferences.lua   # Layout mode, sort, filters
    └── animation.lua     # Spawn/destroy effects
```

**Critical Rule:** `ui/state/` is for **UI preferences only**, not business data.

| Belongs in `ui/state/` | Does NOT belong |
|------------------------|-----------------|
| Layout mode (horizontal/vertical) | Playlist data |
| Sort direction | Playback state |
| Search filter text | Business rules |
| Panel separator positions | Undo history |

**Example `ui/init.lua`:**
```lua
local M = {}

function M.create(state, config, settings)
  local self = {
    state = state,
    config = config,
  }
  return setmetatable(self, { __index = M })
end

function M:draw(ctx, window, shell_state)
  -- Use services from state
  local playlists = self.state.services.playlist:get_all()

  -- Render UI
  for _, pl in ipairs(playlists) do
    if Ark.Button(ctx, {label = pl.name}).clicked then
      self.state.services.playlist:activate(pl.id)
    end
  end
end

return M
```

---

### `config/` - Static Definitions

**Purpose:** Constants, defaults, UI strings. Never changes at runtime.

```lua
local M = {}

M.COLORS = {
  HIGHLIGHT = Ark.Colors.hex('#4A90D9'),
}

M.SIZES = {
  TILE_WIDTH = 120,
  PADDING = 8,
}

M.TIMING = {
  FADE_DURATION = 0.2,
}

return M
```

---

## Universal Rules

| Rule | Description |
|------|-------------|
| **`app/` always has 2 files** | `init.lua` (bootstrap), `state.lua` (container) |
| **`domain/` groups by concept** | Business logic; can use `reaper.*` in scripts |
| **`data/` handles persistence** | ExtState, JSON files |
| **`ui/init.lua`** | Always the UI orchestrator entry point |
| **`ui/state/`** | UI-only state (preferences, NOT business data) |
| **Keep `config/`** | Clear name, doesn't collide |

---

## Forbidden Folder Names

| Folder | Why | Use Instead |
|--------|-----|-------------|
| `core/` | Becomes dumping ground | Distribute to proper layers |
| `utils/` | Too vague | Use arkitekt utilities or specific layer |
| `services/` | Ambiguous | `domain/*/service.lua` |
| `helpers/` | Too vague | Put in specific layer |
| `lib/` | Unclear scope | `domain/` for logic, `data/` for persistence |
| `common/` | Everything is "common" | Be specific |

---

## Module Patterns

### Standard Module

```lua
-- @noindex
local M = {}

-- Dependencies
local Logger = require('arkitekt.debug.logger')

-- Constants
local DEFAULT_VALUE = 100

-- Private functions
local function _validate(input)
  -- implementation
end

-- Public API
function M.public_function(param1, opts)
  opts = opts or {}
  -- implementation
end

return M
```

### Factory Pattern

```lua
function M.new(dependencies)
  local instance = {}

  function instance:method()
    -- implementation
  end

  return instance
end
```

### Index Pattern (Clean Imports)

```lua
-- domain/playlist/init.lua
return {
  Model = require("domain.playlist.model"),
  Service = require("domain.playlist.service"),
}

-- Usage:
local Playlist = require("domain.playlist")
local service = Playlist.Service.new(repo)
```

---

## Anti-Patterns

### 1. God Objects

```lua
-- BAD: app/state.lua with 50+ functions
M.get_playlists()
M.set_active_playlist()
M.get_region_by_rid()
-- ... 40+ more

-- GOOD: Delegate to domain services
State.services.playlist:get_active()
State.services.region:find_by_rid(rid)
```

### 2. UI State in Domain

```lua
-- BAD: domain/ui_preferences.lua
-- This is UI state, not business domain!

-- GOOD: ui/state/preferences.lua
```

### 3. Deep Nesting

```lua
-- BAD: Redundant nesting
ui/views/transport/transport_view.lua

-- GOOD: Flat
ui/views/transport.lua
-- Or if complex:
ui/views/transport/init.lua
```

### 4. Callback Chains

```lua
-- BAD: 30 inline callbacks
self.tiles = Tiles.create({
  on_drop = function(rid) ... end,
  on_select = function(key) ... end,
  -- ... 28 more
})

-- GOOD: Extract to module
local callbacks = require("ui.tile_callbacks")
self.tiles = Tiles.create(callbacks.create(self, State))
```

---

## Dependency Flow

```
UI → app → domain ← data
```

**Never:**
- UI → storage directly
- domain → UI

**Inject dependencies through `app/init.lua`:**
```lua
-- app/init.lua
local persistence = Persistence.new("MyApp")
local playlist_service = PlaylistService.new(persistence)

State.initialize({
  services = { playlist = playlist_service },
  data = { persistence = persistence },
})
```

---

## File Organization Rules

### File Naming

| Rule | Good | Bad |
|------|------|-----|
| Lowercase with underscores | `playlist_service.lua` | `PlaylistService.lua` |
| No redundant prefixes | `ui/views/layout.lua` | `ui/views/layout_view.lua` |
| Entry points are `init.lua` | `ui/init.lua` | `ui/main.lua` |

### File Size

| Size | Status | Action |
|------|--------|--------|
| < 200 lines | Excellent | No action |
| 200-400 lines | Good | Monitor |
| 400-700 lines | Warning | Consider splitting |
| > 700 lines | **Consider splitting** | Break into modules if concerns are separable |

**Exceptions:** Cohesive modules can exceed 700 lines if splitting would harm clarity:
- Coordinators with rendering methods (1200+ lines acceptable)
- State machines with many transitions
- View modules with inline logic
- Converters/parsers with complex logic

**When to split:**
- Mixed concerns (e.g., `coordinator.lua` + `coordinator_render.lua` doing identical things)
- Multiple unrelated responsibilities
- Hard to navigate/understand

**When NOT to split:**
- Single cohesive responsibility
- Artificial separation just to meet line count
- Would require excessive delegation

---

## Testing

All ARKITEKT tests are **integration tests** - they run inside REAPER.

```lua
local TestRunner = require('arkitekt.debug.test_runner')
local assert = TestRunner.assert

local tests = {}

function tests.test_playlist_creation()
  local pl = Playlist.new("id", "name")
  assert.not_nil(pl)
  assert.equals("name", pl.name)
end

TestRunner.register("MyApp.domain.playlist", tests)
```

**See [TESTING.md](./TESTING.md) for full guide.**

---

## Organizing by Responsibility

Common script folders:

| Folder | Purpose | Uses `reaper.*`? |
|--------|---------|------------------|
| `app/` | Bootstrap, state, wiring | Yes (defer, init) |
| `ui/`, `views/` | Rendering, interaction | Yes (via ImGui) |
| `domain/` | Business logic | Yes (pragmatic) |
| `data/` | Persistence | Yes (ExtState, files) |
| `config/` | Constants | No |
| `tests/` | Integration tests | Yes (runs in REAPER) |

**The real rule:** Organize so it's **easy to find and understand**, not to satisfy abstract purity.

---

## Bootstrap Pattern

Entry points **MUST** use `dofile` bootstrap, **not** `require`.

```lua
-- @noindex
-- MyApp

-- Bootstrap framework
local Ark = dofile(debug.getinfo(1,"S").source:sub(2):match("(.-ARKITEKT[/\\])") .. "arkitekt" .. package.config:sub(1,1) .. "init.lua")

-- Imports
local Shell = require('arkitekt.app.shell')
local Settings = require('arkitekt.core.settings')
local State = require('MyApp.app.state')
local GUI = require('MyApp.ui.init')

-- Initialize
local data_dir = Ark._bootstrap.get_data_dir("MyApp")
local settings = Settings.new(data_dir, "settings.json")

State.initialize(settings)
local gui = GUI.create(State, settings)

-- Run
Shell.run({
  title = "My App",
  draw = function(ctx, shell_state)
    gui:draw(ctx, shell_state)
  end,
  on_close = function()
    State.save()
  end,
})
```

**Why `dofile`?** Bootstrap sets `package.path`. Using `require` before bootstrap is a chicken-and-egg failure.

**See [CONVENTIONS.md](./CONVENTIONS.md) for full pattern.**

---

## Quick Reference Card

### Layer Checklist

- [ ] `app/` has `init.lua` and `state.lua`
- [ ] `domain/` groups by business concept
- [ ] `data/` handles persistence (ExtState, JSON)
- [ ] `ui/state/` contains only UI preferences
- [ ] No `core/`, `utils/`, or `services/` folders
- [ ] Entry point uses `dofile` bootstrap

### Architecture Rules

- [ ] Framework `core/` is pure (no reaper.*, no ImGui.*)
- [ ] Scripts can use `reaper.*` in `domain/` (pragmatic)
- [ ] Dependency flow: UI → app → domain ← data
- [ ] No ImGui in `domain/` layer
- [ ] State container is thin (no logic)

---

## See Also

- [CONVENTIONS.md](./CONVENTIONS.md) - Naming and module patterns
- [QUICKSTART.md](./QUICKSTART.md) - Create app in 5 minutes
- [REFACTOR_PLAN.md](./REFACTOR_PLAN.md) - How to refactor safely
- [TESTING.md](./TESTING.md) - Test framework guide
- [STORAGE.md](./STORAGE.md) - Persistence patterns
