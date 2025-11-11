-- @noindex
local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb


local M = {}
local config
local Colors
local MarchingAnts
local Draw
local TileFX

function M.init(config_module, colors_module, marching_ants_module, draw_module, tile_fx_module)
  config = config_module
  Colors = colors_module
  MarchingAnts = marching_ants_module
  Draw = draw_module
  TileFX = tile_fx_module
end

M.CONFIG = {
  rounding = 0,
  
  disabled = {
    desaturate = 0.8,
    brightness = 0.4,
    min_alpha = 0x33,
    fade_speed = 20.0,
  },
  
  header = {
    height_ratio = 0.15,
    min_height = 22,
    saturation_factor = 1.1,
    brightness_factor = 0.7,
    alpha = 0xDD,
    text_shadow = hexrgb("#00000099"),
  },
  
  badge = {
    padding_x = 6,
    padding_y = 3,
    margin = 6,
    rounding = 4,
    bg = hexrgb("#14181C"),
    border_alpha = 0x33,
  },
  
  text = {
    primary_color = hexrgb("#FFFFFF"),
    padding_left = 6,
    padding_top = 4,
    margin_right = 6,
  },
  
  waveform = {
    saturation = 0.3,
    brightness = 0.15,
    line_alpha = 0.8,
    zero_line_alpha = 0.3,
  },
  
  tile_fx = {
    fill_opacity = 0.65,
    fill_saturation = 0.75,
    fill_brightness = 0.6,
    
    border_opacity = 0.0,
    border_saturation = 0.8,
    border_brightness = 1.4,
    border_thickness = 1.0,
    
    index_saturation = 1,
    index_brightness = 1.6,
    
    separator_saturation = 1,
    separator_brightness = 1.6,
    separator_alpha = 0x99,
    
    name_brightness = 1.0,
    name_base_color = hexrgb("#DDE3E9"),
    
    duration_saturation = 0.3,
    duration_brightness = 1,
    duration_alpha = 0x88,
    
    gradient_intensity = 0.2,
    gradient_opacity = 0.08,
    
    specular_strength = 0.12,
    specular_coverage = 0.25,
    
    inner_shadow_strength = 0.25,
    
    ants_enabled = true,
    ants_replace_border = false,
    ants_thickness = 1,
    ants_dash = 8,
    ants_gap = 6,
    ants_speed = 20,
    ants_inset = 0,
    ants_alpha = 0xFF,
    
    glow_strength = 0.4,
    glow_layers = 3,
    
    hover_fill_boost = 0.08,
    hover_specular_boost = 0.6,
  },
  
  animation_speed_hover = 12.0,
  
  cascade = {
    stagger_delay = 0.03,
    scale_from = 0.85,
    y_offset = 20,
    rotation_degrees = 3,
  },
  
  responsive = {
    hide_text_below = 35,
    hide_badge_below = 25,
  },
}

M.tile_spawn_times = M.tile_spawn_times or {}

local function smootherstep(t)
  t = math.max(0.0, math.min(1.0, t))
  return t * t * t * (t * (t * 6 - 15) + 10)
end

local function ease_out_back(t)
  local c1 = 1.70158
  local c3 = c1 + 1
  return 1 + c3 * (t - 1)^3 + c1 * (t - 1)^2
end

local function calculate_cascade_factor(rect, overlay_alpha)
  if overlay_alpha >= 0.999 then return 1.0 end
  if overlay_alpha <= 0.001 then return 0.0 end
  
  local x1, y1 = rect[1], rect[2]
  
  local key = string.format("%.0f_%.0f", x1, y1)
  
  if not M.tile_spawn_times[key] then
    local grid_x = math.floor(x1 / 150)
    local grid_y = math.floor(y1 / 150)
    local grid_distance = math.sqrt(grid_x * grid_x + grid_y * grid_y)
    M.tile_spawn_times[key] = grid_distance * M.CONFIG.cascade.stagger_delay
  end
  
  local delay = M.tile_spawn_times[key]
  local adjusted_progress = (overlay_alpha - delay) / (1.0 - delay)
  adjusted_progress = math.max(0.0, math.min(1.0, adjusted_progress))
  
  return ease_out_back(adjusted_progress)
end

local function truncate_text(ctx, text, max_width)
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

local function get_dark_waveform_color(base_color)
  if not Colors then
    return hexrgb("#333333")
  end
  
  local r, g, b = ImGui.ColorConvertU32ToDouble4(base_color)
  local h, s, v = ImGui.ColorConvertRGBtoHSV(r, g, b)
  
  s = M.CONFIG.waveform.saturation
  v = M.CONFIG.waveform.brightness
  
  r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, M.CONFIG.waveform.line_alpha)
end

local function render_header_bar(dl, x1, y1, x2, header_height, base_color, enabled_factor)
  if not Colors then
    ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y1 + header_height, base_color, M.CONFIG.rounding)
    return
  end
  
  local r, g, b = ImGui.ColorConvertU32ToDouble4(base_color)
  local h, s, v = ImGui.ColorConvertRGBtoHSV(r, g, b)
  
  s = s * M.CONFIG.header.saturation_factor
  v = v * M.CONFIG.header.brightness_factor
  
  r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)
  
  local alpha = M.CONFIG.header.alpha
  if enabled_factor < 1.0 then
    alpha = math.floor(alpha * enabled_factor + M.CONFIG.disabled.min_alpha * (1.0 - enabled_factor))
  end
  
  local header_color = ImGui.ColorConvertDouble4ToU32(r, g, b, alpha / 255)
  
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y1 + header_height, header_color, M.CONFIG.rounding)
  
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y1 + header_height, M.CONFIG.header.text_shadow, M.CONFIG.rounding)
end

function M.render_placeholder(dl, x1, y1, x2, y2, base_color, is_midi, alpha)
  if not Colors then return end
  
  local r, g, b = ImGui.ColorConvertU32ToDouble4(base_color)
  local h, s, v = ImGui.ColorConvertRGBtoHSV(r, g, b)
  
  s = s * 0.3
  v = v * 0.2
  
  r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)
  local placeholder_color = ImGui.ColorConvertDouble4ToU32(r, g, b, alpha)
  
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, placeholder_color)
  
  local center_x = (x1 + x2) / 2
  local center_y = (y1 + y2) / 2
  local size = math.min(x2 - x1, y2 - y1) * 0.15
  
  local spinner_alpha = math.floor(alpha * 128)
  local spinner_color = Colors.with_alpha(hexrgb("#FFFFFF"), spinner_alpha)
  
  local time = reaper.time_precise()
  local angle = (time * 2) % (math.pi * 2)
  
  for i = 0, 7 do
    local a = angle + (i * math.pi / 4)
    local radius = size * (0.3 + 0.7 * ((i + 1) / 8))
    local px = center_x + math.cos(a) * size
    local py = center_y + math.sin(a) * size
    ImGui.DrawList_AddCircleFilled(dl, px, py, radius, spinner_color)
  end
end

function M.render_complete_tile(ctx, dl, rect, item_data, tile_state, base_color, animator, visualization, cache_mgr, is_disabled, overlay_alpha)
  overlay_alpha = overlay_alpha or 1.0
  
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local tile_w, tile_h = x2 - x1, y2 - y1
  local center_x, center_y = (x1 + x2) / 2, (y1 + y2) / 2
  
  local cascade_factor = calculate_cascade_factor(rect, overlay_alpha)
  
  if cascade_factor < 0.001 then
    return
  end
  
  local scale = M.CONFIG.cascade.scale_from + (1.0 - M.CONFIG.cascade.scale_from) * cascade_factor
  local y_offset = M.CONFIG.cascade.y_offset * (1.0 - cascade_factor)
  
  local scaled_w = tile_w * scale
  local scaled_h = tile_h * scale
  local scaled_x1 = center_x - scaled_w / 2
  local scaled_y1 = center_y - scaled_h / 2 + y_offset
  local scaled_x2 = center_x + scaled_w / 2
  local scaled_y2 = center_y + scaled_h / 2 + y_offset
  
  if animator and item_data.key then
    animator:track(item_data.key, 'hover', tile_state.hover and 1.0 or 0.0, M.CONFIG.animation_speed_hover)
    animator:track(item_data.key, 'enabled', is_disabled and 0.0 or 1.0, M.CONFIG.disabled.fade_speed)
  end
  
  local hover_factor = animator and animator:get(item_data.key, 'hover') or (tile_state.hover and 1.0 or 0.0)
  local enabled_factor = animator and animator:get(item_data.key, 'enabled') or (is_disabled and 0.0 or 1.0)
  
  local render_color = base_color
  if enabled_factor < 1.0 and Colors then
    render_color = Colors.desaturate(render_color, M.CONFIG.disabled.desaturate * (1.0 - enabled_factor))
    render_color = Colors.adjust_brightness(render_color, 1.0 - (1.0 - M.CONFIG.disabled.brightness) * (1.0 - enabled_factor))
  end
  
  local combined_alpha = cascade_factor * enabled_factor
  if Colors then
    local base_alpha = (render_color & 0xFF) / 255
    local final_alpha = base_alpha * combined_alpha
    render_color = Colors.with_alpha(render_color, math.floor(final_alpha * 255))
  end
  
  local show_text = tile_h >= M.CONFIG.responsive.hide_text_below
  local show_badge = tile_h >= M.CONFIG.responsive.hide_badge_below
  local text_alpha = math.floor(0xFF * combined_alpha)
  
  local header_height = math.max(M.CONFIG.header.min_height, tile_h * M.CONFIG.header.height_ratio)
  if show_text then
    header_height = math.max(header_height, ImGui.GetTextLineHeight(ctx) + M.CONFIG.text.padding_top * 2)
  end
  
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathLineTo(dl, scaled_x1, scaled_y1)
  ImGui.DrawList_PathLineTo(dl, scaled_x2, scaled_y1)
  ImGui.DrawList_PathLineTo(dl, scaled_x2, scaled_y2)
  ImGui.DrawList_PathLineTo(dl, scaled_x1, scaled_y2)
  ImGui.DrawList_PathFillConvex(dl, render_color)
  
  local fx_config = {}
  for k, v in pairs(M.CONFIG.tile_fx) do
    fx_config[k] = v
  end
  fx_config.rounding = M.CONFIG.rounding
  fx_config.ants_replace_border = false
  
  if TileFX then
    TileFX.render_complete(dl, scaled_x1, scaled_y1, scaled_x2, scaled_y2, render_color, fx_config, tile_state.selected, hover_factor, 0, 0)
  end
  
  render_header_bar(dl, scaled_x1, scaled_y1, scaled_x2, header_height, base_color, combined_alpha)
  
  if tile_state.selected and MarchingAnts and M.CONFIG.tile_fx.ants_enabled and cascade_factor > 0.5 then
    local ant_color
    if Colors then
      ant_color = Colors.same_hue_variant(
        base_color,
        M.CONFIG.tile_fx.border_saturation,
        M.CONFIG.tile_fx.border_brightness,
        math.floor(M.CONFIG.tile_fx.ants_alpha * combined_alpha)
      )
    else
      ant_color = hexrgb("#FFFFFF")
    end
    
    local inset = M.CONFIG.tile_fx.ants_inset
    MarchingAnts.draw(
      dl,
      scaled_x1 + inset, scaled_y1 + inset, scaled_x2 - inset, scaled_y2 - inset,
      ant_color,
      M.CONFIG.tile_fx.ants_thickness,
      M.CONFIG.rounding,
      M.CONFIG.tile_fx.ants_dash,
      M.CONFIG.tile_fx.ants_gap,
      M.CONFIG.tile_fx.ants_speed
    )
  end
  
  if show_text and cascade_factor > 0.3 then
    local text_x = scaled_x1 + M.CONFIG.text.padding_left
    local text_y = scaled_y1 + (header_height - ImGui.GetTextLineHeight(ctx)) / 2
    
    local right_bound_x = scaled_x2 - M.CONFIG.text.margin_right
    if show_badge and item_data.total and item_data.total > 1 then
      local badge_text = string.format("%d/%d", item_data.index or 1, item_data.total)
      local bw, _ = ImGui.CalcTextSize(ctx, badge_text)
      right_bound_x = right_bound_x - (bw + M.CONFIG.badge.padding_x * 2 + M.CONFIG.badge.margin)
    end
    
    local available_width = right_bound_x - text_x
    local truncated_name = truncate_text(ctx, item_data.name, available_width)
    
    if Draw then
      Draw.text(dl, text_x, text_y, Colors and Colors.with_alpha(M.CONFIG.text.primary_color, text_alpha) or M.CONFIG.text.primary_color, truncated_name)
    else
      ImGui.DrawList_AddText(dl, text_x, text_y, Colors and Colors.with_alpha(M.CONFIG.text.primary_color, text_alpha) or M.CONFIG.text.primary_color, truncated_name)
    end
  end
  
  if show_badge and item_data.total and item_data.total > 1 and cascade_factor > 0.3 then
    local badge_text = string.format("%d/%d", item_data.index or 1, item_data.total)
    local bw, bh = ImGui.CalcTextSize(ctx, badge_text)
    
    local badge_x = scaled_x2 - bw - M.CONFIG.badge.padding_x * 2 - M.CONFIG.badge.margin
    local badge_y = scaled_y1 + (header_height - (bh + M.CONFIG.badge.padding_y * 2)) / 2
    local badge_x2 = badge_x + bw + M.CONFIG.badge.padding_x * 2
    local badge_y2 = badge_y + bh + M.CONFIG.badge.padding_y * 2
    
    local badge_bg = (M.CONFIG.badge.bg & 0xFFFFFF00) | (math.floor(((M.CONFIG.badge.bg & 0xFF) * combined_alpha)))
    
    ImGui.DrawList_AddRectFilled(dl, badge_x, badge_y, badge_x2, badge_y2, badge_bg, M.CONFIG.badge.rounding)
    
    if Colors then
      ImGui.DrawList_AddRect(dl, badge_x, badge_y, badge_x2, badge_y2, 
        Colors.with_alpha(base_color, M.CONFIG.badge.border_alpha), 
        M.CONFIG.badge.rounding, 0, 0.5)
    end
    
    if Draw then
      Draw.text(dl, badge_x + M.CONFIG.badge.padding_x, badge_y + M.CONFIG.badge.padding_y, 
        Colors and Colors.with_alpha(hexrgb("#FFFFFFDD"), text_alpha) or hexrgb("#FFFFFFDD"), badge_text)
    else
      ImGui.DrawList_AddText(dl, badge_x + M.CONFIG.badge.padding_x, badge_y + M.CONFIG.badge.padding_y, 
        Colors and Colors.with_alpha(hexrgb("#FFFFFFDD"), text_alpha) or hexrgb("#FFFFFFDD"), badge_text)
    end
  end
  
  if not is_disabled and item_data.item and cascade_factor > 0.2 then
    local content_y1 = scaled_y1 + header_height
    local content_w = scaled_w
    local content_h = scaled_y2 - content_y1
    
    ImGui.SetCursorScreenPos(ctx, scaled_x1, content_y1)
    ImGui.Dummy(ctx, content_w, content_h)
    
    local dark_color = get_dark_waveform_color(base_color)
    if Colors then
      local waveform_alpha = combined_alpha * M.CONFIG.waveform.line_alpha
      dark_color = Colors.with_alpha(dark_color, math.floor(waveform_alpha * 255))
    end
    
    if item_data.is_midi then
      local thumbnail = cache_mgr and cache_mgr.get_midi_thumbnail(item_data.cache, item_data.item, content_w, content_h)
      if thumbnail then
        if visualization.DisplayMidiItemTransparent then
          ImGui.SetCursorScreenPos(ctx, scaled_x1, content_y1)
          ImGui.Dummy(ctx, content_w, content_h)
          visualization.DisplayMidiItemTransparent(ctx, thumbnail, dark_color, dl)
        end
      else
        M.render_placeholder(dl, scaled_x1, content_y1, scaled_x2, scaled_y2, render_color, true, combined_alpha)
        if item_data.job_queue and item_data.job_queue.add_midi_job then
          item_data.job_queue.add_midi_job(item_data.cache, item_data.item, content_w, content_h, item_data.key)
        end
      end
    else
      local waveform = cache_mgr and cache_mgr.get_waveform_data(item_data.cache, item_data.item)
      if waveform then
        if visualization.DisplayWaveformTransparent then
          visualization.DisplayWaveformTransparent(ctx, waveform, dark_color, dl, content_w)
        end
      else
        M.render_placeholder(dl, scaled_x1, content_y1, scaled_x2, scaled_y2, render_color, false, combined_alpha)
        if item_data.job_queue and item_data.job_queue.add_waveform_job then
          item_data.job_queue.add_waveform_job(item_data.cache, item_data.item, item_data.key)
        end
      end
    end
  end
end

return M