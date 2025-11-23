# Configuration Management - Best Practices & Refactoring Guide

## The Problem We're Facing

### Root Cause
We have **6 different patterns** for merging configs across the codebase, leading to:
- 🐛 **Bugs from precedence conflicts** (panel defaults override presets)
- 🔄 **Unpredictable behavior** (different merge strategies in different components)
- 📝 **Duplicated defaults** (same values defined in multiple places)
- 🎯 **Hard to reason about** (unclear which config "wins")

### Recent Bug Example
```lua
# Panel config.lua (ELEMENT_STYLE.button)
bg_on_color = WHITE  # Hardcoded white toggle color

# User's button config
preset_name = "BUTTON_TOGGLE_TEAL"  # Trying to use teal

# Result: WHITE wins because panel merge happens first!
```

---

## Lua Best Practices for Config Management

### 1. **Single Source of Truth**
❌ **DON'T:** Define the same default in multiple places
```lua
-- panel/config.lua
ELEMENT_STYLE.button = { bg_on_color = hexrgb("#434343FF") }

-- style_defaults.lua
BUTTON_TOGGLE.bg_on_color = hexrgb("#434343FF")
```

✅ **DO:** Define defaults once, reference everywhere
```lua
-- style_defaults.lua (single source)
M.BUTTON_TOGGLE_WHITE = create_toggle_style(M.TOGGLE_VARIANTS.WHITE)

-- panel/config.lua (no toggle colors, just context overrides)
ELEMENT_STYLE.button = {
  -- Only panel-specific base colors, NO toggle colors
}
```

---

### 2. **Clear Precedence Hierarchy**

Define explicit order:
```
BASE DEFAULTS < PRESET < CONTEXT DEFAULTS < USER CONFIG
```

❌ **DON'T:** Merge at multiple levels without clear rules
```lua
-- Panel merges first
config = deepMerge(ELEMENT_STYLE, user_config)
-- Then button tries to apply preset (too late!)
config = apply_defaults(PRESET, config)
```

✅ **DO:** Single merge point with explicit precedence
```lua
function resolve_config(user_config, context)
  -- 1. Start with base
  local config = BASE_DEFAULTS

  -- 2. Apply preset if specified
  if user_config.preset_name then
    config = merge(config, PRESETS[user_config.preset_name])
  end

  -- 3. Apply context defaults (only non-conflicting keys)
  config = merge_safe(config, context.defaults)

  -- 4. User config wins everything
  config = merge(config, user_config)

  return config
end
```

---

### 3. **Immutable Presets**

Presets should be **frozen complete configs**, not partials.

❌ **DON'T:** Partial presets that need merging
```lua
BUTTON_TOGGLE_TEAL = {
  -- Only toggle colors, missing base colors
  bg_on_color = TEAL,
  text_on_color = TEAL,
}
```

✅ **DO:** Complete, self-contained presets
```lua
BUTTON_TOGGLE_TEAL = {
  -- ALL colors defined (OFF + ON states)
  bg_color = BASE_BG,
  text_color = BASE_TEXT,
  bg_on_color = TEAL_BG,
  text_on_color = TEAL_TEXT,
  -- ... complete config
}

-- Make it immutable (Lua doesn't have const, but document it)
-- DO NOT MODIFY - use as base for merging only
```

---

### 4. **Explicit Over Implicit**

Make config sources obvious.

❌ **DON'T:** Hidden defaults buried in code
```lua
local bg = config.bg or hexrgb("#252525FF")  -- Magic value!
```

✅ **DO:** Named, discoverable defaults
```lua
-- At top of file
local DEFAULTS = {
  bg = hexrgb("#252525FF"),
  border = hexrgb("#000000DD"),
}

local bg = config.bg or DEFAULTS.bg
```

---

### 5. **Shallow Merge for Simple Configs, Deep Only When Needed**

❌ **DON'T:** Always deep merge everything
```lua
-- Unnecessarily complex for flat configs
config = deepMerge(defaults, user_config)
```

✅ **DO:** Match strategy to structure
```lua
-- Simple flat config? Shallow merge
for k, v in pairs(defaults) do
  if config[k] == nil then
    config[k] = v
  end
end

-- Nested config (e.g., popup.styles.item)? Deep merge
if type(v) == "table" and type(config[k]) == "table" then
  config[k] = deepMerge(v, config[k])
else
  config[k] = v
end
```

---

### 6. **Lazy Evaluation**

Apply defaults at the **last responsible moment** (render time, not creation time).

❌ **DON'T:** Apply defaults when creating config
```lua
function Panel.new(config)
  self.config = apply_defaults(DEFAULTS, config)  -- Too early!
  -- Now user can't override later
end
```

✅ **DO:** Apply defaults when using config
```lua
function Panel.new(config)
  self.user_config = config  -- Store as-is
end

function Panel:draw()
  -- Apply defaults at render time
  local config = apply_defaults(DEFAULTS, self.user_config)
  -- Use config...
end
```

---

### 7. **No Mutation of Inputs**

Never modify the user's config object.

❌ **DON'T:** Mutate in place
```lua
function apply_defaults(config)
  config.bg = config.bg or DEFAULT_BG  -- Mutates user's table!
  return config
end
```

✅ **DO:** Create new table
```lua
function apply_defaults(defaults, user_config)
  local result = {}
  for k, v in pairs(defaults) do
    result[k] = user_config[k] ~= nil and user_config[k] or v
  end
  return result  -- New table
end
```

---

### 8. **Type Validation (Bonus)**

Catch config errors early.

```lua
function validate_button_config(config)
  assert(type(config.bg_color) == "number", "bg_color must be integer color")
  assert(type(config.label) == "string" or config.label == nil, "label must be string")
  -- ... more checks
  return true
end
```

---

## Recommended Refactoring Plan

### Phase 1: Standardize Merge Functions (Quick Win)
Create **one merge utility** everyone uses:

```lua
-- arkitekt/core/config.lua (NEW FILE)
local M = {}

-- Shallow merge (for flat configs)
function M.merge(base, override)
  local result = {}
  for k, v in pairs(base) do result[k] = v end
  for k, v in pairs(override or {}) do result[k] = v end
  return result
end

-- Deep merge (for nested configs)
function M.deepMerge(base, override)
  if type(base) ~= "table" then return override end
  if type(override) ~= "table" then return base end

  local result = {}
  for k, v in pairs(base) do result[k] = v end

  for k, v in pairs(override) do
    if type(v) == "table" and type(result[k]) == "table" then
      result[k] = M.deepMerge(result[k], v)
    else
      result[k] = v
    end
  end
  return result
end

-- Apply defaults (with optional deep merge for specific keys)
function M.apply_defaults(defaults, user_config, deep_keys)
  user_config = user_config or {}
  deep_keys = deep_keys or {}

  local result = {}

  -- Handle defaults
  for k, v in pairs(defaults) do
    if deep_keys[k] and type(v) == "table" and type(user_config[k]) == "table" then
      result[k] = M.deepMerge(v, user_config[k])
    else
      result[k] = user_config[k] ~= nil and user_config[k] or v
    end
  end

  -- Add extra user keys
  for k, v in pairs(user_config) do
    if result[k] == nil then
      result[k] = v
    end
  end

  return result
end

return M
```

**Action:** Replace all 6 patterns with these 3 functions.

---

### Phase 2: Fix Preset System (Medium Priority)

**Current Problems:**
1. Panel config has hardcoded toggle colors ✅ **FIXED**
2. Preset application happens after panel merge ❌ **STILL WRONG**

**Solution:**
```lua
-- button.lua - CORRECT ORDER
function M.draw(ctx, dl, x, y, width, height, user_config, state_or_id)
  local config

  -- 1. Start with base
  local base = Style.BUTTON

  -- 2. Apply preset FIRST (before any merging)
  if user_config and user_config.preset_name then
    base = Config.merge(base, Style[user_config.preset_name])
  end

  -- 3. Apply context defaults (panel-specific) - only non-preset keys
  local context_defaults = get_context_defaults(state_or_id)
  if context_defaults then
    -- Only merge keys that preset doesn't define
    for k, v in pairs(context_defaults) do
      if base[k] == nil then
        base[k] = v
      end
    end
  end

  -- 4. User config always wins
  config = Config.merge(base, user_config)

  return config
end
```

---

### Phase 3: Eliminate Duplicate Defaults (Long Term)

**Audit:**
```bash
# Find all hexrgb color definitions
grep -r "hexrgb(" --include="*.lua" | grep -E "(bg_color|border|text_color)" | sort | uniq -c

# Find duplicate default structures
grep -r "DEFAULTS\|DEFAULT_CONFIG\|ELEMENT_STYLE" --include="*.lua"
```

**Consolidate:**
- Move ALL base colors to `core/colors.lua`
- Move ALL control defaults to `widgets/controls/style_defaults.lua`
- Remove defaults from `panel/config.lua` (except panel-specific geometry)

---

## Quick Reference Card

### When to Use Each Pattern

| Use Case | Pattern | Example |
|----------|---------|---------|
| Flat config (1 level) | Shallow merge | `button = { bg, border, text }` |
| Nested config (2+ levels) | Deep merge | `dropdown = { popup = { item = {...} } }` |
| Preset selection | Preset + merge | `preset_name = "BUTTON_TOGGLE_TEAL"` |
| Context overrides | Safe merge (skip existing) | Panel adding rounding to preset buttons |
| User final say | Direct assignment | `config.bg = user_config.bg or default` |

### Merge Precedence (Left to Right, Right Wins)

```
BASE → PRESET → CONTEXT → USER
```

### Golden Rules

1. ✅ One source of truth for each default
2. ✅ Presets are complete, immutable configs
3. ✅ User config always wins
4. ✅ Never mutate input tables
5. ✅ Apply defaults late (at use time)
6. ✅ Document precedence clearly

---

## Files That Need Refactoring

### High Priority (Causing Bugs)
- [x] `panel/config.lua` - Remove toggle color defaults ✅ DONE
- [ ] `panel/header/layout.lua` - Fix merge order (context before user)
- [ ] `widgets/controls/button.lua` - Apply preset before context merge

### Medium Priority (Inconsistent Patterns)
- [ ] `widgets/overlay/config.lua` - Replace triple-nest with deepMerge
- [ ] `widgets/nodal/config.lua` - Replace triple-nest with deepMerge
- [ ] `widgets/navigation/menutabs.lua` - Use standard merge utilities

### Low Priority (Already Working)
- [ ] `widgets/displays/status_pad.lua` - Simple pattern, works fine
- [ ] `widgets/panel/header/tab_strip.lua` - Simple pattern, works fine

---

## Testing Strategy

After refactoring each component:

```lua
-- Test precedence order
local config = Component.create({
  preset_name = "PRESET_A",  -- Should apply
  bg_color = USER_COLOR,     -- Should override preset
})

assert(config.bg_color == USER_COLOR, "User config should win")
assert(config.border == PRESET_A.border, "Preset should fill gaps")
```

---

## Summary

**The Core Problem:** Merging configs at multiple layers without clear precedence rules.

**The Solution:**
1. Single merge utility (3 functions)
2. Clear precedence: `BASE → PRESET → CONTEXT → USER`
3. Presets are complete configs, not partials
4. Apply defaults late, never mutate inputs

**Impact:**
- 🐛 Fewer bugs from conflicting defaults
- 📖 Easier to understand config flow
- ♻️ More reusable preset system
- 🚀 Faster debugging (one place to look)
