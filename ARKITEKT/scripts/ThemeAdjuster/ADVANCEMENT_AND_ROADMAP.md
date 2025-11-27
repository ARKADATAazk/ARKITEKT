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

#### 1.1 Assembler: Theme Output System
**Priority: HIGH** - Core apply functionality

- [x] Implement "Reassemble Theme" action
  - Copy base theme to output folder
  - Apply package assets based on resolution order
  - Preserve theme metadata
- [x] Add output folder selection (default: `<ThemeName>_Reassembled/`)
- [x] Add theme backup before modification (folder mode)
- [x] **Delta tracking** - Only copy changed files on subsequent applies
  - `.assembler_state.json` tracks applied assets
  - Restores original files when packages are removed
- [x] **Output mode toggle** - Folder (📁) vs ZIP (📦) in footer
- [ ] Handle conflicts (same key from multiple packages) - show visual indicator? Maybe not needed if priority is clear
- [ ] **ZIP operation progress UI** - Fetch spinner/progress from existing arkitekt library when needed

#### 1.2 Additional Tab: Polish & Organization
**Priority: MEDIUM** - Core param system works, need better organization

Parameter adjustment via `ThemeLayout_SetParameter()` already works.
Focus on organization and UX:

- [ ] Clear separation: DEFAULT vs ADDITIONAL params in TCP/MCP views
- [ ] Template controls (spinner, slider, toggle) - wire up properly
- [ ] Polish drag-drop between Library → Templates → Assignment
- [ ] Template export/import (share templates)
- [ ] Better visual distinction for param categories

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

## Design Decisions (Resolved)

### Parameter System
- **`ThemeLayout_SetParameter()`** - Permanent, works correctly. This is the core mechanism.
- **No image strip handling** - Not needed. Users see changes live in REAPER, no in-app visualization.

### Control Types (Current)
Three types cover current needs:
- **Preset spinner** - Cycle through discrete values
- **Slider** - Continuous range
- **Toggle** - On/off

Future: Tables, macros, grouped controls - but not immediate priority.

### The "Generic vs Theme 6.0" Challenge

**Problem**: ThemeAdjuster aims to be generic (work with any theme), but Theme 6.0 (the reference) has messy, inconsistent param naming. This creates tension:
- Filter/treat Theme 6.0 params specially
- Hard to represent values meant for it
- Need backward compatibility for 6.0-based themes

**Possible approaches**:
1. **Rename Theme 6.0 params** with a backward compat layer for existing themes
2. **Rebuild as example** - Show how devs can "visually program" their own adjuster (like Wordpress blocks)
3. **Default vs Additional split** - Keep organized: stock params in one spot, custom/additional elsewhere

### Open Questions

1. **TCP view organization**: How to clearly separate:
   - DEFAULT theme controls (stock params)
   - ADDITIONAL params (custom/unknown)
   - Need clear visual distinction

2. **Theme agnostic goal**: How much do we optimize for Theme 6.0 vs building a truly generic system?

3. **Future vision**: Custom tables, macro handling, visual block programming - defer to later phases

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
