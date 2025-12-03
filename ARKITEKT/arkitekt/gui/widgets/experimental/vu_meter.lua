-- @noindex
-- arkitekt/gui/widgets/experimental/vu_meter.lua
-- EXPERIMENTAL: VU meter widget for audio level visualization
-- Shows peak and RMS levels with color gradient (green → yellow → red)

local ImGui = require('arkitekt.platform.imgui')
local Theme = require('arkitekt.core.theme')
local Colors = require('arkitekt.core.colors')
local Base = require('arkitekt.gui.widgets.base')

local M = {}

-- ============================================================================
-- CONSTANTS
-- ============================================================================

-- dB thresholds for color zones
local DB_GREEN = -18    -- Below this: green
local DB_YELLOW = -6    -- Below this: yellow
local DB_RED = -3       -- Below this: orange
-- Above DB_RED: red

-- Peak hold time
local PEAK_HOLD_TIME = 1.0  -- seconds

-- ============================================================================
-- DEFAULTS
-- ============================================================================

local DEFAULTS = {
  -- Identity
  id = nil,
  label = "",

  -- Position (nil = use cursor)
  x = nil,
  y = nil,

  -- Size
  width = 20,
  height = 200,
  orientation = "vertical",  -- "vertical" or "horizontal"

  -- Values (in dB, typically -inf to 0)
  peak = -100,      -- Current peak level (dB)
  rms = -100,       -- Current RMS level (dB)
  min_db = -60,     -- Minimum dB value to display
  max_db = 0,       -- Maximum dB value (usually 0 dB)

  -- State
  disabled = false,
  show_peak_hold = true,    -- Show peak hold indicator
  show_scale = true,        -- Show dB scale markings
  show_clip_indicator = true, -- Show clipping indicator

  -- Style
  bg_color = nil,
  border_color = nil,
  color_green = nil,
  color_yellow = nil,
  color_orange = nil,
  color_red = nil,
  color_clip = nil,
  peak_hold_color = nil,
  scale_text_color = nil,

  -- Callbacks
  tooltip = nil,

  -- Cursor control
  advance = "vertical",

  -- Draw list
  draw_list = nil,
}

-- ============================================================================
-- STATE MANAGEMENT
-- ============================================================================

local instances = Base.create_instance_registry()

local function create_state(id)
  return {
    id = id,
    peak_hold_value = -100,
    peak_hold_time = 0,
    clipped = false,
    clip_time = 0,
  }
end

-- ============================================================================
-- COLOR UTILITIES
-- ============================================================================

local function get_level_color(db, opts)
  if db >= DB_RED then
    return opts.color_red or Colors.hexrgb("#FF3333")
  elseif db >= DB_YELLOW then
    return opts.color_orange or Colors.hexrgb("#FF9933")
  elseif db >= DB_GREEN then
    return opts.color_yellow or Colors.hexrgb("#FFFF33")
  else
    return opts.color_green or Colors.hexrgb("#33FF33")
  end
end

-- ============================================================================
-- RENDERING
-- ============================================================================

local function render_vertical_meter(ctx, dl, x, y, w, h, peak_db, rms_db, min_db, max_db, opts, state)
  local bg_color = opts.bg_color or Theme.COLORS.BG_BASE
  local border_color = opts.border_color or Theme.COLORS.BORDER_OUTER

  -- Background
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, bg_color)

  -- Calculate normalized positions (0 = bottom, 1 = top)
  local function db_to_y(db)
    if db <= min_db then return y + h end
    if db >= max_db then return y end
    local t = (db - min_db) / (max_db - min_db)
    return y + h - (t * h)
  end

  -- Draw RMS level (filled from bottom)
  if rms_db > min_db then
    local rms_y = db_to_y(rms_db)
    local rms_h = (y + h) - rms_y

    -- Draw gradient by segments
    local segments = 20
    for i = 0, segments - 1 do
      local seg_y1 = y + h - (i / segments) * h
      local seg_y2 = y + h - ((i + 1) / segments) * h

      -- Only draw if within RMS range
      if seg_y1 > rms_y then
        local seg_db = min_db + ((y + h - seg_y1) / h) * (max_db - min_db)
        local color = get_level_color(seg_db, opts)

        -- Dim for RMS
        color = Colors.with_opacity(color, 0.6)

        ImGui.DrawList_AddRectFilled(dl, x + 1, math.max(seg_y2, rms_y), x + w - 1, seg_y1, color)
      end
    end
  end

  -- Draw peak level (brighter, narrower bar)
  if peak_db > min_db then
    local peak_y = db_to_y(peak_db)
    local peak_h = math.max(2, (y + h) - peak_y)

    -- Draw gradient by segments
    local segments = 20
    for i = 0, segments - 1 do
      local seg_y1 = y + h - (i / segments) * h
      local seg_y2 = y + h - ((i + 1) / segments) * h

      -- Only draw if within peak range
      if seg_y1 > peak_y then
        local seg_db = min_db + ((y + h - seg_y1) / h) * (max_db - min_db)
        local color = get_level_color(seg_db, opts)

        ImGui.DrawList_AddRectFilled(dl, x + 1, math.max(seg_y2, peak_y), x + w - 1, seg_y1, color)
      end
    end
  end

  -- Peak hold indicator
  if opts.show_peak_hold and state.peak_hold_value > min_db then
    local hold_y = db_to_y(state.peak_hold_value)
    local hold_color = opts.peak_hold_color or Colors.hexrgb("#FFFFFF")
    ImGui.DrawList_AddLine(dl, x + 1, hold_y, x + w - 1, hold_y, hold_color, 2)
  end

  -- Clip indicator (top)
  if opts.show_clip_indicator and state.clipped then
    local clip_color = opts.color_clip or Colors.hexrgb("#FF0000")
    local clip_alpha = math.max(0, 1.0 - (state.clip_time / 2.0))  -- Fade over 2 seconds
    clip_color = Colors.with_opacity(clip_color, clip_alpha)
    ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + 4, clip_color)
  end

  -- Border
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, border_color, 0, 0, 1)

  -- Scale markings (if enabled and enough width)
  if opts.show_scale and w >= 30 then
    local scale_color = opts.scale_text_color or Theme.COLORS.TEXT_DIMMED
    local marks = {0, -6, -12, -18, -24, -36, -48}

    for _, db in ipairs(marks) do
      if db >= min_db and db <= max_db then
        local mark_y = db_to_y(db)
        -- Small tick mark
        ImGui.DrawList_AddLine(dl, x + w, mark_y, x + w + 3, mark_y, scale_color, 1)

        -- Text label (right of meter)
        local label = tostring(db)
        ImGui.SetCursorScreenPos(ctx, x + w + 5, mark_y - 6)
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, scale_color)
        ImGui.Text(ctx, label)
        ImGui.PopStyleColor(ctx)
      end
    end
  end

  -- Label below meter
  if opts.label and opts.label ~= "" then
    local label_color = opts.scale_text_color or Theme.COLORS.TEXT_NORMAL
    local label_w = ImGui.CalcTextSize(ctx, opts.label)
    local label_x = x + (w - label_w) / 2
    local label_y = y + h + 4

    ImGui.SetCursorScreenPos(ctx, label_x, label_y)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, label_color)
    ImGui.Text(ctx, opts.label)
    ImGui.PopStyleColor(ctx)
  end
end

-- ============================================================================
-- STATE UPDATE
-- ============================================================================

local function update_state(state, peak_db, dt)
  local now = reaper.time_precise()

  -- Update peak hold
  if peak_db > state.peak_hold_value then
    state.peak_hold_value = peak_db
    state.peak_hold_time = now
  elseif now - state.peak_hold_time > PEAK_HOLD_TIME then
    -- Decay peak hold
    state.peak_hold_value = state.peak_hold_value - (dt * 20)  -- -20 dB/s decay
  end

  -- Update clipping indicator
  if peak_db >= -0.1 then  -- Near 0 dB = clipping
    state.clipped = true
    state.clip_time = 0
  elseif state.clipped then
    state.clip_time = state.clip_time + dt
    if state.clip_time > 2.0 then
      state.clipped = false
    end
  end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Draw a VU meter widget
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result { width, height, hovered }
function M.draw(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)

  -- Resolve unique ID
  local unique_id = Base.resolve_id(ctx, opts, "vu_meter")

  -- Get or create state
  local state = Base.get_or_create_instance(instances, unique_id, create_state, ctx)

  -- Get position and draw list
  local x, y = Base.get_position(ctx, opts)
  local dl = Base.get_draw_list(ctx, opts)

  -- Get size
  local w = opts.width or 20
  local h = opts.height or 200

  -- Get values
  local peak_db = opts.peak or -100
  local rms_db = opts.rms or -100
  local min_db = opts.min_db or -60
  local max_db = opts.max_db or 0

  -- Calculate delta time for animations
  local dt = 1.0 / 60.0  -- Assume 60 fps (Base could provide frame time)

  -- Update state
  update_state(state, peak_db, dt)

  -- Create invisible button for interaction
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, "##" .. unique_id, w, h)
  local hovered = ImGui.IsItemHovered(ctx)

  -- Render meter
  if opts.orientation == "vertical" then
    render_vertical_meter(ctx, dl, x, y, w, h, peak_db, rms_db, min_db, max_db, opts, state)
  else
    -- TODO: Horizontal orientation
    error("Horizontal VU meter not yet implemented")
  end

  -- Tooltip
  if hovered then
    local tooltip_text
    if opts.tooltip then
      tooltip_text = opts.tooltip
    else
      tooltip_text = string.format("Peak: %.1f dB\nRMS: %.1f dB", peak_db, rms_db)
    end

    if ImGui.BeginTooltip(ctx) then
      ImGui.Text(ctx, tooltip_text)
      ImGui.EndTooltip(ctx)
    end
  end

  -- Calculate total dimensions (including label and scale)
  local label_height = (opts.label and opts.label ~= "") and 20 or 0
  local scale_width = opts.show_scale and 30 or 0
  local total_width = w + scale_width
  local total_height = h + label_height

  -- Advance cursor
  Base.advance_cursor(ctx, x, y, total_width, total_height, opts.advance)

  -- Return standardized result
  return Base.create_result({
    width = total_width,
    height = total_height,
    hovered = hovered,
  })
end

-- ============================================================================
-- MODULE EXPORT (Callable)
-- ============================================================================

-- Make module callable: Ark.VUMeter(ctx, ...) → M.draw(ctx, ...)
return setmetatable(M, {
  __call = function(_, ctx, ...)
    return M.draw(ctx, ...)
  end
})
