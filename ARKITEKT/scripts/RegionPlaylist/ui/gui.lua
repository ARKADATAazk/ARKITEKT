-- @noindex
-- RegionPlaylist/ui/gui.lua
-- Main GUI orchestrator (refactored - view-based architecture)

local ImGui = require 'imgui' '0.10'
local RegionTiles = require("RegionPlaylist.ui.tiles.coordinator")
local Shortcuts = require("RegionPlaylist.ui.shortcuts")
local PlaylistController = require("RegionPlaylist.core.controller")
local Config = require('RegionPlaylist.core.config')
local BatchOperations = require("RegionPlaylist.ui.batch_operations")

local TransportView = require("RegionPlaylist.ui.views.transport.transport_view")
local LayoutView = require("RegionPlaylist.ui.views.layout_view")
local OverflowModalView = require("RegionPlaylist.ui.views.overflow_modal_view")

local M = {}
local GUI = {}
GUI.__index = GUI

function M.create(State, AppConfig, settings)
  local self = setmetatable({
    State = State,
    Config = Config,
    settings = settings,
    region_tiles = nil,
    controller = nil,
    shell_state = nil,
    quantize_lookahead = settings and settings:get('quantize_lookahead') or Config.QUANTIZE.default_lookahead,
    
    transport_view = nil,
    layout_view = nil,
    overflow_modal_view = nil,
  }, GUI)
  
  self.controller = PlaylistController.new(State, settings, State.undo_manager)
  
  State.get_bridge():set_controller(self.controller)
  State.get_bridge():set_playlist_lookup(State.get_playlist_by_id)
  
  if not State.get_separator_position_horizontal() then
    State.set_separator_position_horizontal(Config.SEPARATOR.horizontal.default_position)
  end
  if not State.get_separator_position_vertical() then
    State.set_separator_position_vertical(Config.SEPARATOR.vertical.default_position)
  end
  
  State.on_state_restored = function()
    self:refresh_tabs()
    if self.region_tiles.active_grid and self.region_tiles.active_grid.selection then
      self.region_tiles.active_grid.selection:clear()
    end
    if self.region_tiles.pool_grid and self.region_tiles.pool_grid.selection then
      self.region_tiles.pool_grid.selection:clear()
    end
  end
  
  State.on_repeat_cycle = function(key, current_loop, total_reps)
  end
  
  self.region_tiles = RegionTiles.create({
    State = State,
    controller = self.controller,

    get_region_by_rid = function(rid)
      return State.get_region_by_rid(rid)
    end,

    get_playlist_by_id = function(playlist_id)
      return State.get_playlist_by_id(playlist_id)
    end,

    detect_circular_ref = function(target_playlist_id, source_playlist_id)
      return State.detect_circular_reference(target_playlist_id, source_playlist_id)
    end,

    allow_pool_reorder = true,
    enable_active_tabs = true,
    tabs = State.get_tabs(),
    active_tab_id = State.get_active_playlist_id(),
    pool_mode = State.get_pool_mode(),
    config = AppConfig.get_region_tiles_config(State.get_layout_mode()),
    
    on_playlist_changed = function(new_id)
      State.set_active_playlist(new_id)
    end,
    
    on_pool_search = function(text)
      State.set_search_filter(text)
      State.persist_ui_prefs()
    end,
    
    on_pool_sort = function(mode)
      State.set_sort_mode(mode)
      if mode == nil then
        State.set_sort_direction("asc")
      end
      State.persist_ui_prefs()
    end,
    
    on_pool_sort_direction = function(direction)
      State.set_sort_direction(direction)
      State.persist_ui_prefs()
    end,
    
    on_pool_mode_changed = function(mode)
      State.set_pool_mode(mode)
      self.region_tiles:set_pool_mode(mode)
      State.persist_ui_prefs()
    end,
    
    on_active_reorder = function(new_order)
      self.controller:reorder_items(State.get_active_playlist_id(), new_order)
    end,
    
    on_active_remove = function(item_key)
      self.controller:delete_items(State.get_active_playlist_id(), {item_key})
    end,
    
    on_active_toggle_enabled = function(item_key, new_state)
      self.controller:toggle_item_enabled(State.get_active_playlist_id(), item_key, new_state)
    end,
    
    on_active_delete = function(item_keys)
      self.controller:delete_items(State.get_active_playlist_id(), item_keys)
      for _, key in ipairs(item_keys) do
        State.add_pending_destroy(key)
      end
    end,

    -- Single item rename (inline editing)
    on_active_rename = function(item_key, new_name)
      self.controller:rename_item(State.get_active_playlist_id(), item_key, new_name)
      -- Refresh tabs in case a playlist was renamed
      self.region_tiles.active_container:set_tabs(State.get_tabs(), State.get_active_playlist_id())
    end,

    -- Batch rename with wildcards
    on_active_batch_rename = function(item_keys, pattern)
      local has_playlists = BatchOperations.rename_active(
        item_keys, pattern,
        self.region_tiles.active_grid.get_items,
        self.controller
      )
      if has_playlists then
        self.region_tiles.active_container:set_tabs(State.get_tabs(), State.get_active_playlist_id())
      end
    end,

    -- Batch rename and recolor
    on_active_batch_rename_and_recolor = function(item_keys, pattern, color)
      local has_playlists = BatchOperations.rename_and_recolor_active(
        item_keys, pattern, color,
        self.region_tiles.active_grid.get_items,
        self.controller
      )
      if has_playlists then
        self.region_tiles.active_container:set_tabs(State.get_tabs(), State.get_active_playlist_id())
      end
    end,

    -- Batch recolor only
    on_active_batch_recolor = function(item_keys, color)
      BatchOperations.recolor_active(
        item_keys, color,
        self.region_tiles.active_grid.get_items,
        self.controller
      )
    end,

    -- Single item rename from pool (inline editing)
    on_pool_rename = function(item_key, new_name)
      local rid = tonumber(item_key:match("pool_(%d+)"))
      if rid then
        -- Rename region directly
        local Regions = require('arkitekt.reaper.regions')
        Regions.set_region_name(0, rid, new_name)
      else
        -- Rename playlist
        local playlist_id = item_key:match("pool_playlist_(.+)")
        if playlist_id then
          self.controller:rename_playlist(playlist_id, new_name)
          -- Refresh tabs to show updated playlist name
          self.region_tiles.active_container:set_tabs(State.get_tabs(), State.get_active_playlist_id())
        end
      end
    end,

    -- Batch rename from pool
    on_pool_batch_rename = function(item_keys, pattern)
      local has_playlists = BatchOperations.rename_pool(
        item_keys, pattern,
        self.controller
      )
      if has_playlists then
        self.region_tiles.active_container:set_tabs(State.get_tabs(), State.get_active_playlist_id())
      end
    end,

    -- Batch rename and recolor from pool
    on_pool_batch_rename_and_recolor = function(item_keys, pattern, color)
      local has_playlists = BatchOperations.rename_and_recolor_pool(
        item_keys, pattern, color,
        self.controller
      )
      if has_playlists then
        self.region_tiles.active_container:set_tabs(State.get_tabs(), State.get_active_playlist_id())
      end
    end,

    -- Batch recolor from pool
    on_pool_batch_recolor = function(item_keys, color)
      BatchOperations.recolor_pool(
        item_keys, color,
        self.controller
      )
    end,

    on_destroy_complete = function(key)
    end,
    
    on_active_copy = function(dragged_items, target_index)
      local success, keys = self.controller:copy_items(State.get_active_playlist_id(), dragged_items, target_index)
      if success and keys then
        for _, key in ipairs(keys) do
          State.add_pending_spawn(key)
          State.add_pending_select(key)
        end
      end
    end,
    
    on_pool_to_active = function(rid, insert_index)
      local success, key = self.controller:add_item(State.get_active_playlist_id(), rid, insert_index)
      return success and key or nil
    end,
    
    on_pool_playlist_to_active = function(playlist_id, insert_index)
      local success, key = self.controller:add_playlist_item(State.get_active_playlist_id(), playlist_id, insert_index)
      return success and key or nil
    end,
    
    on_pool_reorder = function(new_rids)
      State.set_pool_order(new_rids)
      State.persist_ui_prefs()
    end,
    
    on_pool_playlist_reorder = function(new_playlist_ids)
      State.reorder_playlists_by_ids(new_playlist_ids)
    end,
    
    on_repeat_cycle = function(item_key)
      self.controller:cycle_repeats(State.get_active_playlist_id(), item_key)
    end,
    
    on_repeat_adjust = function(keys, delta)
      self.controller:adjust_repeats(State.get_active_playlist_id(), keys, delta)
    end,
    
    on_repeat_sync = function(keys, target_reps)
      self.controller:sync_repeats(State.get_active_playlist_id(), keys, target_reps)
    end,
    
    on_pool_double_click = function(rid)
      local success, key = self.controller:add_item(State.get_active_playlist_id(), rid)
      if success and key then
        State.add_pending_spawn(key)
        State.add_pending_select(key)
      end
    end,
    
    on_pool_playlist_double_click = function(playlist_id)
      local active_playlist_id = State.get_active_playlist_id()
      
      if State.detect_circular_reference then
        local circular, path = State.detect_circular_reference(active_playlist_id, playlist_id)
        if circular then
          local path_str = table.concat(path, " → ")
          reaper.ShowConsoleMsg(string.format("Circular reference detected: %s\n", path_str))
          reaper.MB("Cannot add playlist: circular reference detected.\n\nPath: " .. path_str, "Circular Reference", 0)
          return
        end
      end
      
      local success, key = self.controller:add_playlist_item(State.get_active_playlist_id(), playlist_id)
      if success and key then
        State.add_pending_spawn(key)
        State.add_pending_select(key)
      end
    end,
    
    settings = settings,
  })
  
  self.region_tiles:set_pool_search_text(State.get_search_filter())
  self.region_tiles:set_pool_sort_mode(State.get_sort_mode())
  self.region_tiles:set_pool_sort_direction(State.get_sort_direction())
  self.region_tiles:set_app_bridge(State.get_bridge())
  self.region_tiles:set_pool_mode(State.get_pool_mode())
  
  State.active_search_filter = ""

  -- Initialize viewmode button in config (needs state module reference)
  Config.set_viewmode_button(State)

  self.transport_view = TransportView.new(Config.TRANSPORT, State)
  self.transport_view.config.quantize_lookahead = self.quantize_lookahead
  -- Pass settings to transport_view for persistence
  State.settings = settings
  
  self.layout_view = LayoutView.new(Config, State)
  
  self.overflow_modal_view = OverflowModalView.new(self.region_tiles, State, function()
    self:refresh_tabs()
  end)
  
  return self
end

function GUI:refresh_tabs()
  self.region_tiles:set_tabs(self.State.get_tabs(), self.State.get_active_playlist_id())
end

function GUI:update_state(ctx, window)
  if self.overflow_modal_view:should_show() then
    self.overflow_modal_view:draw(ctx, window)
  end

  self.State.get_bridge():update()
  self.State.update()

  -- Sync layout_mode from State to region_tiles when it changes
  local current_layout_mode = self.State.get_layout_mode()
  if current_layout_mode ~= self.region_tiles.layout_mode then
    self.region_tiles:set_layout_mode(current_layout_mode)
  end

  local pending_spawn = self.State.get_pending_spawn()
  local pending_select = self.State.get_pending_select()
  local pending_destroy = self.State.get_pending_destroy()
  
  local has_pending = false
  
  if #pending_spawn > 0 then
    self.region_tiles.active_grid:mark_spawned(pending_spawn)
    has_pending = true
  end
  
  if #pending_select > 0 then
    if self.region_tiles.pool_grid and self.region_tiles.pool_grid.selection then
      self.region_tiles.pool_grid.selection:clear()
    end
    if self.region_tiles.active_grid and self.region_tiles.active_grid.selection then
      self.region_tiles.active_grid.selection:clear()
    end
    
    for _, key in ipairs(pending_select) do
      if self.region_tiles.active_grid.selection then
        self.region_tiles.active_grid.selection.selected[key] = true
      end
    end
    
    if self.region_tiles.active_grid.selection then
      self.region_tiles.active_grid.selection.last_clicked = pending_select[#pending_select]
    end
    
    if self.region_tiles.active_grid.behaviors and self.region_tiles.active_grid.behaviors.on_select and self.region_tiles.active_grid.selection then
      self.region_tiles.active_grid.behaviors.on_select(self.region_tiles.active_grid, self.region_tiles.active_grid.selection:selected_keys())
    end
    has_pending = true
  end
  
  if #pending_destroy > 0 then
    self.region_tiles.active_grid:mark_destroyed(pending_destroy)
    has_pending = true
  end
  
  if has_pending then
    self.State.clear_pending()
  end
  
  self.region_tiles:update_animations(0.016)
  
  Shortcuts.handle_keyboard_shortcuts(ctx, self.State, self.region_tiles)
end

function GUI:draw(ctx, window, shell_state)
  self.shell_state = shell_state

  self:update_state(ctx, window)

  -- Get cursor position BEFORE drawing transport
  local transport_start_x, transport_start_y = ImGui.GetCursorScreenPos(ctx)

  local is_blocking = self.region_tiles:is_modal_blocking(ctx)
  self.transport_view:draw(ctx, shell_state, is_blocking)

  -- Position cursor after transport with separator gap
  local sep_gap = self.Config.SEPARATOR.horizontal.gap
  local transport_height = self.Config.TRANSPORT.height
  ImGui.SetCursorScreenPos(ctx, transport_start_x, transport_start_y + transport_height + sep_gap)

  self.layout_view:draw(ctx, self.region_tiles, shell_state)

  self.region_tiles:draw_ghosts(ctx)
end

return M
