-- @noindex
-- arkitekt/gui/systems/grid_renderer.lua
-- Centralized grid/tile rendering utilities
-- Consolidates duplicate code from package_tiles, media_grid, RegionPlaylist renderers

local ImGui = require('arkitekt.platform.imgui')
local Colors = require('arkitekt.core.colors')

local M = {}

-- >>> TEXT UTILITIES (BEGIN)

-- Truncate text to fit within max_width, adding ellipsis if needed
-- Previously duplicated in: package_tiles/renderer.lua, media_grid/renderers/base.lua, RegionPlaylist/renderers/base.lua
function M.truncate_text(ctx, text, max_width, ellipsis)
  ellipsis = ellipsis or "…"

  if not text or text == "" then return "" end

  local text_w = ImGui.CalcTextSize(ctx, text)
  if text_w <= max_width then
    return text
  end

  local ellipsis_w = ImGui.CalcTextSize(ctx, ellipsis)
  local target_width = max_width - ellipsis_w

  if target_width <= 0 then
    return ellipsis
  end

  -- Binary search for optimal truncation point
  local low, high = 1, #text
  while low < high do
    local mid = math.ceil((low + high) / 2)
    local test_text = text:sub(1, mid)
    local test_width = ImGui.CalcTextSize(ctx, test_text)

    if test_width <= target_width then
      low = mid
    else
      high = mid - 1
    end
  end

  return text:sub(1, low) .. ellipsis
end

-- Calculate text dimensions for a given string
function M.measure_text(ctx, text)
  local w, h = ImGui.CalcTextSize(ctx, text)
  return { width = w, height = h }
end

-- <<< TEXT UTILITIES (END)

-- >>> BADGE POSITIONING (BEGIN)

-- Calculate badge position with responsive vertical centering
-- Small tiles (< 40px): center vertically
-- Large tiles (> 40px): align to top with padding
function M.calculate_badge_position(rect, badge_height, config)
  config = config or {}
  local threshold = config.vertical_center_threshold or 40
  local top_padding = config.top_padding or 4
  local left_padding = config.left_padding or 4

  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local tile_height = y2 - y1

  local badge_x = x1 + left_padding
  local badge_y

  if tile_height < threshold then
    -- Center vertically for small tiles
    badge_y = y1 + (tile_height - badge_height) / 2
  else
    -- Top-aligned with padding for larger tiles
    badge_y = y1 + top_padding
  end

  return badge_x, badge_y
end

-- Calculate chip/indicator position (similar to badge but typically right-aligned)
function M.calculate_chip_position(rect, chip_width, chip_height, config)
  config = config or {}
  local threshold = config.vertical_center_threshold or 40
  local top_padding = config.top_padding or 4
  local right_padding = config.right_padding or 4

  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local tile_height = y2 - y1

  local chip_x = x2 - right_padding - chip_width
  local chip_y

  if tile_height < threshold then
    chip_y = y1 + (tile_height - chip_height) / 2
  else
    chip_y = y1 + top_padding
  end

  return chip_x, chip_y
end

-- <<< BADGE POSITIONING (END)

-- >>> TEXT POSITIONING (BEGIN)

-- Calculate text position with overflow handling
-- Returns position and available width for text
function M.calculate_text_position(ctx, rect, config)
  config = config or {}
  local left_padding = config.left_padding or 6
  local right_padding = config.right_padding or 6
  local vertical_align = config.vertical_align or "center"  -- "center", "top", "bottom"
  local top_padding = config.top_padding or 4
  local bottom_padding = config.bottom_padding or 4

  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local tile_width = x2 - x1
  local tile_height = y2 - y1
  local text_height = ImGui.GetTextLineHeight(ctx)

  local text_x = x1 + left_padding
  local available_width = tile_width - left_padding - right_padding
  local text_y

  if vertical_align == "center" then
    text_y = y1 + (tile_height - text_height) / 2
  elseif vertical_align == "top" then
    text_y = y1 + top_padding
  elseif vertical_align == "bottom" then
    text_y = y2 - bottom_padding - text_height
  end

  return text_x, text_y, available_width
end

-- Calculate width needed for right-side elements (badges, chips, icons)
function M.calculate_right_elements_width(elements)
  local total_width = 0

  for _, element in ipairs(elements) do
    total_width = total_width + (element.width or 0)
    total_width = total_width + (element.margin or 4)
  end

  return total_width
end

-- <<< TEXT POSITIONING (END)

-- >>> TILE BACKGROUND/EFFECTS (BEGIN)

-- Draw tile background with optional rounded corners
function M.draw_tile_background(dl, rect, color, rounding)
  rounding = rounding or 4
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, color, rounding)
end

-- Draw tile border
function M.draw_tile_border(dl, rect, color, rounding, thickness)
  rounding = rounding or 4
  thickness = thickness or 1
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, color, rounding, 0, thickness)
end

-- Draw hover shadow effect
function M.draw_hover_shadow(dl, rect, hover_factor, config)
  config = config or {}
  local max_offset = config.max_offset or 2
  local max_alpha = config.max_alpha or 20
  local rounding = config.rounding or 4

  if hover_factor < 0.01 then return end

  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local shadow_alpha = (hover_factor * max_alpha) // 1
  local shadow_col = (0x000000 << 8) | shadow_alpha

  for i = max_offset, 1, -1 do
    ImGui.DrawList_AddRectFilled(dl, x1 - i, y1 - i + 2, x2 + i, y2 + i + 2, shadow_col, rounding)
  end
end

-- <<< TILE BACKGROUND/EFFECTS (END)

-- >>> COLOR UTILITIES (BEGIN)

-- Compute fill color with hover state
function M.compute_fill_color(base_color, hover_factor, config)
  config = config or {}
  local desaturation = config.desaturation or 0.5
  local brightness = config.brightness or 0.45
  local alpha = config.alpha or 0xCC
  local hover_brightness = config.hover_brightness or 0.65

  local base_fill = Colors.derive_fill(base_color, {
    desaturate = desaturation,
    brightness = brightness,
    alpha = alpha,
  })

  if hover_factor and hover_factor > 0 then
    local hover_fill = Colors.adjust_brightness(base_fill, hover_brightness)
    return Colors.lerp(base_fill, hover_fill, hover_factor)
  end

  return base_fill
end

-- Compute border color with hover/active states
function M.compute_border_color(base_color, is_hovered, is_active, hover_factor, config)
  config = config or {}
  local hover_lerp = config.hover_lerp or 0.4
  local mode = config.color_mode or 'auto'

  local border_color = Colors.derive_border(base_color, {
    mode = (mode == 'grayscale') and 'brighten' or 'normalize',
    pullback = (mode == 'bright') and 0.85 or 0.95,
  })

  if is_hovered and hover_factor then
    local selection_color = Colors.derive_selection(base_color)
    return Colors.lerp(border_color, selection_color, hover_factor * hover_lerp)
  end

  return border_color
end

-- <<< COLOR UTILITIES (END)

-- >>> LAYOUT CALCULATION (BEGIN)

-- Calculate responsive tile height based on column width
-- Consolidates duplicate logic from package_tiles/grid.lua
function M.calculate_responsive_height(tile_width, aspect_ratio, min_height, max_height)
  aspect_ratio = aspect_ratio or 0.65
  min_height = min_height or 40
  max_height = max_height or 200

  local responsive_h = tile_width * aspect_ratio
  return math.max(min_height, math.min(max_height, responsive_h))
end

-- Calculate grid dimensions (wrapper around layout.calculate)
-- Provides simplified interface for common use cases
function M.calculate_grid(avail_w, min_col_w, gap, num_items, origin_x, origin_y, fixed_tile_h)
  local LayoutGrid = require('arkitekt.gui.widgets.containers.grid.layout')
  return LayoutGrid.calculate(avail_w, min_col_w, gap, num_items, origin_x, origin_y, fixed_tile_h)
end

-- <<< LAYOUT CALCULATION (END)

-- >>> DRAW TEXT WITH CLIPPING (BEGIN)

-- Draw text with automatic truncation if needed
function M.draw_text_truncated(ctx, dl, x, y, text, max_width, color)
  local truncated = M.truncate_text(ctx, text, max_width)
  ImGui.DrawList_AddText(dl, x, y, color, truncated)
end

-- Draw text with clipping rect (for complex layouts)
function M.draw_text_clipped(dl, x, y, text, clip_x1, clip_y1, clip_x2, clip_y2, color)
  ImGui.DrawList_PushClipRect(dl, clip_x1, clip_y1, clip_x2, clip_y2, true)
  ImGui.DrawList_AddText(dl, x, y, color, text)
  ImGui.DrawList_PopClipRect(dl)
end

-- <<< DRAW TEXT WITH CLIPPING (END)

return M
