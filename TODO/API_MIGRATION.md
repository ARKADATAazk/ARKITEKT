# API Migration: Callable Widget Pattern

> **Goal**: All widgets use `Ark.Widget(ctx, opts)` - no `.draw()`, no `.draw_at_cursor()`
> **Secondary**: Use `Ark.*` for all widgets/utilities instead of direct `require()`

---

## Target API

```lua
-- Callable pattern (CORRECT)
local result = Ark.Button(ctx, "Save")                    -- positional: label
local result = Ark.Button(ctx, "Save", 100)               -- positional: label, width
local result = Ark.Button(ctx, { label = "Save", preset = "primary" })  -- opts

local result = Ark.Checkbox(ctx, { checked = value, label = "Enable" })
if result.changed then value = result.checked end

-- WRONG - kill these:
Ark.Button.draw(ctx, { ... })
Ark.Button.draw_at_cursor(ctx, { ... })
Ark.Checkbox.draw_at_cursor(ctx, "", checked, nil, id)
```

---

## Cursor Philosophy

**Prefer native ImGui layout over absolute positioning.**

```lua
-- GOOD: Use ImGui layout
Ark.Button(ctx, "Save")
ImGui.SameLine(ctx)
Ark.Button(ctx, "Cancel")

-- AVOID: Manual x, y unless truly needed
Ark.Button(ctx, { label = "Save", x = 100, y = 50 })
```

When to use `x, y`:
- Custom drawing overlays
- Absolute-positioned elements (floating buttons, etc.)
- Grid cell rendering (already positioned by grid)

---

## Migration Status

### Core Widgets (DONE)

| Widget | Callable | Positional | Opts | Result Object |
|--------|----------|------------|------|---------------|
| Button | YES | `(ctx, label, width)` | YES | `{ clicked, hovered, ... }` |
| Checkbox | YES | NO | YES | `{ changed, checked, ... }` |
| Combo | YES | NO | YES | `{ changed, value, ... }` |
| Spinner | YES | NO | YES | `{ changed, value, ... }` |

### Scripts Migration

| App | `draw_at_cursor` | `.draw()` | Status |
|-----|------------------|-----------|--------|
| ThemeAdjuster | 30+ | 20+ | NOT STARTED |
| TemplateBrowser | 20+ | 15+ | NOT STARTED |
| WalterBuilder | 0 | 20+ | NOT STARTED |
| RegionPlaylist | 0 | 5+ | NOT STARTED |
| ItemPicker | 0 | 5+ | NOT STARTED |
| ProductionPanel | 0 | 3+ | NOT STARTED |
| Demos/Sandbox | varies | varies | LOW PRIORITY |

---

## Migration Checklist

### Per-File Process

1. Find all `.draw_at_cursor` and `.draw(ctx,` calls
2. Convert to callable: `Ark.Widget(ctx, opts)`
3. Update return handling: `if result.clicked` / `if result.changed`
4. Test the view/component
5. Mark done

### After All Scripts Done

- [ ] Remove `draw_at_cursor` shims from primitives
- [ ] Remove `M.draw` exports (keep only `__call`)
- [ ] Update cookbook/WIDGETS.md examples
- [ ] Update cookbook/API_DESIGN_PHILOSOPHY.md examples

---

## Quick Reference: Old → New

### Button
```lua
-- OLD
if Ark.Button.draw_at_cursor(ctx, { label = "Save" }) then

-- NEW
if Ark.Button(ctx, "Save") then
-- or
local result = Ark.Button(ctx, { label = "Save", preset = "primary" })
if result.clicked then
```

### Checkbox
```lua
-- OLD
if Ark.Checkbox.draw_at_cursor(ctx, "Enable", is_checked, nil, "my_id") then
  is_checked = not is_checked
end

-- NEW
local result = Ark.Checkbox(ctx, { label = "Enable", checked = is_checked, id = "my_id" })
if result.changed then
  is_checked = result.checked
end
```

### Combo
```lua
-- OLD
local changed, new_idx = Ark.Combo.draw(ctx, { ... })

-- NEW
local result = Ark.Combo(ctx, { items = items, selected = idx })
if result.changed then
  idx = result.selected
end
```

---

## Order of Attack

1. **ThemeAdjuster** - most calls, highest impact
2. **TemplateBrowser** - second most
3. **WalterBuilder** - moderate
4. **RegionPlaylist** - light
5. **ItemPicker** - light
6. **Others** - as encountered

---

## Direct Requires to Migrate

Scripts should use `Ark.*` instead of direct requires for widgets/UI utilities:

```lua
-- OLD
local Button = require('arkitekt.gui.widgets.primitives.button')
local Background = require('arkitekt.gui.draw.patterns')

-- NEW
-- Just use Ark.Button, Ark.Pattern directly (Ark is already in scope)
```

**Keep direct require** (domain/core utilities - no Ark exposure needed):
- `Settings`, `JSON`, `Fs`, `Sorting`, `Unicode`, `Duration`, `UndoManager`

**Migrate to Ark** (widgets and UI utilities):
- All widgets: `Button`, `Checkbox`, `Slider`, `Chip`, `Panel`, etc.
- Drawing: `Pattern`, `Shapes`, `TransportIcons`
- UI utils: `Colors`, `Theme`, `ThemeManager`

---

## Notes

- Solo dev = no shim period needed
- Kill old methods after migration complete
- Grid renderers already use new pattern (mostly)
