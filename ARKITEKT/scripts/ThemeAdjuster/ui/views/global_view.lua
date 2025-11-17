-- @noindex
-- ThemeAdjuster/ui/views/global_view.lua
-- Global color controls tab

local ImGui = require 'imgui' '0.10'
local HueSlider = require('rearkitekt.gui.widgets.primitives.hue_slider')
local Checkbox = require('rearkitekt.gui.widgets.primitives.checkbox')
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
    -- Storage values (actual theme parameter values)
    gamma = 1000,         -- Storage: 500-2000, Display: 0.50-2.00, Default: 1000 (1.00)
    highlights = 256,     -- Storage: 0-512, Display: 0.00-2.00, Default: 256 (1.00)
    midtones = 256,       -- Storage: 0-512, Display: 0.00-2.00, Default: 256 (1.00)
    shadows = 256,        -- Storage: 0-512, Display: 0.00-2.00, Default: 256 (1.00)
    saturation = 256,     -- Storage: 0-512, Display: 0%-200%, Default: 256 (100%)
    tint = 192,           -- Storage: 0-384, Display: -180° to +180°, Default: 192 (0°)

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
  if ok and type(gamma) == "number" then self.gamma = gamma end

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
  self.gamma = 1000
  self.highlights = 256
  self.midtones = 256
  self.shadows = 256
  self.saturation = 256
  self.tint = 192

  self:set_param(-1000, self.gamma, true)
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
  if ImGui.BeginChild(ctx, "global_color_sliders", avail_w, 0, 1) then
    ImGui.Dummy(ctx, 0, 8)

    ImGui.Indent(ctx, 12)
    ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
    ImGui.Text(ctx, "COLOR ADJUSTMENTS")
    ImGui.PopFont(ctx)
    ImGui.Dummy(ctx, 0, 10)

    -- Modern responsive slider layout
    local LABEL_WIDTH = 100
    local VALUE_WIDTH = 70
    local SLIDER_HEIGHT = 24
    local SPACING = 12
    local MIN_SLIDER_WIDTH = 200
    local HORIZONTAL_PADDING = 40  -- Total horizontal padding (20px on each side)

    -- Calculate responsive slider width (extends horizontally to window width)
    local available_for_slider = avail_w - LABEL_WIDTH - VALUE_WIDTH - HORIZONTAL_PADDING - (SPACING * 2)
    local slider_w = math.max(MIN_SLIDER_WIDTH, available_for_slider)

    -- Calculate starting X position for centered layout
    local total_row_width = LABEL_WIDTH + SPACING + slider_w + SPACING + VALUE_WIDTH
    local start_x = (avail_w - total_row_width) / 2

    -- Helper function for modern aligned slider rows
    local function draw_slider_row(label, value_text, slider_func, slider_id, slider_value, slider_opts)
      local cursor_x_base = ImGui.GetCursorPosX(ctx)

      -- LEFT LABEL (right-aligned)
      local label_text_w = ImGui.CalcTextSize(ctx, label)
      ImGui.SetCursorPosX(ctx, cursor_x_base + start_x + LABEL_WIDTH - label_text_w)
      ImGui.AlignTextToFramePadding(ctx)
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
      ImGui.Text(ctx, label)
      ImGui.PopStyleColor(ctx)

      -- SLIDER (fixed width, centered vertically)
      ImGui.SameLine(ctx, 0, SPACING)
      slider_opts.w = slider_w
      slider_opts.h = SLIDER_HEIGHT
      local changed, new_val = slider_func(ctx, slider_id, slider_value, slider_opts)

      -- RIGHT VALUE (left-aligned)
      ImGui.SameLine(ctx, 0, SPACING)
      ImGui.AlignTextToFramePadding(ctx)
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#FFFFFF"))
      ImGui.Text(ctx, value_text)
      ImGui.PopStyleColor(ctx)

      ImGui.Dummy(ctx, 0, 8)
      return changed, new_val
    end

    -- Gamma slider (Storage: 500-2000, Display: 0.50-2.00, Default: 1000)
    local gamma_display = self.gamma / 1000
    local changed, new_gamma_normalized = draw_slider_row(
      "Gamma",
      string.format("%.2f", gamma_display),
      HueSlider.draw_gamma,
      "##gamma",
      ((self.gamma - 500) / 1500) * 100,  -- Map 500-2000 to 0-100
      {default = 33.33}  -- 1000 is 33.33% of range
    )
    if changed then
      self.gamma = math.floor((new_gamma_normalized / 100) * 1500 + 500 + 0.5)
      self:set_param(-1000, self.gamma, false)
    end
    if ImGui.IsItemDeactivatedAfterEdit(ctx) then
      self:set_param(-1000, self.gamma, true)
    end

    -- Highlights slider (Storage: 0-512, Display: 0.00-2.00, Default: 256)
    local highlights_display = self.highlights / 256
    local changed, new_highlights_normalized = draw_slider_row(
      "Highlights",
      string.format("%.2f", highlights_display),
      HueSlider.draw_gamma,
      "##highlights",
      (self.highlights / 512) * 100,  -- Map 0-512 to 0-100
      {default = 50}  -- 256 is 50% of range
    )
    if changed then
      self.highlights = math.floor((new_highlights_normalized / 100) * 512 + 0.5)
      self:set_param(-1003, self.highlights, false)
    end
    if ImGui.IsItemDeactivatedAfterEdit(ctx) then
      self:set_param(-1003, self.highlights, true)
    end

    -- Midtones slider (Storage: 0-512, Display: 0.00-2.00, Default: 256)
    local midtones_display = self.midtones / 256
    local changed, new_midtones_normalized = draw_slider_row(
      "Midtones",
      string.format("%.2f", midtones_display),
      HueSlider.draw_gamma,
      "##midtones",
      (self.midtones / 512) * 100,  -- Map 0-512 to 0-100
      {default = 50}  -- 256 is 50% of range
    )
    if changed then
      self.midtones = math.floor((new_midtones_normalized / 100) * 512 + 0.5)
      self:set_param(-1002, self.midtones, false)
    end
    if ImGui.IsItemDeactivatedAfterEdit(ctx) then
      self:set_param(-1002, self.midtones, true)
    end

    -- Shadows slider (Storage: 0-512, Display: 0.00-2.00, Default: 256)
    local shadows_display = self.shadows / 256
    local changed, new_shadows_normalized = draw_slider_row(
      "Shadows",
      string.format("%.2f", shadows_display),
      HueSlider.draw_gamma,
      "##shadows",
      (self.shadows / 512) * 100,  -- Map 0-512 to 0-100
      {default = 50}  -- 256 is 50% of range
    )
    if changed then
      self.shadows = math.floor((new_shadows_normalized / 100) * 512 + 0.5)
      self:set_param(-1001, self.shadows, false)
    end
    if ImGui.IsItemDeactivatedAfterEdit(ctx) then
      self:set_param(-1001, self.shadows, true)
    end

    -- Saturation slider (Storage: 0-512, Display: 0%-200%, Default: 256 = 100%)
    local saturation_display = math.floor(self.saturation / 2.56 + 0.5)
    local changed, new_saturation_normalized = draw_slider_row(
      "Saturation",
      string.format("%d%%", saturation_display),
      function(c, i, v, o) return HueSlider.draw_saturation(c, i, v, 210, o) end,
      "##saturation",
      (self.saturation / 512) * 100,  -- Map 0-512 to 0-100
      {default = 50, brightness = 80}  -- 256 is 50% of range
    )
    if changed then
      self.saturation = math.floor((new_saturation_normalized / 100) * 512 + 0.5)
      self:set_param(-1004, self.saturation, false)
    end
    if ImGui.IsItemDeactivatedAfterEdit(ctx) then
      self:set_param(-1004, self.saturation, true)
    end

    -- Tint slider (Storage: 0-384, Display: -180° to +180°, Default: 192 = 0°)
    local tint_degrees = math.floor(self.tint * 0.9375 - 180 + 0.5)
    local changed, new_tint_normalized = draw_slider_row(
      "Tint",
      string.format("%.0f°", tint_degrees),
      HueSlider.draw_hue,
      "##tint",
      ((self.tint / 384) * 360),
      {default = 180, saturation = 75, brightness = 80}
    )
    if changed then
      self.tint = math.floor((new_tint_normalized / 360) * 384 + 0.5)
      self:set_param(-1005, self.tint, false)
    end
    if ImGui.IsItemDeactivatedAfterEdit(ctx) then
      self:set_param(-1005, self.tint, true)
    end

    ImGui.Dummy(ctx, 0, 10)

    -- Toggles
    ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
    ImGui.Text(ctx, "OPTIONS")
    ImGui.PopFont(ctx)
    ImGui.Dummy(ctx, 0, 6)

    local dl = ImGui.GetWindowDrawList(ctx)
    local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)

    if Checkbox.draw_at_cursor(ctx, "Custom color track names", self.custom_track_names, nil, "custom_track_names") then
      self.custom_track_names = not self.custom_track_names
      -- TODO: Set 'glb_track_label_color' parameter
    end
    ImGui.NewLine(ctx)

    ImGui.Dummy(ctx, 0, 4)

    if Checkbox.draw_at_cursor(ctx, "Also affect project custom colors", self.affect_project_colors, nil, "affect_project_colors") then
      self.affect_project_colors = not self.affect_project_colors
      self:set_param(-1006, self.affect_project_colors and 1 or 0, true)
    end
    ImGui.NewLine(ctx)

    ImGui.Dummy(ctx, 0, 10)

    -- Reset button (centered)
    local button_w = 180
    local button_x = (avail_w - button_w - 24) / 2
    ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + button_x)
    if ImGui.Button(ctx, "Reset All Color Controls", button_w, 28) then
      self:reset_color_controls()
    end

    ImGui.Unindent(ctx, 12)
    ImGui.Dummy(ctx, 0, 8)
    ImGui.EndChild(ctx)
  end
  ImGui.PopStyleColor(ctx)
end

return M
