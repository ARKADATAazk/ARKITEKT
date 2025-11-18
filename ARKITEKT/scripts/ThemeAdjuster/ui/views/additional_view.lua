-- @noindex
-- ThemeAdjuster/ui/views/additional_view.lua
-- Additional parameters tab - Grid-based tile manager

local ImGui = require 'imgui' '0.10'
local Checkbox = require('rearkitekt.gui.widgets.primitives.checkbox')
local Button = require('rearkitekt.gui.widgets.primitives.button')
local Background = require('rearkitekt.gui.widgets.containers.panel.background')
local Style = require('rearkitekt.gui.style.defaults')
local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb
local ParamDiscovery = require('ThemeAdjuster.core.param_discovery')
local ThemeMapper = require('ThemeAdjuster.core.theme_mapper')
local ThemeParams = require('ThemeAdjuster.core.theme_params')
local GridBridge = require('rearkitekt.gui.widgets.containers.grid.grid_bridge')
local LibraryGridFactory = require('ThemeAdjuster.ui.grids.library_grid_factory')
local AssignmentGridFactory = require('ThemeAdjuster.ui.grids.assignment_grid_factory')

local PC = Style.PANEL_COLORS

local M = {}
local AdditionalView = {}
AdditionalView.__index = AdditionalView

-- Tab configurations
local TAB_CONFIGS = {
  {id = "TCP", label = "TCP", color = hexrgb("#4A90E2")},
  {id = "MCP", label = "MCP", color = hexrgb("#E24A90")},
  {id = "ENVCP", label = "ENV", color = hexrgb("#90E24A")},
  {id = "TRANS", label = "TRN", color = hexrgb("#E2904A")},
  {id = "GLOBAL", label = "GLB", color = hexrgb("#9B4AE2")},
}

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
    active_assignment_tab = "TCP",  -- Currently selected tab in assignment grid

    -- Tab assignments with ordering
    -- Structure: { TCP = { {param_name = "...", order = 1}, ... }, MCP = {...}, ... }
    assignments = {
      TCP = {},
      MCP = {},
      ENVCP = {},
      TRANS = {},
      GLOBAL = {}
    },

    -- Custom metadata: param_name -> {display_name = "", description = ""}
    custom_metadata = {},

    -- Grid instances
    library_grid = nil,
    assignment_grids = {},  -- tab_id -> grid
    bridge = nil,

    -- Callback to invalidate caches in TCP/MCP views
    cache_invalidation_callback = nil,

    -- ImGui context (needed for GridBridge)
    _imgui_ctx = nil,
  }, AdditionalView)

  -- Discover parameters on init
  self:refresh_params()

  -- Load assignments from JSON if available
  self:load_assignments()

  -- Create grids
  self:create_grids()

  return self
end

function AdditionalView:create_grids()
  -- Create library grid
  self.library_grid = LibraryGridFactory.create(self, {padding = 8})

  -- Create assignment grids for each tab
  for _, tab_config in ipairs(TAB_CONFIGS) do
    self.assignment_grids[tab_config.id] = AssignmentGridFactory.create(self, tab_config.id, {padding = 8})
  end

  -- Create GridBridge to coordinate drag-drop
  self.bridge = GridBridge.new({
    copy_mode_detector = function(source, target, payload)
      -- Library → Assignment: always copy
      if source == 'library' then
        return true
      end
      -- Assignment → Assignment: copy if Ctrl held
      if source:match("^assign_") and target:match("^assign_") then
        if self._imgui_ctx then
          local ctrl = ImGui.IsKeyDown(self._imgui_ctx, ImGui.Key_LeftCtrl) or
                      ImGui.IsKeyDown(self._imgui_ctx, ImGui.Key_RightCtrl)
          return ctrl
        end
      end
      return false
    end,

    delete_mode_detector = function(ctx, source, target, payload)
      -- Remove from assignment if dragged outside
      if source:match("^assign_") and not target:match("^assign_") then
        return not self.bridge:is_mouse_over_grid(ctx, source)
      end
      return false
    end,

    on_cross_grid_drop = function(drop_info)
      local source_id = drop_info.source_grid
      local target_id = drop_info.target_grid
      local payload = drop_info.payload
      local insert_index = drop_info.insert_index

      -- Library → Assignment: assign parameters
      if source_id == 'library' and target_id:match("^assign_(.+)") then
        local tab_id = target_id:match("^assign_(.+)")
        for i, param_name in ipairs(payload) do
          self:assign_param_to_tab_at_index(param_name, tab_id, insert_index + i - 1)
        end
        return
      end

      -- Assignment → Assignment: move or copy
      if source_id:match("^assign_(.+)") and target_id:match("^assign_(.+)") then
        local source_tab = source_id:match("^assign_(.+)")
        local target_tab = target_id:match("^assign_(.+)")
        local is_copy = drop_info.is_copy_mode

        if is_copy then
          -- Copy to target tab
          for i, param_name in ipairs(payload) do
            self:assign_param_to_tab_at_index(param_name, target_tab, insert_index + i - 1)
          end
        else
          -- Move to target tab (or reorder within same tab)
          if source_tab == target_tab then
            -- Reorder within same tab handled by grid reorder behavior
          else
            -- Move to different tab
            for i, param_name in ipairs(payload) do
              self:unassign_param_from_tab(param_name, source_tab)
              self:assign_param_to_tab_at_index(param_name, target_tab, insert_index + i - 1)
            end
          end
        end
      end
    end,

    on_drag_canceled = function(cancel_info)
      -- Handle delete if dragged outside
      if cancel_info.source_grid:match("^assign_(.+)") then
        local tab_id = cancel_info.source_grid:match("^assign_(.+)")
        local payload = cancel_info.payload or {}
        for _, param_name in ipairs(payload) do
          self:unassign_param_from_tab(param_name, tab_id)
        end
      end
    end,
  })

  -- Register library grid
  self.bridge:register_grid('library', self.library_grid, {
    accepts_drops_from = {},  -- Library doesn't accept drops
    on_drag_start = function(item_keys)
      -- Extract parameter names from keys
      local param_names = {}
      local params = self:get_library_items()
      local params_by_key = {}
      for _, param in ipairs(params) do
        params_by_key[self.library_grid.key(param)] = param
      end

      for _, key in ipairs(item_keys) do
        local param = params_by_key[key]
        if param then
          table.insert(param_names, param.name)
        end
      end

      self.bridge:start_drag('library', param_names)
    end,
  })

  -- Register assignment grids
  for _, tab_config in ipairs(TAB_CONFIGS) do
    local grid_id = "assign_" .. tab_config.id
    local grid = self.assignment_grids[tab_config.id]

    self.bridge:register_grid(grid_id, grid, {
      accepts_drops_from = {'library', 'assign_TCP', 'assign_MCP', 'assign_ENVCP', 'assign_TRANS', 'assign_GLOBAL'},
      on_drag_start = function(item_keys)
        -- Extract parameter names from keys
        local param_names = {}
        for _, key in ipairs(item_keys) do
          local param_name = key:match("^assign_(.+)")
          if param_name then
            table.insert(param_names, param_name)
          end
        end

        self.bridge:start_drag(grid_id, param_names)
      end,
    })
  end
end

function AdditionalView:refresh_params()
  -- Discover all theme parameters
  self.all_params = ParamDiscovery.discover_all_params()

  -- Organize ALL params into groups
  self.param_groups = ParamDiscovery.organize_into_groups(self.all_params)

  -- Filter out known params from each group
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

-- Grid data provider methods
function AdditionalView:get_library_items()
  return self.unknown_params
end

function AdditionalView:get_assignment_items(tab_id)
  if not self.assignments[tab_id] then
    return {}
  end

  -- Build param lookup table
  local param_lookup = {}
  for _, param in ipairs(self.unknown_params) do
    param_lookup[param.name] = param
  end

  -- Convert assignments to items with metadata
  local items = {}
  for _, assignment in ipairs(self.assignments[tab_id]) do
    if param_lookup[assignment.param_name] then
      table.insert(items, {
        param_name = assignment.param_name,
        order = assignment.order,
      })
    end
  end

  return items
end

function AdditionalView:draw(ctx, shell_state)
  -- Store ImGui context for GridBridge
  self._imgui_ctx = ctx

  local avail_w = ImGui.GetContentRegionAvail(ctx)
  local avail_h = ImGui.GetContentRegionAvail(ctx)

  -- Title and buttons
  ImGui.PushFont(ctx, shell_state.fonts.bold, 16)
  ImGui.Text(ctx, "Parameter Manager")
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
  if Button.draw_at_cursor(ctx, {
    label = "Export to JSON",
    width = 120,
    height = 24,
    on_click = function()
      self:export_parameters()
    end
  }, "export_json") then
  end

  ImGui.Dummy(ctx, 0, 8)

  -- Two-panel layout: LEFT = Parameter Library | RIGHT = Assignment Grid
  local panel_gap = 16
  local left_width = avail_w * 0.55
  local right_width = avail_w * 0.45 - panel_gap

  -- LEFT PANEL: Parameter Library
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#1A1A1A"))
  if ImGui.BeginChild(ctx, "param_library", left_width, 0, 1) then
    local child_x, child_y = ImGui.GetWindowPos(ctx)
    local child_w, child_h = ImGui.GetWindowSize(ctx)
    local dl = ImGui.GetWindowDrawList(ctx)

    -- Background pattern
    local pattern_cfg = {
      enabled = true,
      primary = {type = 'grid', spacing = 50, color = PC.pattern_primary, line_thickness = 1.5},
      secondary = {enabled = true, type = 'grid', spacing = 5, color = PC.pattern_secondary, line_thickness = 0.5},
    }
    Background.draw(dl, child_x, child_y, child_x + child_w, child_y + child_h, pattern_cfg)

    ImGui.Indent(ctx, 8)
    ImGui.Dummy(ctx, 0, 4)

    -- Header
    ImGui.PushFont(ctx, shell_state.fonts.bold, 14)
    ImGui.Text(ctx, "PARAMETER LIBRARY")
    ImGui.PopFont(ctx)

    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#888888"))
    local param_count = #self.unknown_params
    ImGui.Text(ctx, string.format("%d parameters • Drag to assign", param_count))
    ImGui.PopStyleColor(ctx)

    ImGui.Dummy(ctx, 0, 8)

    -- Draw library grid
    if param_count == 0 then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#666666"))
      ImGui.Text(ctx, "No additional parameters found")
      ImGui.PopStyleColor(ctx)
    else
      self.library_grid:draw(ctx)
    end

    ImGui.Unindent(ctx, 8)
    ImGui.Dummy(ctx, 0, 4)
    ImGui.EndChild(ctx)
  end
  ImGui.PopStyleColor(ctx)

  -- RIGHT PANEL: Assignment Grid
  ImGui.SameLine(ctx, 0, panel_gap)

  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#1A1A1A"))
  if ImGui.BeginChild(ctx, "assignment_grid", right_width, 0, 1) then
    local child_x, child_y = ImGui.GetWindowPos(ctx)
    local child_w, child_h = ImGui.GetWindowSize(ctx)
    local dl = ImGui.GetWindowDrawList(ctx)

    -- Background pattern
    local pattern_cfg = {
      enabled = true,
      primary = {type = 'grid', spacing = 50, color = PC.pattern_primary, line_thickness = 1.5},
      secondary = {enabled = true, type = 'grid', spacing = 5, color = PC.pattern_secondary, line_thickness = 0.5},
    }
    Background.draw(dl, child_x, child_y, child_x + child_w, child_y + child_h, pattern_cfg)

    ImGui.Indent(ctx, 8)
    ImGui.Dummy(ctx, 0, 4)

    -- Header
    ImGui.PushFont(ctx, shell_state.fonts.bold, 14)
    ImGui.Text(ctx, "ACTIVE ASSIGNMENTS")
    ImGui.PopFont(ctx)

    ImGui.Dummy(ctx, 0, 8)

    -- Tab bar
    self:draw_assignment_tab_bar(ctx, shell_state)

    ImGui.Dummy(ctx, 0, 8)

    -- Draw active assignment grid (ALWAYS draw, even when empty, to accept drops!)
    local active_grid = self.assignment_grids[self.active_assignment_tab]
    if active_grid then
      active_grid:draw(ctx)
    end

    ImGui.Unindent(ctx, 8)
    ImGui.Dummy(ctx, 0, 4)
    ImGui.EndChild(ctx)
  end
  ImGui.PopStyleColor(ctx)

  -- Group filter dialog
  if self.show_group_filter then
    self:draw_group_filter_dialog(ctx, shell_state)
  end
end

function AdditionalView:draw_assignment_tab_bar(ctx, shell_state)
  local tab_w = 60
  local tab_h = 28
  local tab_spacing = 4

  for i, tab_config in ipairs(TAB_CONFIGS) do
    if i > 1 then
      ImGui.SameLine(ctx, 0, tab_spacing)
    end

    local is_active = (self.active_assignment_tab == tab_config.id)
    local assigned_count = #self.assignments[tab_config.id]

    -- Tab button
    local bg_color = is_active and tab_config.color or hexrgb("#2A2A2A")
    local hover_color = tab_config.color
    local text_color = is_active and hexrgb("#FFFFFF") or hexrgb("#888888")

    ImGui.PushStyleColor(ctx, ImGui.Col_Button, bg_color)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, hover_color)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, tab_config.color)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, text_color)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameRounding, 4)

    local label = tab_config.label
    if assigned_count > 0 then
      label = label .. " (" .. assigned_count .. ")"
    end

    if ImGui.Button(ctx, label .. "##tab_" .. tab_config.id, tab_w + (assigned_count > 0 and 20 or 0), tab_h) then
      self.active_assignment_tab = tab_config.id
    end

    ImGui.PopStyleVar(ctx)
    ImGui.PopStyleColor(ctx, 4)

    -- Drop target for drag-and-drop
    if ImGui.BeginDragDropTarget(ctx) then
      local rv, payload = ImGui.AcceptDragDropPayload(ctx, "PARAM")
      if rv then
        self:assign_param_to_tab(payload, tab_config.id)
      end
      ImGui.EndDragDropTarget(ctx)
    end

    -- Tooltip
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, string.format("%s Tab (%d params)", tab_config.label, assigned_count))
    end
  end
end

function AdditionalView:draw_group_filter_dialog(ctx, shell_state)
  local open = true

  ImGui.SetNextWindowSize(ctx, 500, 600, ImGui.Cond_FirstUseEver)
  ImGui.SetNextWindowPos(ctx, 100, 100, ImGui.Cond_FirstUseEver)

  if ImGui.Begin(ctx, "Group Filter", true, ImGui.WindowFlags_NoCollapse) then
    ImGui.PushFont(ctx, shell_state.fonts.bold, 14)
    ImGui.Text(ctx, "Parameter Groups")
    ImGui.PopFont(ctx)

    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#888888"))
    ImGui.Text(ctx, "Show/hide groups of parameters")
    ImGui.PopStyleColor(ctx)

    ImGui.Dummy(ctx, 0, 8)

    -- Action buttons
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

function AdditionalView:export_parameters()
  local success, path = ThemeMapper.export_mappings(self.unknown_params)
  if success then
    reaper.ShowConsoleMsg(string.format("[ThemeAdjuster] Exported to: %s\n", path))
  else
    reaper.ShowConsoleMsg(string.format("[ThemeAdjuster] Export failed: %s\n", path))
  end
end

-- Assignment management methods
function AdditionalView:is_param_assigned(param_name, tab_id)
  if not self.assignments[tab_id] then return false end

  for _, assignment in ipairs(self.assignments[tab_id]) do
    if assignment.param_name == param_name then
      return true
    end
  end

  return false
end

function AdditionalView:get_assignment_count(param_name)
  local count = 0
  for tab_id, assignments in pairs(self.assignments) do
    for _, assignment in ipairs(assignments) do
      if assignment.param_name == param_name then
        count = count + 1
        break
      end
    end
  end
  return count
end

function AdditionalView:assign_param_to_tab(param_name, tab_id)
  if not self.assignments[tab_id] then
    self.assignments[tab_id] = {}
  end

  -- Check if already assigned
  if self:is_param_assigned(param_name, tab_id) then
    return false
  end

  -- Add to end of list
  local order = #self.assignments[tab_id] + 1
  table.insert(self.assignments[tab_id], {
    param_name = param_name,
    order = order
  })

  self:save_assignments()
  return true
end

function AdditionalView:assign_param_to_tab_at_index(param_name, tab_id, index)
  if not self.assignments[tab_id] then
    self.assignments[tab_id] = {}
  end

  -- Check if already assigned
  if self:is_param_assigned(param_name, tab_id) then
    -- If already assigned, reorder it to the new index
    for i, assignment in ipairs(self.assignments[tab_id]) do
      if assignment.param_name == param_name then
        local item = table.remove(self.assignments[tab_id], i)
        table.insert(self.assignments[tab_id], index, item)
        break
      end
    end
  else
    -- Insert at specified index
    table.insert(self.assignments[tab_id], index, {
      param_name = param_name,
      order = index
    })
  end

  -- Reorder remaining params
  for i, a in ipairs(self.assignments[tab_id]) do
    a.order = i
  end

  self:save_assignments()
  return true
end

function AdditionalView:unassign_param_from_tab(param_name, tab_id)
  if not self.assignments[tab_id] then return false end

  for i, assignment in ipairs(self.assignments[tab_id]) do
    if assignment.param_name == param_name then
      table.remove(self.assignments[tab_id], i)
      -- Reorder remaining params
      for j, a in ipairs(self.assignments[tab_id]) do
        a.order = j
      end
      self:save_assignments()
      return true
    end
  end

  return false
end

function AdditionalView:reorder_assignments(tab_id, new_order_keys)
  if not self.assignments[tab_id] then return false end

  -- Build lookup table
  local assignments_by_key = {}
  for _, assignment in ipairs(self.assignments[tab_id]) do
    local key = "assign_" .. assignment.param_name
    assignments_by_key[key] = assignment
  end

  -- Build new ordered list
  local new_assignments = {}
  for _, key in ipairs(new_order_keys) do
    local assignment = assignments_by_key[key]
    if assignment then
      table.insert(new_assignments, assignment)
    end
  end

  -- Update orders
  for i, assignment in ipairs(new_assignments) do
    assignment.order = i
  end

  self.assignments[tab_id] = new_assignments
  self:save_assignments()
  return true
end

function AdditionalView:get_assigned_params(tab_id)
  local assigned = {}

  if not self.assignments[tab_id] then
    return assigned
  end

  -- Build param lookup table
  local param_lookup = {}
  for _, param in ipairs(self.unknown_params) do
    param_lookup[param.name] = param
  end

  -- Get assigned params in order
  for _, assignment in ipairs(self.assignments[tab_id]) do
    local param = param_lookup[assignment.param_name]
    if param then
      -- Clone param
      local param_copy = {}
      for k, v in pairs(param) do
        param_copy[k] = v
      end

      -- Attach custom metadata
      local metadata = self.custom_metadata[param.name]
      if metadata then
        param_copy.display_name = metadata.display_name or param.name
        param_copy.description = metadata.description or ""
      else
        param_copy.display_name = param.name
        param_copy.description = ""
      end

      table.insert(assigned, param_copy)
    end
  end

  return assigned
end

function AdditionalView:load_assignments()
  -- Load assignments from JSON file
  local mappings = ThemeMapper.load_current_mappings()

  if mappings and mappings.assignments then
    -- Check format
    local is_old_format = false
    for key, value in pairs(mappings.assignments) do
      if type(value) == "table" and value.TCP ~= nil then
        is_old_format = true
        break
      elseif type(value) == "table" and type(value[1]) == "table" then
        is_old_format = false
        break
      end
    end

    if is_old_format then
      -- Convert old format to new format
      local new_assignments = {
        TCP = {},
        MCP = {},
        ENVCP = {},
        TRANS = {},
        GLOBAL = {}
      }

      for param_name, assignment in pairs(mappings.assignments) do
        for tab_id, is_assigned in pairs(assignment) do
          if is_assigned and new_assignments[tab_id] then
            table.insert(new_assignments[tab_id], {
              param_name = param_name,
              order = #new_assignments[tab_id] + 1
            })
          end
        end
      end

      self.assignments = new_assignments
    else
      -- Already new format
      self.assignments = mappings.assignments
      -- Ensure all tabs exist
      for _, tab_id in ipairs({"TCP", "MCP", "ENVCP", "TRANS", "GLOBAL"}) do
        if not self.assignments[tab_id] then
          self.assignments[tab_id] = {}
        end
      end
    end
  else
    -- Initialize empty assignments
    self.assignments = {
      TCP = {},
      MCP = {},
      ENVCP = {},
      TRANS = {},
      GLOBAL = {}
    }
  end

  if mappings and mappings.custom_metadata then
    self.custom_metadata = mappings.custom_metadata
  else
    self.custom_metadata = {}
  end

  -- Load group filter state
  if mappings and mappings.enabled_groups then
    for group_name, enabled in pairs(mappings.enabled_groups) do
      self.enabled_groups[group_name] = enabled
    end
    self:apply_group_filter()
  end
end

function AdditionalView:set_cache_invalidation_callback(callback)
  self.cache_invalidation_callback = callback
end

function AdditionalView:save_assignments()
  local success = ThemeMapper.save_assignments(self.assignments, self.custom_metadata, self.enabled_groups)

  -- Invalidate TCP/MCP caches
  if self.cache_invalidation_callback then
    self.cache_invalidation_callback()
  end

  return success
end

function AdditionalView:save_group_filter()
  ThemeMapper.save_assignments(self.assignments, self.custom_metadata, self.enabled_groups)

  if self.cache_invalidation_callback then
    self.cache_invalidation_callback()
  end
end

return M
