# Widget Signatures

> **ImGui → ARKITEKT mappings for each widget**

---

## Pattern Overview

Every widget follows this pattern:

```lua
-- Positional (ImGui-like)
Ark.Widget(ctx, required_param, optional1, optional2)

-- Opts table (ARKITEKT power)
Ark.Widget(ctx, {
  required_param = value,
  optional1 = value,
  -- ... extras not available in positional
  on_change = callback,
  tooltip = "hint",
  disabled = condition,
})

-- SINGLE RETURN: result object (Decision 18)
-- All widgets return a result object with consistent fields:
local r = Ark.Button(ctx, "OK")
if r.clicked then ... end

local r = Ark.Slider(ctx, "Vol", v, 0, 1)
if r.changed then vol = r.value end

-- Result object fields:
r.clicked   -- Button/RadioButton: was clicked this frame
r.changed   -- Stateful widgets: value changed this frame
r.value     -- Current value (checked, text, number, index)
r.hovered   -- Is mouse over?
r.active    -- Is being interacted with?

-- Inline form works too:
if Ark.Button(ctx, "OK").clicked then ... end
```

---

## Button

### ImGui
```lua
-- Signature
local pressed = ImGui.Button(ctx, label)
local pressed = ImGui.Button(ctx, label, size_w, size_h)

-- Usage
if ImGui.Button(ctx, "Save") then
  save_file()
end

if ImGui.Button(ctx, "OK", 100, 30) then
  confirm()
end
```

### ARKITEKT Positional
```lua
-- Signature (single return: result object)
local r = Ark.Button(ctx, label)
local r = Ark.Button(ctx, label, width, height)

-- Usage
local r = Ark.Button(ctx, "Save")
if r.clicked then save_file() end

local r = Ark.Button(ctx, "OK", 100, 30)
if r.clicked then confirm() end

-- Inline form
if Ark.Button(ctx, "Save").clicked then save_file() end

-- Access hover state
local r = Ark.Button(ctx, "Save")
if r.clicked then save_file() end
if r.hovered then show_tooltip() end
```

### ARKITEKT Opts
```lua
Ark.Button(ctx, {
  -- Required
  label = "Save",

  -- Size (optional, aliases: w/h)
  width = 100,    -- or: w = 100
  height = 30,    -- or: h = 30

  -- State (optional)
  disabled = false,
  toggled = false,

  -- Styling (optional)
  style = "success",   -- semantic preset

  -- Callbacks (optional)
  on_click = function() end,
  on_right_click = function() end,

  -- Extras (optional)
  tooltip = "Save the file",
  icon = "",           -- Icon character
  icon_font = font,     -- Font for icon
})
```

### Result Object
```lua
result.clicked        -- boolean: left-clicked this frame
result.right_clicked  -- boolean: right-clicked this frame
result.hovered        -- boolean: mouse is over
result.active         -- boolean: being pressed
result.width          -- number: actual width
result.height         -- number: actual height
```

---

## Checkbox

### ImGui
```lua
-- Signature
local changed, value = ImGui.Checkbox(ctx, label, value)

-- Usage
local changed, auto_save = ImGui.Checkbox(ctx, "Auto-save", config.auto_save)
if changed then
  config.auto_save = auto_save
end
```

### ARKITEKT Positional
```lua
-- Signature (single return: result object)
local r = Ark.Checkbox(ctx, label, checked)

-- Usage
local r = Ark.Checkbox(ctx, "Auto-save", config.auto_save)
if r.changed then config.auto_save = r.value end

-- Inline form
if Ark.Checkbox(ctx, "Auto-save", config.auto_save).changed then
  config.auto_save = not config.auto_save
end
```

### ARKITEKT Opts
```lua
Ark.Checkbox(ctx, {
  label = "Auto-save",
  checked = config.auto_save,

  -- Callbacks
  on_change = function(new_value)
    config.auto_save = new_value
  end,

  -- Extras
  disabled = false,
  tooltip = "Automatically save every 5 minutes",
})
```

### Result Object
```lua
result.value    -- boolean: current checked state
result.changed  -- boolean: did it change this frame?
result.hovered  -- boolean: mouse is over
```

---

## Slider

### ImGui
```lua
-- Signature (multiple variants)
local changed, value = ImGui.SliderInt(ctx, label, value, min, max, format, flags)
local changed, value = ImGui.SliderFloat(ctx, label, value, min, max, format, flags)

-- Usage
local changed, volume = ImGui.SliderInt(ctx, "Volume", config.volume, 0, 100)
if changed then
  config.volume = volume
end
```

### ARKITEKT Positional
```lua
-- Signature (single return: result object; unified - handles int/float automatically)
local r = Ark.Slider(ctx, label, value, min, max)

-- Usage
local r = Ark.Slider(ctx, "Volume", config.volume, 0, 100)
if r.changed then config.volume = r.value end

-- Inline form (when you just need to know something changed)
if Ark.Slider(ctx, "Volume", config.volume, 0, 100).changed then
  trigger_audio_update()
end
```

### ARKITEKT Opts
```lua
Ark.Slider(ctx, {
  label = "Volume",
  value = config.volume,
  min = 0,
  max = 100,

  -- Formatting
  format = "%d%%",     -- Display format
  step = 1,            -- Increment step
  is_integer = true,   -- Force integer

  -- Callbacks
  on_change = function(new_value)
    config.volume = new_value
    audio.set_volume(new_value)
  end,

  -- Extras
  width = 200,         -- or: w = 200
  disabled = false,
  tooltip = "Adjust volume level",
})
```

### Result Object
```lua
result.value    -- number: current slider value
result.changed  -- boolean: did it change this frame?
result.hovered  -- boolean
result.active   -- boolean: being dragged
```

---

## InputText

### ImGui
```lua
-- Signature
local changed, text = ImGui.InputText(ctx, label, text, flags)
local changed, text = ImGui.InputTextWithHint(ctx, label, hint, text, flags)

-- Usage
local changed, name = ImGui.InputText(ctx, "Name", config.name)
if changed then
  config.name = name
end
```

### ARKITEKT Positional
```lua
-- Signature (single return: result object)
local r = Ark.InputText(ctx, label, text)
local r = Ark.InputText(ctx, label, text, width)

-- Usage
local r = Ark.InputText(ctx, "Name", config.name)
if r.changed then config.name = r.value end

-- Inline form
if Ark.InputText(ctx, "Search", query).changed then
  trigger_search()
end
```

### ARKITEKT Opts
```lua
Ark.InputText(ctx, {
  label = "Name",
  text = config.name,

  -- Size
  width = 200,         -- or: w = 200

  -- Hint/placeholder
  hint = "Enter your name",

  -- Validation
  max_length = 50,
  pattern = "^[a-zA-Z]+$",  -- Optional regex

  -- Callbacks
  on_change = function(new_text)
    config.name = new_text
  end,
  on_enter = function(text)
    submit_form()
  end,

  -- Extras
  disabled = false,
  password = false,    -- Hide characters
  multiline = false,
  tooltip = "Your display name",
})
```

### Result Object
```lua
result.value    -- string: current text (standardized)
result.text     -- string: alias for .value (backward compat, temporary)
result.changed  -- boolean: did text change?
result.hovered  -- boolean
result.active   -- boolean: has focus
```

---

## Combo

### ImGui
```lua
-- Signature
local changed, value = ImGui.Combo(ctx, label, current_item, items_separated_by_zeros)
-- or with callback
local changed = ImGui.BeginCombo(ctx, label, preview_value, flags)
-- ... items ...
ImGui.EndCombo(ctx)

-- Usage
local changed, selected = ImGui.Combo(ctx, "Theme", theme_idx, "Light\0Dark\0System\0")
```

### ARKITEKT Positional
```lua
-- Signature (single return: result object)
local r = Ark.Combo(ctx, label, selected_index, items)

-- Usage
local r = Ark.Combo(ctx, "Theme", config.theme, {"Light", "Dark", "System"})
if r.changed then config.theme = r.value end

-- Inline form
if Ark.Combo(ctx, "Theme", config.theme, themes).changed then
  mark_settings_dirty()
end
```

### ARKITEKT Opts
```lua
Ark.Combo(ctx, {
  label = "Theme",
  selected = config.theme,      -- Index or value
  items = {"Light", "Dark", "System"},

  -- Display
  preview = nil,                -- Custom preview text
  width = 150,                  -- or: w = 150

  -- Callbacks
  on_change = function(index, item)
    config.theme = index
    apply_theme(item)
  end,

  -- Extras
  disabled = false,
  tooltip = "Select color theme",
})
```

### Result Object
```lua
result.value    -- number: selected index
result.item     -- string: selected item text
result.changed  -- boolean: did selection change?
result.open     -- boolean: is dropdown open?
result.hovered  -- boolean
```

---

## RadioButton

### ImGui
```lua
-- Signature
local pressed = ImGui.RadioButton(ctx, label, active)

-- Usage
if ImGui.RadioButton(ctx, "Option A", selected == 1) then
  selected = 1
end
if ImGui.RadioButton(ctx, "Option B", selected == 2) then
  selected = 2
end
```

### ARKITEKT Positional
```lua
-- Signature (single return: result object)
local r = Ark.RadioButton(ctx, label, active)

-- Usage
local r = Ark.RadioButton(ctx, "Option A", selected == 1)
if r.clicked then selected = 1 end

local r = Ark.RadioButton(ctx, "Option B", selected == 2)
if r.clicked then selected = 2 end

-- Inline form
if Ark.RadioButton(ctx, "Option A", selected == 1).clicked then
  selected = 1
end

-- Access hover state
local r = Ark.RadioButton(ctx, "Option A", selected == 1)
if r.hovered then show_tooltip() end
```

### ARKITEKT Opts
```lua
Ark.RadioButton(ctx, {
  label = "Option A",
  active = selected == 1,

  -- Callbacks
  on_click = function()
    selected = 1
  end,

  -- Extras
  disabled = false,
  tooltip = "Select option A",
})
```

### Result Object
```lua
result.clicked  -- boolean: was clicked this frame
result.hovered  -- boolean: mouse is over
result.active   -- boolean: is being pressed
```

---

## Summary: Positional Parameter Order

| Widget | Positional Params |
|--------|-------------------|
| Button | `label, width, height` |
| Checkbox | `label, checked` |
| Slider | `label, value, min, max` |
| InputText | `label, text, width` |
| Combo | `label, selected, items` |
| RadioButton | `label, active` |

All match ImGui's parameter order where applicable.

---

## Migration Cheatsheet

```lua
-- ImGui → ARKITEKT (single return: result object)

-- Button
if ImGui.Button(ctx, "X") then              →  if Ark.Button(ctx, "X").clicked then
if ImGui.Button(ctx, "X", 80, 30) then      →  if Ark.Button(ctx, "X", 80, 30).clicked then

-- Or with result variable for hover/active:
                                            →  local r = Ark.Button(ctx, "X")
                                            →  if r.clicked then ... end
                                            →  if r.hovered then show_tooltip() end

-- RadioButton
if ImGui.RadioButton(ctx, "A", sel==1) then →  if Ark.RadioButton(ctx, "A", sel==1).clicked then

-- Checkbox
local c, v = ImGui.Checkbox(ctx, "X", val)  →  local r = Ark.Checkbox(ctx, "X", val)
if c then val = v end                        →  if r.changed then val = r.value end

-- Slider
local c, v = ImGui.SliderInt(ctx, "X", val, 0, 100)  →  local r = Ark.Slider(ctx, "X", val, 0, 100)
if c then val = v end                                 →  if r.changed then val = r.value end

-- InputText
local c, t = ImGui.InputText(ctx, "X", txt)  →  local r = Ark.InputText(ctx, "X", txt)
if c then txt = t end                         →  if r.changed then txt = r.value end

-- Combo
local c, i = ImGui.Combo(ctx, "X", idx, items)  →  local r = Ark.Combo(ctx, "X", idx, items_table)
if c then idx = i end                            →  if r.changed then idx = r.value end
```

### Result Field Summary

| Widget | Primary Field | Value Field |
|--------|---------------|-------------|
| Button | `.clicked` | N/A |
| RadioButton | `.clicked` | N/A |
| Checkbox | `.changed` | `.value` (boolean) |
| Slider | `.changed` | `.value` (number) |
| InputText | `.changed` | `.value` (string) |
| Combo | `.changed` | `.value` (index), `.item` (text) |
