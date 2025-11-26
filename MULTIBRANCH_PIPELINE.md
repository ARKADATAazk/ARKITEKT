# Multibranch Pipeline Strategy

**Purpose**: Execute multiple TODO items in parallel across 4-5 branches while avoiding merge conflicts.

**Strategy**: Group tasks by file overlap and dependency to minimize conflicts.

---

## Branch Overview

| Branch | Focus Area | Risk Level | Estimated Files | Can Merge After |
|--------|-----------|------------|-----------------|-----------------|
| **Branch 1** | Performance: Simple Replacements | LOW | ~50 files | Any branch |
| **Branch 2** | Performance: Local Caching | LOW-MED | ~15 files | Any branch |
| **Branch 3** | Theme System Enhancements | LOW | ~3 files | Any branch |
| **Branch 4** | Namespace & Cleanup | MEDIUM | ~30 files | Branch 1, 2 |
| **Branch 5** | GUI Reorganization | HIGH | ~60 files | ALL other branches |

---

## Branch 1: Performance - Simple Replacements

**Branch name**: `feature/perf-simple-replacements`

**Source TODO**: `TODO/PERFORMANCE.md` (items 1-2)

**Tasks**:
1. Replace `table.insert(tbl, value)` → `tbl[#tbl + 1] = value` (~90 occurrences)
2. Replace `math.floor(x)` → `x // 1` (~90 occurrences)

**File areas**:
- `scripts/TemplateBrowser/domain/*.lua`
- `scripts/RegionPlaylist/storage/sws_importer.lua`
- `scripts/RegionPlaylist/domains/dependency.lua`
- `scripts/ItemPicker/data/*.lua`
- `arkitekt/reaper/region_operations.lua`
- `arkitekt/core/colors.lua`
- `arkitekt/core/images.lua`
- `arkitekt/core/json.lua`
- `arkitekt/gui/draw/pattern.lua`
- `scripts/ItemPicker/services/visualization.lua`
- `scripts/ColorPalette/app/gui.lua`

**Conflict potential**: VERY LOW (pattern-based replacements, minimal logic changes)

**Dependencies**: None

**Can be merged**: Independently, or first to reduce merge conflicts for others

---

## Branch 2: Performance - Local Caching

**Branch name**: `feature/perf-local-caching`

**Source TODO**: `TODO/PERFORMANCE.md` (items 3, 11)

**Tasks**:
1. Add local caching headers for math functions (`min`, `max`, `abs`, etc.)
2. Cache REAPER API lookups in hot loops

**File areas**:
- `scripts/RegionPlaylist/engine/playback.lua`
- `scripts/RegionPlaylist/engine/coordinator.lua`
- `scripts/ItemPicker/services/visualization.lua`
- `scripts/RegionPlaylist/engine/core.lua`
- `arkitekt/reaper/regions.lua`
- Any other hot-path files identified during analysis

**Conflict potential**: LOW-MEDIUM (adds lines at top of files, modifies loop internals)

**Dependencies**: None (but benefits from Branch 1 being merged first)

**Can be merged**: Independently after Branch 1

---

## Branch 3: Theme System Enhancements

**Branch name**: `feature/theme-debugging-validation`

**Source TODO**: `TODO/theme-debug-overlay.md`, `TODO/theme-validation.md`

**Tasks**:
1. Add theme debug overlay (F12 toggle, visual debugging)
2. Add theme validation (runtime checks for preset consistency)
3. Auto-validate in dev mode

**File areas**:
- `arkitekt/core/theme_manager/init.lua`
- `arkitekt/gui/app.lua` (or equivalent main render loop)

**Conflict potential**: VERY LOW (isolated to theme system)

**Dependencies**: None

**Can be merged**: Independently at any time

---

## Branch 4: Namespace & Cleanup

**Branch name**: `feature/namespace-cleanup`

**Source TODO**: `TODO/additionnalnotes.md`

**Tasks**:
1. Add ImGui Loader to centralize package initialization
2. Use `ark.` namespace everywhere in scripts (replace direct requires)
3. Replace `0x4D` type opacity controllers with opacity utility

**File areas**:
- Create new: `arkitekt/loaders/imgui_loader.lua` (or similar)
- All scripts: `scripts/*/main.lua` (package initialization)
- All files using `0x4D` opacity pattern (need to grep for this)
- Multiple files across `scripts/` and `arkitekt/gui/`

**Conflict potential**: MEDIUM (touches many script entry points and opacity usage)

**Dependencies**:
- Should wait for Branch 1 to merge (to avoid conflicts in same files)
- Can run parallel to Branch 2, 3

**Can be merged**: After Branch 1

---

## Branch 5: GUI Reorganization

**Branch name**: `feature/gui-reorganization`

**Source TODO**: `TODO/GUI_REORGANIZATION.md`

**Tasks**:
1. Create new directory structure (`draw/`, `animation/`, `interaction/`, `layout/`, `renderers/`)
2. Move ~25 files to new locations
3. Merge duplicate drag_drop files
4. Update ALL require paths across entire codebase
5. Delete empty folders

**File areas**:
- **Direct changes**: All of `arkitekt/gui/` (~25 files moved/renamed)
- **Indirect changes**: Every file that requires a gui module (~60+ files)

**Conflict potential**: VERY HIGH (massive file moves + require path changes everywhere)

**Dependencies**:
- **MUST wait for ALL other branches to merge first**
- Any file that touches `arkitekt/gui/` or requires gui modules will conflict

**Can be merged**: LAST, after all other branches are integrated

---

## Execution Strategy

### Phase 1: Parallel Development (Branches 1-4)

**Start simultaneously**:
- Branch 1: Performance - Simple Replacements
- Branch 2: Performance - Local Caching
- Branch 3: Theme System Enhancements
- Branch 4: Namespace & Cleanup (can start but don't merge until after Branch 1)

**Merge order**:
1. Branch 3 (safest, completely isolated)
2. Branch 1 (foundational, helps others)
3. Branch 2 (builds on Branch 1 changes)
4. Branch 4 (wait for 1 & 2 to avoid conflicts)

### Phase 2: GUI Reorganization (Branch 5)

**Start**: After Phase 1 is 75%+ complete (to minimize moving target)

**Merge**: ONLY after all Phase 1 branches are merged to main

---

## Conflict Avoidance Rules

### Rule 1: File Ownership
Each branch "owns" specific files during development:
- **Branch 1**: Domain/storage/data files (for table.insert/math.floor)
- **Branch 2**: Engine/playback files (for local caching)
- **Branch 3**: Theme manager files
- **Branch 4**: Script entry points and opacity files
- **Branch 5**: All GUI files (DO NOT touch until Phase 2)

### Rule 2: Communication Protocol
Before starting work:
1. Check which files your branch will modify
2. Check if any other branch is touching those files
3. If overlap exists, coordinate merge order

### Rule 3: Rebase Strategy
- Branch 1, 2, 3: Can develop independently
- Branch 4: Rebase on Branch 1 before final merge
- Branch 5: Rebase on main AFTER all others merge

---

## File Overlap Analysis

### No Overlap (Safe to parallel):
- Branch 1 + Branch 3: ✅ Zero file overlap
- Branch 2 + Branch 3: ✅ Zero file overlap

### Minimal Overlap (Coordinate merges):
- Branch 1 + Branch 2: `scripts/ItemPicker/services/visualization.lua` (both touch it)
  - **Solution**: Merge Branch 1 first, Branch 2 rebases
- Branch 1 + Branch 4: Script files (different patterns)
  - **Solution**: Merge Branch 1 first

### High Overlap (Sequential only):
- ANY branch + Branch 5: 60+ files touched by GUI reorg
  - **Solution**: Branch 5 goes LAST

---

## Testing Checkpoints

After each branch merge:
1. Run all scripts to ensure no require path breaks
2. Check console for Lua errors
3. Test one script from each category (RegionPlaylist, ItemPicker, TemplateBrowser)
4. Verify theme system still works (for Branch 3)

---

## Rollback Plan

If conflicts become unmanageable:

**Option A: Pause & Merge**
- Pause conflicting branch
- Merge completed branches
- Rebase conflicting branch on updated main
- Continue development

**Option B: Squash & Simplify**
- If Branch 5 conflicts are too complex, break it into sub-branches:
  - 5a: Move files only (no require updates)
  - 5b: Update require paths in one script category at a time
  - 5c: Update require paths in arkitekt core

---

## Success Metrics

- [ ] All 5 branches successfully merged
- [ ] Zero runtime errors in any script
- [ ] Performance improvements measurable (Branch 1 & 2)
- [ ] Theme debug tools functional (Branch 3)
- [ ] ark. namespace used consistently (Branch 4)
- [ ] GUI structure reorganized (Branch 5)

---

## Notes

- **Exclude from all branches**: `ThemeAdjuster/` (external reference code)
- **Regex testing**: Test all find/replace patterns on sample files first
- **Commit frequently**: Small commits make conflict resolution easier
- **Document assumptions**: Note any "TODO: verify after merge" items

---

## Quick Reference: Which branch am I on?

Run: `git branch --show-current`

Match to:
- `feature/perf-simple-replacements` = Branch 1
- `feature/perf-local-caching` = Branch 2
- `feature/theme-debugging-validation` = Branch 3
- `feature/namespace-cleanup` = Branch 4
- `feature/gui-reorganization` = Branch 5
