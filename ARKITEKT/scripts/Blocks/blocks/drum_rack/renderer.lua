-- @noindex
-- Blocks/blocks/drum_rack/renderer.lua
-- Drum pad tile renderer inspired by RegionPlaylist tile style

local ImGui = require('arkitekt.core.imgui')
local Ark = require('arkitekt')

local TileFX = require('arkitekt.gui.renderers.tile.renderer')
local TileFXConfig = require('arkitekt.gui.renderers.tile.defaults')

-- Performance: Localize functions
local Colors = Ark.Colors
local Colors_WithAlpha = Colors.WithAlpha
local Colors_WithOpacity = Colors.WithOpacity
local Colors_AdjustBrightness = Colors.AdjustBrightness
local Colors_SameHueVariant = Colors.SameHueVariant
local Colors_Luminance = Colors.Luminance
local Colors_Lerp = Colors.Lerp
local Draw_Text = Ark.Draw.Text

local M = {}

M.CONFIG = {
  -- Appearance
  empty_color = 0x2A2A2AFF,
  rounding = 6,

  -- Text
  name_padding = { x = 8, y = 6 },
  name_color = 0xFFFFFFFF,
  name_shadow_color = 0x00000099,

  -- MIDI note badge
  badge = {
    padding_x = 5,
    padding_y = 3,
    margin = 4,
    rounding = 4,
    bg_color = 0x00000080,
    text_color = 0xFFFFFFDD,
  },

  -- Volume bar
  volume_bar = {
    height = 4,
    margin = 4,
    bg_color = 0x00000050,
    rounding = 2,
  },

  -- Responsive thresholds
  responsive = {
    hide_name_below = 50,
    hide_badge_below = 45,
    hide_volume_below = 55,
  },
}

--- Render a drum pad tile
--- @param ctx userdata ImGui context
--- @param rect table {x1, y1, x2, y2}
--- @param pad table Pad data {name, note, color, has_sample, volume, uuid, ...}
--- @param tile_state table {hover, pressed, selected}
--- @param animator table? Optional animator for hover effects
--- @param is_drop_target boolean? True if this pad is being targeted for a drop
--- @param visualization table? Visualization module for waveforms
--- @param runtime_cache table? Runtime cache with waveform data
function M.render(ctx, rect, pad, tile_state, animator, is_drop_target, visualization, runtime_cache)
  local dl = ImGui.GetWindowDrawList(ctx)
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local w, h = x2 - x1, y2 - y1

  -- Get tile FX config
  local fx_config = TileFXConfig.get()

  -- Determine base color
  local base_color = pad.has_sample and pad.color or M.CONFIG.empty_color

  -- Track hover animation if animator provided
  local hover_factor = 0
  if animator and pad.key then
    animator:track(pad.key, 'hover', tile_state.hover and 1.0 or 0.0, 12.0)
    hover_factor = animator:get(pad.key, 'hover')
  elseif tile_state.hover then
    hover_factor = 1.0
  end

  -- Override for drop target state
  local border_color = base_color
  if is_drop_target then
    border_color = 0x42E896FF  -- Green drop indicator
    hover_factor = 1.0  -- Force hover state for visual feedback
  end

  -- Draw base tile with TileFX (includes shadow, glow, border, etc.)
  TileFX.render_complete_fast(
    ctx, dl,
    x1, y1, x2, y2,
    base_color,
    fx_config,
    tile_state.selected or is_drop_target,
    hover_factor,
    0,  -- playback_progress
    0,  -- playback_fade
    border_color,  -- border_color
    base_color,  -- progress_color
    nil,  -- stripe_color
    false  -- stripe_enabled
  )

  -- Additional drop target indicator
  if is_drop_target then
    local drop_color = 0x42E89644  -- Green with alpha
    ImGui.DrawList_AddRect(dl, x1 + 2, y1 + 2, x2 - 2, y2 - 2, 0x42E896FF, M.CONFIG.rounding - 2, 0, 2)
  end

  -- Draw waveform if available
  if pad.has_sample and pad.uuid and visualization and runtime_cache then
    local waveform = runtime_cache.waveforms and runtime_cache.waveforms[pad.uuid]
    if waveform and visualization.DisplayWaveformTransparent then
      -- Calculate waveform area (content area below header)
      local header_h = 20  -- Approximate header height
      local content_y = y1 + header_h
      local content_h = h - header_h - 12  -- Leave room for volume bar
      local content_w = w

      -- Waveform color = border color at 50% opacity
      local wave_color = Colors_WithOpacity(border_color, 0.5)

      -- Match ItemPicker's waveform quality (0.2 = 20% resolution for performance)
      local waveform_quality = 0.2
      local target_width = (content_w * waveform_quality) // 1

      -- Position for waveform (uses GetItemRect internally)
      ImGui.SetCursorScreenPos(ctx, x1, content_y)
      ImGui.Dummy(ctx, content_w, content_h)
      -- use_filled = false for polyline style
      visualization.DisplayWaveformTransparent(ctx, waveform, wave_color, dl, target_width, pad.uuid, runtime_cache, false)
    end
  end

  -- Responsive visibility
  local show_name = h >= M.CONFIG.responsive.hide_name_below
  local show_badge = h >= M.CONFIG.responsive.hide_badge_below
  local show_volume = h >= M.CONFIG.responsive.hide_volume_below and pad.has_sample

  -- Draw pad name (top-left)
  if show_name and pad.name and pad.name ~= '' then
    local name_x = x1 + M.CONFIG.name_padding.x
    local name_y = y1 + M.CONFIG.name_padding.y

    -- Determine text color based on background luminance
    local lum = Colors_Luminance(base_color)
    local name_color = lum > 0.5 and 0x000000FF or M.CONFIG.name_color

    -- Shadow for better readability
    Draw_Text(dl, name_x + 1, name_y + 1, M.CONFIG.name_shadow_color, pad.name)
    Draw_Text(dl, name_x, name_y, name_color, pad.name)
  end

  -- Draw MIDI note badge (top-right)
  if show_badge and pad.note then
    local note_text = tostring(pad.note)
    local note_w, note_h = ImGui.CalcTextSize(ctx, note_text)

    local badge_w = note_w + M.CONFIG.badge.padding_x * 2
    local badge_h = note_h + M.CONFIG.badge.padding_y * 2
    local badge_x = x2 - badge_w - M.CONFIG.badge.margin
    local badge_y = y1 + M.CONFIG.badge.margin

    -- Badge background
    ImGui.DrawList_AddRectFilled(dl,
      badge_x, badge_y,
      badge_x + badge_w, badge_y + badge_h,
      M.CONFIG.badge.bg_color, M.CONFIG.badge.rounding)

    -- Badge text
    Draw_Text(dl,
      badge_x + M.CONFIG.badge.padding_x,
      badge_y + M.CONFIG.badge.padding_y,
      M.CONFIG.badge.text_color,
      note_text)

    -- Pitch offset badge (below note) - only show if pitch != 0
    if pad.pitch and math.abs(pad.pitch) > 0.5 then
      local pitch_text = string.format('%+.0fst', pad.pitch)
      local pitch_w, pitch_h = ImGui.CalcTextSize(ctx, pitch_text)
      local pitch_badge_w = pitch_w + M.CONFIG.badge.padding_x * 2
      local pitch_badge_h = pitch_h + M.CONFIG.badge.padding_y * 2
      local pitch_badge_x = x2 - pitch_badge_w - M.CONFIG.badge.margin
      local pitch_badge_y = badge_y + badge_h + 2

      -- Pitch badge background (tinted)
      local pitch_bg = pad.pitch > 0 and 0x4A88D980 or 0xD94A4A80
      ImGui.DrawList_AddRectFilled(dl,
        pitch_badge_x, pitch_badge_y,
        pitch_badge_x + pitch_badge_w, pitch_badge_y + pitch_badge_h,
        pitch_bg, M.CONFIG.badge.rounding)

      Draw_Text(dl,
        pitch_badge_x + M.CONFIG.badge.padding_x,
        pitch_badge_y + M.CONFIG.badge.padding_y,
        M.CONFIG.badge.text_color,
        pitch_text)
    end

    -- Velocity layers badge (bottom-right) - only show if > 1 layer
    if pad.layer_count and pad.layer_count > 1 then
      local layer_text = string.format('%dL', pad.layer_count)
      local layer_w, layer_h = ImGui.CalcTextSize(ctx, layer_text)
      local layer_badge_w = layer_w + M.CONFIG.badge.padding_x * 2
      local layer_badge_h = layer_h + M.CONFIG.badge.padding_y * 2
      local layer_badge_x = x2 - layer_badge_w - M.CONFIG.badge.margin
      local layer_badge_y = y2 - layer_badge_h - M.CONFIG.volume_bar.height - M.CONFIG.badge.margin * 2

      -- Layer badge background (purple tint)
      ImGui.DrawList_AddRectFilled(dl,
        layer_badge_x, layer_badge_y,
        layer_badge_x + layer_badge_w, layer_badge_y + layer_badge_h,
        0x884AD980, M.CONFIG.badge.rounding)

      Draw_Text(dl,
        layer_badge_x + M.CONFIG.badge.padding_x,
        layer_badge_y + M.CONFIG.badge.padding_y,
        M.CONFIG.badge.text_color,
        layer_text)
    end
  end

  -- Draw volume bar (bottom)
  if show_volume then
    local bar_margin = M.CONFIG.volume_bar.margin
    local bar_h = M.CONFIG.volume_bar.height
    local bar_x1 = x1 + bar_margin
    local bar_x2 = x2 - bar_margin
    local bar_y1 = y2 - bar_h - bar_margin
    local bar_y2 = y2 - bar_margin
    local bar_w = bar_x2 - bar_x1

    -- Background track
    ImGui.DrawList_AddRectFilled(dl,
      bar_x1, bar_y1, bar_x2, bar_y2,
      M.CONFIG.volume_bar.bg_color, M.CONFIG.volume_bar.rounding)

    -- Volume level
    local volume = pad.volume or 1.0
    local level_w = bar_w * volume
    local level_color = Colors_AdjustBrightness(base_color, 1.4)

    ImGui.DrawList_AddRectFilled(dl,
      bar_x1, bar_y1, bar_x1 + level_w, bar_y2,
      level_color, M.CONFIG.volume_bar.rounding)
  end

  -- Empty pad indicator
  if not pad.has_sample and show_name then
    local plus_color = Colors_WithOpacity(0xFFFFFFFF, 0.2)
    local cx, cy = (x1 + x2) / 2, (y1 + y2) / 2

    -- Draw + icon
    local plus_size = math.min(w, h) * 0.2
    ImGui.DrawList_AddLine(dl, cx - plus_size, cy, cx + plus_size, cy, plus_color, 2)
    ImGui.DrawList_AddLine(dl, cx, cy - plus_size, cx, cy + plus_size, plus_color, 2)
  end
end

return M
