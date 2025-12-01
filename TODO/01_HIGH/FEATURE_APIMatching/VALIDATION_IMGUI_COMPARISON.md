# ImGui Pattern Comparison & Validation

**Date:** January 2025
**Purpose:** Validate ARKITEKT's opts-based approach against ImGui patterns

---

## TL;DR - Are We Doing It Right?

**YES ✅** - Our approach is correct and actually **improves** on ImGui's patterns while staying familiar.

**Key Points:**
1. ImGui has **no container callback pattern** - it uses Begin/End for everything
2. ARKITEKT's **opts + callbacks** is a smart evolution, not a deviation
3. Grid/SlidingZone callbacks are **better than ImGui's approach** for composition
4. We're following ImGui's **spirit** (immediate mode), not forcing exact API parity

---

## ImGui Container Patterns

### BeginChild / EndChild (ImGui's "container")

**ImGui approach:**
```lua
-- ImGui: Positional params, no callbacks
if ImGui.BeginChild(ctx, 'my_child', width, height, flags) then
  ImGui.Text(ctx, "Content here")
  ImGui.Button(ctx, "Click")
  -- ... more content
end
ImGui.EndChild(ctx)
```

**Characteristics:**
- Positional parameters (width, height, flags)
- No callbacks - content is inline between Begin/End
- Flags for configuration (borders, scrolling, etc.)
- Simple but **no built-in composition helpers**

**ARKITEKT equivalent:**
```lua
-- Panel uses Begin/End internally but exposes callback regions
Ark.Panel(ctx, {
  id = "my_panel",
  width = 200,
  height = 300,

  draw = function(ctx)
    ImGui.Text(ctx, "Content here")
    Ark.Button(ctx, "Click")
  end,
})
```

**Why this is better:**
- ✅ Hides Begin/End complexity (ID scoping, state management)
- ✅ Callbacks allow composition (header, footer, content separately)
- ✅ Opts table is more readable than positional params
- ✅ Still immediate mode - callback runs every frame

---

## Callback Pattern Validation

### Does ImGui Use Callbacks?

**Short answer:** Rarely, and only for very specific widgets.

**ImGui callbacks:**
```cpp
// Tables have column setup, but not render callbacks
if (BeginTable("table", 3)) {
  TableSetupColumn("Name");
  TableSetupColumn("Value");
  // ... rows
  EndTable();
}

// Plots CAN use callbacks for data (optional)
PlotLines("Frame Times", values_getter_callback, data, count);
```

**Key observation:** ImGui **avoids callbacks** for most widgets because:
1. C++ lambda syntax is verbose
2. Inline code is simpler for simple cases
3. They want minimal API surface

**ARKITEKT's position:**
- Lua has lightweight function syntax: `function() ... end`
- Callbacks enable **composition without config tunneling**
- We use callbacks for **complex containers**, not simple widgets

---

## ARKITEKT Pattern Categories vs ImGui

### 1. Simple Widgets (No Callbacks)

**ImGui:**
```lua
if ImGui.Button(ctx, "Click", 100, 30) then ... end
if ImGui.Checkbox(ctx, "Enable", value) then value = not value end
```

**ARKITEKT:**
```lua
if Ark.Button(ctx, "Click", 100, 30).clicked then ... end
if Ark.Checkbox(ctx, "Enable", value).toggled then value = not value end
```

**Pattern match:** ✅ **PERFECT** - We match ImGui's simplicity, add result objects for extra info

---

### 2. Containers (Begin/End in ImGui, Callbacks in ARKITEKT)

**ImGui:**
```lua
if ImGui.BeginChild(ctx, 'content', w, h, flags) then
  -- Content inline
  ImGui.Text(ctx, "Line 1")
  ImGui.Text(ctx, "Line 2")
end
ImGui.EndChild(ctx)
```

**ARKITEKT Panel:**
```lua
Ark.Panel(ctx, {
  id = "content",
  width = w,
  height = h,

  draw = function(ctx)
    -- Content in callback
    ImGui.Text(ctx, "Line 1")
    ImGui.Text(ctx, "Line 2")
  end,
})
```

**Pattern match:** ⚠️ **EVOLUTION** - We wrap Begin/End for better composition
- ImGui forces inline content
- ARKITEKT uses callbacks to enable **region separation** (header, footer, content)
- Still immediate mode - callback runs every frame

**Is this deviation bad?** ❌ NO - It's an **improvement**:
- Panel with header/footer/corner buttons would require manual layout in ImGui
- ARKITEKT provides **structured regions** while keeping flexibility
- User can still call `ImGui.*` and `Ark.*` inside callbacks

---

### 3. Custom Containers (Grid, SlidingZone) - No ImGui Equivalent

**ARKITEKT Grid:**
```lua
Ark.Grid(ctx, {
  items = items,
  render = function(ctx, rect, item, state)
    -- Draw tile
  end,
})
```

**ARKITEKT SlidingZone:**
```lua
Ark.SlidingZone(ctx, {
  edge = "right",
  bounds = {x, y, w, h},

  on_draw = function(ctx, dl, bounds, visibility)
    -- Draw sliding content
  end,
})
```

**ImGui equivalent:** **NONE** - You'd build this manually with BeginChild + custom logic

**Pattern match:** N/A - These are **ARKITEKT-specific features**
- ImGui doesn't have grid layout or sliding panels
- Our callback pattern is necessary for composition
- No ImGui pattern to compare against

**Is opts + callbacks correct here?** ✅ **YES**:
- Can't use positional params (too many options)
- Callbacks are the only sane way to handle custom tile rendering
- This is exactly how you'd implement it in C++ ImGui anyway

---

## The Opts Table Question

### ImGui's Approach: Positional + Flags

```lua
-- ImGui: Mix of positional params and bitwise flags
ImGui.InputText(ctx, "Label", buffer, 256,
  ImGui.InputTextFlags_Password | ImGui.InputTextFlags_CharsNoBlank)

ImGui.BeginChild(ctx, "ID", 200, 300,
  ImGui.ChildFlags_Borders | ImGui.ChildFlags_ResizeY,
  ImGui.WindowFlags_NoScrollbar)
```

**Problems:**
1. **Parameter explosion** - BeginChild has 5+ positional params
2. **Bitwise flags are cryptic** - `0x0020 | 0x0040` means what?
3. **Can't skip middle params** - `BeginChild(ctx, "ID", nil, nil, flags)` 🤮
4. **No self-documentation** - What's the 4th parameter again?

### ARKITEKT's Approach: Hybrid (Positional for Simple, Opts for Complex)

```lua
-- Simple case: Positional (like ImGui)
Ark.Button(ctx, "Click")
Ark.Button(ctx, "Click", 100, 30)

-- Complex case: Opts table (better than ImGui flags)
Ark.InputText(ctx, {
  label = "Password",
  password = true,          -- Clear intent
  chars_no_blank = true,    -- Self-documenting
  placeholder = "Enter password...",
})

Ark.Panel(ctx, {
  id = "sidebar",
  width = 200,
  height = 300,
  borders = true,           -- Not ChildFlags_Borders
  resizable_y = true,       -- Not ChildFlags_ResizeY
  no_scrollbar = true,      -- Not WindowFlags_NoScrollbar
})
```

**Benefits over ImGui:**
1. ✅ **Readable** - `password = true` vs `InputTextFlags_Password`
2. ✅ **Skippable** - Only set what you need, no `nil` placeholders
3. ✅ **Self-documenting** - Named fields explain themselves
4. ✅ **Simple stays simple** - Positional mode for common cases
5. ✅ **Easy to extend** - Add new opts without breaking API

**Pattern match:** ✅ **IMPROVEMENT** - We keep ImGui's simplicity for common cases, improve complex cases

---

## Specific Pattern Validation

### SlidingZone Callback Pattern

**Current:**
```lua
SlidingZone.draw(ctx, {
  on_draw = function(ctx, dl, bounds, visibility, state) ... end,
})
```

**Proposed:**
```lua
Ark.SlidingZone(ctx, {
  draw = function(ctx, bounds, visibility) ... end,
})
```

**Comparison to Grid:**
```lua
Ark.Grid(ctx, {
  render = function(ctx, rect, item, state) ... end,
})
```

**Pattern consistency check:**

| Widget | Callback Name | Params | Purpose |
|--------|---------------|--------|---------|
| Grid | `render` | (ctx, rect, item, state) | Draw one tile |
| SlidingZone (current) | `on_draw` | (ctx, dl, bounds, visibility, state) | Draw zone content |
| SlidingZone (proposed) | `draw` | (ctx, bounds, visibility) | Draw zone content |
| Panel (spec'd) | `draw` | (ctx) | Draw panel content |

**Issues with current SlidingZone:**
1. ❌ `on_draw` is inconsistent (Grid uses `render`, Panel uses `draw`)
2. ❌ Exposes `dl` (draw list) - Grid/Panel hide this
3. ❌ Exposes `state` - Grid hides this (state is internal)

**Proposed fixes:**
1. ✅ Rename `on_draw` → `draw` (match Panel)
2. ⚠️ Keep `dl` param? (might be needed for custom drawing)
3. ⚠️ Keep `visibility` param? (useful for fade animations)

**Revised proposal:**
```lua
Ark.SlidingZone(ctx, {
  draw = function(ctx, dl, bounds, visibility)
    -- ctx = ImGui context
    -- dl = draw list (for custom drawing)
    -- bounds = {x, y, w, h} of visible area
    -- visibility = 0.0-1.0 animation value
  end,
})
```

**Why keep extra params?**
- `dl` - SlidingZone is for custom overlays, not widget composition (unlike Panel)
- `visibility` - Enables fade effects in user code
- Different use case than Grid (which renders structured tiles)

---

## ImGui Philosophy Check

### What Makes ImGui "ImGui"?

**Core principles:**
1. **Immediate mode** - No retained state in widgets
2. **Simple API** - Minimal parameters, sensible defaults
3. **Inline code** - Logic flows naturally top-to-bottom
4. **No config objects** - (Mostly) positional params

**ARKITEKT adaptations:**
1. ✅ **Still immediate mode** - Callbacks run every frame, no retained DOM
2. ✅ **Still simple** - Positional mode for common cases
3. ⚠️ **Callbacks instead of inline** - For complex containers only
4. ❌ **Opts tables for complexity** - Improvement over bitwise flags

**Are we still "ImGui-like"?** ✅ **YES**

**What changed:**
- We use **opts tables** instead of **bitwise flags** (better in Lua)
- We use **callbacks** for **composition** (better than Begin/End everywhere)

**What stayed the same:**
- Simple widgets stay simple: `Ark.Button(ctx, "Click")`
- Immediate mode architecture
- Direct, imperative code style

---

## Final Verdict

### Question: Is ARKITEKT's opts + callbacks approach correct?

**Answer: YES ✅**

### Why?

**1. Opts are better than flags in Lua**
```lua
-- ImGui (C++)
InputTextFlags_Password | InputTextFlags_CharsDecimal  // Bitwise, cryptic

-- ARKITEKT (Lua)
{ password = true, chars_decimal = true }  // Clear, readable
```

**2. Callbacks enable composition**
```lua
-- Without callbacks (ImGui style) - forced inline
Ark.Panel:begin(ctx)
  Ark.Button(ctx, "Header")  -- Is this header or content?
  Ark.Button(ctx, "Footer")  -- How does Panel know?
Ark.Panel:end(ctx)

-- With callbacks - structured regions
Ark.Panel(ctx, {
  header = { draw = function(ctx) Ark.Button(ctx, "Header") end },
  draw = function(ctx) Ark.Button(ctx, "Content") end,
  footer = { draw = function(ctx) Ark.Button(ctx, "Footer") end },
})
```

**3. Hybrid params preserve ImGui's simplicity**
```lua
-- Simple cases stay simple (like ImGui)
Ark.Button(ctx, "Click")

-- Complex cases are clearer (better than ImGui)
Ark.Button(ctx, {
  label = "Submit",
  disabled = not valid,
  tooltip = "Submit the form",
  on_click = submit,
})
```

**4. We follow ImGui's spirit, not its API verbatim**
- ImGui's C++ constraints (verbose lambdas, no named params) don't apply to Lua
- Lua's lightweight function syntax makes callbacks natural
- Opts tables are idiomatic Lua (like all Lua libraries)

---

## Pattern Recommendations

### ✅ **DO:** Opts + Callbacks for Complex Containers

**Examples:**
- Grid: `render` callback for tiles
- SlidingZone: `draw` callback for content
- Panel: Multiple `draw` callbacks for regions

**Why:** Composition is impossible without callbacks

---

### ✅ **DO:** Hybrid Params (Positional + Opts) for Primitives

**Examples:**
- Button: `Ark.Button(ctx, "Click")` OR `Ark.Button(ctx, {label = "Click", ...})`
- Slider: `Ark.Slider(ctx, value, 0, 100)` OR `Ark.Slider(ctx, {value, min, max, ...})`

**Why:** Simple cases stay simple, complex cases stay clear

---

### ❌ **DON'T:** Force Positional-Only (like ImGui C++)

**Bad:**
```lua
Ark.InputText(ctx, "Label", buffer, 256, 0x0020 | 0x0040, ...)
```

**Good:**
```lua
Ark.InputText(ctx, {
  label = "Label",
  password = true,
  chars_no_blank = true,
})
```

**Why:** Lua doesn't have bitwise flags culture, opts are clearer

---

### ❌ **DON'T:** Use Callbacks for Simple Widgets

**Bad:**
```lua
Ark.Button(ctx, {
  render = function(ctx)  -- WHY?!
    -- Draw button??
  end
})
```

**Good:**
```lua
Ark.Button(ctx, "Click")
```

**Why:** Callbacks are for composition, not simple rendering

---

## Conclusion

**ARKITEKT's approach is validated ✅**

We're not "breaking" ImGui patterns - we're **evolving them for Lua's strengths**:

1. **Opts tables** > bitwise flags (Lua idiom)
2. **Callbacks** > forced inline content (enables composition)
3. **Hybrid params** > positional-only (simple stays simple, complex stays clear)

**ImGui C++ developers would build the same patterns if they had:**
- Lightweight function syntax
- Named parameters
- Table literals

We're staying true to **ImGui's philosophy** (immediate mode, simple API) while adapting to **Lua's idioms**.

---

## SlidingZone Specific Validation

### Final Decision on SlidingZone

**Callback signature:**
```lua
Ark.SlidingZone(ctx, {
  draw = function(ctx, dl, bounds, visibility)
    -- ctx: ImGui context
    -- dl: DrawList (for custom rendering)
    -- bounds: {x, y, w, h} visible area
    -- visibility: 0.0-1.0 animation progress
  end,
})
```

**Why this is correct:**
- ✅ Callback name `draw` matches Panel convention
- ✅ Exposes `dl` because SlidingZone is for custom overlays (not widget composition)
- ✅ Exposes `visibility` for fade effects
- ✅ Different from Grid's `render` (different use case)

**Pattern consistency:**
- Grid: `render(ctx, rect, item, state)` - Structured tiles
- SlidingZone: `draw(ctx, dl, bounds, visibility)` - Custom overlay
- Panel: `draw(ctx)` - Widget composition

**All three are correct** - they have different purposes, so different signatures make sense.

---

**Ready to implement? YES ✅**
