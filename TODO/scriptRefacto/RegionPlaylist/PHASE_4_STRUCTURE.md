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
| `engine/` | `domain/playback/` + `platform/` | 7 |
| `storage/` | `infra/` | 3 |

## Key Decisions

### 1. UI State Domains → ui/state/

These are UI concerns, not business logic:
- `domains/animation.lua` → `ui/state/animation.lua`
- `domains/notification.lua` → `ui/state/notification.lua`
- `domains/ui_preferences.lua` → `ui/state/preferences.lua`

### 2. Engine → domain/playback/ + platform/

The engine contains **mixed concerns**. Per [cookbook/SCRIPT_LAYERS.md](../../../../cookbook/SCRIPT_LAYERS.md), we must separate:

**Pure playback logic → `domain/playback/`** (NO `reaper.*` calls):
- `engine/engine_state.lua` → `domain/playback/state.lua` (sequence, indices)
- `engine/playback.lua` → `domain/playback/loop.lua` (loop logic)
- Sequence expansion, item management

**REAPER API wrappers → `platform/`** (wraps `reaper.*` calls):
- `platform/transport.lua` - Wraps `reaper.GetPlayState()`, `reaper.OnPlayButton()`, etc.
- `platform/timing.lua` - Wraps `reaper.GetPlayPosition()`, `reaper.time_precise()`
- `platform/regions.lua` - Wraps `reaper.EnumProjectMarkers()`, region queries

**Orchestration → `app/` or `engine/`** (uses platform + domain):
- `engine/core.lua` → `app/playback_controller.lua` or keep in `engine/`
- `engine/transport.lua` → Split: pure logic to domain, REAPER calls to platform
- `engine/transitions.lua` → Split: state machine to domain, timing to platform

**Example split for transport.lua:**

```lua
-- platform/transport.lua (REAPER wrappers)
local M = {}

function M.get_play_state(proj)
  return reaper.GetPlayState()
end

function M.get_play_position(proj)
  return reaper.GetPlayPosition()
end

function M.start_playback()
  reaper.OnPlayButton()
end

function M.stop_playback()
  reaper.OnStopButton()
end

return M
```

```lua
-- domain/playback/transport.lua (pure logic)
local M = {}

function M.new(platform_transport)
  local self = {
    _platform = platform_transport,
    loop_enabled = false,
    shuffle_enabled = false,
  }
  return setmetatable(self, { __index = M })
end

function M:is_playing()
  local state = self._platform.get_play_state()
  return state & 1 == 1  -- Pure bit check
end

return M
```

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
