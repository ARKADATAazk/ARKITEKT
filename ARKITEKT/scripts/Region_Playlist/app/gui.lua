-- @noindex
-- Region_Playlist/app/gui.lua

local RegionTiles = require('Region_Playlist.widgets.region_tiles.coordinator')
local PlaylistController = require('Region_Playlist.app.controller')
local Config = require('Region_Playlist.app.config')
local StateStore = require('Region_Playlist.core.state')

local M = {}
local GUI = {}
GUI.__index = GUI

local function S()
  return StateStore.for_project(0)
end

local function get_active_playlist_id(State)
  local active_id = S():get('playlists.active_id')
  if active_id ~= nil then
    return active_id
  end

  local playlist = State.get_active_playlist and State.get_active_playlist()
  return playlist and playlist.id or nil
end

local function set_active_playlist_id(State, playlist_id)
  if not playlist_id then return end
  S():set('playlists.active_id', playlist_id)
  if State.set_active_playlist then
    State.set_active_playlist(playlist_id)
  end
end

function M.create(State, AppConfig, settings)
  local self = setmetatable({
    State = State,
    Config = Config,
    settings = settings,
    controller = nil,
    region_tiles = nil,
    main_view = nil,
  }, GUI)

  self.controller = PlaylistController.new(State, settings, State.state.undo_manager)

  if State.state.bridge and State.state.bridge.set_controller then
    State.state.bridge:set_controller(self.controller)
  end
  if State.state.bridge and State.state.bridge.set_playlist_lookup then
    State.state.bridge:set_playlist_lookup(State.get_playlist_by_id)
  end

  if not State.state.separator_position_horizontal then
    State.state.separator_position_horizontal = Config.SEPARATOR.horizontal.default_position
  end
  if not State.state.separator_position_vertical then
    State.state.separator_position_vertical = Config.SEPARATOR.vertical.default_position
  end

  self.region_tiles = RegionTiles.create({
    controller = self.controller,

    get_region_by_rid = function(rid)
      return State.state.region_index[rid]
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
    active_tab_id = get_active_playlist_id(State),
    pool_mode = State.state.pool_mode,
    config = AppConfig.get_region_tiles_config(State.state.layout_mode),

    on_playlist_changed = function(new_id)
      set_active_playlist_id(State, new_id)
    end,

    on_pool_search = function(text)
      State.state.search_filter = text
      State.persist_ui_prefs()
    end,

    on_pool_sort = function(mode)
      State.state.sort_mode = mode
      State.persist_ui_prefs()
    end,

    on_pool_sort_direction = function(direction)
      State.state.sort_direction = direction
      State.persist_ui_prefs()
    end,

    on_pool_mode_changed = function(mode)
      State.state.pool_mode = mode
      self.region_tiles:set_pool_mode(mode)
      State.persist_ui_prefs()
    end,

    on_active_reorder = function(new_order)
      self.controller:reorder_items(get_active_playlist_id(State), new_order)
    end,

    on_active_remove = function(item_key)
      self.controller:delete_items(get_active_playlist_id(State), { item_key })
    end,

    on_active_toggle_enabled = function(item_key, new_state)
      self.controller:toggle_item_enabled(get_active_playlist_id(State), item_key, new_state)
    end,

    on_active_delete = function(item_keys)
      self.controller:delete_items(get_active_playlist_id(State), item_keys)
      for _, key in ipairs(item_keys) do
        State.state.pending_destroy[#State.state.pending_destroy + 1] = key
      end
    end,

    on_destroy_complete = function(_)
    end,

    on_active_copy = function(dragged_items, target_index)
      local success, keys = self.controller:copy_items(get_active_playlist_id(State), dragged_items, target_index)
      if success and keys then
        for _, key in ipairs(keys) do
          State.state.pending_spawn[#State.state.pending_spawn + 1] = key
          State.state.pending_select[#State.state.pending_select + 1] = key
        end
      end
    end,

    on_pool_to_active = function(rid, insert_index)
      local success, key = self.controller:add_item(get_active_playlist_id(State), rid, insert_index)
      return success and key or nil
    end,

    on_pool_playlist_to_active = function(playlist_id, insert_index)
      local success, key = self.controller:add_playlist_item(get_active_playlist_id(State), playlist_id, insert_index)
      return success and key or nil
    end,

    on_pool_reorder = function(new_rids)
      State.state.pool_order = new_rids
      State.persist_ui_prefs()
    end,

    on_repeat_cycle = function(item_key)
      self.controller:cycle_repeats(get_active_playlist_id(State), item_key)
    end,

    on_repeat_adjust = function(keys, delta)
      self.controller:adjust_repeats(get_active_playlist_id(State), keys, delta)
    end,

    on_repeat_sync = function(keys, target_reps)
      self.controller:sync_repeats(get_active_playlist_id(State), keys, target_reps)
    end,

    on_pool_double_click = function(rid)
      local success, key = self.controller:add_item(get_active_playlist_id(State), rid)
      if success and key then
        State.state.pending_spawn[#State.state.pending_spawn + 1] = key
        State.state.pending_select[#State.state.pending_select + 1] = key
      end
    end,

    on_pool_playlist_double_click = function(playlist_id)
      local active_playlist_id = get_active_playlist_id(State)

      if State.detect_circular_reference then
        local circular, path = State.detect_circular_reference(active_playlist_id, playlist_id)
        if circular then
          local path_str = table.concat(path, ' → ')
          reaper.ShowConsoleMsg(string.format('Circular reference detected: %s\n', path_str))
          reaper.MB('Cannot add playlist: circular reference detected.\n\nPath: ' .. path_str, 'Circular Reference', 0)
          return
        end
      end

      local success, key = self.controller:add_playlist_item(get_active_playlist_id(State), playlist_id)
      if success and key then
        State.state.pending_spawn[#State.state.pending_spawn + 1] = key
        State.state.pending_select[#State.state.pending_select + 1] = key
      end
    end,

    settings = settings,
  })

  self.region_tiles:set_pool_search_text(State.state.search_filter)
  self.region_tiles:set_pool_sort_mode(State.state.sort_mode)
  self.region_tiles:set_pool_sort_direction(State.state.sort_direction)
  self.region_tiles:set_app_bridge(State.state.bridge)
  self.region_tiles:set_pool_mode(State.state.pool_mode)

  State.state.active_search_filter = State.state.active_search_filter or ''

  return self
end

function GUI:refresh_tabs()
  if self.region_tiles then
    self.region_tiles:set_tabs(self.State.get_tabs(), get_active_playlist_id(self.State))
  end
end

function GUI:set_main_view(main_view)
  self.main_view = main_view
end

function GUI:draw(ctx, window)
  if self.main_view then
    return self.main_view:draw(ctx, window)
  end
end

return M
