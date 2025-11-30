# Phase 4: Containers API Analysis

**Date:** January 2025
**Branch:** `phase4/containers-api-matching`
**Status:** Analysis complete, awaiting decision

---

## Executive Summary

**Recommendation:** Panel, SlidingZone, and TileGroup should **NOT** adopt the simple callable pattern used for primitives. Instead, they should evolve toward **callback-based APIs** that align with Grid/TreeView patterns.

**Key Insight:** Containers are fundamentally different from primitives:
- **Primitives** (Button, Checkbox) are **single-frame, stateless** → Callable pattern works perfectly
- **Containers** (Panel, Grid) are **multi-frame, stateful, compositional** → Need different patterns

---

## Container Analysis

### 1. Panel

**Current API:**
```lua
local panel = Panel.new("my_panel", { config })
if panel:begin_draw(ctx) then
  -- content
end
panel:end_draw(ctx)
```

**Proposed API** (from `PANEL_REWORK.md`):
```lua
Ark.Panel(ctx, {
  id = "my_panel",

  header = {
    height = 30,
    draw = function(ctx)
      Ark.Button(ctx, { label = "Title" })
      Ark.Spacer(ctx)
    end,
  },

  corner = {
    bottom_right = function(ctx)
      Ark.Button(ctx, { icon = "⚙" })
    end,
  },

  draw = function(ctx)
    -- Main content
    Ark.Grid(ctx, { ... })
  end,
})
```

**Pattern:** Callback-based regions (like Grid's `render` callback)

**Callable Pattern Fit:** ❌ **NO**
- Panel is compositional - contains multiple regions (header, footer, sidebars, corners, content)
- Begin/End pattern necessary for ImGui child window management
- Callbacks allow user to call widgets directly (no config tunneling)
- Result: **Callback-based, not simple callable**

**Recommendation:**
- ✅ Make Panel callable: `Ark.Panel(ctx, opts)`
- ✅ Use callback regions (header.draw, corner.bottom_right, draw)
- ❌ NOT a simple single-call widget like Button
- Status: **Already spec'd in PANEL_REWORK.md - proceed with that design**

---

### 2. SlidingZone

**Current API:**
```lua
SlidingZone.draw(ctx, {
  id = "settings_panel",
  edge = "right",
  bounds = { x, y, w, h },
  size = 200,
  trigger = "hover",

  on_draw = function(ctx, dl, content_bounds, visibility, state)
    -- Draw content here
  end,
})
```

**Proposed API:**
```lua
Ark.SlidingZone(ctx, {
  id = "settings_panel",
  edge = "right",
  bounds = { x, y, w, h },
  size = 200,

  draw = function(ctx, bounds, visibility)
    -- Draw content here
    Ark.Button(ctx, { label = "Settings" })
  end,
})
```

**Pattern:** Callback-based content rendering

**Callable Pattern Fit:** ⚠️ **PARTIAL**
- Already a single-call widget (`SlidingZone.draw()`)
- Uses callback for content (`on_draw`)
- Can adopt callable pattern: `Ark.SlidingZone(ctx, opts)`
- Callback pattern is correct - user provides `draw` callback
- Result: **Make callable + keep callback pattern**

**Recommendation:**
- ✅ Add `__call` metamethod → `Ark.SlidingZone(ctx, opts)`
- ✅ Rename `on_draw` → `draw` (align with Panel convention)
- ✅ Keep single-call pattern (not Begin/End)
- Status: **Simple migration - add callable + rename callback**

---

### 3. TileGroup

**Current API:**
```lua
local groups = {
  TileGroup.create_group({
    id = "group_1",
    name = "Custom Meters",
    items = {item1, item2, item3}
  })
}

-- In Grid's get_items():
function get_items()
  return TileGroup.flatten_groups(groups, ungrouped)
end

-- In Grid's render callback:
function render_tile(ctx, rect, item, state)
  if TileGroup.is_group_header(item) then
    local clicked = TileGroup.render_header(ctx, rect, item, state)
    if clicked then
      TileGroup.toggle_group(item)
    end
  else
    -- Render regular tile
  end
end
```

**Proposed API:**
```lua
-- Same - TileGroup is a data structure helper, not a widget
```

**Pattern:** Utility library (data transformation + helpers)

**Callable Pattern Fit:** ❌ **NOT APPLICABLE**
- TileGroup is not a widget - it's a data structure helper
- Provides functions for organizing Grid items into groups
- Renders headers via `TileGroup.render_header()` (already a function call)
- Result: **Not a widget - no callable pattern needed**

**Recommendation:**
- ✅ Keep current API - it's already well-designed
- ❌ Not a widget - no callable pattern
- ℹ️ Could add `__call` to `render_header` → `TileGroup.Header(ctx, ...)`
- Status: **No changes needed (or optional: make render_header callable)**

---

## Pattern Classification

### Simple Callable (Primitives)
**When:** Single-frame, stateless, simple input/output

**Pattern:**
```lua
if Ark.Button(ctx, "Click").clicked then ... end
```

**Applies to:**
- Button, Checkbox, Slider, InputText, Combo, RadioButton
- Badge, Spinner, ProgressBar, etc.

---

### Callback-Based Callable (Complex Containers)
**When:** Multi-frame, stateful, compositional, user provides content

**Pattern:**
```lua
Ark.Panel(ctx, {
  header = { draw = function(ctx) ... end },
  draw = function(ctx) ... end,
})

Ark.Grid(ctx, {
  items = items,
  render = function(ctx, rect, item) ... end,
})
```

**Applies to:**
- Panel (multiple region callbacks)
- Grid (render callback)
- TreeView (render callback)
- SlidingZone (content callback)

---

### Utility Library (Not Widgets)
**When:** Data transformation, helpers, no direct rendering

**Pattern:**
```lua
local groups = TileGroup.create_group(...)
local flat = TileGroup.flatten_groups(groups, ungrouped)
```

**Applies to:**
- TileGroup (group header is rendered via function, but TileGroup itself is not a widget)
- Math utilities
- Color utilities
- Layout helpers

---

## Phase 4 Recommendations

### Immediate Actions

**1. SlidingZone** - Simple migration
- Add `__call` metamethod
- Rename `on_draw` → `draw` (backward compat: keep `on_draw` as alias)
- Register in `arkitekt/init.lua`
- Update documentation

**2. Panel** - Follow existing spec
- Implement callback regions as spec'd in `PANEL_REWORK.md`
- Add `__call` metamethod
- This is a larger refactor - defer to separate task/branch

**3. TileGroup** - No changes
- Already well-designed
- Not a widget - no callable pattern needed
- Optional: Make `render_header` callable → `TileGroup.Header(ctx, ...)`

---

## Implementation Plan

### Task 1: SlidingZone Callable Pattern ✅ **QUICK WIN**

**Effort:** Low (30 min)
**Impact:** High (consistency with other widgets)

**Changes:**
1. Add `__call` metamethod in `sliding_zone.lua`:
   ```lua
   return setmetatable(M, {
     __call = function(_, ctx, opts)
       return M.draw(ctx, opts)
     end
   })
   ```

2. Add backward-compatible callback rename:
   ```lua
   -- In M.draw():
   opts.draw = opts.draw or opts.on_draw  -- Backward compat
   ```

3. Register in `arkitekt/init.lua`:
   ```lua
   SlidingZone = lazy("gui.widgets.containers.sliding_zone"),
   ```

4. Update PROGRESS.md

---

### Task 2: Panel Callback Regions ⏸️ **DEFER**

**Effort:** High (4-6 hours)
**Impact:** High (major API improvement)

**Why defer:**
- Already fully spec'd in `PANEL_REWORK.md`
- Requires coordinated changes across panel subsystems
- Should be separate branch/PR
- Not blocking other work

**Action:**
- Mark in PROGRESS.md as "Spec complete, implementation deferred"
- Create separate task when ready

---

### Task 3: TileGroup (Optional) ⏸️ **SKIP**

**Effort:** Low
**Impact:** Low (cosmetic improvement only)

**Why skip:**
- TileGroup is not a widget
- Current API is already clean
- No user requests for changes

**Action:**
- Document in PROGRESS.md as "Not applicable - utility library"

---

## Updated Phase 4 Goals

**Original:**
- [ ] Panel - Complex, Begin/End pattern, may not fit
- [ ] SlidingZone - Evaluate
- [ ] TileGroup - Evaluate

**Revised:**
- [x] **SlidingZone** - ✅ Add callable pattern + rename callback → **DO THIS NOW**
- [ ] **Panel** - ✅ Use callback regions (spec'd in PANEL_REWORK.md) → **DEFER**
- [x] **TileGroup** - ❌ Not applicable (utility library) → **NO CHANGES**

---

## Next Steps

1. **Implement SlidingZone callable pattern** (this branch)
2. **Update PROGRESS.md** to reflect Phase 4 status
3. **Merge to dev** once SlidingZone changes are tested
4. **Create separate branch for Panel rework** when ready to tackle it

---

## Appendix: Why Containers Are Different

### Primitives (Button, Checkbox)
- **Single responsibility:** Render one thing
- **Single frame:** No Begin/End
- **No composition:** Don't contain other widgets
- **Simple API:** `Ark.Button(ctx, "Click")`

### Containers (Panel, Grid)
- **Multiple responsibilities:** Header, content, footer, scrolling, etc.
- **Multi-frame:** Begin → content → End (ImGui child windows)
- **Compositional:** Contain other widgets
- **Callback API:** User provides `draw` functions for regions

### The Wrong Approach
```lua
-- DON'T: Try to make Panel a single-call widget
Ark.Panel(ctx, "my_panel")  -- How do you pass content???
```

### The Right Approach
```lua
-- DO: Use callbacks for composition
Ark.Panel(ctx, {
  id = "my_panel",
  draw = function(ctx)
    Ark.Button(ctx, "Click")  -- User calls widgets directly
  end,
})
```

**Callbacks unlock composition** - the user can call any widget inside the callback. No config tunneling, no type indirection, just clean code.

---

## Conclusion

**Phase 4 is not about making all containers "callable like Button."**

It's about:
1. ✅ Making containers callable (`Ark.Panel()` not `Panel.draw()`)
2. ✅ Using callbacks for composition (not config tunneling)
3. ✅ Consistency with Grid/TreeView patterns

**SlidingZone** is ready now. **Panel** needs more work but is already spec'd. **TileGroup** doesn't need changes.
