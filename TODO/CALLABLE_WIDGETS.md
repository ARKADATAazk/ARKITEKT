# Callable Widgets: Remove `.draw()` Requirement

## Goal

Make widgets **callable** like ImGui, removing the need for `.draw()` suffix:

```lua
-- ImGui style
ImGui.Button(ctx, "Click")

-- ARKITEKT current
Ark.Button.draw(ctx, "Click")

-- ARKITEKT proposed
Ark.Button(ctx, "Click")  -- ✨ Just like ImGui!
```

## Current State

All widgets require explicit `.draw()` call:
```lua
Ark.Button.draw(ctx, {label = "Click"})
Ark.Checkbox.draw(ctx, {checked = true})
Ark.Slider.draw(ctx, {value = 50, min = 0, max = 100})
```

**Problem**: Extra `.draw()` makes it feel less like ImGui. Adds visual noise.

## Target State

Widgets are **callable** AND have methods:

```lua
-- Primary usage: callable (like ImGui)
Ark.Button(ctx, "Click")                    -- Shorthand, calls draw()
Ark.Checkbox(ctx, "Enable", true)           -- Shorthand
Ark.Slider(ctx, "Volume", 50, 0, 100)       -- Shorthand

-- Explicit methods still work
Ark.Button.draw(ctx, "Click")               -- Explicit
Ark.Button.measure(ctx, {label = "Click"})  -- Utility function
Ark.Button.cleanup()                        -- Cleanup function
```

## Implementation

Use `__call` metamethod to make module callable:

```lua
-- arkitekt/gui/widgets/primitives/button.lua
local M = {}

-- Primary draw function
function M.draw(ctx, label_or_opts, ...)
  -- ... implementation
end

-- Utility functions
function M.measure(ctx, opts)
  -- ... implementation
end

function M.cleanup()
  -- ... implementation
end

-- Make module callable (shorthand for .draw())
return setmetatable(M, {
  __call = function(_, ctx, ...)
    return M.draw(ctx, ...)
  end
})
```

## Benefits

### 1. **Closer to ImGui**
```lua
-- ImGui
if ImGui.Button(ctx, "Click") then end
ImGui.Text(ctx, "Hello")
local rv, v = ImGui.Checkbox(ctx, "Enable", true)

-- ARKITEKT with callable widgets
if Ark.Button(ctx, "Click").clicked then end
Ark.Text(ctx, "Hello")
local result = Ark.Checkbox(ctx, "Enable", true)
```

**Feels immediately familiar!**

### 2. **Less Typing**
```lua
-- Before
Ark.Button.draw(ctx, "Click")     -- 12 characters after "Ark."
Ark.Checkbox.draw(ctx, "Enable")  -- 15 characters

-- After
Ark.Button(ctx, "Click")          -- 7 characters (shorter!)
Ark.Checkbox(ctx, "Enable")       -- 9 characters
```

### 3. **Still Have Explicit Methods**
```lua
-- Shorthand for simple cases
Ark.Button(ctx, "Click")

-- Explicit when you want to be clear
Ark.Button.draw(ctx, "Click")

-- Utility methods remain accessible
local width = Ark.Button.measure(ctx, {label = "Click"})
Ark.Button.cleanup()
```

### 4. **Matches ImGui Mental Model**
- ImGui: `ImGui.Button` is a function
- ARKITEKT: `Ark.Button` is also "a function" (callable)
- Natural mapping from ImGui knowledge

## Migration Path

**Backward compatible!** Existing code keeps working:

```lua
-- Old code (still works)
Ark.Button.draw(ctx, {label = "Click"})

-- New code (shorter)
Ark.Button(ctx, "Click")
```

Users can:
1. Keep using `.draw()` if they prefer explicit
2. Switch to callable style for brevity
3. Mix both in same codebase

## Examples

### Before (Current)
```lua
Ark.Button.draw(ctx, {label = "Open", width = 100})
Ark.Checkbox.draw(ctx, {label = "Enable", checked = true})
Ark.Slider.draw(ctx, {label = "Volume", value = 50, min = 0, max = 100})
Ark.InputText.draw(ctx, {label = "Name", text = current_name})
```

### After (Callable)
```lua
-- Positional params (ImGui-like)
Ark.Button(ctx, "Open", 100)
Ark.Checkbox(ctx, "Enable", true)
Ark.Slider(ctx, "Volume", 50, 0, 100)
Ark.InputText(ctx, "Name", current_name)

-- Opts table (when you need more)
Ark.Button(ctx, {label = "Open", width = 100, on_click = open_file})
Ark.Checkbox(ctx, {label = "Enable", checked = true, on_change = toggle})
Ark.Slider(ctx, {label = "Volume", value = 50, min = 0, max = 100, format = "%d%%"})
```

### Real-World Comparison

**ImGui** (what users know):
```lua
if ImGui.Button(ctx, "Save", 80, 30) then
  save_file()
end

local rv, enabled = ImGui.Checkbox(ctx, "Auto-save", config.auto_save)
if rv then
  config.auto_save = enabled
end

ImGui.Text(ctx, "Volume:")
ImGui.SameLine(ctx)
local rv, vol = ImGui.SliderInt(ctx, "##volume", config.volume, 0, 100)
```

**ARKITEKT with callable** (almost identical!):
```lua
if Ark.Button(ctx, "Save", 80, 30).clicked then
  save_file()
end

local result = Ark.Checkbox(ctx, "Auto-save", config.auto_save)
if result.changed then
  config.auto_save = result.value
end

Ark.Text(ctx, "Volume:")
Ark.Layout.same_line(ctx)
local result = Ark.Slider(ctx, "##volume", config.volume, 0, 100)
```

**Difference**: Just `Ark.` prefix and result unpacking!

## Implementation Checklist

### Primitives
- [ ] **Button**
- [ ] **Checkbox**
- [ ] **InputText**
- [ ] **Slider**
- [ ] **Combo**
- [ ] **RadioButton**
- [ ] **Badge**
- [ ] **Spinner**
- [ ] **CloseButton**
- [ ] **CornerButton**
- [ ] **HueSlider**
- [ ] **Scrollbar**
- [ ] **MarkdownField**
- [ ] **Splitter**

### Containers
- [ ] **Panel**
- [ ] **TileGroup**
- [ ] **SlidingZone**

### Pattern
```lua
-- Every widget module
local M = {}

function M.draw(ctx, ...)
  -- ... implementation
end

-- Other methods
function M.measure(ctx, opts)
  -- ...
end

-- Make callable
return setmetatable(M, {
  __call = function(_, ctx, ...)
    return M.draw(ctx, ...)
  end
})
```

## Combining with Hybrid API

**Maximum ImGui compatibility**:

```lua
-- Both positional params AND callable
Ark.Button(ctx, "Click", 100, 30)              -- Just like ImGui!
Ark.Checkbox(ctx, "Enable", true)              -- Just like ImGui!
Ark.Slider(ctx, "Volume", 50, 0, 100)          -- Just like ImGui!

-- Still have opts for power
Ark.Button(ctx, {
  label = "Click",
  width = 100,
  on_click = handler,
  tooltip = "Description",
})
```

**Result**:
- Migration: Change `ImGui.` → `Ark.` (that's it!)
- Result handling: Use `.clicked` / `.changed` instead of return values
- Advanced features: Use opts table when needed

## Performance

**Zero overhead!** Metamethod `__call` is a simple redirect to `M.draw()`:

```lua
-- These are identical in performance:
Ark.Button(ctx, "Click")       -- __call → M.draw()
Ark.Button.draw(ctx, "Click")  -- Direct call to M.draw()
```

Lua optimizes metamethod calls efficiently.

## Documentation Updates

Update all docs to show callable style as primary:

```lua
-- Quick example (show callable)
Ark.Button(ctx, "Click")

-- Full signature
Ark.Button(ctx, label, width, height)  -- Positional
Ark.Button(ctx, {opts table})          -- Opts
Ark.Button.draw(ctx, ...)              -- Explicit (same as above)
```

## Notes

- **Begin/End patterns** stay as methods (not callable):
  ```lua
  -- These make sense as methods
  if Ark.Menu.begin_menu(ctx, "File") then
    Ark.Menu.item(ctx, "Open")
    Ark.Menu.end_menu(ctx)
  end
  ```

- **Utility modules** stay as methods:
  ```lua
  -- Not callable (multiple functions)
  Ark.Colors.hex_to_rgba("#FF0000")
  Ark.Math.clamp(value, 0, 100)
  Ark.UUID.generate()
  ```

- **Only single-draw widgets** become callable:
  - Primitives: Yes ✅
  - Containers: Maybe (if single draw() call)
  - Utilities: No ❌

## Success Metrics

- ✅ `Ark.Button(ctx, ...)` works like `ImGui.Button(ctx, ...)`
- ✅ Migration from ImGui is <10 characters per widget
- ✅ Backward compatible (existing `.draw()` calls still work)
- ✅ No performance penalty

## References

- [HYBRID_API.md](./HYBRID_API.md) - Positional + opts support
- [API_DESIGN_PHILOSOPHY.md](../cookbook/API_DESIGN_PHILOSOPHY.md)
- [IMGUI_API_COVERAGE.md](./IMGUI_API_COVERAGE.md)

---

## Decision: Should We Do This?

**Pros:**
- ✅ Maximum ImGui familiarity
- ✅ Less typing (shorter code)
- ✅ Backward compatible
- ✅ Zero performance cost
- ✅ Mental model matches ImGui

**Cons:**
- ⚠️ Less explicit than `.draw()`
- ⚠️ Need to implement for each widget
- ⚠️ Slightly more complex module structure

**Recommendation**: **YES** - combine with hybrid API for maximum ImGui compatibility.

**With both features**:
```lua
-- ImGui
ImGui.Button(ctx, "Click", 100, 30)

-- ARKITEKT (almost identical!)
Ark.Button(ctx, "Click", 100, 30)
```

Users only need to:
1. Change `ImGui.` to `Ark.`
2. Handle results differently (`.clicked` instead of boolean return)

That's it! Everything else works the same.
