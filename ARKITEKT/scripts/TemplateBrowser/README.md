# Template Browser

A powerful template management tool for REAPER with advanced organization features.

## Features

- **Three-panel layout**: Folders | Templates | Info/Tags
- **Virtual folders**: Organize templates without moving files
- **Tag system**: Multi-tag support with colors
- **VST filtering**: Filter templates by the FX they contain
- **Drag-and-drop**: Move templates and folders visually
- **Recent templates**: Quick access to recently used templates
- **Notes**: Add markdown notes to any template
- **Undo/Redo**: Full undo support for file operations

## Architecture

### Module Structure

```
TemplateBrowser/
├── app/                     # Application layer
│   ├── config.lua          # Configuration (re-exports from config/)
│   └── state.lua           # Application state
│
├── config/                  # Configuration constants
│   ├── constants.lua       # App-wide constants
│   ├── defaults.lua        # Default values
│   └── strings.lua         # UI strings
│
├── data/                    # Data persistence layer
│   ├── storage.lua         # Metadata save/load (JSON)
│   ├── file_ops.lua        # File system operations
│   └── undo.lua            # Undo/redo manager
│
├── domain/                  # Business logic (no UI)
│   ├── template/
│   │   ├── scanner.lua     # Template discovery & filtering
│   │   ├── operations.lua  # Template actions (apply/insert)
│   │   ├── stats.lua       # Usage statistics
│   │   └── track_parser.lua # Track chunk parsing
│   ├── tags/
│   │   └── service.lua     # Tag management
│   ├── fx/
│   │   ├── parser.lua      # VST/FX parsing
│   │   └── queue.lua       # Background FX parsing queue
│   └── search/
│       └── fuzzy.lua       # Fuzzy search
│
├── ui/                      # User interface
│   ├── init.lua            # Main GUI orchestrator
│   ├── status.lua          # Status bar component
│   ├── shortcuts.lua       # Keyboard shortcuts
│   ├── tooltips.lua        # Tooltip definitions & rendering
│   │
│   ├── config/             # UI-specific constants
│   │   ├── constants.lua   # Layout constants
│   │   ├── left_panel.lua
│   │   ├── template.lua
│   │   ├── info.lua
│   │   ├── convenience.lua
│   │   └── recent.lua
│   │
│   ├── views/              # Modular view components
│   │   ├── helpers.lua
│   │   ├── left_panel_view.lua
│   │   ├── template_panel_view.lua
│   │   ├── info_panel_view.lua
│   │   ├── convenience_panel_view.lua
│   │   ├── template_modals_view.lua
│   │   ├── tree_view.lua
│   │   ├── left_panel/
│   │   │   ├── directory_tab.lua
│   │   │   ├── vsts_tab.lua
│   │   │   └── tags_tab.lua
│   │   └── convenience_panel/
│   │       ├── tags_tab.lua
│   │       └── vsts_tab.lua
│   │
│   └── tiles/              # Template tile rendering
│       ├── factory.lua
│       ├── grid_callbacks.lua
│       ├── helpers.lua
│       ├── tile.lua
│       └── tile_compact.lua
```

### Data Flow

```
[User Action] → [Domain Logic] → [State Update] → [View Re-render]
     ↓
[Persistence] (for destructive operations)
```

**Example: Moving a template**
1. User drags template to folder (tree_view.lua)
2. tree_view calls FileOps.move_template() (domain)
3. FileOps updates file system
4. Scanner.scan_templates() rebuilds state
5. View modules re-render with new state

### View Architecture

All view modules follow a consistent pattern:

```lua
-- Stateless function module
local M = {}

function M.draw_something(ctx, state, config, width, height)
  -- Render UI
  -- Handle user input
  -- Update state directly
end

return M
```

**Key principles:**
- Views are **stateless** - all state lives in `app/state.lua`
- Views **read** state and **write** state directly
- Domain logic is **separate** from UI logic
- UI constants live in `ui/config/constants.lua`

## Common Development Tasks

### Adding a New Template Action

**Example: Add "Duplicate Template" button**

1. **Add domain logic** (`domain/template/operations.lua`):
```lua
function M.duplicate_template(template_path, state)
  -- Implementation
end
```

2. **Add UI button** (`ui/views/info_panel_view.lua`):
```lua
if Button.draw_at_cursor(ctx, {
  label = "Duplicate Template",
  width = -1,
  height = UI.BUTTON.HEIGHT_ACTION
}, "duplicate_template") then
  TemplateOps.duplicate_template(tmpl.path, state)
end
```

3. **Add keyboard shortcut** (`ui/shortcuts.lua`):
```lua
if ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl) and
   ImGui.IsKeyPressed(ctx, ImGui.Key_D) then
  return "duplicate_template"
end
```

4. **Wire shortcut** (`ui/init.lua`):
```lua
elseif action == "duplicate_template" then
  if self.state.selected_template then
    TemplateOps.duplicate_template(
      self.state.selected_template.path,
      self.state
    )
  end
```

### Adding a New Folder Action

**Example: Add "Archive Folder" to context menu**

1. **Add domain logic** (`data/file_ops.lua`):
```lua
function M.archive_folder(folder_path)
  -- Implementation
  return success, archive_path
end
```

2. **Add to context menu** (`ui/views/tree_view.lua`):
```lua
if ContextMenu.item(ctx_inner, "Archive Folder") then
  local success = FileOps.archive_folder(node.full_path)
  if success then
    Scanner.scan_templates(state)
  end
  ImGui.CloseCurrentPopup(ctx_inner)
end
```

### Adding a New Tab to Left Panel

1. **Create tab module** (`ui/views/left_panel/new_tab.lua`):
```lua
local M = {}

function M.draw(ctx, state, config, width, height)
  -- Tab content
end

return M
```

2. **Import in left_panel_view.lua**:
```lua
local NewTab = require('TemplateBrowser.ui.views.left_panel.new_tab')
```

3. **Add to tabs definition**:
```lua
local tabs_def = {
  { id = "directory", label = "DIRECTORY" },
  { id = "vsts", label = "VSTS" },
  { id = "tags", label = "TAGS" },
  { id = "newtab", label = "NEW TAB" },  -- Add here
}
```

4. **Add to tab switcher**:
```lua
if state.left_panel_tab == "directory" then
  DirectoryTab.draw(ctx, state, config, width, content_height)
-- ... other tabs ...
elseif state.left_panel_tab == "newtab" then
  NewTab.draw(ctx, state, config, width, content_height)
end
```

### Changing UI Layout

**Panel widths** are controlled by separator ratios in `ui/init.lua`:
```lua
self.state.separator1_ratio  -- Left panel width
self.state.separator2_ratio  -- Template panel width
```

**Spacing/padding** constants live in `ui/config/constants.lua`:
```lua
M.PADDING = {
  PANEL = 14,
  PANEL_INNER = 8,
  SMALL = 4,
}
```

## Testing

After making changes:

1. **Reload REAPER** - Template Browser doesn't hot-reload
2. **Test basic operations**:
   - Browse templates
   - Apply/Insert template
   - Create/rename/delete folders
   - Tag templates
   - Filter by tags/VSTs
3. **Test undo/redo** for destructive operations
4. **Check console** for Lua errors

## Performance Considerations

- **FX parsing** happens in background queue (5 templates per frame)
- **Large libraries** (1000+ templates) should load quickly
- **Metadata caching** prevents re-parsing unchanged templates
- **Virtual folders** have no file system overhead

## State Management

All state lives in `app/state.lua`:

```lua
State = {
  -- Templates
  templates = {},           -- All templates
  filtered_templates = {},  -- After filtering
  selected_template = nil,  -- Currently selected

  -- Folders
  folders = {},            -- Folder tree structure
  selected_folder = "",    -- Current folder path
  selected_folders = {},   -- Multi-select support

  -- Filters
  filter_tags = {},        -- Active tag filters
  filter_fx = {},          -- Active FX filters
  search_query = "",       -- Search text

  -- UI state
  left_panel_tab = "directory",
  separator1_ratio = 0.20,
  separator2_ratio = 0.75,

  -- Metadata (persisted to disk)
  metadata = {
    templates = {},        -- Per-template metadata
    tags = {},            -- Tag definitions
    virtual_folders = {}, -- Virtual folder structure
    folders = {},         -- Physical folder metadata
  }
}
```

## Metadata Persistence

Metadata is stored in: `REAPER/Data/ARKITEKT/TemplateBrowser/metadata.json`

Contains:
- Template notes, colors, tags, usage stats
- Tag definitions (name, color)
- Virtual folder structure
- Physical folder colors

**Auto-saves** on every metadata change.

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+Z` | Undo |
| `Ctrl+Y` / `Ctrl+Shift+Z` | Redo |
| `F2` | Rename selected template |
| `Delete` | Archive selected template |
| `Enter` | Apply template to selected track |
| `Ctrl+Enter` | Insert template as new track |
| `Ctrl+F` | Focus search box |
| `Esc` | Close window |
| Arrow keys | Navigate template grid |

## Code Style

- **Naming**: `snake_case` for functions and variables
- **Comments**: Use `--` for inline, document complex logic
- **Modules**: Return table with public functions
- **State**: Never create local state in views
- **Constants**: Use `UI.BUTTON.HEIGHT_DEFAULT` not magic numbers

## Future Enhancements

Potential improvements:
- [ ] Import/export templates from ZIP
- [ ] Cloud sync for metadata
- [ ] Template preview (audio/MIDI)
- [ ] Bulk operations (multi-select templates)
- [ ] Custom metadata fields
- [ ] Template usage analytics
- [ ] Search by content (track names, FX chains)

## Troubleshooting

**Templates not showing:**
- Check REAPER/TrackTemplates folder exists
- Force rescan: VSTs tab → "Force Reparse All"

**Metadata lost:**
- Check REAPER/Data/ARKITEKT/TemplateBrowser/metadata.json
- Layout preferences stored in layout.json

**Performance issues:**
- Large FX chains take time to parse
- Background queue processes 5 per frame
- Check console for parsing errors

## Contributing

When making changes:
1. Follow the module structure above
2. Keep views stateless
3. Add constants to `ui/config/constants.lua`
4. Test all undo/redo operations
5. Update this README if adding features
