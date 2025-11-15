-- @noindex
-- ItemPicker/ui/tiles/factories/audio_grid_factory.lua
-- Factory for creating audio items grid

local ImGui = require 'imgui' '0.10'
local Grid = require('ItemPicker.ui.performance_grid')  -- Use performance-optimized grid
local AudioRenderer = require('ItemPicker.ui.tiles.renderers.audio')

local M = {}

function M.create(ctx, config, state, visualization, cache_mgr, animator)
  local function get_items()
    if not state.sample_indexes then return {} end

    local filtered = {}
    for _, filename in ipairs(state.sample_indexes) do
      -- Check disabled filter
      if not state.settings.show_disabled_items and state.disabled.audio[filename] then
        goto continue
      end

      local content = state.samples[filename]
      if not content or #content == 0 then
        goto continue
      end

      -- Get current item index
      local current_idx = state.box_current_item[filename] or 1
      if current_idx > #content then current_idx = 1 end

      local entry = content[current_idx]
      if not entry or not entry[1] or not entry[2] then
        goto continue
      end

      local item = entry[1]
      local item_name = entry[2]
      local track_muted = entry.track_muted or false
      local item_muted = entry.item_muted or false

      -- Check mute filters
      if not state.settings.show_muted_tracks and track_muted then
        goto continue
      end

      if not state.settings.show_muted_items and item_muted then
        goto continue
      end

      -- Check search filter
      local search = state.settings.search_string or ""
      if search ~= "" and not item_name:lower():find(search:lower(), 1, true) then
        goto continue
      end

      -- Get track color (using I_CUSTOMCOLOR like old implementation)
      local track = reaper.GetMediaItemTrack(item)
      local track_color = reaper.GetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR")
      local r, g, b = 85/256, 91/256, 91/256  -- Default grey
      if track_color ~= 16576 and track_color > 0 then
        local R = track_color & 255
        local G = (track_color >> 8) & 255
        local B = (track_color >> 16) & 255
        r, g, b = R/255, G/255, B/255
      end
      local color = ImGui.ColorConvertDouble4ToU32(r, g, b, 1)

      table.insert(filtered, {
        filename = filename,
        item = item,
        name = item_name,
        index = current_idx,
        total = #content,
        color = color,
        key = filename,
      })

      ::continue::
    end

    return filtered
  end

  local grid = Grid.new({
    id = "audio_items",
    gap = config.TILE.GAP,
    min_col_w = function() return state:get_tile_width() end,
    fixed_tile_h = state:get_tile_height(),

    get_items = get_items,

    key = function(item_data)
      return item_data.filename
    end,

    render_tile = function(ctx, rect, item_data, tile_state)
      local dl = ImGui.GetWindowDrawList(ctx)
      AudioRenderer.render(ctx, dl, rect, item_data, tile_state, config, animator, visualization, cache_mgr, state)
    end,
  })

  -- Behaviors
  grid.behaviors = {
    drag_start = function(keys)
      reaper.ShowConsoleMsg(string.format("[DRAG_START] Called! keys=%d\n", keys and #keys or 0))
      if not keys or #keys == 0 then return end

      -- Support multi-item drag (use first selected item for preview)
      local key = keys[1]
      reaper.ShowConsoleMsg(string.format("[DRAG_START] First key: %s\n", tostring(key)))
      local items = get_items()

      for _, item_data in ipairs(items) do
        if item_data.key == key then
          local drag_w = math.min(200, state:get_tile_width())
          local drag_h = math.min(120, state:get_tile_height())

          -- Store all selected keys for batch insert
          state.dragging_keys = keys
          state.dragging_is_audio = true

          reaper.ShowConsoleMsg(string.format("[DRAG_START] Starting drag for: %s\n", item_data.name))
          state.start_drag(item_data.item, item_data.name, item_data.color, drag_w, drag_h)
          return
        end
      end
      reaper.ShowConsoleMsg("[DRAG_START] Item not found in grid!\n")
    end,

    right_click = function(key, selected_keys)
      -- Toggle disabled state for all selected items
      if #selected_keys > 1 then
        -- Multi-select: toggle all to the opposite of clicked item's state
        local new_state = not state.is_audio_disabled(key)
        for _, sel_key in ipairs(selected_keys) do
          if new_state then
            state.disabled.audio[sel_key] = true
          else
            state.disabled.audio[sel_key] = nil
          end
        end
        state.persist_disabled()
      else
        -- Single item: toggle
        state.toggle_audio_disabled(key)
      end
    end,

    wheel_adjust = function(keys, delta)
      reaper.ShowConsoleMsg(string.format("[WHEEL_ADJUST] Called! keys=%d, delta=%d\n", #keys, delta))
      if not keys or #keys == 0 then return end
      local key = keys[1]
      reaper.ShowConsoleMsg(string.format("[WHEEL_ADJUST] Cycling: %s, delta=%d\n", tostring(key), delta))
      state.cycle_audio_item(key, delta > 0 and 1 or -1)
    end,

    delete = function(item_keys)
      -- Disable all selected items
      for _, key in ipairs(item_keys) do
        state.disabled.audio[key] = true
      end
      state.persist_disabled()
    end,

    alt_click = function(item_keys)
      -- Quick disable with Alt+click
      for _, key in ipairs(item_keys) do
        state.disabled.audio[key] = true
      end
      state.persist_disabled()
    end,

    on_select = function(selected_keys)
      -- Update state with current selection count
      state.audio_selection_count = #selected_keys
    end,

    play = function(selected_keys)
      -- Preview selected items (use first selected)
      if not selected_keys or #selected_keys == 0 then return end

      local key = selected_keys[1]
      local items = get_items()

      for _, item_data in ipairs(items) do
        if item_data.key == key then
          -- Toggle preview
          if state.is_previewing(item_data.item) then
            state.stop_preview()
          else
            state.start_preview(item_data.item)
          end
          return
        end
      end
    end,
  }

  return grid
end

return M
