-- @noindex
-- DrumBlocks/widgets/waveform_slicer.lua
-- Waveform display with transient detection and slice editing

local Ark = require('arkitekt')
local ImGui = Ark.ImGui
local Colors = Ark.Colors
local TransientDetector = require('DrumBlocks.domain.transient_detector')

-- Cache functions for performance
local max, min, abs, sqrt, floor = math.max, math.min, math.abs, math.sqrt, math.floor
local AddPolyline = ImGui.DrawList_AddPolyline
local new_array = reaper.new_array

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
  text_dim = 0x666666FF,
  lane_bg = 0x181818FF,
  lane_bg_alt = 0x141414FF,
  separator = 0x333333FF,
  btn_bg = 0x1A1A1AFF,
  btn_bg_hover = 0x2A2A2AFF,
  btn_bg_selected = 0x444444FF,
  btn_bg_selected_hover = 0x555555FF,
  icon_default = 0x888888FF,
  icon_selected = 0xFFFFFFFF,
  waveform = 0xAAAAAAEE,
  waveform_dim = 0xAAAAAA44,

  -- Slice colors (yellow theme)
  slice_marker = 0xDDCC44FF,
  slice_marker_hover = 0xFFEE66FF,
  slice_marker_selected = 0xFFFF88FF,
  slice_region = 0xDDCC4420,
  slice_region_selected = 0xDDCC4440,
  slice_region_hover = 0xDDCC4430,
  slice_number = 0xDDCC44FF,
  slice_handle = 0xDDCC44FF,

  -- Drag selection (cyan/teal for contrast)
  drag_select_fill = 0x44AACC30,
  drag_select_border = 0x44AACCAA,
}

local LEFT_LANE_WIDTH = 28
local RIGHT_LANE_WIDTH = 72
local TOP_LANE_HEIGHT = 22
local BOTTOM_LANE_HEIGHT = 18
local BTN_SIZE = 20
local BTN_GAP = 4
local BTN_ROUNDING = 3
local SLICE_HANDLE_WIDTH = 8

-- Slice modes
M.MODE_TRANSIENT = 'transient'
M.MODE_GRID = 'grid'
M.MODE_MANUAL = 'manual'

-- Persistent state per widget
M._state = {}

-- ============================================================================
-- HELPERS
-- ============================================================================

local function point_in_rect(mx, my, x1, y1, x2, y2)
  return mx >= x1 and mx <= x2 and my >= y1 and my <= y2
end

local function get_btn_bg(is_selected, is_hovered)
  if is_selected then
    return is_hovered and COLORS.btn_bg_selected_hover or COLORS.btn_bg_selected
  end
  return is_hovered and COLORS.btn_bg_hover or COLORS.btn_bg
end

-- Helper: get peak value with proper downsampling
local function get_peak_value(peak_data, num_p, t_normalized, offset, half_window, is_max)
  local pos = t_normalized * (num_p - 1) + 1

  if half_window > 1 then
    local idx_start = max(1, floor(pos - half_window))
    local idx_end = min(num_p, floor(pos + half_window))
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
    local pos_floor = floor(pos)
    local idx_low = max(1, min(num_p, pos_floor))
    local idx_high = max(1, min(num_p, idx_low + 1))
    local frac = pos - pos_floor
    local val_low = peak_data[offset + idx_low]
    local val_high = peak_data[offset + idx_high]
    return val_low + (val_high - val_low) * frac
  end
end

-- ============================================================================
-- ICON DRAWING
-- ============================================================================

local function draw_icon_transient(dl, cx, cy, color)
  -- Waveform-like icon with spike
  ImGui.DrawList_AddLine(dl, cx - 6, cy, cx - 3, cy, color, 1.5)
  ImGui.DrawList_AddLine(dl, cx - 3, cy, cx - 1, cy - 5, color, 1.5)
  ImGui.DrawList_AddLine(dl, cx - 1, cy - 5, cx + 1, cy + 3, color, 1.5)
  ImGui.DrawList_AddLine(dl, cx + 1, cy + 3, cx + 3, cy, color, 1.5)
  ImGui.DrawList_AddLine(dl, cx + 3, cy, cx + 6, cy, color, 1.5)
end

local function draw_icon_grid(dl, cx, cy, color)
  -- Grid lines icon
  for i = -2, 2 do
    local lx = cx + i * 3
    ImGui.DrawList_AddLine(dl, lx, cy - 5, lx, cy + 5, color, 1)
  end
end

local function draw_icon_manual(dl, cx, cy, color)
  -- Plus/add icon
  ImGui.DrawList_AddLine(dl, cx - 5, cy, cx + 5, cy, color, 2)
  ImGui.DrawList_AddLine(dl, cx, cy - 5, cx, cy + 5, color, 2)
end

local function draw_icon_distribute(dl, cx, cy, color)
  -- Arrow pointing to grid
  ImGui.DrawList_AddTriangleFilled(dl, cx - 4, cy, cx, cy - 4, cx, cy + 4, color)
  ImGui.DrawList_AddLine(dl, cx, cy - 3, cx + 5, cy - 3, color, 1.5)
  ImGui.DrawList_AddLine(dl, cx, cy, cx + 5, cy, color, 1.5)
  ImGui.DrawList_AddLine(dl, cx, cy + 3, cx + 5, cy + 3, color, 1.5)
end

local function draw_icon_select_all(dl, cx, cy, color)
  ImGui.DrawList_AddRect(dl, cx - 5, cy - 5, cx + 5, cy + 5, color, 0, 0, 1.5)
  ImGui.DrawList_AddRectFilled(dl, cx - 3, cy - 3, cx + 3, cy + 3, color)
end

-- ============================================================================
-- MAIN DRAW FUNCTION
-- ============================================================================

function M.draw(ctx, opts)
  opts = opts or {}

  -- Extract options
  local peaks = opts.peaks
  local width = opts.width or 400
  local height = opts.height or 140
  local sample_duration = opts.sample_duration or 1.0
  local sample_name = opts.sample_name
  local bpm = opts.bpm
  local widget_id = opts.id or 'waveform_slicer'
  local waveform_color = opts.waveform_color or COLORS.waveform

  -- Callbacks
  local on_slices_change = opts.on_slices_change
  local on_selection_change = opts.on_selection_change
  local on_distribute = opts.on_distribute  -- Called when user wants to distribute slices to pads
  local on_bpm_change = opts.on_bpm_change

  -- Get/init persistent state for this widget
  local state = M._state[widget_id]
  if not state then
    state = {
      mode = M.MODE_TRANSIENT,
      threshold = 0.3,
      pre_roll = 0.01,    -- 1% pre-roll to capture attack onset
      retrigger_ms = 50,  -- Minimum ms between transients
      db_threshold = -40, -- Minimum dB level for transients
      grid_division = 4,  -- Quarter notes
      slices = {},
      selected = {},  -- Map of slice index -> selection order (1, 2, 3...)
      selection_counter = 0,  -- Tracks next selection order number
      deleted = {},   -- Set of deleted slice positions (survives pre-roll changes)
      view_start = 0,
      view_end = 1,
      drag = {},
      -- Horizontal drag selection
      drag_select = nil,  -- { start_t = normalized start, current_t = normalized end }
    }
    M._state[widget_id] = state
  end

  -- Layout calculations
  local base_x, base_y = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)

  local left_x = base_x
  local content_x = base_x + LEFT_LANE_WIDTH
  local content_width = width - LEFT_LANE_WIDTH - RIGHT_LANE_WIDTH
  local right_x = base_x + width - RIGHT_LANE_WIDTH

  local top_y = base_y
  local waveform_y = base_y + TOP_LANE_HEIGHT
  local waveform_h = height - TOP_LANE_HEIGHT - BOTTOM_LANE_HEIGHT
  local bottom_y = waveform_y + waveform_h
  local mid_y = waveform_y + waveform_h / 2

  -- Capture input
  ImGui.InvisibleButton(ctx, '##slicer_' .. widget_id, width, height)
  local is_hovered = ImGui.IsItemHovered(ctx)
  local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
  local mouse_down = ImGui.IsMouseDown(ctx, 0)
  local mouse_clicked = ImGui.IsMouseClicked(ctx, 0)
  local mouse_released = ImGui.IsMouseReleased(ctx, 0)
  local ctrl_down = ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl)
  local shift_down = ImGui.IsKeyDown(ctx, ImGui.Mod_Shift)

  local view_start = state.view_start
  local view_end = state.view_end
  local view_range = view_end - view_start

  -- Helper functions
  local function sample_to_screen(t)
    return content_x + ((t - view_start) / view_range) * content_width
  end

  local function screen_to_sample(sx)
    return view_start + ((sx - content_x) / content_width) * view_range
  end

  -- Handle zoom (CTRL+scroll)
  if is_hovered and ctrl_down then
    local wheel = ImGui.GetMouseWheel(ctx)
    if wheel ~= 0 then
      local current_range = view_end - view_start
      local new_range = max(0.05, min(1.0, current_range * (1 - wheel * 0.15)))

      local mouse_t = view_start + ((mouse_x - content_x) / content_width) * current_range
      local mouse_ratio = (mouse_x - content_x) / content_width
      local desired_start = mouse_t - mouse_ratio * new_range

      state.view_start = max(0, min(1 - new_range, desired_start))
      state.view_end = state.view_start + new_range
      view_start, view_end = state.view_start, state.view_end
      view_range = view_end - view_start
    end
  end

  -- ========================================================================
  -- DETECT/UPDATE SLICES
  -- ========================================================================

  local slices_changed = false

  -- Helper to filter out deleted slices (by approximate position match)
  local function filter_deleted(slices, deleted)
    if not deleted or not next(deleted) then return slices end
    local filtered = {}
    for _, slice in ipairs(slices) do
      local dominated = false
      for del_pos in pairs(deleted) do
        -- Match if within 1% of each other
        if math.abs(slice.start - del_pos) < 0.01 then
          dominated = true
          break
        end
      end
      if not dominated then
        filtered[#filtered + 1] = slice
      end
    end
    return filtered
  end

  -- Auto-detect transients when mode is transient and we have peaks
  if state.mode == M.MODE_TRANSIENT and peaks and #peaks >= 4 then
    -- Check if detection params changed (clears deleted set)
    local params_key = string.format('%.3f_%.0f_%.0f', state.threshold, state.retrigger_ms, state.db_threshold)
    if state._last_params_key ~= params_key then
      state.deleted = {}
      state._last_params_key = params_key
    end

    -- Convert retrigger_ms to normalized distance based on sample duration
    local retrigger_normalized = sample_duration > 0 and (state.retrigger_ms / 1000) / sample_duration or 0.01

    local transients = TransientDetector.detect_from_peaks(peaks, {
      threshold = state.threshold,
      min_distance_normalized = retrigger_normalized,
      db_threshold = state.db_threshold,
    })
    local raw_slices = TransientDetector.transients_to_slices(transients, {
      pre_roll = state.pre_roll,
      include_start = false,  -- Don't create slice at 0ms
    })

    -- Filter out manually deleted slices
    local new_slices = filter_deleted(raw_slices, state.deleted)

    -- Only update if different
    if #new_slices ~= #state.slices or state._last_pre_roll ~= state.pre_roll then
      state.slices = new_slices
      state.selected = {}
      state.selection_counter = 0
      state._last_pre_roll = state.pre_roll
      slices_changed = true
    end
  elseif state.mode == M.MODE_GRID and sample_duration > 0 and bpm and bpm > 0 then
    -- Check if division changed (clears deleted set)
    if state._last_division ~= state.grid_division then
      state.deleted = {}
      state._last_division = state.grid_division
    end

    local slice_points = TransientDetector.slice_by_grid(sample_duration, bpm, state.grid_division)
    local raw_slices = TransientDetector.transients_to_slices(slice_points, {
      pre_roll = state.pre_roll,
      include_start = false,  -- Don't create slice at 0ms
    })

    -- Filter out manually deleted slices
    local new_slices = filter_deleted(raw_slices, state.deleted)

    if #new_slices ~= #state.slices or state._last_pre_roll ~= state.pre_roll then
      state.slices = new_slices
      state.selected = {}
      state.selection_counter = 0
      state._last_pre_roll = state.pre_roll
      slices_changed = true
    end
  end

  local slices = state.slices
  local selected = state.selected

  -- ========================================================================
  -- DRAW BACKGROUNDS
  -- ========================================================================

  -- Left lane
  ImGui.DrawList_AddRectFilled(dl, left_x, base_y, left_x + LEFT_LANE_WIDTH, base_y + height, COLORS.lane_bg, 4, ImGui.DrawFlags_RoundCornersLeft)
  ImGui.DrawList_AddLine(dl, left_x + LEFT_LANE_WIDTH, base_y, left_x + LEFT_LANE_WIDTH, base_y + height, COLORS.separator)

  -- Right lane
  ImGui.DrawList_AddRectFilled(dl, right_x, base_y, right_x + RIGHT_LANE_WIDTH, base_y + height, COLORS.lane_bg, 4, ImGui.DrawFlags_RoundCornersRight)
  ImGui.DrawList_AddLine(dl, right_x, base_y, right_x, base_y + height, COLORS.separator)

  -- Top lane
  ImGui.DrawList_AddRectFilled(dl, content_x, top_y, content_x + content_width, top_y + TOP_LANE_HEIGHT, COLORS.lane_bg_alt)
  ImGui.DrawList_AddLine(dl, content_x, top_y + TOP_LANE_HEIGHT, content_x + content_width, top_y + TOP_LANE_HEIGHT, COLORS.separator)

  -- Waveform area
  ImGui.DrawList_AddRectFilled(dl, content_x, waveform_y, content_x + content_width, waveform_y + waveform_h, COLORS.bg)

  -- Bottom lane
  ImGui.DrawList_AddRectFilled(dl, content_x, bottom_y, content_x + content_width, bottom_y + BOTTOM_LANE_HEIGHT, COLORS.lane_bg)
  ImGui.DrawList_AddLine(dl, content_x, bottom_y, content_x + content_width, bottom_y, COLORS.separator)

  -- Grid lines
  for i = 1, 7 do
    local gx = content_x + (content_width / 8) * i
    ImGui.DrawList_AddLine(dl, gx, waveform_y, gx, waveform_y + waveform_h, COLORS.grid_line)
  end
  ImGui.DrawList_AddLine(dl, content_x, mid_y, content_x + content_width, mid_y, COLORS.center_line)

  -- ========================================================================
  -- LEFT LANE: Mode Buttons
  -- ========================================================================

  local modes = {
    { id = M.MODE_TRANSIENT, tip = 'Transient Detection', draw = draw_icon_transient },
    { id = M.MODE_GRID, tip = 'Grid / BPM', draw = draw_icon_grid },
    { id = M.MODE_MANUAL, tip = 'Manual', draw = draw_icon_manual },
  }

  local mode_start_y = base_y + 8
  local mode_btn_x = left_x + (LEFT_LANE_WIDTH - BTN_SIZE) / 2

  for i, mode in ipairs(modes) do
    local btn_y = mode_start_y + (i - 1) * (BTN_SIZE + BTN_GAP)
    local is_sel = state.mode == mode.id
    local hovered = is_hovered and point_in_rect(mouse_x, mouse_y, mode_btn_x, btn_y, mode_btn_x + BTN_SIZE, btn_y + BTN_SIZE)

    ImGui.DrawList_AddRectFilled(dl, mode_btn_x, btn_y, mode_btn_x + BTN_SIZE, btn_y + BTN_SIZE, get_btn_bg(is_sel, hovered), BTN_ROUNDING)
    mode.draw(dl, mode_btn_x + BTN_SIZE / 2, btn_y + BTN_SIZE / 2, is_sel and COLORS.slice_marker or COLORS.icon_default)

    if hovered then
      if mouse_clicked and not is_sel then
        state.mode = mode.id
        state.slices = {}
        state.selected = {}
        state.selection_counter = 0
        slices_changed = true
      end
      ImGui.BeginTooltip(ctx)
      ImGui.Text(ctx, mode.tip)
      ImGui.EndTooltip(ctx)
    end
  end

  -- ========================================================================
  -- RIGHT LANE: Controls
  -- ========================================================================

  local ctrl_y = base_y + 8
  local ctrl_x = right_x + 4
  local ctrl_w = RIGHT_LANE_WIDTH - 8

  -- Helper to draw a compact horizontal slider with label and value
  local function draw_h_slider(label, value, val_min, val_max, y_pos, format_func, tooltip)
    local row_h = 28
    local label_h = 10
    local slider_h = 4
    local slider_x = ctrl_x
    local slider_w = ctrl_w

    -- Label (left-aligned, small)
    ImGui.DrawList_AddText(dl, slider_x, y_pos, COLORS.text_dim, label)

    -- Value (right-aligned)
    local val_text = format_func(value)
    local val_w = ImGui.CalcTextSize(ctx, val_text)
    ImGui.DrawList_AddText(dl, slider_x + slider_w - val_w, y_pos, COLORS.text, val_text)

    -- Slider track (below label)
    local track_y = y_pos + label_h + 4
    ImGui.DrawList_AddRectFilled(dl, slider_x, track_y, slider_x + slider_w, track_y + slider_h, COLORS.btn_bg, 2)

    -- Fill
    local norm = (value - val_min) / (val_max - val_min)
    norm = max(0, min(1, norm))
    local fill_w = norm * slider_w
    ImGui.DrawList_AddRectFilled(dl, slider_x, track_y, slider_x + fill_w, track_y + slider_h, COLORS.slice_marker, 2)

    -- Handle
    local handle_x = slider_x + norm * slider_w
    ImGui.DrawList_AddCircleFilled(dl, handle_x, track_y + slider_h / 2, 4, COLORS.slice_marker)

    -- Interaction zone
    local hovered = is_hovered and point_in_rect(mouse_x, mouse_y, slider_x - 2, y_pos, slider_x + slider_w + 2, track_y + slider_h + 4)

    -- Tooltip
    if hovered and tooltip then
      ImGui.BeginTooltip(ctx)
      ImGui.Text(ctx, tooltip)
      ImGui.EndTooltip(ctx)
    end

    return y_pos + row_h, hovered, slider_x, slider_w, val_min, val_max
  end

  -- Transient mode controls
  if state.mode == M.MODE_TRANSIENT then
    -- 1. Sensitivity (inverted: low threshold = high sensitivity)
    local sens_y, sens_hovered, sx, sw, smin, smax = draw_h_slider(
      'Sens',
      1 - state.threshold,
      0, 1,
      ctrl_y,
      function(v) return string.format('%.0f%%', v * 100) end,
      'Sensitivity: Higher = more slices'
    )

    if sens_hovered and mouse_clicked then state.drag.sens = true end
    if state.drag.sens then
      if mouse_down then
        local new_norm = max(0, min(1, (mouse_x - sx) / sw))
        state.threshold = 1 - max(0.05, min(0.95, new_norm))
        state.slices = {}
        slices_changed = true
      else
        state.drag.sens = false
      end
    end

    ctrl_y = sens_y

    -- 2. Pre-roll (0-50ms)
    local pre_y, pre_hovered = draw_h_slider(
      'Pre',
      state.pre_roll * 1000,
      0, 50,
      ctrl_y,
      function(v) return string.format('%.0fms', v) end,
      'Pre-roll: Captures attack onset'
    )

    if pre_hovered and mouse_clicked then state.drag.pre = true end
    if state.drag.pre then
      if mouse_down then
        local new_norm = max(0, min(1, (mouse_x - ctrl_x) / ctrl_w))
        state.pre_roll = new_norm * 0.05
      else
        state.drag.pre = false
      end
    end

    ctrl_y = pre_y

    -- 3. Retrigger (0-1000ms)
    local retrig_y, retrig_hovered = draw_h_slider(
      'Retrig',
      state.retrigger_ms,
      0, 1000,
      ctrl_y,
      function(v) return string.format('%.0fms', v) end,
      'Retrigger: Min time between slices'
    )

    if retrig_hovered and mouse_clicked then state.drag.retrig = true end
    if state.drag.retrig then
      if mouse_down then
        local new_norm = max(0, min(1, (mouse_x - ctrl_x) / ctrl_w))
        state.retrigger_ms = new_norm * 1000
        state.slices = {}
        slices_changed = true
      else
        state.drag.retrig = false
      end
    end

    ctrl_y = retrig_y

    -- 4. dB Threshold (-60 to 0)
    local db_y, db_hovered = draw_h_slider(
      'Floor',
      state.db_threshold,
      -60, 0,
      ctrl_y,
      function(v) return string.format('%.0fdB', v) end,
      'Floor: Ignore transients below this level'
    )

    if db_hovered and mouse_clicked then state.drag.db = true end
    if state.drag.db then
      if mouse_down then
        local new_norm = max(0, min(1, (mouse_x - ctrl_x) / ctrl_w))
        state.db_threshold = -60 + new_norm * 60
        state.slices = {}
        slices_changed = true
      else
        state.drag.db = false
      end
    end

    ctrl_y = db_y
  end

  -- BPM input (for grid mode)
  if state.mode == M.MODE_GRID then
    ImGui.DrawList_AddText(dl, ctrl_x, ctrl_y, COLORS.text_dim, 'BPM')
    ctrl_y = ctrl_y + 14

    local bpm_text = bpm and tostring(floor(bpm)) or '---'
    local bpm_w = ImGui.CalcTextSize(ctx, bpm_text)
    ImGui.DrawList_AddText(dl, ctrl_x + (ctrl_w - bpm_w) / 2, ctrl_y, COLORS.text, bpm_text)
    ctrl_y = ctrl_y + 18

    -- Division selector
    ImGui.DrawList_AddText(dl, ctrl_x, ctrl_y, COLORS.text_dim, 'Div')
    ctrl_y = ctrl_y + 14

    local divisions = { 2, 4, 8, 16 }
    local div_labels = { '1/2', '1/4', '1/8', '1/16' }
    for i, div in ipairs(divisions) do
      local is_sel = state.grid_division == div
      local btn_y = ctrl_y + (i - 1) * 16
      local label = div_labels[i]
      local label_w = ImGui.CalcTextSize(ctx, label)

      local btn_hovered = is_hovered and point_in_rect(mouse_x, mouse_y, ctrl_x, btn_y, ctrl_x + ctrl_w, btn_y + 14)
      local color = is_sel and COLORS.slice_marker or (btn_hovered and COLORS.text or COLORS.text_dim)
      ImGui.DrawList_AddText(dl, ctrl_x + (ctrl_w - label_w) / 2, btn_y, color, label)

      if btn_hovered and mouse_clicked then
        state.grid_division = div
        state.slices = {}
        slices_changed = true
      end
    end
  end

  -- ========================================================================
  -- WAVEFORM RENDERING
  -- ========================================================================

  if peaks and #peaks >= 4 then
    local num_peaks = #peaks // 2
    local base_scale = (waveform_h / 2) * 0.9
    local top_pts, bot_pts = {}, {}

    local peaks_per_pixel = num_peaks * view_range / content_width
    local half_window = peaks_per_pixel * 0.5
    local smoothing_factor = max(1, sqrt(peaks_per_pixel))
    local draw_points = max(32, floor(content_width / smoothing_factor))

    local inv_draw = 1 / (draw_points - 1)
    local ti, bi = 0, 0

    for i = 1, draw_points do
      local ratio = (i - 1) * inv_draw
      local px = content_x + ratio * content_width
      local t = view_start + ratio * view_range

      if t >= 0 and t <= 1 then
        local max_val = get_peak_value(peaks, num_peaks, t, 0, half_window, true)
        local min_val = get_peak_value(peaks, num_peaks, t, num_peaks, half_window, false)

        local top_y_pt = max(waveform_y, min(waveform_y + waveform_h, mid_y - max_val * base_scale))
        local bot_y_pt = max(waveform_y, min(waveform_y + waveform_h, mid_y - min_val * base_scale))

        ti = ti + 1; top_pts[ti] = px; ti = ti + 1; top_pts[ti] = top_y_pt
        bi = bi + 1; bot_pts[bi] = px; bi = bi + 1; bot_pts[bi] = bot_y_pt
      end
    end

    if ti >= 4 then
      AddPolyline(dl, new_array(top_pts), waveform_color, ImGui.DrawFlags_None, 1.0)
      AddPolyline(dl, new_array(bot_pts), waveform_color, ImGui.DrawFlags_None, 1.0)
    end
  else
    local text = 'No sample loaded'
    local text_w = ImGui.CalcTextSize(ctx, text)
    ImGui.DrawList_AddText(dl, content_x + (content_width - text_w) / 2, mid_y - 6, COLORS.text, text)
  end

  -- ========================================================================
  -- SLICE REGIONS AND MARKERS
  -- ========================================================================

  local hovered_slice = nil
  local hovered_handle = nil  -- { slice_idx, 'start' or 'stop' }

  for i, slice in ipairs(slices) do
    local x1 = sample_to_screen(slice.start)
    local x2 = sample_to_screen(slice.stop)

    -- Skip if not visible
    if x2 < content_x or x1 > content_x + content_width then
      goto continue
    end

    x1 = max(content_x, x1)
    x2 = min(content_x + content_width, x2)

    local is_selected = selected[i]
    local slice_hovered = is_hovered and point_in_rect(mouse_x, mouse_y, x1, waveform_y, x2, waveform_y + waveform_h)

    if slice_hovered then
      hovered_slice = i
    end

    -- Check handle hover
    local start_handle_hovered = is_hovered and point_in_rect(mouse_x, mouse_y, x1 - SLICE_HANDLE_WIDTH/2, waveform_y, x1 + SLICE_HANDLE_WIDTH/2, waveform_y + waveform_h)
    local stop_handle_hovered = is_hovered and i < #slices and point_in_rect(mouse_x, mouse_y, x2 - SLICE_HANDLE_WIDTH/2, waveform_y, x2 + SLICE_HANDLE_WIDTH/2, waveform_y + waveform_h)

    if start_handle_hovered and state.mode == M.MODE_MANUAL then
      hovered_handle = { i, 'start' }
    elseif stop_handle_hovered and state.mode == M.MODE_MANUAL then
      hovered_handle = { i, 'stop' }
    end

    -- Floor positions to whole pixels
    local x1_px = floor(x1)
    local x2_px = floor(x2)

    -- Draw region fill (start after 2px marker to avoid overlap)
    local region_color = is_selected and COLORS.slice_region_selected
                      or (slice_hovered and COLORS.slice_region_hover)
                      or COLORS.slice_region
    ImGui.DrawList_AddRectFilled(dl, x1_px + 2, waveform_y, x2_px, waveform_y + waveform_h, region_color)

    -- Draw slice marker line (at start) - 2px width, crisp
    local marker_color = is_selected and COLORS.slice_marker_selected
                      or (start_handle_hovered and COLORS.slice_marker_hover)
                      or COLORS.slice_marker
    ImGui.DrawList_AddRectFilled(dl, x1_px, waveform_y, x1_px + 2, waveform_y + waveform_h, marker_color)

    -- Draw slice number in top lane (small number)
    local num_text = tostring(i)
    local num_w = ImGui.CalcTextSize(ctx, num_text)
    local num_x = floor(x1_px + (x2_px - x1_px - num_w) / 2)
    if num_x >= content_x and num_x + num_w <= content_x + content_width then
      local num_color = is_selected and COLORS.slice_marker_selected or COLORS.slice_number
      ImGui.DrawList_AddText(dl, num_x, top_y + floor((TOP_LANE_HEIGHT - 12) / 2), num_color, num_text)
    end

    -- Draw selection order badge (for selected slices)
    if is_selected then
      -- Selection order is stored directly in selected[i]
      local sel_order = selected[i]

      if sel_order and sel_order > 0 then
        local badge_text = tostring(sel_order)
        local badge_w, badge_text_h = ImGui.CalcTextSize(ctx, badge_text)

        -- Square badge - fixed size for consistency
        local badge_size = 14
        local badge_x = x1_px + 3
        local badge_y = waveform_y + 3

        -- Draw square background with border
        ImGui.DrawList_AddRectFilled(dl, badge_x, badge_y, badge_x + badge_size, badge_y + badge_size, 0x222222DD)
        ImGui.DrawList_AddRect(dl, badge_x, badge_y, badge_x + badge_size, badge_y + badge_size, COLORS.slice_marker, 0, 0, 1)

        -- Center text in square
        local text_x = floor(badge_x + (badge_size - badge_w) / 2)
        local text_y = floor(badge_y + (badge_size - badge_text_h) / 2)
        ImGui.DrawList_AddText(dl, text_x, text_y, COLORS.slice_marker, badge_text)
      end
    end

    ::continue::
  end

  -- ========================================================================
  -- SLICE INTERACTION
  -- ========================================================================

  local alt_down = ImGui.IsKeyDown(ctx, ImGui.Mod_Alt)

  -- ALT+Click to delete slice
  if mouse_clicked and hovered_slice and alt_down then
    local slice = slices[hovered_slice]
    if slice then
      -- Mark position as deleted (survives pre-roll changes)
      state.deleted[slice.start] = true
      -- Remove from current slices
      table.remove(slices, hovered_slice)
      -- Clear selection of this slice
      selected[hovered_slice] = nil
      -- Re-index selections above deleted index
      local new_selected = {}
      for idx in pairs(selected) do
        if idx > hovered_slice then
          new_selected[idx - 1] = true
        elseif idx < hovered_slice then
          new_selected[idx] = true
        end
      end
      state.selected = new_selected
      selected = state.selected
      slices_changed = true
    end
  -- Click to select (only if not ALT)
  elseif mouse_clicked and hovered_slice and not hovered_handle and not alt_down then
    if ctrl_down then
      -- Toggle selection with order tracking
      if selected[hovered_slice] then
        -- Deselect: remove and renumber remaining selections
        local removed_order = selected[hovered_slice]
        selected[hovered_slice] = nil
        -- Decrement order for selections that came after
        for idx, order in pairs(selected) do
          if order > removed_order then
            selected[idx] = order - 1
          end
        end
        state.selection_counter = state.selection_counter - 1
      else
        -- Add to selection with next order number
        state.selection_counter = state.selection_counter + 1
        selected[hovered_slice] = state.selection_counter
      end
    elseif shift_down and state.last_selected then
      -- Range selection: add in position order
      local from_idx = min(state.last_selected, hovered_slice)
      local to_idx = max(state.last_selected, hovered_slice)
      for i = from_idx, to_idx do
        if not selected[i] then
          state.selection_counter = state.selection_counter + 1
          selected[i] = state.selection_counter
        end
      end
    else
      -- Single selection: reset counter
      state.selection_counter = 1
      state.selected = { [hovered_slice] = 1 }
      selected = state.selected
    end
    state.last_selected = hovered_slice

    if on_selection_change then
      -- Return in selection order
      local sel_list = {}
      for idx, order in pairs(selected) do
        sel_list[order] = idx
      end
      -- Compact the list (in case of gaps)
      local result = {}
      for _, idx in ipairs(sel_list) do
        result[#result + 1] = idx
      end
      on_selection_change(result)
    end
  end

  -- Manual mode: add slice on double-click
  if state.mode == M.MODE_MANUAL and is_hovered and ImGui.IsMouseDoubleClicked(ctx, 0) then
    local click_t = screen_to_sample(mouse_x)
    if click_t >= 0 and click_t <= 1 then
      -- Find where to insert
      local insert_idx = #slices + 1
      for i, slice in ipairs(slices) do
        if click_t < slice.start then
          insert_idx = i
          break
        elseif click_t < slice.stop then
          -- Split this slice
          local new_slice = { start = click_t, stop = slice.stop }
          slice.stop = click_t
          table.insert(slices, i + 1, new_slice)
          slices_changed = true
          break
        end
      end
    end
  end

  -- Handle drag for manual mode
  if hovered_handle and mouse_clicked and state.mode == M.MODE_MANUAL then
    state.drag.handle = hovered_handle
    state.drag.start_x = mouse_x
    state.drag.orig_pos = hovered_handle[2] == 'start' and slices[hovered_handle[1]].start or slices[hovered_handle[1]].stop
  end

  if state.drag.handle and mouse_down then
    local delta = (mouse_x - state.drag.start_x) / content_width * view_range
    local new_pos = max(0, min(1, state.drag.orig_pos + delta))
    local slice_idx = state.drag.handle[1]
    local handle_type = state.drag.handle[2]

    if handle_type == 'start' then
      local prev_stop = slice_idx > 1 and slices[slice_idx - 1].stop or 0
      slices[slice_idx].start = max(prev_stop, min(slices[slice_idx].stop - 0.01, new_pos))
      if slice_idx > 1 then
        slices[slice_idx - 1].stop = slices[slice_idx].start
      end
    else
      local next_start = slice_idx < #slices and slices[slice_idx + 1].start or 1
      slices[slice_idx].stop = max(slices[slice_idx].start + 0.01, min(next_start, new_pos))
      if slice_idx < #slices then
        slices[slice_idx + 1].start = slices[slice_idx].stop
      end
    end
    slices_changed = true
  end

  if mouse_released then
    state.drag.handle = nil
  end

  -- ========================================================================
  -- HORIZONTAL DRAG SELECTION (Manual mode)
  -- ========================================================================

  -- Check if mouse is in waveform area
  local in_waveform_area = is_hovered and point_in_rect(mouse_x, mouse_y, content_x, waveform_y, content_x + content_width, waveform_y + waveform_h)

  -- Start drag selection on click in waveform area (manual mode, not on handle or existing slice action)
  if state.mode == M.MODE_MANUAL and in_waveform_area and mouse_clicked and not hovered_handle and not alt_down then
    -- Only start drag if not clicking on a slice (to allow slice selection)
    if not hovered_slice then
      local start_t = screen_to_sample(mouse_x)
      start_t = max(0, min(1, start_t))
      state.drag_select = { start_t = start_t, current_t = start_t }
    end
  end

  -- Update drag selection while dragging
  if state.drag_select and mouse_down then
    local current_t = screen_to_sample(mouse_x)
    current_t = max(0, min(1, current_t))
    state.drag_select.current_t = current_t
  end

  -- Complete drag selection on release
  if state.drag_select and mouse_released then
    local sel = state.drag_select
    local sel_start = min(sel.start_t, sel.current_t)
    local sel_end = max(sel.start_t, sel.current_t)

    -- Only create slice if selection is meaningful (> 0.5% of sample)
    if sel_end - sel_start > 0.005 then
      -- Create new slice from selection
      local new_slice = { start = sel_start, stop = sel_end }

      -- Simple insertion: add slice and sort by start position
      slices[#slices + 1] = new_slice
      table.sort(slices, function(a, b) return a.start < b.start end)

      slices_changed = true
    end

    state.drag_select = nil
  end

  -- Draw drag selection rectangle
  if state.drag_select then
    local sel = state.drag_select
    local x1_sel = floor(sample_to_screen(min(sel.start_t, sel.current_t)))
    local x2_sel = floor(sample_to_screen(max(sel.start_t, sel.current_t)))

    -- Clamp to content area
    x1_sel = max(content_x, x1_sel)
    x2_sel = min(content_x + content_width, x2_sel)

    if x2_sel > x1_sel then
      -- Fill
      ImGui.DrawList_AddRectFilled(dl, x1_sel, waveform_y, x2_sel, waveform_y + waveform_h, COLORS.drag_select_fill)
      -- Border
      ImGui.DrawList_AddRect(dl, x1_sel, waveform_y, x2_sel, waveform_y + waveform_h, COLORS.drag_select_border, 0, 0, 1)

      -- Show time range in tooltip
      local start_time = min(sel.start_t, sel.current_t) * sample_duration
      local end_time = max(sel.start_t, sel.current_t) * sample_duration
      local duration = end_time - start_time
      ImGui.BeginTooltip(ctx)
      ImGui.Text(ctx, string.format('%.3fs - %.3fs (%.3fs)', start_time, end_time, duration))
      ImGui.EndTooltip(ctx)
    end
  end

  -- ========================================================================
  -- TOP LANE: Actions
  -- ========================================================================

  local action_x = content_x + 4
  local action_y = top_y + (TOP_LANE_HEIGHT - BTN_SIZE) / 2 + 1

  -- Select All button
  local sel_all_hovered = is_hovered and point_in_rect(mouse_x, mouse_y, action_x, action_y, action_x + BTN_SIZE, action_y + BTN_SIZE)
  ImGui.DrawList_AddRectFilled(dl, action_x, action_y, action_x + BTN_SIZE, action_y + BTN_SIZE, get_btn_bg(false, sel_all_hovered), BTN_ROUNDING)
  draw_icon_select_all(dl, action_x + BTN_SIZE / 2, action_y + BTN_SIZE / 2, sel_all_hovered and COLORS.slice_marker or COLORS.icon_default)

  if sel_all_hovered then
    if mouse_clicked then
      state.selected = {}
      state.selection_counter = #slices
      for i = 1, #slices do
        state.selected[i] = i  -- Order by position when selecting all
      end
      selected = state.selected
    end
    ImGui.BeginTooltip(ctx)
    ImGui.Text(ctx, 'Select All')
    ImGui.EndTooltip(ctx)
  end

  action_x = action_x + BTN_SIZE + BTN_GAP

  -- Distribute button
  local selected_count = 0
  for _ in pairs(selected) do selected_count = selected_count + 1 end

  local dist_enabled = selected_count > 0
  local dist_hovered = dist_enabled and is_hovered and point_in_rect(mouse_x, mouse_y, action_x, action_y, action_x + BTN_SIZE, action_y + BTN_SIZE)

  ImGui.DrawList_AddRectFilled(dl, action_x, action_y, action_x + BTN_SIZE, action_y + BTN_SIZE, get_btn_bg(false, dist_hovered), BTN_ROUNDING)
  draw_icon_distribute(dl, action_x + BTN_SIZE / 2, action_y + BTN_SIZE / 2, dist_enabled and (dist_hovered and COLORS.slice_marker or COLORS.icon_default) or COLORS.text_dim)

  if dist_hovered then
    if mouse_clicked and on_distribute then
      -- Sort by selection order, not position
      local sel_slices = {}
      for idx, order in pairs(selected) do
        sel_slices[#sel_slices + 1] = { index = idx, order = order, start = slices[idx].start, stop = slices[idx].stop }
      end
      table.sort(sel_slices, function(a, b) return a.order < b.order end)
      on_distribute(sel_slices)
    end
    ImGui.BeginTooltip(ctx)
    ImGui.Text(ctx, string.format('Distribute %d slices to pads', selected_count))
    ImGui.EndTooltip(ctx)
  end

  -- ========================================================================
  -- BOTTOM LANE: Info
  -- ========================================================================

  -- Sample name (left side)
  if sample_name and sample_name ~= '' then
    local max_w = content_width * 0.5
    local text_w = ImGui.CalcTextSize(ctx, sample_name)
    local label = sample_name
    if text_w > max_w then
      while text_w > max_w - 12 and #label > 3 do
        label = label:sub(1, -2)
        text_w = ImGui.CalcTextSize(ctx, label)
      end
      label = label .. '...'
    end
    ImGui.DrawList_AddText(dl, content_x + 6, bottom_y + 2, COLORS.text, label)
  end

  -- Duration and slice count (right side): "10.88s / 11 slices"
  local info_text = ''
  if sample_duration > 0 then
    info_text = string.format('%.2fs', sample_duration)
  end
  if #slices > 0 then
    if info_text ~= '' then
      info_text = info_text .. ' / '
    end
    info_text = info_text .. string.format('%d slice%s', #slices, #slices == 1 and '' or 's')
  end
  if info_text ~= '' then
    local info_w = ImGui.CalcTextSize(ctx, info_text)
    ImGui.DrawList_AddText(dl, content_x + content_width - info_w - 6, bottom_y + 2, COLORS.text_dim, info_text)
  end

  -- ========================================================================
  -- BORDER
  -- ========================================================================

  ImGui.DrawList_AddRect(dl, base_x, base_y, base_x + width, base_y + height, COLORS.border, 4, 0, 1)

  -- ========================================================================
  -- TOOLTIPS
  -- ========================================================================

  if hovered_slice and not state.drag.handle and not state.drag_select then
    local slice = slices[hovered_slice]
    local start_time = slice.start * sample_duration
    local stop_time = slice.stop * sample_duration
    local duration = stop_time - start_time

    ImGui.BeginTooltip(ctx)
    ImGui.TextColored(ctx, COLORS.slice_marker, string.format('Slice %d', hovered_slice))
    ImGui.Text(ctx, string.format('%.3fs - %.3fs (%.3fs)', start_time, stop_time, duration))
    ImGui.Separator(ctx)
    ImGui.TextDisabled(ctx, 'Click to select')
    ImGui.TextDisabled(ctx, 'Ctrl+click to multi-select')
    ImGui.TextDisabled(ctx, 'Alt+click to delete')
    ImGui.TextDisabled(ctx, 'Drag to pad grid')
    ImGui.EndTooltip(ctx)
  elseif state.mode == M.MODE_MANUAL and in_waveform_area and not hovered_slice and not state.drag.handle and not state.drag_select then
    ImGui.BeginTooltip(ctx)
    ImGui.TextColored(ctx, COLORS.slice_marker, 'Manual Slicing')
    ImGui.Separator(ctx)
    ImGui.TextDisabled(ctx, 'Drag to create slice')
    ImGui.TextDisabled(ctx, 'Double-click to split')
    ImGui.EndTooltip(ctx)
  end

  -- ========================================================================
  -- CALLBACKS
  -- ========================================================================

  if slices_changed and on_slices_change then
    on_slices_change(slices)
  end

  -- ========================================================================
  -- DRAG DATA (for external drag-drop)
  -- ========================================================================

  local drag_payload = nil
  if selected_count > 0 and is_hovered and ImGui.IsMouseDragging(ctx, 0, 10) then
    -- Sort by selection order, not position
    local sel_slices = {}
    for idx, order in pairs(selected) do
      sel_slices[#sel_slices + 1] = { index = idx, order = order, start = slices[idx].start, stop = slices[idx].stop }
    end
    table.sort(sel_slices, function(a, b) return a.order < b.order end)
    drag_payload = sel_slices
  end

  return {
    width = width,
    height = height,
    hovered = is_hovered,
    slices = slices,
    selected = selected,
    selected_count = selected_count,
    mode = state.mode,
    threshold = state.threshold,
    drag_payload = drag_payload,
  }
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

-- Get current slices for a widget
function M.getSlices(widget_id)
  local state = M._state[widget_id]
  return state and state.slices or {}
end

-- Get selected slice indices (in selection order)
function M.getSelected(widget_id)
  local state = M._state[widget_id]
  if not state then return {} end

  -- Build list with order info
  local sel = {}
  for idx, order in pairs(state.selected) do
    sel[#sel + 1] = { idx = idx, order = order }
  end
  -- Sort by selection order
  table.sort(sel, function(a, b) return a.order < b.order end)
  -- Return just the indices
  local result = {}
  for i, item in ipairs(sel) do
    result[i] = item.idx
  end
  return result
end

-- Set mode programmatically
function M.setMode(widget_id, mode)
  local state = M._state[widget_id]
  if state then
    state.mode = mode
    state.slices = {}
    state.selected = {}
    state.selection_counter = 0
  end
end

-- Clear state for a widget
function M.reset(widget_id)
  M._state[widget_id] = nil
end

return M
