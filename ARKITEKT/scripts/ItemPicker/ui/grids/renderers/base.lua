-- @noindex
-- ItemPicker/ui/tiles/renderers/base.lua
-- Base tile renderer with shared functionality

local ImGui = require('arkitekt.core.imgui')
local Ark = require('arkitekt')
local hexrgb = Ark.Colors.Hexrgb
local TileFX = require('arkitekt.gui.renderers.tile.renderer')
local MarchingAnts = require('arkitekt.gui.interaction.marching_ants')
local Easing = require('arkitekt.gui.animation.easing')
local MediaGridBase = require('arkitekt.gui.widgets.media.media_grid.renderers.base')
local Palette = require('ItemPicker.config.palette')
local M = {}

-- PERF: Localize frequently used functions to avoid table lookups in hot paths
local DrawList_AddText = ImGui.DrawList_AddText
local DrawList_AddRectFilled = ImGui.DrawList_AddRectFilled
local DrawList_AddRect = ImGui.DrawList_AddRect
local SetCursorScreenPos = ImGui.SetCursorScreenPos
local InvisibleButton = ImGui.InvisibleButton
local IsItemClicked = ImGui.IsItemClicked
local floor = math.floor

-- PERF: Localize color functions (called many times per tile)
local Colors_desaturate = Ark.Colors.Desaturate
local Colors_AdjustBrightness = Ark.Colors.AdjustBrightness
local Colors_WithAlpha = Ark.Colors.WithAlpha
local Colors_Opacity = Ark.Colors.Opacity
local Colors_RgbaToComponents = Ark.Colors.RgbaToComponents
local Colors_RgbToHsl = Ark.Colors.RgbToHsl
local Colors_HslToRgb = Ark.Colors.HslToRgb
local Colors_ComponentsToRgba = Ark.Colors.ComponentsToRgba

-- PERF: Inline pixel snapping (avoids function call overhead)
local function snap(x)
  return (x + 0.5) // 1
end

-- PERF: Inline with_alpha (avoids Ark.Colors.WithAlpha function call)
local function with_alpha(color, alpha)
  return (color & 0xFFFFFF00) | (alpha & 0xFF)
end

-- PERF: Per-frame config cache (set once per frame via begin_frame)
-- This eliminates the 47% overhead from config.TILE_RENDER.__index metatable calls
-- Declared early so all functions can access it
local _frame_config = {}

-- Reuse tile_spawn_times from MediaGridBase for consistent cascade timing
M.tile_spawn_times = MediaGridBase.tile_spawn_times

-- Ensure color has minimum lightness for readability
function M.ensure_min_lightness(color, min_lightness)
  local h, s, l = Ark.Colors.RgbToHsl(color)
  if l < min_lightness then
    l = min_lightness
  end
  local r, g, b = Ark.Colors.HslToRgb(h, s, l)
  return Ark.Colors.ComponentsToRgba(r, g, b, 0xFF)
end

-- Calculate cascade animation factor (delegates to MediaGridBase)
function M.calculate_cascade_factor(rect, overlay_alpha, config)
  -- MediaGridBase needs the full cascade config (stagger_delay etc), just pass it through
  -- This function is only called when overlay_alpha < 0.999 (rare case during fade-in)
  local adapted_config = { cascade = config.TILE_RENDER.cascade }
  return MediaGridBase.calculate_cascade_factor(rect, overlay_alpha, adapted_config)
end

-- PERF: Cache for ellipsis width (computed once per context)
local _ellipsis_cache = { width = nil, ctx = nil }

-- Truncate text to fit width
-- OPTIMIZED: Binary search truncation (O(log n) instead of O(n) CalcTextSize calls)
function M.truncate_text(ctx, text, max_width)
  if not text or max_width <= 0 then return '' end

  -- PERF: Quick length-based estimate to skip CalcTextSize for short text
  -- Use very conservative estimate: 12px per char covers most wide characters
  local len = #text
  if len * 12 < max_width then
    return text  -- Almost certainly fits
  end

  local text_width = ImGui.CalcTextSize(ctx, text)
  if text_width <= max_width then return text end

  -- PERF: Cache ellipsis width per context
  if _ellipsis_cache.ctx ~= ctx then
    _ellipsis_cache.width = ImGui.CalcTextSize(ctx, '...')
    _ellipsis_cache.ctx = ctx
  end
  local ellipsis_width = _ellipsis_cache.width

  if max_width <= ellipsis_width then return '' end

  local available_width = max_width - ellipsis_width

  -- Binary search for the longest substring that fits
  local low, high = 1, len
  local best = 0

  while low <= high do
    local mid = (low + high) // 2
    local truncated = text:sub(1, mid)
    if ImGui.CalcTextSize(ctx, truncated) <= available_width then
      best = mid
      low = mid + 1
    else
      high = mid - 1
    end
  end

  if best > 0 then
    return text:sub(1, best) .. '...'
  end
  return '...'
end

-- Get dark waveform color from base color (uses palette for theme-reactive values)
function M.get_dark_waveform_color(base_color, config, palette)
  local r, g, b = ImGui.ColorConvertU32ToDouble4(base_color)
  local h, s, v = ImGui.ColorConvertRGBtoHSV(r, g, b)

  -- PERF: Use cached config values, palette overrides if available
  local c = _frame_config
  local viz_sat = (palette and palette.viz_saturation) or c.waveform_saturation
  local viz_bright = (palette and palette.viz_brightness) or c.waveform_brightness

  s = viz_sat
  v = viz_bright

  r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, c.waveform_line_alpha)
end

-- Render header bar (now accepts optional palette for theme-reactive values)
function M.render_header_bar(dl, x1, y1, x2, header_height, base_color, alpha, config, is_small_tile, palette)
  -- PERF: Use cached config values
  local c = _frame_config

  -- In small tile mode with disable_header_fill, don't render anything
  -- (base tile color is bright enough, no darkening overlay needed)
  if is_small_tile and c.small_tile_disable_header_fill then
    return
  end

  local p = palette or {}

  -- Normal header rendering with colored background
  local r, g, b = ImGui.ColorConvertU32ToDouble4(base_color)
  local h, s, v = ImGui.ColorConvertRGBtoHSV(r, g, b)

  -- Choose appropriate config section based on tile mode
  -- Use palette values if available, fallback to config
  if is_small_tile then
    s = s * c.small_tile_header_saturation_factor
    v = v * c.small_tile_header_brightness_factor
  else
    s = s * (p.header_saturation or c.header_saturation_factor)
    v = v * (p.header_brightness or c.header_brightness_factor)
  end

  r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)

  -- For small tiles, header_alpha is a multiplier (0.0-1.0), so convert it
  local base_header_alpha = c.header_alpha / 255
  local final_alpha
  if is_small_tile then
    -- In small tile mode, alpha is already pre-multiplied by header_alpha in the caller
    final_alpha = Ark.Colors.Opacity(alpha)
  else
    final_alpha = Ark.Colors.Opacity(base_header_alpha * alpha)
  end

  local header_color = ImGui.ColorConvertDouble4ToU32(r, g, b, final_alpha / 255)

  -- Choose appropriate text shadow
  local text_shadow = is_small_tile and c.small_tile_header_text_shadow or c.header_text_shadow

  -- Round only top corners of header (top-left and top-right)
  -- Use slightly less rounding than tile for better visual alignment
  local header_rounding = math.max(0, config.TILE.ROUNDING - c.header_rounding_offset)
  local round_flags = ImGui.DrawFlags_RoundCornersTop
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y1 + header_height, header_color, header_rounding, round_flags)
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y1 + header_height, text_shadow, header_rounding, round_flags)
end

-- Render placeholder with loading spinner
function M.render_placeholder(dl, x1, y1, x2, y2, base_color, alpha)
  local r, g, b = ImGui.ColorConvertU32ToDouble4(base_color)
  local h, s, v = ImGui.ColorConvertRGBtoHSV(r, g, b)

  -- Darkened background preserving original color hue
  s = s * 0.6   -- Keep more saturation (was 0.2)
  v = v * 0.35  -- Darker but still visible (was 0.15)

  r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)
  local placeholder_color = ImGui.ColorConvertDouble4ToU32(r, g, b, alpha)

  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, placeholder_color)

  -- Loading spinner using reusable widget
  local center_x = (x1 + x2) / 2
  local center_y = (y1 + y2) / 2
  local size = math.min(x2 - x1, y2 - y1) * 0.2

  -- Dark spinner color from palette (slightly lighter than background)
  local palette = Palette.get()
  local spinner_alpha = (alpha * 100) // 1
  local spinner_color = Ark.Colors.WithAlpha(palette.placeholder_spinner or 0x808080FF, spinner_alpha)
  local thickness = math.max(2, size * 0.2)

  Ark.LoadingSpinner.DrawDirect(dl, center_x, center_y, {
    size = size,
    thickness = thickness,
    color = spinner_color,
    arc_length = 1.5,  -- 270 degrees (in pi radians)
    speed = 3.0,
  })
end

-- Apply muted and disabled state effects to render color
function M.apply_state_effects(base_color, muted_factor, enabled_factor, config)
  local render_color = base_color
  -- PERF: Use cached config values
  local c = _frame_config

  -- Apply muted state first (lighter effect than disabled)
  if muted_factor > 0.001 then
    render_color = Ark.Colors.Desaturate(render_color, c.muted_desaturate * muted_factor)
    render_color = Ark.Colors.AdjustBrightness(render_color,
      1.0 - (1.0 - c.muted_brightness) * muted_factor)
  end

  -- Apply disabled state (stronger effect, overrides muted)
  if enabled_factor < 1.0 then
    render_color = Ark.Colors.Desaturate(render_color, c.disabled_desaturate * (1.0 - enabled_factor))
    render_color = Ark.Colors.AdjustBrightness(render_color,
      1.0 - (1.0 - c.disabled_brightness) * (1.0 - enabled_factor))
  end

  return render_color
end

-- =============================================================================
-- OPTIMIZED COLOR PIPELINE
-- =============================================================================
-- Cache for pre-computed tile colors: base_color -> { normal, compact }
-- Each entry stores the adjusted color (saturation + brightness + min lightness applied)
local _tile_color_cache = {}
local _tile_color_cache_key = nil  -- Track config+palette to invalidate on change

-- Get or compute the base tile color (expensive operations cached)
-- Now uses palette values for theme-reactive brightness/saturation
function M.get_cached_tile_color(base_color, is_compact, config, palette)
  -- Build cache key from palette values that affect tile color
  -- PERF: Only use numeric values, not tostring(config) which changes each frame
  local p = palette or {}
  local sat = p.tile_saturation or 0
  local bright = p.tile_brightness or 0
  local compact_sat = p.tile_compact_saturation or 0
  local compact_bright = p.tile_compact_brightness or 0

  -- Simple numeric hash to detect palette changes
  local cache_key_num = sat * 1000000 + bright * 10000 + compact_sat * 100 + compact_bright

  -- Invalidate cache if palette values changed
  if _tile_color_cache_key ~= cache_key_num then
    _tile_color_cache = {}
    _tile_color_cache_key = cache_key_num
  end

  local cached = _tile_color_cache[base_color]

  if not cached then
    -- PERF: Use cached config values
    local c = _frame_config

    -- Use palette values if available, fallback to config
    local sat_factor = p.tile_saturation or c.base_fill_saturation_factor
    local bright_factor = p.tile_brightness or c.base_fill_brightness_factor
    local compact_sat_factor = p.tile_compact_saturation or c.base_fill_compact_saturation_factor
    local compact_bright_factor = p.tile_compact_brightness or c.base_fill_compact_brightness_factor
    local min_lightness = c.min_lightness

    -- Normal mode color
    local normal = base_color
    normal = Colors_desaturate(normal, 1.0 - sat_factor)
    normal = Colors_AdjustBrightness(normal, bright_factor)
    normal = M._ensure_min_lightness_fast(normal, min_lightness)

    -- Compact mode color
    local compact = base_color
    compact = Colors_desaturate(compact, 1.0 - compact_sat_factor)
    compact = Colors_AdjustBrightness(compact, compact_bright_factor)
    compact = M._ensure_min_lightness_fast(compact, min_lightness)

    cached = { normal = normal, compact = compact }
    _tile_color_cache[base_color] = cached
  end

  return is_compact and cached.compact or cached.normal
end

-- Fast min lightness check (simplified HSL)
function M._ensure_min_lightness_fast(color, min_lightness)
  local r, g, b, a = Colors_RgbaToComponents(color)
  -- Quick luminance approximation
  local lum = (r * 0.299 + g * 0.587 + b * 0.114) / 255
  if lum >= min_lightness then
    return color
  end
  -- Only do full HSL conversion if needed
  local h, s, l = Colors_RgbToHsl(color)
  local r_new, g_new, b_new = Colors_HslToRgb(h, s, min_lightness)
  return Colors_ComponentsToRgba(r_new, g_new, b_new, a)
end

-- Simplified color pipeline: cached base + dynamic effects (boolean states, no animation)
-- Returns render_color ready for use (with alpha already applied)
function M.compute_tile_color_fast(base_color, is_compact, is_muted, is_disabled, is_hovered, is_selected, cascade_factor, config, palette)
  -- Get cached base color (no per-frame cost after first computation)
  local render_color = M.get_cached_tile_color(base_color, is_compact, config, palette)

  -- PERF: Use cached config values
  local c = _frame_config
  local p = palette or {}

  -- Apply dynamic state effects (only when actually muted/disabled)
  if is_muted then
    render_color = Ark.Colors.Desaturate(render_color, c.muted_desaturate)
    render_color = Ark.Colors.AdjustBrightness(render_color, c.muted_brightness)
  end

  if is_disabled then
    render_color = Ark.Colors.Desaturate(render_color, c.disabled_desaturate)
    render_color = Ark.Colors.AdjustBrightness(render_color, c.disabled_brightness)
  end

  -- Apply hover effect (simple brightness boost) - use palette if available
  if is_hovered then
    local hover_boost = p.hover_brightness or c.hover_brightness_boost
    render_color = Ark.Colors.AdjustBrightness(render_color, 1.0 + hover_boost)
  end

  -- Apply selection effect
  if is_selected then
    render_color = Ark.Colors.AdjustBrightness(render_color, 1.0 + c.selection_tile_brightness_boost)
  end

  -- Apply alpha
  local alpha = cascade_factor
  if is_disabled then
    local min_alpha = c.disabled_min_alpha / 255
    alpha = alpha * min_alpha
  end
  if is_muted then
    alpha = alpha * c.muted_alpha_factor
  end

  render_color = Ark.Colors.WithAlpha(render_color, Ark.Colors.Opacity(alpha))

  return render_color, alpha
end

-- Optimized color pipeline with animated factors (for smooth hover/muted/disabled transitions)
-- This is the drop-in replacement for the original ~12 operation chain
-- Returns: render_color (with alpha), combined_alpha (for text/badges)
function M.compute_tile_color(base_color, is_compact, hover_factor, muted_factor, enabled_factor, is_selected, cascade_factor, config, palette)
  -- Get cached base color (saturation + brightness + min_lightness pre-computed)
  local render_color = M.get_cached_tile_color(base_color, is_compact, config, palette)

  -- PERF: Use cached config values
  local c = _frame_config
  local p = palette or {}

  -- Apply muted effect (only if animating or muted)
  if muted_factor > 0.001 then
    render_color = Colors_desaturate(render_color, c.muted_desaturate * muted_factor)
    render_color = Colors_AdjustBrightness(render_color,
      1.0 - (1.0 - c.muted_brightness) * muted_factor)
  end

  -- Apply disabled effect (only if animating or disabled)
  if enabled_factor < 0.999 then
    local disabled_factor = 1.0 - enabled_factor
    render_color = Colors_desaturate(render_color, c.disabled_desaturate * disabled_factor)
    render_color = Colors_AdjustBrightness(render_color,
      1.0 - (1.0 - c.disabled_brightness) * disabled_factor)
  end

  -- Apply hover effect - use palette if available
  if hover_factor > 0.001 then
    local hover_boost = (p.hover_brightness or c.hover_brightness_boost) * hover_factor
    render_color = Colors_AdjustBrightness(render_color, 1.0 + hover_boost)
  end

  -- Apply selection effect
  if is_selected then
    render_color = Colors_AdjustBrightness(render_color, 1.0 + c.selection_tile_brightness_boost)
  end

  -- Calculate combined alpha (matches original calculate_combined_alpha)
  local min_alpha_factor = c.disabled_min_alpha / 255
  local alpha_factor = min_alpha_factor + (1.0 - min_alpha_factor) * enabled_factor

  if muted_factor > 0.001 then
    alpha_factor = alpha_factor * (1.0 - (1.0 - c.muted_alpha_factor) * muted_factor)
  end

  -- combined_alpha is used for text/badges (doesn't include base_alpha)
  local combined_alpha = cascade_factor * alpha_factor

  -- final_alpha for the render_color includes base_alpha from the color itself
  local base_alpha = (render_color & 0xFF) / 255
  local final_alpha = base_alpha * combined_alpha
  render_color = Colors_WithAlpha(render_color, Colors_Opacity(final_alpha))

  return render_color, combined_alpha
end

-- Calculate combined alpha with muted and disabled effects
function M.calculate_combined_alpha(cascade_factor, enabled_factor, muted_factor, base_alpha, config)
  -- PERF: Use cached config values
  local c = _frame_config
  local min_alpha_factor = c.disabled_min_alpha / 255
  local alpha_factor = min_alpha_factor + (1.0 - min_alpha_factor) * enabled_factor

  -- Apply muted alpha reduction
  if muted_factor > 0.001 then
    alpha_factor = alpha_factor * (1.0 - (1.0 - c.muted_alpha_factor) * muted_factor)
  end

  local combined_alpha = cascade_factor * alpha_factor
  local final_alpha = base_alpha * combined_alpha

  return combined_alpha, final_alpha
end

-- Get text color with muted state applied
function M.get_text_color(muted_factor, config)
  -- PERF: Use cached config values
  local c = _frame_config
  local text_color = c.text_primary_color

  -- Apply red text color for muted items
  if muted_factor > 0.001 then
    local muted_text = c.muted_text_color
    local r1, g1, b1 = ImGui.ColorConvertU32ToDouble4(text_color)
    local r2, g2, b2 = ImGui.ColorConvertU32ToDouble4(muted_text)
    local r = r1 + (r2 - r1) * muted_factor
    local g = g1 + (g2 - g1) * muted_factor
    local b = b1 + (b2 - b1) * muted_factor
    text_color = ImGui.ColorConvertDouble4ToU32(r, g, b, 1.0)
  end

  return text_color
end

-- PERF: Cache for badge text dimensions (index/total -> {width, height})
-- Badge text is always 'N/M' format, so limited combinations
local _badge_size_cache = {}
local _badge_size_cache_ctx = nil

-- Call this once per frame before rendering tiles to cache config values
function M.cache_config(config)
  local tr = config.TILE_RENDER
  local c = _frame_config

  -- Cascade animation
  c.cascade_scale_from = tr.cascade.scale_from
  c.cascade_y_offset = tr.cascade.y_offset

  -- Responsive thresholds
  c.small_tile_height = tr.responsive.small_tile_height
  c.hide_text_below = tr.responsive.hide_text_below - tr.header.min_height
  c.hide_badge_below = tr.responsive.hide_badge_below - tr.header.min_height

  -- Animation speeds
  c.animation_speed_hover = tr.animation_speed_hover
  c.animation_speed_header_transition = tr.animation_speed_header_transition

  -- Header
  c.header_min_height = tr.header.min_height
  c.header_height_ratio = tr.header.height_ratio
  c.header_alpha = tr.header.alpha
  c.header_saturation_factor = tr.header.saturation_factor
  c.header_brightness_factor = tr.header.brightness_factor
  c.header_rounding_offset = tr.header.rounding_offset
  c.header_text_shadow = tr.header.text_shadow

  -- Small tile
  c.small_tile_header_alpha = tr.small_tile.header_alpha
  c.small_tile_visualization_alpha = tr.small_tile.visualization_alpha
  c.small_tile_disable_header_fill = tr.small_tile.disable_header_fill
  c.small_tile_header_saturation_factor = tr.small_tile.header_saturation_factor
  c.small_tile_header_brightness_factor = tr.small_tile.header_brightness_factor
  c.small_tile_header_text_shadow = tr.small_tile.header_text_shadow

  -- Disabled state
  c.disabled_fade_speed = tr.disabled.fade_speed
  c.disabled_backdrop_alpha = tr.disabled.backdrop_alpha
  c.disabled_backdrop_color = tr.disabled.backdrop_color
  c.disabled_desaturate = tr.disabled.desaturate
  c.disabled_brightness = tr.disabled.brightness
  c.disabled_min_alpha = tr.disabled.min_alpha or 0x33

  -- Muted state
  c.muted_fade_speed = tr.muted.fade_speed
  c.muted_desaturate = tr.muted.desaturate
  c.muted_brightness = tr.muted.brightness
  c.muted_alpha_factor = tr.muted.alpha_factor or 0.8
  c.muted_text_color = tr.muted.text_color

  -- Hover
  c.hover_brightness_boost = tr.hover.brightness_boost

  -- Selection
  c.selection_tile_brightness_boost = tr.selection.tile_brightness_boost or 0.35
  c.selection_border_saturation = tr.selection.border_saturation
  c.selection_border_brightness = tr.selection.border_brightness
  c.selection_ants_alpha = tr.selection.ants_alpha
  c.selection_ants_inset = tr.selection.ants_inset
  c.selection_ants_thickness = tr.selection.ants_thickness
  c.selection_ants_dash = tr.selection.ants_dash
  c.selection_ants_gap = tr.selection.ants_gap
  c.selection_ants_speed = tr.selection.ants_speed

  -- Text
  c.text_padding_left = tr.text.padding_left
  c.text_padding_top = tr.text.padding_top
  c.text_margin_right = tr.text.margin_right
  c.text_primary_color = tr.text.primary_color

  -- Waveform
  c.waveform_saturation = tr.waveform.saturation
  c.waveform_brightness = tr.waveform.brightness
  c.waveform_line_alpha = tr.waveform.line_alpha

  -- Base fill
  c.base_fill_saturation_factor = tr.base_fill.saturation_factor
  c.base_fill_brightness_factor = tr.base_fill.brightness_factor
  c.base_fill_compact_saturation_factor = tr.base_fill.compact_saturation_factor
  c.base_fill_compact_brightness_factor = tr.base_fill.compact_brightness_factor
  c.min_lightness = tr.min_lightness

  -- Badges - cycle
  c.badge_cycle = tr.badges.cycle
  c.badge_cycle_padding_x = tr.badges.cycle.padding_x
  c.badge_cycle_padding_y = tr.badges.cycle.padding_y
  c.badge_cycle_margin = tr.badges.cycle.margin
  c.badge_cycle_bg = tr.badges.cycle.bg
  c.badge_cycle_rounding = tr.badges.cycle.rounding
  c.badge_cycle_border_darken = tr.badges.cycle.border_darken
  c.badge_cycle_border_alpha = tr.badges.cycle.border_alpha
  c.badge_cycle_text_color = tr.badges.cycle.text_color

  -- Badges - favorite
  c.badge_favorite = tr.badges.favorite
  c.badge_favorite_margin = tr.badges.favorite.margin
  c.badge_favorite_spacing = tr.badges.favorite.spacing or 4
  c.badge_favorite_icon_size = tr.badges.favorite.icon_size

  -- Badges - pool
  c.badge_pool = tr.badges.pool
  c.badge_pool_padding_x = tr.badges.pool.padding_x
  c.badge_pool_padding_y = tr.badges.pool.padding_y
  c.badge_pool_margin = tr.badges.pool.margin
  c.badge_pool_spacing = tr.badges.pool.spacing or 4
  c.badge_pool_bg = tr.badges.pool.bg
  c.badge_pool_rounding = tr.badges.pool.rounding
  c.badge_pool_border_darken = tr.badges.pool.border_darken
  c.badge_pool_border_alpha = tr.badges.pool.border_alpha

  -- Duration text
  c.duration_text_margin_x = tr.duration_text.margin_x
  c.duration_text_margin_y = tr.duration_text.margin_y
  c.duration_text_dark_tile_threshold = tr.duration_text.dark_tile_threshold
  c.duration_text_light_saturation = tr.duration_text.light_saturation
  c.duration_text_light_value = tr.duration_text.light_value
  c.duration_text_dark_saturation = tr.duration_text.dark_saturation
  c.duration_text_dark_value = tr.duration_text.dark_value
end

-- Expose the cache for renderers to access directly
M.cfg = _frame_config

-- Render text with badge
-- @param extra_text_margin Optional extra margin for text truncation only (doesn't affect badge position)
-- @param text_color Optional custom text color (defaults to config primary_color)
-- @param truncated_text_cache Optional cache table for truncated text (key -> {name, width, truncated})
function M.render_tile_text(ctx, dl, x1, y1, x2, header_height, item_name, index, total, base_color, text_alpha, config, item_key, badge_rects, on_badge_click, extra_text_margin, text_color, truncated_text_cache)
  -- PERF: Use pre-cached config values (set once per frame)
  local c = _frame_config
  local show_text = header_height >= c.hide_text_below
  local show_badge = header_height >= c.hide_badge_below

  if not show_text then return end

  -- PERF: Cache GetTextLineHeight (doesn't change within a frame)
  local text_line_height = _badge_size_cache.text_line_height
  if _badge_size_cache_ctx ~= ctx then
    text_line_height = ImGui.GetTextLineHeight(ctx)
    _badge_size_cache = { text_line_height = text_line_height }
    _badge_size_cache_ctx = ctx
  end

  local text_x = x1 + c.text_padding_left
  local text_y = y1 + (header_height - text_line_height) / 2 - (4 - c.text_padding_top) + 1

  -- Calculate text truncation boundary (includes extra margin for favorite badge, etc.)
  local right_bound_x = x2 - c.text_margin_right - (extra_text_margin or 0)
  local badge_text, bw, bh
  if show_badge and total and total > 1 then
    -- PERF: Cache badge text dimensions by index/total combo
    local cache_key = index * 10000 + total  -- Simple key for 'N/M' where N,M < 10000
    local cached = _badge_size_cache[cache_key]
    if cached then
      badge_text, bw, bh = cached[1], cached[2], cached[3]
    else
      badge_text = string.format('%d/%d', index or 1, total)
      bw, bh = ImGui.CalcTextSize(ctx, badge_text)
      _badge_size_cache[cache_key] = {badge_text, bw, bh}
    end
    right_bound_x = right_bound_x - (bw + c.badge_cycle_padding_x * 2 + c.badge_cycle_margin)
  end

  local available_width = right_bound_x - text_x

  -- PERF: Use cached truncated text if available and width matches
  local truncated_name
  -- Round to nearest 2px to avoid cache misses from floating point drift
  local width_key = ((available_width + 1) // 2) * 2
  if truncated_text_cache and item_key then
    local cached = truncated_text_cache[item_key]
    if cached and cached.name == item_name and cached.width == width_key then
      truncated_name = cached.truncated
    else
      truncated_name = M.truncate_text(ctx, item_name, available_width)
      truncated_text_cache[item_key] = { name = item_name, width = width_key, truncated = truncated_name }
    end
  else
    truncated_name = M.truncate_text(ctx, item_name, available_width)
  end

  -- Use custom text color if provided, otherwise use primary color
  -- PERF: Inlined text rendering - bypasses Ark.Draw.Text function call overhead
  local final_text_color = text_color or c.text_primary_color
  DrawList_AddText(dl, snap(text_x), snap(text_y), with_alpha(final_text_color, text_alpha), truncated_name or '')

  -- Render cycle badge (vertically centered in header)
  -- PERF: Inlined badge rendering - bypasses Ark.Badge.clickable overhead
  -- (avoids: 2x parse_opts, table allocations, merge_config, function calls)
  if show_badge and total and total > 1 then
    -- badge_text, bw, bh already computed above

    -- Calculate badge dimensions with padding
    local badge_w = bw + c.badge_cycle_padding_x * 2
    local badge_h = bh + c.badge_cycle_padding_y * 2

    -- Center vertically in header
    local badge_x = x2 - badge_w - c.badge_cycle_margin
    local badge_y = y1 + (header_height - badge_h) / 2
    local badge_x2 = badge_x + badge_w
    local badge_y2 = badge_y + badge_h

    -- Background
    local bg_color = c.badge_cycle_bg
    local bg_alpha = floor((bg_color & 0xFF) * (text_alpha / 255))
    bg_color = (bg_color & 0xFFFFFF00) | bg_alpha
    DrawList_AddRectFilled(dl, badge_x, badge_y, badge_x2, badge_y2, bg_color, c.badge_cycle_rounding)

    -- Border using darker tile color
    local border_color = Ark.Colors.AdjustBrightness(base_color, c.badge_cycle_border_darken)
    border_color = with_alpha(border_color, c.badge_cycle_border_alpha)
    DrawList_AddRect(dl, badge_x, badge_y, badge_x2, badge_y2, border_color, c.badge_cycle_rounding, 0, 0.5)

    -- Text (fallback to white if text_color not defined in config)
    local badge_text_color = with_alpha(c.badge_cycle_text_color or 0xFFFFFFFF, text_alpha)
    DrawList_AddText(dl, badge_x + c.badge_cycle_padding_x, badge_y + c.badge_cycle_padding_y, badge_text_color, badge_text)

    -- Store badge rect for exclusion zones AND post-render click detection
    -- PERF: Removed InvisibleButton - click detection is now done once per frame
    -- in the coordinator via badge_rects hit testing (saves ~5000 widgets/frame)
    if badge_rects and item_key then
      badge_rects[item_key] = {badge_x, badge_y, badge_x2, badge_y2}
    end
  end
end

return M
