-- @noindex
-- ItemPicker/ui/tiles/factories/audio_grid_factory.lua
-- Factory for creating audio items grid

local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local Grid = require('rearkitekt.gui.widgets.containers.grid.core')
local AudioRenderer = require('ItemPicker.ui.grids.renderers.audio')

local M = {}

function M.create(ctx, config, state, visualization, animator)
  local function get_items()
    if not state.sample_indexes then return {} end

    -- Compute filter hash to detect changes
    local settings = state.settings
    local filter_hash = string.format("%s|%s|%s|%s|%s|%s|%s|%d",
      tostring(settings.show_favorites_only),
      tostring(settings.show_disabled_items),
      tostring(settings.show_muted_tracks),
      tostring(settings.show_muted_items),
      settings.search_string or "",
      settings.sort_mode or "none",
      table.concat(state.sample_indexes, ","),  -- Invalidate if items change
      #state.sample_indexes
    )

    -- Return cached result if filters haven't changed
    if state.runtime_cache.audio_filter_hash == filter_hash and state.runtime_cache.audio_filtered then
      return state.runtime_cache.audio_filtered
    end

    -- Filters changed - rebuild filtered list
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

      -- Use cached track color (fetched during loading, not every frame!)
      local track_color = entry.track_color or 0
      local r, g, b = 85/256, 91/256, 91/256  -- Default grey

      -- REAPER's I_CUSTOMCOLOR: 0 = no custom color set, use default grey
      -- Non-zero values are in Windows COLORREF format: 0x00BBGGRR
      if track_color > 0 then
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
      -- Sort by color using library's color comparison
      -- Uses HSL: Hue → Saturation (desc) → Lightness (desc)
      -- Grays (sat < 0.08) are grouped at the end
      table.sort(filtered, function(a, b)
        return Colors.compare_colors(a.color, b.color)
      end)
    elseif sort_mode == "name" then
      -- Sort alphabetically by name
      table.sort(filtered, function(a, b)
        return a.name:lower() < b.name:lower()
      end)
    end

    -- Cache result for next frame
    state.runtime_cache.audio_filtered = filtered
    state.runtime_cache.audio_filter_hash = filter_hash

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
      AudioRenderer.render(ctx, dl, rect, item_data, tile_state, config, animator, visualization, state)
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

    favorite = function(item_uuids)
      -- Toggle favorite with F key
      local items = get_items()
      local filename_map = {}
      for _, data in ipairs(items) do
        if data.uuid then
          filename_map[data.uuid] = data.filename
        end
      end

      if #item_uuids > 1 then
        -- Multi-select: toggle all to opposite of first item's state
        local first_filename = filename_map[item_uuids[1]]
        local new_state = not state.is_audio_favorite(first_filename)
        for _, uuid in ipairs(item_uuids) do
          local filename = filename_map[uuid]
          if filename then
            if new_state then
              state.favorites.audio[filename] = true
            else
              state.favorites.audio[filename] = nil
            end
          end
        end
        state.persist_favorites()
      else
        -- Single item: toggle
        local filename = filename_map[item_uuids[1]]
        if filename then
          state.toggle_audio_favorite(filename)
        end
      end
    end,

    wheel_adjust = function(uuids, delta)
      reaper.ShowConsoleMsg(string.format("[WHEEL_ADJUST] Called! uuids=%d, delta=%d\n", uuids and #uuids or 0, delta or 0))
      if not uuids or #uuids == 0 then
        reaper.ShowConsoleMsg("[WHEEL_ADJUST] Empty uuids, returning\n")
        return nil
      end
      local uuid = uuids[1]

      -- Get filename from UUID
      local items = get_items()
      for _, data in ipairs(items) do
        if data.uuid == uuid then
          reaper.ShowConsoleMsg(string.format("[WHEEL_ADJUST] Cycling item: %s\n", data.filename))
          state.cycle_audio_item(data.filename, delta > 0 and 1 or -1)

          -- Rebuild items list after cycling to get new UUID
          state.runtime_cache.audio_filter_hash = nil  -- Force rebuild
          local updated_items = get_items()

          -- Find the new item with the same filename
          for _, updated_data in ipairs(updated_items) do
            if updated_data.filename == data.filename then
              reaper.ShowConsoleMsg(string.format("[WHEEL_ADJUST] New UUID: %s\n", updated_data.uuid))
              return updated_data.uuid
            end
          end

          return uuid  -- Fallback to old UUID if not found
        end
      end
      reaper.ShowConsoleMsg("[WHEEL_ADJUST] UUID not found in items\n")
      return nil
    end,

    delete = function(item_uuids)
      -- Toggle disable state for all selected items
      -- Convert UUIDs to filenames
      local items = get_items()
      local filename_map = {}
      for _, data in ipairs(items) do
        if data.uuid then
          filename_map[data.uuid] = data.filename
        end
      end

      -- Determine toggle state: if first item is disabled, enable all; otherwise disable all
      if #item_uuids > 0 then
        local first_filename = filename_map[item_uuids[1]]
        local new_state = not state.disabled.audio[first_filename]

        for _, uuid in ipairs(item_uuids) do
          local filename = filename_map[uuid]
          if filename then
            if new_state then
              state.disabled.audio[filename] = true
            else
              state.disabled.audio[filename] = nil
            end
          end
        end
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
