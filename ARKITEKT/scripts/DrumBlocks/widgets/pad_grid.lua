-- @noindex
-- DrumBlocks/widgets/pad_grid.lua
-- 4x4 pad grid widget using Ark.Grid with fixed_cols=4

local Ark = require('arkitekt')
local ImGui = Ark.ImGui
local Colors = Ark.Colors
local WidgetBase = require('arkitekt.gui.widgets.base')
local Icons = require('arkitekt.gui.draw.icons')
local TileFX = require('arkitekt.gui.renderers.tile.renderer')
local TileFXConfig = require('arkitekt.gui.renderers.tile.defaults')
local MarchingAnts = require('arkitekt.gui.interaction.marching_ants')
local Bridge = require('DrumBlocks.domain.bridge')
local MXRender = require('DrumBlocks.domain.mx_render')
local ColorPickerMenu = require('arkitekt.gui.widgets.menus.color_picker_menu')

-- Cache functions for performance (per LUA_PERFORMANCE_GUIDE.md)
local max, min, sqrt = math.max, math.min, math.sqrt
local AddPolyline = ImGui.DrawList_AddPolyline
local new_array = reaper.new_array

-- Selection highlight animation state
local selection_highlight = {
  start_time = reaper.time_precise(),  -- Initialize to current time
  duration = 2.0,  -- 2 second strobe cycle
}

-- Clipboard for copy/paste
local clipboard = {
  pads = {},  -- Array of copied pad data
}

-- Toast notification state
local toast = {
  message = nil,
  start_time = 0,
  duration = 1.2,  -- seconds
}

local M = {}

-- ============================================================================
-- MIDI NOTE NAMES
-- ============================================================================

local NOTE_NAMES = { 'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B' }

local function midi_to_note_name(midi_note)
  local note_idx = midi_note % 12
  local octave = math.floor(midi_note / 12) - 1
  return NOTE_NAMES[note_idx + 1] .. octave
end

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local DEFAULT_PAD_SIZE = 80
local DEFAULT_PAD_SPACING = 6
local FOOTER_H = 20

local COLORS = {
  pad_empty = 0x2A2A2AFF,
  pad_loaded = 0x3A3A3AFF,      -- Grayscale (no blue tint)
  pad_border = 0x555555FF,
  pad_border_selected = 0x999999FF,  -- Light gray (no blue tint)
  text = 0xFFFFFFFF,
}

-- ============================================================================
-- ITEMPICKER INTEGRATION
-- ============================================================================

local ItemPickerState = nil
local itempicker_loaded = false

local function ensure_itempicker()
  if itempicker_loaded then return end
  itempicker_loaded = true
  local ok, ip_state = pcall(require, 'ItemPicker.app.state')
  if ok then ItemPickerState = ip_state end
end

local function is_itempicker_dragging_audio()
  if not ItemPickerState then return false end
  return ItemPickerState.dragging == true and ItemPickerState.dragging_is_audio == true
end

local function get_dragged_sample()
  if not ItemPickerState or not ItemPickerState.dragging_keys then
    return nil, nil
  end
  local uuid = ItemPickerState.dragging_keys[1]
  if not uuid then return nil, nil end
  local item_data = ItemPickerState.audio_item_lookup and ItemPickerState.audio_item_lookup[uuid]
  return item_data, uuid
end

local function get_source_path(media_item)
  if not media_item or not reaper.ValidatePtr2(0, media_item, 'MediaItem*') then
    return nil
  end
  local take = reaper.GetActiveTake(media_item)
  if not take then return nil end
  local source = reaper.GetMediaItemTake_Source(take)
  if reaper.BR_GetMediaSourceProperties then
    local _, _, _, _, _, reverse = reaper.BR_GetMediaSourceProperties(take)
    if reverse and source then
      local parent = reaper.GetMediaSourceParent(source)
      if parent then source = parent end
    end
  end
  if source then
    return reaper.GetMediaSourceFileName(source) or ''
  end
  return nil
end

-- ============================================================================
-- WAVEFORM RENDERING
-- ============================================================================

-- Calculate envelope value at position t (0-1) by interpolating between points
local function calc_envelope_at(t, points)
  if not points or #points < 2 then return 0.5 end
  t = math.max(0, math.min(1, t))

  -- Find surrounding points
  local p1, p2 = points[1], points[#points]
  for i = 1, #points - 1 do
    if t >= points[i].x and t <= points[i + 1].x then
      p1 = points[i]
      p2 = points[i + 1]
      break
    end
  end

  -- Interpolate
  local range = p2.x - p1.x
  if range < 0.001 then return p1.y end
  local alpha = (t - p1.x) / range
  return p1.y + (p2.y - p1.y) * alpha
end

-- Helper: get peak value with min/max window for smoothing (defined once, not per-frame)
local function get_peak_smooth(peaks, num_peaks, t_normalized, offset, window, is_max)
  local pos = t_normalized * (num_peaks - 1) + 1
  local half_w = window * 0.5
  local idx_start = max(1, (pos - half_w) // 1)
  local idx_end = min(num_peaks, (pos + half_w) // 1)

  local result = peaks[offset + idx_start]
  for idx = idx_start + 1, idx_end do
    local val = peaks[offset + idx]
    if is_max then
      if val > result then result = val end
    else
      if val < result then result = val end
    end
  end
  return result
end

-- Simple waveform drawing - shows ONLY the playable region (start to end markers)
-- Uses low LOD (256 peaks) with smooth downsampling for clean thumbnails
local function draw_waveform(ctx, dl, x, y, w, h, pad_index, pad_data, app_state, waveform_color)
  local start_point = pad_data.start_point or 0
  local end_point = pad_data.end_point or 1
  local region_size = max(0.001, end_point - start_point)

  -- Use 'low' tier (256 peaks) for pad thumbnails
  local peaks = app_state and app_state.getPadPeaks and app_state.getPadPeaks(pad_index, 0, 'low')
  if not peaks then return end

  local num_peaks = #peaks // 2  -- Use // for integer division
  if num_peaks < 2 then return end

  local mid_y = y + h * 0.5
  local volume = pad_data.volume or 1.0
  local base_scale = h * 0.4 * min(volume, 1.0)
  local color = waveform_color or 0x888888AA

  local volume_envelope = pad_data.volume_envelope
  local is_reversed = pad_data.reverse

  -- Get playable duration for scaling draw points
  local sample_duration = app_state and app_state.getSampleDuration and app_state.getSampleDuration(pad_index, 0)
  sample_duration = (sample_duration and sample_duration > 0) and sample_duration or 2
  local playable_duration = sample_duration * region_size

  -- Scale draw points by duration: short clips get more detail, long clips get smoothed
  local duration_factor = max(0.5, sqrt(playable_duration))
  local draw_points = max(48, min(192, 96 / duration_factor)) // 1
  local window = max(1, num_peaks / draw_points)

  -- Pre-calculate loop constants
  local inv_draw_points = 1 / (draw_points - 1)

  -- Build polylines
  local top_line, bot_line = {}, {}
  local ti, bi = 0, 0  -- Direct index tracking

  for i = 1, draw_points do
    local t = (i - 1) * inv_draw_points
    local px = x + t * w

    -- Map to position within the playable region
    local sample_t = is_reversed and (end_point - t * region_size) or (start_point + t * region_size)

    local max_val = get_peak_smooth(peaks, num_peaks, sample_t, 0, window, true)
    local min_val = get_peak_smooth(peaks, num_peaks, sample_t, num_peaks, window, false)

    -- Apply volume envelope if present
    local gain = volume_envelope and (calc_envelope_at(t, volume_envelope) * 2 * volume) or volume

    ti = ti + 1; top_line[ti] = px
    ti = ti + 1; top_line[ti] = mid_y + max_val * gain * base_scale
    bi = bi + 1; bot_line[bi] = px
    bi = bi + 1; bot_line[bi] = mid_y + min_val * gain * base_scale
  end

  -- Draw polylines (use cached functions)
  if ti >= 4 then
    AddPolyline(dl, new_array(top_line), color, ImGui.DrawFlags_None, 1.0)
    AddPolyline(dl, new_array(bot_line), color, ImGui.DrawFlags_None, 1.0)
  end
end

-- ============================================================================
-- DRAG-DROP STATE
-- ============================================================================

local drag_state = {
  -- ItemPicker integration
  drop_target_pad = nil,
  last_drop_target_pad = nil,
  was_mouse_down = false,
  was_dragging = false,
  cached_item_data = nil,
  cached_uuid = nil,

  -- Internal pad drag (supports multi-selection)
  internal_drag_sources = {},    -- Array of pad indices being dragged
  internal_drag_target = nil,    -- Current hover target
  internal_drag_started = false, -- Has drag threshold been exceeded
}

-- ============================================================================
-- PAD TILE RENDERER (for Ark.Grid render_item)
-- ============================================================================

-- Module-level state for footer button clicks (shared across render calls)
local footer_clicks = {}

local function render_pad_tile(ctx, rect, pad_item, tile_state, app_state, any_soloed, display_opts)
  local dl = ImGui.GetWindowDrawList(ctx)
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local w, h = x2 - x1, y2 - y1
  local rounding = 6

  local pad_index = pad_item.pad_index
  local pad_data = pad_item.pad_data

  -- Get pad's custom color
  local pad_color = pad_data.color

  -- Base color
  local base_color = COLORS.pad_empty
  if pad_color then
    base_color = pad_color
  elseif pad_data.name then
    base_color = COLORS.pad_loaded
  end

  -- Border color
  local border_color
  if pad_color then
    border_color = Colors.SameHueVariant(pad_color, 1.0, 1.6, 0xFF)
  else
    border_color = tile_state.selected and COLORS.pad_border_selected or COLORS.pad_border
  end

  -- Check if playing
  local is_playing = false
  if app_state.hasDrumBlocks() then
    is_playing = Bridge.isPlaying(app_state.getTrack(), app_state.getFxIndex(), pad_index)
  end

  -- Dimmed state (muted or not soloed when another is)
  local is_muted = pad_data.muted or false
  local is_soloed = pad_data.soloed or false
  local is_dimmed = is_muted or (any_soloed and not is_soloed)

  -- TileFX config
  local fx_config = TileFXConfig.get()
  local hover_factor = tile_state.hover and 1.0 or 0.0
  local playback_fade = is_playing and 1.0 or 0.0

  -- Draw main pad with TileFX
  TileFX.render_complete_fast(
    ctx, dl,
    x1, y1, x2, y2,
    base_color,
    fx_config,
    tile_state.selected,
    hover_factor,
    0,
    playback_fade,
    border_color,
    base_color,
    nil,
    false
  )

  -- Footer only for pads with samples
  local footer_y = y2 - FOOTER_H
  if pad_data.name then
    local footer_color = Colors.SameHueVariant(pad_color or base_color, 0.3, 0.25, 0xFF)
    ImGui.DrawList_AddRectFilled(dl, x1 + 1, footer_y, x2 - 1, y2 - 1, footer_color, rounding - 1, ImGui.DrawFlags_RoundCornersBottom)

    -- Footer separator
    local sep_color = Colors.WithOpacity(0x000000FF, 0.3)
    ImGui.DrawList_AddLine(dl, x1 + 1, footer_y, x2 - 1, footer_y, sep_color, 1)
  end

  -- Waveform or empty indicator
  local waveform_color = Colors.WithOpacity(border_color, 0.5)
  local content_h = pad_data.name and (h - FOOTER_H - 20) or (h - 24)  -- More space when no footer
  local waveform_x = x1 + 4
  local waveform_y = y1 + 20
  local waveform_w = w - 8
  local waveform_h = content_h - 4
  if pad_data.name and content_h > 10 then
    draw_waveform(ctx, dl, waveform_x, waveform_y, waveform_w, waveform_h, pad_index, pad_data, app_state, waveform_color)
  else
    -- Empty pad: draw "+" indicator centered in tile
    local plus_size = math.min(w, h) * 0.35
    local bar_thickness = 3
    local center_x = x1 + w / 2
    local center_y = y1 + h / 2
    local plus_color = 0x383838FF
    local half_size = plus_size / 2
    local half_thick = bar_thickness / 2
    -- Horizontal bar
    ImGui.DrawList_AddRectFilled(dl, center_x - half_size, center_y - half_thick, center_x + half_size, center_y + half_thick, plus_color)
    -- Vertical bar
    ImGui.DrawList_AddRectFilled(dl, center_x - half_thick, center_y - half_size, center_x + half_thick, center_y + half_size, plus_color)
  end

  -- Playback cursor (vertical line at current playback position)
  if is_playing and content_h > 10 then
    local progress = Bridge.getPadPlayProgress(app_state.getTrack(), app_state.getFxIndex(), pad_index)
    if progress and progress >= 0 and progress <= 1 then
      local cursor_x = waveform_x + progress * waveform_w
      local cursor_color = 0xFFFFFFDD  -- Bright white with some transparency
      ImGui.DrawList_AddLine(dl, cursor_x, waveform_y, cursor_x, waveform_y + waveform_h, cursor_color, 1.5)
    end
  end

  -- ========================================================================
  -- FOOTER BUTTONS (M / Play / S) - only for pads with samples
  -- ========================================================================
  local text_h = ImGui.GetTextLineHeight(ctx)

  if pad_data.name then
    local btn_margin = 3
    local btn_spacing = 2
    local btn_w = (w - btn_margin * 2 - btn_spacing * 2) / 3
    local btn_h = FOOTER_H - 4
    local btn_y = footer_y + 2

    local btn_colors = {
      normal = 0x888888FF,
      hover = 0xCCCCCCFF,
      active_mute = 0xFF6666FF,
      active_solo = 0xFFCC44FF,
    }

    local mute_x = x1 + btn_margin
    local play_x = mute_x + btn_w + btn_spacing
    local solo_x = play_x + btn_w + btn_spacing

    -- Separators
    local sep_btn_color = Colors.WithOpacity(0x000000FF, 0.4)
    ImGui.DrawList_AddLine(dl, play_x - 1, footer_y + 4, play_x - 1, footer_y + FOOTER_H - 4, sep_btn_color, 1)
    ImGui.DrawList_AddLine(dl, solo_x - 1, footer_y + 4, solo_x - 1, footer_y + FOOTER_H - 4, sep_btn_color, 1)

    local text_center_y = btn_y + (btn_h - text_h) / 2

    -- Get modifier keys for mute/solo behavior
    local mods = ImGui.GetKeyMods(ctx)
    local ctrl = (mods & ImGui.Mod_Ctrl) ~= 0
    local alt = (mods & ImGui.Mod_Alt) ~= 0

    -- M button
    -- Click: toggle, CTRL: unmute all, CTRL+ALT: exclusive, ALT: mute others
    ImGui.SetCursorScreenPos(ctx, mute_x, btn_y)
    if ImGui.InvisibleButton(ctx, '##mute_' .. pad_index, btn_w, btn_h) then
      footer_clicks[pad_index] = { action = 'mute', ctrl = ctrl, alt = alt }
    end
    local mute_hovered = ImGui.IsItemHovered(ctx)
    local mute_color = is_muted and btn_colors.active_mute or (mute_hovered and btn_colors.hover or btn_colors.normal)
    local m_w = ImGui.CalcTextSize(ctx, 'M')
    ImGui.DrawList_AddText(dl, mute_x + (btn_w - m_w) / 2, text_center_y, mute_color, 'M')

    -- Play button (small triangle, same style as M/S)
    ImGui.SetCursorScreenPos(ctx, play_x, btn_y)
    if ImGui.InvisibleButton(ctx, '##play_' .. pad_index, btn_w, btn_h) then
      footer_clicks[pad_index] = 'play'
    end
    local play_hovered = ImGui.IsItemHovered(ctx)
    local play_color = play_hovered and btn_colors.hover or btn_colors.normal
    -- Draw play triangle with AA outline
    local tri_cx = play_x + btn_w / 2
    local tri_cy = btn_y + btn_h / 2
    local half_w = 3.5
    local half_h = 4
    local x1_t, y1_t = tri_cx - half_w, tri_cy - half_h
    local x2_t, y2_t = tri_cx - half_w, tri_cy + half_h
    local x3_t, y3_t = tri_cx + half_w, tri_cy
    ImGui.DrawList_AddTriangleFilled(dl, x1_t, y1_t, x2_t, y2_t, x3_t, y3_t, play_color)
    ImGui.DrawList_AddTriangle(dl, x1_t, y1_t, x2_t, y2_t, x3_t, y3_t, play_color, 1.0)

    -- S button
    -- Click: toggle, CTRL: unsolo all, CTRL+ALT: exclusive solo
    ImGui.SetCursorScreenPos(ctx, solo_x, btn_y)
    if ImGui.InvisibleButton(ctx, '##solo_' .. pad_index, btn_w, btn_h) then
      footer_clicks[pad_index] = { action = 'solo', ctrl = ctrl, alt = alt }
    end
    local solo_hovered = ImGui.IsItemHovered(ctx)
    local solo_color = is_soloed and btn_colors.active_solo or (solo_hovered and btn_colors.hover or btn_colors.normal)
    local s_w = ImGui.CalcTextSize(ctx, 'S')
    ImGui.DrawList_AddText(dl, solo_x + (btn_w - s_w) / 2, text_center_y, solo_color, 'S')
  end

  -- ========================================================================
  -- TEXT ELEMENTS
  -- ========================================================================

  display_opts = display_opts or {}

  -- Badge (top-right): shows MIDI note or output bus depending on io_mode
  local badge_text
  if display_opts.io_mode then
    -- Show output bus (1-16, default 1)
    local output = (pad_data.output_group or 0) + 1  -- Convert 0-based to 1-based
    badge_text = tostring(output)
  else
    -- Show MIDI note name
    badge_text = midi_to_note_name(pad_index)
  end
  local badge_w = ImGui.CalcTextSize(ctx, badge_text)
  Ark.Badge.Text(ctx, {
    x = x2 - badge_w - 14,
    y = y1 + 4,
    text = badge_text,
    base_color = pad_color or border_color,
    draw_list = dl,
  })

  -- Choke group indicator (top-left) when choke_mode is on
  if display_opts.choke_mode and pad_data.kill_group and pad_data.kill_group > 0 then
    local choke_text = 'K' .. pad_data.kill_group
    Ark.Badge.Text(ctx, {
      x = x1 + 4,
      y = y1 + 4,
      text = choke_text,
      base_color = 0xFF6666FF,  -- Red tint for kill groups
      draw_list = dl,
    })
  end

  -- Sample name (above footer)
  if pad_data.name then
    local max_text_w = w - 10
    local name = WidgetBase.truncate_text(ctx, pad_data.name, max_text_w, '..')
    local text_w_actual = ImGui.CalcTextSize(ctx, name)
    local text_x = x1 + (w - text_w_actual) / 2
    local text_y = footer_y - text_h - 3
    ImGui.DrawList_AddText(dl, text_x + 1, text_y + 1, 0x000000AA, name)
    ImGui.DrawList_AddText(dl, text_x, text_y, COLORS.text, name)
  end

  -- Dimmed overlay
  if is_dimmed then
    ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, 0x000000AA, rounding)
  end

  -- ========================================================================
  -- SELECTION EFFECTS (marching ants + strobing highlight)
  -- ========================================================================
  if tile_state.selected then
    -- Strobing highlight (2-second cycle fade in/out)
    local now = reaper.time_precise()
    local elapsed = now - selection_highlight.start_time
    local cycle = elapsed % selection_highlight.duration
    local t = cycle / selection_highlight.duration
    -- Sine wave for smooth fade: 0 -> 1 -> 0
    local strobe_alpha = math.sin(t * math.pi) * 0.15  -- Max 15% opacity
    local strobe_color = Colors.WithOpacity(border_color, strobe_alpha)
    ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, strobe_color, rounding)

    -- Marching ants border
    local ant_color = Colors.WithOpacity(border_color, 0.9)
    MarchingAnts.Draw(dl, x1, y1, x2, y2, ant_color, 1.5, rounding, 12, 8, 40)
  end

  -- ========================================================================
  -- EXTERNAL FILE DROP TARGET
  -- ========================================================================
  ImGui.SetCursorScreenPos(ctx, x1, y1)
  ImGui.InvisibleButton(ctx, '##tile_drop_' .. pad_index, w, h - FOOTER_H)

  -- Hide default drop target visual
  ImGui.PushStyleColor(ctx, ImGui.Col_DragDropTarget, 0x00000000)

  if ImGui.BeginDragDropTarget(ctx) then
    -- Only handle external file drops here
    local rv, count = ImGui.AcceptDragDropPayloadFiles(ctx)
    if rv and count > 0 then
      local files = {}
      for fi = 0, count - 1 do
        local _, filepath = ImGui.GetDragDropPayloadFile(ctx, fi)
        if filepath and filepath ~= '' then
          files[#files + 1] = filepath
        end
      end
      if #files > 0 then
        footer_clicks[pad_index] = {
          action = 'file_drop',
          files = files,
        }
      end
    end

    -- Visual feedback for file drops
    ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, 0x42E896FF, rounding, 0, 2)

    ImGui.EndDragDropTarget(ctx)
  end

  ImGui.PopStyleColor(ctx)

  -- ========================================================================
  -- INTERNAL PAD DRAG VISUALS
  -- ========================================================================
  if drag_state.internal_drag_started then
    local mods = ImGui.GetKeyMods(ctx)
    local is_copy = (mods & ImGui.Mod_Ctrl) ~= 0

    -- Check if this pad is a drag source (being dragged)
    local is_source = false
    for _, src in ipairs(drag_state.internal_drag_sources) do
      if src == pad_index then
        is_source = true
        break
      end
    end

    if is_source then
      -- Dim source pads during drag (unless copying)
      if not is_copy then
        ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, 0x00000066, rounding)
      end
      -- Dashed border on source
      ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, 0xFFFFFF44, rounding, 0, 1)
    end

    -- Drop target highlight
    if drag_state.internal_drag_target == pad_index then
      local highlight_color = is_copy and 0x4488FFFF or 0x42E896FF  -- Blue for copy, green for swap
      ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, highlight_color, rounding, 0, 2)

      -- Show count badge for multi-selection
      local count = #drag_state.internal_drag_sources
      if count > 1 then
        local badge_text = tostring(count)
        local badge_w, badge_h = ImGui.CalcTextSize(ctx, badge_text)
        local badge_x = x2 - badge_w - 8
        local badge_y = y1 + 4
        ImGui.DrawList_AddRectFilled(dl, badge_x - 4, badge_y - 2, badge_x + badge_w + 4, badge_y + badge_h + 2, highlight_color, 4)
        ImGui.DrawList_AddText(dl, badge_x, badge_y, 0xFFFFFFFF, badge_text)
      end
    end
  end
end

-- ============================================================================
-- CONTEXT MENU
-- ============================================================================

local context_state = {
  pad_indices = {},  -- Array of selected pad indices
  open_menu = false,
}

local function draw_context_menu(ctx, state, pad_indices)
  if not ImGui.BeginPopup(ctx, 'pad_context_menu') then return end
  if not pad_indices or #pad_indices == 0 then
    ImGui.EndPopup(ctx)
    return
  end

  local is_multi = #pad_indices > 1
  local first_pad = pad_indices[1]
  local pad_data = state.getPadData(first_pad)

  -- Check if any selected pad has a sample
  local any_has_sample = false
  for _, idx in ipairs(pad_indices) do
    if state.hasSample(idx) then
      any_has_sample = true
      break
    end
  end

  -- Header showing selection count
  if is_multi then
    ImGui.TextDisabled(ctx, string.format('%d pads selected', #pad_indices))
    ImGui.Separator(ctx)
  end

  -- Preview (first pad only)
  if ImGui.MenuItem(ctx, 'Preview', nil, false, state.hasSample(first_pad)) then
    if state.hasDrumBlocks() then
      Bridge.previewPad(state.getTrack(), state.getFxIndex(), first_pad, 100)
    end
  end

  ImGui.Separator(ctx)

  -- Load Sample (applies same sample to all)
  local load_label = is_multi and 'Load Sample to All...' or 'Load Sample...'
  if ImGui.MenuItem(ctx, load_label) then
    local retval, filename = reaper.GetUserFileNameForRead('', 'Load Sample', 'wav;mp3;ogg;flac;aif;aiff')
    if retval and filename ~= '' then
      for _, idx in ipairs(pad_indices) do
        state.setPadSample(idx, 0, filename)
      end
    end
  end

  -- Clear Sample (all selected)
  local clear_label = is_multi and 'Clear Samples' or 'Clear Sample'
  if ImGui.MenuItem(ctx, clear_label, nil, false, any_has_sample) then
    for _, idx in ipairs(pad_indices) do
      state.setPadSample(idx, 0, '')
    end
  end

  ImGui.Separator(ctx)

  -- Kill Group (applies to all)
  if ImGui.BeginMenu(ctx, 'Kill Group') then
    local current_kg = pad_data.kill_group or 0
    if ImGui.MenuItem(ctx, 'None', nil, not is_multi and current_kg == 0) then
      for _, idx in ipairs(pad_indices) do
        state.setPadKillGroup(idx, 0)
      end
    end
    ImGui.Separator(ctx)
    for g = 1, 8 do
      if ImGui.MenuItem(ctx, 'Group ' .. g, nil, not is_multi and current_kg == g) then
        for _, idx in ipairs(pad_indices) do
          state.setPadKillGroup(idx, g)
        end
      end
    end
    ImGui.EndMenu(ctx)
  end

  -- Output (1-16 stereo outputs)
  if ImGui.BeginMenu(ctx, 'Output') then
    local current_og = pad_data.output_group or 0
    for g = 0, 15 do
      local label = tostring(g + 1)  -- Display as 1-16
      if ImGui.MenuItem(ctx, label, nil, not is_multi and current_og == g) then
        for _, idx in ipairs(pad_indices) do
          state.setPadOutputGroup(idx, g)
        end
      end
    end
    ImGui.EndMenu(ctx)
  end

  ImGui.Separator(ctx)

  -- 808 Presets (applies to all)
  if ImGui.BeginMenu(ctx, '808 Presets', any_has_sample) then
    local presets = {
      { name = 'Kick 808', preset = Bridge.Presets.Kick808 },
      { name = 'Sub Kick 808', preset = Bridge.Presets.SubKick808 },
      { name = 'Punchy Kick 808', preset = Bridge.Presets.PunchyKick808 },
      { name = 'Snare 808', preset = Bridge.Presets.Snare808 },
      { name = 'Tom 808', preset = Bridge.Presets.Tom808 },
      { name = 'HiHat 808', preset = Bridge.Presets.HiHat808 },
      { name = 'Open Hat 808', preset = Bridge.Presets.OpenHat808 },
      { name = 'Clap 808', preset = Bridge.Presets.Clap808 },
      { name = 'Cowbell 808', preset = Bridge.Presets.Cowbell808 },
    }
    for _, p in ipairs(presets) do
      if ImGui.MenuItem(ctx, p.name) then
        if state.hasDrumBlocks() then
          for _, idx in ipairs(pad_indices) do
            if state.hasSample(idx) then
              Bridge.applyPreset(state.getTrack(), state.getFxIndex(), idx, p.preset)
            end
          end
        end
      end
    end
    ImGui.EndMenu(ctx)
  end

  ImGui.Separator(ctx)

  -- Duplicate (single pad only - doesn't make sense for multi)
  if not is_multi then
    local can_duplicate = state.hasSample(first_pad) and (first_pad % 16) < 15
    if ImGui.MenuItem(ctx, 'Duplicate to Next Pad', nil, false, can_duplicate) then
      local next_pad = first_pad + 1
      local sample_path = state.getPadSample(first_pad, 0)
      if sample_path then
        state.setPadSample(next_pad, 0, sample_path)
        state.setPadVolume(next_pad, pad_data.volume)
        state.setPadPan(next_pad, pad_data.pan)
        state.setPadTune(next_pad, (pad_data.tune or 0) + 12)
      end
    end
    ImGui.Separator(ctx)
  end

  -- Color picker (applies to all)
  ColorPickerMenu.render(ctx, {
    current_color = state.getPadColor(first_pad),
    on_select = function(color_int, _, _)
      for _, idx in ipairs(pad_indices) do
        state.setPadColor(idx, color_int)
      end
    end,
  })

  ImGui.EndPopup(ctx)
end

-- ============================================================================
-- MAIN DRAW
-- ============================================================================

function M.draw(ctx, state, opts)
  ensure_itempicker()

  opts = opts or {}
  local pad_size = opts.pad_size or DEFAULT_PAD_SIZE
  local spacing = opts.spacing or DEFAULT_PAD_SPACING

  -- Toolbar display modes
  local display_opts = {
    io_mode = opts.io_mode or false,
    fold_mode = opts.fold_mode or false,
    choke_mode = opts.choke_mode or false,
  }

  local current_bank = state.getCurrentBank()
  local bank_start = current_bank * 16

  -- Check if any pad across ALL banks is soloed (solo is global)
  local any_soloed = false
  for i = 0, 127 do
    local pad_data = state.getPadData(i)
    if pad_data and pad_data.soloed then
      any_soloed = true
      break
    end
  end

  -- Build items array
  local items = {}
  if display_opts.fold_mode then
    -- Fold mode: show ALL pads with samples across all 128 pads (like Ableton)
    for i = 0, 127 do
      local pad_data = state.getPadData(i)
      if pad_data and pad_data.name then
        items[#items + 1] = {
          pad_index = i,
          pad_data = pad_data,
        }
      end
    end
  else
    -- Normal mode: show current bank (16 pads)
    for i = 0, 15 do
      local pad_index = bank_start + i
      local pad_data = state.getPadData(pad_index)
      items[#items + 1] = {
        pad_index = pad_index,
        pad_data = pad_data,
      }
    end
  end

  -- Clear footer clicks
  footer_clicks = {}

  -- Track ItemPicker drag state
  local dragging_from_itempicker = is_itempicker_dragging_audio()
  local mouse_down = ImGui.IsMouseDown(ctx, 0)
  local just_dropped = drag_state.was_dragging and drag_state.was_mouse_down and not mouse_down

  if dragging_from_itempicker and mouse_down then
    drag_state.last_drop_target_pad = drag_state.drop_target_pad
    drag_state.cached_item_data, drag_state.cached_uuid = get_dragged_sample()
  end

  drag_state.was_mouse_down = mouse_down
  drag_state.was_dragging = dragging_from_itempicker
  drag_state.drop_target_pad = nil

  -- Reset internal drag target before Grid render (will be set by render_item if hovering)
  drag_state.internal_drag_target = nil

  -- Get selected pad key
  local selected_pad = state.getSelectedPad()
  local selected_key = selected_pad and ('pad_' .. selected_pad) or nil

  -- In fold mode, prioritize 4 rows instead of 4 columns
  -- This makes the grid expand horizontally when there are fewer items
  local num_cols = 4
  if display_opts.fold_mode and #items > 0 and #items < 16 then
    -- Calculate columns to achieve max 4 rows: cols = ceil(N/4)
    num_cols = math.ceil(#items / 4)
  end

  -- Render grid using Ark.Grid
  local result = Ark.Grid(ctx, {
    id = 'drumblocks_pad_grid',
    items = items,
    key = function(item) return 'pad_' .. item.pad_index end,

    -- Layout: columns depend on fold mode, square tiles
    fixed_cols = num_cols,
    gap = spacing,
    fixed_tile_h = pad_size,
    min_col_w = pad_size,

    -- Disable default drop zone visuals (we handle our own)
    render_drop_zones = false,

    -- Selection and drag behaviors
    behaviors = {
      on_select = function(grid, selected_keys)
        if selected_keys and #selected_keys > 0 then
          local key = selected_keys[1]
          local pad_idx = tonumber(key:match('pad_(%d+)'))
          if pad_idx then
            state.setSelectedPad(pad_idx)
            -- Preview on select
            if state.hasSample(pad_idx) and state.hasDrumBlocks() then
              Bridge.previewPad(state.getTrack(), state.getFxIndex(), pad_idx, 100)
            end
          end
        end
      end,

      ['click:right'] = function(grid, key, selected_keys)
        -- Collect all selected pad indices for multi-edit
        context_state.pad_indices = {}
        if selected_keys and #selected_keys > 0 then
          for _, sel_key in ipairs(selected_keys) do
            local idx = tonumber(sel_key:match('pad_(%d+)'))
            if idx then
              context_state.pad_indices[#context_state.pad_indices + 1] = idx
            end
          end
          table.sort(context_state.pad_indices)
        else
          -- Fallback: just the clicked pad
          local idx = tonumber(key:match('pad_(%d+)'))
          if idx then
            context_state.pad_indices = { idx }
          end
        end
        if #context_state.pad_indices > 0 then
          context_state.open_menu = true
        end
      end,

      -- Track when Grid starts a drag (for internal pad move/copy)
      drag_start = function(grid, item_keys)
        if item_keys and #item_keys > 0 then
          -- Collect all dragged pad indices (multi-selection support)
          drag_state.internal_drag_sources = {}
          for _, key in ipairs(item_keys) do
            local pad_idx = tonumber(key:match('pad_(%d+)'))
            if pad_idx then
              drag_state.internal_drag_sources[#drag_state.internal_drag_sources + 1] = pad_idx
            end
          end
          -- Sort by index for predictable ordering
          table.sort(drag_state.internal_drag_sources)
          drag_state.internal_drag_started = #drag_state.internal_drag_sources > 0
        end
      end,
    },

    -- Render each pad tile
    render_item = function(inner_ctx, rect, item, tile_state)
      -- Track hover target for internal pad drag BEFORE rendering (so visual shows this frame)
      if drag_state.internal_drag_started and tile_state.hover then
        drag_state.internal_drag_target = item.pad_index
      end

      -- Track drop target for ItemPicker
      if dragging_from_itempicker and tile_state.hover then
        drag_state.drop_target_pad = item.pad_index
      end

      render_pad_tile(inner_ctx, rect, item, tile_state, state, any_soloed, display_opts)
    end,

    -- External file drops (from OS/Media Explorer)
    accept_external_drops = true,
    on_external_drop = function(insert_index)
      -- Get dropped files
      local _, count = ImGui.AcceptDragDropPayloadFiles(ctx)
      if count and count > 0 then
        -- Collect files first
        local files = {}
        for i = 0, count - 1 do
          local _, filepath = ImGui.GetDragDropPayloadFile(ctx, i)
          if filepath and filepath ~= '' then
            files[#files + 1] = filepath
          end
        end
        -- Process through MX render for selection/rate support
        local processed_files = MXRender.processFiles(files)
        for i, filepath in ipairs(processed_files) do
          local ext = filepath:match('%.([^.]+)$')
          if ext then
            ext = ext:lower()
            if ext == 'wav' or ext == 'mp3' or ext == 'ogg' or ext == 'flac' or ext == 'aif' or ext == 'aiff' then
              local target_pad = bank_start + insert_index - 1 + (i - 1)
              if target_pad < bank_start + 16 then
                state.setPadSample(target_pad, 0, filepath)
                if i == 1 then
                  state.setSelectedPad(target_pad)
                end
              end
            end
          end
        end
      end
    end,

    -- ItemPicker drag detection
    external_drag_check = function()
      return is_itempicker_dragging_audio()
    end,
  })

  -- Handle footer button clicks, file drops, and pad moves
  for pad_index, action in pairs(footer_clicks) do
    local pad_data = state.getPadData(pad_index)

    -- Check if action is a table or string
    if type(action) == 'table' then
      if action.action == 'file_drop' then
        -- Handle dropped files - process through MX render for selection/rate support
        local processed_files = MXRender.processFiles(action.files)
        for fi, filepath in ipairs(processed_files) do
          local ext = filepath:match('%.([^.]+)$')
          if ext then
            ext = ext:lower()
            if ext == 'wav' or ext == 'mp3' or ext == 'ogg' or ext == 'flac' or ext == 'aif' or ext == 'aiff' then
              local target_pad = pad_index + (fi - 1)
              if target_pad < bank_start + 16 then
                state.setPadSample(target_pad, 0, filepath)
                if fi == 1 then
                  state.setSelectedPad(target_pad)
                end
              end
            end
          end
        end

      elseif action.action == 'mute' then
        -- Mute with modifiers (Reaper-style):
        -- Click: toggle, CTRL: unmute all, CTRL+ALT: exclusive, ALT: mute others
        if action.ctrl and action.alt then
          -- CTRL+ALT: Exclusive mute (mute only this, unmute all others)
          for i = 0, 127 do
            local pd = state.getPadData(i)
            if pd then pd.muted = (i == pad_index) end
          end
        elseif action.ctrl then
          -- CTRL: Unmute all
          for i = 0, 127 do
            local pd = state.getPadData(i)
            if pd then pd.muted = false end
          end
        elseif action.alt then
          -- ALT: Mute all others
          for i = 0, 127 do
            local pd = state.getPadData(i)
            if pd then pd.muted = (i ~= pad_index) end
          end
        else
          -- Normal click: toggle
          pad_data.muted = not pad_data.muted
        end

      elseif action.action == 'solo' then
        -- Solo with modifiers (Reaper-style):
        -- Click: toggle, CTRL: unsolo all, CTRL+ALT: exclusive solo
        if action.ctrl and action.alt then
          -- CTRL+ALT: Exclusive solo (solo only this, unsolo all others)
          for i = 0, 127 do
            local pd = state.getPadData(i)
            if pd then pd.soloed = (i == pad_index) end
          end
        elseif action.ctrl then
          -- CTRL: Unsolo all
          for i = 0, 127 do
            local pd = state.getPadData(i)
            if pd then pd.soloed = false end
          end
        else
          -- Normal click: toggle
          pad_data.soloed = not pad_data.soloed
        end
      end

    elseif action == 'play' then
      if state.hasDrumBlocks() then
        Bridge.previewPad(state.getTrack(), state.getFxIndex(), pad_index, 100)
      end
    end
  end

  -- Handle ItemPicker drop
  if just_dropped and drag_state.last_drop_target_pad and drag_state.cached_item_data then
    local pad_index = drag_state.last_drop_target_pad
    local item_data = drag_state.cached_item_data
    local uuid = drag_state.cached_uuid

    local source_path = get_source_path(item_data[1])
    if source_path and source_path ~= '' then
      state.setPadSample(pad_index, 0, source_path)
      local pad_data = state.getPadData(pad_index)
      if pad_data then
        pad_data.uuid = uuid
      end
    end

    drag_state.last_drop_target_pad = nil
    drag_state.cached_item_data = nil
    drag_state.cached_uuid = nil
  end

  -- ========================================================================
  -- INTERNAL PAD DRAG COMPLETION
  -- ========================================================================
  -- Check if internal drag just ended (mouse released)
  if drag_state.internal_drag_started and not mouse_down then
    local sources = drag_state.internal_drag_sources
    local target = drag_state.internal_drag_target

    -- Perform copy/swap if valid drop target
    if sources and #sources > 0 and target then
      local mods = ImGui.GetKeyMods(ctx)
      local is_copy = (mods & ImGui.Mod_Ctrl) ~= 0

      -- Check if target is one of the sources (no-op)
      local target_is_source = false
      for _, src in ipairs(sources) do
        if src == target then
          target_is_source = true
          break
        end
      end

      if not target_is_source then
        if #sources == 1 then
          -- Single pad: swap or copy
          if is_copy then
            state.copyPad(sources[1], target)
          else
            state.swapPads(sources[1], target)
          end
          state.setSelectedPad(target)
        else
          -- Multiple pads: swap source range with destination range
          local count = #sources

          if is_copy then
            -- Copy mode: just copy sources to consecutive positions at target
            for i, src in ipairs(sources) do
              local dest = target + (i - 1)
              if dest < bank_start + 16 then
                state.copyPad(src, dest)
              end
            end
          else
            -- Move mode: swap ranges using pairwise swaps
            -- Build destination indices
            local destinations = {}
            for i = 1, count do
              local dest = target + (i - 1)
              if dest < bank_start + 16 then
                destinations[#destinations + 1] = dest
              end
            end

            -- Perform pairwise swaps: sources[i] <-> destinations[i]
            -- Use a temp pad approach to avoid conflicts
            local swapped = {}  -- Track which pads we've already swapped

            for i = 1, math.min(#sources, #destinations) do
              local src_idx = sources[i]
              local dest_idx = destinations[i]

              -- Skip if same position or already swapped
              if src_idx ~= dest_idx and not swapped[src_idx] and not swapped[dest_idx] then
                state.swapPads(src_idx, dest_idx)
                swapped[src_idx] = true
                swapped[dest_idx] = true
              end
            end
          end

          state.setSelectedPad(target)
        end
      end
    end

    -- Reset internal drag state
    drag_state.internal_drag_sources = {}
    drag_state.internal_drag_target = nil
    drag_state.internal_drag_started = false
  end

  -- ========================================================================
  -- KEYBOARD HANDLING
  -- ========================================================================
  local window_focused = ImGui.IsWindowFocused(ctx, ImGui.FocusedFlags_RootAndChildWindows)
  local mods = ImGui.GetKeyMods(ctx)
  local ctrl_down = (mods & ImGui.Mod_Ctrl) ~= 0

  -- Spacebar = preview selected pad
  if window_focused and selected_pad and ImGui.IsKeyPressed(ctx, ImGui.Key_Space) then
    if state.hasDrumBlocks() then
      Bridge.previewPad(state.getTrack(), state.getFxIndex(), selected_pad, 100)
    end
  end

  -- Arrow keys = navigate
  local nav_offset = nil
  if window_focused then
    if ImGui.IsKeyPressed(ctx, ImGui.Key_LeftArrow) then nav_offset = -1
    elseif ImGui.IsKeyPressed(ctx, ImGui.Key_RightArrow) then nav_offset = 1
    elseif ImGui.IsKeyPressed(ctx, ImGui.Key_UpArrow) then nav_offset = -4
    elseif ImGui.IsKeyPressed(ctx, ImGui.Key_DownArrow) then nav_offset = 4
    end
  end

  if nav_offset and selected_pad then
    local new_index = selected_pad + nav_offset
    local bank_end = bank_start + 15
    if new_index < bank_start then new_index = bank_end
    elseif new_index > bank_end then new_index = bank_start
    end
    state.setSelectedPad(new_index)
  end

  -- Get selected pad indices from grid selection (for multi-select operations)
  local selected_indices = {}
  if result.selected_keys and #result.selected_keys > 0 then
    for _, key in ipairs(result.selected_keys) do
      local idx = tonumber(key:match('pad_(%d+)'))
      if idx then
        selected_indices[#selected_indices + 1] = idx
      end
    end
    table.sort(selected_indices)
  elseif selected_pad then
    selected_indices = { selected_pad }
  end

  -- CTRL+C = Copy selected pads
  if window_focused and ctrl_down and ImGui.IsKeyPressed(ctx, ImGui.Key_C) then
    if #selected_indices > 0 then
      clipboard.pads = {}
      for _, idx in ipairs(selected_indices) do
        local pad_data = state.getPadData(idx)
        if pad_data then
          -- Deep copy pad data
          local copy = {}
          for k, v in pairs(pad_data) do
            if type(v) == 'table' then
              copy[k] = {}
              for k2, v2 in pairs(v) do
                copy[k][k2] = v2
              end
            else
              copy[k] = v
            end
          end
          clipboard.pads[#clipboard.pads + 1] = copy
        end
      end
      -- Show toast
      local count = #clipboard.pads
      toast.message = count == 1 and 'Copied 1 pad' or string.format('Copied %d pads', count)
      toast.start_time = reaper.time_precise()
    end
  end

  -- CTRL+V = Paste to selected pad(s)
  if window_focused and ctrl_down and ImGui.IsKeyPressed(ctx, ImGui.Key_V) then
    if #clipboard.pads > 0 and #selected_indices > 0 then
      -- Paste clipboard pads starting at first selected index
      local first_target = selected_indices[1]
      local pasted_count = 0
      for i, pad_copy in ipairs(clipboard.pads) do
        local target_idx = first_target + (i - 1)
        if target_idx <= 127 then  -- Don't exceed max pads
          -- Apply copied pad data
          local target_pad = state.getPadData(target_idx)
          if target_pad then
            -- Copy all fields except samples (need to re-load)
            for k, v in pairs(pad_copy) do
              if k ~= 'samples' then
                if type(v) == 'table' then
                  target_pad[k] = {}
                  for k2, v2 in pairs(v) do
                    target_pad[k][k2] = v2
                  end
                else
                  target_pad[k] = v
                end
              end
            end

            -- Load sample via state (handles VST sync)
            local sample_path = pad_copy.samples and pad_copy.samples[0]
            if sample_path and sample_path ~= '' then
              state.setPadSample(target_idx, 0, sample_path)
            else
              state.setPadSample(target_idx, 0, '')
            end

            -- Sync other params to VST
            if state.hasDrumBlocks() then
              Bridge.setVolume(state.getTrack(), state.getFxIndex(), target_idx, target_pad.volume or 0.8)
              Bridge.setPan(state.getTrack(), state.getFxIndex(), target_idx, target_pad.pan or 0)
              Bridge.setTune(state.getTrack(), state.getFxIndex(), target_idx, target_pad.tune or 0)
              Bridge.setKillGroup(state.getTrack(), state.getFxIndex(), target_idx, target_pad.kill_group or 0)
              Bridge.setOutputGroup(state.getTrack(), state.getFxIndex(), target_idx, target_pad.output_group or 0)
              Bridge.setPadColor(state.getTrack(), state.getFxIndex(), target_idx, target_pad.color)
            end
            pasted_count = pasted_count + 1
          end
        end
      end
      -- Show toast
      if pasted_count > 0 then
        toast.message = pasted_count == 1 and 'Pasted 1 pad' or string.format('Pasted %d pads', pasted_count)
        toast.start_time = reaper.time_precise()
      end
    end
  end

  -- Delete = Clear selected pad(s)
  if window_focused and ImGui.IsKeyPressed(ctx, ImGui.Key_Delete) then
    if #selected_indices > 0 then
      for _, idx in ipairs(selected_indices) do
        state.clearPad(idx)
      end
      -- Show toast
      local count = #selected_indices
      toast.message = count == 1 and 'Cleared 1 pad' or string.format('Cleared %d pads', count)
      toast.start_time = reaper.time_precise()
    end
  end

  -- Context menu
  if context_state.open_menu then
    ImGui.OpenPopup(ctx, 'pad_context_menu')
    context_state.open_menu = false
  end

  if #context_state.pad_indices > 0 then
    draw_context_menu(ctx, state, context_state.pad_indices)
  end

  -- ========================================================================
  -- TOAST NOTIFICATION
  -- ========================================================================
  if toast.message then
    local now = reaper.time_precise()
    local elapsed = now - toast.start_time
    if elapsed < toast.duration then
      -- Use foreground draw list to render on top
      local dl = ImGui.GetForegroundDrawList(ctx)

      -- Use the result dimensions for the grid area
      local grid_w = result.width or (4 * (pad_size + spacing))

      -- Get window position
      local wx, wy = ImGui.GetWindowPos(ctx)
      local ww, wh = ImGui.GetWindowSize(ctx)

      -- Fade out in last 0.3s
      local alpha = 1.0
      local fade_start = toast.duration - 0.3
      if elapsed > fade_start then
        alpha = 1.0 - (elapsed - fade_start) / 0.3
      end

      -- Calculate toast size and position (centered over window)
      local text_w, text_h = ImGui.CalcTextSize(ctx, toast.message)
      local tpad_x, tpad_y = 16, 8
      local toast_w = text_w + tpad_x * 2
      local toast_h = text_h + tpad_y * 2

      -- Center horizontally in window, position near top
      local toast_x = wx + (ww - toast_w) / 2
      local toast_y = wy + 50

      -- Background with fade
      local bg_alpha = math.floor(0xDD * alpha)
      local bg_color = 0x2A2A2A00 + bg_alpha
      ImGui.DrawList_AddRectFilled(dl, toast_x, toast_y, toast_x + toast_w, toast_y + toast_h, bg_color, 6)

      -- Border
      local border_alpha = math.floor(0x88 * alpha)
      local border_color = 0x88AAFF00 + border_alpha
      ImGui.DrawList_AddRect(dl, toast_x, toast_y, toast_x + toast_w, toast_y + toast_h, border_color, 6, 0, 1)

      -- Text
      local text_alpha = math.floor(0xFF * alpha)
      local text_color = 0xFFFFFF00 + text_alpha
      ImGui.DrawList_AddText(dl, toast_x + tpad_x, toast_y + tpad_y, text_color, toast.message)
    else
      toast.message = nil
    end
  end

  -- Grid dimensions: cols * tile + (cols+1) * gap
  -- For 4x4: 4*90 + 5*6 = 390
  local grid_dim = 4 * pad_size + 5 * spacing
  return {
    width = result.width or grid_dim,
    height = result.height or grid_dim,
    selected_indices = selected_indices,
  }
end

-- Check if there's an active internal pad drag
function M.isInternalDragActive()
  return drag_state.internal_drag_started and #drag_state.internal_drag_sources > 0
end

-- Get the drag sources (pad indices being dragged)
function M.getDragSources()
  if drag_state.internal_drag_started then
    return drag_state.internal_drag_sources
  end
  return nil
end

-- Check if drag has a target (dropped on a pad vs elsewhere)
function M.hasDragTarget()
  return drag_state.internal_drag_target ~= nil
end

-- Clear drag state (call after handling drop externally)
function M.clearDragState()
  drag_state.internal_drag_sources = {}
  drag_state.internal_drag_target = nil
  drag_state.internal_drag_started = false
end

-- Show a toast message (shared toast system)
function M.showToast(message)
  toast.message = message
  toast.start_time = reaper.time_precise()
end

return M
