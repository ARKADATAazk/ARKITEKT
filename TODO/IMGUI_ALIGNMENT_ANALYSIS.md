# ImGui Alignment Analysis – Are ARKITEKT's Naming Standards Correct?

> **Question**: Does ARKITEKT framework align with ImGui conventions? Should we reconsider the `opts` pattern?
> **Status**: ✅ ANALYZED
> **Date**: 2025-12-01

---

## 🎯 Executive Summary

**VERDICT**: ARKITEKT's naming standards are **fundamentally correct** but could be better aligned in specific areas.

| Area | ImGui Pattern | ARKITEKT Pattern | Alignment | Recommendation |
|------|---------------|------------------|-----------|----------------|
| **Widget APIs** | Positional params | HYBRID (positional OR opts) | ✅ EXCELLENT | Keep hybrid approach |
| **Context naming** | `ctx` (always) | `ctx` (always) | ✅ PERFECT | No changes needed |
| **Begin/End pairs** | `BeginXXX/EndXXX` | `begin_xxx/end_xxx` | ✅ GOOD | Keep snake_case |
| **Widget constructors** | `new(ctx)` single param | `new(opts)` multi-field | ⚠️ DIVERGENT | **Needs discussion** |
| **Local variables** | No standard (C++) | `cfg`, `ctx`, `state` | ✅ GOOD | Keep abbreviations |

**Key Finding**: ARKITEKT's **widget draw APIs** perfectly align with ImGui (hybrid mode). But **constructors** diverge significantly - this is intentional but worth validating.

---

## 📋 ImGui Philosophy (Ground Truth)

### 1. Core Principles (from Dear ImGui documentation)

**Immediate Mode**:
- Widgets are stateless functions called every frame
- State stored externally by application code
- Simple, direct APIs
- Minimal abstraction

```cpp
// C++ ImGui pattern
if (ImGui::Button("Click", ImVec2(100, 30))) {
  // clicked
}
```

```lua
-- Lua ReaImGui equivalent
if ImGui.Button(ctx, "Click", 100, 30) then
  -- clicked
end
```

### 2. ReaImGui Patterns (from references/imgui/ReaImGui_Demo.lua)

**Module-level state**:
```lua
-- ImGui demo uses module-level state, not constructor params
local demo = {
  open = true,
  menu = { enabled = true, f = 0.5, n = 0, b = true },
  widgets = {},
  -- State stored in module table
}

function demo.ShowDemoWindow(open)
  -- Functions access module-level state
  -- Not passed as constructor parameters
end
```

**Simple constructors** (when classes are used):
```lua
-- ExampleAppLog from ImGui demo
function ExampleAppLog:new(ctx)
  local instance = {
    ctx = ctx,  -- Only ctx is passed
    lines = {},  -- Other fields initialized with defaults
    filter = ImGui.CreateTextFilter(),
    auto_scroll = true,
  }
  return setmetatable(instance, self)
end

-- Usage
local my_log = ExampleAppLog:new(ctx)
my_log:AddLog("Hello")
my_log:Draw("Log Window")
```

**Key pattern**: Single `ctx` parameter, everything else initialized to defaults or set later.

---

## 📊 ARKITEKT Current Patterns

### 1. Widget Draw APIs ✅ EXCELLENT

**Hybrid approach** - supports BOTH ImGui-style AND opts-style:

```lua
-- Pattern 1: ImGui-style positional (simple cases)
if Ark.Button(ctx, "Save") then end
if Ark.Button(ctx, "Save", 100) then end  -- with width

-- Pattern 2: Opts-based (complex cases)
if Ark.Button(ctx, {
  label = "Delete",
  preset = "danger",
  width = 100,
  tooltip = "Delete this item",
  on_click = function() end,
}) then end
```

**From arkitekt/gui/widgets/primitives/button.lua:504**:
```lua
function M.draw(ctx, label_or_opts, width, height)
  -- Hybrid parameter detection
  local opts
  if type(label_or_opts) == "table" then
    opts = label_or_opts  -- Opts table
  elseif type(label_or_opts) == "string" then
    opts = { label = label_or_opts, width = width, height = height }  -- Positional
  end
  -- ...
end
```

**Verdict**: ✅ This is **excellent design** - maintains ImGui simplicity while offering enhanced features.

---

### 2. Widget Constructors ⚠️ DIVERGENT FROM IMGUI

**ARKITEKT pattern** - Complex opts tables:

```lua
-- From arkitekt/gui/widgets/containers/grid/core.lua:144
function M.new(opts)
  opts = opts or {}

  local grid = setmetatable({
    id = opts.id or "grid",
    gap = opts.gap or 12,
    min_col_w_fn = type(opts.min_col_w) == "function" and opts.min_col_w or ...,
    fixed_tile_h_fn = ...,
    get_items = opts.get_items or function() return {} end,
    key = opts.key or function(item) return tostring(item) end,
    behaviors = opts.behaviors or {},
    mouse_behaviors = opts.mouse_behaviors or {},
    render_item = opts.render_item or function() end,
    render_overlays = opts.render_overlays,
    external_drag_check = opts.external_drag_check,
    accept_external_drops = opts.accept_external_drops or false,
    on_external_drop = opts.on_external_drop,
    on_click_empty = opts.on_click_empty,
    extend_input_area = opts.extend_input_area or { ... },
    config = opts.config or DEFAULTS,
    -- 20+ fields total!
  }, { __index = Grid })
end
```

**ImGui equivalent** (from demo):
```lua
-- Simple, minimal
function ExampleAppLog:new(ctx)
  local instance = {
    ctx = ctx,  -- ONLY ctx parameter
    lines = {},
    filter = ImGui.CreateTextFilter(),
    auto_scroll = true,
  }
  return setmetatable(instance, self)
end
```

**Comparison**:

| Aspect | ImGui Pattern | ARKITEKT Pattern | Divergence |
|--------|---------------|------------------|------------|
| Parameters | 1 (`ctx`) | 20+ fields in `opts` | ⚠️ HIGH |
| Complexity | Minimal | High (complex config) | ⚠️ HIGH |
| Flexibility | Low (set fields later) | High (all config upfront) | ✅ Better |
| Readability | Very simple | Self-documenting | ✅ Better |
| ImGui-like | ✅ Yes | ❌ No | ⚠️ Divergent |

**Question**: Is this divergence justified?

---

## 🔍 Deep Dive: Why ARKITEKT Diverges

### Reason 1: ImGui is Mostly Stateless

**ImGui philosophy**:
- Widgets are **immediate mode** - no persistent state
- Configuration happens via Push/Pop style:
  ```lua
  ImGui.PushStyleColor(ctx, ImGui.Col_Button, color)
  ImGui.Button(ctx, "Click")
  ImGui.PopStyleColor(ctx)
  ```
- No "widget instances" - just function calls

**ARKITEKT reality**:
- Grid, Panel, etc. are **stateful containers**
- Need configuration for callbacks, behaviors, rendering
- Persistent state for animations, drag-drop, selection
- Can't use Push/Pop for 20+ config fields

**Conclusion**: Divergence is **necessary** for stateful widgets.

---

### Reason 2: ARKITEKT Adds Features ImGui Doesn't Have

**ImGui scope**:
- Primitives: Button, Checkbox, Input, Slider
- Basic containers: Window, Menu, Popup, Table

**ARKITEKT additions**:
- Advanced containers: Grid (with drag-drop, reordering, marquee)
- Panels with collapsing, scrolling, header customization
- Animation systems
- Theme management
- Behavior composition

**These need configuration!**

Example: Grid needs:
- `get_items` - data source
- `render_item` - custom renderer
- `behaviors` - interaction behaviors (select, drag, reorder)
- `key` - item identity function
- `on_external_drop` - drop handler
- etc.

**Conclusion**: Can't use ImGui's simple `new(ctx)` for complex widgets.

---

### Reason 3: Lua Patterns vs C++ Patterns

**C++ approach** (ImGui):
```cpp
// Configuration via properties (C++ setters)
ImGuiTableFlags flags = ImGuiTableFlags_Resizable | ImGuiTableFlags_Reorderable;
if (ImGui::BeginTable("table", 3, flags)) {
  // ...
  ImGui::EndTable();
}
```

**Lua approach** (ARKITEKT):
```lua
-- Configuration via opts table (no setters in Lua)
local grid = Grid.new({
  id = "my_grid",
  behaviors = {select = true, drag = true},
  get_items = function() return items end,
  render_item = function(ctx, item, ...) ... end,
})
```

**Lua doesn't have**:
- Property setters (need to assign fields directly)
- Method overloading (can't have multiple constructors)
- Builder patterns (verbose in Lua)

**Lua idiom**: Opts tables are THE standard for complex configuration in Lua.

**Conclusion**: `opts` pattern is **idiomatic Lua**, even if different from C++ ImGui.

---

## 🎯 Recommendations

### 1. Widget Draw APIs ✅ KEEP AS-IS

**Current**: Hybrid (positional OR opts)
**Verdict**: ✅ PERFECT - Best of both worlds

```lua
-- Simple cases: ImGui-style
Ark.Button(ctx, "Save", 100)

-- Complex cases: Opts-style
Ark.Button(ctx, { label = "Delete", preset = "danger", tooltip = "..." })
```

**Reasoning**:
- Maintains ImGui simplicity for common cases
- Adds power for complex cases
- cookbook/API_DESIGN_PHILOSOPHY.md explicitly endorses this

---

### 2. Widget Constructors ⚡ REFINE PATTERN

**Current**: Always `M.new(opts)` with many fields
**Proposal**: **THREE-TIER PATTERN** based on widget complexity

#### Tier 1: Simple Widgets (ImGui-aligned) ✅

**For**: Primitives with minimal/no state (Button instances, Checkbox instances, etc.)

**Pattern**: No constructor OR minimal constructor
```lua
-- Option A: No constructor at all (stateless)
Ark.Button(ctx, "Click")  -- No Button.new() needed

-- Option B: Minimal constructor (if state needed)
function M.new(ctx, id)  -- Only essential params
  return setmetatable({ ctx = ctx, id = id, hover_alpha = 0 }, M)
end
```

**Example**: Button, Checkbox, Slider (when used as one-offs)

---

#### Tier 2: Medium Widgets (Hybrid approach) ✅

**For**: Widgets with configuration but not excessive

**Pattern**: Single required param + optional opts
```lua
-- Required param first (usually ctx or config), opts second
function M.new(ctx, opts)
  opts = opts or {}
  return setmetatable({
    ctx = ctx,
    id = opts.id or generate_id(),
    -- Up to ~5-10 config fields from opts
  }, M)
end

-- OR: Single config param (if no ctx needed)
function M.new(config)
  return setmetatable({ config = config or {} }, M)
end
```

**Example**: DisplayWidget, Selector, StatusPad

**ImGui comparison**: Closer to `ExampleAppLog:new(ctx)` pattern

---

#### Tier 3: Complex Containers (ARKITEKT enhancement) ✅

**For**: Stateful containers with extensive configuration

**Pattern**: Full opts table (current approach)
```lua
function M.new(opts)
  opts = opts or {}
  -- Extract 10-20+ configuration fields
  return setmetatable({ ... }, M)
end
```

**Example**: Grid, Panel, Table, Canvas

**Reasoning**: No simpler alternative exists for complex configuration

---

### 3. Local Variable Naming ✅ KEEP AS-IS

**Current**: `cfg`, `ctx`, `state` (abbreviated for frequently-used locals)

**Verdict**: ✅ GOOD - This is NOT ImGui-specific, just good Lua practice

**ImGui doesn't dictate** local variable naming (C++ uses whatever).
**Lua community standard**: Short, clear abbreviations (`cfg`, `ctx`, `db`, `tx`)

---

### 4. Parameter Naming ✅ KEEP AS-IS

**Current**: `ctx` first, then `opts` or positional params

**Verdict**: ✅ PERFECT - Matches ImGui convention

**ImGui**: Context always first (`ImGui.Button(ctx, ...)`)
**ARKITEKT**: Context always first (`Ark.Button(ctx, ...)`)

---

## 📐 Alignment Score

| Category | Weight | Score | Weighted |
|----------|--------|-------|----------|
| Widget draw APIs | 40% | 10/10 ✅ | 4.0 |
| Context naming | 20% | 10/10 ✅ | 2.0 |
| Begin/End patterns | 15% | 9/10 ✅ | 1.35 |
| Immediate mode behavior | 15% | 10/10 ✅ | 1.5 |
| Constructor patterns | 10% | 6/10 ⚠️ | 0.6 |
| **TOTAL** | **100%** | **-- /10** | **9.45/10** ✅ |

**Grade**: A+ (94.5%) - Excellent alignment with ImGui

**Only area for improvement**: Constructor patterns (Tier 1-2 could be simpler)

---

## ✅ Final Recommendations

### Immediate (No Changes Needed)

1. ✅ **Keep hybrid widget APIs** - Perfect balance of simplicity and power
2. ✅ **Keep `ctx` naming** - Universal standard
3. ✅ **Keep `cfg`, `state` abbreviations** - Good Lua practice
4. ✅ **Keep `opts` for complex widgets** - Necessary for advanced features

### Consider (Minor Refinements)

1. ⚡ **Simplify Tier 1 constructors** - Primitives could use `new(ctx, id)` instead of `new(opts)`
2. ⚡ **Document three-tier pattern** - Make it clear when to use which constructor style
3. ⚡ **Add ImGui comparison examples** - Show how ARKITEKT maps to ImGui patterns

### Don't Change

1. ❌ **Don't remove `opts` pattern** - It's essential for complex widgets
2. ❌ **Don't force ImGui-style for everything** - Lua idioms matter
3. ❌ **Don't simplify Grid/Panel constructors** - They need the configuration

---

## 📚 Updated Guidelines

Add to `TODO/NAMING_STANDARDS.md`:

### Constructor Pattern Selection

**Choose based on widget complexity:**

```lua
-- Tier 1: Primitives (ImGui-aligned)
-- If widget is stateless OR has minimal state
function M.new(ctx, id)  -- Simple params only
  return setmetatable({ ctx = ctx, id = id }, M)
end

-- Tier 2: Medium widgets (Hybrid)
-- If widget needs ctx + moderate config (5-10 fields)
function M.new(ctx, opts)  -- Required param + opts
  opts = opts or {}
  return setmetatable({
    ctx = ctx,
    id = opts.id or generate_id(),
    config = opts.config or {},
    -- Moderate number of fields
  }, M)
end

-- Tier 3: Complex containers (Full opts)
-- If widget needs extensive config (10+ fields, callbacks, behaviors)
function M.new(opts)  -- Full opts table
  opts = opts or {}
  -- Extract many fields
  return setmetatable({ ... }, M)
end
```

**Decision tree**:
1. No state? → No constructor (stateless function)
2. Minimal state? → `new(ctx)` or `new(ctx, id)`
3. Moderate config? → `new(ctx, opts)` or `new(config)`
4. Complex config? → `new(opts)`

---

## 🏆 Conclusion

**ARKITEKT's naming standards ARE correct and well-aligned with ImGui** (94.5% alignment).

**Key insights**:
1. ✅ Widget draw APIs perfectly match ImGui philosophy (hybrid approach)
2. ✅ Context and naming conventions are spot-on
3. ⚠️ Constructors diverge from ImGui, but **this is justified**:
   - ImGui is mostly stateless (no complex constructors)
   - ARKITEKT adds stateful containers (need configuration)
   - Lua opts tables are idiomatic (C++ uses different patterns)

**Minor refinement**: Consider three-tier constructor pattern for better alignment on simple widgets, but keep `opts` for complex ones.

**Bottom line**: ARKITEKT successfully balances ImGui familiarity with necessary enhancements. The `opts` pattern is **not a problem** - it's a **solution** to real complexity that ImGui doesn't address.
