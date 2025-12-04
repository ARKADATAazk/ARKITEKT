# TreeView Implementation Analysis & Improvement Plan

## Executive Summary

Both `sandbox_4.lua` (basic TreeView) and `sandbox_5.lua` (multi-column TreeView) provide solid foundational implementations with many advanced features. However, when compared to industry-standard PyQt5 QTreeView/QTreeWidget, several critical features and architectural improvements are needed.

---

## Current Feature Matrix

| Feature | sandbox_4 | sandbox_5 | PyQt5 | Priority |
|---------|-----------|-----------|-------|----------|
| **Core Functionality** |
| Hierarchical display | ✅ | ✅ | ✅ | - |
| Expand/collapse | ✅ | ✅ | ✅ | - |
| Single selection | ✅ | ✅ | ✅ | - |
| Multi-selection | ✅ | ✅ | ✅ | - |
| Range selection (Shift) | ✅ | ✅ | ✅ | - |
| Toggle selection (Ctrl) | ✅ | ✅ | ✅ | - |
| **Editing** |
| Inline edit (F2) | ✅ | ✅ | ✅ | - |
| Double-click edit | ✅ | ✅ | ✅ | - |
| Edit validation | ❌ | ❌ | ✅ | HIGH |
| Persistent editors | ❌ | ❌ | ✅ | LOW |
| Custom editors per column | ❌ | ❌ | ✅ | MEDIUM |
| **Navigation** |
| Arrow keys | ✅ | ✅ | ✅ | - |
| Home/End | ✅ | ✅ | ✅ | - |
| Page Up/Down | ✅ | ✅ | ✅ | - |
| Type-ahead search | ❌ | ❌ | ✅ | MEDIUM |
| Find next/previous | ❌ | ⚠️ | ✅ | MEDIUM |
| Scroll to item API | ⚠️ | ⚠️ | ✅ | HIGH |
| **Visual Features** |
| Custom icons | ✅ | ✅ | ✅ | - |
| Tree lines | ✅ | ✅ | ✅ | - |
| Alternating rows | ✅ | ✅ | ✅ | - |
| Item checkboxes | ❌ | ❌ | ✅ | HIGH |
| Item tooltips | ❌ | ❌ | ✅ | MEDIUM |
| Word wrap | ❌ | ❌ | ✅ | LOW |
| Elide text | ⚠️ | ⚠️ | ✅ | - |
| Icons with state | ⚠️ | ⚠️ | ✅ | MEDIUM |
| Animated expand/collapse | ❌ | ❌ | ✅ | LOW |
| **Drag & Drop** |
| Basic drag & drop | ✅ | ✅ | ✅ | - |
| Drop indicators | ✅ | ✅ | ✅ | - |
| Auto-expand on hover | ❌ | ❌ | ✅ | MEDIUM |
| Auto-scroll on edge | ❌ | ❌ | ✅ | HIGH |
| Drag preview | ❌ | ❌ | ✅ | LOW |
| External drag/drop | ❌ | ❌ | ✅ | LOW |
| **Clipboard** |
| Cut/Copy/Paste | ✅ | ✅ | ✅ | - |
| Duplicate (Ctrl+D) | ✅ | ✅ | ❌ | - |
| Delete (Del) | ✅ | ✅ | ✅ | - |
| **Columns** (sandbox_5 only) |
| Multiple columns | - | ✅ | ✅ | - |
| Sortable columns | - | ✅ | ✅ | - |
| Resizable columns | - | ✅ | ✅ | - |
| Column reordering | - | ❌ | ✅ | MEDIUM |
| Column visibility toggle | - | ❌ | ✅ | MEDIUM |
| Column stretch modes | - | ❌ | ✅ | LOW |
| Header context menu | - | ⚠️ | ✅ | MEDIUM |
| **Performance** |
| Virtual scrolling | ✅ | ✅ | ✅ | - |
| Lazy loading | ❌ | ❌ | ✅ | MEDIUM |
| Item caching | ❌ | ❌ | ✅ | LOW |
| **Item State** |
| Selectable flag | ❌ | ❌ | ✅ | HIGH |
| Editable flag | ❌ | ❌ | ✅ | HIGH |
| Enabled/Disabled | ❌ | ❌ | ✅ | HIGH |
| Checkable items | ❌ | ❌ | ✅ | HIGH |
| Tri-state checkboxes | ❌ | ❌ | ✅ | MEDIUM |
| **Selection Modes** |
| Single selection mode | ⚠️ | ⚠️ | ✅ | MEDIUM |
| Multi-selection mode | ✅ | ✅ | ✅ | - |
| Extended selection | ✅ | ✅ | ✅ | - |
| Contiguous selection | ⚠️ | ⚠️ | ✅ | LOW |
| No selection mode | ❌ | ❌ | ✅ | LOW |
| **Context Menu** |
| Basic context menu | ✅ | ✅ | ✅ | - |
| Custom menu items | ⚠️ | ⚠️ | ✅ | MEDIUM |
| Dynamic menu | ❌ | ❌ | ✅ | MEDIUM |
| **Scrolling** |
| Mouse wheel | ✅ | ✅ | ✅ | - |
| Scrollbar rendering | ❌ | ❌ | ✅ | MEDIUM |
| Horizontal scroll | ❌ | ❌ | ✅ | MEDIUM |
| Smooth scrolling | ❌ | ❌ | ✅ | LOW |
| **Search** |
| Basic text search | ✅ | ✅ | ✅ | - |
| Search popup | ❌ | ✅ | ✅ | - |
| Regex search | ❌ | ❌ | ✅ | LOW |
| Search in all columns | ❌ | ❌ | ✅ | MEDIUM |
| Case sensitivity toggle | ❌ | ❌ | ✅ | MEDIUM |
| Highlight all matches | ❌ | ❌ | ✅ | LOW |
| **API & Architecture** |
| Programmatic API | ⚠️ | ⚠️ | ✅ | HIGH |
| Event callbacks | ❌ | ❌ | ✅ | HIGH |
| Model/View separation | ❌ | ❌ | ✅ | MEDIUM |
| Data roles | ❌ | ❌ | ✅ | MEDIUM |
| Persistent indices | ❌ | ❌ | ✅ | LOW |

**Legend:**
- ✅ Fully implemented
- ⚠️ Partially implemented
- ❌ Not implemented

---

## Critical Code Quality Issues

### 1. **Missing Module Encapsulation**
```lua
-- PROBLEM: Everything in global scope
local function is_selected(id)
  return tree_state.selected[id] == true
end

-- SOLUTION: Encapsulate in module
local TreeView = {}
TreeView.__index = TreeView

function TreeView:new(config)
  local self = setmetatable({}, TreeView)
  self.state = { selected = {}, ... }
  return self
end

function TreeView:is_selected(id)
  return self.state.selected[id] == true
end
```

### 2. **Undefined Reference to `Ark.InputText`**
```lua
-- Line 658 in sandbox_4.lua
Ark.InputText.set_text("tree_edit_" .. node.id, tree_state.edit_buffer)
```
**Issue:** `ark` is not defined in scope. Should be:
```lua
local Ark = { InputText = InputText }  -- Define namespace
```

### 3. **No Item State Management**
```lua
-- PROBLEM: No way to disable/enable items selectively
-- All items are always selectable and editable

-- SOLUTION: Add item flags
{
  id = "button",
  name = "Button.lua",
  flags = {
    selectable = true,
    editable = true,
    enabled = true,
    checkable = false,
    draggable = true,
    droppable = true,
  },
  children = {}
}
```

### 4. **Hard-Coded Colors (No Theming)**
```lua
-- PROBLEM: Colors hard-coded in TREE_CONFIG
bg_hover = hex("#2E2E2EFF"),
bg_selected = hex("#393939FF"),

-- SOLUTION: Theme system
local Themes = {
  dark = {
    bg_hover = hex("#2E2E2EFF"),
    bg_selected = hex("#393939FF"),
    -- ... all colors
  },
  light = {
    bg_hover = hex("#E0E0E0FF"),
    bg_selected = hex("#CCE8FFFF"),
    -- ... all colors
  }
}
```

### 5. **Duplicate Code Between sandbox_4 and sandbox_5**
- 95% of code is duplicated
- Should extract common TreeView base, extend for columns
- Violates DRY principle massively

### 6. **No Event System/Callbacks**
```lua
-- PROBLEM: No way to hook into events from outside
-- User can't respond to selection changes, edits, etc.

-- SOLUTION: Callback system
local tree = TreeView:new({
  on_selection_changed = function(selected_ids)
    print("Selection changed:", table.concat(selected_ids, ", "))
  end,
  on_item_edited = function(id, old_value, new_value)
    print("Item edited:", id, old_value, "->", new_value)
  end,
  on_item_activated = function(id)  -- Double-click
    print("Item activated:", id)
  end,
  on_context_menu = function(id, x, y)
    -- Return custom menu items
    return {
      { label = "Custom Action", action = function() ... end }
    }
  end,
})
```

### 7. **No Input Validation**
```lua
-- PROBLEM: Edit mode accepts any text, no validation
if tree_state.edit_buffer ~= "" then
  node.name = tree_state.edit_buffer
end

-- SOLUTION: Validation callback
if tree_state.edit_buffer ~= "" then
  if config.on_validate_edit then
    local valid, error_msg = config.on_validate_edit(node.id, tree_state.edit_buffer)
    if not valid then
      -- Show error, keep editing
      return
    end
  end
  node.name = tree_state.edit_buffer
end
```

### 8. **No Programmatic API**
```lua
-- PROBLEM: Can't control tree from code
-- Everything must be done through UI interaction

-- SOLUTION: API methods
function TreeView:select_item(id)
  self.state.selected = { [id] = true }
  self.state.focused = id
  self:ensure_visible(id)
end

function TreeView:expand_node(id, recursive)
  self.state.open[id] = true
  if recursive then
    local node = self:find_node(id)
    if node and node.children then
      for _, child in ipairs(node.children) do
        self:expand_node(child.id, true)
      end
    end
  end
end

function TreeView:get_selected_items()
  local items = {}
  for id, _ in pairs(self.state.selected) do
    table.insert(items, id)
  end
  return items
end
```

### 9. **Missing Critical Features**

#### a) **Item Checkboxes**
```lua
-- Add checkbox support
local function draw_checkbox(dl, x, y, checked, tristate)
  local size = 12
  -- Draw checkbox square
  ImGui.DrawList_AddRect(dl, x, y, x + size, y + size, color_border, 2)
  if checked == true then
    -- Draw checkmark
    ImGui.DrawList_AddLine(dl, x + 3, y + 6, x + 5, y + 9, color_check, 2)
    ImGui.DrawList_AddLine(dl, x + 5, y + 9, x + 9, y + 3, color_check, 2)
  elseif checked == "partial" and tristate then
    -- Draw dash for partial
    ImGui.DrawList_AddLine(dl, x + 3, y + 6, x + 9, y + 6, color_check, 2)
  end
end

-- Add to node data
{
  id = "src",
  name = "src",
  checkable = true,
  checked = true,  -- true, false, or "partial" for tristate
  tri_state = true,
}
```

#### b) **Auto-Expand on Drag Hover**
```lua
-- Add hover timer
if tree_state.drag_active and is_hovered then
  local hover_time = tree_state.drag_hover_times[node.id] or 0
  hover_time = hover_time + delta_time
  tree_state.drag_hover_times[node.id] = hover_time

  if hover_time > 0.7 and has_children and not is_open then
    tree_state.open[node.id] = true
  end
else
  tree_state.drag_hover_times[node.id] = nil
end
```

#### c) **Auto-Scroll on Drag to Edge**
```lua
-- Add edge detection during drag
if tree_state.drag_active then
  local edge_threshold = 30
  local scroll_speed = 5

  if my < tree_y + edge_threshold then
    -- Scrolling up
    tree_state.scroll_y = tree_state.scroll_y - scroll_speed
  elseif my > tree_y + tree_h - edge_threshold then
    -- Scrolling down
    tree_state.scroll_y = tree_state.scroll_y + scroll_speed
  end

  tree_state.scroll_y = math.max(0, tree_state.scroll_y)
end
```

#### d) **Scrollbar Rendering**
```lua
-- Add visible scrollbar
local function draw_scrollbar(ctx, dl, x, y, w, h, scroll_y, content_h)
  local scrollbar_w = 12
  local scrollbar_x = x + w - scrollbar_w

  -- Track
  ImGui.DrawList_AddRectFilled(dl, scrollbar_x, y, scrollbar_x + scrollbar_w, y + h, color_track)

  -- Thumb
  local visible_ratio = h / content_h
  local thumb_h = math.max(20, h * visible_ratio)
  local thumb_y = y + (scroll_y / content_h) * h

  ImGui.DrawList_AddRectFilled(dl, scrollbar_x + 2, thumb_y, scrollbar_x + scrollbar_w - 2, thumb_y + thumb_h, color_thumb, 2)

  -- Handle thumb dragging
  ImGui.SetCursorScreenPos(ctx, scrollbar_x, thumb_y)
  ImGui.InvisibleButton(ctx, "##scrollbar_thumb", scrollbar_w, thumb_h)
  if ImGui.IsItemActive(ctx) then
    local _, delta_y = ImGui.GetMouseDragDelta(ctx, 0, 0)
    scroll_y = (thumb_y + delta_y - y) / h * content_h
    ImGui.ResetMouseDragDelta(ctx, 0)
  end

  return scroll_y
end
```

#### e) **Horizontal Scrolling**
```lua
-- Track maximum width needed
local max_width = 0
for _, item in ipairs(tree_state.flat_list) do
  local item_width = calculate_item_width(item)
  max_width = math.max(max_width, item_width)
end

-- Add horizontal scroll if needed
if max_width > visible_width then
  -- Draw horizontal scrollbar
  -- Offset rendering by scroll_x
end
```

### 10. **No Error Handling**
```lua
-- PROBLEM: No protection against invalid operations
-- What if node.children is nil? What if ID doesn't exist?

-- SOLUTION: Add validation
local function find_node_by_id(nodes, id)
  if not nodes or type(nodes) ~= "table" then return nil end
  if not id then return nil end

  for _, node in ipairs(nodes) do
    if not node then goto continue end

    if node.id == id then return node end
    if node.children then
      local found = find_node_by_id(node.children, id)
      if found then return found end
    end

    ::continue::
  end
  return nil
end
```

---

## Recommended Improvements Priority List

### **HIGH Priority** (Critical functionality)

1. **Add item state flags** (selectable, editable, enabled, checkable)
2. **Implement checkbox support** with tri-state
3. **Create event callback system** (on_selection_changed, on_item_edited, etc.)
4. **Add programmatic API** (select_item, expand_node, scroll_to_item, etc.)
5. **Fix undefined `ark` reference**
6. **Add edit validation**
7. **Auto-scroll on drag to edges**
8. **Ensure visible / scroll to item API**

### **MEDIUM Priority** (Important features)

9. **Module encapsulation** - convert to proper OOP module
10. **Refactor common code** - extract base TreeView from both sandboxes
11. **Add theme support** - don't hard-code colors
12. **Type-ahead search** (press keys to jump to items)
13. **Find next/previous in search**
14. **Item tooltips**
15. **Custom item icons with state**
16. **Column reordering** (sandbox_5)
17. **Column visibility toggle** (sandbox_5)
18. **Header context menu** (sandbox_5)
19. **Scrollbar rendering**
20. **Horizontal scrolling**
21. **Auto-expand on drag hover**
22. **Custom context menu items via callback**
23. **Search case sensitivity toggle**
24. **Search in all columns**
25. **Dynamic context menus**

### **LOW Priority** (Nice to have)

26. **Animated expand/collapse**
27. **Persistent editors**
28. **Custom editors per column**
29. **Word wrap**
30. **Drag preview**
31. **External drag/drop**
32. **Smooth scrolling**
33. **Regex search**
34. **Highlight all search matches**
35. **Lazy loading for huge trees**
36. **Item caching**

---

## Architecture Recommendation

### Proposed Structure:
```
ARKITEKT/gui/widgets/
  ├── tree/
  │   ├── init.lua          -- Main TreeView module
  │   ├── tree_state.lua    -- State management
  │   ├── tree_item.lua     -- Item representation
  │   ├── tree_renderer.lua -- Drawing functions
  │   ├── tree_input.lua    -- Input handling
  │   ├── tree_columns.lua  -- Column support
  │   └── tree_themes.lua   -- Theme definitions
```

### Usage Example:
```lua
local TreeView = require('arkitekt.gui.widgets.tree')

local tree = TreeView:new({
  data = mock_tree,
  theme = "dark",
  config = {
    show_tree_lines = true,
    show_checkboxes = true,
    enable_drag_drop = true,
    -- ... other config
  },
  callbacks = {
    on_selection_changed = function(items) end,
    on_item_checked = function(id, checked) end,
    on_item_edited = function(id, old_val, new_val) end,
    on_item_activated = function(id) end,
    on_context_menu = function(id) return menu_items end,
  }
})

-- In draw loop
tree:draw(ctx, x, y, w, h)

-- API usage
tree:select_item("src")
tree:expand_node("root", true)  -- recursive
tree:check_item("button", true)
local selected = tree:get_selected_items()
```

---

## Conclusion

The current implementations are impressive prototypes with many advanced features. However, they need:

1. **Architectural refactoring** for reusability and maintainability
2. **Critical feature additions** (checkboxes, item states, callbacks, API)
3. **Code quality improvements** (encapsulation, error handling, validation)
4. **PyQt5 feature parity** for professional-grade tree widget

These improvements would transform the sandboxes into production-ready, reusable TreeView components suitable for the ARKITEKT toolkit.
