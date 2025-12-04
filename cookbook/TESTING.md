# Testing Guide

> How to write and run tests for ARKITEKT scripts.

---

## Overview

ARKITEKT provides a built-in test runner integrated into scripts. Tests run within REAPER (the host environment) and are launched via the titlebar debug menu.

**Key Principles:**
- Tests are **script-integrated** (not separate REAPER actions)
- Both **pure domain tests** and **integration tests** are supported
- Test runner uses REAPER's `time_precise()` for timing
- Results are logged via the Logger system

---

## Test Runner

Located at: `arkitekt/debug/test_runner.lua`

### API

```lua
local TestRunner = require('arkitekt.debug.test_runner')

-- Register a test suite
TestRunner.register("AppName.module", test_table)

-- Run a specific suite
local results = TestRunner.run("AppName.module")

-- Run all registered suites
local results = TestRunner.run_all()

-- Get registered apps
local apps = TestRunner.get_registered_apps()

-- Get last results
local results = TestRunner.get_results()
```

---

## Test File Structure

```
scripts/[AppName]/
└── tests/
    ├── domain_tests.lua       # Pure domain logic tests
    └── integration_tests.lua  # Tests using real REAPER data
```

### Domain Tests

Test pure business logic with mocked dependencies. No REAPER state required.

```lua
-- tests/domain_tests.lua
local TestRunner = require('arkitekt.debug.test_runner')
local assert = TestRunner.assert

local playlist_tests = {}

function playlist_tests.test_new_creates_empty_playlist()
  local Playlist = require('AppName.domain.playlist')
  local pl = Playlist.new("uuid-1", "My Playlist")

  assert.not_nil(pl, "Playlist should be created")
  assert.equals("My Playlist", pl.name, "Name should match")
  assert.table_length(pl.items, 0, "Should have no items")
end

function playlist_tests.test_add_item()
  local Playlist = require('AppName.domain.playlist')
  local pl = Playlist.new("uuid-1", "Test")

  Playlist.add_item(pl, { type = "region", rid = 1 })

  assert.table_length(pl.items, 1, "Should have 1 item")
end

-- Register the suite
TestRunner.register("AppName.domain.playlist", playlist_tests)

return playlist_tests
```

### Integration Tests

Test with real REAPER project data. Use skip helpers for missing prerequisites.

```lua
-- tests/integration_tests.lua
local TestRunner = require('arkitekt.debug.test_runner')
local Logger = require('arkitekt.debug.logger')
local assert = TestRunner.assert

-- Skip helper for tests requiring regions
local function skip_if_no_regions(test_fn)
  return function()
    local _, _, num_regions = reaper.CountProjectMarkers(0)
    if num_regions == 0 then
      Logger.warn("TEST", "SKIPPED - No regions in project")
      return
    end
    test_fn()
  end
end

local engine_tests = {}

function engine_tests.test_engine_scans_regions()
  local EngineState = require('AppName.engine.engine_state')
  local state = EngineState.new({ proj = 0 })

  local count = 0
  for _ in pairs(state.region_cache) do
    count = count + 1
  end

  local _, _, num_regions = reaper.CountProjectMarkers(0)
  assert.equals(num_regions, count, "Should match project region count")
end

-- Wrap with skip helper
engine_tests.test_with_regions = skip_if_no_regions(function()
  -- This only runs if project has regions
  local region = get_first_region()
  assert.not_nil(region, "Should find a region")
end)

TestRunner.register("AppName.integration.engine", engine_tests)

return engine_tests
```

---

## Assertions

The test runner provides these assertion helpers:

| Assertion | Usage |
|-----------|-------|
| `assert.truthy(value, msg)` | Value is truthy |
| `assert.falsy(value, msg)` | Value is falsy |
| `assert.equals(expected, actual, msg)` | Strict equality |
| `assert.not_equals(expected, actual, msg)` | Not equal |
| `assert.is_nil(value, msg)` | Value is nil |
| `assert.not_nil(value, msg)` | Value is not nil |
| `assert.is_type(value, type, msg)` | Type check |
| `assert.has_key(table, key, msg)` | Table has key |
| `assert.table_length(table, len, msg)` | Array length |
| `assert.throws(fn, pattern, msg)` | Function throws matching error |
| `assert.in_range(value, min, max, msg)` | Value in range |

### Examples

```lua
-- Type checking
assert.is_type(result, "table", "Should return table")

-- Error handling
assert.throws(function()
  domain:set_mode("invalid")
end, "Invalid mode", "Should reject invalid mode")

-- Numeric ranges
assert.in_range(opacity, 0, 1, "Opacity should be 0-1")
```

---

## Mocking Dependencies

For pure domain tests, create mock objects to isolate the unit under test:

```lua
-- Mock settings object
local function create_mock_settings()
  local store = {}
  return {
    get = function(_, key) return store[key] end,
    set = function(_, key, value) store[key] = value end,
    _store = store,  -- For test inspection
  }
end

-- Mock repository
local function create_mock_repository()
  local data = {}
  return {
    find_by_id = function(_, id) return data[id] end,
    save = function(_, item) data[item.id] = item end,
    delete = function(_, id) data[id] = nil end,
    _data = data,
  }
end

-- Usage in test
function tests.test_with_mocks()
  local settings = create_mock_settings()
  local domain = UIPref.new(CONSTANTS, settings)

  domain:set_layout_mode("vertical")
  domain:save_to_settings()

  assert.equals("vertical", settings._store.layout_mode)
end
```

---

## Launching Tests

Tests are launched via the titlebar context menu under the Debug section.

### Adding Test Menu to Your Script

In your titlebar/chrome setup:

```lua
-- In titlebar context menu setup
local function build_debug_menu(ctx)
  if ImGui.BeginMenu(ctx, "Debug") then

    if ImGui.MenuItem(ctx, "Run Domain Tests") then
      require('AppName.tests.domain_tests')
      TestRunner.run("AppName.domain.playlist")
      TestRunner.run("AppName.domain.region")
      -- ... other domain suites
    end

    if ImGui.MenuItem(ctx, "Run Integration Tests") then
      require('AppName.tests.integration_tests')
      TestRunner.run("AppName.integration.engine")
      TestRunner.run("AppName.integration.storage")
    end

    if ImGui.MenuItem(ctx, "Run All Tests") then
      require('AppName.tests.domain_tests')
      require('AppName.tests.integration_tests')
      TestRunner.run_all()
    end

    ImGui.EndMenu(ctx)
  end
end
```

### Test Output

Results are logged to the REAPER console via Logger:

```
[TEST] ═══════════════════════════════════════
[TEST] Running test suite: AppName.domain.playlist
[TEST] ═══════════════════════════════════════
[TEST] ✓ AppName.domain.playlist.test_new_creates_empty_playlist PASSED (0.05ms)
[TEST] ✓ AppName.domain.playlist.test_add_item PASSED (0.03ms)
[TEST] ✗ AppName.domain.playlist.test_remove_item FAILED: Expected 0, got 1
[TEST] ───────────────────────────────────────
[TEST] Results: 2/3 passed (0.12ms)
[TEST] 1 tests failed
[TEST] ═══════════════════════════════════════
```

---

## Test Organization

### By Layer

```
tests/
├── domain/                    # Domain tests
│   ├── playlist_tests.lua
│   ├── region_tests.lua
│   └── dependency_tests.lua
├── core/                      # Core utility tests
│   └── theme_params_tests.lua
└── integration/               # Full integration tests
    ├── storage_tests.lua
    └── workflow_tests.lua
```

### By Feature

```
tests/
├── domain_tests.lua           # All domain tests in one file
└── integration_tests.lua      # All integration tests in one file
```

Choose based on script complexity. Smaller scripts can use single files; larger ones benefit from per-module organization.

---

## Best Practices

### 1. Test Pure Logic First

Focus on `domain/` tests - they're fast, reliable, and don't need REAPER state.

```lua
-- GOOD: Tests pure logic
function tests.test_validate_rejects_empty_name()
  local result, err = Playlist.validate({ id = "x", name = "" })
  assert.falsy(result)
  assert.equals("Missing name", err)
end
```

### 2. Use Descriptive Test Names

```lua
-- BAD
function tests.test1() ... end

-- GOOD
function tests.test_add_item_to_empty_playlist_increases_count() ... end
```

### 3. One Assertion Per Concept

```lua
-- BAD: Too many unrelated assertions
function tests.test_playlist()
  assert.not_nil(pl)
  assert.equals("name", pl.name)
  assert.table_length(pl.items, 0)
  assert.is_nil(pl.chip_color)
end

-- GOOD: Focused assertions
function tests.test_new_playlist_has_empty_items()
  local pl = Playlist.new("id", "name")
  assert.table_length(pl.items, 0, "New playlist should have no items")
end
```

### 4. Skip Gracefully

Don't fail tests due to missing prerequisites:

```lua
function tests.test_with_track()
  local track = reaper.GetTrack(0, 0)
  if not track then
    Logger.warn("TEST", "SKIPPED - No tracks in project")
    return
  end
  -- ... actual test
end
```

### 5. Clean Up Side Effects

For integration tests that modify state:

```lua
function tests.test_save_and_load()
  local test_id = "test-" .. math.random(10000)

  -- Test
  Persistence.save_active_playlist(test_id, 0)
  local loaded = Persistence.load_active_playlist(0)
  assert.equals(test_id, loaded)

  -- Cleanup (optional - depends on your needs)
  -- Persistence.delete_active_playlist(0)
end
```

---

## Core/Integration Tests

Testing core modules that interact with REAPER requires REAPER to be running:

```lua
-- tests/core/theme_params_tests.lua
local TestRunner = require('arkitekt.debug.test_runner')
local assert = TestRunner.assert

local tests = {}

function tests.test_get_parameter_returns_value()
  local ThemeParams = require('ThemeAdjuster.platform.theme_params')

  -- This calls reaper.ThemeLayout_GetParameter internally
  local value = ThemeParams.get_parameter("tcp_height")

  -- Value may be nil if param doesn't exist, but should not error
  assert.is_type(value, "number", "Should return number or nil")
end

TestRunner.register("ThemeAdjuster.platform.theme_params", tests)
```

---

## See Also

- [ARCHITECTURE.md](./ARCHITECTURE.md) - Layer purity rules and script organization
- `arkitekt/debug/test_runner.lua` - Test runner source
- `scripts/RegionPlaylist/tests/` - Reference implementation
