-- Incremental project item loader
-- Processes items in small batches per frame to avoid blocking UI

local M = {}

function M.new(reaper_interface, batch_size)
  local loader = {
    reaper_interface = reaper_interface,
    batch_size = batch_size or 50, -- Process 50 items per frame

    -- Loading state
    is_loading = false,
    all_items = nil,
    current_index = 0,

    -- Track chunks (loaded once at start)
    track_chunks = nil,
    item_chunks = {},

    -- Results
    samples = {},
    sample_indexes = {},
    midi_items = {},
    midi_indexes = {},
  }

  return loader
end

-- Start incremental loading
function M.start_loading(loader, state, settings)
  if loader.is_loading then return end

  loader.is_loading = true
  loader.current_index = 0

  -- Get track chunks once (relatively fast)
  loader.track_chunks = loader.reaper_interface.GetAllTrackStateChunks()

  -- Collect all items into a flat list
  loader.all_items = {}
  local all_tracks = loader.reaper_interface.GetAllTracks()

  for _, track in pairs(all_tracks) do
    if reaper.GetMediaTrackInfo_Value(track, "B_SHOWINTCP") ~= 0 and
       not loader.reaper_interface.IsParentFrozen(track, loader.track_chunks) then
      local track_items = loader.reaper_interface.GetItemInTrack(track)
      for _, item in pairs(track_items) do
        if item and reaper.ValidatePtr2(0, item, "MediaItem*") then
          table.insert(loader.all_items, {item = item, track = track})
        end
      end
    end
  end

  -- Reset results
  loader.samples = {}
  loader.sample_indexes = {}
  loader.midi_items = {}
  loader.midi_indexes = {}
  loader.item_chunks = {}
end

-- Process one batch (call this every frame)
-- Returns: is_complete, progress (0-1)
function M.process_batch(loader, state, settings)
  if not loader.is_loading then return true, 1.0 end

  local total_items = #loader.all_items
  if total_items == 0 then
    loader.is_loading = false
    return true, 1.0
  end

  local batch_start_time = reaper.time_precise()
  local batch_end = math.min(loader.current_index + loader.batch_size, total_items)

  -- Process this batch
  local reaper_time = 0
  local processing_time = 0

  for i = loader.current_index + 1, batch_end do
    local entry = loader.all_items[i]
    local item = entry.item
    local track = entry.track

    -- Get and clean chunk for this item
    local t1 = reaper.time_precise()
    local _, chunk = reaper.GetItemStateChunk(item, "")
    local take = reaper.GetActiveTake(item)
    local is_midi = take and reaper.TakeIsMIDI(take) or false
    local t2 = reaper.time_precise()
    reaper_time = reaper_time + (t2 - t1)

    local utils = require('ItemPicker.services.utils')
    chunk = utils.RemoveKeyFromChunk(chunk, "POSITION")
    chunk = utils.RemoveKeyFromChunk(chunk, "IGUID")
    chunk = utils.RemoveKeyFromChunk(chunk, "IID")
    chunk = utils.RemoveKeyFromChunk(chunk, "GUID")
    local chunk_id = loader.reaper_interface.ItemChunkID(item)
    loader.item_chunks[chunk_id] = chunk

    if take then
      if is_midi then
        -- Process MIDI item
        M.process_midi_item(loader, item, track, chunk, chunk_id, state)
      else
        -- Process audio item
        M.process_audio_item(loader, item, track, chunk, chunk_id, state)
      end
    end

    local t3 = reaper.time_precise()
    processing_time = processing_time + (t3 - t2)
  end

  loader.current_index = batch_end
  local progress = loader.current_index / total_items

  local batch_time = (reaper.time_precise() - batch_start_time) * 1000
  local reaper_ms = reaper_time * 1000
  local processing_ms = processing_time * 1000
  reaper.ShowConsoleMsg(string.format("Batch %d-%d: %.1fms total (REAPER: %.1fms, Processing: %.1fms)\n",
    batch_end - loader.batch_size + 1, batch_end, batch_time, reaper_ms, processing_ms))

  if loader.current_index >= total_items then
    loader.is_loading = false
    return true, 1.0
  end

  return false, progress
end

function M.process_audio_item(loader, item, track, chunk, chunk_id, state)
  local UUID = require('rearkitekt.core.uuid')
  local take = reaper.GetActiveTake(item)

  local source = reaper.GetMediaItemTake_Source(take)
  local _, _, _, _, _, reverse = reaper.BR_GetMediaSourceProperties(take)
  if reverse then
    source = reaper.GetMediaSourceParent(source)
  end

  local filename = reaper.GetMediaSourceFileName(source)
  if not filename then return end

  -- Check for duplicates
  if loader.samples[filename] then
    for _, existing in ipairs(loader.samples[filename]) do
      if loader.item_chunks[chunk_id] == loader.item_chunks[loader.reaper_interface.ItemChunkID(existing[1])] then
        return -- Duplicate, skip
      end
    end
  else
    table.insert(loader.sample_indexes, filename)
    loader.samples[filename] = {}
  end

  local item_name = (filename:match("[^/\\]+$") or ""):match("(.+)%..+$") or filename:match("[^/\\]+$")
  local track_muted = reaper.GetMediaTrackInfo_Value(track, "B_MUTE") == 1 or loader.reaper_interface.IsParentMuted(track)
  local item_muted = reaper.GetMediaItemInfo_Value(item, "B_MUTE") == 1

  table.insert(loader.samples[filename], {
    item,
    item_name,
    track_muted = track_muted,
    item_muted = item_muted,
    uuid = UUID.generate()
  })
end

function M.process_midi_item(loader, item, track, chunk, chunk_id, state)
  local UUID = require('rearkitekt.core.uuid')
  local settings = state.settings or {}

  local track_guid = reaper.GetTrackGUID(track)
  local track_name = ({reaper.GetTrackName(track)})[2] or "Unnamed Track"

  local key = settings.split_midi_by_track and track_guid or "midi"
  local display_name = settings.split_midi_by_track and track_name or "MIDI"

  -- Check for duplicates
  if loader.midi_items[key] then
    for _, existing in ipairs(loader.midi_items[key]) do
      if loader.item_chunks[chunk_id] == loader.item_chunks[loader.reaper_interface.ItemChunkID(existing[1])] then
        return -- Duplicate, skip
      end
    end
  else
    table.insert(loader.midi_indexes, key)
    loader.midi_items[key] = {}
  end

  local track_muted = reaper.GetMediaTrackInfo_Value(track, "B_MUTE") == 1 or loader.reaper_interface.IsParentMuted(track)
  local item_muted = reaper.GetMediaItemInfo_Value(item, "B_MUTE") == 1

  table.insert(loader.midi_items[key], {
    item,
    display_name,
    track_muted = track_muted,
    item_muted = item_muted,
    uuid = UUID.generate()
  })
end

-- Get current results (safe to call anytime)
function M.get_results(loader, state)
  state.track_chunks = loader.track_chunks
  state.item_chunks = loader.item_chunks
  state.samples = loader.samples
  state.sample_indexes = loader.sample_indexes
  state.midi_items = loader.midi_items
  state.midi_indexes = loader.midi_indexes

  -- Build UUID lookup tables
  state.audio_item_lookup = {}
  for filename, items in pairs(loader.samples) do
    for _, item_data in ipairs(items) do
      if item_data.uuid then
        state.audio_item_lookup[item_data.uuid] = item_data
      end
    end
  end

  state.midi_item_lookup = {}
  for track_guid, items in pairs(loader.midi_items) do
    for _, item_data in ipairs(items) do
      if item_data.uuid then
        state.midi_item_lookup[item_data.uuid] = item_data
      end
    end
  end
end

return M
