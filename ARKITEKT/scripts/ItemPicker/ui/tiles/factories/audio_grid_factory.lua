-- @noindex
-- ItemPicker/ui/tiles/factories/audio_grid_factory.lua
-- Factory for creating audio items grid

local ImGui = require 'imgui' '0.10'
local Grid = require('rearkitekt.gui.widgets.grid.core')
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

      -- Get track color
      local take = reaper.GetActiveTake(item)
      local track = reaper.GetMediaItemTrack(item)
      local track_color = reaper.GetTrackColor(track)

      table.insert(filtered, {
        filename = filename,
        item = item,
        name = item_name,
        index = current_idx,
        total = #content,
        color = track_color ~= 0 and (track_color | 0xFF) or 0xFF555555,
        key = filename,
      })

      ::continue::
    end

    return filtered
  end

  local grid = Grid.new({
    id = "audio_items",
    gap = config.TILE.GAP,
    min_col_w = function() return state:get_tile_width(config) end,
    fixed_tile_h = state:get_tile_height(config),

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
      if not keys or #keys == 0 then return end
      local key = keys[1]

      -- Find the item
      local items = get_items()
      for _, item_data in ipairs(items) do
        if item_data.key == key then
          -- Start drag
          local drag_w = math.min(200, state:get_tile_width(config))
          local drag_h = math.min(120, state:get_tile_height(config))

          state:start_drag(item_data.item, item_data.name, item_data.color, drag_w, drag_h)
          return
        end
      end
    end,

    right_click = function(key, selected_keys)
      -- Toggle disabled state
      state:toggle_audio_disabled(key)
    end,

    wheel_adjust = function(keys, delta)
      if not keys or #keys == 0 then return end
      local key = keys[1]
      state:cycle_audio_item(key, delta > 0 and 1 or -1)
    end,
  }

  return grid
end

return M
