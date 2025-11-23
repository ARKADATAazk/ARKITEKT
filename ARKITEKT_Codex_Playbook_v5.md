# ARKITEKT Codex Playbook — **V5** (Safety · Parity · Proof-Greps · Pipelines)

> **Purpose**: Tell Codex *exactly* how to edit this repo safely — now including **batched pipelines**.  
> **Style**: Small, reversible changes; strict boundaries; clear acceptance & proof-greps.  
> **Output**: Codex returns **one JSON object** describing the patch (edits/moves/deletions/notes/acceptance).

---

## Repo facts (don’t guess)
- **Project root**: `ARKITEKT/`
- **Library namespace**: `arkitekt` (canonical; *do not* use `arkitekt`)
- **App code**: `ARKITEKT/scripts/<Feature>/...` (e.g., `RegionPlaylist/`)
- **Runtime**: **Lua 5.3**; modules use `local M = {}; ...; return M`
- **No runtime**: do **not** run/simulate REAPER / ReaScript / ReaImGui

## Hard boundaries (non-negotiable)
- **Path fence**: Only touch files inside the task’s declared roots (`live_root`, `feature_root`, or explicit allowlist).
- **Require fence**: You may `require('arkitekt.*')` and `<Feature>.{core,app,engine,storage,views,widgets,components}.*`.
- **Purity**: Do **not** add new `reaper.*` or `ImGui.*` in *pure* layers (`core/*`, `storage/persistence.lua`, `selectors.lua`).
- **No globals**; no side-effects at `require` time.
- **Docs**: Do **not** edit `.md/.txt/.xml` unless explicitly asked.
- **Idempotence**: Re-applying the patch is a no-op (no double deletes/renames).

---

## Defaults (V5)
**Diff budget (global hard cap):** ≤ **12 files**, ≤ **700** added LOC.  
**Core/storage stricter cap:** ≤ **6 files**, ≤ **300** added LOC.  
**Mechanical exception:** Up to **30 files** **iff** each file adds ≤ **50** LOC and changes are *mechanical only* (e.g., require swaps).  
**Allowlist default:** If omitted, default to `live_root` + `feature_root`.  
**Shim expiry default:** 30 days from patch date; include **planned removal phase** in shim header.  
**Failure contract (when `ok:false`):**
```json
{
  "unmet_exports": [],
  "missing_files": [],
  "exceeded_budget": {"files": 0, "loc": 0},
  "would_touch": []
}
```
**Counting rules:** ignore whitespace-only lines; pure moves/renames = 0 LOC; exclude generated/snapshots.

---

## Pipelines & Conformance (V5)

> Batch multiple CODEX phases safely via a manifest; enforce Playbook rules **per phase**.

### Why
- Reuse the same **budgets** (≤12/700; core/storage: ≤6/300) across batched phases.  
- Keep **require/purity fences** and **proof-greps** identical to single-task edits.  
- Maintain **idempotence**, **acceptance**, **proof_grep**, and the **failure contract** per phase.

### Manifest location & schema
- **Path:** `.codex/pipeline.json`
- **Schema (minimal):**
```json
{
  "stop_on_fail": true,
  "phases": [
    {
      "name": "string-identifier",
      "payload": {
        "task": "…",
        "constraints": {
          "allowlist": ["<minimal paths>"],
          "diff_budget": {"files": 12, "added_loc": 700}
        },
        "acceptance": ["... per V5 template ..."],
        "proof_grep":  ["... per V5 template ..."],
        "notes":       "... impact/risks/mitigations/rollback ..."
      }
    }
  ]
}
```

### Conformance rules (per phase)
- Every phase **must** include: `allowlist`, `diff_budget`, `acceptance`, `proof_grep`, and `notes`.
- If a phase touches `core/*` or `storage/*` → use stricter cap ≤ **6 files** / ≤ **300 LOC**.
- Required proof-greps (**at minimum**):
  - **Block old namespace:** no `require("arkitekt.`  
  - **No backslashes in require():** forbid `\` inside `require(...)`  
  - **Purity fence:** for `core/*`, `storage/persistence.lua`, `selectors.lua` → no new `reaper.` or `ImGui`  
  - **Positive canonicalization** near engine/coordinator boundary: must find `canonicalize_sequence(` (or a `shapes.canonicalize_*(` equivalent)

### Runner contract
- Submit phases **in order**; if `stop_on_fail=true`, **abort** on first failure.
- Each phase pushes to a distinct branch `codex/phase-<name>`; no cross-phase squashing.
- On failure, return V5 **failure contract** (`unmet_exports`, `missing_files`, `exceeded_budget`, `would_touch`); **no partial patches**.

### CI/Notifications contract
On any `push` to `codex/**`:
1) **Lua 5.3 parse** of changed `.lua` files.  
2) Enforce proof-greps & budgets (global ≤12/700; core/storage ≤6/300).  
3) Open/Update a PR per phase branch.  
4) Post a Discord webhook (success/failure).  
**Minimal Discord step (GitHub Actions):**
```yaml
- name: Discord notify
  if: always()
  env:
    WEBHOOK: ${{ secrets.DISCORD_WEBHOOK }}
    STATUS: ${{ job.status }}
  run: |
    MSG="**${{ github.ref_name }}** ${STATUS}"
    curl -fsS -H "Content-Type: application/json"       -d "$(jq -n --arg c "$MSG" '{content:$c}')" "$WEBHOOK"
```

### New meta-tasks
1) **author_pipeline_manifest** — create/update `.codex/pipeline.json` with phases that already obey V5 caps & proof-greps.  
2) **run_pipeline** — feed phases sequentially; halt on first failure when `stop_on_fail=true`. Record per-phase `ok:true/false` and attach CI URLs in `notes`.  
3) **create_ci_notifications** — author a GitHub Actions workflow that validates parse + greps + budgets; opens/updates PR; posts Discord webhook.

---

## Parity & shims (temporary adapters)
When changing an API used by other files, **preserve behavior** with a clearly marked shim:

```lua
-- @deprecated TEMP_PARITY_SHIM: get_sequence() → use playlists.sequencer
-- EXPIRES: 2025-11-15 (planned removal: Phase-3)
-- reason: GUI still calls bridge:get_sequence(); remove after GUI migrates.
function M.get_sequence()
  return Sequencer.expand_playlist(M:get_active_playlist(), M.get_playlist_by_id)
end
```

**Rules**
- Tag **@deprecated** + **EXPIRES: YYYY-MM-DD** + planned removal phase.
- Keep surface compatible (names/args/returns).
- Remove shims in the stated phase; fail the patch if the date is passed.

---

## Proof-greps (always-on static checks)
Add these to every task’s `acceptance`/`proof_grep`.

**Block old namespace**
- **Must not find**: `require("arkitekt.`

**No Windows separators in requires**
- **Must not find**: backslashes inside `require(...)`

**Canonical shape before engine calls**
- **Must find** a positive near engine/coordinator boundary: `canonicalize_sequence(` (or `shapes.canonicalize_*(`)  
- **Must not find** negatives (table values where numbers are expected): `loop%s*=%s*{` and `total_loops%s*=%s*{`

**Require graph health**
- If moving/deleting modules: “**No remaining require(...) of moved/deleted modules**” and “**All importers updated**”.

**Purity fence**
- For `core/*`, `storage/persistence.lua`, `selectors.lua`: “**no new reaper%. or ImGui**”.

---

## Notes format (impact analysis)
For anything larger than a one-liner, structure `notes`:

- **Impacted modules**: list files
- **Caller deltas**: signatures/args/return shape deltas
- **Risks**: what could break
- **Mitigations**: parity shims, proof-greps, rollback outline

---

## Common tasks (how to behave)

### 1) Scan requires
**Input**: `{"task":"scan_requires","root":"ARKITEKT"}`  
**Do**: regex map `file -> [requires...]`; list top imports.  
**Output**: `ok:true`, `notes` with totals; **no edits**.

### 2) Refactor a require (surgical)
**Input**: `{"task":"refactor_require","from":"X.Y","to":"A.B","live_root":"ARKITEKT/scripts"}`  
**Do**: update **all** importers under `live_root`.  
**Acceptance**: no remaining imports of `from`; Lua 5.3 parse; idempotent.

### 3) Delete legacy & prove callers use new module
**Input**: `{"task":"phaseX_cleanup_remove_legacy","live_root":"ARKITEKT/scripts","feature_root":"RegionPlaylist"}`  
**Do**: preflight importers → rewrite to new path → delete legacy; also delete unused parallel feature tree at repo root.  
**Acceptance**: “zero references to legacy paths”; idempotent.

### 4) Scaffold a pure module
**Input**: `{"task":"scaffold_module","files":[{"path":".../core/keys.lua","template":"module_table"}]}`  
**Do**: minimal Lua 5.3 module; no `reaper/ImGui` in pure layers; TODOs allowed in `app/*` only.

### 5) Move a module
**Input**: `{"task":"move_module","from":"...","to":"..."}`  
**Do**: move + update **all** importers; avoid new cycles; keep semantics (pure vs runtime).

### 6) (Meta) Author/Run pipelines
**Input**:
- `{"task":"author_pipeline_manifest","edits":[{"path":".codex/pipeline.json","op":"create|update","contents":{...}}]}`
- `{"task":"run_pipeline","path":".codex/pipeline.json"}`  
**Do**: write/validate manifest; submit phases in order; stop on first fail if `stop_on_fail=true`.  
**Acceptance**: each phase returns `ok:true`; CI passes; Discord ping sent.

---

## Acceptance block template
Paste (and adjust) per task or phase:

```json
{
  "acceptance": [
    "No remaining require(...) of moved/deleted modules.",
    "All edited files parse as Lua 5.3.",
    "Pure layers contain no new reaper.* or ImGui calls.",
    "Patch is idempotent (re-apply = no-op).",
    "No files changed outside declared roots.",
    "Diff budget respected."
  ],
  "proof_grep": [
    {"pattern":"require\([\"']arkitekt\.", "should_match": false},
    {"pattern":"require%([^)]-[\\]", "should_match": false},
    {"pattern":"canonicalize_sequence%\(", "should_match": true},
    {"pattern":"loop%s*=%s*{", "should_match": false},
    {"pattern":"total_loops%s*=%s*{", "should_match": false}
  ]
}
```

> If a task/phase touches `core/*` or `storage/*`, enforce the **stricter cap** ≤ **6 files**, ≤ **300 LOC** (or claim the **mechanical exception** explicitly).

---

## Failure policy (fail-closed)
If Codex can’t meet acceptance (e.g., would exceed budget or parity), it must return `ok:false` with the **failure contract** filled:
- `unmet_exports`: which functions/symbols callers expect but you didn’t provide
- `missing_files`: required paths not found
- `exceeded_budget`: files/loc counts
- `would_touch`: files it *would* need to edit  
No partial patches.

---

## Shapes & coercion (canonical data)
Define/require a canonical sequence shape before engine/coordinator calls. At a minimum:
- `rid: number`
- `item_key: string|nil`
- `loop: number` (≥1)
- `total_loops: number` (≥loop)

**Boundary rule**: coerce with a single call, e.g. `canonicalize_sequence(seq)` or `shapes.canonicalize_sequence(seq)`.  
Greps enforce that we *do* the positive canonicalization and we *don’t* pass tables for numeric fields.

---

## Rollback (workflow)
- Work on `codex/<task-name>` branches.
- Single logical changeset (squash OK).
- Commit title includes the task code.
- Include a short **undo outline** in notes (reverse moves/renames).

---

## Minimal task example (ready to paste)
```json
{
  "task": "refactor_require",
  "from": "RegionPlaylist.app.state",
  "to": "RegionPlaylist.core.state",
  "live_root": "ARKITEKT/scripts",
  "constraints": {
    "allowlist": ["ARKITEKT/scripts/RegionPlaylist"],
    "diff_budget": {"files": 12, "added_loc": 700}
  },
  "acceptance": [
    "No remaining require(...) of moved/deleted modules.",
    "All edited files parse as Lua 5.3.",
    "Patch is idempotent (re-apply = no-op).",
    "No files changed outside declared roots.",
    "Diff budget respected."
  ],
  "proof_grep": [
    {"pattern":"require\([\"']arkitekt\.", "should_match": false},
    {"pattern":"require%([^)]-[\\]", "should_match": false}
  ],
  "notes": "Impacted modules: N files. Caller deltas: import path only. Risks: low. Mitigations: mechanical exception; rollback = revert commit."
}
```

---

## Quick operator checklist (human)
- **Allowlist** minimal and correct?
- **Diff budget** matches scope (core/storage vs app)?
- Need a **parity shim**? Add `@deprecated` + `EXPIRES` + removal phase.
- Include **proof-greps** (namespace, backslashes, purity, canonicalization).
- Clear **rollback** path?

---

**V5 = V4 +** Pipelines: manifest spec, phase conformance rules, runner & CI/Discord contracts, and meta-tasks for authoring/running pipelines — while preserving all V4 safety rails.
