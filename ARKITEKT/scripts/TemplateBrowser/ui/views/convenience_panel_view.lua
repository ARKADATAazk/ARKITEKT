-- @noindex
-- TemplateBrowser/ui/views/convenience_panel_view.lua
-- Convenience panel view: Tags / VSTs mini tabs (for quick access)

local ImGui = require 'imgui' '0.10'

-- Import tab modules
local ConvTagsTab = require('TemplateBrowser.ui.views.convenience_panel.tags_tab')
local ConvVstsTab = require('TemplateBrowser.ui.views.convenience_panel.vsts_tab')

local M = {}

-- Draw convenience panel with container
function M.draw_convenience_panel(ctx, gui, width, height)
  -- Set container dimensions
  gui.convenience_panel_container.width = width
  gui.convenience_panel_container.height = height

  -- Begin panel drawing (includes background, border, header)
  if gui.convenience_panel_container:begin_draw(ctx) then
    local state = gui.state

    -- Calculate content height after header
    local header_height = gui.convenience_panel_container.config.header and gui.convenience_panel_container.config.header.height or 30
    local padding = gui.convenience_panel_container.config.padding or 8
    local content_height = height - header_height - (padding * 2)

    -- Draw content based on active tab
    if state.convenience_panel_tab == "tags" then
      ConvTagsTab.draw(ctx, state, gui.config, width, content_height)
    elseif state.convenience_panel_tab == "vsts" then
      ConvVstsTab.draw(ctx, state, gui.config, width, content_height)
    end

    gui.convenience_panel_container:end_draw(ctx)
  end
end

return M
