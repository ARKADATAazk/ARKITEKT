# Testing Guide for REAPER Lua

> "Since this is REAPER Lua, I'm not sure you can implement testing as you would in other environments."

**Good news: You absolutely can!** While REAPER Lua has unique constraints, most of your code can be tested effectively.

## Why Testing is Possible (and Necessary)

### What Makes REAPER Lua Different

1. **Runtime Environment**: Code runs inside REAPER, not standalone
2. **API Dependencies**: Heavy use of `reaper.*` functions
3. **GUI Framework**: ReaImGui is REAPER-specific
4. **No Node/npm**: Different ecosystem than JavaScript

### What Doesn't Change

1. **Logic is logic**: Math, string manipulation, algorithms work the same
2. **Lua is testable**: Standard Lua testing tools work fine
3. **Mocking works**: You can mock `reaper` and `r` globals
4. **CI/CD is possible**: GitHub Actions can run Lua tests

## Testing Strategy for ARKITEKT

### Layer 1: Pure Logic (Easy - 100% testable)

**What to test:**
- Configuration merging (`arkitekt/core/config.lua`)
- Color conversion (`arkitekt/core/colors.lua`)
- Math utilities (`arkitekt/core/math.lua`)
- JSON parsing (`arkitekt/core/json.lua`)
- UUID generation (`arkitekt/core/uuid.lua`)
- Layout calculations
- State management logic
- Data transformations

**No REAPER APIs needed!**

```lua
-- tests/unit/core/config_test.lua
describe("Config merge", function()
  local config = require("arkitekt.core.config")

  it("should merge nested tables", function()
    local base = { ui = { width = 400, height = 300 } }
    local override = { ui = { width = 600 } }

    local result = config.merge(base, override)

    assert.are.equal(600, result.ui.width)
    assert.are.equal(300, result.ui.height)  -- Preserved
  end)

  it("should respect merge precedence", function()
    local base = { color = 0x000000FF }
    local preset = { color = 0x111111FF, size = 14 }
    local user = { size = 16 }

    local result = config.resolve({
      base = base,
      preset = preset,
      user = user
    })

    -- Preset overrides base, user overrides preset
    assert.are.equal(0x111111FF, result.color)
    assert.are.equal(16, result.size)
  end)
end)
```

### Layer 2: REAPER API Logic (Medium - mockable)

**What to test with mocks:**
- Settings persistence (`arkitekt/core/settings.lua`)
- Undo manager (`arkitekt/core/undo_manager.lua`)
- Item/track data loading
- Theme detection
- Window management

**Strategy:** Mock the `reaper` global

```lua
-- tests/mocks/reaper_api.lua
local M = {}

-- Mock reaper global
M.reaper = {
  -- Extended state (settings persistence)
  GetExtState = function(section, key)
    return M._ext_state[section] and M._ext_state[section][key] or ""
  end,

  SetExtState = function(section, key, value, persist)
    M._ext_state[section] = M._ext_state[section] or {}
    M._ext_state[section][key] = value
  end,

  -- Project state
  GetProjectName = function()
    return "TestProject.rpp"
  end,

  -- Time/tempo
  TimeMap2_GetDividedBpmAtTime = function(proj, time)
    return 120.0  -- Mock 120 BPM
  end,

  -- Undo
  Undo_BeginBlock = function() end,
  Undo_EndBlock = function(desc, flags) end,
}

M._ext_state = {}

function M.reset()
  M._ext_state = {}
end

return M
```

**Using mocks in tests:**

```lua
-- tests/unit/core/settings_test.lua
describe("Settings persistence", function()
  local settings
  local mock_reaper

  before_each(function()
    -- Set up mock before loading module
    mock_reaper = require("tests.mocks.reaper_api")
    _G.reaper = mock_reaper.reaper
    mock_reaper.reset()

    -- Now load module (it will use mocked reaper)
    package.loaded["arkitekt.core.settings"] = nil
    settings = require("arkitekt.core.settings")
  end)

  after_each(function()
    _G.reaper = nil
  end)

  it("should save and load settings", function()
    settings.set("test_app", "width", 800)
    settings.set("test_app", "height", 600)

    local width = settings.get("test_app", "width", 400)
    local height = settings.get("test_app", "height", 300)

    assert.are.equal(800, tonumber(width))
    assert.are.equal(600, tonumber(height))
  end)

  it("should use default when key not found", function()
    local value = settings.get("test_app", "missing_key", 999)
    assert.are.equal(999, value)
  end)
end)
```

### Layer 3: Widget Logic (Medium - isolate calculations)

**What to test:**
- Layout calculations (position, size, wrapping)
- Hit testing (is point inside widget?)
- State transitions (hover, click, drag)
- Grid calculations (row/col from index)
- Scroll offset calculations

**Strategy:** Separate calculations from rendering

```lua
-- arkitekt/gui/widgets/grid/layout.lua
local M = {}

-- ✅ TESTABLE: Pure calculation function
function M.calculate_grid_layout(config)
  local items_per_row = math.floor(config.width / config.item_width)
  local row_count = math.ceil(config.item_count / items_per_row)
  local total_height = row_count * config.item_height

  return {
    items_per_row = items_per_row,
    row_count = row_count,
    total_height = total_height
  }
end

-- ✅ TESTABLE: Get item at position
function M.get_item_at_position(x, y, layout, config)
  local col = math.floor(x / config.item_width)
  local row = math.floor(y / config.item_height)
  local index = row * layout.items_per_row + col

  if index >= 0 and index < config.item_count then
    return index
  end
  return nil
end

return M
```

**Testing widget calculations:**

```lua
-- tests/unit/gui/widgets/grid_layout_test.lua
describe("Grid layout calculations", function()
  local layout = require("arkitekt.gui.widgets.grid.layout")

  describe("calculate_grid_layout", function()
    it("should calculate correct grid dimensions", function()
      local config = {
        width = 800,
        item_width = 100,
        item_height = 80,
        item_count = 50
      }

      local result = layout.calculate_grid_layout(config)

      assert.are.equal(8, result.items_per_row)  -- 800 / 100
      assert.are.equal(7, result.row_count)       -- ceil(50 / 8)
      assert.are.equal(560, result.total_height)  -- 7 * 80
    end)

    it("should handle fractional items per row", function()
      local config = {
        width = 450,  -- Not evenly divisible
        item_width = 100,
        item_height = 100,
        item_count = 20
      }

      local result = layout.calculate_grid_layout(config)

      assert.are.equal(4, result.items_per_row)  -- floor(450 / 100)
      assert.are.equal(5, result.row_count)      -- ceil(20 / 4)
    end)
  end)

  describe("get_item_at_position", function()
    it("should return correct item index", function()
      local config = {
        item_width = 100,
        item_height = 100,
        item_count = 50
      }
      local grid_layout = {
        items_per_row = 8
      }

      -- Click at (250, 150) should be item at col=2, row=1
      local index = layout.get_item_at_position(250, 150, grid_layout, config)

      assert.are.equal(10, index)  -- row 1 * 8 + col 2
    end)

    it("should return nil for out of bounds", function()
      local config = {
        item_width = 100,
        item_height = 100,
        item_count = 10
      }
      local grid_layout = {
        items_per_row = 8
      }

      local index = layout.get_item_at_position(250, 250, grid_layout, config)

      assert.is_nil(index)  -- Row 2, col 2 = index 18, but only 10 items
    end)
  end)
end)
```

### Layer 4: Integration (Hard - requires REAPER or heavy mocking)

**What NOT to unit test:**
- Actual ImGui rendering calls
- Real REAPER project manipulation
- File I/O to REAPER directories
- Audio processing

**Alternative:** Manual QA, smoke tests, documented test procedures

```markdown
## Manual Test Checklist - ItemPicker

### Basic Functionality
- [ ] Launch ARK_ItemPicker.lua from REAPER
- [ ] Verify window opens without errors
- [ ] Check that items load and display
- [ ] Test search functionality
- [ ] Test grid/list view toggle

### Performance
- [ ] Load project with 1000+ items
- [ ] Verify virtual scrolling works smoothly
- [ ] Check memory usage (Task Manager)

### Theme Integration
- [ ] Test with dark REAPER theme
- [ ] Test with light REAPER theme
- [ ] Change ARKITEKT theme and verify update
```

## Test Infrastructure Setup

### 1. Install Busted (Lua Testing Framework)

```bash
# Install LuaRocks (Lua package manager)
# macOS
brew install luarocks

# Linux
sudo apt-get install luarocks

# Windows
# Download from https://luarocks.org/

# Install Busted
luarocks install busted
```

### 2. Create Test Directory Structure

```
tests/
├── unit/                      # Pure logic tests (no REAPER)
│   ├── core/
│   │   ├── config_test.lua
│   │   ├── colors_test.lua
│   │   ├── math_test.lua
│   │   ├── json_test.lua
│   │   └── uuid_test.lua
│   ├── gui/
│   │   ├── layout_test.lua
│   │   └── widgets/
│   │       └── grid_layout_test.lua
│   └── apps/
│       └── color_palette/
│           └── state_test.lua
│
├── integration/               # Tests with mocked REAPER
│   ├── settings_test.lua
│   ├── undo_manager_test.lua
│   └── theme_load_test.lua
│
├── mocks/                     # Mock REAPER APIs
│   ├── reaper_api.lua
│   └── imgui_api.lua
│
├── fixtures/                  # Test data
│   ├── sample_config.lua
│   └── sample_theme.lua
│
└── spec_helper.lua           # Shared test utilities
```

### 3. Configure Lua Path for Tests

Create `.busted` configuration file:

```lua
-- .busted
return {
  _all = {
    lua = "lua5.3",
    ROOT = {"tests/"},
    pattern = "_test%.lua$",

    -- Add project to Lua path
    before = function()
      package.path = package.path .. ";./ARKITEKT/?.lua"
      package.path = package.path .. ";./ARKITEKT/?/init.lua"
    end
  }
}
```

### 4. Create Helper Module

```lua
-- tests/spec_helper.lua
local M = {}

-- Load module with mocked reaper global
function M.require_with_mock(module_path, mock_reaper)
  _G.reaper = mock_reaper or {}
  package.loaded[module_path] = nil
  local module = require(module_path)
  _G.reaper = nil
  return module
end

-- Deep table comparison
function M.table_equals(t1, t2)
  if type(t1) ~= "table" or type(t2) ~= "table" then
    return t1 == t2
  end

  for k, v in pairs(t1) do
    if not M.table_equals(v, t2[k]) then
      return false
    end
  end

  for k, v in pairs(t2) do
    if not M.table_equals(v, t1[k]) then
      return false
    end
  end

  return true
end

return M
```

### 5. Add GitHub Actions CI

```yaml
# .github/workflows/test.yml
name: Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Install Lua
      run: |
        sudo apt-get update
        sudo apt-get install -y lua5.3 liblua5.3-dev luarocks

    - name: Install Busted
      run: |
        sudo luarocks install busted

    - name: Run tests
      run: |
        busted tests/

    - name: Upload coverage (if luacov installed)
      run: |
        if command -v luacov &> /dev/null; then
          luacov
          cat luacov.report.out
        fi
```

## Running Tests

### Run All Tests

```bash
busted tests/
```

### Run Specific Test Suite

```bash
# Run only core tests
busted tests/unit/core/

# Run specific file
busted tests/unit/core/config_test.lua
```

### Run with Verbose Output

```bash
busted -v tests/
```

### Run with Coverage (requires luacov)

```bash
luarocks install luacov
busted -c tests/
luacov
cat luacov.report.out
```

### Watch Mode (auto-rerun on file changes)

```bash
# Install busted with luafilesystem
luarocks install luafilesystem

# Run in watch mode
busted --watch tests/
```

## Example Test Suite

### Priority Tests to Write First

1. **Config merge tests** (`tests/unit/core/config_test.lua`)
   - This is your #1 documented pain point
   - Test all 6 merge patterns and consolidate to one
   - Test precedence: BASE < PRESET < CONTEXT < USER

2. **Color conversion tests** (`tests/unit/core/colors_test.lua`)
   - Color format conversions
   - RGBA packing/unpacking
   - Color interpolation

3. **Grid layout tests** (`tests/unit/gui/widgets/grid_layout_test.lua`)
   - Virtual scrolling calculations
   - Item positioning
   - Hit testing

4. **Settings persistence tests** (`tests/integration/settings_test.lua`)
   - Save/load with mocked reaper.GetExtState
   - Default value handling
   - Type conversions

## What Success Looks Like

### Short Term (1 month)
- [ ] Busted installed and configured
- [ ] 20+ tests for core utilities
- [ ] Config merge precedence bug fixed via TDD
- [ ] GitHub Actions running tests on every PR

### Medium Term (3 months)
- [ ] 100+ tests covering core and GUI calculations
- [ ] Coverage >70% for `arkitekt/core/`
- [ ] Coverage >50% for `arkitekt/gui/` (layout logic)
- [ ] All new PRs include tests

### Long Term (6 months)
- [ ] Integration tests with full REAPER API mocks
- [ ] Performance benchmarks for widget rendering
- [ ] Visual regression testing for themes
- [ ] Community contributing tests with PRs

## Common Pitfalls & Solutions

### Pitfall 1: "Can't run tests without REAPER"

**Solution:** Separate pure logic from REAPER API calls

```lua
-- ❌ BAD: Logic mixed with REAPER API
function get_item_color(item)
  local color = reaper.GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR")
  return color | 0x1000000  -- Bit manipulation
end

-- ✅ GOOD: Separated into testable function
function add_color_flag(color)
  return color | 0x1000000  -- TESTABLE
end

function get_item_color(item)
  local color = reaper.GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR")
  return add_color_flag(color)  -- Logic extracted
end
```

### Pitfall 2: "Global state makes tests flaky"

**Solution:** Reset state between tests

```lua
describe("StatefulModule", function()
  local module

  before_each(function()
    package.loaded["arkitekt.stateful_module"] = nil
    module = require("arkitekt.stateful_module")
  end)

  it("test 1", function()
    -- Fresh module instance
  end)

  it("test 2", function()
    -- Another fresh instance, no pollution
  end)
end)
```

### Pitfall 3: "ImGui calls can't be tested"

**Solution:** Test the data, not the rendering

```lua
-- ❌ BAD: Untestable
function render_button(label, x, y)
  r.ImGui_SetCursorPos(ctx, x, y)
  if r.ImGui_Button(ctx, label) then
    do_action()
  end
end

-- ✅ GOOD: Testable logic, simple rendering
function calculate_button_bounds(label, x, y, config)
  return {
    x = x,
    y = y,
    width = config.button_width,
    height = config.button_height
  }
end

function render_button(label, x, y, config)
  local bounds = calculate_button_bounds(label, x, y, config)
  r.ImGui_SetCursorPos(ctx, bounds.x, bounds.y)
  if r.ImGui_Button(ctx, label, bounds.width, bounds.height) then
    do_action()
  end
end

-- TEST: calculate_button_bounds is pure and testable
```

## Conclusion

**Testing REAPER Lua is not only possible, it's essential for a top-tier toolkit.**

The key insight: **Most of your code is not REAPER-specific.** It's:
- Configuration management
- Color calculations
- Layout algorithms
- State management
- Data transformations

All of this is 100% testable with standard Lua testing tools.

For the REAPER-specific parts, mock the APIs you need and focus on testing your logic, not REAPER's implementation.

**Start small:**
1. Install Busted today
2. Write 5 tests for `config.lua` tomorrow
3. Fix the config merge bug via TDD
4. Add CI next week

You'll wonder how you lived without tests.
