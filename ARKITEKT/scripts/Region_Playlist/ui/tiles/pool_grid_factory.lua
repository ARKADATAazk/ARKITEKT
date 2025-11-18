-- @noindex
-- Region_Playlist/ui/tiles/pool_grid_factory.lua
-- UNCHANGED

local Grid = require('rearkitekt.gui.widgets.containers.grid.core')
local PoolTile = require('Region_Playlist.ui.tiles.renderers.pool')
local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb


local M = {}

local function is_item_draggable(rt, key, item)
  if item.id and item.items then
    return not (item.is_disabled or false)
  end
  return true
end

local function create_behaviors(rt)
  return {
    drag_start = function(item_keys)
      if rt.bridge then
        return
      end
      
      local pool_items = rt.pool_grid.get_items()
      local items_by_key = {}
      for _, item in ipairs(pool_items) do
        local item_key = rt.pool_grid.key(item)
        items_by_key[item_key] = item
      end
      
      local filtered_keys = {}
      for _, key in ipairs(item_keys) do
        local item = items_by_key[key]
        if item and is_item_draggable(rt, key, item) then
          filtered_keys[#filtered_keys + 1] = key
        end
      end
      
      if #filtered_keys == 0 then
        return
      end
      
      local payload = {}
      for _, key in ipairs(filtered_keys) do
        local item = items_by_key[key]
        if item then
          -- Check if it's a playlist (has id and items fields)
          if item.id and item.items then
            payload[#payload + 1] = {type = "playlist", id = item.id}
          else
            -- It's a region (has rid field)
            local rid = item.rid
            if rid then
              payload[#payload + 1] = rid
            end
          end
        end
      end
      rt.drag_state.source = 'pool'
      rt.drag_state.data = payload
      rt.drag_state.ctrl_held = false
    end,
    
    reorder = function(new_order)
      if not rt.allow_pool_reorder then return end
      
      -- Extract regions and playlists separately
      local rids = {}
      local playlist_ids = {}
      
      for _, key in ipairs(new_order) do
        local playlist_id = key:match("pool_playlist_(.+)")
        if playlist_id then
          playlist_ids[#playlist_ids + 1] = playlist_id
        else
          local rid = tonumber(key:match("pool_(%d+)"))
          if rid then
            rids[#rids + 1] = rid
          end
        end
      end
      
      -- Call appropriate reorder callbacks
      if #rids > 0 and rt.on_pool_reorder then
        rt.on_pool_reorder(rids)
      end
      
      if #playlist_ids > 0 and rt.on_pool_playlist_reorder then
        rt.on_pool_playlist_reorder(playlist_ids)
      end
    end,
    
    -- Inline editing: Double-click to edit single tile
    start_inline_edit = function(key)
      local GridInput = require('rearkitekt.gui.widgets.containers.grid.input')
      local pool_items = rt.pool_grid.get_items()
      for _, item in ipairs(pool_items) do
        if rt.pool_grid.key(item) == key then
          local current_name
          if item.id and item.items then
            -- It's a playlist
            local playlist = rt.get_playlist_by_id and rt.get_playlist_by_id(item.id)
            current_name = playlist and playlist.name or "Playlist"
          else
            -- It's a region
            local State = require("Region_Playlist.core.app_state")
            local region = State.get_region_by_rid(item.rid)
            current_name = region and region.name or "Region"
          end
          GridInput.start_inline_edit(rt.pool_grid, key, current_name)
          break
        end
      end
    end,

    -- Inline edit complete callback
    on_inline_edit_complete = function(key, new_name)
      if rt.on_pool_rename then
        rt.on_pool_rename(key, new_name)
      end
    end,

    -- F2: Batch rename with wildcards
    rename = function(selected_keys)
      if not selected_keys or #selected_keys == 0 then return end

      -- Single selection: start inline editing
      if #selected_keys == 1 then
        local GridInput = require('rearkitekt.gui.widgets.containers.grid.input')
        local key = selected_keys[1]
        local pool_items = rt.pool_grid.get_items()
        for _, item in ipairs(pool_items) do
          if rt.pool_grid.key(item) == key then
            local current_name
            if item.id and item.items then
              -- It's a playlist
              local playlist = rt.get_playlist_by_id and rt.get_playlist_by_id(item.id)
              current_name = playlist and playlist.name or "Playlist"
            else
              -- It's a region
              local State = require("Region_Playlist.core.app_state")
              local region = State.get_region_by_rid(item.rid)
              current_name = region and region.name or "Region"
            end
            GridInput.start_inline_edit(rt.pool_grid, key, current_name)
            break
          end
        end
      else
        -- Multiple selection: open batch rename modal
        local BatchRenameModal = require('rearkitekt.gui.widgets.overlays.batch_rename_modal')
        BatchRenameModal.open(#selected_keys, function(pattern)
          if rt.on_pool_batch_rename then
            rt.on_pool_batch_rename(selected_keys, pattern)
          end
        end, {
          on_rename_and_recolor = function(pattern, color)
            if rt.on_pool_batch_rename_and_recolor then
              rt.on_pool_batch_rename_and_recolor(selected_keys, pattern, color)
            end
          end,
          on_recolor = function(color)
            if rt.on_pool_batch_recolor then
              rt.on_pool_batch_recolor(selected_keys, color)
            end
          end
        })
      end
    end,

    can_drag_item = function(key)
      local pool_items = rt.pool_grid.get_items()
      for _, item in ipairs(pool_items) do
        local item_key = rt.pool_grid.key(item)
        if item_key == key then
          return is_item_draggable(rt, key, item)
        end
      end
      return true
    end,
    
    on_select = function(selected_keys)
      -- Count regions and playlists in pool grid selection
      local region_count = 0
      local playlist_count = 0

      if selected_keys and #selected_keys > 0 then
        for _, key in ipairs(selected_keys) do
          if key:match("^pool_playlist_") then
            playlist_count = playlist_count + 1
          else
            region_count = region_count + 1
          end
        end
      end

      -- Combine with active grid selection
      local active_selection_info = { region_count = 0, playlist_count = 0 }
      if rt.active_grid and rt.active_grid.selection then
        local active_items = rt.active_grid.get_items()
        local active_selected_keys = rt.active_grid.selection:selected_keys()

        for _, key in ipairs(active_selected_keys) do
          local item = nil
          for _, it in ipairs(active_items) do
            if it.key == key then
              item = it
              break
            end
          end

          if item then
            if item.playlist_id then
              active_selection_info.playlist_count = active_selection_info.playlist_count + 1
            else
              active_selection_info.region_count = active_selection_info.region_count + 1
            end
          end
        end
      end

      -- Update State with combined selection info
      if rt.State and rt.State.set_selection_info then
        rt.State.set_selection_info({
          region_count = region_count + active_selection_info.region_count,
          playlist_count = playlist_count + active_selection_info.playlist_count
        })
      end
    end,
  }
end

local function create_external_drag_check(rt)
  return function()
    if rt.bridge then
      return rt.bridge:is_external_drag_for('pool')
    end
    return rt.drag_state.source == 'active'
  end
end

local function create_copy_mode_check(rt)
  return function()
    if rt.bridge then
      return rt.bridge:compute_copy_mode('pool')
    end
    return rt.drag_state.is_copy_mode
  end
end

local function create_render_tile(rt, tile_config)
  return function(ctx, rect, region, state, grid)
    local tile_height = rect[4] - rect[2]
    PoolTile.render(ctx, rect, region, state, rt.pool_animator, rt.hover_config,
                    tile_height, tile_config.border_thickness, grid)
  end
end

function M.create(rt, config)
  config = config or {}
  
  local base_tile_height = config.base_tile_height_pool or 72
  local tile_config = config.tile_config or { border_thickness = 0.5, rounding = 6 }
  local dim_config = config.dim_config or {
    fill_color = hexrgb("#00000088"),
    stroke_color = hexrgb("#FFFFFF33"),
    stroke_thickness = 1.5,
    rounding = 6,
  }
  local drop_config = config.drop_config or {}
  local ghost_config = config.ghost_config or {}
  local padding = config.container and config.container.padding or 8
  
  return Grid.new({
    id = "pool_grid",
    gap = PoolTile.CONFIG.gap,
    min_col_w = function() return PoolTile.CONFIG.tile_width end,
    fixed_tile_h = base_tile_height,
    get_items = function() return {} end,
    
    key = function(item)
      if item.id and item.items then
        return "pool_playlist_" .. tostring(item.id)
      else
        return "pool_" .. tostring(item.rid)
      end
    end,
    
    external_drag_check = create_external_drag_check(rt),
    is_copy_mode_check = create_copy_mode_check(rt),
    
    behaviors = create_behaviors(rt),
    
    accept_external_drops = false,
    
    render_tile = create_render_tile(rt, tile_config),
    
    extend_input_area = { 
      left = padding, 
      right = padding, 
      top = padding, 
      bottom = padding 
    },
    
    config = {
      spawn = PoolTile.CONFIG.spawn,
      ghost = ghost_config,
      dim = dim_config,
      drop = drop_config,
      drag = { threshold = 6 },
    },
  })
end

return M