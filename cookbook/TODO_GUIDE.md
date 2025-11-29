# TODO Guide

> How to create, organize, and maintain TODO tasks in ARKITEKT.

---

## Philosophy

**TODO files are living specs, not just task lists.**

A good TODO file:
- Captures the **why** (problem, motivation)
- Defines the **what** (scope, requirements)
- Guides the **how** (approach, phases)
- Tracks **decisions** (choices made, alternatives considered)

---

## Priority Levels

| Priority | When to Use | Examples |
|----------|-------------|----------|
| **HIGH** | Blocking issues, critical features, high-value improvements | Security fixes, broken features, major refactors |
| **MEDIUM** | Important but not urgent, quality improvements | Performance optimizations, code cleanup, UX improvements |
| **LOW** | Nice to have, future enhancements, polish | Nitpicks, minor optimizations, experimental features |

**Guideline:** If unsure, start with MEDIUM. Adjust based on impact and urgency.

---

## Folder Structure

Organize by **priority** (folder), then **category** (prefix):

```
TODO/
├── README.md              # Master index
├── HIGH/                  # Critical, blocking
│   ├── REFACTOR_ThemeAdjuster.md
│   ├── FEATURE_APIMatching/
│   └── BUG_MemoryLeak.md
├── MEDIUM/                # Important but not urgent
│   ├── PERF_ImageCache.md
│   └── CLEANUP_ImGuiRefs.md
├── LOW/                   # Nice to have
│   └── DOCS_Examples.md
└── DONE/                  # Completed (archived)
    ├── 2024-11/
    └── 2024-12/
```

---

## Naming Convention

Since priority is in the folder, files are named:

```
[CATEGORY]_[ShortDescription].md
```

### Examples

```
HIGH/REFACTOR_ThemeAdjuster.md
MEDIUM/FEATURE_BatchProcessor.md
MEDIUM/PERF_ImGuiOptimization.md
LOW/CLEANUP_ImGuiCentralization.md
HIGH/BUG_MemoryLeak.md
```

### Categories

| Category | Description | Examples |
|----------|-------------|----------|
| **REFACTOR** | Restructure existing code | Layer fixes, module splits, API changes |
| **FEATURE** | New functionality | New widgets, new tools, new capabilities |
| **CLEANUP** | Code quality | Remove duplication, fix naming, organize files |
| **PERF** | Performance optimization | Cache improvements, render optimizations |
| **DOCS** | Documentation tasks | Guides, API docs, examples |
| **BUG** | Bug fixes | Crashes, incorrect behavior |
| **RESEARCH** | Investigation, exploration | Spike tasks, proof of concepts |

---

## File Structure

### Simple TODO (Single File)

For straightforward tasks:

```markdown
# [Category]: Short Description

> One-line summary of what this task accomplishes.

**Progress:** ⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜ 0% (0/10 tasks)

**Status:** Not Started
**Started:** (date when work begins)
**Completed:** (date when finished)

---

## Problem

Why this task exists. What's broken, missing, or could be better?

## Checklist

- [ ] **Phase 1: Planning**
  - [ ] Define scope
  - [ ] Document current state
- [ ] **Phase 2: Implementation**
  - [ ] Task 1
  - [ ] Task 2
  - [ ] Task 3
- [ ] **Phase 3: Verification**
  - [ ] Tests pass
  - [ ] Documentation updated

## Approach

How to tackle this:
1. Step 1
2. Step 2
3. Step 3

## Acceptance Criteria

Done when:
- [ ] Criterion 1
- [ ] Criterion 2
- All checklist items completed

## Notes

- Additional context
- Links to related issues
- References
```

### Progress Tracking

**Progress Bar:** Use checkbox emoji for visual tracking
```
⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜ 0%   (0/10)
■■⬜⬜⬜⬜⬜⬜⬜⬜ 20%  (2/10)
■■■■■⬜⬜⬜⬜⬜ 50%  (5/10)
■■■■■■■■■■ 100% (10/10)
```

**Update progress as you complete checklist items.** Each ■ = 10%.

---

### Complex TODO (Subfolder)

When a TODO has **3+ related documents**, create a subfolder:

```
HIGH_FEATURE_APIMatching/
├── README.md          # Overview, status, links to other files
├── DECISIONS.md       # Decision log
├── PHASING.md         # Implementation phases
├── SCOPE.md           # What's in/out of scope
├── IMPLEMENTATION.md  # Technical implementation details
└── EXAMPLES.md        # Code examples, before/after
```

### When to Create Subfolder

Create a subfolder when the TODO has:
- ✅ **3+ separate concerns** (decisions, phases, implementation)
- ✅ **Complex scope** requiring detailed planning
- ✅ **Multiple decision points** to track
- ✅ **Phased implementation** over time
- ✅ **Examples/references** that clutter main file

**Don't create subfolder when:**
- ❌ Simple task with clear steps
- ❌ Can fit in one well-organized file
- ❌ No decisions to track

---

## Subfolder File Templates

### README.md (Subfolder Entry Point)

```markdown
# [Priority] [Category]: Task Name

> One-line summary

## Status

- **Priority:** HIGH/MEDIUM/LOW
- **Started:** YYYY-MM-DD
- **Status:** Not Started / In Progress / Blocked / Completed
- **Owner:** (if applicable)

## Quick Links

- [Scope](SCOPE.md) - What's in/out
- [Decisions](DECISIONS.md) - Choices made
- [Phasing](PHASING.md) - Implementation plan
- [Implementation](IMPLEMENTATION.md) - Technical details

## Overview

Brief description of the task, why it matters, and what it accomplishes.

## Current Blockers

- Blocker 1
- Blocker 2

(Remove this section if none)
```

---

### SCOPE.md (What's Included/Excluded)

```markdown
# Scope

## In Scope

What this task **will** address:
- Item 1
- Item 2

## Out of Scope

What this task **will NOT** address:
- Item 1 (why: reason)
- Item 2 (why: reason)

## Success Criteria

Done when:
- [ ] Criterion 1
- [ ] Criterion 2
```

---

### DECISIONS.md (Decision Log)

```markdown
# Decision Log

Track all significant decisions made during planning/implementation.

## Decision 1: [Short Title]

**Date:** YYYY-MM-DD
**Status:** Decided / Pending / Revisit

**Context:**
Why this decision was needed.

**Options Considered:**
1. Option A - Pros/cons
2. Option B - Pros/cons
3. Option C - Pros/cons

**Decision:**
Chose option X because [reasoning].

**Consequences:**
- Positive: ...
- Negative: ...

---

## Decision 2: [Next Decision]
...
```

---

### PHASING.md (Implementation Phases)

```markdown
# Implementation Phases

Break work into incremental, testable phases.

## Phase 1: [Name]

**Goal:** What this phase accomplishes

**Tasks:**
- [ ] Task 1
- [ ] Task 2

**Success Criteria:**
- [ ] Can do X
- [ ] Tests pass

**Estimated Effort:** Small / Medium / Large

---

## Phase 2: [Name]
...

---

## Phase 3: [Name]
...

## Rollout Plan

How to deploy/enable the changes:
1. Step 1
2. Step 2
```

---

### IMPLEMENTATION.md (Technical Details)

```markdown
# Implementation Details

## Architecture Changes

What parts of the codebase are affected:
- `arkitekt/core/` - Changes here
- `arkitekt/gui/` - Changes there

## API Changes

### New APIs
\`\`\`lua
function M.new_api(opts)
  -- description
end
\`\`\`

### Deprecated APIs
- `old_api()` → use `new_api()` (deprecated: YYYY-MM-DD)

## File Changes

| File | Change Type | Description |
|------|-------------|-------------|
| `path/to/file.lua` | Modified | What changed |
| `path/to/new.lua` | New | What it does |

## Testing Strategy

How to verify this works:
- Unit tests for ...
- Integration tests for ...
- Manual testing: ...

## Migration Path

If breaking changes, how to migrate:
1. Step 1
2. Step 2
```

---

## Creating a New TODO

### Process

1. **Identify the need** - What problem are you solving?
2. **Choose priority** - HIGH / MEDIUM / LOW
3. **Choose category** - REFACTOR / FEATURE / etc.
4. **Name the file** - `[PRIORITY]_[CATEGORY]_[Description].md`
5. **Start with template** - Use simple or complex structure
6. **Collaborate with AI** - Use the workflow below

---

### AI Collaboration Workflow

When working with Claude to create a TODO:

**Step 1: Problem Definition**
```
You: "I want to refactor ThemeAdjuster to follow our architecture"
Claude: Asks clarifying questions about scope, current issues, goals
```

**Step 2: Scope Discussion**
```
Claude: Helps define what's in/out of scope
You: Make decisions together, Claude documents in SCOPE.md
```

**Step 3: Decision Points**
```
Claude: Identifies decision points (e.g., "How to handle backward compatibility?")
You: Discuss options
Claude: Documents in DECISIONS.md with reasoning
```

**Step 4: Phasing**
```
Claude: Proposes implementation phases
You: Adjust based on priorities
Claude: Documents in PHASING.md
```

**Step 5: Technical Design**
```
Claude: Designs implementation approach
You: Review and approve
Claude: Documents in IMPLEMENTATION.md
```

**Step 6: Create README**
```
Claude: Creates README.md tying everything together
```

---

### Questions to Ask Claude

When defining a TODO, ask Claude to help with:

1. **"What's the scope of this task?"**
   - Forces clear boundaries
   - Identifies what's in/out

2. **"What decisions do we need to make?"**
   - Surfaces choice points early
   - Prevents rework

3. **"How should we phase this?"**
   - Ensures incremental progress
   - Identifies dependencies

4. **"What are the risks?"**
   - Anticipates problems
   - Plans mitigation

5. **"What's the success criteria?"**
   - Defines "done"
   - Enables verification

6. **"How does this fit with existing architecture?"**
   - Ensures consistency
   - Identifies conflicts

---

## TODO Lifecycle

### States

| State | Meaning | Visual |
|-------|---------|--------|
| **Not Started** | Defined but not begun | Progress: ⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜ 0% |
| **In Progress** | Actively working | Progress: ■■■⬜⬜⬜⬜⬜⬜⬜ 30% |
| **Blocked** | Waiting on something | Status: Blocked (document why) |
| **Completed** | Finished | Progress: ■■■■■■■■■■ 100% |
| **Cancelled** | No longer needed | Move to DONE/ with reason |

### Completion Process

When a TODO is 100% done:

1. **Mark all checkboxes** ✅
2. **Update progress bar** to 100% (■■■■■■■■■■)
3. **Update status fields:**
   ```markdown
   **Status:** Completed
   **Completed:** 2024-11-29
   ```
4. **Move to DONE folder:**
   ```
   HIGH/REFACTOR_ThemeAdjuster.md
   → DONE/2024-11/REFACTOR_ThemeAdjuster.md
   ```
5. **Update TODO/README.md** - Remove from active list
6. **Commit:**
   ```bash
   git add TODO/
   git commit -m "Complete: REFACTOR ThemeAdjuster"
   ```

### Archive Structure

```
DONE/
├── 2024-11/
│   ├── REFACTOR_ThemeManager.md
│   ├── FEATURE_Settings.md
│   └── CLEANUP_ImGuiRefs.md
├── 2024-12/
│   └── PERF_ImageCache.md
└── 2025-01/
```

**Archiving preserves:**
- What was done
- Why it was done
- How it was approached
- Decisions made
- Git history linkage

---

## Organization

### Folder Structure

```
TODO/
├── README.md                    # Master index of all TODOs
│
├── HIGH/                        # Critical priority
│   ├── REFACTOR_ThemeAdjuster.md
│   ├── FEATURE_APIMatching/     # Complex with subfolder
│   │   ├── README.md
│   │   ├── SCOPE.md
│   │   ├── DECISIONS.md
│   │   └── PHASING.md
│   └── BUG_MemoryLeak.md
│
├── MEDIUM/                      # Important but not urgent
│   ├── PERF_ImageCache.md
│   ├── CLEANUP_ImGuiRefs.md
│   └── FEATURE_BatchProcessor.md
│
├── LOW/                         # Nice to have
│   ├── CLEANUP_Nitpicks.md
│   ├── DOCS_Examples.md
│   └── RESEARCH_ImGuiPatterns.md
│
└── DONE/                        # Completed tasks (by month)
    ├── 2024-11/
    │   ├── REFACTOR_ThemeManager.md
    │   └── FEATURE_Settings.md
    └── 2024-12/
        └── PERF_Caching.md
```

### README.md Structure

```markdown
# TODO Tracker

Active tasks for ARKITEKT. See [cookbook/TODO_GUIDE.md](../cookbook/TODO_GUIDE.md) for process.

## High Priority

| Task | Category | Progress | Status |
|------|----------|----------|--------|
| [ThemeAdjuster](HIGH/REFACTOR_ThemeAdjuster.md) | Refactor | ■■■⬜⬜⬜⬜⬜⬜⬜ 30% | In Progress |
| [APIMatching](HIGH/FEATURE_APIMatching/) | Feature | ■■■■■■■⬜⬜⬜ 70% | In Progress |

## Medium Priority

| Task | Category | Progress | Status |
|------|----------|----------|--------|
| [BatchProcessor](MEDIUM/FEATURE_BatchProcessor.md) | Feature | ⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜ 0% | Not Started |
| [ImageCache](MEDIUM/PERF_ImageCache.md) | Performance | ■■⬜⬜⬜⬜⬜⬜⬜⬜ 20% | In Progress |

## Low Priority

| Task | Category | Progress | Status |
|------|----------|----------|--------|
| [Nitpicks](LOW/CLEANUP_Nitpicks.md) | Cleanup | ⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜ 0% | Not Started |

## Recently Completed

See [DONE/](DONE/) for archived tasks.

Last completed:
- 2024-11-28: REFACTOR_ThemeManager
- 2024-11-25: FEATURE_Settings

## Process

1. Pick a task from HIGH → MEDIUM → LOW
2. Update progress bar as you complete checklist items
3. Update status in file and README
4. Move to DONE/YYYY-MM/ when 100%
```

---

## Naming Subfolders

Subfolders can be:

**Named like files:** `HIGH_FEATURE_APIMatching/`
**Grouped by theme:** `scriptRefacto/`, `widgets/`, `core/`

**Guidelines:**
- Use file-style naming for **individual complex tasks**
- Use theme names for **grouping related simple tasks**

---

## Examples

### Simple TODO Example

`MEDIUM_PERF_ImageCaching.md`:

```markdown
# MEDIUM PERF: Image Caching Optimization

> Reduce memory usage and improve performance of image cache.

## Problem

Current image cache doesn't limit memory, causing performance issues with 100+ images.

## Requirements

- [ ] Add configurable memory budget
- [ ] Implement LRU eviction
- [ ] Add cache hit/miss metrics

## Approach

1. Add `max_memory` option to Images.new()
2. Track memory usage per image
3. Evict least-recently-used when over budget
4. Add debug overlay for cache stats

## Acceptance Criteria

- [ ] Memory usage stays under budget
- [ ] No visual glitches from eviction
- [ ] Performance improves with large image sets
- [ ] Tests pass

## Notes

- See LUA_PERFORMANCE_GUIDE.md for patterns
- Related to TODO/PERFORMANCE.md
```

---

### Complex TODO Example

`HIGH_FEATURE_APIMatching/` structure:

**README.md** - Overview and links
**SCOPE.md** - Match ImGui API 1:1 for 80% of widgets
**DECISIONS.md** - 19 logged decisions about opts vs positional params
**PHASING.md** - Phase 1: Research, Phase 2: Core widgets, Phase 3: Complex widgets
**IMPLEMENTATION.md** - Technical approach for each widget category

---

## Anti-Patterns

**Don't:**
- ❌ Create TODO without clear problem statement
- ❌ Mix multiple unrelated tasks in one file
- ❌ Start work without defining scope
- ❌ Skip decision documentation
- ❌ Create subfolder for simple 1-file task
- ❌ Use vague names like "Improvements.md"
- ❌ Forget to update status

**Do:**
- ✅ Clearly define problem and value
- ✅ Scope before implementation
- ✅ Document decisions and reasoning
- ✅ Break into phases
- ✅ Use clear, descriptive names
- ✅ Keep README.md index updated

---

## Quick Reference

### Folder Structure
```
TODO/
├── HIGH/         # Critical
├── MEDIUM/       # Important
├── LOW/          # Nice to have
└── DONE/         # Archive by month
    └── YYYY-MM/
```

### File Naming
```
[CATEGORY]_[Description].md

REFACTOR_ThemeAdjuster.md
FEATURE_BatchProcessor.md
CLEANUP_Formatting.md
```

### Categories
**REFACTOR** | **FEATURE** | **CLEANUP** | **PERF** | **DOCS** | **BUG** | **RESEARCH**

### Progress Tracking
```markdown
**Progress:** ■■■⬜⬜⬜⬜⬜⬜⬜ 30% (3/10)
**Status:** Not Started | In Progress | Blocked | Completed
**Started:** YYYY-MM-DD
**Completed:** YYYY-MM-DD
```

### Subfolder Trigger
Create subfolder when TODO has:
- 3+ documents needed
- Complex scope
- Multiple decisions
- Phased implementation

### Required Files in Subfolder
- README.md (always)
- SCOPE.md (if complex scope)
- DECISIONS.md (if multiple decisions)
- PHASING.md (if multi-phase)
- IMPLEMENTATION.md (if technical complexity)

### Completion Process
1. Mark all checkboxes ✅
2. Update progress to 100%
3. Add completion date
4. Move to `DONE/YYYY-MM/`
5. Update README.md

---

## See Also

- [REFACTOR_PLAN.md](./REFACTOR_PLAN.md) - How to execute refactors
- [ARCHITECTURE.md](./ARCHITECTURE.md) - Target architecture
- [CONVENTIONS.md](./CONVENTIONS.md) - Code standards
- [TODO/README.md](../TODO/README.md) - Active task list
