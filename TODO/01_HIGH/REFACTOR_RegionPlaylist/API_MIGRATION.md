# RegionPlaylist Migration TODO

> **Goal:** Align RegionPlaylist with API decisions (currently ~70% compliant)

---

## Priority 1: Color Migration (Decision 15)

**Problem:** 75% of colors are hardcoded hex values

### Files to Update

#### `ui/tiles/renderers/pool.lua`
```lua
-- BEFORE (hardcoded)
M.CONFIG = {
  bg_base = Ark.Colors.hexrgb("#1A1A1A"),
  playlist_tile = {
    base_color = Ark.Colors.hexrgb("#3A3A3A"),
    name_color = Ark.Colors.hexrgb("#CCCCCC"),
    badge_color = Ark.Colors.hexrgb("#999999")
  },
}

-- AFTER (theme-reactive)
M.CONFIG = {
  bg_base = nil,  -- Falls back to Theme.COLORS.BG_PANEL
  playlist_tile = {
    base_color = nil,   -- Theme.COLORS.PLAYLIST_TILE_COLOR
    name_color = nil,   -- Theme.COLORS.PLAYLIST_NAME_COLOR
    badge_color = nil,  -- Theme.COLORS.PLAYLIST_BADGE_COLOR
  },
}
```

#### `defs/palette.lua`
- Move custom colors to `arkitekt/defs/colors/theme.lua` if reusable
- Keep script-specific colors in palette with snap/lerp DSL

### Tasks
- [ ] Audit all `hexrgb("#...")` calls in RegionPlaylist
- [ ] Replace with `Theme.COLORS.*` or `nil` fallback
- [ ] Add missing colors to theme.lua if needed
- [ ] Test with dark, light, and adapt modes

---

## Priority 2: Widget Migration (Decisions 2, 3, 4)

**Problem:** Custom button classes instead of Ark.Button

### Files to Update

#### `ui/views/transport/button_widgets.lua`
```lua
-- BEFORE (custom class)
local ViewModeButton = {}
ViewModeButton.__index = ViewModeButton
function ViewModeButton:draw(ctx, dl, x, y, w, h)
  -- 100+ lines of custom drawing
end

-- AFTER (use Ark.Button)
local result = Ark.Button(ctx, {
  label = "",
  preset = "toggle_white",
  is_toggled = state.is_playing,
  custom_draw = TransportIcons.draw_play,
  tooltip = Strings.TRANSPORT.play,
  on_click = handle_play,
})
```

### Tasks
- [ ] Replace `ViewModeButton` with `Ark.Button` + `custom_draw`
- [ ] Replace `SimpleToggleButton` with `Ark.Button` + `preset`
- [ ] Update to `.clicked` result pattern
- [ ] Remove custom button class files (after migration)

---

## Priority 3: API Syntax (Decisions 2, 11)

**Problem:** Uses `.draw()` and vertical advance

### After Framework Updates
```lua
-- BEFORE
Button.draw(ctx, opts)

-- AFTER (callable)
Ark.Button(ctx, opts)

-- BEFORE (vertical default)
advance = "vertical"

-- AFTER (horizontal default, matching ImGui)
-- No change needed if horizontal is desired
```

### Tasks
- [ ] Wait for framework callable modules implementation
- [ ] Update all widget calls to new syntax
- [ ] Review advance settings (most should use new horizontal default)

---

## Priority 4: Preset Standardization (Decision 15)

**Problem:** Uses `preset_name` string, should be simpler `preset`

### Files to Update
```lua
-- BEFORE
preset_name = "BUTTON_TOGGLE_WHITE"

-- AFTER
preset = "toggle_white"
```

### Tasks
- [ ] Rename `preset_name` to `preset` in all configs
- [ ] Use lowercase preset names (framework normalizes)
- [ ] Remove any remaining raw color overrides

---

## Migration Checklist

### Phase 1: Colors (Can Do Now)
- [ ] pool.lua - Replace hardcoded hex
- [ ] active.lua - Replace hardcoded hex
- [ ] base.lua - Replace hardcoded hex
- [ ] Test all theme modes (dark/light/adapt)

### Phase 2: Widgets (After Framework Update)
- [ ] Migrate ViewModeButton → Ark.Button
- [ ] Migrate SimpleToggleButton → Ark.Button
- [ ] Update result handling to `.clicked`

### Phase 3: Syntax (After Framework Update)
- [ ] Update to callable `Ark.Button()` syntax
- [ ] Review cursor advance settings

---

## Files Inventory

| File | Issues | Priority |
|------|--------|----------|
| `ui/tiles/renderers/pool.lua` | Hardcoded hex colors | High |
| `ui/tiles/renderers/active.lua` | Hardcoded hex colors | High |
| `ui/tiles/renderers/base.lua` | Hardcoded hex colors | High |
| `ui/views/transport/button_widgets.lua` | Custom button classes | Medium |
| `ui/views/transport/transport_view.lua` | preset_name syntax | Low |
| `defs/defaults.lua` | Some hardcoded colors | Medium |

---

## Success Criteria

After migration:
- [ ] No `hexrgb("#...")` except in defs/palette.lua DSL
- [ ] No custom button/widget classes
- [ ] All buttons use `Ark.Button()` with `preset`
- [ ] Works correctly in dark, light, and adapt modes
- [ ] Score: 95%+ on API decisions compliance
