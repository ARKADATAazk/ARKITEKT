# Batch Processor Modal TODO

> Make `batch_rename_modal.lua` more generic and configurable for reuse across scripts.

---

## Current State

**Location**: `arkitekt/gui/widgets/overlays/batch_rename_modal.lua` (983 lines)

Currently handles:
- Rename (pattern with wildcards)
- Recolor (color picker)
- Rename & Recolor (both)

**This already works well.** The goal is to make it configurable so different scripts can use it with different options enabled.

---

## Core Goal: Configurable Rename + Recolor

Make the existing functionality configurable:

```lua
BatchProcessor.open({
  item_count = 5,
  item_type = "regions",  -- Display text

  -- Enable/disable what's already there
  rename = {
    enabled = true,
    wildcards = {"$n", "$l"},
    common_names = "game",  -- or "general" or custom list
  },
  recolor = {
    enabled = true,
    initial_color = 0xFF5733FF,
  },

  -- Callbacks (already exists)
  on_rename = function(pattern) ... end,
  on_recolor = function(color) ... end,
  on_rename_and_recolor = function(pattern, color) ... end,
})
```

---

## Implementation: Phase 1 (Concrete)

Make current modal configurable:

- [ ] Add `opts.rename.enabled` to show/hide rename section
- [ ] Add `opts.recolor.enabled` to show/hide color picker
- [ ] Add `opts.common_names` to switch preset or provide custom list
- [ ] Add `opts.wildcards` to customize which wildcards appear
- [ ] Maintain backward compatibility (current API still works)

This is mostly parameterizing what already exists.

---

## Future: Maybe Add More Operations (Speculative)

**Uncertain** - These might be useful but we'll see:

| Operation | Notes |
|-----------|-------|
| Retag | Tag chip palette - might be useful for TemplateBrowser |
| Set properties | Dropdowns/checkboxes - maybe for RegionPlaylist quantize |
| Move to folder | Folder picker - maybe for TemplateBrowser |

**Don't build these until there's a real need.** The value of the "god object" is doing multiple things at once - but rename + recolor might be all that's needed.

---

## Shared Components to Extract

These are independently useful regardless of batch processor scope:

| Component | Current Location | Target |
|-----------|-----------------|--------|
| Wildcard system | Lines 92-133 | `core/wildcards.lua` |
| Common names palette | Lines 479-544 | `defs/common_names.lua` |
| Flow layout chips | Lines 555-627 | `widgets/data/action_chip_palette.lua` |

See `TODO/TAGGING_SERVICE.md` for chip palette design.

---

## Priority

**Low-Medium** - The modal already works. Making it configurable is nice-to-have for code reuse, but not urgent.

---

*Created: 2025-11-27*
