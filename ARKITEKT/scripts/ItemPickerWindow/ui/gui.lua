-- @noindex
-- ItemPickerWindow/ui/gui.lua
-- Main GUI orchestrator for window mode

local ImGui = require 'imgui' '0.10'
local Coordinator = require('ItemPickerWindow.ui.coordinator')
local LayoutView = require('ItemPickerWindow.ui.layout_view')
local ToolbarView = require('ItemPickerWindow.ui.toolbar_view')

local M = {}
local GUI = {}
GUI.__index = GUI

function M.create(config, state, controller, visualization)
  local self = setmetatable({
    config = config,
    state = state,
    controller = controller,
    visualization = visualization,
    coordinator = nil,
    layout_view = nil,
    toolbar_view = nil,
    initialized = false,
    data_loaded = false,
    loading_started = false,
  }, GUI)

  self.layout_view = LayoutView.new(config, state)
  self.toolbar_view = ToolbarView.new(config, state)

  return self
end

function GUI:initialize_once(ctx)
  if self.initialized then return end

  -- Store context
  self.ctx = ctx

  -- Initialize empty state so UI can render immediately
  self.state.samples = {}
  self.state.sample_indexes = {}
  self.state.midi_items = {}
  self.state.midi_indexes = {}
  self.state.audio_item_lookup = {}
  self.state.midi_item_lookup = {}

  -- Initialize disk cache
  local disk_cache = require('ItemPicker.data.disk_cache')
  disk_cache.init()

  -- Initialize job queue
  if not self.state.job_queue then
    local job_queue_module = require('ItemPicker.data.job_queue')
    self.state.job_queue = job_queue_module.new(10)
  end

  -- Create coordinator with TilesContainer panels
  self.coordinator = Coordinator.new(ctx, self.config, self.state, self.visualization)

  -- Store coordinator reference in state
  self.state.coordinator = self.coordinator

  self.initialized = true
end

function GUI:start_incremental_loading()
  if self.loading_started then return end

  reaper.ShowConsoleMsg("=== ItemPickerWindow: Starting lazy loading ===\n")

  local current_change_count = reaper.GetProjectStateChangeCount(0)
  self.state.last_change_count = current_change_count

  self.loading_start_time = reaper.time_precise()
  self.loading_started = true
  self.start_loading_next_frame = true
end

function GUI:update_state(ctx)
  -- Process incremental loading
  if self.state.is_loading then
    local is_complete, progress = self.controller.process_loading_batch(self.state)

    if is_complete then
      local elapsed = (reaper.time_precise() - self.loading_start_time) * 1000
      reaper.ShowConsoleMsg(string.format("=== ItemPickerWindow: Loading complete! (%.1fms) ===\n", elapsed))
      reaper.ShowConsoleMsg(string.format("[DEBUG] Loaded: %d audio groups, %d MIDI groups\n",
        #(self.state.sample_indexes or {}), #(self.state.midi_indexes or {})))

      if not self.state.skip_visualizations then
        local disk_cache = require('ItemPicker.data.disk_cache')
        local stats = disk_cache.preload_to_runtime(self.state.runtime_cache)
        if stats and stats.loaded > 0 then
          reaper.ShowConsoleMsg(string.format("[ItemPickerWindow] Loaded %d cached visualizations from disk\n", stats.loaded))
        end
      end

      self.data_loaded = true
    end
  end

  -- Check if we need to reorganize items
  if self.state.needs_reorganize and not self.state.is_loading then
    self.state.needs_reorganize = false
    if self.state.incremental_loader then
      local incremental_loader_module = require("ItemPicker.data.loaders.incremental_loader")
      incremental_loader_module.reorganize_items(
        self.state.incremental_loader,
        self.state.settings.group_items_by_name
      )
      self.state.samples = self.state.incremental_loader.samples
      self.state.sample_indexes = self.state.incremental_loader.sample_indexes
      self.state.midi_items = self.state.incremental_loader.midi_items
      self.state.midi_indexes = self.state.incremental_loader.midi_indexes
      incremental_loader_module.get_results(self.state.incremental_loader, self.state)
      self.state.runtime_cache.audio_filter_hash = nil
      self.state.runtime_cache.midi_filter_hash = nil
    end
  end

  -- Check if we need to recollect items (project changes)
  if self.state.needs_recollect and not self.state.is_loading then
    self.state.needs_recollect = false
    self.state.samples = {}
    self.state.sample_indexes = {}
    self.state.midi_items = {}
    self.state.midi_indexes = {}
    local fast_mode = true
    self.state.skip_visualizations = false
    self.controller.start_incremental_loading(self.state, 100, fast_mode)
  end

  -- Auto-reload on project changes (track item count)
  self.state.frame_count = (self.state.frame_count or 0) + 1
  if self.state.frame_count % 60 == 0 and not self.state.is_loading then
    local current_item_count = reaper.CountMediaItems(0)
    if self.state.last_item_count == nil then
      self.state.last_item_count = current_item_count
    elseif current_item_count ~= self.state.last_item_count then
      reaper.ShowConsoleMsg(string.format("[ItemPickerWindow] Item count changed (%d -> %d), reloading...\n",
        self.state.last_item_count, current_item_count))
      self.state.last_item_count = current_item_count
      self.state.needs_recollect = true
    end
  end

  -- Update animations
  self.coordinator:update_animations(0.016)

  -- Handle tile size shortcuts
  self.coordinator:handle_tile_size_shortcuts(ctx)

  -- Process async jobs
  if not self.state.skip_visualizations and self.state.job_queue and self.state.runtime_cache then
    local job_queue_module = require('ItemPicker.data.job_queue')
    if self.state.is_loading then
      self.state.job_queue.max_per_frame = 20
    else
      self.state.job_queue.max_per_frame = 5
    end
    job_queue_module.process_jobs(
      self.state.job_queue,
      self.visualization,
      self.state.runtime_cache,
      ctx
    )
  end
end

function GUI:draw(ctx, shell_state)
  self:initialize_once(ctx)

  -- Get draw list
  if not self.state.draw_list then
    self.state.draw_list = ImGui.GetWindowDrawList(ctx)
  end

  -- Start loading on second frame
  if not self.loading_started then
    self:start_incremental_loading()
  elseif self.start_loading_next_frame and not self.state.is_loading then
    self.start_loading_next_frame = false
    local fast_mode = true
    self.state.skip_visualizations = false
    self.controller.start_incremental_loading(self.state, 100, fast_mode)
  end

  -- Update state
  self:update_state(ctx)

  -- Store fonts in state for renderers
  self.state.icon_font = shell_state.fonts.icons
  self.state.icon_font_size = shell_state.fonts.icons_size or 14
  self.state.monospace_font = shell_state.fonts.monospace
  self.state.monospace_font_size = shell_state.fonts.monospace_size or 14

  -- Draw toolbar at top
  local toolbar_height = self.toolbar_view:draw(ctx, shell_state)

  -- Add gap between toolbar and panels
  local gap = 8
  local start_x, start_y = ImGui.GetCursorScreenPos(ctx)
  ImGui.SetCursorScreenPos(ctx, start_x, start_y + gap)

  -- Draw layout (panels)
  self.layout_view:draw(ctx, self.coordinator, shell_state)

  -- Handle exit
  if self.state.exit or ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
    if shell_state.window and shell_state.window.request_close then
      shell_state.window:request_close()
    end
  end
end

return M
