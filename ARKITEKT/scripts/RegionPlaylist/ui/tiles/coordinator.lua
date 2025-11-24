-- @noindex
-- RegionPlaylist/ui/tiles/coordinator.lua

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local Config = require('RegionPlaylist.core.config')
local Render = require('RegionPlaylist.ui.tiles.coordinator_render')
local Draw = require('arkitekt.gui.draw')
local Colors = require('arkitekt.core.colors')
local TileAnim = require('arkitekt.gui.rendering.tile.animator')
local HeightStabilizer = require('arkitekt.gui.systems.height_stabilizer')
local Selector = require('RegionPlaylist.ui.tiles.selector')
local ActiveGridFactory = require('RegionPlaylist.ui.tiles.active_grid_factory')
local PoolGridFactory = require('RegionPlaylist.ui.tiles.pool_grid_factory')
local GridBridge = require('arkitekt.gui.widgets.containers.grid.grid_bridge')
local TilesContainer = require('arkitekt.gui.widgets.containers.panel')
local PanelConfig = require('arkitekt.gui.widgets.containers.panel.defaults')
local State = require("RegionPlaylist.core.app_state")

local M = {}

local RegionTiles = {}
RegionTiles.__index = RegionTiles

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

function M.create(opts)
  opts = opts or {}

  local config = opts.config or {}

  -- Wrap get_playlist_by_id with caching
  local raw_get_playlist = opts.get_playlist_by_id
  local cached_get_playlist = function(id)
    return cached_get_playlist_by_id(raw_get_playlist, id)
  end

  -- Start with all opts (auto-inherit callbacks and options)
  local rt = setmetatable({}, RegionTiles)
  for k, v in pairs(opts) do
    rt[k] = v
  end

  -- Override specific fields that need special handling
  rt.get_playlist_by_id = cached_get_playlist
  rt.config = config
  rt.allow_pool_reorder = opts.allow_pool_reorder ~= false

  -- Unpack config for convenience
  rt.layout_mode = config.layout_mode
  rt.hover_config = config.hover_config
  rt.responsive_config = config.responsive_config
  rt.container_config = config.container
  rt.wheel_config = config.wheel_config

  -- Initialize internal state
  rt.selector = Selector.new()
  rt.active_animator = TileAnim.new(config.hover_config.animation_speed_hover)
  rt.pool_animator = TileAnim.new(config.hover_config.animation_speed_hover)

  rt.active_bounds = nil
  rt.pool_bounds = nil
  rt.active_grid = nil
  rt.pool_grid = nil
  rt.bridge = nil
  rt.app_bridge = nil
  rt.wheel_consumed_this_frame = false

  rt.active_height_stabilizer = HeightStabilizer.new({
    stable_frames_required = config.responsive_config.stable_frames_required,
    height_hysteresis = config.responsive_config.height_hysteresis,
  })
  rt.pool_height_stabilizer = HeightStabilizer.new({
    stable_frames_required = config.responsive_config.stable_frames_required,
    height_hysteresis = config.responsive_config.height_hysteresis,
  })

  rt.current_active_tile_height = config.responsive_config.base_tile_height_active
  rt.current_pool_tile_height = config.responsive_config.base_tile_height_pool

  rt._original_active_min_col_w = nil
  rt._imgui_ctx = nil

  -- Create grids after rt is fully initialized
  rt.active_grid = ActiveGridFactory.create(rt, config)
  rt._original_active_min_col_w = rt.active_grid.min_col_w_fn

  rt.pool_grid = PoolGridFactory.create(rt, config)

  -- Helper: wrap controller action with auto-refresh on success
  local function controller_action(action_fn)
    return function(...)
      if not rt.controller then return end
      local success, err = action_fn(rt.controller, ...)
      if success then
        rt.active_container:set_tabs(State.get_tabs(), State.get_active_playlist_id())
      elseif err then
        reaper.ShowConsoleMsg("[RegionPlaylist] Error: " .. tostring(err) .. "\n")
      end
      return success, err
    end
  end

  local active_config = Config.get_active_container_config({
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
  
  rt.active_container = TilesContainer.new({
    id = "active_tiles_container",
    config = active_config,
  })

  rt.active_container:set_tabs(opts.tabs or {}, opts.active_tab_id)
  
  -- >>> POOL MODE STATE (BEGIN)
  -- State-first pattern: Define state before callbacks
  local pool_mode_state = {
    current_mode = opts.pool_mode or "regions",
    previous_mode = "regions"
  }
  -- <<< POOL MODE STATE (END)
  
  local pool_config = Config.get_pool_container_config({
    on_mode_toggle = function()
      -- Left-click: toggle between regions and playlists
      local new_mode
      if pool_mode_state.current_mode == "regions" then
        new_mode = "playlists"
      elseif pool_mode_state.current_mode == "playlists" then
        new_mode = "regions"
      else
        -- If in mixed, go to previous mode
        new_mode = pool_mode_state.previous_mode
      end
      
      -- Update previous mode if we're not in mixed
      if new_mode ~= "mixed" then
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
      if pool_mode_state.current_mode == "mixed" then
        -- Exit mixed mode, restore previous mode
        new_mode = pool_mode_state.previous_mode
      else
        -- Enter mixed mode, save current mode
        pool_mode_state.previous_mode = pool_mode_state.current_mode
        new_mode = "mixed"
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
  
  rt.pool_container = TilesContainer.new({
    id = "pool_tiles_container",
    config = pool_config,
  })
  
  rt.pool_container.current_mode = opts.pool_mode or "regions"
  
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
          
          if type(item_data) == "number" then
            if rt.on_pool_to_active then
              new_key = rt.on_pool_to_active(item_data, insert_index)
            end
          elseif type(item_data) == "table" and item_data.type == "playlist" then
            local active_playlist_id = rt.active_container:get_active_tab_id()
            
            if rt.detect_circular_ref then
              local circular, path = rt.detect_circular_ref(active_playlist_id, item_data.id)
              if circular then
                -- Set error in status bar and skip
                if rt.State and rt.State.set_circular_dependency_error then
                  rt.State.set_circular_dependency_error("Cannot add playlist - would create circular dependency")
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
              if type(item_data) == "number" then
                region_count = region_count + 1
              elseif type(item_data) == "table" and item_data.type == "playlist" then
                playlist_count = playlist_count + 1
              end
            end

            local parts = {}
            if region_count > 0 then
              table.insert(parts, string.format("%d region%s", region_count, region_count > 1 and "s" or ""))
            end
            if playlist_count > 0 then
              table.insert(parts, string.format("%d playlist%s", playlist_count, playlist_count > 1 and "s" or ""))
            end

            if #parts > 0 then
              local items_text = table.concat(parts, ", ")
              local active_playlist = rt.State.get_active_playlist and rt.State.get_active_playlist()
              local playlist_name = active_playlist and active_playlist.name or "Active Grid"
              rt.State.set_state_change_notification(string.format("Copied %s from Pool Grid to Active Grid (%s)", items_text, playlist_name))
            end
          end

          if rt.pool_grid and rt.pool_grid.selection then
            rt.pool_grid.selection:clear()
          end
          if rt.active_grid and rt.active_grid.selection then
            rt.active_grid.selection:clear()
          end
          
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
    end,
    
    on_drag_canceled = function(cancel_info)
      if cancel_info.source_grid == 'active' and rt.active_grid and rt.active_grid.behaviors and rt.active_grid.behaviors.delete then
        rt.active_grid.behaviors.delete(rt.active_grid, cancel_info.payload or {})
      end
    end,
  })
  
  rt.bridge:register_grid('active', rt.active_grid, {
    accepts_drops_from = {'pool'},
    on_drag_start = function(item_keys)
      rt.bridge:start_drag('active', item_keys)
    end,
  })
  
  rt.bridge:register_grid('pool', rt.pool_grid, {
    accepts_drops_from = {},
    on_drag_start = function(item_keys)
      local payload = {}
      
      -- Handle both regions and playlists by checking key pattern
      for _, key in ipairs(item_keys) do
        local playlist_id = key:match("pool_playlist_(.+)")
        if playlist_id and rt.get_playlist_by_id then
          -- It's a playlist
          local playlist = rt.get_playlist_by_id(playlist_id)
          if playlist then
            payload[#payload + 1] = {
              type = "playlist",
              id = playlist.id,
              name = playlist.name,
              chip_color = playlist.chip_color,
              item_count = #playlist.items,
            }
          end
        else
          -- It's a region
          local rid = tonumber(key:match("pool_(%d+)"))
          if rid then
            payload[#payload + 1] = rid
          end
        end
      end
      
      rt.bridge:start_drag('pool', payload)
    end,
  })
  
  rt:set_layout_mode(rt.layout_mode)
  
  return rt
end

function RegionTiles:set_layout_mode(mode)
  self.layout_mode = mode
  if mode == 'vertical' then
    self.active_grid.min_col_w_fn = function() return 9999 end
  else
    self.active_grid.min_col_w_fn = self._original_active_min_col_w
  end
end

function RegionTiles:set_app_bridge(bridge)
  self.app_bridge = bridge
end

function RegionTiles:set_pool_mode(mode)
  if self.pool_container then
    self.pool_container.current_mode = mode
  end
end

function RegionTiles:_find_hovered_tile(ctx, items)
  local mx, my = ImGui.GetMousePos(ctx)
  
  for _, item in ipairs(items) do
    local key = item.key
    local rect = self.active_grid.rect_track:get(key)
    if rect then
      if mx >= rect[1] and mx < rect[3] and my >= rect[2] and my < rect[4] then
        local is_selected = self.active_grid.selection:is_selected(key)
        return item, key, is_selected
      end
    end
  end
  
  return nil, nil, false
end

function RegionTiles:is_mouse_over_active_tile(ctx, playlist)
  if not self.active_bounds then return false end
  
  local mx, my = ImGui.GetMousePos(ctx)
  
  if not (mx >= self.active_bounds[1] and mx < self.active_bounds[3] and
          my >= self.active_bounds[2] and my < self.active_bounds[4]) then
    return false
  end
  
  local item, key, _ = self:_find_hovered_tile(ctx, playlist.items)
  return item ~= nil and key ~= nil
end

function RegionTiles:should_consume_wheel(ctx, playlist)
  self.wheel_consumed_this_frame = false
  
  if not self.on_repeat_adjust then return false end
  
  local wheel_y = ImGui.GetMouseWheel(ctx)
  if wheel_y == 0 then return false end
  
  return self:is_mouse_over_active_tile(ctx, playlist)
end

function RegionTiles:_get_drag_colors()
  local colors = {}
  
  if not self.bridge:is_drag_active() then return nil end
  
  local source = self.bridge:get_source_grid()
  local payload = self.bridge:get_drag_payload()
  
  if source == 'active' then
    local data = payload and payload.data or {}
    if type(data) == 'table' then
      local playlist_items = self.active_grid.get_items()
      for _, key in ipairs(data) do
        for _, item in ipairs(playlist_items) do
          if item.key == key then
            if item.type == "playlist" then
              if self.get_playlist_by_id then
                local playlist = self.get_playlist_by_id(item.playlist_id)
                if playlist and playlist.chip_color then
                  colors[#colors + 1] = playlist.chip_color
                end
              end
            else
              local region = self.get_region_by_rid(item.rid)
              if region and region.color then
                colors[#colors + 1] = region.color
              end
            end
            break
          end
        end
      end
    end
  elseif source == 'pool' then
    local data = payload and payload.data or {}
    if type(data) == 'table' then
      for _, item in ipairs(data) do
        if type(item) == "number" then
          local region = self.get_region_by_rid(item)
          if region and region.color then
            colors[#colors + 1] = region.color
          end
        elseif type(item) == "table" and item.type == "playlist" then
          if item.chip_color then
            colors[#colors + 1] = item.chip_color
          end
        end
      end
    end
  end
  
  return #colors > 0 and colors or nil
end

function RegionTiles:update_animations(dt)
  self.selector:update(dt)
  self.active_animator:update(dt)
  self.pool_animator:update(dt)
end

function RegionTiles:set_tabs(tabs, active_id)
  if self.active_container then
    self.active_container:set_tabs(tabs, active_id)
  end
end

function RegionTiles:get_active_tab_id()
  if self.active_container then
    return self.active_container:get_active_tab_id()
  end
  return nil
end

function RegionTiles:get_pool_search_text()
  return self.pool_container:get_search_text()
end

function RegionTiles:set_pool_search_text(text)
  self.pool_container:set_search_text(text)
end

function RegionTiles:get_pool_sort_mode()
  return self.pool_container:get_sort_mode()
end

function RegionTiles:set_pool_sort_mode(mode)
  self.pool_container:set_sort_mode(mode)
end

function RegionTiles:get_pool_sort_direction()
  return self.pool_container:get_sort_direction()
end

function RegionTiles:set_pool_sort_direction(direction)
  self.pool_container:set_sort_direction(direction)
end

function RegionTiles:is_modal_blocking(ctx)
  -- Check if custom overlay modal is open (overflow tabs picker)
  local overflow_active = self.active_container and self.active_container:is_overflow_visible()
  if overflow_active then return true end

  -- Check if any ImGui popup is open (context menus, etc)
  if ctx then
    return ImGui.IsPopupOpen(ctx, '', ImGui.PopupFlags_AnyPopupId)
  end

  return false
end

function RegionTiles:draw_selector(ctx, playlists, active_id, height)
  return Render.draw_selector(self, ctx, playlists, active_id, height)
end

function RegionTiles:draw_active(ctx, playlist, height, shell_state)
  if self.active_container and self.active_container.visible_bounds then
    self.active_grid.panel_clip_bounds = self.active_container.visible_bounds
  end

  -- Inject modal blocking state and icon font into corner buttons
  local is_blocking = self:is_modal_blocking(ctx)
  local icons_font = shell_state and shell_state.fonts and shell_state.fonts.icons
  local icons_size = shell_state and shell_state.fonts and shell_state.fonts.icons_size
  if self.active_container and self.active_container.config and self.active_container.config.corner_buttons then
    local cb = self.active_container.config.corner_buttons
    if cb.top_right then
      cb.top_right.icon_font = icons_font
      cb.top_right.icon_font_size = icons_size
      cb.top_right.is_blocking = is_blocking
    end
    if cb.top_left then
      cb.top_left.icon_font = icons_font
      cb.top_left.icon_font_size = icons_size
      cb.top_left.is_blocking = is_blocking
    end
    if cb.bottom_right then
      cb.bottom_right.icon_font = icons_font
      cb.bottom_right.icon_font_size = icons_size
      cb.bottom_right.is_blocking = is_blocking
    end
    if cb.bottom_left then
      cb.bottom_left.icon_font = icons_font
      cb.bottom_left.icon_font_size = icons_size
      cb.bottom_left.is_blocking = is_blocking
    end
  end

  -- Inject icon font into tab_strip config for color picker
  if icons_font and self.active_container and self.active_container.config and self.active_container.config.header then
    local header = self.active_container.config.header
    if header.elements then
      for _, element in ipairs(header.elements) do
        if element.type == "tab_strip" and element.config then
          element.config.icon_font = icons_font
          element.config.icon_font_size = icons_size or 12
        end
      end
    end
  end

  return Render.draw_active(self, ctx, playlist, height, shell_state)
end

function RegionTiles:draw_pool(ctx, regions, height, shell_state)
  if self.pool_container and self.pool_container.visible_bounds then
    self.pool_grid.panel_clip_bounds = self.pool_container.visible_bounds
  end

  -- Inject modal blocking state into corner buttons
  local is_blocking = self:is_modal_blocking(ctx)
  if self.pool_container and self.pool_container.config and self.pool_container.config.corner_buttons then
    local cb = self.pool_container.config.corner_buttons
    if cb.bottom_left then
      cb.bottom_left.is_blocking = is_blocking
    end
  end

  -- Inject icon font and size into corner buttons
  local icons_font = shell_state and shell_state.fonts and shell_state.fonts.icons
  local icons_size = shell_state and shell_state.fonts and shell_state.fonts.icons_size
  if icons_font and self.pool_container and self.pool_container.config and self.pool_container.config.corner_buttons then
    local cb = self.pool_container.config.corner_buttons
    if cb.top_right then
      cb.top_right.icon_font = icons_font
      cb.top_right.icon_font_size = icons_size
    end
    if cb.top_left then
      cb.top_left.icon_font = icons_font
      cb.top_left.icon_font_size = icons_size
    end
    if cb.bottom_right then
      cb.bottom_right.icon_font = icons_font
      cb.bottom_right.icon_font_size = icons_size
    end
    if cb.bottom_left then
      cb.bottom_left.icon_font = icons_font
      cb.bottom_left.icon_font_size = icons_size
    end
  end

  return Render.draw_pool(self, ctx, regions, height)
end

function RegionTiles:draw_ghosts(ctx)
  return Render.draw_ghosts(self, ctx)
end

return M