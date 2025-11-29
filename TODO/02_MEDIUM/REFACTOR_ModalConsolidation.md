# Modal Dialog Consolidation

> Framework has `modal_dialog.lua` with message/confirm/input dialogs, but scripts ignore it and roll their own.

---

## Current State: 3000+ Lines Across 6 Implementations

| Modal | Location | Lines | Used By |
|-------|----------|-------|---------|
| **modal_dialog.lua** | `arkitekt/gui/widgets/overlays/overlay/` | 366 | **NOBODY** |
| **batch_rename_modal** | `arkitekt/gui/widgets/overlays/` | 982 | RegionPlaylist |
| **package_modal** | `ThemeAdjuster/ui/views/` | 1036 | ThemeAdjuster |
| **template_modals_view** | `TemplateBrowser/ui/views/` | 486 | TemplateBrowser |
| **param_link_modal** | `ThemeAdjuster/ui/views/` | 244 | ThemeAdjuster |
| **overflow_modal_view** | `RegionPlaylist/ui/views/` | 212 | RegionPlaylist |

**Total**: ~3,326 lines

---

## Framework Modal System (UNUSED)

**`arkitekt/gui/widgets/overlays/overlay/modal_dialog.lua`** (366 lines)

Already provides:
```lua
local ModalDialog = require('arkitekt.gui.widgets.overlays.overlay.modal_dialog')

-- Simple message (OK button)
ModalDialog.show_message(ctx, window, "Title", "Message text", {
  on_close = function() end
})

-- Confirmation (OK/Cancel)
ModalDialog.show_confirm(ctx, window, "Title", "Are you sure?", {
  on_confirm = function() end,
  on_cancel = function() end,
  confirm_label = "Delete",  -- Custom button text
  cancel_label = "Keep",
})

-- Text input
ModalDialog.show_input(ctx, window, "Rename", initial_text, {
  placeholder = "Enter name...",
  on_confirm = function(text) end,
  on_cancel = function() end,
})
```

**Features**:
- Uses Sheet + overlay system (proper layering)
- ESC to close
- Scrim click to close (except input - might lose data)
- Auto-focus input field
- Themed styling via `Theme.build_search_input_config()`
- Configurable width/height

**Why unused?** Scripts predate it, or developers didn't know it existed.

---

## Script Modal Breakdown

### 1. batch_rename_modal.lua (982 lines)

**Purpose**: Batch rename regions/playlists with wildcards and color picker.

| Section | Lines | Description |
|---------|-------|-------------|
| **Preference persistence** | 33-90 | 6 ExtState pairs (separator, start_index, padding, letter_case, names_category) |
| **Wildcard processing** | 93-135 | `$n` (number), `$l` (letter) expansion |
| **Preview generation** | 124-135 | Shows how items will be renamed |
| **Common names data** | ~200 | Hardcoded game/general name presets |
| **Color picker embed** | ~100 | Full ColorPickerWindow integration |
| **Radio button options** | ~150 | Separator style, padding, case |
| **Chip display** | ~100 | Click-to-use preset names |
| **Dual render mode** | 817-920 | Container.render OR BeginPopupModal |

**Extractable**:
- [ ] Preference persistence → use `arkitekt/core/settings.lua`
- [ ] Common names → `arkitekt/defs/common_names.lua` or tagging service
- [ ] Color picker popup → reusable component

**NOT extractable** (domain-specific):
- Wildcard pattern logic
- Preview generation

---

### 2. package_modal.lua (1036 lines) - ThemeAdjuster

**Purpose**: Manage theme package assets (include/exclude/pin).

| Section | Lines | Description |
|---------|-------|-------------|
| **Image cache** | 43-49 | Uses `arkitekt.platform.images` |
| **DPI detection** | 52-77 | Check for 150%/200% variants |
| **Area colors** | 26-41 | TCP, MCP, Transport color mapping |
| **Asset tile** | 349-429 | Custom tile with context menu |
| **Grid view** | 531-690 | Scrollable asset grid |
| **Stats computation** | 187-219 | Per-area/status counts |
| **Grouped display** | 308-348 | Group by TCP, MCP, etc. |
| **Status filter** | 826-843 | Filter popup |

**Assessment**: This is a complex data editor, not a dialog. Not extractable to generic modal.

---

### 3. template_modals_view.lua (486 lines) - TemplateBrowser

**Actually 5 separate modals**:

| Modal | Lines | Pattern | Extractable? |
|-------|-------|---------|--------------|
| `draw_template_context_menu` | 21-143 | Color picker popup | YES → generic color picker popup |
| `draw_template_rename_modal` | 148-239 | BeginPopupModal + InputText | YES → use modal_dialog.show_input |
| `draw_tag_context_menu` | 244-319 | Color picker popup | YES → same as above |
| `draw_vst_context_menu` | 324-406 | Color picker popup | YES → same as above |
| `draw_conflict_resolution_modal` | 411-482 | 3-button choice | PARTIAL → needs custom buttons |

**Color picker popup duplicated 3x** in this file alone!

**Extractable**:
- [ ] Color picker popup → `ModalDialog.show_color_picker()`
- [ ] Rename modal → use `ModalDialog.show_input()`
- [ ] Conflict resolution → needs new `ModalDialog.show_choice()` with N buttons

---

### 4. param_link_modal.lua (244 lines) - ThemeAdjuster

**Purpose**: Select compatible parameter to link.

| Section | Lines | Description |
|---------|-------|-------------|
| **Type compatibility** | 47-80 | Filter by param type |
| **Search filter** | ~50 | Filter by name |
| **ChipList display** | ~100 | Scrollable param list |
| **Link creation** | ~50 | On select callback |

**Pattern**: Uses raw `ImGui.BeginPopupModal`.

**Extractable**:
- [ ] List picker pattern → `ModalDialog.show_list_picker(items, {search, on_select})`

---

### 5. overflow_modal_view.lua (212 lines) - RegionPlaylist

**Purpose**: Tab picker when tabs overflow.

| Section | Lines | Description |
|---------|-------|-------------|
| **Tab list with counts** | 50-66 | Shows R/P counts |
| **Search input** | 89-92 | Filter tabs |
| **ChipList rendering** | 96-120 | Scrollable chip grid |
| **Dual mode** | 72-156 | Overlay OR popup fallback |

**Pattern**: Implements same dual-mode as batch_rename (Container.render + BeginPopupModal fallback).

**Extractable**:
- [ ] Dual-mode pattern → built into modal_dialog.lua
- [ ] Search + list → `ModalDialog.show_list_picker()`

---

## Common Patterns Identified

### Pattern 1: Dual Render Mode
Both batch_rename and overflow_modal implement:
```lua
if window and window.overlay then
  -- Use Container.render with overlay
else
  -- Fallback to BeginPopupModal
end
```
**Should be**: Built into modal_dialog.lua base

### Pattern 2: Color Picker Popup
Duplicated 4x (3 in template_modals + 1 in batch_rename):
```lua
if ImGui.BeginPopup(ctx, "color_picker") then
  -- 4x4 color grid
  for idx, color in ipairs(PRESET_COLORS) do
    -- Draw chip, handle click
  end
  ImGui.EndPopup(ctx)
end
```
**Should be**: `ModalDialog.show_color_picker(ctx, window, current_color, opts)`

### Pattern 3: List Picker with Search
Found in param_link_modal and overflow_modal:
```lua
-- Search input
local changed, text = ImGui.InputTextWithHint(ctx, "##search", "Search...", search_text)
-- Filtered list
for _, item in ipairs(filtered_items) do
  if ImGui.Selectable(ctx, item.label) then
    on_select(item)
  end
end
```
**Should be**: `ModalDialog.show_list_picker(ctx, window, items, opts)`

### Pattern 4: Inline ExtState Persistence
batch_rename_modal has 57 lines of:
```lua
local function load_X_preference()
  local value = reaper.GetExtState(SECTION, KEY)
  return value == "..." and ... or default
end

local function save_X_preference(value)
  reaper.SetExtState(SECTION, KEY, tostring(value), true)
end
```
**Should be**: Use `arkitekt/core/settings.lua` with ExtState backend

---

## Proposed Additions to modal_dialog.lua

### 1. Color Picker Popup
```lua
ModalDialog.show_color_picker(ctx, window, current_color, {
  colors = PRESET_COLORS,  -- Optional custom palette
  on_select = function(color) end,
  on_cancel = function() end,
})
```

### 2. List Picker with Search
```lua
ModalDialog.show_list_picker(ctx, window, items, {
  title = "Select Item",
  search_placeholder = "Search...",
  render_item = function(ctx, item) end,  -- Optional custom rendering
  on_select = function(item) end,
  on_cancel = function() end,
})
```

### 3. Choice Dialog (N buttons)
```lua
ModalDialog.show_choice(ctx, window, "File Conflict", "File already exists.", {
  choices = {
    {label = "Replace", action = function() end},
    {label = "Keep Both", action = function() end},
    {label = "Skip", action = function() end, default = true},
  },
  on_cancel = function() end,
})
```

---

## Migration Plan

### Phase 1: Promote Existing (Low Effort)
- [ ] Document `modal_dialog.lua` in cookbook
- [ ] Add examples to `demos/`
- [ ] Migrate `template_modals_view.draw_template_rename_modal` → `show_input()`

### Phase 2: Add Missing Dialogs (Medium Effort)
- [ ] Add `show_color_picker()` to modal_dialog.lua
- [ ] Add `show_list_picker()` to modal_dialog.lua
- [ ] Add `show_choice()` to modal_dialog.lua

### Phase 3: Migrate Scripts (High Effort)
- [ ] Migrate template_modals color pickers (3 places)
- [ ] Migrate batch_rename color picker
- [ ] Migrate param_link_modal → show_list_picker
- [ ] Migrate overflow_modal → show_list_picker
- [ ] Migrate batch_rename preferences → Settings module

### Phase 4: Complex Modals (Optional)
- [ ] batch_rename_modal - Keep as-is (too complex/specialized)
- [ ] package_modal - Keep as-is (data editor, not dialog)

---

## Line Count Impact

| Phase | Lines Removed | Lines Added | Net |
|-------|--------------|-------------|-----|
| Phase 1 | ~90 (rename modal) | ~5 | -85 |
| Phase 2 | 0 | ~200 | +200 |
| Phase 3 | ~400 (color pickers, list pickers) | ~50 | -350 |
| **Total** | ~490 | ~255 | **-235** |

Plus: Consistency, single source of truth, easier maintenance.

---

## Files to Modify

### Framework
- `arkitekt/gui/widgets/overlays/overlay/modal_dialog.lua` - Add new dialog types
- `cookbook/MODAL_DIALOGS.md` - Documentation (create)

### Scripts
- `TemplateBrowser/ui/views/template_modals_view.lua` - Migrate to framework
- `ThemeAdjuster/ui/views/param_link_modal.lua` - Migrate to framework
- `RegionPlaylist/ui/views/overflow_modal_view.lua` - Migrate to framework
- `arkitekt/gui/widgets/overlays/batch_rename_modal.lua` - Migrate preferences only

---

*Created: 2025-11-27*
