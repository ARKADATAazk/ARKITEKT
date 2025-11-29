# Constant Organization Improvements

Architectural improvements for constant organization and lookup patterns in ARKITEKT.

## Priority: Medium
**Estimated effort:** 6-8 hours total

---

## 1. Bidirectional Lookup Pattern (High Priority)

**Problem:**
Arrays of options (dropdowns, selects) require O(n) iteration to find items by label/name.

**Current approach:**
```lua
M.QUANTIZE_OPTIONS = {
  { value = "4bar", label = "4 Bars" },
  { value = "2bar", label = "2 Bars" },
}

-- Finding value by label requires loop
for _, opt in ipairs(QUANTIZE_OPTIONS) do
  if opt.label == user_input then
    return opt.value
  end
end
```

**Solution:**
Build reverse lookup tables for O(1) access.

```lua
-- constants.lua
M.QUANTIZE_OPTIONS = {
  { value = "4bar", label = "4 Bars" },
  { value = "2bar", label = "2 Bars" },
}

-- Build reverse lookup (computed once at module load)
M.QUANTIZE_BY_LABEL = {}
for _, opt in ipairs(M.QUANTIZE_OPTIONS) do
  M.QUANTIZE_BY_LABEL[opt.label] = opt.value
end

-- Now instant lookup:
local value = Constants.QUANTIZE_BY_LABEL[user_input]  -- O(1)
```

**Action items:**
- [x] Create `arkitekt/core/lookup.lua` helper module
- [x] Implement `build_reverse_lookup(array, key_field, value_field)` function
- [x] Audit all option arrays in constants files
- [x] Add reverse lookups where label→value or name→id conversions happen (RegionPlaylist QUANTIZE_OPTIONS)
- [ ] Document pattern in API_DOCUMENTATION_GUIDE.md

**Estimated effort:** 2 hours

---

## 2. Consolidated Feature Flags File

**Problem:**
Feature flags scattered across multiple files makes it hard to:
- See what features are experimental
- Toggle features for testing
- Track what needs cleanup before 1.0

**Current state:**
```lua
-- arkitekt/defs/app.lua
M.PROFILER_ENABLED = false

-- Elsewhere in other files
-- No central visibility
```

**Solution:**
Create centralized feature flags file (kept minimal - only flags actually used in code).

```lua
-- arkitekt/defs/features.lua
local M = {}

-- Profiler: Performance profiling window
M.PROFILER_ENABLED = false

return M
```

**Note:** Originally included experimental/platform/deprecation flags, but stripped to only what's actually checked in code. Add flags only when needed, not speculatively.

**Benefits:**
- Single source of truth for all toggles
- Easy to see what's experimental
- Clear deprecation tracking
- Platform-specific flags in one place

**Action items:**
- [x] Create `arkitekt/defs/features.lua`
- [x] Audit codebase for scattered feature flags
- [x] Migrate flags to centralized file
- [x] Update code to reference `Features.FLAG_NAME`
- [x] Add to namespace in `arkitekt/init.lua`
- [ ] Document in NAMESPACE.md

**Estimated effort:** 2 hours
**Status:** ✅ **COMPLETED** - Feature flags centralized in `arkitekt/defs/features.lua`

---

## 3. Reverse Lookup Helper Utilities

**Problem:**
Need reusable utilities for building bidirectional lookups.

**Solution:**
Create helper module for common lookup patterns.

```lua
-- arkitekt/core/lookup.lua (NEW FILE)
local M = {}

-- Build reverse lookup from array of objects
-- @param array: Array of objects with key/value fields
-- @param key_field: Field name to use as key in reverse table
-- @param value_field: Field name to use as value in reverse table
-- @return: Table mapping key_field values to value_field values
function M.build_reverse_lookup(array, key_field, value_field)
  local reverse = {}
  for _, item in ipairs(array) do
    reverse[item[key_field]] = item[value_field]
  end
  return reverse
end

-- Build index lookup (key_field → entire object)
function M.build_index(array, key_field)
  local index = {}
  for _, item in ipairs(array) do
    index[item[key_field]] = item
  end
  return index
end

-- Build bidirectional lookup (both directions)
function M.build_bidirectional(array, key1, key2)
  local forward = {}
  local reverse = {}
  for _, item in ipairs(array) do
    forward[item[key1]] = item[key2]
    reverse[item[key2]] = item[key1]
  end
  return forward, reverse
end

return M
```

**Usage example:**
```lua
local Lookup = require('arkitekt.core.lookup')

M.QUANTIZE_OPTIONS = {...}

-- Simple reverse lookup
M.QUANTIZE_BY_LABEL = Lookup.build_reverse_lookup(
  M.QUANTIZE_OPTIONS, "label", "value"
)

-- Or full object index
M.QUANTIZE_INDEX = Lookup.build_index(
  M.QUANTIZE_OPTIONS, "value"
)

-- Or bidirectional
M.LABEL_TO_VALUE, M.VALUE_TO_LABEL = Lookup.build_bidirectional(
  M.QUANTIZE_OPTIONS, "label", "value"
)
```

**Action items:**
- [x] Create `arkitekt/core/lookup.lua`
- [x] Implement `build_reverse_lookup()` function
- [x] Implement `build_index()` function
- [x] Implement `build_bidirectional()` function
- [x] Implement `build_reverse()` function (bonus: for flat key-value tables)
- [ ] Add unit tests
- [ ] Document in API_DOCUMENTATION_GUIDE.md
- [x] Add to lazy loading registry in init.lua (registered as Ark.Lookup)

**Estimated effort:** 1.5 hours

---

## 4. Constants Audit Script

**Problem:**
Need systematic way to find:
- Duplicate color definitions
- Hardcoded values that should be constants
- Constants that could be theme-aware
- Missing documentation

**Solution:**
Create audit script to analyze constants usage.

```lua
-- scripts/dev/audit_constants.lua
-- Analyzes constants files and reports issues

local checks = {
  duplicate_colors = true,
  hardcoded_colors = true,
  missing_docs = true,
  theme_aware_candidates = true,
}

-- Scan all constants.lua files
-- Report duplicates
-- Suggest consolidation opportunities
```

**Action items:**
- [ ] Create `scripts/dev/audit_constants.lua`
- [ ] Implement duplicate color detection
- [ ] Implement hardcoded value scanning
- [ ] Implement documentation coverage check
- [ ] Generate report with recommendations
- [ ] Document audit process in CONTRIBUTING.md

**Estimated effort:** 3 hours

---

## 5. Apply Pattern to Existing Constants

**Action items:**

### RegionPlaylist
- [x] Add `QUANTIZE_BY_LABEL` reverse lookup
- [x] Add `QUANTIZE_BY_VALUE` reverse lookup (value → label for display)
- [x] Add `QUANTIZE_INDEX` full object lookup
- [ ] Consider transport button reverse lookups

### ThemeAdjuster
- [ ] Audit parameter mappings for lookup opportunities
- [ ] Add reverse lookups for parameter groups

### ItemPicker
- [ ] Check filter options for reverse lookup needs

### TemplateBrowser
- [ ] Check category/tag lookups

**Estimated effort:** 1.5 hours

---

## 6. Documentation Updates

**Action items:**
- [ ] Add "Constant Organization" section to API_DOCUMENTATION_GUIDE.md
- [ ] Document bidirectional lookup pattern
- [ ] Add examples of when to use reverse lookups
- [ ] Document feature flags pattern
- [ ] Update NAMESPACE.md to include Features and Lookup modules

**Estimated effort:** 1 hour

---

## Implementation Order

1. **Phase 1: Foundation** (3 hours)
   - Create `arkitekt/core/lookup.lua`
   - Create `arkitekt/defs/features.lua`
   - Add to namespace/lazy loading

2. **Phase 2: Apply Pattern** (2 hours)
   - Add reverse lookups to RegionPlaylist constants
   - Add to other apps as needed

3. **Phase 3: Audit & Cleanup** (3 hours)
   - Create audit script
   - Run audit
   - Fix identified issues
   - Update documentation

---

## Success Criteria

- [ ] Lookup helper module available in arkitekt namespace
- [ ] Feature flags consolidated in single file
- [ ] All dropdown/option arrays have reverse lookups where needed
- [ ] O(1) lookups replace O(n) iterations
- [ ] Documentation updated with patterns
- [ ] Audit script identifies no critical issues

---

## Notes

- Keep named keys over positional arrays (better maintainability)
- Don't mix constants and mutable state
- Maintain clear section headers and documentation
- Use semantic references (ColorDefs.OPERATIONS) over hardcoded values

---

## Related Files

- `arkitekt/defs/app.lua` - App constants
- `arkitekt/defs/typography.lua` - Typography constants
- `arkitekt/defs/colors.lua` - Color definitions
- `scripts/*/defs/constants.lua` - App-specific constants
- `API_DOCUMENTATION_GUIDE.md` - Documentation standards
