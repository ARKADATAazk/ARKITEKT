-- @noindex
-- ItemPicker/ui/components/track_filter.lua
-- Track whitelist filter modal with tile-style TreeView

local ImGui = require('arkitekt.core.imgui')
local Ark = require('arkitekt')
local TrackFilter = require('ItemPicker.domain.filters.track')
local Palette = require('ItemPicker.config.palette')

local M = {}

-- Tile styling constants
local TRACK_TILE = {
  HEIGHT = 18,
  PADDING_X = 6,
  PADDING_Y = 2,
  MARGIN_Y = 1,
  ROUNDING = 3,
  COLOR_BAR_WIDTH = 3,
  INDENT = 16,
}

-- Build track hierarchy (domain layer now includes display_color)
function M.build_track_tree()
  return TrackFilter.build_track_tree()
end

-- Re-export domain functions for backward compatibility
local is_effectively_selected = TrackFilter.is_effectively_selected
local is_parent_disabled = TrackFilter.is_parent_disabled
local get_track_path = TrackFilter.get_track_path

-- Draw a single track tile
local function draw_track_tile(ctx, draw_list, x, y, width, track_data, is_selected, is_hovered, depth, is_expanded, has_children, parent_disabled, palette)
  local height = TRACK_TILE.HEIGHT
  local rounding = TRACK_TILE.ROUNDING
  local indent = depth * TRACK_TILE.INDENT

  local tile_x = x + indent
  local tile_w = width - indent

  -- Dim everything if parent is disabled
  local dim_factor = parent_disabled and 0.4 or 1.0

  -- Background
  local bg_alpha = is_selected and 0xCC or (is_hovered and 0x66 or 0x33)
  bg_alpha = (bg_alpha * dim_factor) // 1
  local bg_color = palette.panel_bg_alt or 0x2A2A2AFF
  bg_color = Ark.Colors.WithAlpha(bg_color, bg_alpha)

  ImGui.DrawList_AddRectFilled(draw_list, tile_x, y, tile_x + tile_w, y + height, bg_color, rounding)

  -- Color bar on the left
  local bar_alpha = is_selected and 0xFF or 0x88
  bar_alpha = (bar_alpha * dim_factor) // 1
  local bar_color = Ark.Colors.WithAlpha(track_data.display_color, bar_alpha)

  ImGui.DrawList_AddRectFilled(draw_list,
    tile_x, y,
    tile_x + TRACK_TILE.COLOR_BAR_WIDTH, y + height,
    bar_color, rounding, ImGui.DrawFlags_RoundCornersLeft)

  -- Expand/collapse arrow for folders
  local text_offset = TRACK_TILE.COLOR_BAR_WIDTH + TRACK_TILE.PADDING_X
  if has_children then
    local arrow_x = tile_x + text_offset
    local arrow_y = y + (height - 6) / 2
    local arrow_alpha = (0x88 * dim_factor) // 1
    local arrow_color = Ark.Colors.WithAlpha(palette.arrow or 0x888888FF, arrow_alpha)

    if is_expanded then
      -- Down arrow
      ImGui.DrawList_AddTriangleFilled(draw_list,
        arrow_x, arrow_y,
        arrow_x + 6, arrow_y,
        arrow_x + 3, arrow_y + 5,
        arrow_color)
    else
      -- Right arrow
      ImGui.DrawList_AddTriangleFilled(draw_list,
        arrow_x, arrow_y,
        arrow_x, arrow_y + 6,
        arrow_x + 5, arrow_y + 3,
        arrow_color)
    end
    text_offset = text_offset + 10
  end

  -- Track name
  local text_x = tile_x + text_offset
  local text_y = y + (height - ImGui.GetTextLineHeight(ctx)) / 2

  local text_alpha = is_selected and 0xFF or 0xAA
  text_alpha = (text_alpha * dim_factor) // 1
  local text_color = Ark.Colors.WithAlpha(palette.text_primary or 0xFFFFFFFF, text_alpha)

  ImGui.DrawList_AddText(draw_list, text_x, text_y, text_color, track_data.name)

  -- Selection indicator (only show if not parent-disabled)
  if is_selected and not parent_disabled then
    local indicator_size = 6
    local indicator_x = tile_x + tile_w - TRACK_TILE.PADDING_X - indicator_size
    local indicator_y = y + (height - indicator_size) / 2
    local indicator_color = palette.filter_indicator or 0x42E896FF

    ImGui.DrawList_AddCircleFilled(draw_list,
      indicator_x + indicator_size/2, indicator_y + indicator_size/2,
      indicator_size/2, indicator_color)
  end

  return height
end

-- Check if track name matches search (case-insensitive)
local function track_matches_search(track, search_lower)
  if not search_lower or search_lower == '' then return true end
  local name_lower = track.name:lower()
  return name_lower:find(search_lower, 1, true) ~= nil
end

-- Check if track or any descendant matches search
local function track_or_children_match(track, search_lower)
  if track_matches_search(track, search_lower) then return true end
  if track.children then
    for _, child in ipairs(track.children) do
      if track_or_children_match(child, search_lower) then return true end
    end
  end
  return false
end

-- Recursive function to draw track tree
local function draw_track_tree(ctx, draw_list, tracks, x, y, width, state, depth, current_y, visible_tracks_list, palette, search_lower)
  depth = depth or 0
  palette = palette or Palette.get()
  current_y = current_y or y
  visible_tracks_list = visible_tracks_list or {}

  local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
  local left_clicked = ImGui.IsMouseClicked(ctx, ImGui.MouseButton_Left)
  local left_down = ImGui.IsMouseDown(ctx, ImGui.MouseButton_Left)
  local left_released = ImGui.IsMouseReleased(ctx, ImGui.MouseButton_Left)
  local right_clicked = ImGui.IsMouseClicked(ctx, ImGui.MouseButton_Right)
  local right_down = ImGui.IsMouseDown(ctx, ImGui.MouseButton_Right)
  local right_released = ImGui.IsMouseReleased(ctx, ImGui.MouseButton_Right)

  -- Stop painting on mouse release
  if left_released or right_released then
    state.track_filter_painting = false
    state.track_filter_paint_value = nil
    state.track_filter_last_painted = nil
    state.track_filter_paint_mode = nil  -- 'enable' or 'disable'
    state.track_filter_prev_mouse_y = nil  -- Reset cursor tracking
  end

  for _, track in ipairs(tracks) do
    -- Skip tracks that don't match search (check self and children)
    if search_lower and search_lower ~= '' and not track_or_children_match(track, search_lower) then
      goto continue_track
    end
    local tile_y = current_y
    local indent = depth * TRACK_TILE.INDENT
    local tile_x = x + indent
    local tile_w = width - indent

    -- Check hover (include margin/gap after track for seamless painting)
    local is_hovered = mouse_x >= tile_x and mouse_x <= tile_x + tile_w and
                       mouse_y >= tile_y and mouse_y <= tile_y + TRACK_TILE.HEIGHT + TRACK_TILE.MARGIN_Y

    -- Check selection state
    local is_selected = state.track_whitelist and state.track_whitelist[track.guid]
    if is_selected == nil then is_selected = true end  -- Default to selected

    -- Check if expanded
    local has_children = track.children and #track.children > 0
    local is_expanded = state.track_expanded and state.track_expanded[track.guid]
    if is_expanded == nil then is_expanded = true end  -- Default expanded

    -- Check if over arrow area (for expand/collapse)
    local arrow_x = tile_x + TRACK_TILE.COLOR_BAR_WIDTH + TRACK_TILE.PADDING_X
    local over_arrow = has_children and mouse_x >= arrow_x and mouse_x <= arrow_x + 12

    -- Handle left click/drag: ENABLE tracks
    local shift_down = ImGui.IsKeyDown(ctx, ImGui.Mod_Shift)
    if is_hovered and left_clicked then
      if over_arrow then
        if shift_down and has_children then
          -- Shift+click arrow: toggle all children to match parent's NEW state
          local new_state = not is_selected
          if not state.track_whitelist then state.track_whitelist = {} end
          state.track_whitelist[track.guid] = new_state
          local function set_children(children, value)
            for _, child in ipairs(children) do
              state.track_whitelist[child.guid] = value
              if child.children then set_children(child.children, value) end
            end
          end
          set_children(track.children, new_state)
        else
          -- Normal click: Toggle expand (not part of paint mode)
          if not state.track_expanded then state.track_expanded = {} end
          state.track_expanded[track.guid] = not is_expanded
        end
      else
        -- Start ENABLE paint mode (left click = enable)
        state.track_filter_painting = true
        state.track_filter_paint_mode = 'enable'
        state.track_filter_last_painted = track.guid
        if not state.track_whitelist then state.track_whitelist = {} end
        state.track_whitelist[track.guid] = true
      end
    end

    -- Handle right click/drag: DISABLE tracks
    if is_hovered and right_clicked and not over_arrow then
      state.track_filter_painting = true
      state.track_filter_paint_mode = 'disable'
      state.track_filter_last_painted = track.guid
      if not state.track_whitelist then state.track_whitelist = {} end
      state.track_whitelist[track.guid] = false
    end

    -- Paint mode while dragging
    if state.track_filter_painting and is_hovered and not over_arrow then
      local is_dragging = (state.track_filter_paint_mode == 'enable' and left_down) or
                          (state.track_filter_paint_mode == 'disable' and right_down)

      if is_dragging and state.track_filter_last_painted ~= track.guid then
        if not state.track_whitelist then state.track_whitelist = {} end

        if state.track_filter_paint_mode == 'enable' then
          -- Enable mode: always set to true
          state.track_whitelist[track.guid] = true
        else
          -- Disable mode: always set to false
          state.track_whitelist[track.guid] = false
        end

        state.track_filter_last_painted = track.guid
      end
    end

    -- Check if parent is disabled (for visual dimming)
    local parent_disabled = is_parent_disabled(track, state.track_whitelist or {})

    -- Draw tile
    draw_track_tile(ctx, draw_list, x, tile_y, width, track, is_selected, is_hovered, depth, is_expanded, has_children, parent_disabled, palette)

    -- Add to visible tracks list for crossing detection (all depths)
    visible_tracks_list[#visible_tracks_list + 1] = {
      track = track,
      y = tile_y,
      height = TRACK_TILE.HEIGHT + TRACK_TILE.MARGIN_Y
    }

    current_y = current_y + TRACK_TILE.HEIGHT + TRACK_TILE.MARGIN_Y

    -- Track hovered item for tooltip (only for nested tracks with depth > 0)
    if is_hovered and depth > 0 then
      state.track_filter_hovered_track = track
    end

    -- Draw children if expanded (or if searching - auto-expand to show matches)
    local show_children = has_children and (is_expanded or (search_lower and search_lower ~= ''))
    if show_children then
      current_y = draw_track_tree(ctx, draw_list, track.children, x, y, width, state, depth + 1, current_y, visible_tracks_list, palette, search_lower)
    end

    ::continue_track::
  end

  -- Handle crossing detection for fast cursor movement (only at top level)
  if depth == 0 and state.track_filter_painting and state.track_filter_prev_mouse_y then
    local is_dragging = (state.track_filter_paint_mode == 'enable' and left_down) or
                        (state.track_filter_paint_mode == 'disable' and right_down)

    if is_dragging then
      -- Find tracks that cursor crossed between previous and current frame
      local prev_y = state.track_filter_prev_mouse_y
      local curr_y = mouse_y
      local min_y = math.min(prev_y, curr_y)
      local max_y = math.max(prev_y, curr_y)

      -- Paint all tracks in the crossed range
      for _, visible_track in ipairs(visible_tracks_list) do
        local track_top = visible_track.y
        local track_bottom = visible_track.y + visible_track.height

        -- Check if track overlaps with the crossed Y range
        if track_bottom >= min_y and track_top <= max_y then
          if state.track_filter_last_painted ~= visible_track.track.guid then
            if not state.track_whitelist then state.track_whitelist = {} end

            local new_value
            if state.track_filter_paint_mode == 'enable' then
              new_value = true
            else
              new_value = false
            end

            state.track_whitelist[visible_track.track.guid] = new_value
            state.track_filter_last_painted = visible_track.track.guid
          end
        end
      end
    end
  end

  -- Update previous mouse position for crossing detection (at top level)
  if depth == 0 then
    state.track_filter_prev_mouse_y = mouse_y
  end

  return current_y
end

-- Use domain functions with UI-specific parameters
local function calculate_tree_height(tracks, state, search_lower)
  -- If searching, we need to calculate height based on filtered/auto-expanded tree
  if search_lower and search_lower ~= '' then
    local function calc_filtered_height(tracks, depth)
      local height = 0
      for _, track in ipairs(tracks) do
        if track_or_children_match(track, search_lower) then
          height = height + TRACK_TILE.HEIGHT + TRACK_TILE.MARGIN_Y
          -- Auto-expand when searching
          if track.children then
            height = height + calc_filtered_height(track.children, depth + 1)
          end
        end
      end
      return height
    end
    return calc_filtered_height(tracks, 0)
  end
  return TrackFilter.calculate_tree_height(tracks, state.track_expanded, TRACK_TILE.HEIGHT, TRACK_TILE.MARGIN_Y)
end

local function calculate_max_depth(tracks)
  return TrackFilter.calculate_max_depth(tracks)
end

local function set_expansion_level(tracks, state, target_level)
  if not state.track_expanded then state.track_expanded = {} end
  TrackFilter.set_expansion_level(tracks, state.track_expanded, target_level)
end

-- Open the track filter modal
function M.open_modal(state)
  state.track_tree = M.build_track_tree()

  if not state.track_whitelist then
    state.track_whitelist = TrackFilter.init_whitelist(state.track_tree)
  end

  if not state.track_expanded then
    state.track_expanded = {}
  end

  state.track_filter_scroll_y = 0
  state.track_filter_search = ''  -- Modal search is temporary (just for navigation)
  state.track_filter_popup_opened = false  -- Reset so popup will be opened fresh
  state.show_track_filter_modal = true
end

-- Render the track filter modal using Ark.Modal
-- Returns true if modal is active
function M.render_modal(ctx, state, bounds)
  if not state.track_tree then return false end

  -- Get search filter for height calculation
  local search_text = state.track_filter_search or ''
  local search_lower = search_text ~= '' and search_text:lower() or nil

  -- Calculate modal size based on content
  local tree_height = calculate_tree_height(state.track_tree, state, search_lower)
  local max_tree_height = bounds.height * 0.5  -- Cap tree area at 50% of viewport
  local tree_area_height = math.min(tree_height + 16, max_tree_height)
  local modal_width = 360
  -- Fixed elements: header(42) + padding(40) + count(20) + search(32) + slider(26) + footer(60) = ~220
  -- Plus tree area
  local modal_height = 260 + tree_area_height

  -- Check if modal wants to close (sync state)
  if Ark.Modal.WantsClose('track_filter') then
    state.show_track_filter_modal = false
    state.track_filter_search = ''  -- Clear modal search (it's just for navigation)
    if state.persist_track_filter then state.persist_track_filter() end
  end

  -- Begin modal (background disabling handled by caller in ui/init.lua)
  if not Ark.Modal.Begin(ctx, 'track_filter', state.show_track_filter_modal, {
    title = 'TRACK FILTER',
    width = modal_width,
    height = modal_height,
    bounds = bounds,  -- Pass bounds for proper scrim coverage
    close_on_escape = true,
    close_on_scrim_click = not state.track_filter_painting,  -- Don't close while painting
    close_on_scrim_right_click = not state.track_filter_painting,
    show_close_button = true,
  }) then
    return false
  end

  -- Get palette for theme-reactive colors
  local palette = Palette.get()
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local content_w, content_h = ImGui.GetContentRegionAvail(ctx)

  -- Keyboard shortcuts (Ctrl+A = All, Ctrl+D = Deselect)
  local ctrl_down = ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl)
  if ctrl_down then
    if ImGui.IsKeyPressed(ctx, ImGui.Key_A) then
      TrackFilter.set_all_tracks(state.track_tree, state.track_whitelist, true)
      if state.persist_track_filter then state.persist_track_filter() end
    end
    if ImGui.IsKeyPressed(ctx, ImGui.Key_D) then
      TrackFilter.set_all_tracks(state.track_tree, state.track_whitelist, false)
      if state.persist_track_filter then state.persist_track_filter() end
    end
  end

  -- Track count (right side of header area)
  local total_count, selected_count = TrackFilter.count_tracks(state.track_tree, state.track_whitelist)
  local count_text = string.format('%d / %d selected', selected_count, total_count)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, palette.text_dimmed or 0x888888FF)
  ImGui.Text(ctx, count_text)
  ImGui.PopStyleColor(ctx)

  ImGui.Spacing(ctx)

  -- Search input
  local search_result = Ark.InputText(ctx, {
    id = 'track_filter_search',
    hint = 'Search tracks...',
    width = content_w,
    height = 24,
    get_value = function() return state.track_filter_search or '' end,
    on_change = function(new_text)
      state.track_filter_search = new_text
      state.track_filter_scroll_y = 0
    end,
  })

  if search_result.changed then
    search_lower = search_result.value ~= '' and search_result.value:lower() or nil
  end

  ImGui.Spacing(ctx)

  -- Depth slider
  local max_depth = calculate_max_depth(state.track_tree)
  if state.track_filter_expand_level == nil then
    state.track_filter_expand_level = max_depth
  end

  ImGui.Text(ctx, 'Depth:')
  ImGui.SameLine(ctx)

  local slider_result = Ark.Slider.Int(ctx, {
    id = 'track_filter_depth',
    value = state.track_filter_expand_level,
    min = 0,
    max = max_depth,
    width = content_w - 60,
    height = 16,
  })

  if slider_result.changed then
    state.track_filter_expand_level = slider_result.value
    if not state.track_expanded then state.track_expanded = {} end
    set_expansion_level(state.track_tree, state, slider_result.value, 0)
  end

  ImGui.Spacing(ctx)

  -- Content area for track tree
  local content_x, content_y = ImGui.GetCursorScreenPos(ctx)
  -- Get actual remaining height after header elements (count, search, slider) have been drawn
  local _, avail_h = ImGui.GetContentRegionAvail(ctx)
  -- Reserve space for footer: Spacing(8) + Separator(2) + Spacing(8) + Buttons(28) + margin(10) = ~56
  local footer_height = 56
  local remaining_height = math.max(100, avail_h - footer_height)

  -- Handle scrolling
  local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
  local scroll_y = state.track_filter_scroll_y or 0
  local max_scroll = math.max(0, tree_height - remaining_height)

  local is_over_content = mouse_x >= content_x and mouse_x <= content_x + content_w and
                          mouse_y >= content_y and mouse_y <= content_y + remaining_height

  if is_over_content then
    local wheel_v = ImGui.GetMouseWheel(ctx)
    if wheel_v ~= 0 then
      scroll_y = scroll_y - wheel_v * 40
      scroll_y = math.max(0, math.min(scroll_y, max_scroll))
      state.track_filter_scroll_y = scroll_y
    end
  end

  -- Clip content area
  ImGui.DrawList_PushClipRect(draw_list, content_x, content_y, content_x + content_w, content_y + remaining_height, true)

  -- Clear hovered track
  state.track_filter_hovered_track = nil

  -- Draw track tree
  draw_track_tree(ctx, draw_list, state.track_tree, content_x, content_y - scroll_y, content_w, state, 0, content_y - scroll_y, nil, nil, search_lower)

  ImGui.DrawList_PopClipRect(draw_list)

  -- Reserve space for content area
  ImGui.Dummy(ctx, content_w, remaining_height)

  -- Tooltip for hovered nested track
  if state.track_filter_hovered_track then
    local hovered = state.track_filter_hovered_track
    local path_text = get_track_path(hovered)
    ImGui.SetTooltip(ctx, path_text)
  end

  -- Footer with buttons
  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  local btn_width = (content_w - 8) / 2

  if Ark.Button(ctx, { id = 'track_filter_all', label = 'All', width = btn_width, height = 28 }).clicked then
    TrackFilter.set_all_tracks(state.track_tree, state.track_whitelist, true)
    if state.persist_track_filter then state.persist_track_filter() end
  end

  ImGui.SameLine(ctx, 0, 8)

  if Ark.Button(ctx, { id = 'track_filter_none', label = 'None', width = btn_width, height = 28 }).clicked then
    TrackFilter.set_all_tracks(state.track_tree, state.track_whitelist, false)
    if state.persist_track_filter then state.persist_track_filter() end
  end

  Ark.Modal.End(ctx)

  return true
end

-- Export helper functions for use by other modules
M.is_effectively_selected = is_effectively_selected
M.is_parent_disabled = is_parent_disabled

return M
