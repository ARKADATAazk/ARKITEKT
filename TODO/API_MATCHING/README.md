# API Matching Roadmap

> **Goal:** Make `Ark.*` feel like `ImGui.*` while improving where it matters.

---

## Summary of Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Namespace** | `Ark.Button()`, `ImGui.SameLine()` | Two namespaces - Ark for widgets, ImGui for utilities |
| **Calling convention** | `Ark.Button()` not `Ark.Button.draw()` | Match ImGui, remove `.draw` |
| **Parameters** | Hybrid: positional AND opts | Easy migration + power when needed |
| **Return values** | Result object | Richer than boolean, still works inline |
| **Public API** | Minimal | Hide cleanup, measure, internals |
| **Hover animations** | Keep (strong tables) | Smooth UX, automatic cleanup |
| **ImGui flags** | Convert to boolean opts | `password = true` not `InputTextFlags_Password` |
| **Chrome options** | Positive naming (`titlebar = true`) | Avoid double negatives |
| **Shell** | Keep & extend | Real value: lifecycle, chrome, themes |
| **Unified namespace** | `Ark.Theme`, `Ark.Shell` | One namespace for framework |
| **Shell persistence** | ✅ Already implemented | Overrides ImGui .ini, supports maximize |

---

## The Target API

```lua
-- Simple (ImGui-familiar, fast migration)
if Ark.Button(ctx, "Click").clicked then
  do_something()
end

Ark.Button(ctx, "Save", 100, 30)  -- With size

-- Complex (when you need power)
Ark.Button(ctx, {
  label = "Submit",
  disabled = not form.valid,
  tooltip = "Submit the form",
  on_click = submit,
})

-- ImGui utilities stay as ImGui
ImGui.SameLine(ctx)
ImGui.Separator(ctx)
local w = ImGui.CalcTextSize(ctx, text)
```

---

## Files in This Folder

### Core Documentation

| File | Description |
|------|-------------|
| [WHAT_IS_ARKITEKT.md](WHAT_IS_ARKITEKT.md) | Framework identity: UI Toolkit = Framework + Design System + Components |
| [DECISIONS.md](DECISIONS.md) | Detailed rationale for each design choice (19 decisions) |
| [SCOPE.md](SCOPE.md) | What gets `Ark.*` vs stays `ImGui.*` |
| [WIDGET_SIGNATURES.md](WIDGET_SIGNATURES.md) | ImGui → Ark signature mappings for each widget |
| [FLAGS_TO_OPTS.md](FLAGS_TO_OPTS.md) | ImGui bitwise flags → ARKITEKT opts mapping (InputText only) |

### Implementation Guides

| File | Description |
|------|-------------|
| [IMPLEMENTATION.md](IMPLEMENTATION.md) | Step-by-step implementation guide |
| [PHASING.md](PHASING.md) | Phased rollout plan with decision tracking |
| [GUARDRAILS.md](GUARDRAILS.md) | Panel/Button context injection for auto-styling |
| [CHECKLIST.md](CHECKLIST.md) | Progress tracker for migration |

### Feature-Specific Reworks

| File | Description |
|------|-------------|
| [SHELL.md](SHELL.md) | Shell features: what's done vs what to add |
| [PANEL_REWORK.md](PANEL_REWORK.md) | Panel callback regions + context injection spec |
| [GRID_REWORK.md](GRID_REWORK.md) | Grid widget simplification and API alignment |

---

## Quick Comparison

### Before (Current ARKITEKT)
```lua
-- Verbose, unfamiliar
local result = Ark.Button.draw(ctx, {label = "OK", width = 100})
if result.clicked then ... end

-- Unnecessary public API
Ark.Button.measure(ctx, opts)
Ark.Button.cleanup()
Ark.Button.draw_at_cursor(ctx, opts)
```

### After (Target ARKITEKT)
```lua
-- Clean, ImGui-familiar
if Ark.Button(ctx, "OK", 100).clicked then ... end

-- Or with opts when needed
if Ark.Button(ctx, {label = "OK", on_click = handler}).clicked then ... end

-- No exposed internals
-- measure/cleanup/draw_at_cursor are internal
```

---

## Implementation Priority

### Phase 1: Core Pattern (Do First)
1. Make modules callable (`__call` metamethod)
2. Add hybrid parameter detection
3. Remove `.draw` from public usage
4. Update documentation

### Phase 2: Apply to All Widgets
- [ ] Button
- [ ] Checkbox
- [ ] InputText
- [ ] Slider
- [ ] Combo
- [ ] RadioButton
- [ ] (others...)

### Phase 3: Cleanup
- [ ] Hide `cleanup()` functions
- [ ] Hide `measure()` functions
- [ ] Remove `draw_at_cursor()` wrappers
- [ ] Update all scripts to new API

---

## Non-Goals

Things we're NOT doing:

1. **Wrapping ImGui utilities** - `ImGui.SameLine()` stays as-is, no `Ark.SameLine()`
2. **Removing opts support** - Power users still get full opts tables
3. **Breaking existing code** - Old `.draw()` syntax will work during transition
4. **Matching ImGui exactly** - We improve where it makes sense (callbacks, tooltips, etc.)

---

## References

- [API_DESIGN_PHILOSOPHY.md](../../cookbook/API_DESIGN_PHILOSOPHY.md)
- [IMGUI_API_COVERAGE.md](../IMGUI_API_COVERAGE.md)
- [HYBRID_API.md](../HYBRID_API.md) (older version, to be merged here)
