-- @noindex
-- ThemeAdjuster/ui/views/tcp_view.lua
-- TCP (Track Control Panel) configuration tab

local ImGui = require 'imgui' '0.10'
local Spinner = require('arkitekt.gui.widgets.primitives.spinner')
local Button = require('arkitekt.gui.widgets.primitives.button')
local Checkbox = require('arkitekt.gui.widgets.primitives.checkbox')
local Background = require('arkitekt.gui.widgets.containers.panel.background')
local Style = require('arkitekt.gui.style.defaults')
local ThemeParams = require('ThemeAdjuster.core.theme_params')
local ThemeMapper = require('ThemeAdjuster.core.theme_mapper')
local ParamDiscovery = require('ThemeAdjuster.core.param_discovery')
local Strings = require('ThemeAdjuster.defs.strings')
local Colors = require('arkitekt.core.colors')
local AdditionalParamTile = require('ThemeAdjuster.ui.grids.renderers.additional_param_tile')
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

-- Visibility elements with bitflags (from Default 6.0)
local VISIBILITY_ELEMENTS = {
  {id = 'tcp_Record_Arm', label = 'RECORD ARM'},
  {id = 'tcp_Monitor', label = 'MONITOR'},
  {id = 'tcp_Track_Name', label = 'TRACK NAME'},
  {id = 'tcp_Volume', label = 'VOLUME'},
  {id = 'tcp_Routing', label = 'ROUTING'},
  {id = 'tcp_Effects', label = 'INSERT FX'},
  {id = 'tcp_Envelope', label = 'ENVELOPE'},
  {id = 'tcp_Pan_&_Width', label = 'PAN & WIDTH'},
  {id = 'tcp_Record_Mode', label = 'RECORD MODE'},
  {id = 'tcp_Input', label = 'INPUT'},
  {id = 'tcp_Values', label = 'LABELS & VALUES'},
  {id = 'tcp_Meter_Values', label = 'METER VALUES'},
}

-- Bitflag column definitions
local VISIBILITY_COLUMNS = {
  {bit = 1, label = 'IF MIXER\nVISIBLE'},
  {bit = 2, label = 'IF TRACK NOT\nSELECTED'},
  {bit = 4, label = 'IF TRACK NOT\nARMED'},
  {bit = 8, label = 'ALWAYS\nHIDE'},
}

function M.new(State, Config, settings, additional_view)
  local self = setmetatable({
    State = State,
    Config = Config,
    settings = settings,
    additional_view = additional_view,  -- Reference to shared assignment state

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
  -- NOTE: REAPER parameter values ARE already 1-based spinner indices
  local spinners = {
    'tcp_LabelSize', 'tcp_vol_size', 'tcp_MeterSize',
    'tcp_InputSize', 'tcp_MeterLoc', 'tcp_sepSends',
    'tcp_fxparms_size', 'tcp_recmon_size', 'tcp_pan_size', 'tcp_width_size'
  }

  for _, param_name in ipairs(spinners) do
    local param = ThemeParams.get_param(param_name)
    if param then
      local idx_field = param_name .. '_idx'
      -- REAPER value is already a 1-based index - use it directly
      self[idx_field] = param.value
    end
  end

  -- Load global parameters (affect all layouts)
  local global_params = {'tcp_indent', 'tcp_control_align'}
  for _, param_name in ipairs(global_params) do
    local param = ThemeParams.get_param(param_name)
    if param then
      local idx_field = param_name .. '_idx'
      -- REAPER value is already a 1-based index - use it directly
      self[idx_field] = param.value
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
  -- Toggle a visibility flag bit and write to theme
  ThemeParams.toggle_flag(param_name, bit)
  -- Reload to sync UI
  local param = ThemeParams.get_param(param_name)
  if param then
    self.visibility[param_name] = param.value
  end
end

function TCPView:get_default_layout()
  -- Get the default TCP layout (returns layout name like "A", "B", "C")
  local ok, layout_name = pcall(reaper.ThemeLayout_GetLayout, "tcp", -1)
  if ok and layout_name and type(layout_name) == "string" then
    -- Extract just the layout letter (might be "A", "150%_B", etc.)
    local layout = string.match(layout_name, "([ABC])") or "A"
    return layout
  end
  return "A"
end

function TCPView:set_default_layout(layout)
  -- Set the default TCP layout for new tracks
  local ok = pcall(reaper.ThemeLayout_SetLayout, "tcp", -1, layout)
  return ok
end

function TCPView:get_additional_params()
  -- Get parameters assigned to TCP tab from shared state (cached)
  if not self.additional_view then
    return {}
  end

  -- Cache the result to avoid recalculating every frame
  if not self.cached_additional_params then
    self.cached_additional_params = self.additional_view:get_assigned_params("TCP")
  end

  return self.cached_additional_params
end

function TCPView:refresh_additional_params()
  -- Force refresh of cached additional params
  self.cached_additional_params = nil
end

function TCPView:draw_additional_param(ctx, param)
  -- Vertical stacked layout for narrow column
  -- Use custom display name if available, otherwise use param name
  local display_name = (param.display_name and param.display_name ~= "")
    and param.display_name or param.name

  -- Label
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#CCCCCC"))
  ImGui.Text(ctx, display_name)
  ImGui.PopStyleColor(ctx)

  -- Tooltip with custom description or default info
  if ImGui.IsItemHovered(ctx) then
    local tooltip
    if param.custom_description and param.custom_description ~= "" then
      -- Use custom description
      tooltip = param.custom_description
    else
      -- Use default technical info
      tooltip = string.format(
        "Parameter: %s\nType: %s\nRange: %.1f - %.1f\nDefault: %.1f\nCurrent: %.1f",
        param.name,
        param.type,
        param.min,
        param.max,
        param.default,
        param.value
      )
    end
    ImGui.SetTooltip(ctx, tooltip)
  end

  ImGui.Dummy(ctx, 0, 2)

  -- Control (full width)
  local control_w = ImGui.GetContentRegionAvail(ctx) - 16

  local changed = false
  local new_value = param.value

  if param.type == "toggle" then
    local is_checked = (param.value ~= 0)
    if Checkbox.draw_at_cursor(ctx, "", is_checked, nil, "tcp_add_" .. param.index) then
      changed = true
      new_value = is_checked and 0 or 1
    end

  elseif param.type == "spinner" then
    local values = {}
    for i = param.min, param.max do
      table.insert(values, tostring(i))
    end

    local current_idx = math.floor(param.value - param.min + 1)
    current_idx = math.max(1, math.min(current_idx, #values))

    local changed_spinner, new_idx = Spinner.draw(
      ctx,
      "##tcp_add_spinner_" .. param.index,
      current_idx,
      values,
      {w = control_w, h = 24}
    )

    if changed_spinner then
      changed = true
      new_value = param.min + (new_idx - 1)
    end

  elseif param.type == "slider" then
    ImGui.SetNextItemWidth(ctx, control_w)
    local changed_slider, slider_value = ImGui.SliderDouble(
      ctx,
      "##tcp_add_slider_" .. param.index,
      param.value,
      param.min,
      param.max,
      "%.1f"
    )

    if changed_slider then
      changed = true
      new_value = slider_value
    end

  else
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#888888"))
    ImGui.Text(ctx, string.format("%.1f", param.value))
    ImGui.PopStyleColor(ctx)
  end

  if changed then
    pcall(reaper.ThemeLayout_SetParameter, param.index, new_value, true)
    pcall(reaper.ThemeLayout_RefreshAll)
    param.value = new_value
  end

  ImGui.Dummy(ctx, 0, 8)
end

function TCPView:draw(ctx, shell_state)
  local avail_w = ImGui.GetContentRegionAvail(ctx)

  -- Get assigned parameters from shared state
  local additional_params = self:get_additional_params()

  -- Title
  ImGui.PushFont(ctx, shell_state.fonts.bold, 16)
  ImGui.Text(ctx, "Track Control Panel")
  ImGui.PopFont(ctx)

  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#999999"))
  ImGui.Text(ctx, "Configure track appearance and element visibility")
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 8)

  -- Determine if we need two columns
  local has_additional = #additional_params > 0
  local left_width = has_additional and (avail_w * 0.6) or avail_w
  local right_width = has_additional and (avail_w * 0.4 - 8) or 0

  -- Left column (main controls)
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#1A1A1A"))
  if ImGui.BeginChild(ctx, "tcp_left", left_width, 0, 1) then
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

    ImGui.Dummy(ctx, 0, 4)

    -- Set Default Layout button
    local default_layout = self:get_default_layout()
    local is_default = (default_layout == self.active_layout)

    ImGui.AlignTextToFramePadding(ctx)
    if is_default then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#00FF88"))
      ImGui.Text(ctx, "Default Layout")
      ImGui.PopStyleColor(ctx)
    else
      ImGui.Text(ctx, "Default Layout")
    end
    ImGui.SameLine(ctx, 120)

    if Button.draw_at_cursor(ctx, {
      label = is_default and ("✓ " .. self.active_layout .. " is Default") or ("Set " .. self.active_layout .. " as Default"),
      width = 200,
      height = 24,
      is_toggled = is_default,
      preset_name = is_default and "BUTTON_TOGGLE_WHITE" or nil,
      on_click = function()
        if not is_default then
          self:set_default_layout(self.active_layout)
        end
      end
    }, "tcp_set_default") then
    end
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, Strings.format(Strings.TCP.set_default_layout, self.active_layout))
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
      -- Send spinner index directly (REAPER expects 1-based indices)
      ThemeParams.set_param('tcp_indent', new_idx, true)
    end

    changed, new_idx = draw_spinner_row("Alignment", "tcp_control_align", self.tcp_control_align_idx, SPINNER_VALUES.tcp_control_align)
    if changed then
      self.tcp_control_align_idx = new_idx
      -- Send spinner index directly (REAPER expects 1-based indices)
      ThemeParams.set_param('tcp_control_align', new_idx, true)
    end

    changed, new_idx = draw_spinner_row("Meter Loc", "tcp_MeterLoc", self.tcp_MeterLoc_idx, SPINNER_VALUES.tcp_MeterLoc)
    if changed then
      self.tcp_MeterLoc_idx = new_idx
      -- Send spinner index directly (REAPER expects 1-based indices)
      ThemeParams.set_param('tcp_MeterLoc', new_idx, true)
    end

    changed, new_idx = draw_spinner_row("Send List", "tcp_sepSends", self.tcp_sepSends_idx, SPINNER_VALUES.tcp_sepSends)
    if changed then
      self.tcp_sepSends_idx = new_idx
      ThemeParams.set_param('tcp_sepSends', new_idx, true)
    end

    ImGui.EndGroup(ctx)

    -- Column 2: Element Sizing
    ImGui.SameLine(ctx, col_w + 8)
    ImGui.BeginGroup(ctx)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
    ImGui.Text(ctx, "Element Sizing")
    ImGui.PopStyleColor(ctx)
    ImGui.Dummy(ctx, 0, 3)

    changed, new_idx = draw_spinner_row("Name", "tcp_LabelSize", self.tcp_LabelSize_idx, SPINNER_VALUES.tcp_LabelSize)
    if changed then
      self.tcp_LabelSize_idx = new_idx
      ThemeParams.set_param('tcp_LabelSize', new_idx, true)
    end

    changed, new_idx = draw_spinner_row("Volume", "tcp_vol_size", self.tcp_vol_size_idx, SPINNER_VALUES.tcp_vol_size)
    if changed then
      self.tcp_vol_size_idx = new_idx
      ThemeParams.set_param('tcp_vol_size', new_idx, true)
    end

    changed, new_idx = draw_spinner_row("Meter", "tcp_MeterSize", self.tcp_MeterSize_idx, SPINNER_VALUES.tcp_MeterSize)
    if changed then
      self.tcp_MeterSize_idx = new_idx
      ThemeParams.set_param('tcp_MeterSize', new_idx, true)
    end

    changed, new_idx = draw_spinner_row("Input", "tcp_InputSize", self.tcp_InputSize_idx, SPINNER_VALUES.tcp_InputSize)
    if changed then
      self.tcp_InputSize_idx = new_idx
      ThemeParams.set_param('tcp_InputSize', new_idx, true)
    end

    ImGui.EndGroup(ctx)

    -- Column 3: Control Sizing
    ImGui.SameLine(ctx, (col_w * 2) + 8)
    ImGui.BeginGroup(ctx)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
    ImGui.Text(ctx, "Control Sizing")
    ImGui.PopStyleColor(ctx)
    ImGui.Dummy(ctx, 0, 3)

    changed, new_idx = draw_spinner_row("FX Parms", "tcp_fxparms_size", self.tcp_fxparms_size_idx, SPINNER_VALUES.tcp_fxparms_size)
    if changed then
      self.tcp_fxparms_size_idx = new_idx
      ThemeParams.set_param('tcp_fxparms_size', new_idx, true)
    end

    changed, new_idx = draw_spinner_row("Rec Mon", "tcp_recmon_size", self.tcp_recmon_size_idx, SPINNER_VALUES.tcp_recmon_size)
    if changed then
      self.tcp_recmon_size_idx = new_idx
      ThemeParams.set_param('tcp_recmon_size', new_idx, true)
    end

    changed, new_idx = draw_spinner_row("Pan", "tcp_pan_size", self.tcp_pan_size_idx, SPINNER_VALUES.tcp_pan_size)
    if changed then
      self.tcp_pan_size_idx = new_idx
      ThemeParams.set_param('tcp_pan_size', new_idx, true)
    end

    changed, new_idx = draw_spinner_row("Width", "tcp_width_size", self.tcp_width_size_idx, SPINNER_VALUES.tcp_width_size)
    if changed then
      self.tcp_width_size_idx = new_idx
      ThemeParams.set_param('tcp_width_size', new_idx, true)
    end

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
          if ImGui.IsItemHovered(ctx) then
            local tooltip = Strings.TCP_VIS_ELEMENTS[elem.id] or ("Toggle " .. elem.label)
            ImGui.SetTooltip(ctx, tooltip)
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

  -- Right column (additional parameters)
  if has_additional then
    ImGui.SameLine(ctx, 0, 8)

    ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#1A1A1A"))
    if ImGui.BeginChild(ctx, "tcp_right", right_width, 0, 1) then
      -- Draw background pattern
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

      -- Additional Parameters Section
      ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#4A90E2"))
      ImGui.Text(ctx, "ADDITIONAL PARAMETERS")
      ImGui.PopStyleColor(ctx)
      ImGui.PopFont(ctx)
      ImGui.Dummy(ctx, 0, 4)

      local tab_color = hexrgb("#4A90E2")  -- TCP blue color
      for _, param in ipairs(additional_params) do
        AdditionalParamTile.render(ctx, param, tab_color, shell_state, self.additional_view)
      end

      ImGui.Unindent(ctx, 8)
      ImGui.Dummy(ctx, 0, 2)
      ImGui.EndChild(ctx)
    end
    ImGui.PopStyleColor(ctx)
  end
end

return M
