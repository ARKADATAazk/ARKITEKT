-- @noindex
-- Region_Playlist/core/controller.lua
-- Centralized playlist operations with automatic undo/save/sync
-- Relies on bridge invalidate logic instead of manual engine sync

local M = {}
local Controller = {}
Controller.__index = Controller

package.loaded["Region_Playlist.core.controller"] = M

local UUID = require("rearkitekt.core.uuid")

function M.new(state_module, settings, undo_manager)
  local ctrl = setmetatable({
    state = state_module,
    settings = settings,
    undo = undo_manager,
  }, Controller)
  
  return ctrl
end

function Controller:_commit()
  self.state.persist()
  local bridge = self.state.get_bridge()
  if bridge then
    bridge:get_sequence()
  end
end

function Controller:_with_undo(fn)
  self.state.capture_undo_snapshot()
  local success, result = pcall(fn)
  if success then
    self:_commit()
    return true, result
  else
    return false, result
  end
end

function Controller:_get_playlist(id)
  return self.state.get_playlist_by_id(id)
end

function Controller:_generate_playlist_id()
  return UUID.generate()
end

function Controller:_generate_item_key()
  return UUID.generate()
end

function Controller:create_playlist(name)
  return self:_with_undo(function()
    local new_id = self:_generate_playlist_id()

    local RegionState = require("Region_Playlist.storage.persistence")

    local new_playlist = {
      id = new_id,
      name = name or ("Playlist " .. new_id),
      items = {},
      chip_color = RegionState.generate_chip_color(),
    }

    local playlists = self.state.get_playlists()
    local active_id = self.state.get_active_playlist_id()

    -- Find active playlist index
    local insert_index = #playlists + 1  -- Default to end
    for i, pl in ipairs(playlists) do
      if pl.id == active_id then
        insert_index = i + 1  -- Insert after active
        break
      end
    end

    table.insert(playlists, insert_index, new_playlist)
    self.state.set_active_playlist(new_id)

    return new_id
  end)
end

function Controller:duplicate_playlist(id)
  local playlists = self.state.get_playlists()
  local source_playlist = nil
  local source_index = nil

  for i, pl in ipairs(playlists) do
    if pl.id == id then
      source_playlist = pl
      source_index = i
      break
    end
  end

  if not source_playlist then
    return false, "Playlist not found"
  end

  return self:_with_undo(function()
    local new_id = self:_generate_playlist_id()
    local RegionState = require("Region_Playlist.storage.persistence")

    -- Deep copy items with proper structure and new keys
    local new_items = {}
    for i, item in ipairs(source_playlist.items) do
      local new_item

      if item.type == "region" then
        -- Region item
        new_item = {
          type = "region",
          rid = item.rid,
          reps = item.reps or 1,
          enabled = item.enabled ~= false,
          key = self:_generate_item_key(),
        }
      elseif item.type == "playlist" then
        -- Playlist item
        new_item = {
          type = "playlist",
          playlist_id = item.playlist_id,
          reps = item.reps or 1,
          enabled = item.enabled ~= false,
          key = self:_generate_item_key(),
        }
      end

      if new_item then
        new_items[i] = new_item
      end
    end

    local new_playlist = {
      id = new_id,
      name = source_playlist.name .. " Copy",
      items = new_items,
      chip_color = source_playlist.chip_color,
    }

    -- Insert after source playlist
    table.insert(playlists, source_index + 1, new_playlist)
    self.state.set_active_playlist(new_id)

    return new_id
  end)
end

function Controller:rename_playlist(id, new_name)
  local playlist = self:_get_playlist(id)
  if not playlist then
    return false, "Playlist not found"
  end

  return self:_with_undo(function()
    playlist.name = new_name or playlist.name
    return true
  end)
end

function Controller:set_playlist_color(id, color)
  local playlist = self:_get_playlist(id)
  if not playlist then
    return false, "Playlist not found"
  end

  return self:_with_undo(function()
    playlist.chip_color = color or nil
    return true
  end)
end

function Controller:delete_playlist(id)
  local playlists = self.state.get_playlists()
  if #playlists <= 1 then
    return false, "Cannot delete last playlist"
  end
  
  return self:_with_undo(function()
    local delete_index = nil
    for i, pl in ipairs(playlists) do
      if pl.id == id then
        delete_index = i
        break
      end
    end
    
    if not delete_index then
      error("Playlist not found")
    end
    
    table.remove(playlists, delete_index)
    
    if self.state.get_active_playlist_id() == id then
      local new_active_index = math.min(delete_index, #playlists)
      self.state.set_active_playlist(playlists[new_active_index].id)
    end
    
    for _, pl in ipairs(playlists) do
      local i = 1
      while i <= #pl.items do
        local item = pl.items[i]
        if item.type == "playlist" and item.playlist_id == id then
          table.remove(pl.items, i)
        else
          i = i + 1
        end
      end
    end
  end)
end

function Controller:reorder_playlists(from_idx, to_idx)
  if from_idx == to_idx then
    return true
  end
  
  return self:_with_undo(function()
    local playlists = self.state.get_playlists()
    local moved_playlist = table.remove(playlists, from_idx)
    table.insert(playlists, to_idx, moved_playlist)
  end)
end

function Controller:add_item(playlist_id, rid, insert_index)
  return self:_with_undo(function()
    local pl = self:_get_playlist(playlist_id)
    if not pl then
      error("Playlist not found")
    end
    
    local new_item = {
      type = "region",
      rid = rid,
      reps = 1,
      enabled = true,
      key = self:_generate_item_key(),
    }
    
    table.insert(pl.items, insert_index or (#pl.items + 1), new_item)
    return new_item.key
  end)
end

function Controller:add_playlist_item(target_playlist_id, source_playlist_id, insert_index)
  return self:_with_undo(function()
    local target_pl = self:_get_playlist(target_playlist_id)
    if not target_pl then
      error("Target playlist not found")
    end
    
    local source_pl = self:_get_playlist(source_playlist_id)
    if not source_pl then
      error("Source playlist not found")
    end
    
    local new_item = {
      type = "playlist",
      playlist_id = source_playlist_id,
      reps = 1,
      enabled = true,
      key = self:_generate_item_key(),
    }
    
    table.insert(target_pl.items, insert_index or (#target_pl.items + 1), new_item)
    return new_item.key
  end)
end

function Controller:add_items_batch(playlist_id, rids, insert_index)
  return self:_with_undo(function()
    local pl = self:_get_playlist(playlist_id)
    if not pl then
      error("Playlist not found")
    end
    
    local keys = {}
    local idx = insert_index or (#pl.items + 1)
    
    for i, rid in ipairs(rids) do
      local new_item = {
        type = "region",
        rid = rid,
        reps = 1,
        enabled = true,
        key = self:_generate_item_key(),
      }
      table.insert(pl.items, idx + i - 1, new_item)
      keys[#keys + 1] = new_item.key
    end
    
    return keys
  end)
end

function Controller:copy_items(playlist_id, items, insert_index)
  return self:_with_undo(function()
    local pl = self:_get_playlist(playlist_id)
    if not pl then
      error("Playlist not found")
    end
    
    local keys = {}
    local idx = insert_index or (#pl.items + 1)
    
    for i, item in ipairs(items) do
      local new_item = {
        type = item.type or "region",
        rid = item.rid,
        playlist_id = item.playlist_id,
        reps = item.reps or 1,
        enabled = item.enabled ~= false,
        key = self:_generate_item_key(),
      }
      table.insert(pl.items, idx + i - 1, new_item)
      keys[#keys + 1] = new_item.key
    end
    
    return keys
  end)
end

function Controller:reorder_items(playlist_id, new_order)
  return self:_with_undo(function()
    local pl = self:_get_playlist(playlist_id)
    if not pl then
      error("Playlist not found")
    end
    
    pl.items = new_order
  end)
end

function Controller:delete_items(playlist_id, item_keys)
  return self:_with_undo(function()
    local pl = self:_get_playlist(playlist_id)
    if not pl then
      error("Playlist not found")
    end
    
    local keys_set = {}
    for _, k in ipairs(item_keys) do
      keys_set[k] = true
    end
    
    local new_items = {}
    for _, item in ipairs(pl.items) do
      if not keys_set[item.key] then
        new_items[#new_items + 1] = item
      end
    end
    
    pl.items = new_items
  end)
end

function Controller:toggle_item_enabled(playlist_id, item_key, enabled)
  return self:_with_undo(function()
    local pl = self:_get_playlist(playlist_id)
    if not pl then
      error("Playlist not found")
    end
    
    for _, item in ipairs(pl.items) do
      if item.key == item_key then
        item.enabled = enabled
        return
      end
    end
  end)
end

function Controller:adjust_repeats(playlist_id, item_keys, delta)
  return self:_with_undo(function()
    local pl = self:_get_playlist(playlist_id)
    if not pl then
      error("Playlist not found")
    end
    
    local keys_set = {}
    for _, k in ipairs(item_keys) do
      keys_set[k] = true
    end
    
    for _, item in ipairs(pl.items) do
      if keys_set[item.key] then
        item.reps = math.max(0, (item.reps or 1) + delta)
      end
    end
  end)
end

function Controller:sync_repeats(playlist_id, item_keys, target_reps)
  return self:_with_undo(function()
    local pl = self:_get_playlist(playlist_id)
    if not pl then
      error("Playlist not found")
    end
    
    local keys_set = {}
    for _, k in ipairs(item_keys) do
      keys_set[k] = true
    end
    
    for _, item in ipairs(pl.items) do
      if keys_set[item.key] then
        item.reps = target_reps
      end
    end
  end)
end

function Controller:cycle_repeats(playlist_id, item_key)
  return self:_with_undo(function()
    local pl = self:_get_playlist(playlist_id)
    if not pl then
      error("Playlist not found")
    end
    
    for _, item in ipairs(pl.items) do
      if item.key == item_key then
        local reps = item.reps or 1
        if reps == 1 then
          item.reps = 2
        elseif reps == 2 then
          item.reps = 4
        elseif reps == 4 then
          item.reps = 8
        else
          item.reps = 1
        end
        return
      end
    end
  end)
end

function Controller:undo()
  return self.state.undo()
end

function Controller:redo()
  return self.state.redo()
end

function Controller:can_undo()
  return self.state.can_undo()
end

function Controller:can_redo()
  return self.state.can_redo()
end

return M
