# Decision 20: Hybrid ID System (Stack + Explicit Field)

**Date:** 2025-11-29
**Status:** Decided
**Supersedes:** Previous "Required ID" decision for Grid/Tree

---

## Problem

Grid and TreeView currently **require** explicit `id` field, which is:
- ❌ Inconsistent with Button (which has optional ID)
- ❌ More friction than ImGui (which auto-generates from labels)
- ❌ Verbose for loops with many widgets

**Original debate:** Should we require ID, make it optional, or auto-generate?

---

## Solution: Support BOTH Stack and Explicit ID

Implement **hybrid system** that combines:
1. **ImGui's PushID/PopID stack** (for scoping multiple widgets)
2. **ARKITEKT's explicit `id` field** (for direct control)
3. **Fallback to label or "widget_name"** (for simple cases)

### **Priority:**
```
1. Explicit `opts.id` → Use directly (bypass stack)
2. ID Stack exists → Prepend stack path to base ID
3. No stack, no explicit → Use label or fallback
```

---

## Examples

### Simple Case (No Stack, No ID)
```lua
-- Works automatically
Ark.Button(ctx, "Save")  -- ID = "Save" (from label)
Ark.Grid(ctx, { items = items })  -- ID = "grid" (fallback)
```

### Multiple Widgets (Explicit ID)
```lua
-- Explicit IDs bypass stack
Ark.Grid(ctx, { id = "active", items = active })
Ark.Grid(ctx, { id = "pool", items = pool })
```

### Loop with Stack (ImGui Way!)
```lua
-- Stack scopes all widgets inside
for i, track in ipairs(tracks) do
  Ark.PushID(ctx, i)
    Ark.Button(ctx, "M")  -- ID = "1/M", "2/M", ...
    Ark.Button(ctx, "S")  -- ID = "1/S", "2/S", ...
    Ark.Grid(ctx, { items = track.items })  -- ID = "1/grid", "2/grid", ...
  Ark.PopID(ctx)
end
```

### Override Stack
```lua
-- Explicit ID ignores stack
Ark.PushID(ctx, "section")
  Ark.Button(ctx, "Auto")  -- ID = "section/Auto" (uses stack)
  Ark.Button(ctx, { id = "fixed", label = "Override" })  -- ID = "fixed" (ignores stack)
Ark.PopID(ctx)
```

---

## Implementation

### 1. ID Stack Module (`arkitekt/core/id_stack.lua`)

```lua
local M = {}
local _stacks = {}  -- Per-context stacks

function M.push(ctx, id)
  _stacks[ctx] = _stacks[ctx] or {}
  table.insert(_stacks[ctx], tostring(id))
end

function M.pop(ctx)
  local stack = _stacks[ctx]
  if stack and #stack > 0 then
    table.remove(stack)
  end
end

function M.resolve(ctx, base_id)
  local stack = _stacks[ctx]
  if not stack or #stack == 0 then
    return base_id  -- No stack active
  end
  -- Prepend stack path
  return table.concat(stack, "/") .. "/" .. base_id
end

return M
```

### 2. Widget Integration Pattern

```lua
local IdStack = require('arkitekt.core.id_stack')

function M.draw(ctx, opts)
  opts = opts or {}

  -- Priority 1: Explicit ID (bypasses stack)
  if opts.id then
    local id = opts.id
    -- ... use id directly
    return
  end

  -- Priority 2: Stack + fallback
  local base_id = opts.label or "grid"  -- Grid has no label, so "grid"
  local id = IdStack.resolve(ctx, base_id)
  -- ... use resolved id
end
```

### 3. Export from `arkitekt/init.lua`

```lua
local IdStack = require('arkitekt.core.id_stack')

return {
  -- ... existing exports

  PushID = IdStack.push,
  PopID = IdStack.pop,

  -- ... widgets
}
```

---

## Why This Is The Right Answer

### ✅ Matches ImGui Perfectly
- `Ark.PushID` = `ImGui.PushID` (same API)
- `Ark.PopID` = `ImGui.PopID` (same API)
- Familiar to ImGui users
- No confusion about "why is ARKITEKT different?"

### ✅ Improves on ImGui
- Explicit `id` field cleaner than `##suffix` syntax
- Stack is **optional** (simple cases don't need it)
- Opts table more flexible than positional params

### ✅ Serves All Users
- **Beginners:** Just works (no stack needed)
- **ImGui users:** Stack available (familiar pattern)
- **Power users:** Explicit ID override (precise control)
- **Complex loops:** Stack reduces typing

### ✅ Solves Real Problems
- TemplateBrowser 4 trees: Can use stack OR explicit IDs
- RegionPlaylist 2 grids: Explicit IDs still work
- Track loops: Stack = one PushID instead of N explicit IDs

---

## Comparison to Alternatives

| Approach | Required ID | Optional ID (Auto) | **Hybrid (Stack + Explicit)** |
|----------|-------------|-------------------|-------------------------------|
| Simple case | ❌ Friction | ✅ Works | ✅ Works |
| Multiple widgets | ✅ Clear | ⚠️ Must add IDs | ✅ Explicit OR stack |
| Loops | ⚠️ `id="x"..i` | ⚠️ `id="x"..i` | ✅ **One PushID wraps all** |
| ImGui compatibility | ❌ Different | ❌ Different | ✅ **Same API** |
| Helper functions | ⚠️ Pass ID param | ❌ Collision | ✅ PushID before call |

**Hybrid wins in every dimension.**

---

## Migration Path

### Phase 1: Add Stack Support
1. Implement `id_stack.lua`
2. Export `Ark.PushID` / `Ark.PopID`
3. Update all widgets to check stack

### Phase 2: Update Widgets
- Grid: Use `IdStack.resolve(ctx, "grid")`
- Tree: Use `IdStack.resolve(ctx, "tree")`
- Button: Use `IdStack.resolve(ctx, opts.label or "button")`
- All widgets: Explicit `opts.id` bypasses stack

### Phase 3: Documentation
- Add stack examples to QUICKSTART.md
- Update WIDGETS.md with both patterns
- Document in API_DESIGN_PHILOSOPHY.md

---

## Files to Modify

| File | Changes |
|------|---------|
| `arkitekt/core/id_stack.lua` | New file - stack implementation |
| `arkitekt/init.lua` | Export PushID/PopID |
| `arkitekt/gui/widgets/containers/grid/core.lua` | Use IdStack.resolve |
| `arkitekt/gui/widgets/navigation/tree_view.lua` | Use IdStack.resolve |
| `arkitekt/gui/widgets/primitives/*.lua` | Use IdStack.resolve |
| `cookbook/API_DESIGN_PHILOSOPHY.md` | Document hybrid approach |
| `TODO/01_HIGH/FEATURE_APIMatching/PROGRESS.md` | Update Phase 3 status |

---

## Testing Checklist

- [ ] Single widget (no stack, no ID) works
- [ ] Explicit ID bypasses stack
- [ ] PushID/PopID scope widgets correctly
- [ ] Nested PushID creates correct paths ("a/b/widget")
- [ ] Mismatched Push/Pop handled gracefully
- [ ] TemplateBrowser works with stack
- [ ] RegionPlaylist works with explicit IDs
- [ ] Loop example with PushID works

---

## Related Decisions

- **Decision 16:** Hidden State for Complex Widgets (established ID-keyed state)
- **Decision 19:** Opts Naming Conventions (established `id` field)
- **This decision (20):** How to resolve ID (stack + explicit + fallback)

---

## Consensus

**Credits:** Decision reached through discussion with Opus 4.5, which identified that hybrid approach is "truly additive - not replacing, but extending" ImGui's capability.

**Outcome:** Unanimous - this is the clear winner.
