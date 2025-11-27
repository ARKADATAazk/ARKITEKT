# ThemeAdjuster Refactoring Plan

**Priority**: 3rd in migration queue (after TemplateBrowser, ItemPicker)
**Effort**: Medium
**Current Status**: ~95% Complete, Production-ready, needs structural migration
**Code Quality Rating**: 8.5/10

---

## Overview

ThemeAdjuster is a **well-architected, production-quality application** with excellent domain logic and proper REAPER integration. This refactor focuses on:

1. **Structural migration** to canonical app/domain/infra/ui architecture (MIGRATION_PLANS.md)
2. **Layer purity fixes** (move REAPER API wrappers to platform layer)
3. **Code quality improvements** (logging, imports, magic numbers)

**Key Strengths to Preserve:**
- ✅ Sophisticated package resolution system with conflict detection
- ✅ Configuration management (multiple named presets)
- ✅ Theme parameter indexing and JSON persistence
- ✅ Security-conscious design (path validation)
- ✅ Clean separation of concerns

---

## Current Structure (40 files)

```
ThemeAdjuster/
├── ARK_ThemeAdjuster.lua      # ✅ Entry point (correct bootstrap)
├── core/                      # ❌ Mixed concerns - needs splitting
│   ├── config.lua             # → app/config.lua
│   ├── state.lua              # → app/state.lua (excellent state management!)
│   ├── theme.lua              # → platform/theme.lua OR domain/theme/reader.lua
│   ├── theme_mapper.lua       # → domain/theme/mapper.lua
│   ├── theme_params.lua       # ⚠️  Uses reaper.* → platform/theme_params.lua
│   ├── parameter_link_manager.lua  # → domain/links/manager.lua
│   └── param_discovery.lua    # ⚠️  Uses reaper.* → platform/param_discovery.lua
│
├── packages/                  # Domain-specific, but does I/O
│   ├── image_map.lua          # → domain/packages/image_map.lua (pure logic)
│   ├── manager.lua            # → infra/packages/manager.lua (I/O heavy!)
│   └── metadata.lua           # → domain/packages/metadata.lua (pure data)
│
├── defs/                      # ✅ Keep as-is
│   ├── constants.lua
│   ├── defaults.lua
│   ├── colors.lua
│   └── strings.lua
│
├── ui/
│   ├── gui.lua                # ⚠️  Direct ImGui require → ui/init.lua
│   ├── main_panel.lua         # → ui/views/main_panel.lua
│   ├── status.lua             # ✅ Keep
│   ├── tab_content.lua        # ✅ Keep (excellent cache management!)
│   └── views/
│       ├── assembler_view.lua      # → ui/views/assembler.lua
│       ├── tcp_view.lua            # → ui/views/tcp.lua
│       ├── mcp_view.lua            # → ui/views/mcp.lua
│       ├── global_view.lua         # → ui/views/global.lua
│       ├── colors_view.lua         # → ui/views/colors.lua
│       ├── transport_view.lua      # → ui/views/transport.lua
│       ├── envelope_view.lua       # → ui/views/envelope.lua
│       ├── additional_view.lua     # → ui/views/additional.lua
│       ├── package_modal.lua       # → ui/views/modals/package.lua
│       ├── param_link_modal.lua    # → ui/views/modals/param_link.lua
│       ├── debug_view.lua          # → ui/views/debug.lua
│       └── packages_view.lua       # → ui/views/packages.lua
│
└── Default_6.0_theme_adjuster.lua  # Legacy entry point
```

---

## Target Structure

```
ThemeAdjuster/
├── ARK_ThemeAdjuster.lua      # Entry point (calls app/init)
│
├── app/
│   ├── init.lua               # NEW: Bootstrap, dependency injection
│   ├── config.lua             # FROM: core/config.lua
│   └── state.lua              # FROM: core/state.lua (keep excellent API!)
│
├── domain/
│   ├── theme/
│   │   ├── mapper.lua         # FROM: core/theme_mapper.lua (JSON logic)
│   │   └── reader.lua         # FROM: core/theme.lua (pure logic)
│   ├── links/
│   │   └── manager.lua        # FROM: core/parameter_link_manager.lua
│   └── packages/
│       ├── image_map.lua      # FROM: packages/image_map.lua (pure)
│       └── metadata.lua       # FROM: packages/metadata.lua (pure)
│
├── platform/                  # NEW: REAPER/ImGui wrappers
│   ├── theme_params.lua       # FROM: core/theme_params.lua
│   ├── param_discovery.lua    # FROM: core/param_discovery.lua
│   └── imgui.lua              # NEW: Centralized ImGui version loader
│
├── infra/
│   ├── storage.lua            # NEW: Settings persistence abstraction
│   └── packages/
│       └── manager.lua        # FROM: packages/manager.lua (I/O operations)
│
├── ui/
│   ├── init.lua               # FROM: ui/gui.lua
│   ├── status.lua             # Keep
│   ├── tab_content.lua        # Keep (excellent as-is!)
│   │
│   ├── config/                # NEW: Extract UI constants
│   │   └── constants.lua      # Extract from views (magic numbers)
│   │
│   ├── views/
│   │   ├── main_panel.lua     # FROM: ui/main_panel.lua
│   │   ├── assembler.lua      # FROM: ui/views/assembler_view.lua
│   │   ├── tcp.lua            # FROM: ui/views/tcp_view.lua
│   │   ├── mcp.lua            # FROM: ui/views/mcp_view.lua
│   │   ├── global.lua         # FROM: ui/views/global_view.lua
│   │   ├── colors.lua         # FROM: ui/views/colors_view.lua
│   │   ├── transport.lua      # FROM: ui/views/transport_view.lua
│   │   ├── envelope.lua       # FROM: ui/views/envelope_view.lua
│   │   ├── additional.lua     # FROM: ui/views/additional_view.lua
│   │   ├── packages.lua       # FROM: ui/views/packages_view.lua
│   │   ├── debug.lua          # FROM: ui/views/debug_view.lua
│   │   └── modals/
│   │       ├── package.lua    # FROM: ui/views/package_modal.lua
│   │       └── param_link.lua # FROM: ui/views/param_link_modal.lua
│   │
│   └── grids/                 # If needed later
│       ├── factories/
│       └── renderers/
│
├── defs/                      # UNCHANGED
│   ├── constants.lua
│   ├── defaults.lua
│   ├── colors.lua
│   └── strings.lua
│
└── tests/                     # NEW: Add test structure
    ├── domain/
    │   ├── theme_test.lua
    │   ├── packages_test.lua
    │   └── links_test.lua
    └── platform/
        └── theme_params_test.lua
```

---

## High Priority Tasks

### 1. Layer Purity Violations ⚠️

**Issue**: Core modules use `reaper.*` APIs directly, violating pure layer separation.

**Files affected:**
- `core/theme_params.lua:34` - Uses `reaper.ThemeLayout_GetParameter()`
- `core/param_discovery.lua` - Uses `reaper.*` APIs (implied)
- `core/theme.lua` - May use `reaper.*` APIs (needs verification)

**Action:**
```bash
# Move REAPER API wrappers to platform layer
mkdir -p ThemeAdjuster/platform
git mv core/theme_params.lua platform/theme_params.lua
git mv core/param_discovery.lua platform/param_discovery.lua

# Update all requires:
# FROM: local ThemeParams = require("ThemeAdjuster.core.theme_params")
# TO:   local ThemeParams = require("ThemeAdjuster.platform.theme_params")
```

**Files to update** (grep results needed):
- All view files that import `theme_params`
- All files that import `param_discovery`
- `core/state.lua` if it imports these

**Effort**: Low (mostly mechanical renames)
**Priority**: HIGH - Establishes correct architecture

---

### 2. Direct ImGui Requires ⚠️

**Issue**: UI files use direct ImGui version require instead of platform layer.

**Pattern found:**
```lua
-- ui/gui.lua:5
local ImGui = require 'imgui' '0.10'

-- ui/tab_content.lua:5
local ImGui = require 'imgui' '0.10'

-- All ui/views/*.lua files
local ImGui = require 'imgui' '0.10'
```

**Action 1**: Create centralized ImGui loader
```lua
-- platform/imgui.lua (NEW)
-- @noindex
-- Centralized ImGui version loader

local M = require 'imgui' '0.10'
return M
```

**Action 2**: Update all imports
```bash
# Search for all direct ImGui requires
grep -r "require 'imgui' '0.10'" ThemeAdjuster/ui/

# Replace with:
local ImGui = require('ThemeAdjuster.platform.imgui')
# or from arkitekt if preferred:
# local ImGui = require('arkitekt.platform.imgui')
```

**Files to update** (estimated 15-20 files):
- `ui/gui.lua`
- `ui/tab_content.lua`
- `ui/views/*.lua` (all view files)

**Effort**: Low (mechanical find/replace)
**Priority**: HIGH - Framework consistency

---

### 3. Console Logging Cleanup 🔊

**Issue**: Excessive debug logging in production code.

**File**: `packages/manager.lua:192-230`

```lua
-- CURRENT (production spam)
reaper.ShowConsoleMsg("[PackageScanner] theme_root = " .. tostring(theme_root) .. "\n")
reaper.ShowConsoleMsg("[PackageScanner] packages_path = " .. packages_path .. "\n")
reaper.ShowConsoleMsg("[PackageScanner] Found package folder: " .. folder .. "\n")
reaper.ShowConsoleMsg("[PackageScanner] Package " .. folder .. " has " .. #package.keys_order .. " assets\n")
reaper.ShowConsoleMsg("[PackageScanner] Total packages found: " .. #packages .. "\n")
```

**Action**: Replace with arkitekt Logger
```lua
-- At top of infra/packages/manager.lua
local Logger = require('arkitekt.debug.logger')
local log = Logger.new("PackageScanner")

-- Replace all ShowConsoleMsg with:
log:debug("theme_root = %s", tostring(theme_root))
log:debug("packages_path = %s", packages_path)
log:debug("Found package folder: %s", folder)
log:info("Total packages found: %d", #packages)
```

**Benefits:**
- Conditional logging (disable in production)
- Proper log levels (debug vs info vs warn)
- Centralized log management

**Effort**: Low (30 minutes)
**Priority**: HIGH - Code quality and user experience

---

## Medium Priority Tasks

### 4. Create app/init.lua Bootstrap

**Action**: Create new bootstrap module for clean dependency injection.

```lua
-- app/init.lua (NEW)
-- @noindex
-- ThemeAdjuster Application Bootstrap
-- Dependency injection and module initialization

local M = {}

-- Load configuration
M.config = require("ThemeAdjuster.app.config")

-- Initialize state
M.state = require("ThemeAdjuster.app.state")

-- Platform services (REAPER API wrappers)
M.platform = {
    theme_params = require("ThemeAdjuster.platform.theme_params"),
    param_discovery = require("ThemeAdjuster.platform.param_discovery"),
    imgui = require("ThemeAdjuster.platform.imgui"),
}

-- Domain services (pure business logic)
M.domain = {
    theme = {
        mapper = require("ThemeAdjuster.domain.theme.mapper"),
        reader = require("ThemeAdjuster.domain.theme.reader"),
    },
    links = require("ThemeAdjuster.domain.links.manager"),
    packages = {
        image_map = require("ThemeAdjuster.domain.packages.image_map"),
        metadata = require("ThemeAdjuster.domain.packages.metadata"),
    },
}

-- Infrastructure (I/O operations)
M.infra = {
    storage = require("ThemeAdjuster.infra.storage"),
    packages = require("ThemeAdjuster.infra.packages.manager"),
}

-- Initialize systems
function M.initialize(settings)
    M.state.initialize(settings)
    M.platform.theme_params.index_parameters()
end

return M
```

**Update entry point** (`ARK_ThemeAdjuster.lua`):
```lua
-- AFTER: local ark = dofile(...)
local App = require("ThemeAdjuster.app.init")

-- Initialize application
App.initialize(settings)

-- THEN: Shell.run({ ... })
```

**Effort**: Medium (2-3 hours, requires testing)
**Priority**: MEDIUM - Establishes clean architecture

---

### 5. Extract Magic Numbers to defs/ui.lua

**Issue**: Hardcoded values in UI code.

**Examples found:**
- `ui/views/assembler_view.lua:121` - `height = 32` (footer height)
- `ui/views/assembler_view.lua:141` - `width = 70` (button width)
- `ui/views/assembler_view.lua:150` - `spacing_before = 8`

**Action**: Create `defs/ui.lua`
```lua
-- defs/ui.lua (NEW)
-- @noindex
-- UI-specific constants

return {
    FOOTER = {
        HEIGHT = 32,
        BUTTON_WIDTH = 70,
        BUTTON_SPACING = 8,
    },
    HEADER = {
        HEIGHT = 32,
    },
    PANEL = {
        PADDING = 12,
    },
    -- Add more as discovered
}
```

**Update usage:**
```lua
-- ui/views/assembler_view.lua
local UIConstants = require('ThemeAdjuster.defs.ui')

footer = {
    enabled = true,
    height = UIConstants.FOOTER.HEIGHT,
    -- ...
}
```

**Files to audit** (search for numeric literals):
- All `ui/views/*.lua` files
- `ui/gui.lua`
- `core/config.lua`

**Effort**: Medium (requires careful audit)
**Priority**: MEDIUM - Maintainability improvement

---

### 6. Move Demo Data to Separate Module

**Issue**: Hardcoded demo data in production code.

**File**: `packages/manager.lua:16-72`

**Action**: Extract to `infra/packages/demo_data.lua`
```lua
-- infra/packages/demo_data.lua (NEW)
-- @noindex
-- Demo package data generator for development/testing

local M = {}

function M.generate_demo_packages()
    local packages = {}
    -- ... move all demo generation logic here ...
    return packages
end

return M
```

**Update manager.lua:**
```lua
-- packages/manager.lua
function M.scan_packages(theme_root, demo_mode)
    if demo_mode then
        local DemoData = require('ThemeAdjuster.infra.packages.demo_data')
        return DemoData.generate_demo_packages()
    end
    -- ... real scanning logic ...
end
```

**Benefits:**
- Cleaner separation of concerns
- Easier to disable demo mode entirely in production builds
- Reduced noise in main manager module

**Effort**: Low (30 minutes)
**Priority**: MEDIUM - Code organization

---

### 7. Structural Migration (Following MIGRATION_PLANS.md)

**Phase 1**: Create new folder structure
```bash
mkdir -p ThemeAdjuster/app
mkdir -p ThemeAdjuster/platform
mkdir -p ThemeAdjuster/domain/theme
mkdir -p ThemeAdjuster/domain/links
mkdir -p ThemeAdjuster/domain/packages
mkdir -p ThemeAdjuster/infra/packages
mkdir -p ThemeAdjuster/ui/config
mkdir -p ThemeAdjuster/ui/views/modals
mkdir -p ThemeAdjuster/tests/domain
mkdir -p ThemeAdjuster/tests/platform
```

**Phase 2**: Move files with backward-compat re-exports

**Step 2.1**: Create `app/` folder
| Action | File | Notes |
|--------|------|-------|
| CREATE | `app/init.lua` | Bootstrap (see Task #4) |
| MOVE | `core/config.lua` → `app/config.lua` | Update requires |
| MOVE | `core/state.lua` → `app/state.lua` | Keep excellent API unchanged! |
| ADD RE-EXPORT | `core/config.lua` | `return require("ThemeAdjuster.app.config")` |
| ADD RE-EXPORT | `core/state.lua` | `return require("ThemeAdjuster.app.state")` |

**Step 2.2**: Create `platform/` folder (REAPER API wrappers)
| Action | File | Notes |
|--------|------|-------|
| MOVE | `core/theme_params.lua` → `platform/theme_params.lua` | REAPER API wrapper |
| MOVE | `core/param_discovery.lua` → `platform/param_discovery.lua` | REAPER API wrapper |
| CREATE | `platform/imgui.lua` | Centralized ImGui loader |
| ADD RE-EXPORT | `core/theme_params.lua` | `return require("ThemeAdjuster.platform.theme_params")` |
| ADD RE-EXPORT | `core/param_discovery.lua` | `return require("ThemeAdjuster.platform.param_discovery")` |

**Step 2.3**: Create `domain/` folder (pure business logic)
| Action | File | Notes |
|--------|------|-------|
| MOVE | `core/theme.lua` → `domain/theme/reader.lua` | Rename for clarity |
| MOVE | `core/theme_mapper.lua` → `domain/theme/mapper.lua` | Keep JSON logic |
| MOVE | `core/parameter_link_manager.lua` → `domain/links/manager.lua` | |
| MOVE | `packages/image_map.lua` → `domain/packages/image_map.lua` | Pure logic |
| MOVE | `packages/metadata.lua` → `domain/packages/metadata.lua` | Pure data |
| ADD RE-EXPORT | All old locations | Point to new locations |

**Step 2.4**: Create `infra/` folder (I/O operations)
| Action | File | Notes |
|--------|------|-------|
| MOVE | `packages/manager.lua` → `infra/packages/manager.lua` | Heavy I/O |
| CREATE | `infra/storage.lua` | Extract persistence abstraction |
| CREATE | `infra/packages/demo_data.lua` | Extract demo data (Task #6) |
| ADD RE-EXPORT | `packages/manager.lua` | `return require("ThemeAdjuster.infra.packages.manager")` |

**Step 2.5**: Reorganize `ui/` folder
| Action | File | Notes |
|--------|------|-------|
| MOVE | `ui/gui.lua` → `ui/init.lua` | Rename to convention |
| CREATE | `ui/config/constants.lua` | Extract magic numbers (Task #5) |
| MOVE | `ui/views/package_modal.lua` → `ui/views/modals/package.lua` | |
| MOVE | `ui/views/param_link_modal.lua` → `ui/views/modals/param_link.lua` | |
| REMOVE SUFFIX | `ui/views/*_view.lua` → `ui/views/*.lua` | Remove `_view` suffix |

**Phase 3**: Update all `require()` statements

**Phase 4**: Remove empty `core/` and `packages/` folders after confirming everything works

**Effort**: Medium (4-6 hours with careful testing)
**Priority**: MEDIUM - Follow migration roadmap

---

## Low Priority Tasks

### 8. Add Unit Tests

**Create test structure:**
```
tests/
├── domain/
│   ├── theme_mapper_test.lua    # Test JSON mapping logic
│   ├── packages_test.lua        # Test package resolution
│   └── links_test.lua           # Test parameter linking
└── platform/
    └── theme_params_test.lua    # Test parameter indexing
```

**Example test** (using busted or similar):
```lua
-- tests/domain/packages_test.lua
local Manager = require('ThemeAdjuster.infra.packages.manager')

describe("Package Resolution", function()
    it("should resolve conflicts by order", function()
        local packages = {
            { id = "A", assets = { tcp_bg = { path = "/a/tcp_bg.png" } } },
            { id = "B", assets = { tcp_bg = { path = "/b/tcp_bg.png" } } },
        }
        local active = { A = true, B = true }
        local order = { "A", "B" }

        local resolved = Manager.resolve_packages(packages, active, order, {}, {})

        assert.equals(resolved.tcp_bg.provider, "B") -- B wins (later in order)
    end)
end)
```

**Effort**: Medium (requires test framework setup)
**Priority**: LOW - Nice to have, but app is already well-tested manually

---

### 9. API Documentation

**Add JSDoc-style comments** to public APIs.

**Example:**
```lua
--- Resolve package assets with conflict handling
-- @param packages table List of package objects
-- @param active_packages table Map of active package IDs
-- @param package_order table Ordered list of package IDs (priority)
-- @param exclusions table Map of excluded assets per package
-- @param pins table Map of pinned assets (override order)
-- @return table Resolved asset map { key = { path, provider, is_strip, pinned? } }
function M.resolve_packages(packages, active_packages, package_order, exclusions, pins)
    -- ...
end
```

**Files to document:**
- All public functions in `domain/` modules
- All public functions in `platform/` modules
- State management API (`app/state.lua`)

**Effort**: Medium (2-3 hours)
**Priority**: LOW - Code is already self-explanatory

---

### 10. Performance Optimization

**Current status**: Performance is acceptable for typical use.

**Potential improvements** (if needed):
1. **Cache package scan results** (`ui/gui.lua:34-48`)
   - Currently rescans on every refresh
   - Could cache and only invalidate on theme change

2. **Virtualize package grid** (only if >100 packages)
   - Currently renders all packages
   - Could virtualize using existing grid infrastructure

3. **Optimize theme parameter lookups**
   - Current indexing is already fast
   - Could memoize frequently accessed parameters

**Effort**: Medium
**Priority**: LOW - Current performance is fine

---

## Migration Checklist

### High Priority
- [ ] 1. Move `theme_params.lua` to `platform/`
- [ ] 2. Move `param_discovery.lua` to `platform/`
- [ ] 3. Create `platform/imgui.lua` loader
- [ ] 4. Update all direct ImGui requires (15-20 files)
- [ ] 5. Replace console logging with Logger
- [ ] 6. Update all requires after moves
- [ ] 7. Test all views still work

### Medium Priority
- [ ] 8. Create `app/init.lua` bootstrap
- [ ] 9. Create `defs/ui.lua` for magic numbers
- [ ] 10. Extract demo data to separate module
- [ ] 11. Move `core/config.lua` → `app/config.lua`
- [ ] 12. Move `core/state.lua` → `app/state.lua`
- [ ] 13. Reorganize `domain/` folder structure
- [ ] 14. Reorganize `infra/` folder structure
- [ ] 15. Remove `_view` suffixes from view files
- [ ] 16. Move modals to `ui/views/modals/`
- [ ] 17. Test all tabs and functionality
- [ ] 18. Delete empty `core/` folder
- [ ] 19. Delete empty `packages/` folder (after moving to infra/)

### Low Priority
- [ ] 20. Add unit tests for domain logic
- [ ] 21. Add unit tests for platform wrappers
- [ ] 22. Add JSDoc comments to public APIs
- [ ] 23. Consider performance optimizations if needed

---

## Testing Strategy

**After each phase:**
1. Launch ThemeAdjuster
2. Test all tabs: Global, Assembler, TCP, MCP, Colors, Envelopes, Transport, Additional, Debug
3. Test package selection and assembly
4. Test configuration switching
5. Test Apply/Revert functionality
6. Test demo mode toggle
7. Check console for errors

**Critical paths to test:**
- Package scanning (real theme + demo mode)
- Theme parameter reading/writing
- Layout switching (A/B/C)
- Visibility checkboxes
- Apply/Revert with backups
- Configuration management (add/delete/rename)
- ZIP theme support

---

## Notes

### Code Quality Summary
- **Overall**: 8.5/10 - Excellent production-quality code
- **Architecture**: 9/10 - Clean separation, minor layer violations
- **Security**: 9/10 - Proper path validation, safe JSON handling
- **Performance**: 8/10 - Good for typical use
- **Testing**: 7/10 - Well tested manually, needs unit tests
- **Documentation**: 7/10 - Clear code, needs API docs

### What NOT to Change
- ✅ **state.lua** - Excellent state management API, keep unchanged!
- ✅ **tab_content.lua** - Excellent cache management, keep as-is
- ✅ **Package resolution logic** - Sophisticated and correct
- ✅ **Theme parameter indexing** - Smart caching system
- ✅ **Configuration management** - Clean multi-preset system
- ✅ **Security patterns** - Path validation is solid

### References
- **Migration Plan**: `cookbook/MIGRATION_PLANS.md` (lines 575-723)
- **Code Review**: This document (section: Code Quality)
- **Architecture Guide**: `cookbook/PROJECT_STRUCTURE.md`
- **Conventions**: `cookbook/CONVENTIONS.md`
- **Integration Status**: `scripts/ThemeAdjuster/INTEGRATION_STATUS.md`

---

## Estimated Effort

| Phase | Tasks | Time | Complexity |
|-------|-------|------|------------|
| **High Priority** | Layer purity + ImGui + logging | 4-6 hours | Low-Medium |
| **Medium Priority** | Structural migration | 4-6 hours | Medium |
| **Low Priority** | Tests + docs | 4-6 hours | Low |
| **TOTAL** | All phases | 12-18 hours | Medium |

---

## Success Criteria

✅ **Complete when:**
1. All files follow canonical `app/domain/platform/infra/ui` structure
2. No `reaper.*` calls in `core/` or `domain/` folders
3. All ImGui requires go through `platform/imgui.lua`
4. Console logging replaced with arkitekt Logger
5. All views work correctly with new structure
6. No regression in functionality

🎉 **Result:** Production-ready, architecturally sound ThemeAdjuster following ARKITEKT best practices
