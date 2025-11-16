local M = {}
local utils
local UUID = require("rearkitekt.core.uuid")

function M.init(utils_module)
  utils = utils_module
end

function M.GetAllTracks()
  local tracks = {}
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    table.insert(tracks, track)
  end
  return tracks
end

function M.GetTrackID(track)
  return reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
end

function M.GetItemInTrack(track)
  local items = {}
  for i = 0, reaper.CountTrackMediaItems(track) - 1 do
    local item = reaper.GetTrackMediaItem(track, i)
    table.insert(items, item)
  end
  return items
end

function M.TrackIsFrozen(track, track_chunks)
  local chunk = track_chunks[M.GetTrackID(track)]
  return chunk:find("<FREEZE")
end

function M.IsParentFrozen(track, track_chunks)
  local getParentTrack = reaper.GetParentTrack
  local parentTrack = getParentTrack(track)
  while parentTrack do
    if M.TrackIsFrozen(track, track_chunks) then
      return true
    end
    parentTrack = getParentTrack(parentTrack)
  end
end

function M.IsParentMuted(track)
  local getParentTrack = reaper.GetParentTrack
  local function isTrackMuted(track) 
    return reaper.GetMediaTrackInfo_Value(track, "B_MUTE") > 0 
  end

  local parentTrack = getParentTrack(track)
  while parentTrack do
    if isTrackMuted(parentTrack) then
      return true
    end
    parentTrack = getParentTrack(parentTrack)
  end
end

function M.GetAllTrackStateChunks()
  local all_tracks = M.GetAllTracks()
  local chunks = {}
  for key, track in pairs(all_tracks) do
    local _, chunk = reaper.GetTrackStateChunk(track, "")
    table.insert(chunks, chunk)
  end
  return chunks
end

function M.GetAllCleanedItemChunks()
  local item_chunks = {}
  for i = 0, reaper.CountMediaItems(0) - 1 do
    local item = reaper.GetMediaItem(0, i)
    local _, chunk = reaper.GetItemStateChunk(item, "")
    chunk = utils.RemoveKeyFromChunk(chunk, "POSITION")
    chunk = utils.RemoveKeyFromChunk(chunk, "IGUID")
    chunk = utils.RemoveKeyFromChunk(chunk, "IID")
    chunk = utils.RemoveKeyFromChunk(chunk, "GUID")
    local track_id = M.GetTrackID(reaper.GetMediaItemTrack(item))
    local item_id = reaper.GetMediaItemInfo_Value(item, "IP_ITEMNUMBER")
    item_chunks[track_id .. " " .. item_id] = chunk
  end
  return item_chunks
end

function M.ItemChunkID(item)
  local track = reaper.GetMediaItemTrack(item)
  local track_id = M.GetTrackID(track)
  local item_id = reaper.GetMediaItemInfo_Value(item, "IP_ITEMNUMBER")
  return track_id .. " " .. item_id
end

function M.GetProjectSamples(settings, state)
  local all_tracks = M.GetAllTracks()
  local samples = {}
  local sample_indexes = {}

  -- Track source pointers to count pooled items
  local source_pool_counts = {}

  -- First pass: count items per source (for pooling detection)
  for key, track in pairs(all_tracks) do
    if reaper.GetMediaTrackInfo_Value(track, "B_SHOWINTCP") == 0 or M.IsParentFrozen(track, state.track_chunks) == true then
      goto count_next_track
    end

    local track_items = M.GetItemInTrack(track)
    for key, item in pairs(track_items) do
      if not item or not reaper.ValidatePtr2(0, item, "MediaItem*") then
        goto count_next_item
      end

      local take = reaper.GetActiveTake(item)
      if not take then
        goto count_next_item
      end

      if not reaper.TakeIsMIDI(take) then
        local source = reaper.GetMediaItemTake_Source(take)
        if source then
          local source_ptr = tostring(source)
          source_pool_counts[source_ptr] = (source_pool_counts[source_ptr] or 0) + 1
        end
      end
      ::count_next_item::
    end
    ::count_next_track::
  end

  -- Second pass: collect items with pool counts (only first instance of pooled items)
  local collected_sources = {}  -- Track which sources we've already collected

  for key, track in pairs(all_tracks) do
    if reaper.GetMediaTrackInfo_Value(track, "B_SHOWINTCP") == 0 or M.IsParentFrozen(track, state.track_chunks) == true then
      goto next_track
    end

    local track_items = M.GetItemInTrack(track)
    for key, item in pairs(track_items) do
      -- Validate item is a valid MediaItem pointer
      if not item or not reaper.ValidatePtr2(0, item, "MediaItem*") then
        goto next_item
      end

      local take = reaper.GetActiveTake(item)
      if not take then
        goto next_item
      end
      if not reaper.TakeIsMIDI(take) then
        local source = reaper.GetMediaItemTake_Source(take)
        local _, _, _, _, _, reverse = reaper.BR_GetMediaSourceProperties(take)
        if reverse then
          source = reaper.GetMediaSourceParent(source)
        end
        local filename = reaper.GetMediaSourceFileName(source)
        if not filename then
          goto next_item
        end

        -- Get source pointer for pooling check
        local source_ptr = tostring(source)

        -- Skip if we've already collected an item with this source (pooled items)
        if collected_sources[source_ptr] then
          goto next_item
        end

        if not samples[filename] then
          table.insert(sample_indexes, filename)
          samples[filename] = {}
        end

        for key, _item in pairs(samples[filename]) do
          if state.item_chunks[M.ItemChunkID(item)] == state.item_chunks[M.ItemChunkID(_item[1])] then
            goto next_item
          end
        end

        -- Get take name (same as MIDI items)
        local item_name = reaper.GetTakeName(take)
        if not item_name or item_name == "" then
          -- Fallback to filename if take has no name
          item_name = (filename:match("[^/\\]+$") or ""):match("(.+)%..+$") or filename:match("[^/\\]+$")
        end

        local track_muted = reaper.GetMediaTrackInfo_Value(track, "B_MUTE") == 1 or M.IsParentMuted(track) == true
        local item_muted = reaper.GetMediaItemInfo_Value(item, "B_MUTE") == 1

        -- Get pool count for this source
        local pool_count = source_pool_counts[source_ptr] or 1

        table.insert(samples[filename], {
          item,
          item_name,
          track_muted = track_muted,
          item_muted = item_muted,
          uuid = UUID.generate(),
          pool_count = pool_count
        })

        -- Mark this source as collected
        collected_sources[source_ptr] = true
      end
      ::next_item::
    end
    ::next_track::
  end
  return samples, sample_indexes
end

function M.GetProjectMIDI(settings, state)
  local all_tracks = M.GetAllTracks()
  local midi_items = {}
  local midi_indexes = {}
  local split_mode = settings.split_midi_by_track

  -- Track MIDI data strings to count pooled items
  local midi_pool_counts = {}

  -- First pass: count items per MIDI data (for pooling detection)
  for key, track in pairs(all_tracks) do
    if reaper.GetMediaTrackInfo_Value(track, "B_SHOWINTCP") == 0 or M.IsParentFrozen(track, state.track_chunks) == true then
      goto count_next_track
    end

    local track_items = M.GetItemInTrack(track)
    for key, item in pairs(track_items) do
      if not item or not reaper.ValidatePtr2(0, item, "MediaItem*") then
        goto count_next_item
      end

      local take = reaper.GetActiveTake(item)
      if not take then
        goto count_next_item
      end

      if reaper.TakeIsMIDI(take) then
        local _, num_notes = reaper.MIDI_CountEvts(take)
        if num_notes > 0 then
          local _, midi_data = reaper.MIDI_GetAllEvts(take)
          if midi_data then
            midi_pool_counts[midi_data] = (midi_pool_counts[midi_data] or 0) + 1
          end
        end
      end
      ::count_next_item::
    end
    ::count_next_track::
  end

  -- Second pass: collect items with pool counts (only first instance of pooled items)
  local collected_midi = {}  -- Track which MIDI data we've already collected

  for key, track in pairs(all_tracks) do
    if reaper.GetMediaTrackInfo_Value(track, "B_SHOWINTCP") == 0 or M.IsParentFrozen(track, state.track_chunks) == true then
      goto next_track
    end

    local track_items = M.GetItemInTrack(track)
    local track_midi = {}
    local track_muted = reaper.GetMediaTrackInfo_Value(track, "B_MUTE") == 1 or M.IsParentMuted(track) == true

    for key, item in pairs(track_items) do
      -- Validate item is a valid MediaItem pointer
      if not item or not reaper.ValidatePtr2(0, item, "MediaItem*") then
        goto next_item
      end

      local take = reaper.GetActiveTake(item)
      if not take then
        goto next_item
      end
      if reaper.TakeIsMIDI(take) then
        local _, num_notes = reaper.MIDI_CountEvts(take)
        if num_notes == 0 then
          goto next_item
        end

        local _, midi = reaper.MIDI_GetAllEvts(take)

        -- Skip if we've already collected an item with this MIDI data (pooled items)
        if collected_midi[midi] then
          goto next_item
        end

        for key, _item in pairs(track_midi) do
          local _, _midi = reaper.MIDI_GetAllEvts(reaper.GetActiveTake(_item[1]))
          if midi == _midi then
            goto next_item
          end
        end

        local item_muted = reaper.GetMediaItemInfo_Value(item, "B_MUTE") == 1
        local item_name = reaper.GetTakeName(take)
        if not item_name or item_name == "" then
          item_name = "MIDI Item"
        end

        -- Get pool count for this MIDI data
        local pool_count = midi_pool_counts[midi] or 1

        local item_data = {
          item,
          item_name,
          track_muted = track_muted,
          item_muted = item_muted,
          uuid = UUID.generate(),
          pool_count = pool_count
        }

        if split_mode then
          -- Split mode: one tile per MIDI item (use item GUID as key)
          local item_guid = reaper.BR_GetMediaItemGUID(item)
          midi_items[item_guid] = { item_data }  -- Wrap in array for consistency
          table.insert(midi_indexes, item_guid)
        else
          -- Grouped mode: collect items by track
          table.insert(track_midi, item_data)
        end

        -- Mark this MIDI data as collected
        collected_midi[midi] = true
      end
      ::next_item::
    end

    -- In grouped mode, store all items for this track
    if not split_mode and #track_midi > 0 then
      local track_guid = reaper.GetTrackGUID(track)
      midi_items[track_guid] = track_midi
      table.insert(midi_indexes, track_guid)
    end
    ::next_track::
  end

  return midi_items, midi_indexes
end

function M.InsertItemAtMousePos(item, state)
  -- Validate item is a valid MediaItem
  if not item or not reaper.ValidatePtr2(0, item, "MediaItem*") then
    return
  end

  local take = reaper.GetActiveTake(item)
  if not take then
    return
  end

  local source = reaper.GetMediaItemTake_Source(take)
  local mouse_x, mouse_y = reaper.GetMousePosition()
  local track, str = reaper.GetThingFromPoint(mouse_x, mouse_y)

  if track or state.out_of_bounds then
    if state.out_of_bounds then
      reaper.InsertTrackAtIndex(reaper.CountTracks(0), false)
      track = reaper.GetTrack(0, reaper.CountTracks(0) - 1)
      state.out_of_bounds = nil
    end

    reaper.BR_GetMouseCursorContext()
    local mouse_position_in_arrange = reaper.BR_GetMouseCursorContext_Position()

    if reaper.GetToggleCommandState(1157) then
      mouse_position_in_arrange = reaper.SnapToGrid(0, mouse_position_in_arrange)
    end

    -- Get all items to insert (support batch insert from dragging_keys)
    local items_to_insert = {}

    if state.dragging_keys and #state.dragging_keys > 0 then
      reaper.ShowConsoleMsg(string.format("[INSERT] Batch insert: %d items\n", #state.dragging_keys))

      for _, uuid in ipairs(state.dragging_keys) do
        local current_item

        if state.dragging_is_audio then
          -- Use UUID lookup table for O(1) access
          local item_data = state.audio_item_lookup[uuid]
          if item_data then
            current_item = item_data[1]
          end
        else
          -- Use UUID lookup table for O(1) access
          local item_data = state.midi_item_lookup[uuid]
          if item_data then
            current_item = item_data[1]
          end
        end

        if current_item and reaper.ValidatePtr2(0, current_item, "MediaItem*") then
          table.insert(items_to_insert, current_item)
        end
      end
    else
      table.insert(items_to_insert, item)
    end

    reaper.ShowConsoleMsg(string.format("[INSERT] Inserting %d items at position %.2f\n", #items_to_insert, mouse_position_in_arrange))

    -- Insert all items
    reaper.SelectAllMediaItems(0, false)
    local current_pos = mouse_position_in_arrange

    for _, insert_item in ipairs(items_to_insert) do
      reaper.SetMediaItemSelected(insert_item, true)
      reaper.ApplyNudge(0, 1, 5, 1, current_pos, false, 1)
      local inserted = reaper.GetSelectedMediaItem(0, 0)
      if inserted then
        reaper.MoveMediaItemToTrack(inserted, track)

        -- Calculate next position (current item length + small gap)
        local item_len = reaper.GetMediaItemInfo_Value(inserted, "D_LENGTH")
        current_pos = current_pos + item_len
      end
      reaper.SelectAllMediaItems(0, false)
    end

    -- Cleanup drag state
    state.dragging_keys = nil
    state.dragging_is_audio = nil
  end
end

return M