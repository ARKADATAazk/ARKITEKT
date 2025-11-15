-- @noindex
-- ItemPicker/ui/gui.lua
-- GUI orchestrator

local ImGui = require 'imgui' '0.10'
local Coordinator = require('ItemPicker.ui.tiles.coordinator')
local LayoutView = require('ItemPicker.ui.views.layout_view')

local M = {}
local GUI = {}
GUI.__index = GUI

function M.new(config, state, controller, visualization, cache_mgr, drag_handler)
  local self = setmetatable({
    config = config,
    state = state,
    controller = controller,
    visualization = visualization,
    cache_mgr = cache_mgr,
    drag_handler = drag_handler,

    coordinator = nil,
    layout_view = nil,

    initialized = false,
  }, GUI)

  return self
end

function GUI:initialize_once(ctx)
  if self.initialized then return end

  -- Initialize domain modules
  if not self.state.cache then
    self.state.cache = self.cache_mgr.new(self.config.CACHE.MAX_ENTRIES)
  end

  if not self.state.job_queue then
    local job_queue_module = require('ItemPicker.domain.job_queue')
    self.state.job_queue = job_queue_module.new(3)
  end

  -- Collect items from project
  self.controller.collect_project_items(self.state)

  -- Create coordinator and layout view
  self.coordinator = Coordinator.new(ctx, self.config, self.state, self.visualization, self.cache_mgr)
  self.layout_view = LayoutView.new(self.config, self.state, self.coordinator)

  self.initialized = true
end

function GUI:draw(ctx, shell_state)
  self:initialize_once(ctx)

  -- Get draw list
  if not self.state.draw_list then
    self.state.draw_list = ImGui.GetWindowDrawList(ctx)
  end

  -- Get overlay alpha for cascade animation
  local is_overlay_mode = shell_state.is_overlay_mode == true
  local overlay = shell_state.overlay

  local overlay_alpha = 1.0
  if is_overlay_mode and overlay and overlay.alpha then
    overlay_alpha = overlay.alpha:value()
  end
  self.state.overlay_alpha = overlay_alpha

  -- Get screen dimensions
  local viewport = ImGui.GetMainViewport(ctx)
  local SCREEN_W, SCREEN_H = ImGui.Viewport_GetSize(viewport)

  -- Get fonts
  local mini_font = shell_state.fonts.default
  local mini_font_size = shell_state.fonts.default_size or 14
  local big_font = shell_state.fonts.title
  local big_font_size = shell_state.fonts.title_size or 24

  -- Process async jobs
  if self.state.job_queue then
    local job_queue_module = require('ItemPicker.domain.job_queue')
    job_queue_module.process_jobs(
      self.state.job_queue,
      self.visualization,
      self.cache_mgr,
      ctx
    )
  end

  -- Update animations
  self.coordinator:update_animations(0.016)

  -- Handle tile size shortcuts
  self.coordinator:handle_tile_size_shortcuts(ctx)

  ImGui.PushFont(ctx, mini_font, mini_font_size)
  reaper.PreventUIRefresh(1)

  -- Check if dragging
  if not self.state.dragging then
    -- Normal mode - show main UI
    self.layout_view:render(ctx, big_font, big_font_size, "Item Picker", SCREEN_W, SCREEN_H)
  else
    -- Dragging mode - create transparent non-blocking window
    ImGui.SetNextWindowPos(ctx, 0, 0)
    ImGui.SetNextWindowSize(ctx, SCREEN_W, SCREEN_H)

    local drag_flags = ImGui.WindowFlags_NoCollapse | ImGui.WindowFlags_NoTitleBar |
                       ImGui.WindowFlags_NoResize | ImGui.WindowFlags_NoMove |
                       ImGui.WindowFlags_NoScrollbar | ImGui.WindowFlags_NoBackground |
                       ImGui.WindowFlags_NoInputs  -- Critical: allows mouse to pass through

    if ImGui.Begin(ctx, "Item Picker (Dragging)", true, drag_flags) then
      -- Window exists but is transparent and non-blocking
      ImGui.End(ctx)
    end

    -- Show drag overlay and preview on top
    local should_insert = self.drag_handler.handle_drag_logic(ctx, self.state, mini_font)
    if should_insert then
      self.controller.insert_item_at_mouse(self.state.item_to_add, self.state)
      self.state.request_exit()  -- Module function, uses dot notation
    end

    self.drag_handler.render_drag_preview(ctx, self.state, mini_font, self.visualization)
  end

  reaper.PreventUIRefresh(-1)
  ImGui.PopFont(ctx)

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
