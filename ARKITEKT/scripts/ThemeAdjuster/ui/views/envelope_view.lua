-- @noindex
-- ThemeAdjuster/ui/views/envelope_view.lua
-- Envelope configuration tab

local ImGui = require 'imgui' '0.10'
local Spinner = require('rearkitekt.gui.widgets.primitives.spinner')
local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}
local EnvelopeView = {}
EnvelopeView.__index = EnvelopeView

-- Spinner value lists
local SPINNER_VALUES = {
  env_vol_size = {'MIN', 40, 60, 80, 100, 120},
  env_pan_size = {'MIN', 40, 60, 80, 100},
  env_labelSize = {'MIN', 50, 75, 100, 125, 150},
  env_MeterSize = {4, 10, 20, 40, 80},
  env_type = {'NORMAL', 'COMPACT', 'TINY'},
  env_min_height = {24, 40, 60, 80, 100, 120},
}

function M.new(State, Config, settings)
  local self = setmetatable({
    State = State,
    Config = Config,
    settings = settings,

    -- Spinner indices (1-based)
    env_vol_size_idx = 1,
    env_pan_size_idx = 1,
    env_labelSize_idx = 1,
    env_MeterSize_idx = 1,
    env_type_idx = 1,
    env_min_height_idx = 1,

    -- Active layout (A/B/C)
    active_layout = 'A',

    -- Toggles
    show_env_volume = true,
    show_env_pan = true,
    show_env_values = true,
    show_env_mod_values = false,
    show_env_fader = true,
    env_hide_tcp_env = false,
  }, EnvelopeView)

  -- Load initial values from theme
  self:load_from_theme()

  return self
end

function EnvelopeView:load_from_theme()
  -- TODO: Load spinner indices and toggle states from theme parameters
  -- For now, keep defaults
end

function EnvelopeView:get_param_index(param_name)
  -- Get parameter index from theme layout
  -- Returns nil if not found
  local ok, idx = pcall(reaper.ThemeLayout_GetParameter, param_name)
  if ok and type(idx) == "number" then
    return idx
  end
  return nil
end

function EnvelopeView:set_param(param, value, save)
  save = save == nil and true or save
  local ok = pcall(reaper.ThemeLayout_SetParameter, param, value, save)
  if ok and save then
    pcall(reaper.ThemeLayout_RefreshAll)
  end
  return ok
end

function EnvelopeView:draw(ctx, shell_state)
  local avail_w = ImGui.GetContentRegionAvail(ctx)

  -- Title
  ImGui.PushFont(ctx, shell_state.fonts.bold, 16)
  ImGui.Text(ctx, "Envelope Panel")
  ImGui.PopFont(ctx)

  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#999999"))
  ImGui.Text(ctx, "Configure envelope appearance and element visibility")
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 8)

  -- Single scrollable content area
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#1A1A1A"))
  if ImGui.BeginChild(ctx, "env_content", avail_w, 0, 1) then
    ImGui.Dummy(ctx, 0, 4)

    ImGui.Indent(ctx, 8)

    -- Layout & Size Section
    ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
    ImGui.Text(ctx, "ACTIVE LAYOUT & SIZE")
    ImGui.PopFont(ctx)
    ImGui.Dummy(ctx, 0, 4)

    -- Active Layout
    ImGui.AlignTextToFramePadding(ctx)
    ImGui.Text(ctx, "Active Layout")
    ImGui.SameLine(ctx, 120)

    for _, layout in ipairs({'A', 'B', 'C'}) do
      local is_active = (self.active_layout == layout)
      if is_active then
        ImGui.PushStyleColor(ctx, ImGui.Col_Button, hexrgb("#2D4A37"))
        ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, hexrgb("#3A5F48"))
        ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, hexrgb("#47724F"))
      end
      if ImGui.Button(ctx, layout, 50, 24) then
        self.active_layout = layout
        -- TODO: Apply layout
      end
      if is_active then
        ImGui.PopStyleColor(ctx, 3)
      end
      ImGui.SameLine(ctx, 0, 6)
    end
    ImGui.NewLine(ctx)

    ImGui.Dummy(ctx, 0, 4)

    -- Apply Size
    ImGui.AlignTextToFramePadding(ctx)
    ImGui.Text(ctx, "Apply Size")
    ImGui.SameLine(ctx, 120)

    for _, size in ipairs({'100%', '150%', '200%'}) do
      if ImGui.Button(ctx, size, 70, 24) then
        -- TODO: Apply size
      end
      ImGui.SameLine(ctx, 0, 6)
    end
    ImGui.NewLine(ctx)

    ImGui.Dummy(ctx, 0, 16)

    -- Sizing Controls Section
    ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
    ImGui.Text(ctx, "SIZING CONTROLS")
    ImGui.PopFont(ctx)
    ImGui.Dummy(ctx, 0, 4)

    -- Calculate column widths
    local col_count = 2
    local col_w = (avail_w - 32) / col_count
    local label_w = 100  -- Fixed label width for consistency

    local spinner_w = col_w - label_w - 16  -- Remaining for spinner

    -- Helper function to draw properly aligned spinner row
    local function draw_spinner_row(label, id, idx, values)
      -- Label (right-aligned in label column)
      local label_text_w = ImGui.CalcTextSize(ctx, label)
      ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + label_w - label_text_w)
      ImGui.AlignTextToFramePadding(ctx)
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
      ImGui.Text(ctx, label)
      ImGui.PopStyleColor(ctx)

      -- Spinner (fixed position, fixed width)
      ImGui.SameLine(ctx, 0, 8)
      local changed, new_idx = Spinner.draw(ctx, id, idx, values, {w = spinner_w, h = 24})


      ImGui.Dummy(ctx, 0, 2)
      return changed, new_idx
    end

    -- Column 1: Element Sizing
    ImGui.BeginGroup(ctx)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
    ImGui.Text(ctx, "Element Sizing")
    ImGui.PopStyleColor(ctx)
    ImGui.Dummy(ctx, 0, 3)

    local changed, new_idx = draw_spinner_row("Label Size", "env_labelSize", self.env_labelSize_idx, SPINNER_VALUES.env_labelSize)
    if changed then self.env_labelSize_idx = new_idx end

    changed, new_idx = draw_spinner_row("Volume", "env_vol_size", self.env_vol_size_idx, SPINNER_VALUES.env_vol_size)
    if changed then self.env_vol_size_idx = new_idx end

    changed, new_idx = draw_spinner_row("Pan", "env_pan_size", self.env_pan_size_idx, SPINNER_VALUES.env_pan_size)
    if changed then self.env_pan_size_idx = new_idx end

    ImGui.EndGroup(ctx)

    -- Column 2: Display Options
    ImGui.SameLine(ctx, col_w + 8)
    ImGui.BeginGroup(ctx)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
    ImGui.Text(ctx, "Display Options")
    ImGui.PopStyleColor(ctx)
    ImGui.Dummy(ctx, 0, 3)

    changed, new_idx = draw_spinner_row("Meter Size", "env_MeterSize", self.env_MeterSize_idx, SPINNER_VALUES.env_MeterSize)
    if changed then self.env_MeterSize_idx = new_idx end

    changed, new_idx = draw_spinner_row("Env Type", "env_type", self.env_type_idx, SPINNER_VALUES.env_type)
    if changed then self.env_type_idx = new_idx end

    changed, new_idx = draw_spinner_row("Min Height", "env_min_height", self.env_min_height_idx, SPINNER_VALUES.env_min_height)
    if changed then self.env_min_height_idx = new_idx end

    ImGui.EndGroup(ctx)

    ImGui.Dummy(ctx, 0, 16)

    -- Element Visibility Section
    ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
    ImGui.Text(ctx, "ELEMENT VISIBILITY")
    ImGui.PopFont(ctx)
    ImGui.Dummy(ctx, 0, 4)

    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#999999"))
    ImGui.Text(ctx, "Control which envelope elements are visible")
    ImGui.PopStyleColor(ctx)
    ImGui.Dummy(ctx, 0, 2)

    -- Helper function for checkbox rows
    local function draw_checkbox_row(label, checked)
      local result = checked
      if ImGui.Checkbox(ctx, label, checked) then
        result = not checked
      end
      ImGui.Dummy(ctx, 0, 3)
      return result
    end

    -- Two columns layout for checkboxes
    local col_w = (avail_w - 32) / 2

    ImGui.BeginGroup(ctx)

    -- Left column
    self.show_env_volume = draw_checkbox_row("Show volume control", self.show_env_volume)
    self.show_env_pan = draw_checkbox_row("Show pan control", self.show_env_pan)
    self.show_env_fader = draw_checkbox_row("Show fader", self.show_env_fader)

    ImGui.EndGroup(ctx)

    ImGui.SameLine(ctx, col_w + 8)

    ImGui.BeginGroup(ctx)

    -- Right column
    self.show_env_values = draw_checkbox_row("Show values", self.show_env_values)
    self.show_env_mod_values = draw_checkbox_row("Show modulation values", self.show_env_mod_values)
    self.env_hide_tcp_env = draw_checkbox_row("Hide TCP envelope controls", self.env_hide_tcp_env)

    ImGui.EndGroup(ctx)

    ImGui.Unindent(ctx, 8)
    ImGui.Dummy(ctx, 0, 2)
    ImGui.EndChild(ctx)
  end
  ImGui.PopStyleColor(ctx)
end

return M
