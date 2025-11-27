-- @noindex
-- WalterBuilder/ui/gui.lua
-- Main GUI orchestrator - combines all panels

local ImGui = require 'imgui' '0.10'
local ark = require('arkitekt')
local State = require('WalterBuilder.app.state')
local PreviewCanvas = require('WalterBuilder.ui.canvas.preview_canvas')
local ElementRenderer = require('WalterBuilder.ui.canvas.element_renderer')
local ElementsPanel = require('WalterBuilder.ui.panels.elements_panel')
local PropertiesPanel = require('WalterBuilder.ui.panels.properties_panel')
local TrackPropertiesPanel = require('WalterBuilder.ui.panels.track_properties_panel')
local CodePanel = require('WalterBuilder.ui.panels.code_panel')
local TCPElements = require('WalterBuilder.defs.tcp_elements')
local Constants = require('WalterBuilder.defs.constants')
local Notification = require('WalterBuilder.domain.notification')

local hexrgb = ark.Colors.hexrgb

local M = {}
local GUI = {}
GUI.__index = GUI

function M.new(state_module, settings, controller)
  local self = setmetatable({
    State = state_module,
    settings = settings,
    controller = controller,
    initialized = false,

    -- Panels
    canvas = nil,
    elements_panel = nil,
    properties_panel = nil,
    track_properties_panel = nil,
    code_panel = nil,

    -- Notification system
    notification = Notification.new(),

    -- Layout
    left_panel_width = Constants.PANEL.LEFT_WIDTH,
    right_panel_width = Constants.PANEL.RIGHT_WIDTH,
  }, GUI)

  -- Wire up controller callbacks
  if controller then
    controller.on_status = function(message, msg_type)
      self.notification:set_message(message, msg_type)
    end

    controller.on_elements_changed = function()
      self:sync_canvas()
      self.code_panel:invalidate()
    end

    controller.on_tracks_changed = function()
      self:sync_canvas()
    end

    controller.on_selection_changed = function()
      self.properties_panel:set_element(self.State.get_selected())
      self.track_properties_panel:set_track(self.State.get_selected_track())
      self.canvas:set_selected(self.State.get_selected())
      self.canvas:set_selected_track(self.State.get_selected_track())
    end
  end

  return self
end

function GUI:initialize_once(ctx)
  if self.initialized then return end

  -- Create canvas
  local parent_w, parent_h = self.State.get_parent_size()
  self.canvas = PreviewCanvas.new({
    parent_w = parent_w,
    parent_h = parent_h,
    show_grid = self.State.get_show_grid(),
    show_attachments = self.State.get_show_attachments(),
    view_mode = PreviewCanvas.VIEW_TRACKS,  -- Start in tracks view
  })

  -- Create panels
  self.elements_panel = ElementsPanel.new({
    on_add = function(def)
      return self:handle_add_element(def)
    end,
  })

  self.properties_panel = PropertiesPanel.new({
    on_change = function(element)
      self:handle_element_changed(element)
    end,
    on_delete = function(element)
      self:handle_delete_element(element)
    end,
  })

  self.track_properties_panel = TrackPropertiesPanel.new({
    on_change = function(track)
      self:handle_track_changed(track)
    end,
    on_delete = function(track)
      self:handle_delete_track(track)
    end,
    on_add = function()
      self:handle_add_track()
    end,
  })

  self.code_panel = CodePanel.new()

  -- Load default tracks if none exist
  if #self.State.get_tracks() == 0 then
    self.State.load_default_tracks()
  end

  -- Update canvas with current elements and tracks
  self:sync_canvas()

  -- Load settings
  if self.settings then
    self.left_panel_width = self.settings:get('left_panel_width', 200)
    self.right_panel_width = self.settings:get('right_panel_width', 280)
  end

  self.initialized = true
end

-- Sync canvas with state
function GUI:sync_canvas()
  local elements = self.State.get_elements()
  local tracks = self.State.get_tracks()
  self.canvas:set_elements(elements)
  self.canvas:set_tracks(tracks)
  self.elements_panel:set_active_elements(self.State.get_element_ids())
  self.code_panel:set_elements(elements)
end

-- Handle adding an element
function GUI:handle_add_element(def)
  if self.controller then
    local elem = self.controller:add_element(def)
    if elem then
      self.canvas:set_selected(elem)
      self.properties_panel:set_element(elem)
    end
  else
    local elem = self.State.add_element(def)
    if elem then
      self.State.set_selected(elem)
      self:sync_canvas()
      self.canvas:set_selected(elem)
      self.properties_panel:set_element(elem)
      self.code_panel:invalidate()
    end
  end
end

-- Handle element changes
function GUI:handle_element_changed(element)
  if self.controller then
    self.controller:update_element(element, {})  -- Element already modified
  else
    self.State.element_changed(element)
  end
  self.canvas.sim_cache = nil  -- Invalidate simulation cache
  self.code_panel:invalidate()
end

-- Handle element deletion
function GUI:handle_delete_element(element)
  if self.controller then
    self.controller:remove_element(element)
    self.canvas:set_selected(nil)
    self.properties_panel:set_element(nil)
  else
    self.State.remove_element(element)
    self.State.clear_selection()
    self.canvas:set_selected(nil)
    self.properties_panel:set_element(nil)
    self:sync_canvas()
    self.code_panel:invalidate()
  end
end

-- Handle track changes
function GUI:handle_track_changed(track)
  if self.controller then
    self.controller:update_track(track, {})  -- Track already modified
  end
  self.canvas.sim_cache = nil  -- Invalidate simulation cache
end

-- Handle track deletion
function GUI:handle_delete_track(track)
  if self.controller then
    self.controller:remove_track(track)
    self.canvas:set_selected_track(nil)
    self.track_properties_panel:set_track(nil)
  else
    self.State.remove_track(track)
    self.State.set_selected_track(nil)
    self.canvas:set_selected_track(nil)
    self.track_properties_panel:set_track(nil)
    self:sync_canvas()
  end
end

-- Handle adding a new track
function GUI:handle_add_track()
  if self.controller then
    local new_track = self.controller:add_track({
      name = "New Track " .. (#self.State.get_tracks() + 1),
    })
    if new_track then
      self.canvas:set_selected_track(new_track)
      self.track_properties_panel:set_track(new_track)
    end
  else
    local new_track = self.State.add_track({
      name = "New Track " .. (#self.State.get_tracks() + 1),
    })
    if new_track then
      self.State.set_selected_track(new_track)
      self.canvas:set_selected_track(new_track)
      self.track_properties_panel:set_track(new_track)
      self:sync_canvas()
    end
  end
end

-- Draw toolbar
function GUI:draw_toolbar(ctx)
  -- Undo/Redo buttons (if controller available)
  if self.controller then
    local can_undo = self.controller:can_undo()
    local can_redo = self.controller:can_redo()

    if not can_undo then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#666666"))
    end
    if ImGui.Button(ctx, "Undo##toolbar", 50, 24) and can_undo then
      self.controller:undo()
    end
    if not can_undo then
      ImGui.PopStyleColor(ctx)
    end
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, "Undo last action (Ctrl+Z)")
    end

    ImGui.SameLine(ctx, 0, 4)

    if not can_redo then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#666666"))
    end
    if ImGui.Button(ctx, "Redo##toolbar", 50, 24) and can_redo then
      self.controller:redo()
    end
    if not can_redo then
      ImGui.PopStyleColor(ctx)
    end
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, "Redo last undone action (Ctrl+Y)")
    end

    ImGui.SameLine(ctx, 0, 16)
  end

  -- Context selector (TCP, MCP, etc.)
  ImGui.Text(ctx, "Context:")
  ImGui.SameLine(ctx)

  local contexts = {"TCP", "MCP", "EnvCP", "Trans"}
  local current = self.State.get_context():upper()

  for _, ctx_name in ipairs(contexts) do
    local is_active = ctx_name == current
    if is_active then
      ImGui.PushStyleColor(ctx, ImGui.Col_Button, hexrgb("#404060"))
    end

    if ImGui.Button(ctx, ctx_name .. "##ctx", 50, 24) then
      self.State.set_context(ctx_name:lower())
    end

    if is_active then
      ImGui.PopStyleColor(ctx)
    end
    ImGui.SameLine(ctx, 0, 4)
  end

  ImGui.SameLine(ctx, 0, 20)

  -- Actions
  if ImGui.Button(ctx, "Load Defaults##toolbar", 100, 24) then
    if self.controller then
      self.controller:load_tcp_defaults()
    else
      self.State.load_tcp_defaults()
      self:sync_canvas()
      self.code_panel:invalidate()
    end
  end
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "Load default TCP layout elements")
  end

  ImGui.SameLine(ctx, 0, 8)

  if ImGui.Button(ctx, "Clear All##toolbar", 80, 24) then
    if self.controller then
      self.controller:clear_elements()
    else
      self.State.clear_elements()
      self.properties_panel:set_element(nil)
      self:sync_canvas()
      self.code_panel:invalidate()
    end
  end
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "Remove all elements from layout")
  end

  ImGui.SameLine(ctx, 0, 8)

  if ImGui.Button(ctx, "Reset Tracks##toolbar", 90, 24) then
    if self.controller then
      self.controller:load_default_tracks()
    else
      self.State.load_default_tracks()
      self:sync_canvas()
    end
  end
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "Reset to default demo tracks")
  end
end

-- Draw status bar
function GUI:draw_status_bar(ctx)
  -- Update notification timeouts
  self.notification:update()

  local message, msg_type = self.notification:get_message()
  if message then
    local color = self.notification:get_message_color()
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, color)
    ImGui.Text(ctx, message)
    ImGui.PopStyleColor(ctx)
  else
    -- Show default status
    local elem_count = #self.State.get_elements()
    local track_count = #self.State.get_tracks()
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#666666"))
    ImGui.Text(ctx, string.format("%d elements, %d tracks", elem_count, track_count))
    ImGui.PopStyleColor(ctx)
  end
end

-- Main draw function
function GUI:draw(ctx, window, shell_state)
  self:initialize_once(ctx)

  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)

  -- Toolbar
  self:draw_toolbar(ctx)
  ImGui.Dummy(ctx, 0, 4)
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 4)

  -- Recalculate available height after toolbar
  local _, remaining_h = ImGui.GetContentRegionAvail(ctx)

  -- Three-panel layout
  -- [Elements Panel] | [Canvas] | [Properties/Code]

  -- Left panel: Elements
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#1A1A1A"))

  ImGui.BeginChild(ctx, "left_panel", self.left_panel_width, remaining_h, 1, 0)
  ImGui.Dummy(ctx, 0, 4)
  ImGui.Indent(ctx, 4)

  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#FFFFFF"))
  ImGui.Text(ctx, "Elements")
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 4)

  local result = self.elements_panel:draw(ctx)
  if result and result.type == "add" then
    self:handle_add_element(result.definition)
  end

  ImGui.Unindent(ctx, 4)
  ImGui.EndChild(ctx)
  ImGui.PopStyleColor(ctx)

  ImGui.SameLine(ctx, 0, 4)

  -- Center: Canvas
  local canvas_w = avail_w - self.left_panel_width - self.right_panel_width - 12

  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#1A1A1A"))

  ImGui.BeginChild(ctx, "center_panel", canvas_w, remaining_h, 1, 0)
  ImGui.Dummy(ctx, 0, 4)
  ImGui.Indent(ctx, 4)

  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#FFFFFF"))
  ImGui.Text(ctx, "Preview Canvas")
  ImGui.PopStyleColor(ctx)

  ImGui.SameLine(ctx)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#666666"))
  ImGui.Text(ctx, "(drag handles to resize)")
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 4)

  -- Draw legend
  ElementRenderer.new():draw_legend(ctx)

  ImGui.Dummy(ctx, 0, 4)

  -- Draw canvas
  local canvas_result = self.canvas:draw(ctx)

  -- Handle canvas events
  if canvas_result then
    if canvas_result.type == "select" then
      self.State.set_selected(canvas_result.element)
      self.properties_panel:set_element(canvas_result.element)
      -- Also select the track if provided
      if canvas_result.track then
        self.State.set_selected_track(canvas_result.track)
        self.track_properties_panel:set_track(canvas_result.track)
      end
    elseif canvas_result.type == "select_track" then
      self.State.set_selected_track(canvas_result.track)
      self.track_properties_panel:set_track(canvas_result.track)
      -- Clear element selection when selecting track background
      self.State.clear_selection()
      self.properties_panel:set_element(nil)
    elseif canvas_result.type == "resize_width" then
      -- Width changed - sync to state
      self.State.set_parent_size(canvas_result.width, self.State.get_parent_size())
    elseif canvas_result.type == "resize_track" then
      -- Track height changed - track object already updated, just sync canvas
      self.canvas:set_selected_track(canvas_result.track)
      self.track_properties_panel:set_track(canvas_result.track)
    end
  end

  -- Sync canvas config back to state
  if self.canvas.config.show_grid ~= self.State.get_show_grid() then
    self.State.set_show_grid(self.canvas.config.show_grid)
  end
  if self.canvas.config.show_attachments ~= self.State.get_show_attachments() then
    self.State.set_show_attachments(self.canvas.config.show_attachments)
  end

  -- Sync parent size
  local cw, ch = self.canvas:get_parent_size()
  local sw, sh = self.State.get_parent_size()
  if cw ~= sw or ch ~= sh then
    self.State.set_parent_size(cw, ch)
  end

  ImGui.Unindent(ctx, 4)
  ImGui.EndChild(ctx)
  ImGui.PopStyleColor(ctx)

  ImGui.SameLine(ctx, 0, 4)

  -- Right panel: Properties and Code (tabbed or split)
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#1A1A1A"))

  ImGui.BeginChild(ctx, "right_panel", self.right_panel_width, remaining_h, 1, 0)
  ImGui.Dummy(ctx, 0, 4)
  ImGui.Indent(ctx, 4)

  -- Tab bar for Track / Element / Code
  if ImGui.BeginTabBar(ctx, "right_tabs") then
    -- Track tab (for track properties)
    if ImGui.BeginTabItem(ctx, "Track") then
      ImGui.Dummy(ctx, 0, 4)
      local track_result = self.track_properties_panel:draw(ctx)

      if track_result then
        if track_result.type == "add_track" then
          self:handle_add_track()
        elseif track_result.type == "delete_track" then
          self:handle_delete_track(track_result.track)
        elseif track_result.type == "change_track" then
          self:handle_track_changed(track_result.track)
        end
      end

      ImGui.EndTabItem(ctx)
    end

    -- Element tab (for element properties)
    if ImGui.BeginTabItem(ctx, "Element") then
      ImGui.Dummy(ctx, 0, 4)
      local props_result = self.properties_panel:draw(ctx)

      if props_result then
        if props_result.type == "delete" then
          self:handle_delete_element(props_result.element)
        elseif props_result.type == "change" then
          self:handle_element_changed(props_result.element)
        end
      end

      ImGui.EndTabItem(ctx)
    end

    -- Code tab
    if ImGui.BeginTabItem(ctx, "Code") then
      ImGui.Dummy(ctx, 0, 4)
      self.code_panel:draw(ctx)
      ImGui.EndTabItem(ctx)
    end

    ImGui.EndTabBar(ctx)
  end

  ImGui.Unindent(ctx, 4)
  ImGui.EndChild(ctx)
  ImGui.PopStyleColor(ctx)

  -- Status bar at bottom
  ImGui.Dummy(ctx, 0, 4)
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 2)
  self:draw_status_bar(ctx)
end

return M
