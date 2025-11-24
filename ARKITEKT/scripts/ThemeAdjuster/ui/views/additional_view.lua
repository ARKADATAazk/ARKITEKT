-- @noindex
-- ThemeAdjuster/ui/views/additional_view.lua
-- Additional parameters tab - Grid-based tile manager

local ImGui = require 'imgui' '0.10'
local Checkbox = require('arkitekt.gui.widgets.primitives.checkbox')
local Button = require('arkitekt.gui.widgets.primitives.button')
local Background = require('arkitekt.gui.widgets.containers.panel.background')
local Style = require('arkitekt.gui.style.defaults')
local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb
local Constants = require('ThemeAdjuster.defs.constants')
local ParamDiscovery = require('ThemeAdjuster.core.param_discovery')
local ThemeMapper = require('ThemeAdjuster.core.theme_mapper')
local ThemeParams = require('ThemeAdjuster.core.theme_params')
local ParameterLinkManager = require('ThemeAdjuster.core.parameter_link_manager')
local GridBridge = require('arkitekt.gui.widgets.containers.grid.grid_bridge')
local LibraryGridFactory = require('ThemeAdjuster.ui.grids.library_grid_factory')
local TemplatesGridFactory = require('ThemeAdjuster.ui.grids.templates_grid_factory')
local AssignmentGridFactory = require('ThemeAdjuster.ui.grids.assignment_grid_factory')
local ParamLinkModal = require('ThemeAdjuster.ui.views.param_link_modal')
local AdditionalParamTile = require('ThemeAdjuster.ui.grids.renderers.additional_param_tile')

local PC = Style.PANEL_COLORS

local M = {}
local AdditionalView = {}
AdditionalView.__index = AdditionalView

-- Tab configurations (using shared THEME_CATEGORY_COLORS palette)
local TC = Constants.THEME_CATEGORY_COLORS
local TAB_CONFIGS = {
  {id = "TCP", label = "TCP", color = TC.tcp_blue},
  {id = "MCP", label = "MCP", color = TC.mcp_green},
  {id = "ENVCP", label = "ENVCP", color = TC.envcp_purple},
  {id = "TRANS", label = "TRANSPORT", color = TC.transport_gold},
  {id = "GLOBAL", label = "GLOBAL", color = TC.global_gray},
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
    group_collapsed_states = {},  -- group_name -> true/false (collapsed state)

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

    -- Templates: id -> {id, name, type, params[], config{}}
    templates = {},
    next_template_id = 1,

    -- Template groups: organized into collapsible groups
    template_groups = {},  -- array of {id, name, color, collapsed, template_ids[]}
    next_template_group_id = 1,
    template_group_collapsed_states = {},  -- group_id -> true/false

    -- Grid instances
    library_grid = nil,
    templates_grid = nil,
    assignment_grids = {},  -- tab_id -> grid
    bridge = nil,

    -- Tab color lookup
    tab_colors = {},

    -- Control rectangles for exclusion zones (prevent drag on interactive controls)
    control_rects = {},  -- param_index -> list of {x1, y1, x2, y2}

    -- Callback to invalidate caches in TCP/MCP views
    cache_invalidation_callback = nil,

    -- ImGui context (needed for GridBridge)
    _imgui_ctx = nil,

    -- Right-click selection state
    right_click_sel = {
      active = false,
      start_x = 0,
      start_y = 0,
      current_x = 0,
      current_y = 0,
      target_grid = nil,
    },
  }, AdditionalView)

  -- Build tab color lookup table
  for _, tab_config in ipairs(TAB_CONFIGS) do
    self.tab_colors[tab_config.id] = tab_config.color
  end

  -- Discover parameters on init
  self:refresh_params()

  -- Load assignments from JSON if available
  self:load_assignments()

  -- Create grids
  self:create_grids()

  -- Create parameter link modal
  self.param_link_modal = ParamLinkModal.new(self)

  return self
end

function AdditionalView:create_grids()
  -- Create library grid
  self.library_grid = LibraryGridFactory.create(self, {padding = 8})

  -- Create templates grid
  self.templates_grid = TemplatesGridFactory.create(self, {padding = 8})

  -- Create assignment grids for each tab
  for _, tab_config in ipairs(TAB_CONFIGS) do
    self.assignment_grids[tab_config.id] = AssignmentGridFactory.create(self, tab_config.id, {padding = 8})
  end

  -- Create GridBridge to coordinate drag-drop
  self.bridge = GridBridge.new({
    copy_mode_detector = function(source, target, payload)
      -- Library → Templates/Assignment: always copy
      if source == 'library' or source == 'templates' then
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

      -- Library → Templates: create template from parameters
      if source_id == 'library' and target_id == 'templates' then
        self:create_template_from_params(payload, insert_index)
        return
      end

      -- Templates → Assignment: assign template or group
      if source_id == 'templates' and target_id:match("^assign_(.+)") then
        local tab_id = target_id:match("^assign_(.+)")
        for i, item in ipairs(payload) do
          if item.type == "group" then
            -- Assign group
            self:assign_template_group_to_tab(item.id, tab_id, insert_index + i - 1)
          elseif item.type == "template" then
            -- Assign individual template
            self:assign_template_to_tab(item.id, tab_id, insert_index + i - 1)
          end
        end
        return
      end

      -- Library → Assignment: assign parameters directly (backwards compat)
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
      -- Filter out group headers - they should not be draggable
      local param_names = {}
      local params = self:get_library_items()
      local params_by_key = {}
      for _, param in ipairs(params) do
        params_by_key[self.library_grid.key(param)] = param
      end

      for _, key in ipairs(item_keys) do
        -- Skip group headers
        if not key:match("^group_header_") then
          local param = params_by_key[key]
          if param then
            table.insert(param_names, param.name)
          end
        end
      end

      -- Only start drag if we have actual parameters
      if #param_names > 0 then
        self.bridge:start_drag('library', param_names)
      end
    end,
  })

  -- Register templates grid
  self.bridge:register_grid('templates', self.templates_grid, {
    accepts_drops_from = {'library'},
    on_drag_start = function(item_keys)
      -- Extract template IDs and group IDs from keys
      local payload = {}
      for _, key in ipairs(item_keys) do
        if key:match("^template_group_header_") then
          -- This is a group
          local group_id = key:match("^template_group_header_(.+)")
          if group_id then
            table.insert(payload, {type = "group", id = group_id})
          end
        else
          -- This is a template
          local template_id = key:match("^template_(.+)")
          if template_id then
            table.insert(payload, {type = "template", id = template_id})
          end
        end
      end

      self.bridge:start_drag('templates', payload)
    end,
  })

  -- Register assignment grids
  for _, tab_config in ipairs(TAB_CONFIGS) do
    local grid_id = "assign_" .. tab_config.id
    local grid = self.assignment_grids[tab_config.id]

    self.bridge:register_grid(grid_id, grid, {
      accepts_drops_from = {'library', 'templates', 'assign_TCP', 'assign_MCP', 'assign_ENVCP', 'assign_TRANS', 'assign_GLOBAL'},
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
  -- Use TileGroup to flatten param_groups into a flat list for the Grid
  local TileGroup = require('arkitekt.gui.widgets.containers.tile_group')

  -- Convert param_groups to TileGroup structures
  local tile_groups = {}
  for _, group in ipairs(self.param_groups) do
    -- Only include enabled groups
    if self.enabled_groups[group.name] then
      -- Get collapsed state from persisted data (default to false)
      local collapsed = self.group_collapsed_states[group.name]
      if collapsed == nil then
        collapsed = false
      end

      table.insert(tile_groups, TileGroup.create_group({
        id = group.name,
        name = group.display_name or group.name,
        color = group.color,
        collapsed = collapsed,
        items = group.params
      }))
    end
  end

  -- Flatten groups into a single list (no ungrouped items since all params are grouped)
  return TileGroup.flatten_groups(tile_groups, {})
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
    if assignment.type == "group" then
      -- This is a group assignment
      table.insert(items, {
        type = "group",
        group_id = assignment.group_id,
        order = assignment.order,
      })
    elseif assignment.param_name and param_lookup[assignment.param_name] then
      -- This is a parameter assignment
      table.insert(items, {
        type = "param",
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

  -- Three-panel layout: LEFT = Parameter Library | MIDDLE = Templates | RIGHT = Assignment Grid
  local panel_gap = 12
  local left_width = avail_w * 0.35 - panel_gap
  local middle_width = avail_w * 0.25 - panel_gap
  local right_width = avail_w * 0.40

  -- LEFT PANEL: Parameter Library
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#1A1A1A"))
  -- Use modern 5-parameter API: BeginChild(ctx, id, w, h, child_flags, window_flags)
  -- WindowFlags_NoMove prevents window dragging, but allows scrolling
  local child_flags = ImGui.ChildFlags_None or 0
  local window_flags = ImGui.WindowFlags_NoMove or 0  -- ONLY NoMove, allow scrolling!
  if ImGui.BeginChild(ctx, "param_library", left_width, 0, child_flags, window_flags) then
    local child_x, child_y = ImGui.GetWindowPos(ctx)
    local child_w, child_h = ImGui.GetWindowSize(ctx)
    local dl = ImGui.GetWindowDrawList(ctx)

    -- Background pattern
    local pattern_cfg = {
      enabled = true,
      primary = {type = 'grid', spacing = 50, color = PC.pattern_primary, line_thickness = 1.5},
      secondary = {enabled = true, type = 'grid', spacing = 5, color = PC.pattern_secondary, line_thickness = 0.5},
    }
    Background.draw(ctx, dl, child_x, child_y, child_x + child_w, child_y + child_h, pattern_cfg)

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

      -- Handle right-click drag selection for library grid
      self:handle_right_click_selection(ctx, self.library_grid, "library")
    end

    ImGui.Unindent(ctx, 8)
    ImGui.Dummy(ctx, 0, 4)
    ImGui.EndChild(ctx)
  end
  ImGui.PopStyleColor(ctx)

  -- MIDDLE PANEL: Templates
  ImGui.SameLine(ctx, 0, panel_gap)

  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#1E1E28"))
  if ImGui.BeginChild(ctx, "templates_grid", middle_width, 0, child_flags, window_flags) then
    local child_x, child_y = ImGui.GetWindowPos(ctx)
    local child_w, child_h = ImGui.GetWindowSize(ctx)
    local dl = ImGui.GetWindowDrawList(ctx)

    -- Background pattern
    local pattern_cfg = {
      enabled = true,
      primary = {type = 'grid', spacing = 50, color = PC.pattern_primary, line_thickness = 1.5},
      secondary = {enabled = true, type = 'grid', spacing = 5, color = PC.pattern_secondary, line_thickness = 0.5},
    }
    Background.draw(ctx, dl, child_x, child_y, child_x + child_w, child_y + child_h, pattern_cfg)

    ImGui.Indent(ctx, 8)
    ImGui.Dummy(ctx, 0, 4)

    -- Header
    ImGui.PushFont(ctx, shell_state.fonts.bold, 14)
    ImGui.Text(ctx, "TEMPLATES")
    ImGui.PopFont(ctx)

    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#888888"))
    local template_count = 0
    for _ in pairs(self.templates) do template_count = template_count + 1 end
    ImGui.Text(ctx, string.format("%d templates • Drag to use", template_count))
    ImGui.PopStyleColor(ctx)

    ImGui.Dummy(ctx, 0, 8)

    -- Draw templates grid
    self.templates_grid:draw(ctx)

    ImGui.Unindent(ctx, 8)
    ImGui.Dummy(ctx, 0, 4)
    ImGui.EndChild(ctx)
  end
  ImGui.PopStyleColor(ctx)

  -- RIGHT PANEL: Assignment Grid
  ImGui.SameLine(ctx, 0, panel_gap)

  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#1A1A1A"))
  if ImGui.BeginChild(ctx, "assignment_grid", right_width, 0, child_flags, window_flags) then
    local child_x, child_y = ImGui.GetWindowPos(ctx)
    local child_w, child_h = ImGui.GetWindowSize(ctx)
    local dl = ImGui.GetWindowDrawList(ctx)

    -- Background pattern
    local pattern_cfg = {
      enabled = true,
      primary = {type = 'grid', spacing = 50, color = PC.pattern_primary, line_thickness = 1.5},
      secondary = {enabled = true, type = 'grid', spacing = 5, color = PC.pattern_secondary, line_thickness = 0.5},
    }
    Background.draw(ctx, dl, child_x, child_y, child_x + child_w, child_y + child_h, pattern_cfg)

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

      -- Handle right-click drag selection for assignment grid
      self:handle_right_click_selection(ctx, active_grid, "assign_" .. self.active_assignment_tab)
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

  -- Handle link handle interactions
  self:handle_link_handle_interactions(ctx)

  -- Parameter link modal
  if self.param_link_modal then
    self.param_link_modal:render(ctx, shell_state)
  end

  -- Template configuration dialogs (from assignment tiles)
  local AssignmentTile = require('ThemeAdjuster.ui.grids.renderers.assignment_tile')
  AssignmentTile.render_template_config_dialogs(ctx, self)

  -- Template configuration dialogs (from template tiles)
  local TemplateTile = require('ThemeAdjuster.ui.grids.renderers.template_tile')
  TemplateTile.render_template_config_dialogs(ctx, self)

  -- Template group configuration dialogs
  local TemplateGroupConfig = require('ThemeAdjuster.ui.grids.renderers.template_group_config')
  TemplateGroupConfig.render_config_dialogs(ctx, self)
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
        -- After removal, array is shorter - clamp index to valid range
        local max_index = #self.assignments[tab_id] + 1
        local safe_index = math.min(index, max_index)
        table.insert(self.assignments[tab_id], safe_index, item)
        break
      end
    end
  else
    -- Insert at specified index (clamp to valid range)
    local max_index = #self.assignments[tab_id] + 1
    local safe_index = math.min(index, max_index)
    table.insert(self.assignments[tab_id], safe_index, {
      param_name = param_name,
      order = safe_index
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

function AdditionalView:unassign_group_from_tab(group_id, tab_id)
  if not self.assignments[tab_id] then return false end

  for i, assignment in ipairs(self.assignments[tab_id]) do
    if assignment.type == "group" and assignment.group_id == group_id then
      table.remove(self.assignments[tab_id], i)
      -- Reorder remaining assignments
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
    -- Check if this is a group assignment
    if assignment.type == "group" and assignment.group_id then
      -- Find the group
      local group = nil
      for _, g in ipairs(self.template_groups) do
        if g.id == assignment.group_id then
          group = g
          break
        end
      end

      -- Create a single "group control" pseudo-parameter (macro)
      if group then
        table.insert(assigned, {
          type = "group",
          group_id = group.id,
          name = group.name or "Unnamed Group",
          display_name = group.name or "Unnamed Group",
          description = "Group macro controlling " .. #(group.template_ids or {}) .. " templates",
          is_group = true,  -- Flag for special rendering
        })
      end

    -- Regular parameter assignment
    elseif assignment.param_name then
      local param = param_lookup[assignment.param_name]
      if param then
        -- Clone param
        local param_copy = {}
        for k, v in pairs(param) do
          param_copy[k] = v
        end

        -- Attach template_id if this param is part of a template
        if assignment.template_id then
          param_copy.template_id = assignment.template_id
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
  end

  return assigned
end

-- Get the assignment object for a specific parameter (searches all tabs)
function AdditionalView:get_assignment_for_param(param_name)
  for tab_id, assignments in pairs(self.assignments) do
    for _, assignment in ipairs(assignments) do
      if assignment.param_name == param_name then
        return assignment
      end
    end
  end
  return nil
end

-- Helper to get param by name
function AdditionalView:get_param_by_name(param_name)
  for _, param in ipairs(self.all_params) do
    if param.name == param_name then
      return param
    end
  end
  return nil
end

--- Template Management Methods ---

-- Get template items for grid
function AdditionalView:get_template_items()
  local TileGroup = require('arkitekt.gui.widgets.containers.tile_group')

  -- Build tile groups from template_groups
  local tile_groups = {}
  for _, group in ipairs(self.template_groups) do
    -- Get collapsed state
    local collapsed = self.template_group_collapsed_states[group.id]
    if collapsed == nil then
      collapsed = false
    end

    -- Build items array for this group
    local group_items = {}
    for _, template_id in ipairs(group.template_ids or {}) do
      if self.templates[template_id] then
        table.insert(group_items, {
          id = template_id,
          order = self.templates[template_id].order or 0
        })
      end
    end

    table.insert(tile_groups, TileGroup.create_group({
      id = group.id,
      name = group.name or ("Group " .. group.id),
      color = group.color,
      collapsed = collapsed,
      items = group_items
    }))
  end

  -- Get ungrouped templates
  local grouped_template_ids = {}
  for _, group in ipairs(self.template_groups) do
    for _, template_id in ipairs(group.template_ids or {}) do
      grouped_template_ids[template_id] = true
    end
  end

  local ungrouped = {}
  for id, template in pairs(self.templates) do
    if not grouped_template_ids[id] then
      table.insert(ungrouped, {
        id = id,
        order = template.order or 0
      })
    end
  end

  -- Sort ungrouped by order
  table.sort(ungrouped, function(a, b) return a.order < b.order end)

  -- Flatten groups into a single list
  return TileGroup.flatten_groups(tile_groups, ungrouped)
end

-- Create template from parameters
function AdditionalView:create_template_from_params(param_names, insert_index)
  -- If single param, create a simple template (ungrouped)
  if #param_names == 1 then
    local template_id = tostring(self.next_template_id)
    self.next_template_id = self.next_template_id + 1

    local template = {
      id = template_id,
      name = param_names[1],
      type = "preset_spinner",  -- Default type
      params = param_names,
      config = {},
      order = insert_index or (#self.templates + 1)
    }

    self.templates[template_id] = template
    self:save_templates()

    return template_id
  end

  -- If multiple params, create a template group
  local group_id = tostring(self.next_template_group_id)
  self.next_template_group_id = self.next_template_group_id + 1

  local template_ids = {}

  -- Create a template for each parameter
  for _, param_name in ipairs(param_names) do
    local template_id = tostring(self.next_template_id)
    self.next_template_id = self.next_template_id + 1

    local template = {
      id = template_id,
      name = param_name,
      type = "preset_spinner",
      params = {param_name},
      config = {},
      order = self.next_template_id
    }

    self.templates[template_id] = template
    table.insert(template_ids, template_id)
  end

  -- Create the template group
  local group = {
    id = group_id,
    name = "Group " .. group_id,  -- User can rename later
    color = string.format("#%06X", math.random(0x333333, 0xCCCCCC)),  -- Random color
    collapsed = false,
    template_ids = template_ids
  }

  table.insert(self.template_groups, group)
  self:save_templates()

  return group_id
end

-- Delete template
function AdditionalView:delete_template(template_id)
  self.templates[template_id] = nil
  self:save_templates()
end

-- Reorder templates and handle group membership changes
function AdditionalView:reorder_templates(new_order_keys)
  -- Build a map to track which group each position belongs to
  local current_group_id = nil
  local position_to_group = {}  -- position -> group_id or nil
  local new_group_memberships = {}  -- group_id -> {template_ids}

  -- Initialize group memberships
  for _, group in ipairs(self.template_groups) do
    new_group_memberships[group.id] = {}
  end

  -- Analyze the new order to determine group memberships
  for pos, key in ipairs(new_order_keys) do
    if key:match("^template_group_header_") then
      -- This is a group header
      local group_id = key:match("^template_group_header_(.+)")
      current_group_id = group_id
      position_to_group[pos] = nil  -- Headers don't belong to groups
    else
      -- This is a template
      local template_id = key:match("^template_(.+)")
      if template_id then
        if current_group_id then
          -- Template is inside a group
          table.insert(new_group_memberships[current_group_id], template_id)
        end
        -- Update template order
        if self.templates[template_id] then
          self.templates[template_id].order = pos
        end
      end
    end
  end

  -- Update all group memberships
  for group_id, new_template_ids in pairs(new_group_memberships) do
    for _, group in ipairs(self.template_groups) do
      if group.id == group_id then
        group.template_ids = new_template_ids
        break
      end
    end
  end

  self:save_templates()
end

-- Assign template to tab
function AdditionalView:assign_template_to_tab(template_id, tab_id, index)
  local template = self.templates[template_id]
  if not template then return end

  -- For now, just assign all params from the template
  -- Later we'll store template reference in assignment
  for i, param_name in ipairs(template.params) do
    local target_index = index and (index + i - 1) or nil
    self:assign_param_to_tab_at_index(param_name, tab_id, target_index)

    -- Mark assignment as using template
    local assignment = self:get_assignment_for_param(param_name)
    if assignment then
      assignment.template_id = template_id
    end
  end

  self:save_assignments()
end

-- Assign template group to tab (as a unified control)
function AdditionalView:assign_template_group_to_tab(group_id, tab_id, index)
  if not self.assignments[tab_id] then
    self.assignments[tab_id] = {}
  end

  -- Find the group
  local group = nil
  for _, g in ipairs(self.template_groups) do
    if g.id == group_id then
      group = g
      break
    end
  end

  if not group then return end

  -- Insert at specified index (clamp to valid range)
  local max_index = #self.assignments[tab_id] + 1
  local safe_index = index and math.min(index, max_index) or max_index

  -- Create a group assignment (different from individual param assignment)
  table.insert(self.assignments[tab_id], safe_index, {
    type = "group",
    group_id = group_id,
    order = safe_index
  })

  -- Reorder remaining assignments
  for i, a in ipairs(self.assignments[tab_id]) do
    a.order = i
  end

  self:save_assignments()
end

-- Delete template group
function AdditionalView:delete_template_group(group_id)
  -- Remove from template_groups array
  for i, group in ipairs(self.template_groups) do
    if group.id == group_id then
      -- Delete all templates in the group
      for _, template_id in ipairs(group.template_ids or {}) do
        self.templates[template_id] = nil
      end

      table.remove(self.template_groups, i)
      break
    end
  end

  -- Remove from collapsed states
  self.template_group_collapsed_states[group_id] = nil

  self:save_templates()
end

-- Save templates to disk
function AdditionalView:save_templates()
  -- Templates are saved as part of assignments
  self:save_assignments()
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

  -- Load group collapsed states
  if mappings and mappings.group_collapsed_states then
    for group_name, collapsed in pairs(mappings.group_collapsed_states) do
      self.group_collapsed_states[group_name] = collapsed
    end
  end

  -- Load parameter link groups
  if mappings and mappings.parameter_link_data then
    ParameterLinkManager.set_all_data(mappings.parameter_link_data)
  end

  -- Load templates
  if mappings and mappings.templates then
    self.templates = mappings.templates
    -- Find max template ID
    local max_id = 0
    for id, _ in pairs(self.templates) do
      local num_id = tonumber(id)
      if num_id and num_id > max_id then
        max_id = num_id
      end
    end
    self.next_template_id = max_id + 1
  end

  -- Load template groups
  if mappings and mappings.template_groups then
    self.template_groups = mappings.template_groups
    -- Find max template group ID
    local max_group_id = 0
    for _, group in ipairs(self.template_groups) do
      local num_id = tonumber(group.id)
      if num_id and num_id > max_group_id then
        max_group_id = num_id
      end
    end
    self.next_template_group_id = max_group_id + 1
  end

  -- Load template group collapsed states
  if mappings and mappings.template_group_collapsed_states then
    self.template_group_collapsed_states = mappings.template_group_collapsed_states
  end
end

function AdditionalView:set_cache_invalidation_callback(callback)
  self.cache_invalidation_callback = callback
end

function AdditionalView:save_assignments()
  local param_link_data = ParameterLinkManager.get_all_data()
  local success = ThemeMapper.save_assignments(
    self.assignments,
    self.custom_metadata,
    self.enabled_groups,
    param_link_data,
    self.templates,
    self.group_collapsed_states,
    self.template_groups,
    self.template_group_collapsed_states
  )

  -- Invalidate TCP/MCP caches
  if self.cache_invalidation_callback then
    self.cache_invalidation_callback()
  end

  return success
end

function AdditionalView:save_group_filter()
  local param_link_data = ParameterLinkManager.get_all_data()
  ThemeMapper.save_assignments(
    self.assignments,
    self.custom_metadata,
    self.enabled_groups,
    param_link_data,
    self.templates,
    self.group_collapsed_states,
    self.template_groups,
    self.template_group_collapsed_states
  )

  if self.cache_invalidation_callback then
    self.cache_invalidation_callback()
  end
end

-- Right-click drag selection handler
function AdditionalView:handle_right_click_selection(ctx, grid, grid_id)
  if not grid or not grid.grid_bounds then return end

  local mx, my = ImGui.GetMousePos(ctx)
  local gb = grid.grid_bounds
  local is_over_grid = mx >= gb[1] and mx <= gb[3] and my >= gb[2] and my <= gb[4]

  -- Start right-click drag
  if is_over_grid and ImGui.IsMouseClicked(ctx, ImGui.MouseButton_Right) then
    self.right_click_sel.active = true
    self.right_click_sel.start_x = mx
    self.right_click_sel.start_y = my
    self.right_click_sel.current_x = mx
    self.right_click_sel.current_y = my
    self.right_click_sel.target_grid = grid_id
  end

  -- Update right-click drag
  if self.right_click_sel.active and self.right_click_sel.target_grid == grid_id then
    if ImGui.IsMouseDragging(ctx, ImGui.MouseButton_Right, 5) then
      self.right_click_sel.current_x = mx
      self.right_click_sel.current_y = my

      -- Select items within rectangle
      local x1 = math.min(self.right_click_sel.start_x, self.right_click_sel.current_x)
      local y1 = math.min(self.right_click_sel.start_y, self.right_click_sel.current_y)
      local x2 = math.max(self.right_click_sel.start_x, self.right_click_sel.current_x)
      local y2 = math.max(self.right_click_sel.start_y, self.right_click_sel.current_y)

      -- Check Ctrl for additive selection
      local ctrl = ImGui.IsKeyDown(ctx, ImGui.Key_LeftCtrl) or ImGui.IsKeyDown(ctx, ImGui.Key_RightCtrl)

      if not ctrl then
        grid.selection:clear()
      end

      -- Select all items intersecting the rectangle
      local items = grid.get_items()
      for _, item in ipairs(items) do
        local key = grid.key(item)
        local rect = grid.rect_track:get(key)
        if rect then
          local rx1, ry1, rx2, ry2 = rect[1], rect[2], rect[3], rect[4]
          -- Check rectangle intersection
          if not (rx2 < x1 or rx1 > x2 or ry2 < y1 or ry1 > y2) then
            grid.selection.selected[key] = true
          end
        end
      end

      -- Draw selection rectangle
      local dl = ImGui.GetWindowDrawList(ctx)
      ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, hexrgb("#5588FF22"), 3)
      ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, hexrgb("#5588FFAA"), 3, 0, 1.5)
    end

    -- End right-click drag
    if ImGui.IsMouseReleased(ctx, ImGui.MouseButton_Right) then
      self.right_click_sel.active = false
      self.right_click_sel.target_grid = nil
    end
  end
end

-- Handle link handle interactions (right-click to open modal)
function AdditionalView:handle_link_handle_interactions(ctx)
  local LibraryTile = require('ThemeAdjuster.ui.grids.renderers.library_tile')

  -- Check for right-click on any link handle
  if ImGui.IsMouseClicked(ctx, ImGui.MouseButton_Right) then
    local mx, my = ImGui.GetMousePos(ctx)

    -- Check all stored link handle rects
    for handle_key, rect in pairs(LibraryTile._link_handle_rects) do
      local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]

      if mx >= x1 and mx <= x2 and my >= y1 and my <= y2 then
        -- Extract param name from handle key
        local param_name = handle_key:gsub("^handle_", "")

        -- Find the parameter to get its type
        for _, param in ipairs(self.all_params) do
          if param.name == param_name then
            -- Open the modal
            self.param_link_modal:show(param_name, param.type)
            break
          end
        end

        break  -- Only handle one click
      end
    end
  end
end

return M
