-- @noindex
-- ItemPicker/ui/gui.lua
-- GUI orchestrator

local ImGui = require 'imgui' '0.10'
local Coordinator = require('ItemPicker.ui.grids.coordinator')
local LayoutView = require('ItemPicker.ui.components.layout_view')
local TrackFilter = require('ItemPicker.ui.components.track_filter')

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

  -- Initialize disk cache for waveform/thumbnail persistence
  -- Pre-loading will happen incrementally as items are loaded
  local disk_cache = require('ItemPicker.data.disk_cache')
  local cache_dir = disk_cache.init()

  -- Initialize job queue for lazy waveform/thumbnail generation
  if not self.state.job_queue then
    local job_queue_module = require('ItemPicker.data.job_queue')
    -- Process more jobs per frame during loading, fewer during normal operation
    self.state.job_queue = job_queue_module.new(10) -- Process 10 jobs per frame
  end

  -- Create coordinator and layout view with empty data
  self.coordinator = Coordinator.new(ctx, self.config, self.state, self.visualization)
  self.layout_view = LayoutView.new(self.config, self.state, self.coordinator)

  -- Store coordinator reference in state for drag cleanup access
  self.state.coordinator = self.coordinator

  self.initialized = true
end

-- Start incremental loading (non-blocking)
function GUI:start_incremental_loading()
  if self.loading_started then return end

  local current_change_count = reaper.GetProjectStateChangeCount(0)
  self.state.last_change_count = current_change_count

  -- LAZY LOAD: Start loading on NEXT frame (not this one!)
  -- This allows UI to show immediately
  self.loading_start_time = reaper.time_precise()
  self.loading_started = true
  self.start_loading_next_frame = true
end


function GUI:draw(ctx, shell_state)
  self:initialize_once(ctx)

  -- Get draw list (MUST be first, before any rendering)
  if not self.state.draw_list then
    self.state.draw_list = ImGui.GetWindowDrawList(ctx)
  end

  -- Start loading on SECOND frame (UI shows first)
  if not self.loading_started then
    self:start_incremental_loading()
  elseif self.start_loading_next_frame and not self.state.is_loading then
    -- Start actual loading NOW (after UI is shown)
    self.start_loading_next_frame = false

    -- Use fast mode (skip expensive chunk processing) but keep visualizations
    local fast_mode = true  -- Skip expensive chunk-based duplicate detection
    self.state.skip_visualizations = false  -- Show waveforms and MIDI thumbnails

    -- Smaller batches for smoother UI (100 items per frame)
    self.controller.start_incremental_loading(self.state, 100, fast_mode)
  end

  -- Process incremental loading batch every frame
  if self.state.is_loading then
    local is_complete, progress = self.controller.process_loading_batch(self.state)

    if is_complete then
      -- Skip disk cache in fast mode
      if not self.state.skip_visualizations then
        local disk_cache = require('ItemPicker.data.disk_cache')
        disk_cache.preload_to_runtime(self.state.runtime_cache)
      end

      self.data_loaded = true
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

  -- Check if track filter modal should be opened
  if self.state.open_track_filter_modal then
    self.state.open_track_filter_modal = nil
    TrackFilter.open_modal(self.state)
  end

  -- Get screen dimensions
  local SCREEN_W, SCREEN_H
  if is_overlay_mode and shell_state.overlay_state then
    -- Overlay mode: bounds already account for multi-monitor via overlay manager's JS API
    SCREEN_W = shell_state.overlay_state.width
    SCREEN_H = shell_state.overlay_state.height
  else
    -- Normal window mode: use viewport
    local viewport = ImGui.GetMainViewport(ctx)
    SCREEN_W, SCREEN_H = ImGui.Viewport_GetSize(viewport)
  end

  -- Get fonts
  local mini_font = shell_state.fonts.default
  local mini_font_size = shell_state.fonts.default_size or 14
  local big_font = shell_state.fonts.title
  local big_font_size = shell_state.fonts.title_size or 24

  -- Store icon font in state for renderers
  self.state.icon_font = shell_state.fonts.icons
  self.state.icon_font_size = shell_state.fonts.icons_size or 14

  -- Store monospace font in state for renderers
  self.state.monospace_font = shell_state.fonts.monospace
  self.state.monospace_font_size = shell_state.fonts.monospace_size or 14

  -- Process async jobs for waveform/thumbnail generation
  -- Skip job processing entirely if skip_visualizations is enabled
  if not self.state.skip_visualizations and self.state.job_queue and self.state.runtime_cache then
    local job_queue_module = require('ItemPicker.data.job_queue')

    -- Process more jobs during initial loading for faster startup
    if self.state.is_loading then
      self.state.job_queue.max_per_frame = 20 -- Aggressive during loading
    else
      self.state.job_queue.max_per_frame = 5 -- Conservative during normal operation
    end

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

  -- Check if we need to reorganize items (instant, no reload)
  if self.state.needs_reorganize and not self.state.is_loading then
    self.state.needs_reorganize = false

    -- Reorganize from raw pool (instant operation)
    if self.state.incremental_loader then
      local incremental_loader_module = require("ItemPicker.data.loaders.incremental_loader")

      incremental_loader_module.reorganize_items(
        self.state.incremental_loader,
        self.state.settings.group_items_by_name
      )

      -- Copy results to state
      self.state.samples = self.state.incremental_loader.samples
      self.state.sample_indexes = self.state.incremental_loader.sample_indexes
      self.state.midi_items = self.state.incremental_loader.midi_items
      self.state.midi_indexes = self.state.incremental_loader.midi_indexes

      -- Rebuild lookups
      incremental_loader_module.get_results(self.state.incremental_loader, self.state)

      -- Invalidate filter cache (items changed)
      self.state.runtime_cache.audio_filter_hash = nil
      self.state.runtime_cache.midi_filter_hash = nil
    end
  end

  -- Check if we need to recollect items from REAPER (project changes)
  if self.state.needs_recollect and not self.state.is_loading then
    self.state.needs_recollect = false

    -- Clear current items
    self.state.samples = {}
    self.state.sample_indexes = {}
    self.state.midi_items = {}
    self.state.midi_indexes = {}

    -- Use fast mode (skip expensive chunk processing) but keep visualizations
    local fast_mode = true  -- Skip expensive chunk-based duplicate detection
    self.state.skip_visualizations = false  -- Show waveforms and MIDI thumbnails
    self.controller.start_incremental_loading(self.state, 100, fast_mode)
  end

  -- Auto-reload on project changes (only in persistent window mode)
  -- Uses item count instead of project state count to avoid playback triggering reload
  if self.state.persistent_mode and not self.state.is_loading then
    self.state.frame_count = (self.state.frame_count or 0) + 1
    if self.state.frame_count % 60 == 0 then  -- Check every ~1 second at 60fps
      local current_item_count = reaper.CountMediaItems(0)
      if self.state.last_item_count == nil then
        self.state.last_item_count = current_item_count
      elseif current_item_count ~= self.state.last_item_count then
        self.state.last_item_count = current_item_count
        self.state.needs_recollect = true
      end
    end
  end

  ImGui.PushFont(ctx, mini_font, mini_font_size)
  reaper.PreventUIRefresh(1)

  -- If we should close, don't render anything - just exit immediately
  -- Runtime loop will detect the flag and handle cleanup/close
  if self.state.should_close_after_drop then
    reaper.PreventUIRefresh(-1)
    ImGui.PopFont(ctx)
    return
  end

  -- Check if dragging
  if not self.state.dragging then
    -- Normal mode - show main UI
    self.layout_view:render(ctx, big_font, big_font_size, "Item Picker", SCREEN_W, SCREEN_H, is_overlay_mode)

    -- Render track filter modal on top if active
    TrackFilter.render_modal(ctx, self.state, {
      x = 0,
      y = 0,
      width = SCREEN_W,
      height = SCREEN_H
    })
  else
    -- Dragging mode - don't create main window at all
    -- The drag_handler creates its own windows (drag_target_window and MouseFollower)
    -- which allows the arrange window to receive mouse input
    local should_insert = self.drag_handler.handle_drag_logic(ctx, self.state, mini_font, self.visualization)
    if should_insert and not self.state.drop_completed then
      -- Check modifier keys for drop behavior
      -- If we have captured state (from multi-drop sequence), verify keys are still held
      local shift, ctrl, alt
      if self.state.captured_shift ~= nil or self.state.captured_ctrl ~= nil then
        -- Check if keys are ACTUALLY still pressed using Reaper API (works without ImGui focus)
        local mouse_state = reaper.JS_Mouse_GetState(0xFF)
        local shift_actual = (mouse_state & 8) ~= 0  -- Bit 3 = Shift
        local ctrl_actual = (mouse_state & 4) ~= 0   -- Bit 2 = Ctrl
        local alt_actual = (mouse_state & 16) ~= 0   -- Bit 4 = Alt

        -- Check if user switched modifiers (e.g., pressing CTRL during SHIFT multi-drop)
        -- Always capture ALT state regardless of which branch we take
        if self.state.captured_shift and ctrl_actual and not shift_actual then
          shift = false
          ctrl = true
          alt = alt_actual
          self.state.captured_shift = nil
          self.state.captured_ctrl = nil
        elseif self.state.captured_shift and not shift_actual then
          shift = false
          ctrl = false
          alt = alt_actual
          self.state.captured_shift = nil
          self.state.captured_ctrl = nil
        elseif self.state.captured_ctrl and not ctrl_actual then
          shift = false
          ctrl = false
          alt = alt_actual
          self.state.captured_shift = nil
          self.state.captured_ctrl = nil
        else
          shift = self.state.captured_shift or false
          ctrl = self.state.captured_ctrl or false
          alt = alt_actual
        end
      else
        -- First drop - check keys directly
        shift = ImGui.IsKeyDown(ctx, ImGui.Key_LeftShift) or ImGui.IsKeyDown(ctx, ImGui.Key_RightShift)
        ctrl = ImGui.IsKeyDown(ctx, ImGui.Key_LeftCtrl) or ImGui.IsKeyDown(ctx, ImGui.Key_RightCtrl)
        alt = ImGui.IsKeyDown(ctx, ImGui.Key_LeftAlt) or ImGui.IsKeyDown(ctx, ImGui.Key_RightAlt)
      end

      -- Set close flag BEFORE inserting for normal drops
      if not shift and not ctrl then
        if not self.state.persistent_mode then
          self.state.should_close_after_drop = true
        end
      end

      -- Save dragging_keys before insert in case we need them for Shift+multi-drop
      -- (InsertMediaItem clears them unconditionally)
      local saved_dragging_keys = self.state.dragging_keys
      local saved_dragging_is_audio = self.state.dragging_is_audio

      -- Check if ALT is held for pooled MIDI copy (only for MIDI items)
      -- Use XOR logic: ALT inverts the original pooled state (matches drag_handler display)
      local use_pooled_copy = false
      if not self.state.dragging_is_audio then
        local original_pooled = self.state.original_pooled_midi_state or false
        local effective_pooled = (original_pooled and not alt) or (not original_pooled and alt)
        use_pooled_copy = effective_pooled
        -- Debug output
        reaper.ShowConsoleMsg(string.format("[POOL DEBUG] alt=%s, original=%s, effective=%s, use_pooled=%s\n",
          tostring(alt), tostring(original_pooled), tostring(effective_pooled), tostring(use_pooled_copy)))
      end

      -- Insert the item (pooled copy if ALT held for MIDI)
      self.controller.insert_item_at_mouse(self.state.item_to_add, self.state, use_pooled_copy)
      self.state.drop_completed = true  -- Mark as completed

      if shift then
        -- SHIFT: Keep dragging active for multi-drop
        self.state.dragging_keys = saved_dragging_keys
        self.state.dragging_is_audio = saved_dragging_is_audio
        self.state.drop_completed = false
        self.state.waiting_for_new_click = true
        self.state.mouse_was_pressed_after_drop = false
        self.state.should_close_after_drop = false  -- Explicitly clear close flag
        -- IMPORTANT: Capture modifier state NOW while we still have focus
        -- ImGui will lose focus when user clicks on arrange view
        self.state.captured_shift = shift
        self.state.captured_ctrl = ctrl
      elseif ctrl then
        -- CTRL: End drag but keep ItemPicker open
        self.state.end_drag()
        self.state.waiting_for_new_click = false
        self.state.should_close_after_drop = false  -- Explicitly clear close flag
        -- Clear captured state
        self.state.captured_shift = nil
        self.state.captured_ctrl = nil
      else
        -- Normal drop behavior
        if self.state.persistent_mode then
          -- Persistent mode: End drag but keep window open (like CTRL drop)
          self.state.end_drag()
          self.state.waiting_for_new_click = false
          self.state.should_close_after_drop = false
        else
          -- Normal drop: DON'T end drag - keep State.dragging active
          -- This keeps us in the dragging branch (no overlay render)
          -- Cleanup will handle clearing drag state
          self.state.waiting_for_new_click = false
          -- Flag is already set before insert, will close on next render
        end
        -- Clear captured state
        self.state.captured_shift = nil
        self.state.captured_ctrl = nil
      end
    end

    -- Clear waiting flag once mouse is pressed again (for SHIFT mode)
    if self.state.waiting_for_new_click and self.state.mouse_was_pressed_after_drop then
      self.state.waiting_for_new_click = false
      self.state.drop_completed = false
    end

    self.drag_handler.render_drag_preview(ctx, self.state, mini_font, self.visualization, self.config)
  end

  reaper.PreventUIRefresh(-1)
  ImGui.PopFont(ctx)

  -- Handle exit
  if self.state.exit or ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
    -- Clear drag state if still dragging on exit (e.g., Escape pressed)
    if self.state.dragging then
      self.state.end_drag()
    end

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
