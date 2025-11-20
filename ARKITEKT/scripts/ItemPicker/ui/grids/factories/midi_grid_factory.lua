-- @noindex
-- ItemPicker/ui/tiles/factories/midi_grid_factory.lua
-- Factory for creating MIDI items grid

local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local Grid = require('rearkitekt.gui.widgets.containers.grid.core')
local MidiRenderer = require('ItemPicker.ui.grids.renderers.midi')

local M = {}

function M.create(ctx, config, state, visualization, animator)
  local function get_items()
    if not state.midi_indexes then return {} end

    -- Compute filter hash to detect changes (EXCLUDING indices to prevent re-sort)
    local settings = state.settings
    local filter_hash = string.format("%s|%s|%s|%s|%s|%s|%s|%s|%d",
      tostring(settings.show_favorites_only),
      tostring(settings.show_disabled_items),
      tostring(settings.show_muted_tracks),
      tostring(settings.show_muted_items),
      settings.search_string or "",
      settings.search_mode or "items",
      settings.sort_mode or "none",
      table.concat(state.midi_indexes, ","),  -- Invalidate if items change
      #state.midi_indexes
    )

    -- Return cached result if filters haven't changed
    if state.runtime_cache.midi_filter_hash == filter_hash and state.runtime_cache.midi_filtered then
      return state.runtime_cache.midi_filtered
    end

    -- Filters changed - rebuild filtered list
    local filtered = {}
    for _, track_guid in ipairs(state.midi_indexes) do
      -- Check favorites filter
      if state.settings.show_favorites_only and not state.favorites.midi[track_guid] then
        goto continue
      end

      -- Check disabled filter
      if not state.settings.show_disabled_items and state.disabled.midi[track_guid] then
        goto continue
      end

      local content = state.midi_items[track_guid]
      if not content or #content == 0 then
        goto continue
      end

      -- Get current item index (absolute position in full array)
      local current_idx = state.box_current_midi_track[track_guid] or 1
      if current_idx > #content then current_idx = 1 end

      -- Build filtered list to calculate position and count
      local seen_pools = {}
      local filtered_list = {}
      for i, entry in ipairs(content) do
        local pool_count = entry.pool_count or 1
        local pool_id = entry.pool_id
        if pool_count > 1 and pool_id then
          if not seen_pools[pool_id] then
            seen_pools[pool_id] = true
            table.insert(filtered_list, {index = i, entry = entry})
          end
        else
          table.insert(filtered_list, {index = i, entry = entry})
        end
      end

      -- Find current position in filtered list
      local current_position = 1
      for pos, item in ipairs(filtered_list) do
        if item.index == current_idx then
          current_position = pos
          break
        end
      end

      local filtered_count = #filtered_list

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
      local track_name = entry.track_name or ""

      -- Safety check: ensure item_name is a valid string
      if not item_name or type(item_name) ~= "string" then
        goto continue
      end

      -- Check mute filters
      if not state.settings.show_muted_tracks and track_muted then
        goto continue
      end

      if not state.settings.show_muted_items and item_muted then
        goto continue
      end

      -- Check search filter (mode-based)
      local search = state.settings.search_string or ""
      if type(search) == "string" and search ~= "" then
        local search_mode = state.settings.search_mode or "items"
        local found = false

        if search_mode == "items" then
          -- Search only item names
          found = item_name:lower():find(search:lower(), 1, true) ~= nil
        elseif search_mode == "tracks" then
          -- Search only track names
          found = track_name:lower():find(search:lower(), 1, true) ~= nil
        elseif search_mode == "regions" then
          -- Search only region names
          if entry.regions then
            for _, region in ipairs(entry.regions) do
              local region_name = type(region) == "table" and region.name or region
              if region_name:lower():find(search:lower(), 1, true) then
                found = true
                break
              end
            end
          end
        elseif search_mode == "mixed" then
          -- Search all: item names, track names, and region names
          found = item_name:lower():find(search:lower(), 1, true) ~= nil or
                  track_name:lower():find(search:lower(), 1, true) ~= nil
          if not found and entry.regions then
            for _, region in ipairs(entry.regions) do
              local region_name = type(region) == "table" and region.name or region
              if region_name:lower():find(search:lower(), 1, true) then
                found = true
                break
              end
            end
          end
        end

        if not found then
          goto continue
        end
      end

      -- Check region filter (if any regions are selected)
      local has_selected_regions = state.selected_regions and next(state.selected_regions) ~= nil
      if has_selected_regions then
        -- Item must have at least one of the selected regions
        local item_has_selected_region = false
        if entry.regions then
          for _, region in ipairs(entry.regions) do
            local region_name = type(region) == "table" and region.name or region
            if state.selected_regions[region_name] then
              item_has_selected_region = true
              break
            end
          end
        end
        if not item_has_selected_region then
          goto continue
        end
      end

      -- Use cached track color (fetched during loading, not every frame!)
      local track_color = entry.track_color or 0

      -- DEBUG: Log track color values
      if not state._color_debug_logged then
        state._color_debug_logged = {}
      end
      if not state._color_debug_logged[track_color] then
        reaper.ShowConsoleMsg(string.format("[COLOR DEBUG MIDI] track_color = %d (0x%08X) for item: %s\n",
          track_color, track_color, item_name))
        state._color_debug_logged[track_color] = true
      end

      -- REAPER returns: ColorToNative(r,g,b) | 0x01000000 for colored items
      -- Check for the 0x01000000 flag to determine if item has a color
      local color
      if (track_color & 0x01000000) ~= 0 then
        -- Has color: mask off 0x01000000 flag and extract RGB from COLORREF (0x00BBGGRR)
        local colorref = track_color & 0x00FFFFFF
        local R = colorref & 255
        local G = (colorref >> 8) & 255
        local B = (colorref >> 16) & 255
        color = ImGui.ColorConvertDouble4ToU32(R/255, G/255, B/255, 1)
      else
        -- No color flag: use default grey
        color = ImGui.ColorConvertDouble4ToU32(85/255, 91/255, 91/255, 1)
      end

      table.insert(filtered, {
        track_guid = track_guid,
        item = item,
        name = item_name,
        index = current_position,  -- Position in filtered list (1, 2, 3...)
        total = filtered_count,  -- Total items in filtered list
        color = color,
        key = uuid,
        uuid = uuid,
        is_midi = true,
        pool_count = pool_count,  -- Number of pooled items (from Reaper pooling)
        track_name = track_name,  -- Track name for search
        regions = entry.regions,  -- Region tags from loader
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
    elseif sort_mode == "pool" then
      -- Sort by pool count (descending), then by name
      table.sort(filtered, function(a, b)
        local a_pool = a.pool_count or 1
        local b_pool = b.pool_count or 1
        if a_pool ~= b_pool then
          return a_pool > b_pool  -- Higher pool counts first
        else
          return (a.name or "") < (b.name or "")  -- Then alphabetically
        end
      end)
    end

    -- Cache result for next frame
    state.runtime_cache.midi_filtered = filtered
    state.runtime_cache.midi_filter_hash = filter_hash

    return filtered
  end

  -- Store badge rectangles for exclusion zones (tile_key -> rect)
  local badge_rects = {}

  local grid = Grid.new({
    id = "midi_items",
    gap = config.TILE.GAP,
    min_col_w = function() return state:get_tile_width() end,
    fixed_tile_h = state:get_tile_height(),
    layout_speed = 12.0,

    get_items = get_items,

    config = {
      drag = { threshold = 30 }
    },

    key = function(item_data)
      return item_data.uuid
    end,

    get_exclusion_zones = function(item_data, rect)
      -- Return badge rect as exclusion zone if it exists
      local badge_rect = badge_rects[item_data.uuid]
      return badge_rect and {badge_rect} or nil
    end,

    render_tile = function(ctx, rect, item_data, tile_state)
      local dl = ImGui.GetWindowDrawList(ctx)
      MidiRenderer.render(ctx, dl, rect, item_data, tile_state, config, animator, visualization, state, badge_rects)
    end,
  })

  -- Behaviors
  grid.behaviors = {
    right_click = function(key, selected_keys)
      -- Right-click toggles disabled state
      local items = get_items()
      local track_guid_map = {}
      for _, data in ipairs(items) do
        if data.uuid then
          track_guid_map[data.uuid] = data.track_guid
        end
      end

      if #selected_keys > 1 then
        -- Multi-select: toggle all to opposite of clicked item's state
        local clicked_track_guid = track_guid_map[key]
        local new_state = not state.disabled.midi[clicked_track_guid]
        for _, uuid in ipairs(selected_keys) do
          local track_guid = track_guid_map[uuid]
          if track_guid then
            if new_state then
              state.disabled.midi[track_guid] = true
            else
              state.disabled.midi[track_guid] = nil
            end
          end
        end
      else
        -- Single item: toggle
        local track_guid = track_guid_map[key]
        if track_guid then
          if state.disabled.midi[track_guid] then
            state.disabled.midi[track_guid] = nil
          else
            state.disabled.midi[track_guid] = true
          end
        end
      end
      state.persist_disabled()
      -- Force cache invalidation to refresh grid
      state.runtime_cache.midi_filter_hash = nil
    end,

    drag_start = function(keys)
      reaper.ShowConsoleMsg(string.format("[DRAG_START MIDI] Called! keys=%d\n", keys and #keys or 0))
      if not keys or #keys == 0 then return end

      -- Support multi-item drag (use first selected item for preview)
      local uuid = keys[1]
      reaper.ShowConsoleMsg(string.format("[DRAG_START MIDI] First UUID: %s\n", tostring(uuid)))

      -- O(1) lookup instead of O(n) search
      local item_lookup_data = state.midi_item_lookup[uuid]
      if not item_lookup_data then
        reaper.ShowConsoleMsg("[DRAG_START MIDI] Item not found in lookup!\n")
        return
      end

      local drag_w = math.min(200, state:get_tile_width())
      local drag_h = math.min(120, state:get_tile_height())

      -- Store all selected keys for batch insert
      state.dragging_keys = keys
      state.dragging_is_audio = false

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
        reaper.ShowConsoleMsg(string.format("[DRAG_START MIDI] Starting drag for: %s\n", display_data.name))
        state.start_drag(display_data.item, display_data.name, display_data.color, drag_w, drag_h)
      end
    end,

    favorite = function(item_uuids)
      -- Toggle favorite with F key
      local items = get_items()
      local track_guid_map = {}
      for _, data in ipairs(items) do
        if data.uuid then
          track_guid_map[data.uuid] = data.track_guid
        end
      end

      if #item_uuids > 1 then
        -- Multi-select: toggle all to opposite of first item's state
        local first_track_guid = track_guid_map[item_uuids[1]]
        local new_state = not state.is_midi_favorite(first_track_guid)
        for _, uuid in ipairs(item_uuids) do
          local track_guid = track_guid_map[uuid]
          if track_guid then
            if new_state then
              state.favorites.midi[track_guid] = true
            else
              state.favorites.midi[track_guid] = nil
            end
          end
        end
        state.persist_favorites()
      else
        -- Single item: toggle
        local track_guid = track_guid_map[item_uuids[1]]
        if track_guid then
          state.toggle_midi_favorite(track_guid)
        end
      end
    end,

    wheel_adjust = function(uuids, delta)
      reaper.ShowConsoleMsg(string.format("[WHEEL_ADJUST MIDI] Called! uuids=%d, delta=%d\n", uuids and #uuids or 0, delta or 0))
      if not uuids or #uuids == 0 then
        reaper.ShowConsoleMsg("[WHEEL_ADJUST MIDI] Empty uuids, returning\n")
        return nil
      end
      local uuid = uuids[1]

      -- Get track_guid from UUID
      local items = get_items()
      for _, data in ipairs(items) do
        if data.uuid == uuid then
          reaper.ShowConsoleMsg(string.format("[WHEEL_ADJUST MIDI] Cycling track: %s\n", data.track_guid))
          state.cycle_midi_item(data.track_guid, delta > 0 and 1 or -1)

          -- Rebuild items list after cycling to get new UUID
          state.runtime_cache.midi_filter_hash = nil  -- Force rebuild
          local updated_items = get_items()

          -- Find the new item with the same track_guid
          for _, updated_data in ipairs(updated_items) do
            if updated_data.track_guid == data.track_guid then
              reaper.ShowConsoleMsg(string.format("[WHEEL_ADJUST MIDI] New UUID: %s\n", updated_data.uuid))
              return updated_data.uuid
            end
          end

          return uuid  -- Fallback to old UUID if not found
        end
      end
      reaper.ShowConsoleMsg("[WHEEL_ADJUST MIDI] UUID not found in items\n")
      return nil
    end,

    delete = function(item_uuids)
      -- Toggle disable state for all selected items
      -- Convert UUIDs to track_guids
      local items = get_items()
      local track_guid_map = {}
      for _, data in ipairs(items) do
        if data.uuid then
          track_guid_map[data.uuid] = data.track_guid
        end
      end

      -- Determine toggle state: if first item is disabled, enable all; otherwise disable all
      if #item_uuids > 0 then
        local first_track_guid = track_guid_map[item_uuids[1]]
        local new_state = not state.disabled.midi[first_track_guid]

        for _, uuid in ipairs(item_uuids) do
          local track_guid = track_guid_map[uuid]
          if track_guid then
            if new_state then
              state.disabled.midi[track_guid] = true
            else
              state.disabled.midi[track_guid] = nil
            end
          end
        end
      end
      state.persist_disabled()
      -- Force cache invalidation to refresh grid
      state.runtime_cache.midi_filter_hash = nil
    end,


    on_select = function(selected_keys)
      -- Update state with current selection count
      state.midi_selection_count = #selected_keys
    end,

    play = function(selected_uuids)
      -- Preview selected items (use first selected)
      if not selected_uuids or #selected_uuids == 0 then return end

      local uuid = selected_uuids[1]
      local items = get_items()

      for _, item_data in ipairs(items) do
        if item_data.uuid == uuid then
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
          state.rename_is_audio = false
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
          state.rename_is_audio = false
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
