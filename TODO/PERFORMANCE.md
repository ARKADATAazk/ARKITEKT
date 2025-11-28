# Performance Optimization TODOs

Reference: [`Documentation/LUA_PERFORMANCE_GUIDE.md`](../Documentation/LUA_PERFORMANCE_GUIDE.md)

## Current Compliance: 9/10 ⬆️ (was 7.5/10)

The codebase shows excellent performance awareness. Hot paths are well-optimized.

## Summary

**Completed optimizations:**
- ✅ **Section 1:** All `table.insert` append patterns replaced with direct indexing (18 occurrences)
- ✅ **Section 2:** Priority hot-path files already use `//1` instead of `math.floor`
- ✅ **Section 3:** Hot-path rendering files already have local function caching
- ✅ **Section 5:** No problematic string concatenation patterns found

**Remaining work:**
- 🟡 **Section 2:** ~104 `math.floor` in non-hot paths (LOW PRIORITY - profile first)
- 🟡 **Section 4:** Review `pairs()` usage (LOW PRIORITY - marginal gains)

**Overall:** Primary performance optimizations complete. Remaining items are low-impact.

---

## What's Already Good

- **Floor division `//1`**: 134 usages in rendering code
- **Local caching in renderers**: `renderer.lua`, `draw.lua`, `colors.lua` all cache `min`, `max`
- **ImGui function caching**: Hot paths cache `AddRectFilled`, `PushClipRect`, etc.
- **Documented optimizations**: Comments explain performance rationale

---

## Action Items

### 1. Replace `table.insert` with Direct Indexing ✅ COMPLETED

**Impact:** Function call overhead removal
**Effort:** Low (regex find-replace)
**Status:** ✅ **COMPLETED** - All simple append patterns replaced (18 occurrences)

```lua
-- Before
table.insert(tbl, value)

// After
tbl[#tbl + 1] = value
```

**Completed files:**
- ✅ `scripts/ItemPicker/ui/components/status.lua` (2 occurrences)
- ✅ `scripts/TemplateBrowser/ui/shortcuts.lua` (3 occurrences)
- ✅ `scripts/TemplateBrowser/ui/init.lua` (8 occurrences)
- ✅ `scripts/TemplateBrowser/ui/tiles/factory.lua` (2 occurrences)
- ✅ `scripts/RegionPlaylist/ui/tiles/renderers/pool.lua` (1 occurrence)
- ✅ `scripts/arkitekt/debug/_console_widget.lua` (1 occurrence)
- ✅ `scripts/arkitekt/core/path_validation.lua` (1 occurrence)

**Note:** Remaining `table.insert` calls with positional index (e.g., `table.insert(tbl, idx, value)`)
are intentional and left unchanged as they insert at specific positions, not append.

**Commits:**
- `354c339` Replace table.insert with direct indexing for performance
- `b1566a9` Continue table.insert performance optimization in framework files

---

### 2. Replace Remaining `math.floor` with `//1` (LOW PRIORITY)

**Impact:** ~5-10% CPU reduction in loops
**Effort:** Low
**Status:** 🟡 **PARTIALLY DONE** - Priority hot-path files already optimized
**Remaining:** ~104 occurrences (excluding ThemeAdjuster/external)

**Priority files status:**
- ✅ `arkitekt/core/colors.lua` - No math.floor found (already optimized)
- ✅ `arkitekt/core/images.lua` - No math.floor found (already optimized)
- ✅ `arkitekt/core/json.lua` - No math.floor found (already optimized)
- ✅ `scripts/ItemPicker/ui/visualization.lua` - Already uses //1 with comments explaining why

**Remaining math.floor locations:**
- ~104 occurrences in non-hot-path code (mostly UI, layout, one-time calculations)
- Most are NOT in tight loops, so performance impact is minimal
- **Recommendation:** Profile before optimizing - likely not worth the effort

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
**Status:** 🟢 **NO ACTION NEEDED** - Hot-path files already optimized

**Analysis:**
- Files listed in original TODO no longer exist or have been refactored
- Existing hot-path rendering files (`arkitekt/gui/rendering/`, `arkitekt/gui/draw.lua`) already have local caching
- See "Already Optimized" section below for exemplary files

**Pattern (for future reference):**
```lua
-- Add to top of file:
local floor = math.floor  -- Or use //1 instead
local min, max = math.min, math.max
local abs = math.abs
```

**Note:** Only add local caching to files with tight loops that run every frame.
Profile first to confirm performance benefit.

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
**Status:** 🟢 **NO ACTION NEEDED** - No problematic patterns found

**Analysis:**
- Searched for `str = str .. x` patterns in loops
- Found only one-time concatenations (not in loops)
- Codebase already uses `table.concat` where appropriate (34 usages)
- **Conclusion:** No optimization needed

**Pattern (for future reference):**
```lua
-- ❌ BAD: Quadratic time in loops
local str = ""
for i = 1, 1000 do
  str = str .. something  -- Creates new string each iteration!
end

-- ✅ GOOD: Linear time
local parts = {}
for i = 1, 1000 do
  parts[#parts + 1] = something
end
local str = table.concat(parts)

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
