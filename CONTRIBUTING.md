# Contributing to ARKITEKT

Thank you for your interest in contributing to ARKITEKT! This document outlines the guidelines and expectations for contributions.

## 📜 License & Philosophy

ARKITEKT is licensed under **GPL v3** to:
- Keep the ecosystem open source
- Prevent closed commercial forks
- Ensure improvements are shared back with the community
- Build a collaborative REAPER scripting ecosystem

**Brand Philosophy:**
- Apps using ARKITEKT should keep the branding
- We welcome building on top of ARKITEKT
- White-labeled forks are discouraged (use as a library instead)
- Technical coupling makes integration easier than rebranding

## 🎯 What We Welcome

### Bug Fixes & Improvements ✅
- Bug fixes to core library or apps
- Performance optimizations
- Code quality improvements
- Documentation improvements

### New Widgets & Components ✅
- New reusable widgets for `arkitekt/gui/widgets/`
- GUI systems (layout, animations, effects)
- Well-documented and tested components

### Theme Contributions ✅
- Custom themes in `arkitekt/themes/`
- REAPER theme companions
- Color scheme improvements

### Example Applications ✅
- New apps demonstrating ARKITEKT usage
- Reference implementations
- Educational examples
- Apps should reside in `apps/` directory

### Documentation ✅
- Architecture guides
- API documentation
- Tutorials and examples
- Code comments and inline docs

## ❌ What We Don't Accept

### Without Discussion First
- Breaking architectural changes
- Major API redesigns
- Removal of core features

### Not Accepting
- Feature requests without implementation
- White-labeled forks (against project philosophy)
- Code that doesn't match existing patterns
- Undocumented or untested contributions

## 🔧 Code Standards

### Directory & File Naming

**Directories:** Use `snake_case` for consistency
```
✅ arkitekt/core/theme_manager/
✅ apps/color_palette/
✅ apps/region_playlist/

❌ arkitekt/Core/ThemeManager/
❌ apps/ColorPalette/
```

**Files:** Use `snake_case.lua`
```
✅ app_state.lua
✅ disk_cache.lua
✅ theme_manager.lua

❌ appState.lua
❌ DiskCache.lua
❌ ThemeManager.lua
```

**Launcher Scripts:** Use `ARK_AppName.lua` (exception for user-facing entry points)
```
✅ ARK_ColorPalette.lua
✅ ARK_RegionPlaylist.lua
✅ ARKITEKT.lua
```

### Require Paths

Follow the standardized import pattern:

```lua
-- Core library imports (lowercase "arkitekt")
local colors = require("arkitekt.core.colors")
local Grid = require("arkitekt.gui.widgets.grid.core")
local theme_manager = require("arkitekt.core.theme_manager")

-- App imports
local state = require("arkitekt.apps.color_palette.app.state")
local engine = require("arkitekt.apps.region_playlist.engine.core")
```

**Pattern:**
- Library: `arkitekt.MODULE.SUBMODULE`
- Apps: `arkitekt.apps.APP_NAME.LAYER.MODULE`

### Configuration Management

**Single Source of Truth:**
- Use `arkitekt/app/init/constants.lua` for framework defaults
- Use `arkitekt/core/config.lua` for configuration merging
- Follow patterns in `DOCS_CONFIG_BEST_PRACTICES.md`

**Config Merge Precedence:**
```
BASE DEFAULTS < PRESET < CONTEXT DEFAULTS < USER CONFIG
```

**DON'T** create app-specific config merge patterns. Use the centralized system.

```lua
-- ✅ DO: Use centralized config resolution
local config = require("arkitekt.core.config")
local resolved = config.resolve(user_config, context_defaults)

-- ❌ DON'T: Create custom merge logic
local config = deepMerge(deepMerge(base, preset), user)
```

### Color System

**Never hardcode colors:**
```lua
-- ❌ DON'T
local bg_color = 0x252525FF

-- ✅ DO: Use theme system
local colors = require("arkitekt.core.colors")
local bg_color = colors.background.primary
```

### Code Style

**Indentation:** 2 spaces (no tabs)
```lua
function my_function()
  if condition then
    do_something()
  end
end
```

**Naming Conventions:**
- Variables/functions: `snake_case`
- Constants: `SCREAMING_SNAKE_CASE`
- Modules: `PascalCase` for tables returned from modules
- Private functions: Prefix with `_` (e.g., `_internal_helper()`)

```lua
-- Variables
local item_count = 10
local user_config = {}

-- Constants
local DEFAULT_WIDTH = 400
local MAX_ITEMS = 1000

-- Module returns
local M = {}
function M.create_widget() end
return M

-- Private functions
local function _calculate_offset()
  -- Internal use only
end
```

**Comments:**
- Explain *why*, not *what*
- Document complex algorithms
- Add TODOs with context

```lua
-- ✅ Good: Explains reasoning
-- Use binary search because item_list can exceed 10k items
local index = binary_search(item_list, target)

-- ❌ Bad: States the obvious
-- Search for item in list
local index = binary_search(item_list, target)
```