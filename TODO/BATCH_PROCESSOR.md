# Batch Processor Modal TODO

> Evolve `batch_rename_modal.lua` into a generic batch processor that can handle multiple operations through configurable parameters.

---

## Current State

**Location**: `arkitekt/gui/widgets/overlays/batch_rename_modal.lua` (983 lines)

Currently handles:
- Rename (pattern with wildcards)
- Recolor (color picker)
- Rename & Recolor (both)

---

## Vision: Generic Batch Processor

A single modal that can be configured to perform any combination of batch operations on selected items:

### Potential Operations

| Operation | UI Component | Applies To |
|-----------|--------------|------------|
| **Rename** | Pattern input + wildcards + common names | Regions, items, tracks, templates |
| **Recolor** | Color picker | Regions, items, tracks, playlists |
| **Retag** | Tag chip palette | Templates, items |
| **Move to folder** | Folder picker | Templates, items |
| **Set property** | Property dropdowns | Regions (quantize, loop), items |
| **Assign to playlist** | Playlist selector | Regions |
| **Bulk delete** | Confirmation | Any |
| **Duplicate** | Count input | Regions, items |
| **Export** | Format selector + path | Templates, items |

---

## API Design (Draft)

```lua
local BatchProcessor = require('arkitekt.gui.widgets.overlays.batch_processor')

-- Configure operations
BatchProcessor.open({
  item_count = 5,
  item_type = "regions",  -- For display ("Batch process 5 regions")

  -- Enable specific operations
  operations = {
    rename = {
      enabled = true,
      wildcards = {"$n", "$l"},  -- Which wildcards to show
      common_names = "game",     -- Preset category or custom list
    },
    recolor = {
      enabled = true,
      initial_color = 0xFF5733FF,
    },
    retag = {
      enabled = true,
      available_tags = {...},
      current_tags = {...},
    },
    set_property = {
      enabled = true,
      properties = {
        {id = "quantize", label = "Quantize", type = "dropdown", options = {...}},
        {id = "loop", label = "Loop", type = "checkbox"},
      },
    },
  },

  -- Callbacks per operation
  on_rename = function(pattern) ... end,
  on_recolor = function(color) ... end,
  on_retag = function(tags) ... end,
  on_set_property = function(props) ... end,

  -- Or single callback with all results
  on_confirm = function(results)
    -- results = {
    --   rename = "pattern_01",
    --   recolor = 0xFF5733FF,
    --   tags_added = {"combat"},
    --   tags_removed = {"calm"},
    --   properties = {quantize = "1/4", loop = true},
    -- }
  end,
})
```

---

## UI Layout Options

### Option A: Tabbed Interface

```
┌─────────────────────────────────────────────┐
│  Batch Process 5 regions                    │
├─────────────────────────────────────────────┤
│ [Rename] [Recolor] [Tags] [Properties]      │  <- Tabs
├─────────────────────────────────────────────┤
│                                             │
│  [Content for selected tab]                 │
│                                             │
├─────────────────────────────────────────────┤
│         [Cancel]  [Apply Selected]          │
└─────────────────────────────────────────────┘
```

### Option B: Collapsible Sections (Current Style, Extended)

```
┌─────────────────────────────────────────────┐
│  Batch Process 5 regions                    │
├─────────────────────────────────────────────┤
│ ▼ Rename                                    │
│   [Pattern input]                           │
│   [Wildcards] [Common names]                │
├─────────────────────────────────────────────┤
│ ▼ Recolor                                   │
│   [Color picker]                            │
├─────────────────────────────────────────────┤
│ ▶ Tags (collapsed)                          │
├─────────────────────────────────────────────┤
│ ▶ Properties (collapsed)                    │
├─────────────────────────────────────────────┤
│  [Cancel] [Rename] [Recolor] [Apply All]    │
└─────────────────────────────────────────────┘
```

### Option C: Two-Column with Sidebar

```
┌──────────┬──────────────────────────────────┐
│ ☑ Rename │  Pattern: [____________]         │
│ ☑ Recolor│  Wildcards: [$n] [$l]           │
│ ☐ Tags   │  Common: [combat] [calm]...     │
│ ☐ Props  │                                  │
│          │  [Color Picker]                  │
│          │                                  │
│          │  Preview: pattern_01, pattern_02 │
├──────────┴──────────────────────────────────┤
│         [Cancel]  [Apply Selected]          │
└─────────────────────────────────────────────┘
```

---

## Implementation Phases

### Phase 1: Refactor Current Modal

- [ ] Extract operation-specific code into separate modules:
  - `batch_processor/rename_section.lua`
  - `batch_processor/recolor_section.lua`
- [ ] Create unified `BatchProcessor` wrapper that composes sections
- [ ] Maintain backward compatibility with current API

### Phase 2: Add Configuration System

- [ ] Define operation config schema
- [ ] Dynamic section rendering based on config
- [ ] Callback system per operation

### Phase 3: Add New Operations

- [ ] Tag management section (add/remove tags)
- [ ] Property editing section (dropdowns, checkboxes)
- [ ] Folder/playlist assignment

### Phase 4: Script Integration

- [ ] RegionPlaylist: rename, recolor, assign to playlist, set quantize
- [ ] ItemPicker: rename, recolor, retag
- [ ] TemplateBrowser: rename, recolor, retag, move to folder

---

## Shared Components to Extract First

These can be extracted independently and reused:

| Component | Current Location | Target |
|-----------|-----------------|--------|
| Wildcard system | Lines 92-133 | `core/wildcards.lua` |
| Common names palette | Lines 479-544 | `defs/common_names.lua` |
| Flow layout chips | Lines 555-627 | `widgets/data/action_chip_palette.lua` |
| Modifier key handling | Lines 599-623 | `core/input_modifiers.lua` |

---

## Per-Script Use Cases

### RegionPlaylist

```lua
BatchProcessor.open({
  item_count = #selected_regions,
  item_type = "regions",
  operations = {
    rename = {enabled = true, common_names = "game"},
    recolor = {enabled = true},
    set_property = {
      enabled = true,
      properties = {
        {id = "quantize", label = "Quantize", type = "dropdown", options = QUANTIZE_OPTIONS},
        {id = "loop", label = "Loop", type = "checkbox"},
      },
    },
    assign_playlist = {
      enabled = true,
      playlists = state.playlists,
    },
  },
  on_confirm = function(results) ... end,
})
```

### ItemPicker

```lua
BatchProcessor.open({
  item_count = #selected_items,
  item_type = "items",
  operations = {
    rename = {enabled = true},
    recolor = {enabled = true},
  },
  on_confirm = function(results) ... end,
})
```

### TemplateBrowser

```lua
BatchProcessor.open({
  item_count = #selected_templates,
  item_type = "templates",
  operations = {
    rename = {enabled = true},
    recolor = {enabled = true},
    retag = {
      enabled = true,
      available_tags = metadata.tags,
    },
    move_to_folder = {
      enabled = true,
      folders = folder_tree,
    },
  },
  on_confirm = function(results) ... end,
})
```

---

## Priority

**Medium-High** - The modal already works well for rename/recolor. Expanding it provides:
- Consistent UX across all scripts for batch operations
- Reduced code duplication
- Single place to improve batch workflows

---

## Related TODOs

- `TODO/TAGGING_SERVICE.md` - Action chip palette extraction
- `TODO/MODULARISATION.md` - General extraction tracking

---

*Created: 2025-11-27*
