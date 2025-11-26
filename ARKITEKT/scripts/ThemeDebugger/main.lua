-- @description Theme Debugger - Live palette editor
-- @author ARKITEKT
-- @version 0.1.0
-- @provides [main] .

-- Bootstrap ARKITEKT
local script_path = debug.getinfo(1, 'S').source:match("@?(.*[/\\])")
local ark_path = script_path:match("(.+)[/\\]scripts[/\\]")
if ark_path then
  package.path = ark_path .. "/?.lua;" .. ark_path .. "/?/init.lua;" .. package.path
end

-- Core requires
local ark = require('arkitekt')
local Shell = require('arkitekt.app.shell')
local Theme = require('arkitekt.core.theme')
local Debug = require('arkitekt.core.theme_manager.debug')
local Colors = require('arkitekt.core.colors')
local Palette = require('arkitekt.defs.colors')
local Registry = require('arkitekt.core.theme_manager.registry')

-- Enable debug mode
Debug.enable_debug()

-- Run as standalone window
Shell.run({
  title = "Theme Debugger",
  version = "0.1.0",
  app_name = "ThemeDebugger",
  toggle_button = true,
  initial_size = { 800, 700 },
  min_size = { 600, 400 },
  show_titlebar = true,
  show_status_bar = false,

  draw = function(ctx, state)
    local ImGui = require('arkitekt.core.imgui')
    local C = Theme.COLORS

    local lightness = Theme.get_theme_lightness()
    local t = Theme.get_t()
    local current_mode = Theme.get_mode()

    -- Header info
    ImGui.Text(ctx, string.format("Mode: %s | Lightness: %.3f | t: %.3f",
      current_mode or "nil", lightness, t))

    -- Validation status
    local valid, err = Debug.validate()
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
    for _ in pairs(Debug.modified_keys) do mod_count = mod_count + 1 end
    if mod_count > 0 then
      ImGui.SameLine(ctx)
      ImGui.TextColored(ctx, 0xFFAA00FF, string.format("[%d modified]", mod_count))
    end

    ImGui.Separator(ctx)

    -- Toolbar
    if ImGui.Button(ctx, "Copy All as Lua") then
      local lua_code = Debug.export_global_as_lua()
      if reaper.CF_SetClipboard then
        reaper.CF_SetClipboard(lua_code)
        reaper.ShowConsoleMsg("Theme Debugger: Copied to clipboard!\n")
      end
    end

    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Copy Modified") then
      local lua_code = Debug.export_modified_as_lua()
      if reaper.CF_SetClipboard then
        reaper.CF_SetClipboard(lua_code)
        reaper.ShowConsoleMsg("Theme Debugger: Modified values copied!\n")
      end
    end

    ImGui.SameLine(ctx)
    if mod_count > 0 then
      if ImGui.Button(ctx, "Reset All") then
        Debug.clear_all_overrides()
      end
    else
      ImGui.BeginDisabled(ctx)
      ImGui.Button(ctx, "Reset All")
      ImGui.EndDisabled(ctx)
    end

    ImGui.SameLine(ctx)
    ImGui.Text(ctx, "  ")
    ImGui.SameLine(ctx)
    local _, show_mod = ImGui.Checkbox(ctx, "Modified only", Debug.show_only_modified)
    Debug.show_only_modified = show_mod

    ImGui.Separator(ctx)

    -- Filter
    ImGui.SetNextItemWidth(ctx, 200)
    local _, filter = ImGui.InputText(ctx, "Filter", Debug.filter_text)
    Debug.filter_text = filter

    ImGui.Separator(ctx)

    -- Scrollable content
    if ImGui.BeginChild(ctx, "palette_list", 0, 0, ImGui.ChildFlags_Borders) then
      -- Draw all palette entries
      draw_palette_entries(ctx, ImGui)
      ImGui.EndChild(ctx)
    end
  end,

  on_close = function()
    Debug.disable_debug()
  end,
})

-- Helper: Draw palette entries
function draw_palette_entries(ctx, ImGui)
  -- Global palette section
  local global_open = ImGui.CollapsingHeader(ctx, "Global Theme Colors", ImGui.TreeNodeFlags_DefaultOpen)
  if global_open then
    local keys = {}
    for key in pairs(Palette.colors) do
      local include = true
      if Debug.filter_text ~= "" then
        include = key:lower():find(Debug.filter_text:lower(), 1, true) ~= nil
      end
      if Debug.show_only_modified and not Debug.modified_keys[key] then
        include = false
      end
      if include then
        keys[#keys + 1] = key
      end
    end
    table.sort(keys)

    for _, key in ipairs(keys) do
      local original = Palette.colors[key]
      local current = Debug.overrides[key]
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
        if Debug.filter_text ~= "" then
          include = key:lower():find(Debug.filter_text:lower(), 1, true) ~= nil
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
end

-- Helper: Format value for display
function format_value(val)
  if type(val) == "string" then
    return val
  elseif type(val) == "number" then
    return string.format("%.3f", val):gsub("%.?0+$", "")
  else
    return tostring(val)
  end
end

-- Helper: Convert hex to int
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

-- Helper: Convert int to hex
local function int_to_hex(color_int)
  local r = (color_int >> 24) & 0xFF
  local g = (color_int >> 16) & 0xFF
  local b = (color_int >> 8) & 0xFF
  return string.format("#%02X%02X%02X", r, g, b)
end

-- Helper: Draw slider
local function draw_slider(ctx, ImGui, label, value, min_val, max_val, format)
  format = format or "%.3f"
  ImGui.SetNextItemWidth(ctx, 120)
  local changed, new_val = ImGui.SliderDouble(ctx, label, value, min_val, max_val, format)
  return changed, new_val
end

-- Helper: Draw color picker
local function draw_color_picker(ctx, ImGui, label, hex_value)
  local color_int = hex_to_int(hex_value)
  local flags = ImGui.ColorEditFlags_NoInputs
              | ImGui.ColorEditFlags_NoLabel
              | ImGui.ColorEditFlags_NoAlpha
  local changed, new_color = ImGui.ColorEdit3(ctx, label, color_int, flags)
  if changed then
    return true, int_to_hex(new_color)
  end
  return false, hex_value
end

-- Helper: Draw entry editor
function draw_entry_editor(ctx, ImGui, key, original_def, current_def)
  local def = current_def or original_def
  if type(def) ~= "table" or not def.mode then return end

  local modified = Debug.modified_keys[key]
  local mode = def.mode

  ImGui.PushID(ctx, key)

  -- Key name with modification indicator
  if modified then
    ImGui.TextColored(ctx, 0xFFAA00FF, key)
  else
    ImGui.Text(ctx, key)
  end

  ImGui.SameLine(ctx, 220)
  ImGui.TextDisabled(ctx, string.format("[%s]", mode))

  if mode == "bg" then
    ImGui.SameLine(ctx)
    ImGui.TextDisabled(ctx, "(passthrough)")

  elseif mode == "lerp" then
    ImGui.SameLine(ctx)
    if type(def.dark) == "number" then
      local changed, new_val = draw_slider(ctx, ImGui, "##dark", def.dark, 0, 2, "D:%.3f")
      if changed then Debug.set_override(key, "dark", new_val) end
    elseif type(def.dark) == "string" then
      local changed, new_val = draw_color_picker(ctx, ImGui, "##dark", def.dark)
      if changed then Debug.set_override(key, "dark", new_val) end
    end
    ImGui.SameLine(ctx)
    ImGui.Text(ctx, "->")
    ImGui.SameLine(ctx)
    if type(def.light) == "number" then
      local changed, new_val = draw_slider(ctx, ImGui, "##light", def.light, 0, 2, "L:%.3f")
      if changed then Debug.set_override(key, "light", new_val) end
    elseif type(def.light) == "string" then
      local changed, new_val = draw_color_picker(ctx, ImGui, "##light", def.light)
      if changed then Debug.set_override(key, "light", new_val) end
    end

  elseif mode == "offset" then
    ImGui.SameLine(ctx)
    local changed_d, new_d = draw_slider(ctx, ImGui, "##dark", def.dark or 0, -0.5, 0.5, "D:%+.3f")
    if changed_d then Debug.set_override(key, "dark", new_d) end
    ImGui.SameLine(ctx)
    ImGui.Text(ctx, "/")
    ImGui.SameLine(ctx)
    local changed_l, new_l = draw_slider(ctx, ImGui, "##light", def.light or 0, -0.5, 0.5, "L:%+.3f")
    if changed_l then Debug.set_override(key, "light", new_l) end

  elseif mode == "snap" then
    ImGui.SameLine(ctx)
    if type(def.dark) == "string" then
      local changed, new_val = draw_color_picker(ctx, ImGui, "##dark", def.dark)
      if changed then Debug.set_override(key, "dark", new_val) end
    elseif type(def.dark) == "number" then
      local changed, new_val = draw_slider(ctx, ImGui, "##dark", def.dark, 0, 2, "D:%.3f")
      if changed then Debug.set_override(key, "dark", new_val) end
    end
    ImGui.SameLine(ctx)
    ImGui.Text(ctx, "|")
    ImGui.SameLine(ctx)
    if type(def.light) == "string" then
      local changed, new_val = draw_color_picker(ctx, ImGui, "##light", def.light)
      if changed then Debug.set_override(key, "light", new_val) end
    elseif type(def.light) == "number" then
      local changed, new_val = draw_slider(ctx, ImGui, "##light", def.light, 0, 2, "L:%.3f")
      if changed then Debug.set_override(key, "light", new_val) end
    end
    ImGui.SameLine(ctx)
    local threshold = def.threshold or 0.5
    local changed_t, new_t = draw_slider(ctx, ImGui, "##threshold", threshold, 0, 1, "T:%.2f")
    if changed_t then Debug.set_override(key, "threshold", new_t) end
  end

  -- Reset button for modified entries
  if modified then
    ImGui.SameLine(ctx)
    if ImGui.SmallButton(ctx, "Reset") then
      Debug.clear_override(key)
    end
  end

  ImGui.PopID(ctx)
end
