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

## Design Goals

### 1. Ease of Use (Primary)

```lua
-- Minimal setup for common case
local result = TreeView.draw(ctx, {
  nodes = data,
  state = tree_state,
})

-- Full-featured with one boolean each
local result = TreeView.draw(ctx, {
  nodes = data,
  state = tree_state,
  enable_multi_select = true,
  enable_keyboard = true,
  enable_rename = true,
  enable_drag_drop = true,
  enable_virtual_scroll = true,
  enable_lines = true,
  on_select = function(node, selection) ... end,
  on_rename = function(node, new_name) ... end,
})
```

### 2. ImGui API Alignment (Where Applicable)

**Match ImGui naming:**
- `TreeNodeFlags` → `tree_node_flags` in opts (if exposing low-level control)
- `OpenOnArrow`, `SpanAvailWidth` → same names in snake_case
- `selected`, `open` terminology matches ImGui

**Match ImGui patterns:**
- State is external (you own it, widget reads/writes)
- Immediate mode (no retained widget objects)
- Result object for "what happened this frame"

**Diverge for good reason:**
- Opts table instead of positional args (Lua-friendly)
- Callbacks instead of inline checks (cleaner)
- Virtual scroll (ImGui Clipper equivalent, but automatic)

### 3. Layered Architecture (Maintainability)

```
arkitekt/gui/widgets/navigation/
├── tree/
│   ├── core.lua           -- Base rendering, expand/collapse (~200 LOC)
│   ├── selection.lua      -- Single/multi-select logic (~150 LOC)
│   ├── keyboard.lua       -- Arrow nav, Home/End, PgUp/PgDown (~200 LOC)
│   ├── virtual_scroll.lua -- Render only visible items (~100 LOC)
│   ├── drag_drop.lua      -- Drag with preview, multi-drag (~200 LOC)
│   ├── icons.lua          -- Folder, file, lua, md icons (~150 LOC)
│   ├── lines.lua          -- Tree lines (solid/dotted) (~100 LOC)
│   ├── columns.lua        -- Headers, sorting, resizing (~300 LOC)
│   ├── rename.lua         -- Inline rename (F2, double-click) (~100 LOC)
│   └── search.lua         -- Type-to-search, Ctrl+F popup (~100 LOC)
│
├── tree_view.lua          -- Standard tree (composes modules)
└── tree_columns.lua       -- Column tree (extends tree_view)
```

**Benefits:**
- Each module is focused and testable
- Features only loaded when enabled
- Easy to add new features without bloating core

---

## API Design

### Node Format

```lua
-- Matches current framework TreeView (backward compatible)
local nodes = {
  {
    id = "unique_id",           -- Required
    name = "Display Name",      -- Required
    children = {...},           -- Optional, nested nodes
    color = 0xRRGGBBAA,         -- Optional, icon/text tint
    icon = "folder",            -- Optional: "folder", "file", "lua", "md", custom
    is_virtual = false,         -- Optional, virtual folder styling
    data = {...},               -- Optional, user data (columns, etc.)
  },
}
```

### State Format

```lua
-- External state (you own it)
local tree_state = {
  open = {},        -- {[node_id] = true, ...}
  selected = {},    -- {[node_id] = true, ...} for multi, or single node_id
  focused = nil,    -- Currently focused node (keyboard nav)
  anchor = nil,     -- Anchor for shift-selection
  scroll_y = 0,     -- Scroll position (virtual scroll)
  renaming = nil,   -- Node being renamed
  rename_buffer = "",
}
```

### Options

```lua
TreeView.draw(ctx, {
  -- Required
  nodes = nodes,
  state = tree_state,

  -- Dimensions (optional, sensible defaults)
  x = nil,              -- Auto from cursor
  y = nil,              -- Auto from cursor
  width = nil,          -- Auto from available
  height = nil,         -- Auto from available

  -- Features (all default false for minimal overhead)
  enable_multi_select = false,
  enable_keyboard = false,      -- Arrow keys, Home/End, PgUp/PgDown
  enable_rename = false,        -- F2, double-click
  enable_drag_drop = false,
  enable_virtual_scroll = false,
  enable_lines = false,         -- Tree connector lines
  enable_search = false,        -- Type-to-search, Ctrl+F
  enable_checkboxes = false,    -- Tri-state checkboxes

  -- Visual options
  show_icons = true,
  show_colors = true,
  line_style = "dotted",        -- "solid" or "dotted"
  item_height = 17,
  indent_width = 22,

  -- Callbacks (optional)
  on_select = function(node, selection) end,
  on_toggle = function(node, is_open) end,
  on_rename = function(node, new_name) end,
  on_delete = function(node) end,
  on_drop = function(source_ids, target_node, position) end,  -- position: "before"|"into"|"after"
  on_double_click = function(node) end,
  on_right_click = function(node) end,

  -- Guards (optional)
  can_select = function(node) return true end,
  can_rename = function(node) return true end,
  can_drag = function(node) return true end,
  can_drop = function(source, target, position) return true end,

  -- Context menu (optional)
  context_menu_id = "tree_context",
  render_context_menu = function(ctx, node) end,

  -- Custom rendering (optional)
  render_icon = function(ctx, dl, node, x, y) end,
  render_label = function(ctx, dl, node, x, y) end,
})
```

### Result Object

```lua
local result = TreeView.draw(ctx, opts)

-- What happened this frame
result.clicked           -- Node that was clicked (or nil)
result.double_clicked    -- Node that was double-clicked (or nil)
result.right_clicked     -- Node that was right-clicked (or nil)
result.toggled           -- Node that was expanded/collapsed (or nil)
result.renamed           -- {node, old_name, new_name} or nil
result.dropped           -- {source_ids, target, position} or nil
result.deleted           -- Node that was deleted (or nil)
result.hovered           -- Node currently hovered (or nil)

-- For advanced use
result.visible_count     -- Number of visible items (after filtering)
result.total_count       -- Total items in tree
result.scroll_changed    -- true if scroll position changed
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
      sortable = true,
      render_tree = true,  -- First column shows tree structure
      get_value = function(node) return node.name end,
    },
    {
      id = "type",
      title = "Type",
      width = 80,
      sortable = true,
      get_value = function(node) return node.data.type end,
    },
    {
      id = "size",
      title = "Size",
      width = 80,
      sortable = true,
      align = "right",
      get_value = function(node) return node.data.size end,
    },
  },

  -- Column-specific options
  enable_column_resize = true,
  enable_column_sort = true,
  header_height = 22,

  -- Column callbacks
  on_sort = function(column_id, ascending) end,
  on_column_resize = function(column_id, new_width) end,
})
```

---

## Migration Plan

### Phase 1: Extract Modules (~3-4 hours)
- [ ] Create `tree/` directory structure
- [ ] Extract `core.lua` from sandbox_4 (base rendering)
- [ ] Extract `selection.lua` (multi-select logic)
- [ ] Extract `keyboard.lua` (navigation)
- [ ] Extract `icons.lua` (icon rendering)
- [ ] Extract `lines.lua` (tree lines)
- [ ] Extract `drag_drop.lua` (drag handling)
- [ ] Extract `rename.lua` (inline rename)

### Phase 2: Create TreeView (~2-3 hours)
- [ ] Compose modules into `tree_view.lua`
- [ ] Implement opts API with feature flags
- [ ] Implement result object
- [ ] Add backward-compatible shims for current API

### Phase 3: Create TreeColumns (~2 hours)
- [ ] Extract `columns.lua` from sandbox_5
- [ ] Create `tree_columns.lua` extending TreeView
- [ ] Column headers, sorting, resizing

### Phase 4: Virtual Scroll (~1-2 hours)
- [ ] Extract `virtual_scroll.lua`
- [ ] Integrate with TreeView/TreeColumns
- [ ] Performance testing with 1000+ nodes

### Phase 5: Migrate TemplateBrowser (~2 hours)
- [ ] Update TemplateBrowser to use new TreeView
- [ ] Verify all callbacks work
- [ ] Remove old wrapper layer

### Phase 6: Cleanup (~1 hour)
- [ ] Deprecate old `tree_view.lua`
- [ ] Update documentation
- [ ] Archive sandbox files

---

## ImGui Alignment Notes

### Naming Conventions

| ImGui | ARKITEKT opts |
|-------|---------------|
| `TreeNodeFlags_Selected` | `selected` in state |
| `TreeNodeFlags_OpenOnArrow` | Default behavior |
| `TreeNodeFlags_SpanAvailWidth` | Default behavior |
| `TreeNodeFlags_Leaf` | Auto-detected from `children` |
| `IsItemClicked()` | `on_select` callback |
| `IsItemHovered()` | `result.hovered` |
| `BeginDragDropSource()` | `enable_drag_drop = true` |

### Patterns We Keep

- **Immediate mode**: No retained objects, draw every frame
- **External state**: You own the state, widget reads/writes
- **ID-based**: Nodes need unique IDs for stable state

### Patterns We Improve

- **Opts table**: Cleaner than 10+ positional parameters
- **Callbacks**: Cleaner than checking IsItemClicked inline
- **Result object**: Single place to check "what happened"
- **Feature flags**: No manual flag bit manipulation

---

## Priority

**High** - TreeView is used by TemplateBrowser and will be needed by other scripts. The sandbox prototypes prove the features work; this is about packaging them properly.

---

*Created: 2025-11-27*
