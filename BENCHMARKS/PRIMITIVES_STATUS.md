# Primitives Optimization Status

**Last Updated:** January 2025

This document tracks which optimizations from `BUTTON_OPTIMIZATION_2025-01.md` have been applied to other primitive widgets.

---

## Optimization Summary

| Optimization | Button | Other Primitives | Notes |
|--------------|--------|------------------|-------|
| #1: rawget ID fix | ✅ Applied | ✅ **Automatic** | Fixed in `base.lua`, all widgets benefit |
| #2: Remove table reuse | ✅ Applied | ✅ **N/A** | Button-specific (positional API) |
| #4: Remove config copies | ✅ Applied | ❌ **Not Applied** | Still doing manual config building |

---

## Individual Widget Status

### ✅ Fully Optimized

**button.lua**
- All 3 optimizations applied
- Positional API (`Ark.Button(ctx, "Label")`) working correctly
- Config uses opts directly instead of copying

### ⚠️ Partially Optimized (Automatic)

These widgets automatically benefit from the `base.lua` rawget fix, but still have inefficient `resolve_config()`:

**checkbox.lua**
- ✅ ID resolution fixed (via Base.resolve_id)
- ❌ Still manually builds config with ~20 field assignments
- Impact: Likely similar to button (copying overhead)

**inputtext.lua**
- ✅ ID resolution fixed (via Base.resolve_id)
- ❌ Calls `Theme.build_search_input_config()` + iterates all opts
- Impact: Unknown, depends on Theme function

**slider.lua**
- ✅ ID resolution fixed (via Base.resolve_id)
- ❌ Has `resolve_config()` (need to check implementation)

**radio_button.lua**
- ✅ ID resolution fixed (via Base.resolve_id)
- ❌ May have config building overhead

**spinner.lua**
- ✅ ID resolution fixed (via Base.resolve_id)
- ❌ May have config building overhead

**splitter.lua**
- ✅ ID resolution fixed (via Base.resolve_id)
- ❌ May have config building overhead

**corner_button.lua**
- ✅ ID resolution fixed (via Base.resolve_id)
- ❌ May have config building overhead

### ℹ️ No resolve_config

These widgets don't have a `resolve_config()` function, so optimization #4 doesn't apply:

- badge.lua
- close_button.lua
- combo.lua
- hue_slider.lua
- loading_spinner.lua
- markdown_field.lua
- progress_bar.lua
- scrollbar.lua

---

## Checkbox Example (Needs Optimization)

**Current implementation:**
```lua
local function resolve_config(opts)
  local config = {
    -- Manual field assignments (~20 fields)
    size = opts.size or DEFAULTS.size,
    disabled = opts.disabled or DEFAULTS.disabled,
    is_blocking = opts.is_blocking or DEFAULTS.is_blocking,
    rounding = opts.rounding or DEFAULTS.rounding,
    alpha = opts.alpha or DEFAULTS.alpha,
    label_spacing = opts.label_spacing or DEFAULTS.label_spacing,

    -- Theme colors (~15 more fields)
    bg_color = Theme.COLORS.BG_BASE,
    bg_hover_color = Theme.COLORS.BG_HOVER,
    -- ... etc
  }
  return config
end
```

**Optimized version (like button):**
```lua
local function resolve_config(opts)
  -- opts already has metatable fallback to DEFAULTS
  local config = opts

  -- Only set dynamic theme colors that can't be in DEFAULTS
  config._bg_color = Theme.COLORS.BG_BASE
  config._bg_hover_color = Theme.COLORS.BG_HOVER
  -- etc...

  return config
end
```

**Savings:** ~20 field assignments per call → 0

---

## InputText Example (Different Pattern)

**Current implementation:**
```lua
local function resolve_config(opts)
  -- Calls Theme function (creates new table)
  local config = Theme.build_search_input_config()

  -- Apply preset (iterates table)
  if type(opts.preset) == "table" then
    for k, v in pairs(opts.preset) do
      config[k] = v
    end
  end

  -- Apply user overrides (iterates again!)
  for k, v in pairs(opts) do
    if v ~= nil and config[k] ~= nil then
      config[k] = v
    end
  end

  return config
end
```

**Issues:**
1. `Theme.build_search_input_config()` creates new table
2. Two `pairs()` iterations over opts
3. Lots of assignments

**Needs investigation:** What does `Theme.build_search_input_config()` do?

---

## Should We Optimize Others?

### Priority Assessment

**High Priority (if used frequently):**
- `checkbox.lua` - Likely used a lot, clear optimization path
- `inputtext.lua` - Depends on usage frequency

**Medium Priority:**
- `slider.lua`, `radio_button.lua` - Depends on usage

**Low Priority:**
- `spinner.lua`, `splitter.lua`, `corner_button.lua` - Less commonly used

### Decision Criteria

Only optimize if:

1. **Widget is used frequently** (>10 instances per frame)
2. **Optimization is simple** (like button: just use opts directly)
3. **Clear performance problem** (profile first!)

**Remember:** Button optimization showed:
- 14ms for 1000 buttons
- Copying 80 fields was the bottleneck
- But buttons are rarely the bottleneck in real apps

**Don't optimize prematurely.** Profile real apps first.

---

## How to Apply Optimizations

If you decide to optimize another primitive:

### Step 1: Profile First

Use the benchmark pattern from `scripts/Sandbox/Sandbox_10.lua`:

```lua
-- Test 1000 instances of the widget
local start = reaper.time_precise()
for i = 1, 1000 do
  Ark.PushID(ctx, i)
  Ark.Checkbox(ctx, { label = "Test" })
  Ark.PopID(ctx)
end
local elapsed = reaper.time_precise() - start
```

### Step 2: Check resolve_config Pattern

**If it manually builds config:**
```lua
local config = {
  field1 = opts.field1 or DEFAULTS.field1,
  field2 = opts.field2 or DEFAULTS.field2,
  -- ... many fields
}
```

**Optimize to:**
```lua
local config = opts  -- opts has metatable to DEFAULTS
-- Only add dynamic values (Theme.COLORS, etc)
```

**If it calls Theme.build_X_config():**

Check what that function does. If it creates a new table, consider caching it.

### Step 3: Verify Base.parse_opts is Called

Make sure the widget calls:
```lua
opts = Base.parse_opts(opts, DEFAULTS)
```

This sets up the metatable fallback, allowing `config = opts` to work.

### Step 4: Test

- Run the benchmark
- Check for regressions
- Verify opts mutation doesn't break anything

---

## Recommended Action Plan

**Phase 1: Investigate (Optional)**

Only if you suspect performance issues:

1. Profile checkbox, inputtext, slider in real usage
2. Check if they're actually slow
3. Compare to button benchmark

**Phase 2: Optimize (If Needed)**

Only if profiling shows issues:

1. Apply #4 optimization to checkbox (clearest case)
2. Investigate Theme.build_X_config() calls
3. Consider caching if Theme functions are expensive

**Phase 3: Document**

Update this file with results.

---

## Current Recommendation

**DO NOT optimize other primitives yet.**

Reasons:

1. **Button optimization was done reactively** - We profiled, found a problem, fixed it
2. **No evidence of problems elsewhere** - Other primitives might be fine
3. **Maintenance cost** - Optimizing without profiling wastes time
4. **Real bottlenecks are elsewhere** - Reaper API calls, not widgets

**When to optimize:**

- When profiling shows a specific widget is slow
- When rendering 100+ instances of a widget
- When users report performance issues

**Until then:** Keep code simple and maintainable.

---

## Monitoring

If you want to check if other primitives need optimization:

1. **Add benchmark scripts** for checkbox, slider, inputtext
2. **Profile real apps** (DevKit, etc) - where is time spent?
3. **Look for user reports** - Are checkboxes slow?

Without evidence of problems, optimization is premature.
