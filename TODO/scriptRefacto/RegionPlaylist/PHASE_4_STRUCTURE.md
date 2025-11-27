# Phase 4: Full Structure Migration (Deferred)

> Complete folder restructuring per MIGRATION_PLANS.md
> **Status**: Deferred until other scripts are migrated

## Overview

This phase aligns RegionPlaylist with the canonical ARKITEKT structure. It's deferred because:

1. RegionPlaylist is the most complex script (47 files)
2. Phases 1-3 provide immediate value without restructuring
3. TemplateBrowser should be migrated first as reference implementation
4. Lessons from other migrations will inform this one

## Related Documentation

- [cookbook/SCRIPT_LAYERS.md](../../../../cookbook/SCRIPT_LAYERS.md) - Platform layer architecture
- [cookbook/TESTING.md](../../../../cookbook/TESTING.md) - Testing patterns
- [cookbook/MIGRATION_PLANS.md](../../../../cookbook/MIGRATION_PLANS.md) - Full migration guide

## Target Structure

See [cookbook/MIGRATION_PLANS.md](../../../../cookbook/MIGRATION_PLANS.md#regionplaylist-migration) for the complete target structure.

## Summary of Changes

| Current | Target | Files Affected |
|---------|--------|----------------|
| `core/` | `app/` + distribute | 5 |
| `domains/` | `domain/` + `ui/state/` | 6 |
| `engine/` | Keep `engine/` | 0 (no change) |
| `storage/` | `infra/` | 3 |

## Key Decisions

### 1. UI State Domains → ui/state/

These are UI concerns, not business logic:
- `domains/animation.lua` → `ui/state/animation.lua`
- `domains/notification.lua` → `ui/state/notification.lua`
- `domains/ui_preferences.lua` → `ui/state/preferences.lua`

### 2. Engine → Keep as `engine/`

**Why not split into `domain/` + `platform/`?**

The engine is a **playback orchestration layer** - it naturally uses `reaper.*` for transport control, timing, and playback. This is fine because:

1. All ARKITEKT code runs inside REAPER - there's no "outside" environment to test in
2. Forcing purity adds complexity without real benefit
3. `engine/` is like `app/` - an orchestration layer that coordinates things
4. Scripts don't need `platform/` layers (see [cookbook/SCRIPT_LAYERS.md](../../../../cookbook/SCRIPT_LAYERS.md))

**Keep engine/ as-is:**
- `engine/core.lua` - Playback coordinator
- `engine/engine_state.lua` - Sequence and position state
- `engine/transport.lua` - Transport control
- `engine/transitions.lua` - Transition handling
- `engine/quantize.lua` - Quantization logic
- `engine/playback.lua` - Playback loop

The `engine/` folder is **script-specific** - it makes sense for RegionPlaylist's playback needs, just like other scripts might have their own specialized folders.

### 3. coordinator_bridge → infra/

The bridge is infrastructure (wires domain to REAPER):
- `engine/coordinator_bridge.lua` → `infra/bridge.lua`

### 4. Storage → infra/

Already correctly isolated:
- `storage/persistence.lua` → `infra/storage.lua`
- `storage/sws_importer.lua` → `infra/sws_import.lua`
- `storage/undo_bridge.lua` → `infra/undo.lua`

## Prerequisites

Before starting Phase 4:

- [ ] Phase 1 complete (StateMachine)
- [ ] Phase 2 complete (Events)
- [ ] Phase 3 complete (Nitpicks)
- [ ] TemplateBrowser migration complete
- [ ] ItemPicker migration complete
- [ ] ThemeAdjuster migration complete

## Estimated Effort

| Task | Files | Effort |
|------|-------|--------|
| Create new folders | - | Low |
| Move files | 42 | Medium |
| Update requires | 47 | Medium |
| Add backward-compat shims | 20 | Low |
| Update tests | 3 | Low |
| Remove shims | 20 | Low |

**Total**: ~2-3 focused sessions

## Migration Strategy

Follow the phased approach from MIGRATION_PLANS.md:

1. **Create new folders** (don't move anything yet)
2. **Add shims** in old locations that re-export from new
3. **Move files one at a time**, update shims
4. **Update all requires** to use new paths
5. **Test thoroughly**
6. **Remove shims** and delete empty folders

## File Migration Table

See [cookbook/MIGRATION_PLANS.md](../../../../cookbook/MIGRATION_PLANS.md#file-migration-table-3) for the complete file migration table.
