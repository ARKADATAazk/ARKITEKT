# Debugging Guide

> Techniques for profiling, debugging, and troubleshooting ARKITEKT applications.

---

## Quick Reference

| Issue | First Check | Tool |
|-------|-------------|------|
| High CPU usage | Hot loop profiling | `reaper.time_precise()` |
| Memory growth | Allocation in render | `collectgarbage("count")` |
| State not persisting | Widget ID uniqueness | `Base.get_state(id)` |
| Theme not updating | Colors cached at load | Read `Theme.COLORS` every frame |
| Scroll not working | Child window flags | `ImGui.WindowFlags_*` |

---

## Profiling Techniques

### Basic Timing

Use `reaper.time_precise()` for accurate sub-millisecond measurement:

```lua
local start = reaper.time_precise()
-- ... code to measure ...
local elapsed = reaper.time_precise() - start
reaper.ShowConsoleMsg(string.format("Elapsed: %.4fms\n", elapsed * 1000))
```

### Section Profiler

For tracking multiple code sections:

```lua
local Profiler = {}
local timings = {}
local counts = {}

function Profiler.start(name)
  timings[name] = reaper.time_precise()
end

function Profiler.stop(name)
  local elapsed = reaper.time_precise() - (timings[name] or 0)
  counts[name] = (counts[name] or 0) + 1
  reaper.ShowConsoleMsg(string.format("[%s] %.4fms (call #%d)\n",
    name, elapsed * 1000, counts[name]))
end

-- Usage
Profiler.start("render_tiles")
render_all_tiles()
Profiler.stop("render_tiles")
```

### Per-Frame Profiler

Track performance across multiple frames:

```lua
local frame_times = {}
local MAX_SAMPLES = 60

local function track_frame(elapsed)
  frame_times[#frame_times + 1] = elapsed
  if #frame_times > MAX_SAMPLES then
    table.remove(frame_times, 1)
  end
end

local function get_stats()
  local sum, min, max = 0, math.huge, 0
  for _, t in ipairs(frame_times) do
    sum = sum + t
    min = math.min(min, t)
    max = math.max(max, t)
  end
  local avg = sum / #frame_times
  return {
    avg_ms = avg * 1000,
    min_ms = min * 1000,
    max_ms = max * 1000,
    fps = 1 / avg
  }
end
```

### Performance Targets

| Metric | Status | Action |
|--------|--------|--------|
| Idle CPU < 1% | Fine | No action needed |
| Idle CPU 1-5% | Monitor | Profile main loop |
| Idle CPU > 5% | Investigate | Profile and optimize hot paths |

**Frame time targets:**
- 60 FPS = 16.6ms per frame
- 30 FPS = 33.3ms per frame
- Comfortable = under 8ms per frame

---

## Memory Debugging

### Track Memory Usage

```lua
local function get_memory_kb()
  return collectgarbage("count")
end

-- Check before/after an operation
local before = get_memory_kb()
do_something()
local after = get_memory_kb()
reaper.ShowConsoleMsg(string.format("Memory delta: %.2f KB\n", after - before))
```

### Find Memory Leaks

Look for growing memory over time:

```lua
local baseline = nil
local check_count = 0

local function check_memory()
  collectgarbage("collect")  -- Force GC first
  local current = collectgarbage("count")

  if not baseline then
    baseline = current
  else
    check_count = check_count + 1
    local growth = current - baseline
    if growth > 100 then  -- 100KB threshold
      reaper.ShowConsoleMsg(string.format(
        "Memory growth: %.2f KB after %d checks\n",
        growth, check_count))
    end
  end
end
```

### Common Memory Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Steady growth | Allocations in render loop | Move allocations outside loop |
| Sudden spikes | Large table creation | Pre-allocate or reuse tables |
| Never decreasing | Strong references | Use weak tables or nil references |

---

## Common Issues and Solutions

### Widget State Lost Between Frames

**Symptom:** Widget resets to default state every frame.

**Cause:** Using same ID for multiple instances, or ID changes each frame.

**Solution:**
```lua
-- BAD: Generic ID causes state collision
local state = Base.get_state("button")

-- BAD: ID changes every frame
local state = Base.get_state("button_" .. os.time())

-- GOOD: Unique, stable ID per instance
local id = opts.id or ("button_" .. tostring(opts):match("0x(%x+)"))
local state = Base.get_state(id)
```

### Theme Colors Not Updating

**Symptom:** Widget colors don't change when theme switches.

**Cause:** Colors cached at module load time.

**Solution:**
```lua
-- BAD: Cached at module load (stale after theme switch)
local BG_COLOR = Theme.COLORS.BG_BASE

function M.draw(ctx, opts)
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, BG_COLOR)
end

-- GOOD: Read fresh every frame
function M.draw(ctx, opts)
  local bg = Theme.COLORS.BG_BASE  -- Fresh every frame
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, bg)
end
```

### Scroll Position Jumping

**Symptom:** Scroll position resets or jumps unexpectedly.

**Cause:** Content height changing between frames, or child window recreated.

**Solution:**
```lua
-- Ensure stable content height
local content_height = calculate_stable_height(items)

-- Use consistent child window ID
ImGui.BeginChild(ctx, "##content_" .. panel_id, w, h, flags)
```

### Click Events Not Registering

**Symptom:** Buttons or interactive areas don't respond to clicks.

**Cause:** Another invisible element consuming the input, or cursor not advanced.

**Solution:**
```lua
-- Ensure correct cursor position before invisible button
ImGui.SetCursorScreenPos(ctx, x, y)
ImGui.InvisibleButton(ctx, id, width, height)

-- Check for overlapping invisible buttons
local hovered = ImGui.IsItemHovered(ctx)
local clicked = ImGui.IsItemClicked(ctx)
```

### Overlapping Widgets

**Symptom:** Widgets draw on top of each other.

**Cause:** Cursor not advanced after drawing.

**Solution:**
```lua
function M.draw(ctx, opts)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  -- ... draw widget ...

  -- IMPORTANT: Advance cursor
  ImGui.SetCursorScreenPos(ctx, x, y + height)
end
```

### Animation Stuttering

**Symptom:** Animations are choppy or inconsistent.

**Cause:** Creating new animation objects every frame, or not using delta time.

**Solution:**
```lua
-- BAD: Creates new animation object every frame
function M.draw(ctx, opts)
  local anim = Animation.new(0.3)  -- New object every frame!
  -- ...
end

-- GOOD: Store animation in state
function M.draw(ctx, opts)
  local state = Base.get_state(id) or { anim = Animation.new(0.3) }
  state.anim:update(dt)  -- Use delta time
  Base.set_state(id, state)
end
```

### "Module not found" Errors

**Symptom:** `require()` fails even though file exists.

**Cause:** Bootstrap hasn't run yet, or wrong namespace.

**Solution:**
```lua
-- Entry points MUST use dofile (not require) for bootstrap
local ARK = dofile(init_path).bootstrap()

-- After bootstrap, require works
local Button = require('arkitekt.gui.widgets.primitives.button')

-- Check namespace - always lowercase 'arkitekt'
-- BAD:  require('arkitekt.gui.widgets...')
-- GOOD: require('arkitekt.gui.widgets...')
```

---

## Debug Output

### Console Messages

```lua
-- Simple message
reaper.ShowConsoleMsg("Debug: something happened\n")

-- Formatted output
reaper.ShowConsoleMsg(string.format("Value: %d, Name: %s\n", val, name))

-- Table inspection
local function dump(t, indent)
  indent = indent or ""
  for k, v in pairs(t) do
    if type(v) == "table" then
      reaper.ShowConsoleMsg(indent .. k .. " = {\n")
      dump(v, indent .. "  ")
      reaper.ShowConsoleMsg(indent .. "}\n")
    else
      reaper.ShowConsoleMsg(indent .. k .. " = " .. tostring(v) .. "\n")
    end
  end
end
```

### Visual Debug Overlay

Draw debug info directly on screen:

```lua
local function draw_debug_info(ctx, dl, x, y, info)
  local text = string.format("FPS: %.1f | Items: %d | Memory: %.1fKB",
    info.fps, info.item_count, collectgarbage("count"))

  -- Background
  local text_w, text_h = ImGui.CalcTextSize(ctx, text)
  ImGui.DrawList_AddRectFilled(dl, x, y, x + text_w + 10, y + text_h + 6, 0x000000CC)

  -- Text
  ImGui.DrawList_AddText(dl, x + 5, y + 3, 0xFFFFFFFF, text)
end
```

### Bounding Box Debug

Visualize widget bounds:

```lua
local DEBUG_BOUNDS = false  -- Toggle for debugging

local function draw_debug_bounds(dl, x1, y1, x2, y2, label)
  if not DEBUG_BOUNDS then return end

  -- Draw red outline
  ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, 0xFF0000FF, 0, 0, 1)

  -- Draw label
  if label then
    ImGui.DrawList_AddText(dl, x1, y1 - 14, 0xFF0000FF, label)
  end
end
```

---

## Stress Testing

### Scale Testing Pattern

Test with progressively larger datasets:

```lua
local TEST_SCALES = {10, 50, 100, 500, 1000, 5000, 10000}

for _, scale in ipairs(TEST_SCALES) do
  local items = generate_test_items(scale)

  local start = reaper.time_precise()
  render_items(items)
  local elapsed = reaper.time_precise() - start

  reaper.ShowConsoleMsg(string.format(
    "Items: %5d | Time: %7.2fms | Per-item: %.4fms\n",
    scale, elapsed * 1000, (elapsed * 1000) / scale))
end
```

### Virtual Mode Threshold

For Grid widgets, enable virtual mode when items exceed threshold:

```lua
Grid.new({
  -- Enable virtual mode for large datasets
  virtual = #items > 500,
  fixed_tile_h = 100,  -- Required for virtual mode
  -- ...
})
```

---

## Logging (ARKITEKT Logger)

### Using the Logger

```lua
local Logger = require('arkitekt.debug.logger')

-- Different log levels
Logger.trace("Detailed trace info")
Logger.debug("Debug message")
Logger.info("Informational message")
Logger.warn("Warning message")
Logger.error("Error message")

-- Formatted logging
Logger.debug("Processing item %d of %d", current, total)

-- Conditional logging
if Logger.is_level_enabled("trace") then
  Logger.trace("Expensive debug: %s", expensive_to_string(data))
end
```

---

## Checklist: Debugging a Slow Script

1. **Profile the main loop** - Is render time under 8ms?
2. **Check allocation in render** - Are you creating tables/objects every frame?
3. **Verify local caching** - Are frequently-used functions cached locally?
4. **Count draw calls** - Can you batch similar operations?
5. **Check item count** - Should you enable virtual mode?
6. **Profile REAPER API calls** - Are you polling when you could use state change count?
7. **Memory check** - Is memory growing over time?

---

## See Also

- [LUA_PERFORMANCE_GUIDE.md](../../cookbook/LUA_PERFORMANCE_GUIDE.md) - Optimization patterns
- [TODO/PERFORMANCE.md](../../TODO/PERFORMANCE.md) - Known performance tasks
- [WIDGETS.md](../../cookbook/WIDGETS.md) - Widget development patterns
