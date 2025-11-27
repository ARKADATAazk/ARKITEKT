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
local CodePanel = require('WalterBuilder.ui.panels.code_panel')
local TCPElements = require('WalterBuilder.defs.tcp_elements')

local hexrgb = ark.Colors.hexrgb

local M = {}
local GUI = {}
GUI.__index = GUI

function M.new(state_module, settings)
  local self = setmetatable({
    State = state_module,
    settings = settings,
    initialized = false,

    -- Panels
    canvas = nil,
    elements_panel = nil,
    properties_panel = nil,
    code_panel = nil,

    -- Layout
    left_panel_width = 200,
    right_panel_width = 280,
  }, GUI)

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

  self.code_panel = CodePanel.new()

  -- Update canvas with current elements
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
  self.canvas:set_elements(elements)
  self.elements_panel:set_active_elements(self.State.get_element_ids())
  self.code_panel:set_elements(elements)
end

-- Handle adding an element
function GUI:handle_add_element(def)
  local elem = self.State.add_element(def)
  if elem then
    self.State.set_selected(elem)
    self:sync_canvas()
    self.canvas:set_selected(elem)
    self.properties_panel:set_element(elem)
    self.code_panel:invalidate()
  end
end

-- Handle element changes
function GUI:handle_element_changed(element)
  self.State.element_changed(element)
  self.canvas.sim_cache = nil  -- Invalidate simulation cache
  self.code_panel:invalidate()
end

-- Handle element deletion
function GUI:handle_delete_element(element)
  self.State.remove_element(element)
  self.State.clear_selection()
  self.canvas:set_selected(nil)
  self.properties_panel:set_element(nil)
  self:sync_canvas()
  self.code_panel:invalidate()
end

-- Draw toolbar
function GUI:draw_toolbar(ctx)
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
    self.State.load_tcp_defaults()
    self:sync_canvas()
    self.code_panel:invalidate()
  end
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "Load default TCP layout elements")
  end

  ImGui.SameLine(ctx, 0, 8)

  if ImGui.Button(ctx, "Clear All##toolbar", 80, 24) then
    self.State.clear_elements()
    self.properties_panel:set_element(nil)
    self:sync_canvas()
    self.code_panel:invalidate()
  end
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "Remove all elements from layout")
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

  -- Handle canvas selection
  if canvas_result and canvas_result.type == "select" then
    self.State.set_selected(canvas_result.element)
    self.properties_panel:set_element(canvas_result.element)
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

  -- Tab bar for Properties / Code
  if ImGui.BeginTabBar(ctx, "right_tabs") then
    -- Properties tab
    if ImGui.BeginTabItem(ctx, "Properties") then
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
end

return M
