# Panel Widget Refactor

> Analysis and roadmap for improving the Panel god-object.

**Current state:** 16 files, 4,788 lines
**Status:** Functional but complex - works well, hard to extend

---

## Executive Summary

Panel is ARKITEKT's most-used container widget. It's feature-complete and stable, but has grown into a god-object that:
- Has 30+ configuration options
- Coordinates 10+ submodules
- Contains a full widget (TabStrip) disguised as a header element
- Mixes app-specific code with framework code

This document proposes incremental refactoring to improve maintainability without breaking existing usage.

---

## Current Architecture

### File Structure

```
panel/
├── init.lua                 (7)    # Re-export coordinator
├── coordinator.lua          (550)  # Main Panel class ← GOD OBJECT
├── defaults.lua             (296)  # Config defaults
├── state.lua                (224)  # State accessors
├── toolbar.lua              (195)  # Unified toolbar API
├── overlay_toolbar.lua      (494)  # Auto-hide toolbars
├── scrolling.lua            (120)  # Scrollbar management
├── content.lua              (75)   # Child window
├── rendering.lua            (140)  # Background/border
├── sidebars.lua             (165)  # Vertical toolbars
├── corner_buttons.lua       (167)  # Corner buttons
├── tab_animator.lua         (107)  # Tab animations
└── header/
    ├── init.lua             (147)  # Header background
    ├── layout.lua           (678)  # Layout engine
    ├── tab_strip.lua        (1403) # ← SHOULD BE SEPARATE WIDGET
    └── separator.lua        (36)   # Separator element
```

### Dependency Graph

```
coordinator.lua
├── toolbar.lua
│   ├── header/init.lua
│   │   └── header/layout.lua
│   │       ├── header/tab_strip.lua (1403 lines!)
│   │       └── header/separator.lua
│   └── sidebars.lua
├── overlay_toolbar.lua
│   ├── header/init.lua
│   └── sidebars.lua
├── content.lua
├── scrolling.lua
├── rendering.lua
├── corner_buttons.lua
├── state.lua
└── defaults.lua
```

---

## Problems

### 1. TabStrip is a Full Widget (1,403 lines)

**Location:** `header/tab_strip.lua`

This "header element" has:
- Drag-and-drop reordering with position clamping
- Responsive width calculation (3 different strategies)
- Overflow handling with menu button
- Context menus with color pickers
- Inline text editing
- Spawn/destroy animations
- 20+ local functions

**Impact:** Can't reuse tabs outside Panel headers. Changes to tab behavior require understanding Panel internals.

### 2. Configuration Sprawl

**Location:** `defaults.lua`

```lua
config = {
  -- Basic styling (5 options)
  bg_color, border_color, border_thickness, rounding, padding,

  -- Behavior (1 option)
  disable_window_drag,

  -- Scrolling (4 options)
  scroll = { flags, custom_scrollbar, bg_color, scrollbar_config },

  -- Anti-jitter (3 options)
  anti_jitter = { enabled, track_scrollbar, height_threshold },

  -- Background pattern (6+ options)
  background_pattern = { enabled, primary = {...}, secondary = {...} },

  -- Header/Footer - LEGACY (8+ options each)
  header = { enabled, height, position, bg_color, rounding, padding, elements },
  footer = {...},

  -- Toolbars - NEW (4 positions × 8+ options)
  toolbars = { top, bottom, left, right },

  -- Overlay toolbars (4 positions × 10+ options)
  overlay_toolbars = { top, bottom, left, right },

  -- Sidebars - LEGACY (8+ options each)
  left_sidebar = { enabled, width, valign, elements },
  right_sidebar = {...},

  -- Corner buttons (6+ options)
  corner_buttons = { size, margin, min_width_to_show, top_left, top_right, ... },
  corner_buttons_always_visible,
}
```

**Impact:** Steep learning curve. Easy to misconfigure. Hard to document.

### 3. App-Specific Code in Framework

**Location:** `header/layout.lua:43-144`

```lua
COMPONENTS.template_header_controls = {
  draw = function(ctx, dl, x, y, width, height, config, state)
    -- 100 lines of TemplateBrowser-specific UI
  end,
}
```

**Impact:** Framework bloat. Sets bad precedent.

### 4. State Scattered Across Instance

**Location:** `coordinator.lua:46-89`

```lua
local panel = setmetatable({
  -- Identity
  id, _panel_id,
  config,

  -- Dimensions (computed)
  width, height,
  child_width, child_height, child_x, child_y,
  actual_child_height, visible_bounds,
  header_height, footer_height,

  -- Scrollbar state
  had_scrollbar_last_frame, scrollbar_size, scrollbar,

  -- Tab state
  tabs, active_tab_id,

  -- Mode state
  current_mode,

  -- Animation state
  overlay_toolbar_animations,

  -- Internal flags
  _child_began_successfully, _id_scope_pushed,
  _overflow_visible, _corner_button_bounds,
}, Panel)
```

**Impact:** No clear distinction between config, state, and computed values. Hard to serialize/restore.

### 5. Implicit Z-Order

**Location:** `coordinator.lua:begin_draw()` and `end_draw()`

Drawing order:
1. Background → `rendering.draw_background()`
2. Top toolbar bg → `Toolbar.draw_background()`
3. Bottom toolbar bg → `Toolbar.draw_background()`
4. Pattern → `Pattern.draw()`
5. Border → `Rendering.draw_border()`
6. Toolbar elements → `Toolbar.draw_elements()` (×4)
7. Child window → `Content.begin_child()`
8. [User content]
9. Scrollbar update → `Scrolling.update_scrollbar()`
10. Child end → `Content.end_child()`
11. Overlay toolbars → `OverlayToolbar.draw()` (×4)
12. Scrollbar render → `Scrolling.draw_scrollbar()`
13. Corner buttons → `CornerButtons.draw()`

**Impact:** Adding features requires finding correct insertion point. Easy to break layering.

---

## Refactoring Phases

### Phase 1: Extract TabStrip Widget

**Risk:** Low
**Effort:** 2-3 hours
**Breaking changes:** None

#### Actions

1. **Move file:**
   ```
   panel/header/tab_strip.lua → widgets/navigation/tab_strip.lua
   ```

2. **Update import in `header/layout.lua`:**
   ```lua
   -- Before
   tab_strip = require('arkitekt.gui.widgets.containers.panel.header.tab_strip'),

   -- After
   tab_strip = require('arkitekt.gui.widgets.navigation.tab_strip'),
   ```

3. **Move `tab_animator.lua`:**
   ```
   panel/tab_animator.lua → widgets/navigation/tab_animator.lua
   ```

4. **Export from widgets index** (if exists)

#### Benefits

- TabStrip usable outside Panel
- Clear ownership of 1,500+ lines
- Easier to test independently

---

### Phase 2: Remove App-Specific Code

**Risk:** Low
**Effort:** 1-2 hours
**Breaking changes:** TemplateBrowser needs update

#### Actions

1. **Remove from `header/layout.lua`:**
   ```lua
   -- Delete lines 43-144 (template_header_controls)
   ```

2. **Create in TemplateBrowser:**
   ```lua
   -- scripts/TemplateBrowser/ui/header_controls.lua
   local M = {}

   function M.draw(ctx, dl, x, y, width, height, config, state)
     -- Move the 100 lines here
   end

   function M.measure(ctx, config, state)
     return 0
   end

   return M
   ```

3. **Register as custom element:**
   ```lua
   -- In TemplateBrowser setup
   local HeaderControls = require('scripts.TemplateBrowser.ui.header_controls')

   panel_config.toolbars.top.elements = {
     { type = "custom", id = "controls", config = { on_draw = HeaderControls.draw } }
   }
   ```

#### Benefits

- Framework stays generic
- App owns its custom UI
- Sets correct pattern for others

---

### Phase 3: Consolidate Small Modules

**Risk:** Low
**Effort:** 1 hour
**Breaking changes:** None (internal only)

#### Actions

1. **Merge `rendering.lua` into `coordinator.lua`:**
   - Only 2 functions (140 lines)
   - Only used by coordinator
   - Reduces file count

2. **Merge `content.lua` into `coordinator.lua`:**
   - Only 2 functions (75 lines)
   - Only used by coordinator

3. **Inline `init.lua`:**
   - Just `return require('...coordinator')`
   - Can be replaced with direct import

#### Result

```
panel/
├── coordinator.lua    (+215 lines, self-contained core)
├── defaults.lua
├── state.lua
├── toolbar.lua
├── overlay_toolbar.lua
├── scrolling.lua
├── sidebars.lua
├── corner_buttons.lua
└── header/
    ├── init.lua
    ├── layout.lua
    └── separator.lua
```

13 files → 11 files, clearer boundaries.

---

### Phase 4: Config Builder Pattern

**Risk:** Medium
**Effort:** 4-6 hours
**Breaking changes:** None (additive API)

#### New API

```lua
-- Current (still works)
local panel = Panel.new({
  config = {
    toolbars = { top = { height = 30, elements = {...} } },
    corner_buttons = { bottom_left = {...} },
  }
})

-- New fluent builder (optional)
local panel = Panel.builder()
  :id("my_panel")
  :size(300, 400)
  :toolbar("top", { height = 30 })
    :button("settings", { icon = "⚙", on_click = fn })
    :search("query", { placeholder = "Search..." })
  :end_toolbar()
  :toolbar("bottom", { height = 24 })
    :button("add", { icon = "+", on_click = fn })
  :end_toolbar()
  :corner_button("bottom_left", { icon = "⚙", on_click = fn })
  :pattern("grid", { spacing = 50 })
  :build()
```

#### Implementation

```lua
-- panel/builder.lua
local M = {}

function M.new()
  return setmetatable({
    _config = { toolbars = {} },
    _current_toolbar = nil,
  }, { __index = M })
end

function M:id(id)
  self._id = id
  return self
end

function M:size(w, h)
  self._width = w
  self._height = h
  return self
end

function M:toolbar(position, opts)
  opts = opts or {}
  opts.enabled = true
  opts.elements = {}
  self._config.toolbars[position] = opts
  self._current_toolbar = position
  return self
end

function M:button(id, opts)
  local toolbar = self._config.toolbars[self._current_toolbar]
  toolbar.elements[#toolbar.elements + 1] = {
    type = "button", id = id, config = opts
  }
  return self
end

function M:end_toolbar()
  self._current_toolbar = nil
  return self
end

function M:build()
  local Panel = require('arkitekt.gui.widgets.containers.panel')
  return Panel.new({
    id = self._id,
    width = self._width,
    height = self._height,
    config = self._config,
  })
end

-- Convenience
Panel.builder = M.new

return M
```

#### Benefits

- Discoverable API (autocomplete-friendly)
- Validates config during construction
- Documents usage through method names
- Backward compatible

---

### Phase 5: State Normalization

**Risk:** Medium
**Effort:** 3-4 hours
**Breaking changes:** Minor (state accessors may change)

#### Current Problem

State mixed with computed values:

```lua
panel.child_width   -- Computed each frame
panel.tabs          -- User-provided state
panel.scrollbar     -- Instance state
panel._overflow_visible  -- Internal flag
```

#### Proposed Structure

```lua
-- panel/panel_state.lua
local M = {}

function M.new(panel_id)
  return {
    -- User-controlled
    tabs = {},
    active_tab_id = nil,
    current_mode = nil,
    search_text = "",
    sort_mode = nil,
    sort_direction = "asc",

    -- Internal (prefixed)
    _scroll_y = 0,
    _overflow_visible = false,
    _overlay_animations = {},
  }
end

function M.serialize(state)
  return {
    tabs = state.tabs,
    active_tab_id = state.active_tab_id,
    current_mode = state.current_mode,
  }
end

function M.deserialize(data)
  -- Restore from saved
end

return M
```

#### Computed Values (Not State)

```lua
-- In Panel instance, recomputed each frame
panel._computed = {
  child_x, child_y, child_width, child_height,
  visible_bounds,
  header_height, footer_height,
  toolbar_sizes = { top, bottom, left, right },
}
```

#### Benefits

- Clear what to persist vs. recompute
- Easier debugging (state is small, computed is derived)
- Can add undo/redo for state changes

---

### Phase 6: Composition Architecture (Future)

**Risk:** High
**Effort:** 2-3 weeks
**Breaking changes:** Major (new API)

This is a longer-term vision, not immediate action.

#### Concept

Instead of one Panel with 30 options, compose smaller pieces:

```lua
-- Base containers
local ScrollContainer = require('arkitekt.gui.widgets.containers.scroll')
local ToolbarContainer = require('arkitekt.gui.widgets.containers.toolbar')

-- Compose
local MyPanel = ToolbarContainer.wrap(ScrollContainer.new({
  id = "my_panel",
  width = 300,
  height = 400,
}))

MyPanel:add_toolbar("top", { ... })
```

#### Benefits

- Pick only features you need
- Each piece testable independently
- Smaller bundle for simple use cases
- Clear extension points

#### Downsides

- Learning curve for composition
- More boilerplate for full-featured panels
- Migration effort for existing code

**Recommendation:** Defer to v2.0 or separate widget set.

---

## Quick Wins (Do First)

| Task | Risk | Effort | Impact |
|------|------|--------|--------|
| Extract TabStrip | Low | 2h | High - reusable widget |
| Remove template_header_controls | Low | 1h | Medium - cleaner framework |
| Merge rendering.lua + content.lua | Low | 1h | Low - fewer files |

## Medium Term

| Task | Risk | Effort | Impact |
|------|------|--------|--------|
| Config Builder | Medium | 4h | High - better DX |
| State Normalization | Medium | 3h | Medium - cleaner internals |

## Long Term

| Task | Risk | Effort | Impact |
|------|------|--------|--------|
| Composition Architecture | High | 2-3w | High - but breaking |

---

## Success Metrics

After Phase 1-3:
- [ ] TabStrip usable outside Panel headers
- [ ] No app-specific code in `arkitekt/gui/widgets/`
- [ ] Panel directory has ≤12 files
- [ ] Total Panel LOC reduced by ~200

After Phase 4-5:
- [ ] Panel.builder() documented and used in ≥1 app
- [ ] Panel state serializable for persistence
- [ ] State vs. computed clearly separated

---

## Notes

- Panel works. Don't break it chasing perfection.
- Refactors should be incremental, each phase shippable.
- Test with RegionPlaylist and TemplateBrowser (heavy Panel users).
- Keep backward compatibility until v2.0.
