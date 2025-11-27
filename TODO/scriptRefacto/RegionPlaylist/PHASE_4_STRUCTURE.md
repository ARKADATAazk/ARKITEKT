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
| `engine/` | `domain/playback/` | 7 |
| `storage/` | `data/` | 3 |

## Key Decisions

### 1. UI State Domains → ui/state/

These are UI concerns, not business logic:
- `domains/animation.lua` → `ui/state/animation.lua`
- `domains/notification.lua` → `ui/state/notification.lua`
- `domains/ui_preferences.lua` → `ui/state/preferences.lua`

### 2. Engine → domain/playback/

The "engine" is actually **playback domain logic** - it's the core business logic of RegionPlaylist. Renaming clarifies this:

**RegionPlaylist has three domains:**
1. `domain/playlist/` - Playlist data structures
2. `domain/region/` - Region data
3. `domain/playback/` - How playlists play (was `engine/`)

**Migration:**
- `engine/core.lua` → `domain/playback/controller.lua`
- `engine/engine_state.lua` → `domain/playback/state.lua`
- `engine/transport.lua` → `domain/playback/transport.lua`
- `engine/transitions.lua` → `domain/playback/transitions.lua`
- `engine/quantize.lua` → `domain/playback/quantize.lua`
- `engine/playback.lua` → `domain/playback/loop.lua`

**Note:** `domain/playback/` can use `reaper.*` - we don't enforce strict purity in scripts (see [cookbook/SCRIPT_LAYERS.md](../../../../cookbook/SCRIPT_LAYERS.md)).

### 3. coordinator_bridge → data/

The bridge is infrastructure (wires domain to REAPER):
- `engine/coordinator_bridge.lua` → `data/bridge.lua`

### 4. Storage → data/

Already correctly isolated:
- `storage/persistence.lua` → `data/storage.lua`
- `storage/sws_importer.lua` → `data/sws_import.lua`
- `storage/undo_bridge.lua` → `data/undo.lua`

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
