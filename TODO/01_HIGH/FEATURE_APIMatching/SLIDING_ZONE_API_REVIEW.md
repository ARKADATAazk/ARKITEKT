# SlidingZone API Review

**Purpose:** Review parameter naming for clarity and consistency

---

## Current API (25 parameters)

### Clear & Good ✅

| Parameter | Purpose | Status |
|-----------|---------|--------|
| `id` | Widget ID | ✅ Clear |
| `edge` | Which edge ("left", "right", "top", "bottom") | ✅ Clear |
| `bounds` | Container area | ✅ Clear |
| `size` | Panel width/height when expanded | ✅ Clear |
| `bg_color` | Background color | ✅ Clear |
| `rounding` | Corner rounding | ✅ Clear |
| `clip_content` | Clip drawing to bounds | ✅ Clear |
| `trigger` | Trigger mode ("hover", "button", "always") | ✅ Clear |
| `draw` | Content draw callback | ✅ Clear (new name) |
| `on_expand` | Callback when expanding | ✅ Clear |
| `on_collapse` | Callback when collapsing | ✅ Clear |

---

### Confusing or Poorly Named ⚠️

| Parameter | Current Name | Issue | Better Name? |
|-----------|--------------|-------|--------------|
| `min_visible` | min_visible | ⚠️ Percentage/ratio (0.0-1.0) not obvious | `collapsed_ratio`? |
| `slide_distance` | slide_distance | ⚠️ What does it control? | `slide_offset`? |
| `animation_speed` | animation_speed | ⚠️ Which animation? | `fade_speed`? |
| `slide_speed` | slide_speed | ✅ OK but confusing with slide_distance | Keep |
| `scale_speed` | scale_speed | ⚠️ What scales? | `expand_speed`? (if expand_scale is used) |
| `retract_delay` | retract_delay | ✅ OK | Keep |
| `directional_delay` | directional_delay | ⚠️ Boolean, what does it enable? | `directional_retract`? |
| `retract_delay_toward` | retract_delay_toward | ⚠️ Toward what? | `retract_delay_inward`? |
| `retract_delay_away` | retract_delay_away | ⚠️ Away from what? | `retract_delay_outward`? |
| `hover_extend_outside` | hover_extend_outside | ⚠️ Outside what? | `trigger_extension`? |
| `hover_padding` | hover_padding | ⚠️ Padding for what? | ❓ Not used? |
| `expand_scale` | expand_scale | ⚠️ Not commonly used (usually 1.0) | Keep but document |
| `content_bounds` | content_bounds | ⚠️ How different from bounds? | ❓ Needs clarification |
| `window_bounds` | window_bounds | ✅ Clear (for cursor tracking) | Keep |

---

### Dead/Deprecated ❌

| Parameter | Status | Action |
|-----------|--------|--------|
| `on_draw` | ❌ Deprecated (use `draw`) | Keep for backward compat |
| `hover_extend_inside` | ❌ Dead (only used in dead code) | **Remove** |
| `draw_list` | ⚠️ Rarely needed (can get from ctx) | Keep but document |

---

## Specific Issues

### 1. `min_visible` is confusing

**Current:**
```lua
min_visible = 0.08  -- What does this mean?
```

**Problem:** Not obvious this is a ratio (0.0-1.0) representing "collapsed_width / expanded_width"

**Better name:**
```lua
collapsed_ratio = 0.08  -- 8% of full size when collapsed
-- OR
min_visibility = 0.08  -- Clearer this is 0.0-1.0 range
```

---

### 2. `slide_distance` vs `slide_speed`

**Current:**
```lua
slide_distance = 20  -- Pixels to slide during reveal animation
slide_speed = 6.0    -- Animation speed for sliding
```

**Problem:** "distance" and "speed" are confusing together

**Better names:**
```lua
slide_offset = 20    -- Offset added during animation
slide_speed = 6.0    -- Animation speed
```

---

### 3. Animation speeds are generic

**Current:**
```lua
animation_speed = 5.0  -- Which animation?
slide_speed = 6.0
scale_speed = 6.0
```

**Better names:**
```lua
fade_speed = 5.0      -- Visibility fade in/out
slide_speed = 6.0     -- Slide offset animation
expand_speed = 6.0    -- Scale expansion (if expand_scale > 1.0)
```

---

### 4. Directional delay naming

**Current:**
```lua
directional_delay = false       -- What does this enable?
retract_delay_toward = 1.0      -- Toward what?
retract_delay_away = 0.1        -- Away from what?
```

**Better names:**
```lua
directional_retract = false     -- Enable direction-aware retract timing
retract_delay_inward = 1.0      -- When exiting toward panel (longer delay)
retract_delay_outward = 0.1     -- When exiting away from panel (shorter delay)
```

---

### 5. `hover_extend_outside` is unclear

**Current:**
```lua
hover_extend_outside = 6  -- Extend hover zone outside bounds
```

**Problem:** "outside bounds" - outside what bounds? The collapsed bar?

**Better name:**
```lua
trigger_extension = 6  -- Pixels beyond collapsed bar to trigger expansion
```

---

### 6. `hover_padding` - Not used?

**Current:**
```lua
hover_padding = 30  -- Padding around content area for hover
```

**Usage:** Only used in Y-axis range checks for left/right edges

**Question:** Is this actually needed? Or can we remove it?

---

### 7. `content_bounds` vs `bounds`

**Current:**
```lua
bounds = {...}          -- Container area
content_bounds = {...}  -- Optional: specific area for content (for hover calc)
```

**Problem:** When would you use this? Not documented

**Clarification needed:** Is this for when the content area is smaller than the bounds?

---

## Proposed API Changes

### Breaking Changes (Major Version)

If we want to improve naming significantly:

```lua
-- BEFORE (current)
Ark.SlidingZone(ctx, {
  min_visible = 0.08,
  slide_distance = 20,
  animation_speed = 5.0,
  slide_speed = 6.0,
  scale_speed = 6.0,
  directional_delay = true,
  retract_delay_toward = 1.0,
  retract_delay_away = 0.1,
  hover_extend_outside = 6,
  hover_padding = 30,
})

-- AFTER (proposed)
Ark.SlidingZone(ctx, {
  collapsed_ratio = 0.08,      -- Clearer: 8% of full size
  slide_offset = 20,           -- Clearer: offset during animation
  fade_speed = 5.0,            -- Clearer: visibility fade
  slide_speed = 6.0,           -- Same
  expand_speed = 6.0,          -- Clearer: scale expansion speed
  directional_retract = true,  -- Clearer: direction-aware retract
  retract_inward = 1.0,        -- Clearer: toward panel
  retract_outward = 0.1,       -- Clearer: away from panel
  trigger_extension = 6,       -- Clearer: trigger zone extension
  -- hover_padding removed (not essential)
})
```

---

### Non-Breaking Improvements (Keep Current Names)

If we want to avoid breaking changes, just improve documentation:

```lua
local DEFAULTS = {
  -- Size & Visibility
  size = 40,                    -- Expanded panel width (left/right) or height (top/bottom)
  min_visible = 0.0,            -- Collapsed size as ratio of full size (0.0-1.0)
                                -- Example: 0.08 = 8% visible when collapsed

  -- Animation
  slide_distance = 20,          -- Offset (in pixels) added during slide animation
  animation_speed = 5.0,        -- Speed of visibility fade (0.0 = instant, higher = slower transition)
  slide_speed = 6.0,            -- Speed of slide offset animation
  scale_speed = 6.0,            -- Speed of scale expansion (if expand_scale > 1.0)

  -- Retract Timing
  retract_delay = 0.3,          -- Delay before retracting (seconds)
  directional_delay = false,    -- Enable direction-aware retract delays
  retract_delay_toward = 1.0,   -- Delay when exiting toward panel edge (inward motion)
  retract_delay_away = 0.1,     -- Delay when exiting away from panel (outward motion)

  -- Trigger Zone
  hover_extend_outside = 6,     -- Pixels beyond collapsed bar to extend trigger zone
                                -- Example: 12px bar + 6px = 18px trigger zone

  -- Advanced
  hover_padding = 30,           -- Y-axis padding for hover detection (left/right edges)
  content_bounds = nil,         -- Override content area for hover calculation
                                -- (rarely needed - use when content is smaller than bounds)

  -- Deprecated
  hover_extend_inside = 50,     -- DEPRECATED: Not used in current implementation
}
```

---

## Dead Code to Remove

```lua
-- Remove these:
hover_extend_inside = 50,  -- Only used in crossed_toward_edge() (never called)

-- And the function:
local function crossed_toward_edge(...)  -- Dead function, never called
```

---

## Recommendations

### Short Term (No Breaking Changes)
1. ✅ Improve inline comments (make clear what values mean)
2. ✅ Remove `hover_extend_inside` (dead parameter)
3. ✅ Remove `crossed_toward_edge()` (dead function)
4. ✅ Document `content_bounds` use case (or remove if not needed)
5. ✅ Document `hover_padding` use case (or simplify)

### Long Term (Breaking Changes OK)
1. Rename confusing parameters:
   - `min_visible` → `collapsed_ratio`
   - `slide_distance` → `slide_offset`
   - `animation_speed` → `fade_speed`
   - `scale_speed` → `expand_speed`
   - `directional_delay` → `directional_retract`
   - `retract_delay_toward/away` → `retract_inward/outward`
   - `hover_extend_outside` → `trigger_extension`

2. Add deprecation shims for old names
3. Update all usages in codebase

---

## Final Assessment

**Is our API good?**

**Current state:** ⚠️ **Functional but confusing**
- Works well
- Some parameter names are unclear
- Some dead code
- Documentation could be better

**After cleanup:** ✅ **Good**
- Remove dead code
- Improve documentation
- Consider renaming in future (non-urgent)

---

## Action Items

**Priority 1 (Do Now):**
- [ ] Remove `hover_extend_inside` parameter (dead)
- [ ] Remove `crossed_toward_edge()` function (dead)
- [ ] Improve inline comments for confusing parameters
- [ ] Document `content_bounds` use case

**Priority 2 (Consider Later):**
- [ ] Rename confusing parameters (breaking change)
- [ ] Add deprecation shims for old names
- [ ] Create migration guide

**Priority 3 (Nice to Have):**
- [ ] Investigate if `hover_padding` is essential
- [ ] Investigate if `expand_scale` is used anywhere
- [ ] Consider simplifying trigger zone logic
