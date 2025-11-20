-- @noindex
-- ItemPicker/ui/components/region_filter_bar.lua
-- Region filter bar - clickable chips to filter items by region

local ImGui = require 'imgui' '0.10'

local M = {}

function M.draw(ctx, draw_list, x, y, width, state, config)
  local chip_cfg = config.REGION_TAGS.chip

  -- Render clickable region chips in a horizontal row
  local chip_x = x + 4
  local chip_y = y
  local chip_height = chip_cfg.height + 2  -- Slightly taller for top bar

  for i, region in ipairs(state.all_regions) do
    local region_name = region.name
    local region_color = region.color
    local is_selected = state.selected_regions[region_name]

    local text_w, text_h = ImGui.CalcTextSize(ctx, region_name)
    local chip_w = text_w + chip_cfg.padding_x * 2

    -- Check if chip fits in current row
    if chip_x + chip_w > x + width - 4 then
      break  -- Stop if we run out of space
    end

    -- Check if mouse is over chip
    local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
    local is_hovered = mouse_x >= chip_x and mouse_x <= chip_x + chip_w and
                       mouse_y >= chip_y and mouse_y <= chip_y + chip_height

    -- Chip background (dark grey, dimmed by default, bright when selected)
    local bg_alpha = is_selected and 0xFF or 0x66  -- 40% opacity when unselected
    if is_hovered and not is_selected then
      bg_alpha = 0x99  -- 60% opacity when hovered
    end
    local bg_color = (chip_cfg.bg_color & 0xFFFFFF00) | bg_alpha

    -- Draw chip background
    ImGui.DrawList_AddRectFilled(draw_list, chip_x, chip_y, chip_x + chip_w, chip_y + chip_height, bg_color, chip_cfg.rounding)

    -- Chip text (region color, dimmed when unselected)
    local text_alpha = is_selected and 0xFF or 0x66
    local text_color = (region_color & 0xFFFFFF00) | text_alpha
    local text_x = chip_x + chip_cfg.padding_x
    local text_y = chip_y + (chip_height - text_h) / 2
    ImGui.DrawList_AddText(draw_list, text_x, text_y, text_color, region_name)

    -- Handle click
    if is_hovered and ImGui.IsMouseClicked(ctx, 0) then
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

    -- Move to next chip position
    chip_x = chip_x + chip_w + chip_cfg.margin_x
  end

  return chip_height + 8  -- Return height used by filter bar
end

return M
