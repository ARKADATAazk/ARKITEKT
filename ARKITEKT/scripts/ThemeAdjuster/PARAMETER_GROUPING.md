# Parameter Grouping & Organization System

## Overview

The Additional tab will support **visual organization** through parameter grouping, allowing users to organize discovered parameters without moving them to other tabs.

## Core Features

### 1. Selection System
- **Selection Rectangle**: Drag to select multiple parameters (marquee selection)
- **Click Selection**: Click individual param to select
- **Multi-Select**: Ctrl+Click to add/remove from selection
- **Select All**: Ctrl+A to select all visible params

### 2. Grouping
- **Create Group**: Select multiple params → "Create Group" button
- **Group Names**: Editable group names with colors
- **Collapse/Expand**: Groups can be collapsed to save space
- **Nested Structure**: Groups contain parameters, displayed as collapsible sections

### 3. Organization
- **Drag to Reorder**: Drag groups to reorder them
- **Individual Access**: Can select individual params within groups
- **Group Movement**: Moving a group moves all contained params
- **Ungroup**: Select group → "Ungroup" to dissolve

### 4. Persistence
- **JSON Storage**: Groups saved in theme mapping JSON
- **Auto-Load**: Groups restored when JSON is loaded
- **Export**: Groups included in JSON export

## Architecture

### Selection State
```lua
{
  selected_params = {
    ["param_name_1"] = true,
    ["param_name_2"] = true,
  },
  selection_rectangle = SelectionRectangle.new(),
  selection_mode = "replace" | "add" | "subtract"
}
```

### Group Structure
```lua
{
  groups = {
    {
      id = "group_1",
      name = "Custom Meters",
      color = "#FF6600",
      collapsed = false,
      params = {
        "tcp_custom_meter_1",
        "tcp_custom_meter_2",
        "mcp_custom_meter_1",
      }
    },
    {
      id = "group_2",
      name = "Fader Sizes",
      color = "#00FF88",
      collapsed = true,
      params = {
        "tcp_fader_size",
        "mcp_fader_size",
      }
    }
  },
  ungrouped_params = {
    "some_other_param",
    "another_param",
  }
}
```

### JSON Format Extension
```json
{
  "theme_name": "MyTheme",
  "version": "1.0.0",
  "params": { ... },
  "groups": [
    {
      "id": "group_1",
      "name": "Custom Meters",
      "color": "#FF6600",
      "collapsed": false,
      "params": [
        "tcp_custom_meter_1",
        "tcp_custom_meter_2"
      ]
    }
  ]
}
```

## UI Layout

```
┌─────────────────────────────────────────┐
│ Additional Parameters    [Export to JSON]│
│ Auto-discovered: MyTheme (15 found)      │
├─────────────────────────────────────────┤
│                                          │
│ [5 params selected]                      │
│ [Create Group]  [Ungroup]  [Deselect All]│
│                                          │
│ ▼ Custom Meters ●────────────────────────│
│   ├─ TCP Meter Size      [spinner] ☑    │
│   ├─ MCP Meter Size      [spinner] ☑    │
│   └─ Meter Algorithm     [toggle]  ☑    │
│                                          │
│ ▶ Fader Sizes ●──────────────────────────│
│                                          │
│ ▼ Uncategorized ────────────────────────│
│   ├─ some_param         [slider]        │
│   └─ another_param      [toggle]        │
│                                          │
│ [Marquee selection rectangle...]        │
└─────────────────────────────────────────┘
```

## User Workflow

### Creating a Group
1. Drag selection rectangle over params (or Ctrl+Click multiple)
2. Click "Create Group" button
3. Enter group name in dialog
4. Choose group color (optional)
5. Group created, params moved into it

### Reorganizing
1. Drag group header to reorder groups
2. Drag individual param to move between groups
3. Collapse groups you don't need to see

### Exporting
1. Click "Export to JSON"
2. Groups are included in exported JSON
3. Share JSON with theme

## Implementation Plan

### Phase 3.1: Selection System
- [ ] Add selection state to AdditionalView
- [ ] Integrate SelectionRectangle widget
- [ ] Implement click selection (single/multi)
- [ ] Add keyboard shortcuts (Ctrl+A, etc.)
- [ ] Visual feedback for selected params

### Phase 3.2: Group Creation
- [ ] "Create Group" UI when selection active
- [ ] Group name dialog
- [ ] Color picker for groups
- [ ] Generate unique group IDs
- [ ] Move params into group

### Phase 3.3: Group Rendering
- [ ] Collapsible group headers
- [ ] Indented param display within groups
- [ ] Group color indicators
- [ ] Collapse/expand state persistence

### Phase 3.4: Organization
- [ ] Drag-to-reorder groups (optional - complex)
- [ ] "Ungroup" button
- [ ] Delete empty groups
- [ ] Rename groups

### Phase 3.5: Persistence
- [ ] Extend JSON format with groups
- [ ] Save groups on export
- [ ] Load groups on startup
- [ ] Migrate old JSONs gracefully

## Technical Details

### Selection Rectangle Integration
```lua
local SelectionRect = require('arkitekt.gui.widgets.data.selection_rectangle')

-- In AdditionalView:new()
self.selection_rect = SelectionRect.new()
self.selected_params = {}

-- In draw loop
if ImGui.IsMouseClicked(ctx, ImGui.MouseButton_Left) then
  local mx, my = ImGui.GetMousePos(ctx)
  self.selection_rect:begin(mx, my, "replace", ctx)
end

if self.selection_rect:is_active() then
  local mx, my = ImGui.GetMousePos(ctx)
  self.selection_rect:update(mx, my)

  -- Visual feedback
  local x1, y1, x2, y2 = self.selection_rect:aabb_visual()
  if x1 then
    local dl = ImGui.GetWindowDrawList(ctx)
    ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, 0x88FFFFFF, 0, 0, 1)
    ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, 0x22FFFFFF)
  end
end

if ImGui.IsMouseReleased(ctx, ImGui.MouseButton_Left) then
  local x1, y1, x2, y2, did_drag = self.selection_rect:finish()
  if did_drag then
    self:select_params_in_rect(x1, y1, x2, y2)
  end
end
```

### Group State Management
```lua
function AdditionalView:create_group()
  local group_id = "group_" .. os.time()
  local group = {
    id = group_id,
    name = "New Group",
    color = "#666666",
    collapsed = false,
    params = {}
  }

  -- Move selected params into group
  for param_name, _ in pairs(self.selected_params) do
    table.insert(group.params, param_name)
  end

  table.insert(self.groups, group)
  self:clear_selection()
end
```

## Future Enhancements
- Drag-and-drop reordering (complex)
- Group-to-group merging
- Search/filter within groups
- Group templates
- Community shared group presets

## Benefits
- **Organization**: Keep Additional tab clean and organized
- **Workflow**: Quickly find related parameters
- **Sharing**: Export organized structures
- **Learning**: Group similar params for easier understanding
- **No Complexity**: Avoids spreading params across existing tabs
