# Deprecation Tracker - Shell API

## Status: ACTIVE (v1.x)
All legacy options are currently supported for backward compatibility.

## Target Cleanup: v2.0
When ready for breaking changes, remove all legacy compatibility code.

---

## Legacy Options to Remove

### 1. Shell.run() - Legacy Chrome Options
**File**: `arkitekt/app/shell.lua:357-363`

| Legacy Option | Replacement | Notes |
|---------------|-------------|-------|
| `show_status_bar` | `chrome = "window"` or explicit | Use chrome presets or individual flags |
| `show_statusbar` | `chrome.show_statusbar` | Typo-tolerant variant |
| `show_titlebar` | `chrome.show_titlebar` | Use chrome config |
| `show_icon` | `chrome.show_icon` | Use chrome config |
| `show_version` | `chrome.show_version` | Use chrome config |
| `enable_maximize` | `chrome.enable_maximize` | Use chrome config |
| `flags` | `imgui_flags` | Use new flag builder system |

**Cleanup Action**: Remove lines 357-363, 370, 386 from shell.lua

---

### 2. Window.new() - Legacy Option Processing
**File**: `arkitekt/app/chrome/window.lua:145-151`

```lua
-- REMOVE: Legacy compatibility overrides (lines 145-151)
if opts.show_titlebar ~= nil then chrome.show_titlebar = opts.show_titlebar end
if opts.show_status_bar ~= nil then chrome.show_statusbar = opts.show_status_bar end
if opts.show_statusbar ~= nil then chrome.show_statusbar = opts.show_statusbar end
if opts.show_icon ~= nil then chrome.show_icon = opts.show_icon end
if opts.show_version ~= nil then chrome.show_version = opts.show_version end
if opts.enable_maximize ~= nil then chrome.enable_maximize = opts.enable_maximize end
```

**Cleanup Action**: Remove legacy option override logic, rely only on chrome presets

---

### 3. Window.new() - Legacy Flags
**File**: `arkitekt/app/chrome/window.lua:121-123`

```lua
-- REMOVE: Legacy flags support (line 121-123)
elseif config.flags then
  base_flags = config.flags
end
```

**Cleanup Action**: Remove `config.flags` fallback, only use `imgui_flags`

---

### 4. Shell.run() - Legacy Overlay Mode Detection
**File**: `arkitekt/app/shell.lua:296-298`

```lua
-- REMOVE: Legacy overlay mode branch (lines 296-298)
if config.mode == "overlay" and not config.imgui_flags then
  return run_overlay_mode(config)
end
```

**Cleanup Action**: Remove special overlay handling, use unified Window.new() path

---

## Migration Guide for Users (v1.x → v2.0)

### Shell Options
```lua
-- OLD (v1.x - DEPRECATED)
Shell.run({
  show_status_bar = false,
  show_titlebar = true,
  show_icon = false,
  flags = ImGui.WindowFlags_NoTitleBar,
})

-- NEW (v2.0+)
Shell.run({
  chrome = "hud",              -- or custom chrome config
  imgui_flags = "window",      -- or custom flags
})
```

### Window Options
```lua
-- OLD (v1.x - DEPRECATED)
Window.new({
  flags = ImGui.WindowFlags_NoTitleBar | ImGui.WindowFlags_NoResize,
  show_icon = false,
  enable_maximize = false,
})

-- NEW (v2.0+)
Window.new({
  imgui_flags = {"WindowFlags_NoTitleBar", "WindowFlags_NoResize"},
  chrome = {
    show_icon = false,
    enable_maximize = false,
  }
})
```

---

## Cleanup Checklist (When Ready for v2.0)

### Step 1: Mark as Breaking Change
- [ ] Update CHANGELOG.md with breaking changes section
- [ ] Bump version to 2.0.0
- [ ] Add migration guide to release notes

### Step 2: Remove Legacy Code
- [ ] shell.lua:357-363 - Remove legacy option passthrough
- [ ] shell.lua:370 - Remove `flags = config.flags`
- [ ] shell.lua:296-298 - Remove special overlay mode handling
- [ ] window.lua:145-151 - Remove legacy option overrides
- [ ] window.lua:121-123 - Remove `config.flags` fallback

### Step 3: Update Documentation
- [ ] Remove legacy examples from SHELL_API.md
- [ ] Update all example scripts to use new API
- [ ] Add "Upgrading from v1.x" guide

### Step 4: Search & Destroy
```bash
# Find all LEGACY_COMPAT markers
grep -rn "LEGACY_COMPAT" ARKITEKT/arkitekt/

# Find all references to deprecated options
grep -rn "show_status_bar\|show_titlebar\|enable_maximize" ARKITEKT/

# Verify no apps use old API
grep -rn "flags.*ImGui.WindowFlags" ARKITEKT/scripts/
```

### Step 5: Testing
- [ ] Test all built-in apps with new API
- [ ] Verify error messages for removed options
- [ ] Update unit tests (if any)

---

## Timeline

| Phase | Version | Status | Notes |
|-------|---------|--------|-------|
| Introduction | v1.0 | ✅ DONE | New API added, legacy supported |
| Deprecation Warning | v1.5 | ⏳ PENDING | Add console warnings for legacy options |
| Legacy Removal | v2.0 | ⏳ PENDING | Breaking change, clean removal |

---

## Notes

- Keep this document updated as new legacy code is identified
- Before v2.0, consider adding deprecation warnings to legacy options
- Document any apps/scripts that still use old API
- Consider semver: only remove in major version bumps

---

## Quick Cleanup Command

When ready for v2.0, run this to find all legacy markers:

```bash
# Find all legacy compatibility code
rg "LEGACY_COMPAT|@deprecated|REMOVE.*v2" ARKITEKT/arkitekt/

# Find specific legacy option usage
rg "show_status_bar|show_titlebar|config\.flags" ARKITEKT/arkitekt/ -A 2 -B 2
```
