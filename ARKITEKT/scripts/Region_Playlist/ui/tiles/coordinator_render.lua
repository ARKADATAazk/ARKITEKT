-- @noindex
-- Region_Playlist/ui/tiles/coordinator_render.lua
-- Rendering methods for region tiles coordinator

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local DragIndicator = require('rearkitekt.gui.fx.dnd.drag_indicator')
local ActiveTile = require('Region_Playlist.ui.tiles.renderers.active')
local PoolTile = require('Region_Playlist.ui.tiles.renderers.pool')
local ResponsiveGrid = require('rearkitekt.gui.systems.responsive_grid')
local State = require('Region_Playlist.core.app_state')
local ContextMenu = require('rearkitekt.gui.widgets.controls.context_menu')
local SWSImporter = require('Region_Playlist.storage.sws_importer')

local M = {}

function M.draw_selector(self, ctx, playlists, active_id, height)
  self.selector:draw(ctx, playlists, active_id, height, self.on_playlist_changed)
end

function M.draw_active(self, ctx, playlist, height)
  self._imgui_ctx = ctx
  
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
    if ContextMenu.item(ctx, "Import from SWS Region Playlist") then
      -- Trigger import
      self._sws_import_requested = true
      ImGui.CloseCurrentPopup(ctx)
    end

    ContextMenu.end_menu(ctx)
  end

  -- SWS Import execution and result modal
  if self._sws_import_requested then
    self._sws_import_requested = false

    -- Check if SWS playlists exist
    local has_sws = SWSImporter.has_sws_playlists()

    if not has_sws then
      self._sws_import_result = {
        success = false,
        message = "No SWS Region Playlists found in the current project.\n\nMake sure the project is saved and contains SWS Region Playlists."
      }
      self._sws_show_result = true
    else
      -- Execute import (replace mode, with backup)
      local success, report, err = SWSImporter.execute_import(false, true)

      if success and report then
        local formatted = SWSImporter.format_report(report)
        self._sws_import_result = {
          success = true,
          message = "Import successful!\n\n" .. formatted
        }
      else
        self._sws_import_result = {
          success = false,
          message = "Import failed: " .. tostring(err or "Unknown error")
        }
      end

      self._sws_show_result = true

      -- Refresh UI state
      if success then
        State.reload_project_data()
        -- Update tabs in the active container
        self.active_container:set_tabs(State.get_tabs(), State.get_active_playlist_id())
      end
    end
  end

  -- Show import result modal
  if self._sws_show_result then
    ImGui.OpenPopup(ctx, "SWS Import Result")
    self._sws_show_result = false
  end

  if ImGui.BeginPopupModal(ctx, "SWS Import Result", nil, ImGui.WindowFlags_AlwaysAutoResize) then
    if self._sws_import_result then
      ImGui.TextWrapped(ctx, self._sws_import_result.message)
      ImGui.Spacing(ctx)

      if ImGui.Button(ctx, "OK", 120, 0) or ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) or ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
        self._sws_import_result = nil
        ImGui.CloseCurrentPopup(ctx)
      end
    end
    ImGui.EndPopup(ctx)
  end

  -- Rename playlist modal
  if self._rename_input_visible then
    ImGui.OpenPopup(ctx, "Rename Playlist")
    self._rename_input_visible = false
    if not self._rename_input_buffer then
      -- Find current name
      local playlists = State.get_playlists()
      for _, pl in ipairs(playlists) do
        if pl.id == self._rename_playlist_id then
          self._rename_input_buffer = pl.name or ""
          break
        end
      end
    end
  end

  if ImGui.BeginPopupModal(ctx, "Rename Playlist", nil, ImGui.WindowFlags_AlwaysAutoResize) then
    ImGui.Text(ctx, "Enter new name:")
    ImGui.SetNextItemWidth(ctx, 300)

    if not self._rename_input_buffer then
      self._rename_input_buffer = ""
    end

    local rv, buf = ImGui.InputText(ctx, "##rename_input", self._rename_input_buffer)
    if rv then
      self._rename_input_buffer = buf
    end

    if ImGui.IsWindowAppearing(ctx) then
      ImGui.SetKeyboardFocusHere(ctx, -1)
    end

    ImGui.Spacing(ctx)

    if ImGui.Button(ctx, "OK", 100, 0) or ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
      if self.controller and self._rename_playlist_id and self._rename_input_buffer and self._rename_input_buffer ~= "" then
        self.controller:rename_playlist(self._rename_playlist_id, self._rename_input_buffer)
        self.active_container:set_tabs(State.get_tabs(), State.get_active_playlist_id())
      end
      self._rename_input_buffer = nil
      self._rename_playlist_id = nil
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.SameLine(ctx)

    if ImGui.Button(ctx, "Cancel", 100, 0) or ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
      self._rename_input_buffer = nil
      self._rename_playlist_id = nil
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.EndPopup(ctx)
  end

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
  
  self.pool_grid:draw(ctx)
  
  self.pool_container:end_draw(ctx)
  
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