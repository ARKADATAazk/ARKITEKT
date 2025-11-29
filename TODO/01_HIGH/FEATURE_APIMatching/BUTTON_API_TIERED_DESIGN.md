# Button API: Tiered Design for Consistency

**Date**: 2025-11-29
**Status**: Implemented
**Related**: Decision 20 (Hybrid ID), API Matching Phase 1

---

## Philosophy

Button API is organized in **three tiers** to balance power with guardrails:

1. **✅ EXPOSED** - Always documented, functional parameters
2. **⚠️ THEME-CONTROLLED** - Defaults from Theme, rarely overridden
3. **❌ HIDDEN** - Accepted but not documented, for migration only

This prevents "Christmas tree" UIs while allowing edge-case flexibility.

---

## Tier 1: EXPOSED (Always Documented)

### Simple Positional Mode (ImGui-compatible)

```lua
-- Returns boolean (like ImGui)
if Ark.Button(ctx, "Save") then
  save_file()
end

-- With width
if Ark.Button(ctx, "Save", 100) then
  save_file()
end
```

**Return**: `boolean` - true if clicked

---

### Opts Mode (Power Features)

```lua
-- Returns result object
local result = Ark.Button(ctx, {
  -- ✅ EXPOSED: Functional
  label = "Save",
  icon = "💾",
  tooltip = "Save file (Ctrl+S)",
  disabled = false,

  -- ✅ EXPOSED: Semantic presets (Theme-controlled colors)
  preset = "primary",  -- or "danger", "success", "secondary"

  -- ✅ EXPOSED: State
  is_toggled = is_muted,  -- For toggle buttons

  -- ✅ EXPOSED: Callbacks
  on_click = save_file,
  on_right_click = show_save_menu,

  -- ✅ EXPOSED: Layout
  width = 100,
  height = 24,
})

-- Result object
if result.clicked then ... end
if result.right_clicked then ... end
if result.hovered then ... end
```

**Return**: `table` - result object with `clicked`, `right_clicked`, `hovered`, `width`, `height`

---

## Tier 2: THEME-CONTROLLED (Advanced, Defaults from Theme)

These options **exist** but default from Theme. Override only for edge cases (pill buttons, compact toolbars, etc.).

```lua
Ark.Button(ctx, {
  label = "Pill",

  -- ⚠️ THEME-CONTROLLED: Geometry overrides
  rounding = 12,   -- Default: Theme.BUTTON.rounding (usually 4)
  padding_x = 8,   -- Default: Theme.BUTTON.padding_x (usually 10)
})
```

**Why allow overrides?**
- Edge cases: pill buttons (rounding = 999), compact toolbars (padding = 4)
- Not chaos: geometry variations don't create "Christmas tree" effect

**Guideline**: 99% of buttons should use Theme defaults.

---

## Tier 3: HIDDEN (Migration Only, Not Documented)

These options are **accepted** for backward compatibility but **not documented** in user-facing docs.

```lua
Ark.Button(ctx, {
  label = "Legacy",

  -- ❌ HIDDEN: Direct color overrides (use preset instead!)
  bg_color = 0xFF0000FF,      -- ❌ Use preset = "danger" instead
  text_color = 0xFFFFFFFF,    -- ❌ Let preset control this

  -- ❌ HIDDEN: Legacy preset system
  preset_name = "BUTTON_DANGER",  -- ❌ Use preset = "danger" instead
})
```

**Why hidden?**
- Prevents new code from using arbitrary colors
- Allows old code to migrate gradually
- Will be removed in Phase 7 (Final Cleanup)

---

## Semantic Presets (Tier 1)

Presets provide **controlled vocabulary** for button variations:

### Available Presets

```lua
-- Default (no preset)
Ark.Button(ctx, "Save")
-- Uses Theme.COLORS.BG_BASE, smooth hover animation

-- Primary (call-to-action)
Ark.Button(ctx, { label = "Submit", preset = "primary" })
-- Uses Theme.COLORS.ACCENT_PRIMARY, bright text

-- Secondary (less prominent)
Ark.Button(ctx, { label = "Cancel", preset = "secondary" })
-- Uses Theme.COLORS.BG_HOVER, normal text

-- Danger (destructive action)
Ark.Button(ctx, { label = "Delete", preset = "danger" })
-- Uses Theme.COLORS.DANGER (red), bright text

-- Success (positive action)
Ark.Button(ctx, { label = "Confirm", preset = "success" })
-- Uses Theme.COLORS.SUCCESS (green), bright text
```

### Why Presets Work

| Approach | Control | Chaos Risk |
|----------|---------|-----------|
| `bg_color = 0xFF0000FF` | User picks anything | 🎄 High |
| `preset = "danger"` | Theme defines "danger" | ✅ Low |

**Benefits:**
- ✅ Limited vocabulary (4 presets, not infinite colors)
- ✅ Semantic names (`danger`, not `red`)
- ✅ Theme-controlled (consistent across app)
- ✅ User chooses **intent**, Theme controls **appearance**

---

## Implementation

### Preset Color Resolution

```lua
-- In button.lua
local function get_preset_colors(preset_name)
  local C = Theme.COLORS

  if preset_name == "primary" then
    return { bg = C.ACCENT_PRIMARY, text = C.TEXT_BRIGHT }
  elseif preset_name == "secondary" then
    return { bg = C.BG_HOVER, text = C.TEXT_NORMAL }
  elseif preset_name == "danger" then
    return { bg = C.DANGER, text = C.TEXT_BRIGHT }
  elseif preset_name == "success" then
    return { bg = C.SUCCESS, text = C.TEXT_BRIGHT }
  end

  return nil  -- No preset
end
```

### Config Resolution Priority

```lua
function resolve_config(opts)
  -- 1. Apply defaults
  -- 2. Apply user overrides
  -- 3. Apply semantic preset (if specified)
  if opts.preset then
    config._preset_colors = get_preset_colors(opts.preset)
  end
  -- 4. Render with preset colors (smooth hover animation)
end
```

---

## Preventing "Christmas Tree" UIs

### What Causes Chaos

🎄🎄🎄 **Custom colors everywhere** (major chaos)
🌲 **Different rounding per button** (minor chaos)
🌲 **Different padding** (minor chaos)

### Our Solution

1. **Colors** → Tier 3 (hidden) - use presets instead
2. **Rounding/Padding** → Tier 2 (theme-controlled) - default from Theme
3. **Presets** → Tier 1 (exposed) - limited semantic vocabulary

**Result**: Consistent, professional UIs with flexibility for edge cases.

---

## Migration Path

### Phase 1: Add Presets (Done ✅)
- Semantic presets: `primary`, `danger`, `success`, `secondary`
- Boolean return in positional mode (ImGui match)

### Phase 2: Update Documentation
- Document Tier 1 (exposed) in WIDGETS.md
- Mention Tier 2 (theme-controlled) for edge cases
- DO NOT document Tier 3 (hidden)

### Phase 3: Migrate Apps
- Replace `bg_color = 0xFF0000FF` with `preset = "danger"`
- Replace `preset_name = "BUTTON_DANGER"` with `preset = "danger"`

### Phase 4: Deprecate Tier 3
- Add warnings when using `bg_color`, `preset_name`, etc.
- Remove in Phase 7 (Final Cleanup)

---

## Examples

### Simple Use (Tier 1)

```lua
-- ImGui style (most common)
if Ark.Button(ctx, "Save") then
  save()
end

-- With preset
if Ark.Button(ctx, { label = "Delete", preset = "danger" }) then
  confirm_delete()
end

-- With callbacks
Ark.Button(ctx, {
  label = "Options",
  on_click = show_options,
  on_right_click = show_context_menu,
})
```

### Advanced Use (Tier 2)

```lua
-- Pill button (rounded)
Ark.Button(ctx, {
  label = "Tag",
  preset = "secondary",
  rounding = 999,  -- Override for pill shape
  padding_x = 12,
})

-- Compact toolbar button
Ark.Button(ctx, {
  icon = "🔧",
  width = 24,
  height = 24,
  padding_x = 4,  -- Override for compact layout
})
```

### Migration (Tier 3 - Avoid)

```lua
-- OLD (will be deprecated)
Ark.Button(ctx, {
  label = "Delete",
  bg_color = 0xFF4444FF,  -- ❌ Direct color
})

-- NEW (use preset)
Ark.Button(ctx, {
  label = "Delete",
  preset = "danger",  -- ✅ Semantic preset
})
```

---

## Summary

| Tier | Purpose | Document? | Example |
|------|---------|-----------|---------|
| **1. EXPOSED** | Functional, semantic | ✅ Yes | `label`, `preset`, `on_click` |
| **2. THEME-CONTROLLED** | Edge cases, geometry | ⚠️ Advanced | `rounding`, `padding_x` |
| **3. HIDDEN** | Migration only | ❌ No | `bg_color`, `preset_name` |

**Philosophy**: Tier 1 is **productive** (clean API), Tier 2 is **flexible** (edge cases), Tier 3 is **transitional** (backward compat).

This design prevents chaos while allowing power users to solve edge cases. 🎯
