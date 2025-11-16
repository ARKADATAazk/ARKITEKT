-- @noindex
-- ThemeAdjuster/ui/views/tcp_view.lua
-- TCP (Track Control Panel) configuration tab

local ImGui = require 'imgui' '0.10'
local Spinner = require('rearkitekt.gui.widgets.primitives.spinner')
local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}
local TCPView = {}
TCPView.__index = TCPView

-- Spinner value lists (from Default 6.0)
local SPINNER_VALUES = {
  tcp_indent = {'NONE', '1/8', '1/4', '1/2', 1, 2, 'MAX'},
  tcp_control_align = {'FOLDER INDENT', 'ALIGNED', 'EXTEND NAME'},
  tcp_LabelSize = {'AUTO', 20, 50, 80, 110, 140, 170},
  tcp_vol_size = {'KNOB', 40, 70, 100, 130, 160, 190},
  tcp_MeterSize = {4, 10, 20, 40, 80, 160, 320},
  tcp_InputSize = {'MIN', 25, 40, 60, 90, 150, 200},
  tcp_MeterLoc = {'LEFT', 'RIGHT', 'LEFT IF ARMED'},
  tcp_sepSends = {'OFF', 'ON'},
}

-- Visibility elements with bitflags
local VISIBILITY_ELEMENTS = {
  {id = 'tcp_Record_Arm', label = 'Record Arm'},
  {id = 'tcp_Monitor', label = 'Monitor'},
  {id = 'tcp_Track_Name', label = 'Track Name'},
  {id = 'tcp_Volume', label = 'Volume'},
  {id = 'tcp_Routing', label = 'Routing'},
  {id = 'tcp_Effects', label = 'Effects'},
  {id = 'tcp_Envelope', label = 'Envelope'},
  {id = 'tcp_Pan_&_Width', label = 'Pan & Width'},
  {id = 'tcp_Record_Mode', label = 'Record Mode'},
  {id = 'tcp_Input', label = 'Input'},
  {id = 'tcp_Values', label = 'Values'},
  {id = 'tcp_Meter_Values', label = 'Meter Values'},
}

-- Bitflag column definitions
local VISIBILITY_COLUMNS = {
  {bit = 1, label = 'IF MIXER\nVISIBLE'},
  {bit = 2, label = 'IF TRACK NOT\nSELECTED'},
  {bit = 4, label = 'IF TRACK NOT\nARMED'},
  {bit = 8, label = 'ALWAYS\nHIDE'},
}

function M.new(State, Config, settings)
  local self = setmetatable({
    State = State,
    Config = Config,
    settings = settings,

    -- Spinner indices (1-based)
    tcp_indent_idx = 1,
    tcp_control_align_idx = 1,
    tcp_LabelSize_idx = 1,
    tcp_vol_size_idx = 1,
    tcp_MeterSize_idx = 1,
    tcp_InputSize_idx = 1,
    tcp_MeterLoc_idx = 1,
    tcp_sepSends_idx = 1,

    -- Active layout (A/B/C)
    active_layout = 'A',

    -- Visibility values (loaded from theme)
    visibility = {},
  }, TCPView)

  -- Initialize visibility values
  for _, elem in ipairs(VISIBILITY_ELEMENTS) do
    self.visibility[elem.id] = 0
  end

  -- Load initial values from theme
  self:load_from_theme()

  return self
end

function TCPView:load_from_theme()
  -- TODO: Load spinner indices from theme parameters
  -- For now, keep defaults
end

function TCPView:get_param_index(param_name)
  -- Get parameter index from theme layout
  -- Returns nil if not found
  local ok, idx = pcall(reaper.ThemeLayout_GetParameter, param_name)
  if ok and type(idx) == "number" then
    return idx
  end
  return nil
end

function TCPView:set_param(param, value, save)
  save = save == nil and true or save
  local ok = pcall(reaper.ThemeLayout_SetParameter, param, value, save)
  if ok and save then
    pcall(reaper.ThemeLayout_RefreshAll)
  end
  return ok
end

function TCPView:toggle_bitflag(param_name, bit)
  -- Get current value
  local current = self.visibility[param_name] or 0
  -- XOR toggle
  local new_value = current ~ bit
  self.visibility[param_name] = new_value
  -- TODO: Set parameter in theme
  -- self:set_param(param_name, new_value, true)
end

function TCPView:draw(ctx, shell_state)
  -- Title
  ImGui.PushFont(ctx, shell_state.fonts.bold, 14)
  ImGui.Text(ctx, "Track Control Panel (TCP)")
  ImGui.PopFont(ctx)

  ImGui.Dummy(ctx, 0, 10)

  -- Spinners section
  ImGui.SeparatorText(ctx, "Layout Settings")

  -- Folder Indent
  ImGui.Text(ctx, "Folder Indent")
  ImGui.SameLine(ctx, 200)
  local changed, new_idx = Spinner.draw(ctx, "tcp_indent", self.tcp_indent_idx, SPINNER_VALUES.tcp_indent, {w = 200})
  if changed then
    self.tcp_indent_idx = new_idx
    -- TODO: Set parameter
  end

  -- Align Controls
  ImGui.Text(ctx, "Align Controls")
  ImGui.SameLine(ctx, 200)
  local changed, new_idx = Spinner.draw(ctx, "tcp_control_align", self.tcp_control_align_idx, SPINNER_VALUES.tcp_control_align, {w = 200})
  if changed then
    self.tcp_control_align_idx = new_idx
  end

  -- Name Size
  ImGui.Text(ctx, "Name Size")
  ImGui.SameLine(ctx, 200)
  local changed, new_idx = Spinner.draw(ctx, "tcp_LabelSize", self.tcp_LabelSize_idx, SPINNER_VALUES.tcp_LabelSize, {w = 200})
  if changed then
    self.tcp_LabelSize_idx = new_idx
  end

  -- Volume Size
  ImGui.Text(ctx, "Volume Size")
  ImGui.SameLine(ctx, 200)
  local changed, new_idx = Spinner.draw(ctx, "tcp_vol_size", self.tcp_vol_size_idx, SPINNER_VALUES.tcp_vol_size, {w = 200})
  if changed then
    self.tcp_vol_size_idx = new_idx
  end

  -- Meter Size
  ImGui.Text(ctx, "Meter Size")
  ImGui.SameLine(ctx, 200)
  local changed, new_idx = Spinner.draw(ctx, "tcp_MeterSize", self.tcp_MeterSize_idx, SPINNER_VALUES.tcp_MeterSize, {w = 200})
  if changed then
    self.tcp_MeterSize_idx = new_idx
  end

  -- Input Size
  ImGui.Text(ctx, "Input Size")
  ImGui.SameLine(ctx, 200)
  local changed, new_idx = Spinner.draw(ctx, "tcp_InputSize", self.tcp_InputSize_idx, SPINNER_VALUES.tcp_InputSize, {w = 200})
  if changed then
    self.tcp_InputSize_idx = new_idx
  end

  -- Meter Location
  ImGui.Text(ctx, "Meter Location")
  ImGui.SameLine(ctx, 200)
  local changed, new_idx = Spinner.draw(ctx, "tcp_MeterLoc", self.tcp_MeterLoc_idx, SPINNER_VALUES.tcp_MeterLoc, {w = 200})
  if changed then
    self.tcp_MeterLoc_idx = new_idx
  end

  -- Sends List
  ImGui.Text(ctx, "Sends List")
  ImGui.SameLine(ctx, 200)
  local changed, new_idx = Spinner.draw(ctx, "tcp_sepSends", self.tcp_sepSends_idx, SPINNER_VALUES.tcp_sepSends, {w = 200})
  if changed then
    self.tcp_sepSends_idx = new_idx
  end

  ImGui.Dummy(ctx, 0, 15)

  -- Layout System
  ImGui.SeparatorText(ctx, "Active Layout")

  -- A/B/C buttons
  ImGui.Text(ctx, "Active Layout:")
  ImGui.SameLine(ctx)

  for _, layout in ipairs({'A', 'B', 'C'}) do
    if self.active_layout == layout then
      ImGui.PushStyleColor(ctx, ImGui.Col_Button, hexrgb("#2D4A37"))
    end
    if ImGui.Button(ctx, layout, 40, 0) then
      self.active_layout = layout
      -- TODO: Apply layout
    end
    if self.active_layout == layout then
      ImGui.PopStyleColor(ctx)
    end
    ImGui.SameLine(ctx)
  end
  ImGui.NewLine(ctx)

  ImGui.Dummy(ctx, 0, 10)

  -- Apply Size buttons
  ImGui.Text(ctx, "Apply Size:")
  ImGui.SameLine(ctx)

  for _, size in ipairs({'100%', '150%', '200%'}) do
    if ImGui.Button(ctx, size, 60, 0) then
      -- TODO: Apply size
    end
    ImGui.SameLine(ctx)
  end
  ImGui.NewLine(ctx)

  ImGui.Dummy(ctx, 0, 15)

  -- Visibility Table
  ImGui.SeparatorText(ctx, "Element Visibility")

  if ImGui.BeginTable(ctx, "tcp_visibility", 5, ImGui.TableFlags_Borders | ImGui.TableFlags_RowBg) then
    -- Setup columns
    ImGui.TableSetupColumn(ctx, "Element", ImGui.TableColumnFlags_WidthFixed, 150)
    for _, col in ipairs(VISIBILITY_COLUMNS) do
      ImGui.TableSetupColumn(ctx, col.label, ImGui.TableColumnFlags_WidthFixed, 80)
    end
    ImGui.TableHeadersRow(ctx)

    -- Rows
    for _, elem in ipairs(VISIBILITY_ELEMENTS) do
      ImGui.TableNextRow(ctx)

      -- Element name
      ImGui.TableSetColumnIndex(ctx, 0)
      ImGui.Text(ctx, elem.label)

      -- Checkboxes for each condition
      for col_idx, col in ipairs(VISIBILITY_COLUMNS) do
        ImGui.TableSetColumnIndex(ctx, col_idx)

        local current_value = self.visibility[elem.id] or 0
        local is_checked = (current_value & col.bit) ~= 0

        ImGui.PushID(ctx, elem.id .. "_" .. col.bit)
        if ImGui.Checkbox(ctx, "##check", is_checked) then
          self:toggle_bitflag(elem.id, col.bit)
        end
        ImGui.PopID(ctx)
      end
    end

    ImGui.EndTable(ctx)
  end
end

return M
