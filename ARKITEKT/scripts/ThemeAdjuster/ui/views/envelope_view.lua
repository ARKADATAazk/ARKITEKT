-- @noindex
-- ThemeAdjuster/ui/views/envelope_view.lua
-- Envelope configuration tab

local ImGui = require 'imgui' '0.10'
local Spinner = require('arkitekt.gui.widgets.primitives.spinner')
local Checkbox = require('arkitekt.gui.widgets.primitives.checkbox')
local Button = require('arkitekt.gui.widgets.primitives.button')
local Background = require('arkitekt.gui.widgets.containers.panel.background')
local Style = require('arkitekt.gui.style.defaults')
local ThemeParams = require('ThemeAdjuster.core.theme_params')
local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb

local PC = Style.PANEL_COLORS  -- Panel colors including pattern defaults

local M = {}
local EnvelopeView = {}
EnvelopeView.__index = EnvelopeView

-- Spinner value lists (from Default 6.0)
local SPINNER_VALUES = {
  envcp_labelSize = {'AUTO', 20, 50, 80, 110, 140, 170},
  envcp_fader_size = {'KNOB', 40, 70, 100, 130, 160, 190},
}

function M.new(State, Config, settings)
  local self = setmetatable({
    State = State,
    Config = Config,
    settings = settings,

    -- Spinner indices (1-based)
    envcp_labelSize_idx = 1,
    envcp_fader_size_idx = 1,

    -- Toggles
    envcp_folder_indent = false,
  }, EnvelopeView)

  -- Load initial values from theme
  self:load_from_theme()

  return self
end

function EnvelopeView:load_from_theme()
  -- Load spinner values from theme parameters
  -- NOTE: REAPER parameter values ARE already 1-based spinner indices
  local spinners = {'envcp_labelSize', 'envcp_fader_size'}

  for _, param_name in ipairs(spinners) do
    local param = ThemeParams.get_param(param_name)
    if param then
      local idx_field = param_name .. '_idx'
      -- REAPER value is already a 1-based index - use it directly
      self[idx_field] = param.value
    end
  end

  -- Load folder indent toggle
  local param = ThemeParams.get_param('envcp_folder_indent')
  if param then
    self.envcp_folder_indent = (param.value ~= 0)
  end
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
    -- Draw background pattern (using panel defaults)
    local child_x, child_y = ImGui.GetWindowPos(ctx)
    local child_w, child_h = ImGui.GetWindowSize(ctx)
    local dl = ImGui.GetWindowDrawList(ctx)
    local pattern_cfg = {
      enabled = true,
      primary = {type = 'grid', spacing = 50, color = PC.pattern_primary, line_thickness = 1.5},
      secondary = {enabled = true, type = 'grid', spacing = 5, color = PC.pattern_secondary, line_thickness = 0.5},
    }
    Background.draw(ctx, dl, child_x, child_y, child_x + child_w, child_y + child_h, pattern_cfg)

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
      if Button.draw_at_cursor(ctx, {
        label = layout,
        width = 50,
        height = 24,
        is_toggled = is_active,
        preset_name = "BUTTON_TOGGLE_WHITE",
        on_click = function()
          self.active_layout = layout
          ThemeParams.set_active_layout('envcp', layout)
          self:load_from_theme()
        end
      }, "env_layout_" .. layout) then
      end
      ImGui.SameLine(ctx, 0, 6)
    end
    ImGui.NewLine(ctx)

    ImGui.Dummy(ctx, 0, 4)

    -- Apply Size (Envelope only has one layout, no A/B/C)
    ImGui.AlignTextToFramePadding(ctx)
    ImGui.Text(ctx, "Apply Size")
    ImGui.SameLine(ctx, 120)

    for _, size in ipairs({'100%', '150%', '200%'}) do
      if Button.draw_at_cursor(ctx, {
        label = size,
        width = 70,
        height = 24,
        on_click = function()
          local scale = (size == '100%') and '' or (size .. '_')
          ThemeParams.apply_layout_to_tracks('envcp', 'A', scale)
        end
      }, "env_size_" .. size) then
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

    local changed, new_idx = draw_spinner_row("Name Size", "envcp_labelSize", self.envcp_labelSize_idx, SPINNER_VALUES.envcp_labelSize)
    if changed then
      self.envcp_labelSize_idx = new_idx
      ThemeParams.set_param('envcp_labelSize', new_idx, true)
    end

    changed, new_idx = draw_spinner_row("Fader Size", "envcp_fader_size", self.envcp_fader_size_idx, SPINNER_VALUES.envcp_fader_size)
    if changed then
      self.envcp_fader_size_idx = new_idx
      ThemeParams.set_param('envcp_fader_size', new_idx, true)
    end

    ImGui.EndGroup(ctx)

    -- Column 2: Options
    ImGui.SameLine(ctx, col_w + 8)
    ImGui.BeginGroup(ctx)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
    ImGui.Text(ctx, "Options")
    ImGui.PopStyleColor(ctx)
    ImGui.Dummy(ctx, 0, 3)

    if Checkbox.draw_at_cursor(ctx, "Match folder indent", self.envcp_folder_indent, nil, "envcp_folder_indent") then
      self.envcp_folder_indent = not self.envcp_folder_indent
      ThemeParams.set_param('envcp_folder_indent', self.envcp_folder_indent and 1 or 0, true)
    end

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
    local function draw_checkbox_row(label, checked, id)
      local result = checked
      if Checkbox.draw_at_cursor(ctx, label, checked, nil, id) then
        result = not checked
      end
      ImGui.NewLine(ctx)
      ImGui.Dummy(ctx, 0, 3)
      return result
    end

    -- Two columns layout for checkboxes
    local col_w = (avail_w - 32) / 2

    ImGui.BeginGroup(ctx)

    -- Left column
    self.show_env_volume = draw_checkbox_row("Show volume control", self.show_env_volume, "env_volume")
    self.show_env_pan = draw_checkbox_row("Show pan control", self.show_env_pan, "env_pan")
    self.show_env_fader = draw_checkbox_row("Show fader", self.show_env_fader, "env_fader")

    ImGui.EndGroup(ctx)

    ImGui.SameLine(ctx, col_w + 8)

    ImGui.BeginGroup(ctx)

    -- Right column
    self.show_env_values = draw_checkbox_row("Show values", self.show_env_values, "env_values")
    self.show_env_mod_values = draw_checkbox_row("Show modulation values", self.show_env_mod_values, "env_mod_values")
    self.env_hide_tcp_env = draw_checkbox_row("Hide TCP envelope controls", self.env_hide_tcp_env, "env_hide_tcp")

    ImGui.EndGroup(ctx)

    ImGui.Unindent(ctx, 8)
    ImGui.Dummy(ctx, 0, 2)
    ImGui.EndChild(ctx)
  end
  ImGui.PopStyleColor(ctx)
end

return M
