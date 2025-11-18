-- @noindex
-- ThemeAdjuster/ui/views/additional_view.lua
-- Additional parameters tab - auto-discovered theme parameters

local ImGui = require 'imgui' '0.10'
local Checkbox = require('rearkitekt.gui.widgets.primitives.checkbox')
local Spinner = require('rearkitekt.gui.widgets.primitives.spinner')
local Button = require('rearkitekt.gui.widgets.primitives.button')
local Background = require('rearkitekt.gui.widgets.containers.panel.background')
local Style = require('rearkitekt.gui.style.defaults')
local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb
local ParamDiscovery = require('ThemeAdjuster.core.param_discovery')
local ThemeMapper = require('ThemeAdjuster.core.theme_mapper')
local ThemeParams = require('ThemeAdjuster.core.theme_params')

local PC = Style.PANEL_COLORS

local M = {}
local AdditionalView = {}
AdditionalView.__index = AdditionalView

function M.new(State, Config, settings)
  local self = setmetatable({
    State = State,
    Config = Config,
    settings = settings,

    -- Discovered parameters
    all_params = {},
    unknown_params = {},
    grouped_params = {},

    -- UI state
    dev_mode = false,
  }, AdditionalView)

  -- Discover parameters on init
  self:refresh_params()

  return self
end

function AdditionalView:refresh_params()
  -- Discover all theme parameters
  self.all_params = ParamDiscovery.discover_all_params()

  -- Filter to only unknown params (not in ThemeParams.KNOWN_PARAMS)
  self.unknown_params = ParamDiscovery.filter_unknown_params(
    self.all_params,
    ThemeParams.KNOWN_PARAMS or {}
  )

  -- Group by category
  self.grouped_params = ParamDiscovery.group_by_category(self.unknown_params)
end

function AdditionalView:draw(ctx, shell_state)
  local avail_w = ImGui.GetContentRegionAvail(ctx)

  -- Title
  ImGui.PushFont(ctx, shell_state.fonts.bold, 16)
  ImGui.Text(ctx, "Additional Parameters")
  ImGui.PopFont(ctx)

  ImGui.SameLine(ctx, 0, 20)

  -- Export button
  local theme_name = ParamDiscovery.get_current_theme_name()
  local param_count = #self.unknown_params

  if Button.draw_at_cursor(ctx, {
    label = "Export to JSON",
    width = 120,
    height = 24,
    on_click = function()
      self:export_parameters()
    end
  }, "export_json") then
  end

  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "Export all discovered parameters to a JSON file in ColorThemes/")
  end

  ImGui.Dummy(ctx, 0, 4)

  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#999999"))
  ImGui.Text(ctx, string.format("Auto-discovered parameters from: %s (%d found)", theme_name, param_count))
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 8)

  -- Scrollable content area
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#1A1A1A"))
  if ImGui.BeginChild(ctx, "additional_content", avail_w, 0, 1) then
    -- Draw background pattern
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

    -- Display grouped parameters
    if param_count == 0 then
      ImGui.Dummy(ctx, 0, 20)
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#666666"))
      ImGui.Text(ctx, "No additional parameters found.")
      ImGui.Text(ctx, "All theme parameters are already mapped to their respective tabs.")
      ImGui.PopStyleColor(ctx)
    else
      for category, params in pairs(self.grouped_params) do
        ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
        ImGui.Text(ctx, category:upper())
        ImGui.PopFont(ctx)
        ImGui.Dummy(ctx, 0, 4)

        for _, param in ipairs(params) do
          self:draw_param_row(ctx, param, shell_state)
        end

        ImGui.Dummy(ctx, 0, 12)
      end
    end

    ImGui.Unindent(ctx, 8)
    ImGui.Dummy(ctx, 0, 2)
    ImGui.EndChild(ctx)
  end
  ImGui.PopStyleColor(ctx)
end

function AdditionalView:draw_param_row(ctx, param, shell_state)
  local label_w = 200
  local control_w = 150

  -- Label (left side)
  ImGui.AlignTextToFramePadding(ctx)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
  ImGui.Text(ctx, param.name)
  ImGui.PopStyleColor(ctx)

  -- Tooltip with details
  if ImGui.IsItemHovered(ctx) then
    local tooltip = string.format(
      "Parameter: %s\nType: %s\nRange: %.1f - %.1f\nDefault: %.1f\nCurrent: %.1f",
      param.name,
      param.type,
      param.min,
      param.max,
      param.default,
      param.value
    )
    ImGui.SetTooltip(ctx, tooltip)
  end

  ImGui.SameLine(ctx, label_w)

  -- Draw the appropriate control
  local changed, new_value = self:draw_control(ctx, param, control_w)

  if changed then
    -- Update parameter via REAPER API
    pcall(reaper.ThemeLayout_SetParameter, param.index, new_value, true)
    pcall(reaper.ThemeLayout_RefreshAll)
    param.value = new_value
  end

  ImGui.Dummy(ctx, 0, 4)
end

function AdditionalView:draw_control(ctx, param, width)
  local changed = false
  local new_value = param.value

  if param.type == "toggle" then
    -- Checkbox for 0/1 toggles
    local is_checked = (param.value ~= 0)
    if Checkbox.draw_at_cursor(ctx, "", is_checked, nil, "param_" .. param.index) then
      changed = true
      new_value = is_checked and 0 or 1
    end

  elseif param.type == "spinner" then
    -- Spinner for discrete values
    local values = {}
    for i = param.min, param.max do
      table.insert(values, tostring(i))
    end

    local current_idx = math.floor(param.value - param.min + 1)
    current_idx = math.max(1, math.min(current_idx, #values))

    local changed_spinner, new_idx = Spinner.draw(
      ctx,
      "##spinner_" .. param.index,
      current_idx,
      values,
      {w = width, h = 24}
    )

    if changed_spinner then
      changed = true
      new_value = param.min + (new_idx - 1)
    end

  elseif param.type == "slider" then
    -- Slider for continuous ranges
    ImGui.SetNextItemWidth(ctx, width)
    local changed_slider, slider_value = ImGui.SliderDouble(
      ctx,
      "##slider_" .. param.index,
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
    -- Static value display
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#888888"))
    ImGui.Text(ctx, string.format("%.1f", param.value))
    ImGui.PopStyleColor(ctx)
  end

  return changed, new_value
end

function AdditionalView:export_parameters()
  -- Export all unknown parameters to JSON
  local success, path_or_error = ThemeMapper.export_mappings(self.unknown_params)

  if success then
    reaper.ShowMessageBox(
      "Parameters exported successfully!\n\nFile: " .. path_or_error .. "\n\n" ..
      "This JSON file can be:\n" ..
      "• Edited to customize parameter names, colors, and categories\n" ..
      "• Shared with other users of this theme\n" ..
      "• Version controlled alongside the theme",
      "Export Successful",
      0
    )
  else
    reaper.ShowMessageBox(
      "Failed to export parameters:\n\n" .. path_or_error,
      "Export Failed",
      0
    )
  end
end

return M
