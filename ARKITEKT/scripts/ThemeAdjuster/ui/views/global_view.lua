-- @noindex
-- ThemeAdjuster/ui/views/global_view.lua
-- Global color controls tab

local ImGui = require 'imgui' '0.10'
local HueSlider = require('rearkitekt.gui.widgets.primitives.hue_slider')
local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}
local GlobalView = {}
GlobalView.__index = GlobalView

function M.new(State, Config, settings)
  local self = setmetatable({
    State = State,
    Config = Config,
    settings = settings,

    -- Slider values (loaded from theme parameters)
    gamma = 1.0,
    highlights = 128,
    midtones = 128,
    shadows = 128,
    saturation = 128,
    tint = 192,  -- 0-384, center = 192 (0°)

    -- Toggles
    custom_track_names = false,
    affect_project_colors = false,
  }, GlobalView)

  -- Load initial values from theme
  self:load_from_theme()

  return self
end

function GlobalView:load_from_theme()
  -- Load values from REAPER theme parameters
  local ok, gamma = pcall(reaper.ThemeLayout_GetParameter, -1000)
  if ok and type(gamma) == "number" then self.gamma = gamma / 1000 end

  local ok, highlights = pcall(reaper.ThemeLayout_GetParameter, -1003)
  if ok and type(highlights) == "number" then self.highlights = highlights end

  local ok, midtones = pcall(reaper.ThemeLayout_GetParameter, -1002)
  if ok and type(midtones) == "number" then self.midtones = midtones end

  local ok, shadows = pcall(reaper.ThemeLayout_GetParameter, -1001)
  if ok and type(shadows) == "number" then self.shadows = shadows end

  local ok, saturation = pcall(reaper.ThemeLayout_GetParameter, -1004)
  if ok and type(saturation) == "number" then self.saturation = saturation end

  local ok, tint = pcall(reaper.ThemeLayout_GetParameter, -1005)
  if ok and type(tint) == "number" then self.tint = tint end
end

function GlobalView:set_param(param_id, value, save)
  save = save == nil and true or save
  local ok = pcall(reaper.ThemeLayout_SetParameter, param_id, value, save)
  if ok and save then
    pcall(reaper.ThemeLayout_RefreshAll)
  end
  return ok
end

function GlobalView:reset_color_controls()
  -- Reset all color controls to defaults
  self.gamma = 1.0
  self.highlights = 128
  self.midtones = 128
  self.shadows = 128
  self.saturation = 128
  self.tint = 192

  self:set_param(-1000, self.gamma * 1000, true)
  self:set_param(-1001, self.shadows, true)
  self:set_param(-1002, self.midtones, true)
  self:set_param(-1003, self.highlights, true)
  self:set_param(-1004, self.saturation, true)
  self:set_param(-1005, self.tint, true)
end

function GlobalView:draw(ctx, shell_state)
  -- Title
  ImGui.PushFont(ctx, shell_state.fonts.bold, 14)
  ImGui.Text(ctx, "Global Color Controls")
  ImGui.PopFont(ctx)

  ImGui.Dummy(ctx, 0, 10)

  -- Gamma slider (grayscale, 0-2.0, default 1.0)
  ImGui.Text(ctx, "Gamma")
  ImGui.SameLine(ctx, 150)
  ImGui.Text(ctx, string.format("%.2f", self.gamma))

  local changed, new_gamma = HueSlider.draw_gamma(ctx, "##gamma", self.gamma * 100, {
    w = 300,
    h = 20,
    default = 100,
  })
  if changed then
    self.gamma = new_gamma / 100
    self:set_param(-1000, self.gamma * 1000, false)
  end
  if ImGui.IsItemDeactivatedAfterEdit(ctx) then
    self:set_param(-1000, self.gamma * 1000, true)
  end

  ImGui.Dummy(ctx, 0, 5)

  -- Highlights slider (grayscale, 0-256, default 128)
  ImGui.Text(ctx, "Highlights")
  ImGui.SameLine(ctx, 150)
  ImGui.Text(ctx, string.format("%d", self.highlights))

  local changed, new_highlights = HueSlider.draw_gamma(ctx, "##highlights", (self.highlights / 256) * 100, {
    w = 300,
    h = 20,
    default = 50,
  })
  if changed then
    self.highlights = math.floor((new_highlights / 100) * 256 + 0.5)
    self:set_param(-1003, self.highlights, false)
  end
  if ImGui.IsItemDeactivatedAfterEdit(ctx) then
    self:set_param(-1003, self.highlights, true)
  end

  ImGui.Dummy(ctx, 0, 5)

  -- Midtones slider (grayscale, 0-256, default 128)
  ImGui.Text(ctx, "Midtones")
  ImGui.SameLine(ctx, 150)
  ImGui.Text(ctx, string.format("%d", self.midtones))

  local changed, new_midtones = HueSlider.draw_gamma(ctx, "##midtones", (self.midtones / 256) * 100, {
    w = 300,
    h = 20,
    default = 50,
  })
  if changed then
    self.midtones = math.floor((new_midtones / 100) * 256 + 0.5)
    self:set_param(-1002, self.midtones, false)
  end
  if ImGui.IsItemDeactivatedAfterEdit(ctx) then
    self:set_param(-1002, self.midtones, true)
  end

  ImGui.Dummy(ctx, 0, 5)

  -- Shadows slider (grayscale, 0-256, default 128)
  ImGui.Text(ctx, "Shadows")
  ImGui.SameLine(ctx, 150)
  ImGui.Text(ctx, string.format("%d", self.shadows))

  local changed, new_shadows = HueSlider.draw_gamma(ctx, "##shadows", (self.shadows / 256) * 100, {
    w = 300,
    h = 20,
    default = 50,
  })
  if changed then
    self.shadows = math.floor((new_shadows / 100) * 256 + 0.5)
    self:set_param(-1001, self.shadows, false)
  end
  if ImGui.IsItemDeactivatedAfterEdit(ctx) then
    self:set_param(-1001, self.shadows, true)
  end

  ImGui.Dummy(ctx, 0, 5)

  -- Saturation slider (grayscale with color hint, 0-256, default 128, displays as %)
  ImGui.Text(ctx, "Saturation")
  ImGui.SameLine(ctx, 150)
  ImGui.Text(ctx, string.format("%d%%", math.floor((self.saturation / 256) * 100 + 0.5)))

  local changed, new_saturation = HueSlider.draw_saturation(ctx, "##saturation", (self.saturation / 256) * 100, 210, {
    w = 300,
    h = 20,
    default = 50,
    brightness = 80,
  })
  if changed then
    self.saturation = math.floor((new_saturation / 100) * 256 + 0.5)
    self:set_param(-1004, self.saturation, false)
  end
  if ImGui.IsItemDeactivatedAfterEdit(ctx) then
    self:set_param(-1004, self.saturation, true)
  end

  ImGui.Dummy(ctx, 0, 5)

  -- Tint slider (hue gradient, 0-384, default 192, displays as -180° to +180°)
  local tint_degrees = (self.tint - 192) * (360 / 384)
  ImGui.Text(ctx, "Tint")
  ImGui.SameLine(ctx, 150)
  ImGui.Text(ctx, string.format("%.0f°", tint_degrees))

  local changed, new_tint_normalized = HueSlider.draw_hue(ctx, "##tint", ((self.tint / 384) * 360), {
    w = 300,
    h = 20,
    default = 180,
    saturation = 75,
    brightness = 80,
  })
  if changed then
    self.tint = math.floor((new_tint_normalized / 360) * 384 + 0.5)
    self:set_param(-1005, self.tint, false)
  end
  if ImGui.IsItemDeactivatedAfterEdit(ctx) then
    self:set_param(-1005, self.tint, true)
  end

  ImGui.Dummy(ctx, 0, 15)

  -- Toggles
  if ImGui.Checkbox(ctx, "Custom color track names", self.custom_track_names) then
    self.custom_track_names = not self.custom_track_names
    -- TODO: Set 'glb_track_label_color' parameter
  end

  if ImGui.Checkbox(ctx, "Also affect project custom colors", self.affect_project_colors) then
    self.affect_project_colors = not self.affect_project_colors
    self:set_param(-1006, self.affect_project_colors and 1 or 0, true)
  end

  ImGui.Dummy(ctx, 0, 15)

  -- Reset button
  if ImGui.Button(ctx, "Reset All Color Controls") then
    self:reset_color_controls()
  end
end

return M
