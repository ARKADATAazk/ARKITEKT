# Framework Preset Management System TODO

> Design a framework-wide system for managing presets (common names, tags, wildcards, etc.) with defaults, user customization, and persistence.

---

## Vision

A unified preset system that:
1. **Ships with defaults** - Framework includes built-in presets (Game Music, General Music, etc.)
2. **User derivation** - Users can customize defaults without destroying them (append, delete, modify)
3. **User creation** - Users can create entirely new preset lists
4. **Persistence** - All customizations persist across sessions (REAPER ExtState)
5. **Editor window** - Dedicated UI to manage all presets framework-wide
6. **Auto-population** - Any dropdown/feature using presets automatically shows user's lists

---

## Architecture

### Data Model

```
Presets
├── defaults/              # Ships with framework (read-only)
│   ├── game_music.lua     # Combat, calm, tension, victory...
│   └── general_music.lua  # Intro, verse, chorus, bridge...
│
├── user/                  # User customizations (persisted)
│   ├── derived/           # Based on defaults
│   │   ├── game_music_custom.json   # Additions/deletions to game_music
│   │   └── general_music_custom.json
│   └── custom/            # Entirely new lists
│       └── my_sfx_names.json
```

### Derivation Model

Users don't copy the entire default - they store **diffs**:

```lua
-- user/derived/game_music_custom.json
{
  base = "game_music",           -- Which default this derives from
  additions = {                  -- New items to append
    {name = "stealth", color = "calm_green"},
    {name = "chase", color = "intense_red"},
  },
  deletions = {"victory", "defeat"},  -- Items to hide from default
  overrides = {                  -- Modify existing items
    combat = {color = "special_purple"},  -- Change combat's color
  },
}
```

**Benefits:**
- Default updates don't destroy user work
- User sees their changes clearly
- Can "reset to default" by clearing derivation

### Resolution Order

When a feature requests preset "game_music":
1. Load default `game_music.lua`
2. If user derivation exists, apply additions/deletions/overrides
3. Return merged result

---

## Framework Components

### 1. Preset Registry (`arkitekt/core/preset_registry.lua`)

Central registry for all preset types:

```lua
local PresetRegistry = require('arkitekt.core.preset_registry')

-- Register a preset type
PresetRegistry.register_type({
  id = "common_names",
  defaults_path = "arkitekt/defs/presets/common_names/",
  user_key = "ARKITEKT_PRESETS_COMMON_NAMES",  -- ExtState key
})

-- Get all available lists for a type
local lists = PresetRegistry.get_lists("common_names")
-- Returns: {"game_music", "general_music", "my_sfx_names"}

-- Get resolved preset (default + user derivation merged)
local names = PresetRegistry.get("common_names", "game_music")
-- Returns: {{name="combat", color=...}, {name="calm", color=...}, ...}

-- Get just the user's derivation (for editor)
local derivation = PresetRegistry.get_derivation("common_names", "game_music")

-- Save user derivation
PresetRegistry.save_derivation("common_names", "game_music", {
  additions = {...},
  deletions = {...},
})
```

### 2. Preset Editor Window (`arkitekt/gui/windows/preset_editor.lua`)

Dedicated window using **dual-grid drag-and-drop** interface:

```
┌──────────────────────────────────────────────────────────────────────┐
│ Preset Editor                                                [_][□][×]│
├──────────────────────────────────────────────────────────────────────┤
│ Type: [Common Names ▾]    List: [Game Music (derived) ▾]  [+ New]    │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   DEFAULT (read-only)              YOUR LIST                         │
│  ┌─────────────────────┐          ┌─────────────────────┐           │
│  │ ┌───────┐ ┌───────┐ │          │ ┌───────┐ ┌───────┐ │           │
│  │ │combat │ │ boss  │ │  drag →  │ │combat │ │ calm  │ │           │
│  │ └───────┘ └───────┘ │  ← drag  │ └───────┘ └───────┘ │           │
│  │ ┌───────┐ ┌───────┐ │          │ ┌───────┐ ┌───────┐ │           │
│  │ │ calm  │ │explore│ │          │ │tension│ │stealth│ │  (added)  │
│  │ └───────┘ └───────┘ │          │ └───────┘ └───────┘ │           │
│  │ ┌───────┐ ┌───────┐ │          │ ┌───────┐           │           │
│  │ │tension│ │victory│ │          │ │ chase │  [+ Add]  │  (added)  │
│  │ └───────┘ └───────┘ │          │ └───────┘           │           │
│  └─────────────────────┘          └─────────────────────┘           │
│                                                                      │
│  [Select All] [Clear]              [Reset to Default] [Save]         │
└──────────────────────────────────────────────────────────────────────┘
```

**Core interaction**: Drag chips between grids using existing GridBridge system.

**Left grid (Defaults)**:
- Read-only display of framework defaults
- Drag FROM here to add to your list
- Grayed out items = already in your list

**Right grid (Your List)**:
- Your current derivation (defaults you kept + your additions)
- Drag TO here from defaults
- Drag OUT to remove
- Reorder by dragging within
- [+ Add] for custom items not in defaults

**Features**:
- Type selector: Common Names, Wildcards, Tags, etc.
- List selector: Game Music, General Music, custom lists
- "New List" creates empty custom list (not derived)
- "Reset to Default" clears all derivations
- Visual distinction: default items vs user-added items
- Color picker on right-click for custom items

### 3. Persistence (`arkitekt/core/preset_persistence.lua`)

Uses REAPER ExtState for persistence:

```lua
-- ExtState keys (per preset type)
-- ARKITEKT_PRESETS_COMMON_NAMES = JSON blob of all user data

local Persistence = require('arkitekt.core.preset_persistence')

-- Load all user data for a type
local user_data = Persistence.load("common_names")

-- Save all user data for a type
Persistence.save("common_names", user_data)
```

### 4. Preset-Aware Dropdown (`arkitekt/gui/widgets/forms/preset_combo.lua`)

Drop-in replacement for combo that auto-populates from registry:

```lua
local PresetCombo = require('arkitekt.gui.widgets.forms.preset_combo')

-- Automatically shows all available lists
local result = PresetCombo.draw(ctx, {
  id = "names_category",
  preset_type = "common_names",
  current_value = self.selected_list,
  on_change = function(list_id) ... end,
})
-- Dropdown shows: "Game Music", "General Music", "My SFX Names"
```

---

## Default Presets to Ship

### Common Names (`arkitekt/defs/presets/common_names/`)

**game_music.lua** (current batch_rename_modal content):
- Combat, battle, boss, action (intense_red)
- Calm, peaceful, ambience, explore (calm_green)
- Tension, suspense, stealth (tension_yellow)
- Victory, defeat, theme (victory_gold)
- Intro, outro, loop (structure_gray)
- Stinger, break, transition (special_purple)

**general_music.lua**:
- Intro, verse, chorus, bridge, outro (structure_gray)
- Build, drop, breakdown (tension_yellow)
- Ambient, pad, texture (calm_green)

### Wildcards (`arkitekt/defs/presets/wildcards/`)

**standard.lua**:
- `$n` - Number (sequential)
- `$l` - Length (duration)
- `$d` - Date
- `$t` - Time
- `$p` - Project name
- `$r` - Region name (original)

---

## Migration Path

### Phase 1: Extract Current Hardcoded Data
- [ ] Move `batch_rename_modal.lua` common names to `defs/presets/common_names/`
- [ ] Move wildcards to `defs/presets/wildcards/`
- [ ] Keep batch_rename_modal working (reads from new location)

### Phase 2: Add Registry + Persistence
- [ ] Create `preset_registry.lua`
- [ ] Create `preset_persistence.lua`
- [ ] Update batch_rename_modal to use registry
- [ ] User can now customize via code (no UI yet)

### Phase 3: Editor Window
- [ ] Create `preset_editor.lua` window
- [ ] Hook into main app menu or toolbar
- [ ] Full CRUD for derivations and custom lists

### Phase 4: Auto-Population
- [ ] Create `preset_combo.lua` widget
- [ ] Any script can use presets with one line
- [ ] New scripts get user's presets for free

---

## Reference: Current Chip Palette Design

The batch_rename_modal.lua (983 lines) has the superior chip design to preserve:

### Semantic Color-Coding

```lua
local COLORS = {
  intense_red = hexrgb("#B85C5C"),      -- Combat, battle, boss, action
  tension_yellow = hexrgb("#B8A55C"),   -- Tension, suspense
  calm_green = hexrgb("#6B9B7C"),       -- Calm, peaceful, ambience, explore
  structure_gray = hexrgb("#8B8B8B"),   -- Intro, outro, verse, chorus
  special_purple = hexrgb("#9B7CB8"),   -- Break, stinger, loop
  victory_gold = hexrgb("#B89B5C"),     -- Victory, theme
}
```

### Action Chips with Modifiers

- **Normal click**: Insert with separator (underscore)
- **SHIFT+click**: Insert without separator
- **SHIFT+CTRL+click**: Capitalize first letter

### Flow Layout

Chips wrap automatically when container width exceeded.

### Category Selector

Dropdown switches between preset lists (Game Music, General Music, user lists).

---

## Extraction: Action Chip Palette Widget

Separate from preset management, extract the chip UI:

**Target**: `arkitekt/gui/widgets/data/action_chip_palette.lua`

```lua
local ActionChipPalette = require('arkitekt.gui.widgets.data.action_chip_palette')

local result = ActionChipPalette.draw(ctx, {
  id = "rename_chips",
  items = preset_items,  -- From PresetRegistry.get()
  width = 300,
  height = 120,
  on_chip_click = function(name, modifiers)
    -- modifiers = {shift = bool, ctrl = bool}
    return processed_text
  end,
})

if result.clicked_chip then
  pattern = pattern .. result.text
end
```

---

## Priority

**Medium-High** - The preset system enables consistent UX across all scripts and gives users control over their workflow vocabulary. But batch_rename_modal already works, so this is enhancement not urgent fix.

---

*Created: 2025-11-27*
*Updated: 2025-11-27 - Expanded to framework-wide preset management system*
