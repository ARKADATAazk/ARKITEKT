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
    -- Process 1 thumbnail per frame (maximum smoothness: 1 * 33fps = 33/sec)
    -- Prioritizes UI responsiveness over generation speed
    self.state.job_queue = job_queue_module.new(1)
  end

  -- Try to load cached project state first
  local cached_state = self.cache_mgr.load_project_state_from_disk()
  local current_change_count = reaper.GetProjectStateChangeCount(0)

  if cached_state and cached_state.change_count == current_change_count then
    -- Project hasn't changed, use cached state (instant load!)
    self.state.sample_indexes = cached_state.sample_indexes or {}
    self.state.midi_indexes = cached_state.midi_indexes or {}
    self.state.last_change_count = current_change_count

    -- Still need to collect full items (just metadata was cached)
    -- But this allows faster startup for large projects
    self.controller.collect_project_items(self.state)
  else
    -- Project changed or no cache, full collection
    self.controller.collect_project_items(self.state)
    self.state.last_change_count = current_change_count

    -- Don't save state on initial load (defer to avoid blocking)
    -- It will be saved on next recollection or when closing
  end

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
  local SCREEN_W, SCREEN_H
  if is_overlay_mode and shell_state.overlay_state then
    -- In overlay mode, use the bounds from overlay manager (full REAPER window via JS API)
    SCREEN_W = shell_state.overlay_state.width
    SCREEN_H = shell_state.overlay_state.height
  else
    -- Normal mode, use viewport size
    local viewport = ImGui.GetMainViewport(ctx)
    SCREEN_W, SCREEN_H = ImGui.Viewport_GetSize(viewport)
  end

  -- Get fonts
  local mini_font = shell_state.fonts.default
  local mini_font_size = shell_state.fonts.default_size or 14
  local big_font = shell_state.fonts.title
  local big_font_size = shell_state.fonts.title_size or 24

  -- Process async jobs (max 1 per frame for smooth FPS)
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

  -- Check if we need to recollect items (e.g., after toggling split_midi_by_track)
  if self.state.needs_recollect then
    self.controller.collect_project_items(self.state)
    self.state.needs_recollect = false
    self.state.last_change_count = reaper.GetProjectStateChangeCount(0)

    -- Save updated state to disk
    self.cache_mgr.save_project_state_to_disk(self.state)
  end

  -- Periodically check for project changes (every 180 frames = ~5-6 seconds)
  -- Reduced frequency to avoid performance impact
  self.state.frame_count = (self.state.frame_count or 0) + 1
  if self.state.frame_count % 180 == 0 then
    local current_change_count = reaper.GetProjectStateChangeCount(0)
    if self.state.last_change_count and current_change_count ~= self.state.last_change_count then
      -- Project changed, trigger recollection
      self.state.needs_recollect = true
    end
  end

  ImGui.PushFont(ctx, mini_font, mini_font_size)
  reaper.PreventUIRefresh(1)

  -- Check if dragging
  if not self.state.dragging then
    -- Normal mode - show main UI
    self.layout_view:render(ctx, big_font, big_font_size, "Item Picker", SCREEN_W, SCREEN_H, is_overlay_mode)
  else
    -- Dragging mode - don't create main window at all
    -- The drag_handler creates its own windows (drag_target_window and MouseFollower)
    -- which allows the arrange window to receive mouse input
    local should_insert = self.drag_handler.handle_drag_logic(ctx, self.state, mini_font)
    if should_insert and not self.state.drop_completed then
      -- Only insert once
      self.controller.insert_item_at_mouse(self.state.item_to_add, self.state)
      self.state.drop_completed = true  -- Mark as completed
      self.state.request_exit()  -- Exit immediately after insertion
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
