# Performance Optimization TODOs

Reference: [`Documentation/LUA_PERFORMANCE_GUIDE.md`](../Documentation/LUA_PERFORMANCE_GUIDE.md)

## Current Compliance: 7.5/10

The codebase shows good awareness in hot rendering paths but inconsistent application elsewhere.

---

## What's Already Good

- **Floor division `//1`**: 134 usages in rendering code
- **Local caching in renderers**: `renderer.lua`, `draw.lua`, `colors.lua` all cache `min`, `max`
- **ImGui function caching**: Hot paths cache `AddRectFilled`, `PushClipRect`, etc.
- **Documented optimizations**: Comments explain performance rationale

---

## Action Items

### 1. Replace `table.insert` with Direct Indexing

**Impact:** Function call overhead removal
**Effort:** Low (regex find-replace)
**Locations:** ~90 occurrences (excluding ThemeAdjuster/external)

```lua
-- Before
table.insert(tbl, value)

-- After
tbl[#tbl + 1] = value
```

**Files to update:**
- `scripts/TemplateBrowser/domain/*.lua` (~19 occurrences)
- `scripts/RegionPlaylist/storage/sws_importer.lua`
- `scripts/RegionPlaylist/domains/dependency.lua`
- `scripts/ItemPicker/data/*.lua`
- `arkitekt/reaper/region_operations.lua` (8 occurrences)

**Regex:** `table\.insert\((\w+),\s*(.+)\)` → `$1[#$1 + 1] = $2`

---

### 2. Replace Remaining `math.floor` with `//1`

**Impact:** ~5-10% CPU reduction in loops
**Effort:** Low
**Locations:** ~90 occurrences (excluding ThemeAdjuster)

**Priority files:**
- `arkitekt/core/colors.lua` (1 occurrence)
- `arkitekt/core/images.lua` (7 occurrences)
- `arkitekt/core/json.lua` (6 occurrences)
- `arkitekt/gui/draw/pattern.lua` (4 occurrences)
- `scripts/ItemPicker/services/visualization.lua` (3 occurrences)
- `scripts/ColorPalette/app/gui.lua` (5 occurrences)

**Pattern:**
```lua
-- Before
math.floor(x)

-- After
x // 1

-- Or for expressions
(x + 0.5) // 1
```

---

### 3. Add Local Caching Headers to Hot Files

**Impact:** 30% faster function calls in loops
**Effort:** Low

Files missing local caching that have loops:

```lua
-- Add to top of file:
local floor = math.floor  -- Or use //1 instead
local min, max = math.min, math.max
local abs = math.abs
```

**Files to update:**
- `scripts/RegionPlaylist/engine/playback.lua` - has loops, missing some caching
- `scripts/RegionPlaylist/engine/coordinator.lua` - orchestrates updates
- `scripts/ItemPicker/services/visualization.lua` - drawing code

---

### 4. Review `pairs()` in GUI Hot Paths

**Impact:** Marginal (iterator overhead)
**Effort:** Medium
**Locations:** 33 in `arkitekt/gui/`

Most `pairs()` usage is fine. Only review if:
- Called every frame
- Iterating over arrays (use numeric `for` instead)

**Low priority** - profile before optimizing.

---

### 5. String Concatenation in Loops

**Impact:** Quadratic → Linear time for large strings
**Effort:** Medium
**Current:** Only 34 `table.concat` usages

**Pattern to find:**
```lua
-- Problematic pattern in loops:
str = str .. something

-- Better:
local parts = {}
for ... do
  parts[#parts + 1] = something
end
local str = table.concat(parts)
```

**Files to audit:**
- `arkitekt/debug/logger.lua`
- `scripts/*/storage/persistence.lua`

---

## Already Optimized (No Action Needed)

These files are exemplary:

| File | Optimizations |
|------|---------------|
| `arkitekt/gui/rendering/tile/renderer.lua` | Local caching, `//1`, ImGui caching |
| `arkitekt/gui/draw.lua` | Local caching, `//1` snapping |
| `arkitekt/core/colors.lua` | Local caching, `//1` throughout |
| `arkitekt/gui/fx/animation/*.lua` | Local caching |

---

## Metrics to Track

| Pattern | Current | Target |
|---------|---------|--------|
| `math.floor` vs `//1` | 45%/55% | 10%/90% |
| `table.insert` vs `[#t+1]` | 77%/23% | 20%/80% |
| Local function caching | ~20 files | All hot-path files |

---

## Second Pass Findings (Additional Items)

### 6. Event Bus Sort on Every Subscribe

**Impact:** Low (only affects startup/init)
**Location:** `arkitekt/core/events.lua:60`

```lua
-- Current: Sorts entire listener array on each subscription
table.sort(self.listeners[event_name], function(a, b)
  return a.priority > b.priority
end)
```

**Recommendation:** Fine for now since subscriptions happen at init, not runtime.
Keep as-is unless profiling shows issues.

---

### 7. Timing Functions Using `math.floor/ceil`

**Impact:** Low (not in frame loops)
**Location:** `arkitekt/reaper/timing.lua`

Uses `math.floor`, `math.ceil` for quantization. These are called on user actions (transitions), not every frame. **No action needed.**

---

### 8. String ID Caching - Already Good!

**Location:** `arkitekt/gui/widgets/containers/grid/core.lua:164-166`

```lua
-- Cache string IDs for performance (avoid string concatenation every frame)
_cached_bg_id = "##grid_bg_" .. grid_id,
_cached_empty_id = "##grid_empty_" .. grid_id,
```

Excellent pattern. Consider applying to other widgets that generate IDs.

---

### 9. Virtual List Mode Available

**Location:** `arkitekt/gui/widgets/containers/grid/core.lua:168-170`

```lua
-- Virtual list mode for large datasets (1000+ items)
virtual = opts.virtual or false,
virtual_buffer_rows = opts.virtual_buffer_rows or 2,
```

Good to have this option. Enable for grids with 100+ items.

---

## REAPER-Specific Optimizations

### 10. Project State Change Detection - Good Pattern

**Locations:** Multiple files use `reaper.GetProjectStateChangeCount(0)`

This is the correct pattern for detecting project changes without polling every item. Already implemented correctly in:
- `arkitekt/reaper/project_monitor.lua`
- `scripts/ItemPicker/ui/main_window.lua`
- `scripts/RegionPlaylist/engine/engine_state.lua`

---

### 11. Consider: Cache REAPER API Lookups

**Impact:** Medium in heavy loops
**Current:** Direct calls to `reaper.*` in some loops

For functions called in tight loops, consider:
```lua
-- At module top
local GetPlayPosition = reaper.GetPlayPosition
local EnumProjectMarkers = reaper.EnumProjectMarkers

-- In loop
local pos = GetPlayPosition()  -- Instead of reaper.GetPlayPosition()
```

**Files to audit:**
- `scripts/RegionPlaylist/engine/core.lua`
- `arkitekt/reaper/regions.lua`

---

## Patterns to Avoid (Already Handled)

| Anti-Pattern | Status | Notes |
|--------------|--------|-------|
| `debug.*` in hot paths | ✅ OK | Only used at startup for path resolution |
| `collectgarbage()` in loops | ✅ OK | Only 2 usages, both in cleanup/shutdown |
| `loadstring` in loops | ✅ OK | Not found |
| `setmetatable` in loops | ✅ OK | Only at object creation |
| Dynamic `__index` functions | ✅ OK | Only 2 usages (init.lua, assembler_view.lua) |

---

## ImGui-Specific Optimizations

### Already Good:
- DrawList caching in renderers
- Cursor position caching where needed
- Clipping rect usage

### Consider:
- Batch similar draw calls (lines → polyline)
- Use `ImGui.IsItemVisible()` to skip hidden widget internals
- Pre-calculate style values outside render loops

---

## Performance Profiling Checklist

Before optimizing, profile with:

```lua
local start = reaper.time_precise()
-- ... code to measure ...
local elapsed = reaper.time_precise() - start
reaper.ShowConsoleMsg(string.format("Elapsed: %.4fms\n", elapsed * 1000))
```

Target metrics:
- **Idle CPU < 1%** = Fine
- **Idle CPU 1-5%** = Monitor
- **Idle CPU > 5%** = Investigate

---

## Notes

- **ThemeAdjuster excluded** - reference code, not ours
- **External libs excluded** - `talagan_ReaImGui Markdown`, etc.
- Profile with `reaper.time_precise()` before/after changes
- Don't optimize cold paths (startup, config loading)

---

## Summary: What Matters Most

1. **High Priority:** `table.insert` → `[#t+1]` (easy wins)
2. **Medium Priority:** Remaining `math.floor` → `//1`
3. **Low Priority:** Everything else - profile first

The hot rendering paths are already well-optimized. Focus on domain/storage layers only if profiling shows issues.
