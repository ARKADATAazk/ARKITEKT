# ARKITEKT-Toolkit Codebase Review

**Date:** November 27, 2025
**Reviewer:** Claude (Opus 4)
**Scope:** Full codebase analysis covering architecture, code quality, documentation, and technical debt

---

## Executive Summary

**Overall Assessment: GOOD with areas needing attention**

ARKITEKT is a well-engineered Lua/ReaImGui framework with ~430 Lua files and ~35,000+ lines of code. The framework core demonstrates excellent architecture and consistent patterns. However, there are notable gaps between documented ideals and implementation reality, particularly in layer purity and application structure consistency.

### Key Metrics

| Metric | Value | Assessment |
|--------|-------|------------|
| Framework Files | 154 Lua files | Comprehensive |
| Application Files | 251 Lua files across 8 apps | Mature ecosystem |
| Documentation | 70+ markdown files | Extensive |
| Test Coverage | 3 files (1 app only) | **Insufficient** |
| TODO/FIXME Comments | 49 occurrences | Normal |
| Layer Purity Violations | 19 reaper.* calls in core/ | **Needs attention** |

---

## Architecture Assessment

### What Works Well

**1. Framework Layer Structure** - The `arkitekt/` organization is logical and mostly well-separated:
- `core/` - Pure utilities (with caveats, see issues below)
- `platform/` - Minimal, focused abstractions (excellent)
- `app/` - Bootstrap and runtime orchestration
- `gui/` - 104 files of widgets, animation, rendering
- `defs/` - Centralized configuration

**2. Widget System** - The 70+ widgets are well-organized:
- Consistent API pattern (`M.draw(ctx, opts)`)
- Proper theme integration
- Good separation of concerns in complex widgets (Panel is 16 files but well-decomposed)

**3. Lazy-Loading Namespace** - The `Ark.*` system via metatable is elegant:
```lua
Ark.Button(ctx, 'Click')  -- Loads on first access
```

**4. Error Handling** - Good defensive programming with 69 pcall/xpcall usages across the framework.

**5. Platform Abstraction** - `platform/images.lua` is particularly well-done:
- Frame budgeting prevents UI stutter
- LRU cache with bounded memory
- Graceful fallback handling

### Significant Issues

**1. Layer Purity Violations in core/** - **CRITICAL**

The documentation explicitly states `core/` should be "100% pure - no reaper.* or ImGui.* calls". However, I found **19 reaper.* calls** across 6 core modules:

| File | Violations | Usage |
|------|------------|-------|
| `core/callbacks.lua` | 10 | `reaper.time_precise()`, `reaper.defer()` |
| `core/settings.lua` | 3 | `reaper.RecursiveCreateDirectory()`, `reaper.time_precise()` |
| `core/events.lua` | 1 | `reaper.time_precise()` |
| `core/shuffle.lua` | 1 | `reaper.time_precise()` |
| `core/uuid.lua` | 1 | `reaper.time_precise()` |
| `core/theme_manager/debug.lua` | 1 | `reaper.CF_SetClipboard` |

**Impact:** These modules aren't portable. If the documented rule is correct, these should either:
- Move timing functions to a platform/ module
- Or acknowledge core/ isn't truly pure

**2. Application Structure Inconsistency**

Documentation describes: `app/`, `domain/`, `data/`, `ui/`, `defs/`, `tests/`

Reality varies significantly:

| App | Matches? | Actual Structure |
|-----|----------|------------------|
| WalterBuilder | Mostly | app/, core/, domain/, defs/, ui/ |
| TemplateBrowser | Partial | core/, domain/, **infra/** (not data), ui/ |
| ItemPicker | No | core/, **services/**, data/, defs/, ui/ |
| RegionPlaylist | No | core/, **domains/**, **engine/**, **storage/**, ui/ |
| ThemeAdjuster | No | core/, **packages/**, defs/, ui/ |

**Impact:** New developers see conflicting patterns. The "ideal" architecture isn't being followed by ~50% of apps.

**3. MediaContainer Uses Outdated Bootstrap**

While 7/8 apps use the modern `dofile(loader.lua)` pattern, MediaContainer still uses manual `require('arkitekt')`:

```lua
-- MediaContainer (OLD pattern)
package.path = path .. "?.lua;" .. ...
ark = require('arkitekt')

-- vs Modern pattern
local ark = dofile(path .. "loader.lua")
```

---

## Code Quality Assessment

### Strengths

**Consistent Module Pattern** - Every file follows:
```lua
local M = {}
-- ... implementation
return M
```

**No Globals** - Verified across all apps.

**Good Naming Conventions** - Consistent use of:
- `snake_case` for files and functions
- `PascalCase` for modules
- `SCREAMING_SNAKE` for constants

**Performance-Conscious Code** - Evidence of optimization awareness:
- Localized math functions in hot paths
- Frame budgeting in image loading
- LRU caches

### Weaknesses

**Test Coverage is Nearly Non-Existent**

Only RegionPlaylist has tests (3 files). No other app has any test coverage. The framework itself has a test runner (`arkitekt/debug/test_runner.lua`) but it's barely used.

```
Total test files in entire codebase: 3
Total tested modules: 2-3 domains in RegionPlaylist
Expected test files for production apps: ~40-50 minimum
```

This is a significant technical debt.

**Large Monolithic Files**

Some files are oversized and could be split:
- `app/chrome/window.lua` - 32KB
- `app/chrome/titlebar.lua` - 25KB
- Several widget files >1000 lines

**ItemPicker core/app_state.lua Has Impure Call**

Line 372 contains `reaper.GetToggleCommandState()` in what's supposed to be a pure core module. Should move to app layer.

---

## Documentation Assessment

### What's Good

- **CLAUDE.md** is excellent - clear routing map, task cookbook, anti-patterns
- **cookbook/** guides are comprehensive and well-written
- **Performance guide** provides actionable optimization patterns
- **Widget development** docs are thorough

### Critical Problems

**1. MIGRATION_PLANS.md is Missing** - Referenced in multiple docs but doesn't exist:
- `docs/INDEX.md` line 42, 85
- `cookbook/PROJECT_STRUCTURE.md` line 629

**2. Documentation vs Reality Gap**

The documentation presents an ideal architecture that ~50% of scripts don't follow. There's no acknowledgment that the codebase is in transition. A new developer reading PROJECT_STRUCTURE.md then looking at RegionPlaylist will be confused.

**3. No @deprecated Markers**

DEPRECATED.md describes a deprecation pattern with `@deprecated` annotations, but **zero instances exist in the codebase**. The deprecation process isn't being followed.

**4. CONTRIBUTING.md is Minimal** (66 lines)

Missing:
- PR process
- Commit message format
- Code review expectations
- Testing requirements

### Developer Experience Issues

| Aspect | Rating | Issue |
|--------|--------|-------|
| Getting Started | 7/10 | Good but architecture reality vs docs causes confusion |
| Finding Code | 8/10 | File routing map helps |
| Understanding Patterns | 5/10 | Multiple conflicting patterns in apps |
| Testing | 3/10 | Unclear how to run tests, minimal examples |
| Contributing | 4/10 | Missing guidelines |

---

## Technical Debt Summary

### Critical (Should address soon)

1. **Layer purity violations in core/** - 19 reaper.* calls violate documented rules
2. **Missing MIGRATION_PLANS.md** - Referenced but doesn't exist
3. **Test coverage** - Only 3 test files in entire codebase

### High Priority

4. **MediaContainer bootstrap** - Uses outdated pattern
5. **ItemPicker core layer violation** - reaper.GetToggleCommandState in core/
6. **Documentation-reality gap** - Scripts don't match documented structure
7. **No @deprecated usage** - Documented pattern not followed

### Medium Priority

8. **Inconsistent app structures** - 5 different organizational patterns
9. **CONTRIBUTING.md incomplete** - Missing essential contributor info
10. **Large files could be split** - window.lua, titlebar.lua, etc.

### Low Priority

11. **TODO comments** - 49 scattered through codebase (normal, but should track)
12. **Performance micro-optimizations** - ~90 `table.insert()` could be direct indexing

---

## Recommendations

### Immediate Actions

1. **Fix or acknowledge core/ purity** - Either:
   - Move timing/defer functions to `platform/timing.lua`
   - Or update docs to say core/ can use certain reaper.* at runtime

2. **Create MIGRATION_PLANS.md** - Document which apps are in what state and migration plans

3. **Add layer purity tests** - Automated check that core/ has no reaper.* imports

### Short-Term (Next Release)

4. **Migrate MediaContainer to modern bootstrap**

5. **Add basic tests to 2-3 more apps** - WalterBuilder and TemplateBrowser as candidates

6. **Update CONTRIBUTING.md** with:
   - PR workflow
   - Testing expectations
   - Code review checklist

7. **Add "Architecture Reality" section to docs** acknowledging transition state

### Medium-Term

8. **Standardize app structure** - Pick one pattern and migrate remaining apps

9. **Implement @deprecated markers** - Use the documented pattern

10. **Split large files** - window.lua and titlebar.lua into smaller modules

---

## Honest Assessment

**The Good:**
ARKITEKT is genuinely well-architected at its core. The widget system is sophisticated, the lazy-loading namespace is elegant, and the framework clearly shows experienced Lua development. The documentation effort is substantial and mostly high-quality.

**The Concerning:**
There's a gap between documented ideals and implementation reality. The "pure core" isn't pure. The "standard app structure" isn't standard. The "deprecation process" isn't being used. This suggests either:
- Documentation was written aspirationally before implementation
- Or the codebase evolved and docs weren't updated

**The Honest Truth:**
This is a **good codebase in transition**. The architecture is sound, the patterns are sensible, and the code quality is consistently above average. But it needs:
- Honesty in documentation about current state vs goals
- Investment in test coverage (this is the biggest gap)
- Commitment to either enforcing or relaxing layer purity rules

The framework is production-ready for its target use case (REAPER ImGui apps), but a new contributor would struggle to understand which patterns to follow due to inconsistencies between apps.

---

## Final Verdict

| Category | Score | Notes |
|----------|-------|-------|
| Architecture | 8/10 | Solid design, some purity violations |
| Code Quality | 7/10 | Consistent patterns, good error handling |
| Test Coverage | 2/10 | Nearly non-existent |
| Documentation | 6/10 | Comprehensive but doesn't match reality |
| Developer Experience | 5/10 | Good framework, confusing apps |
| Technical Debt | Moderate | Several critical items, many medium |
| **Overall** | **6.5/10** | Good foundation, needs cleanup |

The codebase is better than average but has accumulated inconsistencies that should be addressed before significant new development.
