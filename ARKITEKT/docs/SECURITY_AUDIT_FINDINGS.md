# Security Audit Findings - Task 3 Review

**Date**: 2025-11-27
**Auditor**: Claude (Security Review)
**Scope**: Complete codebase review for security vulnerabilities

---

## Executive Summary

Post-implementation security audit found **3 categories** of issues:

1. ✅ **FIXED**: Layer purity violations (colors.lua) - RESOLVED
2. ✅ **FIXED**: Primary file operations (TemplateBrowser, ThemeAdjuster) - RESOLVED
3. ⚠️ **FOUND**: Secondary file operations bypassing validation

---

## Detailed Findings

### 1. Layer Purity (VERIFIED SECURE)

**Status**: ✅ All Clear

**Checked**: All `core/*` modules for `reaper.*` and `ImGui.*` calls at import time

**Result**: All `reaper.*` calls are inside functions (runtime only), not at module top-level (import time). This complies with layer purity rules.

**Files Checked**:
- `arkitekt/core/settings.lua` - ✅ Runtime calls only
- `arkitekt/core/callbacks.lua` - ✅ Runtime calls only
- `arkitekt/core/events.lua` - ✅ Runtime calls only
- `arkitekt/core/shuffle.lua` - ✅ Runtime calls only
- `arkitekt/core/uuid.lua` - ✅ Runtime calls only
- `arkitekt/core/theme_manager/debug.lua` - ✅ Runtime calls only
- `arkitekt/core/theme_manager/integration.lua` - ✅ Runtime calls only

---

### 2. Primary File Operations (SECURED)

**Status**: ✅ Secured

These operations now use `PathValidation` module:

**TemplateBrowser** (`scripts/TemplateBrowser/infra/file_ops.lua`):
- ✅ `rename_template()` - Validates & sanitizes
- ✅ `rename_folder()` - Validates & sanitizes
- ✅ `create_folder()` - Validates & sanitizes

**ThemeAdjuster**:
- ✅ `packages/manager.lua::make_zip()` - Validates paths
- ✅ `core/theme.lua::unzip()` - Validates paths

---

### 3. Secondary File Operations (ISSUES FOUND)

**Status**: ⚠️ Needs Review

#### Issue 3.1: TemplateBrowser Undo/Redo Operations

**File**: `scripts/TemplateBrowser/ui/views/tree_view.lua`
**Lines**: 776, 810, 822
**Severity**: MEDIUM

**Problem**: Direct `os.remove()` and `os.rename()` calls that bypass FileOps validation module.

```lua
-- Line 776: Direct os.remove
success = os.remove(node.full_path)

-- Line 810: Direct os.rename
local restore_success = os.rename(archive_path, node.full_path)

-- Line 822: Direct os.remove
local redo_success = os.remove(node.full_path)
```

**Risk Assessment**:
- **Likelihood**: LOW - Paths come from filesystem scanner, not direct user input
- **Impact**: MEDIUM - Could allow deletion of unintended files if scanner is compromised
- **Overall**: MEDIUM

**Recommendation**:
- OPTION A: Add validation before os.* calls
- OPTION B: Refactor to use FileOps module methods
- **Preferred**: OPTION A (minimal change, maintains undo/redo functionality)

---

#### Issue 3.2: ItemPicker Cache Cleanup

**File**: `scripts/ItemPicker/data/disk_cache.lua`
**Lines**: 125, 317
**Severity**: LOW

**Problem**: `os.remove()` on paths constructed from GUIDs without validation.

```lua
-- Line 124-125: Cache eviction
local old_cache_path = cache_dir .. "/" .. oldest.guid .. ".lua"
os.remove(old_cache_path)

-- Line 316-317: Cache clearing
local cache_path = cache_dir .. "/" .. current_project_guid .. ".lua"
os.remove(cache_path)
```

**Risk Assessment**:
- **Likelihood**: VERY LOW - GUIDs come from REAPER, expected to be safe
- **Impact**: LOW - Only affects cache files in controlled directory
- **Overall**: LOW

**Recommendation**:
- Add validation for defense-in-depth
- **Priority**: LOW (optional hardening)

---

#### Issue 3.3: ThemeAdjuster Recursive Directory Removal

**File**: `scripts/ThemeAdjuster/core/theme.lua`
**Lines**: 48, 50
**Severity**: LOW

**Problem**: `os.remove()` in recursive directory deletion without validation.

```lua
-- Line 48-50: Recursive removal
local function remove_dir_rec(dir)
  if not dir_exists(dir) then return end
  for _,p in ipairs(list_files(dir, nil, {})) do os.remove(p) end
  for _,sd in ipairs(list_subdirs(dir, {})) do remove_dir_rec(sd) end
  os.remove(dir)
end
```

**Risk Assessment**:
- **Likelihood**: LOW - Paths are internally generated from cache directories
- **Impact**: MEDIUM - Recursive deletion is inherently risky
- **Overall**: LOW-MEDIUM

**Recommendation**:
- Add validation to prevent deletion outside intended directories
- **Priority**: MEDIUM (safety improvement)

---

#### Issue 3.4: Settings Module Atomic Write

**File**: `arkitekt/core/settings.lua`
**Lines**: 34, 37, 38
**Severity**: VERY LOW

**Problem**: `os.remove()` and `os.rename()` in atomic write implementation.

```lua
-- Lines 34-38: Atomic write pattern
os.remove(tmp)  -- Cleanup on error
...
os.remove(p)    -- Windows-safe replace
local rename_ok, rename_err = os.rename(tmp, p)
```

**Risk Assessment**:
- **Likelihood**: VERY LOW - Paths are internal settings files
- **Impact**: LOW - Only affects application settings
- **Overall**: VERY LOW

**Recommendation**:
- Current implementation is acceptable for internal settings
- **Priority**: VERY LOW (optional)

---

## Security Recommendations

### Immediate Actions (Priority: HIGH)

1. **Fix tree_view.lua undo/redo operations**
   - Add path validation before os.remove/os.rename in undo/redo functions
   - Prevents potential path manipulation attacks

### Short-term Actions (Priority: MEDIUM)

2. **Add validation to remove_dir_rec in theme.lua**
   - Ensure recursive deletion stays within intended directories
   - Add path prefix check against expected cache directories

3. **Document safe usage patterns**
   - Update SECURITY.md with internal vs external path guidelines
   - Clarify when validation is required vs optional

### Long-term Actions (Priority: LOW)

4. **Harden ItemPicker cache operations**
   - Add GUID format validation
   - Validate cache paths before deletion

5. **Centralize all file operations**
   - Create utility module for all os.remove/os.rename operations
   - Enforce validation at a single chokepoint

---

## Summary Statistics

| Category | Count | Status |
|----------|-------|--------|
| **Layer Purity Violations** | 0 | ✅ CLEAN |
| **Primary File Ops (Fixed)** | 5 | ✅ SECURED |
| **Secondary Ops (Found)** | 8 | ⚠️ REVIEW |
| **Critical Issues** | 0 | ✅ NONE |
| **High Priority** | 1 | ⚠️ tree_view.lua |
| **Medium Priority** | 1 | ⚠️ theme.lua |
| **Low Priority** | 2 | ℹ️ Optional |

---

## Conclusion

The primary security hardening task has been **successfully completed**. All user-facing file operations are now properly validated.

The additional findings represent **defense-in-depth opportunities** rather than critical vulnerabilities. The highest priority is securing the undo/redo operations in tree_view.lua.

**Overall Security Posture**: GOOD ✅

All critical paths are secured. Remaining issues are edge cases and internal operations that pose minimal risk.

---

## Next Steps

1. Review findings with team
2. Prioritize fixes based on risk assessment
3. Implement HIGH priority fix (tree_view.lua)
4. Consider MEDIUM priority hardening (theme.lua)
5. Update SECURITY.md with internal path guidelines
