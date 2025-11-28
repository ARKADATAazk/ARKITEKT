# Flags to Opts Mapping

> **How ImGui's bitwise flags translate to ARKITEKT's opts tables**

---

## Overview

ImGui uses **bitwise flags** combined with the `|` operator:

```lua
-- ImGui: Flags as final parameter, combined with bitwise OR
ImGui.InputText(ctx, 'pw', text, ImGui.InputTextFlags_Password | ImGui.InputTextFlags_ReadOnly)
ImGui.SliderDouble(ctx, 'x', val, 0, 10, '%.3f', ImGui.SliderFlags_Logarithmic)
ImGui.TreeNode(ctx, 'Node', ImGui.TreeNodeFlags_OpenOnArrow | ImGui.TreeNodeFlags_SpanAvailWidth)
```

ARKITEKT converts these to **boolean opts fields**:

```lua
-- ARKITEKT: Flags become boolean opts (no bitwise operations needed)
Ark.InputText(ctx, { label = "pw", text = text, password = true, readonly = true })
Ark.Slider(ctx, { label = "x", value = val, min = 0, max = 10, logarithmic = true })
Ark.TreeNode(ctx, { label = "Node", open_on_arrow = true, span_width = true })
```

**Benefits:**
- No memorizing flag constants
- Self-documenting code
- IDE autocomplete for opts fields
- No bitwise operator confusion

---

## SliderFlags

Used by: `Ark.Slider`, `Ark.DragValue`

| ImGui Flag | ARKITEKT Opt | Type | Description |
|------------|--------------|------|-------------|
| `SliderFlags_AlwaysClamp` | `clamp` | boolean | Clamp value to min/max bounds |
| `SliderFlags_ClampOnInput` | `clamp_input` | boolean | Clamp when Ctrl+Click manual input |
| `SliderFlags_Logarithmic` | `logarithmic` | boolean | Logarithmic scale (more precision for small values) |
| `SliderFlags_NoRoundToFormat` | `no_round` | boolean | Don't round to format precision |
| `SliderFlags_NoInput` | `no_input` | boolean | Disable Ctrl+Click text input |
| `SliderFlags_WrapAround` | `wrap` | boolean | Wrap from max→min (Drag only) |

### Example

```lua
-- ImGui
rv, val = ImGui.SliderDouble(ctx, 'Volume', val, 0.001, 1.0, '%.3f',
    ImGui.SliderFlags_Logarithmic | ImGui.SliderFlags_AlwaysClamp)

-- ARKITEKT
local r = Ark.Slider(ctx, {
  label = "Volume",
  value = val,
  min = 0.001,
  max = 1.0,
  format = "%.3f",
  logarithmic = true,
  clamp = true,
})
if r.changed then val = r.value end
```

---

## InputTextFlags

Used by: `Ark.InputText`

| ImGui Flag | ARKITEKT Opt | Type | Description |
|------------|--------------|------|-------------|
| `InputTextFlags_Password` | `password` | boolean | Hide characters as `*` |
| `InputTextFlags_ReadOnly` | `readonly` | boolean | Read-only mode |
| `InputTextFlags_AllowTabInput` | `allow_tab` | boolean | Allow Tab key in text |
| `InputTextFlags_CtrlEnterForNewLine` | `ctrl_enter_newline` | boolean | Ctrl+Enter for newline |
| `InputTextFlags_CharsDecimal` | `chars` | `"decimal"` | Only 0-9, +, -, . |
| `InputTextFlags_CharsHexadecimal` | `chars` | `"hex"` | Only 0-9, A-F |
| `InputTextFlags_CharsUppercase` | `uppercase` | boolean | Force uppercase |
| `InputTextFlags_CharsNoBlank` | `no_blank` | boolean | Filter out spaces |
| `InputTextFlags_NoUndoRedo` | `no_undo` | boolean | Disable undo/redo |
| `InputTextFlags_EscapeClearsAll` | `escape_clears` | boolean | Escape clears text |
| `InputTextFlags_ElideLeft` | `elide_left` | boolean | Elide overflow on left |

### Example

```lua
-- ImGui
rv, text = ImGui.InputText(ctx, 'Search', text,
    ImGui.InputTextFlags_EscapeClearsAll | ImGui.InputTextFlags_CharsNoBlank)

-- ARKITEKT
local r = Ark.InputText(ctx, {
  label = "Search",
  text = text,
  escape_clears = true,
  no_blank = true,
})
if r.changed then text = r.value end
```

---

## TreeNodeFlags

Used by: `Ark.TreeNode`, `Ark.CollapsingHeader`

| ImGui Flag | ARKITEKT Opt | Type | Description |
|------------|--------------|------|-------------|
| `TreeNodeFlags_DefaultOpen` | `default_open` | boolean | Start expanded |
| `TreeNodeFlags_OpenOnArrow` | `open_on_arrow` | boolean | Only open on arrow click |
| `TreeNodeFlags_OpenOnDoubleClick` | `open_on_dblclick` | boolean | Open on double-click |
| `TreeNodeFlags_SpanAvailWidth` | `span_width` | boolean | Extend hit area to available width |
| `TreeNodeFlags_SpanFullWidth` | `span_full_width` | boolean | Extend to full row width |
| `TreeNodeFlags_Framed` | `framed` | boolean | Draw with frame background |
| `TreeNodeFlags_NoTreePushOnOpen` | `no_push` | boolean | Don't push when open (flat tree) |
| `TreeNodeFlags_Leaf` | `leaf` | boolean | No arrow, not expandable |
| `TreeNodeFlags_Bullet` | `bullet` | boolean | Display bullet instead of arrow |
| `TreeNodeFlags_DrawLinesFull` | `lines` | `"full"` | Draw hierarchy lines |
| `TreeNodeFlags_DrawLinesToNodes` | `lines` | `"to_nodes"` | Lines only to nodes |
| `TreeNodeFlags_NavLeftJumpsToParent` | `nav_parent` | boolean | Left nav jumps to parent |

### Example

```lua
-- ImGui
if ImGui.TreeNode(ctx, 'Settings',
    ImGui.TreeNodeFlags_DefaultOpen | ImGui.TreeNodeFlags_SpanAvailWidth) then
  -- content
  ImGui.TreePop(ctx)
end

-- ARKITEKT
local r = Ark.TreeNode(ctx, {
  label = "Settings",
  default_open = true,
  span_width = true,
  draw = function(ctx)
    -- content (auto TreePop)
  end,
})
```

---

## SelectableFlags

Used by: `Ark.Selectable`

| ImGui Flag | ARKITEKT Opt | Type | Description |
|------------|--------------|------|-------------|
| `SelectableFlags_AllowDoubleClick` | `double_click` | boolean | Report on double-click |
| `SelectableFlags_SpanAllColumns` | `span_columns` | boolean | Span all table columns |
| `SelectableFlags_Disabled` | `disabled` | boolean | Disabled appearance |
| `SelectableFlags_Highlight` | `highlight` | boolean | Highlighted appearance |
| `SelectableFlags_AllowOverlap` | `allow_overlap` | boolean | Allow other items over |

### Example

```lua
-- ImGui
if ImGui.Selectable(ctx, 'Item', selected, ImGui.SelectableFlags_AllowDoubleClick) then
  if ImGui.IsMouseDoubleClicked(ctx, 0) then
    open_item()
  else
    select_item()
  end
end

-- ARKITEKT
local r = Ark.Selectable(ctx, {
  label = "Item",
  selected = selected,
  double_click = true,
})
if r.double_clicked then open_item()
elseif r.clicked then select_item() end
```

---

## ComboFlags

Used by: `Ark.Combo`

| ImGui Flag | ARKITEKT Opt | Type | Description |
|------------|--------------|------|-------------|
| `ComboFlags_PopupAlignLeft` | `align_left` | boolean | Align popup left |
| `ComboFlags_HeightSmall` | `height` | `"small"` | Max 4 items |
| `ComboFlags_HeightRegular` | `height` | `"regular"` | Max 8 items (default) |
| `ComboFlags_HeightLarge` | `height` | `"large"` | Max 20 items |
| `ComboFlags_HeightLargest` | `height` | `"largest"` | As large as possible |
| `ComboFlags_NoArrowButton` | `no_arrow` | boolean | No dropdown arrow |
| `ComboFlags_NoPreview` | `no_preview` | boolean | No preview text |

### Example

```lua
-- ImGui
rv, idx = ImGui.Combo(ctx, 'Theme', idx, items,
    ImGui.ComboFlags_HeightLarge | ImGui.ComboFlags_PopupAlignLeft)

-- ARKITEKT
local r = Ark.Combo(ctx, {
  label = "Theme",
  selected = idx,
  items = items,
  height = "large",
  align_left = true,
})
```

---

## TabBarFlags / TabItemFlags

Used by: `Ark.TabBar`, `Ark.TabItem`

### TabBarFlags

| ImGui Flag | ARKITEKT Opt | Type | Description |
|------------|--------------|------|-------------|
| `TabBarFlags_Reorderable` | `reorderable` | boolean | Allow reordering tabs |
| `TabBarFlags_AutoSelectNewTabs` | `auto_select_new` | boolean | Auto-select new tabs |
| `TabBarFlags_TabListPopupButton` | `popup_button` | boolean | Show tab list button |
| `TabBarFlags_NoCloseWithMiddleMouseButton` | `no_middle_close` | boolean | Disable middle-click close |
| `TabBarFlags_FittingPolicyScroll` | `fitting` | `"scroll"` | Scroll overflow tabs |
| `TabBarFlags_FittingPolicyResizeDown` | `fitting` | `"resize"` | Resize tabs to fit |

### TabItemFlags

| ImGui Flag | ARKITEKT Opt | Type | Description |
|------------|--------------|------|-------------|
| `TabItemFlags_SetSelected` | `selected` | boolean | Force selection |
| `TabItemFlags_Leading` | `position` | `"leading"` | Pin to left |
| `TabItemFlags_Trailing` | `position` | `"trailing"` | Pin to right |
| `TabItemFlags_NoCloseButton` | `no_close` | boolean | Hide close button |
| `TabItemFlags_NoTooltip` | `no_tooltip` | boolean | Disable tooltip |

---

## ColorEditFlags

Used by: `Ark.ColorEdit`, `Ark.ColorPicker`

| ImGui Flag | ARKITEKT Opt | Type | Description |
|------------|--------------|------|-------------|
| `ColorEditFlags_NoAlpha` | `no_alpha` | boolean | Hide alpha channel |
| `ColorEditFlags_NoPicker` | `no_picker` | boolean | No color picker popup |
| `ColorEditFlags_NoOptions` | `no_options` | boolean | No right-click options |
| `ColorEditFlags_NoSmallPreview` | `no_preview` | boolean | No small preview square |
| `ColorEditFlags_NoInputs` | `no_inputs` | boolean | No sliders/text inputs |
| `ColorEditFlags_NoTooltip` | `no_tooltip` | boolean | No tooltip on hover |
| `ColorEditFlags_NoLabel` | `no_label` | boolean | No label |
| `ColorEditFlags_NoDragDrop` | `no_drag_drop` | boolean | Disable drag-drop |
| `ColorEditFlags_AlphaBar` | `alpha_bar` | boolean | Show alpha bar in picker |
| `ColorEditFlags_AlphaPreviewHalf` | `alpha_preview` | `"half"` | Checkerboard preview |
| `ColorEditFlags_DisplayRGB` | `display` | `"rgb"` | Force RGB display |
| `ColorEditFlags_DisplayHSV` | `display` | `"hsv"` | Force HSV display |
| `ColorEditFlags_DisplayHex` | `display` | `"hex"` | Force Hex display |
| `ColorEditFlags_PickerHueBar` | `picker` | `"bar"` | Hue bar picker |
| `ColorEditFlags_PickerHueWheel` | `picker` | `"wheel"` | Hue wheel picker |

---

## WindowFlags

Used by: `Ark.Window`, `Ark.ChildWindow`, `Ark.Panel`

| ImGui Flag | ARKITEKT Opt | Type | Description |
|------------|--------------|------|-------------|
| `WindowFlags_NoTitleBar` | `no_title` | boolean | No title bar |
| `WindowFlags_NoResize` | `no_resize` | boolean | Disable resizing |
| `WindowFlags_NoMove` | `no_move` | boolean | Disable moving |
| `WindowFlags_NoScrollbar` | `no_scrollbar` | boolean | Hide scrollbar |
| `WindowFlags_NoScrollWithMouse` | `no_scroll_mouse` | boolean | Disable mouse scroll |
| `WindowFlags_NoCollapse` | `no_collapse` | boolean | Disable collapsing |
| `WindowFlags_AlwaysAutoResize` | `auto_resize` | boolean | Auto-fit to content |
| `WindowFlags_NoBackground` | `no_background` | boolean | Transparent background |
| `WindowFlags_NoSavedSettings` | `no_save` | boolean | Don't persist state |
| `WindowFlags_NoNav` | `no_nav` | boolean | Disable keyboard nav |
| `WindowFlags_MenuBar` | `menu_bar` | boolean | Has menu bar |
| `WindowFlags_HorizontalScrollbar` | `h_scrollbar` | boolean | Show horizontal scrollbar |
| `WindowFlags_NoFocusOnAppearing` | `no_focus` | boolean | Don't take focus on appear |
| `WindowFlags_NoDocking` | `no_docking` | boolean | Disable docking |

---

## TableFlags

Used by: `Ark.Table`, `Ark.Grid`

| ImGui Flag | ARKITEKT Opt | Type | Description |
|------------|--------------|------|-------------|
| `TableFlags_Resizable` | `resizable` | boolean | Columns resizable |
| `TableFlags_Reorderable` | `reorderable` | boolean | Columns reorderable |
| `TableFlags_Hideable` | `hideable` | boolean | Columns hideable |
| `TableFlags_Sortable` | `sortable` | boolean | Enable sorting |
| `TableFlags_RowBg` | `row_bg` | boolean | Alternate row colors |
| `TableFlags_Borders` | `borders` | boolean | All borders |
| `TableFlags_BordersInner` | `borders` | `"inner"` | Inner borders only |
| `TableFlags_BordersOuter` | `borders` | `"outer"` | Outer borders only |
| `TableFlags_SizingStretchSame` | `sizing` | `"stretch"` | Stretch columns equally |
| `TableFlags_SizingFixedFit` | `sizing` | `"fixed"` | Fixed column width |
| `TableFlags_ScrollX` | `scroll_x` | boolean | Horizontal scroll |
| `TableFlags_ScrollY` | `scroll_y` | boolean | Vertical scroll |

---

## Coverage Tiers

Not all flags need opts mappings. We use a tiered approach:

```
┌─────────────────────────────────────────────────────────┐
│  TIER 1: Common Flags → Opts (documented above)         │
│  ───────────────────────────────────────────────────────│
│  password, readonly, logarithmic, clamp, default_open,  │
│  span_width, borders, resizable, etc.                   │
│  ~40 flags that cover 95% of usage                      │
│  → Full IDE autocomplete, type safety                   │
├─────────────────────────────────────────────────────────┤
│  TIER 2: Rare Flags → Passthrough                       │
│  ───────────────────────────────────────────────────────│
│  CallbackCharFilter, CallbackHistory, etc.              │
│  Power users can use: flags = ImGui.X                   │
│  → When requested often, promote to Tier 1              │
├─────────────────────────────────────────────────────────┤
│  TIER 3: Future Flags → Auto-available                  │
│  ───────────────────────────────────────────────────────│
│  New ImGui flags from updates                           │
│  → Work immediately via passthrough                     │
│  → Map to opts based on user demand                     │
└─────────────────────────────────────────────────────────┘
```

### Passthrough Syntax

For rare/advanced flags not yet mapped to opts:

```lua
-- Tier 2: Rare flag via passthrough
Ark.InputText(ctx, {
  label = "Code",
  text = code,
  flags = ImGui.InputTextFlags_CallbackCharFilter,
  callback = filter_fn,
})

-- Combining opts + passthrough (opts take precedence)
Ark.InputText(ctx, {
  label = "Search",
  text = query,
  password = true,  -- Tier 1: mapped opt
  flags = ImGui.InputTextFlags_CallbackCompletion,  -- Tier 2: passthrough
})
```

### Future-Proofing

When ImGui updates add new flags:

1. **Immediately usable** via `flags = ImGui.NewFlag`
2. **No ARKITEKT update required** for basic functionality
3. **Opts mapping added** when flag becomes commonly requested

This means:
- No massive upfront flag database to maintain
- New ImGui features work on day one
- Opts grow organically based on real usage

---

## Migration Cheatsheet

```lua
-- ImGui flags                              →  ARKITEKT opts
ImGui.InputTextFlags_Password               →  password = true
ImGui.InputTextFlags_ReadOnly               →  readonly = true
ImGui.SliderFlags_Logarithmic               →  logarithmic = true
ImGui.SliderFlags_AlwaysClamp               →  clamp = true
ImGui.TreeNodeFlags_DefaultOpen             →  default_open = true
ImGui.TreeNodeFlags_SpanAvailWidth          →  span_width = true
ImGui.SelectableFlags_AllowDoubleClick      →  double_click = true
ImGui.ComboFlags_HeightLarge                →  height = "large"
ImGui.WindowFlags_NoTitleBar                →  no_title = true
ImGui.TableFlags_Borders                    →  borders = true

-- Multiple flags → multiple opts
flags = Flag_A | Flag_B | Flag_C            →  opt_a = true, opt_b = true, opt_c = true
```

---

## Why Opts Over Flags?

| Aspect | ImGui Flags | ARKITEKT Opts |
|--------|-------------|---------------|
| **Discoverability** | Must know constant names | IDE autocomplete |
| **Readability** | `0x0020 \| 0x0080` - what? | `password = true` - clear |
| **Typos** | Silent wrong flag | Error: unknown opt |
| **Defaults** | Must OR with base | Just set what you need |
| **Grouping** | All flags are equal | Related opts grouped |
| **Types** | All integers | bool, string, number |

The translation is mechanical - every flag becomes a boolean opt. Users don't lose power, they gain clarity.

---

## Implementation

### Where It Goes

Each widget module handles its own opts → flags mapping:

```lua
-- arkitekt/gui/widgets/primitives/input_text.lua

local ImGui = require('arkitekt.platform.imgui')

-- Flag mapping table (easy to extend, AI can generate)
local FLAG_MAP = {
  password      = ImGui.InputTextFlags_Password,
  readonly      = ImGui.InputTextFlags_ReadOnly,
  allow_tab     = ImGui.InputTextFlags_AllowTabInput,
  no_undo       = ImGui.InputTextFlags_NoUndoRedo,
  escape_clears = ImGui.InputTextFlags_EscapeClearsAll,
  uppercase     = ImGui.InputTextFlags_CharsUppercase,
  no_blank      = ImGui.InputTextFlags_CharsNoBlank,
}

-- String enum mappings
local CHARS_MAP = {
  decimal = ImGui.InputTextFlags_CharsDecimal,
  hex     = ImGui.InputTextFlags_CharsHexadecimal,
}

function M.draw(ctx, label_or_opts, text, width)
  local opts = parse_opts(label_or_opts, text, width)

  -- Build flags from opts (the conversion)
  local flags = opts.flags or 0  -- Start with passthrough
  for opt, flag in pairs(FLAG_MAP) do
    if opts[opt] then flags = flags | flag end
  end
  if opts.chars then
    flags = flags | (CHARS_MAP[opts.chars] or 0)
  end

  -- Call ImGui
  local changed, new_text = ImGui.InputText(ctx, opts.label, opts.text, flags)

  return { changed = changed, value = new_text, hovered = ImGui.IsItemHovered(ctx) }
end
```

### Pattern Benefits

| Aspect | Benefit |
|--------|---------|
| **FLAG_MAP table** | Easy to read, extend, generate with AI |
| **String enums** | `chars = "hex"` instead of multiple booleans |
| **Passthrough first** | `opts.flags or 0` ensures escape hatch works |
| **Loop over map** | Adding new flags = add one line to table |

### Performance

**The conversion per widget, per frame:**

```lua
for opt, flag in pairs(FLAG_MAP) do    -- ~10 iterations
  if opts[opt] then                     -- table lookup + branch
    flags = flags | flag                -- bitwise OR (1 CPU cycle)
  end
end
```

**Cost analysis:**

| Operation | Time |
|-----------|------|
| Table lookup `opts[opt]` | ~10-20 ns |
| Bitwise OR | ~1 ns |
| 10 flag checks total | ~200 ns |
| ImGui widget render | ~10,000-100,000 ns |

**Verdict: Negligible (<1% of widget cost)**

The opts → flags conversion is noise compared to ImGui's actual rendering, layout calculations, and draw list operations. Not worth optimizing.

### Shared Helpers (Optional)

For consistency across widgets, could extract common logic:

```lua
-- arkitekt/gui/widgets/base/flags.lua

local M = {}

function M.build(opts, flag_map, enum_maps)
  local flags = opts.flags or 0

  -- Boolean opts
  for opt, flag in pairs(flag_map) do
    if opts[opt] then flags = flags | flag end
  end

  -- String enum opts
  for opt, map in pairs(enum_maps or {}) do
    if opts[opt] and map[opts[opt]] then
      flags = flags | map[opts[opt]]
    end
  end

  return flags
end

return M
```

Usage:
```lua
local Flags = require('arkitekt.gui.widgets.base.flags')

local flags = Flags.build(opts, FLAG_MAP, { chars = CHARS_MAP })
```

But per-widget inline is fine too - keeps each widget self-contained.
