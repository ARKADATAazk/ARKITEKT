-- @noindex
-- TemplateBrowser/ui/views/left_panel_view.lua
-- Left tabbed panel view: Directory / VSTs / Tags (refactored)

local ImGui = require 'imgui' '0.10'
local Tabs = require('rearkitekt.gui.widgets.navigation.tabs')
local Helpers = require('TemplateBrowser.ui.views.helpers')

-- Import tab modules
local DirectoryTab = require('TemplateBrowser.ui.views.left_panel.directory_tab')
local VstsTab = require('TemplateBrowser.ui.views.left_panel.vsts_tab')
local TagsTab = require('TemplateBrowser.ui.views.left_panel.tags_tab')

local M = {}

-- Draw tabbed left panel (DIRECTORY / VSTS / TAGS)
function M.draw_left_panel(ctx, state, config, width, height)
  if not Helpers.begin_child_compat(ctx, "LeftPanel", width, height, true) then
    return
  end

  -- Count active filters for badges (future enhancement)
  local fx_filter_count = 0
  for _ in pairs(state.filter_fx) do
    fx_filter_count = fx_filter_count + 1
  end

  local tag_filter_count = 0
  for _ in pairs(state.filter_tags) do
    tag_filter_count = tag_filter_count + 1
  end

  -- Draw tabs using rearkitekt Tabs widget
  local tabs_def = {
    { id = "directory", label = "DIRECTORY" },
    { id = "vsts", label = "VSTS" },
    { id = "tags", label = "TAGS" },
  }

  local clicked_tab = Tabs.draw_at_cursor(ctx, tabs_def, state.left_panel_tab, {
    height = 24,
    available_width = width,
    bg_color = config.COLORS.header_bg,
    active_color = config.COLORS.selected_bg,
    text_color = config.COLORS.text,
  })

  if clicked_tab then
    state.left_panel_tab = clicked_tab
  end

  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Draw content based on active tab
  local content_height = height - 35  -- Account for tab bar

  if state.left_panel_tab == "directory" then
    DirectoryTab.draw(ctx, state, config, width, content_height)
  elseif state.left_panel_tab == "vsts" then
    VstsTab.draw(ctx, state, config, width, content_height)
  elseif state.left_panel_tab == "tags" then
    TagsTab.draw(ctx, state, config, width, content_height)
  end

  ImGui.EndChild(ctx)
end

return M
