# Why ARKITEKT's API is Better Than ImGui's

> **Key Insight**: Don't blindly copy ImGui. Some of our differences are **improvements**.

---

## The Question

**User asked:** "Why doesn't ImGui have result objects with `.clicked`, `.right_clicked`, etc.?"

**Answer:** C++ API constraints and historical simplicity. But Lua lets us do better!

---

## ImGui's Approach (C++)

```cpp
// ImGui: Boolean return + manual polling
if (ImGui::Button("File")) {
    open_file();  // Left click only
}

// Want right-click? Poll separately
if (ImGui::IsItemClicked(1)) {  // 1 = right mouse button
    show_context_menu();
}

// Want hover info? Poll again
if (ImGui::IsItemHovered()) {
    show_tooltip();
}
```

### Why ImGui Does This

1. **C++ Constraints**
   - Multiple returns require structs or out params (verbose)
   - Boolean is simplest for common case (left-click only)
   - Struct allocation has overhead in C++

2. **Simplicity Philosophy**
   - 90% of buttons only need left-click
   - Keep common case simple, advanced case manual
   - Historical: Started as debug UI tool

3. **API Stability**
   - Boolean return is standard across all ImGui versions
   - Can't break existing code

---

## ARKITEKT's Approach (Lua)

```lua
-- ARKITEKT: Rich result object
local result = Ark.Button.draw(ctx, "File")

if result.clicked then
    open_file()
end

if result.right_clicked then
    show_context_menu()
end

if result.hovered then
    show_tooltip()
end

-- All info available immediately, no extra polling
```

### Why ARKITEKT is Better

#### 1. **No Polling Required**
```lua
-- ImGui (C++): Multiple API calls
ImGui::Button("File");
if (ImGui::IsItemClicked(0)) { ... }      // Poll left-click
if (ImGui::IsItemClicked(1)) { ... }      // Poll right-click
if (ImGui::IsItemHovered()) { ... }       // Poll hover
if (ImGui::IsItemActive()) { ... }        // Poll active

// ARKITEKT (Lua): One call, all info
local r = Ark.Button.draw(ctx, "File")
-- r.clicked, r.right_clicked, r.hovered, r.active all available
```

#### 2. **Discoverable**
```lua
-- IDE autocomplete shows all available fields
local result = Ark.Button.draw(ctx, "File")
result. -- ← Autocomplete shows:
        --   .clicked
        --   .right_clicked
        --   .hovered
        --   .active
        --   .width
        --   .height
```

ImGui users have to **remember** `IsItemClicked(1)` exists!

#### 3. **Lua-Friendly**
```lua
-- Tables are cheap in Lua (no allocation overhead)
local result = {
    clicked = false,
    right_clicked = false,
    hovered = true,
    width = 100,
    height = 30,
}
```

In C++, this would be a struct allocation. In Lua, it's idiomatic and efficient.

#### 4. **Consistent Pattern**
```lua
-- All widgets follow same pattern
local btn = Ark.Button.draw(ctx, ...)    -- .clicked, .right_clicked
local chk = Ark.Checkbox.draw(ctx, ...)  -- .changed, .value
local sld = Ark.Slider.draw(ctx, ...)    -- .changed, .value

// ImGui: Inconsistent returns
bool clicked = ImGui::Button(...);                // boolean
bool changed, value = ImGui::Checkbox(...);       // multiple
int changed, value = ImGui::SliderInt(...);       // different types
```

#### 5. **Forward Compatible**
```lua
-- Easy to add new fields without breaking API
local result = {
    clicked = false,
    right_clicked = false,
    middle_clicked = false,  -- ← Add new feature!
    double_clicked = false,  -- ← Another new feature!
    -- Old code that only checks .clicked still works
}
```

#### 6. **Rich Context**
```lua
-- Can include anything useful
local result = {
    clicked = false,
    right_clicked = false,

    -- Geometry
    x = 100,
    y = 50,
    width = 80,
    height = 30,

    -- State
    hovered = true,
    active = false,

    -- Advanced
    hover_time = 0.5,  -- How long hovered
    click_position = {x=120, y=65},  -- Where clicked
}
```

---

## Real-World Example

### Scenario: Button with context menu

**ImGui (C++):**
```cpp
if (ImGui::Button("File", ImVec2(80, 30))) {
    open_file();
}

// Separate check for right-click
if (ImGui::IsItemClicked(1)) {
    ImGui::OpenPopup("file_context");
}

if (ImGui::BeginPopup("file_context")) {
    if (ImGui::MenuItem("Open")) { open_file(); }
    if (ImGui::MenuItem("Recent")) { show_recent(); }
    ImGui::EndPopup();
}
```

**ARKITEKT (Lua):**
```lua
local result = Ark.Button.draw(ctx, "File", 80, 30)

if result.clicked then
    open_file()
end

if result.right_clicked then
    -- Context menu logic inline
    show_context_menu({
        {"Open", open_file},
        {"Recent", show_recent},
    })
end
```

**ARKITEKT is clearer and more concise!**

---

## When to Match ImGui vs When to Improve

### ✅ Match ImGui For:

1. **Naming** - `same_line()` not `nextHorizontal()`
2. **Begin/End patterns** - Stateful operations
3. **Parameter order** - `ctx` first, then label, then state
4. **Immediate mode** - Draw every frame

### ⚡ Improve Over ImGui For:

1. **Return values** - Result objects > booleans
2. **Parameters** - Opts tables > long positional lists
3. **Styling** - Presets > raw colors
4. **State** - Auto-managed > manual tracking
5. **Callbacks** - Optional callbacks > polling only

---

## Decision Framework

**Ask: "Does ImGui do it this way because of C++ constraints or because it's the best design?"**

| ImGui Pattern | Reason | ARKITEKT Decision |
|---------------|--------|-------------------|
| Boolean returns | C++ simplicity | ⚡ Improve: Use result objects (Lua tables are great) |
| Manual polling | C++ API limits | ⚡ Improve: Include all info in result |
| Positional params | C++ function signatures | ⚡ Improve: Opts tables (but support both!) |
| Begin/End pairs | Good design | ✅ Match: Same pattern |
| Immediate mode | Good design | ✅ Match: Draw every frame |
| Function naming | Good design | ✅ Match: Keep familiar names |

---

## The Golden Rule

> **"If ImGui users would be confused → match ImGui.**
> **If Lua lets us do better → improve!"**

---

## Examples of Smart Improvements

### 1. Result Objects (This Document)
**Better than** ImGui's boolean + polling

### 2. Opts Tables
```lua
-- ImGui (positional hell)
ImGui::Button("Click", 100, 30, nil, nil, nil, callback)
                                 -- ^^^ nil spam for optional params

-- ARKITEKT (named, optional)
Ark.Button.draw(ctx, {
    label = "Click",
    width = 100,
    height = 30,
    on_click = callback,
    -- No nil spam!
})
```

### 3. Auto State Management
```lua
-- ImGui: Manual state
static int counter = 0;
if (ImGui::Button("Count")) {
    counter++;
}

-- ARKITEKT: Auto state
-- Widget manages hover animation, state, etc. internally
-- User doesn't need to track
```

### 4. Theme Integration
```lua
-- ImGui: Raw colors
PushStyleColor(ImGuiCol_Button, 0xFF0000FF);
Button("Danger");
PopStyleColor();

-- ARKITEKT: Presets
Ark.Button.draw(ctx, {
    label = "Danger",
    preset_name = "BUTTON_DANGER",
    -- Auto-adapts to theme!
})
```

---

## Conclusion

**Don't blindly copy ImGui.**

ARKITEKT should:
- ✅ **Feel familiar** (naming, patterns, immediate mode)
- ⚡ **Be better** where Lua enables it (tables, opts, auto-state)
- 📚 **Teach** users the improvements through good docs and migration tools

**Result objects are a perfect example**: ImGui can't do this well (C++ constraints), but ARKITEKT can and should!

---

## References

- [API_DESIGN_PHILOSOPHY.md](../../cookbook/API_DESIGN_PHILOSOPHY.md)
- [HYBRID_API.md](../HYBRID_API.md)
- [MIGRATION_SCRIPT.md](./MIGRATION_SCRIPT.md)
