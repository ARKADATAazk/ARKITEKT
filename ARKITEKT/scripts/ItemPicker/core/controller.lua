-- @noindex
-- ItemPicker/core/controller.lua
-- Business logic controller

local M = {}

local reaper_interface
local utils
local incremental_loader_module

function M.init(reaper_interface_module, utils_module)
  reaper_interface = reaper_interface_module
  utils = utils_module
  incremental_loader_module = require('ItemPicker.data.loaders.incremental_loader')
  -- Expose reaper_interface for incremental loader
  M.reaper_interface = reaper_interface_module
end

-- Start incremental loading (non-blocking)
function M.start_incremental_loading(state, batch_size, fast_mode)
  if not state.incremental_loader then
    state.incremental_loader = incremental_loader_module.new(reaper_interface, batch_size or 50)
  end

  -- Set fast mode flag (skips expensive chunk processing)
  state.incremental_loader.fast_mode = fast_mode or false

  incremental_loader_module.start_loading(state.incremental_loader, state, state.settings)
  state.is_loading = true
  state.loading_progress = 0
end

-- Process one batch of loading (call every frame)
-- Returns: is_complete, progress (0-1)
function M.process_loading_batch(state)
  if not state.incremental_loader or not state.is_loading then
    return true, 1.0
  end

  local is_complete, progress = incremental_loader_module.process_batch(
    state.incremental_loader,
    state,
    state.settings
  )

  if is_complete then
    -- Loading complete, update state
    incremental_loader_module.get_results(state.incremental_loader, state)
    state.is_loading = false
    state.loading_progress = 1.0
    -- Keep incremental_loader alive for reorganization (toggling group_by_name)
    -- state.incremental_loader = nil
  else
    state.loading_progress = progress
  end

  return is_complete, progress
end

-- Collect all items from the project (legacy synchronous method - kept for compatibility)
function M.collect_project_items(state)
  -- Get track and item chunks for comparison
  state.track_chunks = reaper_interface.GetAllTrackStateChunks()
  state.item_chunks = reaper_interface.GetAllCleanedItemChunks()

  -- Get samples and MIDI items
  local samples, sample_indexes = reaper_interface.GetProjectSamples(state.settings, state)
  local midi_items, midi_indexes = reaper_interface.GetProjectMIDI(state.settings, state)

  state.samples = samples
  state.sample_indexes = sample_indexes
  state.midi_items = midi_items
  state.midi_indexes = midi_indexes

  -- Build UUID lookup tables for O(1) access
  state.audio_item_lookup = {}
  for filename, items in pairs(samples) do
    for _, item_data in ipairs(items) do
      if item_data.uuid then
        state.audio_item_lookup[item_data.uuid] = item_data
      end
    end
  end

  state.midi_item_lookup = {}
  for track_guid, items in pairs(midi_items) do
    for _, item_data in ipairs(items) do
      if item_data.uuid then
        state.midi_item_lookup[item_data.uuid] = item_data
      end
    end
  end
end

-- Insert item at mouse position in arrange view
function M.insert_item_at_mouse(item, state, use_pooled_copy)
  if not item then return false end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local success = reaper_interface.InsertItemAtMousePos(item, state, use_pooled_copy)

  reaper.PreventUIRefresh(-1)
  local undo_msg = use_pooled_copy and "Insert Pooled MIDI Item from ItemPicker" or "Insert Item from ItemPicker"
  reaper.Undo_EndBlock(undo_msg, -1)

  return success
end

return M
