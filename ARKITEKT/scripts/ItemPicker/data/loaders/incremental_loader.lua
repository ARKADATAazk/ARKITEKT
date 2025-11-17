-- Incremental project item loader
-- Processes items in small batches per frame to avoid blocking UI

local M = {}

-- Generate stable UUID from item GUID (for cache consistency)
local function get_item_uuid(item)
  -- Use REAPER's built-in item GUID for stable identification
  local guid = reaper.BR_GetMediaItemGUID(item)
  if guid then
    return guid
  end

  -- Fallback: generate hash from item properties
  local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local track = reaper.GetMediaItem_Track(item)
  local track_num = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")

  return string.format("item_%d_%.6f_%.6f", track_num, pos, length)
end

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

    -- Raw item pool (ALL items with metadata, before grouping)
    raw_audio_items = {},  -- { {item, item_name, filename, track_color, track_muted, item_muted, uuid}, ... }
    raw_midi_items = {},   -- { {item, item_name, track_color, track_muted, item_muted, uuid}, ... }

    -- Results (organized by grouping)
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
  loader.initialization_complete = false

  -- DON'T do ANY blocking work here!
  -- Everything happens in first batch of process_batch()

  reaper.ShowConsoleMsg(string.format("[ItemPicker] Starting lazy loading (fast_mode: %s)\n",
    tostring(loader.fast_mode or false)))

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

  -- FIRST BATCH: Do initialization (moved from start_loading to avoid blocking)
  if not loader.initialization_complete then
    local init_start = reaper.time_precise()

    local all_tracks = loader.reaper_interface.GetAllTracks()

    -- FAST MODE: Skip expensive frozen check and mute status computation
    if loader.fast_mode then
      -- Just collect all items from all visible tracks (NO frozen check, NO mute computation)
      loader.all_items = {}
      for _, track in pairs(all_tracks) do
        if reaper.GetMediaTrackInfo_Value(track, "B_SHOWINTCP") ~= 0 then
          local track_items = loader.reaper_interface.GetItemInTrack(track)
          for _, item in pairs(track_items) do
            if item and reaper.ValidatePtr2(0, item, "MediaItem*") then
              table.insert(loader.all_items, {item = item, track = track})
            end
          end
        end
      end

      -- Minimal track_chunks for compatibility
      loader.track_chunks = {}
      loader.track_muted_cache = {}  -- Will compute on-demand per item
    else
      -- NORMAL MODE: Full initialization with frozen check and mute caching
      loader.track_chunks = loader.reaper_interface.GetAllTrackStateChunks()

      loader.track_muted_cache = {}
      for _, track in pairs(all_tracks) do
        local track_muted = reaper.GetMediaTrackInfo_Value(track, "B_MUTE") == 1 or loader.reaper_interface.IsParentMuted(track)
        loader.track_muted_cache[track] = track_muted
      end

      loader.all_items = {}
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
    end

    loader.initialization_complete = true

    local init_time = (reaper.time_precise() - init_start) * 1000
    reaper.ShowConsoleMsg(string.format("[ItemPicker] Initialized: %d items in %.1fms\n", #loader.all_items, init_time))

    -- Return to allow UI to update (don't process items this frame)
    return false, 0.0
  end

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

    local take = reaper.GetActiveTake(item)
    if not take then goto next_item end

    local is_midi = reaper.TakeIsMIDI(take)

    if loader.fast_mode then
      -- FAST MODE: Skip expensive chunk processing, no duplicate detection
      local t1 = reaper.time_precise()

      if is_midi then
        M.process_midi_item_fast(loader, item, track, state)
      else
        M.process_audio_item_fast(loader, item, track, state)
      end

      local t2 = reaper.time_precise()
      processing_time = processing_time + (t2 - t1)
    else
      -- NORMAL MODE: Full chunk processing for duplicate detection
      local t1 = reaper.time_precise()
      local _, chunk = reaper.GetItemStateChunk(item, "")
      local t2 = reaper.time_precise()
      reaper_time = reaper_time + (t2 - t1)

      local utils = require('ItemPicker.services.utils')
      chunk = utils.RemoveKeyFromChunk(chunk, "POSITION")
      chunk = utils.RemoveKeyFromChunk(chunk, "IGUID")
      chunk = utils.RemoveKeyFromChunk(chunk, "IID")
      chunk = utils.RemoveKeyFromChunk(chunk, "GUID")
      local chunk_id = loader.reaper_interface.ItemChunkID(item)
      loader.item_chunks[chunk_id] = chunk

      if is_midi then
        M.process_midi_item(loader, item, track, chunk, chunk_id, state)
      else
        M.process_audio_item(loader, item, track, chunk, chunk_id, state)
      end

      local t3 = reaper.time_precise()
      processing_time = processing_time + (t3 - t2)
    end

    ::next_item::
  end

  loader.current_index = batch_end
  local progress = loader.current_index / total_items

  local batch_time = (reaper.time_precise() - batch_start_time) * 1000
  local reaper_ms = reaper_time * 1000
  local processing_ms = processing_time * 1000
  reaper.ShowConsoleMsg(string.format("Batch %d-%d: %.1fms total (REAPER: %.1fms, Processing: %.1fms)\n",
    batch_end - loader.batch_size + 1, batch_end, batch_time, reaper_ms, processing_ms))

  if loader.current_index >= total_items then
    -- All items loaded - now organize them based on grouping setting
    M.reorganize_items(loader, state.settings.group_items_by_name)
    loader.is_loading = false
    return true, 1.0
  end

  return false, progress
end

-- Fast mode: Skip chunk-based duplicate detection
function M.process_audio_item_fast(loader, item, track, state)
  local take = reaper.GetActiveTake(item)
  if not take then return end

  -- Use cached source directly (skip reverse checking in fast mode)
  local source = reaper.GetMediaItemTake_Source(take)
  local filename = reaper.GetMediaSourceFileName(source)
  if not filename then return end

  local item_name = reaper.GetTakeName(take)
  if not item_name or item_name == "" then
    item_name = (filename:match("[^/\\]+$") or ""):match("(.+)%..+$") or filename:match("[^/\\]+$")
  end

  -- Compute mute status and track color ONCE during loading
  local track_muted = reaper.GetMediaTrackInfo_Value(track, "B_MUTE") == 1
  local item_muted = reaper.GetMediaItemInfo_Value(item, "B_MUTE") == 1
  local track_color = reaper.GetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR")

  local uuid = get_item_uuid(item)

  -- Store in raw pool (before grouping)
  table.insert(loader.raw_audio_items, {
    item = item,
    item_name = item_name,
    filename = filename,
    track_color = track_color,
    track_muted = track_muted,
    item_muted = item_muted,
    uuid = uuid,
  })
end

-- Normal mode: Full chunk-based duplicate detection
function M.process_audio_item(loader, item, track, chunk, chunk_id, state)
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

  local item_name = reaper.GetTakeName(take)
  if not item_name or item_name == "" then
    item_name = (filename:match("[^/\\]+$") or ""):match("(.+)%..+$") or filename:match("[^/\\]+$")
  end

  local track_muted = reaper.GetMediaTrackInfo_Value(track, "B_MUTE") == 1 or loader.reaper_interface.IsParentMuted(track)
  local item_muted = reaper.GetMediaItemInfo_Value(item, "B_MUTE") == 1

  table.insert(loader.samples[filename], {
    item,
    item_name,
    track_muted = track_muted,
    item_muted = item_muted,
    uuid = get_item_uuid(item)
  })
end

-- Fast mode: Skip chunk-based duplicate detection
function M.process_midi_item_fast(loader, item, track, state)
  local take = reaper.GetActiveTake(item)
  if not take then return end

  -- Get MIDI take name (like audio uses filename)
  local item_name = reaper.GetTakeName(take)
  if not item_name or item_name == "" then
    item_name = "Unnamed MIDI"
  end

  -- Compute mute status and track color ONCE during loading
  local track_muted = reaper.GetMediaTrackInfo_Value(track, "B_MUTE") == 1
  local item_muted = reaper.GetMediaItemInfo_Value(item, "B_MUTE") == 1
  local track_color = reaper.GetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR")

  local uuid = get_item_uuid(item)

  -- Store in raw pool (before grouping)
  table.insert(loader.raw_midi_items, {
    item = item,
    item_name = item_name,
    track_color = track_color,
    track_muted = track_muted,
    item_muted = item_muted,
    uuid = uuid,
  })
end

-- Normal mode: Full chunk-based duplicate detection
function M.process_midi_item(loader, item, track, chunk, chunk_id, state)
  local take = reaper.GetActiveTake(item)
  if not take then return end

  -- Get MIDI take name (like audio uses filename)
  local item_name = reaper.GetTakeName(take)
  if not item_name or item_name == "" then
    item_name = "Unnamed MIDI"
  end

  -- Check for duplicates
  if loader.midi_items[item_name] then
    for _, existing in ipairs(loader.midi_items[item_name]) do
      if loader.item_chunks[chunk_id] == loader.item_chunks[loader.reaper_interface.ItemChunkID(existing[1])] then
        return -- Duplicate, skip
      end
    end
  else
    table.insert(loader.midi_indexes, item_name)
    loader.midi_items[item_name] = {}
  end

  local track_muted = reaper.GetMediaTrackInfo_Value(track, "B_MUTE") == 1 or loader.reaper_interface.IsParentMuted(track)
  local item_muted = reaper.GetMediaItemInfo_Value(item, "B_MUTE") == 1

  table.insert(loader.midi_items[item_name], {
    item,
    item_name,  -- Display the actual take name
    track_muted = track_muted,
    item_muted = item_muted,
    uuid = get_item_uuid(item)
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

-- Reorganize items based on grouping setting (instant, no REAPER API calls)
function M.reorganize_items(loader, group_by_name)
  -- Clear grouped results
  loader.samples = {}
  loader.sample_indexes = {}
  loader.midi_items = {}
  loader.midi_indexes = {}

  -- Reorganize audio items
  for _, raw_item in ipairs(loader.raw_audio_items) do
    local group_key
    if group_by_name then
      -- Group by filename (multiple items with same source file)
      group_key = raw_item.filename
    else
      -- Each item is separate (use UUID as unique key)
      group_key = raw_item.uuid
    end

    if not loader.samples[group_key] then
      table.insert(loader.sample_indexes, group_key)
      loader.samples[group_key] = {}
    end

    table.insert(loader.samples[group_key], {
      raw_item.item,
      raw_item.item_name,
      track_muted = raw_item.track_muted,
      item_muted = raw_item.item_muted,
      uuid = raw_item.uuid,
      track_color = raw_item.track_color,  -- Include cached color
    })
  end

  -- Reorganize MIDI items
  for _, raw_item in ipairs(loader.raw_midi_items) do
    local group_key
    if group_by_name then
      -- Group by take name (so all "Kick" MIDI items are together)
      group_key = raw_item.item_name
    else
      -- Each item is separate (use UUID as unique key)
      group_key = raw_item.uuid
    end

    if not loader.midi_items[group_key] then
      table.insert(loader.midi_indexes, group_key)
      loader.midi_items[group_key] = {}
    end

    table.insert(loader.midi_items[group_key], {
      raw_item.item,
      raw_item.item_name,
      track_muted = raw_item.track_muted,
      item_muted = raw_item.item_muted,
      uuid = raw_item.uuid,
      track_color = raw_item.track_color,  -- Include cached color
    })
  end
end

return M
