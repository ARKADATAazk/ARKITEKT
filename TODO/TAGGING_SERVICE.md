# Framework Tagging Service TODO

> Design a unified tagging/action-chip service based on the superior `batch_rename_modal.lua` design.

---

## Reference Implementation

**Location**: `arkitekt/gui/widgets/overlays/batch_rename_modal.lua` (983 lines)

### Key Design Patterns

#### 1. Semantic Color-Coding

Chips are color-coded by meaning, not decoration:

```lua
local COLORS = {
  intense_red = hexrgb("#B85C5C"),      -- Combat, battle, boss, action
  tension_yellow = hexrgb("#B8A55C"),   -- Tension, suspense
  calm_green = hexrgb("#6B9B7C"),       -- Calm, peaceful, ambience, explore
  structure_gray = hexrgb("#8B8B8B"),   -- Intro, outro, verse, chorus
  special_purple = hexrgb("#9B7CB8"),   -- Break, stinger, loop
  victory_gold = hexrgb("#B89B5C"),     -- Victory, theme
  ...
}
```

#### 2. Action-Oriented Chips (Click to Build)

```lua
local clicked = Chip.draw(ctx, {
  label = name,
  style = Chip.STYLE.ACTION,
  interactive = true,
  bg_color = color,  -- Semantic color
  text_color = tag_config.text_color,
})

if clicked then
  -- Insert into pattern
  self.pattern = self.pattern .. sep .. name_text
end
```

#### 3. Modifier Key Support

- **Normal click**: Insert with separator (underscore)
- **SHIFT+click**: Insert without separator
- **SHIFT+CTRL+click**: Capitalize first letter

```lua
local is_shift = ImGui.IsKeyDown(ctx, ImGui.Key_LeftShift)
local is_ctrl = ImGui.IsKeyDown(ctx, ImGui.Key_LeftCtrl)

if is_shift and is_ctrl then
  name_text = name:sub(1, 1):upper() .. name:sub(2)
end

if is_shift then
  self.pattern = self.pattern .. name_text  -- No separator
else
  self.pattern = self.pattern .. "_" .. name_text  -- With separator
end
```

#### 4. Context Menu on Wildcards

Right-click wildcards for options (padding, start index, case):

```lua
if ImGui.IsItemHovered(ctx) and ImGui.IsMouseClicked(ctx, 1) then
  ImGui.OpenPopup(ctx, "wildcard_context_" .. chip_data.type)
end

if ContextMenu.begin(ctx, "wildcard_context_number") then
  ContextMenu.checkbox_item(ctx, "Start from 0", self.start_index == 0)
  ContextMenu.checkbox_item(ctx, "Padding: 01", self.padding == 2)
  ...
end
```

#### 5. Category Selector

Chips organized into categories with dropdown:

```lua
local result = Combo.draw(ctx, {
  id = "names_category",
  options = {
    {value = "game", label = "Game Music"},
    {value = "general", label = "General Music"},
  },
  current_value = self.names_category,
  on_change = function(value)
    self.names_category = value
  end,
})

local common_names = self.names_category == "game" and game_music_names or general_music_names
```

#### 6. Automatic Flow Layout

Chips wrap to next line when container width exceeded:

```lua
if cur_line_x + chip_spacing + chip_width > right_col_width then
  cur_line_x = 0
  cur_line_y = cur_line_y + line_height
end

ImGui.SetCursorPos(ctx, cur_line_x, cur_line_y)
Chip.draw(ctx, {...})
cur_line_x = cur_line_x + chip_width
```

---

## Extraction Plan

### Target Module: `arkitekt/gui/widgets/data/action_chip_palette.lua`

A reusable "chip palette" widget that:
1. Renders a collection of action chips with automatic wrapping
2. Supports semantic color-coding by category
3. Handles click/modifier interactions
4. Optional context menus on chips
5. Category selector (dropdown or tabs)

### API Design (Draft)

```lua
local ActionChipPalette = require('arkitekt.gui.widgets.data.action_chip_palette')

-- Define chip categories with semantic colors
local CATEGORIES = {
  game = {
    {name = "combat", color = COLORS.intense_red},
    {name = "calm", color = COLORS.calm_green},
    ...
  },
  general = {
    {name = "intro", color = COLORS.structure_gray},
    {name = "verse", color = COLORS.structure_gray},
    ...
  },
}

-- Draw palette
local result = ActionChipPalette.draw(ctx, {
  id = "rename_chips",
  categories = CATEGORIES,
  current_category = "game",
  width = 300,
  height = 120,
  on_category_change = function(cat) ... end,
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

## Components to Extract

| Component | From | Target |
|-----------|------|--------|
| Semantic color palette | `batch_rename_modal.lua:481-495` | `defs/semantic_colors.lua` |
| Category chip definitions | `batch_rename_modal.lua:497-544` | Per-app `defs/` or shared |
| Flow layout logic | `batch_rename_modal.lua:555-627` | `action_chip_palette.lua` |
| Modifier key handling | `batch_rename_modal.lua:599-623` | `action_chip_palette.lua` |
| Wildcard context menu | `batch_rename_modal.lua:380-441` | Separate or inline |

---

## Comparison: TemplateBrowser Tags vs BatchRename Chips

| Feature | TemplateBrowser `tags/service.lua` | BatchRename Chips |
|---------|-----------------------------------|-------------------|
| Purpose | CRUD operations on tags | Action chips for building patterns |
| Interaction | Assign/remove from items | Click to insert text |
| Color | User-assigned per tag | Semantic by category |
| Modifiers | None | Shift, Ctrl combos |
| Context menu | None | Right-click options |
| Categories | None | Game Music / General Music |
| Flow layout | None (list) | Automatic wrapping |

**Conclusion**: BatchRename chips are more sophisticated for UI interaction. TemplateBrowser tags are for data management. Both serve different purposes but could share:
- Chip widget (`gui/widgets/data/chip.lua`) ✅ Already shared
- Semantic color palette (extract from batch rename)
- Flow layout logic (extract from batch rename)

---

## Priority

**Medium** - The batch rename modal already works. Extraction benefits future scripts needing similar chip palettes (e.g., RegionPlaylist tags, ItemPicker region tags).

---

*Created: 2025-11-27*
