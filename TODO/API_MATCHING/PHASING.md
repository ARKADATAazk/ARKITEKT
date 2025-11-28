# API Matching: Phasing & Parallel Work Guide

> **Master plan for implementing the new ARKITEKT API**

---

## Decision Summary (16 Total)

| # | Decision | Status |
|---|----------|--------|
| 1 | Two Namespaces (`Ark.*` + `ImGui.*`) | Decided |
| 2 | Callable Modules (no `.draw()`) | Decided |
| 3 | Hybrid Parameters (positional + opts) | Decided |
| 4 | Result Objects (not just booleans) | Decided |
| 5 | Hide Internal Functions | Decided |
| 6 | Strong Tables + 30s Cleanup | Decided |
| 7 | Callbacks Are Optional | Decided |
| 8 | Keep Icons Simple (UTF-8 + font) | Decided |
| 9 | `.value` Everywhere (standardized) | Decided |
| 10 | Simple Alignment (`align = "center"`) | Decided |
| 11 | Match ImGui Cursor Advance | Decided |
| 12 | No Animation Toggle | Decided |
| 13 | Clear Error Messages | Decided |
| 14 | Ark + ImGui Interop Rules | Decided |
| 15 | Presets Only (no raw colors in docs) | Decided |
| 16 | Hidden State for Complex Widgets | Decided |

---

## Work Streams

### Stream A: Simple Widgets (Can Parallelize)

Each widget is independent. Can be done in parallel branches.

| Widget | File | Complexity | Parallelizable |
|--------|------|------------|----------------|
| Button | `primitives/button.lua` | Low | ✅ Yes |
| Checkbox | `primitives/checkbox.lua` | Low | ✅ Yes |
| Slider | `primitives/slider.lua` | Low | ✅ Yes |
| InputText | `primitives/inputtext.lua` | Medium | ✅ Yes |
| Combo | `primitives/combo.lua` | Medium | ✅ Yes |
| RadioButton | `primitives/radio_button.lua` | Low | ✅ Yes |

**Work per widget:**
1. Add `__call` metamethod
2. Add hybrid parameter detection
3. Standardize result object (`.value`)
4. Hide internal functions
5. Add error messages

### Stream B: Complex Widgets (Sequential)

These have dependencies and shared patterns.

| Widget | File | Depends On |
|--------|------|------------|
| Grid | `containers/grid/` | Base patterns from Stream A |
| TreeView | `navigation/tree_view.lua` | Grid patterns |
| Table (future) | TBD | Grid patterns |

### Stream C: App Migration (After Widgets)

Migrate apps to new API. Can parallelize per-app.

| App | Depends On | Parallelizable |
|-----|------------|----------------|
| RegionPlaylist | Stream A + B | ✅ Yes (after widgets) |
| ItemPicker | Stream A + B | ✅ Yes (after widgets) |
| ThemeAdjuster | Stream A | ✅ Yes (after widgets) |
| Sandbox | Stream A | ✅ Yes (after widgets) |

### Stream D: Documentation (Parallel with C)

| Doc | Depends On |
|-----|------------|
| QUICKSTART.md | Stream A examples |
| WIDGETS.md | Stream A + B |
| CLAUDE.md | All streams |
| Migration Guide | Stream A + B |

---

## Phase Breakdown

### Phase 0: Foundation (DO FIRST - Sequential)

**Purpose:** Establish patterns before parallelizing.

```
Duration: 1 session
Parallelizable: NO (establishes patterns)
```

| Task | Description |
|------|-------------|
| 0.1 | Implement Button with all new patterns (reference implementation) |
| 0.2 | Test hybrid params, result object, error messages |
| 0.3 | Document the pattern in IMPLEMENTATION.md |
| 0.4 | Create test file for validation |

**Output:** `button.lua` as reference for all other widgets.

---

### Phase 1: Simple Widgets (PARALLEL OK)

**Purpose:** Apply pattern to all simple widgets.

```
Duration: 1-2 sessions (faster if parallel)
Parallelizable: YES - each widget is independent
```

**Branch Strategy:**
```
Branch A: claude/api-button-checkbox-XXXXX
  - Button (reference)
  - Checkbox

Branch B: claude/api-slider-input-XXXXX
  - Slider
  - InputText

Branch C: claude/api-combo-radio-XXXXX
  - Combo
  - RadioButton
```

| Widget | Changes Required |
|--------|------------------|
| Button | `__call`, hybrid params, result object, hide internals |
| Checkbox | Same + ensure `.value` (not `.checked`) |
| Slider | Same + unify SliderInt/SliderFloat |
| InputText | Same + change `.text` → `.value` |
| Combo | Same + `.value` for index, `.item` for text |
| RadioButton | Same |

**Merge:** All branches merge to main after testing.

---

### Phase 2: Grid Rework (SEQUENTIAL)

**Purpose:** Apply hidden state pattern to Grid.

```
Duration: 2-3 sessions
Parallelizable: NO (complex, needs careful design)
Depends On: Phase 1 complete (patterns established)
```

| Task | Description |
|------|-------------|
| 2.1 | Add `Ark.Grid(ctx, opts)` API parallel to `Grid.new()` |
| 2.2 | Implement ID-keyed state storage |
| 2.3 | Implement result object with selection/drag/reorder |
| 2.4 | Add debug warnings for ID collisions |
| 2.5 | Keep `Grid.new()` as deprecated shim |

**See:** `TODO/API_MATCHING/GRID_REWORK.md` for full spec.

---

### Phase 3: App Migration (PARALLEL OK)

**Purpose:** Update all apps to new API.

```
Duration: 2-3 sessions (faster if parallel)
Parallelizable: YES - each app is independent
Depends On: Phase 1 + Phase 2 complete
```

**Branch Strategy:**
```
Branch A: claude/migrate-regionplaylist-XXXXX
  - Update RegionPlaylist
  - Test all features

Branch B: claude/migrate-itempicker-XXXXX
  - Update ItemPicker
  - Test all features

Branch C: claude/migrate-themeadjuster-XXXXX
  - Update ThemeAdjuster
  - Test all features
```

| App | Widgets Used | Grid Used |
|-----|--------------|-----------|
| RegionPlaylist | All | Yes (pool + active) |
| ItemPicker | Button, Checkbox, InputText | Yes |
| ThemeAdjuster | Button, Slider, Checkbox | No |
| Sandbox | Various | Maybe |

**Migration per app:**
1. Find all `Ark.*.draw(` calls → replace with `Ark.*(`
2. Update opts-only to positional where simpler
3. Update result field access (`.text` → `.value`)
4. Test all functionality
5. Remove old `.draw` calls

---

### Phase 4: TreeView & Other Complex (SEQUENTIAL)

**Purpose:** Apply Grid patterns to other complex widgets.

```
Duration: 1-2 sessions
Parallelizable: NO (builds on Grid patterns)
Depends On: Phase 2 complete
```

| Widget | Changes |
|--------|---------|
| TreeView | Migrate to `Ark.Tree(ctx, opts)` pattern |
| (Others TBD) | As needed |

---

### Phase 5: Documentation (PARALLEL with Phase 3+)

**Purpose:** Update all docs to reflect new API.

```
Duration: 1 session
Parallelizable: YES - can run alongside app migration
```

| Doc | Updates |
|-----|---------|
| `QUICKSTART.md` | All examples use new API |
| `WIDGETS.md` | Updated signatures, result objects |
| `CLAUDE.md` | Updated quick reference |
| `API_DESIGN_PHILOSOPHY.md` | Add decision rationale |
| New: `MIGRATION.md` | "Coming from ImGui" guide |

---

### Phase 6: Cleanup (SEQUENTIAL - Last)

**Purpose:** Remove deprecated code, final audit.

```
Duration: 1 session
Parallelizable: NO (final cleanup)
Depends On: All phases complete
```

| Task | Description |
|------|-------------|
| 6.1 | Remove `.draw()` methods (breaking change) |
| 6.2 | Remove `Grid.new()` shim |
| 6.3 | Hide remaining internal functions |
| 6.4 | Performance audit (table allocations) |
| 6.5 | Final grep for old patterns |

---

## Parallel Execution Map

```
Timeline:   ─────────────────────────────────────────────────────►

Phase 0:    [Foundation - Button Reference]
            ════════════════
                            │
Phase 1:                    ├─► [Branch A: Button+Checkbox]
(PARALLEL)                  ├─► [Branch B: Slider+Input]
                            └─► [Branch C: Combo+Radio]
                                        │
                                        ▼ (merge)
Phase 2:                    [Grid Rework - Sequential]
                            ════════════════════════════
                                        │
Phase 3:                                ├─► [Branch A: RegionPlaylist]
(PARALLEL)                              ├─► [Branch B: ItemPicker]
                                        └─► [Branch C: ThemeAdjuster]
                                                    │
Phase 4:                    [TreeView - Sequential] │
                            ════════════════════    │
                                        │           │
Phase 5:                                └───────────┼─► [Docs - Parallel OK]
(PARALLEL)                                          │
                                                    ▼ (merge all)
Phase 6:                    [Cleanup - Sequential - LAST]
                            ══════════════════════════════
```

---

## Branch Naming Convention

```
claude/<phase>-<scope>-<session_id>

Examples:
claude/api-button-reference-XXXXX      # Phase 0
claude/api-slider-input-XXXXX          # Phase 1
claude/grid-rework-XXXXX               # Phase 2
claude/migrate-regionplaylist-XXXXX    # Phase 3
claude/docs-update-XXXXX               # Phase 5
```

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Merge conflicts in shared files | Phase 0 establishes patterns before parallel work |
| Grid patterns not established | Phase 2 is sequential, fully documented |
| Apps break during migration | Keep old API working (shims) during transition |
| Missing test coverage | Each phase includes testing task |

---

## Quick Start for Parallel Branches

### For Widget Work (Phase 1)

```markdown
Task: Implement new API for [Widget Name]

Files to modify:
- arkitekt/gui/widgets/primitives/[widget].lua

Changes:
1. Add __call metamethod (see button.lua reference)
2. Add hybrid parameter detection
3. Standardize result object (.value)
4. Hide internal functions (make local)
5. Add error messages for invalid input

Test:
- Positional: Ark.[Widget](ctx, ...)
- Opts: Ark.[Widget](ctx, {...})
- Old .draw() still works
```

### For App Migration (Phase 3)

```markdown
Task: Migrate [App Name] to new API

Files to modify:
- scripts/[AppName]/**/*.lua

Changes:
1. Replace Ark.*.draw( with Ark.*(
2. Update result field access (.text → .value)
3. Simplify opts-only to positional where appropriate
4. Test all app functionality

Grep patterns:
- Find: Ark\.\w+\.draw\(
- Find: \.text\b (for InputText)
```

---

## Completion Criteria

| Phase | Done When |
|-------|-----------|
| 0 | Button works with all new patterns, documented |
| 1 | All simple widgets callable, tested |
| 2 | `Ark.Grid(ctx, opts)` works, Grid.new deprecated |
| 3 | All apps use new API, no `.draw()` calls |
| 4 | TreeView uses new pattern |
| 5 | All docs updated, migration guide complete |
| 6 | Old APIs removed, clean audit |

---

## Files Quick Reference

| Purpose | Location |
|---------|----------|
| Decision rationale | `TODO/API_MATCHING/DECISIONS.md` |
| Widget signatures | `TODO/API_MATCHING/WIDGET_SIGNATURES.md` |
| Implementation guide | `TODO/API_MATCHING/IMPLEMENTATION.md` |
| Progress checklist | `TODO/API_MATCHING/CHECKLIST.md` |
| Grid rework spec | `TODO/API_MATCHING/GRID_REWORK.md` |
| Guardrails philosophy | `TODO/API_MATCHING/GUARDRAILS.md` |
| This phasing guide | `TODO/API_MATCHING/PHASING.md` |
