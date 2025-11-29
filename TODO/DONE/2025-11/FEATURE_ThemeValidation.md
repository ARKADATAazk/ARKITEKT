# Theme Manager Validation

Runtime checks to catch configuration errors early.

## Problem

If you add a key to `dark` preset but forget `light`, or mistype a key name, you get silent failures or nil values at runtime.

## Solution

Add validation that runs on module load (dev mode) or on demand.

## Implementation

### 1. Add validate function

```lua
--- Validate preset configuration
--- @return boolean valid, string|nil error_message
function M.validate()
  local errors = {}

  -- Check both presets have same keys
  local dark_keys = {}
  for key in pairs(M.presets.dark) do
    dark_keys[key] = true
  end

  local light_keys = {}
  for key in pairs(M.presets.light) do
    light_keys[key] = true
  end

  -- Keys in dark but not light
  for key in pairs(dark_keys) do
    if not light_keys[key] then
      table.insert(errors, string.format("Key '%s' in dark preset but missing from light", key))
    end
  end

  -- Keys in light but not dark
  for key in pairs(light_keys) do
    if not dark_keys[key] then
      table.insert(errors, string.format("Key '%s' in light preset but missing from dark", key))
    end
  end

  -- Check all values are wrapped
  for preset_name, preset in pairs(M.presets) do
    for key, value in pairs(preset) do
      if type(value) ~= "table" or not value.mode then
        table.insert(errors, string.format(
          "Key '%s' in %s preset is not wrapped (use blend() or step())",
          key, preset_name
        ))
      end
    end
  end

  -- Check wrapper modes match between presets
  for key in pairs(M.presets.dark) do
    if M.presets.light[key] then
      local dark_mode = get_mode(M.presets.dark[key])
      local light_mode = get_mode(M.presets.light[key])
      if dark_mode ~= light_mode then
        table.insert(errors, string.format(
          "Key '%s' has mismatched modes: dark=%s, light=%s",
          key, dark_mode, light_mode
        ))
      end
    end
  end

  -- Check value types match
  for key in pairs(M.presets.dark) do
    if M.presets.light[key] then
      local dark_val = unwrap(M.presets.dark[key])
      local light_val = unwrap(M.presets.light[key])
      local dark_type = type(dark_val)
      local light_type = type(light_val)
      if dark_type ~= light_type then
        table.insert(errors, string.format(
          "Key '%s' has mismatched types: dark=%s, light=%s",
          key, dark_type, light_type
        ))
      end
    end
  end

  if #errors > 0 then
    return false, table.concat(errors, "\n")
  end

  return true, nil
end
```

### 2. Auto-validate in dev mode

```lua
-- At end of init.lua, before return M
if os.getenv("ARKITEKT_DEV") or reaper.GetExtState("ARKITEKT", "dev_mode") == "1" then
  local valid, err = M.validate()
  if not valid then
    reaper.ShowConsoleMsg("[ThemeManager] Validation errors:\n" .. err .. "\n")
  end
end
```

### 3. Assert helper for generate_palette

```lua
function M.generate_palette(base_bg, base_text, base_accent, rules)
  -- ... existing code ...

  -- Assert required rules exist
  local required = {
    "bg_hover_delta", "bg_active_delta", "bg_header_delta", "bg_panel_delta",
    "border_outer_color", "border_outer_opacity",
    "tile_fill_brightness", "tile_name_color",
    -- ... etc
  }

  for _, key in ipairs(required) do
    assert(rules[key] ~= nil, string.format("Missing required rule: %s", key))
  end

  -- ... rest of function ...
end
```

## Validation Checks

| Check | Catches |
|-------|---------|
| Same keys in both presets | Forgetting to add to one preset |
| All values wrapped | Raw values instead of `blend()`/`step()` |
| Modes match | `blend()` in dark but `step()` in light |
| Types match | Number in dark but string in light |
| Required keys exist | Missing keys used by generate_palette |

## When to Run

1. **Dev mode**: Auto-run on module load, log to console
2. **On demand**: Call `ThemeManager.validate()` from debug tools
3. **CI/Tests**: If you have a test suite, add validation test

## Example Output

```
[ThemeManager] Validation errors:
Key 'my_new_color' in dark preset but missing from light
Key 'typo_delta' in light preset but missing from dark
Key 'raw_value' in dark preset is not wrapped (use blend() or step())
```

## Files to Modify

- `arkitekt/core/theme_manager/init.lua` - Add validate function and auto-check

## Effort

Low. ~50 lines for full validation. Catches bugs before they become runtime issues.
