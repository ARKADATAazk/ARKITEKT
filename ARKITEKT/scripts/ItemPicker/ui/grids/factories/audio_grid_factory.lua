-- @noindex
-- ItemPicker/ui/tiles/factories/audio_grid_factory.lua
-- Factory for creating audio items grid

local ImGui = require 'imgui' '0.10'
local Colors = require('arkitekt.core.colors')
local Grid = require('arkitekt.gui.widgets.containers.grid.core')
local AudioRenderer = require('ItemPicker.ui.grids.renderers.audio')
local shared = require('ItemPicker.ui.grids.factories.grid_factory_shared')

local M = {}

function M.create(ctx, config, state, visualization, animator)
  local grid  -- Forward declaration for selection cleanup

  local function get_items()
    if not state.sample_indexes then return {} end

    -- Compute filter hash to detect changes
    local filter_hash = shared.build_filter_hash(state.settings, state.sample_indexes)

    -- Return cached result if filters haven't changed
    if state.runtime_cache.audio_filter_hash == filter_hash and state.runtime_cache.audio_filtered then
      return state.runtime_cache.audio_filtered
    end

    -- Filters changed - rebuild filtered list
    local filtered = {}
    for _, filename in ipairs(state.sample_indexes) do
      -- Check favorites and disabled filters
      if not shared.passes_favorites_filter(state.settings, state.favorites.audio, filename) then
        goto continue
      end
      if not shared.passes_disabled_filter(state.settings, state.disabled.audio, filename) then
        goto continue
      end

      local content = state.samples[filename]
      if not content or #content == 0 then
        goto continue
      end

      -- Get current item index and filtered position
      local current_idx = state.box_current_item[filename] or 1
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
      local track_name = entry.track_name or ""

      -- Safety check: ensure item_name is a valid string
      if not item_name or type(item_name) ~= "string" then
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

      -- Check track filter
      if not shared.passes_track_filter(state, entry.track_guid) then
        goto continue
      end

      -- Convert cached track color to ImGui color
      local color = shared.convert_track_color(entry.track_color or 0)

      table.insert(filtered, {
        filename = filename,
        item = item,
        name = item_name,
        index = current_position,  -- Position in filtered list (1, 2, 3...)
        total = filtered_count,  -- Total items in filtered list
        color = color,
        key = uuid,
        uuid = uuid,
        pool_count = pool_count,  -- Number of pooled items (from Reaper pooling)
        track_name = track_name,  -- Track name for search
        regions = entry.regions,  -- Region tags from loader
        track_muted = track_muted,  -- Track mute state
        item_muted = item_muted,  -- Item mute state
      })

      ::continue::
    end

    -- Apply sorting
    local sort_mode = state.settings.sort_mode or "none"
    local sort_reverse = state.settings.sort_reverse or false

    if sort_mode == "length" then
      -- Sort by item length/duration
      table.sort(filtered, function(a, b)
        local a_len = 0
        local b_len = 0
        if a.item then
          a_len = reaper.GetMediaItemInfo_Value(a.item, "D_LENGTH")
        end
        if b.item then
          b_len = reaper.GetMediaItemInfo_Value(b.item, "D_LENGTH")
        end
        if sort_reverse then
          return a_len > b_len  -- Longest first
        else
          return a_len < b_len  -- Shortest first
        end
      end)
    elseif sort_mode == "color" then
      -- Sort by color using library's color comparison
      -- Uses HSL: Hue → Saturation (desc) → Lightness (desc)
      -- Grays (sat < 0.08) are grouped at the end
      table.sort(filtered, function(a, b)
        if sort_reverse then
          return Colors.compare_colors(b.color, a.color)
        else
          return Colors.compare_colors(a.color, b.color)
        end
      end)
    elseif sort_mode == "name" then
      -- Sort alphabetically by name
      table.sort(filtered, function(a, b)
        if sort_reverse then
          return a.name:lower() > b.name:lower()
        else
          return a.name:lower() < b.name:lower()
        end
      end)
    elseif sort_mode == "pool" then
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
          return (a.name or "") < (b.name or "")  -- Then alphabetically
        end
      end)
    end

    -- Cache result for next frame
    state.runtime_cache.audio_filtered = filtered
    state.runtime_cache.audio_filter_hash = filter_hash

    -- Smart selection cleanup: deselect items that are no longer accessible
    if grid and grid.selection then
      local available_keys = {}
      for _, item_data in ipairs(filtered) do
        available_keys[item_data.uuid] = true
      end

      local selected = grid.selection:selected_keys()
      local needs_update = false
      for _, key in ipairs(selected) do
        if not available_keys[key] then
          grid.selection.selected[key] = nil
          needs_update = true
        end
      end

      if needs_update and grid.behaviors and grid.behaviors.on_select then
        grid.behaviors.on_select(grid, grid.selection:selected_keys())
      end
    end

    return filtered
  end

  -- Store badge rectangles for exclusion zones (tile_key -> rect)
  local badge_rects = {}

  grid = Grid.new({
    id = "audio_items",
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

    render_tile = function(ctx, rect, item_data, tile_state)
      local dl = ImGui.GetWindowDrawList(ctx)
      AudioRenderer.render(ctx, dl, rect, item_data, tile_state, config, animator, visualization, state, badge_rects)
    end,
  })

  -- Behaviors (using generic shortcut names)
  grid.behaviors = {
    drag_start = function(grid, keys)
      -- Don't start drag if we're closing
      if state.should_close_after_drop then
        return
      end

      if not keys or #keys == 0 then return end

      -- Support multi-item drag (use first selected item for preview)
      local uuid = keys[1]

      -- O(1) lookup instead of O(n) search
      local item_lookup_data = state.audio_item_lookup[uuid]
      if not item_lookup_data then
        return
      end

      local drag_w = math.min(200, state.get_tile_width())
      local drag_h = math.min(120, state.get_tile_height())

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
        local is_source_pooled = (display_data.pool_count or 1) > 1
        state.start_drag(display_data.item, display_data.name, display_data.color, drag_w, drag_h, is_source_pooled)
      end
    end,

    -- Right-click: toggle disabled state
    ['click:right'] = function(grid, key, selected_keys)
      local items = get_items()
      local filename_map = {}
      for _, data in ipairs(items) do
        if data.uuid then
          filename_map[data.uuid] = data.filename
        end
      end

      if #selected_keys > 1 then
        -- Multi-select: toggle all to opposite of clicked item's state
        local clicked_filename = filename_map[key]
        local new_state = not state.disabled.audio[clicked_filename]
        for _, uuid in ipairs(selected_keys) do
          local filename = filename_map[uuid]
          if filename then
            if new_state then
              state.disabled.audio[filename] = true
            else
              state.disabled.audio[filename] = nil
            end
          end
        end
      else
        -- Single item: toggle
        local filename = filename_map[key]
        if filename then
          if state.disabled.audio[filename] then
            state.disabled.audio[filename] = nil
          else
            state.disabled.audio[filename] = true
          end
        end
      end
      state.persist_disabled()
      -- Force cache invalidation to refresh grid
      state.runtime_cache.audio_filter_hash = nil
    end,

    -- F key: toggle favorite
    f = function(grid, keys)
      local items = get_items()
      local filename_map = {}
      for _, data in ipairs(items) do
        if data.uuid then
          filename_map[data.uuid] = data.filename
        end
      end

      if #keys > 1 then
        -- Multi-select: toggle all to opposite of first item's state
        local first_filename = filename_map[keys[1]]
        local new_state = not state.is_audio_favorite(first_filename)
        for _, key in ipairs(keys) do
          local filename = filename_map[key]
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
        local filename = filename_map[keys[1]]
        if filename then
          state.toggle_audio_favorite(filename)
        end
      end
    end,

    -- Wheel cycling through pooled items
    wheel_cycle = function(grid, keys, delta)
      if not keys or #keys == 0 then
        return nil
      end
      local key = keys[1]

      -- Get filename from UUID
      local items = get_items()
      for _, data in ipairs(items) do
        if data.uuid == key then
          state.cycle_audio_item(data.filename, delta > 0 and 1 or -1)

          -- Rebuild items list after cycling to get new UUID
          state.runtime_cache.audio_filter_hash = nil  -- Force rebuild
          local updated_items = get_items()

          -- Find the new item with the same filename
          for _, updated_data in ipairs(updated_items) do
            if updated_data.filename == data.filename then
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
      local filename_map = {}
      for _, data in ipairs(items) do
        if data.uuid then
          filename_map[data.uuid] = data.filename
        end
      end

      -- Determine toggle state: if first item is disabled, enable all; otherwise disable all
      if #keys > 0 then
        local first_filename = filename_map[keys[1]]
        local new_state = not state.disabled.audio[first_filename]

        for _, key in ipairs(keys) do
          local filename = filename_map[key]
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
      -- Force cache invalidation to refresh grid
      state.runtime_cache.audio_filter_hash = nil
    end,

    on_select = function(grid, keys)
      -- Update state with current selection count
      state.audio_selection_count = #keys
    end,

    -- SPACE: Preview (default mode)
    space = function(grid, keys)
      if not keys or #keys == 0 then return end

      local key = keys[1]
      local items = get_items()

      for _, item_data in ipairs(items) do
        if item_data.key == key then
          -- Toggle preview: stop if this exact item is playing, otherwise start/switch
          if state.is_previewing(item_data.item) then
            state.stop_preview()
          else
            state.start_preview(item_data.item) -- Use default mode (respects setting)
          end
          return
        end
      end
    end,

    -- CTRL+SPACE: Force play through track (with FX)
    ['space:ctrl'] = function(grid, keys)
      if not keys or #keys == 0 then return end

      local key = keys[1]
      local items = get_items()

      for _, item_data in ipairs(items) do
        if item_data.key == key then
          if state.is_previewing(item_data.item) then
            state.stop_preview()
          else
            state.start_preview(item_data.item, "through_track")
          end
          return
        end
      end
    end,

    -- SHIFT+SPACE: Force direct preview (no FX)
    ['space:shift'] = function(grid, keys)
      if not keys or #keys == 0 then return end

      local key = keys[1]
      local items = get_items()

      for _, item_data in ipairs(items) do
        if item_data.key == key then
          if state.is_previewing(item_data.item) then
            state.stop_preview()
          else
            state.start_preview(item_data.item, "direct")
          end
          return
        end
      end
    end,

    -- Double-click: start rename
    double_click = function(grid, key)
      local items = get_items()
      for _, item_data in ipairs(items) do
        if item_data.uuid == key then
          state.rename_active = true
          state.rename_uuid = key
          state.rename_text = item_data.name
          state.rename_is_audio = true
          state.rename_focused = false  -- Reset focus flag
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
          state.rename_is_audio = true
          state.rename_focused = false  -- Reset focus flag
          state.rename_queue = keys  -- Store all selected for batch rename
          state.rename_queue_index = 1
          return
        end
      end
    end,
  }

  return grid
end

return M
