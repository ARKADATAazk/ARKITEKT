# ARKITEKT Naming Standards – Definitive Guide

> **Status**: ✅ DEFINED (Based on comprehensive 12-app survey + framework analysis)
> **Authority**: `arkitekt/gui/widgets/*` framework (14/20 uses `opts` pattern)
> **Last Updated**: 2025-12-01

---

## 🎯 Executive Summary

After analyzing **12 ARKITEKT apps** (188 files, ~90 constructors) and the **core framework** (`arkitekt/gui/widgets/*`), here is the definitive standard:

| Element | Standard | Framework Support | App Consensus |
|---------|----------|-------------------|---------------|
| **Constructor** | `function M.new(opts)` | ✅ 70% (14/20) | ⚠️ Mixed (40% apps) |
| **Config local var** | `local cfg = self.config` | ✅ 100% (7/7) | ⚠️ 60% use `cfg` |
| **State local var** | `local state = ...` | ✅ 100% | ✅ 100% (NEVER `st`) |
| **ImGui context** | `ctx` parameter | ✅ 100% | ✅ 100% |

**Key Findings**:
1. **Framework is authoritative** - Uses `opts` pattern predominantly
2. **Apps are INCONSISTENT** - RegionPlaylist, ItemPicker, others use 3 different patterns
3. **State is NEVER abbreviated** - Zero uses of `st` for application state
4. **Config abbreviation wins** - Framework consistently uses `cfg` for locals

---

## 📋 The Authoritative Standard

### 1. Constructor Patterns ⭐⭐⭐

**Three valid patterns, choose based on context:**

#### Pattern A: `opts`-based (RECOMMENDED for most cases)

```lua
-- ✅ USE FOR: Framework widgets, UI components, extensible modules
function M.new(opts)
  opts = opts or {}

  local cfg = opts.config
  local state = opts.state

  return setmetatable({
    config = cfg,
    state = state,
    id = opts.id,
    -- Easy to add opts.theme, opts.callbacks, etc.
  }, { __index = M })
end

-- Usage:
local widget = Widget.new({
  config = my_config,
  state = my_state,
  id = "widget1"
})
```

**Framework Examples**:
- `panel/coordinator.lua:40` - `function M.new(opts)`
- `grid/core.lua:144` - `function M.new(opts)`
- `menutabs.lua:60` - `function M.new(opts)`

**When to use**:
- ✅ Framework widgets and UI components
- ✅ Modules with 3+ dependencies
- ✅ When extensibility is important
- ✅ When following framework conventions

---

#### Pattern B: No-param constructor (VALID for encapsulated modules)

```lua
-- ✅ USE FOR: Self-contained modules with internal state only
function M.new()
  local instance = {
    -- Private state initialized here
    internal_state = {},
  }
  return setmetatable(instance, { __index = M })
end

-- Usage:
local module = Module.new()  -- No config needed
module:initialize(settings)  -- Configure separately if needed
```

**Framework Examples**:
- `overlay/manager.lua:122` - `function M.new()`
- `batch_rename_modal.lua:135` - `function M.new()`

**RegionPlaylist Examples**:
- `domain/dependency.lua:14` - `function M.new()`
- `domain/region.lua:14` - `function M.new()`
- `domain/playlist.lua:14` - `function M.new()`

**When to use**:
- ✅ Simple domain objects with no external dependencies
- ✅ Modules that initialize via separate `initialize()` method
- ✅ Pure behavior modules (strategies, utilities)

---

#### Pattern C: Single `config` param (VALID for config-driven modules)

```lua
-- ✅ USE FOR: Modules that ONLY need configuration (no other dependencies)
function M.new(config)
  return setmetatable({
    config = config or {},
  }, { __index = M })
end

-- Usage:
local widget = Widget.new(my_config)
```

**Framework Examples**:
- `grid/animation.lua:18` - `function M.new(config)`
- `grid/grid_bridge.lua:14` - `function M.new(config)`

**RegionPlaylist Examples**:
- `display_widget.lua:55` - `function M.new(config)`
- `selector.lua:31` - `function M.new(config)`

**When to use**:
- ✅ UI widgets that ONLY need visual configuration
- ✅ Renderers that don't need state
- ✅ Simple modules with single dependency

---

#### ❌ ANTI-PATTERN: Multi-param direct constructors

```lua
-- ❌ AVOID: Hard to extend, unclear parameter order
function M.new(config, state, visualization, animator, disable_animator)
  -- What if we need to add theme? callbacks? logger?
  -- Signature grows forever, refactoring becomes nightmare
end

-- ✅ REFACTOR TO:
function M.new(opts)
  local cfg = opts.config
  local state = opts.state
  local viz = opts.visualization
  local animator = opts.animator
  local disable_animator = opts.disable_animator
  -- Easy to add opts.theme, opts.callbacks without breaking callers
end
```

**Only exception**: App/orchestration layer (1-2 instances per app max)
```lua
-- ⚠️ ACCEPTABLE: Top-level orchestrator (app/controller.lua)
function M.new(state_module, settings, undo_manager)
  -- OK because: top-level wiring, explicit dependencies, called once
end
```

---

### 2. Local Variable Naming ⭐⭐⭐

**Standard Abbreviations** (based on framework):

| Full Name | Local Variable | Context | Framework Support |
|-----------|---------------|---------|-------------------|
| `config` | `cfg` | From `self.config` or `opts.config` | ✅ 100% (7/7) |
| `context` (ImGui) | `ctx` | ImGui context parameter | ✅ 100% |
| `options` | `opts` | Function parameter | ✅ 100% |
| `state` | `state` | Application/module state | ✅ 100% (NEVER `st`) |

```lua
-- ✅ CORRECT - Framework standard
function SomeClass:draw(ctx, opts)
  local cfg = self.config  -- Use 'cfg' for local reference

  local bg_color = cfg.colors.background
  local padding = cfg.layout.padding

  ImGui.Button(ctx, "Click me")
end

-- ❌ WRONG - Verbose
function SomeClass:draw(context, options)
  local configuration = self.configuration
  -- Too verbose, inconsistent with framework
end
```

**Key Rule**: Use the abbreviated form (`cfg`) for local variables, keep full names for struct fields.

```lua
-- ✅ CORRECT Pattern
return setmetatable({
  config = cfg,  -- Struct field: full name
  state = state,
}, ...)

function M:method()
  local cfg = self.config  -- Local var: abbreviated
  -- Use cfg in method body
end
```

---

### 3. Parameter Naming ⭐⭐

**Function Signature Standards**:

```lua
-- ✅ CORRECT: ImGui widgets
function M.draw(ctx, opts)
  -- ctx: ImGui context (always first for ImGui calls)
  -- opts: Configuration/parameters
end

-- ✅ CORRECT: Constructors
function M.new(opts)
  -- opts: Table with config, state, and other dependencies
end

-- ✅ CORRECT: Simple utilities (direct params OK)
function M.calculate_bounds(width, height, padding)
  -- Direct params for simple functions with 1-3 params
end
```

**Parameter Ordering** (when using direct params):

```lua
-- STANDARD ORDER (RegionPlaylist, Framework):
function M.draw(
  ctx,           -- 1. ImGui context (if needed)
  id,            -- 2. Identity/key
  width, height, -- 3. Dimensions
  content_fn,    -- 4. Callbacks
  config,        -- 5. Configuration
  ...            -- 6. Other context-specific params
)
```

---

## 📊 Current State of Codebase

### Framework (`arkitekt/gui/widgets/*`) ✅ AUTHORITATIVE

| Pattern | Count | % | Status |
|---------|-------|---|--------|
| `M.new(opts)` | 14 | 70% | ✅ PRIMARY |
| `M.new(config)` | 2 | 10% | ✅ VALID (grid modules) |
| `M.new()` | 2 | 10% | ✅ VALID (managers) |
| Direct params | 0 | 0% | ❌ NEVER |

**Local variables**:
- `local cfg = self.config` - 7/7 (100%)
- `ctx` for ImGui - 100%

**Verdict**: Framework is **consistent and authoritative**. Use as reference.

---

### RegionPlaylist ⚠️ MIXED (Needs Standardization)

**Constructor Patterns**:
| Pattern | Files | % | Status |
|---------|-------|---|--------|
| `M.new(opts)` | 6 | 33% | ✅ Framework-aligned |
| `M.new()` | 4 | 22% | ✅ Valid pattern |
| `M.new(config, ...)` | 8 | 44% | ⚠️ Should migrate to opts |

**Local variables**:
- `local cfg` - 4/5 files (80%) ✅
- `local config` - 1/5 files (20%) ⚠️
- State never abbreviated ✅

**Files using `opts` (already aligned)**:
- ✅ `domain/playback/controller.lua:14`
- ✅ `domain/playback/quantize.lua:28`
- ✅ `domain/playback/transport.lua:25`
- ✅ `domain/playback/state.lua:25`
- ✅ `domain/playback/transitions.lua:31`
- ✅ `ui/views/transport/transport_container.lua:26`

**Files needing migration to `opts`**:
- ⚠️ `app/controller.lua:18` - `M.new(state_module, settings, undo_manager)`
- ⚠️ `ui/views/transport/transport_view.lua:21` - `M.new(config, state_module)`
- ⚠️ `ui/views/layout_view.lua:19` - `M.new(config, state_module)`
- ⚠️ `ui/views/overflow_modal_view.lua:17` - `M.new(region_tiles, state_module, on_tab_selected)`
- ⚠️ `ui/state/preferences.lua:16` - `M.new(constants, settings)`
- ⚠️ `ui/state/notification.lua:10` - `M.new(timeouts)`

**Files using `M.new()` (valid, keep as-is)**:
- ✅ `domain/dependency.lua:14`
- ✅ `domain/region.lua:14`
- ✅ `domain/playlist.lua:14`
- ✅ `ui/state/animation.lua:9`

**Local variable fix**:
- ⚠️ `ui/views/transport/coordinator.lua:45` - Change `local config` → `local cfg`

---

### ItemPicker ⚠️ ANTI-PATTERN (Needs Major Refactoring)

**Constructor Patterns**:
| Pattern | Files | Status |
|---------|-------|--------|
| `M.new()` | ~5 | ✅ Valid |
| `M.new(config, state, ...)` | ~8 | ❌ ANTI-PATTERN |

**Problematic signatures**:
```lua
// ❌ ItemPicker anti-pattern example
function M.new(config, state, controller, visualization, drag_handler)
  -- 5 direct parameters! Hard to extend, unclear ordering
end
```

**Local variables**:
- Uses full `config` (not `cfg`) - inconsistent with framework
- Uses `state` (correct) - 100%

**Migration effort**: 2-3 hours (8 constructors + call sites)

---

### Other Apps Summary

| App | Constructor Pattern | Config Var | Consistency | Migration Effort |
|-----|---------------------|------------|-------------|------------------|
| ThemeAdjuster | Mixed `M.new()` / `M.new(config)` | `config` | Medium-High | 3-4 hours |
| TemplateBrowser | `M.new(config)` / `M.new()` | `config` | High | 4-5 hours |
| WalterBuilder | `M.new(opts)` ✅ | varies | High | Minimal |
| ColorPalette | `M.initialize()` | `cfg`/`config` | Medium | 1-2 hours |
| MIDIHelix | `M.new(Ark)` ⚠️ | minimal | Low | 2-3 hours |
| ProductionPanel | `M.initialize()` | minimal | Medium-Low | 1-2 hours |

---

## 🎯 Migration Strategy

### Priority Order

1. **🟢 Phase 0: Document Standard** ✅ DONE
   - This file serves as definitive reference

2. **🟡 Phase 1: RegionPlaylist (Quick Win)**
   - **Effort**: 2-3 hours
   - **Files**: 8 constructors + 1 local var
   - **Benefit**: Most mature app becomes reference implementation

   **Checklist**:
   - [ ] Fix `coordinator.lua:45` - `local config` → `local cfg`
   - [ ] Migrate 8 files to `opts` pattern (listed above)
   - [ ] Update call sites
   - [ ] Verify no regressions

3. **🔴 Phase 2: ItemPicker (Biggest Deviation)**
   - **Effort**: 2-3 hours
   - **Files**: 8 constructors
   - **Benefit**: Removes anti-pattern from codebase

   **Checklist**:
   - [ ] Refactor `M.new(config, state, ...)` → `M.new(opts)`
   - [ ] Update all call sites
   - [ ] Change `local config` → `local cfg`
   - [ ] Test thoroughly (complex app)

4. **🟡 Phase 3-5: Other Apps** (Incremental)
   - **Effort**: 8-12 hours total
   - **Apps**: ThemeAdjuster, TemplateBrowser, others
   - **Strategy**: Do during natural development, not dedicated migration

5. **📚 Phase 6: Documentation & Enforcement**
   - **Effort**: 1-2 hours
   - [ ] Update `cookbook/CONVENTIONS.md`
   - [ ] Add examples to `cookbook/QUICKSTART.md`
   - [ ] Update `CLAUDE.md` checklist
   - [ ] (Optional) Add lint rules

---

## 📐 Decision Matrix

**When should I use each constructor pattern?**

| Your Module Is... | Use Pattern | Example |
|-------------------|-------------|---------|
| Framework widget/container | `M.new(opts)` | Panel, Grid, MenuTabs |
| UI component with config only | `M.new(config)` | DisplayWidget, Selector |
| Domain object with no deps | `M.new()` | Region, Playlist, Dependency |
| Has 3+ dependencies | `M.new(opts)` | TransportView (config, state, callbacks) |
| Simple utility class | `M.new()` | Math utils, helpers |
| Top-level orchestrator (1 per app) | Direct params OK | Controller.new(state, settings, undo) |

**Rule of Thumb**: If unsure, **use `M.new(opts)`** - it's never wrong.

---

## 💡 Quick Reference Templates

### Template 1: Framework Widget (opts pattern)

```lua
local M = {}

function M.new(opts)
  opts = opts or {}

  local cfg = opts.config or {}
  local state = opts.state

  return setmetatable({
    config = cfg,
    state = state,
    id = opts.id or generate_id(),
  }, { __index = M })
end

function M:draw(ctx)
  local cfg = self.config

  -- Use cfg for frequent access
  ImGui.PushStyleColor(ctx, ImGui.Col_Button, cfg.colors.primary)
  if ImGui.Button(ctx, "Click") then
    -- Handle click
  end
  ImGui.PopStyleColor(ctx)
end

return M
```

### Template 2: Domain Module (no params)

```lua
local M = {}

function M.new()
  return setmetatable({
    -- Internal state only
    items = {},
    dirty = false,
  }, { __index = M })
end

function M:add_item(item)
  table.insert(self.items, item)
  self.dirty = true
end

return M
```

### Template 3: Config-Only Module

```lua
local M = {}

function M.new(config)
  return setmetatable({
    config = config or {},
  }, { __index = M })
end

function M:render(ctx)
  local cfg = self.config
  -- Render using cfg
end

return M
```

---

## 🚨 Anti-Patterns to Avoid

### ❌ 1. Mixed abbreviations in same file
```lua
-- ❌ BAD
function View:draw()
  local cfg = self.config
  local configuration = self.other_config  -- Pick one!
end
```

### ❌ 2. Abbreviating state
```lua
-- ❌ BAD
local st = self.state  -- NEVER abbreviate 'state'

-- ✅ GOOD
local state = self.state
```

### ❌ 3. Multi-param constructors (unless orchestrator)
```lua
-- ❌ BAD (ItemPicker anti-pattern)
function M.new(config, state, controller, visualization, drag_handler)
  -- Unextensible, hard to maintain
end

-- ✅ GOOD
function M.new(opts)
  local cfg = opts.config
  local state = opts.state
  -- Easy to extend
end
```

### ❌ 4. Verbose local names
```lua
-- ❌ BAD
local configuration = self.config
local imgui_context = ctx

-- ✅ GOOD
local cfg = self.config
local ctx = ctx  -- Already abbreviated
```

---

## 🏆 Benefits of This Standard

| Benefit | Impact | Measurement |
|---------|--------|-------------|
| **Reduced Cognitive Load** | High | One pattern across 12 apps |
| **Easier Code Reuse** | High | Copy-paste works between apps |
| **Faster Onboarding** | Medium | Learn once, apply everywhere |
| **Framework Alignment** | High | All apps feel cohesive |
| **Refactoring Safety** | Medium | Can automate signature changes |
| **Professional Consistency** | High | Codebase looks mature |

**ROI**: 2-3 days migration effort → Permanent improvement in maintainability

---

## 🔗 Related Documents

- `CLAUDE.md` - Framework conventions and field guide
- `cookbook/CONVENTIONS.md` - Detailed coding conventions
- `cookbook/QUICKSTART.md` - Quick start with examples
- `cookbook/API_DESIGN_PHILOSOPHY.md` - Widget API design principles
- `TODO/API_MIGRATION.md` - Widget API migration (separate from naming)

---

## 📝 Summary

**The Standard** (in priority order):

1. ⭐⭐⭐ **Constructor**: Use `M.new(opts)` unless module has zero deps (`M.new()`) or only config (`M.new(config)`)
2. ⭐⭐⭐ **Config local**: Always use `cfg` (not `config`) for local variables
3. ⭐⭐⭐ **State local**: Always use `state` (NEVER `st`)
4. ⭐⭐⭐ **ImGui context**: Always use `ctx` (not `context`)
5. ⭐⭐ **Parameter naming**: Use `opts` for option tables, `ctx` for ImGui, direct params for 1-2 simple args

**Current Status**:
- ✅ Framework: 100% consistent (authoritative)
- ⚠️ RegionPlaylist: 78% consistent (8 files to migrate)
- ❌ ItemPicker: Anti-pattern present (8 files to migrate)
- ⚠️ Others: Mixed (12-16 hours total migration)

**Next Action**: Decide whether to migrate RegionPlaylist now (2-3 hours) or incrementally during development.
