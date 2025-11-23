-- @noindex
-- RegionPlaylist/ui/tiles/active_grid_factory.lua
-- UNCHANGED

local Grid = require('arkitekt.gui.widgets.containers.grid.core')
local ActiveTile = require('RegionPlaylist.ui.tiles.renderers.active')
local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb


local M = {}

local function handle_unified_delete(rt, item_keys)
  if not item_keys or #item_keys == 0 then return end
  
  if rt.active_grid then
    rt.active_grid:mark_destroyed(item_keys)
  end
  
  if rt.active_grid and rt.active_grid.selection then
    for _, key in ipairs(item_keys) do
      rt.active_grid.selection.selected[key] = nil
    end
    if rt.active_grid.behaviors and rt.active_grid.behaviors.on_select then
      rt.active_grid.behaviors.on_select(rt.active_grid, rt.active_grid.selection:selected_keys())
    end
  end
  
  if rt.on_active_delete then
    rt.on_active_delete(item_keys)
  end
end

local function create_behaviors(rt)
  return {
    drag_start = function(grid, item_keys)
    end,

    -- Right-click: toggle enabled state
    ['click:right'] = function(grid, key, selected_keys)
      if not rt.on_active_toggle_enabled then return end

      if #selected_keys > 1 then
        local playlist_items = rt.active_grid.get_items()
        local item_map = {}
        for _, item in ipairs(playlist_items) do
          item_map[item.key] = item
        end

        local clicked_item = item_map[key]
        if clicked_item then
          local new_state = not (clicked_item.enabled ~= false)
          for _, sel_key in ipairs(selected_keys) do
            rt.on_active_toggle_enabled(sel_key, new_state)
          end
        end
      else
        local playlist_items = rt.active_grid.get_items()
        for _, item in ipairs(playlist_items) do
          if item.key == key then
            local new_state = not (item.enabled ~= false)
            rt.on_active_toggle_enabled(key, new_state)
            break
          end
        end
      end
    end,

    delete = function(grid, item_keys)
      handle_unified_delete(rt, item_keys)
    end,

    -- SPACE: empty for now
    space = function(grid, selected_keys)
    end,
    
    reorder = function(grid, new_order)
      if not rt.active_grid or not rt.active_grid.drag then return end
      
      local is_copy_mode = false
      if rt.bridge then
        is_copy_mode = rt.bridge:compute_copy_mode('active')
      end
      
      if is_copy_mode and rt.on_active_copy then
        local playlist_items = rt.active_grid.get_items()
        local items_by_key = {}
        for _, item in ipairs(playlist_items) do
          items_by_key[item.key] = item
        end
        
        local dragged_ids = rt.active_grid.drag:get_dragged_ids()
        local dragged_items = {}
        for _, key in ipairs(dragged_ids) do
          if items_by_key[key] then
            dragged_items[#dragged_items + 1] = items_by_key[key]
          end
        end
        
        if #dragged_items > 0 then
          rt.on_active_copy(dragged_items, rt.active_grid.drag:get_target_index())

          -- Show copy notification
          if rt.State and rt.State.set_state_change_notification then
            local region_count = 0
            local playlist_count = 0
            for _, item in ipairs(dragged_items) do
              if item.playlist_id then
                playlist_count = playlist_count + 1
              else
                region_count = region_count + 1
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
              rt.State.set_state_change_notification(string.format("Copied %s within Active Grid (%s)", items_text, playlist_name))
            end
          end
        end
      elseif rt.on_active_reorder then
        local playlist_items = rt.active_grid.get_items()
        local items_by_key = {}
        for _, item in ipairs(playlist_items) do
          items_by_key[item.key] = item
        end
        
        local new_items = {}
        for _, key in ipairs(new_order) do
          if items_by_key[key] then
            new_items[#new_items + 1] = items_by_key[key]
          end
        end

        rt.on_active_reorder(new_items)

        -- Show move notification
        if rt.State and rt.State.set_state_change_notification and rt.active_grid.drag then
          local dragged_ids = rt.active_grid.drag:get_dragged_ids()
          if #dragged_ids > 0 then
            local region_count = 0
            local playlist_count = 0
            for _, key in ipairs(dragged_ids) do
              local item = items_by_key[key]
              if item then
                if item.playlist_id then
                  playlist_count = playlist_count + 1
                else
                  region_count = region_count + 1
                end
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
              rt.State.set_state_change_notification(string.format("Moved %s within Active Grid (%s)", items_text, playlist_name))
            end
          end
        end
      end
    end,
    
    on_select = function(grid, selected_keys)
      -- Count regions and playlists in active grid selection
      local region_count = 0
      local playlist_count = 0

      if selected_keys and #selected_keys > 0 then
        local playlist_items = rt.active_grid.get_items()
        local items_by_key = {}
        for _, item in ipairs(playlist_items) do
          items_by_key[item.key] = item
        end

        for _, key in ipairs(selected_keys) do
          local item = items_by_key[key]
          if item then
            if item.playlist_id then
              playlist_count = playlist_count + 1
            else
              region_count = region_count + 1
            end
          end
        end
      end

      -- Combine with pool grid selection
      local pool_selection_info = { region_count = 0, playlist_count = 0 }
      if rt.pool_grid and rt.pool_grid.selection then
        local pool_items = rt.pool_grid.get_items()
        local pool_selected_keys = rt.pool_grid.selection:selected_keys()

        for _, key in ipairs(pool_selected_keys) do
          if key:match("^pool_playlist_") then
            pool_selection_info.playlist_count = pool_selection_info.playlist_count + 1
          else
            pool_selection_info.region_count = pool_selection_info.region_count + 1
          end
        end
      end

      -- Update State with combined selection info
      if rt.State and rt.State.set_selection_info then
        rt.State.set_selection_info({
          region_count = region_count + pool_selection_info.region_count,
          playlist_count = playlist_count + pool_selection_info.playlist_count
        })
      end
    end,

    -- Inline editing: Double-click to edit single tile
    start_inline_edit = function(grid, key)
      local GridInput = require('arkitekt.gui.widgets.containers.grid.input')
      local playlist_items = rt.active_grid.get_items()
      for _, item in ipairs(playlist_items) do
        if item.key == key then
          -- Get current name
          local current_name
          if item.type == "playlist" then
            local playlist = rt.get_playlist_by_id and rt.get_playlist_by_id(item.playlist_id)
            current_name = playlist and playlist.name or "Playlist"
          else
            local region = rt.get_region_by_rid(item.rid)
            current_name = region and region.name or "Region"
          end
          GridInput.start_inline_edit(rt.active_grid, key, current_name)
          break
        end
      end
    end,

    -- Inline edit complete callback
    on_inline_edit_complete = function(grid, key, new_name)
      if rt.on_active_rename then
        rt.on_active_rename(key, new_name)
      end
    end,

    -- Double-click outside text zone: Move cursor and seek to region/playlist
    double_click_seek = function(grid, key)
      local playlist_items = rt.active_grid.get_items()
      for _, item in ipairs(playlist_items) do
        if item.key == key then
          if item.type == "playlist" then
            -- For playlists, seek to the first item in the playlist
            local playlist = rt.get_playlist_by_id and rt.get_playlist_by_id(item.playlist_id)
            if playlist and playlist.items and #playlist.items > 0 then
              local first_item = playlist.items[1]
              if first_item.rid then
                local region = rt.get_region_by_rid(first_item.rid)
                if region and region.start then
                  reaper.SetEditCurPos(region.start, true, true)
                end
              end
            end
          else
            -- For regions, seek to region start
            local region = rt.get_region_by_rid(item.rid)
            if region and region.start then
              reaper.SetEditCurPos(region.start, true, true)
            end
          end
          break
        end
      end
    end,

    -- F2: Batch rename with wildcards
    f2 = function(grid, selected_keys)
      if not selected_keys or #selected_keys == 0 then return end

      -- Single selection: start inline editing
      if #selected_keys == 1 then
        local GridInput = require('arkitekt.gui.widgets.containers.grid.input')
        local key = selected_keys[1]
        local playlist_items = rt.active_grid.get_items()
        for _, item in ipairs(playlist_items) do
          if item.key == key then
            local current_name
            if item.type == "playlist" then
              local playlist = rt.get_playlist_by_id and rt.get_playlist_by_id(item.playlist_id)
              current_name = playlist and playlist.name or "Playlist"
            else
              local region = rt.get_region_by_rid(item.rid)
              current_name = region and region.name or "Region"
            end
            GridInput.start_inline_edit(rt.active_grid, key, current_name)
            break
          end
        end
      else
        -- Multiple selection: open batch rename modal
        local BatchRenameModal = require('arkitekt.gui.widgets.overlays.batch_rename_modal')
        BatchRenameModal.open(#selected_keys, function(pattern)
          if rt.on_active_batch_rename then
            rt.on_active_batch_rename(selected_keys, pattern)
          end
        end, {
          item_type = "regions",  -- Label for Region Playlist items
          on_rename_and_recolor = function(pattern, color)
            if rt.on_active_batch_rename_and_recolor then
              rt.on_active_batch_rename_and_recolor(selected_keys, pattern, color)
            end
          end,
          on_recolor = function(color)
            if rt.on_active_batch_recolor then
              rt.on_active_batch_recolor(selected_keys, color)
            end
          end
        })
      end
    end,
  }
end

local function create_external_drop_handler(rt)
  return function(insert_index)
  end
end

local function create_external_drag_check(rt)
  return function()
    if rt.bridge then
      return rt.bridge:is_external_drag_for('active')
    end
    return false
  end
end

local function create_copy_mode_check(rt)
  return function()
    if rt.bridge then
      return rt.bridge:compute_copy_mode('active')
    end
    return false
  end
end

local function create_render_tile(rt, tile_config)
  return function(ctx, rect, item, state, grid)
    local tile_height = rect[4] - rect[2]
    ActiveTile.render(ctx, rect, item, state, rt.get_region_by_rid, rt.active_animator,
                    rt.on_repeat_cycle, rt.hover_config, tile_height, tile_config.border_thickness,
                    rt.app_bridge, rt.get_playlist_by_id, grid)
  end
end

function M.create(rt, config)
  config = config or {}
  
  local base_tile_height = config.base_tile_height_active or 72
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
    id = "active_grid",
    gap = ActiveTile.CONFIG.gap,
    min_col_w = function() return ActiveTile.CONFIG.tile_width end,
    fixed_tile_h = base_tile_height,
    get_items = function() return {} end,
    key = function(item) return item.key end,
    
    external_drag_check = create_external_drag_check(rt),
    is_copy_mode_check = create_copy_mode_check(rt),
    
    behaviors = create_behaviors(rt),
    
    accept_external_drops = true,
    on_external_drop = create_external_drop_handler(rt),
    
    on_destroy_complete = function(key)
      if rt.on_destroy_complete then
        rt.on_destroy_complete(key)
      end
    end,
    
    on_click_empty = function(key)
      if rt.on_repeat_cycle then
        rt.on_repeat_cycle(key)
      end
    end,

    render_tile = create_render_tile(rt, tile_config),
    
    extend_input_area = { 
      left = padding, 
      right = padding, 
      top = padding, 
      bottom = padding 
    },
    
    config = {
      spawn = ActiveTile.CONFIG.spawn,
      destroy = { enabled = true },
      ghost = ghost_config,
      dim = dim_config,
      drop = drop_config,
      drag = { threshold = 6 },
    },
  })
end

return M