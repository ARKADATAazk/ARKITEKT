-- @noindex
-- ItemPicker/ui/components/track_filter.lua
-- Track whitelist filter modal with tile-style TreeView

local ImGui = require 'imgui' '0.10'
local Colors = require('arkitekt.core.colors')

local M = {}

-- Tile styling constants
local TRACK_TILE = {
  HEIGHT = 18,  -- Reduced from 26 (-30%)
  PADDING_X = 6,
  PADDING_Y = 2,
  MARGIN_Y = 1,
  ROUNDING = 3,
  COLOR_BAR_WIDTH = 3,
  INDENT = 16,  -- Per level indent
}

-- Get track color from REAPER's COLORREF format
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

-- Build track hierarchy from project
function M.build_track_tree()
  local tracks = {}
  local track_count = reaper.CountTracks(0)

  -- First pass: collect all tracks with metadata
  local all_tracks = {}
  for i = 0, track_count - 1 do
    local track = reaper.GetTrack(0, i)
    if not track then goto continue end

    local guid = reaper.GetTrackGUID(track)
    local _, name = reaper.GetTrackName(track)
    local color = reaper.GetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR")
    local depth = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
    local folder_depth = reaper.GetTrackDepth(track)

    all_tracks[i + 1] = {
      track = track,
      guid = guid,
      name = name or ("Track " .. (i + 1)),
      color = color,
      display_color = get_track_display_color(color),
      index = i + 1,
      depth = folder_depth,
      folder_depth = depth,  -- 1 = folder start, 0 = normal, -1/-2 = folder end
      children = {},
      is_folder = depth == 1,
    }

    ::continue::
  end

  -- Second pass: build tree structure
  local root = { children = {} }
  local stack = { root }

  for i, track_data in ipairs(all_tracks) do
    local parent = stack[#stack]
    table.insert(parent.children, track_data)

    if track_data.folder_depth == 1 then
      -- This is a folder, push to stack
      table.insert(stack, track_data)
    elseif track_data.folder_depth < 0 then
      -- End of folder(s)
      for j = 1, -track_data.folder_depth do
        if #stack > 1 then
          table.remove(stack)
        end
      end
    end
  end

  return root.children
end

-- Draw a single track tile
local function draw_track_tile(ctx, draw_list, x, y, width, track_data, is_selected, is_hovered, depth, is_expanded, has_children)
  local height = TRACK_TILE.HEIGHT
  local rounding = TRACK_TILE.ROUNDING
  local indent = depth * TRACK_TILE.INDENT

  local tile_x = x + indent
  local tile_w = width - indent

  -- Background
  local bg_alpha = is_selected and 0xCC or (is_hovered and 0x66 or 0x33)
  local bg_color = Colors.hexrgb("#2A2A2A")
  bg_color = Colors.with_alpha(bg_color, bg_alpha)

  ImGui.DrawList_AddRectFilled(draw_list, tile_x, y, tile_x + tile_w, y + height, bg_color, rounding)

  -- Color bar on the left
  local bar_alpha = is_selected and 0xFF or 0x88
  local bar_color = Colors.with_alpha(track_data.display_color, bar_alpha)

  ImGui.DrawList_AddRectFilled(draw_list,
    tile_x, y,
    tile_x + TRACK_TILE.COLOR_BAR_WIDTH, y + height,
    bar_color, rounding, ImGui.DrawFlags_RoundCornersLeft)

  -- Expand/collapse arrow for folders
  local text_offset = TRACK_TILE.COLOR_BAR_WIDTH + TRACK_TILE.PADDING_X
  if has_children then
    local arrow_x = tile_x + text_offset
    local arrow_y = y + (height - 6) / 2
    local arrow_color = Colors.hexrgb("#888888")

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
  local text_color = Colors.with_alpha(Colors.hexrgb("#FFFFFF"), text_alpha)

  ImGui.DrawList_AddText(draw_list, text_x, text_y, text_color, track_data.name)

  -- Selection indicator
  if is_selected then
    local indicator_size = 6
    local indicator_x = tile_x + tile_w - TRACK_TILE.PADDING_X - indicator_size
    local indicator_y = y + (height - indicator_size) / 2
    local indicator_color = Colors.hexrgb("#42E896FF")

    ImGui.DrawList_AddCircleFilled(draw_list,
      indicator_x + indicator_size/2, indicator_y + indicator_size/2,
      indicator_size/2, indicator_color)
  end

  return height
end

-- Recursive function to draw track tree
local function draw_track_tree(ctx, draw_list, tracks, x, y, width, state, depth, current_y)
  depth = depth or 0
  current_y = current_y or y

  local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
  local left_clicked = ImGui.IsMouseClicked(ctx, ImGui.MouseButton_Left)

  for _, track in ipairs(tracks) do
    local tile_y = current_y
    local indent = depth * TRACK_TILE.INDENT
    local tile_x = x + indent
    local tile_w = width - indent

    -- Check hover
    local is_hovered = mouse_x >= tile_x and mouse_x <= tile_x + tile_w and
                       mouse_y >= tile_y and mouse_y <= tile_y + TRACK_TILE.HEIGHT

    -- Check selection state
    local is_selected = state.track_whitelist and state.track_whitelist[track.guid]
    if is_selected == nil then is_selected = true end  -- Default to selected

    -- Check if expanded
    local has_children = track.children and #track.children > 0
    local is_expanded = state.track_expanded and state.track_expanded[track.guid]
    if is_expanded == nil then is_expanded = true end  -- Default expanded

    -- Handle clicks
    if is_hovered and left_clicked then
      -- Check if clicked on arrow area
      local arrow_x = tile_x + TRACK_TILE.COLOR_BAR_WIDTH + TRACK_TILE.PADDING_X
      if has_children and mouse_x >= arrow_x and mouse_x <= arrow_x + 12 then
        -- Toggle expand
        if not state.track_expanded then state.track_expanded = {} end
        state.track_expanded[track.guid] = not is_expanded
      else
        -- Toggle selection
        if not state.track_whitelist then state.track_whitelist = {} end
        state.track_whitelist[track.guid] = not is_selected
      end
    end

    -- Draw tile
    draw_track_tile(ctx, draw_list, x, tile_y, width, track, is_selected, is_hovered, depth, is_expanded, has_children)
    current_y = current_y + TRACK_TILE.HEIGHT + TRACK_TILE.MARGIN_Y

    -- Draw children if expanded
    if has_children and is_expanded then
      current_y = draw_track_tree(ctx, draw_list, track.children, x, y, width, state, depth + 1, current_y)
    end
  end

  return current_y
end

-- Calculate total height needed for track tree
local function calculate_tree_height(tracks, state, depth)
  depth = depth or 0
  local height = 0

  for _, track in ipairs(tracks) do
    height = height + TRACK_TILE.HEIGHT + TRACK_TILE.MARGIN_Y

    local has_children = track.children and #track.children > 0
    local is_expanded = state.track_expanded and state.track_expanded[track.guid]
    if is_expanded == nil then is_expanded = true end

    if has_children and is_expanded then
      height = height + calculate_tree_height(track.children, state, depth + 1)
    end
  end

  return height
end

-- Calculate maximum depth of the track tree
local function calculate_max_depth(tracks, current_depth)
  current_depth = current_depth or 0
  local max_depth = current_depth

  for _, track in ipairs(tracks) do
    if track.children and #track.children > 0 then
      local child_depth = calculate_max_depth(track.children, current_depth + 1)
      if child_depth > max_depth then
        max_depth = child_depth
      end
    end
  end

  return max_depth
end

-- Set expansion state based on depth level
local function set_expansion_level(tracks, state, target_level, current_depth)
  current_depth = current_depth or 0

  for _, track in ipairs(tracks) do
    if track.children and #track.children > 0 then
      -- Expand if current depth is less than target level
      state.track_expanded[track.guid] = current_depth < target_level
      set_expansion_level(track.children, state, target_level, current_depth + 1)
    end
  end
end

-- Open the track filter modal
function M.open_modal(state)
  -- Build track tree
  state.track_tree = M.build_track_tree()

  -- Initialize whitelist if not present (all selected by default)
  if not state.track_whitelist then
    state.track_whitelist = {}
    local function init_whitelist(tracks)
      for _, track in ipairs(tracks) do
        state.track_whitelist[track.guid] = true
        if track.children then
          init_whitelist(track.children)
        end
      end
    end
    init_whitelist(state.track_tree)
  end

  -- Initialize expanded state
  if not state.track_expanded then
    state.track_expanded = {}
  end

  -- Reset scroll position
  state.track_filter_scroll_y = 0

  -- Set flag to show modal (rendered directly in ItemPicker)
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
  local scrim_color = Colors.with_alpha(Colors.hexrgb("#000000"), math.floor(0x80 * alpha))
  ImGui.DrawList_AddRectFilled(draw_list, bounds.x, bounds.y, bounds.x + bounds.width, bounds.y + bounds.height, scrim_color)

  -- Calculate modal size
  local tree_height = calculate_tree_height(state.track_tree, state, 0)
  local max_content = bounds.height * 0.6
  local content_height = math.min(tree_height + 32, max_content)
  local modal_width = 320
  local slider_area_height = 32  -- Height for depth slider
  local modal_height = 50 + slider_area_height + content_height + 50

  local modal_x = bounds.x + (bounds.width - modal_width) / 2
  local modal_y = bounds.y + (bounds.height - modal_height) / 2

  -- Check for clicks outside modal to close
  local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
  local left_clicked = ImGui.IsMouseClicked(ctx, ImGui.MouseButton_Left)
  local is_over_modal = mouse_x >= modal_x and mouse_x <= modal_x + modal_width and
                        mouse_y >= modal_y and mouse_y <= modal_y + modal_height

  if left_clicked and not is_over_modal then
    state.show_track_filter_modal = false
    return false
  end

  -- Check for Escape to close
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
    state.show_track_filter_modal = false
    return false
  end

  -- Modal background
  local bg_color = Colors.with_alpha(Colors.hexrgb("#1A1A1A"), math.floor(0xF5 * alpha))
  ImGui.DrawList_AddRectFilled(draw_list, modal_x, modal_y, modal_x + modal_width, modal_y + modal_height, bg_color, 8)

  -- Border
  local border_color = Colors.with_alpha(Colors.hexrgb("#404040"), math.floor(0xFF * alpha))
  ImGui.DrawList_AddRect(draw_list, modal_x, modal_y, modal_x + modal_width, modal_y + modal_height, border_color, 8)

  -- Header
  local title_color = Colors.with_alpha(Colors.hexrgb("#FFFFFF"), math.floor(0xFF * alpha))
  ImGui.DrawList_AddText(draw_list, modal_x + padding, modal_y + padding, title_color, "TRACK FILTER")

  -- Track count
  local total_count = 0
  local selected_count = 0
  local function count_tracks(tracks)
    for _, track in ipairs(tracks) do
      total_count = total_count + 1
      if state.track_whitelist[track.guid] then
        selected_count = selected_count + 1
      end
      if track.children then
        count_tracks(track.children)
      end
    end
  end
  count_tracks(state.track_tree)

  local count_text = string.format("%d / %d selected", selected_count, total_count)
  local count_w = ImGui.CalcTextSize(ctx, count_text)
  local count_color = Colors.with_alpha(Colors.hexrgb("#888888"), math.floor(0xFF * alpha))
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
  local label_color = Colors.with_alpha(Colors.hexrgb("#888888"), math.floor(0xFF * alpha))
  ImGui.DrawList_AddText(draw_list, slider_x, slider_y + 2, label_color, label_text)

  local label_w = ImGui.CalcTextSize(ctx, label_text) + 8
  local track_x = slider_x + label_w
  local track_w = slider_w - label_w - 30  -- Leave space for value

  -- Slider track background
  local track_bg = Colors.with_alpha(Colors.hexrgb("#2A2A2A"), math.floor(0xCC * alpha))
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
  local handle_color = is_over_slider and Colors.hexrgb("#FFFFFF") or Colors.hexrgb("#CCCCCC")
  handle_color = Colors.with_alpha(handle_color, math.floor(0xFF * alpha))
  ImGui.DrawList_AddCircleFilled(draw_list, handle_x, track_y + track_h / 2, handle_radius, handle_color)

  -- Draw current value
  local value_text = tostring(slider_value)
  local value_color = Colors.with_alpha(Colors.hexrgb("#FFFFFF"), math.floor(0xFF * alpha))
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

  -- Draw track tree with scroll offset
  draw_track_tree(ctx, draw_list, state.track_tree, content_x, content_y - scroll_y, content_w, state, 0, content_y - scroll_y)

  ImGui.DrawList_PopClipRect(draw_list)

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
    local function select_all(tracks)
      for _, track in ipairs(tracks) do
        state.track_whitelist[track.guid] = true
        if track.children then select_all(track.children) end
      end
    end
    select_all(state.track_tree)
  end

  local all_bg = all_hovered and Colors.hexrgb("#3A3A3A") or Colors.hexrgb("#2A2A2A")
  all_bg = Colors.with_alpha(all_bg, math.floor(0xEE * alpha))
  ImGui.DrawList_AddRectFilled(draw_list, all_x, btn_y, all_x + btn_width, btn_y + btn_height, all_bg, 4)
  local all_text_w = ImGui.CalcTextSize(ctx, "All")
  ImGui.DrawList_AddText(draw_list,
    all_x + (btn_width - all_text_w) / 2,
    btn_y + (btn_height - ImGui.GetTextLineHeight(ctx)) / 2,
    Colors.with_alpha(Colors.hexrgb("#FFFFFF"), math.floor(0xEE * alpha)), "All")

  -- "None" button
  local none_x = content_x + btn_width + 8
  local none_hovered = mouse_x >= none_x and mouse_x <= none_x + btn_width and
                       mouse_y >= btn_y and mouse_y <= btn_y + btn_height

  if none_hovered and left_clicked then
    local function select_none(tracks)
      for _, track in ipairs(tracks) do
        state.track_whitelist[track.guid] = false
        if track.children then select_none(track.children) end
      end
    end
    select_none(state.track_tree)
  end

  local none_bg = none_hovered and Colors.hexrgb("#3A3A3A") or Colors.hexrgb("#2A2A2A")
  none_bg = Colors.with_alpha(none_bg, math.floor(0xEE * alpha))
  ImGui.DrawList_AddRectFilled(draw_list, none_x, btn_y, none_x + btn_width, btn_y + btn_height, none_bg, 4)
  local none_text_w = ImGui.CalcTextSize(ctx, "None")
  ImGui.DrawList_AddText(draw_list,
    none_x + (btn_width - none_text_w) / 2,
    btn_y + (btn_height - ImGui.GetTextLineHeight(ctx)) / 2,
    Colors.with_alpha(Colors.hexrgb("#FFFFFF"), math.floor(0xEE * alpha)), "None")

  return true  -- Modal is active, block input behind
end

return M
