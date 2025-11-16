-- @noindex
-- ItemPicker/ui/tiles/factories/audio_grid_factory.lua
-- Factory for creating audio items grid

local ImGui = require 'imgui' '0.10'
local Grid = require('rearkitekt.gui.widgets.containers.grid.core')
local AudioRenderer = require('ItemPicker.ui.tiles.renderers.audio')

local M = {}

function M.create(ctx, config, state, visualization, cache_mgr, animator)
  local function get_items()
    if not state.sample_indexes then return {} end

    local filtered = {}
    for _, filename in ipairs(state.sample_indexes) do
      -- Check favorites filter
      if state.settings.show_favorites_only and not state.favorites.audio[filename] then
        goto continue
      end

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
      if not entry or not entry[2] then  -- Only require name, not item pointer
        goto continue
      end

      local item = entry[1]  -- May be nil for cached data
      local item_name = entry[2]
      local track_muted = entry.track_muted or false
      local item_muted = entry.item_muted or false
      local uuid = entry.uuid
      local pool_count = entry.pool_count or 1

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

      -- Get track color (default grey if item is nil/invalid)
      local track_color = 16576  -- Default grey code
      if item and reaper.ValidatePtr2(0, item, "MediaItem*") then
        local track = reaper.GetMediaItemTrack(item)
        if track then
          track_color = reaper.GetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR")
        end
      end

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
        key = uuid,
        uuid = uuid,
        pool_count = pool_count,  -- Number of pooled items (from Reaper pooling)
      })

      ::continue::
    end

    -- Apply sorting
    local sort_mode = state.settings.sort_mode or "none"
    if sort_mode == "color" then
      -- Sort by color (hue-based for visual grouping)
      table.sort(filtered, function(a, b)
        -- Extract RGB from ImGui color (ABGR format)
        local ar = (a.color >> 16) & 0xFF
        local ag = (a.color >> 8) & 0xFF
        local ab = a.color & 0xFF

        local br = (b.color >> 16) & 0xFF
        local bg = (b.color >> 8) & 0xFF
        local bb = b.color & 0xFF

        -- Convert to HSV for better color sorting
        local function rgb_to_hue(r, g, b)
          r, g, b = r/255, g/255, b/255
          local max = math.max(r, g, b)
          local min = math.min(r, g, b)
          if max == min then return 0 end

          local hue
          if max == r then
            hue = (g - b) / (max - min)
          elseif max == g then
            hue = 2 + (b - r) / (max - min)
          else
            hue = 4 + (r - g) / (max - min)
          end
          hue = hue * 60
          if hue < 0 then hue = hue + 360 end
          return hue
        end

        local a_hue = rgb_to_hue(ar, ag, ab)
        local b_hue = rgb_to_hue(br, bg, bb)
        return a_hue < b_hue
      end)
    elseif sort_mode == "name" then
      -- Sort alphabetically by name
      table.sort(filtered, function(a, b)
        return a.name:lower() < b.name:lower()
      end)
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
      return item_data.uuid
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
      local uuid = keys[1]
      reaper.ShowConsoleMsg(string.format("[DRAG_START] First UUID: %s\n", tostring(uuid)))

      -- O(1) lookup instead of O(n) search
      local item_lookup_data = state.audio_item_lookup[uuid]
      if not item_lookup_data then
        reaper.ShowConsoleMsg("[DRAG_START] Item not found in lookup!\n")
        return
      end

      local drag_w = math.min(200, state:get_tile_width())
      local drag_h = math.min(120, state:get_tile_height())

      -- Store all selected keys for batch insert
      state.dragging_keys = keys
      state.dragging_is_audio = true

      -- Get current display data (filtered version)
      local items = get_items()
      local display_data
      for _, item_data in ipairs(items) do
        if item_data.uuid == uuid then
          display_data = item_data
          break
        end
      end

      if display_data then
        reaper.ShowConsoleMsg(string.format("[DRAG_START] Starting drag for: %s\n", display_data.name))
        state.start_drag(display_data.item, display_data.name, display_data.color, drag_w, drag_h)
      end
    end,

    right_click = function(uuid, selected_uuids)
      -- Toggle favorite state for all selected items
      -- Need to get filename from UUID lookup
      local item_data = state.audio_item_lookup[uuid]
      if not item_data then return end

      local items = get_items()
      local filename_map = {}
      for _, data in ipairs(items) do
        if data.uuid then
          filename_map[data.uuid] = data.filename
        end
      end

      if #selected_uuids > 1 then
        -- Multi-select: toggle all to the opposite of clicked item's state
        local clicked_filename = filename_map[uuid]
        local new_state = not state.is_audio_favorite(clicked_filename)
        for _, sel_uuid in ipairs(selected_uuids) do
          local sel_filename = filename_map[sel_uuid]
          if sel_filename then
            if new_state then
              state.favorites.audio[sel_filename] = true
            else
              state.favorites.audio[sel_filename] = nil
            end
          end
        end
        state.persist_favorites()
      else
        -- Single item: toggle
        local filename = filename_map[uuid]
        if filename then
          state.toggle_audio_favorite(filename)
        end
      end
    end,

    wheel_adjust = function(uuids, delta)
      if not uuids or #uuids == 0 then return end
      local uuid = uuids[1]

      -- Get filename from UUID
      local items = get_items()
      for _, data in ipairs(items) do
        if data.uuid == uuid then
          state.cycle_audio_item(data.filename, delta > 0 and 1 or -1)
          return
        end
      end
    end,

    delete = function(item_uuids)
      -- Disable all selected items
      -- Convert UUIDs to filenames
      local items = get_items()
      local filename_map = {}
      for _, data in ipairs(items) do
        if data.uuid then
          filename_map[data.uuid] = data.filename
        end
      end

      for _, uuid in ipairs(item_uuids) do
        local filename = filename_map[uuid]
        if filename then
          state.disabled.audio[filename] = true
        end
      end
      state.persist_disabled()
    end,

    alt_click = function(item_uuids)
      -- Toggle disable with Alt+click
      -- Convert UUIDs to filenames
      local items = get_items()
      local filename_map = {}
      for _, data in ipairs(items) do
        if data.uuid then
          filename_map[data.uuid] = data.filename
        end
      end

      for _, uuid in ipairs(item_uuids) do
        local filename = filename_map[uuid]
        if filename then
          state.toggle_audio_disabled(filename)
        end
      end
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

    double_click = function(uuid)
      -- Start rename for this item
      local items = get_items()
      for _, item_data in ipairs(items) do
        if item_data.uuid == uuid then
          state.rename_active = true
          state.rename_uuid = uuid
          state.rename_text = item_data.name
          state.rename_is_audio = true
          state.rename_focused = false  -- Reset focus flag
          return
        end
      end
    end,

    rename = function(selected_keys)
      -- Start rename for selected items (batch rename)
      if not selected_keys or #selected_keys == 0 then return end

      -- Start with first selected item
      local uuid = selected_keys[1]
      local items = get_items()

      for _, item_data in ipairs(items) do
        if item_data.uuid == uuid then
          state.rename_active = true
          state.rename_uuid = uuid
          state.rename_text = item_data.name
          state.rename_is_audio = true
          state.rename_focused = false  -- Reset focus flag
          state.rename_queue = selected_keys  -- Store all selected for batch rename
          state.rename_queue_index = 1
          return
        end
      end
    end,
  }

  return grid
end

return M
