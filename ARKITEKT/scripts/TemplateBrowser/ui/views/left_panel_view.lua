-- @noindex
-- TemplateBrowser/ui/views/left_panel_view.lua
-- Left tabbed panel view: Directory / VSTs / Tags
-- Delegates to gui_functions module for actual implementations

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

-- Draw the left panel with tabs
function LeftPanelView:draw(ctx, width, height)
  -- Delegate directly to gui_functions module (it handles its own BeginChild/EndChild)
  self.gui_functions.draw_left_panel(ctx, self.state, self.config, width, height)
end

return M
