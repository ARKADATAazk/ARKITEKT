-- @noindex
-- RegionPlaylist/ui/tiles/coordinator_factory.lua

local ImGui = require('arkitekt.core.imgui')
local Ark = require('arkitekt')

local ConfigFactory = require('RegionPlaylist.app.config_factory')
local TileAnim = require('arkitekt.gui.animation.tile_animator')
local HeightStabilizer = require('arkitekt.gui.layout.height_stabilizer')
local Selector = require('RegionPlaylist.ui.tiles.selector')
local GridBridge = require('arkitekt.gui.widgets.containers.grid.grid_bridge')
local ActiveTile = require('RegionPlaylist.ui.tiles.renderers.active')
local State = require('RegionPlaylist.app.state')
local Logger = require('arkitekt.debug.logger')

local M = {}

-- =============================================================================
-- PER-FRAME CACHING
-- =============================================================================
-- Caches playlist lookups per frame to avoid redundant queries when multiple
-- tiles reference the same playlist (nested playlists).
--
-- Pattern: Cache cleared on frame boundary (via reaper.time_precise())

local playlist_cache = {}
local cache_frame_time = 0

local function cached_get_playlist_by_id(get_fn, playlist_id)
  local current_time = reaper.time_precise()

  if current_time ~= cache_frame_time then
    playlist_cache = {}
    cache_frame_time = current_time
  end

  if not playlist_cache[playlist_id] then
    playlist_cache[playlist_id] = get_fn(playlist_id)
  end

  return playlist_cache[playlist_id]
end

-- =============================================================================
-- CONSTRUCTOR
-- =============================================================================
-- Creates coordinator instance with grid instances, animators, and state.
--
-- Responsibilities:
--   - Create active and pool grid configurations (via factories)
--   - Initialize animators (hover effects)
--   - Initialize height stabilizers (prevent jitter)
--   - Register grids with bridge (drag-drop coordination)
--   - Wire callbacks from opts
--
-- Pattern: Constructor function that returns stateful coordinator instance

function M.new(Coordinator, opts)
  opts = opts or {}

  local cfg = opts.config or {}

  -- Wrap get_playlist_by_id with caching
  local raw_get_playlist = opts.get_playlist_by_id
  local cached_get_playlist = function(id)
    return cached_get_playlist_by_id(raw_get_playlist, id)
  end

  -- Start with all opts (auto-inherit callbacks and options)
  local rt = setmetatable({}, Coordinator)
  for k, v in pairs(opts) do
    rt[k] = v
  end

  -- Override specific fields that need special handling
  rt.get_playlist_by_id = cached_get_playlist
  rt.config = cfg
  rt.allow_pool_reorder = opts.allow_pool_reorder ~= false

  -- Unpack config for convenience
  rt.layout_mode = cfg.layout_mode
  rt.hover_config = cfg.hover_config
  rt.responsive_config = cfg.responsive_config
  rt.container_config = cfg.container
  rt.wheel_config = cfg.wheel_config

  -- Initialize internal state
  rt.selector = Selector.new()
  rt.active_animator = TileAnim.new(cfg.hover_config.animation_speed_hover)
  rt.pool_animator = TileAnim.new(cfg.hover_config.animation_speed_hover)

  rt.active_bounds = nil
  rt.pool_bounds = nil
  rt.active_grid = nil  -- Set by Ark.Grid() result
  rt.pool_grid = nil    -- Set by Ark.Grid() result
  rt.bridge = nil
  rt.app_bridge = nil
  rt.wheel_consumed_this_frame = false

  rt.active_height_stabilizer = HeightStabilizer.new({
    stable_frames_required = cfg.responsive_config.stable_frames_required,
    height_hysteresis = cfg.responsive_config.height_hysteresis,
  })
  rt.pool_height_stabilizer = HeightStabilizer.new({
    stable_frames_required = cfg.responsive_config.stable_frames_required,
    height_hysteresis = cfg.responsive_config.height_hysteresis,
  })

  rt.current_active_tile_height = cfg.responsive_config.base_tile_height_active
  rt.current_pool_tile_height = cfg.responsive_config.base_tile_height_pool

  -- Default min col width function (can be overridden by layout mode)
  rt._active_min_col_w_fn = function() return ActiveTile.CONFIG.tile_width end
  rt._imgui_ctx = nil

  -- Per-frame state for opts-based grids (set before Ark.Grid calls)
  rt._active_items = {}
  rt._active_tile_height = cfg.responsive_config.base_tile_height_active
  rt._active_clip_bounds = nil
  rt._pool_items = {}
  rt._pool_tile_height = cfg.responsive_config.base_tile_height_pool
  rt._pool_gap = nil
  rt._pool_clip_bounds = nil
  rt._pool_disable_background_clicks = false

  -- Helper: wrap controller action with auto-refresh on success
  local function controller_action(action_fn)
    return function(...)
      if not rt.controller then return end
      local success, err = action_fn(rt.controller, ...)
      if success then
        rt.active_container:set_tabs(State.get_tabs(), State.get_active_playlist_id())
      elseif err then
        Logger.error('COORDINATOR', 'Error: %s', tostring(err))
      end
      return success, err
    end
  end

  local active_config = ConfigFactory.get_active_container_config({
    on_tab_create = controller_action(function(ctrl)
      return ctrl:create_playlist()
    end),

    on_tab_change = function(id)
      State.set_active_playlist(id)
      rt.active_container:set_active_tab_id(id)
    end,

    on_tab_reorder = controller_action(function(ctrl, source_index, target_index)
      return ctrl:reorder_playlists(source_index, target_index)
    end),

    on_tab_delete = controller_action(function(ctrl, id)
      return ctrl:delete_playlist(id)
    end),

    on_tab_rename = controller_action(function(ctrl, id, new_name)
      ctrl:rename_playlist(id, new_name)
      rt.active_container:set_tabs(State.get_tabs(), State.get_active_playlist_id())
    end),

    on_tab_duplicate = controller_action(function(ctrl, id)
      return ctrl:duplicate_playlist(id)
    end),

    on_tab_color_change = controller_action(function(ctrl, id, color)
      return ctrl:set_playlist_color(id, color == false and nil or color)
    end),

    on_overflow_clicked = function()
      rt.active_container._overflow_visible = true
    end,

    on_actions_button_click = function()
      rt._actions_menu_visible = true
    end,
  })

  rt.active_container = Ark.Panel.new({
    id = 'active_tiles_container',
    config = active_config,
  })

  rt.active_container:set_tabs(opts.tabs or {}, opts.active_tab_id)

  -- >>> POOL MODE STATE (BEGIN)
  -- State-first pattern: Define state before callbacks
  local pool_mode_state = {
    current_mode = opts.pool_mode or 'regions',
    previous_mode = 'regions'
  }
  -- <<< POOL MODE STATE (END)

  local pool_config = ConfigFactory.get_pool_container_config({
    on_mode_toggle = function()
      -- Left-click: toggle between regions and playlists
      local new_mode
      if pool_mode_state.current_mode == 'regions' then
        new_mode = 'playlists'
      elseif pool_mode_state.current_mode == 'playlists' then
        new_mode = 'regions'
      else
        -- If in mixed, go to previous mode
        new_mode = pool_mode_state.previous_mode
      end

      -- Update previous mode if we're not in mixed
      if new_mode ~= 'mixed' then
        pool_mode_state.previous_mode = new_mode
      end

      pool_mode_state.current_mode = new_mode
      rt.pool_container.current_mode = new_mode
      if rt.on_pool_mode_changed then
        rt.on_pool_mode_changed(new_mode)
      end
    end,

    on_mode_toggle_right = function()
      -- Right-click: toggle mixed mode on/off
      local new_mode
      if pool_mode_state.current_mode == 'mixed' then
        -- Exit mixed mode, restore previous mode
        new_mode = pool_mode_state.previous_mode
      else
        -- Enter mixed mode, save current mode
        pool_mode_state.previous_mode = pool_mode_state.current_mode
        new_mode = 'mixed'
      end
      pool_mode_state.current_mode = new_mode
      rt.pool_container.current_mode = new_mode
      if rt.on_pool_mode_changed then
        rt.on_pool_mode_changed(new_mode)
      end
    end,

    on_search_changed = function(text)
      if rt.on_pool_search then
        rt.on_pool_search(text)
      end
    end,

    on_sort_changed = function(mode)
      if rt.on_pool_sort then
        rt.on_pool_sort(mode)
      end
    end,

    on_sort_direction_changed = function(direction)
      if rt.on_pool_sort_direction then
        rt.on_pool_sort_direction(direction)
      end
    end,

    on_actions_click = function()
      rt._pool_actions_menu_visible = true
    end,
  })

  rt.pool_container = Ark.Panel.new({
    id = 'pool_tiles_container',
    config = pool_config,
  })

  rt.pool_container.current_mode = opts.pool_mode or 'regions'

  rt.bridge = GridBridge.new({
    copy_mode_detector = function(source, target, payload)
      if source == 'pool' and target == 'active' then
        return true
      end

      if source == 'active' and target == 'active' then
        if rt._imgui_ctx then
          local ctrl = ImGui.IsKeyDown(rt._imgui_ctx, ImGui.Key_LeftCtrl) or
                      ImGui.IsKeyDown(rt._imgui_ctx, ImGui.Key_RightCtrl)
          return ctrl
        end
      end

      return false
    end,

    delete_mode_detector = function(ctx, source, target, payload)
      if source == 'active' and target ~= 'active' then
        return not rt.bridge:is_mouse_over_grid(ctx, 'active')
      end
      return false
    end,

    on_cross_grid_drop = function(drop_info)
      if drop_info.source_grid == 'pool' and drop_info.target_grid == 'active' then
        local spawned_keys = {}
        local insert_index = drop_info.insert_index

        for _, item_data in ipairs(drop_info.payload) do
          local new_key = nil

          if type(item_data) == 'number' then
            if rt.on_pool_to_active then
              new_key = rt.on_pool_to_active(item_data, insert_index)
            end
          elseif type(item_data) == 'table' and item_data.type == 'playlist' then
            local active_playlist_id = rt.active_container:get_active_tab_id()

            if rt.detect_circular_ref then
              local circular, path = rt.detect_circular_ref(active_playlist_id, item_data.id)
              if circular then
                -- Set error in status bar and skip
                if rt.State and rt.State.set_circular_dependency_error then
                  rt.State.set_circular_dependency_error('Cannot add playlist - would create circular dependency')
                end
                goto continue_loop
              end
            end

            if rt.on_pool_playlist_to_active then
              new_key = rt.on_pool_playlist_to_active(item_data.id, insert_index)
            end
          end

          if new_key then
            spawned_keys[#spawned_keys + 1] = new_key
          end

          insert_index = insert_index + 1

          ::continue_loop::
        end

        if #spawned_keys > 0 then
          -- Clear any circular dependency errors on successful operation
          if rt.State and rt.State.clear_circular_dependency_error then
            rt.State.clear_circular_dependency_error()
          end

          -- Show drag-and-drop notification
          if rt.State and rt.State.set_state_change_notification then
            local region_count = 0
            local playlist_count = 0

            for _, item_data in ipairs(drop_info.payload) do
              if type(item_data) == 'number' then
                region_count = region_count + 1
              elseif type(item_data) == 'table' and item_data.type == 'playlist' then
                playlist_count = playlist_count + 1
              end
            end

            local parts = {}
            if region_count > 0 then
              parts[#parts + 1] = string.format('%d region%s', region_count, region_count > 1 and 's' or '')
            end
            if playlist_count > 0 then
              parts[#parts + 1] = string.format('%d playlist%s', playlist_count, playlist_count > 1 and 's' or '')
            end

            if #parts > 0 then
              local items_text = table.concat(parts, ', ')
              local active_playlist = rt.State.get_active_playlist and rt.State.get_active_playlist()
              local playlist_name = active_playlist and active_playlist.name or 'Active Grid'
              rt.State.set_state_change_notification(string.format('Copied %s from Pool Grid to Active Grid (%s)', items_text, playlist_name))
            end
          end

          if rt.pool_grid and rt.pool_grid.selection then
            rt.pool_grid.selection:clear()
          end
          if rt.active_grid and rt.active_grid.selection then
            rt.active_grid.selection:clear()
          end

          if rt.active_grid then
            rt.active_grid:mark_spawned(spawned_keys)

            for _, key in ipairs(spawned_keys) do
              if rt.active_grid.selection then
                rt.active_grid.selection.selected[key] = true
              end
            end

            if rt.active_grid.selection then
              rt.active_grid.selection.last_clicked = spawned_keys[#spawned_keys]
            end

            if rt.active_grid.behaviors and rt.active_grid.behaviors.on_select and rt.active_grid.selection then
              rt.active_grid.behaviors.on_select(rt.active_grid, rt.active_grid.selection:selected_keys())
            end
          end
        end
      end
    end,

    on_drag_canceled = function(cancel_info)
      if cancel_info.source_grid == 'active' and rt.active_grid and rt.active_grid.behaviors and rt.active_grid.behaviors.delete then
        rt.active_grid.behaviors.delete(rt.active_grid, cancel_info.payload or {})
      end
    end,
  })

  -- Grid registration happens lazily when grids are first drawn
  -- Store registration config for later
  rt._active_grid_bridge_config = {
    accepts_drops_from = {'pool'},
    on_drag_start = function(item_keys)
      rt.bridge:start_drag('active', item_keys)
    end,
  }

  rt._pool_grid_bridge_config = {
    accepts_drops_from = {},
    on_drag_start = function(item_keys)
      local payload = {}

      -- Handle both regions and playlists by checking key pattern
      for _, key in ipairs(item_keys) do
        local playlist_id = key:match('pool_playlist_(.+)')
        if playlist_id and rt.get_playlist_by_id then
          -- It's a playlist
          local playlist = rt.get_playlist_by_id(playlist_id)
          if playlist then
            payload[#payload + 1] = {
              type = 'playlist',
              id = playlist.id,
              name = playlist.name,
              chip_color = playlist.chip_color,
              item_count = #playlist.items,
            }
          end
        else
          -- It's a region
          local rid = tonumber(key:match('pool_(%d+)'))
          if rid then
            payload[#payload + 1] = rid
          end
        end
      end

      rt.bridge:start_drag('pool', payload)
    end,
  }

  rt:set_layout_mode(rt.layout_mode)

  return rt
end

return M
