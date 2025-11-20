-- @noindex
-- TemplateBrowser/ui/main_window.lua
-- Main window orchestrator using view-based architecture
-- This is the NEW entry point that composes left/template/info panel views

local ImGui = require 'imgui' '0.10'
local Separator = require('rearkitekt.gui.widgets.primitives.separator')
local Colors = require('rearkitekt.core.colors')

-- Import view modules
local LeftPanelView = require('TemplateBrowser.ui.views.left_panel_view')
local TemplatePanelView = require('TemplateBrowser.ui.views.template_panel_view')
local InfoPanelView = require('TemplateBrowser.ui.views.info_panel_view')

-- Import gui module for draw functions and backwards compatibility
local GUI_Module = require('TemplateBrowser.ui.gui')

local M = {}
local MainWindow = {}
MainWindow.__index = MainWindow

function M.new(config, state, scanner, gui_instance)
  local self = setmetatable({
    config = config,
    state = state,
    scanner = scanner,
    gui = gui_instance,  -- Reference to original GUI instance for template_container

    -- Create view instances with gui_functions
    left_panel = nil,
    template_panel = nil,
    info_panel = nil,
  }, MainWindow)

  -- Initialize views with gui draw functions
  self.left_panel = LeftPanelView.new(config, state, GUI_Module.draw_functions)
  self.template_panel = TemplatePanelView.new(config, state, gui_instance, GUI_Module.draw_functions)
  self.info_panel = InfoPanelView.new(config, state, GUI_Module.draw_functions)

  return self
end

function MainWindow:draw(ctx, shell_state)
  local is_overlay_mode = shell_state.is_overlay_mode == true
  local overlay = shell_state.overlay
  local overlay_alpha = 1.0
  if is_overlay_mode and overlay and overlay.alpha then
    overlay_alpha = overlay.alpha:value()
  end
  self.state.overlay_alpha = overlay_alpha

  -- Get screen dimensions (same as original gui.lua)
  local SCREEN_W, SCREEN_H
  if is_overlay_mode and shell_state.overlay_state then
    SCREEN_W = shell_state.overlay_state.width
    SCREEN_H = shell_state.overlay_state.height
  else
    local MonitorDetection = require('rearkitekt.app.utils.monitor_detection')
    SCREEN_W, SCREEN_H = MonitorDetection.get_reaper_window_size(ctx)
  end

  -- Title (moved up by 15 pixels)
  local title_y_offset = -15
  ImGui.PushFont(ctx, shell_state.fonts.title, shell_state.fonts.title_size)
  local title = "Template Browser"
  local title_w = ImGui.CalcTextSize(ctx, title)
  local title_y = ImGui.GetCursorPosY(ctx) + title_y_offset
  ImGui.SetCursorPosY(ctx, title_y)
  ImGui.SetCursorPosX(ctx, (SCREEN_W - title_w) * 0.5)

  ImGui.PushStyleColor(ctx, ImGui.Col_Text, Colors.hexrgb("#E0E0E0"))
  ImGui.Text(ctx, title)
  ImGui.PopStyleColor(ctx)
  ImGui.PopFont(ctx)

  -- Panel layout configuration (same as original)
  local padding_top = 50
  local padding_bottom = 30
  local padding_left = 12
  local padding_right = 12

  local left_column_width = 300
  local info_width = 350
  local separator_width = 2

  local content_width = SCREEN_W - padding_left - padding_right
  local panel_height = SCREEN_H - padding_top - padding_bottom - 30  -- Reserve space for status bar

  local template_width = content_width - left_column_width - info_width - (separator_width * 2)

  -- Set cursor for layout
  ImGui.SetCursorPos(ctx, padding_left, padding_top)

  -- === LEFT PANEL (Directory/VSTs/Tags) ===
  self.left_panel:draw(ctx, left_column_width, panel_height)
  ImGui.SameLine(ctx, 0, 0)

  -- Separator
  Separator.draw_vertical_at_cursor(ctx, separator_width, panel_height)
  ImGui.SameLine(ctx, 0, 0)

  -- === MIDDLE PANEL (Templates Grid) ===
  self.template_panel:draw(ctx, template_width, panel_height)
  ImGui.SameLine(ctx, 0, 0)

  -- Separator
  Separator.draw_vertical_at_cursor(ctx, separator_width, panel_height)
  ImGui.SameLine(ctx, 0, 0)

  -- === RIGHT PANEL (Info & Tags) ===
  self.info_panel:draw(ctx, info_width, panel_height)

  -- Status bar
  local StatusBar = require('TemplateBrowser.ui.status_bar')
  local status_bar_height = 24
  local status_bar_y = SCREEN_H - padding_bottom - status_bar_height
  ImGui.SetCursorPos(ctx, padding_left, status_bar_y)
  StatusBar.draw(ctx, self.state, content_width, status_bar_height)

  -- Handle exit
  if self.state.exit or ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
    if is_overlay_mode then
      if overlay and overlay.close then
        overlay:close()
      end
    else
      if shell_state.window and shell_state.window.request_close then
        shell_state.window:request_close()
      end
    end
  end
end

return M
