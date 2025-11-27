# ThemeAdjuster - Advancement & Roadmap

> **Target Users**: Theme developers AND end users customizing themes

---

## Current State Summary

### Working Features

| Feature | Status | Notes |
|---------|--------|-------|
| **Package Assembler** | ~90% | Drag-drop reorder, exclusions, pins, configurations |
| **Package Scanning** | Working | Scans folders for assets |
| **Theme Detection** | Working | Detects current theme, ZIP vs folder |
| **Parameter Discovery** | Working | Discovers all theme params |
| **Parameter Assignment** | ~70% | Drag params to tabs (TCP/MCP/etc) |
| **Templates System** | ~50% | Create/group templates, needs config UI |
| **Parameter Linking** | ~40% | Link params together, needs polish |
| **Companion JSON** | Working | Saves/loads mappings per theme |
| **TCP/MCP/etc Views** | Partial | Display assigned params |

### Known Incomplete Areas

1. **Additional Tab** - Complex but unfinished
   - Template configuration UI (preset spinner, etc.)
   - Parameter control rendering in assignment grid
   - How assigned params display in TCP/MCP views

2. **Apply Mechanism** - Core functionality gap
   - No "Reassemble Theme" output yet
   - No parameter value writing back

3. **No Real-time Preview** - Planned for later

---

## Architecture Overview

```
ThemeAdjuster/
├── app/           # State, config, init
├── data/          # Package scanning, demo data
├── defs/          # Constants, colors, strings
├── domain/        # Business logic
│   ├── links/     # Parameter linking
│   ├── packages/  # Package metadata, image mapping
│   └── theme/     # Reader, mapper, params, discovery
├── ui/
│   ├── views/     # Tab views (tcp, mcp, assembler, additional, etc.)
│   └── grids/     # Grid factories and tile renderers
└── tests/
```

---

## Roadmap

### Phase 1: Core Functionality (Critical Path)

#### 1.1 Theme Output System
**Priority: HIGH** - Without this, nothing is usable

- [ ] Implement "Reassemble Theme" action
  - Copy base theme to output folder
  - Apply package assets based on resolution order
  - Handle image strips and individual images
  - Preserve theme metadata
- [ ] Add output folder selection
- [ ] Add theme backup before modification
- [ ] Status feedback (progress, errors)

#### 1.2 Parameter Value Application
**Priority: HIGH** - Required for parameter adjustments to work

- [ ] Write parameter values back to theme
  - Via `reaper.ThemeLayout_SetParameter()`?
  - Or modify theme files directly?
- [ ] Track "dirty" state (unsaved changes)
- [ ] Save/restore parameter presets

#### 1.3 Additional Tab Completion
**Priority: MEDIUM** - Large effort, needed for advanced users

- [ ] Template configuration UI
  - Preset spinner (discrete values)
  - Slider (continuous range)
  - Toggle (on/off)
  - Color picker (for color params)
- [ ] Parameter controls in assignment grid
  - Currently tiles exist but no interactive controls?
  - Need value display, adjustment widgets
- [ ] Polish drag-drop between panels
- [ ] Template export/import (share templates)

---

### Phase 2: User Experience

#### 2.1 Validation & Safety
- [ ] Validate theme before apply
- [ ] Check for missing assets
- [ ] Warn about overwrites
- [ ] Backup management (list, restore)

#### 2.2 Undo/Redo System
- [ ] Command pattern for actions
- [ ] History stack
- [ ] UI to navigate history

#### 2.3 Search & Filter
- [ ] Global search across all params
- [ ] Filter by category, type, assigned status
- [ ] Quick-jump to param by name

#### 2.4 Keyboard Shortcuts
- [ ] Ctrl+Z/Y for undo/redo
- [ ] Delete key for removing assignments
- [ ] Arrow keys for navigation
- [ ] Enter to confirm actions

---

### Phase 3: Advanced Features

#### 3.1 Real-time Preview
**Note**: Deferred - complex, low priority initially

- [ ] Apply changes temporarily without saving
- [ ] Preview parameter adjustments live
- [ ] Preview package assembly result
- [ ] Requires theme reload mechanism

#### 3.2 Package Repository
- [ ] Package format specification
- [ ] Import packages from files
- [ ] Export packages to share
- [ ] (Future) Online repository browser

#### 3.3 Theme Comparison
- [ ] Compare two themes side-by-side
- [ ] Diff parameter values
- [ ] Merge changes from one to another

#### 3.4 Batch Operations
- [ ] Apply same adjustment to multiple params
- [ ] Bulk assign params to tabs
- [ ] Copy configuration between themes

---

### Phase 4: Polish & Documentation

#### 4.1 Help System
- [ ] Tooltips for all controls
- [ ] "What's this?" context help
- [ ] Built-in tutorial/walkthrough
- [ ] Link to online docs

#### 4.2 Error Handling
- [ ] Graceful degradation for missing files
- [ ] Clear error messages
- [ ] Recovery suggestions

#### 4.3 Performance
- [ ] Lazy loading for large parameter lists
- [ ] Cache invalidation optimization
- [ ] Smooth scrolling for grids

---

## Questions to Resolve

### Technical

1. **Parameter persistence**: Does `ThemeLayout_SetParameter()` persist across sessions, or do we need to modify theme files directly?

2. **Theme reload**: Can we force REAPER to reload theme without restart? Required for real-time preview.

3. **Image strip handling**: How to properly slice/combine image strips when assembling?

### Design

1. **Template types**: What control types do we need?
   - Preset spinner (discrete values)
   - Slider (continuous)
   - Toggle (boolean)
   - Color picker
   - Others?

2. **Assignment behavior**: When a param is assigned to TCP tab, what exactly happens?
   - Shows in TCP view with controls?
   - Just tagged for organization?
   - Something else?

3. **Package priority**: Current model is linear priority. Do we need:
   - Per-category priorities?
   - Conditional priorities (if X then use Y)?

---

## File Reference

### Key Files for Phase 1

| Task | Files |
|------|-------|
| Theme output | `data/packages/manager.lua` (add assemble function) |
| Parameter apply | `domain/theme/params.lua` (add write functions) |
| Additional tab | `ui/views/additional_view.lua` |
| Template config | `ui/grids/renderers/template_tile.lua` |
| Assignment rendering | `ui/grids/renderers/assignment_tile.lua` |

### Config Locations

- Theme mappings: `ColorThemes/<ThemeName>.json`
- App settings: Via `arkitekt.core.settings`
- Package state: `<ThemeRoot>/assembler_state.json`

---

## Contributing

When working on ThemeAdjuster:

1. **Read CLAUDE.md** - Follow layer organization
2. **Keep domain clean** - No ImGui in `domain/*`
3. **Use Fs module** - For all file operations
4. **Use Logger** - For debug output
5. **Test in Sandbox** - Before committing

---

*Last updated: 2025-11-27*
