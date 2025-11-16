-- @noindex
-- Region_Playlist/ui/tiles/coordinator_render.lua
-- Rendering methods for region tiles coordinator

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local Dnd = require('rearkitekt.gui.fx.interactions.dnd')
local DragIndicator = Dnd.DragIndicator
local ActiveTile = require('Region_Playlist.ui.tiles.renderers.active')
local PoolTile = require('Region_Playlist.ui.tiles.renderers.pool')
local ResponsiveGrid = require('rearkitekt.gui.systems.responsive_grid')
local State = require('Region_Playlist.core.app_state')
local ContextMenu = require('rearkitekt.gui.widgets.overlays.context_menu')
local SWSImporter = require('Region_Playlist.storage.sws_importer')
local ModalDialog = require('rearkitekt.gui.widgets.overlays.overlay.modal_dialog')
local ColorPickerWindow = require('rearkitekt.gui.widgets.tools.color_picker_window')

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

  -- Inline Color Picker (renders on top at bottom-left if visible)
  if self._active_color_picker_visible then
    local picker_size = 130
    -- Position at bottom-left corner of active container
    local picker_x = cursor_x + self.container_config.padding
    local picker_y = cursor_y + height - picker_size - self.container_config.padding

    ImGui.SetCursorScreenPos(ctx, picker_x, picker_y)

    -- Remove all padding
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 0, 0)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 0, 0)

    -- Wrap in a child region for input handling
    if ImGui.BeginChild(ctx, "ActiveColorPickerRegion", picker_size, picker_size, false) then
      ColorPickerWindow.render_inline(ctx, "active_recolor_inline", {
        size = picker_size,
        on_change = function(color)
          -- Batch apply color to all selected regions/playlists
          if self.active_grid and self.active_grid.selection and self.controller then
            local selected_keys = self.active_grid.selection:selected_keys()
            local rids = {}
            local playlist_ids = {}

            for _, key in ipairs(selected_keys) do
              -- Collect regions: "active_123"
              local rid = key:match("^active_(%d+)$")
              if rid then
                table.insert(rids, tonumber(rid))
              end

              -- Collect playlists: "active_playlist_abc-def"
              local playlist_id = key:match("^active_playlist_(.+)$")
              if playlist_id then
                table.insert(playlist_ids, playlist_id)
              end
            end

            -- Batch update regions
            if #rids > 0 then
              self.controller:set_region_colors_batch(rids, color)
            end

            -- Update playlists individually (usually fewer playlists)
            for _, playlist_id in ipairs(playlist_ids) do
              self.controller:set_playlist_color(playlist_id, color)
            end
          end
        end,
        on_close = function()
          self._active_color_picker_visible = false
        end,
      })
      ImGui.EndChild(ctx)
    end

    ImGui.PopStyleVar(ctx, 2)
  end

  -- Actions context menu
  if self._actions_menu_visible then
    ImGui.OpenPopup(ctx, "ActionsMenu")
    self._actions_menu_visible = false
  end

  if ContextMenu.begin(ctx, "ActionsMenu") then
    if ContextMenu.item(ctx, "Recolor") then
      -- Toggle behavior: close if already open
      if self._active_color_picker_visible then
        self._active_color_picker_visible = false
      else
        -- Get first selected item's color as initial color
        local initial_color = nil
        if self.active_grid and self.active_grid.selection then
          local selected_keys = self.active_grid.selection:selected_keys()
          for _, key in ipairs(selected_keys) do
            local rid = key:match("^active_(%d+)$")
            if rid then
              local region = State.get_region_by_rid(tonumber(rid))
              if region and region.color then
                initial_color = region.color
                break
              end
            end
          end
        end

        -- Show inline color picker
        self._active_color_picker_visible = true
        ColorPickerWindow.show_inline("active_recolor_inline", initial_color)
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

  -- Open rename playlist modal
  if self._rename_input_visible then
    -- Find current name
    local playlists = State.get_playlists()
    reaper.ShowConsoleMsg("[Debug] Looking for playlist ID: " .. tostring(self._rename_playlist_id) .. "\n")
    for _, pl in ipairs(playlists) do
      reaper.ShowConsoleMsg("[Debug] Checking playlist ID: " .. tostring(pl.id) .. " name: " .. tostring(pl.name) .. "\n")
      if pl.id == self._rename_playlist_id then
        rename_initial_text = pl.name or ""
        reaper.ShowConsoleMsg("[Debug] Found matching playlist!\n")
        break
      end
    end
    if not rename_initial_text then
      reaper.ShowConsoleMsg("[Debug] ERROR: No matching playlist found!\n")
    end
    self._rename_input_visible = false
  end

  -- Show rename playlist modal
  if rename_initial_text then
    ModalDialog.show_input(ctx, window, "Rename Playlist", rename_initial_text, {
      id = "##rename_playlist",
      placeholder = "Enter playlist name",
      confirm_label = "Rename",
      cancel_label = "Cancel",
      width = 0.4,
      height = 0.25,
      on_confirm = function(new_name)
        if self.controller and self._rename_playlist_id then
          self.controller:rename_playlist(self._rename_playlist_id, new_name)
          self.active_container:set_tabs(State.get_tabs(), State.get_active_playlist_id())
        end
        rename_initial_text = nil
        self._rename_playlist_id = nil
      end,
      on_cancel = function()
        rename_initial_text = nil
        self._rename_playlist_id = nil
      end
    })
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

  -- Inline Color Picker (renders on top at bottom-left if visible)
  if self._pool_color_picker_visible then
    local picker_size = 130
    -- Position at bottom-left corner of pool container
    local picker_x = cursor_x + self.container_config.padding
    local picker_y = cursor_y + height - picker_size - self.container_config.padding

    ImGui.SetCursorScreenPos(ctx, picker_x, picker_y)

    -- Remove all padding
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 0, 0)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 0, 0)

    -- Wrap in a child region for input handling
    if ImGui.BeginChild(ctx, "PoolColorPickerRegion", picker_size, picker_size, false) then
      ColorPickerWindow.render_inline(ctx, "pool_recolor_inline", {
        size = picker_size,
        on_change = function(color)
          -- Batch apply color to all selected regions/playlists
          if self.pool_grid and self.pool_grid.selection and self.controller then
            local selected_keys = self.pool_grid.selection:selected_keys()
            local rids = {}
            local playlist_ids = {}

            for _, key in ipairs(selected_keys) do
              -- Collect regions: "pool_123"
              local rid = key:match("^pool_(%d+)$")
              if rid then
                table.insert(rids, tonumber(rid))
              end

              -- Collect playlists: "pool_playlist_abc-def"
              local playlist_id = key:match("^pool_playlist_(.+)$")
              if playlist_id then
                table.insert(playlist_ids, playlist_id)
              end
            end

            -- Batch update regions
            if #rids > 0 then
              self.controller:set_region_colors_batch(rids, color)
            end

            -- Update playlists individually (usually fewer playlists)
            for _, playlist_id in ipairs(playlist_ids) do
              self.controller:set_playlist_color(playlist_id, color)
            end
          end
        end,
        on_close = function()
          self._pool_color_picker_visible = false
        end,
      })
      ImGui.EndChild(ctx)
    end

    ImGui.PopStyleVar(ctx, 2)
  end

  -- Pool Actions context menu
  if self._pool_actions_menu_visible then
    ImGui.OpenPopup(ctx, "PoolActionsMenu")
    self._pool_actions_menu_visible = false
  end

  if ContextMenu.begin(ctx, "PoolActionsMenu") then
    if ContextMenu.item(ctx, "Recolor") then
      -- Toggle behavior: close if already open
      if self._pool_color_picker_visible then
        self._pool_color_picker_visible = false
      else
        -- Get first selected item's color as initial color
        local initial_color = nil
        if self.pool_grid and self.pool_grid.selection then
          local selected_keys = self.pool_grid.selection:selected_keys()
          for _, key in ipairs(selected_keys) do
            local rid = key:match("^pool_(%d+)$")
            if rid then
              local region = State.get_region_by_rid(tonumber(rid))
              if region and region.color then
                initial_color = region.color
                break
              end
            end
          end
        end

        -- Show inline color picker
        self._pool_color_picker_visible = true
        ColorPickerWindow.show_inline("pool_recolor_inline", initial_color)
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