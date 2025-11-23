-- @noindex
-- RegionPlaylist/ui/batch_operations.lua
-- Helper for batch rename/recolor operations on regions and playlists

local BatchRenameModal = require('arkitekt.gui.widgets.overlays.batch_rename_modal')
local Regions = require('arkitekt.reaper.regions')

local M = {}

-- =============================================================================
-- ITEM SEPARATION
-- =============================================================================

-- Separate active grid items into regions and playlists
-- Returns: region_items, playlist_items (arrays with item data)
function M.separate_active_items(item_keys, get_items_fn)
  local region_items = {}
  local playlist_items = {}

  local items = get_items_fn()
  for i, key in ipairs(item_keys) do
    for _, item in ipairs(items) do
      if item.key == key then
        if item.type == "playlist" then
          table.insert(playlist_items, {
            index = i,
            key = key,
            playlist_id = item.playlist_id
          })
        else
          table.insert(region_items, {
            index = i,
            key = key,
            rid = item.rid
          })
        end
        break
      end
    end
  end

  return region_items, playlist_items
end

-- Separate pool items into regions and playlists by parsing keys
-- Returns: region_items, playlist_items (arrays with item data)
function M.separate_pool_items(item_keys)
  local region_items = {}
  local playlist_items = {}

  for i, key in ipairs(item_keys) do
    local rid = tonumber(key:match("pool_(%d+)"))
    if rid then
      table.insert(region_items, {
        index = i,
        key = key,
        rid = rid
      })
    else
      local playlist_id = key:match("pool_playlist_(.+)")
      if playlist_id then
        table.insert(playlist_items, {
          index = i,
          key = key,
          playlist_id = playlist_id
        })
      end
    end
  end

  return region_items, playlist_items
end

-- =============================================================================
-- BATCH OPERATIONS
-- =============================================================================

-- Batch rename regions and playlists
function M.batch_rename(region_items, playlist_items, new_names, controller)
  -- Batch rename regions
  if #region_items > 0 then
    local region_renames = {}
    for _, item in ipairs(region_items) do
      table.insert(region_renames, {
        rid = item.rid,
        name = new_names[item.index]
      })
    end
    Regions.set_region_names_batch(0, region_renames)
  end

  -- Rename playlists individually
  for _, item in ipairs(playlist_items) do
    controller:rename_playlist(item.playlist_id, new_names[item.index])
  end
end

-- Batch recolor regions and playlists
function M.batch_recolor(region_items, playlist_items, color, controller)
  -- Batch recolor regions
  if #region_items > 0 then
    local rids = {}
    for _, item in ipairs(region_items) do
      table.insert(rids, item.rid)
    end
    controller:set_region_colors_batch(rids, color)
  end

  -- Recolor playlists individually
  for _, item in ipairs(playlist_items) do
    controller:set_playlist_color(item.playlist_id, color)
  end
end

-- =============================================================================
-- HIGH-LEVEL OPERATIONS (for GUI callbacks)
-- =============================================================================

-- Rename items from active grid
function M.rename_active(item_keys, pattern, get_items_fn, controller)
  local new_names = BatchRenameModal.apply_pattern_to_items(pattern, #item_keys)
  local region_items, playlist_items = M.separate_active_items(item_keys, get_items_fn)
  M.batch_rename(region_items, playlist_items, new_names, controller)
  return #playlist_items > 0
end

-- Rename and recolor items from active grid
function M.rename_and_recolor_active(item_keys, pattern, color, get_items_fn, controller)
  local new_names = BatchRenameModal.apply_pattern_to_items(pattern, #item_keys)
  local region_items, playlist_items = M.separate_active_items(item_keys, get_items_fn)
  M.batch_rename(region_items, playlist_items, new_names, controller)
  M.batch_recolor(region_items, playlist_items, color, controller)
  return #playlist_items > 0
end

-- Recolor items from active grid
function M.recolor_active(item_keys, color, get_items_fn, controller)
  local region_items, playlist_items = M.separate_active_items(item_keys, get_items_fn)
  M.batch_recolor(region_items, playlist_items, color, controller)
end

-- Rename items from pool
function M.rename_pool(item_keys, pattern, controller)
  local new_names = BatchRenameModal.apply_pattern_to_items(pattern, #item_keys)
  local region_items, playlist_items = M.separate_pool_items(item_keys)
  M.batch_rename(region_items, playlist_items, new_names, controller)
  return #playlist_items > 0
end

-- Rename and recolor items from pool
function M.rename_and_recolor_pool(item_keys, pattern, color, controller)
  local new_names = BatchRenameModal.apply_pattern_to_items(pattern, #item_keys)
  local region_items, playlist_items = M.separate_pool_items(item_keys)
  M.batch_rename(region_items, playlist_items, new_names, controller)
  M.batch_recolor(region_items, playlist_items, color, controller)
  return #playlist_items > 0
end

-- Recolor items from pool
function M.recolor_pool(item_keys, color, controller)
  local region_items, playlist_items = M.separate_pool_items(item_keys)
  M.batch_recolor(region_items, playlist_items, color, controller)
end

return M
