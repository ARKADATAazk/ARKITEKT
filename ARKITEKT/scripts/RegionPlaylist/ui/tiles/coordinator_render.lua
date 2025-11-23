-- @noindex
-- RegionPlaylist/ui/tiles/coordinator_render.lua
-- Rendering methods for region tiles coordinator

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local Dnd = require('arkitekt.gui.fx.interactions.dnd')
local DragIndicator = Dnd.DragIndicator
local ActiveTile = require('RegionPlaylist.ui.tiles.renderers.active')
local PoolTile = require('RegionPlaylist.ui.tiles.renderers.pool')
local ResponsiveGrid = require('arkitekt.gui.systems.responsive_grid')
local State = require('RegionPlaylist.core.app_state')
local ContextMenu = require('arkitekt.gui.widgets.overlays.context_menu')
local SWSImporter = require('RegionPlaylist.storage.sws_importer')
local ModalDialog = require('arkitekt.gui.widgets.overlays.overlay.modal_dialog')
local BatchRenameModal = require('arkitekt.gui.widgets.overlays.batch_rename_modal')
local ColorPickerMenu = require('arkitekt.gui.widgets.menus.color_picker_menu')
local Persistence = require('RegionPlaylist.storage.persistence')

local M = {}

-- Modal state
local sws_result_data = nil
local rename_initial_text = nil

-- Helper: Refresh UI after successful import and select first imported playlist
local function refresh_after_import(self)
  State.reload_project_data()

  -- Select first imported playlist (prepended at index 1)
  local playlists = State.get_playlists()
  if playlists and #playlists > 0 then
    State.set_active_playlist(playlists[1].id)
  end

  -- Update tabs UI
  self.active_container:set_tabs(State.get_tabs(), State.get_active_playlist_id())
end

-- Helper: Execute SWS import and handle results
local function execute_sws_import(self, ctx)
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
    refresh_after_import(self)
  else
    sws_result_data = {
      title = "Import Failed",
      message = "Import failed: " .. tostring(err or "Unknown error")
    }
  end
end

-- Helper: Extract region items from a playlist for operations
local function extract_playlist_region_items(playlist)
  local items = {}
  if playlist and playlist.items then
    for _, item in ipairs(playlist.items) do
      if item.type == "region" and item.rid then
        table.insert(items, {
          rid = item.rid,
          reps = item.reps or 1
        })
      end
    end
  end
  return items
end

-- Helper: Extract RIDs and playlist IDs from pool selection
local function extract_pool_selection(selection)
  local rids = {}
  local playlist_ids = {}
  if selection then
    local selected_keys = selection:selected_keys()
    for _, key in ipairs(selected_keys) do
      local rid = key:match("^pool_(%d+)$")
      if rid then
        table.insert(rids, tonumber(rid))
      end
      local playlist_id = key:match("^pool_playlist_(.+)$")
      if playlist_id then
        table.insert(playlist_ids, playlist_id)
      end
    end
  end
  return rids, playlist_ids
end

function M.draw_selector(self, ctx, playlists, active_id, height)
  self.selector:draw(ctx, playlists, active_id, height, self.on_playlist_changed)
end

function M.draw_active(self, ctx, playlist, height, shell_state)
  self._imgui_ctx = ctx
  local window = shell_state and shell_state.window
  
  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  local avail_w, _ = ImGui.GetContentRegionAvail(ctx)
  
  self.active_bounds = {cursor_x, cursor_y, cursor_x + avail_w, cursor_y + height}
  self.bridge:update_bounds('active', cursor_x, cursor_y, cursor_x + avail_w, cursor_y + height)
  
  self.active_container.width = avail_w
  self.active_container.height = height
  
  if not self.active_container:begin_draw(ctx) then
    return
  end
  
  local header_height = 0
  if self.active_container.config.header and self.active_container.config.header.enabled then
    header_height = self.active_container.config.header.height or 36
  end
  
  local child_w = avail_w - (self.container_config.padding * 2)
  local child_h = (height - header_height) - (self.container_config.padding * 2)

  self.active_grid.get_items = function() return playlist.items end

  local raw_height, raw_gap = ResponsiveGrid.calculate_responsive_tile_height({
    item_count = #playlist.items,
    avail_width = child_w,
    avail_height = child_h,
    base_gap = ActiveTile.CONFIG.gap,
    min_col_width = ActiveTile.CONFIG.tile_width,
    base_tile_height = self.responsive_config.base_tile_height_active,
    min_tile_height = self.responsive_config.min_tile_height,
    responsive_config = self.responsive_config,
  })

  local responsive_height = self.active_height_stabilizer:update(raw_height)

  self.current_active_tile_height = responsive_height
  self.active_grid.fixed_tile_h = responsive_height
  self.active_grid.gap = raw_gap

  local wheel_y = ImGui.GetMouseWheel(ctx)

  if wheel_y ~= 0 then
    local item, key, is_selected = self:_find_hovered_tile(ctx, playlist.items)

    if item and key and self.on_repeat_adjust then
      local delta = (wheel_y > 0) and self.wheel_config.step or -self.wheel_config.step
      local shift_held = ImGui.IsKeyDown(ctx, ImGui.Key_LeftShift) or ImGui.IsKeyDown(ctx, ImGui.Key_RightShift)

      local keys_to_adjust = {}
      if is_selected and self.active_grid.selection:count() > 0 then
        keys_to_adjust = self.active_grid.selection:selected_keys()
      else
        keys_to_adjust = {key}
      end

      if shift_held and self.on_repeat_sync then
        local target_reps = item.reps or 1
        self.on_repeat_sync(keys_to_adjust, target_reps)
      end

      self.on_repeat_adjust(keys_to_adjust, delta)
      self.wheel_consumed_this_frame = true
    end
  end

  self.active_grid:draw(ctx)

  self.active_container:end_draw(ctx)

  -- Actions context menu
  if self._actions_menu_visible then
    ImGui.OpenPopup(ctx, "ActionsMenu")
    self._actions_menu_visible = false
  end

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
      self._sws_import_requested = true
      ImGui.CloseCurrentPopup(ctx)
    end
    ContextMenu.end_menu(ctx)
  end

  -- Execute SWS import
  if self._sws_import_requested then
    self._sws_import_requested = false
    execute_sws_import(self, ctx)
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

  -- Draw batch rename modal (if open)
  if BatchRenameModal.is_open() then
    local active_playlist = State.get_active_playlist()
    local selected_count = 0
    if self.active_grid and self.active_grid.selection then
      selected_count = self.active_grid.selection:count()
    end
    -- Pass window object to enable overlay mode and shell_state for fonts
    BatchRenameModal.draw(ctx, selected_count, window, shell_state)
  end

  -- Modal dialog for playlist renaming removed - now using inline editing

  if self.bridge:is_drag_active() and self.bridge:get_source_grid() == 'active' and ImGui.IsMouseReleased(ctx, 0) then
    if not self.bridge:is_mouse_over_grid(ctx, 'active') then
      self.bridge:cancel_drag()
    else
      self.bridge:clear_drag()
    end
  end
end

function M.draw_pool(self, ctx, regions, height)
  self._imgui_ctx = ctx

  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  local avail_w, _ = ImGui.GetContentRegionAvail(ctx)
  
  self.pool_bounds = {cursor_x, cursor_y, cursor_x + avail_w, cursor_y + height}
  self.bridge:update_bounds('pool', cursor_x, cursor_y, cursor_x + avail_w, cursor_y + height)
  
  self.pool_container.width = avail_w
  self.pool_container.height = height
  
  if not self.pool_container:begin_draw(ctx) then
    return
  end
  
  local header_height = 0
  if self.container_config.header and self.container_config.header.enabled then
    header_height = self.container_config.header.height or 36
  end
  
  local child_w = avail_w - (self.container_config.padding * 2)
  local child_h = (height - header_height) - (self.container_config.padding * 2)

  self.pool_grid.get_items = function() return regions end

  local raw_height, raw_gap = ResponsiveGrid.calculate_responsive_tile_height({
    item_count = #regions,
    avail_width = child_w,
    avail_height = child_h,
    base_gap = PoolTile.CONFIG.gap,
    min_col_width = PoolTile.CONFIG.tile_width,
    base_tile_height = self.responsive_config.base_tile_height_pool,
    min_tile_height = self.responsive_config.min_tile_height,
    responsive_config = self.responsive_config,
  })

  local responsive_height = self.pool_height_stabilizer:update(raw_height)

  self.current_pool_tile_height = responsive_height
  self.pool_grid.fixed_tile_h = responsive_height
  self.pool_grid.gap = raw_gap

  -- Disable background deselection when action menu is visible
  self.pool_grid.disable_background_clicks = ImGui.IsPopupOpen(ctx, "PoolActionsMenu")

  self.pool_grid:draw(ctx)

  self.pool_container:end_draw(ctx)

  -- Pool Actions context menu
  if self._pool_actions_menu_visible then
    ImGui.OpenPopup(ctx, "PoolActionsMenu")
    self._pool_actions_menu_visible = false
  end

  if ContextMenu.begin(ctx, "PoolActionsMenu") then
    if ContextMenu.item(ctx, "Append Selected Regions to Project") then
      local rids = extract_pool_selection(self.pool_grid and self.pool_grid.selection)
      if #rids > 0 then
        local RegionOps = require('arkitekt.reaper.region_operations')
        RegionOps.append_regions_to_project(rids)
      end
      ImGui.CloseCurrentPopup(ctx)
    end

    if ContextMenu.item(ctx, "Paste Selected Regions at Edit Cursor") then
      local rids = extract_pool_selection(self.pool_grid and self.pool_grid.selection)
      if #rids > 0 then
        local RegionOps = require('arkitekt.reaper.region_operations')
        RegionOps.paste_regions_at_cursor(rids)
      end
      ImGui.CloseCurrentPopup(ctx)
    end

    ContextMenu.end_menu(ctx)
  end

  -- Pool tile right-click context menu
  if self._pool_tile_context_visible then
    ImGui.OpenPopup(ctx, "PoolTileContextMenu")
    self._pool_tile_context_visible = false
  end

  if ContextMenu.begin(ctx, "PoolTileContextMenu") then
    local selected_keys = self._pool_tile_context_keys or {}

    -- Apply Random Color (same color for all selected)
    if ContextMenu.item(ctx, "Apply Random Color") then
      if #selected_keys > 0 and self.controller then
        local color = Persistence.generate_chip_color()
        local rids, playlist_ids = extract_pool_selection(self.pool_grid and self.pool_grid.selection)

        if #rids > 0 then
          self.controller:set_region_colors_batch(rids, color)
        end
        for _, playlist_id in ipairs(playlist_ids) do
          self.controller:set_playlist_color(playlist_id, color)
        end
      end
      ImGui.CloseCurrentPopup(ctx)
    end

    -- Apply Random Colors (different color for each)
    if ContextMenu.item(ctx, "Apply Random Colors") then
      if #selected_keys > 0 and self.controller then
        for _, key in ipairs(selected_keys) do
          local color = Persistence.generate_chip_color()
          local rid = key:match("^pool_(%d+)$")
          if rid then
            self.controller:set_region_colors_batch({tonumber(rid)}, color)
          else
            local playlist_id = key:match("^pool_playlist_(.+)$")
            if playlist_id then
              self.controller:set_playlist_color(playlist_id, color)
            end
          end
        end
      end
      ImGui.CloseCurrentPopup(ctx)
    end

    -- Color picker submenu
    ColorPickerMenu.render(ctx, {
      on_select = function(color_int, color_hex, color_name)
        if self.controller and color_int then
          local rids, playlist_ids = extract_pool_selection(self.pool_grid and self.pool_grid.selection)
          if #rids > 0 then
            self.controller:set_region_colors_batch(rids, color_int)
          end
          for _, playlist_id in ipairs(playlist_ids) do
            self.controller:set_playlist_color(playlist_id, color_int)
          end
        end
      end
    })

    -- Batch Rename & Recolor
    if ContextMenu.item(ctx, "Batch Rename & Recolor...") then
      if #selected_keys > 0 then
        BatchRenameModal.open(#selected_keys, function(pattern)
          if self.on_pool_batch_rename then
            self.on_pool_batch_rename(selected_keys, pattern)
          end
        end, {
          item_type = "items",
          on_rename_and_recolor = function(pattern, color)
            if self.on_pool_batch_rename_and_recolor then
              self.on_pool_batch_rename_and_recolor(selected_keys, pattern, color)
            end
          end,
          on_recolor = function(color)
            if self.on_pool_batch_recolor then
              self.on_pool_batch_recolor(selected_keys, color)
            end
          end
        })
      end
      ImGui.CloseCurrentPopup(ctx)
    end

    ContextMenu.end_menu(ctx)
  end

  if self.bridge:is_drag_active() and self.bridge:get_source_grid() == 'pool' and ImGui.IsMouseReleased(ctx, 0) then
    if not self.bridge:is_mouse_over_grid(ctx, 'active') then
      self.bridge:clear_drag()
    end
  end
end

function M.draw_ghosts(self, ctx)
  if not self.bridge:is_drag_active() then return nil end
  
  local mx, my = ImGui.GetMousePos(ctx)
  local count = self.bridge:get_drag_count()
  
  local colors = self:_get_drag_colors()
  local fg_dl = ImGui.GetForegroundDrawList(ctx)
  
  local is_over_active = self.bridge:is_mouse_over_grid(ctx, 'active')
  local is_over_pool = self.bridge:is_mouse_over_grid(ctx, 'pool')
  
  local target_grid = nil
  if is_over_active then
    target_grid = 'active'
  elseif is_over_pool then
    target_grid = 'pool'
  end
  
  local is_copy_mode = false
  local is_delete_mode = false
  
  if target_grid then
    is_copy_mode = self.bridge:compute_copy_mode(target_grid)
    is_delete_mode = self.bridge:compute_delete_mode(ctx, target_grid)
  else
    local source = self.bridge:get_source_grid()
    if source == 'active' then
      is_delete_mode = true
    end
  end
  
  DragIndicator.draw(ctx, fg_dl, mx, my, count, self.config.ghost_config, colors, is_copy_mode, is_delete_mode)
end

return M