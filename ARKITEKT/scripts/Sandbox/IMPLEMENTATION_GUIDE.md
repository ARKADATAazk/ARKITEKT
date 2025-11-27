# TreeView Implementation Guide

## Completed Improvements ✅

### 1. Fixed `ark` Namespace Reference
- **Problem:** `ark.InputText` was undefined
- **Solution:** Added namespace definition:
```lua
local ark = {
  InputText = InputText
}
```
- **Files:** sandbox_4.lua:23-26, sandbox_5.lua:23-26

### 2. Added Item State Flags System
- **New Config:** `default_item_flags` in TREE_CONFIG
- **Flags:**
  - `selectable` - Can be selected
  - `editable` - Can be renamed
  - `enabled` - Is active (not grayed out)
  - `checkable` - Has checkbox
  - `draggable` - Can be dragged
  - `droppable` - Can accept drops
- **Helper Functions:**
  - `get_item_flags(node)` - Merges item flags with defaults
  - `is_item_enabled(node)` - Checks if item is enabled
  - `is_item_checkable(node)` - Checks if item should show checkbox

### 3. Implemented Checkbox System with Tri-State
- **New Config Properties:**
  - `checkbox_size = 12`
  - `checkbox_margin = 6`
  - `show_checkboxes = true`  -- Global toggle
  - Checkbox colors (border, check, bg, bg_disabled)

- **Checkbox States:**
  - `true` - Checked
  - `false` - Unchecked
  - `"partial"` - Tri-state (some children checked)

- **Functions:**
  - `get_check_state(node)` - Get checkbox state
  - `set_check_state(nodes, node_id, checked)` - Set state recursively with tri-state parent update
  - `draw_checkbox(dl, x, y, checked, enabled)` - Render checkbox

- **Tri-State Logic:**
  - When child is checked/unchecked, parent updates to:
    - `true` if all children checked
    - `false` if no children checked
    - `"partial"` if some children checked
  - When parent is toggled, all children inherit the state

### 4. Added Disabled Item Colors
- `bg_disabled` - Background for disabled items
- `text_disabled` - Text color for disabled items

### 5. Updated Mock Data
- Added `flags` to items (e.g., `flags = { checkable = true }`)
- Added `checked` state to items

---

## Remaining Implementation Tasks 🚧

### HIGH PRIORITY

#### 1. Update `render_tree_item()` to Draw Checkboxes

**Location:** sandbox_4.lua around line 710

**Changes Needed:**
```lua
local function render_tree_item(ctx, dl, node, depth, y_pos, visible_x, visible_w, parent_lines, is_last_child, row_index, parent_id, visible_top, visible_bottom)
  local cfg = TREE_CONFIG
  local item_h = cfg.item_height

  -- Get item flags and states
  local flags = get_item_flags(node)
  local is_enabled = flags.enabled
  local is_checkable = flags.checkable and cfg.show_checkboxes

  -- ... existing search filter code ...

  -- Calculate positions
  local indent_x = visible_x + cfg.padding_left + depth * cfg.indent_width
  local current_x = indent_x

  -- Arrow position
  local arrow_x = current_x
  local has_children = node.children and #node.children > 0
  if has_children then
    current_x = current_x + cfg.arrow_size + cfg.arrow_margin
  end

  -- Checkbox position (if checkable)
  local checkbox_x = current_x
  if is_checkable then
    current_x = current_x + cfg.checkbox_size + cfg.checkbox_margin
  end

  -- Icon position
  local icon_x = current_x
  current_x = current_x + cfg.icon_width + cfg.icon_margin

  -- Text position
  local text_x = current_x + cfg.item_padding_left

  -- ... rest of rendering ...

  -- In visible drawing section:
  if is_visible then
    -- ... backgrounds ...

    -- Disabled overlay
    if not is_enabled then
      ImGui.DrawList_AddRectFilled(dl, visible_x, y_pos, visible_x + visible_w, y_pos + item_h, cfg.bg_disabled)
    end

    -- ... tree lines ...

    -- Arrow
    if has_children then
      draw_arrow(dl, arrow_x, arrow_y, is_open, cfg.arrow_color)
    end

    -- Checkbox (NEW!)
    if is_checkable then
      local checkbox_y = y_pos + (item_h - cfg.checkbox_size) / 2
      local checked = get_check_state(node)
      draw_checkbox(dl, checkbox_x, checkbox_y, checked, is_enabled)
    end

    -- Icon
    draw_node_icon(dl, icon_x, icon_y, node, is_open, icon_color)

    -- Text (with disabled color if needed)
    local text_color
    if not is_enabled then
      text_color = cfg.text_disabled
    elseif is_hovered or item_selected then
      text_color = cfg.text_hover
    else
      text_color = cfg.text_normal
    end

    -- ... text rendering with text_color ...

    -- Interaction section (only if enabled)
    if not is_editing and is_enabled and flags.selectable then
      -- Invisible button for interaction
      ImGui.SetCursorScreenPos(ctx, visible_x, y_pos)
      ImGui.InvisibleButton(ctx, "##tree_item_" .. node.id, visible_w, item_h)

      -- Click handling
      if ImGui.IsItemClicked(ctx, 0) then
        -- Check if clicked on checkbox
        if is_checkable and mx >= checkbox_x and mx < checkbox_x + cfg.checkbox_size + cfg.checkbox_margin then
          -- Toggle checkbox
          local current_state = get_check_state(node)
          local new_state = (current_state == true) and false or true
          set_check_state(mock_tree, node.id, new_state)  -- Pass tree root
        elseif has_children and mx >= arrow_x and mx < arrow_x + cfg.arrow_size + cfg.arrow_margin then
          -- Toggle expand/collapse
          tree_state.open[node.id] = not tree_state.open[node.id]
        else
          -- Selection handling (existing code)
          -- ... Ctrl, Shift, normal click ...
        end
      end

      -- ... rest of interaction code ...
    end
  end
end
```

#### 2. Add Event Callback System

**Location:** After TREE_CONFIG definition

**Implementation:**
```lua
-- Event callbacks (can be set by user)
local TREE_CALLBACKS = {
  on_selection_changed = nil,  -- function(selected_ids_array)
  on_item_checked = nil,       -- function(node_id, checked_state, node_data)
  on_item_edited = nil,        -- function(node_id, old_name, new_name, node_data)
  on_item_activated = nil,     -- function(node_id, node_data)  -- double-click
  on_item_deleted = nil,       -- function(deleted_ids_array)
  on_context_menu = nil,       -- function(node_id, node_data) -> custom_menu_items
  on_drag_drop = nil,          -- function(drag_id, target_id, position)
}

-- Helper to trigger callback
local function trigger_callback(event_name, ...)
  local callback = TREE_CALLBACKS[event_name]
  if callback and type(callback) == "function" then
    callback(...)
  end
end
```

**Usage in Code:**
```lua
-- When selection changes:
trigger_callback("on_selection_changed", get_selected_ids_array())

-- When checkbox toggled:
set_check_state(mock_tree, node.id, new_state)
trigger_callback("on_item_checked", node.id, new_state, node)

-- When item edited:
if tree_state.edit_buffer ~= "" and tree_state.edit_buffer ~= node.name then
  local old_name = node.name
  node.name = tree_state.edit_buffer
  trigger_callback("on_item_edited", node.id, old_name, node.name, node)
end

-- When item double-clicked (not for edit):
if not is_editing and ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) and not flags.editable then
  trigger_callback("on_item_activated", node.id, node)
end
```

#### 3. Add Programmatic API

**Location:** After helper functions, before draw_custom_tree

**Implementation:**
```lua
-- ==================================================================
-- PROGRAMMATIC API
-- ==================================================================

local TreeAPI = {}

-- Select item(s)
function TreeAPI.select_item(id, add_to_selection)
  if add_to_selection then
    tree_state.selected[id] = true
  else
    tree_state.selected = { [id] = true }
  end
  tree_state.focused = id
  tree_state.anchor = id
  TreeAPI.ensure_visible(id)
  trigger_callback("on_selection_changed", TreeAPI.get_selected_items())
end

-- Get selected items
function TreeAPI.get_selected_items()
  local items = {}
  for id, _ in pairs(tree_state.selected) do
    table.insert(items, id)
  end
  return items
end

-- Clear selection
function TreeAPI.clear_selection()
  tree_state.selected = {}
  tree_state.anchor = nil
  trigger_callback("on_selection_changed", {})
end

-- Expand node
function TreeAPI.expand_node(id, recursive)
  tree_state.open[id] = true
  if recursive then
    local node = find_node_by_id(mock_tree, id)
    if node and node.children then
      for _, child in ipairs(node.children) do
        TreeAPI.expand_node(child.id, true)
      end
    end
  end
end

-- Collapse node
function TreeAPI.collapse_node(id, recursive)
  tree_state.open[id] = false
  if recursive then
    local node = find_node_by_id(mock_tree, id)
    if node and node.children then
      for _, child in ipairs(node.children) do
        TreeAPI.collapse_node(child.id, true)
      end
    end
  end
end

-- Ensure item is visible (scroll to it)
function TreeAPI.ensure_visible(id)
  -- Find item in flat_list
  for i, item in ipairs(tree_state.flat_list) do
    if item.id == id then
      local item_y = item.y_pos
      local cfg = TREE_CONFIG
      local visible_top = tree_state.tree_bounds.y + cfg.padding_top
      local visible_bottom = tree_state.tree_bounds.y + tree_state.tree_bounds.h - cfg.padding_bottom

      if item_y < visible_top then
        tree_state.scroll_y = tree_state.scroll_y - (visible_top - item_y)
      elseif item_y + item.height > visible_bottom then
        tree_state.scroll_y = tree_state.scroll_y + (item_y + item.height - visible_bottom)
      end

      tree_state.scroll_y = math.max(0, tree_state.scroll_y)
      break
    end
  end
end

-- Check/uncheck item
function TreeAPI.check_item(id, checked)
  set_check_state(mock_tree, id, checked)
  local node = find_node_by_id(mock_tree, id)
  if node then
    trigger_callback("on_item_checked", id, checked, node)
  end
end

-- Get item data
function TreeAPI.get_item(id)
  return find_node_by_id(mock_tree, id)
end

-- Set item flags
function TreeAPI.set_item_flags(id, flags)
  local node = find_node_by_id(mock_tree, id)
  if node then
    node.flags = node.flags or {}
    for key, val in pairs(flags) do
      node.flags[key] = val
    end
  end
end
```

**Usage Example:**
```lua
-- In application code:
TreeAPI.select_item("button")
TreeAPI.expand_node("root", true)  -- Expand recursively
TreeAPI.check_item("src", true)
local selected = TreeAPI.get_selected_items()

-- Set callbacks:
TREE_CALLBACKS.on_selection_changed = function(items)
  print("Selected:", table.concat(items, ", "))
end

TREE_CALLBACKS.on_item_checked = function(id, checked, node)
  print("Item", id, "checked:", checked)
end
```

#### 4. Add Auto-Scroll on Drag to Edges

**Location:** In `draw_custom_tree()` drag handling section

**Implementation:**
```lua
-- Handle drag & drop
if tree_state.drag_active then
  local mx, my = ImGui.GetMousePos(ctx)
  local edge_threshold = 30
  local scroll_speed = 5

  -- Auto-scroll when dragging near edges
  if my < tree_y + edge_threshold then
    tree_state.scroll_y = tree_state.scroll_y - scroll_speed
    tree_state.scroll_y = math.max(0, tree_state.scroll_y)
  elseif my > tree_y + tree_h - edge_threshold then
    tree_state.scroll_y = tree_state.scroll_y + scroll_speed
    local max_scroll = math.max(0, tree_state.total_content_height - tree_h)
    tree_state.scroll_y = math.min(max_scroll, tree_state.scroll_y)
  end

  -- ... existing drop handling ...
end
```

#### 5. Add Auto-Expand on Drag Hover

**Location:** Add to tree_state, update in render_tree_item

**Add to tree_state:**
```lua
local tree_state = {
  -- ... existing fields ...
  drag_hover_times = {},  -- Track hover duration per node
  drag_hover_expand_delay = 0.7,  -- Seconds to wait before auto-expand
}
```

**In render_tree_item interaction section:**
```lua
-- Auto-expand on drag hover
if tree_state.drag_active and tree_state.drag_node_id ~= node.id and is_hovered and has_children then
  local hover_time = tree_state.drag_hover_times[node.id] or 0
  local delta_time = ImGui.GetDeltaTime(ctx)
  hover_time = hover_time + delta_time
  tree_state.drag_hover_times[node.id] = hover_time

  if hover_time > tree_state.drag_hover_expand_delay and not is_open then
    tree_state.open[node.id] = true
  end
elseif not is_hovered or not tree_state.drag_active then
  tree_state.drag_hover_times[node.id] = nil
end
```

---

### MEDIUM PRIORITY

#### 6. Add Type-Ahead Search
- Listen for key presses when focused
- Build search string from keypresses
- Jump to first matching item
- Clear search string after timeout

#### 7. Add Scrollbar Rendering
- Calculate scrollbar thumb size and position
- Draw track and thumb
- Handle thumb dragging

#### 8. Add Horizontal Scrolling
- Track maximum item width
- Show horizontal scrollbar if needed
- Offset rendering by scroll_x

#### 9. Add Tooltips
- Store `tooltip` property on nodes
- Show tooltip popup on hover (after delay)

#### 10. Theme System
- Extract all colors to theme tables
- Support "dark" and "light" themes
- Allow theme switching

---

## Integration with sandbox_5 (Multi-Column TreeView)

All improvements to sandbox_4 should be replicated to sandbox_5 with the following additions:

### Column-Specific Features:

1. **Checkbox in First Column Only**
   - Checkboxes should only appear in the first column (tree column)

2. **Per-Column Editing**
   - Allow editing values in different columns
   - Each column can have custom editor type

3. **Per-Column Item Flags**
   - Some columns may be read-only while others are editable

4. **Sort Stability with Checkboxes**
   - Ensure checked state is maintained during sorting

---

## Testing Checklist

### Checkbox Features:
- [ ] Checkboxes appear for checkable items
- [ ] Clicking checkbox toggles state
- [ ] Tri-state updates correctly when child checked/unchecked
- [ ] Parent checkbox toggles all children
- [ ] Disabled items show grayed checkboxes
- [ ] Checkboxes respect global show_checkboxes toggle

### Item Flags:
- [ ] Non-selectable items can't be selected
- [ ] Non-editable items can't be renamed
- [ ] Disabled items are grayed out
- [ ] Disabled items don't respond to clicks
- [ ] Per-item draggable flag works

### API:
- [ ] TreeAPI.select_item() selects and scrolls to item
- [ ] TreeAPI.expand_node() expands single node
- [ ] TreeAPI.expand_node(id, true) expands recursively
- [ ] TreeAPI.check_item() updates checkbox
- [ ] TreeAPI.get_selected_items() returns correct IDs

### Callbacks:
- [ ] on_selection_changed fires when selection changes
- [ ] on_item_checked fires when checkbox toggled
- [ ] on_item_edited fires when item renamed
- [ ] on_item_activated fires on double-click (non-editable items)

### Drag & Drop:
- [ ] Auto-scroll works when dragging to top edge
- [ ] Auto-scroll works when dragging to bottom edge
- [ ] Auto-expand works when hovering over collapsed folder

### Performance:
- [ ] Virtual scrolling still works with checkboxes
- [ ] No lag with 1000+ items
- [ ] Tri-state updates don't cause stuttering

---

## Summary

### Completed:
1. ✅ Fixed `ark` namespace reference
2. ✅ Added item state flags system
3. ✅ Implemented checkbox drawing with tri-state
4. ✅ Added checkbox state management functions
5. ✅ Added disabled item colors
6. ✅ Updated mock data with flags and checkboxes

### In Progress:
- Updating render_tree_item() to integrate checkboxes
- Adding event callback system
- Creating programmatic API

### Remaining High Priority:
- Auto-scroll on drag to edges
- Auto-expand on drag hover
- Ensure visible / scroll to item

### Documentation Created:
- TREEVIEW_ANALYSIS.md - Comprehensive comparison with PyQt5
- IMPLEMENTATION_GUIDE.md (this file) - Step-by-step implementation guide

These improvements will bring the TreeView implementations to professional-grade quality with full feature parity to PyQt5's QTreeView/QTreeWidget.
