# Region Playlist

> Audio region sequencing and playback app for REAPER

Region Playlist lets you sequence REAPER regions and nested playlists into playback queues with looping, transitions, and quantization. Think of it as a flexible "set list" manager for audio regions.

---

## Quick Start

**Load in REAPER:**
```
Actions → Load ReaScript → ARKITEKT/scripts/RegionPlaylist/ARK_RegionPlaylist.lua
```

**Basic workflow:**
1. Create regions in your REAPER project
2. Drag regions from Pool Grid (bottom) to Active Grid (top)
3. Adjust loop counts with mouse wheel
4. Click Play in transport bar
5. Regions play in sequence with your settings

---

## Architecture Overview

```
ARK_RegionPlaylist.lua (entry point)
  ↓
app/
  init.lua           → Dependency injection (all layers wired)
  state.lua          → State container with domain composition
  controller.lua     → Playlist CRUD with undo integration
  config.lua         → Pure re-exports of constants from defs/
  config_factory.lua → Factory functions for dynamic configs
  pool_queries.lua   → Filtering and sorting logic for pool

domain/
  playlist.lua       → Playlist domain (CRUD operations)
  region.lua         → Region cache and pool ordering
  dependency.lua     → Circular reference detection
  playback/          → Transport engine subsystem
    controller.lua   → Main playback coordinator
    state.lua        → Engine state machine
    expander.lua     → Nested playlist expansion
    quantize.lua     → Beat quantization
    transitions.lua  → Cross-region transitions
    loop.lua         → Loop boundary detection
    transport.lua    → Play/stop/seek operations

data/
  bridge.lua         → App ↔ Engine coordination bridge
  storage.lua        → Project persistence (ExtState)
  sws_import.lua     → SWS Region Playlist importer
  undo.lua           → Undo manager

ui/
  gui.lua            → Main UI orchestrator
  components/
    batch_operations.lua → Batch rename/recolor utilities
  views/
    layout_view.lua  → Horizontal/vertical split layouts
    transport/       → Transport bar components
  tiles/
    coordinator.lua  → Tile rendering orchestrator (1235 lines)
    active_grid_factory.lua → Active grid configuration
    pool_grid_factory.lua   → Pool grid configuration
    renderers/       → Tile drawing implementations
  state/
    animation.lua    → UI animation queues
    notification.lua → Status messages
    preferences.lua  → Search/sort/layout settings

defs/
  constants.lua      → App constants
  defaults.lua       → Default configurations
  strings.lua        → UI text strings
  palette.lua        → Color palette

tests/
  domain_tests.lua   → Domain logic tests
  integration_tests.lua → Full integration tests
```

---

## Key Concepts

### Bridge Pattern

**Location:** `data/bridge.lua`

The Bridge coordinates between the UI layer (app state, tiles) and the playback engine (domain/playback). When playlists are edited in the UI, the Bridge invalidates its cached sequence and lazily rebuilds on next playback request.

**Why it exists:**
- Decouples UI mutations from engine state
- Handles nested playlist expansion (recursion, loops)
- Caches flat sequences for performance
- Provides simplified API to UI

**Flow:**
```
UI edits playlist
  → controller.commit()
  → bridge.invalidate_sequence()
  → [User clicks play]
  → engine requests next region
  → bridge.get_sequence() (lazy rebuild)
  → expander.expand(playlists) → flat sequence
  → engine plays sequence
```

### Domain Composition Pattern

**Location:** `app/state.lua`

Instead of a monolithic 1170-line state module, RegionPlaylist decomposes state into 6 focused domain modules:

- **animation** - Pending UI animations (spawn/select/destroy)
- **notification** - Status messages and circular dependency errors
- **ui_preferences** - Search, sort, layout, pool mode settings
- **region** - Region cache and pool order
- **dependency** - Circular reference detection for nested playlists
- **playlist** - Playlist CRUD operations

**Benefits:**
- Unit testable with mocks (no full app context needed)
- Clear ownership of responsibilities
- Easier to reason about changes
- Smaller file sizes (150-200 lines vs 1170)

**Pattern:**
```lua
-- Each domain is instantiated
M.animation = Animation.new()
M.playlist = Playlist.new()

-- State exposes domain methods via accessors
function M.get_playlists()
  return M.playlist:get_all()
end

-- Or direct access for simple cases
local playlists = State.playlist:get_all()
```

### Factory Pattern

**Locations:** `ui/tiles/active_grid_factory.lua`, `ui/tiles/pool_grid_factory.lua`

Factories build configuration objects (opts tables) for ARKITEKT Grid widgets. They:
- Map app state to Grid widget parameters
- Wire interaction callbacks (drag, drop, reorder, select)
- Configure animations and visual effects
- Handle per-frame state updates

**Why factories exist:**
- Grid configuration is complex (400+ lines)
- Separates concerns: state management vs widget configuration
- Makes coordinator.lua readable (delegates config building)
- Follows ARKITEKT opts-based API pattern

### Sequence Expansion

**Location:** `domain/playback/expander.lua`

Nested playlists are recursively flattened into a linear sequence of `{rid, key, loops}` entries. The expander:
- Detects circular references (A contains B contains A)
- Respects repeat counts at each nesting level
- Maintains unique keys for UI animations
- Handles disabled items

**Example:**
```
Active Playlist:
  Region 1 (2 reps)
  Nested Playlist A (3 reps)
    Region 2 (1 rep)
    Region 3 (2 reps)

Expanded Sequence:
  [Region 1, Region 1, Region 2, Region 3, Region 3,
   Region 2, Region 3, Region 3, Region 2, Region 3, Region 3]
```

### Coordinator Pattern

**Location:** `ui/tiles/coordinator.lua`

The tile coordinator orchestrates:
- Grid widget lifecycle (active + pool)
- Per-frame caching (playlist lookups)
- Animation state (hover, spawn, destroy)
- Height stabilization (responsive sizing)
- Bridge registration (drag-drop coordination)
- Modal blocking detection

It's the "orchestration layer" between raw state and rendered grids.

---

## Data Flow

### User Action → State Update → UI Refresh

```
1. User drags region from pool to active
   ↓
2. Grid calls on_external_drop callback
   ↓
3. Callback invokes controller.add_item(rid, index)
   ↓
4. Controller modifies playlist via domain
   ↓
5. Controller calls commit() → persists + invalidates bridge
   ↓
6. State emits pending_spawn animation
   ↓
7. Next frame: GUI.update_state() processes animations
   ↓
8. Grid marks spawned items, triggers spawn animation
   ↓
9. Rendered with visual effects
```

### Playback Flow

```
1. User clicks Play button
   ↓
2. Transport calls bridge.play()
   ↓
3. Bridge checks if sequence is stale
   ↓
4. If stale: expander.expand(playlists) → flat sequence
   ↓
5. Engine.play(sequence)
   ↓
6. Per frame: Engine updates playback position
   ↓
7. UI polls bridge.get_current_key()
   ↓
8. Active grid highlights current tile
```

---

## Module Patterns

### ImGui-Style Module State

**Example:** `ui/views/transport/transport_view.lua`

Some modules use ImGui C++-style module-level state instead of OOP instances:

```lua
-- Private module state (like ImGui demo.* tables)
local view = {
  config = nil,
  state = nil,
  display = nil,
}

function M.init(config, state_module)
  view.config = config
  view.state = state_module
  -- Initialize once
end

function M.draw(ctx, shell_state, is_blocking)
  -- Access view.* directly
  local bridge = view.state.get_bridge()
end
```

**When to use:**
- Single-instance UI views (one transport bar per app)
- Stateless rendering modules
- Mimicking ImGui demo patterns

**When NOT to use:**
- Multiple instances needed (grids, tiles)
- Complex lifecycle management
- Heavy state mutations

**See also:** `TODO/IMGUI_MODULE_PATTERN.md`

### Per-Frame Caching

**Location:** `ui/tiles/coordinator.lua`

Coordinator caches playlist lookups per frame to avoid redundant queries:

```lua
local playlist_cache = {}
local cache_frame_time = 0

local function cached_get_playlist_by_id(get_fn, playlist_id)
  local current_time = reaper.time_precise()

  -- Invalidate cache on new frame
  if current_time ~= cache_frame_time then
    playlist_cache = {}
    cache_frame_time = current_time
  end

  if not playlist_cache[playlist_id] then
    playlist_cache[playlist_id] = get_fn(playlist_id)
  end

  return playlist_cache[playlist_id]
end
```

This pattern optimizes tile rendering when many tiles reference the same playlist.

---

## Testing

### Run Tests

```lua
-- From REAPER Developer Console:
package.path = [[D:\Dropbox\REAPER\Scripts\ARKITEKT-Dev\?.lua;]] .. package.path
dofile([[D:\Dropbox\REAPER\Scripts\ARKITEKT-Dev\ARKITEKT\scripts\RegionPlaylist\tests\run_tests.lua]])
```

### Test Structure

- **domain_tests.lua** - Unit tests for domain modules (playlist, region, dependency)
- **integration_tests.lua** - Full workflow tests (create → add → play → delete)

### Writing Tests

```lua
local TestRunner = require('arkitekt.testing.test_runner')

TestRunner.add_test("My Feature", "Should do X", function()
  -- Arrange
  local playlist = Playlist.new()

  -- Act
  local result = playlist:add_item(rid)

  -- Assert
  assert(result.ok, "Should succeed")
  assert(#playlist:get_items() == 1, "Should have 1 item")
end)
```

---

## Configuration

### Defaults

**Location:** `defs/defaults.lua`

Override via project ExtState or user config:

```lua
REGION_TILES = {
  responsive = {
    enabled = true,
    base_tile_height_active = 72,
    base_tile_height_pool = 72,
    min_tile_height = 20,
  },
  hover = {
    animation_speed = 0.15,
    brightness_factor = 1.4,
  },
  -- ...
}
```

### Theme Colors

**Location:** `defs/palette.lua`

Based on Catppuccin Mocha palette. Modify colors:

```lua
local PALETTE = {
  base = hexrgba("#1e1e2e"),
  text = hexrgba("#cdd6f4"),
  accent = hexrgba("#89b4fa"),
  -- ...
}
```

---

## Refactoring History

**See:** `REFACTORING.md` for detailed migration journey from monolithic to domain-composed architecture.

**Key migrations:**
- State module decomposition (1170 → 6 domains)
- Domain pattern introduction
- Bridge pattern extraction
- Grid API migration (imperative → opts-based)

---

## Performance Optimizations

### Tile Rendering

- Per-frame config caching (TileFXConfig.begin_frame)
- Playlist lookup caching (coordinator)
- Height stabilization (prevents jitter)
- Responsive tile sizing (fits available space)

### Playback Engine

- Lazy sequence expansion (only on invalidation)
- Cached expanded sequences
- Beat-aligned quantization
- Transition boundary detection

**See:** `ARKITEKT/scripts/ItemPicker/OPTIMIZATION.md` for general ARKITEKT performance patterns

---

## Common Tasks

### Add a New Domain Module

1. Create `domain/my_domain.lua`:
```lua
local M = {}

function M.new()
  return setmetatable({
    -- Private state
  }, { __index = M })
end

function M:my_method()
  -- Implementation
end

return M
```

2. Instantiate in `app/state.lua`:
```lua
M.my_domain = MyDomain.new()

function M.initialize(deps)
  M.my_domain:initialize(deps)
end
```

3. Add accessors:
```lua
function M.get_my_data()
  return M.my_domain:get_data()
end
```

### Add a Transport Button

1. Add icon to `ui/views/transport/transport_fx.lua`
2. Add button defaults to `defs/defaults.lua` TRANSPORT section
3. Update `app/config_factory.lua` get_transport_config() if dynamic behavior needed
4. Wire callback in `ui/views/transport/transport_view.lua`

### Extend Pool Sorting

1. Add sort mode to `defs/constants.lua` SORT_MODES
2. Implement logic in `app/pool_queries.lua`
3. Wire to UI in pool container config

---

## Troubleshooting

### Common Issues

**Grid not updating after state change:**
- Check if bridge.invalidate_sequence() called after edit
- Verify pending animations processed in update_state()

**Playback not advancing:**
- Check engine state machine in domain/playback/state.lua
- Verify sequence expansion in bridge

**Circular dependency detected:**
- Check dependency.lua detect_circular_reference()
- View circular path in notification bar

**Layout stuck in single column:**
- Verify layout_mode synced before draw (layout_view.lua)
- Check _active_min_col_w_fn updated in coordinator

---

## See Also

- `REFACTORING.md` - Migration history and lessons learned
- `cookbook/CONVENTIONS.md` - ARKITEKT coding conventions
- `cookbook/ARCHITECTURE.md` - Framework architecture guide
- `TODO/IMGUI_MODULE_PATTERN.md` - ImGui module state pattern
- `TODO/NAMING_STANDARDS.md` - Constructor and naming standards

---

## Contributing

When adding features:
1. Follow domain composition pattern for state
2. Use factory pattern for complex widget configs
3. Add tests to domain_tests.lua or integration_tests.lua
4. Document patterns in module headers
5. Update this README if adding new concepts

**Architecture questions?** Check `REFACTORING.md` for rationale behind current design.
