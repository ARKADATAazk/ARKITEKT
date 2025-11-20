-- @noindex
-- TemplateBrowser/ui/views/template_panel_view.lua
-- Middle panel view: Recent templates + template grid
-- Delegates to gui_functions module for actual implementations

local M = {}
local TemplatePanelView = {}
TemplatePanelView.__index = TemplatePanelView

-- Create new template panel view
-- @param config Configuration object
-- @param state Application state
-- @param gui Reference to main GUI object (for template_container access)
-- @param gui_functions Module containing draw_* functions from original gui.lua
function M.new(config, state, gui, gui_functions)
  local self = setmetatable({
    config = config,
    state = state,
    gui = gui,
    gui_functions = gui_functions,
  }, TemplatePanelView)

  return self
end

-- Draw the template panel
function TemplatePanelView:draw(ctx, width, height)
  -- Delegate to gui_functions module
  -- This function handles the entire middle panel rendering
  self.gui_functions.draw_template_panel(ctx, self.gui, width, height)
end

return M
