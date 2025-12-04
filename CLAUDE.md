# CLAUDE.md – ARKITEKT Field Guide

> **Definitive guide for AI assistants working on ARKITEKT.**
> Be strict with rules, gentle with diffs.

---

## 1. TL;DR (30 seconds)

**What is ARKITEKT?**  
Lua 5.3 framework for building ReaImGui apps in REAPER. It provides widgets, window management, theming, storage, and app scaffolding.

**Critical rules**

1. **Namespace**
   - `arkitekt.*` for `require(...)`
   - `Ark.*` for lazy-loaded widgets/utilities (via loader bootstrap)

2. **Bootstrap**
   - Entry points **MUST** use `dofile` bootstrap, **not** `require`.
   - Reason: bootstrap sets `package.path`; `require` before that is a chicken-and-egg failure.
   - For the full template: see `cookbook/CONVENTIONS.md#bootstrap-pattern`.

3. **Layer responsibilities**
   - `domain/*` = business logic (**no ImGui**).
   - `core/*` = reusable utilities (fs/json/settings/math).
   - `platform/*` = ReaImGui/REAPER abstractions (imgui/images/etc.).
   - UI layers (`app/ui/views/widgets/gui`) can call both `reaper.*` and `ImGui.*`.
   - Separation is about **responsibility**, not “purity”.

4. **No globals**
   - Every module returns a table `M`.
   - No implicit globals, no side effects at require time (no `reaper.*`, no I/O, no logging at top level).

5. **Edit discipline**
   - Always read the file (and nearby modules) **before** editing.
   - Diffs must be **surgical**: no reformatting, no drive-by refactors.

6. **Naming standards**
   - Constructors: `M.new(opts)` preferred (extensible), `M.new(config)` or `M.new()` valid
   - Local vars: `cfg` (not `config`), `state` (never `st`), `ctx`, `opts`
   - See `cookbook/CONVENTIONS.md` for full standards

**Quick examples**

```lua
-- Button - ImGui-style positional mode
if Ark.Button(ctx, 'Save') then ... end
if Ark.Button(ctx, 'Save', 100) then ... end  -- with width

-- Button - Opts mode with semantic presets
if Ark.Button(ctx, { label = 'Delete', preset = 'danger' }) then ... end
-- Presets: 'primary', 'danger', 'success', 'secondary'

-- ID Stack (for loops with multiple widgets)
for i, track in ipairs(tracks) do
  Ark.PushID(ctx, i)
    if Ark.Button(ctx, 'M') then ... end  -- ID = '1/M', '2/M', ...
    if Ark.Button(ctx, 'S') then ... end  -- ID = '1/S', '2/S', ...
    Ark.Grid(ctx, { items = track.items })  -- ID = '1/grid', '2/grid', ...
  Ark.PopID(ctx)
end

-- Disabled Stack (disable region of widgets)
Ark.BeginDisabled(ctx, is_loading)
  Ark.Button(ctx, 'Save')      -- All disabled when is_loading
  Ark.Button(ctx, 'Cancel')
  Ark.InputText(ctx, { id = 'name' })
Ark.EndDisabled(ctx)
```

For full widget API, see `cookbook/QUICKSTART.md` and `cookbook/WIDGETS.md`.
For ArkContext and stacks, see `cookbook/ARKCONTEXT.md`.

**Colors**

Use byte literals (`0xRRGGBBAA`) for static colors:

```lua
local COLORS = {
    red = 0xFF0000FF,      -- Opaque red (RRGGBB + FF alpha)
    blue = 0x0000FF80,     -- 50% transparent blue
}

-- For dynamic opacity, use WithOpacity:
local fill = Ark.Colors.WithOpacity(base_color, 0.5)
```

**Note:** `Colors.hex()` exists for runtime user input (theme manager, palettes) but should NOT be used for static color definitions.

---

## 2. Where to Work – Routing Map

| You want to…                       | Go to…                                           |
|-----------------------------------|--------------------------------------------------|
| Add/modify a **widget**           | `arkitekt/gui/widgets/[category]/`              |
| Change **app bootstrap/runtime**  | `arkitekt/runtime/` (shell.lua, chrome/)        |
| Add **constants/defaults**        | `arkitekt/config/` or `scripts/[AppName]/config/` |
| Modify **theming**                | `arkitekt/theme/` or `arkitekt/theme/manager/`  |
| Work on **animations**            | `arkitekt/gui/animation/`                       |
| Work on **drawing/rendering**     | `arkitekt/gui/draw/` or `arkitekt/gui/renderers/` |
| Add **interaction handlers**      | `arkitekt/gui/interaction/` (drag-drop, selection, reorder) |
| Add **layout utilities**          | `arkitekt/gui/layout/`                          |
| Change **font loading**           | `arkitekt/runtime/chrome/fonts.lua`             |
| Edit a **specific app**           | `scripts/[AppName]/`                            |
| Add **reusable utilities**        | `arkitekt/core/` (fs, json, settings, etc.)     |
| Add **assets** (fonts, icons)     | `arkitekt/assets/`                              |
| Add **vendor/external libs**      | `arkitekt/vendor/`                              |
| Check detailed **guides**         | `cookbook/`                                     |
| Find **actionable tasks**         | `TODO/`                                         |

**Layer structure (per app / module)**

```text
app/      # Orchestration, wiring, runtime
domain/   # Business logic (no ImGui)
core/     # Reusable utilities (fs/json/settings/math)
storage/  # Persistence logic
ui/       # Views, components
widgets/  # Reusable UI elements
config/   # Constants & configuration
tests/    # Unit tests
```

**Dependency flow**: `UI → app → domain ← infra`  
**Never**: UI → storage directly, or domain → UI.

---

## 3. Task Cookbook (short version)

For full workflows, see the corresponding sections in `cookbook/`.

### Add a New Widget

- Read `cookbook/API_DESIGN_PHILOSOPHY.md` and `cookbook/WIDGETS.md`.
- Find a similar widget in `arkitekt/gui/widgets/[category]/` and copy its pattern.
- Single-frame widget → `M.draw(ctx, opts)` returning result.
- Multi-frame widget → `M.begin_*` / `M.end_*` (ImGui-style).
- Never hardcode colors/timing; use `arkitekt/config/*` + `Theme.COLORS`.

### Fix a Bug

- Read the entire file containing the bug, plus any obviously related modules.
- Change only what’s necessary; no refactor unless explicitly requested.
- Make sure you didn’t introduce ImGui in `domain/*`.
- If it’s a recurring pattern issue, add a note/task to `TODO/` rather than silently redesigning.

### Add a Feature to an Existing App

- Start at `scripts/[AppName]/ARK_[AppName].lua` to locate app wiring.
- Decide the layer:
  - UI change → `ui/` (or `widgets/`).
  - Business logic → `domain/` or `core/`.
  - State management / orchestration → `app/`.
- Follow patterns you see in that layer and the rules in `cookbook/CONVENTIONS.md`.

### Performance Optimization

- Check `TODO/PERFORMANCE.md` + `cookbook/LUA_PERFORMANCE_GUIDE.md`.
- Use `reaper.time_precise()` profiling.
- Typical fixes:
  - Cache function lookups (`local floor = math.floor`).
  - Avoid string concat in hot loops.
  - Pre-allocate tables when size is known.

### Refactor / Migration

- Check `cookbook/REFACTOR_PLAN.md`.
- Use phased approach: shims → new path wired → remove legacy.
- Mark deprecated shims clearly with expiry notes.
- Respect diff budget (see below).

---

## 4. Edit Hygiene & Diff Budget

**Do:**

- Keep diffs *surgical*.
- Match existing style/patterns.
- Use anchor comments when editing large chunks:

  ```lua
  -- >>> SECTION_NAME (BEGIN)
  --   code
  -- <<< SECTION_NAME (END)
  ```

**Don’t:**

- Reformat whole files.
- Rename things that are out of scope.
- Introduce new globals or implicit state.

**Diff budget (per task):**

- Max **12 files**, **≤700 LOC** changed.
- For `core/*`: prefer **≤6 files**, **≤300 LOC**.
- If you must go beyond this, stop and split into multiple phases/tasks.

---

## 5. ImGui / ReaImGui References

Use these as **reference only** (they show ImGui patterns, not ARKITEKT APIs):

- `references/imgui/ReaImGui_Demo.lua` – official demo with all widgets and patterns.
- `references/imgui/imgui_defs.lua` – LuaCATS type defs and ImGui constants.

Typical workflow for a new widget:

1. Grep the ImGui demo for the base widget pattern.
2. Understand whether it’s Begin/End or single-call.
3. Decide whether to mirror exactly or “wrap + improve” per `cookbook/API_DESIGN_PHILOSOPHY.md`.
4. Implement using ARKITEKT’s widget conventions.

---

## 6. Anti-Patterns – Hard No's

Never do these:

- UI / ImGui calls in `domain/*`.
- New globals or module-level side effects.
- Hardcoded magic numbers when a `config/` constant exists.
- Creating new folders just because "it feels cleaner" – check existing structure first.
- Touching unrelated files "while you're here".
- Re-declaring default config values (colors, padding, rounding, etc.) just to restate defaults.
- Overriding core defaults unless explicitly requested.
- **Adding backwards compatibility / legacy fallbacks.** ARKITEKT is fully internal with no external consumers. During refactors, just change the code directly—no shims, no "legacy support", no deprecation warnings. Clean breaks are preferred.

---

## 7. Final Checklist Before You Say "Done"

Make sure:

- [ ] No legacy namespaces; only `require('arkitekt.*')` and `Ark.*` for loader utilities.
- [ ] No UI / ImGui in `domain/*`.
- [ ] No new globals or top-level side effects.
- [ ] Only files in scope were touched.
- [ ] Diff is small and focused.
- [ ] Code matches existing patterns in that folder.
- [ ] You actually read the file(s) before editing.
- [ ] Naming follows standards: `M.new(opts)`, `cfg` locals, `state` never `st`

If in doubt: **stop, re-read, then adjust.**
