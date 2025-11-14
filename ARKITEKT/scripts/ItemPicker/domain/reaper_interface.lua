local M = {}
local utils

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
  
  for key, track in pairs(all_tracks) do
    if reaper.GetMediaTrackInfo_Value(track, "B_SHOWINTCP") == 0 or M.IsParentFrozen(track, state.track_chunks) == true then
      goto next_track
    end
    
    local track_items = M.GetItemInTrack(track)
    for key, item in pairs(track_items) do
      local take = reaper.GetActiveTake(item)
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
        
        if not samples[filename] then
          table.insert(sample_indexes, filename)
          samples[filename] = {}
        end
        
        for key, _item in pairs(samples[filename]) do
          if state.item_chunks[M.ItemChunkID(item)] == state.item_chunks[M.ItemChunkID(_item[1])] then
            goto next_item
          end
        end
        
        local item_name = (filename:match("[^/\\]+$") or ""):match("(.+)%..+$") or filename:match("[^/\\]+$")
        
        local track_muted = reaper.GetMediaTrackInfo_Value(track, "B_MUTE") == 1 or M.IsParentMuted(track) == true
        local item_muted = reaper.GetMediaItemInfo_Value(item, "B_MUTE") == 1
        
        table.insert(samples[filename], { 
          item, 
          item_name,
          track_muted = track_muted,
          item_muted = item_muted
        })
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

  for key, track in pairs(all_tracks) do
    if reaper.GetMediaTrackInfo_Value(track, "B_SHOWINTCP") == 0 or M.IsParentFrozen(track, state.track_chunks) == true then
      goto next_track
    end

    local track_items = M.GetItemInTrack(track)
    local track_midi = {}
    local track_muted = reaper.GetMediaTrackInfo_Value(track, "B_MUTE") == 1 or M.IsParentMuted(track) == true

    for key, item in pairs(track_items) do
      local take = reaper.GetActiveTake(item)
      if reaper.TakeIsMIDI(take) then
        local _, num_notes = reaper.MIDI_CountEvts(take)
        if num_notes == 0 then
          goto next_item
        end

        local _, midi = reaper.MIDI_GetAllEvts(take)
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

        table.insert(track_midi, {
          item,
          item_name,
          track_muted = track_muted,
          item_muted = item_muted
        })
      end
      ::next_item::
    end

    if #track_midi > 0 then
      local track_guid = reaper.GetTrackGUID(track)
      midi_items[track_guid] = track_midi
      table.insert(midi_indexes, track_guid)
    end
    ::next_track::
  end

  return midi_items, midi_indexes
end

function M.InsertItemAtMousePos(item, state)
  local take = reaper.GetActiveTake(item)
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
    
    reaper.SelectAllMediaItems(0, false)
    reaper.SetMediaItemSelected(item, true)
    reaper.ApplyNudge(0, 1, 5, 1, mouse_position_in_arrange, false, 1)
    reaper.MoveMediaItemToTrack(reaper.GetSelectedMediaItem(0, 0), track)
  end
end

return M