# SlidingZone Migration Analysis

**Can we replace manual sliding patterns with SlidingZone?**

---

## Current Manual Patterns

### 1. SettingsPanel (Top Edge - Slides Down from Above)

**Trigger:** Hover above search bar OR exit window through top
**Behavior:** Slides down from hidden position above search
**Retract:** 1.5s delay when leaving window

```lua
-- Trigger zone
is_in_trigger_zone = mouse_y < (search_y - trigger_zone_padding)
crossed_through_top = exited_window_upward

-- Animation
settings_slide_progress = lerp(progress, target, slide_speed)
settings_y = search_base_y - max_height + (max_height * progress)

// Hidden:  y = search_y - max_height (above, off-screen)
// Visible: y = search_y (just above search bar)
```

**Special Features:**
- ✅ "Crossed through top" detection (window_bounds)
- ✅ Retract delay (retract_delay)
- ⚠️ Close when hovering below search bar (custom logic)
- ⚠️ Sticky visible (stays open after trigger)

---

### 2. RegionFilter (Top Edge - Slides Down from Above)

**Trigger:** Hover above panels OR settings visible
**Behavior:** Slides down from hidden position
**Retract:** Immediate when leaving trigger zone

```lua
// Trigger zone
is_hovering_above_panels = mouse_y < (panels_start_y + trigger_padding)
filters_should_show = is_hovering_above_panels OR settings_visible

// Animation
filter_slide_progress = lerp(progress, target, slide_speed)
filter_height = max_height * progress

// Position
// Hidden:  height = 0
// Visible: height = max_height (slides down)
```

**Special Features:**
- ✅ Trigger zone (simple Y threshold)
- ✅ Chained visibility (shows when settings shows)
- ⚠️ No retract delay
- ⚠️ Height-based (not position-based)

---

## Can SlidingZone Handle These?

### SettingsPanel → SlidingZone ✅ **YES (with minor additions)**

**Match:**
```lua
Ark.SlidingZone(ctx, {
  id = "settings_panel",
  edge = "top",
  bounds = {
    x = coord_offset_x,
    y = search_base_y,  // Final position (visible)
    w = screen_w,
    h = settings_max_height,
  },
  size = settings_max_height,
  collapsed_ratio = 0.0,  // Fully hidden

  retract_delay = 1.5,  // ✅ Already supported!
  window_bounds = {...},  // ✅ Already supported!

  draw = function(ctx, dl, bounds, visibility)
    SettingsPanel.draw(ctx, dl, bounds.x, bounds.y,
      bounds.h, visibility, state, config)
  end,
})
```

**What's Missing:**
- ❌ **"Close when hovering below search"** - Custom retract condition
  - Current: Closes when `mouse_y > search_y + search_height + padding`
  - SlidingZone: Only closes when leaving trigger zone or window

**Solution:**
- Add `retract_when` callback option?
  ```lua
  retract_when = function(ctx, mouse_x, mouse_y)
    return mouse_y > search_y + search_height + 100
  end
  ```

---

### RegionFilter → SlidingZone ⚠️ **MAYBE (needs chaining)**

**Match:**
```lua
Ark.SlidingZone(ctx, {
  id = "region_filter",
  edge = "top",
  bounds = {
    x = coord_offset_x,
    y = filter_base_y,
    w = screen_w,
    h = filter_max_height,
  },
  size = filter_max_height,
  collapsed_ratio = 0.0,

  retract_delay = 0.0,  // Immediate

  draw = function(ctx, dl, bounds, visibility)
    RegionFilterBar.draw(ctx, dl, bounds.x, bounds.y,
      bounds.w, state, config, visibility)
  end,
})
```

**What's Missing:**
- ❌ **Chained visibility** - Shows when SettingsPanel is open
  - Current: `filters_should_show = hover OR settings_visible`
  - SlidingZone: Only responds to own trigger zone

**Solution:**
- Add `force_visible` parameter?
  ```lua
  force_visible = state.settings_panel_visible  // Keep open when settings open
  ```

---

## Feature Gaps

| Feature | SettingsPanel Needs | RegionFilter Needs | SlidingZone Has? |
|---------|---------------------|-------------------|------------------|
| Top edge sliding | ✅ | ✅ | ✅ Yes |
| Retract delay | ✅ (1.5s) | ❌ (0s) | ✅ Yes |
| Window bounds tracking | ✅ | ❌ | ✅ Yes |
| Collapsed ratio 0.0 | ✅ | ✅ | ✅ Yes |
| Custom retract conditions | ✅ (below search) | ❌ | ❌ **NO** |
| Chained visibility | ❌ | ✅ (follows settings) | ❌ **NO** |

---

## Recommendations

### Option 1: Add Missing Features to SlidingZone ✅ **RECOMMENDED**

**Add two optional parameters:**

```lua
-- Custom retract condition
retract_when = function(ctx, mouse_x, mouse_y, state)
  return mouse_y > some_threshold  // Return true to force retract
end,

-- Force visible (for chaining)
force_visible = settings_panel_visible,  // Boolean or function
```

**Benefits:**
- ✅ Covers both use cases
- ✅ Keeps SlidingZone flexible
- ✅ Simple API additions

---

### Option 2: Keep Manual Patterns ❌ **NOT RECOMMENDED**

**Why not:**
- Duplicated code (3 different sliding implementations)
- Harder to maintain
- Inconsistent behavior

---

### Option 3: Hybrid Approach ⚠️ **COMPROMISE**

**Migrate SettingsPanel only** (close enough to SlidingZone)
**Keep RegionFilter manual** (chaining is simpler custom)

**Benefits:**
- ✅ Reduce duplication (2 → 1 manual pattern)
- ✅ No new SlidingZone features needed
- ❌ Still have some duplication

---

## Proposed SlidingZone Additions

### 1. `retract_when` Callback (for SettingsPanel)

```lua
local DEFAULTS = {
  -- ...existing...
  retract_when = nil,  // function(ctx, mx, my, state) -> boolean
}

// In update logic:
local should_retract = false
if opts.retract_when then
  should_retract = opts.retract_when(ctx, mx, my, state)
end

if should_retract then
  state.is_expanded = false
  state.is_in_hover_zone = false
end
```

**Use case:**
```lua
Ark.SlidingZone(ctx, {
  retract_when = function(ctx, mx, my)
    return my > search_y + search_height + 100  // Close when below search
  end,
})
```

---

### 2. `force_visible` Parameter (for RegionFilter)

```lua
local DEFAULTS = {
  -- ...existing...
  force_visible = false,  // boolean or function() -> boolean
}

// In trigger logic:
local forced = opts.force_visible
if type(forced) == "function" then
  forced = forced()
end

if forced then
  state.is_in_hover_zone = true  // Force trigger zone active
end
```

**Use case:**
```lua
Ark.SlidingZone(ctx, {
  force_visible = function()
    return settings_panel.visible  // Stay open when settings open
  end,
})
```

---

## Migration Plan

### Phase 1: Add Features to SlidingZone
- [ ] Add `retract_when` callback
- [ ] Add `force_visible` parameter
- [ ] Test with manual examples

### Phase 2: Migrate SettingsPanel
- [ ] Replace manual sliding with `Ark.SlidingZone`
- [ ] Use `retract_when` for "close below search" logic
- [ ] Use `window_bounds` for "crossed through top" detection
- [ ] Test behavior matches exactly

### Phase 3: Migrate RegionFilter
- [ ] Replace manual sliding with `Ark.SlidingZone`
- [ ] Use `force_visible` to chain with SettingsPanel
- [ ] Test chaining behavior

### Phase 4: Cleanup
- [ ] Remove manual `settings_slide_progress` state
- [ ] Remove manual `filter_slide_progress` state
- [ ] Simplify layout_view.lua logic

---

## Final Assessment

**Can we migrate?** ✅ **YES, with 2 small additions**

**Effort:**
- SlidingZone additions: ~30 minutes
- SettingsPanel migration: ~20 minutes
- RegionFilter migration: ~15 minutes
- Testing: ~30 minutes
**Total: ~2 hours**

**Value:**
- ✅ Consolidate 3 sliding patterns → 1 reusable widget
- ✅ Consistent behavior across all panels
- ✅ Easier to maintain
- ✅ Cleaner layout_view.lua code

**Recommendation:** DO IT! The additions make SlidingZone more powerful and eliminate code duplication.
