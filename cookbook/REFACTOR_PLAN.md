# Refactoring Guide

> Systematic approach to refactoring ARKITEKT code safely.

---

## Philosophy

**Refactor incrementally, test constantly, respect diff budget.**

Refactoring is not rewriting. It's improving internal structure while preserving external behavior.

### When to Refactor

| Trigger | Action |
|---------|--------|
| File > 700 LOC | Split into modules |
| Code duplicated in 3+ places | Extract to shared module |
| ImGui in `domain/*` | Move to UI layer |
| God object (50+ functions) | Split into focused services |
| Deep nesting (4+ levels) | Flatten structure |
| Unclear responsibilities | Reorganize by layer |

### When NOT to Refactor

- During feature development (refactor first OR after, not during)
- Without reading the code first
- Without tests or manual verification plan
- When you can't articulate what's wrong

---

## Diff Budget Constraints

**Always respect these limits:**

| Scope | Max Files | Max LOC Changed |
|-------|-----------|-----------------|
| Scripts | 12 | 700 |
| Framework `core/*` | 6 | 300 |

**If refactor exceeds budget:**
1. Split into multiple phases
2. Use feature branches
3. Coordinate breaking changes

---

## Refactor Types

### Type A: Cross-Cutting Changes
Namespace changes, API migrations, module relocations.

**Characteristics:**
- Touches many files
- Low conceptual complexity
- High coordination cost

**Strategy:** Shim pattern + incremental migration

---

### Type B: Architectural Refactors
Extracting logic, fixing layer boundaries, splitting god objects.

**Characteristics:**
- Fewer files, deeper changes
- High conceptual complexity
- Clear before/after structure

**Strategy:** Branch + surgical changes

---

### Type C: Code Quality Refactors
Breaking large files, removing duplication, flattening nesting.

**Characteristics:**
- Usually single-file or small scope
- Low risk
- Immediate improvement

**Strategy:** Direct refactor on main

---

### Type D: Deprecation-Driven Refactors
Removing old APIs, cleaning up shims.

**Characteristics:**
- Coordinated removal
- Preceded by deprecation period
- Known call sites

**Strategy:** Grep + update + remove

---

## Pre-Refactor Checklist

Before touching any code:

- [ ] **Read all affected files** - Understand current implementation
- [ ] **Identify dependencies** - What depends on what
- [ ] **Check diff budget** - Will this fit? If not, how to split?
- [ ] **Baseline tests** - Run existing tests, or plan manual verification
- [ ] **Create branch** - For large refactors (`git checkout -b refactor/description`)
- [ ] **Document scope** - What changes, what stays the same

---

## Execution Strategies

### Strategy 1: Incremental Migration (Strangler Fig)

Use for: Type A (cross-cutting), Type D (deprecation)

**Pattern:**

**Phase 1: Add New (No Breaking Changes)**
```lua
-- New API
function M.new_function(opts)
  -- implementation
end

-- Old API (shim)
-- @deprecated TEMP_PARITY_SHIM: old_function() → use new_function()
-- EXPIRES: [date] (planned removal: after migration complete)
function M.old_function(arg1, arg2)
  return M.new_function({param1 = arg1, param2 = arg2})
end
```

**Phase 2: Migrate Call Sites**
Update callers incrementally:
- Commit after each file or small batch
- Run tests after each commit
- Track progress (grep for old function)

**Phase 3: Remove Old**
When grep returns no results:
- Remove shim
- Update DEPRECATED.md
- Commit with "Remove deprecated X"

**Benefits:**
- Zero downtime
- Easy to rollback
- Low risk

**Drawbacks:**
- Longer timeline
- Temporary code duplication

---

### Strategy 2: Surgical Refactor

Use for: Type B (architectural), Type C (code quality)

**Pattern:**

1. **Read everything** - Entire file + dependencies
2. **One change at a time** - Extract one function/module
3. **Test immediately** - After each change
4. **Commit frequently** - Small, focused commits
5. **Respect boundaries** - Only files in scope

**Example Flow:**
```
1. Extract domain logic → commit → test
2. Update UI to use new domain → commit → test
3. Remove old code → commit → test
4. Update tests → commit
```

**Benefits:**
- Clear history
- Easy to bisect if issues
- Incremental progress

**Drawbacks:**
- Requires discipline
- Can be slow for large refactors

---

### Strategy 3: Branch Refactor

Use for: Large Type B (architectural) that exceeds diff budget

**Pattern:**

1. **Create feature branch** - `git checkout -b refactor/description`
2. **Make all changes** - Complete the refactor
3. **Test thoroughly** - Integration tests, manual testing
4. **Review diff** - Check for unintended changes
5. **Merge to main** - When confident

**Benefits:**
- Can work freely
- Test whole refactor before merge
- Easier to abandon if needed

**Drawbacks:**
- Merge conflicts if main changes
- All-or-nothing merge
- Harder to bisect issues

---

## Shim Pattern (TEMP_PARITY_SHIM)

For API migrations and deprecations.

### When to Use

- Changing function signatures
- Renaming functions/modules
- Relocating modules
- API redesigns

### Pattern

```lua
-- @deprecated TEMP_PARITY_SHIM: old_api() → use new_module.new_api()
-- EXPIRES: 2025-12-31 (planned removal: after all scripts migrated)
-- reason: API redesign for consistency
function M.old_api(arg1, arg2, arg3)
  -- Translate old API to new
  return NewModule.new_api({
    param1 = arg1,
    param2 = arg2,
    enabled = arg3,
  })
end
```

### Shim Checklist

- [ ] Add `@deprecated` annotation
- [ ] Include TEMP_PARITY_SHIM marker
- [ ] Set EXPIRES date
- [ ] Document reason
- [ ] Point to replacement
- [ ] Add to DEPRECATED.md

### Removing Shims

Before removal:
```bash
# Find all usages
grep -r "old_api" scripts/
grep -r "old_api" arkitekt/

# Should return only the shim itself
```

After confirming no usages:
- Remove shim
- Update DEPRECATED.md (move to "Completed")
- Commit: "Remove deprecated old_api (expired [date])"

---

## Refactoring Checklist

### Planning Phase

- [ ] Scope defined (files, changes, boundaries)
- [ ] Dependencies mapped
- [ ] Diff budget checked (fits? split needed?)
- [ ] Tests identified (existing or manual plan)
- [ ] Branch created (if needed)
- [ ] Backup/commit current state

### Execution Phase

**For Each Change:**
- [ ] Read code before editing
- [ ] Make surgical change
- [ ] Run tests
- [ ] Commit with clear message
- [ ] Check diff budget remaining

**After All Changes:**
- [ ] Full test pass
- [ ] Manual verification
- [ ] Review diff for unintended changes
- [ ] Check CLAUDE.md references still valid

### Cleanup Phase

- [ ] Old code deprecated (if not removed)
- [ ] DEPRECATED.md updated
- [ ] TODO entries created (if follow-up needed)
- [ ] Documentation updated
- [ ] Merge branch (if used)

---

## Common Patterns

### Pattern: Extract Domain Logic from UI

**Before:** UI file with business logic mixed in

**Steps:**
1. Create `domain/[concept]/service.lua`
2. Move business logic to service
3. Update UI to call service
4. Test
5. Remove old code from UI

**Constraints:**
- No ImGui in domain layer
- Service should be testable independently

---

### Pattern: Split God Object

**Before:** `app/state.lua` with 50+ functions

**Steps:**
1. Identify cohesive groups (playlist ops, region ops, etc.)
2. Create service modules for each group
3. Inject services into state container
4. Update callers: `State.do_thing()` → `State.services.thing:do()`
5. Remove functions from state (keep container only)

**Result:** Thin state container, focused services

---

### Pattern: Migrate API Signature

**Before:** `function Button(ctx, label, w, h, enabled)`

**After:** `function Button.draw(ctx, opts)`

**Steps:**
1. Add new signature
2. Add shim for old signature
3. Migrate call sites incrementally
4. Remove shim when done

---

### Pattern: Relocate Module

**Before:** `arkitekt/app/runtime/shell.lua`

**After:** `arkitekt/app/shell.lua`

**Steps:**
1. Copy file to new location
2. Add shim at old location:
```lua
-- @deprecated TEMP_PARITY_SHIM: Relocated to arkitekt.app.shell
-- EXPIRES: 2025-12-31
return require('arkitekt.app.shell')
```
3. Update direct requires incrementally
4. Remove old file when no direct requires remain

---

### Pattern: Flatten Deep Nesting

**Before:**
```
ui/views/transport/transport_view.lua
ui/views/transport/transport_buttons.lua
```

**After:**
```
ui/views/transport/init.lua
ui/views/transport/buttons.lua
```

Or if small:
```
ui/views/transport.lua
```

**Steps:**
1. Rename files (remove redundant prefixes)
2. Update requires
3. Test
4. Consider consolidating if files are small

---

## Diff Management

### Staying Within Budget

**Techniques:**
1. **Split into phases** - Do 10 files, commit, then next 10
2. **Use branches** - Separate phases in different branches
3. **Extract first** - Extract to new file, then update callers separately
4. **Deprecate gradually** - Keep old code longer if needed

### Tracking Progress

```bash
# Count files changed
git diff --name-only main | wc -l

# Count lines changed
git diff --stat main

# List changed files
git diff --name-only main
```

---

## Testing During Refactor

### No Automated Tests

**Manual verification plan:**
- List key behaviors to verify
- Test before refactor (baseline)
- Test after each phase
- Test edge cases

### With Automated Tests

**Process:**
1. Run tests before (should pass)
2. Make change
3. Run tests after (should still pass)
4. If tests fail: fix code or update tests (if behavior intentionally changed)

### Smoke Testing

Minimal verification:
- Script loads without errors
- Main workflow works
- No console errors

---

## Anti-Patterns

### Don't Do These

**Mixing concerns:**
- ❌ Refactor + feature in same commit
- ❌ Refactor + reformatting in same commit
- ❌ Fixing bugs during refactor

**Skipping steps:**
- ❌ Not reading code before editing
- ❌ Skipping tests "because it's just a refactor"
- ❌ Not checking diff budget

**Breaking things:**
- ❌ Removing old API immediately (deprecate first)
- ❌ Changing behavior during refactor
- ❌ Touching unrelated files "while you're here"

**Poor organization:**
- ❌ Giant commits with no message
- ❌ Mixing multiple refactor patterns in one batch
- ❌ No branch for large changes

---

## Quick Reference Card

### Before Starting

1. Read all affected code
2. Map dependencies
3. Check diff budget
4. Create branch if needed
5. Baseline tests

### During Refactor

1. One change at a time
2. Test after each change
3. Commit frequently
4. Track progress
5. Stay in scope

### After Finishing

1. Full test pass
2. Review diff
3. Update docs
4. Update DEPRECATED.md
5. Merge branch

### For API Changes

1. Add new API
2. Add shim for old
3. Migrate incrementally
4. Remove shim when done
5. Document in DEPRECATED.md

---

## See Also

- [CONVENTIONS.md](./CONVENTIONS.md) - Target code patterns
- [ARCHITECTURE.md](./ARCHITECTURE.md) - Target architecture
- [MODULARISATION.md](./MODULARISATION.md) - When to extract
- [DEPRECATED.md](./DEPRECATED.md) - Deprecation tracking
- [CLAUDE.md](../CLAUDE.md) - Edit discipline rules
