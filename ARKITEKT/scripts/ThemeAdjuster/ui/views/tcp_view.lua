-- @noindex
-- ThemeAdjuster/ui/views/tcp_view.lua
-- TCP (Track Control Panel) configuration tab

local ImGui = require 'imgui' '0.10'
local Spinner = require('rearkitekt.gui.widgets.primitives.spinner')
local Button = require('rearkitekt.gui.widgets.primitives.button')
local Background = require('rearkitekt.gui.widgets.containers.panel.background')
local Style = require('rearkitekt.gui.style.defaults')
local ThemeParams = require('ThemeAdjuster.core.theme_params')
local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb

local PC = Style.PANEL_COLORS  -- Panel colors including pattern defaults

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

    -- Active layout (A/B/C) - sync with ThemeParams
    active_layout = ThemeParams.get_active_layout('tcp'),

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
  -- Load spinner values from current layout's theme parameters
  local spinners = {
    'tcp_LabelSize', 'tcp_vol_size', 'tcp_MeterSize',
    'tcp_InputSize', 'tcp_MeterLoc', 'tcp_sepSends',
    'tcp_fxparms_size', 'tcp_recmon_size', 'tcp_pan_size', 'tcp_width_size'
  }

  for _, param_name in ipairs(spinners) do
    local param = ThemeParams.get_param(param_name)
    if param then
      local idx_field = param_name .. '_idx'
      self[idx_field] = ThemeParams.get_spinner_index(param_name, param.value)
    end
  end

  -- Load global parameters (affect all layouts)
  local global_params = {'tcp_indent', 'tcp_control_align'}
  for _, param_name in ipairs(global_params) do
    local param = ThemeParams.get_param(param_name)
    if param then
      local idx_field = param_name .. '_idx'
      self[idx_field] = ThemeParams.get_spinner_index(param_name, param.value)
    end
  end

  -- Load visibility flags
  for _, elem in ipairs(VISIBILITY_ELEMENTS) do
    local param = ThemeParams.get_param(elem.id)
    if param then
      self.visibility[elem.id] = param.value
    end
  end
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

  ImGui.Dummy(ctx, 0, 8)

  -- Single scrollable content area
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#1A1A1A"))
  if ImGui.BeginChild(ctx, "tcp_content", avail_w, 0, 1) then
    -- Draw background pattern (using panel defaults)
    local child_x, child_y = ImGui.GetWindowPos(ctx)
    local child_w, child_h = ImGui.GetWindowSize(ctx)
    local dl = ImGui.GetWindowDrawList(ctx)
    local pattern_cfg = {
      enabled = true,
      primary = {type = 'grid', spacing = 50, color = PC.pattern_primary, line_thickness = 1.5},
      secondary = {enabled = true, type = 'grid', spacing = 5, color = PC.pattern_secondary, line_thickness = 0.5},
    }
    Background.draw(dl, child_x, child_y, child_x + child_w, child_y + child_h, pattern_cfg)

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
          -- Update local and global active layout
          self.active_layout = layout
          ThemeParams.set_active_layout('tcp', layout)
          -- Reload all parameters from new layout
          self:load_from_theme()
        end
      }, "tcp_layout_" .. layout) then
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
      if Button.draw_at_cursor(ctx, {
        label = size,
        width = 70,
        height = 24,
        on_click = function()
          -- Apply layout to selected tracks
          local scale = (size == '100%') and '' or (size .. '_')
          ThemeParams.apply_layout_to_tracks('tcp', self.active_layout, scale)
        end
      }, "tcp_size_" .. size) then
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
    if changed then
      self.tcp_indent_idx = new_idx
      local value = ThemeParams.get_spinner_value('tcp_indent', new_idx)
      ThemeParams.set_param('tcp_indent', value, true)
    end

    changed, new_idx = draw_spinner_row("Alignment", "tcp_control_align", self.tcp_control_align_idx, SPINNER_VALUES.tcp_control_align)
    if changed then
      self.tcp_control_align_idx = new_idx
      local value = ThemeParams.get_spinner_value('tcp_control_align', new_idx)
      ThemeParams.set_param('tcp_control_align', value, true)
    end

    changed, new_idx = draw_spinner_row("Meter Loc", "tcp_MeterLoc", self.tcp_MeterLoc_idx, SPINNER_VALUES.tcp_MeterLoc)
    if changed then
      self.tcp_MeterLoc_idx = new_idx
      local value = ThemeParams.get_spinner_value('tcp_MeterLoc', new_idx)
      ThemeParams.set_param('tcp_MeterLoc', value, true)
    end

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

    ImGui.Dummy(ctx, 0, 16)

    -- Element Visibility Section
    ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
    ImGui.Text(ctx, "ELEMENT VISIBILITY")
    ImGui.PopFont(ctx)
    ImGui.Dummy(ctx, 0, 4)

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
