-- @noindex
-- RegionPlaylist/ui/components/menus/pool_tile_context_menu.lua
-- Pool Tile Context Menu - Right-click context menu for pool tiles (regions/playlists)

local ImGui = require('arkitekt.platform.imgui')
local ContextMenu = require('arkitekt.gui.widgets.overlays.context_menu')
local ColorPickerMenu = require('arkitekt.gui.widgets.menus.color_picker_menu')
local BatchRenameModal = require('arkitekt.gui.widgets.overlays.batch_rename_modal')
local Persistence = require('RegionPlaylist.data.storage')

local M = {}

-- Helper: Extract RIDs and playlist IDs from pool selection
local function extract_pool_selection(selection)
  local rids = {}
  local playlist_ids = {}
  if selection then
    local selected_keys = selection:selected_keys()
    for _, key in ipairs(selected_keys) do
      local rid = key:match("^pool_(%d+)$")
      if rid then
        rids[#rids + 1] = tonumber(rid)
      end
      local playlist_id = key:match("^pool_playlist_(.+)$")
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

-- Trigger menu to open on next frame with selected keys
function M.open(coordinator, selected_keys)
  coordinator._pool_tile_context_visible = true
  coordinator._pool_tile_context_keys = selected_keys
end

-- Render menu popup and handle interactions
function M.render(ctx, coordinator, shell_state)
  -- Open popup if requested
  if coordinator._pool_tile_context_visible then
    ImGui.OpenPopup(ctx, "PoolTileContextMenu")
    coordinator._pool_tile_context_visible = false
  end

  -- Render popup
  if ContextMenu.begin(ctx, "PoolTileContextMenu") then
    local selected_keys = coordinator._pool_tile_context_keys or {}

    -- Apply Random Color (same color for all selected)
    if ContextMenu.item(ctx, "Apply Random Color") then
      if #selected_keys > 0 and coordinator.controller then
        local color = Persistence.generate_chip_color()
        local rids, playlist_ids = extract_pool_selection(coordinator.pool_grid and coordinator.pool_grid.selection)

        if #rids > 0 then
          coordinator.controller:set_region_colors_batch(rids, color)
        end
        for _, playlist_id in ipairs(playlist_ids) do
          coordinator.controller:set_playlist_color(playlist_id, color)
        end
      end
      ImGui.CloseCurrentPopup(ctx)
    end

    -- Apply Random Colors (different color for each)
    if ContextMenu.item(ctx, "Apply Random Colors") then
      if #selected_keys > 0 and coordinator.controller then
        -- Build map of rid -> color for batch operation
        local rid_color_map = {}
        local playlist_colors = {}

        for _, key in ipairs(selected_keys) do
          local color = Persistence.generate_chip_color()
          local rid = key:match("^pool_(%d+)$")
          if rid then
            rid_color_map[tonumber(rid)] = color
          else
            local playlist_id = key:match("^pool_playlist_(.+)$")
            if playlist_id then
              playlist_colors[#playlist_colors + 1] = {id = playlist_id, color = color}
            end
          end
        end

        -- Single batch operation for all regions (MUCH faster!)
        if next(rid_color_map) then
          coordinator.controller:set_region_colors_individual(rid_color_map)
        end

        -- Apply playlist colors
        for _, entry in ipairs(playlist_colors) do
          coordinator.controller:set_playlist_color(entry.id, entry.color)
        end
      end
      ImGui.CloseCurrentPopup(ctx)
    end

    -- Color picker submenu
    ColorPickerMenu.render(ctx, {
      on_select = function(color_int, color_hex, color_name)
        if coordinator.controller and color_int then
          local rids, playlist_ids = extract_pool_selection(coordinator.pool_grid and coordinator.pool_grid.selection)
          if #rids > 0 then
            coordinator.controller:set_region_colors_batch(rids, color_int)
          end
          for _, playlist_id in ipairs(playlist_ids) do
            coordinator.controller:set_playlist_color(playlist_id, color_int)
          end
        end
      end
    })

    -- Batch Rename & Recolor
    if ContextMenu.item(ctx, "Batch Rename & Recolor...") then
      if #selected_keys > 0 then
        BatchRenameModal.open(#selected_keys, function(pattern)
          if coordinator.on_pool_batch_rename then
            coordinator.on_pool_batch_rename(selected_keys, pattern)
          end
        end, {
          item_type = "items",
          on_rename_and_recolor = function(pattern, color)
            if coordinator.on_pool_batch_rename_and_recolor then
              coordinator.on_pool_batch_rename_and_recolor(selected_keys, pattern, color)
            end
          end,
          on_recolor = function(color)
            if coordinator.on_pool_batch_recolor then
              coordinator.on_pool_batch_recolor(selected_keys, color)
            end
          end
        })
      end
      ImGui.CloseCurrentPopup(ctx)
    end

    ContextMenu.end_menu(ctx)
  end
end

return M
