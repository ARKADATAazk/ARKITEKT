-- @noindex
-- arkitekt/core/theme_manager/debug.lua
-- Live theme debugger with editing and export
--
-- Features:
--   - Live editing of DSL values (lerp, offset, snap)
--   - Real-time palette regeneration
--   - Export as Lua DSL code (for theme.lua)
--   - Separate export for global and script palettes

local Colors = require('arkitekt.core.colors')
local Palette = require('arkitekt.defs.colors')
local Engine = require('arkitekt.core.theme_manager.engine')
local Registry = require('arkitekt.core.theme_manager.registry')

local M = {}

-- Lazy load Theme to avoid circular dependency
local _Theme
local function get_theme()
  if not _Theme then
    _Theme = require('arkitekt.core.theme')
  end
  return _Theme
end

-- =============================================================================
-- DEBUG STATE
-- =============================================================================

M.debug_enabled = false

-- Temporary overrides (session only, not persisted)
-- Structure: { KEY = { dark = val, light = val, threshold = val }, ... }
M.overrides = {}

-- Track which keys have been modified
M.modified_keys = {}

-- UI state
M.scroll_y = 0
M.filter_text = ""
M.show_only_modified = false
M.expand_global = true
M.expand_scripts = {}

function M.toggle_debug()
  M.debug_enabled = not M.debug_enabled
end

function M.enable_debug()
  M.debug_enabled = true
end

function M.disable_debug()
  M.debug_enabled = false
end

-- =============================================================================
-- OVERRIDE MANAGEMENT
-- =============================================================================

--- Apply an override to a palette key
--- @param key string Palette key
--- @param field string "dark", "light", or "threshold"
--- @param value any New value
function M.set_override(key, field, value)
  if not M.overrides[key] then
    -- Initialize from original definition
    local def = Palette.colors[key]
    if def and type(def) == "table" and def.mode then
      M.overrides[key] = {
        mode = def.mode,
        dark = def.dark,
        light = def.light,
        threshold = def.threshold or 0.5,
      }
    else
      return -- Can't override non-DSL values
    end
  end

  M.overrides[key][field] = value
  M.modified_keys[key] = true

  -- Regenerate palette with overrides
  M.apply_overrides()
end

--- Restore a single key to its original value
local function restore_original(key)
  local Theme = get_theme()
  local base_bg = Theme.COLORS.BG_BASE
  if not base_bg then return end

  local original_def = Palette.colors[key]
  if not original_def then return end

  local _, _, bg_lightness = Colors.rgb_to_hsl(base_bg)
  local t = Engine.compute_t(bg_lightness)

  local original_value = Engine.derive_entry(base_bg, original_def, t)
  if original_value then
    Theme.COLORS[key] = original_value
  end
end

--- Clear override for a key (revert to original)
function M.clear_override(key)
  M.overrides[key] = nil
  M.modified_keys[key] = nil
  -- Restore the original value for this key
  restore_original(key)
  Registry.clear_cache()
end

--- Clear all overrides
function M.clear_all_overrides()
  -- Collect keys to restore before clearing
  local keys_to_restore = {}
  for key in pairs(M.overrides) do
    keys_to_restore[#keys_to_restore + 1] = key
  end

  M.overrides = {}
  M.modified_keys = {}

  -- Restore all original values
  for _, key in ipairs(keys_to_restore) do
    restore_original(key)
  end
  Registry.clear_cache()
end

--- Apply current overrides to Theme.COLORS
function M.apply_overrides()
  local Theme = get_theme()
  local base_bg = Theme.COLORS.BG_BASE
  if not base_bg then return end

  local _, _, bg_lightness = Colors.rgb_to_hsl(base_bg)
  local t = Engine.compute_t(bg_lightness)

  -- Regenerate each overridden key
  for key, override in pairs(M.overrides) do
    local def = {
      mode = override.mode,
      dark = override.dark,
      light = override.light,
      threshold = override.threshold,
    }

    -- Derive the new value
    local new_value = Engine.derive_entry(base_bg, def, t)
    if new_value then
      Theme.COLORS[key] = new_value
    end
  end

  -- Clear script palette cache so they regenerate
  Registry.clear_cache()
end

-- =============================================================================
-- VALIDATION
-- =============================================================================

--- Validate colors structure
function M.validate()
  local errors = {}
  local valid_modes = { bg = true, lerp = true, offset = true, snap = true }

  for key, def in pairs(Palette.colors) do
    if type(def) == "table" and def.mode then
      if not valid_modes[def.mode] then
        errors[#errors + 1] = string.format(
          "colors.%s has invalid mode '%s'",
          key, tostring(def.mode)
        )
      end
      if def.mode ~= "bg" then
        if def.dark == nil then
          errors[#errors + 1] = string.format("colors.%s missing 'dark' value", key)
        end
        if def.light == nil then
          errors[#errors + 1] = string.format("colors.%s missing 'light' value", key)
        end
      end
    elseif type(def) ~= "table" then
      errors[#errors + 1] = string.format(
        "colors.%s is raw value '%s' (missing DSL wrapper?)",
        key, tostring(def)
      )
    end
  end

  if #errors > 0 then
    return false, table.concat(errors, "\n")
  end
  return true, nil
end

--- Get validation summary
function M.get_validation_summary()
  local valid, err = M.validate()
  local count = 0
  for _ in pairs(Palette.colors) do count = count + 1 end
  return {
    valid = valid,
    error_message = err,
    color_count = count,
    error_count = err and select(2, err:gsub("\n", "\n")) + 1 or 0,
  }
end

-- =============================================================================
-- EXPORT AS LUA
-- =============================================================================

--- Format a value for Lua export
local function format_value(val)
  if type(val) == "string" then
    return string.format('"%s"', val)
  elseif type(val) == "number" then
    -- Format nicely: remove trailing zeros
    local formatted = string.format("%.4f", val):gsub("%.?0+$", "")
    if formatted == "" or formatted == "-" then formatted = "0" end
    return formatted
  else
    return tostring(val)
  end
end

--- Export global palette as Lua DSL code
function M.export_global_as_lua()
  local lines = {}
  lines[#lines + 1] = "M.colors = {"

  -- Group by category (based on prefix)
  local categories = {}
  local category_order = {
    "BG", "BORDER", "ACCENT", "TEXT", "PATTERN",
    "TILE", "BADGE", "PLAYLIST", "OP", "BUTTON"
  }

  -- Collect all keys and categorize
  local all_keys = {}
  for key in pairs(Palette.colors) do
    all_keys[#all_keys + 1] = key
  end
  table.sort(all_keys)

  for _, key in ipairs(all_keys) do
    local def = M.overrides[key] or Palette.colors[key]
    if type(def) == "table" and def.mode then
      -- Find category
      local cat = "OTHER"
      for _, prefix in ipairs(category_order) do
        if key:sub(1, #prefix) == prefix then
          cat = prefix
          break
        end
      end

      categories[cat] = categories[cat] or {}
      categories[cat][#categories[cat] + 1] = { key = key, def = def }
    end
  end

  -- Output by category
  for _, cat in ipairs(category_order) do
    if categories[cat] and #categories[cat] > 0 then
      lines[#lines + 1] = ""
      lines[#lines + 1] = string.format("  -- === %s ===", cat)

      for _, item in ipairs(categories[cat]) do
        local key, def = item.key, item.def
        local modified = M.modified_keys[key] and " -- MODIFIED" or ""

        if def.mode == "bg" then
          lines[#lines + 1] = string.format("  %s = bg(),%s", key, modified)
        elseif def.mode == "lerp" then
          lines[#lines + 1] = string.format("  %s = lerp(%s, %s),%s",
            key, format_value(def.dark), format_value(def.light), modified)
        elseif def.mode == "offset" then
          if def.dark == def.light then
            lines[#lines + 1] = string.format("  %s = offset(%s),%s",
              key, format_value(def.dark), modified)
          else
            lines[#lines + 1] = string.format("  %s = offset(%s, %s),%s",
              key, format_value(def.dark), format_value(def.light), modified)
          end
        elseif def.mode == "snap" then
          local threshold = def.threshold or 0.5
          if threshold == 0.5 then
            lines[#lines + 1] = string.format("  %s = snap(%s, %s),%s",
              key, format_value(def.dark), format_value(def.light), modified)
          else
            lines[#lines + 1] = string.format("  %s = snap(%s, %s, %s),%s",
              key, format_value(def.dark), format_value(def.light),
              format_value(threshold), modified)
          end
        end
      end
    end
  end

  -- Handle OTHER category
  if categories.OTHER and #categories.OTHER > 0 then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "  -- === OTHER ==="
    for _, item in ipairs(categories.OTHER) do
      local key, def = item.key, item.def
      local modified = M.modified_keys[key] and " -- MODIFIED" or ""
      if def.mode == "lerp" then
        lines[#lines + 1] = string.format("  %s = lerp(%s, %s),%s",
          key, format_value(def.dark), format_value(def.light), modified)
      elseif def.mode == "snap" then
        lines[#lines + 1] = string.format("  %s = snap(%s, %s),%s",
          key, format_value(def.dark), format_value(def.light), modified)
      end
    end
  end

  lines[#lines + 1] = "}"

  return table.concat(lines, "\n")
end

--- Export only modified values as Lua
function M.export_modified_as_lua()
  if not next(M.modified_keys) then
    return "-- No modifications"
  end

  local lines = {}
  lines[#lines + 1] = "-- Modified values only:"

  local sorted_keys = {}
  for key in pairs(M.modified_keys) do
    sorted_keys[#sorted_keys + 1] = key
  end
  table.sort(sorted_keys)

  for _, key in ipairs(sorted_keys) do
    local def = M.overrides[key]
    if def then
      if def.mode == "lerp" then
        lines[#lines + 1] = string.format("  %s = lerp(%s, %s),",
          key, format_value(def.dark), format_value(def.light))
      elseif def.mode == "offset" then
        if def.dark == def.light then
          lines[#lines + 1] = string.format("  %s = offset(%s),",
            key, format_value(def.dark))
        else
          lines[#lines + 1] = string.format("  %s = offset(%s, %s),",
            key, format_value(def.dark), format_value(def.light))
        end
      elseif def.mode == "snap" then
        local threshold = def.threshold or 0.5
        if threshold == 0.5 then
          lines[#lines + 1] = string.format("  %s = snap(%s, %s),",
            key, format_value(def.dark), format_value(def.light))
        else
          lines[#lines + 1] = string.format("  %s = snap(%s, %s, %s),",
            key, format_value(def.dark), format_value(def.light),
            format_value(threshold))
        end
      end
    end
  end

  return table.concat(lines, "\n")
end

--- Copy text to clipboard (REAPER)
local function copy_to_clipboard(text)
  if reaper and reaper.CF_SetClipboard then
    reaper.CF_SetClipboard(text)
    return true
  end
  return false
end

-- =============================================================================
-- UI RENDERING
-- =============================================================================

--- Draw a slider for a numeric value
local function draw_slider(ctx, ImGui, label, value, min_val, max_val, format)
  format = format or "%.3f"
  ImGui.SetNextItemWidth(ctx, 120)
  local changed, new_val = ImGui.SliderDouble(ctx, label, value, min_val, max_val, format)
  return changed, new_val
end

--- Convert hex string to packed RGBA integer
local function hex_to_int(hex_value)
  if type(hex_value) ~= "string" then return 0x808080FF end
  local hex = hex_value:gsub("^#", "")
  if #hex >= 6 then
    local r = tonumber(hex:sub(1, 2), 16) or 128
    local g = tonumber(hex:sub(3, 4), 16) or 128
    local b = tonumber(hex:sub(5, 6), 16) or 128
    return (r << 24) | (g << 16) | (b << 8) | 0xFF
  end
  return 0x808080FF
end

--- Convert packed RGBA integer to hex string
local function int_to_hex(color_int)
  local r = (color_int >> 24) & 0xFF
  local g = (color_int >> 16) & 0xFF
  local b = (color_int >> 8) & 0xFF
  return string.format("#%02X%02X%02X", r, g, b)
end

--- Draw a color picker for a hex string
local function draw_color_picker(ctx, ImGui, label, hex_value)
  local color_int = hex_to_int(hex_value)

  -- Color picker flags
  local flags = ImGui.ColorEditFlags_NoInputs
              | ImGui.ColorEditFlags_NoLabel
              | ImGui.ColorEditFlags_NoAlpha

  local changed, new_color = ImGui.ColorEdit3(ctx, label, color_int, flags)

  if changed then
    return true, int_to_hex(new_color)
  end

  return false, hex_value
end

--- Draw editor for a single DSL entry
local function draw_entry_editor(ctx, ImGui, key, original_def, current_def)
  local def = current_def or original_def
  if type(def) ~= "table" or not def.mode then return end

  local modified = M.modified_keys[key]
  local mode = def.mode

  ImGui.PushID(ctx, key)

  -- Key name with modification indicator
  if modified then
    ImGui.TextColored(ctx, 0xFFAA00FF, key)
  else
    ImGui.Text(ctx, key)
  end

  ImGui.SameLine(ctx, 200)
  ImGui.TextDisabled(ctx, string.format("[%s]", mode))

  if mode == "bg" then
    ImGui.SameLine(ctx)
    ImGui.TextDisabled(ctx, "(passthrough)")

  elseif mode == "lerp" then
    ImGui.SameLine(ctx)

    -- Dark value
    if type(def.dark) == "number" then
      local changed, new_val = draw_slider(ctx, ImGui, "##dark", def.dark, 0, 2, "D:%.3f")
      if changed then M.set_override(key, "dark", new_val) end
    elseif type(def.dark) == "string" then
      local changed, new_val = draw_color_picker(ctx, ImGui, "##dark", def.dark)
      if changed then M.set_override(key, "dark", new_val) end
    end

    ImGui.SameLine(ctx)
    ImGui.Text(ctx, "->")
    ImGui.SameLine(ctx)

    -- Light value
    if type(def.light) == "number" then
      local changed, new_val = draw_slider(ctx, ImGui, "##light", def.light, 0, 2, "L:%.3f")
      if changed then M.set_override(key, "light", new_val) end
    elseif type(def.light) == "string" then
      local changed, new_val = draw_color_picker(ctx, ImGui, "##light", def.light)
      if changed then M.set_override(key, "light", new_val) end
    end

  elseif mode == "offset" then
    ImGui.SameLine(ctx)

    -- Dark offset
    local changed_d, new_d = draw_slider(ctx, ImGui, "##dark", def.dark or 0, -0.5, 0.5, "D:%+.3f")
    if changed_d then M.set_override(key, "dark", new_d) end

    ImGui.SameLine(ctx)
    ImGui.Text(ctx, "/")
    ImGui.SameLine(ctx)

    -- Light offset
    local changed_l, new_l = draw_slider(ctx, ImGui, "##light", def.light or 0, -0.5, 0.5, "L:%+.3f")
    if changed_l then M.set_override(key, "light", new_l) end

  elseif mode == "snap" then
    ImGui.SameLine(ctx)

    -- Dark value
    if type(def.dark) == "string" then
      local changed, new_val = draw_color_picker(ctx, ImGui, "##dark", def.dark)
      if changed then M.set_override(key, "dark", new_val) end
    elseif type(def.dark) == "number" then
      local changed, new_val = draw_slider(ctx, ImGui, "##dark", def.dark, 0, 2, "D:%.3f")
      if changed then M.set_override(key, "dark", new_val) end
    end

    ImGui.SameLine(ctx)
    ImGui.Text(ctx, "|")
    ImGui.SameLine(ctx)

    -- Light value
    if type(def.light) == "string" then
      local changed, new_val = draw_color_picker(ctx, ImGui, "##light", def.light)
      if changed then M.set_override(key, "light", new_val) end
    elseif type(def.light) == "number" then
      local changed, new_val = draw_slider(ctx, ImGui, "##light", def.light, 0, 2, "L:%.3f")
      if changed then M.set_override(key, "light", new_val) end
    end

    ImGui.SameLine(ctx)

    -- Threshold
    local threshold = def.threshold or 0.5
    local changed_t, new_t = draw_slider(ctx, ImGui, "##threshold", threshold, 0, 1, "T:%.2f")
    if changed_t then M.set_override(key, "threshold", new_t) end
  end

  -- Reset button for modified entries
  if modified then
    ImGui.SameLine(ctx)
    if ImGui.SmallButton(ctx, "Reset##" .. key) then
      M.clear_override(key)
    end
  end

  ImGui.PopID(ctx)
end

--- Render debug window
function M.render_debug_window(ctx, ImGui, state)
  if not M.debug_enabled then return end
  if not ctx or not ImGui then return end

  local lightness = state.lightness or 0.14
  local t = state.t or 0
  local current_mode = state.mode

  -- Window setup - style is already pushed by shell
  ImGui.SetNextWindowSize(ctx, 750, 650, ImGui.Cond_FirstUseEver)

  local visible, open = ImGui.Begin(ctx, "Theme Debugger", true)
  if visible then
    -- Header info
    ImGui.Text(ctx, string.format("Mode: %s | Lightness: %.3f | t: %.3f",
      current_mode or "nil", lightness, t))

    -- Validation status
    local valid, err = M.validate()
    ImGui.SameLine(ctx)
    if valid then
      ImGui.TextColored(ctx, 0x4CAF50FF, "[Valid]")
    else
      ImGui.TextColored(ctx, 0xEF5350FF, "[Errors]")
      if ImGui.IsItemHovered(ctx) then
        ImGui.SetTooltip(ctx, err)
      end
    end

    -- Modified count
    local mod_count = 0
    for _ in pairs(M.modified_keys) do mod_count = mod_count + 1 end
    if mod_count > 0 then
      ImGui.SameLine(ctx)
      ImGui.TextColored(ctx, 0xFFAA00FF, string.format("[%d modified]", mod_count))
    end

    ImGui.Separator(ctx)

    -- Toolbar
    if ImGui.Button(ctx, "Copy All as Lua") then
      local lua_code = M.export_global_as_lua()
      if copy_to_clipboard(lua_code) then
        reaper.ShowConsoleMsg("Theme Debugger: Copied to clipboard!\n")
      end
    end

    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Copy Modified") then
      local lua_code = M.export_modified_as_lua()
      if copy_to_clipboard(lua_code) then
        reaper.ShowConsoleMsg("Theme Debugger: Modified values copied!\n")
      end
    end

    ImGui.SameLine(ctx)
    if mod_count > 0 then
      if ImGui.Button(ctx, "Reset All") then
        M.clear_all_overrides()
      end
    else
      ImGui.BeginDisabled(ctx)
      ImGui.Button(ctx, "Reset All")
      ImGui.EndDisabled(ctx)
    end

    ImGui.SameLine(ctx)
    ImGui.Text(ctx, "  ")
    ImGui.SameLine(ctx)
    local _, show_mod = ImGui.Checkbox(ctx, "Show modified only", M.show_only_modified)
    M.show_only_modified = show_mod

    ImGui.Separator(ctx)

    -- Filter
    ImGui.SetNextItemWidth(ctx, 200)
    local _, filter = ImGui.InputText(ctx, "Filter", M.filter_text)
    M.filter_text = filter

    ImGui.Separator(ctx)

    -- Scrollable content
    if ImGui.BeginChild(ctx, "palette_list", 0, 0, 0) then

      -- Global palette section
      local global_open = ImGui.CollapsingHeader(ctx, "Global Theme Colors", ImGui.TreeNodeFlags_DefaultOpen)
      if global_open then
        -- Collect and sort keys
        local keys = {}
        for key in pairs(Palette.colors) do
          local include = true

          -- Filter check
          if M.filter_text ~= "" then
            include = key:lower():find(M.filter_text:lower(), 1, true) ~= nil
          end

          -- Modified-only check
          if M.show_only_modified and not M.modified_keys[key] then
            include = false
          end

          if include then
            keys[#keys + 1] = key
          end
        end
        table.sort(keys)

        -- Draw entries
        for _, key in ipairs(keys) do
          local original = Palette.colors[key]
          local current = M.overrides[key]
          draw_entry_editor(ctx, ImGui, key, original, current)
        end

        if #keys == 0 then
          ImGui.TextDisabled(ctx, "(no matching entries)")
        end
      end

      ImGui.Spacing(ctx)

      -- Script palettes
      for script_name, palette_def in pairs(Registry.script_palettes) do
        local header = string.format("Script: %s", script_name)
        if ImGui.CollapsingHeader(ctx, header) then
          local keys = {}
          for key in pairs(palette_def) do
            local include = true
            if M.filter_text ~= "" then
              include = key:lower():find(M.filter_text:lower(), 1, true) ~= nil
            end
            if include then
              keys[#keys + 1] = key
            end
          end
          table.sort(keys)

          for _, key in ipairs(keys) do
            local def = palette_def[key]
            if type(def) == "table" and def.mode then
              ImGui.PushID(ctx, script_name .. "_" .. key)
              ImGui.Text(ctx, key)
              ImGui.SameLine(ctx, 200)
              ImGui.TextDisabled(ctx, string.format("[%s]", def.mode))

              -- Show values (read-only for now)
              if def.mode == "lerp" or def.mode == "snap" then
                ImGui.SameLine(ctx)
                ImGui.TextDisabled(ctx, string.format("D:%s L:%s",
                  format_value(def.dark), format_value(def.light)))
              elseif def.mode == "offset" then
                ImGui.SameLine(ctx)
                ImGui.TextDisabled(ctx, string.format("D:%+.3f L:%+.3f",
                  def.dark or 0, def.light or 0))
              end

              ImGui.PopID(ctx)
            end
          end
        end
      end

      ImGui.EndChild(ctx)
    end

    ImGui.End(ctx)
  else
    ImGui.End(ctx)
  end

  if not open then
    M.debug_enabled = false
  end
end

--- Check for F12 key press to toggle debug window
function M.check_debug_hotkey(ctx, ImGui)
  if not ctx or not ImGui then return end
  if ImGui.IsKeyPressed and ImGui.Key_F12 then
    if ImGui.IsKeyPressed(ctx, ImGui.Key_F12) then
      M.toggle_debug()
    end
  end
end

return M
