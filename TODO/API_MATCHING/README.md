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

| File | Description |
|------|-------------|
| [DECISIONS.md](DECISIONS.md) | Detailed rationale for each design choice |
| [WIDGET_SIGNATURES.md](WIDGET_SIGNATURES.md) | ImGui → Ark signature mappings for each widget |
| [IMPLEMENTATION.md](IMPLEMENTATION.md) | Step-by-step implementation guide |
| [CHECKLIST.md](CHECKLIST.md) | Progress tracker for migration |

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
