# TreeView Widget Refactor TODO

> Consolidate sandbox_4 (TreeView v3.5) and sandbox_5 (TreeColumns) into production-ready framework widgets with easy-to-use opts API while respecting ImGui conventions where applicable.

---

## Current State

| Component | Lines | Status |
|-----------|-------|--------|
| `arkitekt/gui/widgets/navigation/tree_view.lua` | 706 | Production, limited features |
| `scripts/Sandbox/sandbox_4.lua` | 1926 | Prototype, full TreeView |
| `scripts/Sandbox/sandbox_5.lua` | 1649 | Prototype, TreeView + Columns |
| `scripts/TemplateBrowser/ui/views/tree_view.lua` | 1173 | Wrapper around framework TreeView |

**Gap**: Framework TreeView lacks keyboard nav, virtual scroll, type-search, columns that sandbox prototypes have.

---

## Design Principles

### 1. Ease of Use (Primary Goal)

```lua
-- Minimal: 2 lines for basic tree
local state = TreeView.create_state()
local result = TreeView.draw(ctx, {nodes = data, state = state})

-- Full-featured: add booleans, not complexity
local result = TreeView.draw(ctx, {
  nodes = data,
  state = state,
  enable_multi_select = true,
  enable_keyboard = true,
  enable_rename = true,
  on_select = function(event) ... end,
})
```

### 2. ImGui Alignment (Where Applicable)

**Keep:**
- Immediate mode (no retained objects)
- External state (you own it)
- ID-based nodes for stability

**Improve:**
- Opts table instead of positional args
- Callbacks instead of inline checks
- Result object for "what happened"
- Feature flags instead of bit manipulation

### 3. Layered Architecture (Maintainability)

```
arkitekt/gui/widgets/navigation/
├── tree/
│   ├── core.lua           -- Base rendering (~200 LOC)
│   ├── state.lua          -- State factory + helpers (~100 LOC)
│   ├── selection.lua      -- Single/multi-select (~150 LOC)
│   ├── keyboard.lua       -- Arrow nav, Home/End (~200 LOC)
│   ├── virtual_scroll.lua -- Render visible only (~100 LOC)
│   ├── drag_drop.lua      -- Drag with preview (~200 LOC)
│   ├── icons.lua          -- Folder, file icons (~150 LOC)
│   ├── lines.lua          -- Tree lines (~100 LOC)
│   ├── columns.lua        -- Headers, sorting (~300 LOC)
│   ├── rename.lua         -- Inline rename (~100 LOC)
│   ├── search.lua         -- Filter + highlight (~150 LOC)
│   ├── lazy.lua           -- Lazy child loading (~100 LOC)
│   └── theme.lua          -- Theme integration (~50 LOC)
│
├── tree_view.lua          -- Standard tree (composes modules)
└── tree_columns.lua       -- Column tree (extends tree_view)
```

---

## API Design

### State Factory

Reduce boilerplate with sensible defaults:

```lua
-- Basic state
local state = TreeView.create_state()

-- With options
local state = TreeView.create_state({
  default_open = {"root", "src"},     -- Initially expanded
  default_selected = "readme",         -- Initially selected
  persist_key = "my_tree",             -- Auto-persist to ExtState
  persist_scope = "project",           -- "global" | "project"
})

-- State structure (for reference)
state = {
  open = {},           -- {[node_id] = true}
  selected = {},       -- {[node_id] = true} or single id
  focused = nil,       -- Keyboard focus
  anchor = nil,        -- Shift-selection anchor
  scroll_y = 0,        -- Virtual scroll position
  renaming = nil,      -- Node being renamed
  rename_buffer = "",  -- Rename text
  filter = "",         -- Current filter string
  loading = {},        -- {[node_id] = true} for async loading
}

-- Persistence helpers
TreeView.save_state(state)    -- Manual save
TreeView.load_state(state)    -- Manual load
```

### Node Format

```lua
local nodes = {
  {
    id = "unique_id",           -- Required
    name = "Display Name",      -- Required
    children = {...},           -- Optional, nested nodes
    has_children = true,        -- For lazy loading (no children array)
    color = 0xRRGGBBAA,         -- Optional, icon/text tint
    icon = "folder",            -- "folder" | "file" | "lua" | "md" | custom
    is_virtual = false,         -- Virtual folder styling
    disabled = false,           -- Grayed out, not selectable
    data = {...},               -- User data (for columns, etc.)
  },
}
```

### Full Options Reference

```lua
TreeView.draw(ctx, {
  -- Required
  nodes = nodes,
  state = state,

  -- Dimensions (auto from cursor/available if nil)
  x = nil,
  y = nil,
  width = nil,
  height = nil,

  -- Core Features (all default false)
  enable_multi_select = false,
  enable_keyboard = false,        -- Arrows, Home/End, PgUp/PgDown
  enable_rename = false,          -- F2, double-click
  enable_drag_drop = false,
  enable_virtual_scroll = false,  -- For large trees (1000+ nodes)
  enable_lines = false,           -- Tree connector lines
  enable_search = false,          -- Type-to-search, Ctrl+F
  enable_checkboxes = false,      -- Tri-state checkboxes
  enable_lazy_load = false,       -- Load children on demand

  -- Visual
  show_icons = true,
  show_colors = true,
  line_style = "dotted",          -- "solid" | "dotted"
  item_height = 17,
  indent_width = 22,

  -- Empty/Loading States
  empty_message = "No items",     -- Shown when nodes is empty
  loading = false,                -- Show loading indicator
  loading_message = "Loading...",

  -- Theming (overrides Theme.COLORS defaults)
  theme = {
    bg = nil,                     -- Falls back to Theme.COLORS.BG_BASE
    bg_hover = nil,
    bg_selected = nil,
    text = nil,
    text_hover = nil,
    text_disabled = nil,
    line_color = nil,
    icon_color = nil,
    accent = nil,                 -- Selection bar, focus ring
  },

  -- Filter/Search
  filter = "",                    -- Hide non-matching nodes
  filter_mode = "highlight",      -- "highlight" | "hide" | "collapse"
  case_sensitive = false,

  -- Undo Integration
  undo_manager = nil,             -- Auto-push rename/drop to undo stack

  -- Callbacks (rich event objects)
  on_select = function(event) end,
  on_toggle = function(event) end,
  on_rename = function(event) end,
  on_delete = function(event) end,
  on_drop = function(event) end,
  on_double_click = function(event) end,
  on_right_click = function(event) end,
  on_lazy_load = function(event) end,  -- Return children or promise

  -- Guards
  can_select = function(node) return true end,
  can_rename = function(node) return true end,
  can_drag = function(node) return true end,
  can_drop = function(source, target, position) return true end,

  -- Context Menu
  context_menu_id = nil,
  render_context_menu = function(ctx, node) end,

  -- Custom Rendering
  render_icon = function(ctx, dl, node, x, y, opts) end,
  render_label = function(ctx, dl, node, x, y, opts) end,
  render_row = function(ctx, dl, node, rect, opts) end,  -- Full control
})
```

### Rich Event Objects

All callbacks receive rich context:

```lua
on_select = function(event)
  event.node           -- The node
  event.nodes          -- All affected nodes (for multi-select)
  event.selection      -- Full current selection
  event.previous       -- Previous selection
  event.modifiers      -- {ctrl = bool, shift = bool, alt = bool}
  event.source         -- "click" | "keyboard" | "api" | "double_click"
  event.prevent()      -- Cancel the action
end

on_drop = function(event)
  event.source_nodes   -- Nodes being dragged
  event.target_node    -- Drop target
  event.position       -- "before" | "into" | "after"
  event.copy           -- true if Ctrl held (copy instead of move)
  event.modifiers      -- {ctrl, shift, alt}
  event.prevent()      -- Cancel the drop
end

on_rename = function(event)
  event.node           -- The node
  event.old_name       -- Previous name
  event.new_name       -- New name
  event.prevent()      -- Cancel rename
end

on_lazy_load = function(event)
  event.node           -- Node being expanded
  event.done(children) -- Call with children array when loaded
  event.error(msg)     -- Call on error
  -- Or return children directly for sync loading
  return children
end
```

### Result Object

```lua
local result = TreeView.draw(ctx, opts)

-- Events this frame
result.clicked           -- Node clicked
result.double_clicked    -- Node double-clicked
result.right_clicked     -- Node right-clicked
result.toggled           -- {node, is_open}
result.renamed           -- {node, old_name, new_name}
result.dropped           -- {sources, target, position, copy}
result.deleted           -- Node deleted
result.selection_changed -- true if selection changed

-- Current state
result.hovered           -- Node under mouse
result.focused           -- Keyboard focused node
result.visible_count     -- Visible after filter
result.total_count       -- Total nodes
result.is_loading        -- Any node loading children

-- For integration
result.needs_repaint     -- Something visual changed
result.scroll_changed    -- Scroll position changed
```

---

## TreeColumns Extension

```lua
local result = TreeColumns.draw(ctx, {
  -- All TreeView options, plus:

  columns = {
    {
      id = "name",
      title = "Name",
      width = 250,
      min_width = 100,
      max_width = 500,
      sortable = true,
      resizable = true,
      render_tree = true,        -- Shows tree structure
      get_value = function(node) return node.name end,
      render = function(ctx, dl, node, rect) end,  -- Custom cell render
    },
    {
      id = "size",
      title = "Size",
      width = 80,
      align = "right",           -- "left" | "center" | "right"
      sortable = true,
      sort_compare = function(a, b) ... end,  -- Custom sort
      get_value = function(node) return node.data.size end,
    },
  },

  -- Column options
  enable_column_resize = true,
  enable_column_reorder = false,  -- Future: drag columns
  enable_column_hide = false,     -- Future: context menu to hide
  header_height = 22,
  persist_columns = false,        -- Remember widths/order

  -- Column callbacks
  on_sort = function(column_id, ascending) end,
  on_column_resize = function(column_id, new_width) end,
})
```

---

## Edge Cases & Error Handling

### Empty States

```lua
-- Empty tree
TreeView.draw(ctx, {
  nodes = {},
  empty_message = "No folders yet",
  empty_action = {
    label = "Create Folder",
    on_click = function() ... end,
  },
})
```

### Loading States

```lua
-- Global loading
TreeView.draw(ctx, {
  nodes = nil,
  loading = true,
  loading_message = "Scanning...",
})

-- Per-node loading (lazy children)
TreeView.draw(ctx, {
  nodes = nodes,
  enable_lazy_load = true,
  on_lazy_load = function(event)
    fetch_children_async(event.node.id, function(children)
      event.done(children)
    end)
  end,
})
```

### Error States

```lua
-- Node-level error (failed to load children)
state.errors["node_id"] = "Failed to load"

-- Widget shows error indicator, retry option
```

### Deep Nesting

- Virtual scroll handles any depth efficiently
- Indent clamps at max depth to prevent overflow
- Collapse-all provides escape hatch

### Wide Trees (1000+ siblings)

- Virtual scroll only renders visible
- Type-to-search jumps to match
- Alphabetical sort helps navigation

---

## Undo Integration

When `undo_manager` provided, widget auto-pushes:

```lua
TreeView.draw(ctx, {
  undo_manager = app.undo_manager,
  on_rename = function(event)
    -- Widget already pushed undo; callback is for side effects
    save_to_disk(event.node)
  end,
  on_drop = function(event)
    -- Widget pushed undo; callback for additional logic
    update_references(event.source_nodes, event.target_node)
  end,
})

-- Undo entry format
{
  description = "Rename: old_name -> new_name",
  undo_fn = function() ... end,
  redo_fn = function() ... end,
}
```

---

## Theming Integration

Widget uses `Theme.COLORS` by default, with overrides:

```lua
-- In tree/theme.lua
local function get_color(opts_theme, key, default_key)
  if opts_theme and opts_theme[key] then
    return opts_theme[key]
  end
  return Theme.COLORS[default_key]
end

-- Usage in rendering
local bg_selected = get_color(opts.theme, "bg_selected", "ACCENT_DIM")
```

Theme reads every frame (not cached) so hot-reload works.

---

## Testing Strategy

### Unit Tests (per module)

```lua
-- tests/tree/selection_test.lua
describe("selection", function()
  it("handles ctrl+click toggle", function()
    local state = {selected = {a = true}}
    selection.handle_click(state, "b", {ctrl = true})
    assert.equals(state.selected, {a = true, b = true})
  end)

  it("handles shift+click range", function()
    local flat = {"a", "b", "c", "d"}
    local state = {selected = {a = true}, anchor = "a"}
    selection.handle_click(state, "c", {shift = true}, flat)
    assert.equals(state.selected, {a = true, b = true, c = true})
  end)
end)
```

### Integration Tests

```lua
-- tests/tree_view_test.lua
describe("TreeView", function()
  it("renders empty state", function()
    local result = TreeView.draw(ctx, {nodes = {}, empty_message = "Empty"})
    assert.equals(result.visible_count, 0)
  end)

  it("expands on arrow click", function()
    local state = TreeView.create_state()
    TreeView.draw(ctx, {nodes = nested_nodes, state = state})
    simulate_click(arrow_position)
    assert.is_true(state.open["parent_id"])
  end)
end)
```

### Performance Benchmarks

```lua
-- benchmarks/tree_virtual_scroll.lua
local nodes = generate_deep_tree(10000)  -- 10k nodes

benchmark("render 10k nodes", function()
  TreeView.draw(ctx, {
    nodes = nodes,
    state = state,
    enable_virtual_scroll = true,
  })
end)
-- Target: <2ms per frame
```

---

## Migration Plan

### Phase 1: Foundation (~4 hours)
- [ ] Create `tree/` directory structure
- [ ] Implement `state.lua` (factory, persistence)
- [ ] Implement `theme.lua` (color integration)
- [ ] Extract `core.lua` from sandbox_4

### Phase 2: Core Features (~4 hours)
- [ ] Extract `selection.lua` (single/multi, modifiers)
- [ ] Extract `keyboard.lua` (full navigation)
- [ ] Extract `icons.lua` (all icon types)
- [ ] Extract `lines.lua` (solid/dotted)

### Phase 3: Advanced Features (~4 hours)
- [ ] Extract `drag_drop.lua` (preview, multi-drag, copy)
- [ ] Extract `rename.lua` (F2, double-click, validation)
- [ ] Extract `search.lua` (filter, highlight, Ctrl+F)
- [ ] Extract `lazy.lua` (async loading, error states)

### Phase 4: Compose TreeView (~3 hours)
- [ ] Create `tree_view.lua` composing all modules
- [ ] Implement full opts API
- [ ] Implement rich event objects
- [ ] Implement result object
- [ ] Add empty/loading states

### Phase 5: Virtual Scroll (~2 hours)
- [ ] Extract `virtual_scroll.lua`
- [ ] Integrate with TreeView
- [ ] Performance test with 10k+ nodes

### Phase 6: TreeColumns (~3 hours)
- [ ] Extract `columns.lua` from sandbox_5
- [ ] Create `tree_columns.lua` extending TreeView
- [ ] Headers, sorting, resizing, alignment

### Phase 7: Testing (~3 hours)
- [ ] Unit tests for each module
- [ ] Integration tests for TreeView
- [ ] Performance benchmarks
- [ ] Edge case coverage

### Phase 8: Migration (~3 hours)
- [ ] Update TemplateBrowser to new TreeView
- [ ] Verify all existing functionality
- [ ] Add backward-compat shims if needed

### Phase 9: Cleanup (~2 hours)
- [ ] Deprecate old `tree_view.lua`
- [ ] Update cookbook/WIDGETS.md
- [ ] Archive sandbox files
- [ ] Add migration guide

---

## ImGui Alignment Reference

| ImGui Pattern | ARKITEKT Approach |
|---------------|-------------------|
| `TreeNodeFlags_*` | `enable_*` booleans in opts |
| `TreeNodeEx()` returns open | `result.toggled` + `state.open` |
| `IsItemClicked()` inline | `on_select` callback with event |
| `IsItemHovered()` inline | `result.hovered` |
| `BeginDragDropSource()` | `enable_drag_drop = true` |
| `SetNextItemOpen()` | `state.open[id] = true` before draw |
| Clipper for virtual scroll | `enable_virtual_scroll = true` |
| `InputText()` for rename | Built-in with `enable_rename` |

---

## Priority

**Critical** - TreeView is a foundational widget used across multiple scripts. Investment here pays dividends everywhere.

**Estimated Total**: ~28 hours across 9 phases

---

## Open Questions

1. **Should columns be a separate widget or built-in?**
   - Current plan: TreeColumns extends TreeView
   - Alternative: Single widget with `columns` opt

2. **How to handle async in Lua without promises?**
   - Current plan: `event.done(children)` callback
   - Alternative: Coroutines?

3. **Should we support horizontal scroll for wide trees?**
   - Current plan: No, indent clamps at max
   - Alternative: Horizontal scrollbar

---

*Created: 2025-11-27*
*Updated: 2025-11-27 - Added state factory, theming, events, testing, undo*
