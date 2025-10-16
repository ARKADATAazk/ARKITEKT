# AGENTS.md — ARKITEKT (Quick Rules for Humans & LLMs)

**Primary spec:** See `ARKITEKT_Codex_Playbook_v5.md`.  
This file is a quick-start and pointer, not a duplicate.

---

## Basics
- Language/runtime: **Lua 5.3**.
- UI: ReaImGui (keep API calls behind view/widgets layers).
- Module shape: return a table (usually `M`); constructors are typically `new(opts)` or `create(opts)`.
- Namespaces: prefer `rearkitekt.*` and project app namespaces; **do not** introduce `arkitekt.*`.

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
