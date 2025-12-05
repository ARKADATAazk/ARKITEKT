-- @noindex
-- ItemPicker/ui/grids/factories/midi.lua
-- Factory for creating MIDI items grid

local ImGui = require('arkitekt.core.imgui')
local Ark = require('arkitekt')
local MidiRenderer = require('ItemPicker.ui.grids.renderers.midi')
local shared = require('ItemPicker.ui.grids.factories.shared')
local ItemsService = require('ItemPicker.domain.items.service')

local M = {}

function M.create_options(config, state, visualization, animator, disable_animator)
  -- Stores reference to grid result for selection cleanup
  local grid_result_ref = { current = nil }

  local function get_items()
    if not state.midi_indexes then return {} end

    -- Compute filter hash to detect changes
    local filter_hash = shared.build_filter_hash(state.settings, state.midi_indexes)

    -- Return cached result if filters haven't changed
    if state.runtime_cache.midi_filter_hash == filter_hash and state.runtime_cache.midi_filtered then
      return state.runtime_cache.midi_filtered
    end

    -- Filters changed - rebuild filtered list
    local filtered = {}
    for _, track_guid in ipairs(state.midi_indexes) do
      -- Check favorites and disabled filters
      if not shared.passes_favorites_filter(state.settings, state.favorites.midi, track_guid) then
        goto continue
      end
      if not shared.passes_disabled_filter(state.settings, state.disabled.midi, track_guid) then
        goto continue
      end

      local content = state.midi_items[track_guid]
      if not content or #content == 0 then
        goto continue
      end

      -- Get current item index and filtered position
      local current_idx = state.box_current_midi_track[track_guid] or 1
      if current_idx > #content then current_idx = 1 end

      local current_position, filtered_count = shared.get_filtered_position(content, current_idx)

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
      local track_name = entry.track_name or ''

      -- Safety check: ensure item_name is a valid string
      if not item_name or type(item_name) ~= 'string' then
        goto continue
      end

      -- Check mute and search filters
      if not shared.passes_mute_filters(state.settings, track_muted, item_muted) then
        goto continue
      end
      if not shared.passes_search_filter(state.settings, item_name, track_name, entry.regions) then
        goto continue
      end

      -- Check region filter (if any regions are selected)
      local has_selected_regions = state.selected_regions and next(state.selected_regions) ~= nil
      if has_selected_regions then
        local filter_mode = state.settings.region_filter_mode or 'or'
        local passes_filter = false

        if not entry.regions or #entry.regions == 0 then
          -- No regions on item = doesn't pass filter
          passes_filter = false
        elseif filter_mode == 'and' then
          -- AND mode: item must have ALL selected regions
          passes_filter = true
          for region_name, _ in pairs(state.selected_regions) do
            local found = false
            for _, region in ipairs(entry.regions) do
              local name = type(region) == 'table' and region.name or region
              if name == region_name then
                found = true
                break
              end
            end
            if not found then
              passes_filter = false
              break
            end
          end
        else
          -- OR mode: item must have at least one selected region
          for _, region in ipairs(entry.regions) do
            local region_name = type(region) == 'table' and region.name or region
            if state.selected_regions[region_name] then
              passes_filter = true
              break
            end
          end
        end

        if not passes_filter then
          goto continue
        end
      end

      -- Check track filter (use entry.track_guid if available, otherwise use loop track_guid)
      local item_track_guid = entry.track_guid or track_guid
      if not shared.passes_track_filter(state, item_track_guid) then
        goto continue
      end

      -- Convert cached track color to ImGui color
      local color = shared.convert_track_color(entry.track_color or 0)

      -- PERF: Cache duration to avoid GetMediaItemInfo_Value calls in renderer
      local duration = (item and reaper.ValidatePtr2(0, item, 'MediaItem*')) and reaper.GetMediaItemInfo_Value(item, 'D_LENGTH') or 0

      filtered[#filtered + 1] = {
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
        track_muted = track_muted,  -- Track mute state
        item_muted = item_muted,  -- Item mute state
        duration = duration,  -- Cached duration for renderer
      }

      ::continue::
    end

    -- Apply sorting
    local sort_mode = state.settings.sort_mode or 'none'
    local sort_reverse = state.settings.sort_reverse or false

    if sort_mode == 'length' then
      -- Sort by item length/duration (using cached duration)
      table.sort(filtered, function(a, b)
        local a_len = a.duration or 0
        local b_len = b.duration or 0
        if sort_reverse then
          return a_len > b_len  -- Longest first
        else
          return a_len < b_len  -- Shortest first
        end
      end)
    elseif sort_mode == 'color' then
      -- Sort by color using library's color comparison
      -- Uses HSL: Hue → Saturation (desc) → Lightness (desc)
      -- Grays (sat < 0.08) are grouped at the end
      table.sort(filtered, function(a, b)
        if sort_reverse then
          return Ark.Colors.CompareColors(b.color, a.color)
        else
          return Ark.Colors.CompareColors(a.color, b.color)
        end
      end)
    elseif sort_mode == 'name' then
      -- Sort alphabetically by name
      table.sort(filtered, function(a, b)
        if sort_reverse then
          return a.name:lower() > b.name:lower()
        else
          return a.name:lower() < b.name:lower()
        end
      end)
    elseif sort_mode == 'pool' then
      -- Sort by pool count (descending), then by name
      table.sort(filtered, function(a, b)
        local a_pool = a.pool_count or 1
        local b_pool = b.pool_count or 1
        if a_pool ~= b_pool then
          if sort_reverse then
            return a_pool < b_pool  -- Lower pool counts first
          else
            return a_pool > b_pool  -- Higher pool counts first
          end
        else
          return (a.name or '') < (b.name or '')  -- Then alphabetically
        end
      end)
    end

    -- Cache result for next frame
    state.runtime_cache.midi_filtered = filtered
    state.runtime_cache.midi_filter_hash = filter_hash

    -- Smart selection cleanup: deselect items that are no longer accessible
    if grid_result_ref.current and grid_result_ref.current.selection then
      local available_keys = {}
      for _, item_data in ipairs(filtered) do
        available_keys[item_data.uuid] = true
      end

      local selected = grid_result_ref.current.selection:selected_keys()
      local needs_update = false
      for _, key in ipairs(selected) do
        if not available_keys[key] then
          grid_result_ref.current.selection.selected[key] = nil
          needs_update = true
        end
      end

      if needs_update and on_select_behavior then
        on_select_behavior(grid_result_ref.current, grid_result_ref.current.selection:selected_keys())
      end
    end

    return filtered
  end

  -- Store badge rectangles for exclusion zones (tile_key -> rect)
  local badge_rects = {}

  -- Behavior callbacks (forward declared for use in get_items)
  local on_select_behavior

  -- PERF: Badge click handler - called from coordinator after all tiles rendered
  -- Returns true if click was consumed
  local function handle_badge_click(ctx)
    local left_click = ImGui.IsMouseClicked(ctx, 0)
    local right_click = ImGui.IsMouseClicked(ctx, 1)
    if not left_click and not right_click then return false end

    local mx, my = ImGui.GetMousePos(ctx)
    for uuid, rect in pairs(badge_rects) do
      if mx >= rect[1] and mx <= rect[3] and my >= rect[2] and my <= rect[4] then
        -- Find the item to get track_guid
        local items = get_items()
        for _, item_data in ipairs(items) do
          if item_data.uuid == uuid and item_data.total and item_data.total > 1 then
            local delta = left_click and 1 or -1
            state.cycle_midi_item(item_data.track_guid, delta)
            state.runtime_cache.midi_filter_hash = nil
            return true
          end
        end
      end
    end
    return false
  end

  -- Grid options (returned for callable API)
  local grid_opts = {
    id = 'midi_items',
    gap = config.TILE.GAP,
    min_col_w = function() return state.get_tile_width() end,
    fixed_tile_h = state.get_tile_height(),
    layout_speed = 12.0,

    get_items = get_items,

    -- Extend input area upward to include panel header for selection rectangle
    extend_input_area = { left = 0, right = 0, top = config.UI_PANELS.header.height, bottom = 0 },

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

    render_item = function(ctx, rect, item_data, tile_state)
      local dl = ImGui.GetWindowDrawList(ctx)
      MidiRenderer.render(ctx, dl, rect, item_data, tile_state, config, animator, visualization, state, badge_rects, disable_animator)
    end,

    -- Behaviors (using generic shortcut names)
    behaviors = {
    -- Right-click: toggle disabled state
    ['click:right'] = function(grid, key, selected_keys)
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

    drag_start = function(grid, keys)
      -- Don't start drag if we're closing
      if state.should_close_after_drop then
        return
      end

      if not keys or #keys == 0 then return end

      -- Support multi-item drag (use first selected item for preview)
      local uuid = keys[1]

      -- O(1) lookup instead of O(n) search
      local item_lookup_data = state.midi_item_lookup[uuid]
      if not item_lookup_data then
        return
      end

      local drag_w = math.min(200, state.get_tile_width())
      local drag_h = math.min(120, state.get_tile_height())

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
        local is_source_pooled = (display_data.pool_count or 1) > 1
        state.start_drag(display_data.item, display_data.name, display_data.color, drag_w, drag_h, is_source_pooled)
      end
    end,

    -- F key: toggle favorite
    f = function(grid, keys)
      if not keys or #keys == 0 then return end

      local items = get_items()
      local track_guid_map = {}
      for _, data in ipairs(items) do
        if data.uuid then
          track_guid_map[data.uuid] = data.track_guid
        end
      end

      if #keys > 1 then
        -- Multi-select: toggle all to opposite of first item's state
        local first_track_guid = track_guid_map[keys[1]]
        local new_state = not state.is_midi_favorite(first_track_guid)
        for _, key in ipairs(keys) do
          local track_guid = track_guid_map[key]
          if track_guid then
            if new_state then
              state.favorites.midi[track_guid] = true
            else
              state.favorites.midi[track_guid] = nil
            end
          end
        end
      else
        -- Single item: toggle
        local track_guid = track_guid_map[keys[1]]
        if track_guid then
          state.toggle_midi_favorite(track_guid)
        end
      end
      state.persist_favorites()
      state.runtime_cache.midi_filter_hash = nil
    end,

    -- Wheel cycling through pooled items
    wheel_cycle = function(grid, keys, delta)
      if not keys or #keys == 0 then
        return nil
      end
      local key = keys[1]

      -- Get track_guid from UUID
      local items = get_items()
      for _, data in ipairs(items) do
        if data.uuid == key then
          state.cycle_midi_item(data.track_guid, delta > 0 and 1 or -1)

          -- Rebuild items list after cycling to get new UUID
          state.runtime_cache.midi_filter_hash = nil  -- Force rebuild
          local updated_items = get_items()

          -- Find the new item with the same track_guid
          for _, updated_data in ipairs(updated_items) do
            if updated_data.track_guid == data.track_guid then
              return updated_data.uuid
            end
          end

          return key  -- Fallback to old key if not found
        end
      end
      return nil
    end,

    -- Delete key: toggle disable state
    delete = function(grid, keys)
      local items = get_items()
      local track_guid_map = {}
      for _, data in ipairs(items) do
        if data.uuid then
          track_guid_map[data.uuid] = data.track_guid
        end
      end

      -- Determine toggle state: if first item is disabled, enable all; otherwise disable all
      if #keys > 0 then
        local first_track_guid = track_guid_map[keys[1]]
        local new_state = not state.disabled.midi[first_track_guid]

        for _, key in ipairs(keys) do
          local track_guid = track_guid_map[key]
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

    on_select = function(grid, keys)
      -- Update state with current selection count
      state.midi_selection_count = #keys
    end,

    -- ENTER: Insert selected items at edit cursor
    enter = function(grid, keys)
      if not keys or #keys == 0 then return end
      ItemsService.insert_items_at_cursor(keys, state, false, false)  -- is_audio=false
      -- Mark all inserted items as used (for "recent" sort)
      for _, uuid in ipairs(keys) do
        state.mark_item_used(uuid)
      end
    end,

    -- SPACE: Preview
    space = function(grid, keys)
      if not keys or #keys == 0 then return end

      local key = keys[1]
      local items = get_items()

      for _, item_data in ipairs(items) do
        if item_data.uuid == key then
          -- Toggle preview: stop if this exact item is playing, otherwise start/switch
          if state.is_previewing(item_data.item) then
            state.stop_preview()
          else
            -- MIDI always uses preview through track
            state.start_preview(item_data.item)
          end
          return
        end
      end
    end,

    -- Double-click: preview (always plays, restarts if same item)
    double_click = function(grid, key)
      local items = get_items()
      for _, item_data in ipairs(items) do
        if item_data.uuid == key then
          -- Always stop current and start new (restarts if same item)
          state.stop_preview()
          state.start_preview(item_data.item)
          return
        end
      end
    end,

    -- F2: batch rename
    f2 = function(grid, keys)
      if not keys or #keys == 0 then return end

      -- Start with first selected item
      local uuid = keys[1]
      local items = get_items()

      for _, item_data in ipairs(items) do
        if item_data.uuid == uuid then
          state.rename_active = true
          state.rename_uuid = uuid
          state.rename_text = item_data.name
          state.rename_is_audio = false
          state.rename_focused = false  -- Reset focus flag
          state.rename_queue = keys  -- Store all selected for batch rename
          state.rename_queue_index = 1
          return
        end
      end
    end,

    -- Hover change: reset auto-preview tracking
    on_hover = function(grid, new_key, prev_key)
      -- Reset auto-preview trigger when hover changes
      state.auto_preview_triggered_key = nil

      -- Stop preview when leaving all tiles (if auto-preview is active)
      if not new_key and state.settings.auto_preview_on_hover and state.auto_preview_active then
        state.stop_preview()
        state.auto_preview_active = false
      end
    end,

    -- Hover tick: auto-preview after delay
    on_hover_tick = function(grid, key, elapsed)
      -- Check if auto-preview is enabled
      if not state.settings.auto_preview_on_hover then return end

      -- Check if we already triggered preview for this key
      if state.auto_preview_triggered_key == key then return end

      -- Check if delay has been met
      local delay = state.settings.auto_preview_delay or 0.3
      if elapsed < delay then return end

      -- Find the item and start preview
      local items = get_items()
      for _, item_data in ipairs(items) do
        if item_data.uuid == key then
          state.auto_preview_triggered_key = key
          state.auto_preview_active = true
          state.start_preview(item_data.item)
          return
        end
      end
    end,
    },  -- end behaviors
  }  -- end grid_opts

  -- Store on_select for use in get_items cleanup
  on_select_behavior = grid_opts.behaviors.on_select

  -- Return options table, result reference, and badge click handler
  return grid_opts, grid_result_ref, handle_badge_click
end

return M
