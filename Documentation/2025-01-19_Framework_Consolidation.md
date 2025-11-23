# Framework Consolidation Refactoring
**Date:** 2025-01-19
**Branch:** `claude/fix-path-resolution-01VdYYQAL7xRszRWUrX3DnWc`
**Commits:** `731f102`, `16dc9af`, `086ee09`, `1e1dba3`, `4b4e3fb`, `40f51d2`

---

## 🎯 Goals Achieved

### ✅ **Universal Path Resolution**
- Replaced fragile hardcoded path climbing (`../../../`) with automatic root detection
- Scripts now work regardless of folder hierarchy depth
- Scans upward for `arkitekt/app/shell.lua` as anchor point

### ✅ **Bootstrap Duplication Elimination**
- Created `arkitekt/app/init.lua` to centralize bootstrap logic
- Reduced entry point bootstrap code from 20 lines to 3 lines
- Eliminated ~140 lines of duplicated initialization code

### ✅ **Configuration Consolidation**
- Created `arkitekt/app/constants.lua` as single source of truth
- Centralized all magic numbers: overlays, animations, typography, chrome
- Framework now controls design consistency

### ✅ **Overlay Configuration Simplification**
- Enhanced `overlay/defaults.lua` with `create_overlay_config()` helper
- Reduced overlay config from ~45 lines to ~7 lines per app
- Apps only override what's truly app-specific
- Eliminated ~190 lines of duplicated overlay configuration

### ✅ **Font Loading Centralization**
- Created `arkitekt/app/fonts.lua` module
- Eliminated ~105 lines of duplicated font loading code
- Font sizes now controlled by constants.lua by default
- Apps can override sizes when needed (e.g., ItemPicker's larger title)

### ✅ **Settings Singleton Fix**
- Fixed anti-pattern where `Settings.open()` returned cached singleton
- `Settings.new()` now creates fresh instances every time
- Enables multiple independent settings instances

### ✅ **ReaPack Path Preservation**
- Changed from `[data]` to `[nomain]` directive
- Preserves directory structure for asset files
- Fonts and assets now stay in correct paths

---

## 📊 Impact Summary

| Metric | Value |
|--------|-------|
| **Total lines eliminated** | ~485 lines |
| **Files created** | 3 (init.lua, constants.lua, fonts.lua) |
| **Files modified** | 11 |
| **Entry points updated** | 7 |
| **Bootstrap code reduction** | 20 lines → 3 lines per entry point |
| **Overlay config reduction** | ~45 lines → ~7 lines per app |
| **Font loading reduction** | ~35 lines → 1 line per app |

---

## 📁 File Changes

### Created Files

#### **`ARKITEKT/arkitekt/app/init.lua`** (NEW - 35 lines)
**Purpose:** Eliminates bootstrap finder duplication across entry points

```lua
local M = {}

function M.bootstrap()
  local sep = package.config:sub(1,1)
  local src = debug.getinfo(2, "S").source:sub(2)
  local dir = src:match("(.*"..sep..")")

  -- Scan upward for arkitekt/app/bootstrap.lua
  local path = dir
  while path and #path > 3 do
    local bootstrap = path .. "arkitekt" .. sep .. "app" .. sep .. "bootstrap.lua"
    local f = io.open(bootstrap, "r")
    if f then
      f:close()
      return dofile(bootstrap)(path)
    end
    path = path:match("(.*"..sep..")[^"..sep.."]-"..sep.."$")
  end

  reaper.MB("ARKITEKT bootstrap not found!", "FATAL ERROR", 0)
  return nil
end

return M
```

**Impact:**
- Entry points reduced from 20 lines of bootstrap code to 3 lines
- Automatic root detection via anchor file scanning
- Works at any folder depth

---

#### **`ARKITEKT/arkitekt/app/constants.lua`** (NEW - 126 lines)
**Purpose:** Single source of truth for framework constants

```lua
local M = {}

M.OVERLAY = {
  CLOSE_BUTTON_SIZE = 32,
  CLOSE_BUTTON_MARGIN = 16,
  CLOSE_BUTTON_PROXIMITY = 150,
  CONTENT_PADDING = 24,
  SCRIM_OPACITY = 0.85,
  DEFAULT_USE_VIEWPORT = true,
  DEFAULT_SHOW_CLOSE_BUTTON = true,
  DEFAULT_ESC_TO_CLOSE = true,
  DEFAULT_CLOSE_ON_BG_CLICK = false,
  DEFAULT_CLOSE_ON_BG_RIGHT_CLICK = true,
}

M.ANIMATION = {
  FADE_FAST = 0.15,
  FADE_NORMAL = 0.3,
  FADE_SLOW = 0.5,
  DEFAULT_FADE_CURVE = 'ease_out_quad',
  HOVER_SPEED = 12.0,
}

M.TYPOGRAPHY = {
  SMALL = 11,
  DEFAULT = 13,
  MEDIUM = 16,
  LARGE = 20,
  XLARGE = 24,
  BODY = 13,
  HEADING = 20,
  TITLE = 24,
  CAPTION = 11,
  CODE = 12,
}

M.CHROME = {
  TITLEBAR_HEIGHT = 26,
  STATUS_BAR_HEIGHT = 28,
  STATUS_BAR_COMPENSATION = 6,
  TAB_HEIGHT = 30,
}

return M
```

**Impact:**
- Replaces ~50 magic numbers scattered across codebase
- Framework controls UX consistency
- Named constants improve code readability

---

#### **`ARKITEKT/arkitekt/app/fonts.lua`** (NEW - 75 lines)
**Purpose:** Centralized font loading with framework defaults

```lua
local Constants = require('arkitekt.app.constants')
local M = {}

---Load standard ARKITEKT fonts and attach to ImGui context
---@param ImGui table ReaImGui module
---@param ctx userdata ImGui context to attach fonts to
---@param opts? table Optional size overrides: { default_size, title_size, monospace_size }
---@return table fonts Table with font objects and their sizes
function M.load(ImGui, ctx, opts)
  opts = opts or {}

  local default_size = opts.default_size or Constants.TYPOGRAPHY.BODY
  local title_size = opts.title_size or Constants.TYPOGRAPHY.HEADING
  local monospace_size = opts.monospace_size or Constants.TYPOGRAPHY.CODE

  -- Find fonts directory, create fonts, attach to context
  -- ... (path resolution and font loading logic)

  return fonts
end

return M
```

**Impact:**
- Eliminates ~105 lines of duplicated font loading
- Uses constants.lua for default sizes
- Supports app-specific overrides

---

### Enhanced Files

#### **`ARKITEKT/arkitekt/gui/widgets/overlays/overlay/defaults.lua`**
**Added:** `create_overlay_config()` factory function

```lua
function M.create_overlay_config(opts)
  assert(opts and opts.id, "Overlay config requires 'id' field")
  assert(opts.render, "Overlay config requires 'render' function")

  local C = Constants.OVERLAY
  local A = Constants.ANIMATION
  local config = M.get()

  return {
    id = opts.id,
    use_viewport = opts.use_viewport ~= nil and opts.use_viewport or C.DEFAULT_USE_VIEWPORT,
    fade_duration = opts.fade_duration or A.FADE_NORMAL,
    fade_curve = opts.fade_curve or A.DEFAULT_FADE_CURVE,
    show_close_button = opts.show_close_button ~= nil and opts.show_close_button or C.DEFAULT_SHOW_CLOSE_BUTTON,
    close_button_size = opts.close_button_size or C.CLOSE_BUTTON_SIZE,
    close_button_margin = opts.close_button_margin or C.CLOSE_BUTTON_MARGIN,
    close_button_proximity = opts.close_button_proximity or C.CLOSE_BUTTON_PROXIMITY,
    esc_to_close = opts.esc_to_close ~= nil and opts.esc_to_close or C.DEFAULT_ESC_TO_CLOSE,
    close_on_bg_click = opts.close_on_bg_click ~= nil and opts.close_on_bg_click or C.DEFAULT_CLOSE_ON_BG_CLICK,
    close_on_bg_right_click = opts.close_on_bg_right_click ~= nil and opts.close_on_bg_right_click or C.DEFAULT_CLOSE_ON_BG_RIGHT_CLICK,
    scrim_color = opts.scrim_color or config.scrim_color,
    scrim_opacity = opts.scrim_opacity or C.SCRIM_OPACITY,
    content_padding = opts.content_padding or C.CONTENT_PADDING,
    render = opts.render,
    on_close = opts.on_close,
  }
end
```

**Impact:**
- Reduces overlay config from ~45 lines to ~7 lines per app
- All defaults pulled from constants.lua
- Apps only specify what's truly custom

---

#### **`ARKITEKT/arkitekt/core/settings.lua`**
**Fixed:** Singleton anti-pattern

**Before:**
```lua
local singleton

function M.open(cache_dir, filename)
  if singleton then return singleton end  -- BUG: Returns cached!
  singleton = setmetatable({...})
  return singleton
end
```

**After:**
```lua
function M.new(cache_dir, filename)
  -- Always creates fresh instance
  return setmetatable({
    _data = t,
    _dir = cache_dir,
    _path = path,
    _dirty = false,
    _last_touch = 0,
    _last_write = 0,
    _interval = 0.5
  }, Settings)
end

M.open = M.new  -- Backward compatible alias
```

**Impact:**
- Multiple apps can now have independent settings instances
- No more unexpected state sharing

---

### Updated Entry Points (All 7)

#### **Pattern: Bootstrap (Before → After)**

**Before (20 lines):**
```lua
local function find_root()
  local sep = package.config:sub(1,1)
  local src = debug.getinfo(1, "S").source:sub(2)
  local dir = src:match("(.*"..sep..")")

  local path = dir
  while path and #path > 3 do
    local bootstrap = path .. "arkitekt" .. sep .. "app" .. sep .. "bootstrap.lua"
    local f = io.open(bootstrap, "r")
    if f then
      f:close()
      return dofile(bootstrap)(path)
    end
    path = path:match("(.*"..sep..")[^"..sep.."]-"..sep.."$")
  end

  reaper.MB("ARKITEKT bootstrap not found!", "FATAL ERROR", 0)
  return nil
end

local ARK = find_root()
if not ARK then return end
```

**After (3 lines):**
```lua
local Init = require('arkitekt.app.init')
local ARK = Init.bootstrap()
if not ARK then return end
```

---

#### **Pattern: Overlay Config (Before → After)**

**Before (~45 lines):**
```lua
overlay_mgr:push({
  id = "template_browser_main",
  use_viewport = true,
  fade_duration = 0.3,
  fade_curve = 'ease_out_quad',
  show_close_button = true,
  close_button_size = 32,
  close_button_margin = 16,
  close_button_proximity = 150,
  esc_to_close = true,
  close_on_bg_click = false,
  close_on_bg_right_click = true,
  scrim_color = { 0, 0, 0 },
  scrim_opacity = 0.85,
  content_padding = 24,
  render = function(ctx, alpha_val, bounds)
    -- render logic
  end,
  on_close = cleanup,
})
```

**After (~7 lines):**
```lua
overlay_mgr:push(OverlayDefaults.create_overlay_config({
  id = "template_browser_main",
  -- All other settings use framework defaults
  render = function(ctx, alpha_val, bounds)
    -- render logic
  end,
  on_close = cleanup,
}))
```

**App-Specific Override Example (ItemPicker):**
```lua
overlay_mgr:push(OverlayDefaults.create_overlay_config({
  id = "item_picker_main",
  esc_to_close = false,  -- GUI handles ESC for special behavior
  render = ...,
  on_close = cleanup,
}))
```

---

#### **Pattern: Font Loading (Before → After)**

**Before (~35 lines):**
```lua
local function load_fonts(ctx)
  local SEP = package.config:sub(1,1)
  local src = debug.getinfo(1, 'S').source:sub(2)
  local this_dir = src:match('(.*'..SEP..')') or ('.'..SEP)
  local parent = this_dir:match('^(.*'..SEP..')[^'..SEP..']*'..SEP..'$') or this_dir
  local fontsdir = parent .. 'arkitekt' .. SEP .. 'fonts' .. SEP

  local regular = fontsdir .. 'Inter_18pt-Regular.ttf'
  local bold = fontsdir .. 'Inter_18pt-SemiBold.ttf'
  local mono = fontsdir .. 'JetBrainsMono-Regular.ttf'

  local function exists(p)
    local f = io.open(p, 'rb')
    if f then f:close(); return true end
  end

  local fonts = {
    default = exists(regular) and ImGui.CreateFont(regular, 14) or ImGui.CreateFont('sans-serif', 14),
    default_size = 14,
    title = exists(bold) and ImGui.CreateFont(bold, 20) or ImGui.CreateFont('sans-serif', 20),
    title_size = 20,
    monospace = exists(mono) and ImGui.CreateFont(mono, 12) or ImGui.CreateFont('sans-serif', 12),
    monospace_size = 12,
  }

  for _, font in pairs(fonts) do
    if font and type(font) ~= "number" then
      ImGui.Attach(ctx, font)
    end
  end

  return fonts
end

local fonts = load_fonts(ctx)
```

**After (1 line with framework defaults):**
```lua
local fonts = Fonts.load(ImGui, ctx)
```

**After (1 line with app-specific overrides):**
```lua
local fonts = Fonts.load(ImGui, ctx, { title_size = 24, monospace_size = 14 })
```

---

## 🏗️ Architecture

### Design Philosophy

> **"Our library is meant to be source of truth in most cases, and that goes for design as well. To keep things uniform."**
> — User design philosophy

**Key Principles:**
1. **Framework controls defaults** - UX consistency across all apps
2. **Apps override minimally** - Only when truly app-specific
3. **Constants eliminate magic numbers** - Named values, single source of truth
4. **DRY (Don't Repeat Yourself)** - Centralize common patterns

### Before (Fragmented)
```
Entry Point A
├─ 20 lines: Bootstrap finder logic (DUPLICATED)
├─ 45 lines: Overlay config with magic numbers (DUPLICATED)
└─ 35 lines: Font loading logic (DUPLICATED)

Entry Point B
├─ 20 lines: Bootstrap finder logic (DUPLICATED)
├─ 45 lines: Overlay config with magic numbers (DUPLICATED)
└─ 35 lines: Font loading logic (DUPLICATED)

... × 7 entry points = ~700 lines of duplication
```

### After (Centralized)
```
arkitekt/app/
├─ init.lua ─────────► Bootstrap (35 lines, used by all)
├─ constants.lua ────► Constants (126 lines, used by all)
├─ fonts.lua ────────► Font loading (75 lines, used by all)
└─ bootstrap.lua ────► (already existed)

Entry Point A: 3 + 7 + 1 = 11 lines
Entry Point B: 3 + 7 + 1 = 11 lines
... × 7 entry points = ~77 lines + 236 lines framework = 313 lines total

Reduction: 700 lines → 313 lines (~55% reduction)
```

---

## 🔧 Usage Examples

### 1. Bootstrap Pattern
```lua
-- Every entry point now uses this 3-line pattern:
local Init = require('arkitekt.app.init')
local ARK = Init.bootstrap()
if not ARK then return end

-- ARK now contains all framework utilities
local ImGui = ARK.ImGui
local Runtime = require('arkitekt.app.runtime')
```

### 2. Overlay Configuration

**Minimal (uses all framework defaults):**
```lua
overlay_mgr:push(OverlayDefaults.create_overlay_config({
  id = "my_overlay",
  render = function(ctx, alpha_val, bounds)
    -- your render logic
  end,
  on_close = cleanup,
}))
```

**With App-Specific Overrides:**
```lua
overlay_mgr:push(OverlayDefaults.create_overlay_config({
  id = "item_picker_main",
  esc_to_close = false,           -- Override: GUI handles ESC
  scrim_color = Colors.hexrgb("#FF0000"),  -- Override: Red scrim
  scrim_opacity = 0.92,           -- Override: More opaque
  render = ...,
  on_close = cleanup,
}))
```

### 3. Font Loading

**Using Framework Defaults:**
```lua
local Fonts = require('arkitekt.app.fonts')
local fonts = Fonts.load(ImGui, ctx)
-- fonts.default, fonts.title, fonts.monospace
-- sizes from constants.lua: BODY=13, HEADING=20, CODE=12
```

**With App-Specific Sizes:**
```lua
local fonts = Fonts.load(ImGui, ctx, {
  title_size = 24,      -- Override: Larger title
  monospace_size = 14   -- Override: Larger code font
})
```

### 4. Using Constants

```lua
local Constants = require('arkitekt.app.constants')

-- Typography
local body_size = Constants.TYPOGRAPHY.BODY  -- 13
local heading_size = Constants.TYPOGRAPHY.HEADING  -- 20

-- Animation
local fade_time = Constants.ANIMATION.FADE_NORMAL  -- 0.3
local fade_curve = Constants.ANIMATION.DEFAULT_FADE_CURVE  -- 'ease_out_quad'

-- Overlay
local button_size = Constants.OVERLAY.CLOSE_BUTTON_SIZE  -- 32
local padding = Constants.OVERLAY.CONTENT_PADDING  -- 24
```

---

## 🐛 Issues Fixed

### Issue 1: Fragile Path Resolution
**Problem:** Scripts moved from `scripts/RegionPlaylist/` to `ARKITEKT/` (3 levels up), breaking hardcoded `../../../` path climbing.

**Solution:** Universal root detection that scans upward for anchor file (`arkitekt/app/shell.lua`).

**Result:** Scripts work at any folder depth.

---

### Issue 2: Module Path Duplication
**Problem:** `package.path` included `arkitekt/` but modules already used full paths like `require('arkitekt.debug.profiler_init')`, causing duplicate prefix.

**Solution:** Removed extra `arkitekt/` from package.path entries in bootstrap.lua.

**Result:** Modules load correctly without path duplication.

---

### Issue 3: ReaPack Data Path
**Problem:** `[data]` directive moved fonts to `Data/arkitekt/fonts/` instead of preserving `Scripts/ARKITEKT/arkitekt/fonts/`.

**Solution:** Changed to `[nomain]` directive to preserve directory structure.

**Result:** Assets stay in correct paths relative to scripts.

---

### Issue 4: Settings Singleton
**Problem:** `Settings.open()` returned cached singleton, preventing multiple independent instances.

**Solution:** `Settings.new()` now always creates fresh instance. `Settings.open()` aliased for backward compatibility.

**Result:** Apps can have independent settings without state sharing.

---

## 📝 Files Modified

### Entry Points (7 total)
- ✅ `ARKITEKT/ARK_TemplateBrowser.lua`
- ✅ `ARKITEKT/ARK_ItemPicker.lua`
- ✅ `ARKITEKT/ARK_RegionPlaylist.lua`
- ✅ `ARKITEKT/ARK_ThemeAdjuster.lua`
- ✅ `ARKITEKT/ARKITEKT.lua`
- ✅ `ARKITEKT/scripts/ColorPalette/ARK_ColorPalette.lua`
- ✅ `ARKITEKT/scripts/ItemPicker/ARK_ItemPicker_Simple.lua`

### Framework Modules
- ✅ `ARKITEKT/arkitekt/app/bootstrap.lua` (path fixes)
- ✅ `ARKITEKT/arkitekt/core/settings.lua` (singleton fix)
- ✅ `ARKITEKT/arkitekt/gui/widgets/overlays/overlay/defaults.lua` (helper added)

### New Framework Modules
- 🆕 `ARKITEKT/arkitekt/app/init.lua`
- 🆕 `ARKITEKT/arkitekt/app/constants.lua`
- 🆕 `ARKITEKT/arkitekt/app/fonts.lua`

---

## 🚀 Future Improvements

Based on initial audit, additional refactoring opportunities:

1. **SetButtonState Duplication** - 5-line function duplicated across 3 files
2. **Cleanup Pattern** - Similar cleanup logic across all entry points
3. **Window.lua God Object** - 794-line file with too many responsibilities
4. **Profiler Integration** - Inconsistent (only 2 of 4 apps)
5. **Path Resolution Utilities** - `debug.getinfo()` pattern appears 20+ times

---

## 📚 Related Documentation

- **Primary Spec:** `ARKITEKT_Codex_Playbook_v5.md`
- **Quick Rules:** `AGENTS.md`
- **Project Flow:** `PROJECT_FLOW.md`
- **Dependencies:** `DEPENDENCIES.md`

---

## 🤝 Design Philosophy

This refactoring embodies the ARKITEKT principle:

> **Framework as Source of Truth**
>
> The framework provides consistent, well-tested defaults for all UX decisions. Applications should only override when there's a compelling app-specific reason.
>
> This ensures:
> - Uniform user experience across all ARKITEKT apps
> - Easy maintenance (fix once, improve everywhere)
> - Reduced cognitive load (one pattern to learn)
> - Faster development (less boilerplate)

**Pattern:**
```
Framework Default → App Override (only if needed) → User Preference (if implemented)
```

---

**End of Document**
