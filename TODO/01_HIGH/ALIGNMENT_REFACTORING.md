# ALIGNMENT REFACTORING PLAN

> **Goal:** Align ARKITEKT with ImGui, Lua, and REAPER conventions to prevent future mass refactors.

**Status:** Ready for execution
**Created:** 2025-12-02
**Estimated Effort:** 40-60 hours (with parallelization: ~15-20 hours)
**Files Affected:** ~450 files

---

## EXECUTIVE SUMMARY

This refactor fixes **7 critical inconsistencies** with ImGui/Lua/REAPER conventions:

1. ✅ **Ark.* Naming** - camelCase → PascalCase (matches ImGui)
2. ✅ **String Quotes** - `"` → `'` (Lua convention)
3. ✅ **Boolean Prefixes** - Add `is_*` to all boolean configs (matches ImGui)
4. ✅ **Error Handling** - pcall → xpcall for user callbacks (get stack traces)
5. ✅ **Return Values** - Checkbox/Combo/Slider positional mode (match ImGui tuples)
6. ✅ **Performance** - Fix per-frame config copying in combo.lua
7. ✅ **Naming Standards** - Document opts/config pattern

---

## PARALLELIZATION STRATEGY

### Branch Structure (Work in Parallel)

```
main
├── refactor/framework-alignment     # Core framework changes
├── refactor/itempicker-alignment    # ItemPicker script
├── refactor/regionplaylist-alignment # RegionPlaylist script
├── refactor/mediacontainer-alignment # MediaContainer script
├── refactor/colorpalette-alignment  # ColorPalette script
├── refactor/devkit-alignment        # DevKit script
└── refactor/demos-alignment         # All demo scripts
```

**Strategy:**
- 1 developer per branch (or automate per branch)
- Framework branch is **foundation** (merge first)
- Script branches rebase on framework after it's merged
- Each branch is independent until merge

**Timeline:**
1. **Day 1-2:** Framework branch (critical, blocks others)
2. **Day 3:** All script branches in parallel (can be done simultaneously)
3. **Day 4:** Integration testing, merge script branches
4. **Day 5:** Documentation updates, CLAUDE.md refresh

---

## PHASE 1: CRITICAL (Do First)

### 1.1 String Quotes: `"` → `'`

**Severity:** CRITICAL
**Files:** ~450 files
**Effort:** 2-3 hours (automated)
**Branch:** `refactor/framework-alignment`

**Pattern:**
```lua
-- BEFORE:
local ImGui = require("arkitekt.platform.imgui")
local label = "Save"

-- AFTER:
local ImGui = require('arkitekt.platform.imgui')
local label = 'Save'
```

**Automation:**
```bash
# Find all double-quoted strings (excluding escaped quotes)
rg '"[^"\\]*"' --type lua

# Regex replacement (use editor or sed):
# Pattern:  "([^"\\]*)"
# Replace:  '$1'

# CAUTION: Manual review needed for:
# - Strings with embedded single quotes: "it's" → 'it\'s'
# - JSON strings (if any)
# - Already-escaped strings
```

**Manual Review Needed:**
- `arkitekt/core/json.lua` - May have special quote handling
- Any multi-line strings
- Strings with escape sequences

---

### 1.2 Ark.* Naming: camelCase → PascalCase

**Severity:** CRITICAL
**Files:** ~50 widget files + loader
**Effort:** 1-2 hours (semi-automated)
**Branch:** `refactor/framework-alignment`

**Pattern:**
```lua
-- BEFORE (if any exist):
Ark.push_id(ctx, i)
Ark.pop_id(ctx)
Ark.same_line(ctx)

-- AFTER:
Ark.PushID(ctx, i)
Ark.PopID(ctx)
Ark.SameLine(ctx)
```

**Current Status:** Framework already uses PascalCase in `arkitekt/init.lua` MODULES table. Verify no snake_case Ark.* calls exist:

```bash
# Search for potential snake_case Ark calls
rg 'Ark\.\w+_\w+' --type lua

# Should return ZERO results (already clean)
```

**Verification Only:** Confirm all loader exports use PascalCase.

---

### 1.3 Boolean Prefixes: Add `is_*` to Config Properties

**Severity:** CRITICAL
**Files:** ~150 files (all widgets + apps)
**Effort:** 8-10 hours (semi-automated + manual testing)
**Branch:** `refactor/framework-alignment` (widgets), `refactor/*-alignment` (apps)

**Pattern:**
```lua
-- BEFORE:
local DEFAULTS = {
  disabled = false,
  checked = false,
  visible = true,
  readonly = false,
  multiline = false,
}

-- AFTER:
local DEFAULTS = {
  is_disabled = false,
  is_checked = false,
  is_visible = true,
  is_readonly = false,
  is_multiline = false,
}
```

**Automation:**
```bash
# Find all boolean config properties (requires manual filtering)
rg '^\s+(disabled|checked|visible|readonly|multiline|active|toggled|hovered|focused|expanded|collapsed)\s*=\s*(true|false)' --type lua

# Semi-automated replacement per file:
# 1. Find occurrences
# 2. Add is_ prefix to property name
# 3. Update all references in same file
```

**Files by Category:**

**Framework (Branch: refactor/framework-alignment):**
- `arkitekt/gui/widgets/primitives/*.lua` (~10 files)
  - button.lua: `disabled`, `toggled`, `blocking`
  - checkbox.lua: `disabled`, `checked`
  - combo.lua: `disabled`, `multiline`
  - slider.lua: `disabled`, `readonly`
- `arkitekt/gui/widgets/containers/*.lua` (~15 files)
  - panel: `collapsed`, `visible`
  - sliding_zone: `expanded`, `visible`
- `arkitekt/gui/widgets/overlays/*.lua` (~5 files)
- `arkitekt/gui/widgets/complex/*.lua` (~10 files)

**Scripts (Branch: refactor/[script]-alignment):**
- `scripts/ItemPicker/**/*.lua` (~30 files)
- `scripts/RegionPlaylist/**/*.lua` (~25 files)
- `scripts/MediaContainer/**/*.lua` (~15 files)
- `scripts/ColorPalette/**/*.lua` (~5 files)
- `scripts/DevKit/**/*.lua` (~10 files)
- `scripts/demos/*.lua` (~10 files)

**Breaking Changes:**
```lua
-- User code BEFORE:
if Ark.Button(ctx, {label = 'Save', disabled = true}) then end

-- User code AFTER:
if Ark.Button(ctx, {label = 'Save', is_disabled = true}) then end
```

**Migration Period:** Consider supporting BOTH for 1-2 releases:
```lua
-- In widget defaults merging:
opts.is_disabled = opts.is_disabled or opts.disabled  -- Backwards compat
if opts.disabled ~= nil then
  Logger.warn("DEPRECATED", "Use is_disabled instead of disabled")
end
```

---

### 1.4 Error Handling: pcall → xpcall for User Callbacks

**Severity:** CRITICAL
**Files:** 3 core files
**Effort:** 1 hour
**Branch:** `refactor/framework-alignment`

**Pattern:**
```lua
-- BEFORE:
local ok, result = pcall(fn, ...)
if not ok then
  Logger.error("CALLBACK", "%s failed: %s", context, result)
  -- No stack trace!
end

-- AFTER:
local ok, result = xpcall(fn, debug.traceback, ...)
if not ok then
  Logger.error("CALLBACK", "%s failed:\n%s", context, result)
  -- Full stack trace included!
end
```

**Files to Update:**

**1. arkitekt/core/callbacks.lua**
```lua
-- Line 51: safe_call_with_log
function M.safe_call_with_log(fn, context, ...)
  if not fn then return nil end

  -- CHANGE THIS:
  local ok, result = xpcall(fn, debug.traceback, ...)
  if not ok then
    local Logger = require('arkitekt.debug.logger')
    Logger.error("CALLBACK", "%s failed:\n%s", context or "Function", result)
    return nil
  end

  return result
end

-- Line 72: chain()
for i, callback in ipairs(callbacks) do
  if callback then
    -- CHANGE THIS:
    local ok, err = xpcall(callback, debug.traceback)
    if not ok then
      errors[#errors + 1] = string.format("Callback #%d failed:\n%s", i, err)
      -- ...
    end
  end
end

-- Line 175, 214: Batched callbacks
local ok, result = xpcall(fn, debug.traceback, table.unpack(args))
```

**2. arkitekt/core/events.lua**
```lua
-- Line 120: emit (single listener)
local ok, err = xpcall(listener.callback, debug.traceback, data)
if not ok then
  Logger.error("EVENTS", "Listener '%s' failed:\n%s", listener.id or "unknown", err)
end

-- Line 131: emit_typed (typed listener)
local ok, err = xpcall(listener.callback, debug.traceback, event_name, data)
if not ok then
  Logger.error("EVENTS", "Typed listener failed:\n%s", err)
end
```

**3. arkitekt/core/state_machine.lua**
```lua
-- Lines 184, 199, 208, 235, 247: State transitions
local ok, err = xpcall(state_def.on_exit, debug.traceback, self.context, action, target, payload)
local ok, err = xpcall(new_state_def.on_enter, debug.traceback, self.context, action, prev_state, payload)
xpcall(self.on_transition, debug.traceback, prev_state, target, action, payload)
```

**KEEP pcall for:**
- Optional requires: `pcall(require, 'module')`
- JSON parsing: `pcall(json.decode, str)`
- File operations: `pcall(io.open, path)`
- Settings serialization: `pcall(json.encode, data)`

**Testing:**
1. Create a button with broken callback: `on_click = function() error("test") end`
2. Click button
3. Verify error log shows FULL stack trace with file:line numbers

---

### 1.5 Widget Return Values: Match ImGui Tuples (Positional Mode)

**Severity:** CRITICAL
**Files:** 3 widget files
**Effort:** 1 hour
**Branch:** `refactor/framework-alignment`

**Problem:** Positional mode returns result table instead of ImGui-style `(changed, value)` tuple.

**Pattern:**
```lua
-- ImGui convention:
local changed, new_value = ImGui.Checkbox(ctx, 'Toggle', value)

-- ARKITEKT should match in positional mode:
local changed, new_value = Ark.Checkbox(ctx, 'Toggle', value)
```

**Files to Update:**

**1. arkitekt/gui/widgets/primitives/checkbox.lua:456-459**
```lua
-- BEFORE:
return setmetatable(M, {
  __call = function(_, ctx, ...)
    return M.draw(ctx, ...)  -- Returns result table
  end
})

-- AFTER:
return setmetatable(M, {
  __call = function(_, ctx, ...)
    local result = M.draw(ctx, ...)

    -- Detect mode: first arg is string = positional mode
    local first_arg = select(1, ...)
    if type(first_arg) == 'string' then
      -- Positional mode: Return ImGui-compatible tuple
      return result.changed, result.value
    else
      -- Opts mode: Return full result table
      return result
    end
  end
})
```

**2. arkitekt/gui/widgets/primitives/combo.lua:667-671**
```lua
-- Same pattern as checkbox
return setmetatable(M, {
  __call = function(_, ctx, ...)
    local result = M.draw(ctx, ...)
    local first_arg = select(1, ...)
    if type(first_arg) == 'string' then
      return result.changed, result.value  -- Tuple for positional
    else
      return result  -- Table for opts
    end
  end
})
```

**3. arkitekt/gui/widgets/primitives/slider.lua:321-325**
```lua
-- Same pattern
return setmetatable(M, {
  __call = function(_, ctx, ...)
    local result = M.draw(ctx, ...)
    local first_arg = select(1, ...)
    if type(first_arg) == 'string' then
      return result.changed, result.value  -- Tuple for positional
    else
      return result  -- Table for opts
    end
  end
})
```

**Testing:**
```lua
-- Positional mode (should work like ImGui)
local changed, val = Ark.Checkbox(ctx, 'Enable', my_flag)
if changed then my_flag = val end

-- Opts mode (keeps enhanced result)
local result = Ark.Checkbox(ctx, {label = 'Enable', checked = my_flag})
if result.changed then
  my_flag = result.value
  if result.hovered then -- Extra info available
    -- ...
  end
end
```

---

### 1.6 Performance: Fix Per-Frame Config Copying

**Severity:** CRITICAL
**Files:** 1 file
**Effort:** 30 minutes
**Branch:** `refactor/framework-alignment`

**File:** `arkitekt/gui/widgets/primitives/combo.lua:460-479`

**Problem:**
```lua
local instance = get_inst(context.unique_id)
if not instance then
  instance = Dropdown.new(context.unique_id, config, initial_value, initial_direction)
else
  -- ❌ BAD: Deep copy EVERY FRAME (60 FPS)
  instance.config = copy_config(config)
end
```

**Fix:**
```lua
local instance = get_inst(context.unique_id)
if not instance then
  -- First creation: Copy config
  instance = Dropdown.new(context.unique_id, config, initial_value, initial_direction)
else
  -- Subsequent frames: Only update changed fields
  -- Assume config is mostly immutable, only sync critical fields
  instance.selected_index = initial_value or instance.selected_index

  -- Optional: Support dynamic config updates (use equality check)
  if config.max_height ~= instance.config.max_height or
     config.max_width ~= instance.config.max_width then
    instance.config.max_height = config.max_height
    instance.config.max_width = config.max_width
  end

  -- Or if full sync needed, do shallow copy (not deep)
  -- for k, v in pairs(config) do
  --   instance.config[k] = v
  -- end
end
```

**Alternative (Better):** Make dropdown config immutable, replace entire instance if config changes:
```lua
local config_key = generate_config_hash(config)  -- Hash based on config values
local instance = get_inst(context.unique_id, config_key)
if not instance then
  instance = Dropdown.new(context.unique_id, config, initial_value, initial_direction)
  store_inst(context.unique_id, config_key, instance)
end
-- No updates needed, instance is tied to specific config
```

**Testing:**
- Profile dropdown rendering before/after
- Verify 60 FPS with 20+ combos on screen

---

## PHASE 2: HIGH PRIORITY (Can Be Separate PR)

### 2.1 Animation Triggering Consistency

**Severity:** HIGH
**Files:** ~20 widget files
**Effort:** 2-3 hours
**Branch:** `refactor/framework-alignment`

**Pattern:**
```lua
-- STANDARDIZE ON:

-- For hover animations (widgets):
Base.update_hover_animation(self, dt, is_hovered, is_active, "hover_alpha")

-- For other animations:
self.expand_alpha = Anim.animate_value(self.expand_alpha, target, dt, speed)

-- AVOID manual lerp:
-- self.alpha = self.alpha + (target - self.alpha) * speed * dt
```

**Files to Update:**
```bash
# Find manual lerp patterns
rg 'self\.\w+\s*=\s*self\.\w+\s*\+\s*\(' --type lua

# Replace with Anim.animate_value calls
```

---

### 2.2 Event Name Separator Consistency

**Severity:** HIGH
**Files:** ~30 files (all event emitters)
**Effort:** 1 hour
**Branch:** Per-script branches

**Pattern:**
```lua
-- BEFORE (inconsistent):
Events.emit('region:selected', data)    -- Colon
Events.emit('playlist_changed', data)   -- Underscore

-- AFTER (consistent):
Events.emit('region:selected', data)           -- Namespace separator
Events.emit('region:deselected', data)
Events.emit('playlist:changed', data)          -- Namespace separator
Events.emit('playlist:item_added', data)       -- Underscore for words, colon for namespace
```

**Standard:**
- Use `:` to separate namespace from event name
- Use `_` within event names for multiple words
- Format: `namespace:event_name`

**Examples:**
```lua
-- Good:
Events.emit('transport:play')
Events.emit('transport:stop')
Events.emit('region:selection_changed')
Events.emit('playlist:item_reordered')

-- Bad:
Events.emit('transport_play')  -- No namespace
Events.emit('region.selected')  -- Wrong separator
```

---

### 2.3 Function Localizations (Performance)

**Severity:** MEDIUM
**Files:** ~15 hot-path widget files
**Effort:** 2 hours
**Branch:** `refactor/framework-alignment`

**Pattern:**
```lua
-- At top of widget file (after requires):
local AddRectFilled = ImGui.DrawList_AddRectFilled
local AddRect = ImGui.DrawList_AddRect
local GetMousePos = ImGui.GetMousePos
local IsItemHovered = ImGui.IsItemHovered
local IsItemActive = ImGui.IsItemActive
local CalcTextSize = ImGui.CalcTextSize
local GetWindowDrawList = ImGui.GetWindowDrawList

-- Then use localized versions:
local dl = GetWindowDrawList(ctx)
AddRectFilled(dl, x1, y1, x2, y2, color)
```

**Files (hot paths):**
- `arkitekt/gui/widgets/primitives/button.lua`
- `arkitekt/gui/widgets/primitives/checkbox.lua`
- `arkitekt/gui/widgets/primitives/combo.lua`
- `arkitekt/gui/widgets/primitives/slider.lua`
- `arkitekt/gui/widgets/complex/grid/renderer.lua`
- `arkitekt/scripts/ItemPicker/ui/components/tile_renderer.lua`

**Performance Gain:** ~5-10% in hot widgets (measured in ItemPicker)

---

### 2.4 Theme Access Pattern Standardization

**Severity:** MEDIUM
**Files:** ~40 widget files
**Effort:** 2 hours
**Branch:** `refactor/framework-alignment`

**Pattern:**
```lua
-- PREFERRED (direct access):
local C = Theme.COLORS
local bg_color = C.BG_BASE
local text_color = C.TEXT_PRIMARY

-- AVOID (unless necessary):
local config = Theme.build_dropdown_config()  -- Only for complex components
Theme.apply_preset(config, 'BUTTON_DANGER')   -- Only for presets
```

**Standard:** Use direct `Theme.COLORS` access unless widget specifically needs preset system.

---

## PHASE 3: DOCUMENTATION

### 3.1 Update CLAUDE.md

**Files:** `CLAUDE.md`
**Effort:** 1 hour
**Branch:** `refactor/framework-alignment`

**Changes:**
```markdown
# Add to section 6: Naming standards

**Booleans**: All boolean config properties MUST use `is_` prefix
- Config: `is_disabled`, `is_checked`, `is_visible`
- Locals: `is_hovered`, `is_active`, `is_focused`
- Matches ImGui convention (IsItemHovered, IsMouseDown)

**Error Handling**:
- User callbacks: `xpcall(fn, debug.traceback)` (get stack traces)
- Optional requires: `pcall(require, 'module')` (expected failures)
- Validation: `return false, err` (let caller decide)
- Programming errors: `assert(condition, msg)` (fail fast)

**Event Names**: Use `namespace:event_name` format
- Namespace separator: `:` (colon)
- Word separator: `_` (underscore)
- Example: `region:selection_changed`

**String Literals**: Always use single quotes `'` (Lua convention)
- Exception: Strings with embedded single quotes: `"it's"`
```

**Update "cfg" references:**
```markdown
# Change section 1.6
- Old: "Local vars: `cfg` (not `config`)"
- New: "Local vars: `config` (not `cfg`), `state` (never `st`), `ctx`, `opts`"
```

---

### 3.2 Create CONVENTIONS.md Section

**Files:** `cookbook/CONVENTIONS.md`
**Effort:** 1 hour
**Branch:** `refactor/framework-alignment`

**Add new sections:**

```markdown
## Error Handling Patterns

### Use `xpcall` with `debug.traceback` for user callbacks:
```lua
local ok, result = xpcall(opts.on_click, debug.traceback)
if not ok then
  Logger.error('CALLBACK', 'on_click failed:\n%s', result)
end
```

### Use `pcall` for expected failures:
```lua
-- Optional modules
local ok, Module = pcall(require, 'optional.module')

-- JSON parsing (user data)
local ok, data = pcall(json.decode, json_str)
```

### Use `assert` for programming errors:
```lua
assert(ctx, 'ctx cannot be nil')
assert(type(opts) == 'table', 'opts must be a table')
```

### Use `return false, err` for validation:
```lua
function validate_path(path)
  if not path then return false, 'Path required' end
  return true
end
```

## Boolean Naming

All boolean properties MUST use `is_` prefix:

```lua
-- Config properties
local DEFAULTS = {
  is_disabled = false,
  is_checked = false,
  is_visible = true,
}

-- Local variables
local is_hovered = ImGui.IsItemHovered(ctx)
local is_active = opts.is_disabled or false
```

## Event Naming

Use `namespace:event_name` format:

```lua
Events.emit('region:selected', data)
Events.emit('playlist:item_added', item)
Events.emit('transport:state_changed', state)
```
```

---

### 3.3 Update Widget Documentation

**Files:** `cookbook/WIDGETS.md`, `cookbook/QUICKSTART.md`
**Effort:** 1 hour
**Branch:** `refactor/framework-alignment`

**Update all examples:**
```lua
-- Old examples:
if Ark.Button(ctx, {label = 'Save', disabled = true}) then end

-- New examples:
if Ark.Button(ctx, {label = 'Save', is_disabled = true}) then end

-- Document return value modes:
-- Positional mode (ImGui-compatible):
local changed, value = Ark.Checkbox(ctx, 'Enable', flag)

-- Opts mode (enhanced):
local result = Ark.Checkbox(ctx, {label = 'Enable', checked = flag})
-- result.changed, result.value, result.hovered, result.active
```

---

## TESTING STRATEGY

### Automated Tests

**1. Regex Validation (Post-Refactor):**
```bash
# No double quotes (except special cases)
rg '"[^"]*"' --type lua | grep -v "it's\|can't\|won't"

# No snake_case Ark.* calls
rg 'Ark\.\w+_\w+' --type lua

# All boolean configs have is_ prefix
rg '^\s+(disabled|checked|visible|active|readonly)\s*=' --type lua
# Should return ZERO results

# Event names use colon separator
rg "Events\.emit\('[^:]+'\)" --type lua
# Should return ZERO results (all should have colon)
```

**2. Unit Tests:**
```lua
-- Test checkbox return values
function test_checkbox_positional_mode()
  local changed, value = Ark.Checkbox(ctx, 'Test', true)
  assert(type(changed) == 'boolean', 'First return should be boolean')
  assert(type(value) == 'boolean', 'Second return should be boolean')
end

function test_checkbox_opts_mode()
  local result = Ark.Checkbox(ctx, {label = 'Test', checked = true})
  assert(type(result) == 'table', 'Should return result table')
  assert(result.changed ~= nil, 'Should have changed field')
  assert(result.value ~= nil, 'Should have value field')
end
```

**3. Performance Tests:**
```lua
-- Measure combo dropdown perf
local start = reaper.time_precise()
for i = 1, 100 do
  Ark.Combo(ctx, {label = 'Test', selected = 1, options = items})
end
local elapsed = reaper.time_precise() - start
assert(elapsed < 0.016, 'Should render 100 combos in < 16ms')
```

### Manual Testing Checklist

**Per Script:**
- [ ] App launches without errors
- [ ] All widgets render correctly
- [ ] Button clicks trigger callbacks with stack traces on error
- [ ] Checkboxes return correct values in both modes
- [ ] Combos render at 60 FPS with 10+ instances
- [ ] Theme colors applied correctly
- [ ] Settings save/load works
- [ ] No console warnings about deprecated patterns

**Integration:**
- [ ] All apps work together (Hub → launches → apps)
- [ ] No global conflicts
- [ ] Performance baseline maintained
- [ ] Memory usage unchanged

---

## ROLLBACK PLAN

**If Refactor Fails:**

1. **Revert branches:**
   ```bash
   git checkout main
   git branch -D refactor/framework-alignment
   git branch -D refactor/*-alignment
   ```

2. **Cherry-pick non-breaking changes:**
   - Documentation updates (safe)
   - Performance fixes (safe)
   - Error handling (safe, improves debugging)

3. **Incremental approach:**
   - Do Phase 1 items one at a time
   - Test each change independently
   - Merge to staging before main

---

## SUCCESS METRICS

**After refactor, verify:**

1. ✅ **Zero double-quoted strings** (except special cases)
2. ✅ **Zero snake_case Ark.* calls**
3. ✅ **All boolean configs have `is_` prefix**
4. ✅ **User callbacks produce stack traces on error**
5. ✅ **Checkbox/Combo/Slider return tuples in positional mode**
6. ✅ **Combo dropdown perf: 100 instances < 16ms**
7. ✅ **All events use `namespace:event_name` format**
8. ✅ **CLAUDE.md accurately reflects codebase**
9. ✅ **No breaking changes for end users** (migration period for booleans)

---

## BRANCH MERGE ORDER

```
1. refactor/framework-alignment     (MERGE FIRST - foundation)
   ↓
2. All script branches in parallel: (REBASE on framework, then merge)
   - refactor/itempicker-alignment
   - refactor/regionplaylist-alignment
   - refactor/mediacontainer-alignment
   - refactor/colorpalette-alignment
   - refactor/devkit-alignment
   - refactor/demos-alignment
   ↓
3. Final integration testing
   ↓
4. Merge to main
```

---

## EXECUTION TIMELINE (Parallelized)

**Day 1:**
- [ ] Create all branches
- [ ] Framework branch: String quotes (automated)
- [ ] Framework branch: Boolean prefixes in framework widgets
- [ ] Framework branch: Error handling (callbacks.lua, events.lua)

**Day 2:**
- [ ] Framework branch: Widget return values (3 files)
- [ ] Framework branch: Performance fix (combo.lua)
- [ ] Framework branch: Merge to staging, test
- [ ] **Checkpoint:** Framework branch tested, ready for script rebases

**Day 3 (Parallel Work):**
- [ ] ItemPicker: Boolean prefixes + string quotes
- [ ] RegionPlaylist: Boolean prefixes + string quotes
- [ ] MediaContainer: Boolean prefixes + string quotes + bootstrap fix
- [ ] ColorPalette: Boolean prefixes + string quotes
- [ ] DevKit: Boolean prefixes + string quotes
- [ ] Demos: Boolean prefixes + string quotes

**Day 4:**
- [ ] All scripts: Rebase on framework branch
- [ ] All scripts: Test independently
- [ ] Merge script branches to staging

**Day 5:**
- [ ] Integration testing (all apps together)
- [ ] Documentation updates (CLAUDE.md, CONVENTIONS.md)
- [ ] Performance validation
- [ ] Merge to main

---

## WORKFLOW: Claude-Assisted Refactoring

**⚠️ WARNING:** Do NOT use blind regex/sed replacements. They will break code.

**✅ SAFE APPROACH:** Find (grep) → Claude edits (surgical) → You review (test)

---

### Strategy 1: String Quotes (Semi-Automated)

**Step 1: Find files with double quotes**
```bash
# Safe - just searches, doesn't modify
rg '"[^"]*"' --type lua -n > quotes_to_fix.txt
```

**Step 2: Group files by directory**
```bash
# Framework widgets (batch 1)
rg '"[^"]*"' arkitekt/gui/widgets/primitives/ --type lua --files-with-matches

# Framework core (batch 2)
rg '"[^"]*"' arkitekt/core/ --type lua --files-with-matches

# Scripts (batch 3+)
rg '"[^"]*"' scripts/ItemPicker/ --type lua --files-with-matches
```

**Step 3: Claude edits each batch**
```
You: "Fix string quotes in arkitekt/gui/widgets/primitives/"
Claude:
  1. Greps for files in that directory
  2. Reads each file
  3. Identifies safe changes:
     - require("arkitekt.*") → require('arkitekt.*') ✅
     - local x = "simple" → local x = 'simple' ✅
     - "it's" → leave as-is or escape to 'it\'s' ✅
     - JSON strings → leave as-is ✅
  4. Uses Edit tool for surgical changes
  5. Shows you the changes

You: Review diffs, test, commit
```

**Step 4: Validate batch**
```bash
# Check this directory is clean
rg '"[^"]*"' arkitekt/gui/widgets/primitives/ --type lua | wc -l
# Should be 0 or only special cases
```

**Batch Size:** 10-20 files at a time, test between batches

---

### Strategy 2: Boolean Prefixes (Manual with Claude)

**Step 1: Find candidates**
```bash
# Safe - just searches
rg '^\s+(disabled|checked|visible|active|readonly|toggled|focused|expanded|collapsed|multiline|blocking)\s*=\s*(true|false)' --type lua -n > booleans.txt

# Group by file
rg '^\s+(disabled|checked|visible)\s*=' arkitekt/gui/widgets/primitives/button.lua -n
```

**Step 2: Claude edits one file at a time**
```
You: "Add is_ prefix to booleans in button.lua"
Claude:
  1. Reads button.lua
  2. Identifies DEFAULTS table
  3. Changes: disabled = false → is_disabled = false
  4. Finds ALL references in file:
     - opts.disabled → opts.is_disabled
     - if config.disabled → if config.is_disabled
     - {disabled = true} → {is_disabled = true}
  5. Uses Edit tool for each change
  6. Shows you ALL changes in file

You: Review, test widget, commit
```

**Step 3: Test the widget**
```lua
-- Manual test in demo
if Ark.Button(ctx, {label = 'Test', is_disabled = true}) then
  reaper.ShowConsoleMsg('Should not click\n')
end
```

**⚠️ Breaking Change:** Update user-facing examples after framework is done

---

### Strategy 3: Error Handling (Simple - Claude Only)

**Files:** 3 core files only
```
You: "Update callbacks.lua to use xpcall with debug.traceback"
Claude:
  1. Reads callbacks.lua
  2. Changes pcall → xpcall(fn, debug.traceback, ...)
  3. Updates error messages to include \n%s for stack trace
  4. Uses Edit tool
  5. Shows you changes

You: Test with intentional error callback
```

**Testing:**
```lua
-- Create test with broken callback
local btn = Ark.Button(ctx, {
  label = 'Test',
  on_click = function()
    error('Intentional test error')
  end
})

-- Click button, verify console shows FULL stack trace
```

---

### Strategy 4: Validation Scripts (Safe - Keep These)

**After each batch, run validation:**

```bash
#!/bin/bash
# validate_batch.sh

echo "=== Validating Current Batch ==="

# 1. Count remaining double quotes
QUOTES=$(rg '"[^"]*"' --type lua | wc -l)
echo "Double quotes remaining: $QUOTES"

# 2. Check for snake_case Ark calls
SNAKE=$(rg 'Ark\.\w+_\w+' --type lua)
if [ -z "$SNAKE" ]; then
  echo "✅ No snake_case Ark calls found"
else
  echo "❌ Found snake_case Ark calls:"
  echo "$SNAKE"
fi

# 3. Check syntax errors
echo "Checking Lua syntax..."
find . -name "*.lua" -type f -exec lua -e "dofile('{}')" \; 2>&1 | grep -i error

echo "=== Validation Complete ==="
```

**Run after:**
- Each file/batch commit
- Before merging branches
- Final validation before main merge

---

## WORK DIVISION BY BRANCH

### **Branch: refactor/framework-alignment** (Foundation - Do First)

**Owner:** You or primary developer
**Effort:** ~10-12 hours
**Files:** ~80 framework files

**Work breakdown:**
```
Day 1 (4 hours):
├── String quotes: arkitekt/core/*.lua (12 files)
├── String quotes: arkitekt/gui/widgets/primitives/*.lua (10 files)
├── Boolean prefixes: primitives/*.lua (10 files)
└── Test batch 1

Day 2 (4 hours):
├── String quotes: arkitekt/gui/widgets/containers/*.lua (15 files)
├── String quotes: arkitekt/gui/widgets/complex/*.lua (10 files)
├── Boolean prefixes: containers/*.lua (15 files)
├── Error handling: callbacks.lua, events.lua, state_machine.lua (3 files)
└── Test batch 2

Day 3 (4 hours):
├── Widget return values: checkbox.lua, combo.lua, slider.lua (3 files)
├── Performance fix: combo.lua (1 file)
├── String quotes: arkitekt/platform/*.lua, arkitekt/app/*.lua (20 files)
├── Full framework integration test
└── Merge to staging
```

---

### **Branch: refactor/itempicker-alignment** (Parallel after framework)

**Owner:** Developer 2 or you (separate session)
**Effort:** ~3-4 hours
**Files:** ~30 files in scripts/ItemPicker/

**Work breakdown:**
```
After framework merged:
├── Rebase on framework branch
├── String quotes: ItemPicker/**/*.lua (batch by directory)
├── Boolean prefixes: ui/components/*.lua
├── Event naming: Fix event emitters
├── Test ItemPicker app
└── Merge to staging
```

---

### **Branch: refactor/regionplaylist-alignment** (Parallel)

**Owner:** Developer 3 or you (separate session)
**Effort:** ~3-4 hours
**Files:** ~25 files in scripts/RegionPlaylist/

**Work breakdown:**
```
After framework merged:
├── Rebase on framework branch
├── String quotes: RegionPlaylist/**/*.lua
├── Boolean prefixes: ui/views/*.lua
├── Event naming: Fix event emitters
├── Test RegionPlaylist app
└── Merge to staging
```

---

### **Branch: refactor/mediacontainer-alignment** (Parallel)

**Owner:** Developer 4 or you (separate session)
**Effort:** ~2-3 hours
**Files:** ~15 files in scripts/MediaContainer/

**Work breakdown:**
```
After framework merged:
├── Rebase on framework branch
├── String quotes: MediaContainer/**/*.lua
├── Boolean prefixes: ui/*.lua
├── Bootstrap pattern: Fix ARK_MediaContainer.lua (use dofile)
├── Test MediaContainer app
└── Merge to staging
```

---

### **Branch: refactor/colorpalette-alignment** (Parallel)

**Owner:** Developer 5 or you (separate session)
**Effort:** ~1-2 hours
**Files:** ~5 files in scripts/ColorPalette/

**Simple - smallest app**

---

### **Branch: refactor/devkit-alignment** (Parallel)

**Owner:** Developer 6 or you (separate session)
**Effort:** ~2 hours
**Files:** ~10 files in devkit/

---

### **Branch: refactor/demos-alignment** (Parallel)

**Owner:** Developer 7 or you (separate session)
**Effort:** ~2 hours
**Files:** ~10 demo files in scripts/demos/

---

## REALISTIC TIMELINE

### **If Working Solo (You + Claude):**

```
Week 1:
├── Mon-Wed: Framework branch (10-12 hrs)
├── Thu: ItemPicker + RegionPlaylist (6-8 hrs)
├── Fri: MediaContainer + ColorPalette + DevKit + Demos (6-8 hrs)
└── Weekend: Integration testing, documentation

Total: ~25-30 hours spread over 1 week
```

### **If Working with Team (Parallel):**

```
Day 1-2: Framework branch (critical path)
Day 3: All 6 script branches in parallel (each dev 2-4 hrs)
Day 4: Integration testing
Day 5: Documentation updates, merge to main

Total: ~15-20 hours calendar time (parallelized)
```

---

## COMMIT STRATEGY

**Small, frequent commits:**

```bash
# After each file or small batch
git add button.lua
git commit -m "refactor: Add is_ prefix to button.lua booleans"

# After each directory
git add arkitekt/gui/widgets/primitives/
git commit -m "refactor: String quotes in primitives widgets"

# After each phase
git add arkitekt/core/callbacks.lua arkitekt/core/events.lua
git commit -m "refactor: Use xpcall for user callbacks (stack traces)"
```

**Benefits:**
- Easy to revert individual changes
- Clear history of what changed
- Can cherry-pick specific fixes if needed

---

## NOTES

- **Breaking Change:** Boolean prefix refactor (`disabled` → `is_disabled`) breaks user code
  - **Mitigation:** Support both for 2 releases, warn on old usage
  - **Alternative:** Deprecation period with automatic migration script

- **Low Risk Changes:** String quotes, error handling, return values (internal only)

- **High Impact:** Performance fix (combo.lua) - measure before/after

- **Regression Testing:** Run all apps after each phase

---

## REFERENCES

- `CODEBASE_REVIEW.md` - Full inconsistency analysis
- `CLAUDE.md` - Current conventions (needs update)
- `cookbook/CONVENTIONS.md` - Detailed patterns (needs update)
- `references/imgui/ReaImGui_Demo.lua` - ImGui reference patterns
- `cookbook/LUA_PERFORMANCE_GUIDE.md` - Performance best practices

---

**Ready to Execute:** 2025-12-02
**Next Action:** Create branches and start Phase 1 (Framework)
