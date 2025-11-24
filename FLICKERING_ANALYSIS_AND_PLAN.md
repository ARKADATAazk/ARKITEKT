# Flickering Analysis & Implementation Plan

**Date**: 2025-11-24
**Context**: Mouse hover flickering investigation in ARKITEKT GUI widgets

---

## 🔍 Root Cause Analysis

### The Flickering Problem

Widgets using **weak tables** + **animation states** flicker because:

1. Lua's garbage collector removes entries from weak tables unpredictably
2. When GC runs, animation state (`hover_alpha`) is lost
3. Next frame recreates instance with `hover_alpha = 0`
4. This causes sudden color jump: animated state → 0 → animating again
5. GC frequency varies with memory pressure (explains inconsistent flicker rates)

**Visual example:**
```
Frame 1: hover_alpha = 0.8 → smooth hover color
Frame 2: [GC runs] → entry removed
Frame 3: hover_alpha = 0 → base color (FLASH!)
Frame 4: hover_alpha = 0.12 → animating up again
```

---

## 📊 Strong Tables vs Weak Tables

### Should we use strong tables everywhere?

**YES** - For GUI widgets, strong tables are the correct choice:

✅ **Pros:**
- Widget instances are long-lived (exist for entire app lifetime)
- Animation state persists between frames
- Number of unique widget IDs is bounded (not infinite)
- IDs are static (`button_1`, `panel_id_widget_id`) not dynamic

❌ **Memory leak risk?**
Only if you create widgets with dynamically generated unique IDs every frame:
```lua
-- ANTI-PATTERN (would leak with strong tables):
Button.draw(ctx, { id = "btn_" .. math.random() })  -- New ID every frame!

-- CORRECT PATTERN (safe with strong tables):
Button.draw(ctx, { id = "save_button" })  -- Static ID
```

### Current Status

**Already fixed (strong tables `{}`)**:
- ✅ button.lua:90
- ✅ checkbox.lua:86
- ✅ combo.lua:15
- ✅ inputtext.lua (uses strong table)

**Still using weak tables (needs fix)**:
- ⚠️ corner_button.lua:74 → `local instances = Base.create_instance_registry()`
- ⚠️ radio_button.lua:67 → `local instances = Base.create_instance_registry()`

---

## 🎯 Hover Detection: GetMousePos vs IsMouseHoveringRect vs IsItemHovered

### The Critical Distinction

The choice depends on **whether the widget needs smooth animation**:

| Method | When to Use | Order Requirement | Animation Support |
|--------|------------|-------------------|-------------------|
| **GetMousePos** | Animated widgets | Check hover → animate → draw → button | ✅ Enables smooth transitions |
| **IsMouseHoveringRect** | Animated widgets | Check hover → animate → draw → button | ✅ Enables smooth transitions |
| **IsItemHovered** | Non-animated widgets | Create button → check hover → draw | ❌ Requires item creation first |

### Why GetMousePos/IsMouseHoveringRect for Animation?

**The Animation-First Order (The Combo Pattern):**

```lua
function render_animated_widget(ctx, dl, x, y, w, h, instance, unique_id)
  -- 1. CHECK HOVER BEFORE DRAWING (manual bounds check)
  local mx, my = ImGui.GetMousePos(ctx)
  local is_hovered = mx >= x and mx < x+w and my >= y and my < y+h

  -- 2. UPDATE ANIMATION USING HOVER STATE
  local dt = ImGui.GetDeltaTime(ctx)
  local target = is_hovered and 1.0 or 0.0
  instance.hover_alpha = instance.hover_alpha + (target - instance.hover_alpha) * 12.0 * dt

  -- 3. CALCULATE COLORS USING ANIMATED HOVER_ALPHA
  local bg_color = lerp(base_color, hover_color, instance.hover_alpha)

  -- 4. DRAW EVERYTHING WITH SMOOTH COLORS
  ImGui.DrawList_AddRectFilled(dl, x, y, x+w, y+h, bg_color)

  -- 5. CREATE INVISIBLEBUTTON LAST (for clicks only)
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, "##" .. unique_id, w, h)

  return is_hovered, ImGui.IsItemClicked(ctx)
end
```

**Why IsItemHovered doesn't work:**

```lua
-- ❌ CHICKEN-AND-EGG PROBLEM:
ImGui.InvisibleButton(ctx, "##id", w, h)  -- Must create item first
local hovered = ImGui.IsItemHovered(ctx)   -- Now we have hover state
-- BUT: It's too late! We already passed the drawing phase
-- We needed hover state BEFORE drawing to calculate animated colors
```

### GetMousePos vs IsMouseHoveringRect

Both work for animated widgets - they're equivalent:

```lua
-- Method 1: GetMousePos (manual bounds check)
local mx, my = ImGui.GetMousePos(ctx)
local is_hovered = mx >= x and mx < x+w and my >= y and my < y+h

-- Method 2: IsMouseHoveringRect (ImGui helper)
local is_hovered = ImGui.IsMouseHoveringRect(ctx, x, y, x+w, y+h)
```

**Trade-offs:**

| Aspect | GetMousePos | IsMouseHoveringRect |
|--------|-------------|---------------------|
| Simplicity | Manual calculation | ImGui built-in |
| Clipping awareness | Manual (PushClipRect) | Manual (PushClipRect) |
| Z-order/stacking | Manual | Manual |
| Performance | Negligible difference | Negligible difference |

**Verdict:** Use **GetMousePos** to match combo.lua's proven pattern (consistency matters).

### Do We Lose Anything?

**Clipping:** ❌ No - Panels handle clipping at container level with `PushClipRect`
**Z-order:** ❌ No - Widgets don't overlap in our layout model (explicit positioning)
**Modal blocking:** ❌ No - We handle with `is_blocking` flag manually
**ImGui state:** ❌ No - We're doing low-level draw list rendering anyway

### When IsItemHovered IS Correct

For **non-animated widgets** (slider, spinner, hue_slider):
- No smooth animation needed (immediate state changes are fine)
- Order: Create InvisibleButton → Check hover → Draw with immediate colors
- Examples: slider.lua, spinner.lua (they create button first, no hover_alpha)

---

## 🛠️ Implementation Plan

### Phase 1: Fix Remaining Weak Tables (5 min)

**File: corner_button.lua:74**
```lua
-- BEFORE:
local instances = Base.create_instance_registry()

-- AFTER:
local instances = {}
```

**File: radio_button.lua:67**
```lua
-- BEFORE:
local instances = Base.create_instance_registry()

-- AFTER:
local instances = {}
```

---

### Phase 2: Standardize Hover Detection (10 min)

**File: corner_button.lua:207**

Currently uses `IsMouseHoveringRect` - this works, but should standardize to `GetMousePos` pattern:

```lua
-- BEFORE:
if not disabled and not is_blocking then
  hovered = ImGui.IsMouseHoveringRect(ctx, x, y, x + size, y + size)
  active = hovered and ImGui.IsMouseDown(ctx, 0)
end

-- AFTER (match combo pattern):
local hovered = false
local active = false
if not disabled and not is_blocking then
  local mx, my = ImGui.GetMousePos(ctx)
  hovered = mx >= x and mx < x + size and my >= y and my < y + size
  active = hovered and ImGui.IsMouseDown(ctx, 0)
end
```

**File: radio_button.lua:120**

Currently uses `Base.get_interaction_state()` which uses `IsMouseHoveringRect`:
- This is actually fine (both methods work)
- No change needed, but document the pattern

---

### Phase 3: Remove Outdated Comments (2 min)

**Remove "weak table to prevent memory leaks" comments:**

- corner_button.lua:71
- radio_button.lua:64

**Already removed from:**
- ✅ button.lua (fixed previously)
- ✅ checkbox.lua (fixed previously)
- ✅ inputtext.lua (fixed previously)

---

### Phase 4: Documentation (20 min)

**Create: `/ARKITEKT/arkitekt/gui/widgets/WIDGET_PATTERN.md`**

Document the canonical patterns for:
1. Instance management (strong tables)
2. Hover detection (GetMousePos for animated, IsItemHovered for non-animated)
3. Animation-first order
4. When to use each pattern

---

### Phase 5: Audit Remaining Widgets (15 min)

**Animated widgets (need GetMousePos + strong tables):**
- ✅ button.lua
- ✅ checkbox.lua
- ✅ combo.lua
- ✅ inputtext.lua
- ⚠️ corner_button.lua (needs fix)
- ⚠️ radio_button.lua (already uses Base helper, OK)
- ❓ close_button.lua (check if it uses animation)
- ❓ scrollbar.lua (check if it uses animation)

**Non-animated widgets (IsItemHovered is fine):**
- slider.lua (no animation, immediate state)
- spinner.lua (no animation, immediate state)
- hue_slider.lua (no animation, immediate state)

**Special cases:**
- separator.lua (mixed usage, check if animation needed)
- markdown_field.lua (complex, check usage)

---

### Phase 6: Testing Checklist (10 min)

After fixes, test in these environments:

**Low GC Pressure:**
- [ ] Sandbox 5 (simple scripts)
- [ ] Watch for 30+ seconds

**High GC Pressure:**
- [ ] TemplateBrowser (complex, many widgets)
- [ ] RegionPlaylist (lots of state)
- [ ] Watch for 30+ seconds during active use

**Specific Widget Tests:**
- [ ] corner_button hover (after fix)
- [ ] radio_button hover (after fix)
- [ ] All tooltips work correctly
- [ ] All clicks register properly
- [ ] No animation stuttering

---

## 📋 Quick Reference: The Two Patterns

### Pattern A: Animated Widgets (button, checkbox, combo, corner_button, radio_button)

```lua
local instances = {}  -- STRONG TABLE

function M.draw(ctx, opts)
  local instance = get_instance(unique_id)

  -- 1. Check hover BEFORE drawing
  local mx, my = ImGui.GetMousePos(ctx)
  local is_hovered = mx >= x and mx < x+w and my >= y and my < y+h

  -- 2. Update animation
  local dt = ImGui.GetDeltaTime(ctx)
  local target = is_hovered and 1.0 or 0.0
  instance.hover_alpha = instance.hover_alpha + (target - instance.hover_alpha) * 12.0 * dt

  -- 3. Get colors using animated hover_alpha
  local bg_color = lerp(base_color, hover_color, instance.hover_alpha)

  -- 4. Draw everything
  ImGui.DrawList_AddRectFilled(dl, x, y, x+w, y+h, bg_color)

  -- 5. Create InvisibleButton LAST
  ImGui.InvisibleButton(ctx, "##" .. unique_id, w, h)
end
```

### Pattern B: Non-Animated Widgets (slider, spinner)

```lua
-- NO instance table needed

function M.draw(ctx, opts)
  -- 1. Create InvisibleButton FIRST
  ImGui.InvisibleButton(ctx, "##" .. unique_id, w, h)

  -- 2. Check hover AFTER
  local is_hovered = ImGui.IsItemHovered(ctx)

  -- 3. Get colors using immediate state (no animation)
  local bg_color = is_hovered and hover_color or base_color

  -- 4. Draw with immediate colors
  ImGui.DrawList_AddRectFilled(dl, x, y, x+w, y+h, bg_color)
end
```

---

## 🎯 Summary for Next Session

### Immediate Actions (15 min):
1. Fix `corner_button.lua:74` → strong table
2. Fix `radio_button.lua:67` → strong table
3. Remove outdated comments (2 files)
4. Test in Sandbox 5 + TemplateBrowser

### Optional Improvements (20 min):
5. Standardize `corner_button.lua:207` to GetMousePos pattern
6. Create `WIDGET_PATTERN.md` documentation
7. Audit remaining primitives (close_button, scrollbar, separator)

### Key Insights:

1. **Flickering = Weak tables + Animation state + GC**
   - Solution: Strong tables for all animated widgets

2. **GetMousePos = Animation-first pattern enabler**
   - Allows checking hover BEFORE drawing
   - Required for smooth frame-by-frame transitions
   - Not about technical superiority, about order requirements

3. **IsItemHovered = Valid for non-animated widgets**
   - Acceptable when immediate state changes are fine
   - Used by slider, spinner (no hover_alpha animation)

4. **No significant trade-offs**
   - Clipping handled at container level
   - No z-order issues in our layout model
   - Strong tables safe with static widget IDs

---

## ✅ Validation Criteria

**Fix is successful when:**
- [ ] No hover flickering in any widget (30+ second observation)
- [ ] Smooth animation transitions (no jumps)
- [ ] Works under low GC pressure (Sandbox 5)
- [ ] Works under high GC pressure (TemplateBrowser)
- [ ] All tooltips appear correctly
- [ ] All clicks register properly

---

**Next session: Start with Phase 1 (5 min fix) → Test → Decide on further improvements**
