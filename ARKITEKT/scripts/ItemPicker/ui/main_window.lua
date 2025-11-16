-- @noindex
-- ItemPicker/ui/gui.lua
-- GUI orchestrator

local ImGui = require 'imgui' '0.10'
local Coordinator = require('ItemPicker.ui.grids.coordinator')
local LayoutView = require('ItemPicker.ui.components.layout_view')

local M = {}
local GUI = {}
GUI.__index = GUI

function M.new(config, state, controller, visualization, drag_handler)
  local self = setmetatable({
    config = config,
    state = state,
    controller = controller,
    visualization = visualization,
    drag_handler = drag_handler,

    coordinator = nil,
    layout_view = nil,

    initialized = false,
    data_loaded = false,
    load_frame_counter = 0,
    incremental_loader = nil,
    loading_started = false,
  }, GUI)

  return self
end

function GUI:initialize_once(ctx)
  if self.initialized then return end

  -- Store context for later use
  self.ctx = ctx

  -- Initialize empty state so UI can render immediately
  self.state.samples = {}
  self.state.sample_indexes = {}
  self.state.midi_items = {}
  self.state.midi_indexes = {}
  self.state.audio_item_lookup = {}
  self.state.midi_item_lookup = {}

  -- Initialize job queue for lazy waveform/thumbnail generation
  if not self.state.job_queue then
    local job_queue_module = require('ItemPicker.data.job_queue')
    self.state.job_queue = job_queue_module.new(3) -- Process 3 jobs per frame
  end

  -- Create coordinator and layout view with empty data
  self.coordinator = Coordinator.new(ctx, self.config, self.state, self.visualization)
  self.layout_view = LayoutView.new(self.config, self.state, self.coordinator)

  self.initialized = true
end

-- Start incremental loading (non-blocking)
-- Start incremental loading (non-blocking)
function GUI:start_incremental_loading()
  if self.loading_started then return end

  reaper.ShowConsoleMsg("=== ItemPicker: Starting data loading ===
")

  local current_change_count = reaper.GetProjectStateChangeCount(0)
  self.state.last_change_count = current_change_count

  -- Use incremental loader to load items
  reaper.ShowConsoleMsg("Using incremental loader (50 items/frame)
")
  local IncrementalLoader = require('ItemPicker.data.loaders.incremental_loader')
  self.incremental_loader = IncrementalLoader.new(self.controller.reaper_interface, 50)
  IncrementalLoader.start_loading(self.incremental_loader, self.state, self.state.settings)
  self.loading_started = true
end

-- Process incremental loading batch (called every frame)
function GUI:process_incremental_loading()
  if self.data_loaded or not self.incremental_loader then return end

  local IncrementalLoader = require('ItemPicker.data.loaders.incremental_loader')
  local is_complete, progress = IncrementalLoader.process_batch(self.incremental_loader, self.state, self.state.settings)

  -- Update state with current results (even if not complete)
  IncrementalLoader.get_results(self.incremental_loader, self.state)

  if is_complete then
    reaper.ShowConsoleMsg("=== ItemPicker: Loading complete! ===
")
    self.data_loaded = true
  end
end

function GUI:draw(ctx, shell_state)
  self:initialize_once(ctx)

  -- Get draw list (MUST be first, before any rendering)
  if not self.state.draw_list then
    self.state.draw_list = ImGui.GetWindowDrawList(ctx)
  end

  -- Start incremental loading after fade animation completes (~20 frames = 333ms at 60fps)
  -- This ensures smooth fade-in before heavy processing begins
  if not self.loading_started then
    self.load_frame_counter = self.load_frame_counter + 1
    if self.load_frame_counter >= 20 then
      self:start_incremental_loading()
    end
  end

  -- Get overlay alpha for cascade animation
  local is_overlay_mode = shell_state.is_overlay_mode == true
  local overlay = shell_state.overlay

  local overlay_alpha = 1.0
  if is_overlay_mode and overlay and overlay.alpha then
    overlay_alpha = overlay.alpha:value()
  end
  self.state.overlay_alpha = overlay_alpha

  -- Only start processing batches once fade is nearly complete (alpha > 0.95)
  if self.loading_started and not self.data_loaded and overlay_alpha > 0.95 then
    self:process_incremental_loading()
  end

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

  -- Process async jobs for waveform/thumbnail generation
  if self.state.job_queue and self.state.runtime_cache then
    local job_queue_module = require('ItemPicker.data.job_queue')
    job_queue_module.process_jobs(
      self.state.job_queue,
      self.visualization,
      self.state.runtime_cache,
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
