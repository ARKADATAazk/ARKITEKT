-- @noindex
-- TemplateBrowser/ui/main_window.lua
-- Main window orchestrator using view-based architecture
-- This is the NEW entry point that composes left/template/info panel views

local ImGui = require 'imgui' '0.10'
local Separator = require('rearkitekt.gui.widgets.primitives.separator')
local Colors = require('rearkitekt.core.colors')

-- Import domain modules for background processing
local FXQueue = require('TemplateBrowser.domain.fx_queue')
local FileOps = require('TemplateBrowser.domain.file_ops')
local TemplateOps = require('TemplateBrowser.domain.template_ops')
local Shortcuts = require('TemplateBrowser.core.shortcuts')
local MarkdownField = require('rearkitekt.gui.widgets.primitives.markdown_field')

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

    -- Draggable separators for panel resizing
    separator1 = Separator.new("sep1"),
    separator2 = Separator.new("sep2"),
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

  -- Initialize gui instance (creates template_grid and template_container)
  self.gui:initialize_once(ctx, is_overlay_mode)

  -- Process background FX parsing queue (5 templates per frame)
  FXQueue.process_batch(self.state, 5)

  -- Process conflict resolution if user made a choice
  if self.state.conflict_resolution and self.state.conflict_pending then
    local conflict = self.state.conflict_pending
    local resolution = self.state.conflict_resolution

    if resolution ~= "cancel" and conflict.operation == "move" then
      local success_count = 0
      local total_count = #conflict.templates
      local target_node = conflict.target_folder

      for _, tmpl in ipairs(conflict.templates) do
        local success, new_path, conflict_detected = FileOps.move_template(tmpl.path, target_node.full_path, resolution)
        if success then
          success_count = success_count + 1
        else
          self.state.set_status("Failed to move template: " .. tmpl.name, "error")
        end
      end

      -- Rescan if any succeeded
      if success_count > 0 then
        local Scanner = require('TemplateBrowser.domain.scanner')
        Scanner.scan_templates(self.state)

        -- Success message
        if total_count > 1 then
          self.state.set_status("Moved " .. success_count .. " of " .. total_count .. " templates to " .. target_node.name, "success")
        else
          self.state.set_status("Moved " .. conflict.templates[1].name .. " to " .. target_node.name, "success")
        end
      end
    end

    -- Clear conflict state
    self.state.conflict_pending = nil
    self.state.conflict_resolution = nil
  end

  -- Handle keyboard shortcuts (but not while editing markdown)
  local is_editing_markdown = false
  if self.state.selected_template then
    local notes_field_id = "template_notes_" .. self.state.selected_template.uuid
    is_editing_markdown = MarkdownField.is_editing(notes_field_id)
  end

  local action = Shortcuts.check_shortcuts(ctx)
  if action and not is_editing_markdown then
    if action == "undo" then
      self.state.undo_manager:undo()
    elseif action == "redo" then
      self.state.undo_manager:redo()
    elseif action == "rename_template" then
      if self.state.selected_template then
        self.state.renaming_item = self.state.selected_template
        self.state.renaming_type = "template"
        self.state.rename_buffer = self.state.selected_template.name
      end
    elseif action == "archive_template" then
      if self.state.selected_template then
        local success, archive_path = FileOps.delete_template(self.state.selected_template.path)
        if success then
          self.state.set_status("Archived: " .. self.state.selected_template.name, "success")
          -- Rescan templates
          local Scanner = require('TemplateBrowser.domain.scanner')
          Scanner.scan_templates(self.state)
          self.state.selected_template = nil
        else
          self.state.set_status("Failed to archive template", "error")
        end
      end
    elseif action == "apply_template" then
      if self.state.selected_template then
        TemplateOps.apply_to_selected_track(self.state.selected_template.path, self.state.selected_template.uuid, self.state)
      end
    elseif action == "insert_template" then
      if self.state.selected_template then
        TemplateOps.insert_as_new_track(self.state.selected_template.path, self.state.selected_template.uuid, self.state)
      end
    elseif action == "focus_search" then
      -- Focus search box (will be handled by container)
      self.state.focus_search = true
    elseif action == "navigate_left" or action == "navigate_right" or
           action == "navigate_up" or action == "navigate_down" then
      -- Grid navigation (will be handled by grid widget)
      self.state.grid_navigation = action
    end
  end

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
  ImGui.SetCursorPos(ctx, (SCREEN_W - title_w) * 0.5, title_y)
  ImGui.Text(ctx, title)
  ImGui.PopFont(ctx)

  -- FX parsing progress indicator
  if not FXQueue.is_complete(self.state) then
    local status = FXQueue.get_status(self.state)
    local progress = FXQueue.get_progress(self.state)

    local status_y = title_y + 25
    local status_w = ImGui.CalcTextSize(ctx, status)

    ImGui.SetCursorPos(ctx, (SCREEN_W - status_w) * 0.5, status_y)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, Colors.hexrgb("#B3B3B3"))
    ImGui.Text(ctx, status)
    ImGui.PopStyleColor(ctx)

    -- Small progress bar
    local bar_width = 200
    local bar_height = 3
    ImGui.SetCursorPos(ctx, (SCREEN_W - bar_width) * 0.5, status_y + 18)
    ImGui.PushStyleColor(ctx, ImGui.Col_PlotHistogram, self.config.COLORS.selected_bg)
    ImGui.ProgressBar(ctx, progress, bar_width, bar_height, "")
    ImGui.PopStyleColor(ctx)
  end

  -- Adjust spacing after title
  ImGui.SetCursorPosY(ctx, title_y + 30)

  -- Padding
  local padding_left = 14
  local padding_right = 14
  local padding_bottom = 14
  local status_bar_height = 24  -- Reserve space for status bar

  local cursor_y = ImGui.GetCursorPosY(ctx)
  local content_width = SCREEN_W - padding_left - padding_right
  local panel_height = SCREEN_H - cursor_y - padding_bottom - status_bar_height

  -- Get cursor position for separator coordinate conversion
  local cursor_screen_x, cursor_screen_y = ImGui.GetCursorScreenPos(ctx)
  -- Window's top-left corner in screen coords
  local window_screen_x = cursor_screen_x
  local window_screen_y = cursor_screen_y - cursor_y

  -- Draggable separator configuration
  local separator_thickness = 8
  local min_panel_width = 150

  -- Calculate positions based on ratios within content area (window-relative)
  local sep1_x_local = padding_left + (content_width * self.state.separator1_ratio)
  local sep2_x_local = padding_left + (content_width * self.state.separator2_ratio)

  -- Convert to screen coordinates for separator
  local sep1_x_screen = window_screen_x + sep1_x_local
  local sep2_x_screen = window_screen_x + sep2_x_local
  local content_y_screen = window_screen_y + cursor_y

  -- Handle separator 1 dragging
  local sep1_action, sep1_new_x_screen = self.separator1:draw_vertical(ctx, sep1_x_screen, content_y_screen, 0, panel_height, separator_thickness)
  if sep1_action == "drag" then
    -- Convert back to window coordinates
    local sep1_new_x = sep1_new_x_screen - window_screen_x
    -- Clamp to valid range within content area
    local min_x = padding_left + min_panel_width
    local max_x = SCREEN_W - padding_right - min_panel_width * 2 - separator_thickness * 2
    sep1_new_x = math.max(min_x, math.min(sep1_new_x, max_x))
    self.state.separator1_ratio = (sep1_new_x - padding_left) / content_width
    sep1_x_local = sep1_new_x
    sep1_x_screen = window_screen_x + sep1_x_local
  elseif sep1_action == "reset" then
    self.state.separator1_ratio = self.config.FOLDERS_PANEL_WIDTH_RATIO
    sep1_x_local = padding_left + (content_width * self.state.separator1_ratio)
    sep1_x_screen = window_screen_x + sep1_x_local
  end

  -- Handle separator 2 dragging
  local sep2_action, sep2_new_x_screen = self.separator2:draw_vertical(ctx, sep2_x_screen, content_y_screen, 0, panel_height, separator_thickness)
  if sep2_action == "drag" then
    -- Convert back to window coordinates
    local sep2_new_x = sep2_new_x_screen - window_screen_x
    -- Clamp to valid range
    local min_x = sep1_x_local + separator_thickness + min_panel_width
    local max_x = SCREEN_W - padding_right - min_panel_width
    sep2_new_x = math.max(min_x, math.min(sep2_new_x, max_x))
    self.state.separator2_ratio = (sep2_new_x - padding_left) / content_width
    sep2_x_local = sep2_new_x
    sep2_x_screen = window_screen_x + sep2_x_local
  elseif sep2_action == "reset" then
    self.state.separator2_ratio = self.state.separator1_ratio + self.config.TEMPLATES_PANEL_WIDTH_RATIO
    sep2_x_local = padding_left + (content_width * self.state.separator2_ratio)
    sep2_x_screen = window_screen_x + sep2_x_local
  end

  -- Calculate panel widths (accounting for separator thickness)
  local left_column_width = sep1_x_local - padding_left - separator_thickness / 2
  local template_width = sep2_x_local - sep1_x_local - separator_thickness
  local info_width = SCREEN_W - padding_right - sep2_x_local - separator_thickness / 2

  -- === LEFT PANEL (Directory/VSTs/Tags) ===
  ImGui.SetCursorPos(ctx, padding_left, cursor_y)
  self.left_panel:draw(ctx, left_column_width, panel_height)

  -- === MIDDLE PANEL (Templates Grid) ===
  ImGui.SetCursorPos(ctx, sep1_x_local + separator_thickness / 2, cursor_y)
  self.template_panel:draw(ctx, template_width, panel_height)

  -- === RIGHT PANEL (Info & Tags) ===
  ImGui.SetCursorPos(ctx, sep2_x_local + separator_thickness / 2, cursor_y)
  self.info_panel:draw(ctx, info_width, panel_height)

  -- Template context menu and rename modal (must be drawn outside panels)
  GUI_Module.draw_functions.draw_template_context_menu(ctx, self.state)
  GUI_Module.draw_functions.draw_template_rename_modal(ctx, self.state)
  GUI_Module.draw_functions.draw_conflict_resolution_modal(ctx, self.state)

  -- Status bar
  local StatusBar = require('TemplateBrowser.ui.status_bar')
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
