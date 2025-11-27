-- @noindex
-- ItemPicker/ui/components/track_filter.lua
-- Track whitelist filter modal with tile-style TreeView

local ImGui = require 'imgui' '0.10'
local ark = require('arkitekt')
local TrackFilter = require('ItemPicker.domain.filters.track')

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

-- Get track color from REAPER's COLORREF format (UI-specific, uses ImGui)
local function get_track_display_color(track_color)
  if track_color and (track_color & 0x01000000) ~= 0 then
    local colorref = track_color & 0x00FFFFFF
    local R = colorref & 255
    local G = (colorref >> 8) & 255
    local B = (colorref >> 16) & 255
    return ImGui.ColorConvertDouble4ToU32(R/255, G/255, B/255, 1)
  else
    return ImGui.ColorConvertDouble4ToU32(85/255, 91/255, 91/255, 1)
  end
end

-- Add display colors to track tree (UI enhancement)
local function add_display_colors(tracks)
  for _, track in ipairs(tracks) do
    track.display_color = get_track_display_color(track.color)
    if track.children then
      add_display_colors(track.children)
    end
  end
end

-- Build track hierarchy with display colors
function M.build_track_tree()
  local tracks = TrackFilter.build_track_tree()
  add_display_colors(tracks)
  return tracks
end

-- Re-export domain functions for backward compatibility
local is_effectively_selected = TrackFilter.is_effectively_selected
local is_parent_disabled = TrackFilter.is_parent_disabled
local get_track_path = TrackFilter.get_track_path

-- Draw a single track tile
local function draw_track_tile(ctx, draw_list, x, y, width, track_data, is_selected, is_hovered, depth, is_expanded, has_children, parent_disabled)
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
  local bg_color = ark.Colors.hexrgb("#2A2A2A")
  bg_color = ark.Colors.with_alpha(bg_color, bg_alpha)

  ImGui.DrawList_AddRectFilled(draw_list, tile_x, y, tile_x + tile_w, y + height, bg_color, rounding)

  -- Color bar on the left
  local bar_alpha = is_selected and 0xFF or 0x88
  bar_alpha = (bar_alpha * dim_factor) // 1
  local bar_color = ark.Colors.with_alpha(track_data.display_color, bar_alpha)

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
    local arrow_color = ark.Colors.with_alpha(ark.Colors.hexrgb("#888888"), arrow_alpha)

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
  local text_color = ark.Colors.with_alpha(ark.Colors.hexrgb("#FFFFFF"), text_alpha)

  ImGui.DrawList_AddText(draw_list, text_x, text_y, text_color, track_data.name)

  -- Selection indicator (only show if not parent-disabled)
  if is_selected and not parent_disabled then
    local indicator_size = 6
    local indicator_x = tile_x + tile_w - TRACK_TILE.PADDING_X - indicator_size
    local indicator_y = y + (height - indicator_size) / 2
    local indicator_color = ark.Colors.hexrgb("#42E896FF")

    ImGui.DrawList_AddCircleFilled(draw_list,
      indicator_x + indicator_size/2, indicator_y + indicator_size/2,
      indicator_size/2, indicator_color)
  end

  return height
end

-- Recursive function to draw track tree
local function draw_track_tree(ctx, draw_list, tracks, x, y, width, state, depth, current_y, visible_tracks_list)
  depth = depth or 0
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
    state.track_filter_paint_mode = nil  -- "enable" or "disable"
    state.track_filter_prev_mouse_y = nil  -- Reset cursor tracking
  end

  for _, track in ipairs(tracks) do
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
        state.track_filter_paint_mode = "enable"
        state.track_filter_last_painted = track.guid
        if not state.track_whitelist then state.track_whitelist = {} end
        state.track_whitelist[track.guid] = true
      end
    end

    -- Handle right click/drag: DISABLE tracks
    if is_hovered and right_clicked and not over_arrow then
      state.track_filter_painting = true
      state.track_filter_paint_mode = "disable"
      state.track_filter_last_painted = track.guid
      if not state.track_whitelist then state.track_whitelist = {} end
      state.track_whitelist[track.guid] = false
    end

    -- Paint mode while dragging
    if state.track_filter_painting and is_hovered and not over_arrow then
      local is_dragging = (state.track_filter_paint_mode == "enable" and left_down) or
                          (state.track_filter_paint_mode == "disable" and right_down)

      if is_dragging and state.track_filter_last_painted ~= track.guid then
        if not state.track_whitelist then state.track_whitelist = {} end

        if state.track_filter_paint_mode == "enable" then
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
    draw_track_tile(ctx, draw_list, x, tile_y, width, track, is_selected, is_hovered, depth, is_expanded, has_children, parent_disabled)

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

    -- Draw children if expanded
    if has_children and is_expanded then
      current_y = draw_track_tree(ctx, draw_list, track.children, x, y, width, state, depth + 1, current_y, visible_tracks_list)
    end
  end

  -- Handle crossing detection for fast cursor movement (only at top level)
  if depth == 0 and state.track_filter_painting and state.track_filter_prev_mouse_y then
    local is_dragging = (state.track_filter_paint_mode == "enable" and left_down) or
                        (state.track_filter_paint_mode == "disable" and right_down)

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
            if state.track_filter_paint_mode == "enable" then
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
local function calculate_tree_height(tracks, state)
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
  state.show_track_filter_modal = true
end

-- Render the track filter modal directly (called from main_window)
-- Returns true if modal is active (to block input behind it)
function M.render_modal(ctx, state, bounds)
  if not state.show_track_filter_modal then return false end
  if not state.track_tree then return false end

  -- Use foreground draw list to render on top of everything
  local draw_list = ImGui.GetForegroundDrawList(ctx)
  local padding = 16
  local alpha = state.overlay_alpha or 1.0

  -- Draw scrim (darkened background)
  local scrim_color = ark.Colors.with_alpha(ark.Colors.hexrgb("#000000"), (0x80 * alpha) // 1)
  ImGui.DrawList_AddRectFilled(draw_list, bounds.x, bounds.y, bounds.x + bounds.width, bounds.y + bounds.height, scrim_color)

  -- Calculate modal size
  local tree_height = calculate_tree_height(state.track_tree, state, 0)
  local max_content = bounds.height * 0.6
  local content_height = math.min(tree_height + 32, max_content)
  local modal_width = 320
  local slider_area_height = 32  -- Height for depth slider
  local modal_height = 50 + slider_area_height + content_height + 50

  local modal_x = bounds.x + (bounds.width - modal_width) / 2
  local modal_y = bounds.y + 80  -- Align to top with padding (slider stays fixed)

  -- Check for clicks outside modal to close (left click only, right-click for painting)
  local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
  local left_clicked = ImGui.IsMouseClicked(ctx, ImGui.MouseButton_Left)
  local is_over_modal = mouse_x >= modal_x and mouse_x <= modal_x + modal_width and
                        mouse_y >= modal_y and mouse_y <= modal_y + modal_height

  -- Only close on left-click outside modal (not right-click, which is used for painting)
  if left_clicked and not is_over_modal and not state.track_filter_painting then
    state.show_track_filter_modal = false
    -- Persist track filter state when modal closes
    if state.persist_track_filter then state.persist_track_filter() end
    return false
  end

  -- Check for Escape to close
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
    state.show_track_filter_modal = false
    -- Persist track filter state when modal closes
    if state.persist_track_filter then state.persist_track_filter() end
    return false
  end

  -- Keyboard shortcuts
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

  -- Create invisible button over modal area to register it for IsAnyItemHovered()
  -- This prevents overlay from closing on right-click within the modal
  ImGui.SetCursorScreenPos(ctx, modal_x, modal_y)
  ImGui.InvisibleButton(ctx, "##track_filter_modal_area", modal_width, modal_height)

  -- Modal background
  local bg_color = ark.Colors.with_alpha(ark.Colors.hexrgb("#1A1A1A"), (0xF5 * alpha) // 1)
  ImGui.DrawList_AddRectFilled(draw_list, modal_x, modal_y, modal_x + modal_width, modal_y + modal_height, bg_color, 8)

  -- Border
  local border_color = ark.Colors.with_alpha(ark.Colors.hexrgb("#404040"), (0xFF * alpha) // 1)
  ImGui.DrawList_AddRect(draw_list, modal_x, modal_y, modal_x + modal_width, modal_y + modal_height, border_color, 8)

  -- Header
  local title_color = ark.Colors.with_alpha(ark.Colors.hexrgb("#FFFFFF"), (0xFF * alpha) // 1)
  ImGui.DrawList_AddText(draw_list, modal_x + padding, modal_y + padding, title_color, "TRACK FILTER")

  -- Track count
  local total_count, selected_count = TrackFilter.count_tracks(state.track_tree, state.track_whitelist)
  local count_text = string.format("%d / %d selected", selected_count, total_count)
  local count_w = ImGui.CalcTextSize(ctx, count_text)
  local count_color = ark.Colors.with_alpha(ark.Colors.hexrgb("#888888"), (0xFF * alpha) // 1)
  ImGui.DrawList_AddText(draw_list, modal_x + modal_width - padding - count_w, modal_y + padding, count_color, count_text)

  -- Depth slider area
  local slider_y = modal_y + 42
  local slider_x = modal_x + padding
  local slider_w = modal_width - padding * 2
  local slider_h = 20

  -- Calculate max depth
  local max_depth = calculate_max_depth(state.track_tree)

  -- Initialize expansion level if not set
  if state.track_filter_expand_level == nil then
    state.track_filter_expand_level = max_depth  -- Start fully expanded
  end

  -- Draw slider label
  local label_text = "Depth:"
  local label_color = ark.Colors.with_alpha(ark.Colors.hexrgb("#888888"), (0xFF * alpha) // 1)
  ImGui.DrawList_AddText(draw_list, slider_x, slider_y + 2, label_color, label_text)

  local label_w = ImGui.CalcTextSize(ctx, label_text) + 8
  local track_x = slider_x + label_w
  local track_w = slider_w - label_w - 30  -- Leave space for value

  -- Slider track background
  local track_bg = ark.Colors.with_alpha(ark.Colors.hexrgb("#2A2A2A"), (0xCC * alpha) // 1)
  local track_y = slider_y + 8
  local track_h = 4
  ImGui.DrawList_AddRectFilled(draw_list, track_x, track_y, track_x + track_w, track_y + track_h, track_bg, 2)

  -- Slider handle position
  local handle_radius = 6
  local slider_value = state.track_filter_expand_level
  local handle_x = track_x + (slider_value / math.max(1, max_depth)) * track_w
  if max_depth == 0 then handle_x = track_x + track_w end

  -- Check if dragging slider
  local is_over_slider = mouse_x >= track_x - handle_radius and mouse_x <= track_x + track_w + handle_radius and
                         mouse_y >= track_y - handle_radius and mouse_y <= track_y + track_h + handle_radius

  if is_over_slider and ImGui.IsMouseDown(ctx, ImGui.MouseButton_Left) then
    -- Calculate new value from mouse position
    local new_value = math.floor(((mouse_x - track_x) / track_w) * max_depth + 0.5)
    new_value = math.max(0, math.min(new_value, max_depth))

    if new_value ~= state.track_filter_expand_level then
      state.track_filter_expand_level = new_value
      -- Update expansion state
      if not state.track_expanded then state.track_expanded = {} end
      set_expansion_level(state.track_tree, state, new_value, 0)
    end
  end

  -- Draw slider handle
  local handle_color = is_over_slider and ark.Colors.hexrgb("#FFFFFF") or ark.Colors.hexrgb("#CCCCCC")
  handle_color = ark.Colors.with_alpha(handle_color, (0xFF * alpha) // 1)
  ImGui.DrawList_AddCircleFilled(draw_list, handle_x, track_y + track_h / 2, handle_radius, handle_color)

  -- Draw current value
  local value_text = tostring(slider_value)
  local value_color = ark.Colors.with_alpha(ark.Colors.hexrgb("#FFFFFF"), (0xFF * alpha) // 1)
  ImGui.DrawList_AddText(draw_list, track_x + track_w + 8, slider_y + 2, value_color, value_text)

  -- Content area bounds (below slider)
  local content_x = modal_x + padding
  local content_y = modal_y + 50 + slider_area_height
  local content_w = modal_width - padding * 2
  local content_h = content_height

  -- Handle scrolling
  local scroll_y = state.track_filter_scroll_y or 0
  local max_scroll = math.max(0, tree_height - content_h)

  -- Check if mouse is over content area for scrolling
  local is_over_content = mouse_x >= content_x and mouse_x <= content_x + content_w and
                          mouse_y >= content_y and mouse_y <= content_y + content_h

  if is_over_content then
    local wheel_v = ImGui.GetMouseWheel(ctx)
    if wheel_v ~= 0 then
      scroll_y = scroll_y - wheel_v * 40  -- 40 pixels per scroll tick
      scroll_y = math.max(0, math.min(scroll_y, max_scroll))
      state.track_filter_scroll_y = scroll_y
    end
  end

  -- Clip content area
  ImGui.DrawList_PushClipRect(draw_list, content_x, content_y, content_x + content_w, content_y + content_h, true)

  -- Clear hovered track before drawing (will be set by draw_track_tree if hovering)
  state.track_filter_hovered_track = nil

  -- Draw track tree with scroll offset
  draw_track_tree(ctx, draw_list, state.track_tree, content_x, content_y - scroll_y, content_w, state, 0, content_y - scroll_y)

  ImGui.DrawList_PopClipRect(draw_list)

  -- Draw tooltip for hovered nested track (outside clip rect)
  if state.track_filter_hovered_track then
    local hovered = state.track_filter_hovered_track
    local path_text = get_track_path(hovered)
    local tooltip_padding = 6
    local text_w, text_h = ImGui.CalcTextSize(ctx, path_text)
    local tooltip_w = text_w + tooltip_padding * 2
    local tooltip_h = text_h + tooltip_padding * 2

    -- Position tooltip below cursor, clamped to screen bounds
    local tip_x = mouse_x + 12
    local tip_y = mouse_y + 18

    -- Keep tooltip within modal bounds
    if tip_x + tooltip_w > modal_x + modal_width - 8 then
      tip_x = modal_x + modal_width - 8 - tooltip_w
    end
    if tip_y + tooltip_h > modal_y + modal_height - 8 then
      tip_y = mouse_y - tooltip_h - 4
    end

    -- Draw tooltip background
    local tip_bg = ark.Colors.with_alpha(ark.Colors.hexrgb("#1A1A1A"), (0xF5 * alpha) // 1)
    local tip_border = ark.Colors.with_alpha(ark.Colors.hexrgb("#505050"), (0xFF * alpha) // 1)
    ImGui.DrawList_AddRectFilled(draw_list, tip_x, tip_y, tip_x + tooltip_w, tip_y + tooltip_h, tip_bg, 4)
    ImGui.DrawList_AddRect(draw_list, tip_x, tip_y, tip_x + tooltip_w, tip_y + tooltip_h, tip_border, 4)

    -- Draw tooltip text
    local tip_text_color = ark.Colors.with_alpha(ark.Colors.hexrgb("#CCCCCC"), (0xFF * alpha) // 1)
    ImGui.DrawList_AddText(draw_list, tip_x + tooltip_padding, tip_y + tooltip_padding, tip_text_color, path_text)
  end

  -- Footer with buttons
  local footer_y = modal_y + modal_height - 50
  local btn_width = (content_w - 8) / 2
  local btn_height = 28
  local btn_y = footer_y + (50 - btn_height) / 2

  -- "All" button
  local all_x = content_x
  local all_hovered = mouse_x >= all_x and mouse_x <= all_x + btn_width and
                      mouse_y >= btn_y and mouse_y <= btn_y + btn_height

  if all_hovered and left_clicked then
    TrackFilter.set_all_tracks(state.track_tree, state.track_whitelist, true)
    if state.persist_track_filter then state.persist_track_filter() end
  end

  local all_bg = all_hovered and ark.Colors.hexrgb("#3A3A3A") or ark.Colors.hexrgb("#2A2A2A")
  all_bg = ark.Colors.with_alpha(all_bg, (0xEE * alpha) // 1)
  ImGui.DrawList_AddRectFilled(draw_list, all_x, btn_y, all_x + btn_width, btn_y + btn_height, all_bg, 4)
  local all_text_w = ImGui.CalcTextSize(ctx, "All")
  ImGui.DrawList_AddText(draw_list,
    all_x + (btn_width - all_text_w) / 2,
    btn_y + (btn_height - ImGui.GetTextLineHeight(ctx)) / 2,
    ark.Colors.with_alpha(ark.Colors.hexrgb("#FFFFFF"), (0xEE * alpha) // 1), "All")

  -- "None" button
  local none_x = content_x + btn_width + 8
  local none_hovered = mouse_x >= none_x and mouse_x <= none_x + btn_width and
                       mouse_y >= btn_y and mouse_y <= btn_y + btn_height

  if none_hovered and left_clicked then
    TrackFilter.set_all_tracks(state.track_tree, state.track_whitelist, false)
    if state.persist_track_filter then state.persist_track_filter() end
  end

  local none_bg = none_hovered and ark.Colors.hexrgb("#3A3A3A") or ark.Colors.hexrgb("#2A2A2A")
  none_bg = ark.Colors.with_alpha(none_bg, (0xEE * alpha) // 1)
  ImGui.DrawList_AddRectFilled(draw_list, none_x, btn_y, none_x + btn_width, btn_y + btn_height, none_bg, 4)
  local none_text_w = ImGui.CalcTextSize(ctx, "None")
  ImGui.DrawList_AddText(draw_list,
    none_x + (btn_width - none_text_w) / 2,
    btn_y + (btn_height - ImGui.GetTextLineHeight(ctx)) / 2,
    ark.Colors.with_alpha(ark.Colors.hexrgb("#FFFFFF"), (0xEE * alpha) // 1), "None")

  return true  -- Modal is active, block input behind
end

-- Export helper functions for use by other modules
M.is_effectively_selected = is_effectively_selected
M.is_parent_disabled = is_parent_disabled

return M
