# Panel API Rework

> **New API design for Panel based on API Matching decisions**

**Status:** Spec complete, not yet implemented
**Related:** `TODO/PANEL_REFACTOR.md` (legacy refactor plan - partially superseded)

---

## Summary

Panel moves from **declarative config** to **callback-based regions**, consistent with Grid's `render` callback pattern.

**Key changes:**
1. Regions use `draw` callbacks - user calls `Ark.Button` directly
2. Corner buttons become a region - not special config
3. Button auto-adapts to context - Panel injects rounding info
4. CornerButton widget deprecated - Button handles everything

---

## Current vs New API

### Current (Declarative Config)

```lua
local panel = Panel.new("my_panel", {
  header = {
    enabled = true,
    height = 30,
    elements = {
      { id = "title", type = "button", config = { label = "Title" }},
      { id = "search", type = "inputtext", config = { placeholder = "..." }},
    },
  },
  corner_buttons = {
    size = 24,
    inner_rounding = 12,
    bottom_right = {
      icon = "⚙",
      on_click = open_settings,
    },
  },
})

if panel:begin_draw(ctx, x, y, w, h) then
  -- content
  panel:end_draw(ctx)
end
```

**Problems:**
- Duplicate type system (`type = "button"` vs `Ark.Button`)
- Config tunneling (every widget option must go through `config = {}`)
- Panel must know about every widget type
- Inconsistent with Grid's callback pattern

### New (Callback Regions)

```lua
Ark.Panel(ctx, {
  id = "my_panel",

  header = {
    height = 30,
    draw = function(ctx)
      Ark.Button(ctx, { label = "Title" })
      Ark.Spacer(ctx)
      Ark.InputText(ctx, { id = "search", placeholder = "..." })
    end,
  },

  corner = {
    bottom_right = function(ctx)
      Ark.Button(ctx, { icon = "⚙", on_click = open_settings })
    end,
  },

  draw = function(ctx)
    -- Main content
    ImGui.Text(ctx, "Content here")
  end,
})
```

**Benefits:**
- User calls real widgets - no `type = "button"` indirection
- Consistent with Grid's `render = function()` pattern
- Panel handles layout, user handles content
- Full flexibility in callbacks

---

## Region Types

### header / footer

```lua
header = {
  height = 30,           -- Optional, has default
  draw = function(ctx)
    -- Buttons here auto-adapt corners for header position
    Ark.Button(ctx, { label = "First" })   -- Left corners rounded
    Ark.Spacer(ctx)
    Ark.Button(ctx, { label = "Last" })    -- Right corners rounded
  end,
}
```

### sidebar_left / sidebar_right

```lua
sidebar_left = {
  width = 40,            -- Optional, has default
  draw = function(ctx)
    Ark.Button(ctx, { icon = "+" })
    Ark.Button(ctx, { icon = "-" })
  end,
}
```

### corner

```lua
corner = {
  top_left = function(ctx)
    Ark.Button(ctx, { icon = "☰" })  -- Auto corner-shaped
  end,
  bottom_right = function(ctx)
    Ark.Button(ctx, { icon = "⚙" })  -- Auto corner-shaped
  end,
}
```

### draw (main content)

```lua
draw = function(ctx)
  -- Main scrollable content area
  for _, item in ipairs(items) do
    ImGui.Text(ctx, item.name)
  end
end
```

---

## Button Context Injection

Panel injects rendering context for each region. Button reads this and auto-adapts.

### How It Works

```
Panel                              Button
  │                                  │
  ├─ "Rendering corner.bottom_right" │
  │                                  │
  ├─ Sets context:                   │
  │   corner = "br"                  │
  │   outer_rounding = 8             │
  │   inner_rounding = 3             │
  │                                  │
  └─ Calls draw callback ───────────►│
                                     │
     Ark.Button(ctx, {icon="⚙"}) ───►│
                                     │
                                     ├─ Reads context
                                     ├─ Detects corner mode
                                     ├─ Uses asymmetric rounding
                                     └─ Renders corner-shaped button
```

### Context Fields

| Field | Set By | Used By | Purpose |
|-------|--------|---------|---------|
| `_panel_id` | Panel | Button | ID namespacing |
| `_region` | Panel | Button | Region type (header, corner, etc.) |
| `_corner_position` | Panel | Button | Which corner (tl, tr, bl, br) |
| `_corner_outer` | Panel | Button | Outer corner radius |
| `_corner_inner` | Panel | Button | Inner corner radius |
| `_header_position` | Panel | Button | Position in header (first, middle, last) |

### Button Behavior

```lua
-- Inside Button rendering:
if ctx._corner_position then
  -- Use asymmetric corner rounding
  render_corner_button(ctx, opts, {
    position = ctx._corner_position,
    outer_rounding = ctx._corner_outer,
    inner_rounding = ctx._corner_inner,
  })
elseif ctx._header_position then
  -- Use selective corner rounding
  render_with_corner_flags(ctx, opts, ctx._header_position)
else
  -- Normal button
  render_normal(ctx, opts)
end
```

---

## CornerButton Deprecation

### Current State

- `arkitekt/gui/widgets/primitives/corner_button.lua` - Separate widget
- `arkitekt/gui/widgets/containers/panel/corner_buttons.lua` - Panel integration

### Migration

1. **Phase 1:** Add context injection to Panel, Button reads it
2. **Phase 2:** Panel's corner regions use `Ark.Button` internally
3. **Phase 3:** Deprecate `Ark.CornerButton` with warning
4. **Phase 4:** Remove after migration period

### Deprecation Message

```lua
-- In corner_button.lua
function M.draw(ctx, opts)
  Logger.warn_once("CornerButton",
    "Ark.CornerButton is deprecated. Use Ark.Button inside Panel corner region instead.")
  -- Continue working for backward compat
  return render_corner_button(ctx, opts)
end
```

---

## Config Override (Optional)

Most users need zero config. Overrides only when needed:

```lua
Ark.Panel(ctx, {
  id = "my_panel",

  -- Override panel rounding (rare)
  rounding = 12,

  -- Override corner button sizing (rare)
  corner = {
    inner_rounding = 6,  -- Applied to all corner buttons
    bottom_right = function(ctx) ... end,
  },

  -- Override header height (common)
  header = {
    height = 40,
    draw = function(ctx) ... end,
  },

  draw = function(ctx) ... end,
})
```

---

## Result Object

```lua
local r = Ark.Panel(ctx, { ... })

-- Available fields
r.content_hovered    -- Mouse over content area
r.content_scrolled   -- Content was scrolled this frame
r.header_hovered     -- Mouse over header
r.corner_clicked     -- Table: { top_left = false, bottom_right = true, ... }
```

---

## Implementation Tasks

### Phase 1: Context Injection

- [ ] Add `_panel_context` to ctx during region callbacks
- [ ] Button reads context and adapts rounding
- [ ] Test with header buttons (existing functionality)

### Phase 2: Corner Region

- [ ] Add `corner = {}` config option to Panel
- [ ] Implement corner region callbacks
- [ ] Inject corner context (_corner_position, _corner_outer, _corner_inner)
- [ ] Button renders asymmetric corners when context present

### Phase 3: Callback Migration

- [ ] Add `header.draw` callback support (alongside existing elements)
- [ ] Add `sidebar_left.draw`, `sidebar_right.draw`
- [ ] Add `draw` for main content (alternative to begin/end)
- [ ] Deprecation warnings for `elements = []` syntax

### Phase 4: Cleanup

- [ ] Deprecate `corner_buttons` config (use `corner` region)
- [ ] Deprecate `Ark.CornerButton` widget
- [ ] Update documentation
- [ ] Remove legacy code after migration period

---

## Relationship to Existing Docs

### TODO/PANEL_REFACTOR.md

The legacy refactor plan focused on:
- Extracting TabStrip (still valid - do this)
- Removing app-specific code (still valid)
- Config builder pattern (superseded by callbacks)
- State normalization (still valid)

**Keep:**
- Phase 1: Extract TabStrip
- Phase 2: Remove app-specific code
- Phase 5: State normalization

**Superseded:**
- Phase 4: Config builder → replaced by callback regions
- Phase 6: Composition architecture → callbacks achieve this simpler

### TODO/API_MATCHING/PHASING.md

Update "Out of Scope" section to reference this doc.
Panel rework can be Phase 4 after app migrations.

---

## Example: Full Panel

```lua
Ark.Panel(ctx, {
  id = "region_playlist",

  header = {
    height = 24,
    draw = function(ctx)
      Ark.TabStrip(ctx, {
        tabs = State.get_tabs(),
        active = State.get_active_tab(),
        on_change = State.set_active_tab,
      })
    end,
  },

  corner = {
    bottom_left = function(ctx)
      Ark.Button(ctx, {
        icon = ICONS.bolt,
        tooltip = "Actions",
        on_click = show_actions_menu,
      })
    end,
  },

  draw = function(ctx)
    Ark.Grid(ctx, {
      id = "active_grid",
      items = playlist.items,
      render = render_tile,
    })
  end,
})
```

**User writes normal widgets. Panel handles all the guardrails.**
