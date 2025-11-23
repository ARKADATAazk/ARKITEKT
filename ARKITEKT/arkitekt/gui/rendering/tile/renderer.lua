-- @noindex
-- Arkitekt/gui/fx/tile_fx.lua
-- Multi-layer tile rendering with granular controls

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local Colors = require('arkitekt.core.colors')
local Background = require('arkitekt.gui.widgets.containers.panel.background')

-- Performance: Localize math functions for hot path (30% faster in loops)
local max = math.max
local min = math.min

-- Performance: Cache ImGui functions to avoid global lookups (~5% faster)
local AddRectFilled = ImGui.DrawList_AddRectFilled
local AddRectFilledMultiColor = ImGui.DrawList_AddRectFilledMultiColor
local AddRect = ImGui.DrawList_AddRect
local AddLine = ImGui.DrawList_AddLine
local PushClipRect = ImGui.DrawList_PushClipRect
local PopClipRect = ImGui.DrawList_PopClipRect
local DrawFlags_RoundCornersAll = ImGui.DrawFlags_RoundCornersAll
local DrawFlags_RoundCornersLeft = ImGui.DrawFlags_RoundCornersLeft

-- Performance: Parse hex colors once at module load (~10-20% faster)
local hexrgb = Colors.hexrgb
local BASE_NEUTRAL = hexrgb("#0F0F0F")

local M = {}

function M.render_base_fill(dl, x1, y1, x2, y2, rounding)
  AddRectFilled(dl, x1, y1, x2, y2, BASE_NEUTRAL, rounding, DrawFlags_RoundCornersAll)
end

function M.render_color_fill(dl, x1, y1, x2, y2, base_color, opacity, saturation, brightness, rounding)
  local r, g, b, _ = Colors.rgba_to_components(base_color)

  if saturation ~= 1.0 then
    local gray = r * 0.299 + g * 0.587 + b * 0.114
    r = (r + (gray - r) * (1 - saturation))//1
    g = (g + (gray - g) * (1 - saturation))//1
    b = (b + (gray - b) * (1 - saturation))//1
  end

  if brightness ~= 1.0 then
    r = min(255, max(0, (r * brightness)//1))
    g = min(255, max(0, (g * brightness)//1))
    b = min(255, max(0, (b * brightness)//1))
  end

  local alpha = (255 * opacity)//1
  local fill_color = Colors.components_to_rgba(r, g, b, alpha)
  AddRectFilled(dl, x1, y1, x2, y2, fill_color, rounding, DrawFlags_RoundCornersAll)
end

function M.render_gradient(dl, x1, y1, x2, y2, base_color, intensity, opacity, rounding)
  local r, g, b, _ = Colors.rgba_to_components(base_color)

  local boost_top = 1.0 + intensity
  local boost_bottom = 1.0 - (intensity * 0.4)

  local r_top = min(255, (r * boost_top)//1)
  local g_top = min(255, (g * boost_top)//1)
  local b_top = min(255, (b * boost_top)//1)

  local r_bottom = max(0, (r * boost_bottom)//1)
  local g_bottom = max(0, (g * boost_bottom)//1)
  local b_bottom = max(0, (b * boost_bottom)//1)

  local alpha = (255 * opacity)//1
  local color_top = Colors.components_to_rgba(r_top, g_top, b_top, alpha)
  local color_bottom = Colors.components_to_rgba(r_bottom, g_bottom, b_bottom, alpha)

  -- Inset on all sides to stay inside rounded corners (AddRectFilledMultiColor doesn't support corner flags)
  local inset = min(2, rounding * 0.3)
  ImGui.DrawList_PushClipRect(dl, x1, y1, x2, y2, true)
  ImGui.DrawList_AddRectFilledMultiColor(dl, x1 + inset, y1 + inset, x2 - inset, y2 - inset,
    color_top, color_top, color_bottom, color_bottom)
  PopClipRect(dl)
end

function M.render_specular(dl, x1, y1, x2, y2, base_color, strength, coverage, rounding)
  local height = y2 - y1
  local band_height = height * coverage
  local band_y2 = y1 + band_height

  local r, g, b, _ = Colors.rgba_to_components(base_color)

  local boost = 1.3
  local r_spec = min(255, (r * boost + 20)//1)
  local g_spec = min(255, (g * boost + 20)//1)
  local b_spec = min(255, (b * boost + 20)//1)

  local alpha_top = (255 * strength * 0.6)//1
  local alpha_bottom = 0

  local color_top = Colors.components_to_rgba(r_spec, g_spec, b_spec, alpha_top)
  local color_bottom = Colors.components_to_rgba(r_spec, g_spec, b_spec, alpha_bottom)

  -- Inset on all sides to stay inside rounded corners (AddRectFilledMultiColor doesn't support corner flags)
  local inset = min(2, rounding * 0.3)
  PushClipRect(dl, x1, y1, x2, y2, true)
  AddRectFilledMultiColor(dl, x1 + inset, y1 + inset, x2 - inset, band_y2,
    color_top, color_top, color_bottom, color_bottom)
  PopClipRect(dl)
end

function M.render_inner_shadow(dl, x1, y1, x2, y2, strength, rounding)
  local shadow_size = 3  -- Increased to 3px to be visible under 1px border
  local shadow_alpha = (255 * strength * 0.4)//1
  local shadow_color = Colors.components_to_rgba(0, 0, 0, shadow_alpha)

  -- Clip to rounded rect bounds (AddRectFilledMultiColor doesn't support corner flags)
  PushClipRect(dl, x1, y1, x2, y2, true)

  AddRectFilledMultiColor(dl,
    x1, y1, x2, y1 + shadow_size,
    shadow_color, shadow_color,
    Colors.components_to_rgba(0, 0, 0, 0), Colors.components_to_rgba(0, 0, 0, 0))

  AddRectFilledMultiColor(dl,
    x1, y1, x1 + shadow_size, y2,
    shadow_color, Colors.components_to_rgba(0, 0, 0, 0),
    Colors.components_to_rgba(0, 0, 0, 0), shadow_color)

  PopClipRect(dl)
end

function M.render_diagonal_stripes(ctx, dl, x1, y1, x2, y2, stripe_color, spacing, thickness, opacity, rounding)
  if opacity <= 0 then return end

  local r, g, b, _ = Colors.rgba_to_components(stripe_color)
  local alpha = (255 * opacity)//1
  local line_color = Colors.components_to_rgba(r, g, b, alpha)

  -- Use baked texture for performance (25+ lines → 1 draw call)
  Background.draw_diagonal_stripes(ctx, dl, x1, y1, x2, y2, spacing, line_color, thickness)
end

function M.render_playback_progress(dl, x1, y1, x2, y2, base_color, progress, fade_alpha, rounding, progress_color_override)
  if progress <= 0 or fade_alpha <= 0 then return end

  local width = x2 - x1
  -- Snap to whole pixels to prevent aliasing on the edge
  local progress_width = (width * progress)//1
  local progress_x = x1 + progress_width

  -- Use override color if provided (for playlist chip color)
  local color_source = progress_color_override or base_color
  local r, g, b, _ = Colors.rgba_to_components(color_source)

  local brightness = 1.15
  r = min(255, (r * brightness)//1)
  g = min(255, (g * brightness)//1)
  b = min(255, (b * brightness)//1)

  local base_alpha = 0x80  -- Doubled from 0x40 for more visible progress bar
  local alpha = (base_alpha * fade_alpha)//1
  local progress_color = Colors.components_to_rgba(r, g, b, alpha)

  -- Inset to stay inside rounded corners (same approach as specular highlight)
  local inset = min(2, rounding * 0.3)

  -- Draw progress as a simple square fill with insets to avoid rounded corners
  ImGui.DrawList_AddRectFilled(dl, x1 + inset, y1 + inset, progress_x, y2 - inset, progress_color, 0, 0)

  -- Draw 1-pixel vertical cursor line at progress position
  -- Only show between 2% and 98% to avoid corner clipping issues
  if progress >= 0.02 and progress < 0.98 then
    local base_bar_alpha = 0xAA
    local bar_alpha = (base_bar_alpha * fade_alpha)//1
    local bar_color = Colors.components_to_rgba(r, g, b, bar_alpha)
    local bar_thickness = 1

    -- Cursor line at progress position
    ImGui.DrawList_AddLine(dl, progress_x, y1 + inset, progress_x, y2 - inset, bar_color, bar_thickness)
  elseif progress >= 0.98 and progress < 1.0 then
    -- Fade out cursor from 98% to 100%
    local fade_range = 1.0 - 0.98
    local fade_progress = (1.0 - progress) / fade_range
    local base_bar_alpha = 0xAA
    local bar_alpha = (base_bar_alpha * fade_alpha * fade_progress)//1
    local bar_color = Colors.components_to_rgba(r, g, b, bar_alpha)
    local bar_thickness = 1

    ImGui.DrawList_AddLine(dl, progress_x, y1 + inset, progress_x, y2 - inset, bar_color, bar_thickness)
  end
end

function M.render_border(dl, x1, y1, x2, y2, base_color, saturation, brightness, opacity, thickness, rounding, is_selected, glow_strength, glow_layers, border_color_override)
  local alpha = (255 * opacity)//1
  -- Use override color if provided (for playlist chip color)
  local color_source = border_color_override or base_color
  local border_color = Colors.same_hue_variant(color_source, saturation, brightness, alpha)

  if is_selected and glow_layers > 0 then
    local r, g, b, _ = Colors.rgba_to_components(border_color)
    for i = glow_layers, 1, -1 do
      local glow_alpha = (glow_strength * 30 / i)//1
      local glow_color = Colors.components_to_rgba(r, g, b, glow_alpha)
      AddRect(dl, x1 - i, y1 - i, x2 + i, y2 + i, glow_color, rounding, DrawFlags_RoundCornersAll, thickness)
    end
  end

  ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, border_color, rounding, ImGui.DrawFlags_RoundCornersAll, thickness)
end

function M.render_complete(ctx, dl, x1, y1, x2, y2, base_color, config, is_selected, hover_factor, playback_progress, playback_fade, border_color_override, progress_color_override, stripe_color, stripe_enabled)
  hover_factor = hover_factor or 0
  playback_progress = playback_progress or 0
  playback_fade = playback_fade or 0

  local fill_opacity = config.fill_opacity + (hover_factor * config.hover_fill_boost)
  local specular_strength = config.specular_strength * (1 + hover_factor * config.hover_specular_boost)

  M.render_base_fill(dl, x1, y1, x2, y2, config.rounding or 6)

  if playback_progress > 0 and playback_fade > 0 then
    M.render_playback_progress(dl, x1, y1, x2, y2, base_color, playback_progress, playback_fade, config.rounding or 6, progress_color_override)
  end

  M.render_color_fill(dl, x1, y1, x2, y2, base_color, fill_opacity, config.fill_saturation, config.fill_brightness, config.rounding or 6)

  -- Diagonal stripes for playlists (if enabled)
  if stripe_enabled and stripe_color then
    local stripe_spacing = config.stripe_spacing or 10
    local stripe_thickness = config.stripe_thickness or 1
    local stripe_opacity = config.stripe_opacity or 0.08
    M.render_diagonal_stripes(ctx, dl, x1, y1, x2, y2, stripe_color, stripe_spacing, stripe_thickness, stripe_opacity, config.rounding or 6)
  end

  M.render_gradient(dl, x1, y1, x2, y2, base_color, config.gradient_intensity, config.gradient_opacity, config.rounding or 6)
  M.render_specular(dl, x1, y1, x2, y2, base_color, specular_strength, config.specular_coverage, config.rounding or 6)
  M.render_inner_shadow(dl, x1, y1, x2, y2, config.inner_shadow_strength, config.rounding or 6)

  if not (is_selected and config.ants_enabled and config.ants_replace_border) then
    M.render_border(dl, x1, y1, x2, y2, base_color, config.border_saturation, config.border_brightness, config.border_opacity,
      config.border_thickness, config.rounding or 6, is_selected, config.glow_strength, config.glow_layers, border_color_override)
  end
end

return M
