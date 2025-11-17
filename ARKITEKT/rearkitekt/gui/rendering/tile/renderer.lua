local min, max, floor, ceil = math.min, math.max, math.floor, math.ceil
local band = bit.band
local Colors = require("rearkitekt.gui.colors")
local ImGui = require("imgui_abstraction")

local M = {}

function M.render_base_fill(dl, x1, y1, x2, y2, rounding)
  local r, g, b, a = 0x10, 0x10, 0x10, 0xFF
  local fill_color = Colors.components_to_rgba(r, g, b, a)
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, fill_color, rounding, ImGui.DrawFlags_RoundCornersAll)
end

function M.render_color_fill(dl, x1, y1, x2, y2, base_color, saturation, brightness, opacity, rounding)
  local r, g, b, _ = Colors.rgba_to_components(base_color)

  if saturation ~= 1.0 then
    local gray = (r * 0.299 + g * 0.587 + b * 0.114)//1
    r = (r + (gray - r) * (1 - saturation))//1
    g = (g + (gray - g) * (1 - saturation))//1
    b = (b + (gray - b) * (1 - saturation))//1

    r = min(255, max(0, r))
    g = min(255, max(0, g))
    b = min(255, max(0, b))
  end

  if brightness ~= 1.0 then
    r = min(255, max(0, (r * brightness)//1))
    g = min(255, max(0, (g * brightness)//1))
    b = min(255, max(0, (b * brightness)//1))
  end

  local alpha = (255 * opacity)//1
  local fill_color = Colors.components_to_rgba(r, g, b, alpha)
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, fill_color, rounding, ImGui.DrawFlags_RoundCornersAll)
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
  local b_bottom = min(255, (b * boost_bottom)//1)

  local alpha = (255 * opacity)//1

  local color_top = Colors.components_to_rgba(r_top, g_top, b_top, alpha)
  local color_bottom = Colors.components_to_rgba(r_bottom, g_bottom, b_bottom, alpha)

  -- Clip to rounded rect bounds (AddRectFilledMultiColor doesn't support corner flags)
  ImGui.DrawList_PushClipRect(dl, x1, y1, x2, y2, true)
  ImGui.DrawList_AddRectFilledMultiColor(dl, x1, y1, x2, y2,
    color_top, color_top, color_bottom, color_bottom)
  ImGui.DrawList_PopClipRect(dl)
end

function M.render_specular(dl, x1, y1, x2, y2, base_color, strength, rounding)
  local r, g, b, _ = Colors.rgba_to_components(base_color)

  local specular_boost = 2.5
  local r_spec = min(255, (r * specular_boost)//1)
  local g_spec = min(255, (g * specular_boost)//1)
  local b_spec = min(255, (b * specular_boost)//1)

  local height = y2 - y1
  local band_height = height * 0.25
  local band_y2 = y1 + band_height

  local alpha_top = (255 * strength * 0.8)//1
  local alpha_bottom = 0

  local color_top = Colors.components_to_rgba(r_spec, g_spec, b_spec, alpha_top)
  local color_bottom = Colors.components_to_rgba(r_spec, g_spec, b_spec, alpha_bottom)

  -- Inset on all sides to stay inside rounded corners (AddRectFilledMultiColor doesn't support corner flags)
  local inset = min(2, rounding * 0.3)
  ImGui.DrawList_PushClipRect(dl, x1, y1, x2, y2, true)
  ImGui.DrawList_AddRectFilledMultiColor(dl, x1 + inset, y1 + inset, x2 - inset, band_y2,
    color_top, color_top, color_bottom, color_bottom)
  ImGui.DrawList_PopClipRect(dl)
end

function M.render_inner_shadow(dl, x1, y1, x2, y2, strength, rounding)
  local shadow_size = 3  -- Increased to 3px to be visible under 1px border
  local shadow_alpha = (255 * strength * 0.4)//1
  local shadow_color = Colors.components_to_rgba(0, 0, 0, shadow_alpha)

  -- Clip to rounded rect bounds (AddRectFilledMultiColor doesn't support corner flags)
  ImGui.DrawList_PushClipRect(dl, x1, y1, x2, y2, true)

  ImGui.DrawList_AddRectFilledMultiColor(dl,
    x1, y1, x2, y1 + shadow_size,
    shadow_color, shadow_color,
    Colors.components_to_rgba(0, 0, 0, 0), Colors.components_to_rgba(0, 0, 0, 0))

  ImGui.DrawList_AddRectFilledMultiColor(dl,
    x1, y1, x1 + shadow_size, y2,
    shadow_color, Colors.components_to_rgba(0, 0, 0, 0),
    Colors.components_to_rgba(0, 0, 0, 0), shadow_color)

  ImGui.DrawList_PopClipRect(dl)
end

function M.render_diagonal_stripes(dl, x1, y1, x2, y2, stripe_color, spacing, thickness, opacity, rounding)
  if opacity <= 0 then return end

  local width = x2 - x1
  local height = y2 - y1
  local diagonal_length = math.sqrt(width * width + height * height)

  local r, g, b, _ = Colors.rgba_to_components(stripe_color)
  local alpha = (255 * opacity)//1
  local line_color = Colors.components_to_rgba(r, g, b, alpha)

  -- Push clip rect to keep stripes within tile bounds
  ImGui.DrawList_PushClipRect(dl, x1, y1, x2, y2, true)

  -- Draw diagonal lines at 45 degrees from top-left to bottom-right
  local start_offset = -height
  local end_offset = width

  for offset = start_offset, end_offset, spacing do
    local line_x1 = x1 + offset
    local line_y1 = y1
    local line_x2 = x1 + offset + height
    local line_y2 = y2

    ImGui.DrawList_AddLine(dl, line_x1, line_y1, line_x2, line_y2, line_color, thickness)
  end

  -- Pop clip rect
  ImGui.DrawList_PopClipRect(dl)
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

  local base_alpha = 0x40
  local alpha = (base_alpha * fade_alpha)//1
  local progress_color = Colors.components_to_rgba(r, g, b, alpha)

  -- Inset to stay inside rounded corners (same approach as specular highlight)
  local inset = min(2, rounding * 0.3)

  -- Draw progress as a simple square fill with insets to avoid rounded corners
  ImGui.DrawList_AddRectFilled(dl, x1 + inset, y1 + inset, progress_x, y2 - inset, progress_color, 0, 0)

  -- Draw 1-pixel vertical cursor line at progress position (only if not at 100%)
  if progress < 1.0 then
    local base_bar_alpha = 0xAA
    local bar_alpha = (base_bar_alpha * fade_alpha)//1
    local bar_color = Colors.components_to_rgba(r, g, b, bar_alpha)
    local bar_thickness = 1

    -- Cursor line with inset to match progress fill
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
      local layer_thickness = thickness + (i * 2)
      local layer_alpha = (alpha * glow_strength * (i / glow_layers))//1
      local layer_color = Colors.components_to_rgba(r, g, b, layer_alpha)
      ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, layer_color, rounding, ImGui.DrawFlags_RoundCornersAll, layer_thickness)
    end
  end

  ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, border_color, rounding, ImGui.DrawFlags_RoundCornersAll, thickness)
end

function M.render_overlay_text(dl, x1, y1, x2, y2, text, font_size, color, opacity, h_align, v_align)
  local alpha = (255 * opacity)//1
  local r, g, b, _ = Colors.rgba_to_components(color)
  local text_color = Colors.components_to_rgba(r, g, b, alpha)

  local text_width, text_height = ImGui.CalcTextSize(text)

  -- Default to center alignment
  h_align = h_align or "center"
  v_align = v_align or "center"

  local text_x
  if h_align == "left" then
    text_x = x1 + 4
  elseif h_align == "right" then
    text_x = x2 - text_width - 4
  else -- center
    text_x = x1 + ((x2 - x1 - text_width) * 0.5)//1
  end

  local text_y
  if v_align == "top" then
    text_y = y1 + 4
  elseif v_align == "bottom" then
    text_y = y2 - text_height - 4
  else -- center
    text_y = y1 + ((y2 - y1 - text_height) * 0.5)//1
  end

  ImGui.DrawList_AddText(dl, text_x, text_y, text_color, text)
end

function M.render(dl, x1, y1, x2, y2, base_color, config, hover_amount, playback_progress, playback_fade, progress_color_override)
  config = config or {}
  hover_amount = hover_amount or 0
  playback_progress = playback_progress or 0
  playback_fade = playback_fade or 0

  local hover_factor = hover_amount
  local saturation = config.saturation + (hover_factor * config.hover_saturation_boost)
  local brightness = config.brightness + (hover_factor * config.hover_brightness_boost)
  local color_opacity = config.color_opacity
  local gradient_intensity = config.gradient_intensity + (hover_factor * config.hover_gradient_boost)
  local gradient_opacity = config.gradient_opacity
  local specular_strength = config.specular_strength * (1 + hover_factor * config.hover_specular_boost)

  M.render_base_fill(dl, x1, y1, x2, y2, config.rounding or 6)

  if playback_progress > 0 and playback_fade > 0 then
    M.render_playback_progress(dl, x1, y1, x2, y2, base_color, playback_progress, playback_fade, config.rounding or 6, progress_color_override)
  end

  if color_opacity > 0 then
    M.render_color_fill(dl, x1, y1, x2, y2, base_color, saturation, brightness, color_opacity, config.rounding or 6)
  end

  if gradient_opacity > 0 then
    M.render_gradient(dl, x1, y1, x2, y2, base_color, gradient_intensity, gradient_opacity, config.rounding or 6)
  end

  if specular_strength > 0 then
    M.render_specular(dl, x1, y1, x2, y2, base_color, specular_strength, config.rounding or 6)
  end

  if config.inner_shadow_strength > 0 then
    M.render_inner_shadow(dl, x1, y1, x2, y2, config.inner_shadow_strength, config.rounding or 6)
  end

  if config.stripes_opacity > 0 then
    M.render_diagonal_stripes(dl, x1, y1, x2, y2, base_color, config.stripes_spacing, config.stripes_thickness, config.stripes_opacity, config.rounding or 6)
  end

  M.render_border(dl, x1, y1, x2, y2, base_color, config.border_saturation, config.border_brightness, config.border_opacity, config.border_thickness, config.rounding or 6, config.is_selected, config.glow_strength, config.glow_layers, config.border_color_override)
end

return M
