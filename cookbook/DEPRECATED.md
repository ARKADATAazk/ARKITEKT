# Deprecation Tracker

Track deprecated code for coordinated removal.

---

## How to Deprecate

1. Add `---@deprecated` annotation
2. Add inline comment with date and replacement
3. Add entry to this file
4. Set removal target

```lua
---@deprecated Use Theme.COLORS.BG_PANEL instead
-- @deprecated 2025-11: Use Theme.COLORS.BG_PANEL
-- @removal-target: v2.0
function M.get_panel_bg()
  return Theme.COLORS.BG_PANEL
end
```

### Parity Shim Pattern

For API migrations, use the parity shim pattern:

```lua
-- @deprecated TEMP_PARITY_SHIM: old_func() → use new_module.func()
-- EXPIRES: 2025-12-15 (planned removal: Phase-3)
-- reason: GUI still calls old API; remove after migration.
function M.old_func()
  return NewModule.new_func()
end
```

---

## Active Deprecations

*(Add entries here as code is deprecated)*

### Template Entry

```markdown
### [Date] Category: Description
- **Location**: `path/to/file.lua:line`
- **Deprecated**: What's deprecated
- **Replacement**: What to use instead
- **Removal Target**: Version or date
- **Migration**: How to update calling code
```

---

## Pending Review

Items that may need deprecation:

### Old Require Paths
```lua
-- Old paths (still work but discouraged)
require('arkitekt.app.runtime.shell')
require('arkitekt.app.assets.fonts')

-- Preferred paths
require('arkitekt.app.shell')
require('arkitekt.app.chrome.fonts')
```
**Status**: Old paths work via compatibility layer

---

## Completed Removals

*(Move entries here when deprecated code is removed)*

### Template

```markdown
### [Removal Date] Description
- **Removed from**: `path/to/file.lua`
- **Was deprecated**: [deprecation date]
- **Replacement**: What replaced it
```

---

## Removal Process

When ready to remove deprecated code:

1. **Search for usages**:
   ```bash
   grep -r "deprecated_function" ARKITEKT/
   ```

2. **Update all call sites** to use replacement

3. **Remove deprecated code**

4. **Move entry** from "Active" to "Completed" with date

5. **Commit** with message referencing deprecation

---

## Grep Patterns for Finding Deprecations

```bash
# Find all @deprecated annotations
grep -r "@deprecated" ARKITEKT/arkitekt/

# Find TEMP_PARITY_SHIM markers
grep -r "TEMP_PARITY_SHIM" ARKITEKT/

# Find EXPIRES markers
grep -r "EXPIRES:" ARKITEKT/
```
