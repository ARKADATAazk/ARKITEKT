# Script Layer Architecture

> Guide for organizing platform-specific code in ARKITEKT scripts.

---

## Overview

ARKITEKT scripts follow a layered architecture where **pure logic** is separated from **platform-specific code**. This enables:

- **Testability**: Pure layers can be unit tested without REAPER
- **Portability**: Business logic could theoretically run outside REAPER
- **Clarity**: Clear boundaries for where REAPER/ImGui calls belong

---

## Layer Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│                         UI / VIEWS                          │
│   (renders widgets, handles user input)                     │
│   MAY use: ImGui, platform/*, arkitekt/platform/*           │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────┐
│                        PLATFORM                             │
│   (wraps REAPER/ImGui APIs for script-specific needs)       │
│   USES: reaper.*, ImGui.* directly                          │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────┐
│                     DOMAIN / CORE                           │
│   (pure business logic, no platform dependencies)           │
│   NEVER uses: reaper.*, ImGui.*                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Two Platform Layers

### 1. Framework Platform: `arkitekt/platform/`

Shared utilities used across all scripts. Located in the ARKITEKT framework.

| Module | Purpose |
|--------|---------|
| `imgui.lua` | ImGui version loader (handles 0.8/0.9 compatibility) |
| `images.lua` | Image loading and caching with budget management |
| `reaper.lua` | Common REAPER API wrappers (if needed) |

**Usage:**
```lua
local ImGui = require('arkitekt.platform.imgui')
local Images = require('arkitekt.platform.images')
```

### 2. Script Platform: `scripts/[AppName]/platform/`

Script-specific REAPER/ImGui wrappers. Contains APIs unique to that script's domain.

**Examples:**

| Script | Platform Module | Wraps |
|--------|-----------------|-------|
| ThemeAdjuster | `platform/theme_params.lua` | `reaper.ThemeLayout_GetParameter()` |
| ThemeAdjuster | `platform/param_discovery.lua` | Theme parameter scanning |
| ItemPicker | `platform/item_source.lua` | `reaper.GetMediaItem*()` calls |
| TemplateBrowser | `platform/template_io.lua` | Track template file I/O |

---

## When to Use Which Layer

### Use `arkitekt/platform/` when:

- The utility is **generic** (ImGui loading, image caching)
- Multiple scripts would benefit from it
- It's not tied to a specific business domain

### Use `scripts/X/platform/` when:

- The wrapper is **script-specific** (theme parameters, item sources)
- It wraps domain-specific REAPER APIs
- No other script would need it

### Keep in `domain/` or `core/` when:

- Logic is **100% pure** (no `reaper.*`, no `ImGui.*`)
- It could run in standalone Lua (theoretically)
- It operates only on data passed in as arguments

---

## Script Structure with Platform Layer

```
scripts/ThemeAdjuster/
├── ARK_ThemeAdjuster.lua     # Entry point
├── app/
│   ├── init.lua              # Bootstrap, wiring
│   └── state.lua             # State container
│
├── platform/                  # ← Script-specific REAPER wrappers
│   ├── theme_params.lua      # reaper.ThemeLayout_GetParameter()
│   ├── param_discovery.lua   # Theme parameter scanning
│   └── imgui.lua             # (Optional) Re-export or extend framework ImGui
│
├── domain/                    # ← Pure business logic
│   ├── theme/
│   │   └── reader.lua        # Parse theme data (pure)
│   └── packages/
│       ├── image_map.lua     # Map package images (pure)
│       └── metadata.lua      # Package metadata (pure)
│
├── ui/
│   └── views/
│       └── main.lua          # Uses platform/ + domain/
│
└── defs/
    └── constants.lua
```

---

## Migration Pattern

When moving REAPER API calls from `core/` to `platform/`:

### Step 1: Identify Violations

```lua
-- BAD: core/theme_params.lua
local M = {}

function M.get_parameter(name)
  return reaper.ThemeLayout_GetParameter(name)  -- ❌ REAPER call in core/
end

return M
```

### Step 2: Move to Platform

```lua
-- GOOD: platform/theme_params.lua
local M = {}

function M.get_parameter(name)
  return reaper.ThemeLayout_GetParameter(name)  -- ✅ REAPER call in platform/
end

return M
```

### Step 3: Add Compatibility Shim (Optional)

To avoid breaking existing imports during migration:

```lua
-- core/theme_params.lua (temporary shim)
-- @deprecated TEMP_PARITY_SHIM: Use platform/theme_params.lua
-- EXPIRES: After all imports updated
return require("ThemeAdjuster.platform.theme_params")
```

### Step 4: Update Imports

```lua
-- Before
local ThemeParams = require("ThemeAdjuster.core.theme_params")

-- After
local ThemeParams = require("ThemeAdjuster.platform.theme_params")
```

---

## ImGui Import Pattern

### Option A: Use Framework Loader (Recommended)

```lua
-- In any file that needs ImGui
local ImGui = require('arkitekt.platform.imgui')
```

### Option B: Script-Level Re-Export

If you need to extend or configure ImGui for a specific script:

```lua
-- platform/imgui.lua
local ImGui = require('arkitekt.platform.imgui')

-- Add script-specific extensions if needed
M.CustomWidget = function(ctx, ...)
  -- ...
end

return ImGui
```

Then use:
```lua
local ImGui = require('ThemeAdjuster.platform.imgui')
```

---

## Layer Purity Rules

### Pure Layers (NO `reaper.*` or `ImGui.*`)

| Layer | Allowed | Forbidden |
|-------|---------|-----------|
| `domain/` | Pure Lua, arkitekt.core.* | reaper.*, ImGui.* |
| `core/` (if exists) | Pure Lua, arkitekt.core.* | reaper.*, ImGui.* |
| `storage/` | Pure serialization logic | Direct file I/O* |

*Storage may use `io.*` for file operations, but not `reaper.*` for ExtState.

### Runtime Layers (May use platform APIs)

| Layer | May Use |
|-------|---------|
| `platform/` | reaper.*, ImGui.* directly |
| `ui/`, `views/` | ImGui via platform layer |
| `app/` | reaper.* for bootstrap, defer |
| `engine/` | reaper.* for transport, timing |

---

## Verification Checklist

Before completing a refactor:

- [ ] No `reaper.*` calls in `domain/` or `core/`
- [ ] No direct `ImGui.*` requires in `domain/` or `core/`
- [ ] All ImGui imports go through `arkitekt.platform.imgui` or `ScriptName.platform.imgui`
- [ ] Script-specific REAPER wrappers are in `ScriptName/platform/`
- [ ] Generic utilities are in `arkitekt/platform/` (or proposed for addition)

---

## See Also

- [PROJECT_STRUCTURE.md](./PROJECT_STRUCTURE.md) - Full layer definitions
- [CONVENTIONS.md](./CONVENTIONS.md) - Naming and coding standards
- [TESTING.md](./TESTING.md) - Testing pure vs platform layers
