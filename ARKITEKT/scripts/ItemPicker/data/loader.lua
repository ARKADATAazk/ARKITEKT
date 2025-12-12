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

  -- Capture track index and timeline position for sorting
  local track_index = GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
  local item_position = GetMediaItemInfo_Value(item, 'D_POSITION')

  -- Get regions if enabled (skip if deferred)
  local regions = nil
  if not loader._skip_regions and loader.settings and (loader.settings.enable_region_processing or loader.settings.show_region_tags) then
    local tr = time_precise()
    regions = loader.reaper_interface.GetRegionsForItem(item)
    loader._region_time = (loader._region_time or 0) + (time_precise() - tr)
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
    track_index = track_index,
    item_position = item_position,
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

  -- Capture track index and timeline position for sorting
  local track_index = GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
  local item_position = GetMediaItemInfo_Value(item, 'D_POSITION')

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
    track_index = track_index,
    item_position = item_position,
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
    track_index = track_index,
    item_position = item_position,
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

  -- Capture track index and timeline position for sorting
  local track_index = GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
  local item_position = GetMediaItemInfo_Value(item, 'D_POSITION')

  -- Get regions if enabled (skip if deferred)
  local regions = nil
  if not loader._skip_regions and loader.settings and (loader.settings.enable_region_processing or loader.settings.show_region_tags) then
    local tr = time_precise()
    regions = loader.reaper_interface.GetRegionsForItem(item)
    loader._region_time = (loader._region_time or 0) + (time_precise() - tr)
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
    track_index = track_index,
    item_position = item_position,
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

  -- Capture track index and timeline position for sorting
  local track_index = GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
  local item_position = GetMediaItemInfo_Value(item, 'D_POSITION')

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
    track_index = track_index,
    item_position = item_position,
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
    track_index = track_index,
    item_position = item_position,
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
  -- Set spawn time for tiles that don't have it (for fade-in animation)
  local spawn_time = time_precise()

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
      track_index = raw_item.track_index,  -- Track position for sorting
      item_position = raw_item.item_position,  -- Timeline position for sorting
      _metadata_loaded_at = raw_item._metadata_loaded_at,  -- For text fade-in animation
      _spawned_at = raw_item._spawned_at or spawn_time,  -- For tile spawn animation
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
      track_index = raw_item.track_index,  -- Track position for sorting
      item_position = raw_item.item_position,  -- Timeline position for sorting
      _metadata_loaded_at = raw_item._metadata_loaded_at,  -- For text fade-in animation
      _spawned_at = raw_item._spawned_at or spawn_time,  -- For tile spawn animation
    }

    ::skip_midi::
  end
end

-- =============================================================================
-- CHUNKED LOADING: Spreads work across frames for smooth animation
-- =============================================================================

-- Initialize chunked load - collect all items, prepare for processing
function M.start_chunked_load(loader, state, settings)
  local t0 = time_precise()

  loader.settings = settings
  loader.fast_mode = true
  loader._skip_regions = true  -- Always skip regions in chunked mode (deferred)

  -- Reset state
  loader.track_chunks = {}
  loader.track_muted_cache = {}
  loader.raw_audio_items = {}
  loader.raw_midi_items = {}
  loader.samples = {}
  loader.sample_indexes = {}
  loader.midi_items = {}
  loader.midi_indexes = {}
  loader._region_time = 0

  -- Phase 1: Get all tracks and items (fast, do immediately)
  local all_tracks = loader.reaper_interface.GetAllTracks()
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

  -- Initialize chunk processing state
  loader._chunk_index = 1
  loader._chunk_phase = 'processing'  -- 'processing' -> 'finalizing' -> 'done'

  local init_ms = (time_precise() - t0) * 1000
  reaper.ShowConsoleMsg(string.format(
    '\n--- Chunked Load Started (%d items) ---\n' ..
    'Init time: %6.2f ms\n',
    #loader.all_items, init_ms
  ))
end

-- Process items with time budget, returns true when complete
-- First batch is small for quick display, then larger batches
function M.process_chunk(loader, state, items_per_chunk)
  if loader._chunk_phase == 'done' then return true end

  local t0 = time_precise()

  if loader._chunk_phase == 'processing' then
    local start_idx = loader._chunk_index
    local total_items = #loader.all_items

    -- Time budget: smaller = smoother animation, larger = faster loading
    -- 1ms first batch, 1.5ms subsequent for smooth progressive reveal
    local is_first_batch = start_idx == 1
    local time_budget = is_first_batch and 0.001 or 0.0015  -- seconds

    -- Set spawn time for this batch (so new tiles animate in)
    local batch_spawn_time = time_precise()

    -- Process items until time budget exhausted
    local i = start_idx
    while i <= total_items do
      local entry = loader.all_items[i]
      local item = entry.item
      local track = entry.track
      local take = GetActiveTake(item)
      if take then
        if TakeIsMIDI(take) then
          M.process_midi_item_fast(loader, item, track, state)
          -- Set spawn time for animation
          local last = loader.raw_midi_items[#loader.raw_midi_items]
          if last then last._spawned_at = batch_spawn_time end
        else
          M.process_audio_item_fast(loader, item, track, state)
          -- Set spawn time for animation
          local last = loader.raw_audio_items[#loader.raw_audio_items]
          if last then last._spawned_at = batch_spawn_time end
        end
      end

      i = i + 1

      -- Check time budget every 20 items
      if i % 20 == 0 and (time_precise() - t0) >= time_budget then
        break
      end
    end

    loader._chunk_index = i

    -- Check if processing is complete
    if loader._chunk_index > total_items then
      loader._chunk_phase = 'finalizing'
    else
      -- Intermediate update: reorganize and show what we have so far
      M.reorganize_items(loader, state.settings.group_items_by_name)
      M.get_results(loader, state)
    end

    return false  -- Not done yet

  elseif loader._chunk_phase == 'finalizing' then
    -- Final reorganize and copy to state
    M.reorganize_items(loader, state.settings.group_items_by_name)
    M.get_results(loader, state)

    -- Mark that deferred load is needed
    state._needs_deferred_load = true

    loader._chunk_phase = 'done'

    local final_ms = (time_precise() - t0) * 1000
    reaper.ShowConsoleMsg(string.format(
      '--- Chunked Load Complete ---\n' ..
      'Items: %d audio, %d MIDI\n',
      #loader.raw_audio_items, #loader.raw_midi_items
    ))

    return true  -- Done!
  end

  return true
end

-- SYNCHRONOUS loading - collects all items in one call
-- Returns: total_ms, item_count
-- Fast initial load: Skip regions and pool counts (deferred)
-- Returns quickly so tiles can appear, heavy work done later
function M.load_all_sync(loader, state, settings, skip_heavy)
  local t0 = time_precise()

  loader.settings = settings
  loader.fast_mode = true  -- Always use fast mode for sync
  loader._skip_regions = skip_heavy  -- Signal to skip regions in process_*_fast

  -- Phase 1: Get all tracks and items
  local t1 = time_precise()
  local all_tracks = loader.reaper_interface.GetAllTracks()
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
  local phase1_ms = (time_precise() - t1) * 1000

  -- Phase 2: Process all items
  local t2 = time_precise()
  loader.track_chunks = {}
  loader.track_muted_cache = {}
  loader.raw_audio_items = {}
  loader.raw_midi_items = {}
  loader.samples = {}
  loader.sample_indexes = {}
  loader.midi_items = {}
  loader.midi_indexes = {}

  -- Track region loading time separately
  loader._region_time = 0

  for i = 1, #loader.all_items do
    local entry = loader.all_items[i]
    local item = entry.item
    local track = entry.track
    local take = GetActiveTake(item)
    if take then
      if TakeIsMIDI(take) then
        M.process_midi_item_fast(loader, item, track, state)
      else
        M.process_audio_item_fast(loader, item, track, state)
      end
    end
  end
  local phase2_ms = (time_precise() - t2) * 1000
  local region_ms = loader._region_time * 1000

  -- Phase 3a: Calculate pool counts (skip if deferred)
  local t3a = time_precise()
  local phase3a_ms = 0
  if not skip_heavy then
    M.calculate_pool_counts(loader)
    phase3a_ms = (time_precise() - t3a) * 1000
  end

  -- Phase 3b: Reorganize items
  local t3b = time_precise()
  M.reorganize_items(loader, state.settings.group_items_by_name)
  local phase3b_ms = (time_precise() - t3b) * 1000

  -- Phase 4: Copy results to state
  local t4 = time_precise()
  M.get_results(loader, state)
  local phase4_ms = (time_precise() - t4) * 1000

  -- Mark that deferred load is needed
  if skip_heavy then
    state._needs_deferred_load = true
  end

  local total_ms = (time_precise() - t0) * 1000
  local item_count = #loader.all_items
  local audio_count = #loader.raw_audio_items
  local midi_count = #loader.raw_midi_items

  -- Print detailed breakdown
  local mode = skip_heavy and ' [FAST - deferred]' or ''
  reaper.ShowConsoleMsg(string.format(
    '\n--- Loader Breakdown%s (%d items: %d audio, %d MIDI) ---\n' ..
    'Phase 1 (get tracks/items):  %6.2f ms\n' ..
    'Phase 2 (process items):     %6.2f ms\n' ..
    '  - regions lookup:          %6.2f ms%s\n' ..
    '  - other processing:        %6.2f ms\n' ..
    'Phase 3a (pool counts):      %6.2f ms%s\n' ..
    'Phase 3b (reorganize):       %6.2f ms\n' ..
    'Phase 4 (copy to state):     %6.2f ms\n' ..
    'LOADER TOTAL:                %6.2f ms\n',
    mode, item_count, audio_count, midi_count,
    phase1_ms, phase2_ms, region_ms, skip_heavy and ' (SKIPPED)' or '',
    phase2_ms - region_ms,
    phase3a_ms, skip_heavy and ' (DEFERRED)' or '',
    phase3b_ms, phase4_ms, total_ms
  ))

  return total_ms, item_count
end

-- Deferred heavy load: Pool counts and regions (called after tiles visible)
function M.load_deferred(loader, state)
  local t0 = time_precise()

  -- Load regions for all items
  local t1 = time_precise()
  if loader.settings and (loader.settings.enable_region_processing or loader.settings.show_region_tags) then
    for _, raw_item in ipairs(loader.raw_audio_items) do
      raw_item.regions = loader.reaper_interface.GetRegionsForItem(raw_item.item)
    end
    for _, raw_item in ipairs(loader.raw_midi_items) do
      raw_item.regions = loader.reaper_interface.GetRegionsForItem(raw_item.item)
    end
  end
  local region_ms = (time_precise() - t1) * 1000

  -- Calculate pool counts
  local t2 = time_precise()
  M.calculate_pool_counts(loader)
  local pool_ms = (time_precise() - t2) * 1000

  -- Re-reorganize with updated data
  local t3 = time_precise()
  M.reorganize_items(loader, state.settings.group_items_by_name)
  local reorg_ms = (time_precise() - t3) * 1000

  -- Copy updated results to state
  M.get_results(loader, state)

  state._needs_deferred_load = false

  local total_ms = (time_precise() - t0) * 1000
  reaper.ShowConsoleMsg(string.format(
    '\n--- Deferred Load Complete ---\n' ..
    'Regions:      %6.2f ms\n' ..
    'Pool counts:  %6.2f ms\n' ..
    'Reorganize:   %6.2f ms\n' ..
    'TOTAL:        %6.2f ms\n',
    region_ms, pool_ms, reorg_ms, total_ms
  ))
end

-- =============================================================================
-- LIGHT/HEAVY LOADING: Fast initial load, then details after tiles settle
-- =============================================================================

-- Light load: Colors + names only (no pool counts, no regions)
-- Returns: total_ms, item_count
function M.load_light_sync(loader, state, settings)
  local t0 = time_precise()

  loader.settings = settings
  loader.fast_mode = true

  -- Reset state
  loader.track_chunks = {}
  loader.track_muted_cache = {}
  loader.raw_audio_items = {}
  loader.raw_midi_items = {}
  loader.samples = {}
  loader.sample_indexes = {}
  loader.midi_items = {}
  loader.midi_indexes = {}

  -- Get all tracks and items
  local all_tracks = loader.reaper_interface.GetAllTracks()
  loader.all_items = {}

  for _, track in pairs(all_tracks) do
    if GetMediaTrackInfo_Value(track, 'B_SHOWINTCP') ~= 0 then
      local track_color = GetMediaTrackInfo_Value(track, 'I_CUSTOMCOLOR')
      local track_guid = GetTrackGUID(track)
      local track_muted = GetMediaTrackInfo_Value(track, 'B_MUTE') == 1
      local _, track_name = GetTrackName(track)
      track_name = track_name or ''

      local track_items = loader.reaper_interface.GetItemInTrack(track)

      for _, item in pairs(track_items) do
        if item and ValidatePtr2(0, item, 'MediaItem*') then
          local take = GetActiveTake(item)
          if take then
            local is_midi = TakeIsMIDI(take)
            local uuid = get_item_uuid(item)
            local item_muted = GetMediaItemInfo_Value(item, 'B_MUTE') == 1

            -- Get item name
            local item_name = GetTakeName(take)
            if not item_name or item_name == '' then
              if is_midi then
                item_name = 'Unnamed MIDI'
              else
                local source = GetMediaItemTake_Source(take)
                local filename = GetMediaSourceFileName(source) or ''
                item_name = (filename:match('[^/\\]+$') or ''):match('(.+)%..+$') or filename:match('[^/\\]+$') or 'Unnamed Audio'
              end
            end

            local raw_item = {
              item = item,
              item_name = item_name,
              filename = is_midi and uuid or (GetMediaSourceFileName(GetMediaItemTake_Source(take)) or uuid),
              track_color = track_color,
              track_guid = track_guid,
              track_muted = track_muted,
              item_muted = item_muted,
              track_name = track_name,
              uuid = uuid,
              -- Placeholders for heavy load
              pool_count = 1,
              pool_id = uuid,
              regions = nil,
              -- Spawn animation timestamp
              _spawned_at = time_precise(),
            }

            if is_midi then
              loader.raw_midi_items[#loader.raw_midi_items + 1] = raw_item
            else
              loader.raw_audio_items[#loader.raw_audio_items + 1] = raw_item
            end

            loader.all_items[#loader.all_items + 1] = {item = item, track = track, is_midi = is_midi}
          end
        end
      end
    end
  end

  -- Reorganize and copy to state
  M.reorganize_items(loader, state.settings.group_items_by_name)
  M.get_results(loader, state)

  local total_ms = (time_precise() - t0) * 1000
  return total_ms, #loader.all_items
end

-- Load regions for all items (called during heavy load)
function M.load_regions(loader, settings)
  if not settings.show_region_tags then return end

  for _, raw_item in ipairs(loader.raw_audio_items) do
    raw_item.regions = loader.reaper_interface.GetRegionsForItem(raw_item.item)
  end

  for _, raw_item in ipairs(loader.raw_midi_items) do
    raw_item.regions = loader.reaper_interface.GetRegionsForItem(raw_item.item)
  end
end

-- =============================================================================
-- LEGACY: Two-phase loading (deprecated)
-- =============================================================================

-- Phase 1: Minimal data for instant tile rendering (just color + position)
-- Returns: total_ms, item_count
function M.load_minimal_sync(loader, state, settings)
  local t0 = time_precise()

  loader.settings = settings
  loader.fast_mode = true

  -- Reset state
  loader.track_chunks = {}
  loader.track_muted_cache = {}
  loader.raw_audio_items = {}
  loader.raw_midi_items = {}
  loader.samples = {}
  loader.sample_indexes = {}
  loader.midi_items = {}
  loader.midi_indexes = {}

  -- Get all tracks and items
  local all_tracks = loader.reaper_interface.GetAllTracks()
  loader.all_items = {}

  for _, track in pairs(all_tracks) do
    if GetMediaTrackInfo_Value(track, 'B_SHOWINTCP') ~= 0 then
      local track_color = GetMediaTrackInfo_Value(track, 'I_CUSTOMCOLOR')
      local track_guid = GetTrackGUID(track)
      local track_items = loader.reaper_interface.GetItemInTrack(track)

      for _, item in pairs(track_items) do
        if item and ValidatePtr2(0, item, 'MediaItem*') then
          local take = GetActiveTake(item)
          if take then
            local is_midi = TakeIsMIDI(take)
            local uuid = get_item_uuid(item)

            -- Minimal data: just enough for colored tile display
            local raw_item = {
              item = item,
              track_color = track_color,
              track_guid = track_guid,
              uuid = uuid,
              -- Placeholder values (filled in phase 2)
              item_name = '...',  -- Shows loading indicator until real name loads
              filename = uuid,  -- Use UUID as temp filename for grouping
              track_muted = false,
              item_muted = false,
              track_name = '',
              regions = nil,
              pool_count = 1,
              pool_id = uuid,
              _needs_metadata = true,  -- Flag for phase 2
              _is_midi = is_midi,
              _spawned_at = time_precise(),  -- For tile spawn animation
            }

            if is_midi then
              loader.raw_midi_items[#loader.raw_midi_items + 1] = raw_item
            else
              loader.raw_audio_items[#loader.raw_audio_items + 1] = raw_item
            end

            loader.all_items[#loader.all_items + 1] = {item = item, track = track, is_midi = is_midi}
          end
        end
      end
    end
  end

  -- Reorganize immediately so tiles can render
  -- IMPORTANT: During minimal load, always use non-grouped mode (each item separate)
  -- This avoids grouping all items under "Audio"/"MIDI" placeholder names
  -- Proper grouping happens after metadata is loaded
  M.reorganize_items(loader, false)  -- false = don't group by name
  M.get_results(loader, state)

  -- Mark that metadata loading is pending
  loader.metadata_pending = true
  loader.metadata_index = 0
  loader._final_group_by_name = state.settings.group_items_by_name  -- Save for final reorganize

  -- Build UUID lookup for O(1) metadata updates (avoids O(n²) in load_metadata_batch)
  loader._raw_item_lookup = {}
  for _, raw_item in ipairs(loader.raw_audio_items) do
    loader._raw_item_lookup[raw_item.uuid] = raw_item
  end
  for _, raw_item in ipairs(loader.raw_midi_items) do
    loader._raw_item_lookup[raw_item.uuid] = raw_item
  end

  local total_ms = (time_precise() - t0) * 1000
  return total_ms, #loader.all_items
end

-- Phase 2: Fill in metadata (names, mute status, regions)
-- Call this in batches after tiles are visible
-- Returns: is_complete, progress (0-1)
function M.load_metadata_batch(loader, state, batch_size)
  if not loader.metadata_pending then return true, 1.0 end

  batch_size = batch_size or 100
  local total = #loader.all_items
  if total == 0 then
    loader.metadata_pending = false
    return true, 1.0
  end

  local batch_end = math.min(loader.metadata_index + batch_size, total)

  for i = loader.metadata_index + 1, batch_end do
    local entry = loader.all_items[i]
    local item = entry.item
    local track = entry.track
    local is_midi = entry.is_midi

    local take = GetActiveTake(item)
    if take then
      local uuid = get_item_uuid(item)

      -- O(1) lookup using pre-built index
      local raw_item = loader._raw_item_lookup and loader._raw_item_lookup[uuid]
      if raw_item and raw_item._needs_metadata then
        -- Fill in metadata
        local item_name = GetTakeName(take)
        if not item_name or item_name == '' then
          if is_midi then
            item_name = 'Unnamed MIDI'
          else
            local source = GetMediaItemTake_Source(take)
            local filename = GetMediaSourceFileName(source) or ''
            item_name = (filename:match('[^/\\]+$') or ''):match('(.+)%..+$') or filename:match('[^/\\]+$') or 'Unnamed Audio'
            raw_item.filename = filename
          end
        end
        raw_item.item_name = item_name
        raw_item._metadata_loaded_at = time_precise()  -- For fade-in animation

        -- Mute status
        raw_item.track_muted = GetMediaTrackInfo_Value(track, 'B_MUTE') == 1
        raw_item.item_muted = GetMediaItemInfo_Value(item, 'B_MUTE') == 1

        -- Track name
        local _, track_name = GetTrackName(track)
        raw_item.track_name = track_name or ''

        -- Regions (if enabled)
        if loader.settings and (loader.settings.enable_region_processing or loader.settings.show_region_tags) then
          raw_item.regions = loader.reaper_interface.GetRegionsForItem(item)
        end

        raw_item._needs_metadata = nil
      end
    end
  end

  loader.metadata_index = batch_end
  local progress = loader.metadata_index / total

  if loader.metadata_index >= total then
    -- All metadata loaded - calculate pool counts before reorganizing
    M.calculate_pool_counts(loader)

    -- Reorganize with real names using saved setting
    local group_by_name = loader._final_group_by_name or state.settings.group_items_by_name
    M.reorganize_items(loader, group_by_name)
    M.get_results(loader, state)

    -- Invalidate filter cache to refresh display
    if state.runtime_cache then
      state.runtime_cache.audio_filter_hash = nil
      state.runtime_cache.midi_filter_hash = nil
    end

    -- Clean up temporary data
    loader._raw_item_lookup = nil
    loader._final_group_by_name = nil
    loader.metadata_pending = false
    return true, 1.0
  end

  return false, progress
end

return M
