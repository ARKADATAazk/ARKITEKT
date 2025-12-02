-- @noindex
-- RegionPlaylist/ui/components/menus/active_actions_menu.lua
-- Active Grid Actions Menu - Context menu for batch operations on active playlist

local ImGui = require('arkitekt.platform.imgui')
local ContextMenu = require('arkitekt.gui.widgets.overlays.context_menu')
local ModalDialog = require('arkitekt.gui.widgets.overlays.overlay.modal_dialog')
local SWSImporter = require('RegionPlaylist.data.sws_import')
local State = require("RegionPlaylist.app.state")

local M = {}

-- Modal state
local sws_result_data = nil

-- Helper: Extract region items from a playlist for operations
local function extract_playlist_region_items(playlist)
  local items = {}
  if playlist and playlist.items then
    for _, item in ipairs(playlist.items) do
      if item.type == "region" and item.rid then
        items[#items + 1] = {
          rid = item.rid,
          reps = item.reps or 1
        }
      end
    end
  end
  return items
end

-- Helper: Refresh UI after successful import and select first imported playlist
local function refresh_after_import(coordinator)
  State.reload_project_data()

  -- Select first imported playlist (prepended at index 1)
  local playlists = State.get_playlists()
  if playlists and #playlists > 0 then
    State.set_active_playlist(playlists[1].id)
  end

  -- Update tabs UI
  coordinator.active_container:set_tabs(State.get_tabs(), State.get_active_playlist_id())
end

-- Helper: Execute SWS import and handle results
local function execute_sws_import(coordinator, ctx)
  -- Check for SWS playlists
  if not SWSImporter.has_sws_playlists() then
    sws_result_data = {
      title = "Import Failed",
      message = "No SWS Region Playlists found in the current project.\n\n" ..
                "Make sure the project is saved and contains SWS Region Playlists."
    }
    return
  end

  -- Execute import
  local success, report, err = SWSImporter.execute_import(true, true)

  if success and report then
    sws_result_data = {
      title = "Import Successful",
      message = "Import successful!\n\n" .. SWSImporter.format_report(report)
    }
    refresh_after_import(coordinator)
  else
    sws_result_data = {
      title = "Import Failed",
      message = "Import failed: " .. tostring(err or "Unknown error")
    }
  end
end

-- =============================================================================
-- PUBLIC API
-- =============================================================================

-- Trigger menu to open on next frame
function M.open(coordinator)
  coordinator._actions_menu_visible = true
end

-- Render menu popup and handle interactions
function M.render(ctx, coordinator, shell_state)
  local window = shell_state and shell_state.window

  -- Open popup if requested
  if coordinator._actions_menu_visible then
    ImGui.OpenPopup(ctx, "ActionsMenu")
    coordinator._actions_menu_visible = false
  end

  -- Render popup
  if ContextMenu.begin(ctx, "ActionsMenu") then
    if ContextMenu.item(ctx, "Crop Project to Playlist") then
      local playlist = State.get_active_playlist()
      local playlist_items = extract_playlist_region_items(playlist)
      if #playlist_items > 0 then
        local RegionOps = require('arkitekt.reaper.region_operations')
        RegionOps.crop_to_playlist(playlist_items)
      end
      ImGui.CloseCurrentPopup(ctx)
    end

    if ContextMenu.item(ctx, "Crop to Playlist (New Tab)") then
      local playlist = State.get_active_playlist()
      local playlist_items = extract_playlist_region_items(playlist)
      if #playlist_items > 0 then
        local RegionOps = require('arkitekt.reaper.region_operations')
        RegionOps.crop_to_playlist_new_tab(playlist_items, playlist.name, playlist.chip_color)
      end
      ImGui.CloseCurrentPopup(ctx)
    end

    if ContextMenu.item(ctx, "Append Playlist to Project") then
      local playlist = State.get_active_playlist()
      local playlist_items = extract_playlist_region_items(playlist)
      if #playlist_items > 0 then
        local RegionOps = require('arkitekt.reaper.region_operations')
        RegionOps.append_playlist_to_project(playlist_items)
      end
      ImGui.CloseCurrentPopup(ctx)
    end

    if ContextMenu.item(ctx, "Paste Playlist at Edit Cursor") then
      local playlist = State.get_active_playlist()
      local playlist_items = extract_playlist_region_items(playlist)
      if #playlist_items > 0 then
        local RegionOps = require('arkitekt.reaper.region_operations')
        RegionOps.paste_playlist_at_cursor(playlist_items)
      end
      ImGui.CloseCurrentPopup(ctx)
    end

    if ContextMenu.item(ctx, "Import from SWS Region Playlist") then
      coordinator._sws_import_requested = true
      ImGui.CloseCurrentPopup(ctx)
    end
    ContextMenu.end_menu(ctx)
  end

  -- Execute SWS import
  if coordinator._sws_import_requested then
    coordinator._sws_import_requested = false
    execute_sws_import(coordinator, ctx)
  end

  -- Show SWS import result modal
  if sws_result_data then
    ModalDialog.show_message(ctx, window, sws_result_data.title, sws_result_data.message, {
      id = "##sws_import_result",
      button_label = "OK",
      width = 0.45,
      height = 0.25,
      on_close = function()
        sws_result_data = nil
      end
    })
  end
end

return M
