-- @noindex
-- ItemPicker/ui/tiles/renderers/base.lua
-- Base tile renderer with shared functionality

local ImGui = require 'imgui' '0.10'
local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb
local Draw = require('arkitekt.gui.draw')
local TileFX = require('arkitekt.gui.rendering.tile.renderer')
local MarchingAnts = require('arkitekt.gui.fx.interactions.marching_ants')
local Badge = require('arkitekt.gui.widgets.primitives.badge')

local M = {}

M.tile_spawn_times = {}

-- Ensure color has minimum lightness for readability
function M.ensure_min_lightness(color, min_lightness)
  local h, s, l = Colors.rgb_to_hsl(color)
  if l < min_lightness then
    l = min_lightness
  end
  local r, g, b = Colors.hsl_to_rgb(h, s, l)
  return Colors.components_to_rgba(r, g, b, 0xFF)
end

-- Easing functions
local function ease_out_back(t)
  local c1 = 1.70158
  local c3 = c1 + 1
  return 1 + c3 * (t - 1)^3 + c1 * (t - 1)^2
end

-- Calculate cascade animation factor based on overlay alpha and position
function M.calculate_cascade_factor(rect, overlay_alpha, config)
  if overlay_alpha >= 0.999 then return 1.0 end
  if overlay_alpha <= 0.001 then return 0.0 end

  local x1, y1 = rect[1], rect[2]
  local key = string.format("%.0f_%.0f", x1, y1)

  if not M.tile_spawn_times[key] then
    local grid_x = math.floor(x1 / 150)
    local grid_y = math.floor(y1 / 150)
    local grid_distance = math.sqrt(grid_x * grid_x + grid_y * grid_y)
    M.tile_spawn_times[key] = grid_distance * config.TILE_RENDER.cascade.stagger_delay
  end

  local delay = M.tile_spawn_times[key]
  local adjusted_progress = (overlay_alpha - delay) / (1.0 - delay)
  adjusted_progress = math.max(0.0, math.min(1.0, adjusted_progress))

  return ease_out_back(adjusted_progress)
end

-- Truncate text to fit width
function M.truncate_text(ctx, text, max_width)
  if not text or max_width <= 0 then return "" end
  local text_width = ImGui.CalcTextSize(ctx, text)
  if text_width <= max_width then return text end

  local ellipsis = "..."
  local ellipsis_width = ImGui.CalcTextSize(ctx, ellipsis)
  if max_width <= ellipsis_width then return "" end

  local available_width = max_width - ellipsis_width
  for i = #text, 1, -1 do
    local truncated = text:sub(1, i)
    if ImGui.CalcTextSize(ctx, truncated) <= available_width then
      return truncated .. ellipsis
    end
  end
  return ellipsis
end

-- Get dark waveform color from base color
function M.get_dark_waveform_color(base_color, config)
  local r, g, b = ImGui.ColorConvertU32ToDouble4(base_color)
  local h, s, v = ImGui.ColorConvertRGBtoHSV(r, g, b)

  s = config.TILE_RENDER.waveform.saturation
  v = config.TILE_RENDER.waveform.brightness

  r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, config.TILE_RENDER.waveform.line_alpha)
end

-- Render header bar
function M.render_header_bar(dl, x1, y1, x2, header_height, base_color, alpha, config, is_small_tile)
  local header_config = config.TILE_RENDER.header
  local small_tile_config = config.TILE_RENDER.small_tile

  -- In small tile mode with disable_header_fill, don't render anything
  -- (base tile color is bright enough, no darkening overlay needed)
  if is_small_tile and small_tile_config.disable_header_fill then
    return
  end

  -- Normal header rendering with colored background
  local r, g, b = ImGui.ColorConvertU32ToDouble4(base_color)
  local h, s, v = ImGui.ColorConvertRGBtoHSV(r, g, b)

  -- Choose appropriate config section based on tile mode
  if is_small_tile then
    s = s * small_tile_config.header_saturation_factor
    v = v * small_tile_config.header_brightness_factor
  else
    s = s * header_config.saturation_factor
    v = v * header_config.brightness_factor
  end

  r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)

  -- For small tiles, header_alpha is a multiplier (0.0-1.0), so convert it
  local base_header_alpha = header_config.alpha / 255
  local final_alpha
  if is_small_tile then
    -- In small tile mode, alpha is already pre-multiplied by header_alpha in the caller
    final_alpha = math.floor(alpha * 255)
  else
    final_alpha = math.floor(base_header_alpha * alpha * 255)
  end

  local header_color = ImGui.ColorConvertDouble4ToU32(r, g, b, final_alpha / 255)

  -- Choose appropriate text shadow
  local text_shadow = is_small_tile and small_tile_config.header_text_shadow or header_config.text_shadow

  -- Round only top corners of header (top-left and top-right)
  -- Use slightly less rounding than tile for better visual alignment
  local header_rounding = math.max(0, config.TILE.ROUNDING - header_config.rounding_offset)
  local round_flags = ImGui.DrawFlags_RoundCornersTop
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y1 + header_height, header_color, header_rounding, round_flags)
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y1 + header_height, text_shadow, header_rounding, round_flags)
end

-- Render placeholder with loading spinner
function M.render_placeholder(dl, x1, y1, x2, y2, base_color, alpha)
  local r, g, b = ImGui.ColorConvertU32ToDouble4(base_color)
  local h, s, v = ImGui.ColorConvertRGBtoHSV(r, g, b)

  -- Darker background
  s = s * 0.2
  v = v * 0.15

  r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)
  local placeholder_color = ImGui.ColorConvertDouble4ToU32(r, g, b, alpha)

  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, placeholder_color)

  -- Simple rotating ring spinner (standard loading indicator)
  local center_x = (x1 + x2) / 2
  local center_y = (y1 + y2) / 2
  local size = math.min(x2 - x1, y2 - y1) * 0.2

  -- Dark spinner color (slightly lighter than background)
  local spinner_alpha = math.floor(alpha * 100)
  local spinner_color = Colors.with_alpha(hexrgb("#808080"), spinner_alpha)

  local time = reaper.time_precise()
  local rotation = (time * 3) % (math.pi * 2)  -- Rotates every ~2 seconds

  -- Draw ring arc (3/4 circle, 1/4 gap) using PathArcTo
  local arc_length = math.pi * 1.5  -- 270 degrees (3/4 of circle)
  local thickness = math.max(2, size * 0.2)

  -- Start angle and end angle
  local start_angle = rotation - math.pi / 2  -- Start at top
  local end_angle = start_angle + arc_length

  -- Draw the arc path
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathArcTo(dl, center_x, center_y, size, start_angle, end_angle, 24)
  ImGui.DrawList_PathStroke(dl, spinner_color, 0, thickness)
end

-- Apply muted and disabled state effects to render color
function M.apply_state_effects(base_color, muted_factor, enabled_factor, config)
  local render_color = base_color

  -- Apply muted state first (lighter effect than disabled)
  if muted_factor > 0.001 then
    render_color = Colors.desaturate(render_color, config.TILE_RENDER.muted.desaturate * muted_factor)
    render_color = Colors.adjust_brightness(render_color,
      1.0 - (1.0 - config.TILE_RENDER.muted.brightness) * muted_factor)
  end

  -- Apply disabled state (stronger effect, overrides muted)
  if enabled_factor < 1.0 then
    render_color = Colors.desaturate(render_color, config.TILE_RENDER.disabled.desaturate * (1.0 - enabled_factor))
    render_color = Colors.adjust_brightness(render_color,
      1.0 - (1.0 - config.TILE_RENDER.disabled.brightness) * (1.0 - enabled_factor))
  end

  return render_color
end

-- Calculate combined alpha with muted and disabled effects
function M.calculate_combined_alpha(cascade_factor, enabled_factor, muted_factor, base_alpha, config)
  local min_alpha_factor = (config.TILE_RENDER.disabled.min_alpha or 0x33) / 255
  local alpha_factor = min_alpha_factor + (1.0 - min_alpha_factor) * enabled_factor

  -- Apply muted alpha reduction
  if muted_factor > 0.001 then
    alpha_factor = alpha_factor * (1.0 - (1.0 - config.TILE_RENDER.muted.alpha_factor) * muted_factor)
  end

  local combined_alpha = cascade_factor * alpha_factor
  local final_alpha = base_alpha * combined_alpha

  return combined_alpha, final_alpha
end

-- Get text color with muted state applied
function M.get_text_color(muted_factor, config)
  local text_color = config.TILE_RENDER.text.primary_color

  -- Apply red text color for muted items
  if muted_factor > 0.001 then
    local muted_text = config.TILE_RENDER.muted.text_color
    local r1, g1, b1 = ImGui.ColorConvertU32ToDouble4(text_color)
    local r2, g2, b2 = ImGui.ColorConvertU32ToDouble4(muted_text)
    local r = r1 + (r2 - r1) * muted_factor
    local g = g1 + (g2 - g1) * muted_factor
    local b = b1 + (b2 - b1) * muted_factor
    text_color = ImGui.ColorConvertDouble4ToU32(r, g, b, 1.0)
  end

  return text_color
end

-- Render text with badge
-- @param extra_text_margin Optional extra margin for text truncation only (doesn't affect badge position)
-- @param text_color Optional custom text color (defaults to config primary_color)
function M.render_tile_text(ctx, dl, x1, y1, x2, header_height, item_name, index, total, base_color, text_alpha, config, item_key, badge_rects, on_badge_click, extra_text_margin, text_color)
  local tile_render = config.TILE_RENDER
  local show_text = header_height >= (tile_render.responsive.hide_text_below - tile_render.header.min_height)
  local show_badge = header_height >= (tile_render.responsive.hide_badge_below - tile_render.header.min_height)

  if not show_text then return end

  local text_x = x1 + tile_render.text.padding_left
  local text_y = y1 + (header_height - ImGui.GetTextLineHeight(ctx)) / 2 - (4 - tile_render.text.padding_top)

  -- Calculate text truncation boundary (includes extra margin for favorite badge, etc.)
  local right_bound_x = x2 - tile_render.text.margin_right - (extra_text_margin or 0)
  if show_badge and total and total > 1 then
    local badge_text = string.format("%d/%d", index or 1, total)
    local bw, _ = ImGui.CalcTextSize(ctx, badge_text)
    local badge_cfg = tile_render.badges.cycle
    right_bound_x = right_bound_x - (bw + badge_cfg.padding_x * 2 + badge_cfg.margin)
  end

  local available_width = right_bound_x - text_x
  local truncated_name = M.truncate_text(ctx, item_name, available_width)

  -- Use custom text color if provided, otherwise use primary color
  local final_text_color = text_color or tile_render.text.primary_color
  Draw.text(dl, text_x, text_y, Colors.with_alpha(final_text_color, text_alpha), truncated_name)

  -- Render cycle badge (vertically centered in header)
  if show_badge and total and total > 1 then
    local badge_cfg = tile_render.badges.cycle
    local badge_text = string.format("%d/%d", index or 1, total)
    local bw, bh = ImGui.CalcTextSize(ctx, badge_text)

    -- Calculate badge dimensions with padding
    local badge_w = bw + badge_cfg.padding_x * 2
    local badge_h = bh + badge_cfg.padding_y * 2

    -- Center vertically in header
    local badge_x = x2 - badge_w - badge_cfg.margin
    local badge_y = y1 + (header_height - badge_h) / 2

    -- Render using modular badge system (clickable)
    local x1, y1, x2_badge, y2_badge = Badge.render_clickable_text_badge(
      ctx, dl, badge_x, badge_y, badge_text, base_color, text_alpha,
      item_key, on_badge_click, badge_cfg
    )

    -- Store badge rect for exclusion zones
    if badge_rects and item_key then
      badge_rects[item_key] = {x1, y1, x2_badge, y2_badge}
    end
  end
end

return M
