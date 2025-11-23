# AGENTS.md — ARKITEKT (Quick Rules for Humans & LLMs)

**Primary spec:** See `ARKITEKT_Codex_Playbook_v5.md`.  
This file is a quick-start and pointer, not a duplicate.

---

## Basics
- Language/runtime: **Lua 5.3**.
- UI: ReaImGui (keep API calls behind view/widgets layers).
- Module shape: return a table (usually `M`); constructors are typically `new(opts)` or `create(opts)`.
- Namespaces: prefer `arkitekt.*` and project app namespaces; **do not** introduce `arkitekt.*`.

## Layering & Purity
- **Pure layers** (no `reaper.*` / no `ImGui` / no IO at import time):
  - `core/*`, `storage/*`, and selectors/utilities.
- **Runtime/UI layers** (may use `reaper.*` and ImGui):
  - `app/*`, `views/*`, `widgets/*`, `components/*`, demos.
- Keep stateful classes in `app/*`, view composition in `views/*`, and low-level drawing in `widgets/*`.

## Edit Hygiene
- No globals; no side-effects at `require` time (module top-level should only define locals/exports).
- Don’t reformat or reorder whole files as part of a behavior-only change.
- Prefer additive shims → wire-up → remove legacy, across **small phases**.
- Keep diffs surgical; use **anchors** for patch targets:
  ```lua
  -- >>> INIT (BEGIN)
  -- ...
  -- <<< INIT (END)

  -- >>> WIRING: CONTROLLER/VIEW (BEGIN)
  -- ...
  -- <<< WIRING: CONTROLLER/VIEW (END)
  ```

## Framework Patterns (Jan 2025)

### Entry Point Bootstrap
**Always use** this bootstrap pattern (finds and loads init.lua via dofile):
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
      local Init = dofile(init)
      ARK = Init.bootstrap()
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
**Why dofile, not require?** The init.lua module can't be `require()`'d until after bootstrap runs and sets up package.path. This creates a chicken-and-egg problem, so we use `dofile()` to load it directly.

**Note:** Path is `app/init/init.lua` (not `app/init.lua`) since the app/ folder was reorganized.

### Constants & Defaults
- Use `arkitekt.app.init.constants` for all magic numbers
- Framework controls defaults; apps override **only** when truly app-specific
- **Anti-pattern:** Hardcoding `32` or `0.3` in app code — use `Constants.OVERLAY.CLOSE_BUTTON_SIZE` or `Constants.ANIMATION.FADE_NORMAL`

### App Folder Structure
Organized by concern (as of Jan 2025 reorganization):
```
app/
├── init/                  # Bootstrap & configuration
│   ├── bootstrap.lua
│   ├── init.lua
│   └── constants.lua      # All framework constants
├── runtime/               # Execution layer
│   ├── runtime.lua        # Low-level defer loop
│   └── shell.lua          # High-level app runner
├── chrome/                # Window chrome components
│   ├── titlebar/
│   ├── window/            # Main window management
│   └── status_bar/
└── assets/                # Visual resources
    ├── fonts.lua
    └── icon.lua
```

### Overlay Configuration
Use `OverlayDefaults.create_overlay_config()` helper:
```lua
overlay_mgr:push(OverlayDefaults.create_overlay_config({
  id = "my_overlay",
  -- Override only if app-specific (most apps: don't override anything!)
  render = function(ctx, alpha_val, bounds) ... end,
  on_close = cleanup,
}))
```
**Don't** manually specify all 15+ overlay config fields — let framework provide defaults.

### Font Loading
Use centralized loader:
```lua
local Fonts = require('arkitekt.app.assets.fonts')
local fonts = Fonts.load(ImGui, ctx)  -- Uses constants.lua defaults
-- OR with app-specific sizes:
local fonts = Fonts.load(ImGui, ctx, { title_size = 24 })
```
**Don't** duplicate 35-line `load_fonts()` function in entry points.

### Settings Instances
Use `Settings.new()` to create fresh instances:
```lua
local Settings = require('arkitekt.core.settings')
local settings = Settings.new(cache_dir, "my_app.json")
```
**Never** assume singleton behavior — each app gets its own instance.

## Known Tech Debt
- **window.lua fullscreen code**: ~82 lines of unused fullscreen/scrim/fade logic (replaced by OverlayManager system). Should be removed in future cleanup.

## Documentation

**Strive for documentation in every important folder.** README.md files help AI agents (and humans) track how things work, understand architecture decisions, and reference the latest progress/refactoring.

### Documentation Hierarchy:
1. **AGENTS.md** (this file): Quick rules, patterns, and architecture overview
2. **Documentation/** folder: Dated refactoring summaries (`YYYY-MM-DD_Description.md`)
3. **Module README.md**: High-level module documentation in important folders
   - `arkitekt/app/README.md` - Framework application layer
   - `arkitekt/gui/widgets/foo/README.md` - Complex widget systems
   - `scripts/MyApp/README.md` - Application-specific docs

### What to Document in README.md:
- **Purpose**: What this module/folder does
- **Structure**: Organization and key files
- **API/Patterns**: How to use or extend it
- **Recent Changes**: Latest refactorings with dates
- **Known Issues**: Tech debt or limitations

### Example:
- **Refactoring summaries:** `Documentation/2025-01-19_Framework_Consolidation.md`
- **Module documentation:** `arkitekt/app/README.md` (framework bootstrap & runtime)
- **Architecture changes:** Update `AGENTS.md` (this file)
