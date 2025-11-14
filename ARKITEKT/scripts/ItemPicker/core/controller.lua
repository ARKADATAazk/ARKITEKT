-- @noindex
-- ItemPicker/core/controller.lua
-- Business logic controller

local M = {}

local reaper_interface
local utils

function M.init(reaper_interface_module, utils_module)
  reaper_interface = reaper_interface_module
  utils = utils_module
end

-- Collect all items from the project
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
end

-- Insert item at mouse position in arrange view
function M.insert_item_at_mouse(item, state)
  if not item then return false end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local success = reaper_interface.InsertItemAtMousePos(item, state)

  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock("Insert Item from ItemPicker", -1)

  return success
end

return M
