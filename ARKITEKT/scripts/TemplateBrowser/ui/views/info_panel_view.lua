-- @noindex
-- TemplateBrowser/ui/views/info_panel_view.lua
-- Right panel view: Template info & tag assignment
-- Delegates to gui_functions module for actual implementations

local M = {}
local InfoPanelView = {}
InfoPanelView.__index = InfoPanelView

-- Create new info panel view
-- @param config Configuration object
-- @param state Application state
-- @param gui_functions Module containing draw_* functions from original gui.lua
function M.new(config, state, gui_functions)
  local self = setmetatable({
    config = config,
    state = state,
    gui_functions = gui_functions,
  }, InfoPanelView)

  return self
end

-- Draw the info panel
function InfoPanelView:draw(ctx, width, height)
  -- Delegate to gui_functions module
  self.gui_functions.draw_info_panel(ctx, self.state, self.config, width, height)
end

return M
