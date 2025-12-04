-- @noindex
-- RegionPlaylist/ui/components/menus/pool_actions_menu.lua
-- Pool Grid Actions Menu - Context menu for batch operations on pool selection

local ImGui = require('arkitekt.core.imgui')
local ContextMenu = require('arkitekt.gui.widgets.overlays.context_menu')

local M = {}

-- Helper: Extract RIDs and playlist IDs from pool selection
local function extract_pool_selection(selection)
  local rids = {}
  local playlist_ids = {}
  if selection then
    local selected_keys = selection:selected_keys()
    for _, key in ipairs(selected_keys) do
      local rid = key:match('^pool_(%d+)$')
      if rid then
        rids[#rids + 1] = tonumber(rid)
      end
      local playlist_id = key:match('^pool_playlist_(.+)$')
      if playlist_id then
        playlist_ids[#playlist_ids + 1] = playlist_id
      end
    end
  end
  return rids, playlist_ids
end

-- =============================================================================
-- PUBLIC API
-- =============================================================================

-- Trigger menu to open on next frame
function M.open(coordinator)
  coordinator._pool_actions_menu_visible = true
end

-- Render menu popup and handle interactions
function M.render(ctx, coordinator)
  -- Open popup if requested
  if coordinator._pool_actions_menu_visible then
    ImGui.OpenPopup(ctx, 'PoolActionsMenu')
    coordinator._pool_actions_menu_visible = false
  end

  -- Render popup
  if ContextMenu.begin(ctx, 'PoolActionsMenu') then
    if ContextMenu.item(ctx, 'Append Selected Regions to Project') then
      local rids = extract_pool_selection(coordinator.pool_grid and coordinator.pool_grid.selection)
      if #rids > 0 then
        local RegionOps = require('arkitekt.reaper.region_operations')
        RegionOps.append_regions_to_project(rids)
      end
      ImGui.CloseCurrentPopup(ctx)
    end

    if ContextMenu.item(ctx, 'Paste Selected Regions at Edit Cursor') then
      local rids = extract_pool_selection(coordinator.pool_grid and coordinator.pool_grid.selection)
      if #rids > 0 then
        local RegionOps = require('arkitekt.reaper.region_operations')
        RegionOps.paste_regions_at_cursor(rids)
      end
      ImGui.CloseCurrentPopup(ctx)
    end

    ContextMenu.end_menu(ctx)
  end
end

return M
