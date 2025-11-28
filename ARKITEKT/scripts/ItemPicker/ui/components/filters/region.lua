-- @noindex
-- ItemPicker/ui/components/filters/region.lua
-- Region filter bar - clickable chips to filter items by region

local ImGui = require 'imgui' '0.10'
local Ark = require('arkitekt')
local M = {}

-- Ensure color has minimum lightness for readability
local function ensure_min_lightness(color, min_lightness)
  local h, s, l = Ark.Colors.rgb_to_hsl(color)
  if l < min_lightness then
    l = min_lightness
  end
  local r, g, b = Ark.Colors.hsl_to_rgb(h, s, l)
  return Ark.Colors.components_to_rgba(r, g, b, 0xFF)
end

function M.draw(ctx, draw_list, x, y, width, state, config, alpha)
  alpha = alpha or 1.0  -- Default to fully visible if not specified
  local chip_cfg = config.REGION_TAGS.chip

  -- Padding for left and right edges
  local padding_x = 14
  local padding_y = 4
  local line_spacing = 4  -- Space between lines
  local chip_height = chip_cfg.height + 2  -- Slightly taller for top bar

  -- Available width for chips (minus padding on both sides)
  local available_width = width - padding_x * 2

  -- First pass: calculate line breaks and positions
  local lines = {{}}  -- Array of lines, each line is array of chip data
  local current_line = 1
  local current_line_width = 0

  for i, region in ipairs(state.all_regions) do
    local region_name = region.name
    local text_w, text_h = ImGui.CalcTextSize(ctx, region_name)
    local chip_w = text_w + chip_cfg.padding_x * 2

    -- Check if chip fits in current line
    local needed_width = chip_w
    if current_line_width > 0 then
      needed_width = needed_width + chip_cfg.margin_x
    end

    if current_line_width + needed_width > available_width and current_line_width > 0 then
      -- Start new line
      current_line = current_line + 1
      lines[current_line] = {}
      current_line_width = 0
      needed_width = chip_w  -- No margin for first chip on new line
    end

    -- Add chip to current line
    lines[current_line][#lines[current_line] + 1] = {
      region = region,
      width = chip_w,
      text_w = text_w,
      text_h = text_h
    }
    current_line_width = current_line_width + needed_width
  end

  -- Second pass: render chips centered per line
  local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
  local total_height = 0

  -- Paint mode state for drag selection
  local left_clicked = ImGui.IsMouseClicked(ctx, ImGui.MouseButton_Left)
  local left_down = ImGui.IsMouseDown(ctx, ImGui.MouseButton_Left)
  local left_released = ImGui.IsMouseReleased(ctx, ImGui.MouseButton_Left)
  local right_clicked = ImGui.IsMouseClicked(ctx, ImGui.MouseButton_Right)
  local right_down = ImGui.IsMouseDown(ctx, ImGui.MouseButton_Right)
  local right_released = ImGui.IsMouseReleased(ctx, ImGui.MouseButton_Right)

  -- Stop painting on mouse release
  if left_released or right_released then
    state.region_filter_painting = false
    state.region_filter_paint_value = nil
    state.region_filter_last_painted = nil
    state.region_filter_paint_mode = nil
  end

  for line_idx, line in ipairs(lines) do
    -- Calculate line width
    local line_width = 0
    for i, chip_data in ipairs(line) do
      line_width = line_width + chip_data.width
      if i < #line then
        line_width = line_width + chip_cfg.margin_x
      end
    end

    -- Center the line
    local line_x = x + padding_x + math.floor((available_width - line_width) / 2)
    local line_y = y + padding_y + (line_idx - 1) * (chip_height + line_spacing)

    -- Render chips on this line
    local chip_x = line_x
    for i, chip_data in ipairs(line) do
      local region = chip_data.region
      local region_name = region.name
      local region_color = region.color
      local is_selected = state.selected_regions[region_name]
      local chip_w = chip_data.width

      -- Check if mouse is over chip
      local is_hovered = mouse_x >= chip_x and mouse_x <= chip_x + chip_w and
                         mouse_y >= line_y and mouse_y <= line_y + chip_height

      -- Chip background (dark grey, dimmed by default, bright when selected)
      local bg_alpha = is_selected and 0xFF or 0x66  -- 40% opacity when unselected
      if is_hovered and not is_selected then
        bg_alpha = Ark.Colors.opacity(0.6)  -- 60% opacity when hovered
      end
      bg_alpha = (bg_alpha * alpha) // 1  -- Apply hover fade
      local bg_color = (chip_cfg.bg_color & 0xFFFFFF00) | bg_alpha

      -- Draw chip background
      ImGui.DrawList_AddRectFilled(draw_list, chip_x, line_y, chip_x + chip_w, line_y + chip_height, bg_color, chip_cfg.rounding)

      -- Chip text (region color with minimum lightness, dimmed when unselected)
      local text_color = ensure_min_lightness(region_color, chip_cfg.text_min_lightness)
      local text_alpha = is_selected and 0xFF or 0x66
      text_alpha = (text_alpha * alpha) // 1  -- Apply hover fade
      text_color = (text_color & 0xFFFFFF00) | text_alpha
      local text_x = chip_x + chip_cfg.padding_x
      local text_y = line_y + (chip_height - chip_data.text_h) / 2
      ImGui.DrawList_AddText(draw_list, text_x, text_y, text_color, region_name)

      -- Handle left click: toggle mode (back-and-forth painting)
      if is_hovered and left_clicked then
        state.region_filter_painting = true
        state.region_filter_paint_mode = "toggle"
        state.region_filter_last_painted = region_name
        -- Toggle selection
        if is_selected then
          state.selected_regions[region_name] = nil
        else
          state.selected_regions[region_name] = true
        end
        -- Invalidate filter cache to refresh grid
        state.runtime_cache.audio_filter_hash = nil
        state.runtime_cache.midi_filter_hash = nil
      end

      -- Handle right click: fixed paint mode (bulk enable/disable)
      if is_hovered and right_clicked then
        state.region_filter_painting = true
        state.region_filter_paint_mode = "fixed"
        state.region_filter_paint_value = not is_selected
        state.region_filter_last_painted = region_name
        if state.region_filter_paint_value then
          state.selected_regions[region_name] = true
        else
          state.selected_regions[region_name] = nil
        end
        -- Invalidate filter cache to refresh grid
        state.runtime_cache.audio_filter_hash = nil
        state.runtime_cache.midi_filter_hash = nil
      end

      -- Paint mode while dragging
      if state.region_filter_painting and is_hovered then
        local is_dragging = (state.region_filter_paint_mode == "toggle" and left_down) or
                            (state.region_filter_paint_mode == "fixed" and right_down)

        if is_dragging and state.region_filter_last_painted ~= region_name then
          if state.region_filter_paint_mode == "toggle" then
            -- Toggle mode: flip the region's current state
            if is_selected then
              state.selected_regions[region_name] = nil
            else
              state.selected_regions[region_name] = true
            end
          else
            -- Fixed mode: apply the paint value
            if state.region_filter_paint_value then
              state.selected_regions[region_name] = true
            else
              state.selected_regions[region_name] = nil
            end
          end
          state.region_filter_last_painted = region_name
          -- Invalidate filter cache
          state.runtime_cache.audio_filter_hash = nil
          state.runtime_cache.midi_filter_hash = nil
        end
      end

      -- Move to next chip position
      chip_x = chip_x + chip_w + chip_cfg.margin_x
    end

    total_height = line_y + chip_height - y
  end

  return total_height + padding_y * 2  -- Return height used by filter bar
end

return M
