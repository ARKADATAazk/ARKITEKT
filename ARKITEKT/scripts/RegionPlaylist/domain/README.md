# Domain Layer

> Business logic and domain models for RegionPlaylist

The domain layer contains focused, testable modules that encapsulate core business logic. Each domain module is independent, has clear responsibilities, and can be unit tested without UI or full app context.

---

## Architecture

```
domain/
├── playlist.lua        → Playlist CRUD operations (242 lines)
│   - Create, read, update, delete playlists
│   - Add/remove/reorder items
│   - Validate operations
│
├── region.lua          → Region cache and pool ordering (151 lines)
│   - Scan and cache regions from project
│   - Track pool order (user-defined sequence)
│   - Filter by search text
│
├── dependency.lua      → Circular reference detection (60 lines)
│   - Detect circular playlist nesting
│   - Prevent infinite loops
│   - Track dependency graphs
│
└── playback/           → Playback engine subsystem
    ├── controller.lua  → Main engine coordinator
    ├── state.lua       → State machine & sequence management
    ├── transport.lua   → Play/stop/seek operations
    ├── transitions.lua → Boundary detection
    ├── quantize.lua    → Beat quantization
    ├── loop.lua        → Loop boundary utilities
    └── expander.lua    → Nested playlist expansion
```

---

## Domain Composition Pattern

### What is Domain Composition?

Instead of a monolithic state module with all business logic mixed together, **domain composition** decomposes state into focused domain modules, each owning a specific business concern.

**Example:**

```lua
-- ❌ MONOLITHIC STATE (anti-pattern)
local State = {
  playlists = {},
  regions = {},
  pool_order = {},
  search_filter = "",
  circular_refs = {},

  function create_playlist(name) ... end,
  function delete_playlist(id) ... end,
  function scan_regions() ... end,
  function set_pool_order(order) ... end,
  function detect_circular(id) ... end,
  -- 1170+ lines of mixed concerns
}

-- ✅ DOMAIN COMPOSITION (our pattern)
local Playlist = require('domain.playlist')  -- 242 lines
local Region = require('domain.region')      -- 151 lines
local Dependency = require('domain.dependency')  -- 60 lines

local State = {
  playlist = Playlist.new(),
  region = Region.new(),
  dependency = Dependency.new(),
}

-- Each domain is focused and testable
State.playlist:create("My Playlist")
State.region:scan_project()
State.dependency:detect_circular_reference(active_id, source_id)
```

### Benefits

**1. Testability**
- Each domain can be unit tested with mocks
- No need for full app context
- Fast, isolated tests

```lua
-- Test playlist domain without UI or engine
local playlist_domain = Playlist.new()
local result = playlist_domain:create("Test")
assert(result.ok, "Should create playlist")
assert(#playlist_domain:get_all() == 1, "Should have 1 playlist")
```

**2. Clarity**
- Each domain has focused responsibility
- Clear ownership of operations
- Easy to reason about changes

**3. Maintainability**
- Smaller file sizes (60-250 lines vs 1170)
- Easier to navigate and modify
- Reduced cognitive load

**4. Reusability**
- Domains can be used in different contexts
- No coupling to specific UI or app structure
- Portable business logic

---

## Domain Modules

### Playlist Domain (domain/playlist.lua)

**Responsibility:** Playlist CRUD operations

**Key Methods:**
- `create(name)` - Create new playlist
- `delete(id)` - Delete playlist
- `get_by_id(id)` - Get playlist by ID
- `get_all()` - Get all playlists
- `add_item(id, item, index?)` - Add item to playlist
- `remove_items(id, keys)` - Remove items by key
- `reorder_items(id, new_items)` - Reorder playlist items
- `update_item(id, key, updates)` - Update item properties
- `set_active(id)` - Set active playlist

**State:**
```lua
{
  playlists = {
    ["uuid-1"] = {
      id = "uuid-1",
      name = "My Playlist",
      items = {
        {key = "key-1", type = "region", rid = 1, reps = 2},
        {key = "key-2", type = "playlist", playlist_id = "uuid-2", reps = 1},
      },
    },
  },
  active_playlist_id = "uuid-1",
  playlist_order = {"uuid-1", "uuid-2"},
}
```

**Example:**
```lua
local Playlist = require('domain.playlist')
local domain = Playlist.new()

-- Create
local result = domain:create("My Setlist")
if result.ok then
  local id = result.value

  -- Add items
  domain:add_item(id, {type = "region", rid = 1, reps = 2})
  domain:add_item(id, {type = "region", rid = 5, reps = 1})

  -- Reorder
  local items = domain:get_by_id(id).items
  domain:reorder_items(id, {items[2], items[1]})

  -- Set active
  domain:set_active(id)
end
```

---

### Region Domain (domain/region.lua)

**Responsibility:** Region cache and pool ordering

**Key Methods:**
- `scan_project()` - Scan and cache regions from REAPER project
- `get_by_rid(rid)` - Get region by REAPER ID
- `get_all()` - Get all cached regions
- `get_pool_order()` - Get user-defined pool order
- `set_pool_order(rids)` - Set pool order
- `filter_by_search(regions, text)` - Filter regions by search text

**State:**
```lua
{
  regions = {
    [1] = {rid = 1, name = "Intro", start_pos = 0, end_pos = 4.5, color = 0x...},
    [2] = {rid = 2, name = "Verse", start_pos = 4.5, end_pos = 16.0, color = 0x...},
  },
  pool_order = {1, 5, 2, 3},  -- User-defined sequence
}
```

**Example:**
```lua
local Region = require('domain.region')
local domain = Region.new()

-- Scan project
domain:scan_project()

-- Get region
local region = domain:get_by_rid(1)
print(region.name, region.start_pos, region.end_pos)

-- Set custom pool order
domain:set_pool_order({5, 1, 3, 2})

-- Filter by search
local all_regions = domain:get_all()
local filtered = domain:filter_by_search(all_regions, "verse")
```

---

### Dependency Domain (domain/dependency.lua)

**Responsibility:** Circular reference detection

**Key Methods:**
- `detect_circular_reference(target_id, source_id, get_playlist_fn)` - Check if adding source to target creates cycle
- `find_circular_path(target_id, source_id, get_playlist_fn)` - Get circular dependency path

**State:**
```lua
{
  -- No persistent state, pure function domain
}
```

**Example:**
```lua
local Dependency = require('domain.dependency')
local domain = Dependency.new()

-- Check if adding Playlist B to Playlist A creates cycle
local circular, path = domain:detect_circular_reference(
  "playlist-A",
  "playlist-B",
  function(id) return State.get_playlist_by_id(id) end
)

if circular then
  print("Circular reference detected:", table.concat(path, " → "))
  -- Output: "A → B → C → A"
else
  -- Safe to add
  playlist:add_item("playlist-A", {type = "playlist", playlist_id = "playlist-B"})
end
```

**How it works:**

```
Playlist A contains:
  - Region 1
  - Playlist B

Playlist B contains:
  - Region 2
  - Playlist C

Playlist C contains:
  - Region 3
  - Playlist A ← CIRCULAR!

Dependency graph:
A → B → C → A (cycle detected)
```

The dependency domain performs a depth-first search to detect cycles before allowing operations that would create them.

---

## Domain vs UI State

**Domain State:**
- Business logic and data
- Playlists, regions, dependencies
- Operations: CRUD, validation, calculations
- **Location:** `domain/` folder

**UI State:**
- UI preferences and ephemeral state
- Search filters, sort modes, layout mode
- Pending animations, notifications
- **Location:** `ui/state/` folder

**Example:**

```lua
-- ✅ DOMAIN: Business data and operations
domain/playlist.lua
  - playlists: {id, name, items}
  - create(name)
  - delete(id)
  - add_item(id, item)

-- ✅ UI STATE: UI preferences
ui/state/preferences.lua
  - search_filter: "intro"
  - sort_mode: "alphabetical"
  - layout_mode: "horizontal"
  - set_search_filter(text)
  - set_layout_mode(mode)

-- ✅ UI STATE: Transient UI state
ui/state/animation.lua
  - pending_spawn: ["key-1", "key-2"]
  - pending_select: ["key-3"]
  - add_pending_spawn(key)
  - clear_pending()
```

**Rule of Thumb:**
- If it's about **what data exists** → Domain
- If it's about **how to display it** → UI State

---

## Testing Domains

### Unit Test Example

```lua
local Playlist = require('domain.playlist')

-- Test create
local domain = Playlist.new()
local result = domain:create("Test Playlist")
assert(result.ok, "Should succeed")
assert(result.value, "Should return ID")

-- Test get
local playlist = domain:get_by_id(result.value)
assert(playlist.name == "Test Playlist", "Name should match")

-- Test add item
local add_result = domain:add_item(result.value, {
  type = "region",
  rid = 1,
  reps = 2,
})
assert(add_result.ok, "Should add item")
assert(#playlist.items == 1, "Should have 1 item")

-- Test validation
local invalid = domain:create("")
assert(not invalid.ok, "Should reject empty name")
assert(invalid.error, "Should have error message")
```

### Mock Dependencies

```lua
-- Domain needs external data (playlist lookup)
local Dependency = require('domain.dependency')
local domain = Dependency.new()

-- Mock playlist lookup
local mock_playlists = {
  ["A"] = {id = "A", items = {{type = "playlist", playlist_id = "B"}}},
  ["B"] = {id = "B", items = {{type = "playlist", playlist_id = "A"}}},
}

local function mock_get_playlist(id)
  return mock_playlists[id]
end

-- Test with mock
local circular, path = domain:detect_circular_reference("A", "B", mock_get_playlist)
assert(circular, "Should detect cycle")
assert(path[1] == "A" and path[#path] == "A", "Should return to start")
```

---

## Domain Initialization

Domains are initialized in `app/state.lua`:

```lua
-- app/state.lua
local Playlist = require('domain.playlist')
local Region = require('domain.region')
local Dependency = require('domain.dependency')

local M = {}

function M.initialize(deps)
  -- Initialize domain modules
  M.playlist = Playlist.new()
  M.region = Region.new()
  M.dependency = Dependency.new()

  -- Wire up dependencies
  M.region:scan_project()

  -- Load persisted data
  if deps.storage then
    local data = deps.storage:load()
    M.playlist:load_state(data.playlists)
    M.region:set_pool_order(data.pool_order or {})
  end
end

-- Expose domain methods via accessors
function M.get_playlists()
  return M.playlist:get_all()
end

function M.create_playlist(name)
  return M.playlist:create(name)
end

return M
```

---

## When to Create a New Domain

**Create a new domain when:**

1. **Distinct business concern** - The logic doesn't fit existing domains
2. **Testable independently** - Can be tested without UI
3. **Clear boundaries** - Operations are cohesive
4. **Reusable** - Could be used in different contexts

**Example: Adding "Tag" domain:**

```lua
-- domain/tag.lua
-- Manages user tags for regions (e.g., "Intro", "Chorus", "Solo")

local M = {}

function M.new()
  return setmetatable({
    tags = {},  -- {tag_name = {rid1, rid2, ...}}
  }, { __index = M })
end

function M:create_tag(name)
  if not name or name == "" then
    return {ok = false, error = "Tag name required"}
  end

  if self.tags[name] then
    return {ok = false, error = "Tag already exists"}
  end

  self.tags[name] = {}
  return {ok = true, value = name}
end

function M:tag_region(tag_name, rid)
  if not self.tags[tag_name] then
    self:create_tag(tag_name)
  end

  table.insert(self.tags[tag_name], rid)
  return {ok = true}
end

function M:get_regions_with_tag(tag_name)
  return self.tags[tag_name] or {}
end

function M:get_all_tags()
  local result = {}
  for tag_name, _ in pairs(self.tags) do
    table.insert(result, tag_name)
  end
  return result
end

return M
```

**Wire into state:**

```lua
-- app/state.lua
local Tag = require('domain.tag')

M.tag = Tag.new()

function M.tag_region(tag_name, rid)
  return M.tag:tag_region(tag_name, rid)
end

function M.get_regions_with_tag(tag_name)
  return M.tag:get_regions_with_tag(tag_name)
end
```

---

## Common Patterns

### Result Pattern

Domains return `{ok, value?, error?}` objects for operations:

```lua
-- Success
return {ok = true, value = created_id}

-- Failure
return {ok = false, error = "Name is required"}

-- Caller handles uniformly
local result = domain:create(name)
if result.ok then
  print("Created:", result.value)
else
  show_error(result.error)
end
```

### Validation at Boundaries

Validate inputs at the domain boundary:

```lua
function M:create(name)
  -- Validate
  if not name or name == "" then
    return {ok = false, error = "Name required"}
  end

  if #name > 100 then
    return {ok = false, error = "Name too long (max 100)"}
  end

  -- Proceed with valid input
  local id = generate_uuid()
  self.playlists[id] = {id = id, name = name, items = {}}
  return {ok = true, value = id}
end
```

### Immutable Returns

Don't let external code mutate internal state:

```lua
-- ❌ BAD: Returns internal reference
function M:get_all()
  return self.playlists  -- Caller can mutate!
end

-- ✅ GOOD: Returns copy
function M:get_all()
  local result = {}
  for id, playlist in pairs(self.playlists) do
    result[id] = playlist
  end
  return result
end

-- ✅ BETTER: Return shallow copy (faster)
function M:get_all()
  return {unpack(self.playlist_order):map(function(id)
    return self.playlists[id]
  end)}
end
```

---

## Migration from Monolithic to Domains

See `REFACTORING.md` for the full migration journey.

**Summary:**
1. **Identify concerns** - List distinct responsibilities in monolithic module
2. **Extract domains** - Create focused domain modules
3. **Wire in state** - Instantiate domains in app/state.lua
4. **Add accessors** - Provide accessor methods for backward compatibility
5. **Test** - Write unit tests for each domain
6. **Remove legacy** - Delete monolithic code after migration

**Before (monolithic):**
```lua
-- app/state.lua (1170 lines)
local M = {
  playlists = {},
  regions = {},
  pool_order = {},
  circular_refs = {},
}

function M.create_playlist(name) ... end
function M.scan_regions() ... end
function M.detect_circular(id) ... end
-- 50+ more functions mixed together
```

**After (domain composition):**
```lua
-- app/state.lua (677 lines, 42% reduction)
local Playlist = require('domain.playlist')  -- 242 lines
local Region = require('domain.region')      -- 151 lines
local Dependency = require('domain.dependency')  -- 60 lines

M.playlist = Playlist.new()
M.region = Region.new()
M.dependency = Dependency.new()

-- Thin accessors
function M.create_playlist(name)
  return M.playlist:create(name)
end
```

---

## See Also

- **Main README** - App architecture overview
- **app/state.lua** - Domain composition implementation
- **REFACTORING.md** - Migration history and lessons
- **cookbook/TESTING.md** - Testing guidelines
- **domain/playback/README.md** - Playback engine domain
