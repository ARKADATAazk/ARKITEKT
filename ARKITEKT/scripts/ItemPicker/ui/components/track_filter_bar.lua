-- @noindex
-- ItemPicker/ui/components/track_filter_bar.lua
-- Track filter bar - vertical tags on left side to filter items by track

local ImGui = require 'imgui' '0.10'
local Colors = require('arkitekt.core.colors')

local M = {}

-- Tag styling constants
local TAG = {
  HEIGHT = 18,       -- Height per tag
  MARGIN_Y = 2,      -- Vertical spacing between tags
  PADDING_X = 8,     -- Left/right padding
  PADDING_Y = 4,     -- Top/bottom padding
  COLOR_BAR_WIDTH = 4,
  ROUNDING = 3,
}

-- Get display color from REAPER's COLORREF format
local function get_display_color(track_color)
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

-- Flatten track tree to get whitelisted tracks in order
local function get_whitelisted_tracks(tracks, whitelist, result)
  result = result or {}

  for _, track in ipairs(tracks) do
    if whitelist[track.guid] then
      table.insert(result, track)
    end
    if track.children and #track.children > 0 then
      get_whitelisted_tracks(track.children, whitelist, result)
    end
  end

  return result
end

-- Draw the vertical track filter bar
-- Returns width used by the bar (0 if no tracks to show)
function M.draw(ctx, draw_list, x, y, height, state, alpha)
  alpha = alpha or 1.0

  -- Check if we have track data
  if not state.track_tree or not state.track_whitelist then
    return 0
  end

  -- Get whitelisted tracks
  local tracks = get_whitelisted_tracks(state.track_tree, state.track_whitelist)

  if #tracks == 0 then
    return 0
  end

  -- Initialize enabled state if not present (all enabled by default)
  if not state.track_filters_enabled then
    state.track_filters_enabled = {}
    for _, track in ipairs(tracks) do
      state.track_filters_enabled[track.guid] = true
    end
  end

  local bar_width = 120  -- Fixed width for the bar
  local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
  local tag_x = x + TAG.PADDING_X
  local tag_y = y + TAG.PADDING_Y
  local tag_width = bar_width - TAG.PADDING_X * 2

  -- Calculate if we need scrolling
  local total_tags_height = #tracks * (TAG.HEIGHT + TAG.MARGIN_Y) - TAG.MARGIN_Y + TAG.PADDING_Y * 2
  local available_height = height
  local needs_scroll = total_tags_height > available_height

  -- Handle scrolling
  local scroll_y = state.track_bar_scroll_y or 0
  if needs_scroll then
    local max_scroll = total_tags_height - available_height
    local is_over_bar = mouse_x >= x and mouse_x <= x + bar_width and
                        mouse_y >= y and mouse_y <= y + height

    if is_over_bar then
      local wheel_v = ImGui.GetMouseWheel(ctx)
      if wheel_v ~= 0 then
        scroll_y = scroll_y - wheel_v * 30
        scroll_y = math.max(0, math.min(scroll_y, max_scroll))
        state.track_bar_scroll_y = scroll_y
      end
    end
  end

  -- Clip to bar area
  ImGui.DrawList_PushClipRect(draw_list, x, y, x + bar_width, y + height, true)

  -- Draw each track tag
  for i, track in ipairs(tracks) do
    local tag_top = tag_y - scroll_y
    local tag_bottom = tag_top + TAG.HEIGHT

    -- Skip if outside visible area
    if tag_bottom >= y and tag_top <= y + height then
      local is_enabled = state.track_filters_enabled[track.guid]
      if is_enabled == nil then is_enabled = true end

      -- Check hover
      local is_hovered = mouse_x >= tag_x and mouse_x <= tag_x + tag_width and
                         mouse_y >= tag_top and mouse_y <= tag_bottom

      -- Background
      local bg_alpha = is_enabled and 0xAA or 0x33
      if is_hovered then
        bg_alpha = is_enabled and 0xDD or 0x66
      end
      bg_alpha = math.floor(bg_alpha * alpha)
      local bg_color = Colors.with_alpha(Colors.hexrgb("#2A2A2A"), bg_alpha)

      ImGui.DrawList_AddRectFilled(draw_list, tag_x, tag_top, tag_x + tag_width, tag_bottom, bg_color, TAG.ROUNDING)

      -- Color bar
      local bar_alpha = is_enabled and 0xFF or 0x66
      bar_alpha = math.floor(bar_alpha * alpha)
      local bar_color = Colors.with_alpha(track.display_color, bar_alpha)

      ImGui.DrawList_AddRectFilled(draw_list,
        tag_x, tag_top,
        tag_x + TAG.COLOR_BAR_WIDTH, tag_bottom,
        bar_color, TAG.ROUNDING, ImGui.DrawFlags_RoundCornersLeft)

      -- Track name
      local text_x = tag_x + TAG.COLOR_BAR_WIDTH + 4
      local text_y = tag_top + (TAG.HEIGHT - ImGui.GetTextLineHeight(ctx)) / 2
      local text_alpha = is_enabled and 0xFF or 0x66
      text_alpha = math.floor(text_alpha * alpha)
      local text_color = Colors.with_alpha(Colors.hexrgb("#FFFFFF"), text_alpha)

      -- Truncate name if too long
      local max_text_width = tag_width - TAG.COLOR_BAR_WIDTH - 8
      local name = track.name
      local name_width = ImGui.CalcTextSize(ctx, name)
      if name_width > max_text_width then
        -- Truncate with ellipsis
        while #name > 3 and ImGui.CalcTextSize(ctx, name .. "...") > max_text_width do
          name = name:sub(1, -2)
        end
        name = name .. "..."
      end

      ImGui.DrawList_AddText(draw_list, text_x, text_y, text_color, name)

      -- Handle click
      if is_hovered and ImGui.IsMouseClicked(ctx, ImGui.MouseButton_Left) then
        state.track_filters_enabled[track.guid] = not is_enabled
        -- Invalidate filter cache
        state.runtime_cache.audio_filter_hash = nil
        state.runtime_cache.midi_filter_hash = nil
      end
    end

    tag_y = tag_y + TAG.HEIGHT + TAG.MARGIN_Y
  end

  ImGui.DrawList_PopClipRect(draw_list)

  return bar_width
end

-- Get list of enabled track GUIDs for filtering
function M.get_enabled_track_guids(state)
  if not state.track_filters_enabled then
    return nil  -- No filtering
  end

  local enabled = {}
  for guid, is_enabled in pairs(state.track_filters_enabled) do
    if is_enabled then
      table.insert(enabled, guid)
    end
  end

  return enabled
end

return M
