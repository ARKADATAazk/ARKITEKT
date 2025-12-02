# Performance Sweep: Systemic Optimization

> **Status:** Not Started
> **Priority:** High
> **Estimated Savings:** 0.15-0.35ms per frame (~1-2% of 16.67ms budget)
> **Reference:** `cookbook/LUA_PERFORMANCE_GUIDE.md`

---

## Executive Summary

Codebase audit (2024-12) identified systemic performance pollution patterns that compound across the framework. This document tracks remediation.

**Total Identified Issues:**
- 1,302 `hexrgb()` string parsing calls
- 260 non-localized `math.*` calls
- 276 table allocations (need hot-path audit)
- 64 `pairs()` loops on arrays
- 51 string operations in potential hot paths

---

## Phase 1: hexrgb() → Bytes (Highest Impact)

**Estimated Savings:** 0.1-0.25ms/frame
**Tracked in:** `TODO/01_HIGH/REFACTOR_ColorsModule.md`

### Status
- [ ] Colors module refactor (Phase 1-4)
- [ ] Framework defs conversion (Phase 5a-5b)
- [ ] App constants conversion (Phase 5c)
- [ ] Widget cleanup (Phase 6)

---

## Phase 2: Localize math.* Functions

**Estimated Savings:** 0.02-0.05ms/frame
**Effort:** Low (mechanical grep + add)

### Pattern

```lua
-- Add at top of files with math.* in loops:
local floor, ceil, min, max, abs = math.floor, math.ceil, math.min, math.max, math.abs
```

### Files to Fix (65 files, 260 occurrences)

#### Critical (Hot Paths) 🔴
- [ ] `gui/widgets/effects/hatched_fill.lua` - 32 calls
- [ ] `gui/widgets/containers/grid/core.lua` - 22 calls
- [ ] `gui/widgets/containers/grid/layout.lua` - 11 calls
- [ ] `gui/widgets/containers/panel/header/tab_strip/rendering.lua` - 9 calls
- [ ] `gui/interaction/selection.lua` - 8 calls

#### High (Render Paths) 🟠
- [ ] `gui/widgets/text/colored_text_view.lua` - 7 calls
- [ ] `gui/widgets/primitives/combo.lua` - 7 calls
- [ ] `gui/widgets/overlays/batch_rename_modal.lua` - 7 calls
- [ ] `gui/widgets/containers/panel/header/tab_strip/animations.lua` - 8 calls
- [ ] `gui/animation/lifecycle.lua` - 6 calls
- [ ] `gui/widgets/media/package_tiles/grid.lua` - 6 calls
- [ ] `gui/widgets/data/selection_rectangle.lua` - 6 calls

#### Medium (UI Components) 🟡
- [ ] `gui/draw/patterns.lua` - 5 calls
- [ ] `gui/widgets/overlays/overlay/manager.lua` - 5 calls
- [ ] `gui/widgets/containers/panel/header/tab_strip.lua` - 5 calls
- [ ] `gui/widgets/primitives/scrollbar.lua` - 4 calls
- [ ] `gui/widgets/primitives/spinner.lua` - 4 calls
- [ ] `gui/interaction/marching_ants.lua` - 4 calls
- [ ] `gui/widgets/editors/nodal/systems/auto_layout.lua` - 4 calls
- [ ] `gui/widgets/editors/nodal/systems/bezier.lua` - 4 calls
- [ ] `gui/widgets/tools/color_picker_window.lua` - 4 calls
- [ ] All remaining files with 1-3 calls

### Verification
```bash
# Count remaining non-localized math.* calls
grep -r "math\.\(floor\|ceil\|min\|max\|abs\)" arkitekt/gui --include="*.lua" | wc -l
```

---

## Phase 3: pairs() → Numeric For (Arrays)

**Estimated Savings:** 0.01-0.03ms/frame
**Effort:** Low (case-by-case review)

### Pattern

```lua
-- Before (pairs on array)
for k, v in pairs(items) do
  process(v)
end

-- After (numeric for)
for i = 1, #items do
  process(items[i])
end
```

### Files to Audit (28 files, 64 occurrences)

Only convert when iterating sequential arrays. Keep `pairs()` for:
- Hash tables (string keys)
- Sparse arrays
- When order doesn't matter and keys are needed

#### Priority Files 🔴
- [ ] `gui/widgets/navigation/tree_view.lua` - 7 calls
- [ ] `gui/widgets/containers/sliding_zone.lua` - 6 calls
- [ ] `gui/animation/tracks.lua` - 4 calls
- [ ] `gui/widgets/containers/panel/header/tab_strip/rendering.lua` - 4 calls
- [ ] `gui/widgets/containers/tile_group/init.lua` - 3 calls
- [ ] `gui/widgets/primitives/combo.lua` - 3 calls
- [ ] `gui/interaction/selection.lua` - 3 calls
- [ ] `gui/widgets/containers/panel/coordinator.lua` - 3 calls

---

## Phase 4: Table Allocation Audit

**Estimated Savings:** Variable (depends on hot-path findings)
**Effort:** High (requires understanding each usage)

### Pattern

```lua
-- Before (allocates every frame)
function draw()
  local opts = { padding = 10, color = 0xFF0000FF }
  render(opts)
end

-- After (reuse or inline)
local opts = { padding = 10, color = 0xFF0000FF }
function draw()
  render(opts)
end
-- Or pass individual args instead of table
```

### Files to Audit (81 files, 276 occurrences)

Focus on files with `= {}` inside functions that are called per-frame.

#### Critical (Known Hot Paths) 🔴
- [ ] `gui/widgets/containers/grid/core.lua` - 23 allocations
- [ ] `gui/widgets/navigation/tree_view.lua` - 20 allocations
- [ ] `gui/widgets/media/package_tiles/renderer.lua` - 9 allocations
- [ ] `gui/widgets/containers/panel/header/layout.lua` - 9 allocations
- [ ] `gui/widgets/containers/panel/tab_animator.lua` - 8 allocations
- [ ] `gui/widgets/editors/nodal/canvas.lua` - 8 allocations

### Audit Criteria
1. Is `= {}` inside a function?
2. Is that function called per-frame (draw/render/update)?
3. Can the table be hoisted to module level?
4. Can the table be reused across frames?

---

## Phase 5: String Operations in Hot Paths

**Estimated Savings:** Minimal (mostly not in hot paths)
**Effort:** Low

### String Concatenation (26 occurrences)

Most are in initialization or rare paths. Audit for:
- [ ] Any `..` inside render loops
- [ ] Any `..` called 60+ times per second

### string.format() (25 occurrences)

Acceptable in:
- Debug output
- One-time formatting
- UI labels that don't change every frame

Problematic in:
- Per-tile rendering
- Per-frame status updates

---

## Verification & Testing

### Before Starting
```bash
# Baseline measurements (run in REAPER with ItemPicker open, 500+ items)
# Record: Idle CPU %, interaction responsiveness
```

### After Each Phase
```bash
# Re-measure and document improvement
```

### Regression Testing
- [ ] All apps launch without errors
- [ ] Theme switching works
- [ ] No visual glitches in widgets
- [ ] Performance improved (not regressed)

---

## Completion Checklist

- [ ] Phase 1: hexrgb → bytes (see REFACTOR_ColorsModule.md)
- [ ] Phase 2: Localize math.* in 65 files
- [ ] Phase 3: Audit pairs() in 28 files
- [ ] Phase 4: Audit table allocations in critical 6 files
- [ ] Phase 5: Verify no string ops in hot paths
- [ ] Final verification: Measure frame time improvement
- [ ] Update LUA_PERFORMANCE_GUIDE.md with final counts

---

## Notes

- Phase 1 (Colors) is the biggest win and should be done first
- Phases 2-3 are mechanical and can be done incrementally
- Phase 4 requires careful analysis and may not yield much improvement
- Always profile before and after to verify actual gains

---

**Last Updated:** 2024-12-02
**Next Action:** Complete Colors module refactor (Phase 1)
