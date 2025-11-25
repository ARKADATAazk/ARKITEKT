# Performance Optimization TODOs

Reference: `lua_perf_guide.md`

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

## Notes

- **ThemeAdjuster excluded** - reference code, not ours
- **External libs excluded** - `talagan_ReaImGui Markdown`, etc.
- Profile with `reaper.time_precise()` before/after changes
- Don't optimize cold paths (startup, config loading)
