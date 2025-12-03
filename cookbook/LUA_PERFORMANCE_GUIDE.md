# Lua Performance Optimization Guide

> Complete reference for ARKITEKT and REAPER script development

## Quick Reference

| Pattern | Slow | Fast | Impact |
|---------|------|------|--------|
| Floor | `math.floor(x)` | `x//1` | 5-10% CPU |
| Insert | `table.insert(t, x)` | `t[#t+1] = x` | Function overhead |
| Globals | `math.sin(x)` in loop | `local sin = math.sin` | 30% faster |
| Strings | `s = s .. x` in loop | `table.concat(parts)` | O(n) vs O(n²) |
| Config | `config.a.b.c` per-item | Cache once per frame | 60% faster |
| Renderer setup | Per-tile config lookups | cache_config() once per frame | 60% faster |
| Colors | `hex("#FF0000")` | `0xFF0000FF` (bytes) | 0.5-1μs per call |
| Iteration | `for k,v in pairs(t)` | `for i=1,#t` (arrays) | 20-30% faster |

---

## Golden Rules

1. **Don't optimize** - Write clear code first
2. **Don't optimize yet** - Get it working, then profile
3. **Profile before and after** - Measure everything

### Performance Targets (REAPER Scripts)

| Metric | Status |
|--------|--------|
| Idle CPU < 1% | Fine |
| Idle CPU 1-5% | Monitor |
| Idle CPU > 5% | Investigate |

**Stress test scale:** 10 → 50 → 100 → 500 → 1,000 → 10,000 items

---

## Local Variables

**Impact:** 30% faster for function calls in loops

```lua
-- SLOW (4 global lookups per iteration)
for i = 1, 1000000 do
  local x = math.sin(i)
end

-- FAST (1 global lookup total)
local sin = math.sin
for i = 1, 1000000 do
  local x = sin(i)
end
```

**Why:** Local variables use registers (up to 250 per function). Globals require `GETGLOBAL` bytecode instructions.

### ARKITEKT Pattern

```lua
-- At module top (see renderer.lua, draw.lua)
local max = math.max
local min = math.min
local floor = math.floor  -- Or just use //1

-- For ImGui functions in hot paths
local AddRectFilled = ImGui.DrawList_AddRectFilled
local AddLine = ImGui.DrawList_AddLine
```

---

## Math Operations

### Floor Division

```lua
math.floor(x)  -- SLOW: C function call
x // 1         -- FAST: VM operation

-- Examples
local px = (x + 0.5) // 1     -- Round to nearest pixel
local idx = (n / step) // 1   -- Integer division
```

### Ceiling (No Built-in Fast Version)

```lua
math.ceil(n)        -- Standard way
(n + 1 - n % 1)     -- Slightly faster alternative
```

### ARKITEKT Examples

```lua
-- From renderer.lua - color component clamping
r = min(255, max(0, (r * brightness) // 1))

-- From draw.lua - pixel snapping
function M.snap(x)
  return (x + 0.5) // 1
end
```

---

## String Operations

### Search vs Match

```lua
string.match(str, "pattern")  -- SLOW: Allocates new string
string.find(str, "pattern")   -- FAST: Returns indices only
```

### String Concatenation in Loops

```lua
-- SLOW: O(n²) - Creates n new strings
local s = ""
for i = 1, 1000 do
  s = s .. items[i]
end

-- FAST: O(n) - Single allocation at end
local parts = {}
for i = 1, 1000 do
  parts[#parts + 1] = items[i]
end
local s = table.concat(parts)
```

**Benchmark:** 5MB file: 5 minutes (slow) vs 0.28 seconds (fast)

---

## Color Parsing Overhead

### The Problem: hex() String Parsing

**Impact:** 0.5-1μs per call (string parsing, validation, bit operations)

```lua
-- SLOW: String parsing every call
local color = hex("#FF5500")     -- ~0.5-1μs
local color = hex("#FF5500FF")   -- ~0.5-1μs

-- FAST: Pre-computed byte literal
local color = 0xFF5500FF            -- ~0ns (compile-time constant)
```

### When String Parsing Hurts

| Context | Calls | Overhead |
|---------|-------|----------|
| Module load (cached) | Once | Negligible |
| Theme change (cached) | Rare | Negligible |
| Per-frame render | 30-60fps × N calls | **Significant** |
| Per-tile render | N tiles × M colors | **Critical** |

### ARKITEKT Codebase Status

**Found:** 1,302 `hex()` calls across 170 files

| Location | Per-Frame? | Action |
|----------|-----------|--------|
| `defs/constants.lua` (cached) | No | Convert for consistency |
| `defs/colors/theme.lua` (cached) | No | Convert for consistency |
| Widget draw functions | **Yes** | **Convert immediately** |
| Render loops | **Yes** | **Convert immediately** |

### The Fix: Bytes Everywhere

```lua
-- Before (string parsing per-frame)
local HOVER_COLOR = hex("#FFFFFF20")
local ERROR_COLOR = hex("#CC2222")

-- After (zero-cost byte literals)
local HOVER_COLOR = 0xFFFFFF20
local ERROR_COLOR = 0xCC2222FF
```

**Format:** `0xRRGGBBAA` (red, green, blue, alpha)

### IDE Support

VS Code extension available for byte color preview:
- Hover over `0xFF5500FF` shows color swatch
- Color picker integration

### Migration Strategy

See `TODO/01_HIGH/REFACTOR_ColorsModule.md` for the full migration plan.

---

## Table Operations

### Insert

```lua
table.insert(tbl, x)  -- SLOW: Function call overhead
tbl[#tbl + 1] = x     -- FAST: Direct indexing
```

### Preallocation

```lua
-- SLOW: Multiple rehashes
local t = {}
t[1] = a; t[2] = b; t[3] = c

-- FAST: Pre-sized
local t = {true, true, true}
t[1] = a; t[2] = b; t[3] = c
```

### Cache Length

```lua
-- SLOW: Recalculates #items each iteration
for i = 1, #items do
  process(items[i])
end

-- FAST: Cache once
local n = #items
for i = 1, n do
  process(items[i])
end
```

### Table Internals

- **Array part:** Integer keys 1 to n (>50% filled)
- **Hash part:** All other keys (strings, sparse integers)
- **Rehash:** Triggered when table full, doubles size
- **Sizes:** Always powers of 2

---

## Loop Optimization

### Avoid Object Creation

```lua
-- SLOW: Allocates 1000 tables
for i = 1, 1000 do
  local point = {x = i, y = i * 2}
  draw(point)
end

-- FAST: Reuses single table
local point = {x = 0, y = 0}
for i = 1, 1000 do
  point.x, point.y = i, i * 2
  draw(point)
end
```

### Iterator Overhead

```lua
-- SLOW: pairs() has function call overhead per iteration
for k, v in pairs(t) do
  process(v)
end

-- MEDIUM: ipairs() is faster but still has iterator overhead
for i, v in ipairs(t) do
  process(v)
end

-- FAST: Numeric for loop (20-30% faster than pairs)
local n = #items
for i = 1, n do
  process(items[i])
end
```

**When to use what:**
- `pairs()` - Hash tables (string keys, sparse arrays)
- `ipairs()` - Sequential arrays when you need both index and value
- Numeric `for` - Sequential arrays in hot paths (render loops)

### Move Constants Out

```lua
-- SLOW: Creates table every iteration
for i = 1, n do
  local config = {threshold = 10, enabled = true}
  process(config)
end

-- FAST: Create once
local config = {threshold = 10, enabled = true}
for i = 1, n do
  process(config)
end
```

---

## ImGui / Drawing

### Batch Draw Calls

```lua
-- SLOW: 1000 individual calls
for i = 1, 1000 do
  ImGui.DrawList_AddLine(dl, x1, y1, x2, y2, color)
end

-- FAST: Single batched call
ImGui.DrawList_AddPolyline(dl, points, color)
```

### Cache DrawList

```lua
-- SLOW: Gets draw list every call
function render_item(ctx, item)
  local dl = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddRect(dl, ...)
end

-- FAST: Pass draw list as parameter
function render_item(dl, item)
  ImGui.DrawList_AddRect(dl, ...)
end

-- In parent:
local dl = ImGui.GetWindowDrawList(ctx)
for _, item in ipairs(items) do
  render_item(dl, item)
end
```

### ARKITEKT Pattern (renderer.lua)

```lua
-- Cache ImGui functions at module top
local AddRectFilled = ImGui.DrawList_AddRectFilled
local AddRect = ImGui.DrawList_AddRect
local PushClipRect = ImGui.DrawList_PushClipRect
local PopClipRect = ImGui.DrawList_PopClipRect

function M.render_base_fill(dl, x1, y1, x2, y2, rounding)
  AddRectFilled(dl, x1, y1, x2, y2, BASE_NEUTRAL, rounding, DrawFlags_RoundCornersAll)
end
```

---

## REAPER-Specific Optimizations

### Cache API Functions

```lua
-- At module top for functions used in loops
local GetPlayPosition = reaper.GetPlayPosition
local EnumProjectMarkers = reaper.EnumProjectMarkers
local time_precise = reaper.time_precise

-- In loop
local pos = GetPlayPosition()
```

### Project State Detection

```lua
-- GOOD: Check change count instead of polling everything
local last_state = reaper.GetProjectStateChangeCount(0)

function check_for_changes()
  local current = reaper.GetProjectStateChangeCount(0)
  if current ~= last_state then
    last_state = current
    refresh_data()
  end
end
```

### Defer Loop Efficiency

```lua
-- Standard defer pattern
local function main()
  -- Update logic
  reaper.defer(main)
end

-- With frame rate limiting (if needed)
local last_time = 0
local MIN_INTERVAL = 0.016  -- ~60 FPS

local function main()
  local now = reaper.time_precise()
  if now - last_time >= MIN_INTERVAL then
    last_time = now
    -- Update logic
  end
  reaper.defer(main)
end
```

---

## Per-Frame Config Caching

**Impact:** Up to 60% faster for high-iteration rendering (thousands of items)

### The Problem

When rendering many items (tiles, rows, notes), accessing config values per-item creates massive overhead:

```lua
-- SLOW: Config with metatable or nested tables
for i = 1, 10000 do
  local threshold = config.TILE_RENDER.responsive.hide_text_below  -- 4+ lookups
  local padding = config.TILE_RENDER.text.padding_left             -- 4+ lookups
  -- ... 50 more config accesses per tile
end
-- Result: 10,000 × 50 × 4 = 2,000,000 table/metatable lookups
```

If config uses metatables (common for defaults/inheritance), the overhead is even worse - each access triggers `__index` metamethod calls.

**Real-world finding:** In ItemPicker with ~10,000 tiles, `CONFIG.__index` consumed **47% of total execution time**.

### The Solution: Per-Frame Caching

Cache all config values once at frame start, access cached locals during rendering:

```lua
-- At module top
local _frame_cache = {}

-- Called once per frame (in begin_frame or similar)
function M.cache_config(config)
  local tr = config.TILE_RENDER
  local c = _frame_cache

  -- Cache all values used in per-item loops
  c.hide_text_below = tr.responsive.hide_text_below
  c.text_padding_left = tr.text.padding_left
  c.text_padding_top = tr.text.padding_top
  c.header_alpha = tr.header.alpha
  c.badge_bg = tr.badge.bg
  -- ... cache everything accessed per-item
end

-- Expose for other modules
M.cfg = _frame_cache

-- In render loop - use cached values
for i = 1, 10000 do
  local threshold = _frame_cache.hide_text_below  -- 1 lookup
  local padding = _frame_cache.text_padding_left  -- 1 lookup
end
-- Result: 10,000 × 50 × 1 = 500,000 lookups (4x reduction)
```

### Critical: Declaration Order

The cache table MUST be declared before any functions that use it:

```lua
-- CORRECT
local M = {}
local _frame_cache = {}  -- Declared BEFORE functions

function M.render()
  local value = _frame_cache.threshold  -- Works
end

-- WRONG - will cause runtime nil errors
function M.render()
  local value = _frame_cache.threshold  -- nil! (captured at parse time)
end

local _frame_cache = {}  -- Too late!
```

### When to Use

| Scenario | Use Per-Frame Caching? |
|----------|------------------------|
| 10+ items in loop | Consider it |
| 100+ items in loop | Recommended |
| 1000+ items in loop | Essential |
| Config has metatables | Essential |
| Single item render | Not needed |

### ARKITEKT Example

From `scripts/ItemPicker/ui/grids/renderers/base.lua`:

```lua
-- PERF: Per-frame config cache
-- Eliminates 47% overhead from config.TILE_RENDER.__index
local _frame_config = {}

M.cfg = _frame_config  -- Expose for audio.lua/midi.lua

function M.cache_config(config)
  local tr = config.TILE_RENDER
  local c = _frame_config

  -- Cascade animation
  c.cascade_scale_from = tr.cascade.scale_from
  c.cascade_y_offset = tr.cascade.y_offset

  -- Header bar
  c.header_alpha = tr.header.alpha
  c.header_min_height = tr.header.min_height

  -- Text rendering
  c.text_padding_left = tr.text.padding_left
  c.text_margin_right = tr.text.margin_right

  -- ... 60+ more values
end

function M.begin_frame(ctx, config)
  if config then
    M.cache_config(config)
  end
end
```

Usage in render functions:

```lua
-- In audio.lua
local cfg = BaseRenderer.cfg

function M.render(ctx, dl, rect, item_data, ...)
  -- Use cached values
  local scale_from = cfg.cascade_scale_from
  local header_h = cfg.header_min_height
  -- ...
end
```

### Results

**Cumulative per second** (~500 visible tiles × 32fps = ~16,000 tile renders/sec):
- Before: ~250ms/sec (~7.8ms/frame)
- After: ~90-100ms/sec (~3ms/frame)
- **60% improvement**

---

## Memory Management

### Data Representation

```lua
-- 95 KB for 1M points
points = {{x=10.3, y=98.5}, {x=10.3, y=18.3}, ...}

-- 65 KB for 1M points
points = {{10.3, 98.5}, {10.3, 18.3}, ...}

-- 24 KB for 1M points (Structure of Arrays)
points = {
  x = {10.3, 10.3, 15.0, ...},
  y = {98.5, 18.3, 98.5, ...}
}
```

### Memoization

```lua
local function memoize(f)
  local cache = {}
  setmetatable(cache, {__mode = "kv"})  -- Weak table
  return function(x)
    local result = cache[x]
    if not result then
      result = f(x)
      cache[x] = result
    end
    return result
  end
end

-- Example: Cache parsed colors
local parse_color = memoize(function(hex)
  return Colors.hex(hex)
end)
```

---

## Garbage Collection

### When to Control GC

```lua
-- Stop during time-critical sections
collectgarbage("stop")
-- ... critical work ...
collectgarbage("restart")

-- Force collection during idle
collectgarbage("collect")

-- Check memory usage
local kb = collectgarbage("count")
```

### ARKITEKT Pattern (lifecycle.lua)

```lua
-- Force GC on script exit/cleanup
function M.cleanup()
  -- Release resources...
  collectgarbage('collect')
end
```

---

## Common Pitfalls

### Boolean Ternary Pattern

```lua
-- BROKEN: Fails when value is false
local enabled = opts.enabled ~= nil and opts.enabled or default
-- When opts.enabled = false: returns default (wrong!)

-- CORRECT: Handles false properly
local enabled = opts.enabled == nil and default or opts.enabled
-- When opts.enabled = false: returns false
-- When opts.enabled = nil: returns default
```

### Table Traversal with Deletion

```lua
-- CORRECT: O(n)
for k in pairs(t) do
  if should_delete(k) then
    t[k] = nil
  end
end

-- BROKEN: O(n²) - next() restarts search
while true do
  local k = next(t)
  if not k then break end
  t[k] = nil
end
```

### Closure Creation in Loops

```lua
-- SLOW: Creates closure each iteration
for i = 1, n do
  button:on_click(function() handle(i) end)
end

-- BETTER: Define handler outside if possible
local handlers = {}
for i = 1, n do
  handlers[i] = function() handle(i) end
end
```

---

## Profiling in REAPER

### Basic Timing

```lua
local start = reaper.time_precise()
-- ... code to measure ...
local elapsed = reaper.time_precise() - start
reaper.ShowConsoleMsg(string.format("Elapsed: %.4fms\n", elapsed * 1000))
```

### Section Profiling

```lua
local Profiler = {}
local timings = {}

function Profiler.start(name)
  timings[name] = reaper.time_precise()
end

function Profiler.stop(name)
  local elapsed = reaper.time_precise() - timings[name]
  reaper.ShowConsoleMsg(string.format("%s: %.4fms\n", name, elapsed * 1000))
end

-- Usage
Profiler.start("render")
render_all_tiles()
Profiler.stop("render")
```

---

## Best Practices Summary

1. **Profile first** - Don't guess, measure with `time_precise()`
2. **Local everything** - Cache globals, functions, lengths at module top
3. **Use `//1`** - Instead of `math.floor()` in hot paths
4. **Use `t[#t+1]`** - Instead of `table.insert()`
5. **Batch strings** - Use `table.concat()` for building strings
6. **Reuse objects** - Move allocations out of loops
7. **Cache ImGui functions** - In rendering hot paths
8. **Use state change count** - Not polling for REAPER project changes
9. **Batch draw calls** - Polyline over individual lines
10. **Per-frame config caching** - For 1000+ item loops with config access
11. **Profile again** - Verify optimizations actually helped

---

## ARKITEKT Codebase Audit (2024-12)

Current pollution patterns found in the codebase:

### Pattern Counts

| Pattern | Count | Location | Priority |
|---------|-------|----------|----------|
| `hex()` calls | 1,302 | 170 files | 🔴 High |
| Non-localized `math.*` | 260 | 65 files (vs 12 localized) | 🟠 Medium |
| `= {}` allocations | 276 | 81 files (audit hot paths) | 🟠 Medium |
| `pairs()` in loops | 64 | 28 files | 🟡 Low |
| String concat `..` | 26 | 18 files | 🟡 Low |
| `string.format()` | 25 | 16 files | 🟡 Low |

### Estimated Savings

| Fix | Estimated Gain | Effort |
|-----|----------------|--------|
| hexrgb → bytes | 0.1-0.25ms/frame | Medium |
| Localize math.* | 0.02-0.05ms/frame | Low |
| pairs → numeric for | 0.01-0.03ms/frame | Low |
| Table reuse | Variable | High |

### Files Most in Need of Optimization

**gui/widgets/** - 81 files with `= {}` allocations
**gui/widgets/effects/hatched_fill.lua** - 32 `math.*` calls (hot path)
**gui/widgets/containers/grid/core.lua** - 22 `math.*` + 23 `= {}` allocations

### Tracking

See `TODO/01_HIGH/PERFORMANCE_SWEEP.md` for the full remediation plan.

---

## Resources

- [Lua Performance Tips (PDF)](https://www.lua.org/gems/sample.pdf) - Roberto Ierusalimschy
- [ReaImGui Documentation](https://github.com/cfillion/reaimgui)
- ARKITEKT examples: `arkitekt/gui/rendering/tile/renderer.lua`, `arkitekt/gui/draw.lua`

---

**Remember:** Premature optimization is the root of all evil. Write clear code first, profile, then optimize the hot paths.
