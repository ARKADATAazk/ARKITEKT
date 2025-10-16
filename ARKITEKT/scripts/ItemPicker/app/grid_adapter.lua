local M = {}
local Grid
local imgui
local ctx
local visualization
local cache_mgr
local config
local shortcuts
local tile_rendering
local disabled_items
local TileAnim

function M.init(imgui_module, imgui_ctx, Grid_module, visualization_module, cache_manager_module, config_module, shortcuts_module, tile_rendering_module, disabled_items_module, tile_anim_module)
  imgui = imgui_module
  ctx = imgui_ctx
  Grid = Grid_module
  visualization = visualization_module
  cache_mgr = cache_manager_module
  config = config_module
  shortcuts = shortcuts_module
  tile_rendering = tile_rendering_module
  disabled_items = disabled_items_module
  TileAnim = tile_anim_module
  
  if not tile_rendering then error("tile_rendering module required") end
  if not disabled_items then error("disabled_items module required") end
end

function M.create_audio_grid(state, settings)
  if not shortcuts then
    error("shortcuts module not initialized in grid_adapter")
  end
  
  if not state.tile_animator then
    state.tile_animator = TileAnim and TileAnim.new(12.0) or nil
  end
  
  local tile_width = shortcuts.get_tile_width(state)
  local tile_height = shortcuts.get_tile_height(state)
  
  return Grid.new({
    id = "audio_items",
    gap = config.TILE.GAP,
    min_col_w = function() return tile_width end,
    fixed_tile_h = tile_height,
    
    get_items = function()
      if not state.sample_indexes then return {} end
      local filtered = {}
      for _, filename in ipairs(state.sample_indexes) do
        if not settings.show_disabled_items and disabled_items.is_disabled_audio(state.disabled, filename) then
          goto skip_disabled
        end
        
        local content = state.samples[filename]
        local current_idx = state.box_current_item[filename] or 1
        if current_idx > #content then current_idx = 1 end
        
        local item = content[current_idx][1]
        local item_name = content[current_idx][2]
        
        if settings.search_string == 0 or item_name:lower():find(settings.search_string:lower()) then
          table.insert(filtered, {
            filename = filename,
            item = item,
            name = item_name,
            index = current_idx,
            total = #content
          })
        end
        
        ::skip_disabled::
      end
      return filtered
    end,
    
    key = function(item_data)
      return item_data.filename
    end,
    
    render_tile = function(ctx, rect, item_data, tile_state)
      local dl = imgui.GetWindowDrawList(ctx)
      local track = reaper.GetMediaItemTrack(item_data.item)
      local track_color = reaper.GetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR")
      local r, g, b = 85/256, 91/256, 91/256
      if track_color ~= 16576 and track_color > 0 then
        local function RGBvalues(RGB)
          local R, G, B = RGB & 255, (RGB >> 8) & 255, (RGB >> 16) & 255
          return R/255, G/255, B/255
        end
        r, g, b = RGBvalues(track_color)
      end
      track_color = imgui.ColorConvertDouble4ToU32(r, g, b, 1)
      
      local is_disabled = disabled_items.is_disabled_audio(state.disabled, item_data.filename)
      
      local render_data = {
        key = item_data.filename,
        name = item_data.name,
        index = item_data.index,
        total = item_data.total,
        item = item_data.item,
        cache = state.cache,
        is_midi = false,
      }
      
      tile_rendering.render_complete_tile(
        dl, rect, render_data, tile_state, 
        track_color, state.tile_animator, 
        visualization, cache_mgr, is_disabled
      )
    end,
    
    behaviors = {
      drag_start = function(keys)
        local item_data = state.audio_grid.get_items()
        for _, data in ipairs(item_data) do
          if state.audio_grid.key(data) == keys[1] then
            local tile_width = shortcuts.get_tile_width(state)
            local tile_height = shortcuts.get_tile_height(state)
            local text_w = imgui.CalcTextSize(ctx, " " .. data.name)
            
            state.item_to_add = data.item
            state.item_to_add_name = data.name
            state.item_to_add_width = math.max(text_w, tile_width)
            state.item_to_add_height = tile_height
            state.item_to_add_color = reaper.GetMediaTrackInfo_Value(reaper.GetMediaItemTrack(data.item), "I_CUSTOMCOLOR")
            state.item_to_add_visual_index = data.filename
            state.dragging = true
            state.drag_waveform = nil
            break
          end
        end
      end,
      
      right_click = function(key, selected_keys)
        if #selected_keys > 1 then
          for _, filename in ipairs(selected_keys) do
            disabled_items.toggle_audio(state.disabled, filename)
          end
        else
          disabled_items.toggle_audio(state.disabled, key)
        end
      end,
      
      wheel_adjust = function(keys, delta)
        for _, filename in ipairs(keys) do
          local content = state.samples[filename]
          if content then
            local current = state.box_current_item[filename] or 1
            state.box_current_item[filename] = math.max(1, math.min(current + delta, #content))
          end
        end
      end
    },
  })
end

function M.create_midi_grid(state, settings)
  if not state.tile_animator then
    state.tile_animator = TileAnim and TileAnim.new(12.0) or nil
  end
  
  local tile_width = shortcuts.get_tile_width(state)
  local tile_height = shortcuts.get_tile_height(state)
  
  return Grid.new({
    id = "midi_items",
    gap = config.TILE.GAP,
    min_col_w = function() return tile_width end,
    fixed_tile_h = tile_height,
    
    get_items = function()
      if not state.midi_tracks then return {} end
      local filtered = {}
      for track_idx, track_items in ipairs(state.midi_tracks) do
        if not settings.show_disabled_items and disabled_items.is_disabled_midi(state.disabled, track_idx) then
          goto skip_disabled
        end
        
        local current_idx = state.box_current_item["midi_" .. track_idx] or 1
        if current_idx > #track_items then current_idx = 1 end
        
        local item = track_items[current_idx]
        local track = reaper.GetMediaItemTrack(item)
        local _, track_name = reaper.GetTrackName(track)
        
        if settings.search_string == 0 or track_name:lower():find(settings.search_string:lower()) then
          table.insert(filtered, {
            track_idx = track_idx,
            item = item,
            name = track_name,
            index = current_idx,
            total = #track_items
          })
        end
        
        ::skip_disabled::
      end
      return filtered
    end,
    
    key = function(item_data)
      return "midi_" .. item_data.track_idx
    end,
    
    render_tile = function(ctx, rect, item_data, tile_state)
      local dl = imgui.GetWindowDrawList(ctx)
      local track = reaper.GetMediaItemTrack(item_data.item)
      local track_color = reaper.GetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR")
      local r, g, b = 85/256, 91/256, 91/256
      if track_color ~= 16576 and track_color > 0 then
        local function RGBvalues(RGB)
          local R, G, B = RGB & 255, (RGB >> 8) & 255, (RGB >> 16) & 255
          return R/255, G/255, B/255
        end
        r, g, b = RGBvalues(track_color)
      end
      track_color = imgui.ColorConvertDouble4ToU32(r, g, b, 1)
      
      local is_disabled = disabled_items.is_disabled_midi(state.disabled, item_data.track_idx)
      
      local render_data = {
        key = "midi_" .. item_data.track_idx,
        name = item_data.name,
        index = item_data.index,
        total = item_data.total,
        item = item_data.item,
        cache = state.cache,
        is_midi = true,
      }
      
      tile_rendering.render_complete_tile(
        dl, rect, render_data, tile_state, 
        track_color, state.tile_animator, 
        visualization, cache_mgr, is_disabled
      )
    end,
    
    behaviors = {
      drag_start = function(keys)
        local item_data = state.midi_grid.get_items()
        for _, data in ipairs(item_data) do
          if state.midi_grid.key(data) == keys[1] then
            local tile_width = shortcuts.get_tile_width(state)
            local tile_height = shortcuts.get_tile_height(state)
            local text_w = imgui.CalcTextSize(ctx, " " .. data.name)
            
            state.item_to_add = data.item
            state.item_to_add_name = data.name
            state.item_to_add_width = math.max(text_w, tile_width)
            state.item_to_add_height = tile_height
            state.item_to_add_color = reaper.GetMediaTrackInfo_Value(reaper.GetMediaItemTrack(data.item), "I_CUSTOMCOLOR")
            state.item_to_add_visual_index = "midi_" .. data.track_idx
            state.dragging = true
            break
          end
        end
      end,
      
      right_click = function(key, selected_keys)
        if #selected_keys > 1 then
          for _, k in ipairs(selected_keys) do
            local track_idx = tonumber(k:match("midi_(%d+)"))
            if track_idx then
              disabled_items.toggle_midi(state.disabled, track_idx)
            end
          end
        else
          local track_idx = tonumber(key:match("midi_(%d+)"))
          if track_idx then
            disabled_items.toggle_midi(state.disabled, track_idx)
          end
        end
      end,
      
      wheel_adjust = function(keys, delta)
        for _, key in ipairs(keys) do
          local track_idx = tonumber(key:match("midi_(%d+)"))
          if track_idx and state.midi_tracks[track_idx] then
            local content = state.midi_tracks[track_idx]
            local current = state.box_current_item[key] or 1
            state.box_current_item[key] = math.max(1, math.min(current + delta, #content))
          end
        end
      end
    },
  })
end

function M.update_animations(state, dt)
  if state.tile_animator then
    state.tile_animator:update(dt or 0.016)
  end
end

return M