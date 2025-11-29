# API Matching Progress

> **Consolidated progress tracker for API migration roadmap**
>
> Replaces: CHECKLIST.md (detailed tasks) + PHASING.md (strategy)

---

## Phase 1: Simple Widgets ✅ **COMPLETE**

**Goal**: Make all simple widgets callable with hybrid params and clean API

**Completed**: All 6 core widgets
- ✅ Button, Checkbox, Slider, InputText, Combo, RadioButton
- ✅ Callable via `__call` metamethod
- ✅ Hybrid parameters (positional + opts)
- ✅ Result objects with `.value`
- ✅ Deprecated functions removed (`cleanup()`, `draw_at_cursor()`)
- ✅ `measure()` is local/internal

**Testing**: Manual testing pending (widgets work in DevKit)

**Next**: Phase 2 primitives or Grid/TreeView rework

---

## Phase 2: Other Primitives ✅ **COMPLETE**

**Goal**: Apply Phase 1 pattern to remaining primitive widgets

**Completed**: All 10 widgets now callable! ✅
- ✅ `badge.lua` - Callable (defaults to `M.text()`), keeps `M.icon()`, `M.clickable()`, `M.favorite()`
- ✅ `spinner.lua` - Callable, cleanup() removed
- ✅ `loading_spinner.lua` - Callable
- ✅ `progress_bar.lua` - Callable
- ✅ `hue_slider.lua` - Callable
- ✅ `scrollbar.lua` - Callable
- ✅ `splitter.lua` - Callable, cleanup() removed
- ✅ `corner_button.lua` - Callable, cleanup() removed
- ✅ `close_button.lua` - Callable
- ✅ `markdown_field.lua` - Callable

**Applied**:
- ✅ `__call` metamethod on all 10 widgets
- ✅ Removed deprecated `cleanup()` from Spinner, Splitter, CornerButton
- ✅ Kept specialized methods where appropriate (Badge has multiple variants)

**Note**: These widgets are mostly opts-only (no positional params needed), so hybrid param detection was not applicable.

---

## Phase 3: Complex Widgets (Grid/TreeView) ✅ **COMPLETE**

**Goal**: Apply callable pattern with hidden state to complex widgets

**Status**: Both widgets completed on `test/grid-api-matching` branch
- ✅ **Grid** - `Ark.Grid(ctx, opts)` with ID-keyed state
  - Branch: `test/grid-api-matching` (complete)
  - Callable pattern + hidden state ✅
  - Result object with selection/drag/reorder ✅
  - Deprecate `Grid.new()` with shim ✅
  - Registered in `arkitekt/init.lua` ✅
  - **Hybrid ID System** ✅ - Supports both PushID/PopID stack AND explicit `opts.id`

- ✅ **TreeView** - `Ark.Tree(ctx, opts)` with ID-keyed state
  - Branch: `test/grid-api-matching` (complete)
  - Callable pattern + hidden state ✅
  - Result object with selection/expanded/renamed ✅
  - Deprecate old API with shim ✅
  - Registered in `arkitekt/init.lua` ✅
  - **Hybrid ID System** ✅ - Supports both PushID/PopID stack AND explicit `opts.id`

**Testing**: Both widgets need manual testing in apps
**Next**: Phase 5 - Script migration (or Phase 4 Panel rework if desired)

**See**:
- `GRID_REWORK.md` for Grid spec
- `DECISION_20_HYBRID_ID_SYSTEM.md` for ID system details

**New Features**:
- ✅ `Ark.PushID(ctx, id)` - Push ID onto stack (ImGui-compatible)
- ✅ `Ark.PopID(ctx)` - Pop ID from stack (ImGui-compatible)
- ✅ All widgets support hybrid ID: explicit `opts.id` OR stack-based OR auto from label
- ✅ `arkitekt/core/id_stack.lua` - ID stack implementation
- ✅ `Base.resolve_id(ctx, opts, default)` - Updated to support stack resolution

---

## Phase 4: Containers ⏳ **NOT STARTED**

**Goal**: Evaluate if callable pattern applies to container widgets

**Status**: Waiting for Phase 1-3 complete
- [ ] Panel - Complex, Begin/End pattern, may not fit
- [ ] SlidingZone - Evaluate
- [ ] TileGroup - Evaluate

**Note**: Containers may keep current API if callable doesn't make sense

---

## Phase 5: Script Migration ⏳ **NOT STARTED**

**Goal**: Update all apps to use new widget APIs

**Status**: Waiting for Phase 1-4 complete

**Strategy**: Parallelize per-app (each app is independent)

Apps to migrate:
- [ ] RegionPlaylist
- [ ] ItemPicker
- [ ] ThemeAdjuster
- [ ] TemplateBrowser
- [ ] Sandbox

**Per app**:
1. Replace `Ark.*.draw(` with `Ark.*(`
2. Replace `Grid.new()` with `Ark.Grid()`
3. Update result field access (`.text` → `.value`)
4. Test all functionality

---

## Phase 6: Documentation ⏳ **NOT STARTED**

**Goal**: Update all documentation to reflect new API

**Status**: Waiting for Phase 5 complete

- [ ] Update CLAUDE.md examples
- [ ] Update cookbook/QUICKSTART.md
- [ ] Update cookbook/WIDGETS.md
- [ ] Update API_DESIGN_PHILOSOPHY.md
- [x] Consolidate CHECKLIST + PHASING → PROGRESS.md

---

## Phase 7: Final Cleanup ⏳ **NOT STARTED**

**Goal**: Remove deprecated code, final audit

**Status**: Waiting for all apps migrated

- [ ] Remove backward compatibility shims (if any)
- [ ] Final audit of exposed functions
- [ ] Performance test (table allocation overhead)
- [ ] Grep for old patterns to ensure complete migration

---

## Notes

### Widgets That May Not Need Callable
Some widgets use Begin/End pattern and may not benefit from callable:
- Panel (uses Begin/End internally?)
- Containers in general

Evaluate case by case.

### Backward Compatibility Period
During migration, all three patterns work:
```lua
Ark.Button(ctx, "OK")                     -- New (callable)
Ark.Button.draw(ctx, {label="OK"})        -- Old (still works)
Ark.Button.draw_at_cursor(ctx, {...})     -- Deprecated (shim wrapper)
```

**Deprecated shims added**:
- `draw_at_cursor()` - Wrapper around `draw()` (cursor positioning is default)
- `cleanup()` - No-op (cleanup is automatic via Base.cleanup_registry)

These shims exist in all Phase 1 & 2 widgets to prevent breaking existing scripts.
Remove shims in Phase 7 after all scripts migrated.
