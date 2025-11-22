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

## 🧪 Testing

### Test Structure

While REAPER Lua presents unique challenges, we can still test:

```
tests/
├── unit/                      # Pure Lua logic (no REAPER APIs)
│   ├── core/
│   │   ├── config_test.lua    # Config merge precedence
│   │   ├── colors_test.lua    # Color conversion utilities
│   │   └── math_test.lua      # Math helpers
│   └── gui/
│       └── layout_test.lua    # Layout calculations
│
├── integration/               # With mocked REAPER APIs
│   ├── widget_render_test.lua
│   └── theme_load_test.lua
│
└── mocks/
    └── reaper_api.lua         # Mock REAPER functions
```

### What to Test

**✅ Always test:**
- Configuration merging logic
- Color conversion/manipulation
- Mathematical calculations
- State management
- Data transformations
- Layout algorithms

**⚠️ Test with mocks:**
- Widget rendering logic
- Theme loading
- Settings persistence
- Undo/redo operations

**❌ Don't test:**
- ReaImGui API calls directly (integration testing territory)
- User interactions (manual QA)

### Running Tests

```bash
# Install Busted (Lua testing framework)
luarocks install busted

# Run all tests
busted tests/

# Run specific test file
busted tests/unit/core/config_test.lua

# Run with coverage (if luacov installed)
busted -c tests/
```

### Example Test

```lua
-- tests/unit/core/config_test.lua
describe("Config merge", function()
  local config = require("arkitekt.core.config")

  it("should prioritize user config over defaults", function()
    local defaults = { width = 400, color = 0xFF0000FF }
    local user = { width = 600 }

    local result = config.merge(defaults, user)

    assert.are.equal(600, result.width)
    assert.are.equal(0xFF0000FF, result.color)
  end)

  it("should apply preset before user config", function()
    local base = { bg = 0x000000FF }
    local preset = { bg = 0x111111FF, fg = 0xFFFFFFFF }
    local user = { fg = 0x00FF00FF }

    local result = config.resolve(user, { preset = preset, base = base })

    assert.are.equal(0x111111FF, result.bg)  -- From preset
    assert.are.equal(0x00FF00FF, result.fg)  -- User override
  end)
end)
```

## 📝 Documentation Requirements

### Code Documentation

**Module headers:**
```lua
--[[
  @module arkitekt.core.theme_manager
  @description Manages theme loading, auto-detection, and application-wide theme state
  @author ARKITEKT Contributors
  @license GPL-3.0
]]

local M = {}
```

**Function documentation:**
```lua
--[[
  Loads a theme by name with fallback to default

  @param name string Theme name ("dark", "light", "auto", or custom)
  @param fallback string|nil Fallback theme if name not found (default: "dark")
  @return table Theme color table
  @raise error If neither theme nor fallback can be loaded
]]
function M.load_theme(name, fallback)
  -- Implementation
end
```

### README Requirements for New Apps

Apps in `apps/` should include a README:

```markdown
# App Name

Brief description (1-2 sentences).

## Features
- Feature 1
- Feature 2

## Usage
How to launch and use the app.

## Configuration
Available config options.

## Dependencies
- ARKITEKT core library
- Any specific REAPER extensions (SWS, JS_API, etc.)
```

## 🔄 Contribution Workflow

### 1. Fork & Branch

```bash
# Fork the repository on GitHub
# Clone your fork
git clone https://github.com/YOUR_USERNAME/ARKITEKT-Project.git
cd ARKITEKT-Project

# Create a feature branch
git checkout -b feature/your-feature-name
# or
git checkout -b fix/bug-description
```

### 2. Make Changes

- Follow code standards above
- Write tests for new functionality
- Update documentation
- Keep commits atomic and well-described

### 3. Test Locally

```bash
# Run tests
busted tests/

# Test in REAPER
# 1. Copy ARKITEKT/ folder to your REAPER Scripts directory
# 2. Run affected scripts in REAPER
# 3. Verify no errors in ReaScript console
```

### 4. Commit Messages

Follow conventional commit format:

```
type(scope): brief description

Longer explanation if needed.

Fixes #issue_number
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code restructuring (no behavior change)
- `docs`: Documentation changes
- `test`: Adding/updating tests
- `style`: Code style changes (formatting, naming)
- `perf`: Performance improvements

**Examples:**
```
feat(widgets): add horizontal slider widget

Implements a customizable horizontal slider with snap-to-grid support
and REAPER automation integration.

Closes #42
```

```
fix(config): correct merge precedence for presets

User config was being overridden by context defaults. Now correctly
applies: base < preset < context < user.

Fixes #38
```

### 5. Submit Pull Request

- Push to your fork
- Open PR against `main` branch
- Fill out PR template
- Reference any related issues

**PR will be reviewed for:**
- Code quality and style compliance
- Test coverage
- Documentation completeness
- Architectural fit
- Breaking changes (require discussion)

## ⏱️ Review Timeline

**Expectations:**
- PRs reviewed but no guaranteed merge timeline
- Maintainers have day jobs; be patient
- Support is best-effort, not guaranteed
- API may evolve; breaking changes possible

**Response time:**
- Simple fixes: 1-2 weeks
- New features: 2-4 weeks
- Architectural changes: Requires discussion first

## 🤝 Community

### Getting Help

- **GitHub Issues:** Bug reports, feature discussions
- **Code Questions:** Open a discussion or draft PR
- **Documentation:** Check `/Documentation/` and `/*.md` files

### Code of Conduct

- Be respectful and constructive
- Focus on technical merit
- Welcome newcomers
- Share knowledge freely
- Credit others' work

## 🎓 Learning Resources

**Before contributing, read:**
- `README.md` - Project overview
- `ARKITEKT_Codex_Playbook_v5.md` - Architecture patterns
- `DOCS_CONFIG_BEST_PRACTICES.md` - Config system
- `PROJECT_STRUCTURE.txt` - Codebase layout
- `arkitekt/app/README.md` - Framework layer docs

**REAPER Resources:**
- [ReaImGui Documentation](https://github.com/cfillion/reaimgui)
- [REAPER API Documentation](https://www.reaper.fm/sdk/reascript/reascript.php)
- [SWS Extension](https://www.sws-extension.org/)

## 📊 Success Metrics

We measure success by:
- Community contributions
- Apps built on ARKITEKT
- Theme ecosystem growth
- User adoption over forking
- Brand recognition in REAPER community

---

## Quick Reference

### File Naming
- Directories: `snake_case`
- Lua files: `snake_case.lua`
- Launchers: `ARK_AppName.lua` (exception)

### Import Pattern
```lua
require("arkitekt.LAYER.MODULE")
require("arkitekt.apps.APP_NAME.LAYER.MODULE")
```

### Config Priority
```
BASE < PRESET < CONTEXT < USER
```

### Commit Format
```
type(scope): description
```

### Test Command
```bash
busted tests/
```

---

**Questions?** Open a GitHub Discussion or Issue.

**Thank you for contributing to ARKITEKT! 🎉**
