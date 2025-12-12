-- @noindex
-- DrumBlocks/widgets/waveform_display.lua
-- Waveform display with envelope editing and start/end markers

local Ark = require('arkitekt')
local ImGui = Ark.ImGui
local Colors = Ark.Colors

-- Cache functions for performance (per LUA_PERFORMANCE_GUIDE.md)
local max, min, abs, sqrt, huge = math.max, math.min, math.abs, math.sqrt, math.huge
local AddPolyline = ImGui.DrawList_AddPolyline
local new_array = reaper.new_array

-- Helper: get peak value with proper downsampling (defined once at module level)
-- When zoomed out (use_window=true), returns min/max over the window
-- When zoomed in, interpolates for smooth curves
local function get_peak_value(peak_data, num_p, t_normalized, offset, half_window, is_max)
  local pos = t_normalized * (num_p - 1) + 1

  if half_window > 1 then
    -- Zoomed out: find min/max over window for proper envelope
    local idx_start = max(1, (pos - half_window) // 1)
    local idx_end = min(num_p, (pos + half_window) // 1)

    local result = peak_data[offset + idx_start]
    for idx = idx_start + 1, idx_end do
      local val = peak_data[offset + idx]
      if is_max then
        if val > result then result = val end
      else
        if val < result then result = val end
      end
    end
    return result
  else
    -- Zoomed in: interpolate for smooth curves
    local pos_floor = pos // 1
    local idx_low = max(1, min(num_p, pos_floor))
    local idx_high = max(1, min(num_p, idx_low + 1))
    local frac = pos - pos_floor
    local val_low = peak_data[offset + idx_low]
    local val_high = peak_data[offset + idx_high]
    return val_low + (val_high - val_low) * frac
  end
end

local M = {}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local COLORS = {
  bg = 0x0E0E0EFF,
  grid_line = 0x1A1A1AFF,
  center_line = 0x2A2A2AFF,
  border = 0x000000FF,
  text = 0xAAAAAAFF,
  lane_bg = 0x181818FF,
  lane_bg_alt = 0x141414FF,
  separator = 0x333333FF,
  btn_bg = 0x1A1A1AFF,
  btn_bg_hover = 0x2A2A2AFF,
  btn_bg_selected = 0x444444FF,
  btn_bg_selected_hover = 0x555555FF,
  icon_default = 0x888888FF,
  icon_selected = 0xFFFFFFFF,
  overlay_red = 0xDD222218,
  cursor = 0xFFFFFFEE,
  volume_env = 0xCCCCCCFF,
  filter_env = 0x50FFA0FF,
  pitch_env = 0xA050FFFF,
  marker = 0xDD5555FF,
  -- Drag selection (cyan/teal for contrast with marker red)
  drag_select_fill = 0x44AACC30,
  drag_select_border = 0x44AACCAA,
}

local HANDLE_HIT_RADIUS = 12
local LEFT_LANE_WIDTH = 24
local RIGHT_LANE_WIDTH = 24
local MARKER_LANE_HEIGHT = 14
local ENV_LANE_HEIGHT = 18
local BOTTOM_LANE_HEIGHT = 16
local BTN_SIZE = 18
local BTN_GAP = 4
local BTN_ROUNDING = 3

-- Envelope types
M.ENV_VOLUME = 'volume'
M.ENV_FILTER = 'filter'
M.ENV_PITCH = 'pitch'

-- Playback modes
M.PLAY_ONESHOT = 'oneshot'
M.PLAY_LOOP = 'loop'
M.PLAY_PINGPONG = 'pingpong'

-- Note-off modes
M.NOTEOFF_IGNORE = 'ignore'
M.NOTEOFF_RELEASE = 'release'
M.NOTEOFF_CUT = 'cut'

-- Persistent state
M._zoom_state = {}
M._drag_state = {}

-- Get zoom factor for a widget (1.0 = full view, 2.0 = 2x zoom, etc.)
function M.getZoomFactor(widget_id)
  local zoom_state = M._zoom_state[widget_id]
  if not zoom_state then return 1.0 end
  local view_range = (zoom_state.view_end or 1) - (zoom_state.view_start or 0)
  if view_range <= 0 then return 1.0 end
  return 1.0 / view_range
end

-- Get effective display width accounting for zoom
-- Use this to request appropriate peak resolution
function M.getEffectiveWidth(widget_id, display_width)
  return display_width * M.getZoomFactor(widget_id)
end

-- Get view range (0-1) for a widget
-- Returns view_start, view_end (defaults to 0, 1 if not initialized)
function M.getViewRange(widget_id)
  local zoom_state = M._zoom_state[widget_id]
  if not zoom_state then return 0, 1 end
  return zoom_state.view_start or 0, zoom_state.view_end or 1
end

-- ============================================================================
-- HELPERS
-- ============================================================================

function M.getDefaultEnvelope(env_type)
  local default_y = (env_type == M.ENV_FILTER) and 1.0 or 0.5
  return { { x = 0, y = default_y }, { x = 1, y = default_y } }
end

local function calc_envelope_at(t, points)
  if not points or #points < 2 then return 1.0 end
  for i = 1, #points - 1 do
    local p1, p2 = points[i], points[i + 1]
    if t >= p1.x and t <= p2.x then
      local range = p2.x - p1.x
      if range <= 0 then return p1.y end
      return p1.y + (p2.y - p1.y) * (t - p1.x) / range
    end
  end
  return (t <= points[1].x) and points[1].y or points[#points].y
end

local function sort_points(points)
  table.sort(points, function(a, b) return a.x < b.x end)
end

local function point_in_rect(mx, my, x1, y1, x2, y2)
  return mx >= x1 and mx <= x2 and my >= y1 and my <= y2
end

local function get_btn_bg(is_selected, is_hovered)
  if is_selected then
    return is_hovered and COLORS.btn_bg_selected_hover or COLORS.btn_bg_selected
  end
  return is_hovered and COLORS.btn_bg_hover or COLORS.btn_bg
end

-- ============================================================================
-- ICON DRAWING
-- ============================================================================

local function draw_icon_oneshot(dl, cx, cy, color)
  ImGui.DrawList_AddTriangleFilled(dl, cx - 4, cy - 5, cx + 5, cy, cx - 4, cy + 5, color)
end

local function draw_icon_loop(dl, cx, cy, color)
  ImGui.DrawList_AddCircle(dl, cx, cy, 5, color, 0, 1.5)
  ImGui.DrawList_AddTriangleFilled(dl, cx + 2, cy - 6, cx + 6, cy - 3, cx + 2, cy - 2, color)
end

local function draw_icon_pingpong(dl, cx, cy, color)
  ImGui.DrawList_AddLine(dl, cx - 5, cy, cx + 5, cy, color, 1.5)
  ImGui.DrawList_AddTriangleFilled(dl, cx - 5, cy, cx - 1, cy - 3, cx - 1, cy + 3, color)
  ImGui.DrawList_AddTriangleFilled(dl, cx + 5, cy, cx + 1, cy - 3, cx + 1, cy + 3, color)
end

local function draw_icon_noteoff_ignore(dl, cx, cy, color)
  ImGui.DrawList_AddTriangleFilled(dl, cx - 4, cy - 4, cx + 3, cy, cx - 4, cy + 4, color)
  ImGui.DrawList_AddLine(dl, cx + 5, cy - 4, cx + 5, cy + 4, color, 2)
end

local function draw_icon_noteoff_release(dl, cx, cy, color)
  ImGui.DrawList_AddLine(dl, cx - 5, cy - 4, cx + 5, cy + 4, color, 1.5)
  ImGui.DrawList_AddTriangleFilled(dl, cx + 5, cy + 4, cx + 1, cy + 2, cx + 3, cy - 1, color)
end

local function draw_icon_noteoff_cut(dl, cx, cy, color)
  ImGui.DrawList_AddLine(dl, cx - 4, cy - 4, cx + 4, cy + 4, color, 2)
  ImGui.DrawList_AddLine(dl, cx + 4, cy - 4, cx - 4, cy + 4, color, 2)
end

local function draw_icon_reverse(dl, cx, cy, color)
  ImGui.DrawList_AddLine(dl, cx + 4, cy - 3, cx - 4, cy - 3, color, 1.5)
  ImGui.DrawList_AddTriangleFilled(dl, cx - 5, cy - 3, cx - 1, cy - 6, cx - 1, cy, color)
  ImGui.DrawList_AddLine(dl, cx - 4, cy + 3, cx + 4, cy + 3, color, 1.5)
  ImGui.DrawList_AddTriangleFilled(dl, cx + 5, cy + 3, cx + 1, cy, cx + 1, cy + 6, color)
end

-- ============================================================================
-- MAIN DRAW FUNCTION
-- ============================================================================

function M.draw(ctx, opts)
  opts = opts or {}

  -- Extract options
  local peaks = opts.peaks
  local width = opts.width or 300
  local height = opts.height or 100
  local volume = opts.volume or 1.0
  local sample_duration = opts.sample_duration or 1.0
  local env_type = opts.env_type or M.ENV_VOLUME
  local envelope = opts.envelope or M.getDefaultEnvelope(env_type)
  local volume_envelope = opts.volume_envelope or M.getDefaultEnvelope(M.ENV_VOLUME)
  local start_point = opts.start_point or 0
  local end_point = opts.end_point or 1
  local show_handles = opts.show_handles ~= false
  local playback_mode = opts.playback_mode or M.PLAY_ONESHOT
  local bg_color = opts.bg_color or COLORS.bg
  local waveform_color = opts.waveform_color or 0xAAAAAAEE
  local is_reversed = opts.reverse or false
  local note_off_mode = opts.note_off_mode or M.NOTEOFF_IGNORE
  local playback_progress = opts.playback_progress
  local widget_id = opts.id or 'waveform_env'

  -- Derived colors
  local waveform_silent = Colors.WithOpacity(waveform_color, 0.2)
  local waveform_outside = Colors.WithOpacity(waveform_color, 0.1)
  local env_color = (env_type == M.ENV_FILTER) and COLORS.filter_env
                 or (env_type == M.ENV_PITCH) and COLORS.pitch_env
                 or COLORS.volume_env

  -- Layout calculations
  local base_x, y = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  local x = base_x + LEFT_LANE_WIDTH
  local content_width = width - LEFT_LANE_WIDTH - RIGHT_LANE_WIDTH
  local right_lane_x = base_x + width - RIGHT_LANE_WIDTH
  local waveform_y = y + MARKER_LANE_HEIGHT + ENV_LANE_HEIGHT
  local waveform_h = height - MARKER_LANE_HEIGHT - ENV_LANE_HEIGHT - BOTTOM_LANE_HEIGHT
  local bottom_lane_y = waveform_y + waveform_h
  local mid_y = waveform_y + waveform_h / 2

  -- Capture input
  ImGui.InvisibleButton(ctx, '##wf_' .. widget_id, width, height)
  local is_hovered = ImGui.IsItemHovered(ctx)
  local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
  local mouse_down = ImGui.IsMouseDown(ctx, 0)
  local mouse_clicked = ImGui.IsMouseClicked(ctx, 0)

  -- Zoom state
  local zoom_state = M._zoom_state[widget_id]
  if not zoom_state then
    zoom_state = { view_start = start_point, view_end = end_point }
    M._zoom_state[widget_id] = zoom_state
  end

  local playback_range = end_point - start_point

  -- Handle zoom (CTRL+scroll)
  if is_hovered and ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl) then
    local wheel = ImGui.GetMouseWheel(ctx)
    if wheel ~= 0 then
      local current_range = zoom_state.view_end - zoom_state.view_start
      local new_range = max(playback_range, min(1.0, current_range * (1 - wheel * 0.15)))

      local mouse_t = zoom_state.view_start + ((mouse_x - x) / content_width) * current_range
      local mouse_ratio = (mouse_x - x) / content_width
      local desired_start = mouse_t - mouse_ratio * new_range

      -- Clamp to keep both markers visible
      local min_start = max(0, end_point - new_range)
      local max_start = min(start_point, 1 - new_range)
      zoom_state.view_start = max(min_start, min(max_start, desired_start))
      zoom_state.view_end = zoom_state.view_start + new_range
    end
  end

  local view_start = zoom_state.view_start
  local view_end = zoom_state.view_end
  local view_range = view_end - view_start

  -- Helper functions
  local function sample_to_screen(t)
    return x + ((t - view_start) / view_range) * content_width
  end

  local function screen_to_sample(sx)
    return view_start + ((sx - x) / content_width) * view_range
  end

  local function envelope_to_sample(env_x)
    return start_point + env_x * (end_point - start_point)
  end

  local function sample_to_envelope(sample_x)
    local range = end_point - start_point
    return (range <= 0) and 0 or max(0, min(1, (sample_x - start_point) / range))
  end

  -- Track state changes
  local new_playback_mode, new_note_off_mode, new_env_type, new_reverse
  local envelope_changed, start_end_changed = false, false

  -- ========================================================================
  -- LEFT LANE (Playback modes)
  -- ========================================================================
  ImGui.DrawList_AddRectFilled(dl, base_x, y, base_x + LEFT_LANE_WIDTH, y + height, COLORS.lane_bg, 4, ImGui.DrawFlags_RoundCornersLeft)

  local pb_modes = {
    { id = M.PLAY_ONESHOT, tip = 'One Shot', draw = draw_icon_oneshot },
    { id = M.PLAY_LOOP, tip = 'Loop', draw = draw_icon_loop },
    { id = M.PLAY_PINGPONG, tip = 'Ping Pong', draw = draw_icon_pingpong },
  }
  local pb_total_h = #pb_modes * BTN_SIZE + (#pb_modes - 1) * BTN_GAP
  local pb_start_y = y + (height - pb_total_h) / 2
  local pb_btn_x = base_x + (LEFT_LANE_WIDTH - BTN_SIZE) / 2

  for i, mode in ipairs(pb_modes) do
    local btn_y = pb_start_y + (i - 1) * (BTN_SIZE + BTN_GAP)
    local is_sel = playback_mode == mode.id
    local hovered = is_hovered and point_in_rect(mouse_x, mouse_y, pb_btn_x, btn_y, pb_btn_x + BTN_SIZE, btn_y + BTN_SIZE)

    ImGui.DrawList_AddRectFilled(dl, pb_btn_x, btn_y, pb_btn_x + BTN_SIZE, btn_y + BTN_SIZE, get_btn_bg(is_sel, hovered), BTN_ROUNDING)
    mode.draw(dl, pb_btn_x + BTN_SIZE / 2, btn_y + BTN_SIZE / 2, is_sel and COLORS.icon_selected or COLORS.icon_default)

    if hovered then
      if mouse_clicked and not is_sel then new_playback_mode = mode.id end
      ImGui.BeginTooltip(ctx)
      ImGui.Text(ctx, mode.tip)
      ImGui.EndTooltip(ctx)
    end
  end

  ImGui.DrawList_AddLine(dl, base_x + LEFT_LANE_WIDTH, y, base_x + LEFT_LANE_WIDTH, y + height, COLORS.separator)

  -- ========================================================================
  -- RIGHT LANE (Note-off modes + Reverse)
  -- ========================================================================
  ImGui.DrawList_AddRectFilled(dl, right_lane_x, y, right_lane_x + RIGHT_LANE_WIDTH, y + height, COLORS.lane_bg, 4, ImGui.DrawFlags_RoundCornersRight)

  local no_modes = {
    { id = M.NOTEOFF_IGNORE, tip = 'Ignore Note-Off (play to end)', draw = draw_icon_noteoff_ignore },
    { id = M.NOTEOFF_RELEASE, tip = 'Release (trigger ADSR release)', draw = draw_icon_noteoff_release },
    { id = M.NOTEOFF_CUT, tip = 'Cut (stop immediately)', draw = draw_icon_noteoff_cut },
  }
  local no_btn_x = right_lane_x + (RIGHT_LANE_WIDTH - BTN_SIZE) / 2
  local no_start_y = y + 8

  for i, mode in ipairs(no_modes) do
    local btn_y = no_start_y + (i - 1) * (BTN_SIZE + BTN_GAP)
    local is_sel = note_off_mode == mode.id
    local hovered = is_hovered and point_in_rect(mouse_x, mouse_y, no_btn_x, btn_y, no_btn_x + BTN_SIZE, btn_y + BTN_SIZE)

    ImGui.DrawList_AddRectFilled(dl, no_btn_x, btn_y, no_btn_x + BTN_SIZE, btn_y + BTN_SIZE, get_btn_bg(is_sel, hovered), BTN_ROUNDING)
    mode.draw(dl, no_btn_x + BTN_SIZE / 2, btn_y + BTN_SIZE / 2, is_sel and COLORS.icon_selected or COLORS.icon_default)

    if hovered then
      if mouse_clicked and not is_sel then new_note_off_mode = mode.id end
      ImGui.BeginTooltip(ctx)
      ImGui.Text(ctx, mode.tip)
      ImGui.EndTooltip(ctx)
    end
  end

  -- Reverse button
  local rev_btn_y = y + height - BTN_SIZE - 8
  local rev_hovered = is_hovered and point_in_rect(mouse_x, mouse_y, no_btn_x, rev_btn_y, no_btn_x + BTN_SIZE, rev_btn_y + BTN_SIZE)

  ImGui.DrawList_AddRectFilled(dl, no_btn_x, rev_btn_y, no_btn_x + BTN_SIZE, rev_btn_y + BTN_SIZE, get_btn_bg(is_reversed, rev_hovered), BTN_ROUNDING)
  draw_icon_reverse(dl, no_btn_x + BTN_SIZE / 2, rev_btn_y + BTN_SIZE / 2, is_reversed and COLORS.icon_selected or COLORS.icon_default)

  if rev_hovered then
    if mouse_clicked then new_reverse = not is_reversed end
    ImGui.BeginTooltip(ctx)
    ImGui.Text(ctx, is_reversed and 'Reverse: ON' or 'Reverse: OFF')
    ImGui.EndTooltip(ctx)
  end

  -- ========================================================================
  -- CENTER AREA
  -- ========================================================================

  -- Marker lane (top)
  ImGui.DrawList_AddRectFilled(dl, x, y, x + content_width, y + MARKER_LANE_HEIGHT, COLORS.lane_bg)

  -- Envelope selector lane (below marker lane)
  ImGui.DrawList_AddRectFilled(dl, x, y + MARKER_LANE_HEIGHT, x + content_width, y + MARKER_LANE_HEIGHT + ENV_LANE_HEIGHT, COLORS.lane_bg_alt)

  -- Envelope selector buttons - detect clicks here, draw later for z-order
  local env_buttons = {
    { id = M.ENV_VOLUME, label = 'VOL', color = COLORS.volume_env },
    { id = M.ENV_FILTER, label = 'FILTER', color = COLORS.filter_env },
    { id = M.ENV_PITCH, label = 'PITCH', color = COLORS.pitch_env },
  }
  local env_btn_base_x = x + 4
  local env_btn_y = y + MARKER_LANE_HEIGHT + 2
  local env_btn_h = ENV_LANE_HEIGHT - 4

  -- Pre-calculate button widths and detect clicks
  local env_btn_data = {}
  local env_btn_x = env_btn_base_x
  for _, btn in ipairs(env_buttons) do
    local label_w = ImGui.CalcTextSize(ctx, btn.label)
    local btn_w = label_w + 16
    local is_sel = env_type == btn.id
    local hovered = is_hovered and point_in_rect(mouse_x, mouse_y, env_btn_x, env_btn_y, env_btn_x + btn_w, env_btn_y + env_btn_h)
    if hovered and mouse_clicked and not is_sel then new_env_type = btn.id end
    env_btn_data[#env_btn_data + 1] = { btn = btn, x = env_btn_x, w = btn_w, is_sel = is_sel, hovered = hovered }
    env_btn_x = env_btn_x + btn_w + 4
  end

  -- Waveform area
  ImGui.DrawList_AddRectFilled(dl, x, waveform_y, x + content_width, waveform_y + waveform_h, bg_color)

  -- Bottom lane
  ImGui.DrawList_AddRectFilled(dl, x, bottom_lane_y, x + content_width, bottom_lane_y + BOTTOM_LANE_HEIGHT, COLORS.lane_bg, 4, ImGui.DrawFlags_RoundCornersBottomRight)

  -- Separator lines
  ImGui.DrawList_AddLine(dl, x, y + MARKER_LANE_HEIGHT, x + content_width, y + MARKER_LANE_HEIGHT, COLORS.separator)
  ImGui.DrawList_AddLine(dl, x, waveform_y, x + content_width, waveform_y, COLORS.separator)
  ImGui.DrawList_AddLine(dl, x, bottom_lane_y, x + content_width, bottom_lane_y, COLORS.separator)

  -- Grid lines
  for i = 1, 7 do
    local gx = x + (content_width / 8) * i
    ImGui.DrawList_AddLine(dl, gx, waveform_y, gx, waveform_y + waveform_h, COLORS.grid_line)
  end
  for i = 1, 3 do
    local gy = waveform_y + (waveform_h / 4) * i
    ImGui.DrawList_AddLine(dl, x, gy, x + content_width, gy, COLORS.grid_line)
  end
  ImGui.DrawList_AddLine(dl, x, mid_y, x + content_width, mid_y, COLORS.center_line)

  -- ========================================================================
  -- WAVEFORM RENDERING (interpolated for smooth tier transitions)
  -- ========================================================================
  if peaks and #peaks >= 4 then
    local num_peaks = #peaks // 2
    local base_scale = (waveform_h / 2) * 0.9
    local outside_top, outside_bot = {}, {}
    local dim_top, dim_bot = {}, {}
    local bright_top, bright_bot = {}, {}

    -- Calculate peaks per pixel for downsampling decision
    local peaks_per_pixel = num_peaks * view_range / content_width
    local half_window = peaks_per_pixel * 0.5

    -- Draw points: continuous scaling based on zoom level
    local smoothing_factor = max(1, sqrt(peaks_per_pixel))
    local draw_points = max(32, (content_width / smoothing_factor) // 1)

    -- Pre-calculate loop constants
    local inv_draw = 1 / (draw_points - 1)
    local playback_range = max(0.001, end_point - start_point)
    local inv_playback = 1 / playback_range
    local wf_top, wf_bot = waveform_y, waveform_y + waveform_h
    local start_end_sum = start_point + end_point

    -- Direct index tracking (faster than #table + 1)
    local oti, obi, dti, dbi, bti, bbi = 0, 0, 0, 0, 0, 0

    for i = 1, draw_points do
      local ratio = (i - 1) * inv_draw
      local px = x + ratio * content_width
      local t = view_start + ratio * view_range

      if t >= 0 and t <= 1 then
        local inside = t >= start_point and t <= end_point
        local sample_t = (is_reversed and inside) and (start_end_sum - t) or t

        local max_val = get_peak_value(peaks, num_peaks, sample_t, 0, half_window, true) * volume
        local min_val = get_peak_value(peaks, num_peaks, sample_t, num_peaks, half_window, false) * volume

        local top_y = max(wf_top, min(wf_bot, mid_y - max_val * base_scale))
        local bot_y = max(wf_top, min(wf_bot, mid_y - min_val * base_scale))

        if inside then
          local env_t = (t - start_point) * inv_playback
          local gain = calc_envelope_at(env_t, volume_envelope) * 2
          local bright_top_y = max(wf_top, min(wf_bot, mid_y - max_val * gain * base_scale))
          local bright_bot_y = max(wf_top, min(wf_bot, mid_y - min_val * gain * base_scale))

          dti = dti + 1; dim_top[dti] = px; dti = dti + 1; dim_top[dti] = top_y
          dbi = dbi + 1; dim_bot[dbi] = px; dbi = dbi + 1; dim_bot[dbi] = bot_y
          bti = bti + 1; bright_top[bti] = px; bti = bti + 1; bright_top[bti] = bright_top_y
          bbi = bbi + 1; bright_bot[bbi] = px; bbi = bbi + 1; bright_bot[bbi] = bright_bot_y
        else
          oti = oti + 1; outside_top[oti] = px; oti = oti + 1; outside_top[oti] = top_y
          obi = obi + 1; outside_bot[obi] = px; obi = obi + 1; outside_bot[obi] = bot_y
        end
      end
    end

    if oti >= 4 then
      AddPolyline(dl, new_array(outside_top), waveform_outside, ImGui.DrawFlags_None, 1.0)
      AddPolyline(dl, new_array(outside_bot), waveform_outside, ImGui.DrawFlags_None, 1.0)
    end
    if dti >= 4 then
      AddPolyline(dl, new_array(dim_top), waveform_silent, ImGui.DrawFlags_None, 1.0)
      AddPolyline(dl, new_array(dim_bot), waveform_silent, ImGui.DrawFlags_None, 1.0)
    end
    if bti >= 4 then
      AddPolyline(dl, new_array(bright_top), waveform_color, ImGui.DrawFlags_None, 1.5)
      AddPolyline(dl, new_array(bright_bot), waveform_color, ImGui.DrawFlags_None, 1.5)
    end

    -- Red overlays
    local start_sx = max(x, min(x + content_width, sample_to_screen(start_point)))
    local end_sx = max(x, min(x + content_width, sample_to_screen(end_point)))
    if start_sx > x then
      ImGui.DrawList_AddRectFilled(dl, x, waveform_y, start_sx, waveform_y + waveform_h, COLORS.overlay_red)
    end
    if end_sx < x + content_width then
      ImGui.DrawList_AddRectFilled(dl, end_sx, waveform_y, x + content_width, waveform_y + waveform_h, COLORS.overlay_red)
    end

    -- Marker lines (from marker lane through env selector into waveform)
    ImGui.DrawList_AddLine(dl, start_sx, y + MARKER_LANE_HEIGHT - 2, start_sx, waveform_y + waveform_h - 2, COLORS.marker, 1)
    ImGui.DrawList_AddLine(dl, end_sx, y + MARKER_LANE_HEIGHT - 2, end_sx, waveform_y + waveform_h - 2, COLORS.marker, 1)
  else
    local text = 'No sample loaded'
    local text_w = ImGui.CalcTextSize(ctx, text)
    ImGui.DrawList_AddText(dl, x + (content_width - text_w) / 2, mid_y - 6, COLORS.text, text)
  end

  -- Draw envelope selector buttons (after marker lines for z-order, always drawn)
  for _, data in ipairs(env_btn_data) do
    local bg = data.is_sel and Colors.WithOpacity(data.btn.color, data.hovered and 0.4 or 0.3) or (data.hovered and 0x252525FF or COLORS.btn_bg)
    ImGui.DrawList_AddRectFilled(dl, data.x, env_btn_y, data.x + data.w, env_btn_y + env_btn_h, bg)
    ImGui.DrawList_AddRect(dl, data.x, env_btn_y, data.x + data.w, env_btn_y + env_btn_h, data.is_sel and data.btn.color or COLORS.separator, 0, 0, 1)
    ImGui.DrawList_AddText(dl, data.x + 8, env_btn_y + (env_btn_h - 12) / 2 - 2, data.is_sel and data.btn.color or COLORS.icon_default, data.btn.label)
  end

  -- ========================================================================
  -- ENVELOPE RENDERING
  -- ========================================================================
  if #envelope >= 2 then
    for i = 1, #envelope - 1 do
      local p1, p2 = envelope[i], envelope[i + 1]
      local x1 = sample_to_screen(envelope_to_sample(p1.x))
      local y1 = waveform_y + (1 - p1.y) * waveform_h
      local x2 = sample_to_screen(envelope_to_sample(p2.x))
      local y2 = waveform_y + (1 - p2.y) * waveform_h
      ImGui.DrawList_AddLine(dl, x1, y1, x2, y2, env_color, 2)
    end
  end

  -- Playback cursor
  if playback_progress and playback_progress >= 0 and playback_progress <= 1 then
    local sample_pos = start_point + playback_progress * (end_point - start_point)
    local cursor_x = sample_to_screen(sample_pos)
    if cursor_x >= x and cursor_x <= x + content_width then
      ImGui.DrawList_AddLine(dl, cursor_x, waveform_y, cursor_x, waveform_y + waveform_h, COLORS.cursor, 2)
    end
  end

  -- ========================================================================
  -- INTERACTION
  -- ========================================================================
  local drag = M._drag_state[widget_id] or {}
  M._drag_state[widget_id] = drag

  local shift_down = ImGui.IsKeyDown(ctx, ImGui.Mod_Shift)
  local alt_down = ImGui.IsKeyDown(ctx, ImGui.Mod_Alt)

  -- Marker handles (in marker lane at top)
  local start_sx = max(x, min(x + content_width, sample_to_screen(start_point)))
  local end_sx = max(x, min(x + content_width, sample_to_screen(end_point)))
  local handle_w, handle_h = 10, MARKER_LANE_HEIGHT - 4
  local marker_y = y + 2

  local start_hovered = is_hovered and point_in_rect(mouse_x, mouse_y, start_sx - handle_w/2, marker_y, start_sx + handle_w/2, marker_y + handle_h)
  local end_hovered = is_hovered and point_in_rect(mouse_x, mouse_y, end_sx - handle_w/2, marker_y, end_sx + handle_w/2, marker_y + handle_h)

  if start_hovered and mouse_clicked then
    drag.handle, drag.start_x, drag.orig_start, drag.orig_end = 'start', mouse_x, start_point, end_point
  elseif end_hovered and mouse_clicked then
    drag.handle, drag.start_x, drag.orig_start, drag.orig_end = 'end', mouse_x, start_point, end_point
  end

  if drag.handle == 'start' and mouse_down then
    local delta = (mouse_x - drag.start_x) / content_width * view_range
    start_point = max(0, min(drag.orig_end - 0.01, drag.orig_start + delta))
    start_end_changed = true
    if start_point < view_start then
      zoom_state.view_start, view_start = start_point, start_point
      view_range = view_end - view_start
    end
  elseif drag.handle == 'end' and mouse_down then
    local delta = (mouse_x - drag.start_x) / content_width * view_range
    end_point = max(drag.orig_start + 0.01, min(1, drag.orig_end + delta))
    start_end_changed = true
    if end_point > view_end then
      zoom_state.view_end, view_end = end_point, end_point
      view_range = view_end - view_start
    end
  end

  -- Draw marker handles
  local start_color = COLORS.marker
  if drag.handle == 'start' then start_color = Colors.Lighten(COLORS.marker, 0.3)
  elseif start_hovered then start_color = Colors.Lighten(COLORS.marker, 0.15) end
  ImGui.DrawList_AddRectFilled(dl, start_sx - handle_w/2, marker_y, start_sx + handle_w/2, marker_y + handle_h, start_color, 2)

  local end_color = COLORS.marker
  if drag.handle == 'end' then end_color = Colors.Lighten(COLORS.marker, 0.3)
  elseif end_hovered then end_color = Colors.Lighten(COLORS.marker, 0.15) end
  ImGui.DrawList_AddRectFilled(dl, end_sx - handle_w/2, marker_y, end_sx + handle_w/2, marker_y + handle_h, end_color, 2)

  -- Marker tooltips
  if drag.handle == 'start' then
    ImGui.BeginTooltip(ctx)
    ImGui.TextColored(ctx, COLORS.marker, string.format('Start: %.3fs', start_point * sample_duration))
    ImGui.EndTooltip(ctx)
  elseif drag.handle == 'end' then
    ImGui.BeginTooltip(ctx)
    ImGui.TextColored(ctx, COLORS.marker, string.format('End: %.3fs', end_point * sample_duration))
    ImGui.EndTooltip(ctx)
  end

  -- Envelope point interaction
  if show_handles and #envelope >= 2 then
    local closest_idx, closest_dist = nil, huge
    for i, pt in ipairs(envelope) do
      local px = sample_to_screen(envelope_to_sample(pt.x))
      local py = waveform_y + (1 - pt.y) * waveform_h
      local dist = sqrt((mouse_x - px)^2 + (mouse_y - py)^2)
      if dist < closest_dist then closest_dist, closest_idx = dist, i end
    end

    local point_hovered = closest_dist < HANDLE_HIT_RADIUS and is_hovered
    local mouse_sample = screen_to_sample(mouse_x)
    local in_region = mouse_sample >= start_point and mouse_sample <= end_point
    local in_waveform = mouse_y >= waveform_y and mouse_y <= waveform_y + waveform_h

    -- Add point (SHIFT+click)
    if shift_down and mouse_clicked and is_hovered and in_region and in_waveform and not drag.handle then
      local new_x = sample_to_envelope(mouse_sample)
      local new_y = 1 - (mouse_y - waveform_y) / waveform_h
      table.insert(envelope, { x = max(0, min(1, new_x)), y = max(0, min(1, new_y)) })
      sort_points(envelope)
      envelope_changed = true
    end

    -- Delete point (ALT+click)
    if alt_down and mouse_clicked and point_hovered and #envelope > 2 then
      table.remove(envelope, closest_idx)
      envelope_changed = true
    end

    -- Start point drag
    if point_hovered and mouse_clicked and not drag.handle and not shift_down and not alt_down then
      drag.handle, drag.point_idx = 'point', closest_idx
      drag.start_x, drag.start_y = mouse_x, mouse_y
      drag.orig_pt_x, drag.orig_pt_y = envelope[closest_idx].x, envelope[closest_idx].y
    end

    -- Handle point drag
    if drag.handle == 'point' and drag.point_idx and mouse_down then
      local pt = envelope[drag.point_idx]
      if pt then
        local region_size = max(0.01, end_point - start_point)
        local delta_x = (mouse_x - drag.start_x) / content_width * view_range / region_size
        local delta_y = -(mouse_y - drag.start_y) / waveform_h

        local new_x, new_y = drag.orig_pt_x + delta_x, drag.orig_pt_y + delta_y

        if drag.point_idx == 1 then
          new_x = 0
        elseif drag.point_idx == #envelope then
          new_x = 1
        else
          local prev_x = envelope[drag.point_idx - 1] and envelope[drag.point_idx - 1].x or 0
          local next_x = envelope[drag.point_idx + 1] and envelope[drag.point_idx + 1].x or 1
          new_x = max(prev_x + 0.01, min(next_x - 0.01, new_x))
        end

        pt.x, pt.y = max(0, min(1, new_x)), max(0, min(1, new_y))
        envelope_changed = true
      end
    end

    -- Draw envelope handles
    for i, pt in ipairs(envelope) do
      local px = sample_to_screen(envelope_to_sample(pt.x))
      local py = waveform_y + (1 - pt.y) * waveform_h
      local is_active = drag.handle == 'point' and drag.point_idx == i
      local is_pt_hovered = closest_idx == i and point_hovered

      if is_active then
        ImGui.DrawList_AddCircleFilled(dl, px, py, 4, env_color)
        -- Tooltip
        local pt_time = envelope_to_sample(pt.x) * sample_duration
        local val_str
        if env_type == M.ENV_VOLUME then
          val_str = pt.y <= 0.001 and '-inf dB' or string.format('%+.1f dB', 20 * math.log(pt.y * 2, 10))
        elseif env_type == M.ENV_PITCH then
          val_str = string.format('%+.1f st', (pt.y - 0.5) * 48)
        else
          val_str = string.format('%.0f%%', pt.y * 100)
        end
        ImGui.BeginTooltip(ctx)
        ImGui.TextColored(ctx, env_color, string.format('%.3fs | %s', pt_time, val_str))
        ImGui.EndTooltip(ctx)
      else
        ImGui.DrawList_AddCircle(dl, px, py, 4, env_color, 0, is_pt_hovered and 2 or 1.5)
      end
    end
  end

  -- ========================================================================
  -- HORIZONTAL DRAG SELECTION (set begin/end markers by drawing)
  -- ========================================================================

  local floor = math.floor

  -- Check if in waveform area and not interacting with other elements
  local in_waveform_for_select = is_hovered and point_in_rect(mouse_x, mouse_y, x, waveform_y, x + content_width, waveform_y + waveform_h)
  local near_env_point = false
  if show_handles and #envelope >= 2 then
    for _, pt in ipairs(envelope) do
      local px = sample_to_screen(envelope_to_sample(pt.x))
      local py = waveform_y + (1 - pt.y) * waveform_h
      if sqrt((mouse_x - px)^2 + (mouse_y - py)^2) < HANDLE_HIT_RADIUS then
        near_env_point = true
        break
      end
    end
  end

  -- Start drag selection (click in waveform area, not on handles/points, not SHIFT/ALT)
  if in_waveform_for_select and mouse_clicked and not drag.handle and not start_hovered and not end_hovered and not near_env_point and not shift_down and not alt_down then
    local start_t = screen_to_sample(mouse_x)
    start_t = max(0, min(1, start_t))
    drag.handle = 'range_select'
    drag.range_start = start_t
    drag.range_current = start_t
  end

  -- Update drag selection while dragging
  if drag.handle == 'range_select' and mouse_down then
    local current_t = screen_to_sample(mouse_x)
    current_t = max(0, min(1, current_t))
    drag.range_current = current_t
  end

  -- Complete drag selection on release - set markers
  if drag.handle == 'range_select' and not mouse_down then
    local sel_start = min(drag.range_start, drag.range_current)
    local sel_end = max(drag.range_start, drag.range_current)

    -- Only set markers if selection is meaningful (> 0.5% of sample)
    if sel_end - sel_start > 0.005 then
      start_point = sel_start
      end_point = sel_end
      start_end_changed = true
      -- Also update zoom to show the selection
      zoom_state.view_start = max(0, sel_start - 0.05)
      zoom_state.view_end = min(1, sel_end + 0.05)
    end

    drag.handle = nil
    drag.range_start = nil
    drag.range_current = nil
  end

  -- Draw drag selection rectangle
  if drag.handle == 'range_select' and drag.range_start and drag.range_current then
    local x1_sel = floor(sample_to_screen(min(drag.range_start, drag.range_current)))
    local x2_sel = floor(sample_to_screen(max(drag.range_start, drag.range_current)))

    -- Clamp to content area
    x1_sel = max(x, x1_sel)
    x2_sel = min(x + content_width, x2_sel)

    if x2_sel > x1_sel then
      -- Fill
      ImGui.DrawList_AddRectFilled(dl, x1_sel, waveform_y, x2_sel, waveform_y + waveform_h, COLORS.drag_select_fill)
      -- Border
      ImGui.DrawList_AddRect(dl, x1_sel, waveform_y, x2_sel, waveform_y + waveform_h, COLORS.drag_select_border, 0, 0, 1)

      -- Show time range in tooltip
      local start_time = min(drag.range_start, drag.range_current) * sample_duration
      local end_time = max(drag.range_start, drag.range_current) * sample_duration
      local duration = end_time - start_time
      ImGui.BeginTooltip(ctx)
      ImGui.Text(ctx, string.format('Set markers: %.3fs - %.3fs (%.3fs)', start_time, end_time, duration))
      ImGui.EndTooltip(ctx)
    end
  end

  -- End drag (for other drag types)
  if not mouse_down and drag.handle ~= 'range_select' then drag.handle, drag.point_idx = nil, nil end

  -- Border
  ImGui.DrawList_AddRect(dl, base_x, y, base_x + width, y + height, COLORS.border, 4, 0, 1)

  -- Bottom lane: sample name
  local sample_name = opts.sample_name
  if sample_name and sample_name ~= '' then
    local max_w = content_width * 0.6
    local text_w = ImGui.CalcTextSize(ctx, sample_name)
    local label = sample_name
    if text_w > max_w then
      while text_w > max_w - 12 and #label > 3 do
        label = label:sub(1, -2)
        text_w = ImGui.CalcTextSize(ctx, label)
      end
      label = label .. '...'
    end
    ImGui.DrawList_AddText(dl, x + 6, bottom_lane_y, COLORS.text, label)
  end

  -- Bottom lane: zoom indicator
  local zoom_pct = (max(0.01, end_point - start_point) / view_range) * 100
  local zoom_text = string.format('%.0f%%', zoom_pct)
  local zoom_text_w = ImGui.CalcTextSize(ctx, zoom_text)
  local zoom_x = x + content_width - zoom_text_w - 8
  local zoom_hovered = is_hovered and point_in_rect(mouse_x, mouse_y, zoom_x - 4, bottom_lane_y, x + content_width - 4, bottom_lane_y + BOTTOM_LANE_HEIGHT)

  ImGui.DrawList_AddText(dl, zoom_x, bottom_lane_y, zoom_hovered and COLORS.icon_selected or COLORS.icon_default, zoom_text)

  if zoom_hovered and mouse_clicked then
    zoom_state.view_start, zoom_state.view_end = start_point, end_point
  end

  -- Help tooltip
  if is_hovered and not drag.handle and not start_hovered and not end_hovered then
    local near_point = false
    if show_handles and #envelope >= 2 then
      for _, pt in ipairs(envelope) do
        local px = sample_to_screen(envelope_to_sample(pt.x))
        local py = waveform_y + (1 - pt.y) * waveform_h
        if sqrt((mouse_x - px)^2 + (mouse_y - py)^2) < HANDLE_HIT_RADIUS then
          near_point = true
          break
        end
      end
    end
    if not near_point then
      ImGui.BeginTooltip(ctx)
      ImGui.TextColored(ctx, env_color, env_type:upper() .. ' Envelope')
      ImGui.Separator(ctx)
      ImGui.TextDisabled(ctx, 'Drag to set begin/end markers')
      ImGui.TextDisabled(ctx, 'Drag points to adjust envelope')
      ImGui.TextDisabled(ctx, 'SHIFT+click to add point')
      ImGui.TextDisabled(ctx, 'ALT+click to remove point')
      ImGui.TextDisabled(ctx, 'CTRL+scroll to zoom')
      ImGui.EndTooltip(ctx)
    end
  end

  -- Callbacks
  if envelope_changed and opts.on_envelope_change then opts.on_envelope_change(envelope) end
  if start_end_changed and opts.on_start_end_change then opts.on_start_end_change(start_point, end_point) end
  if new_env_type and opts.on_env_type_change then opts.on_env_type_change(new_env_type) end
  if new_playback_mode and opts.on_playback_mode_change then opts.on_playback_mode_change(new_playback_mode) end
  if new_note_off_mode and opts.on_note_off_mode_change then opts.on_note_off_mode_change(new_note_off_mode) end
  if new_reverse ~= nil and opts.on_reverse_change then opts.on_reverse_change(new_reverse) end

  return {
    width = width,
    height = height,
    hovered = is_hovered,
    envelope_changed = envelope_changed,
    start_end_changed = start_end_changed,
    env_type_changed = new_env_type ~= nil,
    playback_mode_changed = new_playback_mode ~= nil,
    note_off_mode_changed = new_note_off_mode ~= nil,
    reverse_changed = new_reverse ~= nil,
    envelope = envelope,
    start_point = start_point,
    end_point = end_point,
    env_type = new_env_type or env_type,
    playback_mode = new_playback_mode or playback_mode,
    note_off_mode = new_note_off_mode or note_off_mode,
    reverse = new_reverse ~= nil and new_reverse or is_reversed,
  }
end

return M
