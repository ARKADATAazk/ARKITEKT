-- @noindex
-- ThemeAdjuster/ui/views/mcp_view.lua
-- MCP (Mixer Control Panel) configuration tab

local ImGui = require 'imgui' '0.10'
local Spinner = require('arkitekt.gui.widgets.primitives.spinner')
local Checkbox = require('arkitekt.gui.widgets.primitives.checkbox')
local Button = require('arkitekt.gui.widgets.primitives.button')
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
local MCPView = {}
MCPView.__index = MCPView

-- Spinner value lists (from Default 6.0)
local SPINNER_VALUES = {
  mcp_indent = {'NONE', '1/8', '1/4', '1/2', 1, 2, 'MAX'},
  mcp_align = {'BOTTOM', 'CENTER'},
  mcp_meterExpSize = {4, 10, 20, 40, 80, 160, 320},
  mcp_border = {'NONE', 'FILLED', 'BORDER'},
  mcp_volText_pos = {'NORMAL', 'SEPARATE'},
  mcp_panText_pos = {'NORMAL', 'SEPARATE'},
  mcp_extmixer_mode = {'OFF', '1', '2', '3'},
  mcp_labelSize = {'MIN', 50, 75, 100, 125, 150},
  mcp_volSize = {'MIN', 40, 60, 80, 100, 120},
  mcp_fxlist_size = {'MIN', 80, 120, 160, 200},
  mcp_sendlist_size = {'MIN', 60, 90, 120, 150},
  mcp_io_size = {'MIN', 50, 75, 100, 125},
}

-- Visibility elements with bitflags (from Default 6.0)
local VISIBILITY_ELEMENTS = {
  {id = 'mcp_Sidebar', label = 'EXTEND WITH SIDEBAR'},
  {id = 'mcp_Narrow', label = 'NARROW FORM'},
  {id = 'mcp_Meter_Expansion', label = 'DO METER EXPANSION'},
  {id = 'mcp_Labels', label = 'ELEMENT LABELS'},
}

-- Bitflag column definitions (from Default 6.0 - different from TCP!)
local VISIBILITY_COLUMNS = {
  {bit = 1, label = 'IF TRACK\nSELECTED'},
  {bit = 2, label = 'IF TRACK NOT\nSELECTED'},
  {bit = 4, label = 'IF TRACK\nARMED'},
  {bit = 8, label = 'IF TRACK NOT\nARMED'},
}

function M.new(State, Config, settings, additional_view)
  local self = setmetatable({
    State = State,
    Config = Config,
    settings = settings,
    additional_view = additional_view,  -- Reference to shared assignment state

    -- Spinner indices (1-based)
    mcp_indent_idx = 1,
    mcp_align_idx = 1,
    mcp_meterExpSize_idx = 1,
    mcp_border_idx = 1,
    mcp_volText_pos_idx = 1,
    mcp_panText_pos_idx = 1,
    mcp_extmixer_mode_idx = 1,
    mcp_labelSize_idx = 1,
    mcp_volSize_idx = 1,
    mcp_fxlist_size_idx = 1,
    mcp_sendlist_size_idx = 1,
    mcp_io_size_idx = 1,

    -- Active layout (A/B/C)
    active_layout = ThemeParams.get_active_layout('mcp'),

    -- Toggles
    hide_mcp_master = false,
    folder_parent_indicator = false,

    -- Visibility values (loaded from theme)
    visibility = {},
  }, MCPView)

  -- Initialize visibility values
  for _, elem in ipairs(VISIBILITY_ELEMENTS) do
    self.visibility[elem.id] = 0
  end

  -- Load initial values from theme
  self:load_from_theme()

  return self
end

function MCPView:load_from_theme()
  -- Load spinner values from current layout's theme parameters
  -- NOTE: REAPER parameter values ARE already 1-based spinner indices
  local spinners = {
    'mcp_meterExpSize', 'mcp_border', 'mcp_volText_pos', 'mcp_panText_pos',
    'mcp_extmixer_mode', 'mcp_labelSize', 'mcp_volSize',
    'mcp_fxlist_size', 'mcp_sendlist_size', 'mcp_io_size'
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
  local global_params = {'mcp_indent', 'mcp_align'}
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

function MCPView:get_param_index(param_name)
  -- Get parameter index from theme layout
  -- Returns nil if not found
  local ok, idx = pcall(reaper.ThemeLayout_GetParameter, param_name)
  if ok and type(idx) == "number" then
    return idx
  end
  return nil
end

function MCPView:set_param(param, value, save)
  save = save == nil and true or save
  local ok = pcall(reaper.ThemeLayout_SetParameter, param, value, save)
  if ok and save then
    pcall(reaper.ThemeLayout_RefreshAll)
  end
  return ok
end

function MCPView:toggle_bitflag(param_name, bit)
  -- Toggle a visibility flag bit and write to theme
  ThemeParams.toggle_flag(param_name, bit)
  -- Reload to sync UI
  local param = ThemeParams.get_param(param_name)
  if param then
    self.visibility[param_name] = param.value
  end
end

function MCPView:get_default_layout()
  -- Get the default MCP layout (returns layout name like "A", "B", "C")
  local ok, layout_name = pcall(reaper.ThemeLayout_GetLayout, "mcp", -1)
  if ok and layout_name and type(layout_name) == "string" then
    -- Extract just the layout letter (might be "A", "150%_B", etc.)
    local layout = string.match(layout_name, "([ABC])") or "A"
    return layout
  end
  return "A"
end

function MCPView:set_default_layout(layout)
  -- Set the default MCP layout for new tracks
  local ok = pcall(reaper.ThemeLayout_SetLayout, "mcp", -1, layout)
  return ok
end

function MCPView:get_additional_params()
  -- Get parameters assigned to MCP tab from shared state (cached)
  if not self.additional_view then
    return {}
  end

  -- Cache the result to avoid recalculating every frame
  if not self.cached_additional_params then
    self.cached_additional_params = self.additional_view:get_assigned_params("MCP")
  end

  return self.cached_additional_params
end

function MCPView:refresh_additional_params()
  -- Force refresh of cached additional params
  self.cached_additional_params = nil
end

function MCPView:draw_additional_param(ctx, param)
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
    if Checkbox.draw_at_cursor(ctx, "", is_checked, nil, "mcp_add_" .. param.index) then
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
      "##mcp_add_spinner_" .. param.index,
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
      "##mcp_add_slider_" .. param.index,
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

function MCPView:draw(ctx, shell_state)
  local avail_w = ImGui.GetContentRegionAvail(ctx)

  -- Get assigned parameters from shared state
  local additional_params = self:get_additional_params()

  -- Title
  ImGui.PushFont(ctx, shell_state.fonts.bold, 16)
  ImGui.Text(ctx, "Mixer Control Panel")
  ImGui.PopFont(ctx)

  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#999999"))
  ImGui.Text(ctx, "Configure mixer appearance and element visibility")
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 8)

  -- Determine if we need two columns
  local has_additional = #additional_params > 0
  local left_width = has_additional and (avail_w * 0.6) or avail_w
  local right_width = has_additional and (avail_w * 0.4 - 8) or 0

  -- Left column (main controls)
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#1A1A1A"))
  if ImGui.BeginChild(ctx, "mcp_left", left_width, 0, 1) then
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
          ThemeParams.set_active_layout('mcp', layout)
          self:load_from_theme()
        end
      }, "mcp_layout_" .. layout) then
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
          local scale = (size == '100%') and '' or (size .. '_')
          ThemeParams.apply_layout_to_tracks('mcp', self.active_layout, scale)
        end
      }, "mcp_size_" .. size) then
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
    }, "mcp_set_default") then
    end
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, Strings.format(Strings.MCP.set_default_layout, self.active_layout))
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

    local changed, new_idx = draw_spinner_row("Indent", "mcp_indent", self.mcp_indent_idx, SPINNER_VALUES.mcp_indent)
    if changed then
      self.mcp_indent_idx = new_idx
      ThemeParams.set_param('mcp_indent', new_idx, true)
    end

    changed, new_idx = draw_spinner_row("Alignment", "mcp_align", self.mcp_align_idx, SPINNER_VALUES.mcp_align)
    if changed then
      self.mcp_align_idx = new_idx
      ThemeParams.set_param('mcp_align', new_idx, true)
    end

    changed, new_idx = draw_spinner_row("Border", "mcp_border", self.mcp_border_idx, SPINNER_VALUES.mcp_border)
    if changed then
      self.mcp_border_idx = new_idx
      ThemeParams.set_param('mcp_border', new_idx, true)
    end

    changed, new_idx = draw_spinner_row("Ext Mixer", "mcp_extmixer_mode", self.mcp_extmixer_mode_idx, SPINNER_VALUES.mcp_extmixer_mode)
    if changed then
      self.mcp_extmixer_mode_idx = new_idx
      ThemeParams.set_param('mcp_extmixer_mode', new_idx, true)
    end

    ImGui.EndGroup(ctx)

    -- Column 2: Element Sizing
    ImGui.SameLine(ctx, col_w + 8)
    ImGui.BeginGroup(ctx)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
    ImGui.Text(ctx, "Element Sizing")
    ImGui.PopStyleColor(ctx)
    ImGui.Dummy(ctx, 0, 3)

    changed, new_idx = draw_spinner_row("Label", "mcp_labelSize", self.mcp_labelSize_idx, SPINNER_VALUES.mcp_labelSize)
    if changed then
      self.mcp_labelSize_idx = new_idx
      ThemeParams.set_param('mcp_labelSize', new_idx, true)
    end

    changed, new_idx = draw_spinner_row("Volume", "mcp_volSize", self.mcp_volSize_idx, SPINNER_VALUES.mcp_volSize)
    if changed then
      self.mcp_volSize_idx = new_idx
      ThemeParams.set_param('mcp_volSize', new_idx, true)
    end

    changed, new_idx = draw_spinner_row("Meter Exp", "mcp_meterExpSize", self.mcp_meterExpSize_idx, SPINNER_VALUES.mcp_meterExpSize)
    if changed then
      self.mcp_meterExpSize_idx = new_idx
      ThemeParams.set_param('mcp_meterExpSize', new_idx, true)
    end

    changed, new_idx = draw_spinner_row("I/O", "mcp_io_size", self.mcp_io_size_idx, SPINNER_VALUES.mcp_io_size)
    if changed then
      self.mcp_io_size_idx = new_idx
      ThemeParams.set_param('mcp_io_size', new_idx, true)
    end

    ImGui.EndGroup(ctx)

    -- Column 3: List Sizing
    ImGui.SameLine(ctx, (col_w * 2) + 8)
    ImGui.BeginGroup(ctx)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
    ImGui.Text(ctx, "List Sizing")
    ImGui.PopStyleColor(ctx)
    ImGui.Dummy(ctx, 0, 3)

    changed, new_idx = draw_spinner_row("FX List", "mcp_fxlist_size", self.mcp_fxlist_size_idx, SPINNER_VALUES.mcp_fxlist_size)
    if changed then
      self.mcp_fxlist_size_idx = new_idx
      ThemeParams.set_param('mcp_fxlist_size', new_idx, true)
    end

    changed, new_idx = draw_spinner_row("Send List", "mcp_sendlist_size", self.mcp_sendlist_size_idx, SPINNER_VALUES.mcp_sendlist_size)
    if changed then
      self.mcp_sendlist_size_idx = new_idx
      ThemeParams.set_param('mcp_sendlist_size', new_idx, true)
    end

    changed, new_idx = draw_spinner_row("Vol Text", "mcp_volText_pos", self.mcp_volText_pos_idx, SPINNER_VALUES.mcp_volText_pos)
    if changed then
      self.mcp_volText_pos_idx = new_idx
      ThemeParams.set_param('mcp_volText_pos', new_idx, true)
    end

    changed, new_idx = draw_spinner_row("Pan Text", "mcp_panText_pos", self.mcp_panText_pos_idx, SPINNER_VALUES.mcp_panText_pos)
    if changed then
      self.mcp_panText_pos_idx = new_idx
      ThemeParams.set_param('mcp_panText_pos', new_idx, true)
    end

    ImGui.EndGroup(ctx)

    ImGui.Dummy(ctx, 0, 16)

    -- Options Section
    ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
    ImGui.Text(ctx, "OPTIONS")
    ImGui.PopFont(ctx)
    ImGui.Dummy(ctx, 0, 4)

    if Checkbox.draw_at_cursor(ctx, "Hide MCP of master track", self.hide_mcp_master, nil, "mcp_hide_master") then
      self.hide_mcp_master = not self.hide_mcp_master
      reaper.Main_OnCommand(41588, 0)  -- Toggle hide master track in mixer
    end
    ImGui.NewLine(ctx)

    ImGui.Dummy(ctx, 0, 3)

    if Checkbox.draw_at_cursor(ctx, "Indicate tracks that are folder parents", self.folder_parent_indicator, nil, "mcp_folder_indicator") then
      self.folder_parent_indicator = not self.folder_parent_indicator
      reaper.Main_OnCommand(40864, 0)  -- Toggle folder parent indicator in mixer
    end
    ImGui.NewLine(ctx)

    ImGui.Dummy(ctx, 0, 16)

    -- Extended Mixer Controls Section
    ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
    ImGui.Text(ctx, "EXTENDED MIXER CONTROLS")
    ImGui.PopFont(ctx)
    ImGui.Dummy(ctx, 0, 4)

    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#999999"))
    ImGui.Text(ctx, "Toggle mixer display options")
    ImGui.PopStyleColor(ctx)
    ImGui.Dummy(ctx, 0, 6)

    -- Helper function to draw action toggle button
    local function draw_action_toggle(label, command_id, button_id)
      local state = reaper.GetToggleCommandState(command_id)
      local is_on = (state == 1)

      if Button.draw_at_cursor(ctx, {
        label = label,
        width = 220,
        height = 28,
        is_toggled = is_on,
        preset_name = "BUTTON_TOGGLE_WHITE",
        on_click = function()
          reaper.Main_OnCommand(command_id, 0)
        end
      }, button_id) then
      end
      return is_on
    end

    -- Row 1: Show FX & Show Params
    draw_action_toggle("Show FX Inserts", 40549, "mcp_show_fx")
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, Strings.MCP.show_fx)
    end

    ImGui.SameLine(ctx, 0, 8)

    draw_action_toggle("Show FX Parameters", 40910, "mcp_show_params")
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, Strings.MCP.show_params)
    end
    ImGui.NewLine(ctx)
    ImGui.Dummy(ctx, 0, 4)

    -- Row 2: Show Sends & Multi-row
    draw_action_toggle("Show Sends", 40557, "mcp_show_sends")
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, Strings.MCP.show_sends)
    end

    ImGui.SameLine(ctx, 0, 8)

    draw_action_toggle("Multi-row Mixer", 40371, "mcp_multi_row")
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, Strings.MCP.multi_row)
    end
    ImGui.NewLine(ctx)
    ImGui.Dummy(ctx, 0, 4)

    -- Row 3: Scroll to Selected & Show Icons
    draw_action_toggle("Scroll to Selected", 40221, "mcp_scroll_selected")
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, Strings.MCP.scroll_to_selected)
    end

    ImGui.SameLine(ctx, 0, 8)

    draw_action_toggle("Show Icons", 40903, "mcp_show_icons")
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, Strings.MCP.show_icons)
    end
    ImGui.NewLine(ctx)

    ImGui.Dummy(ctx, 0, 16)

    -- Element Visibility Section
    ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
    ImGui.Text(ctx, "ELEMENT VISIBILITY")
    ImGui.PopFont(ctx)
    ImGui.Dummy(ctx, 0, 4)

    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#999999"))
    ImGui.Text(ctx, "Control when mixer elements are visible")
    ImGui.PopStyleColor(ctx)
    ImGui.Dummy(ctx, 0, 2)

    -- Table
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_CellPadding, 6, 4)
    if ImGui.BeginTable(ctx, "mcp_visibility", 5, ImGui.TableFlags_Borders | ImGui.TableFlags_RowBg | ImGui.TableFlags_ScrollY, avail_w - 16, 300) then
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
            local tooltip = Strings.MCP_VIS_ELEMENTS[elem.id] or ("Toggle " .. elem.label)
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
    if ImGui.BeginChild(ctx, "mcp_right", right_width, 0, 1) then
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
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#E24A90"))
      ImGui.Text(ctx, "ADDITIONAL PARAMETERS")
      ImGui.PopStyleColor(ctx)
      ImGui.PopFont(ctx)
      ImGui.Dummy(ctx, 0, 4)

      local tab_color = hexrgb("#E8C547")  -- MCP yellow color
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
