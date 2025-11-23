-- @noindex
-- TemplateBrowser/ui/views/left_panel_view.lua
-- Left panel view: Directory / VSTs / Tags (using panel container) + Convenience panel (mini Tags/VSTs)

local ImGui = require 'imgui' '0.10'

-- Import tab modules
local DirectoryTab = require('TemplateBrowser.ui.views.left_panel.directory_tab')
local VstsTab = require('TemplateBrowser.ui.views.left_panel.vsts_tab')
local TagsTab = require('TemplateBrowser.ui.views.left_panel.tags_tab')
local ConveniencePanelView = require('TemplateBrowser.ui.views.convenience_panel_view')

local M = {}

-- Draw left column: split into two panels vertically (left_panel + convenience_panel)
function M.draw_left_panel(ctx, gui, width, height)
  local state = gui.state

  -- Only show convenience panel when on Directory tab
  local show_convenience_panel = (state.left_panel_tab == "directory" or not state.left_panel_tab)

  -- Get window's screen position and save for panel positioning
  local initial_x, initial_y = ImGui.GetCursorScreenPos(ctx)

  local top_panel_height, bottom_panel_height

  if show_convenience_panel then
    -- Separator configuration
    local separator_thickness = 8
    local min_panel_height = 100

    -- Initialize separator ratio if not set (default 65% top, 35% bottom)
    state.left_panel_separator_ratio = state.left_panel_separator_ratio or 0.65

    -- Calculate separator position
    local sep_y_local = height * state.left_panel_separator_ratio
    local sep_y_screen = initial_y + sep_y_local

    -- Handle separator dragging
    local sep_action, sep_new_y_screen = gui.left_panel_separator:draw_horizontal(ctx, initial_x, sep_y_screen, width, 0, separator_thickness)
    if sep_action == "drag" then
      -- Convert back to local coordinates
      local sep_new_y = sep_new_y_screen - initial_y
      -- Clamp to valid range
      local min_y = min_panel_height
      local max_y = height - min_panel_height
      sep_new_y = math.max(min_y, math.min(sep_new_y, max_y))
      state.left_panel_separator_ratio = sep_new_y / height
      sep_y_local = sep_new_y
    elseif sep_action == "reset" then
      state.left_panel_separator_ratio = 0.65
      sep_y_local = height * state.left_panel_separator_ratio
    end

    -- Calculate panel heights (accounting for separator thickness)
    top_panel_height = sep_y_local - separator_thickness / 2
    bottom_panel_height = height - sep_y_local - separator_thickness / 2
  else
    -- No convenience panel, use full height for main panel
    top_panel_height = height
  end

  -- Draw top panel (main left panel with Directory/VSTs/Tags tabs)
  -- Explicitly position at the top
  ImGui.SetCursorScreenPos(ctx, initial_x, initial_y)

  gui.left_panel_container.width = width
  gui.left_panel_container.height = top_panel_height

  if gui.left_panel_container:begin_draw(ctx) then
    -- Calculate content height after header
    local header_height = gui.left_panel_container.config.header and gui.left_panel_container.config.header.height or 30
    local padding = gui.left_panel_container.config.padding or 8
    local content_height = top_panel_height - header_height - (padding * 2)

    -- Draw content based on active tab
    if state.left_panel_tab == "directory" then
      DirectoryTab.draw(ctx, state, gui.config, width, content_height, gui)
    elseif state.left_panel_tab == "vsts" then
      VstsTab.draw(ctx, state, gui.config, width, content_height)
    elseif state.left_panel_tab == "tags" then
      TagsTab.draw(ctx, state, gui.config, width, content_height)
    end

    gui.left_panel_container:end_draw(ctx)
  end

  -- Draw bottom panel (convenience panel with mini Tags/VSTs tabs) only on Directory tab
  if show_convenience_panel then
    local separator_thickness = 8
    local sep_y_local = height * state.left_panel_separator_ratio
    local bottom_panel_start_y = initial_y + sep_y_local + separator_thickness / 2
    ImGui.SetCursorScreenPos(ctx, initial_x, bottom_panel_start_y)

    ConveniencePanelView.draw_convenience_panel(ctx, gui, width, bottom_panel_height)
  end
end

return M
