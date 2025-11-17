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
  tcp_fxparms_size = {'MIN', 50, 75, 100, 125, 150},
  tcp_recmon_size = {'MIN', 20, 30, 40, 50},
  tcp_pan_size = {'MIN', 40, 60, 80, 100},
  tcp_width_size = {'MIN', 40, 60, 80, 100},
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
    tcp_fxparms_size_idx = 1,
    tcp_recmon_size_idx = 1,
    tcp_pan_size_idx = 1,
    tcp_width_size_idx = 1,

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
  local avail_w = ImGui.GetContentRegionAvail(ctx)

  -- Title
  ImGui.PushFont(ctx, shell_state.fonts.bold, 16)
  ImGui.Text(ctx, "Track Control Panel")
  ImGui.PopFont(ctx)

  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#999999"))
  ImGui.Text(ctx, "Configure track appearance and element visibility")
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 12)

  -- Layout Settings Section
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#1A1A1A"))
  if ImGui.BeginChild(ctx, "tcp_layout_section", avail_w, 220, 1) then
    ImGui.Dummy(ctx, 0, 2)

    ImGui.Indent(ctx, 8)
    ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
    ImGui.Text(ctx, "LAYOUT SETTINGS")
    ImGui.PopFont(ctx)
    ImGui.Dummy(ctx, 0, 2)

    -- Calculate column widths
    local col_count = 3
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

    -- Column 1: Layout
    ImGui.BeginGroup(ctx)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
    ImGui.Text(ctx, "Layout")
    ImGui.PopStyleColor(ctx)
    ImGui.Dummy(ctx, 0, 3)

    local changed, new_idx = draw_spinner_row("Indent", "tcp_indent", self.tcp_indent_idx, SPINNER_VALUES.tcp_indent)
    if changed then self.tcp_indent_idx = new_idx end

    changed, new_idx = draw_spinner_row("Alignment", "tcp_control_align", self.tcp_control_align_idx, SPINNER_VALUES.tcp_control_align)
    if changed then self.tcp_control_align_idx = new_idx end

    changed, new_idx = draw_spinner_row("Meter Loc", "tcp_MeterLoc", self.tcp_MeterLoc_idx, SPINNER_VALUES.tcp_MeterLoc)
    if changed then self.tcp_MeterLoc_idx = new_idx end

    changed, new_idx = draw_spinner_row("Send List", "tcp_sepSends", self.tcp_sepSends_idx, SPINNER_VALUES.tcp_sepSends)
    if changed then self.tcp_sepSends_idx = new_idx end

    ImGui.EndGroup(ctx)

    -- Column 2: Element Sizing
    ImGui.SameLine(ctx, col_w + 8)
    ImGui.BeginGroup(ctx)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
    ImGui.Text(ctx, "Element Sizing")
    ImGui.PopStyleColor(ctx)
    ImGui.Dummy(ctx, 0, 3)

    changed, new_idx = draw_spinner_row("Name", "tcp_LabelSize", self.tcp_LabelSize_idx, SPINNER_VALUES.tcp_LabelSize)
    if changed then self.tcp_LabelSize_idx = new_idx end

    changed, new_idx = draw_spinner_row("Volume", "tcp_vol_size", self.tcp_vol_size_idx, SPINNER_VALUES.tcp_vol_size)
    if changed then self.tcp_vol_size_idx = new_idx end

    changed, new_idx = draw_spinner_row("Meter", "tcp_MeterSize", self.tcp_MeterSize_idx, SPINNER_VALUES.tcp_MeterSize)
    if changed then self.tcp_MeterSize_idx = new_idx end

    changed, new_idx = draw_spinner_row("Input", "tcp_InputSize", self.tcp_InputSize_idx, SPINNER_VALUES.tcp_InputSize)
    if changed then self.tcp_InputSize_idx = new_idx end

    ImGui.EndGroup(ctx)

    -- Column 3: Control Sizing
    ImGui.SameLine(ctx, (col_w * 2) + 8)
    ImGui.BeginGroup(ctx)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
    ImGui.Text(ctx, "Control Sizing")
    ImGui.PopStyleColor(ctx)
    ImGui.Dummy(ctx, 0, 3)

    changed, new_idx = draw_spinner_row("FX Parms", "tcp_fxparms_size", self.tcp_fxparms_size_idx, SPINNER_VALUES.tcp_fxparms_size)
    if changed then self.tcp_fxparms_size_idx = new_idx end

    changed, new_idx = draw_spinner_row("Rec Mon", "tcp_recmon_size", self.tcp_recmon_size_idx, SPINNER_VALUES.tcp_recmon_size)
    if changed then self.tcp_recmon_size_idx = new_idx end

    changed, new_idx = draw_spinner_row("Pan", "tcp_pan_size", self.tcp_pan_size_idx, SPINNER_VALUES.tcp_pan_size)
    if changed then self.tcp_pan_size_idx = new_idx end

    changed, new_idx = draw_spinner_row("Width", "tcp_width_size", self.tcp_width_size_idx, SPINNER_VALUES.tcp_width_size)
    if changed then self.tcp_width_size_idx = new_idx end

    ImGui.EndGroup(ctx)

    ImGui.Unindent(ctx, 8)
    ImGui.Dummy(ctx, 0, 2)
    ImGui.EndChild(ctx)
  end
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 10)

  -- Layout & Size Section
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#1A1A1A"))
  if ImGui.BeginChild(ctx, "tcp_layout_buttons", avail_w, 100, 1) then
    ImGui.Dummy(ctx, 0, 2)

    ImGui.Indent(ctx, 8)
    ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
    ImGui.Text(ctx, "ACTIVE LAYOUT & SIZE")
    ImGui.PopFont(ctx)
    ImGui.Dummy(ctx, 0, 2)

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

    ImGui.Unindent(ctx, 8)
    ImGui.Dummy(ctx, 0, 2)
    ImGui.EndChild(ctx)
  end
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 10)

  -- Visibility Table Section
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#1A1A1A"))
  if ImGui.BeginChild(ctx, "tcp_visibility_section", avail_w, 0, 1) then
    ImGui.Dummy(ctx, 0, 2)

    ImGui.Indent(ctx, 8)
    ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
    ImGui.Text(ctx, "ELEMENT VISIBILITY")
    ImGui.PopFont(ctx)
    ImGui.Dummy(ctx, 0, 3)

    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#999999"))
    ImGui.Text(ctx, "Control when track elements are visible")
    ImGui.PopStyleColor(ctx)
    ImGui.Dummy(ctx, 0, 2)

    -- Table
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_CellPadding, 6, 4)
    if ImGui.BeginTable(ctx, "tcp_visibility", 5, ImGui.TableFlags_Borders | ImGui.TableFlags_RowBg | ImGui.TableFlags_ScrollY, avail_w - 16, 300) then
      -- Setup columns
      ImGui.TableSetupColumn(ctx, "Element", ImGui.TableColumnFlags_WidthFixed, 130)
      for _, col in ipairs(VISIBILITY_COLUMNS) do
        ImGui.TableSetupColumn(ctx, col.label, ImGui.TableColumnFlags_WidthFixed, 85)
      end
      ImGui.TableSetupScrollFreeze(ctx, 0, 1)
      ImGui.TableHeadersRow(ctx)

      -- Rows
      for _, elem in ipairs(VISIBILITY_ELEMENTS) do
        ImGui.TableNextRow(ctx)

        -- Element name
        ImGui.TableSetColumnIndex(ctx, 0)
        ImGui.AlignTextToFramePadding(ctx)
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
    ImGui.PopStyleVar(ctx)

    ImGui.Unindent(ctx, 8)
    ImGui.Dummy(ctx, 0, 2)
    ImGui.EndChild(ctx)
  end
  ImGui.PopStyleColor(ctx)
end

return M
