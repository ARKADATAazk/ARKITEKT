# Icon LuaCATS Definitions

> **Priority**: Low (nice-to-have)
> **Effort**: ~1 hour
> **Value**: IDE convenience for icon discovery

---

## Decision: Keep Icons Simple

**Chosen approach**: Direct UTF-8 characters + user-provided font

```lua
Ark.Button(ctx, {
  icon = "\xEF\x83\x87",     -- Direct UTF-8 (copy from FontAwesome site)
  icon_font = fonts.icons,   -- User provides font object
  label = "Save",
})
```

**Why not symbolic names?**
- Coders already copy UTF-8 from icon font websites (FontAwesome, RemixIcon, etc.)
- No framework magic to maintain
- Works with any icon font
- Less runtime overhead (no lookup table)

---

## Enhancement: LuaCATS Icon Definitions

Add a reference file for IDE autocomplete/hover info. Not runtime code - just dev tooling.

### Location
```
reference/icons/
├── remix_icons.lua      -- RemixIcon definitions
├── fontawesome.lua      -- FontAwesome definitions
└── README.md            -- How to use
```

Or simpler:
```
helpers/icon_defs.lua    -- Single file with common icons
```

### Format
```lua
-- helpers/icon_defs.lua
-- LuaCATS definitions for icon autocomplete
-- Usage: local Icons = require('helpers.icon_defs')

---@class Icons
---@field SAVE string
---@field FOLDER string
---@field PLAY string ▶
---@field PAUSE string ⏸
---@field STOP string ⏹
---@field SETTINGS string ⚙
---@field SEARCH string 🔍
---@field ADD string +
---@field REMOVE string -
---@field CHECK string ✓
---@field CLOSE string ✕

local Icons = {
  -- RemixIcon (ri-*)
  SAVE = "\xEE\x97\xA7",           -- ri-save-line
  FOLDER = "\xEE\x96\xB5",         -- ri-folder-line
  FOLDER_OPEN = "\xEE\x96\xB7",    -- ri-folder-open-line
  FILE = "\xEE\x96\xAB",           -- ri-file-line

  -- Playback
  PLAY = "\xEE\x9E\xA8",           -- ri-play-fill
  PAUSE = "\xEE\x9E\xAA",          -- ri-pause-fill
  STOP = "\xEE\x9E\xB4",           -- ri-stop-fill
  SKIP_BACK = "\xEE\x9E\xB2",      -- ri-skip-back-fill
  SKIP_FORWARD = "\xEE\x9E\xB3",   -- ri-skip-forward-fill

  -- Actions
  ADD = "\xEE\x80\x9E",            -- ri-add-line
  CLOSE = "\xEE\x80\xAA",          -- ri-close-line
  CHECK = "\xEE\x80\xA8",          -- ri-check-line
  SEARCH = "\xEE\x9E\x88",         -- ri-search-line
  SETTINGS = "\xEE\x9E\x98",       -- ri-settings-3-line

  -- ... etc
}

return Icons
```

### Usage (optional convenience)
```lua
local Icons = require('helpers.icon_defs')

Ark.Button(ctx, {
  icon = Icons.SAVE,
  icon_font = fonts.remix,
  label = "Save",
})
```

### Benefits
- IDE shows icon glyph in autocomplete/hover
- Consistent icon names across codebase
- No runtime lookup (constants are inlined)
- Still works with raw UTF-8 (Icons table is optional)

---

## Tasks

- [ ] Create `helpers/icon_defs.lua` with RemixIcon subset
- [ ] Add LuaCATS `---@field` annotations with glyph previews
- [ ] Document which font each icon requires
- [ ] Optional: Add FontAwesome subset

---

## Future (Maybe)

If multiple icon fonts become common:

```lua
-- Possible future enhancement
Ark.Button(ctx, {
  icon = Icons.SAVE,
  -- icon_font auto-detected from Icons namespace?
})
```

**Decision**: Not needed now. Keep simple - user provides font.
