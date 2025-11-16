-- @noindex
-- ReArkitekt/gui/widgets/tools/color_picker_window.lua
-- Floating color picker window for live batch recoloring
-- Opens as a draggable, always-on-top window with hue wheel picker
-- Changes apply instantly to selected items as you adjust the color

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')

local M = {}
local hexrgb = Colors.hexrgb

-- State for each picker instance
local instances = {}

--- Create or get a color picker instance
--- @param id string Unique identifier for this picker
--- @return table Instance state
local function get_instance(id)
  if not instances[id] then
    instances[id] = {
      is_open = false,
      current_color = 0xFF0000FF,  -- Default red
      backup_color = nil,
      first_open = true,
    }
  end
  return instances[id]
end

--- Open the color picker window
--- @param id string Unique identifier for this picker
--- @param initial_color number Optional initial color (RGBA)
function M.open(id, initial_color)
  local inst = get_instance(id)
  inst.is_open = true
  if initial_color then
    inst.current_color = initial_color
    inst.backup_color = initial_color
  end
  inst.first_open = true
end

--- Close the color picker window
--- @param id string Unique identifier for this picker
function M.close(id)
  local inst = get_instance(id)
  inst.is_open = false
end

--- Check if the color picker is open
--- @param id string Unique identifier for this picker
--- @return boolean
function M.is_open(id)
  local inst = get_instance(id)
  return inst.is_open
end

--- Render the color picker window
--- @param ctx userdata ImGui context
--- @param id string Unique identifier for this picker
--- @param config table Configuration { on_change = function(color), title = string }
--- @return boolean changed Whether color was changed this frame
function M.render(ctx, id, config)
  config = config or {}
  local inst = get_instance(id)

  if not inst.is_open then
    return false
  end

  local title = config.title or "Color Picker"
  local on_change = config.on_change

  -- Window flags: always on top, auto-resize, with close button
  local window_flags = ImGui.WindowFlags_AlwaysAutoResize |
                       ImGui.WindowFlags_NoCollapse |
                       ImGui.WindowFlags_TopMost

  -- Set initial window position (center of screen) on first open
  if inst.first_open then
    local viewport = ImGui.GetMainViewport(ctx)
    local display_w, display_h = ImGui.Viewport_GetSize(viewport)
    ImGui.SetNextWindowPos(ctx, display_w * 0.5, display_h * 0.5, ImGui.Cond_Appearing, 0.5, 0.5)
    inst.first_open = false
  end

  -- Begin window
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 12, 12)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding, 4)

  local visible, open = ImGui.Begin(ctx, title .. "##" .. id, true, window_flags)

  ImGui.PopStyleVar(ctx, 2)

  -- Update open state from window close button
  if not open then
    inst.is_open = false
    ImGui.End(ctx)
    return false
  end

  if not visible then
    ImGui.End(ctx)
    return false
  end

  local changed = false

  -- Style the color picker with dark borders
  ImGui.PushStyleColor(ctx, ImGui.Col_Border, hexrgb("#000000FF"))  -- Dark border for triangle
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameBorderSize, 1)

  -- Color picker configuration
  local picker_flags = ImGui.ColorEditFlags_PickerHueWheel |
                       ImGui.ColorEditFlags_NoSidePreview |
                       ImGui.ColorEditFlags_NoSmallPreview |
                       ImGui.ColorEditFlags_NoAlpha |
                       ImGui.ColorEditFlags_NoInputs |
                       ImGui.ColorEditFlags_NoLabel

  -- Convert our RGBA to ImGui's ARGB format
  local argb_color = Colors.rgba_to_argb(inst.current_color)

  -- Draw the color picker (hue wheel + triangle)
  local rv, new_argb_color = ImGui.ColorPicker4(ctx, '##picker', argb_color, picker_flags)

  ImGui.PopStyleVar(ctx, 1)
  ImGui.PopStyleColor(ctx, 1)

  if rv then
    -- Convert ImGui's ARGB back to our RGBA format
    inst.current_color = Colors.argb_to_rgba(new_argb_color)
    changed = true

    -- Call callback immediately on change (live update)
    if on_change then
      reaper.ShowConsoleMsg(string.format("Color changed to RGBA: %08X (was ARGB: %08X)\n", inst.current_color, new_argb_color))
      on_change(inst.current_color)
    end
  end

  -- Optional: Show hex value
  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  local hex_str = string.format("#%06X", (inst.current_color >> 8) & 0xFFFFFF)
  ImGui.Text(ctx, "Color: " .. hex_str)

  -- Close button at bottom
  ImGui.Spacing(ctx)
  local button_w = ImGui.GetContentRegionAvail(ctx)
  if ImGui.Button(ctx, "Close", button_w, 0) then
    inst.is_open = false
  end

  ImGui.End(ctx)

  return changed
end

--- Get the current color value
--- @param id string Unique identifier for this picker
--- @return number Current color (RGBA)
function M.get_color(id)
  local inst = get_instance(id)
  return inst.current_color
end

--- Set the current color value (without triggering callback)
--- @param id string Unique identifier for this picker
--- @param color number Color to set (RGBA)
function M.set_color(id, color)
  local inst = get_instance(id)
  inst.current_color = color
end

return M
