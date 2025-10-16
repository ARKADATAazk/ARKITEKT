local M = {}
local imgui
local ctx
local config
local Colors
local MarchingAnts
local Draw
local TileFX

function M.init(imgui_module, imgui_ctx, config_module, colors_module, marching_ants_module, draw_module, tile_fx_module)
  imgui = imgui_module
  ctx = imgui_ctx
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
    text_shadow = 0x00000099,
  },
  
  badge = {
    padding_x = 6,
    padding_y = 3,
    margin = 6,
    rounding = 4,
    bg = 0x14181CFF,
    border_alpha = 0x33,
  },
  
  text = {
    primary_color = 0xFFFFFFFF,
    padding_left = 6,
    padding_top = 4,
    margin_right = 6,
  },
  
  waveform = {
    saturation = 0.3,
    brightness = 0.15,
    line_alpha = 0.8,  -- Changed to 80% opacity
    zero_line_alpha = 0.3,
  },
  
  tile_fx = {
    fill_opacity = 0.65,
    fill_saturation = 0.75,
    fill_brightness = 0.6,  -- Back to original
    
    border_opacity = 0.0,  -- Set to 0 (no border)
    border_saturation = 0.8,
    border_brightness = 1.4,
    border_thickness = 1.0,
    
    index_saturation = 1,
    index_brightness = 1.6,
    
    separator_saturation = 1,
    separator_brightness = 1.6,
    separator_alpha = 0x99,
    
    name_brightness = 1.0,
    name_base_color = 0xDDE3E9FF,
    
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
  
  responsive = {
    hide_text_below = 35,
    hide_badge_below = 25,
  },
}


local function truncate_text(ctx, text, max_width)
  if not text or max_width <= 0 then return "" end
  local text_width = imgui.CalcTextSize(ctx, text)
  if text_width <= max_width then return text end
  
  local ellipsis = "..."
  local ellipsis_width = imgui.CalcTextSize(ctx, ellipsis)
  if max_width <= ellipsis_width then return "" end
  
  local available_width = max_width - ellipsis_width
  for i = #text, 1, -1 do
    local truncated = text:sub(1, i)
    if imgui.CalcTextSize(ctx, truncated) <= available_width then
      return truncated .. ellipsis
    end
  end
  return ellipsis
end

local function get_dark_waveform_color(base_color)
  if not Colors then
    return 0x333333FF
  end
  
  local r, g, b = imgui.ColorConvertU32ToDouble4(base_color)
  local h, s, v = imgui.ColorConvertRGBtoHSV(r, g, b)
  
  s = M.CONFIG.waveform.saturation
  v = M.CONFIG.waveform.brightness
  
  r, g, b = imgui.ColorConvertHSVtoRGB(h, s, v)
  return imgui.ColorConvertDouble4ToU32(r, g, b, M.CONFIG.waveform.line_alpha)
end

local function render_header_bar(dl, x1, y1, x2, header_height, base_color, enabled_factor)
  if not Colors then
    imgui.DrawList_AddRectFilled(dl, x1, y1, x2, y1 + header_height, base_color, M.CONFIG.rounding)
    return
  end
  
  local r, g, b = imgui.ColorConvertU32ToDouble4(base_color)
  local h, s, v = imgui.ColorConvertRGBtoHSV(r, g, b)
  
  s = s * M.CONFIG.header.saturation_factor
  v = v * M.CONFIG.header.brightness_factor
  
  r, g, b = imgui.ColorConvertHSVtoRGB(h, s, v)
  
  local alpha = M.CONFIG.header.alpha
  if enabled_factor < 1.0 then
    alpha = math.floor(alpha * enabled_factor + M.CONFIG.disabled.min_alpha * (1.0 - enabled_factor))
  end
  
  local header_color = imgui.ColorConvertDouble4ToU32(r, g, b, alpha / 255)
  
  imgui.DrawList_AddRectFilled(dl, x1, y1, x2, y1 + header_height, header_color, M.CONFIG.rounding)
  
  imgui.DrawList_AddRectFilled(dl, x1, y1, x2, y1 + header_height, M.CONFIG.header.text_shadow, M.CONFIG.rounding)
end

function M.render_complete_tile(dl, rect, item_data, tile_state, base_color, animator, visualization, cache_mgr, is_disabled)
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local tile_w, tile_h = x2 - x1, y2 - y1
  
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
  
  local show_text = tile_h >= M.CONFIG.responsive.hide_text_below
  local show_badge = tile_h >= M.CONFIG.responsive.hide_badge_below
  local text_alpha = math.floor(0xFF * enabled_factor + M.CONFIG.disabled.min_alpha * (1.0 - enabled_factor))
  
  local header_height = math.max(M.CONFIG.header.min_height, tile_h * M.CONFIG.header.height_ratio)
  if show_text then
    header_height = math.max(header_height, imgui.GetTextLineHeight(ctx) + M.CONFIG.text.padding_top * 2)
  end
  
  local fx_config = {}
  for k, v in pairs(M.CONFIG.tile_fx) do
    fx_config[k] = v
  end
  fx_config.rounding = M.CONFIG.rounding
  fx_config.ants_replace_border = false
  
  if TileFX then
    TileFX.render_complete(dl, x1, y1, x2, y2, render_color, fx_config, tile_state.selected, hover_factor, 0, 0)
  end
  
  render_header_bar(dl, x1, y1, x2, header_height, base_color, enabled_factor)
  
  if tile_state.selected and MarchingAnts and M.CONFIG.tile_fx.ants_enabled then
    local ant_color
    if Colors then
      ant_color = Colors.same_hue_variant(
        base_color,
        M.CONFIG.tile_fx.border_saturation,
        M.CONFIG.tile_fx.border_brightness,
        M.CONFIG.tile_fx.ants_alpha
      )
    else
      ant_color = 0xFFFFFFFF
    end
    
    local inset = M.CONFIG.tile_fx.ants_inset
    MarchingAnts.draw(
      dl,
      x1 + inset, y1 + inset, x2 - inset, y2 - inset,
      ant_color,
      M.CONFIG.tile_fx.ants_thickness,
      M.CONFIG.rounding,
      M.CONFIG.tile_fx.ants_dash,
      M.CONFIG.tile_fx.ants_gap,
      M.CONFIG.tile_fx.ants_speed
    )
  end
  
  if show_text then
    local text_x = x1 + M.CONFIG.text.padding_left
    local text_y = y1 + (header_height - imgui.GetTextLineHeight(ctx)) / 2
    
    local right_bound_x = x2 - M.CONFIG.text.margin_right
    if show_badge and item_data.total and item_data.total > 1 then
      local badge_text = string.format("%d/%d", item_data.index or 1, item_data.total)
      local bw, _ = imgui.CalcTextSize(ctx, badge_text)
      right_bound_x = right_bound_x - (bw + M.CONFIG.badge.padding_x * 2 + M.CONFIG.badge.margin)
    end
    
    local available_width = right_bound_x - text_x
    local truncated_name = truncate_text(ctx, item_data.name, available_width)
    
    if Draw then
      Draw.text(dl, text_x, text_y, Colors and Colors.with_alpha(M.CONFIG.text.primary_color, text_alpha) or M.CONFIG.text.primary_color, truncated_name)
    else
      imgui.DrawList_AddText(dl, text_x, text_y, Colors and Colors.with_alpha(M.CONFIG.text.primary_color, text_alpha) or M.CONFIG.text.primary_color, truncated_name)
    end
  end
  
  if show_badge and item_data.total and item_data.total > 1 then
    local badge_text = string.format("%d/%d", item_data.index or 1, item_data.total)
    local bw, bh = imgui.CalcTextSize(ctx, badge_text)
    
    local badge_x = x2 - bw - M.CONFIG.badge.padding_x * 2 - M.CONFIG.badge.margin
    local badge_y = y1 + (header_height - (bh + M.CONFIG.badge.padding_y * 2)) / 2
    local badge_x2 = badge_x + bw + M.CONFIG.badge.padding_x * 2
    local badge_y2 = badge_y + bh + M.CONFIG.badge.padding_y * 2
    
    local badge_bg = (M.CONFIG.badge.bg & 0xFFFFFF00) | (math.floor(((M.CONFIG.badge.bg & 0xFF) * enabled_factor) + (M.CONFIG.disabled.min_alpha * (1.0 - enabled_factor))))
    
    imgui.DrawList_AddRectFilled(dl, badge_x, badge_y, badge_x2, badge_y2, badge_bg, M.CONFIG.badge.rounding)
    
    if Colors then
      imgui.DrawList_AddRect(dl, badge_x, badge_y, badge_x2, badge_y2, 
        Colors.with_alpha(base_color, M.CONFIG.badge.border_alpha), 
        M.CONFIG.badge.rounding, 0, 0.5)
    end
    
    if Draw then
      Draw.text(dl, badge_x + M.CONFIG.badge.padding_x, badge_y + M.CONFIG.badge.padding_y, 
        Colors and Colors.with_alpha(0xFFFFFFDD, text_alpha) or 0xFFFFFFDD, badge_text)
    else
      imgui.DrawList_AddText(dl, badge_x + M.CONFIG.badge.padding_x, badge_y + M.CONFIG.badge.padding_y, 
        Colors and Colors.with_alpha(0xFFFFFFDD, text_alpha) or 0xFFFFFFDD, badge_text)
    end
  end
  
  if not is_disabled and item_data.item then
    local content_y1 = y1 + header_height
    imgui.SetCursorScreenPos(ctx, x1, content_y1)
    imgui.Dummy(ctx, tile_w, y2 - content_y1)
    
    local dark_color = get_dark_waveform_color(base_color)
    
    if item_data.is_midi then
      if visualization.DisplayMidiItemTransparent then
        local thumbnail = cache_mgr and cache_mgr.get_midi_thumbnail(item_data.cache, item_data.item, tile_w, y2 - content_y1)
        if not thumbnail and visualization.GetMidiThumbnail then
          thumbnail = visualization.GetMidiThumbnail(item_data.cache, item_data.item)
        end
        if thumbnail then
          imgui.SetCursorScreenPos(ctx, x1, content_y1)
          imgui.Dummy(ctx, tile_w, y2 - content_y1)
          visualization.DisplayMidiItemTransparent(thumbnail, dark_color, dl)
        end
      end
    else
      if visualization.DisplayWaveformTransparent then
        local waveform = visualization.GetItemWaveform and visualization.GetItemWaveform(item_data.cache, item_data.item)
        if waveform then
          visualization.DisplayWaveformTransparent(waveform, dark_color, dl, tile_w)
        end
      end
    end
  end
end

return M