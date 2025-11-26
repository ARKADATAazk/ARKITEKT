-- @noindex
-- arkitekt/core/theme_manager/debug.lua
-- Debug window and validation
--
-- Provides visual debugging tools for tuning theme values.

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
-- VALIDATION
-- =============================================================================

--- Validate colors structure
function M.validate()
  local errors = {}
  local valid_modes = { bg = true, lerp = true, offset = true, snap = true }

  for key, def in pairs(Palette.colors) do
    if type(def) == "table" and def.mode then
      -- Check: Valid mode
      if not valid_modes[def.mode] then
        errors[#errors + 1] = string.format(
          "colors.%s has invalid mode '%s'",
          key, tostring(def.mode)
        )
      end

      -- Check: Has dark and light values (except bg mode)
      if def.mode ~= "bg" then
        if def.dark == nil then
          errors[#errors + 1] = string.format("colors.%s missing 'dark' value", key)
        end
        if def.light == nil then
          errors[#errors + 1] = string.format("colors.%s missing 'light' value", key)
        end
      end
    elseif type(def) ~= "table" then
      -- Raw values without mode - could be typo
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
-- DEBUG WINDOW RENDERING
-- =============================================================================

--- Render debug window showing current theme state
function M.render_debug_window(ctx, ImGui, state)
  if not M.debug_enabled then return end
  if not ctx or not ImGui then return end

  local lightness = state.lightness or 0.14
  local t = state.t or 0
  local current_mode = state.mode

  ImGui.SetNextWindowBgAlpha(ctx, 0.92)

  local window_flags = ImGui.WindowFlags_AlwaysAutoResize
  if ImGui.WindowFlags_NoSavedSettings then
    window_flags = window_flags | ImGui.WindowFlags_NoSavedSettings
  end

  local visible, open = ImGui.Begin(ctx, "Theme Debug", true, window_flags)
  if visible then
    -- Header info
    ImGui.Text(ctx, string.format("Lightness: %.3f", lightness))
    ImGui.Text(ctx, string.format("Interpolation t: %.3f", t))
    ImGui.Text(ctx, string.format("Mode: %s", current_mode or "nil"))

    -- Validation status
    local valid, err = M.validate()
    if valid then
      ImGui.TextColored(ctx, 0x4CAF50FF, "Validation: OK")
    else
      ImGui.TextColored(ctx, 0xEF5350FF, "Validation: ERRORS")
      if ImGui.IsItemHovered(ctx) then
        ImGui.SetTooltip(ctx, err)
      end
    end

    ImGui.Separator(ctx)

    -- Presets and anchors
    ImGui.Text(ctx, string.format("Dark preset: %s (t=0, L=%.2f)", Palette.presets.dark, Palette.anchors.dark))
    ImGui.Text(ctx, string.format("Light preset: %s (t=1, L=%.2f)", Palette.presets.light, Palette.anchors.light))
    ImGui.Separator(ctx)

    -- All Theme.COLORS
    if ImGui.CollapsingHeader(ctx, "Theme.COLORS", ImGui.TreeNodeFlags_DefaultOpen) then
      local Theme = get_theme()
      local color_keys = {}
      for k in pairs(Theme.COLORS) do
        color_keys[#color_keys + 1] = k
      end
      table.sort(color_keys)

      for _, k in ipairs(color_keys) do
        local v = Theme.COLORS[k]
        if type(v) == "number" and v == math.floor(v) then
          ImGui.ColorButton(ctx, "style_" .. k, math.floor(v), 0, 12, 12)
          ImGui.SameLine(ctx)
          ImGui.Text(ctx, string.format("%s: 0x%08X", k, math.floor(v)))
        elseif type(v) == "number" then
          ImGui.Text(ctx, string.format("%s: %.3f", k, v))
        else
          ImGui.Text(ctx, string.format("%s: %s", k, tostring(v)))
        end
      end
    end

    -- Colors (flat structure, grouped by mode)
    if ImGui.CollapsingHeader(ctx, "Colors") then
      -- Group by mode for readability
      local by_mode = { bg = {}, offset = {}, snap = {}, lerp = {}, other = {} }
      for k, def in pairs(Palette.colors) do
        if type(def) == "table" and def.mode then
          by_mode[def.mode] = by_mode[def.mode] or {}
          by_mode[def.mode][#by_mode[def.mode] + 1] = k
        else
          by_mode.other[#by_mode.other + 1] = k
        end
      end

      for _, mode in ipairs({"bg", "offset", "snap", "lerp", "other"}) do
        if #(by_mode[mode] or {}) > 0 then
          table.sort(by_mode[mode])
          ImGui.Text(ctx, string.format("  [%s]", mode))
          for _, k in ipairs(by_mode[mode]) do
            ImGui.Text(ctx, "    " .. k)
          end
        end
      end
    end

    -- Registered script palettes
    for script_name, palette_def in pairs(Registry.script_palettes) do
      if ImGui.CollapsingHeader(ctx, "Script: " .. script_name) then
        local keys = {}
        for k in pairs(palette_def) do keys[#keys + 1] = k end
        table.sort(keys)
        for _, k in ipairs(keys) do
          local def = palette_def[k]
          if type(def) == "table" and def.mode then
            ImGui.Text(ctx, string.format("  %s [%s]", k, def.mode))
          else
            ImGui.Text(ctx, "  " .. k)
          end
        end
      end
    end

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
