# TreeView Potential Improvements

## Completed ✅
- [x] Multi-drag support
- [x] Visual feedback for dragged items
- [x] VS Code-style drag preview with count badge
- [x] PushID/PopID for proper ID scoping
- [x] Fixed duplicate ID issues

## High Priority 🔥

### 1. Auto-Scroll During Drag
**What:** Automatically scroll when dragging near top/bottom edges
**Why:** Essential for dragging items to off-screen locations
**Implementation:**
```lua
-- In draw_custom_tree, during drag:
if tree_state.drag_active then
  local my = ImGui.GetMousePos(ctx)
  local scroll_zone = 30 -- pixels from edge

  if my < y + scroll_zone then
    tree_state.scroll_y = math.max(0, tree_state.scroll_y - 5)
  elseif my > y + h - scroll_zone then
    tree_state.scroll_y = tree_state.scroll_y + 5
  end
end
```

### 2. Copy-on-Drag (Ctrl+Drag)
**What:** Hold Ctrl while dragging to copy instead of move
**Why:** Standard behavior in file explorers
**Implementation:**
```lua
-- Detect Ctrl during drag
if tree_state.drag_active then
  local ctrl_held = ImGui.GetKeyMods(ctx) & ImGui.Mod_Ctrl ~= 0
  tree_state.drag_is_copy = ctrl_held

  -- Show + cursor indicator
  -- On drop, duplicate instead of move
end
```

### 3. Type-to-Search
**What:** Start typing to jump to matching item (like VS Code)
**Why:** Fast navigation in large trees
**Implementation:**
```lua
-- Track typed characters with timeout
tree_state.type_buffer = ""
tree_state.type_timeout = 0

if ImGui.IsKeyPressed(...) and not editing then
  tree_state.type_buffer = tree_state.type_buffer .. char
  -- Find and focus first matching item
end
```

### 4. Expand/Collapse All Children
**What:** Right-click folder → "Expand All" / "Collapse All"
**Why:** Quick navigation in deep hierarchies
**Already implemented:** Ctrl+8 and Ctrl+9 exist, just add to context menu

## Medium Priority 🟡

### 5. Better Keyboard Navigation
**Missing:**
- Home/End: Jump to first/last item
- PageUp/PageDown: Scroll by page
- Ctrl+Home/End: Jump to tree top/bottom
- Left arrow on closed folder: Jump to parent
- Right arrow on folder: Expand folder

### 6. Smooth Scrolling
**What:** Animated scroll instead of instant jump
**Why:** Better UX, easier to track visually
**Implementation:** Interpolate scroll_y over time

### 7. Tooltips
**What:** Show full path on hover for truncated items
**Why:** Essential when items are too long for tree width
```lua
if ImGui.IsItemHovered(ctx) and text_truncated then
  ImGui.SetTooltip(ctx, full_path)
end
```

### 8. Breadcrumb Trail
**What:** Show current path at top: `Root > src > components`
**Why:** Context awareness in deep trees

### 9. Custom Icons per File Type
**What:** Different icons for .lua, .md, .json, etc.
**Why:** Visual distinction, matches IDE behavior
**Status:** Partially implemented, could be expanded

### 10. Drag Multiple Items to External Target
**What:** Drag items out of tree to other windows/apps
**Why:** OS integration
**Limitation:** May not be possible in ReaImGui

## Low Priority 🟢

### 11. Undo/Redo Stack
**What:** Ctrl+Z to undo drag/drop, rename, delete
**Why:** Safety net for mistakes
**Complexity:** Requires state snapshots

### 12. Virtual Scrolling Optimization
**Status:** Already implemented
**Improvement:** Could add item height caching

### 13. Column Sorting
**What:** Sort by name, date, type, size
**Why:** File manager feature
**Note:** Requires metadata in nodes

### 14. Drag Preview Animation
**What:** Smooth preview fade-in/movement
**Why:** Polish
**Complexity:** Low, just interpolation

### 15. Sticky Section Headers
**What:** Headers stay visible when scrolling
**Why:** Context in long lists
**Complexity:** Medium

### 16. Filter Improvements
**Current:** Simple string match
**Improvements:**
- Regex support
- Case-sensitive toggle
- Fuzzy matching
- Search in: names only / full path

### 17. Custom Context Menu Actions
**What:** Allow registering custom actions
**Why:** Extensibility
```lua
tree_config.context_menu_items = {
  { label = "Open in Explorer", callback = function(node) ... end },
  { label = "Copy Path", callback = function(node) ... end },
}
```

### 18. Checkbox Tri-State Logic
**Status:** Partially implemented
**Improvement:** Actually compute parent/child checkbox states

### 19. Tree Persistence
**What:** Save/load expanded state, scroll position
**Why:** UX across sessions
```lua
-- Save on close:
local state = {
  open = tree_state.open,
  scroll = tree_state.scroll_y,
}
-- Load on init
```

### 20. Accessibility
**What:** Screen reader support, high contrast mode
**Why:** Inclusivity
**Limitation:** ReaImGui may have limited support

## Performance 🚀

### Current Status
- Virtual scrolling ✅
- Flat list caching ✅
- Efficient ID scoping ✅

### Potential Optimizations
1. **Lazy loading:** Don't populate children until folder expanded
2. **Item pooling:** Reuse draw objects
3. **Dirty flags:** Only redraw changed portions
4. **Search indexing:** Pre-compute search tokens

## VS Code Parity Analysis

**Features we have:**
- ✅ Multi-selection
- ✅ Multi-drag
- ✅ Drag preview with count
- ✅ Context menu
- ✅ Inline rename
- ✅ Search/filter
- ✅ Keyboard navigation (arrows)
- ✅ Icons
- ✅ Tree lines
- ✅ Selection highlighting

**Missing from VS Code:**
- ❌ Auto-scroll during drag
- ❌ Copy-on-drag (Ctrl+drag)
- ❌ Type-to-search
- ❌ Breadcrumbs
- ❌ Tooltips for truncated items
- ❌ Git status indicators
- ❌ File watchers / auto-refresh
- ❌ Compact folders (e.g., "src/components" collapsed)

## Recommended Next Steps

**For production-ready TreeView:**
1. Auto-scroll during drag (HIGH)
2. Copy-on-drag with Ctrl (HIGH)
3. Tooltips for truncated items (HIGH)
4. Type-to-search (MEDIUM)
5. Better keyboard nav (Home/End/PageUp/PageDown) (MEDIUM)

**For polish:**
1. Smooth scrolling animations
2. Drag preview animation
3. Better visual feedback for disabled items

**For extensibility:**
1. Custom context menu registration
2. Event callbacks (on rename, on delete, on drag, etc.)
3. Custom icon providers
