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
    data_loaded = false,
    load_frame_counter = 0,
    incremental_loader = nil,
    loading_started = false,
  }, GUI)

  return self
end

function GUI:initialize_once(ctx)
  if self.initialized then return end

  -- Initialize domain modules (lightweight, immediate)
  if not self.state.cache then
    self.state.cache = self.cache_mgr.new(self.config.CACHE.MAX_ENTRIES)
  end

  if not self.state.job_queue then
    local job_queue_module = require('ItemPicker.domain.job_queue')
    -- Start with burst mode: 10 jobs/frame during initial load
    self.state.job_queue = job_queue_module.new(10)
  end

  -- Initialize empty state so UI can render immediately
  self.state.samples = {}
  self.state.sample_indexes = {}
  self.state.midi_items = {}
  self.state.midi_indexes = {}
  self.state.audio_item_lookup = {}
  self.state.midi_item_lookup = {}

  -- Create coordinator and layout view with empty data
  self.coordinator = Coordinator.new(ctx, self.config, self.state, self.visualization, self.cache_mgr)
  self.layout_view = LayoutView.new(self.config, self.state, self.coordinator)

  self.initialized = true
end

-- Start incremental loading (non-blocking)
function GUI:start_incremental_loading()
  if self.loading_started then return end

  reaper.ShowConsoleMsg("=== ItemPicker: Starting data loading ===\n")

  local current_change_count = reaper.GetProjectStateChangeCount(0)
  self.state.last_change_count = current_change_count

  -- Try loading cached item data first (INSTANT)
  local cached_data = self.cache_mgr.load_items_data_from_disk()

  if cached_data and cached_data.change_count == current_change_count then
    reaper.ShowConsoleMsg("Cache HIT! Loading from disk (instant)\n")

    -- Populate state with cached metadata (no item pointers yet)
    self.state.sample_indexes = cached_data.sample_indexes or {}
    self.state.midi_indexes = cached_data.midi_indexes or {}

    -- Create empty samples/midi_items structures
    self.state.samples = {}
    self.state.midi_items = {}

    -- Populate with cached metadata (dummy item pointers for now)
    for filename, meta_items in pairs(cached_data.samples_meta or {}) do
      self.state.samples[filename] = {}
      for _, meta in ipairs(meta_items) do
        -- Placeholder: [nil, name, track_muted, item_muted, uuid]
        table.insert(self.state.samples[filename], {
          nil,  -- Item pointer will be populated by validation
          meta.name,
          track_muted = meta.track_muted,
          item_muted = meta.item_muted,
          uuid = meta.uuid
        })
      end
    end

    for key, meta_items in pairs(cached_data.midi_meta or {}) do
      self.state.midi_items[key] = {}
      for _, meta in ipairs(meta_items) do
        table.insert(self.state.midi_items[key], {
          nil,  -- Item pointer will be populated by validation
          meta.name,
          track_muted = meta.track_muted,
          item_muted = meta.item_muted,
          uuid = meta.uuid
        })
      end
    end

    -- Build UUID lookup tables
    self.state.audio_item_lookup = {}
    for filename, items in pairs(self.state.samples) do
      for _, item_data in ipairs(items) do
        if item_data.uuid then
          self.state.audio_item_lookup[item_data.uuid] = item_data
        end
      end
    end

    self.state.midi_item_lookup = {}
    for key, items in pairs(self.state.midi_items) do
      for _, item_data in ipairs(items) do
        if item_data.uuid then
          self.state.midi_item_lookup[item_data.uuid] = item_data
        end
      end
    end

    -- Mark as loaded (UI can render immediately with cached data)
    self.data_loaded = true
    self.loading_started = true

    reaper.ShowConsoleMsg("Cache loaded! UI ready instantly\n")
    reaper.ShowConsoleMsg("TODO: Background validation not implemented yet\n")

  else
    -- Cache miss or stale, use incremental loader
    if not cached_data then
      reaper.ShowConsoleMsg("Cache MISS! No cached data found\n")
    else
      reaper.ShowConsoleMsg("Cache STALE! Change count mismatch\n")
    end

    reaper.ShowConsoleMsg("Using incremental loader (50 items/frame)\n")
    local IncrementalLoader = require('ItemPicker.domain.incremental_loader')
    self.incremental_loader = IncrementalLoader.new(self.controller.reaper_interface, 50)
    IncrementalLoader.start_loading(self.incremental_loader, self.state, self.state.settings)
    self.loading_started = true
  end
end

-- Process incremental loading batch (called every frame)
function GUI:process_incremental_loading()
  if self.data_loaded or not self.incremental_loader then return end

  local IncrementalLoader = require('ItemPicker.domain.incremental_loader')
  local is_complete, progress = IncrementalLoader.process_batch(self.incremental_loader, self.state, self.state.settings)

  -- Update state with current results (even if not complete)
  IncrementalLoader.get_results(self.incremental_loader, self.state)

  if is_complete then
    reaper.ShowConsoleMsg("=== ItemPicker: Loading complete! ===\n")
    self.data_loaded = true

    -- Save item data to disk cache for next launch
    reaper.ShowConsoleMsg("Saving item data to disk cache...\n")
    self.cache_mgr.save_items_data_to_disk(self.state)

    -- After initial load burst, throttle to 2 jobs/frame for smooth FPS
    if self.state.job_queue then
      self.state.job_queue.max_per_frame = 2
    end
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
