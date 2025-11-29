# TemplateBrowser Refactoring TODO

> **Status**: 8.5/10 (Production-ready with minor improvements needed)
> **Migration Priority**: 1st (Reference Implementation)
> **Effort**: Low-Medium
> **Reference**: [cookbook/MIGRATION_PLANS.md](../../cookbook/MIGRATION_PLANS.md#templatebrowser-migration)

## Quick Assessment

✅ **Strengths**: Excellent architecture, rich features, strong ARKITEKT compliance, performance optimizations
⚠️ **Issues**: Code duplication (~300 LOC), state module confusion, magic numbers, console logging

---

## Table of Contents

1. [Priority 1: Critical Refactoring](#priority-1-critical-refactoring)
2. [Priority 2: Migration (File Moves)](#priority-2-migration-file-moves)
3. [Priority 3: Code Quality Improvements](#priority-3-code-quality-improvements)
4. [Priority 4: Polish & Documentation](#priority-4-polish--documentation)
5. [Priority 5: Future Enhancements](#priority-5-future-enhancements)
6. [Migration Checklist](#migration-checklist)

---

## Priority 1: Critical Refactoring

**Goal**: Fix major issues before migration. Ship-blocking items.

### 1.1 Deduplicate Grid Factory Callbacks (~300 LOC savings)

**Impact**: High | **Effort**: Medium | **Status**: ⬜

**Location**: `ui/init.lua:56-214` and `ui/init.lua:296-426`

**Problem**: The `template_grid` and `quick_access_grid` callbacks are 95% identical. This creates maintenance burden and inconsistency risk.

**Solution**:

```lua
-- NEW: ui/tiles/helpers.lua (or ui/grid_callbacks.lua)
local M = {}

function M.create_grid_callbacks(gui, get_templates_fn, is_quick_access)
  return {
    on_select = function(selected_keys)
      -- Unified select logic
      if selected_keys and #selected_keys > 0 then
        local key = selected_keys[1]
        local uuid = key:match("template_(.+)")
        local templates = get_templates_fn()

        for _, tmpl in ipairs(templates) do
          if tmpl.uuid == uuid then
            gui.state.selected_template = tmpl
            break
          end
        end
      else
        gui.state.selected_template = nil
      end

      -- Store selected keys only for main grid (not quick access)
      if not is_quick_access then
        gui.state.selected_template_keys = selected_keys or {}
      end
    end,

    on_double_click = function(template)
      if template then
        -- Check for rename (Ctrl+DoubleClick) only on main grid
        if not is_quick_access then
          local ctrl_down = ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl)
          if ctrl_down then
            gui.state.renaming_item = template
            gui.state.renaming_type = "template"
            gui.state.rename_buffer = template.name
            return
          end
        end

        -- Apply template
        TemplateOps.apply_to_selected_track(template.path, template.uuid, gui.state)
      end
    end,

    on_right_click = function(template, selected_keys)
      if template then
        gui.state.context_menu_template = template
      end
    end,

    on_star_click = function(template)
      if template then
        local Persistence = require('TemplateBrowser.domain.persistence')
        local favorites_id = "__FAVORITES__"
        local favorites = gui.state.metadata.virtual_folders[favorites_id]

        if not favorites then
          gui.state.set_status("Favorites folder not found", "error")
          return
        end

        -- Toggle favorite
        local is_favorited = false
        local favorite_index = nil
        for idx, ref_uuid in ipairs(favorites.template_refs) do
          if ref_uuid == template.uuid then
            is_favorited = true
            favorite_index = idx
            break
          end
        end

        if is_favorited then
          table.remove(favorites.template_refs, favorite_index)
          gui.state.set_status("Removed from Favorites: " .. template.name, "success")
        else
          table.insert(favorites.template_refs, template.uuid)
          gui.state.set_status("Added to Favorites: " .. template.name, "success")
        end

        Persistence.save_metadata(gui.state.metadata)

        -- Refresh if viewing Favorites
        if gui.state.selected_folder == favorites_id then
          local Scanner = require('TemplateBrowser.domain.scanner')
          Scanner.filter_templates(gui.state)
        end
      end
    end,

    on_tag_drop = function(template, payload)
      if template and payload then
        local Tags = require('TemplateBrowser.domain.tags')
        local Persistence = require('TemplateBrowser.domain.persistence')

        local tag_name = payload.label or payload.id
        if not tag_name then return end

        -- Check if template is in selection (only for main grid)
        local template_key = "template_" .. template.uuid
        local is_selected = false
        local selected_keys = is_quick_access and {} or (gui.state.selected_template_keys or {})

        for _, key in ipairs(selected_keys) do
          if key == template_key then
            is_selected = true
            break
          end
        end

        local tagged_count = 0

        if is_selected and #selected_keys > 1 then
          -- Multi-select: tag all selected
          for _, key in ipairs(selected_keys) do
            local uuid = key:match("template_(.+)")
            if uuid and Tags.add_tag_to_template(gui.state.metadata, uuid, tag_name) then
              tagged_count = tagged_count + 1
            end
          end
        else
          -- Single: tag only dropped template
          if Tags.add_tag_to_template(gui.state.metadata, template.uuid, tag_name) then
            tagged_count = 1
          end
        end

        Persistence.save_metadata(gui.state.metadata)

        -- Re-filter if tag filters active
        if next(gui.state.filter_tags) then
          local Scanner = require('TemplateBrowser.domain.scanner')
          Scanner.filter_templates(gui.state)
        end

        -- Status message
        if tagged_count > 1 then
          gui.state.set_status("Tagged " .. tagged_count .. " templates with " .. tag_name, "success")
        elseif tagged_count == 1 then
          gui.state.set_status("Tagged \"" .. template.name .. "\" with " .. tag_name, "success")
        end
      end
    end,
  }
end

return M
```

**Then in `ui/init.lua`**:

```lua
local GridCallbacks = require('TemplateBrowser.ui.tiles.helpers')

-- Main grid
self.template_grid = TemplateGridFactory.create(
  function() return self.state.filtered_templates end,
  self.state.metadata,
  self.template_animator,
  function() return self.state.template_view_mode == "list" and self.state.list_tile_width or self.state.grid_tile_width end,
  function() return self.state.template_view_mode end,
  GridCallbacks.create_grid_callbacks(self, function() return self.state.filtered_templates end, false),
  self
)

-- Quick access grid
self.quick_access_grid = TemplateGridFactory.create(
  get_quick_access_templates,
  self.state.metadata,
  self.template_animator,
  function() return self.state.quick_access_view_mode == "list" and self.state.list_tile_width or self.state.grid_tile_width end,
  function() return self.state.quick_access_view_mode end,
  GridCallbacks.create_grid_callbacks(self, get_quick_access_templates, true),
  self
)
```

**Files to modify**:
- [ ] CREATE: `ui/tiles/helpers.lua` (or `ui/grid_callbacks.lua`)
- [ ] EDIT: `ui/init.lua` (lines 56-426) - Replace with callback factory calls

**Benefits**:
- ~300 LOC reduction
- Single source of truth for grid behavior
- Easier to maintain and update
- Reduces inconsistency bugs

---

### 1.2 Resolve State Module Confusion

**Impact**: High | **Effort**: Low | **Status**: ⬜

**Problem**: Two state modules exist:
- `core/state.lua` (used by entry point)
- `app/state.lua` (seems more complete per migration plan)

**Current Usage**:
```lua
-- ARK_TemplateBrowser.lua:14
local State = require('TemplateBrowser.core.state')  -- ← Currently used
```

**Solution**:

**Option A** (Recommended - Matches Migration Plan):
1. **Keep**: `app/state.lua` as the canonical state module
2. **Convert**: `core/state.lua` → re-export shim:
   ```lua
   -- @deprecated TEMP_PARITY_SHIM: Use TemplateBrowser.app.state
   -- EXPIRES: After migration Phase 2 completion
   return require("TemplateBrowser.app.state")
   ```
3. **Update**: `ARK_TemplateBrowser.lua` to use `app.state`

**Option B** (If app/state.lua is newer/experimental):
1. **Move**: `app/state.lua` content into `core/state.lua`
2. **Delete**: `app/state.lua`

**Action Items**:
- [ ] DECISION: Choose Option A or B (recommend A per migration plan)
- [ ] EXECUTE: Implement chosen option
- [ ] TEST: Verify all state operations work
- [ ] COMMIT: "Resolve state module ambiguity"

**Files to check**:
- `core/state.lua` - Current implementation (75 lines)
- `app/state.lua` - Alternative implementation (158 lines) ← More complete!
- `ARK_TemplateBrowser.lua` - Entry point require

---

### 1.3 Fix Direct ImGui Require (Use Platform Layer)

**Impact**: Medium | **Effort**: Low | **Status**: ⬜

**Locations**:
- `ui/init.lua:5`
- `ui/views/template_panel_view.lua:5`
- `ui/views/left_panel_view.lua:5`

**Current**:
```lua
local ImGui = require 'imgui' '0.10'  -- ❌ Direct, version-specific
```

**Should be**:
```lua
local ImGui = require('arkitekt.platform.imgui')  -- ✅ Framework abstraction
```

**Rationale**:
- Bypasses framework version management
- Tight coupling to ImGui version
- Inconsistent with ARKITEKT conventions

**IF** you need a specific version different from framework:
- Document WHY in a comment
- Consider if framework should be updated instead

**Action Items**:
- [ ] EDIT: `ui/init.lua` - Replace ImGui require
- [ ] EDIT: `ui/views/template_panel_view.lua` - Replace ImGui require
- [ ] EDIT: `ui/views/left_panel_view.lua` - Replace ImGui require
- [ ] TEST: Verify ImGui functions work correctly
- [ ] COMMIT: "Use platform layer for ImGui imports"

---

### 1.4 Move Magic Numbers to Constants

**Impact**: Medium | **Effort**: Medium | **Status**: ⬜

**Problem**: Many layout values hardcoded throughout UI code.

**Examples**:
- `ui/init.lua:756`: `title_y_offset = -15`
- `ui/init.lua:809`: `separator_thickness = 8`
- `ui/init.lua:127`: `quick_access_separator_position = 350`
- `ui/views/template_panel_view.lua:176`: `min_grid_height = 200`
- `ui/views/template_panel_view.lua:177`: `min_quick_access_height = 120`
- `ui/views/template_panel_view.lua:175`: `separator_gap = 8`

**Solution**: Create `defs/layout.lua`:

```lua
-- @noindex
-- TemplateBrowser/defs/layout.lua
-- Layout constants (spacing, sizes, offsets)

local M = {}

-- ============================================================================
-- TITLE / HEADER
-- ============================================================================
M.TITLE = {
  Y_OFFSET = -15,  -- Pixels to move title upward for tighter layout
}

-- ============================================================================
-- SEPARATORS / SPLITTERS
-- ============================================================================
M.SEPARATOR = {
  THICKNESS = 8,  -- Hit area for draggable separators
  GAP = 8,  -- Spacing around separators

  -- Default positions
  DEFAULT_GRID_HEIGHT = 350,  -- Initial main grid height (user-adjustable)
  MIN_PANEL_WIDTH = 150,  -- Minimum column width
  MIN_GRID_HEIGHT = 200,  -- Minimum main grid height
  MIN_QUICK_ACCESS_HEIGHT = 120,  -- Minimum quick access panel height
}

-- ============================================================================
-- PADDING
-- ============================================================================
M.PADDING = {
  WINDOW_LEFT = 14,
  WINDOW_RIGHT = 14,
  WINDOW_BOTTOM = 14,
  PANEL_INNER = 8,  -- Internal panel padding
}

-- ============================================================================
-- STATUS BAR
-- ============================================================================
M.STATUS_BAR = {
  HEIGHT = 24,  -- Reserved space at bottom
}

-- ============================================================================
-- FILTER CHIPS
-- ============================================================================
M.FILTER_CHIP = {
  HEIGHT = 22,
  SPACING = 4,
  MARGIN_H = 8,  -- Horizontal margin from edges
  MARGIN_V = 4,  -- Vertical margin around chip row
}

return M
```

**Then update requires**:

```lua
-- ui/init.lua
local Layout = require('TemplateBrowser.defs.layout')

-- Usage:
local title_y_offset = Layout.TITLE.Y_OFFSET
local separator_thickness = Layout.SEPARATOR.THICKNESS
local padding_left = Layout.PADDING.WINDOW_LEFT
```

**Action Items**:
- [ ] CREATE: `defs/layout.lua` with all layout constants
- [ ] EDIT: `ui/init.lua` - Replace hardcoded values with Layout.* references
- [ ] EDIT: `ui/views/template_panel_view.lua` - Replace hardcoded values
- [ ] EDIT: `ui/views/left_panel_view.lua` - Replace hardcoded values
- [ ] TEST: Verify layout looks identical
- [ ] COMMIT: "Extract layout magic numbers to defs/layout.lua"

---

## Priority 2: Migration (File Moves)

**Goal**: Align with canonical ARKITEKT structure per [MIGRATION_PLANS.md](../../cookbook/MIGRATION_PLANS.md)

### 2.1 Phase 1: Prepare for Migration

**Status**: ⬜

- [ ] **VERIFY**: All Priority 1 refactoring complete (dedupe, state, constants)
- [ ] **BACKUP**: Create git branch `migrate/templatebrowser-structure`
- [ ] **DOCUMENT**: Note any custom deviations from migration plan

---

### 2.2 Phase 2: Create New Folder Structure

**Status**: ⬜

```bash
# Run from ARKITEKT/scripts/TemplateBrowser/
mkdir -p app
mkdir -p infra
mkdir -p domain/template
mkdir -p domain/tags
mkdir -p domain/fx
mkdir -p ui/state
mkdir -p ui/config
mkdir -p ui/views/modals
mkdir -p tests/domain
mkdir -p tests/infra
```

**Action Items**:
- [ ] CREATE: All new directories
- [ ] COMMIT: "Create canonical folder structure"

---

### 2.3 Phase 3: Move Core → App

**Status**: ⬜

**Files to move**:

| Current | New | Notes |
|---------|-----|-------|
| `core/config.lua` | `app/config.lua` | Static configuration |
| `core/state.lua` | `app/state.lua` | State container (already exists?) |

**Re-exports for backward compat**:

```lua
-- core/config.lua (keep temporarily)
-- @deprecated TEMP_PARITY_SHIM: Moved to app/config.lua
-- EXPIRES: After Phase 5 cleanup
return require("TemplateBrowser.app.config")
```

**Action Items**:
- [ ] MOVE: `core/config.lua` → `app/config.lua`
- [ ] CREATE: `core/config.lua` re-export shim
- [ ] IF NEEDED: Merge `app/state.lua` with `core/state.lua` (see 1.2)
- [ ] CREATE: `core/state.lua` re-export shim
- [ ] TEST: All requires still work
- [ ] COMMIT: "Move core/config and core/state to app/"

---

### 2.4 Phase 4: Move UI Concerns (Core → UI)

**Status**: ⬜

**Files to move**:

| Current | New | Notes |
|---------|-----|-------|
| `core/shortcuts.lua` | `ui/shortcuts.lua` | Keyboard shortcuts (UI concern) |
| `core/tooltips.lua` | `ui/tooltips.lua` | Tooltip state (UI concern) |

**Action Items**:
- [ ] MOVE: `core/shortcuts.lua` → `ui/shortcuts.lua`
- [ ] MOVE: `core/tooltips.lua` → `ui/tooltips.lua`
- [ ] CREATE: Re-export shims in `core/`
- [ ] UPDATE: All files that require these (search codebase)
- [ ] TEST: Shortcuts and tooltips work
- [ ] COMMIT: "Move UI concerns from core/ to ui/"

---

### 2.5 Phase 5: Move Domain → Infra (I/O Operations)

**Status**: ⬜

**These are in `domain/` but perform I/O, should be in `data/`**:

| Current | New | Rename? |
|---------|-----|---------|
| `domain/persistence.lua` | `data/storage.lua` | Yes (rename to match convention) |
| `domain/undo.lua` | `data/undo.lua` | No |
| `domain/file_ops.lua` | `data/file_ops.lua` | No |

**Note**: Re-export shims ALREADY EXIST!
- `domain/persistence.lua` → Already re-exports `data/storage.lua` ✅
- `domain/undo.lua` → Already re-exports `data/undo.lua` ✅
- `domain/file_ops.lua` → Already re-exports `data/file_ops.lua` ✅

**Action Items**:
- [ ] VERIFY: Files are actually in `data/` (check filesystem)
- [ ] IF NOT: Move them now
- [ ] UPDATE: All `require()` statements to use `data.*` not `domain.*`
- [ ] GREP: Find all `require.*domain\.persistence` → change to `data.storage`
- [ ] GREP: Find all `require.*domain\.undo` → change to `data.undo`
- [ ] GREP: Find all `require.*domain\.file_ops` → change to `data.file_ops`
- [ ] TEST: All file operations work
- [ ] COMMIT: "Complete domain → data migration for I/O modules"

---

### 2.6 Phase 6: Reorganize Domain Folders

**Status**: ⬜

**Group by business entity**:

| Current | New | Notes |
|---------|-----|-------|
| `domain/scanner.lua` | `domain/template/scanner.lua` | Already re-exported ✅ |
| `domain/template_ops.lua` | `domain/template/ops.lua` | Already re-exported ✅ |
| `domain/tags.lua` | `domain/tags/service.lua` | Needs re-export |
| `domain/fx_parser.lua` | `domain/fx/parser.lua` | Needs re-export |
| `domain/fx_queue.lua` | `domain/fx/queue.lua` | Needs re-export |

**Note**: Some re-exports already exist! Verify and complete.

**Action Items**:
- [ ] VERIFY: Which moves are already done (check re-exports)
- [ ] MOVE: `domain/tags.lua` → `domain/tags/service.lua`
- [ ] MOVE: `domain/fx_parser.lua` → `domain/fx/parser.lua`
- [ ] MOVE: `domain/fx_queue.lua` → `domain/fx/queue.lua`
- [ ] CREATE: Re-export shims for moved files
- [ ] UPDATE: All `require()` statements to new paths
- [ ] TEST: All domain operations work
- [ ] COMMIT: "Reorganize domain/ by business entity"

---

### 2.7 Phase 7: Reorganize UI Folders

**Status**: ⬜

**Main files**:

| Current | New | Notes |
|---------|-----|-------|
| `ui/gui.lua` | `ui/init.lua` | Rename to convention |
| `ui/status_bar.lua` | `ui/status.lua` | Simplify name |

**Config files**:

| Current | New |
|---------|-----|
| `ui/ui_constants.lua` | `ui/config/constants.lua` |
| `ui/left_panel_config.lua` | `ui/config/left_panel.lua` |
| `ui/template_container_config.lua` | `ui/config/template.lua` |
| `ui/info_panel_config.lua` | `ui/config/info.lua` |
| `ui/convenience_panel_config.lua` | `ui/config/convenience.lua` |
| `ui/recent_panel_config.lua` | `ui/config/recent.lua` |

**Views** (remove `_view` suffix):

| Current | New |
|---------|-----|
| `views/tree_view.lua` | `views/tree.lua` |
| `views/template_panel_view.lua` | `views/template_panel.lua` |
| `views/info_panel_view.lua` | `views/info_panel.lua` |
| `views/left_panel_view.lua` | `views/left_panel/init.lua` |
| `views/convenience_panel_view.lua` | `views/convenience/init.lua` |
| `views/template_modals_view.lua` | `views/modals/template.lua` |

**Tiles** (simplify names):

| Current | New |
|---------|-----|
| `tiles/template_grid_factory.lua` | `tiles/factory.lua` |
| `tiles/template_tile.lua` | `tiles/tile.lua` |
| `tiles/template_tile_compact.lua` | `tiles/tile_compact.lua` |

**Tab files** (remove `_tab` suffix):

| Current | New |
|---------|-----|
| `views/left_panel/directory_tab.lua` | `views/left_panel/directory.lua` |
| `views/left_panel/tags_tab.lua` | `views/left_panel/tags.lua` |
| `views/left_panel/vsts_tab.lua` | `views/left_panel/vsts.lua` |
| `views/convenience_panel/tags_tab.lua` | `views/convenience/tags.lua` |
| `views/convenience_panel/vsts_tab.lua` | `views/convenience/vsts.lua` |

**Action Items**:
- [ ] MOVE: All main files (gui.lua, status_bar.lua)
- [ ] MOVE: All config files to `ui/config/`
- [ ] MOVE: All view files (rename, remove suffixes)
- [ ] MOVE: All tile files (simplify names)
- [ ] MOVE: All tab files (remove `_tab` suffix)
- [ ] CREATE: Re-export shims for ALL old locations
- [ ] UPDATE: All `require()` statements
- [ ] TEST: Full UI renders correctly
- [ ] COMMIT: "Reorganize ui/ folder structure"

---

### 2.8 Phase 8: Create New Bootstrap File

**Status**: ⬜

**Create**: `app/init.lua`

```lua
-- @noindex
-- TemplateBrowser/app/init.lua
-- Application bootstrap and dependency injection

local M = {}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
M.config = require('TemplateBrowser.app.config')

-- ============================================================================
-- STATE
-- ============================================================================
M.state = require('TemplateBrowser.app.state')

-- ============================================================================
-- DOMAIN SERVICES
-- ============================================================================
M.template = {
  scanner = require('TemplateBrowser.domain.template.scanner'),
  ops = require('TemplateBrowser.domain.template.ops'),
}

M.tags = require('TemplateBrowser.domain.tags.service')

M.fx = {
  parser = require('TemplateBrowser.domain.fx.parser'),
  queue = require('TemplateBrowser.domain.fx.queue'),
}

-- ============================================================================
-- DATA LAYER
-- ============================================================================
M.data = {
  storage = require('TemplateBrowser.data.storage'),
  undo = require('TemplateBrowser.data.undo'),
  file_ops = require('TemplateBrowser.data.file_ops'),
}

-- ============================================================================
-- UI
-- ============================================================================
M.ui = require('TemplateBrowser.ui.init')

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--- Initialize application state
function M.initialize()
  M.state.initialize(M.config)
end

--- Create GUI instance
function M.create_gui()
  return M.ui.new(M.config, M.state, M.template.scanner)
end

return M
```

**Then update**: `ARK_TemplateBrowser.lua`

```lua
-- Load TemplateBrowser modules
local App = require('TemplateBrowser.app.init')

-- Initialize state
App.initialize()

-- Create GUI instance
local gui = App.create_gui()

-- Run in overlay mode
Shell.run({
  -- ... rest unchanged
  draw = function(ctx, state)
    -- Incremental scanner (unchanged)
    if not App.state.scan_complete then
      if not App.state.scan_in_progress then
        App.state.scan_in_progress = true
        App.template.scanner.scan_init(App.state)
      else
        local complete = App.template.scanner.scan_batch(App.state, 50)
        if complete then
          App.state.scan_complete = true
          App.state.scan_in_progress = false
        end
      end
    end

    if gui and gui.draw then
      gui:draw(ctx, {
        fonts = state.fonts,
        overlay_state = state.overlay,
        overlay = { alpha = { value = function() return state.overlay.alpha end } },
        is_overlay_mode = true,
      })
    end
  end,

  on_close = function()
    App.state.cleanup()
  end,
})
```

**Action Items**:
- [ ] CREATE: `app/init.lua` with bootstrap logic
- [ ] EDIT: `ARK_TemplateBrowser.lua` to use App.init
- [ ] TEST: Application starts and runs correctly
- [ ] COMMIT: "Add app/init.lua bootstrap module"

---

### 2.9 Phase 9: Extract UI State

**Status**: ⬜

**Create**: `ui/state/preferences.lua`

Extract UI-specific state from `app/state.lua`:
- Panel ratios (separator1_ratio, separator2_ratio, etc.)
- View modes (template_view_mode, quick_access_view_mode)
- Tile widths (grid_tile_width, list_tile_width)
- Tab selections (left_panel_tab, convenience_panel_tab)

**Example**:

```lua
-- @noindex
-- TemplateBrowser/ui/state/preferences.lua
-- UI preferences (layout, view modes, display options)

local M = {}

M.defaults = {
  -- Panel layout
  separator1_ratio = 0.22,  -- Left column width ratio
  separator2_ratio = 0.72,  -- Left+middle width ratio
  explorer_height_ratio = 0.6,  -- Explorer vs tags panel height
  quick_access_separator_position = 350,  -- Main grid height (px)
  left_panel_separator_ratio = 0.65,  -- Explorer/convenience split

  -- View modes
  template_view_mode = "grid",  -- "grid" | "list"
  quick_access_view_mode = "grid",  -- "grid" | "list"

  -- Tile sizes
  grid_tile_width = 180,  -- Grid mode tile width
  list_tile_width = 450,  -- List mode tile width

  -- Active tabs
  left_panel_tab = "directory",  -- "directory" | "vsts" | "tags"
  convenience_panel_tab = "tags",  -- "tags" | "vsts"

  -- Sort/filter
  sort_mode = "alphabetical",  -- "alphabetical" | "usage" | "insertion" | "color"
  quick_access_mode = "recents",  -- "recents" | "favorites" | "most_used"
  quick_access_sort = "alphabetical",  -- "alphabetical" | "color" | "insertion"
}

--- Apply preferences to state
function M.apply_to_state(state, config)
  for key, default_value in pairs(M.defaults) do
    if state[key] == nil then
      state[key] = config.TILE and config.TILE[key:upper()] or default_value
    end
  end
end

return M
```

**Then update** `app/state.lua` to delegate:

```lua
function M.initialize(config)
  -- ... existing init ...

  -- Apply UI preferences
  local Preferences = require('TemplateBrowser.ui.state.preferences')
  Preferences.apply_to_state(M, config)
end
```

**Action Items**:
- [ ] CREATE: `ui/state/preferences.lua`
- [ ] EXTRACT: UI-specific state fields from `app/state.lua`
- [ ] UPDATE: `app/state.lua` to use preferences module
- [ ] TEST: All UI state works correctly
- [ ] COMMIT: "Extract UI preferences to ui/state/preferences.lua"

---

### 2.10 Phase 10: Cleanup

**Status**: ⬜

**After confirming everything works**:

**Delete re-export shims** (ONLY after all requires updated):
- [ ] DELETE: `core/config.lua` (shim)
- [ ] DELETE: `core/state.lua` (shim)
- [ ] DELETE: `core/shortcuts.lua` (shim)
- [ ] DELETE: `core/tooltips.lua` (shim)
- [ ] DELETE: `domain/persistence.lua` (shim)
- [ ] DELETE: `domain/undo.lua` (shim)
- [ ] DELETE: `domain/file_ops.lua` (shim)
- [ ] DELETE: `domain/scanner.lua` (shim)
- [ ] DELETE: `domain/template_ops.lua` (shim)
- [ ] DELETE: `domain/tags.lua` (shim)
- [ ] DELETE: `domain/fx_parser.lua` (shim)
- [ ] DELETE: `domain/fx_queue.lua` (shim)
- [ ] DELETE: All `ui/` re-export shims

**Delete empty folders**:
- [ ] DELETE: `core/` folder (should be empty)

**Verify**:
- [ ] RUN: `find . -name "*.lua" -exec grep -l "require.*TemplateBrowser\.core\." {} \;`
  - Should return ZERO results
- [ ] RUN: `find . -name "*.lua" -exec grep -l "require.*\.domain\.persistence" {} \;`
  - Should return ZERO results

**Final commit**:
- [ ] COMMIT: "Remove migration shims and empty folders"

---

## Priority 3: Code Quality Improvements

**Goal**: Address minor issues found in code review.

### 3.1 Replace Console Logging with Logger Framework

**Impact**: Medium | **Effort**: Medium | **Status**: ⬜

**Problem**: Production code has verbose console logging (50+ occurrences in scanner.lua alone).

**Current**:
```lua
reaper.ShowConsoleMsg("FX: File changed (size): " .. template_name .. "\n")
reaper.ShowConsoleMsg("New template UUID: " .. template_name .. " -> " .. uuid .. "\n")
```

**Should be**:
```lua
local Logger = require('arkitekt.debug.logger')
local log = Logger.new("TemplateBrowser.Scanner")

log:debug("File changed (size): %s (%d -> %d)", template_name, old_size, new_size)
log:info("New template UUID: %s -> %s", template_name, uuid)
```

**Benefits**:
- Centralized logging control
- Log levels (debug, info, warn, error)
- Opt-in debug mode (not always spamming console)
- Better formatting

**Files to update**:
- [ ] `domain/template/scanner.lua` (~20 occurrences)
- [ ] `data/storage.lua` (persistence logging)
- [ ] Any other files using `reaper.ShowConsoleMsg` for debug

**Action Items**:
- [ ] ADD: Logger requires to affected files
- [ ] REPLACE: All `reaper.ShowConsoleMsg` debug statements
- [ ] KEEP: User-facing errors as dialogs (reaper.MB)
- [ ] TEST: Logging works, can be controlled
- [ ] COMMIT: "Replace console logging with Logger framework"

---

### 3.2 Add Error Handling to Template Operations

**Impact**: Low | **Effort**: Low | **Status**: ⬜

**Location**: `domain/template/ops.lua:28-35`

**Problem**: `apply_to_selected_track` silently fails if template file can't be opened, while `insert_as_new_track` shows error dialog.

**Current**:
```lua
local f = io.open(chunk_file, "r")
if f then
  chunk = f:read("*all")
  f:close()
  reaper.SetTrackStateChunk(track, chunk, false)
end
-- ↑ Just silently does nothing if file doesn't exist
```

**Should be**:
```lua
local f = io.open(chunk_file, "r")
if not f then
  reaper.MB("Could not read template file: " .. chunk_file, "Template Browser", 0)
  -- Also set error status
  if state then
    state.set_status("Failed to read template file", "error")
  end
  return false
end

chunk = f:read("*all")
f:close()
reaper.SetTrackStateChunk(track, chunk, false)
```

**Action Items**:
- [ ] EDIT: `domain/template/ops.lua` - Add error handling to `apply_to_selected_track`
- [ ] TEST: Try applying nonexistent template, verify error shown
- [ ] COMMIT: "Add error handling to apply_to_selected_track"

---

### 3.3 Implement Status Message Auto-Clear

**Impact**: Low | **Effort**: Low | **Status**: ⬜

**Location**: `app/state.lua:145-149` and `ui/status_bar.lua`

**Problem**: Status timestamp is set but never checked for auto-clear.

**Current**:
```lua
-- app/state.lua
function M.set_status(message, msg_type)
  M.status_message = message or ""
  M.status_type = msg_type or "info"
  M.status_timestamp = reaper.time_precise()  -- ← Set but never used
end
```

**Solution**: In `ui/status_bar.lua` (or `ui/status.lua` after migration):

```lua
local STATUS_AUTO_CLEAR_TIME = 5.0  -- Seconds (move to defs/constants.lua)

function M.draw(ctx, state, width, height)
  -- Auto-clear old messages
  if state.status_message ~= "" and state.status_timestamp > 0 then
    local elapsed = reaper.time_precise() - state.status_timestamp
    if elapsed > STATUS_AUTO_CLEAR_TIME then
      state.clear_status()
    end
  end

  -- ... rest of draw code
end
```

**Action Items**:
- [ ] ADD: Auto-clear constant to `defs/constants.lua`
- [ ] EDIT: `ui/status_bar.lua` - Implement auto-clear check
- [ ] TEST: Set status message, verify it clears after 5 seconds
- [ ] COMMIT: "Implement status message auto-clear"

**Alternative**: Remove timestamp if auto-clear not desired.

---

### 3.4 Clean Up Unused State Fields

**Impact**: Low | **Effort**: Low | **Status**: ⬜

**Location**: `app/state.lua:67-68`

**Problem**: `M.overlay_alpha` appears to be set but never used.

**Investigation needed**:
```bash
# Search for usage
grep -r "overlay_alpha" scripts/TemplateBrowser/
```

**If unused**:
- [ ] DELETE: `M.overlay_alpha` field from state
- [ ] VERIFY: No errors/warnings after removal
- [ ] COMMIT: "Remove unused overlay_alpha field"

**If used**:
- [ ] KEEP: Field
- [ ] DOCUMENT: Add comment explaining usage

---

### 3.5 Consistent Require Style

**Impact**: Low | **Effort**: Low | **Status**: ⬜

**Problem**: Mixed require styles throughout codebase.

**Current**:
```lua
local ImGui = require 'imgui' '0.10'  -- Lua-style
local ark = require('arkitekt')  -- Paren-style
```

**Convention**: Use parentheses consistently.

**Action Items**:
- [ ] GREP: Find all `require '` and `require "` patterns
- [ ] REPLACE: With `require('...')` or `require("...")`
- [ ] PREFER: Single quotes `require('module')` (ARKITEKT convention)
- [ ] COMMIT: "Normalize require statement style"

---

## Priority 4: Polish & Documentation

**Goal**: Improve code readability and maintainability.

### 4.1 Add Function Docstrings

**Impact**: Medium | **Effort**: Medium | **Status**: ⬜

**Focus on complex functions** (>100 lines, complex logic):

**Examples**:

```lua
-- domain/template/scanner.lua

--- Filter templates by folder, search query, FX, and tags.
--- All filters use AND logic (template must match ALL active filters).
--- Multi-select folders are supported (template matches ANY selected folder).
--- @param state table Application state containing:
---   - templates: All templates to filter
---   - search_query: Text search (substring match)
---   - filter_tags: Active tag filters (tag_name -> true)
---   - filter_fx: Active FX filters (fx_name -> true)
---   - selected_folder: Primary selected folder
---   - selected_folders: Multi-select folders (path -> true)
---   - metadata: Template metadata (for tags, virtual folders)
--- @return nil Updates state.filtered_templates in-place
function M.filter_templates(state)
  -- ... implementation
end

--- Scan a batch of templates incrementally (non-blocking).
--- Call this each frame until it returns true.
--- @param state table Application state to update
--- @param batch_size number? Number of files to scan per call (default: 50)
--- @return boolean True when scan is complete, false if more work remains
function M.scan_batch(state, batch_size)
  -- ... implementation
end
```

**Files to document**:
- [ ] `domain/template/scanner.lua`:
  - [ ] `filter_templates()` (240 lines, complex filtering)
  - [ ] `scan_batch()` (incremental scanning logic)
  - [ ] `scan_init()` (setup)
- [ ] `ui/init.lua`:
  - [ ] `GUI:draw()` (332 lines, main render loop)
  - [ ] `GUI:initialize_once()` (initialization logic)
- [ ] `data/storage.lua`:
  - [ ] `json_encode()` (custom JSON encoder)
  - [ ] `json_decode()` (custom JSON decoder)

**Action Items**:
- [ ] ADD: LuaCATS-style docstrings to major functions
- [ ] DOCUMENT: Complex algorithms and filter logic
- [ ] COMMIT: "Add docstrings to complex functions"

---

### 4.2 Break Up Long Functions

**Impact**: Medium | **Effort**: High | **Status**: ⬜

**Candidates**:

**1. `ui/init.lua:581-913` - `GUI:draw()` (332 lines)**

Extract:
- Loading screen logic → `GUI:draw_loading_screen(ctx, window_width, window_height)`
- Conflict resolution → `GUI:process_conflict_resolution()`
- Keyboard shortcuts → `GUI:process_shortcuts(ctx)`
- Separator handling → `GUI:update_separators(ctx, ...)`

**2. `domain/template/scanner.lua:296-536` - `filter_templates()` (240 lines)**

Extract:
- Virtual folder logic → `local function check_virtual_folder(state, template, folder_path)`
- Physical folder logic → `local function check_physical_folder(template, folder_path, escaped_paths)`
- Sorting logic → `local function apply_sort(templates, sort_mode, metadata)`

**Action Items**:
- [ ] EXTRACT: Loading screen from `GUI:draw()`
- [ ] EXTRACT: Conflict resolution from `GUI:draw()`
- [ ] EXTRACT: Keyboard shortcuts from `GUI:draw()`
- [ ] EXTRACT: Separator handling from `GUI:draw()`
- [ ] EXTRACT: Virtual folder check from `filter_templates()`
- [ ] EXTRACT: Physical folder check from `filter_templates()`
- [ ] EXTRACT: Sort logic from `filter_templates()`
- [ ] TEST: All functionality works identically
- [ ] COMMIT: "Refactor long functions into smaller units"

---

### 4.3 Move Batch Size to Constants

**Impact**: Low | **Effort**: Low | **Status**: ⬜

**Location**: `ui/init.lua:643`

```lua
FXQueue.process_batch(self.state, 5)  -- ← Magic number
```

**Solution**: `defs/constants.lua`

```lua
M.FX_QUEUE = {
  BATCH_SIZE = 5,  -- Templates per frame for FX parsing
}
```

**Then**:
```lua
FXQueue.process_batch(self.state, config.FX_QUEUE.BATCH_SIZE)
```

**Also applies to**:
- Scanner batch size (50 files/frame) in `ARK_TemplateBrowser.lua:47`

**Action Items**:
- [ ] ADD: `FX_QUEUE.BATCH_SIZE` to `defs/constants.lua`
- [ ] ADD: `SCANNER.BATCH_SIZE` to `defs/constants.lua`
- [ ] UPDATE: All hardcoded batch sizes
- [ ] COMMIT: "Move batch sizes to constants"

---

## Priority 5: Future Enhancements

**Goal**: Optional improvements for later (not ship-blocking).

### 5.1 Virtual Scrolling for Large Libraries

**Impact**: High (for 1000+ templates) | **Effort**: High | **Status**: ⬜

**Problem**: Currently renders all filtered templates. With 1000+ templates, this can impact performance.

**Solution**: Implement virtual scrolling in grid (only render visible tiles).

**Reference**: See `arkitekt/gui/widgets/data/media_grid.lua` for pattern.

**Defer**: Post-migration cleanup.

---

### 5.2 Template Thumbnail Generation

**Impact**: Medium (UX) | **Effort**: High | **Status**: ⬜

**Idea**: Generate visual previews of track templates (similar to FX chain screenshots).

**Challenges**:
- REAPER doesn't provide template preview API
- Would need to parse template chunk and render custom preview
- Caching required

**Defer**: Feature request, not priority.

---

### 5.3 Cloud Sync for Metadata

**Impact**: Medium (multi-machine users) | **Effort**: High | **Status**: ⬜

**Idea**: Sync favorites, tags, notes across machines via cloud (Dropbox, Google Drive, etc.)

**Requirements**:
- Conflict resolution
- Merge strategy
- User opt-in

**Defer**: Feature request.

---

### 5.4 Import/Export Metadata

**Impact**: Medium | **Effort**: Medium | **Status**: ⬜

**Idea**: Export/import tags and metadata as JSON for backup or sharing.

**Simple implementation**:
```lua
-- Already have JSON encoder in data/storage.lua
-- Just need UI buttons and file picker
function M.export_metadata(path)
  local Storage = require('TemplateBrowser.data.storage')
  Storage.save_metadata_to_path(metadata, path)
end
```

**Action Items** (later):
- [ ] ADD: "Export Metadata" button
- [ ] ADD: "Import Metadata" button
- [ ] IMPLEMENT: File picker dialog
- [ ] HANDLE: Merge conflicts on import

---

## Migration Checklist

**Track progress through migration phases**:

### Files Moved (from MIGRATION_PLANS.md)

| # | Current Path | New Path | Status |
|---|--------------|----------|--------|
| 1 | `core/config.lua` | `app/config.lua` | ⬜ |
| 2 | `core/state.lua` | `app/state.lua` | ⬜ |
| 3 | `core/shortcuts.lua` | `ui/shortcuts.lua` | ⬜ |
| 4 | `core/tooltips.lua` | `ui/tooltips.lua` | ⬜ |
| 5 | `domain/persistence.lua` | `data/storage.lua` | ⬜ *(shim exists)* |
| 6 | `domain/undo.lua` | `data/undo.lua` | ⬜ *(shim exists)* |
| 7 | `domain/file_ops.lua` | `data/file_ops.lua` | ⬜ *(shim exists)* |
| 8 | `domain/scanner.lua` | `domain/template/scanner.lua` | ⬜ *(shim exists)* |
| 9 | `domain/template_ops.lua` | `domain/template/ops.lua` | ⬜ *(shim exists)* |
| 10 | `domain/tags.lua` | `domain/tags/service.lua` | ⬜ |
| 11 | `domain/fx_parser.lua` | `domain/fx/parser.lua` | ⬜ |
| 12 | `domain/fx_queue.lua` | `domain/fx/queue.lua` | ⬜ |
| 13 | `ui/gui.lua` | `ui/init.lua` | ⬜ |
| 14 | `ui/status_bar.lua` | `ui/status.lua` | ⬜ |
| 15 | `ui/ui_constants.lua` | `ui/config/constants.lua` | ⬜ |
| 16 | `ui/left_panel_config.lua` | `ui/config/left_panel.lua` | ⬜ |
| 17 | `ui/template_container_config.lua` | `ui/config/template.lua` | ⬜ |
| 18 | `ui/info_panel_config.lua` | `ui/config/info.lua` | ⬜ |
| 19 | `ui/convenience_panel_config.lua` | `ui/config/convenience.lua` | ⬜ |
| 20 | `ui/recent_panel_config.lua` | `ui/config/recent.lua` | ⬜ |
| 21 | `ui/views/tree_view.lua` | `ui/views/tree.lua` | ⬜ |
| 22 | `ui/views/left_panel_view.lua` | `ui/views/left_panel/init.lua` | ⬜ |
| 23 | `ui/views/template_panel_view.lua` | `ui/views/template_panel.lua` | ⬜ |
| 24 | `ui/views/info_panel_view.lua` | `ui/views/info_panel.lua` | ⬜ |
| 25 | `ui/views/convenience_panel_view.lua` | `ui/views/convenience/init.lua` | ⬜ |
| 26 | `ui/views/template_modals_view.lua` | `ui/views/modals/template.lua` | ⬜ |
| 27 | `ui/tiles/template_grid_factory.lua` | `ui/tiles/factory.lua` | ⬜ |
| 28 | `ui/tiles/template_tile.lua` | `ui/tiles/tile.lua` | ⬜ |
| 29 | `ui/tiles/template_tile_compact.lua` | `ui/tiles/tile_compact.lua` | ⬜ |
| 30 | `views/left_panel/directory_tab.lua` | `views/left_panel/directory.lua` | ⬜ |
| 31 | `views/left_panel/tags_tab.lua` | `views/left_panel/tags.lua` | ⬜ |
| 32 | `views/left_panel/vsts_tab.lua` | `views/left_panel/vsts.lua` | ⬜ |
| 33 | `views/convenience_panel/tags_tab.lua` | `views/convenience/tags.lua` | ⬜ |
| 34 | `views/convenience_panel/vsts_tab.lua` | `views/convenience/vsts.lua` | ⬜ |

### New Files Created

| # | Path | Purpose | Status |
|---|------|---------|--------|
| 1 | `app/init.lua` | Bootstrap, dependency injection | ⬜ |
| 2 | `ui/state/preferences.lua` | UI-specific state | ⬜ |
| 3 | `defs/layout.lua` | Layout constants | ⬜ |
| 4 | `ui/tiles/helpers.lua` | Grid callback factory (deduplication) | ⬜ |

### Folders to Delete

| Folder | Reason | Status |
|--------|--------|--------|
| `core/` | Empty after migration to app/ui | ⬜ |

---

## Summary Progress

**Overall Migration**: 0 / 38 files moved
**New Files**: 0 / 4 created
**Refactoring**: 0 / 4 critical items complete

**Completion Criteria**:
- ✅ All Priority 1 refactoring complete
- ✅ All files migrated to canonical structure
- ✅ All re-export shims removed
- ✅ `core/` folder deleted
- ✅ Application runs without errors
- ✅ All tests pass (if tests exist)

---

## References

- [cookbook/MIGRATION_PLANS.md](../../cookbook/MIGRATION_PLANS.md) - Master migration plan
- [cookbook/CONVENTIONS.md](../../cookbook/CONVENTIONS.md) - Coding standards
- [cookbook/PROJECT_STRUCTURE.md](../../cookbook/PROJECT_STRUCTURE.md) - Architecture guide
- [Code Review](./REVIEW.md) - Detailed code review (this document is based on it)

---

## Notes

### Deviations from Migration Plan

None so far - structure closely matches planned architecture.

### Custom Patterns

1. **Grid callback factory**: Not in migration plan, but critical for reducing duplication
2. **Layout constants**: Recommended addition to clean up magic numbers
3. **Bootstrap file**: Migration plan suggests `app/init.lua`, we're following that

### Migration Tips

1. **Always keep app working**: Use re-export shims during migration
2. **One file at a time**: Move, test, commit
3. **Update requires as you go**: Don't batch all updates at end
4. **Test between phases**: Catch issues early
5. **Use grep**: Find all require statements before deleting shims

---

*Last Updated: 2025-11-27*
*Rating: 8.5/10 → Target: 9.5/10*
