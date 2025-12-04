# Widget Development Guide

How to create and extend ARKITEKT widgets.

---

## Widget Categories

| Category | Path | Purpose |
|----------|------|---------|
| Primitives | `arkitekt/gui/widgets/primitives/` | Atomic UI elements (button, checkbox, slider) |
| Containers | `arkitekt/gui/widgets/containers/` | Layout and grouping (panel, grid, scroll) |
| Composites | `arkitekt/gui/widgets/composites/` | Multi-primitive combinations |
| Overlays | `arkitekt/gui/widgets/overlays/` | Full-screen modal overlays |
| Media | `arkitekt/gui/widgets/media/` | Media-specific (waveform, grid) |

---

## Widget API Contract

### Callable Module Pattern (Preferred)

Widgets are **callable modules** - users call them directly without `.Draw`:

```lua
-- User API (no .Draw!)
local r = Ark.Button(ctx, 'Save')
local r = Ark.Button(ctx, { label = 'Save', preset = 'success' })

-- NOT: Ark.Button.Draw(ctx, ...)  -- Wrong!
```

### Internal Signature
```lua
function M.Draw(ctx, opts)
  -- ctx: ImGui context (userdata)
  -- opts: Configuration table (optional fields)
  return result  -- State table for caller
end

-- Make module callable via __call metamethod
return setmetatable(M, {
  __call = function(_, ctx, label_or_opts, ...)
    -- Detect positional vs opts mode
    if type(label_or_opts) == 'table' then
      return M.Draw(ctx, label_or_opts)
    else
      return M.Draw(ctx, { label = label_or_opts, ... })
    end
  end
})
```

### opts Table Convention
```lua
---@class WidgetOptions
---@field id? string           Unique identifier (auto-generated if nil)
---@field x? number            X position (nil = cursor position)
---@field y? number            Y position (nil = cursor position)
---@field width? number        Widget width
---@field height? number       Widget height
---@field is_disabled? boolean Disable interactions
---@field preset_name? string  Style preset name
```

### Boolean Property Naming (is_ prefix)
All boolean config properties use the `is_` prefix for clarity and autocomplete:
- `is_disabled` - Widget cannot be interacted with
- `is_checked` - Checkbox checked state
- `is_selected` - Item selection state
- `is_toggled` - Toggle button state
- `is_blocking` - Block interaction without visual change
- `is_multiline` - InputText multiline mode
- `is_interactive` - Chip/item can be clicked

### Result Table Convention
```lua
---@class WidgetResult
---@field hovered boolean      Mouse is over widget
---@field active boolean       Widget is being interacted with
---@field width number         Actual rendered width
---@field height number        Actual rendered height
```

---

## Minimal Widget Template

```lua
-- @noindex
-- arkitekt/gui/widgets/primitives/my_widget.lua

local Theme = require('arkitekt.theme')
local Base = require('arkitekt.gui.widgets.base')

local M = {}

---@param ctx userdata
---@param opts table
---@return table
function M.Draw(ctx, opts)
  opts = opts or {}
  local ImGui = reaper.ImGui

  -- Generate unique ID
  local id = opts.id or ("mywidget_" .. tostring(opts):match("0x(%x+)"))

  -- Get/create state
  local state = Base.get_state(id) or { value = opts.value or 0 }

  -- Resolve config from theme (read every frame!)
  local config = {
    bg_color = Theme.COLORS.BG_BASE,
    text_color = Theme.COLORS.TEXT_NORMAL,
    width = opts.width or 100,
  }

  -- Get cursor position
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w, h = config.width, 20

  -- Draw (use Base helper for cached draw list)
  local dl = Base.get_draw_list(ctx, opts)
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, config.bg_color)

  -- Handle input
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, id, w, h)
  local hovered = ImGui.IsItemHovered(ctx)
  local active = ImGui.IsItemActive(ctx)

  -- Update state
  local changed = false
  if active then
    state.value = state.value + 1
    changed = true
  end

  -- Save state
  Base.set_state(id, state)

  -- Advance cursor
  ImGui.SetCursorScreenPos(ctx, x, y + h)

  return {
    value = state.value,
    changed = changed,
    hovered = hovered,
  }
end

-- Make module callable: Ark.MyWidget(ctx, opts) -> M.Draw(ctx, opts)
return setmetatable(M, {
  __call = function(_, ctx, opts)
    return M.Draw(ctx, opts)
  end
})
```

---

## Config Resolution Pattern

### Dynamic Config (Theme-Reactive)

**Critical**: Read `Theme.COLORS` during render, not at module load.

```lua
local Theme = require('arkitekt.theme')

local function resolve_config(opts)
  -- Base config from theme (fresh every frame)
  local config = {
    bg_color = Theme.COLORS.BG_BASE,
    bg_hover_color = Theme.COLORS.BG_HOVER,
    text_color = Theme.COLORS.TEXT_NORMAL,
    rounding = 0,
    padding_x = 10,
    padding_y = 6,
  }

  -- Apply preset if specified
  if opts.preset_name then
    local preset = Theme.build_button_config()  -- or appropriate builder
    for k, v in pairs(preset) do
      config[k] = v
    end
  end

  -- User overrides (highest priority)
  for k, v in pairs(opts) do
    if config[k] ~= nil and v ~= nil then
      config[k] = v
    end
  end

  return config
end
```

---

## State Management

### Using Base.state_store
```lua
local Base = require('arkitekt.gui.widgets.base')

function M.draw(ctx, opts)
  local id = opts.id or generate_id()

  -- Get existing state or create new
  local state = Base.get_state(id) or {
    expanded = false,
    scroll_y = 0,
  }

  -- Modify state
  if clicked then
    state.expanded = not state.expanded
  end

  -- Save state
  Base.set_state(id, state)
end
```

---

## Drawing Patterns

### DrawList Usage

Use `Base.get_draw_list()` for automatic caching via ArkContext:

```lua
local Base = require('arkitekt.gui.widgets.base')

function M.Draw(ctx, opts)
  local dl = Base.get_draw_list(ctx, opts)  -- Cached per-frame

  -- Rectangles
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, color, rounding)
  ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, color, rounding, flags, thickness)

  -- Text
  ImGui.DrawList_AddText(dl, x, y, color, text)

  -- Lines
  ImGui.DrawList_AddLine(dl, x1, y1, x2, y2, color, thickness)
end
```

For advanced caching (expensive computations), see `cookbook/ARKCONTEXT.md`.

### Cursor Management
```lua
-- Save position
local x, y = ImGui.GetCursorScreenPos(ctx)

-- Draw widget...

-- Advance cursor after drawing
ImGui.SetCursorScreenPos(ctx, x, y + height)
```

---

## Input Handling

### InvisibleButton Pattern
```lua
ImGui.SetCursorScreenPos(ctx, x, y)
ImGui.InvisibleButton(ctx, id, width, height)

local hovered = ImGui.IsItemHovered(ctx)
local active = ImGui.IsItemActive(ctx)
local clicked = ImGui.IsItemClicked(ctx)
local right_clicked = ImGui.IsItemClicked(ctx, 1)
```

### Mouse Position
```lua
-- Via ArkContext (cached per-frame)
local actx = Base.get_context(ctx)
local mx, my = actx:mouse_pos()
local rel_x = mx - x  -- Relative to widget
local rel_y = my - y

-- Or direct ImGui call (not cached)
local mx, my = ImGui.GetMousePos(ctx)
```

### Keyboard Input
```lua
if ImGui.IsItemFocused(ctx) then
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
    -- Handle enter
  end
end
```

---

## Common Theme Colors

```lua
Theme.COLORS.BG_BASE           -- Control background
Theme.COLORS.BG_HOVER          -- Hovered background
Theme.COLORS.BG_ACTIVE         -- Active/pressed background
Theme.COLORS.BG_PANEL          -- Panel/container background
Theme.COLORS.BORDER_OUTER      -- Dark outer border
Theme.COLORS.BORDER_INNER      -- Light inner highlight
Theme.COLORS.TEXT_NORMAL       -- Standard text
Theme.COLORS.TEXT_HOVER        -- Bright hover text
Theme.COLORS.TEXT_DIMMED       -- Secondary/disabled text
Theme.COLORS.ACCENT_PRIMARY    -- Primary accent color
```

---

## Common Mistakes

| Mistake | Problem | Solution |
|---------|---------|----------|
| Hardcoded colors | Won't respond to theme | Use `Theme.COLORS.*` |
| Colors cached at load | Stale after theme switch | Read `Theme.COLORS` every frame |
| Forgetting cursor advance | Next widget overlaps | Call `SetCursorScreenPos` after drawing |
| Generic ID | State collisions | Generate unique ID per instance |
| State in module scope | Shared across instances | Use `Base.get_state(id)` |

### Examples

```lua
-- BAD: Hardcoded color
local bg = 0x252525FF

-- GOOD: Theme-reactive
local bg = Theme.COLORS.BG_BASE

-- BAD: Cached at module load
local BG_COLOR = Theme.COLORS.BG_BASE  -- Stale!

-- GOOD: Read in draw function
function M.draw(ctx, opts)
  local bg = Theme.COLORS.BG_BASE  -- Fresh every frame
end

-- BAD: Generic ID causes state collision
local state = Base.get_state("button")

-- GOOD: Unique per-instance ID
local id = opts.id or ("button_" .. tostring(opts):match("0x(%x+)"))
local state = Base.get_state(id)
```

---

## Testing Checklist

- [ ] Renders correctly at default size
- [ ] Responds to hover/active states
- [ ] Works with theme changes (dark/light)
- [ ] Handles disabled state
- [ ] Works with custom colors via opts
- [ ] No visual glitches at edges
- [ ] Proper cursor advancement
- [ ] Unique ID per instance
