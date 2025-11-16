-- @noindex
-- ItemPicker/ui/tiles/factories/midi_grid_factory.lua
-- Factory for creating MIDI items grid

local ImGui = require 'imgui' '0.10'
local Grid = require('rearkitekt.gui.widgets.containers.grid.core')
local MidiRenderer = require('ItemPicker.ui.tiles.renderers.midi')

local M = {}

function M.create(ctx, config, state, visualization, cache_mgr, animator)
  local function get_items()
    if not state.midi_indexes then return {} end

    local filtered = {}
    for _, track_guid in ipairs(state.midi_indexes) do
      -- Check disabled filter
      if not state.settings.show_disabled_items and state.disabled.midi[track_guid] then
        goto continue
      end

      local content = state.midi_items[track_guid]
      if not content or #content == 0 then
        goto continue
      end

      -- Get current item index
      local current_idx = state.box_current_midi_track[track_guid] or 1
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
        track_guid = track_guid,
        item = item,
        name = item_name,
        index = current_idx,
        total = #content,
        color = color,
        key = uuid,
        uuid = uuid,
        is_midi = true,
      })

      ::continue::
    end

    return filtered
  end

  local grid = Grid.new({
    id = "midi_items",
    gap = config.TILE.GAP,
    min_col_w = function() return state:get_tile_width() end,
    fixed_tile_h = state:get_tile_height(),

    get_items = get_items,

    key = function(item_data)
      return item_data.uuid
    end,

    render_tile = function(ctx, rect, item_data, tile_state)
      local dl = ImGui.GetWindowDrawList(ctx)
      MidiRenderer.render(ctx, dl, rect, item_data, tile_state, config, animator, visualization, cache_mgr, state)
    end,
  })

  -- Behaviors
  grid.behaviors = {
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

    right_click = function(uuid, selected_uuids)
      -- Toggle disabled state for all selected items
      -- Need to get track_guid from UUID lookup
      local item_data = state.midi_item_lookup[uuid]
      if not item_data then return end

      local items = get_items()
      local track_guid_map = {}
      for _, data in ipairs(items) do
        if data.uuid then
          track_guid_map[data.uuid] = data.track_guid
        end
      end

      if #selected_uuids > 1 then
        -- Multi-select: toggle all to the opposite of clicked item's state
        local clicked_track_guid = track_guid_map[uuid]
        local new_state = not state.is_midi_disabled(clicked_track_guid)
        for _, sel_uuid in ipairs(selected_uuids) do
          local sel_track_guid = track_guid_map[sel_uuid]
          if sel_track_guid then
            if new_state then
              state.disabled.midi[sel_track_guid] = true
            else
              state.disabled.midi[sel_track_guid] = nil
            end
          end
        end
        state.persist_disabled()
      else
        -- Single item: toggle
        local track_guid = track_guid_map[uuid]
        if track_guid then
          state.toggle_midi_disabled(track_guid)
        end
      end
    end,

    wheel_adjust = function(uuids, delta)
      if not uuids or #uuids == 0 then return end
      local uuid = uuids[1]

      -- Get track_guid from UUID
      local items = get_items()
      for _, data in ipairs(items) do
        if data.uuid == uuid then
          state.cycle_midi_item(data.track_guid, delta > 0 and 1 or -1)
          return
        end
      end
    end,

    delete = function(item_uuids)
      -- Disable all selected items
      -- Convert UUIDs to track_guids
      local items = get_items()
      local track_guid_map = {}
      for _, data in ipairs(items) do
        if data.uuid then
          track_guid_map[data.uuid] = data.track_guid
        end
      end

      for _, uuid in ipairs(item_uuids) do
        local track_guid = track_guid_map[uuid]
        if track_guid then
          state.disabled.midi[track_guid] = true
        end
      end
      state.persist_disabled()
    end,

    alt_click = function(item_uuids)
      -- Quick disable with Alt+click
      -- Convert UUIDs to track_guids
      local items = get_items()
      local track_guid_map = {}
      for _, data in ipairs(items) do
        if data.uuid then
          track_guid_map[data.uuid] = data.track_guid
        end
      end

      for _, uuid in ipairs(item_uuids) do
        local track_guid = track_guid_map[uuid]
        if track_guid then
          state.disabled.midi[track_guid] = true
        end
      end
      state.persist_disabled()
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
  }

  return grid
end

return M
