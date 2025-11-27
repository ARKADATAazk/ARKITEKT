# RegionPlaylist Refactoring Plan

> Migration plan for improving RegionPlaylist's state machine and event patterns.
> Based on code review findings.

## Overview

RegionPlaylist is the most complex ARKITEKT script (~14,000 lines, 49 files). The current architecture is solid but has two key areas for improvement:

1. **Implicit State Machine** - Playback state scattered across boolean flags
2. **Callback Explosion** - 40+ inline callbacks in gui.lua

## Current State Assessment

| Area | Score | Notes |
|------|-------|-------|
| Architecture | 8/10 | Clean layers, good separation |
| StateMachine | 5/10 | Implicit, scattered state |
| Event System | 6/10 | Works but doesn't scale |
| Code Quality | 7/10 | Some duplication, large functions |
| Performance | 8/10 | Good caching, localized functions |

## Migration Phases

| Phase | Description | Effort | Files Changed |
|-------|-------------|--------|---------------|
| 1 | Introduce StateMachine to engine | Medium | 4-6 |
| 2 | Migrate to Events pattern | Medium | 6-8 |
| 3 | Code cleanup (nitpicks) | Low | 8-12 |
| 4 | Structure migration (optional) | High | 40+ |

**Recommendation**: Complete Phases 1-3 first. Phase 4 (full structure migration per MIGRATION_PLANS.md) can wait until other scripts are migrated.

## Phase Files

- [PHASE_1_STATE_MACHINE.md](PHASE_1_STATE_MACHINE.md) - Introduce explicit playback state machine
- [PHASE_2_EVENTS.md](PHASE_2_EVENTS.md) - Migrate callbacks to event bus
- [NITPICKS.md](NITPICKS.md) - Small code quality improvements
- [PHASE_4_STRUCTURE.md](PHASE_4_STRUCTURE.md) - Full structure migration (defer)

## Quick Wins (Can Do Anytime)

These don't require the phased migration:

- [ ] Extract magic numbers to `defs/constants.lua`
- [ ] Remove empty callback functions
- [ ] Add helper for undo/redo status message building
- [ ] Standardize on `safe_call` across modules

## Dependencies

- `arkitekt/core/state_machine.lua` - **CREATED** ✓
- `arkitekt/core/events.lua` - Already exists ✓

## Success Criteria

After completing Phases 1-3:

1. Playback state is explicit and queryable (`fsm:is("playing")`)
2. State transitions are logged and debuggable
3. Callbacks are organized and can have multiple listeners
4. No magic numbers in engine code
5. Duplicate code extracted to helpers
