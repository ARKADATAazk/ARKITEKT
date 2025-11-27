# CLAUDE.md - AI Assistant Field Guide for ARKITEKT

> **This is the definitive guide for AI assistants working with ARKITEKT.**
> For heavy batch/pipeline operations, see `ARKITEKT_Codex_Playbook_v5.md`.

---

## Quick Start (30 seconds)

**What is ARKITEKT?**
A Lua 5.3 framework for building ReaImGui applications in REAPER (audio workstation). It provides reusable widgets, window management, theming, and application scaffolding.

**Critical Rules:**
1. **Namespace**: Always `arkitekt` (lowercase). NEVER `arkitekt`.
2. **Bootstrap**: Use `dofile()`, not `require()` for entry points.
3. **Layer purity**: `core/*` and `storage/*` must NOT use `reaper.*` or `ImGui.*` at import time.
4. **No globals**: Everything returns a module table `M`.
5. **Read before writing**: ALWAYS read existing code before proposing changes.

---

## File Routing Map

| You want to... | Go to... |
|---------------|----------|
| Add/modify a **widget** | `arkitekt/gui/widgets/[category]/` |
| Change **app bootstrap** | `arkitekt/app/` (init/, runtime/, chrome/) |
| Add **constants/defaults** | `arkitekt/defs/` or app-specific `defs/` |
| Modify **theming** | `arkitekt/core/theme_manager/` |
| Work on **animations** | `arkitekt/gui/fx/animation/` |
| Change **font loading** | `arkitekt/app/chrome/fonts.lua` |
| Edit a **specific app** | `scripts/[AppName]/` |
| Add **pure utilities** | `arkitekt/core/` (no reaper/ImGui!) |
| Check **cookbook** | `cookbook/` |
| Find **actionable tasks** | `TODO/` |

### Layer Structure (per app/module)

```
app/        # Application orchestration, wiring
domain/     # Business logic (pure, no UI)
core/       # Pure utilities (no reaper/ImGui at import)
storage/    # Persistence (pure)
ui/         # Views, components
widgets/    # Reusable UI elements
defs/       # Constants, configuration
tests/      # Unit tests
```

**Dependency flow**: `UI → App → Domain ← Infra`
**NEVER**: UI → Storage directly, or Domain → UI

---

## What NOT To Do (Anti-Patterns)

### Critical Violations

| Don't | Do Instead |
|-------|------------|
| Use `require("arkitekt.")` | Use `require("arkitekt.")` |
| Add `reaper.*` in `core/*` | Keep core pure, move runtime code to `app/` |
| Create globals | Return module table `M` |
| Hardcode magic numbers | Use constants from `arkitekt/defs/` |
| Create new folders blindly | Check if existing structure fits |
| Propose changes without reading | ALWAYS read the file first |
| Touch >12 files in one change | Break into smaller phases |
| Reformat entire files | Keep diffs surgical |
| Add features beyond request | Do exactly what was asked |

### Layer Purity Violations

**Pure layers** (NO `reaper.*`, NO `ImGui.*` at import time):
- `core/*`
- `storage/*`
- `domain/*`
- `selectors.lua` (if present)

**Runtime layers** (may use `reaper.*` and `ImGui`):
- `app/*`
- `ui/*`, `views/*`, `widgets/*`
- `engine/*`

---

## Task Cookbook

### Task: Add a New Widget

1. **Read the widget guide**: `cookbook/WIDGETS.md`
2. **Check existing widgets**: `arkitekt/gui/widgets/[category]/`
3. **Find similar widget** to use as template
4. **Follow the widget API contract**:
   - Signature: `function M.draw(ctx, opts) return result end`
   - Use `Theme.COLORS` for colors (read every frame!)
   - Use `Base.get_state(id)` for persistent state
   - Advance cursor after drawing
5. **Test in Sandbox**: `scripts/Sandbox/`

### Task: Fix a Bug

1. **Read the file** containing the bug
2. **Understand the context** - read related files if needed
3. **Make surgical fix** - change only what's necessary
4. **Don't refactor** surrounding code unless asked
5. **Verify layer rules** - did you add reaper/ImGui to pure layer?

### Task: Add Feature to Existing App

1. **Read app entry point**: `scripts/[AppName]/ARK_[AppName].lua`
2. **Identify the layer** your feature belongs to:
   - UI change → `ui/`
   - Business logic → `domain/` or `core/`
   - State management → `app/`
3. **Check existing patterns** in that layer
4. **Follow conventions** from `cookbook/CONVENTIONS.md`
5. **Update constants** in `defs/` if adding magic numbers

### Task: Performance Optimization

1. **Check TODO/PERFORMANCE.md** for known issues
2. **Profile with `reaper.time_precise()`**
3. **Apply common patterns**:
   - Use `//1` for integer division
   - Cache function lookups at module top: `local floor = math.floor`
   - Avoid string concatenation in hot loops
   - Pre-allocate tables when size is known
4. **Reference**: `cookbook/LUA_PERFORMANCE_GUIDE.md`

### Task: Refactor/Migrate Code

1. **Check if migration plan exists**: `cookbook/MIGRATION_PLANS.md`
2. **Follow the phased approach**:
   - Phase 1: Add shims (preserve old API)
   - Phase 2: Wire up new code
   - Phase 3: Remove legacy
3. **Mark deprecated code**:
   ```lua
   -- @deprecated TEMP_PARITY_SHIM: old_func() → use new_module.func()
   -- EXPIRES: YYYY-MM-DD (planned removal: Phase-3)
   ```
4. **Update all importers** when moving modules
5. **Diff budget**: ≤12 files, ≤700 LOC (stricter for core: ≤6/300)

### Task: Add Constants/Configuration

1. **Framework constants** → `arkitekt/defs/app.lua`
2. **App-specific constants** → `scripts/[AppName]/defs/`
3. **Follow naming**:
   ```lua
   -- arkitekt/defs/timing.lua
   return {
     ANIMATION = {
       FADE_FAST = 0.15,
       FADE_NORMAL = 0.3,
     },
   }
   ```
4. **Never hardcode** timing, sizes, or colors in widget code

---

## Bootstrap Pattern

**Entry points MUST use dofile (not require)**:

```lua
local ARK
do
  local sep = package.config:sub(1,1)
  local src = debug.getinfo(1, "S").source:sub(2)
  local path = src:match("(.*"..sep..")")
  while path and #path > 3 do
    local init = path .. "arkitekt" .. sep .. "app" .. sep .. "init" .. sep .. "init.lua"
    local f = io.open(init, "r")
    if f then
      f:close()
      ARK = dofile(init).bootstrap()
      break
    end
    path = path:match("(.*"..sep..")[^"..sep.."]-"..sep.."$")
  end
  if not ARK then
    reaper.MB("ARKITEKT framework not found!", "FATAL ERROR", 0)
    return
  end
end
```

**Why?** Bootstrap sets up `package.path` - you can't `require()` until that runs. Chicken-and-egg problem.

---

## Module Pattern Template

```lua
-- @noindex
-- [AppName]/[layer]/[module_name].lua
-- Brief description of what this module does

local M = {}

-- DEPENDENCIES (at top, after M declaration)
local Logger = require('arkitekt.debug.logger')
local SomeOther = require('arkitekt.core.some_other')

-- CONSTANTS (if module-specific)
local DEFAULT_VALUE = 100
local MAX_ITEMS = 50

-- PRIVATE FUNCTIONS (prefix with underscore)
local function _helper(x)
  return x * 2
end

-- PUBLIC API
function M.new(opts)
  opts = opts or {}
  local self = {
    value = opts.value or DEFAULT_VALUE,
  }
  return setmetatable(self, { __index = M })
end

function M:do_something()
  return _helper(self.value)
end

return M
```

---

## Edit Hygiene

### Surgical Diffs
- Change **only** what's necessary
- Don't reformat or reorder unrelated code
- Don't add comments/docstrings to unchanged code
- Don't "improve" code that wasn't part of the request

### Anchor Comments (for large files)
```lua
-- >>> SECTION_NAME (BEGIN)
-- ... code ...
-- <<< SECTION_NAME (END)
```

### No Side Effects at Require Time
Module top-level should ONLY:
- Define `local M = {}`
- Define local functions
- Require dependencies
- Return `M`

**NEVER** at module top-level:
- Call `reaper.*` functions
- Initialize global state
- Print/log
- Open files

---

## Verification Checklist

Before completing any task, verify:

- [ ] No `require("arkitekt.` (old namespace)
- [ ] No `reaper.*` or `ImGui.*` in pure layers
- [ ] No globals introduced
- [ ] No files outside task scope modified
- [ ] Diff is surgical (no formatting changes)
- [ ] Follows existing patterns in the codebase
- [ ] Read the file before editing it

---

## Quick Reference

### Naming Conventions
- **Files/folders**: `snake_case` (`media_grid.lua`)
- **Modules**: `PascalCase` when required (`local MediaGrid = require(...)`)
- **Functions**: `snake_case` (`function M.get_items()`)
- **Constants**: `SCREAMING_SNAKE` (`local MAX_ITEMS = 100`)
- **Private**: `_underscore_prefix` (`local function _helper()`)

### Common Imports
```lua
-- Framework
local Shell = require('arkitekt.app.runtime.shell')
local Settings = require('arkitekt.core.settings')
local Logger = require('arkitekt.debug.logger')
local Constants = require('arkitekt.app.init.constants')

-- Widgets
local Button = require('arkitekt.gui.widgets.primitives.button')
local Panel = require('arkitekt.gui.widgets.containers.panel')
```

### App Structure
```
scripts/MyApp/
├── ARK_MyApp.lua          # Entry point (bootstrap + Shell.run)
├── app/                   # Orchestration
│   └── state.lua          # App state management
├── core/                  # Pure logic
├── defs/                  # Constants
│   ├── defaults.lua
│   └── config.lua
├── ui/                    # Views
│   └── main_view.lua
└── tests/                 # Tests
```

---

## Documentation Hierarchy

When you need more detail:

1. **This file** (CLAUDE.md) - Quick reference, task cookbook
2. **cookbook/CONVENTIONS.md** - Detailed coding standards
3. **cookbook/PROJECT_STRUCTURE.md** - Full architecture guide
4. **cookbook/WIDGETS.md** - Widget development patterns
5. **cookbook/THEME_MANAGER.md** - Theming system guide
6. **cookbook/LUA_PERFORMANCE_GUIDE.md** - Performance optimization
7. **cookbook/DEPRECATED.md** - Deprecation tracker
8. **TODO/** - Actionable improvements to work on

---

## Common Gotchas

| Gotcha | Solution |
|--------|----------|
| "Module not found" after bootstrap | Check `package.path` was set up correctly |
| Fullscreen/overlay not working | Use `OverlayManager`, not old window.lua code |
| Settings not persisting | Use `Settings.new()` - each app needs own instance |
| Fonts not loading | Use `arkitekt.app.chrome.fonts` loader |
| Animation stuttering | Check if you're creating new animation objects every frame |
| Widget state lost | Make sure state lives in app layer, not recreated each draw |

---

## Final Reminders

1. **Read first, write second** - Understand before changing
2. **Minimal changes** - Do exactly what's asked, nothing more
3. **Respect layers** - Pure stays pure, runtime stays runtime
4. **Follow patterns** - Look at similar code in the codebase
5. **Check namespace** - `arkitekt`, never `arkitekt`
