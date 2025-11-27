# Script Layer Architecture

> Guide for organizing code in ARKITEKT framework and scripts.

---

## Key Insight: Framework vs Scripts

ARKITEKT code runs **exclusively inside REAPER**. There's no external environment to test in. This means:

- "Pure domain testing" still happens inside REAPER
- Strict purity enforcement adds complexity without real benefit for scripts
- The framework keeps discipline; scripts stay pragmatic

| Level | Purity Rules | `platform/` Layer | Why |
|-------|--------------|-------------------|-----|
| **Framework** (`arkitekt/`) | Strict in `core/` | Yes | Framework utilities should be stable, reusable |
| **Scripts** (`scripts/X/`) | Relaxed | No | Scripts are app-specific, always in REAPER |

---

## Framework: `arkitekt/`

The framework maintains purity in `core/` to keep utilities stable and reusable.

```
arkitekt/
├── core/           # Pure utilities - NO reaper.*, NO ImGui.*
│   ├── json.lua
│   ├── uuid.lua
│   ├── colors.lua
│   └── ...
│
├── platform/       # REAPER/ImGui abstractions
│   ├── imgui.lua   # ImGui version loader (0.8/0.9 compat)
│   └── images.lua  # Image loading with cache/budget
│
├── gui/            # Widgets and rendering (uses ImGui)
├── app/            # Bootstrap and runtime
└── debug/          # Logger, test runner
```

### Framework Rules

| Folder | May use `reaper.*` | May use `ImGui.*` |
|--------|-------------------|-------------------|
| `core/` | No | No |
| `platform/` | Yes | Yes |
| `gui/`, `app/`, `debug/` | Yes | Yes |

**Why keep `core/` pure?** Framework utilities (json, uuid, colors, math) are used everywhere. Keeping them pure ensures they're stable and don't have hidden dependencies.

---

## Scripts: `scripts/X/`

Scripts organize by **responsibility**, not purity. Use folders that make sense for your app.

### Typical Script Structure

```
scripts/RegionPlaylist/
├── ARK_RegionPlaylist.lua   # Entry point
├── app/                     # Bootstrap, state container
├── engine/                  # ← Script-specific: playback orchestration
├── domains/                 # Business data (playlists, regions)
├── ui/                      # Views, tiles
├── storage/                 # Persistence
├── defs/                    # Constants
└── tests/                   # Integration tests
```

### Script-Specific Folders

Scripts can have **specialized folders** that don't fit the canonical structure:

| Script | Special Folder | Purpose |
|--------|---------------|---------|
| RegionPlaylist | `engine/` | Playback orchestration (uses `reaper.*` for transport) |
| ThemeAdjuster | `packages/` | Theme package management |
| TemplateBrowser | `scanner/` | Template file scanning |

**This is fine.** The `engine/` folder is like `app/` - an orchestration layer that naturally uses platform APIs.

### No `platform/` in Scripts

Scripts don't need a `platform/` folder because:

1. All script code runs in REAPER anyway
2. Forcing purity splits adds complexity without benefit
3. Orchestration layers (`app/`, `engine/`) can use `reaper.*` directly

**Instead of:**
```
scripts/RegionPlaylist/
├── platform/           # ❌ Unnecessary
│   └── transport.lua
├── domain/
│   └── playback/
│       └── transport.lua
```

**Just do:**
```
scripts/RegionPlaylist/
├── engine/             # ✅ Simpler - orchestration uses reaper.* directly
│   └── transport.lua
```

---

## Using Framework Platform

Scripts should use `arkitekt/platform/` for shared utilities:

```lua
-- ImGui (handles version compatibility)
local ImGui = require('arkitekt.platform.imgui')

-- Image cache (with budget management)
local Images = require('arkitekt.platform.images')
```

These exist because they solve **cross-script problems** (ImGui version compat, image memory management).

---

## Organizing by Responsibility

### Common Script Folders

| Folder | Purpose | Uses `reaper.*`? |
|--------|---------|------------------|
| `app/` | Bootstrap, state container, wiring | Yes (defer, init) |
| `ui/`, `views/` | Rendering, user interaction | Yes (via ImGui) |
| `engine/` | Script-specific orchestration | Yes (transport, timing) |
| `domains/` | Business data structures | Can if needed |
| `storage/` | Persistence | Yes (ExtState, files) |
| `defs/` | Constants, defaults | No |
| `tests/` | Integration tests | Yes (runs in REAPER) |

### The Real Rule

Organize code so it's **easy to find and understand**, not to satisfy abstract purity requirements.

---

## Testing Reality

All ARKITEKT tests are **integration tests** - they run inside REAPER using the test runner:

```lua
local TestRunner = require('arkitekt.debug.test_runner')

-- Tests run in REAPER, can use reaper.* freely
function tests.test_playlist_saves()
  Persistence.save_playlists(data, 0)
  local loaded = Persistence.load_playlists(0)
  assert.not_nil(loaded)
end
```

You can mock dependencies for isolation, but the tests still execute in REAPER. See [TESTING.md](./TESTING.md) for the test framework.

---

## Summary

| Principle | Framework | Scripts |
|-----------|-----------|---------|
| Keep `core/` pure | Yes | Not required |
| Use `platform/` | Yes, for shared abstractions | No, not needed |
| Organize by... | Layer type | Responsibility |
| Test environment | REAPER | REAPER |

**Framework = disciplined.** Keeps utilities stable and reusable.

**Scripts = pragmatic.** Organize by what makes sense for your app.

---

## See Also

- [PROJECT_STRUCTURE.md](./PROJECT_STRUCTURE.md) - Canonical folder structure
- [TESTING.md](./TESTING.md) - Test framework guide
- [CONVENTIONS.md](./CONVENTIONS.md) - Naming and coding standards
