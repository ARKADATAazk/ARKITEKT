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

-- Helper function to lighten a hex color
local function lighten_color(color_int, factor)
  -- Extract RGBA components
  local r = (color_int >> 24) & 0xFF
  local g = (color_int >> 16) & 0xFF
  local b = (color_int >> 8) & 0xFF
  local a = color_int & 0xFF

  -- Lighten by mixing with white
  r = math.floor(r + (255 - r) * factor)
  g = math.floor(g + (255 - g) * factor)
  b = math.floor(b + (255 - b) * factor)

  -- Clamp values
  r = math.min(255, math.max(0, r))
  g = math.min(255, math.max(0, g))
  b = math.min(255, math.max(0, b))

  -- Reconstruct color
  return (r << 24) | (g << 16) | (b << 8) | a
end

function M.new(State, Config, settings)
  local self = setmetatable({
    State = State,
    Config = Config,
    settings = settings,

    -- Discovered parameters
    all_params = {},
    unknown_params = {},
    grouped_params = {},

    -- Parameter groups (organized by group headers)
    param_groups = {},
    enabled_groups = {},  -- group_name -> true/false

    -- UI state
    dev_mode = false,
    show_group_filter = false,  -- Show group filter dialog

    -- Tab assignments: param_name -> {TCP = true, MCP = false, ...}
    assignments = {},

    -- Custom metadata: param_name -> {display_name = "", description = ""}
    custom_metadata = {},

    -- Callback to invalidate caches in TCP/MCP views
    cache_invalidation_callback = nil,
  }, AdditionalView)

  -- Discover parameters on init
  self:refresh_params()

  -- Load assignments from JSON if available
  self:load_assignments()

  return self
end

function AdditionalView:refresh_params()
  -- Discover all theme parameters
  self.all_params = ParamDiscovery.discover_all_params()

  -- Organize ALL params into groups (including group headers)
  -- This ensures group headers aren't filtered out before we can detect them
  self.param_groups = ParamDiscovery.organize_into_groups(self.all_params)

  -- Filter out known params from each group (but keep the group structure)
  local known_params = ThemeParams.KNOWN_PARAMS or {}
  for _, group in ipairs(self.param_groups) do
    local filtered_params = {}
    for _, param in ipairs(group.params) do
      if not known_params[param.name] then
        table.insert(filtered_params, param)
      end
    end
    group.params = filtered_params
  end

  -- Remove empty groups
  local non_empty_groups = {}
  for _, group in ipairs(self.param_groups) do
    if #group.params > 0 then
      table.insert(non_empty_groups, group)
    end
  end
  self.param_groups = non_empty_groups

  -- Initialize enabled_groups if not already set
  if not next(self.enabled_groups) then
    local disabled_by_default = ParamDiscovery.get_default_disabled_groups()
    for _, group in ipairs(self.param_groups) do
      -- Disable groups that are in the default disabled list
      self.enabled_groups[group.name] = not disabled_by_default[group.name]
    end
  end

  -- Filter unknown_params based on enabled groups
  self:apply_group_filter()

  -- Group by category (for existing UI)
  self.grouped_params = ParamDiscovery.group_by_category(self.unknown_params)
end

function AdditionalView:apply_group_filter()
  -- Build filtered list of params based on enabled groups
  self.unknown_params = {}

  for _, group in ipairs(self.param_groups) do
    if self.enabled_groups[group.name] then
      for _, param in ipairs(group.params) do
        table.insert(self.unknown_params, param)
      end
    end
  end

  -- Rebuild category groups for display
  self.grouped_params = ParamDiscovery.group_by_category(self.unknown_params)
end

function AdditionalView:draw(ctx, shell_state)
  local avail_w = ImGui.GetContentRegionAvail(ctx)

  -- Title
  ImGui.PushFont(ctx, shell_state.fonts.bold, 16)
  ImGui.Text(ctx, "Additional Parameters")
  ImGui.PopFont(ctx)

  ImGui.SameLine(ctx, 0, 20)

  -- Filter Groups button
  if Button.draw_at_cursor(ctx, {
    label = "Filter Groups",
    width = 120,
    height = 24,
    on_click = function()
      self.show_group_filter = not self.show_group_filter
    end
  }, "filter_groups") then
  end

  if ImGui.IsItemHovered(ctx) then
    local enabled_count = 0
    for _, enabled in pairs(self.enabled_groups) do
      if enabled then enabled_count = enabled_count + 1 end
    end
    ImGui.SetTooltip(ctx, string.format("Show/hide parameter groups (%d/%d enabled)", enabled_count, #self.param_groups))
  end

  ImGui.SameLine(ctx, 0, 8)

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

  -- Group filter dialog
  if self.show_group_filter then
    self:draw_group_filter_dialog(ctx, shell_state)
  end
end

function AdditionalView:draw_group_filter_dialog(ctx, shell_state)
  -- Center the window
  local window_w = 500
  local window_h = 400

  -- Get parent window position and size for centering
  local parent_x, parent_y = ImGui.GetWindowPos(ctx)
  local parent_w, parent_h = ImGui.GetWindowSize(ctx)

  -- Center relative to parent window
  ImGui.SetNextWindowPos(ctx, parent_x + (parent_w - window_w) / 2, parent_y + (parent_h - window_h) / 2, ImGui.Cond_Appearing)
  ImGui.SetNextWindowSize(ctx, window_w, window_h, ImGui.Cond_Appearing)

  local flags = ImGui.WindowFlags_NoCollapse
  local visible, open = ImGui.Begin(ctx, "Parameter Group Filter##group_filter", true, flags)

  if visible then
    ImGui.PushFont(ctx, shell_state.fonts.bold, 14)
    ImGui.Text(ctx, "Enable/Disable Parameter Groups")
    ImGui.PopFont(ctx)

    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#999999"))
    ImGui.Text(ctx, "Only parameters from enabled groups will be shown in the Additional tab")
    ImGui.PopStyleColor(ctx)

    ImGui.Dummy(ctx, 0, 8)

    -- Buttons
    if Button.draw_at_cursor(ctx, {
      label = "Enable All",
      width = 100,
      height = 24,
      on_click = function()
        for group_name, _ in pairs(self.enabled_groups) do
          self.enabled_groups[group_name] = true
        end
        self:apply_group_filter()
        self:save_group_filter()
      end
    }, "enable_all_groups") then
    end

    ImGui.SameLine(ctx, 0, 8)

    if Button.draw_at_cursor(ctx, {
      label = "Disable All",
      width = 100,
      height = 24,
      on_click = function()
        for group_name, _ in pairs(self.enabled_groups) do
          self.enabled_groups[group_name] = false
        end
        self:apply_group_filter()
        self:save_group_filter()
      end
    }, "disable_all_groups") then
    end

    ImGui.SameLine(ctx, 0, 8)

    if Button.draw_at_cursor(ctx, {
      label = "Reset to Defaults",
      width = 130,
      height = 24,
      on_click = function()
        local disabled_by_default = ParamDiscovery.get_default_disabled_groups()
        for _, group in ipairs(self.param_groups) do
          self.enabled_groups[group.name] = not disabled_by_default[group.name]
        end
        self:apply_group_filter()
        self:save_group_filter()
      end
    }, "reset_groups") then
    end

    ImGui.Dummy(ctx, 0, 8)

    -- Group list
    ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#1A1A1A"))
    if ImGui.BeginChild(ctx, "group_list", 0, -32, 1) then
      ImGui.Indent(ctx, 8)
      ImGui.Dummy(ctx, 0, 4)

      for i, group in ipairs(self.param_groups) do
        local is_enabled = self.enabled_groups[group.name]
        local param_count = #group.params

        -- Checkbox
        if Checkbox.draw_at_cursor(ctx, "", is_enabled, nil, "group_check_" .. i) then
          self.enabled_groups[group.name] = not is_enabled
          self:apply_group_filter()
          self:save_group_filter()
        end

        -- Group info
        ImGui.SameLine(ctx, 0, 8)
        ImGui.AlignTextToFramePadding(ctx)

        local display_text = string.format("%s (%d params)", group.display_name, param_count)
        if is_enabled then
          ImGui.Text(ctx, display_text)
        else
          ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#666666"))
          ImGui.Text(ctx, display_text)
          ImGui.PopStyleColor(ctx)
        end

        ImGui.Dummy(ctx, 0, 2)
      end

      ImGui.Unindent(ctx, 8)
      ImGui.Dummy(ctx, 0, 4)
      ImGui.EndChild(ctx)
    end
    ImGui.PopStyleColor(ctx)

    ImGui.End(ctx)
  end

  if not open then
    self.show_group_filter = false
  end
end

function AdditionalView:draw_param_row(ctx, param, shell_state)
  local label_w = 250
  local control_start = label_w
  local control_w = 150
  local chips_start = control_start + control_w + 20
  local name_start = chips_start + 280
  local desc_start = name_start + 200

  -- Initialize metadata if needed
  if not self.custom_metadata[param.name] then
    self.custom_metadata[param.name] = {
      display_name = "",
      description = ""
    }
  end

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

  -- Draw the control (checkbox/slider/spinner)
  ImGui.SameLine(ctx, control_start)
  local changed, new_value = self:draw_control(ctx, param, control_w)

  if changed then
    -- Update parameter via REAPER API
    pcall(reaper.ThemeLayout_SetParameter, param.index, new_value, true)
    pcall(reaper.ThemeLayout_RefreshAll)
    param.value = new_value
  end

  -- Draw assignable tab chips
  ImGui.SameLine(ctx, chips_start)
  local assignment_changed = self:draw_assignment_chips(ctx, param)
  if assignment_changed then
    self:save_assignments()
  end

  -- Custom Name field
  ImGui.SameLine(ctx, name_start)
  ImGui.AlignTextToFramePadding(ctx)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#888888"))
  ImGui.Text(ctx, "N:")
  ImGui.PopStyleColor(ctx)
  ImGui.SameLine(ctx, 0, 4)

  ImGui.SetNextItemWidth(ctx, 140)
  local name_changed, new_name = ImGui.InputText(ctx, "##name_" .. param.index,
    self.custom_metadata[param.name].display_name)
  if name_changed then
    self.custom_metadata[param.name].display_name = new_name
    self:save_assignments()
  end

  -- Description field
  ImGui.SameLine(ctx, desc_start)
  ImGui.AlignTextToFramePadding(ctx)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#888888"))
  ImGui.Text(ctx, "D:")
  ImGui.PopStyleColor(ctx)
  ImGui.SameLine(ctx, 0, 4)

  ImGui.SetNextItemWidth(ctx, 200)
  local desc_changed, new_desc = ImGui.InputText(ctx, "##desc_" .. param.index,
    self.custom_metadata[param.name].description)
  if desc_changed then
    self.custom_metadata[param.name].description = new_desc
    self:save_assignments()
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

function AdditionalView:draw_assignment_chips(ctx, param)
  -- Available tabs for assignment
  local tabs = {
    {id = "TCP", label = "TCP", color = hexrgb("#4A90E2")},
    {id = "MCP", label = "MCP", color = hexrgb("#E24A90")},
    {id = "ENVCP", label = "ENV", color = hexrgb("#90E24A")},
    {id = "TRANS", label = "TRN", color = hexrgb("#E2904A")},
    {id = "GLOBAL", label = "GLB", color = hexrgb("#9B4AE2")},
  }

  -- Initialize assignment state for this param if needed
  if not self.assignments[param.name] then
    self.assignments[param.name] = {}
  end

  local changed = false
  local chip_w = 48
  local chip_h = 20
  local chip_spacing = 4

  for i, tab in ipairs(tabs) do
    if i > 1 then
      ImGui.SameLine(ctx, 0, chip_spacing)
    end

    local is_assigned = self.assignments[param.name][tab.id] or false
    local chip_id = "chip_" .. param.index .. "_" .. tab.id

    -- Draw chip button
    local bg_color = is_assigned and tab.color or hexrgb("#333333")
    local hover_color = is_assigned and lighten_color(tab.color, 0.2) or hexrgb("#444444")
    local text_color = is_assigned and hexrgb("#FFFFFF") or hexrgb("#888888")

    ImGui.PushStyleColor(ctx, ImGui.Col_Button, bg_color)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, hover_color)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, tab.color)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, text_color)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameRounding, 3)

    if ImGui.Button(ctx, tab.label .. "##" .. chip_id, chip_w, chip_h) then
      self.assignments[param.name][tab.id] = not is_assigned
      changed = true
    end

    ImGui.PopStyleVar(ctx)
    ImGui.PopStyleColor(ctx, 4)

    -- Tooltip
    if ImGui.IsItemHovered(ctx) then
      local tooltip = is_assigned
        and string.format("Remove from %s tab", tab.label)
        or string.format("Assign to %s tab", tab.label)
      ImGui.SetTooltip(ctx, tooltip)
    end
  end

  return changed
end

function AdditionalView:load_assignments()
  -- Load assignments from JSON file
  local mappings = ThemeMapper.load_current_mappings()

  if mappings and mappings.assignments then
    self.assignments = mappings.assignments
  else
    self.assignments = {}
  end

  if mappings and mappings.custom_metadata then
    self.custom_metadata = mappings.custom_metadata
  else
    self.custom_metadata = {}
  end

  -- Load group filter state
  if mappings and mappings.enabled_groups then
    -- Merge with current enabled_groups (in case new groups were added)
    for group_name, enabled in pairs(mappings.enabled_groups) do
      self.enabled_groups[group_name] = enabled
    end
    -- Re-apply filter with loaded settings
    self:apply_group_filter()
  end
end

function AdditionalView:set_cache_invalidation_callback(callback)
  -- Set callback to invalidate TCP/MCP caches when assignments change
  self.cache_invalidation_callback = callback
end

function AdditionalView:save_assignments()
  -- Save assignments, metadata, and group filter to JSON file
  local success = ThemeMapper.save_assignments(self.assignments, self.custom_metadata, self.enabled_groups)

  -- Invalidate TCP/MCP caches so they pick up the new assignments
  if self.cache_invalidation_callback then
    self.cache_invalidation_callback()
  end

  return success
end

function AdditionalView:save_group_filter()
  -- Save only group filter state (lightweight save)
  ThemeMapper.save_assignments(self.assignments, self.custom_metadata, self.enabled_groups)

  -- Invalidate TCP/MCP caches since filtering might affect visible params
  if self.cache_invalidation_callback then
    self.cache_invalidation_callback()
  end
end

function AdditionalView:get_assigned_params(tab_id)
  -- Return all parameters assigned to a specific tab with custom metadata
  local assigned = {}

  -- Filter to params assigned to this tab from cached unknown_params
  for _, param in ipairs(self.unknown_params) do
    local assignment = self.assignments[param.name]
    if assignment and assignment[tab_id] then
      -- Attach custom metadata if available
      local metadata = self.custom_metadata[param.name]
      if metadata then
        param.display_name = metadata.display_name or param.name
        param.custom_description = metadata.description or ""
      else
        param.display_name = param.name
        param.custom_description = ""
      end

      table.insert(assigned, param)
    end
  end

  return assigned
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
