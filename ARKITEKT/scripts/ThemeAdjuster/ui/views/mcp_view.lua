-- @noindex
-- ThemeAdjuster/ui/views/mcp_view.lua
-- MCP (Mixer Control Panel) configuration tab

local ImGui = require 'imgui' '0.10'
local Spinner = require('rearkitekt.gui.widgets.primitives.spinner')
local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb

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

-- Visibility elements with bitflags
local VISIBILITY_ELEMENTS = {
  {id = 'mcp_Sidebar', label = 'Sidebar'},
  {id = 'mcp_Narrow', label = 'Narrow'},
  {id = 'mcp_Transport', label = 'Transport'},
  {id = 'mcp_Sends', label = 'Sends'},
  {id = 'mcp_Fader', label = 'Fader'},
  {id = 'mcp_Pan', label = 'Pan'},
  {id = 'mcp_Width', label = 'Width'},
  {id = 'mcp_Volume', label = 'Volume'},
  {id = 'mcp_Meter', label = 'Meter'},
  {id = 'mcp_Fx_Group', label = 'FX Group'},
  {id = 'mcp_Fx', label = 'FX'},
  {id = 'mcp_Sendlist', label = 'Send List'},
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
    active_layout = 'A',

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
  -- TODO: Load spinner indices from theme parameters
  -- For now, keep defaults
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
  -- Get current value
  local current = self.visibility[param_name] or 0
  -- XOR toggle
  local new_value = current ~ bit
  self.visibility[param_name] = new_value
  -- TODO: Set parameter in theme
  -- self:set_param(param_name, new_value, true)
end

function MCPView:draw(ctx, shell_state)
  local avail_w = ImGui.GetContentRegionAvail(ctx)

  -- Title
  ImGui.PushFont(ctx, shell_state.fonts.bold, 16)
  ImGui.Text(ctx, "Mixer Control Panel")
  ImGui.PopFont(ctx)

  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#999999"))
  ImGui.Text(ctx, "Configure mixer appearance and element visibility")
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 8)

  -- Single scrollable content area
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#1A1A1A"))
  if ImGui.BeginChild(ctx, "mcp_content", avail_w, 0, 1) then
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
    if changed then self.mcp_indent_idx = new_idx end

    changed, new_idx = draw_spinner_row("Alignment", "mcp_align", self.mcp_align_idx, SPINNER_VALUES.mcp_align)
    if changed then self.mcp_align_idx = new_idx end

    changed, new_idx = draw_spinner_row("Border", "mcp_border", self.mcp_border_idx, SPINNER_VALUES.mcp_border)
    if changed then self.mcp_border_idx = new_idx end

    changed, new_idx = draw_spinner_row("Ext Mixer", "mcp_extmixer_mode", self.mcp_extmixer_mode_idx, SPINNER_VALUES.mcp_extmixer_mode)
    if changed then self.mcp_extmixer_mode_idx = new_idx end

    ImGui.EndGroup(ctx)

    -- Column 2: Element Sizing
    ImGui.SameLine(ctx, col_w + 8)
    ImGui.BeginGroup(ctx)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
    ImGui.Text(ctx, "Element Sizing")
    ImGui.PopStyleColor(ctx)
    ImGui.Dummy(ctx, 0, 3)

    changed, new_idx = draw_spinner_row("Label", "mcp_labelSize", self.mcp_labelSize_idx, SPINNER_VALUES.mcp_labelSize)
    if changed then self.mcp_labelSize_idx = new_idx end

    changed, new_idx = draw_spinner_row("Volume", "mcp_volSize", self.mcp_volSize_idx, SPINNER_VALUES.mcp_volSize)
    if changed then self.mcp_volSize_idx = new_idx end

    changed, new_idx = draw_spinner_row("Meter Exp", "mcp_meterExpSize", self.mcp_meterExpSize_idx, SPINNER_VALUES.mcp_meterExpSize)
    if changed then self.mcp_meterExpSize_idx = new_idx end

    changed, new_idx = draw_spinner_row("I/O", "mcp_io_size", self.mcp_io_size_idx, SPINNER_VALUES.mcp_io_size)
    if changed then self.mcp_io_size_idx = new_idx end

    ImGui.EndGroup(ctx)

    -- Column 3: List Sizing
    ImGui.SameLine(ctx, (col_w * 2) + 8)
    ImGui.BeginGroup(ctx)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
    ImGui.Text(ctx, "List Sizing")
    ImGui.PopStyleColor(ctx)
    ImGui.Dummy(ctx, 0, 3)

    changed, new_idx = draw_spinner_row("FX List", "mcp_fxlist_size", self.mcp_fxlist_size_idx, SPINNER_VALUES.mcp_fxlist_size)
    if changed then self.mcp_fxlist_size_idx = new_idx end

    changed, new_idx = draw_spinner_row("Send List", "mcp_sendlist_size", self.mcp_sendlist_size_idx, SPINNER_VALUES.mcp_sendlist_size)
    if changed then self.mcp_sendlist_size_idx = new_idx end

    changed, new_idx = draw_spinner_row("Vol Text", "mcp_volText_pos", self.mcp_volText_pos_idx, SPINNER_VALUES.mcp_volText_pos)
    if changed then self.mcp_volText_pos_idx = new_idx end

    changed, new_idx = draw_spinner_row("Pan Text", "mcp_panText_pos", self.mcp_panText_pos_idx, SPINNER_VALUES.mcp_panText_pos)
    if changed then self.mcp_panText_pos_idx = new_idx end

    ImGui.EndGroup(ctx)

    ImGui.Dummy(ctx, 0, 16)

    -- Options Section
    ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
    ImGui.Text(ctx, "OPTIONS")
    ImGui.PopFont(ctx)
    ImGui.Dummy(ctx, 0, 4)

    if ImGui.Checkbox(ctx, "Hide MCP of master track", self.hide_mcp_master) then
      self.hide_mcp_master = not self.hide_mcp_master
      -- TODO: Set parameter
    end

    ImGui.Dummy(ctx, 0, 3)

    if ImGui.Checkbox(ctx, "Indicate tracks that are folder parents", self.folder_parent_indicator) then
      self.folder_parent_indicator = not self.folder_parent_indicator
      -- TODO: Set parameter
    end

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
