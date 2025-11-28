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

-- Returns result object
local result = Ark.Widget(ctx, ...)
result.value     -- Widget-specific (checked, text, etc.)
result.changed   -- Did value change this frame?
result.hovered   -- Is mouse over?
result.active    -- Is being interacted with?
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
-- Signature
local result = Ark.Button(ctx, label)
local result = Ark.Button(ctx, label, width, height)

-- Usage
if Ark.Button(ctx, "Save").clicked then
  save_file()
end

if Ark.Button(ctx, "OK", 100, 30).clicked then
  confirm()
end
```

### ARKITEKT Opts
```lua
Ark.Button(ctx, {
  -- Required
  label = "Save",

  -- Size (optional)
  width = 100,
  height = 30,

  -- State (optional)
  disabled = false,
  is_toggled = false,

  -- Callbacks (optional)
  on_click = function() end,
  on_right_click = function() end,

  -- Extras (optional)
  tooltip = "Save the file",
  icon = "",           -- Icon character
  icon_font = font,     -- Font for icon
  preset_name = "BUTTON_SUCCESS",
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
-- Signature
local result = Ark.Checkbox(ctx, label, checked)

-- Usage
local result = Ark.Checkbox(ctx, "Auto-save", config.auto_save)
if result.changed then
  config.auto_save = result.value
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
-- Signature (unified - handles int/float automatically)
local result = Ark.Slider(ctx, label, value, min, max)

-- Usage
local result = Ark.Slider(ctx, "Volume", config.volume, 0, 100)
if result.changed then
  config.volume = result.value
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
  width = 200,
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
-- Signature
local result = Ark.InputText(ctx, label, text)
local result = Ark.InputText(ctx, label, text, width)

-- Usage
local result = Ark.InputText(ctx, "Name", config.name)
if result.changed then
  config.name = result.text
end
```

### ARKITEKT Opts
```lua
Ark.InputText(ctx, {
  label = "Name",
  text = config.name,

  -- Size
  width = 200,

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
result.text     -- string: current text
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
-- Signature
local result = Ark.Combo(ctx, label, selected_index, items)

-- Usage
local result = Ark.Combo(ctx, "Theme", config.theme, {"Light", "Dark", "System"})
if result.changed then
  config.theme = result.value
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
  width = 150,

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
-- Signature
local result = Ark.RadioButton(ctx, label, active)

-- Usage
if Ark.RadioButton(ctx, "Option A", selected == 1).clicked then
  selected = 1
end
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
-- ImGui → ARKITEKT (minimal changes)

-- Button
ImGui.Button(ctx, "X")           →  Ark.Button(ctx, "X").clicked
ImGui.Button(ctx, "X", 80, 30)   →  Ark.Button(ctx, "X", 80, 30).clicked

-- Checkbox
local c, v = ImGui.Checkbox(ctx, "X", val)  →  local r = Ark.Checkbox(ctx, "X", val)
if c then val = v end                        →  if r.changed then val = r.value end

-- Slider
local c, v = ImGui.SliderInt(ctx, "X", val, 0, 100)  →  local r = Ark.Slider(ctx, "X", val, 0, 100)
if c then val = v end                                 →  if r.changed then val = r.value end

-- InputText
local c, t = ImGui.InputText(ctx, "X", txt)  →  local r = Ark.InputText(ctx, "X", txt)
if c then txt = t end                         →  if r.changed then txt = r.text end
```
