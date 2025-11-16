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
  local avail_w = ImGui.GetContentRegionAvail(ctx)

  -- Title
  ImGui.PushFont(ctx, shell_state.fonts.bold, 16)
  ImGui.Text(ctx, "Global Color Controls")
  ImGui.PopFont(ctx)

  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#999999"))
  ImGui.Text(ctx, "Adjust theme-wide color properties")
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 15)

  -- Color Sliders Section
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#1A1A1A"))
  if ImGui.BeginChild(ctx, "global_color_sliders", avail_w, 0, ImGui.ChildFlags_Border) then
    ImGui.Dummy(ctx, 0, 8)

    ImGui.Indent(ctx, 12)
    ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
    ImGui.Text(ctx, "COLOR ADJUSTMENTS")
    ImGui.PopFont(ctx)
    ImGui.Dummy(ctx, 0, 12)

  -- Helper function for slider rows
  local function draw_slider_row(label, value_text, slider_func, slider_id, slider_value, slider_opts)
    ImGui.AlignTextToFramePadding(ctx)
    ImGui.Text(ctx, label)
    ImGui.SameLine(ctx, 150)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#CCCCCC"))
    ImGui.Text(ctx, value_text)
    ImGui.PopStyleColor(ctx)
    ImGui.Dummy(ctx, 0, 4)

    local changed, new_val = slider_func(ctx, slider_id, slider_value, slider_opts)
    ImGui.Dummy(ctx, 0, 8)
    return changed, new_val
  end

  -- Gamma slider (grayscale, 0-2.0, default 1.0)
  local changed, new_gamma = draw_slider_row(
    "Gamma",
    string.format("%.2f", self.gamma),
    HueSlider.draw_gamma,
    "##gamma",
    self.gamma * 100,
    {w = math.min(350, avail_w - 200), h = 22, default = 100}
  )
  if changed then
    self.gamma = new_gamma / 100
    self:set_param(-1000, self.gamma * 1000, false)
  end
  if ImGui.IsItemDeactivatedAfterEdit(ctx) then
    self:set_param(-1000, self.gamma * 1000, true)
  end

  -- Highlights slider
  changed, new_highlights = draw_slider_row(
    "Highlights",
    string.format("%d", self.highlights),
    HueSlider.draw_gamma,
    "##highlights",
    (self.highlights / 256) * 100,
    {w = math.min(350, avail_w - 200), h = 22, default = 50}
  )
  if changed then
    self.highlights = math.floor((new_highlights / 100) * 256 + 0.5)
    self:set_param(-1003, self.highlights, false)
  end
  if ImGui.IsItemDeactivatedAfterEdit(ctx) then
    self:set_param(-1003, self.highlights, true)
  end

  -- Midtones slider
  local changed, new_midtones = draw_slider_row(
    "Midtones",
    string.format("%d", self.midtones),
    HueSlider.draw_gamma,
    "##midtones",
    (self.midtones / 256) * 100,
    {w = math.min(350, avail_w - 200), h = 22, default = 50}
  )
  if changed then
    self.midtones = math.floor((new_midtones / 100) * 256 + 0.5)
    self:set_param(-1002, self.midtones, false)
  end
  if ImGui.IsItemDeactivatedAfterEdit(ctx) then
    self:set_param(-1002, self.midtones, true)
  end

  -- Shadows slider
  changed, new_shadows = draw_slider_row(
    "Shadows",
    string.format("%d", self.shadows),
    HueSlider.draw_gamma,
    "##shadows",
    (self.shadows / 256) * 100,
    {w = math.min(350, avail_w - 200), h = 22, default = 50}
  )
  if changed then
    self.shadows = math.floor((new_shadows / 100) * 256 + 0.5)
    self:set_param(-1001, self.shadows, false)
  end
  if ImGui.IsItemDeactivatedAfterEdit(ctx) then
    self:set_param(-1001, self.shadows, true)
  end

  -- Saturation slider
  changed, new_saturation = draw_slider_row(
    "Saturation",
    string.format("%d%%", math.floor((self.saturation / 256) * 100 + 0.5)),
    function(c, i, v, o) return HueSlider.draw_saturation(c, i, v, 210, o) end,
    "##saturation",
    (self.saturation / 256) * 100,
    {w = math.min(350, avail_w - 200), h = 22, default = 50, brightness = 80}
  )
  if changed then
    self.saturation = math.floor((new_saturation / 100) * 256 + 0.5)
    self:set_param(-1004, self.saturation, false)
  end
  if ImGui.IsItemDeactivatedAfterEdit(ctx) then
    self:set_param(-1004, self.saturation, true)
  end

  -- Tint slider
  local tint_degrees = (self.tint - 192) * (360 / 384)
  changed, new_tint_normalized = draw_slider_row(
    "Tint",
    string.format("%.0f°", tint_degrees),
    HueSlider.draw_hue,
    "##tint",
    ((self.tint / 384) * 360),
    {w = math.min(350, avail_w - 200), h = 22, default = 180, saturation = 75, brightness = 80}
  )
  if changed then
    self.tint = math.floor((new_tint_normalized / 360) * 384 + 0.5)
    self:set_param(-1005, self.tint, false)
  end
  if ImGui.IsItemDeactivatedAfterEdit(ctx) then
    self:set_param(-1005, self.tint, true)
  end

  ImGui.Dummy(ctx, 0, 12)

  -- Toggles
  ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
  ImGui.Text(ctx, "OPTIONS")
  ImGui.PopFont(ctx)
  ImGui.Dummy(ctx, 0, 8)

  if ImGui.Checkbox(ctx, "Custom color track names", self.custom_track_names) then
    self.custom_track_names = not self.custom_track_names
    -- TODO: Set 'glb_track_label_color' parameter
  end

  ImGui.Dummy(ctx, 0, 4)

  if ImGui.Checkbox(ctx, "Also affect project custom colors", self.affect_project_colors) then
    self.affect_project_colors = not self.affect_project_colors
    self:set_param(-1006, self.affect_project_colors and 1 or 0, true)
  end

  ImGui.Dummy(ctx, 0, 12)

  -- Reset button
  if ImGui.Button(ctx, "Reset All Color Controls", 180, 28) then
    self:reset_color_controls()
  end

  ImGui.Unindent(ctx, 12)
  ImGui.Dummy(ctx, 0, 8)
  ImGui.EndChild(ctx)
  end
  ImGui.PopStyleColor(ctx)
end

return M
