-- @noindex
-- TemplateBrowser/ui/views/left_panel_view.lua
-- Left panel view: Directory / VSTs / Tags (using panel container)

local ImGui = require 'imgui' '0.10'

-- Import tab modules
local DirectoryTab = require('TemplateBrowser.ui.views.left_panel.directory_tab')
local VstsTab = require('TemplateBrowser.ui.views.left_panel.vsts_tab')
local TagsTab = require('TemplateBrowser.ui.views.left_panel.tags_tab')

local M = {}

-- Draw left panel with container
function M.draw_left_panel(ctx, gui, width, height)
  -- Set container dimensions
  gui.left_panel_container.width = width
  gui.left_panel_container.height = height

  -- Begin panel drawing (includes background, border, header)
  if gui.left_panel_container:begin_draw(ctx) then
    local state = gui.state

    -- Draw content based on active tab
    if state.left_panel_tab == "directory" then
      DirectoryTab.draw(ctx, state, gui.config, width)
    elseif state.left_panel_tab == "vsts" then
      VstsTab.draw(ctx, state, gui.config, width)
    elseif state.left_panel_tab == "tags" then
      TagsTab.draw(ctx, state, gui.config, width)
    end

    gui.left_panel_container:end_draw(ctx)
  end
end

return M
