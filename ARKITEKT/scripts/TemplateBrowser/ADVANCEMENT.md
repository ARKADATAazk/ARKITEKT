# TemplateBrowser Advancement Log

## Current Status: Production-Ready with Enhancements Planned

### Core Features (Complete)
- [x] Template scanning with incremental updates
- [x] Grid and list view modes
- [x] Resizable tiles
- [x] Tag system (create, rename, delete, assign)
- [x] FX/VST parsing from templates
- [x] Background FX parsing queue (non-blocking)
- [x] Search by template name
- [x] Filter by tags
- [x] Filter by FX/VST
- [x] Sort: alphabetical, usage count, insertion order, color
- [x] Favorites system
- [x] Recents tracking
- [x] Most used tracking
- [x] Template insertion (new track)
- [x] Template application (to selected tracks)
- [x] Undo/redo for file operations
- [x] Archive system (soft delete)
- [x] Rename templates
- [x] Move templates between folders
- [x] Create/rename/delete folders
- [x] Conflict resolution (overwrite/keep both)
- [x] Metadata persistence (JSON)
- [x] Three-panel layout (folders | grid | info)
- [x] Keyboard shortcuts
- [x] Context menus
- [x] Status bar with messages
- [x] Overlay mode toggle

### Recent Refactoring (Complete)
- [x] Console logging → Logger framework migration
- [x] Deprecated shim cleanup
- [x] ops.lua → operations.lua rename
- [x] Inline requires moved to module top
- [x] Platform abstraction for ImGui
- [x] Magic numbers to constants

### Recently Completed
- [x] Fuzzy search implementation
- [x] Track count parsing from .RTrackTemplate files
- [x] Track count badge on tiles (`5T`, `16T`)
- [x] Stacked visual for multi-track templates
- [x] _Inbox folder workflow (pinned at top, template count badge)
- [x] _Archive folder (renamed from .archive for visibility)

### Planned (Next Sprint)
- [x] Track-tree hover preview (lazy-loaded, cached)

### Backlog
- [ ] Search in notes
- [ ] Usage statistics over time
- [ ] New template indicator
- [ ] Auto-tag suggestions
- [ ] Bulk operations
- [ ] Keyboard navigation improvements

---

## Architecture Overview

```
TemplateBrowser/
├── ARK_TemplateBrowser.lua    # Entry point
├── app/                        # State management
├── data/                       # Persistence, file ops, undo
├── domain/                     # Business logic
│   ├── template/              # Scanner, operations
│   ├── tags/                  # Tag service
│   ├── search/                # Fuzzy search
│   └── fx/                    # FX parser, queue
├── ui/                        # Views, tiles, config
│   ├── views/                 # Panel renderers
│   └── tiles/                 # Tile renderers
└── defs/                      # Constants, defaults
```

### Key Files
| File | Purpose |
|------|---------|
| `domain/template/scanner.lua` | Scan filesystem, filter templates |
| `domain/template/operations.lua` | Insert/apply templates |
| `domain/template/track_parser.lua` | Parse track names/hierarchy from templates |
| `domain/search/fuzzy.lua` | Fuzzy string matching for search |
| `domain/fx/parser.lua` | Parse FX from .RTrackTemplate |
| `data/storage.lua` | JSON metadata persistence |
| `data/file_ops.lua` | Move/rename/delete with archive |
| `ui/tiles/tile.lua` | Grid tile renderer |
| `ui/tooltips.lua` | Template tooltips with track tree preview |

---

## Version History

### v0.9 (Current)
- Logger migration complete
- Full refactoring pass
- Production-ready stability

### v0.8
- FX parsing with background queue
- Tag filtering improvements
- Conflict resolution modal

### v0.7
- Three-panel layout
- Favorites/recents/most used
- Undo/redo system

### v0.6
- Initial tag system
- Metadata persistence
- Archive system

### v0.5
- Basic grid view
- Template scanning
- Insert/apply operations
