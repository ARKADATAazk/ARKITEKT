# ImGui Import Centralization

Consolidate scattered ImGui imports to use central loader.

## Problem

60+ files do their own `require 'imgui' '0.10'` instead of using:
- `Ark.ImGui` (from namespace)
- `require('arkitekt.core.imgui')` (central wrapper)

Version `'0.10'` is hardcoded in 60+ places.

## Solution

### Option A: Use Ark.ImGui
Files that already have `ark` available should use `Ark.ImGui`.

### Option B: Use central wrapper
```lua
local ImGui = require('arkitekt.core.imgui')
```

## Files to Update

### Framework (arkitekt/)
- [ ] `gui/widgets/primitives/button.lua`
- [ ] `gui/widgets/primitives/combo.lua`
- [ ] `gui/widgets/primitives/slider.lua`
- [ ] `gui/widgets/primitives/inputtext.lua`
- [ ] `gui/widgets/primitives/close_button.lua`
- [ ] `gui/widgets/data/*.lua`
- [ ] `gui/widgets/text/*.lua`

### Scripts
- [ ] `scripts/RegionPlaylist/ui/**/*.lua`
- [ ] `scripts/ItemPicker/ui/**/*.lua`
- [ ] `scripts/TemplateBrowser/ui/**/*.lua`
- [ ] `scripts/ColorPalette/**/*.lua`
- [ ] `scripts/demos/*.lua`

## Grep to find them
```bash
grep -r "require.*imgui.*0.10" ARKITEKT/ --include="*.lua"
```

## Priority
Low - Works fine, just inconsistent and version scattered.
