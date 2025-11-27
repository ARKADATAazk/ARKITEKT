# ARKITEKT Security Guide

> **Last Updated**: 2025-11-27
> **Security Hardening Version**: 1.0

This document describes the security measures implemented in ARKITEKT to protect against common vulnerabilities.

---

## Overview

ARKITEKT implements multiple layers of security to protect users from:

- **Path Traversal Attacks**: Preventing malicious paths like `../../etc/passwd`
- **Command Injection**: Blocking shell metacharacters in paths passed to OS commands
- **Malicious Filenames**: Sanitizing user-provided filenames
- **Layer Purity Violations**: Ensuring pure modules don't call runtime APIs at import time

---

## Path Validation Module

**Location**: `arkitekt/core/path_validation.lua`

### Purpose

Centralized path validation to prevent security vulnerabilities in file operations across all ARKITEKT applications.

### Key Features

1. **Path Safety Validation** (`is_safe_path()`)
   - Validates paths contain only safe characters
   - Blocks shell metacharacters: `;`, `|`, `&`, `$`, `` ` ``, `'`, `"`, `<`, `>`
   - Prevents directory traversal with `..`
   - Allows: alphanumeric, spaces, `.`, `-`, `_`, `/`, `\`, `:`, `(`, `)`

2. **Filename Safety Validation** (`is_safe_filename()`)
   - Validates filenames (no path separators allowed)
   - Blocks hidden files starting with `.`
   - Prevents directory traversal
   - Same character restrictions as paths

3. **Filename Sanitization** (`sanitize_filename()`)
   - Removes/replaces unsafe characters
   - Converts path separators to underscores
   - Removes shell metacharacters
   - Replaces `..` with `__`
   - Trims leading/trailing dots and spaces
   - Returns "unnamed" if result is empty

4. **Suspicious Pattern Detection** (`check_suspicious_patterns()`)
   - Detects null bytes
   - Identifies excessive path separators (`///`)
   - Blocks percent encoding (`%20`)
   - Flags unicode control characters

### Usage Examples

```lua
local PathValidation = require('arkitekt.core.path_validation')

-- Validate a path
local ok, err = PathValidation.is_safe_path("/home/user/documents/file.txt")
if not ok then
  reaper.ShowConsoleMsg("Invalid path: " .. err .. "\n")
  return
end

-- Validate a filename
local ok, err = PathValidation.is_safe_filename("my_file.txt")
if not ok then
  reaper.ShowConsoleMsg("Invalid filename: " .. err .. "\n")
  return
end

-- Sanitize user input
local safe_name = PathValidation.sanitize_filename(user_input)

-- Assert path safety (raises error if invalid)
local path = PathValidation.assert_safe_path(user_path, "rename operation")

-- Validate and normalize in one call
local ok, normalized = PathValidation.validate_and_normalize(path)
```

---

## Security Best Practices

### For File Operations

**ALWAYS** validate paths before file operations:

```lua
-- ✓ GOOD: Validate before rename
function M.rename_file(old_path, new_name)
  local ok, err = PathValidation.is_safe_path(old_path)
  if not ok then
    return false, "Invalid path: " .. err
  end

  new_name = PathValidation.sanitize_filename(new_name)
  -- ... perform rename
end

-- ✗ BAD: No validation
function M.rename_file(old_path, new_name)
  os.rename(old_path, new_path)  -- VULNERABLE!
end
```

### For Shell Commands

**CRITICAL**: Always validate paths before passing to shell commands:

```lua
-- ✓ GOOD: Validate and quote
local function make_zip(src_dir, out_zip)
  local ok, err = PathValidation.is_safe_path(src_dir)
  if not ok then
    return false, "Invalid source: " .. err
  end

  ok, err = PathValidation.is_safe_path(out_zip)
  if not ok then
    return false, "Invalid output: " .. err
  end

  -- Also use proper quoting for shell
  local cmd = string.format('cd "%s" && zip -r "%s" *', src_dir, out_zip)
  os.execute(cmd)
end

-- ✗ BAD: No validation or quoting
local function make_zip(src_dir, out_zip)
  os.execute("cd " .. src_dir .. " && zip -r " .. out_zip .. " *")  -- VULNERABLE!
end
```

### For User Input

**ALWAYS** sanitize user-provided filenames:

```lua
-- ✓ GOOD: Sanitize user input
local function create_folder(parent, user_folder_name)
  user_folder_name = PathValidation.sanitize_filename(user_folder_name)

  local ok, err = PathValidation.is_safe_filename(user_folder_name)
  if not ok then
    return false, err
  end

  -- ... create folder
end

-- ✗ BAD: Trust user input
local function create_folder(parent, user_folder_name)
  local path = parent .. "/" .. user_folder_name  -- VULNERABLE!
  os.execute("mkdir " .. path)
end
```

---

## Attack Vectors Prevented

### 1. Path Traversal

**Attack**: `../../etc/passwd`
**Prevention**: `is_safe_path()` blocks paths containing `..`

**Attack**: `/var/www/../../../root/.ssh/id_rsa`
**Prevention**: `..` sequences are blocked regardless of context

### 2. Command Injection

**Attack**: `file.txt; rm -rf /`
**Prevention**: Semicolons blocked by character whitelist

**Attack**: `file | cat /etc/passwd`
**Prevention**: Pipe character blocked

**Attack**: `` file`whoami`.txt ``
**Prevention**: Backticks blocked

**Attack**: `$HOME/malicious`
**Prevention**: Dollar signs blocked

### 3. Malicious Filenames

**Attack**: `.hidden` (hidden file)
**Prevention**: `is_safe_filename()` blocks filenames starting with `.`

**Attack**: `file'; DROP TABLE users--`
**Prevention**: Quotes blocked

**Attack**: `<script>alert('xss')</script>`
**Prevention**: Angle brackets blocked

### 4. Encoding Attacks

**Attack**: `file%00.txt` (null byte via URL encoding)
**Prevention**: Percent encoding detected by `check_suspicious_patterns()`

**Attack**: `file\0.txt` (null byte)
**Prevention**: Null bytes detected and blocked

---

## Security Testing

**Location**: `arkitekt/core/tests/test_path_validation.lua`

### Running Tests

```lua
local Tests = require('arkitekt.core.tests.test_path_validation')
Tests.run_all()
```

### Test Coverage

- ✓ Valid paths (Unix, Windows, relative)
- ✓ Path traversal attacks (`..`)
- ✓ Command injection (`;`, `|`, `&`, `` ` ``, `$`, etc.)
- ✓ Empty and nil paths
- ✓ Safe filenames
- ✓ Filename sanitization
- ✓ Suspicious pattern detection
- ✓ Validation and normalization

---

## Layer Purity Compliance

**Fixed Violations**:

1. **arkitekt/core/colors.lua:225**
   - **Issue**: `reaper.ColorToNative()` called in pure core layer
   - **Fix**: Replaced with pure Lua bit operations
   - **Impact**: Maintains layer purity while preserving functionality

**Layer Rules**:

- **Pure layers** (NO `reaper.*`, NO `ImGui.*` at import time):
  - `core/*` ✓
  - `storage/*` ✓
  - `domain/*` ✓

- **Runtime layers** (may use `reaper.*` and `ImGui`):
  - `app/*`
  - `ui/*`, `views/*`, `widgets/*`
  - `engine/*`

---

## Applications Updated

### 1. TemplateBrowser

**File**: `scripts/TemplateBrowser/infra/file_ops.lua`

**Security Enhancements**:
- ✓ `rename_template()`: Validates old path and sanitizes new name
- ✓ `rename_folder()`: Validates old path and sanitizes new name
- ✓ `create_folder()`: Validates parent path and sanitizes folder name

### 2. ThemeAdjuster

**File**: `scripts/ThemeAdjuster/packages/manager.lua`

**Security Enhancements**:
- ✓ `make_zip()`: Uses centralized `PathValidation.is_safe_path()`
- ✓ Removed duplicate validation code
- ✓ Consistent validation across all ZIP operations

---

## Developer Guidelines

### When Adding New File Operations

1. **Import the validation module**:
   ```lua
   local PathValidation = require('arkitekt.core.path_validation')
   ```

2. **Validate all paths**:
   ```lua
   local ok, err = PathValidation.is_safe_path(path)
   if not ok then
     -- Handle error
     return false, err
   end
   ```

3. **Sanitize user input**:
   ```lua
   filename = PathValidation.sanitize_filename(user_input)
   ```

4. **Add tests**:
   - Add test cases for new file operations
   - Test both valid and malicious inputs
   - Verify error handling

### When Reviewing Code

**Security Checklist**:
- [ ] All `os.rename()` calls validate inputs
- [ ] All `os.execute()` calls validate and quote arguments
- [ ] All `io.open()` calls validate paths
- [ ] User input is sanitized before use
- [ ] No `..` sequences in constructed paths
- [ ] No shell metacharacters in paths
- [ ] Error messages don't leak sensitive information

---

## Reporting Security Issues

If you discover a security vulnerability:

1. **DO NOT** open a public issue
2. Report privately to the maintainers
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

---

## Future Enhancements

Planned security improvements:

- [ ] Add path canonicalization to resolve symlinks
- [ ] Implement path whitelist for allowed directories
- [ ] Add audit logging for file operations
- [ ] Implement file permission checks
- [ ] Add rate limiting for file operations
- [ ] Create security audit tool for codebase scanning

---

## References

- **OWASP Path Traversal**: https://owasp.org/www-community/attacks/Path_Traversal
- **Command Injection**: https://owasp.org/www-community/attacks/Command_Injection
- **Input Validation**: https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html

---

**Remember**: Security is a continuous process. Always validate, sanitize, and test.
