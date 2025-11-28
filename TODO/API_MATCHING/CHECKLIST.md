# API Matching Checklist

> **Progress tracker for the API migration**

---

## Phase 1: Core Widgets

### Button
- [ ] Add `__call` metamethod
- [ ] Add hybrid parameter detection
- [ ] Test positional: `Ark.Button(ctx, "OK")`
- [ ] Test positional+size: `Ark.Button(ctx, "OK", 100, 30)`
- [ ] Test opts: `Ark.Button(ctx, {label = "OK"})`
- [ ] Hide `measure()` (make local)
- [ ] Hide `cleanup()` (make local)
- [ ] Remove `draw_at_cursor()`

### Checkbox
- [ ] Add `__call` metamethod
- [ ] Add hybrid parameter detection
- [ ] Test positional: `Ark.Checkbox(ctx, "Enable", true)`
- [ ] Test opts: `Ark.Checkbox(ctx, {label = "Enable", checked = true})`
- [ ] Hide internal functions

### Slider
- [ ] Add `__call` metamethod
- [ ] Add hybrid parameter detection
- [ ] Test positional: `Ark.Slider(ctx, "Volume", 50, 0, 100)`
- [ ] Test opts: `Ark.Slider(ctx, {label = "Volume", value = 50, min = 0, max = 100})`
- [ ] Hide internal functions

### InputText
- [ ] Add `__call` metamethod
- [ ] Add hybrid parameter detection
- [ ] Test positional: `Ark.InputText(ctx, "Name", text)`
- [ ] Test opts: `Ark.InputText(ctx, {label = "Name", text = text})`
- [ ] Hide internal functions

### Combo
- [ ] Add `__call` metamethod
- [ ] Add hybrid parameter detection
- [ ] Test positional: `Ark.Combo(ctx, "Theme", 1, {"Light", "Dark"})`
- [ ] Test opts: `Ark.Combo(ctx, {label = "Theme", selected = 1, items = {...}})`
- [ ] Hide internal functions

---

## Phase 2: Other Primitives

- [ ] RadioButton
- [ ] Badge
- [ ] Spinner
- [ ] LoadingSpinner
- [ ] ProgressBar
- [ ] HueSlider
- [ ] Scrollbar
- [ ] Splitter
- [ ] CornerButton
- [ ] CloseButton
- [ ] MarkdownField

---

## Phase 3: Containers

- [ ] Panel - evaluate if callable makes sense
- [ ] SlidingZone - evaluate if callable makes sense
- [ ] TileGroup - evaluate if callable makes sense

---

## Phase 4: Script Migration

### RegionPlaylist
- [ ] Update all widget calls
- [ ] Test functionality
- [ ] Remove `.draw` calls

### ItemPicker
- [ ] Update all widget calls
- [ ] Test functionality
- [ ] Remove `.draw` calls

### ThemeAdjuster
- [ ] Update all widget calls
- [ ] Test functionality
- [ ] Remove `.draw` calls

### TemplateBrowser
- [ ] Update all widget calls
- [ ] Test functionality
- [ ] Remove `.draw` calls

### Sandbox
- [ ] Update all widget calls
- [ ] Test functionality

---

## Phase 5: Documentation

- [ ] Update CLAUDE.md examples
- [ ] Update cookbook/QUICKSTART.md
- [ ] Update cookbook/WIDGETS.md
- [ ] Update API_DESIGN_PHILOSOPHY.md
- [ ] Remove/archive old HYBRID_API.md (merged into this folder)

---

## Phase 6: Cleanup

- [ ] Remove backward compatibility shims (if any)
- [ ] Final audit of exposed functions
- [ ] Performance test (table allocation overhead)

---

## Notes

### Widgets That May Not Need Callable
Some widgets use Begin/End pattern and may not benefit from callable:
- Panel (uses Begin/End internally?)
- Containers in general

Evaluate case by case.

### Backward Compatibility Period
During migration, both work:
```lua
Ark.Button(ctx, "OK")           -- New (callable)
Ark.Button.draw(ctx, {label="OK"})  -- Old (still works)
```

Remove old pattern after all scripts migrated.
