-- @noindex
-- ItemPicker/data/loader.lua
-- Incremental project item loader
-- Processes items in small batches per frame to avoid blocking UI
-- @migrated 2024-11-27 from data/loaders/incremental_loader.lua

local M = {}

-- Import shared UUID function from reaper_api
local reaper_api = require('ItemPicker.data.reaper_api')
local get_item_uuid = reaper_api.get_item_uuid

-- Performance: Cache REAPER API function references at module level
-- This eliminates table lookups in hot loops (5-10% faster)
local GetMediaTrackInfo_Value = reaper.GetMediaTrackInfo_Value
local GetMediaItemInfo_Value = reaper.GetMediaItemInfo_Value
local GetMediaItemTakeInfo_Value = reaper.GetMediaItemTakeInfo_Value
local GetActiveTake = reaper.GetActiveTake
local TakeIsMIDI = reaper.TakeIsMIDI
local GetMediaItemTake_Source = reaper.GetMediaItemTake_Source
local GetMediaSourceFileName = reaper.GetMediaSourceFileName
local GetTakeName = reaper.GetTakeName
local GetTrackGUID = reaper.GetTrackGUID
local GetTrackName = reaper.GetTrackName
local ValidatePtr2 = reaper.ValidatePtr2
local BR_GetMediaSourceProperties = reaper.BR_GetMediaSourceProperties
local GetMediaSourceParent = reaper.GetMediaSourceParent
local MIDI_GetAllEvts = reaper.MIDI_GetAllEvts
local time_precise = reaper.time_precise
local GetItemStateChunk = reaper.GetItemStateChunk

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

    -- Hash sets for O(1) duplicate detection (chunk content -> true)
    processed_audio_chunks = {},
    processed_midi_chunks = {},

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

  -- Reset results
  loader.samples = {}
  loader.sample_indexes = {}
  loader.midi_items = {}
  loader.midi_indexes = {}
  loader.item_chunks = {}
  loader.processed_audio_chunks = {}
  loader.processed_midi_chunks = {}
end

-- Process one batch (call this every frame)
-- Returns: is_complete, progress (0-1)
function M.process_batch(loader, state, settings)
  if not loader.is_loading then return true, 1.0 end

  -- Store settings reference for item processing functions
  loader.settings = settings

  -- FIRST BATCH: Do initialization (moved from start_loading to avoid blocking)
  if not loader.initialization_complete then
    local init_start = time_precise()

    local all_tracks = loader.reaper_interface.GetAllTracks()

    -- FAST MODE: Skip expensive frozen check and mute status computation
    if loader.fast_mode then
      -- Just collect all items from all visible tracks (NO frozen check, NO mute computation)
      loader.all_items = {}
      for _, track in pairs(all_tracks) do
        if GetMediaTrackInfo_Value(track, 'B_SHOWINTCP') ~= 0 then
          local track_items = loader.reaper_interface.GetItemInTrack(track)
          for _, item in pairs(track_items) do
            if item and ValidatePtr2(0, item, 'MediaItem*') then
              loader.all_items[#loader.all_items + 1] = {item = item, track = track}
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
        local track_muted = GetMediaTrackInfo_Value(track, 'B_MUTE') == 1 or loader.reaper_interface.IsParentMuted(track)
        loader.track_muted_cache[track] = track_muted
      end

      loader.all_items = {}
      for _, track in pairs(all_tracks) do
        if GetMediaTrackInfo_Value(track, 'B_SHOWINTCP') ~= 0 and
           not loader.reaper_interface.IsParentFrozen(track, loader.track_chunks) then
          local track_items = loader.reaper_interface.GetItemInTrack(track)
          for _, item in pairs(track_items) do
            if item and ValidatePtr2(0, item, 'MediaItem*') then
              loader.all_items[#loader.all_items + 1] = {item = item, track = track}
            end
          end
        end
      end
    end

    loader.initialization_complete = true

    -- Return to allow UI to update (don't process items this frame)
    return false, 0.0
  end

  local total_items = #loader.all_items
  if total_items == 0 then
    loader.is_loading = false
    return true, 1.0
  end

  local batch_start_time = time_precise()
  local batch_end = math.min(loader.current_index + loader.batch_size, total_items)

  -- Process this batch
  local reaper_time = 0
  local processing_time = 0

  for i = loader.current_index + 1, batch_end do
    local entry = loader.all_items[i]
    local item = entry.item
    local track = entry.track

    local take = GetActiveTake(item)
    if not take then goto next_item end

    local is_midi = TakeIsMIDI(take)

    if loader.fast_mode then
      -- FAST MODE: Skip expensive chunk processing, no duplicate detection
      local t1 = time_precise()

      if is_midi then
        M.process_midi_item_fast(loader, item, track, state)
      else
        M.process_audio_item_fast(loader, item, track, state)
      end

      local t2 = time_precise()
      processing_time = processing_time + (t2 - t1)
    else
      -- NORMAL MODE: Full chunk processing for duplicate detection
      local t1 = time_precise()
      local _, chunk = GetItemStateChunk(item, '')
      local t2 = time_precise()
      reaper_time = reaper_time + (t2 - t1)

      local utils = require('ItemPicker.domain.items.utils')
      chunk = utils.RemoveKeyFromChunk(chunk, 'POSITION')
      chunk = utils.RemoveKeyFromChunk(chunk, 'IGUID')
      chunk = utils.RemoveKeyFromChunk(chunk, 'IID')
      chunk = utils.RemoveKeyFromChunk(chunk, 'GUID')
      local chunk_id = loader.reaper_interface.ItemChunkID(item)
      loader.item_chunks[chunk_id] = chunk

      if is_midi then
        M.process_midi_item(loader, item, track, chunk, chunk_id, state)
      else
        M.process_audio_item(loader, item, track, chunk, chunk_id, state)
      end

      local t3 = time_precise()
      processing_time = processing_time + (t3 - t2)
    end

    ::next_item::
  end

  loader.current_index = batch_end
  local progress = loader.current_index / total_items

  if loader.current_index >= total_items then
    -- All items loaded - calculate pool counts before organizing
    M.calculate_pool_counts(loader)
    -- Now organize them based on grouping setting
    M.reorganize_items(loader, state.settings.group_items_by_name)
    loader.is_loading = false
    return true, 1.0
  end

  return false, progress
end

-- Fast mode: Skip chunk-based duplicate detection
function M.process_audio_item_fast(loader, item, track, state)
  local take = GetActiveTake(item)
  if not take then return end

  -- Use cached source directly (skip reverse checking in fast mode)
  local source = GetMediaItemTake_Source(take)
  local filename = GetMediaSourceFileName(source)
  if not filename then return end

  local item_name = GetTakeName(take)
  if not item_name or item_name == '' then
    item_name = (filename:match('[^/\\]+$') or ''):match('(.+)%..+$') or filename:match('[^/\\]+$') or 'Unnamed Audio'
  end

  -- Compute mute status and track color ONCE during loading
  local track_muted = GetMediaTrackInfo_Value(track, 'B_MUTE') == 1
  local item_muted = GetMediaItemInfo_Value(item, 'B_MUTE') == 1
  local track_color = GetMediaTrackInfo_Value(track, 'I_CUSTOMCOLOR')
  local track_guid = GetTrackGUID(track)

  -- Get track name for search
  local _, track_name = GetTrackName(track)
  track_name = track_name or ''

  local uuid = get_item_uuid(item)

  -- Get regions if enabled (check both settings for backwards compatibility)
  local regions = nil
  if loader.settings and (loader.settings.enable_region_processing or loader.settings.show_region_tags) then
    regions = loader.reaper_interface.GetRegionsForItem(item)
  end

  -- Store in raw pool (before grouping)
  loader.raw_audio_items[#loader.raw_audio_items + 1] = {
    item = item,
    item_name = item_name,
    filename = filename,
    track_name = track_name,
    track_color = track_color,
    track_guid = track_guid,
    track_muted = track_muted,
    item_muted = item_muted,
    uuid = uuid,
    regions = regions,
  }
end

-- Normal mode: Full chunk-based duplicate detection
function M.process_audio_item(loader, item, track, chunk, chunk_id, state)
  local take = GetActiveTake(item)

  local source = GetMediaItemTake_Source(take)
  local _, _, _, _, _, reverse = BR_GetMediaSourceProperties(take)
  if reverse then
    source = GetMediaSourceParent(source)
  end

  local filename = GetMediaSourceFileName(source)
  if not filename then return end

  -- Check for duplicates using hash set (O(1) instead of O(n))
  local chunk = loader.item_chunks[chunk_id]
  if loader.processed_audio_chunks[chunk] then
    return -- Duplicate, skip
  end
  loader.processed_audio_chunks[chunk] = true

  if not loader.samples[filename] then
    loader.sample_indexes[#loader.sample_indexes + 1] = filename
    loader.samples[filename] = {}
  end

  local item_name = GetTakeName(take)
  if not item_name or item_name == '' then
    item_name = (filename:match('[^/\\]+$') or ''):match('(.+)%..+$') or filename:match('[^/\\]+$') or 'Unnamed Audio'
  end

  local track_muted = GetMediaTrackInfo_Value(track, 'B_MUTE') == 1 or loader.reaper_interface.IsParentMuted(track)
  local item_muted = GetMediaItemInfo_Value(item, 'B_MUTE') == 1
  local track_color = GetMediaTrackInfo_Value(track, 'I_CUSTOMCOLOR')
  local track_guid = GetTrackGUID(track)
  local uuid = get_item_uuid(item)

  -- Get track name for search
  local _, track_name = GetTrackName(track)
  track_name = track_name or ''

  -- Get regions if enabled (check both settings for backwards compatibility)
  local regions = nil
  if loader.settings and (loader.settings.enable_region_processing or loader.settings.show_region_tags) then
    regions = loader.reaper_interface.GetRegionsForItem(item)
  end

  -- Store in loader.samples for duplicate detection
  loader.samples[filename][#loader.samples[filename] + 1] = {
    item,
    item_name,
    track_muted = track_muted,
    item_muted = item_muted,
    track_guid = track_guid,
    uuid = uuid,
    regions = regions,
  }

  -- ALSO store in raw pool for reorganization
  loader.raw_audio_items[#loader.raw_audio_items + 1] = {
    item = item,
    item_name = item_name,
    filename = filename,
    track_name = track_name,
    track_color = track_color,
    track_guid = track_guid,
    track_muted = track_muted,
    item_muted = item_muted,
    uuid = uuid,
    regions = regions,
  }
end

-- Fast mode: Skip chunk-based duplicate detection
function M.process_midi_item_fast(loader, item, track, state)
  local take = GetActiveTake(item)
  if not take then return end

  -- Get MIDI take name (like audio uses filename)
  local item_name = GetTakeName(take)
  if not item_name or item_name == '' then
    item_name = 'Unnamed MIDI'
  end

  -- Compute mute status and track color ONCE during loading
  local track_muted = GetMediaTrackInfo_Value(track, 'B_MUTE') == 1
  local item_muted = GetMediaItemInfo_Value(item, 'B_MUTE') == 1
  local track_color = GetMediaTrackInfo_Value(track, 'I_CUSTOMCOLOR')
  local track_guid = GetTrackGUID(track)

  local uuid = get_item_uuid(item)

  -- Get track name for search
  local _, track_name = GetTrackName(track)
  track_name = track_name or ''

  -- Get regions if enabled (check both settings for backwards compatibility)
  local regions = nil
  if loader.settings and (loader.settings.enable_region_processing or loader.settings.show_region_tags) then
    regions = loader.reaper_interface.GetRegionsForItem(item)
  end

  -- Store in raw pool (before grouping)
  loader.raw_midi_items[#loader.raw_midi_items + 1] = {
    item = item,
    item_name = item_name,
    track_color = track_color,
    track_guid = track_guid,
    track_muted = track_muted,
    item_muted = item_muted,
    uuid = uuid,
    track_name = track_name,
    regions = regions,
  }
end

-- Normal mode: Full chunk-based duplicate detection
function M.process_midi_item(loader, item, track, chunk, chunk_id, state)
  local take = GetActiveTake(item)
  if not take then return end

  -- Get MIDI take name (like audio uses filename)
  local item_name = GetTakeName(take)
  if not item_name or item_name == '' then
    item_name = 'Unnamed MIDI'
  end

  -- Check for duplicates using hash set (O(1) instead of O(n))
  local chunk = loader.item_chunks[chunk_id]
  if loader.processed_midi_chunks[chunk] then
    return -- Duplicate, skip
  end
  loader.processed_midi_chunks[chunk] = true

  if not loader.midi_items[item_name] then
    loader.midi_indexes[#loader.midi_indexes + 1] = item_name
    loader.midi_items[item_name] = {}
  end

  local track_muted = GetMediaTrackInfo_Value(track, 'B_MUTE') == 1 or loader.reaper_interface.IsParentMuted(track)
  local item_muted = GetMediaItemInfo_Value(item, 'B_MUTE') == 1
  local track_color = GetMediaTrackInfo_Value(track, 'I_CUSTOMCOLOR')
  local track_guid = GetTrackGUID(track)
  local uuid = get_item_uuid(item)

  -- Get track name for search
  local _, track_name = GetTrackName(track)
  track_name = track_name or ''

  -- Get regions if enabled (check both settings for backwards compatibility)
  local regions = nil
  if loader.settings and (loader.settings.enable_region_processing or loader.settings.show_region_tags) then
    regions = loader.reaper_interface.GetRegionsForItem(item)
  end

  -- Store in loader.midi_items for duplicate detection
  loader.midi_items[item_name][#loader.midi_items[item_name] + 1] = {
    item,
    item_name,
    track_muted = track_muted,
    item_muted = item_muted,
    track_guid = track_guid,
    uuid = uuid,
    track_name = track_name,
    regions = regions,
  }

  -- ALSO store in raw pool for reorganization
  loader.raw_midi_items[#loader.raw_midi_items + 1] = {
    item = item,
    item_name = item_name,
    track_color = track_color,
    track_guid = track_guid,
    track_muted = track_muted,
    item_muted = item_muted,
    uuid = uuid,
    track_name = track_name,
    regions = regions,
  }
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

-- Calculate pool counts based on REAPER's actual pooling (shared sources/MIDI data)
function M.calculate_pool_counts(loader)
  -- Count audio items by source pointer (REAPER's pooling for audio)
  local source_pool_counts = {}
  for _, raw_item in ipairs(loader.raw_audio_items) do
    local item = raw_item.item
    local take = GetActiveTake(item)
    if take then
      local source = GetMediaItemTake_Source(take)
      -- Check for reverse (get parent source)
      local _, _, _, _, _, reverse = BR_GetMediaSourceProperties(take)
      if reverse then
        source = GetMediaSourceParent(source)
      end
      -- Use source pointer address as unique identifier
      local source_id = tostring(source)
      if source_id then
        source_pool_counts[source_id] = (source_pool_counts[source_id] or 0) + 1
      end
    end
  end

  -- Assign pool counts to audio items
  for _, raw_item in ipairs(loader.raw_audio_items) do
    local item = raw_item.item
    local take = GetActiveTake(item)
    if take then
      local source = GetMediaItemTake_Source(take)
      local _, _, _, _, _, reverse = BR_GetMediaSourceProperties(take)
      if reverse then
        source = GetMediaSourceParent(source)
      end
      -- Use source pointer address as unique identifier
      local source_id = tostring(source)
      raw_item.pool_count = source_pool_counts[source_id] or 1
      raw_item.pool_id = source_id  -- Store pool identifier
    else
      raw_item.pool_count = 1
      raw_item.pool_id = raw_item.uuid  -- Unique ID for non-pooled items
    end
  end

  -- Count MIDI items by MIDI data (REAPER's pooling for MIDI)
  local midi_pool_counts = {}
  for _, raw_item in ipairs(loader.raw_midi_items) do
    local item = raw_item.item
    local take = GetActiveTake(item)
    if take then
      local _, midi_data = MIDI_GetAllEvts(take, '')
      if midi_data then
        midi_pool_counts[midi_data] = (midi_pool_counts[midi_data] or 0) + 1
      end
    end
  end

  -- Assign pool counts to MIDI items
  for _, raw_item in ipairs(loader.raw_midi_items) do
    local item = raw_item.item
    local take = GetActiveTake(item)
    if take then
      local _, midi_data = MIDI_GetAllEvts(take, '')
      if midi_data and #midi_data > 0 then
        raw_item.pool_count = midi_pool_counts[midi_data] or 1
        -- Use hash of MIDI data as pool ID
        local hash = 0
        for i = 1, #midi_data do
          hash = (hash * 31 + string.byte(midi_data, i)) % 2147483647
        end
        raw_item.pool_id = tostring(hash)
      else
        raw_item.pool_count = 1
        raw_item.pool_id = raw_item.uuid  -- Unique ID for empty MIDI items
      end
    else
      raw_item.pool_count = 1
      raw_item.pool_id = raw_item.uuid  -- Unique ID for non-pooled items
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
      -- Group by item name (so all items named 'Kick' are together, regardless of source file)
      group_key = raw_item.item_name
    else
      -- Each item is separate (use UUID as unique key)
      group_key = raw_item.uuid
    end

    -- Skip items with nil keys (shouldn't happen, but safety check)
    if not group_key or group_key == '' then
      reaper.ShowConsoleMsg(string.format('[REORGANIZE] WARNING: Skipping audio item with nil/empty group_key (item_name=%s, uuid=%s)\n',
        tostring(raw_item.item_name), tostring(raw_item.uuid)))
      goto skip_audio
    end

    if not loader.samples[group_key] then
      loader.sample_indexes[#loader.sample_indexes + 1] = group_key
      loader.samples[group_key] = {}
    end

    loader.samples[group_key][#loader.samples[group_key] + 1] = {
      raw_item.item,
      raw_item.item_name,
      track_muted = raw_item.track_muted,
      item_muted = raw_item.item_muted,
      track_guid = raw_item.track_guid,  -- Track GUID for filtering
      uuid = raw_item.uuid,
      track_color = raw_item.track_color,  -- Include cached color
      pool_count = raw_item.pool_count or 1,  -- From REAPER pooling detection
      pool_id = raw_item.pool_id,  -- Pool identifier for filtering
      track_name = raw_item.track_name,  -- Track name for search
      regions = raw_item.regions,  -- Region tags
    }

    ::skip_audio::
  end

  -- Reorganize MIDI items
  for _, raw_item in ipairs(loader.raw_midi_items) do
    local group_key
    if group_by_name then
      -- Group by take name (so all 'Kick' MIDI items are together)
      group_key = raw_item.item_name
    else
      -- Each item is separate (use UUID as unique key)
      group_key = raw_item.uuid
    end

    -- Skip items with nil keys (shouldn't happen, but safety check)
    if not group_key or group_key == '' then
      reaper.ShowConsoleMsg(string.format('[REORGANIZE] WARNING: Skipping MIDI item with nil/empty group_key (item_name=%s, uuid=%s)\n',
        tostring(raw_item.item_name), tostring(raw_item.uuid)))
      goto skip_midi
    end

    if not loader.midi_items[group_key] then
      loader.midi_indexes[#loader.midi_indexes + 1] = group_key
      loader.midi_items[group_key] = {}
    end

    loader.midi_items[group_key][#loader.midi_items[group_key] + 1] = {
      raw_item.item,
      raw_item.item_name,
      track_muted = raw_item.track_muted,
      item_muted = raw_item.item_muted,
      track_guid = raw_item.track_guid,  -- Track GUID for filtering
      uuid = raw_item.uuid,
      track_color = raw_item.track_color,  -- Include cached color
      pool_count = raw_item.pool_count or 1,  -- From REAPER pooling detection
      pool_id = raw_item.pool_id,  -- Pool identifier for filtering
      track_name = raw_item.track_name,  -- Track name for search
      regions = raw_item.regions,  -- Region tags
    }

    ::skip_midi::
  end
end

return M
