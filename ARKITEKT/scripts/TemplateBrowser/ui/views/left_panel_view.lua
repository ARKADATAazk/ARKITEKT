-- @noindex
-- TemplateBrowser/ui/views/left_panel_view.lua
-- Left tabbed panel view: Directory / VSTs / Tags
-- Delegates to gui_functions module for actual implementations

local ImGui = require 'imgui' '0.10'
local Tabs = require('rearkitekt.gui.widgets.navigation.tabs')

local M = {}
local LeftPanelView = {}
LeftPanelView.__index = LeftPanelView

-- Create new left panel view
-- @param config Configuration object
-- @param state Application state
-- @param gui_functions Module containing draw_* functions from original gui.lua
function M.new(config, state, gui_functions)
  local self = setmetatable({
    config = config,
    state = state,
    gui_functions = gui_functions,
  }, LeftPanelView)

  return self
end

-- ImGui compatibility for BeginChild
local function BeginChildCompat(ctx, id, w, h, want_border, window_flags)
  local child_flags = want_border and 1 or 0
  return ImGui.BeginChild(ctx, id, w, h, child_flags, window_flags or 0)
end

-- Draw the left panel with tabs
function LeftPanelView:draw(ctx, width, height)
  if not BeginChildCompat(ctx, "LeftPanel", width, height, true) then
    return
  end

  -- Count active filters for tab badges
  local fx_filter_count = 0
  for _ in pairs(self.state.filter_fx) do
    fx_filter_count = fx_filter_count + 1
  end

  local tag_filter_count = 0
  for _ in pairs(self.state.filter_tags) do
    tag_filter_count = tag_filter_count + 1
  end

  -- Draw tabs
  local tabs_def = {
    { id = "directory", label = "DIRECTORY" },
    { id = "vsts", label = "VSTS" },
    { id = "tags", label = "TAGS" },
  }

  local clicked_tab = Tabs.draw_at_cursor(ctx, tabs_def, self.state.left_panel_tab, {
    height = 24,
    available_width = width,
    bg_color = self.config.COLORS.header_bg,
    active_color = self.config.COLORS.selected_bg,
    text_color = self.config.COLORS.text,
  })

  if clicked_tab then
    self.state.left_panel_tab = clicked_tab
  end

  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Draw content based on active tab
  local content_height = height - 35  -- Account for tab bar

  -- Delegate to gui_functions module for actual rendering
  if self.state.left_panel_tab == "directory" then
    self.gui_functions.draw_directory_content(ctx, self.state, self.config, width, content_height)
  elseif self.state.left_panel_tab == "vsts" then
    self.gui_functions.draw_vsts_content(ctx, self.state, self.config, width, content_height)
  elseif self.state.left_panel_tab == "tags" then
    self.gui_functions.draw_tags_content(ctx, self.state, self.config, width, content_height)
  end

  ImGui.EndChild(ctx)
end

return M
