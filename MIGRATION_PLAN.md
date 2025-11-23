# Migration Plan: arkitekt → arkitekt

This document outlines the step-by-step plan to migrate from `arkitekt` to `arkitekt` naming and restructure the project according to the release strategy.

## Overview

**Goal:** Transform the project into a professional, community-ready toolkit with:
- Consistent naming: `arkitekt` (lowercase)
- Clear structure: `arkitekt/` (library) + `apps/` (examples)
- Standardized imports: `require("arkitekt.MODULE")`
- Hub application: `ARKITEKT.lua` central launcher

**Breaking Change:** Yes - This is a MAJOR version bump (0.2.0 → 1.0.0)

---

## Pre-Migration Checklist

Before starting, ensure:
- [ ] All current changes committed to git
- [ ] Backup created (just in case)
- [ ] Team aligned on naming decision
- [ ] CHANGELOG.md updated with breaking change notice
- [ ] Version bumped to 1.0.0 in all relevant files

```bash
# Create backup branch
git checkout -b backup/pre-arkitekt-migration
git push origin backup/pre-arkitekt-migration

# Create migration branch
git checkout main
git checkout -b refactor/migrate-to-arkitekt
```

---

## Phase 1: Directory Restructure (Estimated: 2 hours)

### Step 1.1: Rename Core Library Directory

```bash
cd ARKITEKT/
mv arkitekt arkitekt
```

**Result:**
```
ARKITEKT/
├── arkitekt/          # ✅ Renamed from arkitekt
├── scripts/           # To be restructured next
└── ...
```

### Step 1.2: Create Apps Directory & Move Scripts

```bash
# Create apps directory
mkdir -p apps

# Move applications (rename to snake_case)
mv scripts/ItemPicker apps/item_picker
mv scripts/ColorPalette apps/color_palette
mv scripts/RegionPlaylist apps/region_playlist
mv scripts/TemplateBrowser apps/template_browser
mv scripts/ThemeAdjuster apps/theme_adjuster

# Move demos and sandbox to dev directory
mkdir -p dev
mv scripts/demos dev/demos
mv scripts/Sandbox dev/sandbox

# Clean up old scripts directory
rmdir scripts  # Should be empty now
```

**Result:**
```
ARKITEKT/
├── arkitekt/                  # Core library (renamed)
├── apps/                      # Applications (snake_case)
│   ├── item_picker/
│   ├── color_palette/
│   ├── region_playlist/
│   ├── template_browser/
│   └── theme_adjuster/
├── dev/                       # Development tools
│   ├── demos/
│   └── sandbox/
└── hub/                       # Hub application code
```

### Step 1.3: Move Entry Point Scripts

```bash
# Entry points stay at top level, rename to match snake_case apps
mv ARK_ItemPicker.lua ARK_ItemPicker.lua.backup
mv ARK_ColorPalette.lua ARK_ColorPalette.lua.backup
mv ARK_RegionPlaylist.lua ARK_RegionPlaylist.lua.backup
mv ARK_TemplateBrowser.lua ARK_TemplateBrowser.lua.backup
mv ARK_ThemeAdjuster.lua ARK_ThemeAdjuster.lua.backup

# Will recreate these with new require paths
```

---

## Phase 2: Update Require Paths (Estimated: 4-6 hours)

This is the most time-consuming step. We need to update all `require()` statements.

### Step 2.1: Pattern Identification

**Before:**
```lua
require("arkitekt.core.colors")
require("arkitekt.gui.widgets.button")
require("ItemPicker.core.state")
```

**After:**
```lua
require("arkitekt.core.colors")
require("arkitekt.gui.widgets.button")
require("arkitekt.apps.item_picker.core.state")
```

### Step 2.2: Automated Find & Replace

**Core Library Requires:**
```bash
# Find all lua files
find ARKITEKT/arkitekt -type f -name "*.lua" -exec sed -i 's/require("arkitekt\./require("arkitekt./g' {} +

# Or on macOS
find ARKITEKT/arkitekt -type f -name "*.lua" -exec sed -i '' 's/require("arkitekt\./require("arkitekt./g' {} +
```

**App Requires (more complex - do per app):**

```bash
# Example for item_picker
cd ARKITEKT/apps/item_picker

# Update internal requires to use full path
find . -type f -name "*.lua" -exec sed -i 's/require("ItemPicker\./require("arkitekt.apps.item_picker./g' {} +

# Update arkitekt library requires
find . -type f -name "*.lua" -exec sed -i 's/require("arkitekt\./require("arkitekt./g' {} +
```

**Repeat for all apps:**
```bash
# color_palette
find ARKITEKT/apps/color_palette -type f -name "*.lua" -exec sed -i 's/require("ColorPalette\./require("arkitekt.apps.color_palette./g' {} +

# region_playlist
find ARKITEKT/apps/region_playlist -type f -name "*.lua" -exec sed -i 's/require("RegionPlaylist\./require("arkitekt.apps.region_playlist./g' {} +

# template_browser
find ARKITEKT/apps/template_browser -type f -name "*.lua" -exec sed -i 's/require("TemplateBrowser\./require("arkitekt.apps.template_browser./g' {} +

# theme_adjuster
find ARKITEKT/apps/theme_adjuster -type f -name "*.lua" -exec sed -i 's/require("ThemeAdjuster\./require("arkitekt.apps.theme_adjuster./g' {} +
```

### Step 2.3: Manual Review (Critical!)

**Automated replacement may miss:**
- String concatenations: `"arkitekt." .. module_name`
- Dynamic requires: `require(module_path_var)`
- Comments and documentation

**Review:**
```bash
# Search for any remaining "arkitekt" references
grep -r "arkitekt" ARKITEKT/arkitekt/ ARKITEKT/apps/

# Search for old app names in requires
grep -r 'require("ItemPicker' ARKITEKT/apps/
grep -r 'require("ColorPalette' ARKITEKT/apps/
grep -r 'require("RegionPlaylist' ARKITEKT/apps/
```

Fix any remaining references manually.

---

## Phase 3: Update Entry Point Scripts (Estimated: 1 hour)

Recreate launcher scripts with new require paths.

### Step 3.1: ARK_ItemPicker.lua

```lua
-- @description ARKITEKT Item Picker
-- @author ARKITEKT Contributors
-- @version 1.0.0
-- @about
--   Visual browser for REAPER media items with search and filtering
--   Part of the ARKITEKT Toolkit

-- Ensure arkitekt library is on the path
local script_path = debug.getinfo(1, "S").source:match([[^@?(.*[\/])[^\/]-$]])
package.path = package.path .. ";" .. script_path .. "?.lua"
package.path = package.path .. ";" .. script_path .. "?/init.lua"

-- Launch ItemPicker app
require("arkitekt.apps.item_picker.init")
```

### Step 3.2: Create Template for Other Launchers

Repeat pattern for:
- `ARK_ColorPalette.lua` → `arkitekt.apps.color_palette.init`
- `ARK_RegionPlaylist.lua` → `arkitekt.apps.region_playlist.init`
- `ARK_TemplateBrowser.lua` → `arkitekt.apps.template_browser.init`
- `ARK_ThemeAdjuster.lua` → `arkitekt.apps.theme_adjuster.init`

### Step 3.3: Update ARKITEKT.lua Hub

```lua
-- @description ARKITEKT Toolkit Hub
-- @author ARKITEKT Contributors
-- @version 1.0.0
-- @about
--   Central hub for ARKITEKT toolkit: theme settings, app launcher, and global preferences

local script_path = debug.getinfo(1, "S").source:match([[^@?(.*[\/])[^\/]-$]])
package.path = package.path .. ";" .. script_path .. "?.lua"
package.path = package.path .. ";" .. script_path .. "?/init.lua"

-- Launch hub application
require("arkitekt.hub.hub")
```

Update `hub/hub.lua` to use `require("arkitekt.*")` paths.

---

## Phase 4: Update Configuration & Documentation (Estimated: 2 hours)

### Step 4.1: Update VSCode Settings

```jsonc
// .vscode/settings.json
{
  "Lua.workspace.library": [
    "${workspaceFolder}/ARKITEKT/arkitekt",  // ← Updated from arkitekt
  ],

  "files.associations": {
    "*.lua": "lua"
  },

  // Update color-coded folders
  "workbench.colorCustomizations": {
    "[Default Dark+]": {
      "activityBar.background": "#1e1e1e",
      "sideBar.background": "#252526",
      "tree.foreground": "#cccccc",

      // Update folder colors to reflect new structure
      "tree.indentGuidesStroke": "#585858"
    }
  },

  "files.exclude": {
    "**/dev/sandbox/": true,  // Hide sandbox from explorer
  }
}
```

### Step 4.2: Update Documentation Files

**Update references in:**
- `README.md` - Change all `arkitekt` → `arkitekt`
- `PROJECT_STRUCTURE.txt` - Regenerate (see Step 4.3)
- `ARKITEKT_Codex_Playbook_v5.md` - Update require examples
- `DOCS_CONFIG_BEST_PRACTICES.md` - Update code examples
- `arkitekt/app/README.md` - Update module paths
- All FLOW documentation in `FLOWS/features/`

**Search & replace pattern:**
```bash
# In all markdown files
find . -name "*.md" -type f -exec sed -i 's/arkitekt/arkitekt/g' {} +
find . -name "*.md" -type f -exec sed -i 's/Arkitekt/arkitekt/g' {} +

# Check for PascalCase app names in docs
grep -r "ItemPicker" --include="*.md"
grep -r "ColorPalette" --include="*.md"
grep -r "RegionPlaylist" --include="*.md"

# Update to snake_case
find . -name "*.md" -type f -exec sed -i 's/ItemPicker/item_picker/g' {} +
find . -name "*.md" -type f -exec sed -i 's/ColorPalette/color_palette/g' {} +
# (and so on for other apps)
```

### Step 4.3: Regenerate PROJECT_STRUCTURE.txt

```bash
# Use tree command or custom script to regenerate
tree ARKITEKT/ -L 4 --dirsfirst > PROJECT_STRUCTURE.txt

# Or use existing generation script if available
```

### Step 4.4: Update ReaPack Index

**Update `index.xml`:**
```xml
<!-- Update package paths -->
<category name="ARKITEKT">
  <reapack name="ARKITEKT_Hub.lua" type="script">
    <version name="1.0.0">
      <source file="ARKITEKT/ARKITEKT.lua">
        <!-- Updated source paths -->
      </source>
      <source file="ARKITEKT/arkitekt/core/colors.lua">
        <!-- Note: arkitekt not arkitekt -->
      </source>
    </version>
  </reapack>
</category>
```

**Regenerate index:**
```bash
reapack-index --commit
```

---

## Phase 5: Testing & Validation (Estimated: 3-4 hours)

### Step 5.1: Static Analysis

```bash
# Check for lua syntax errors
find ARKITEKT -name "*.lua" -type f -exec luac -p {} \;

# Check for remaining old references
echo "Checking for 'arkitekt' references..."
grep -r "arkitekt" ARKITEKT/ || echo "✅ None found"

echo "Checking for old app name patterns..."
grep -r 'require("ItemPicker' ARKITEKT/ || echo "✅ None found"
grep -r 'require("ColorPalette' ARKITEKT/ || echo "✅ None found"
```

### Step 5.2: Manual Testing in REAPER

**Test each launcher:**

1. **ARK_ItemPicker.lua**
   - [ ] Launches without errors
   - [ ] UI renders correctly
   - [ ] Search functionality works
   - [ ] Items load and display
   - [ ] Theme applies correctly

2. **ARK_ColorPalette.lua**
   - [ ] Launches without errors
   - [ ] Color grid renders
   - [ ] Color selection works
   - [ ] Settings persist

3. **ARK_RegionPlaylist.lua**
   - [ ] Launches without errors
   - [ ] Regions load
   - [ ] Playback works
   - [ ] Storage functions work

4. **ARK_TemplateBrowser.lua**
   - [ ] Launches without errors
   - [ ] Templates display
   - [ ] Insertion works

5. **ARK_ThemeAdjuster.lua**
   - [ ] Launches without errors
   - [ ] Theme preview works
   - [ ] Export functionality works

6. **ARKITEKT.lua (Hub)**
   - [ ] Launches without errors
   - [ ] App registry displays
   - [ ] Theme settings work
   - [ ] About/credits show

### Step 5.3: Check REAPER Console

Watch for:
- Missing module errors: `module 'X' not found`
- Nil global errors: `attempt to index nil value`
- Path errors: `no file './arkitekt/...`

**Fix any errors before proceeding.**

---

## Phase 6: Git Commit & Push (Estimated: 30 minutes)

### Step 6.1: Review Changes

```bash
git status
git diff --name-only
```

**Should see:**
- Renamed: `arkitekt/` → `arkitekt/`
- Moved: `scripts/*/` → `apps/*/`
- Modified: All `.lua` files (require paths)
- Modified: Documentation files

### Step 6.2: Commit with Detailed Message

```bash
git add -A

git commit -m "$(cat <<'EOF'
refactor: migrate to arkitekt naming and restructure project

BREAKING CHANGE: Major refactoring for v1.0.0 release

## Directory Changes
- Renamed: arkitekt/ → arkitekt/ (lowercase)
- Moved: scripts/* → apps/* (snake_case)
- Created: dev/ for demos and sandbox
- Standardized: All app directories to snake_case

## Require Path Changes
Before: require("arkitekt.MODULE")
After:  require("arkitekt.MODULE")

Before: require("ItemPicker.MODULE")
After:  require("arkitekt.apps.item_picker.MODULE")

## Apps Renamed
- ItemPicker → item_picker
- ColorPalette → color_palette
- RegionPlaylist → region_playlist
- TemplateBrowser → template_browser
- ThemeAdjuster → theme_adjuster

## Migration Guide
See MIGRATION_PLAN.md for complete details.

Users must update any custom code using old paths.

## Testing
- ✅ All apps tested in REAPER
- ✅ No lua syntax errors
- ✅ No old require paths remaining
- ✅ Documentation updated

Closes #TBD
EOF
)"
```

### Step 6.3: Push to Branch

```bash
git push -u origin refactor/migrate-to-arkitekt
```

### Step 6.4: Create Pull Request

**PR Title:** `[v1.0.0] Migrate to arkitekt naming and restructure project`

**PR Description:**
```markdown
## Summary
Major refactoring to align with release strategy and prepare for v1.0.0 public release.

## Breaking Changes
⚠️ **All require paths have changed**

**Before:**
```lua
require("arkitekt.core.colors")
require("ItemPicker.core.state")
```

**After:**
```lua
require("arkitekt.core.colors")
require("arkitekt.apps.item_picker.core.state")
```

## Changes

### Directory Structure
- `arkitekt/` → `arkitekt/` (lowercase, Lua standard)
- `scripts/ItemPicker/` → `apps/item_picker/` (snake_case)
- `scripts/demos/` → `dev/demos/` (development tools)

### App Naming
All apps now use `snake_case`:
- ItemPicker → item_picker
- ColorPalette → color_palette
- RegionPlaylist → region_playlist
- TemplateBrowser → template_browser
- ThemeAdjuster → theme_adjuster

### Documentation
- All docs updated with new paths
- MIGRATION_PLAN.md added
- CHANGELOG.md updated with breaking changes

## Testing
- [x] All apps tested in REAPER
- [x] Lua syntax validation passed
- [x] No old require paths remaining
- [x] Documentation review completed

## Migration Guide
See `MIGRATION_PLAN.md` for complete step-by-step instructions.

## Checklist
- [x] Directory restructure complete
- [x] All require paths updated
- [x] Entry scripts recreated
- [x] Documentation updated
- [x] Manual testing in REAPER
- [x] Git history clean
```

---

## Phase 7: Post-Migration Cleanup (Estimated: 1 hour)

After PR is merged:

### Step 7.1: Remove Dead Code

```bash
# Delete old ThemeAdjuster directory
git rm -r "ARKITEKT/apps/theme_adjuster/(old)"

# Delete backup entry scripts
git rm ARKITEKT/ARK_*.lua.backup

# Commit cleanup
git commit -m "chore: remove deprecated code and backups"
git push
```

### Step 7.2: Update CHANGELOG

```markdown
## [1.0.0] - 2025-XX-XX

### Changed
- BREAKING: Renamed core library from `arkitekt` to `arkitekt`
- BREAKING: Moved all apps to `apps/` directory with snake_case naming
- BREAKING: All require paths updated to new structure
- Standardized directory naming to snake_case
- Reorganized development tools into `dev/` directory

### Migration
See MIGRATION_PLAN.md for complete migration instructions.
All user code using old require paths must be updated.
```

### Step 7.3: Tag Release

```bash
git tag -a v1.0.0 -m "Release v1.0.0 - arkitekt migration"
git push origin v1.0.0
```

### Step 7.4: Update ReaPack

```bash
# Regenerate index with new version
reapack-index --commit --version 1.0.0

# Push index
git add index.xml
git commit -m "chore: update ReaPack index for v1.0.0"
git push
```

---

## Rollback Plan

If something goes wrong:

```bash
# Return to backup branch
git checkout backup/pre-arkitekt-migration

# Create recovery branch
git checkout -b recovery/rollback-arkitekt

# Cherry-pick any commits you want to keep
git cherry-pick <commit-hash>

# Push recovery branch
git push -u origin recovery/rollback-arkitekt
```

---

## Estimated Timeline

| Phase | Task | Time | Cumulative |
|-------|------|------|------------|
| 1 | Directory restructure | 2 hours | 2 hours |
| 2 | Update require paths | 4-6 hours | 6-8 hours |
| 3 | Update entry scripts | 1 hour | 7-9 hours |
| 4 | Update docs & config | 2 hours | 9-11 hours |
| 5 | Testing & validation | 3-4 hours | 12-15 hours |
| 6 | Git commit & PR | 30 min | 12.5-15.5 hours |
| 7 | Post-migration cleanup | 1 hour | 13.5-16.5 hours |

**Total: 2-3 full work days**

---

## Success Criteria

Migration is complete when:
- [ ] All directories renamed to `arkitekt` and `apps/`
- [ ] All require paths use new structure
- [ ] No references to `arkitekt` remain (except in CHANGELOG)
- [ ] No references to old app names (ItemPicker, etc.) remain
- [ ] All apps launch successfully in REAPER
- [ ] All documentation updated
- [ ] Tests pass (when implemented)
- [ ] ReaPack index regenerated
- [ ] Version tagged as v1.0.0
- [ ] CHANGELOG updated with breaking changes

---

## Communication Plan

**Before migration:**
- [ ] Announce in README that v1.0.0 will have breaking changes
- [ ] Document migration path for users
- [ ] Create GitHub issue for tracking

**During migration:**
- [ ] Update issue with progress
- [ ] Note any unexpected issues

**After migration:**
- [ ] Close migration issue
- [ ] Announce v1.0.0 release
- [ ] Provide migration guide link
- [ ] Update any external references

---

## Questions & Decisions

### Decision Points

**Q: Should we keep backward compatibility with old paths?**
A: No. Clean break for v1.0.0. Users can pin to v0.2.0 if needed.

**Q: What about user scripts using old require paths?**
A: Document clearly in CHANGELOG and provide migration examples.

**Q: Should we create compatibility shims?**
A: No. Would complicate codebase and delay inevitable migration.

**Q: Timeline for migration?**
A: Coordinate with team. Suggest doing on dedicated refactoring sprint.

---

## Next Steps

After migration is complete:

1. **Implement testing** (see TESTING_GUIDE.md)
2. **Fix config merge system** (see DOCS_CONFIG_BEST_PRACTICES.md)
3. **Build hub application** (ARKITEKT.lua)
4. **Create theme manager** (arkitekt/core/theme_manager.lua)
5. **Write contributing guide** (CONTRIBUTING.md) ✅ Done
6. **Prepare for public release**

---

**Ready to begin? Start with Phase 1!**
