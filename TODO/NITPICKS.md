# Nitpicks - Trivial Migrations & Micro-Duplications

> Quick wins that can each be fixed in under 10 minutes.
> These are low-hanging fruit for cleanup when touching nearby code.

---

## Trivial Migrations (Copy → Require)

### 1. Easing Functions
**Files**: 2 | **Effort**: < 5 min each

| File | Change |
|------|--------|
| `gui/widgets/media/media_grid/renderers/base.lua:18-22` | Delete local `ease_out_back()`, add `local Easing = require('arkitekt.gui.animation.easing')` |
| `ItemPicker/ui/grids/renderers/base.lua:25-29` | Same |

**Before:**
```lua
local function ease_out_back(t)
  local c1 = 1.70158
  local c3 = c1 + 1
  return 1 + c3 * (t - 1)^3 + c1 * (t - 1)^2
end
```

**After:**
```lua
local Easing = require('arkitekt.gui.animation.easing')
-- Use Easing.ease_out_back(t) instead
```

---

### 2. UUID Generation
**Files**: 1 | **Effort**: < 5 min

| File | Change |
|------|--------|
| `TemplateBrowser/infra/storage.lua:52-60` | Delete local `generate_uuid()`, add `local UUID = require('arkitekt.core.uuid')`, use `UUID.generate()` |

---

### 3. JSON Encode/Decode
**Files**: 1 | **Effort**: ~15 min (larger file)

| File | Change |
|------|--------|
| `TemplateBrowser/infra/storage.lua:62-190` | Delete local JSON functions (~130 lines), add `local JSON = require('arkitekt.core.json')` |

**Note**: TemplateBrowser uses pretty-printed JSON. If needed, add pretty-print to core/json.lua first.

---

### 4. Color Lerp
**Files**: 3 | **Effort**: < 5 min each

| File | Change |
|------|--------|
| `ThemeAdjuster/ui/grids/renderers/tile_visuals.lua:134-155` | Use `Colors.lerp()` from `arkitekt.core.colors` |
| `RegionPlaylist/ui/views/transport/button_widgets.lua:114` | Use `Colors.lerp()` |
| `RegionPlaylist/ui/views/transport/transport_container.lua:172` | Use `Colors.lerp()` |

---

### 5. Math Lerp/Clamp
**Files**: 2 | **Effort**: < 5 min each

| File | Change |
|------|--------|
| `ThemeAdjuster/ui/grids/renderers/tile_visuals.lua:153` | Use `Math.lerp()` from `arkitekt.core.math` |
| `scripts/demos/widget_demo.lua:64` | Use `Math.clamp()` |

---

### 6. Path Join (Demos)
**Files**: 5 | **Effort**: < 3 min each

All demos duplicate this pattern:
```lua
local function join(a,b)
  local s=package.config:sub(1,1)
  return (a:sub(-1)==s) and (a..b) or (a..s..b)
end
```

| File |
|------|
| `scripts/demos/demo.lua:35` |
| `scripts/demos/demo_modal_overlay.lua:37` |
| `scripts/demos/demo2.lua:36` |
| `scripts/demos/demo3.lua:36` |
| `scripts/demos/widget_demo.lua:45` |

**Fix**: When file_utils.lua is extracted, import `File.join()` from there.

---

## Cascade Animation Consolidation

**Files**: 2 | **Effort**: ~10 min

Both have identical `calculate_cascade_factor()`:
- `gui/widgets/media/media_grid/renderers/base.lua:25-44`
- `ItemPicker/ui/grids/renderers/base.lua:32-51`

**Option A**: ItemPicker imports from media_grid
```lua
local MediaGridBase = require('arkitekt.gui.widgets.media.media_grid.renderers.base')
-- Use MediaGridBase.calculate_cascade_factor()
```

**Option B**: Extract to `arkitekt/gui/animation/cascade.lua`

---

## Duration Formatting

**Files**: 3+ | **Effort**: ~20 min (create new module)

Multiple scripts format `seconds → "HH:MM:SS"`:
- `RegionPlaylist/ui/views/transport/display_widget.lua:166`
- `ItemPicker/ui/grids/renderers/audio.lua:519-667`
- `ItemPicker/ui/grids/renderers/midi.lua:516-520`

**Proposed**: Create `arkitekt/core/duration.lua`

---

## Checklist Format

Use this when doing cleanup:

- [x] `ease_out_back` in media_grid/renderers/base.lua
- [x] `ease_out_back` in ItemPicker/ui/grids/renderers/base.lua
- [x] `generate_uuid` in TemplateBrowser/infra/storage.lua
- [x] `json_encode/decode` in TemplateBrowser/infra/storage.lua
- [x] `color_lerp` in tile_visuals.lua
- [x] `lerp_color` in button_widgets.lua
- [x] `lerp_color` in transport_container.lua
- [x] `lerp` in tile_visuals.lua (scalar)
- [x] `clamp` in widget_demo.lua
- [x] `join` in demo.lua
- [x] `join` in demo_modal_overlay.lua
- [x] `join` in demo2.lua
- [x] `join` in demo3.lua
- [x] `join` in widget_demo.lua
- [x] `calculate_cascade_factor` consolidation
- [ ] Duration formatting extraction

---

*Created: 2025-11-27*
