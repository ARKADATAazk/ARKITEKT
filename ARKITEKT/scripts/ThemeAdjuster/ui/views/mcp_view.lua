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

  ImGui.Dummy(ctx, 0, 15)

  -- Layout Settings Section
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#1A1A1A"))
  if ImGui.BeginChild(ctx, "mcp_layout_section", avail_w, 260, 1) then
    ImGui.Dummy(ctx, 0, 8)

    ImGui.Indent(ctx, 12)
    ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
    ImGui.Text(ctx, "LAYOUT SETTINGS")
    ImGui.PopFont(ctx)
    ImGui.Dummy(ctx, 0, 8)

    local label_w = 140
    local spinner_w = math.min(220, avail_w - label_w - 40)

    -- Helper function to draw spinner row
    local function draw_spinner_row(label, id, idx, values)
      ImGui.AlignTextToFramePadding(ctx)
      ImGui.Text(ctx, label)
      ImGui.SameLine(ctx, label_w)
      local changed, new_idx = Spinner.draw(ctx, id, idx, values, {w = spinner_w})
      ImGui.Dummy(ctx, 0, 4)
      return changed, new_idx
    end

    -- Spinners
    local changed, new_idx = draw_spinner_row("Folder Indent", "mcp_indent", self.mcp_indent_idx, SPINNER_VALUES.mcp_indent)
    if changed then self.mcp_indent_idx = new_idx end

    changed, new_idx = draw_spinner_row("Align Controls", "mcp_align", self.mcp_align_idx, SPINNER_VALUES.mcp_align)
    if changed then self.mcp_align_idx = new_idx end

    changed, new_idx = draw_spinner_row("Meter Expansion", "mcp_meterExpSize", self.mcp_meterExpSize_idx, SPINNER_VALUES.mcp_meterExpSize)
    if changed then self.mcp_meterExpSize_idx = new_idx end

    changed, new_idx = draw_spinner_row("Border Style", "mcp_border", self.mcp_border_idx, SPINNER_VALUES.mcp_border)
    if changed then self.mcp_border_idx = new_idx end

    changed, new_idx = draw_spinner_row("Volume Text", "mcp_volText_pos", self.mcp_volText_pos_idx, SPINNER_VALUES.mcp_volText_pos)
    if changed then self.mcp_volText_pos_idx = new_idx end

    changed, new_idx = draw_spinner_row("Pan Text", "mcp_panText_pos", self.mcp_panText_pos_idx, SPINNER_VALUES.mcp_panText_pos)
    if changed then self.mcp_panText_pos_idx = new_idx end

    changed, new_idx = draw_spinner_row("Extended Mixer", "mcp_extmixer_mode", self.mcp_extmixer_mode_idx, SPINNER_VALUES.mcp_extmixer_mode)
    if changed then self.mcp_extmixer_mode_idx = new_idx end

    ImGui.Unindent(ctx, 12)
    ImGui.Dummy(ctx, 0, 8)
    ImGui.EndChild(ctx)
  end
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 12)

  -- Layout & Size Section
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#1A1A1A"))
  if ImGui.BeginChild(ctx, "mcp_layout_buttons", avail_w, 120, 1) then
    ImGui.Dummy(ctx, 0, 8)

    ImGui.Indent(ctx, 12)
    ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
    ImGui.Text(ctx, "ACTIVE LAYOUT & SIZE")
    ImGui.PopFont(ctx)
    ImGui.Dummy(ctx, 0, 8)

    -- Active Layout
    ImGui.AlignTextToFramePadding(ctx)
    ImGui.Text(ctx, "Active Layout")
    ImGui.SameLine(ctx, 140)

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

    ImGui.Dummy(ctx, 0, 8)

    -- Apply Size
    ImGui.AlignTextToFramePadding(ctx)
    ImGui.Text(ctx, "Apply Size")
    ImGui.SameLine(ctx, 140)

    for _, size in ipairs({'100%', '150%', '200%'}) do
      if ImGui.Button(ctx, size, 70, 24) then
        -- TODO: Apply size
      end
      ImGui.SameLine(ctx, 0, 6)
    end
    ImGui.NewLine(ctx)

    ImGui.Unindent(ctx, 12)
    ImGui.Dummy(ctx, 0, 8)
    ImGui.EndChild(ctx)
  end
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 12)

  -- Options Section
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#1A1A1A"))
  if ImGui.BeginChild(ctx, "mcp_options_section", avail_w, 100, 1) then
    ImGui.Dummy(ctx, 0, 8)

    ImGui.Indent(ctx, 12)
    ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
    ImGui.Text(ctx, "OPTIONS")
    ImGui.PopFont(ctx)
    ImGui.Dummy(ctx, 0, 8)

    if ImGui.Checkbox(ctx, "Hide MCP of master track", self.hide_mcp_master) then
      self.hide_mcp_master = not self.hide_mcp_master
      -- TODO: Set parameter
    end

    ImGui.Dummy(ctx, 0, 4)

    if ImGui.Checkbox(ctx, "Indicate tracks that are folder parents", self.folder_parent_indicator) then
      self.folder_parent_indicator = not self.folder_parent_indicator
      -- TODO: Set parameter
    end

    ImGui.Unindent(ctx, 12)
    ImGui.Dummy(ctx, 0, 8)
    ImGui.EndChild(ctx)
  end
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 12)

  -- Visibility Table Section
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#1A1A1A"))
  if ImGui.BeginChild(ctx, "mcp_visibility_section", avail_w, 0, 1) then
    ImGui.Dummy(ctx, 0, 8)

    ImGui.Indent(ctx, 12)
    ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
    ImGui.Text(ctx, "ELEMENT VISIBILITY")
    ImGui.PopFont(ctx)
    ImGui.Dummy(ctx, 0, 4)

    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#999999"))
    ImGui.Text(ctx, "Control when mixer elements are visible")
    ImGui.PopStyleColor(ctx)
    ImGui.Dummy(ctx, 0, 8)

    -- Table
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_CellPadding, 8, 6)
    if ImGui.BeginTable(ctx, "mcp_visibility", 5, ImGui.TableFlags_Borders | ImGui.TableFlags_RowBg | ImGui.TableFlags_ScrollY, avail_w - 24, 300) then
      -- Setup columns
      ImGui.TableSetupColumn(ctx, "Element", ImGui.TableColumnFlags_WidthFixed, 150)
      for _, col in ipairs(VISIBILITY_COLUMNS) do
        ImGui.TableSetupColumn(ctx, col.label, ImGui.TableColumnFlags_WidthFixed, 90)
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

    ImGui.Unindent(ctx, 12)
    ImGui.Dummy(ctx, 0, 8)
    ImGui.EndChild(ctx)
  end
  ImGui.PopStyleColor(ctx)
end

return M
