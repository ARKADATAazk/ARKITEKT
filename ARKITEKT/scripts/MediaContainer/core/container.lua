-- @noindex
-- MediaContainer/core/container.lua
-- Container operations: create, copy, paste, sync

local State = require("MediaContainer.core.app_state")
local UUID = require("arkitekt.core.uuid")

local M = {}

-- Create a new container from currently selected items
function M.create_from_selection()
  local num_selected = reaper.CountSelectedMediaItems(0)
  if num_selected == 0 then
    reaper.ShowMessageBox("Please select at least one media item.", "Media Container", 0)
    return nil
  end

  reaper.Undo_BeginBlock()

  -- Collect selected items and determine bounds
  local items = {}
  local min_pos = math.huge
  local max_end = 0
  local min_track_idx = math.huge
  local max_track_idx = 0
  local track_guids = {}

  for i = 0, num_selected - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local guid = reaper.BR_GetMediaItemGUID(item)
    local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local item_end = pos + len

    local track = reaper.GetMediaItem_Track(item)
    local track_guid = reaper.GetTrackGUID(track)
    local track_idx = State.get_track_index(track)

    -- Track bounds
    if pos < min_pos then min_pos = pos end
    if item_end > max_end then max_end = item_end end
    if track_idx < min_track_idx then min_track_idx = track_idx end
    if track_idx > max_track_idx then max_track_idx = track_idx end

    track_guids[track_guid] = true

    items[#items + 1] = {
      guid = guid,
      rel_position = pos - min_pos,  -- Will be recalculated after loop
      rel_track_index = track_idx - min_track_idx,  -- Will be recalculated
      length = len,
    }
  end

  -- Recalculate relative positions now that we know min_pos and min_track_idx
  for _, item_ref in ipairs(items) do
    local item = State.find_item_by_guid(item_ref.guid)
    if item then
      local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      local track = reaper.GetMediaItem_Track(item)
      local track_idx = State.get_track_index(track)

      item_ref.rel_position = pos - min_pos
      item_ref.rel_track_index = track_idx - min_track_idx
    end
  end

  -- Get track GUIDs for top and bottom tracks
  local top_track = reaper.GetTrack(0, min_track_idx)
  local bottom_track = reaper.GetTrack(0, max_track_idx)
  local top_track_guid = top_track and reaper.GetTrackGUID(top_track) or nil
  local bottom_track_guid = bottom_track and reaper.GetTrackGUID(bottom_track) or nil

  -- Create container
  local container = {
    id = UUID.generate(),
    name = "Container " .. (#State.containers + 1),
    color = State.generate_container_color(),
    start_time = min_pos,
    end_time = max_end,
    top_track_guid = top_track_guid,
    bottom_track_guid = bottom_track_guid,
    items = items,
    master_id = nil,  -- This is a master container
  }

  State.add_container(container)

  -- Cache initial item states (using relative position)
  for _, item_ref in ipairs(items) do
    local item = State.find_item_by_guid(item_ref.guid)
    if item then
      local hash = State.get_item_state_hash(item, container)
      if hash then
        State.item_state_cache[item_ref.guid] = hash
      end
    end
  end

  reaper.Undo_EndBlock("Create Media Container", -1)

  return container
end

-- Copy container to clipboard (finds container at edit cursor or containing selection)
function M.copy_container()
  local cursor_pos = reaper.GetCursorPosition()

  -- First, try to find container at cursor position
  local found_container = nil

  for _, container in ipairs(State.containers) do
    if cursor_pos >= container.start_time and cursor_pos <= container.end_time then
      found_container = container
      break
    end
  end

  -- If not found at cursor, check selected items
  if not found_container then
    local num_selected = reaper.CountSelectedMediaItems(0)
    if num_selected > 0 then
      local item = reaper.GetSelectedMediaItem(0, 0)
      local item_guid = reaper.BR_GetMediaItemGUID(item)

      for _, container in ipairs(State.containers) do
        for _, item_ref in ipairs(container.items) do
          if item_ref.guid == item_guid then
            found_container = container
            break
          end
        end
        if found_container then break end
      end
    end
  end

  if not found_container then
    reaper.ShowMessageBox("No container found at cursor position or in selection.", "Media Container", 0)
    return false
  end

  -- Get master container if this is a linked copy
  local master_id = found_container.master_id or found_container.id
  State.set_clipboard(master_id)

  reaper.ShowConsoleMsg(string.format("[MediaContainer] Copied container '%s' to clipboard\n", found_container.name))
  return true
end

-- Paste container at cursor position
function M.paste_container()
  local master_id = State.get_clipboard()
  if not master_id then
    reaper.ShowMessageBox("No container in clipboard. Copy a container first.", "Media Container", 0)
    return nil
  end

  local master = State.get_container_by_id(master_id)
  if not master then
    reaper.ShowMessageBox("Source container no longer exists.", "Media Container", 0)
    return nil
  end

  local cursor_pos = reaper.GetCursorPosition()

  -- Start undo block
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  -- Determine target track (use first selected track or track at cursor)
  local target_track = reaper.GetSelectedTrack(0, 0)
  if not target_track then
    -- Get track under edit cursor using mouse position logic or first track
    target_track = reaper.GetTrack(0, 0)
  end

  if not target_track then
    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock("Media Container Paste (failed)", -1)
    reaper.ShowMessageBox("No target track available.", "Media Container", 0)
    return nil
  end

  local base_track_idx = State.get_track_index(target_track)

  -- Copy items from master container
  local new_items = {}

  for _, item_ref in ipairs(master.items) do
    local source_item = State.find_item_by_guid(item_ref.guid)
    if not source_item then
      goto continue
    end

    -- Get or create target track
    local target_track_idx = base_track_idx + item_ref.rel_track_index
    local item_track = reaper.GetTrack(0, target_track_idx)

    -- Create track if needed
    if not item_track then
      local num_tracks = reaper.CountTracks(0)
      for j = num_tracks, target_track_idx do
        reaper.InsertTrackAtIndex(j, false)
      end
      item_track = reaper.GetTrack(0, target_track_idx)
    end

    if not item_track then
      goto continue
    end

    -- Copy item using state chunk
    local _, chunk = reaper.GetItemStateChunk(source_item, "")

    -- Create new item on target track
    local new_item = reaper.AddMediaItemToTrack(item_track)
    reaper.SetItemStateChunk(new_item, chunk, false)

    -- Set new position
    local new_pos = cursor_pos + item_ref.rel_position
    reaper.SetMediaItemInfo_Value(new_item, "D_POSITION", new_pos)

    -- Get new item GUID
    local new_guid = reaper.BR_GetMediaItemGUID(new_item)

    new_items[#new_items + 1] = {
      guid = new_guid,
      rel_position = item_ref.rel_position,
      rel_track_index = item_ref.rel_track_index,
      length = item_ref.length,
    }

    ::continue::
  end

  -- Calculate new container bounds
  local duration = master.end_time - master.start_time
  local new_top_track = reaper.GetTrack(0, base_track_idx)
  local new_bottom_idx = base_track_idx + (master.bottom_track_guid and
    State.get_track_index(State.find_track_by_guid(master.bottom_track_guid)) -
    State.get_track_index(State.find_track_by_guid(master.top_track_guid)) or 0)
  local new_bottom_track = reaper.GetTrack(0, new_bottom_idx)

  -- Create linked container
  local linked_container = {
    id = UUID.generate(),
    name = master.name .. " (linked)",
    color = master.color,
    start_time = cursor_pos,
    end_time = cursor_pos + duration,
    top_track_guid = new_top_track and reaper.GetTrackGUID(new_top_track) or nil,
    bottom_track_guid = new_bottom_track and reaper.GetTrackGUID(new_bottom_track) or nil,
    items = new_items,
    master_id = master_id,  -- Link to master
  }

  State.add_container(linked_container)

  -- Cache initial item states (using relative position to the new container)
  for _, item_ref in ipairs(new_items) do
    local item = State.find_item_by_guid(item_ref.guid)
    if item then
      local hash = State.get_item_state_hash(item, linked_container)
      if hash then
        State.item_state_cache[item_ref.guid] = hash
      end
    end
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Media Container Paste", -1)

  reaper.ShowConsoleMsg(string.format("[MediaContainer] Pasted linked container '%s' at %.2f\n",
    linked_container.name, cursor_pos))

  return linked_container
end

-- Detect changes in container items
function M.detect_changes()
  local changes = {}

  for _, container in ipairs(State.containers) do
    for _, item_ref in ipairs(container.items) do
      local item = State.find_item_by_guid(item_ref.guid)
      if not item then
        goto continue
      end

      local current_hash = State.get_item_state_hash(item, container)
      local cached_hash = State.item_state_cache[item_ref.guid]

      if current_hash and current_hash ~= cached_hash then
        changes[#changes + 1] = {
          container_id = container.id,
          item_guid = item_ref.guid,
          item = item,
          old_hash = cached_hash,
          new_hash = current_hash,
        }
        reaper.ShowConsoleMsg(string.format("[MediaContainer] Change detected in %s\n", container.name))
      end

      ::continue::
    end
  end

  return changes
end

-- Sync changes to linked containers
function M.sync_changes(changes)
  if #changes == 0 then
    return
  end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  -- Track which master groups we've already processed to avoid loops
  local processed_masters = {}

  for _, change in ipairs(changes) do
    local source_container = State.get_container_by_id(change.container_id)
    if not source_container then
      goto next_change
    end

    -- Get master ID
    local master_id = source_container.master_id or source_container.id

    -- Skip if we've already processed this master group
    if processed_masters[master_id] then
      -- Just update the cache for this item
      State.item_state_cache[change.item_guid] = change.new_hash
      goto next_change
    end
    processed_masters[master_id] = true

    reaper.ShowConsoleMsg(string.format("[MediaContainer] Processing sync for master group %s\n", master_id:sub(1,8)))

    -- Find the item reference in source container
    local source_item_ref = nil
    local source_item_index = nil
    for i, item_ref in ipairs(source_container.items) do
      if item_ref.guid == change.item_guid then
        source_item_ref = item_ref
        source_item_index = i
        break
      end
    end

    if not source_item_ref then
      goto next_change
    end

    -- Get current item properties
    local source_item = change.item
    local new_pos = reaper.GetMediaItemInfo_Value(source_item, "D_POSITION")
    local new_rel_pos = new_pos - source_container.start_time

    -- Update source item ref
    source_item_ref.rel_position = new_rel_pos
    source_item_ref.length = reaper.GetMediaItemInfo_Value(source_item, "D_LENGTH")

    -- Sync to all linked containers
    local linked = State.get_linked_containers(master_id)
    for _, linked_container in ipairs(linked) do
      if linked_container.id == source_container.id then
        goto next_linked
      end

      -- Find corresponding item in linked container
      local target_item_ref = linked_container.items[source_item_index]
      if not target_item_ref then
        goto next_linked
      end

      local target_item = State.find_item_by_guid(target_item_ref.guid)
      if not target_item then
        goto next_linked
      end

      -- Apply properties from source to target
      M.apply_item_properties(source_item, target_item,
        source_container.start_time, linked_container.start_time)

      reaper.ShowConsoleMsg(string.format("[MediaContainer] Synced to %s\n", linked_container.name))

      -- Update cache (using relative position to linked container)
      local new_hash = State.get_item_state_hash(target_item, linked_container)
      if new_hash then
        State.item_state_cache[target_item_ref.guid] = new_hash
      end

      -- Update item ref
      target_item_ref.rel_position = new_rel_pos
      target_item_ref.length = source_item_ref.length

      ::next_linked::
    end

    -- Update source cache
    State.item_state_cache[change.item_guid] = change.new_hash

    ::next_change::
  end

  State.persist()

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Media Container Sync", -1)
end

-- Apply item properties from source to target
function M.apply_item_properties(source_item, target_item, source_container_start, target_container_start)
  -- Get source properties
  local source_pos = reaper.GetMediaItemInfo_Value(source_item, "D_POSITION")
  local rel_pos = source_pos - source_container_start

  -- Position (relative to container)
  reaper.SetMediaItemInfo_Value(target_item, "D_POSITION", target_container_start + rel_pos)

  -- Length
  reaper.SetMediaItemInfo_Value(target_item, "D_LENGTH",
    reaper.GetMediaItemInfo_Value(source_item, "D_LENGTH"))

  -- Basic properties
  reaper.SetMediaItemInfo_Value(target_item, "B_MUTE",
    reaper.GetMediaItemInfo_Value(source_item, "B_MUTE"))
  reaper.SetMediaItemInfo_Value(target_item, "D_VOL",
    reaper.GetMediaItemInfo_Value(source_item, "D_VOL"))

  -- Fades
  reaper.SetMediaItemInfo_Value(target_item, "D_FADEINLEN",
    reaper.GetMediaItemInfo_Value(source_item, "D_FADEINLEN"))
  reaper.SetMediaItemInfo_Value(target_item, "D_FADEOUTLEN",
    reaper.GetMediaItemInfo_Value(source_item, "D_FADEOUTLEN"))
  reaper.SetMediaItemInfo_Value(target_item, "C_FADEINSHAPE",
    reaper.GetMediaItemInfo_Value(source_item, "C_FADEINSHAPE"))
  reaper.SetMediaItemInfo_Value(target_item, "C_FADEOUTSHAPE",
    reaper.GetMediaItemInfo_Value(source_item, "C_FADEOUTSHAPE"))

  -- Snap offset
  reaper.SetMediaItemInfo_Value(target_item, "D_SNAPOFFSET",
    reaper.GetMediaItemInfo_Value(source_item, "D_SNAPOFFSET"))

  -- Take properties
  local source_take = reaper.GetActiveTake(source_item)
  local target_take = reaper.GetActiveTake(target_item)

  if source_take and target_take then
    reaper.SetMediaItemTakeInfo_Value(target_take, "D_PITCH",
      reaper.GetMediaItemTakeInfo_Value(source_take, "D_PITCH"))
    reaper.SetMediaItemTakeInfo_Value(target_take, "D_PLAYRATE",
      reaper.GetMediaItemTakeInfo_Value(source_take, "D_PLAYRATE"))
    reaper.SetMediaItemTakeInfo_Value(target_take, "D_VOL",
      reaper.GetMediaItemTakeInfo_Value(source_take, "D_VOL"))
    reaper.SetMediaItemTakeInfo_Value(target_take, "D_STARTOFFS",
      reaper.GetMediaItemTakeInfo_Value(source_take, "D_STARTOFFS"))
  end
end

-- Update container bounds when items move
function M.update_container_bounds(container)
  if #container.items == 0 then
    return
  end

  local min_pos = math.huge
  local max_end = 0

  for _, item_ref in ipairs(container.items) do
    local item = State.find_item_by_guid(item_ref.guid)
    if item then
      local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
      local item_end = pos + len

      if pos < min_pos then min_pos = pos end
      if item_end > max_end then max_end = item_end end
    end
  end

  if min_pos ~= math.huge then
    container.start_time = min_pos
    container.end_time = max_end
  end
end

-- Delete container
function M.delete_container(container_id)
  reaper.Undo_BeginBlock()
  State.remove_container(container_id)
  reaper.Undo_EndBlock("Delete Media Container", -1)
end

-- Get container at position
function M.get_container_at_position(pos)
  for _, container in ipairs(State.containers) do
    if pos >= container.start_time and pos <= container.end_time then
      return container
    end
  end
  return nil
end

return M
