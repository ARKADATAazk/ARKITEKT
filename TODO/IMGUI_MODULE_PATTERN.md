# ImGui Module Function Pattern - Architectural Standard

> **Decision**: App views should use ImGui-style module functions, NOT retained instances
> **Date**: 2025-12-01
> **Status**: ✅ APPROVED - Ready for implementation
> **Priority**: 🔴 HIGH - Fundamental architecture alignment

---

## 🎯 The Decision

**App views (TransportView, LayoutView, etc.) should use module functions like ImGui, not retained OOP instances.**

### What This Means

**BEFORE (Current - Retained Instances)**:
```lua
-- View definition
function TransportView.new(config, state)
  return setmetatable({ config = config, state = state }, TransportView)
end

function TransportView:draw(ctx, shell_state)
  -- Use self.config, self.state
end

-- Usage
self.transport_view = TransportView.new(Config.TRANSPORT, State)
self.transport_view:draw(ctx, shell_state)
```

**AFTER (ImGui-Style - Module Functions)**:
```lua
-- View definition
local view = {}  -- Module-level state

function M.init(config, state)
  view.config = config
  view.state = state
end

function M.draw(ctx, shell_state)
  -- Use view.config, view.state
end

-- Usage
TransportView.init(Config.TRANSPORT, State)
TransportView.draw(ctx, shell_state)  -- No self, just function call
```

---

## 📋 Why This Pattern?

### 1. ImGui Alignment ⭐⭐⭐

**ImGui Demo Pattern** (references/imgui/ReaImGui_Demo.lua):
```lua
-- Module-level state
local demo = {
  open = true,
  menu = { enabled = true },
  widgets = {},
}

-- Module functions (not methods)
function demo.ShowDemoWindow(open)
  -- Access demo.* directly
  if demo.no_titlebar then ... end
end

-- Called every frame
demo.ShowDemoWindow(demo.open)
```

**ARKITEKT should match this exactly** - it's what ReaImGui users know!

---

### 2. LLM Friendliness ⭐⭐⭐

**Module functions are clearer for LLMs**:

```lua
-- ✅ CLEAR - Module function with explicit state
function M.draw(ctx, shell_state)
  local cfg = view.config  -- Explicit where config comes from
  local state = view.state
end

-- ❌ CONFUSING - Instance method with hidden state
function TransportView:draw(ctx, shell_state)
  local cfg = self.config  -- Where is self from? Metatables? OOP?
end
```

**LLMs understand**:
- Module tables (simple)
- Module functions (simple)

**LLMs struggle with**:
- Lua metatables
- `self` / `:` method syntax
- Retained instances

---

### 3. Simplicity ⭐⭐

**No OOP complexity**:
```lua
-- Module pattern - Just tables and functions
local view = {}
function M.init(config) view.config = config end
function M.draw(ctx) -- use view.config end

-- vs Instance pattern - Metatables, self, :
local View = {}
View.__index = View
function View.new(config) return setmetatable({ config = config }, View) end
function View:draw(ctx) -- use self.config end
```

The module pattern is **fundamentally simpler** - fewer concepts to understand.

---

### 4. Copy-Paste Friendly ⭐⭐

**With module functions**, you can copy ImGui demo patterns directly:

```lua
-- ImGui demo pattern
function demo.ShowExampleAppLayout()
  if not app.layout then
    app.layout = { selected = 0 }
  end

  ImGui.Begin(ctx, 'Example: Simple layout')
  -- ...
  ImGui.End(ctx)
end

-- ARKITEKT can match this exactly
function M.draw(ctx)
  if not view.initialized then
    view.selected = 0
  end

  Ark.Panel(ctx, { ... })
  -- ...
end
```

**With instance methods**, you have to translate OOP patterns.

---

## 📊 Pattern Comparison

| Aspect | Module Functions (ImGui) | Retained Instances (Current) |
|--------|-------------------------|------------------------------|
| **ImGui alignment** | ✅ Exact match | ❌ Different paradigm |
| **LLM clarity** | ✅ Simple, explicit | ❌ OOP confusion |
| **State visibility** | ✅ Module-level (clear) | ❌ Instance (hidden in self) |
| **Copy-paste from ImGui** | ✅ Direct | ❌ Requires translation |
| **Multiple instances** | ❌ One per module | ✅ Many instances |
| **Code verbosity** | ✅ Less (no self:) | ❌ More (:method syntax) |
| **Lua idioms** | ✅ Module pattern | ⚠️ OOP (less common) |

**Winner**: Module Functions (5:2 for key criteria)

---

## 🎯 When to Use Each Pattern

### Use Module Functions (ImGui-Style) ✅

**For**: App views, screens, UI orchestrators

**When**:
- Only ONE instance needed (one transport view, one layout view)
- Want ImGui alignment
- Target audience includes LLMs or ImGui users
- Complex view with many helpers (better to avoid passing self everywhere)

**Examples**:
- `TransportView` - One transport control panel
- `LayoutView` - One layout manager
- `OverflowModalView` - One modal (singleton)
- `PreferencesView` - One preferences screen

---

### Use Retained Instances (OOP-Style) ⚠️

**For**: Domain objects, data structures

**When**:
- MULTIPLE instances needed
- Object represents data/entity (not UI)
- Need polymorphism

**Examples**:
- `Region` - Many region objects
- `PlaybackEngine` - Multiple engines
- `AnimationController` - Many animation instances
- Domain models where you need `region1`, `region2`, etc.

---

### Use Immediate Mode (Framework Widgets) ✅

**For**: Framework widgets/containers

**When**:
- Called every frame
- Stateless or internal state only
- Part of public widget API

**Examples**:
- `Ark.Button(ctx, "Save")` - Already doing this!
- `Ark.Grid(ctx, opts)` - Already doing this!
- `Ark.Panel(ctx, opts)` - Already doing this!

---

## 🔧 Migration Pattern

### Standard Template

```lua
-- ============================================================================
-- MODULE-LEVEL STATE (ImGui-style)
-- ============================================================================

local M = {}

-- Private state (like ImGui demo.* tables)
local view = {
  config = nil,
  state = nil,
  -- ... other state
}

-- ============================================================================
-- INITIALIZATION (Called once at app startup)
-- ============================================================================

--- Initialize the view with configuration and state
--- @param config table View configuration
--- @param state_module table State module reference
function M.init(config, state_module)
  view.config = config
  view.state = state_module
  -- Initialize any sub-components
end

-- ============================================================================
-- PRIVATE HELPERS (Access view.* directly)
-- ============================================================================

local function build_play_button(ctx, bridge_state)
  local cfg = view.config  -- Access module state
  -- ...
end

-- ============================================================================
-- PUBLIC DRAW FUNCTION (Called every frame)
-- ============================================================================

--- Draw the view
--- @param ctx ImGui_Context
--- @param shell_state table Current shell state
function M.draw(ctx, shell_state)
  -- Access view.config, view.state directly
  local bridge = view.state.get_bridge()

  -- Build UI using helpers
  local play_btn = build_play_button(ctx, bridge_state)
  -- ...
end

return M
```

---

## 📋 Migration Checklist

### RegionPlaylist Views (6 files)

**High Priority** (Complex views):
- [ ] `ui/views/transport/transport_view.lua` - 892 lines, 14 methods → module functions
- [ ] `ui/views/layout_view.lua` - Large view → module functions
- [ ] `ui/views/overflow_modal_view.lua` - Modal view → module functions

**Medium Priority** (State managers):
- [ ] `ui/state/preferences.lua` - Preferences manager → module functions
- [ ] `ui/state/notification.lua` - Simple, could stay as-is or migrate
- [ ] `ui/state/animation.lua` - Already `new()` no params, minimal changes

**Low Priority** (Controllers - Keep as-is?)**:
- `app/controller.lua` - Main controller (3 params) - **Discuss**: Keep OOP or migrate?

---

## 🎯 Step-by-Step Migration (Example: TransportView)

### Step 1: Convert State to Module-Level

**Before**:
```lua
local TransportView = {}
TransportView.__index = TransportView

function M.new(config, state_module)
  return setmetatable({
    config = config,
    state = state_module,
    container = nil,
    transport_display = DisplayWidget.new(config.display),
  }, TransportView)
end
```

**After**:
```lua
local M = {}

-- Module-level state (like ImGui demo)
local view = {
  config = nil,
  state = nil,
  container = nil,
  transport_display = nil,
}

function M.init(config, state_module)
  view.config = config
  view.state = state_module
  view.transport_display = DisplayWidget.new(config.display)
  view.container = TransportContainer.new({
    id = "region_playlist_transport",
    height = config.height,
    -- ...
  })
end
```

---

### Step 2: Convert Methods to Module Functions

**Before**:
```lua
function TransportView:build_play_button(bridge_state)
  local cfg = self.config
  -- ...
end

function TransportView:draw(ctx, shell_state)
  local bridge = self.state.get_bridge()
  local play_btn = self:build_play_button(bridge_state)
  -- ...
end
```

**After**:
```lua
-- Private helper (local function)
local function build_play_button(ctx, bridge_state)
  local cfg = view.config  -- Access module state
  -- ...
end

-- Public module function
function M.draw(ctx, shell_state)
  local bridge = view.state.get_bridge()
  local play_btn = build_play_button(ctx, bridge_state)
  -- ...
end
```

---

### Step 3: Update Call Sites

**Before (gui.lua)**:
```lua
function GUI:init()
  self.transport_view = TransportView.new(Config.TRANSPORT, State)
  self.layout_view = LayoutView.new(Config, State)
end

function GUI:draw(ctx)
  self.transport_view:draw(ctx, shell_state)
  self.layout_view:draw(ctx)
end
```

**After (gui.lua)**:
```lua
function GUI:init()
  -- Initialize views (module functions, not constructors)
  TransportView.init(Config.TRANSPORT, State)
  LayoutView.init(Config, State)
end

function GUI:draw(ctx)
  -- Call module functions directly
  TransportView.draw(ctx, shell_state)
  LayoutView.draw(ctx)
end
```

---

## 🏆 Benefits Summary

**After migration, developers will**:

1. ✅ **Match ImGui patterns exactly** - Familiar to ReaImGui users
2. ✅ **Reduce cognitive load** - No OOP, just tables and functions
3. ✅ **Improve LLM assistance** - Clearer, more predictable code
4. ✅ **Enable direct copy-paste** - ImGui demo patterns work as-is
5. ✅ **Simplify onboarding** - Fewer Lua concepts to learn
6. ✅ **Align with framework** - Widgets already use immediate mode

**Migration Effort**: ~2-3 hours for RegionPlaylist (6 files)

**Long-term Benefit**: Every future view/screen follows clear, predictable pattern

---

## 📚 Related Documents

- `TODO/API_MIGRATION.md` - Widget API migration (already done!)
- `TODO/NAMING_STANDARDS.md` - Naming conventions (now less relevant)
- `cookbook/API_DESIGN_PHILOSOPHY.md` - Widget design philosophy
- `references/imgui/ReaImGui_Demo.lua` - Reference implementation

---

## ✅ Next Actions

1. **Migrate TransportView** - Largest view, most methods (892 lines)
2. **Migrate LayoutView** - Second largest
3. **Migrate OverflowModalView** - Third view
4. **Update GUI.lua** - Change from `view:draw()` to `View.draw()`
5. **Test thoroughly** - Verify all views work
6. **Update CLAUDE.md** - Add module function pattern to conventions

**Start with**: TransportView (most complex, best test case)
