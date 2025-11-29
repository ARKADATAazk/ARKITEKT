# ImGui Import Centralization

Consolidate scattered ImGui imports to use central loader.

**Progress:** ■■■■■■■■■■ 100% (125/125)
**Status:** Completed

## Problem

126 files did their own `require 'imgui' '0.10'` instead of using the central loader at `arkitekt/platform/imgui.lua`.

Version `'0.10'` was hardcoded in 126 places.

## Solution Implemented

Used central wrapper:
```lua
local ImGui = require('arkitekt.platform.imgui')
```

## Implementation

### Batch Update Script
Created `update_imgui_imports.sh` that:
1. Found all 125 files with scattered imports
2. Removed `package.path` lines for ImGui
3. Replaced all import patterns with central loader
4. Excluded `platform/imgui.lua` itself
5. Excluded `external/` libraries

### Files Updated

**Total:** 125 files across:
- ✅ `arkitekt/gui/widgets/**/*.lua` (all widgets)
- ✅ `scripts/RegionPlaylist/ui/**/*.lua`
- ✅ `scripts/ItemPicker/ui/**/*.lua`
- ✅ `scripts/WalterBuilder/ui/**/*.lua`
- ✅ `scripts/ColorPalette/**/*.lua`
- ✅ `scripts/demos/*.lua`
- ✅ `scripts/Sandbox/*.lua`
- ✅ `hub/hub.lua`
- ✅ All other framework files

### Verification

```bash
# Before: 126 files with scattered imports
grep -r "require.*imgui.*0.10" ARKITEKT/ --include="*.lua" | wc -l
# Result: 126

# After: Only 2 remaining (expected)
grep -r "require.*imgui.*0.10" ARKITEKT/ --include="*.lua"
# Result:
#   arkitekt/platform/imgui.lua (central loader - should keep)
#   arkitekt/external/talagan_ReaImGui Markdown/... (external lib - should keep)

# Confirm central loader usage: 197 files now use it
grep -r "arkitekt\.platform\.imgui" ARKITEKT/ --include="*.lua" | wc -l
# Result: 197
```

## Benefits

✅ **Single source of truth** - Version managed in one place
✅ **Easy updates** - Change version in one file
✅ **Cleaner imports** - No more `package.path` manipulation
✅ **Consistent** - All framework/script files use same pattern

## Completion Date

2025-11-29
