-- @noindex
-- arkitekt/gui/widgets/primitives/knob.lua
-- Circular knob widget (rotary control) with ARKITEKT styling

local ImGui = require('arkitekt.core.imgui')
local Theme = require('arkitekt.theme')
local Colors = require('arkitekt.core.colors')
local Base = require('arkitekt.gui.widgets.base')

local M = {}

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local PI = math.pi
local ANGLE_MIN = PI * 0.75
local ANGLE_MAX = PI * 2.25

-- ============================================================================
-- DEFAULTS
-- ============================================================================

local DEFAULTS = {
  id = nil,
  label = '',
  x = nil,
  y = nil,
  size = 40,
  radius = nil,
  value = 0,
  min = 0,
  max = 100,
  default = nil,
  sensitivity = 0.005,
  is_disabled = false,
  variant = 'tick',
  steps = 10,
  bg_color = nil,
  bg_hover_color = nil,
  bg_active_color = nil,
  line_color = nil,
  track_color = nil,
  value_color = nil,
  inner_color = nil,
  inner_hover_color = nil,
  inner_active_color = nil,
  border_color = nil,
  border_hover_color = nil,
  text_color = nil,
  label_color = nil,
  format = '%.1f',
  show_value = true,
  show_label = true,
  on_change = nil,
  tooltip = nil,
  advance = 'vertical',
  draw_list = nil,
}

-- ============================================================================
-- STATE MANAGEMENT
-- ============================================================================

local knob_locks = {}

-- ============================================================================
-- VARIANT RENDERING
-- ============================================================================

local function render_tick(ctx, dl, cx, cy, r, angle, opts, hovered, active, disabled)
  local line_color = opts.line_color or Theme.COLORS.ACCENT_PRIMARY
  local inner_color = opts.inner_color or Theme.COLORS.BG_HOVER

  if disabled then
    line_color = Colors.WithOpacity(Colors.Desaturate(line_color, 0.5), 0.5)
    inner_color = Colors.WithOpacity(Colors.Desaturate(inner_color, 0.5), 0.5)
  elseif active then
    inner_color = opts.inner_active_color or Colors.AdjustBrightness(inner_color, 0.9)
  elseif hovered then
    inner_color = opts.inner_hover_color or Colors.AdjustBrightness(inner_color, 1.1)
  end

  local cos_a, sin_a = math.cos(angle), math.sin(angle)
  local r_inner = r * 0.4
  ImGui.DrawList_AddLine(dl, cx + cos_a * r_inner, cy + sin_a * r_inner,
                         cx + cos_a * (r - 2), cy + sin_a * (r - 2), line_color, 2.0)
  ImGui.DrawList_AddCircleFilled(dl, cx, cy, r_inner, inner_color, 16)
end

local function render_dot(ctx, dl, cx, cy, r, angle, opts, hovered, active, disabled)
  local dot_color = opts.line_color or Theme.COLORS.ACCENT_PRIMARY
  local inner_color = opts.inner_color or Theme.COLORS.BG_HOVER

  if disabled then
    dot_color = Colors.WithOpacity(Colors.Desaturate(dot_color, 0.5), 0.5)
    inner_color = Colors.WithOpacity(Colors.Desaturate(inner_color, 0.5), 0.5)
  elseif active then
    inner_color = opts.inner_active_color or Colors.AdjustBrightness(inner_color, 0.9)
  elseif hovered then
    inner_color = opts.inner_hover_color or Colors.AdjustBrightness(inner_color, 1.1)
  end

  local cos_a, sin_a = math.cos(angle), math.sin(angle)
  local r_inner = r * 0.4
  local dot_r = r * 0.1
  local dot_dist = r - dot_r - 2
  ImGui.DrawList_AddCircleFilled(dl, cx, cy, r_inner, inner_color, 16)
  ImGui.DrawList_AddCircleFilled(dl, cx + cos_a * dot_dist, cy + sin_a * dot_dist, dot_r, dot_color, 12)
end

local function render_wiper(ctx, dl, cx, cy, r, angle, t, opts, hovered, active, disabled)
  local track_color = opts.track_color or Colors.WithOpacity(Theme.COLORS.BG_BASE, 0.3)
  local value_color = opts.value_color or Theme.COLORS.ACCENT_PRIMARY
  local inner_color = opts.inner_color or Theme.COLORS.BG_HOVER

  if disabled then
    track_color = Colors.WithOpacity(Colors.Desaturate(track_color, 0.5), 0.5)
    value_color = Colors.WithOpacity(Colors.Desaturate(value_color, 0.5), 0.5)
    inner_color = Colors.WithOpacity(Colors.Desaturate(inner_color, 0.5), 0.5)
  elseif active then
    inner_color = opts.inner_active_color or Colors.AdjustBrightness(inner_color, 0.9)
  elseif hovered then
    inner_color = opts.inner_hover_color or Colors.AdjustBrightness(inner_color, 1.1)
  end

  local thickness = r * 0.15
  local r_inner = r * 0.4

  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathArcTo(dl, cx, cy, r - thickness/2, ANGLE_MIN, ANGLE_MAX, 32)
  ImGui.DrawList_PathStroke(dl, track_color, 0, thickness)

  if t > 0.01 then
    ImGui.DrawList_PathClear(dl)
    ImGui.DrawList_PathArcTo(dl, cx, cy, r - thickness/2, ANGLE_MIN, angle, 32)
    ImGui.DrawList_PathStroke(dl, value_color, 0, thickness)
  end

  ImGui.DrawList_AddCircleFilled(dl, cx, cy, r_inner, inner_color, 16)
end

local function render_wiper_only(ctx, dl, cx, cy, r, angle, t, opts, disabled)
  local track_color = opts.track_color or Colors.WithOpacity(Theme.COLORS.BG_BASE, 0.3)
  local value_color = opts.value_color or Theme.COLORS.ACCENT_PRIMARY

  if disabled then
    track_color = Colors.WithOpacity(Colors.Desaturate(track_color, 0.5), 0.5)
    value_color = Colors.WithOpacity(Colors.Desaturate(value_color, 0.5), 0.5)
  end

  local thickness = r * 0.2

  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathArcTo(dl, cx, cy, r - thickness/2, ANGLE_MIN, ANGLE_MAX, 32)
  ImGui.DrawList_PathStroke(dl, track_color, 0, thickness)

  if t > 0.01 then
    ImGui.DrawList_PathClear(dl)
    ImGui.DrawList_PathArcTo(dl, cx, cy, r - thickness/2, ANGLE_MIN, angle, 32)
    ImGui.DrawList_PathStroke(dl, value_color, 0, thickness)
  end
end

local function render_wiper_dot(ctx, dl, cx, cy, r, angle, t, opts, hovered, active, disabled)
  local track_color = opts.track_color or Colors.WithOpacity(Theme.COLORS.BG_BASE, 0.3)
  local value_color = opts.value_color or Theme.COLORS.ACCENT_PRIMARY
  local dot_color = opts.line_color or Theme.COLORS.ACCENT_PRIMARY
  local inner_color = opts.inner_color or Theme.COLORS.BG_HOVER

  if disabled then
    track_color = Colors.WithOpacity(Colors.Desaturate(track_color, 0.5), 0.5)
    value_color = Colors.WithOpacity(Colors.Desaturate(value_color, 0.5), 0.5)
    dot_color = Colors.WithOpacity(Colors.Desaturate(dot_color, 0.5), 0.5)
    inner_color = Colors.WithOpacity(Colors.Desaturate(inner_color, 0.5), 0.5)
  elseif active then
    inner_color = opts.inner_active_color or Colors.AdjustBrightness(inner_color, 0.9)
  elseif hovered then
    inner_color = opts.inner_hover_color or Colors.AdjustBrightness(inner_color, 1.1)
  end

  local thickness = r * 0.12
  local r_inner = r * 0.35

  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathArcTo(dl, cx, cy, r - thickness/2, ANGLE_MIN, ANGLE_MAX, 32)
  ImGui.DrawList_PathStroke(dl, track_color, 0, thickness)

  if t > 0.01 then
    ImGui.DrawList_PathClear(dl)
    ImGui.DrawList_PathArcTo(dl, cx, cy, r - thickness/2, ANGLE_MIN, angle, 32)
    ImGui.DrawList_PathStroke(dl, value_color, 0, thickness)
  end

  ImGui.DrawList_AddCircleFilled(dl, cx, cy, r_inner, inner_color, 16)

  local cos_a, sin_a = math.cos(angle), math.sin(angle)
  local dot_r = r * 0.08
  local dot_dist = r - thickness - dot_r - 2
  ImGui.DrawList_AddCircleFilled(dl, cx + cos_a * dot_dist, cy + sin_a * dot_dist, dot_r, dot_color, 12)
end

local function render_stepped(ctx, dl, cx, cy, r, angle, t, opts, hovered, active, disabled)
  local tick_color = opts.track_color or Colors.WithOpacity(Theme.COLORS.TEXT_NORMAL, 0.3)
  local active_tick = opts.value_color or Theme.COLORS.ACCENT_PRIMARY
  local dot_color = opts.line_color or Theme.COLORS.ACCENT_PRIMARY
  local inner_color = opts.inner_color or Theme.COLORS.BG_HOVER

  if disabled then
    tick_color = Colors.WithOpacity(Colors.Desaturate(tick_color, 0.5), 0.5)
    active_tick = Colors.WithOpacity(Colors.Desaturate(active_tick, 0.5), 0.5)
    dot_color = Colors.WithOpacity(Colors.Desaturate(dot_color, 0.5), 0.5)
    inner_color = Colors.WithOpacity(Colors.Desaturate(inner_color, 0.5), 0.5)
  elseif active then
    inner_color = opts.inner_active_color or Colors.AdjustBrightness(inner_color, 0.9)
  elseif hovered then
    inner_color = opts.inner_hover_color or Colors.AdjustBrightness(inner_color, 1.1)
  end

  local steps = opts.steps or 10
  local r_inner = r * 0.35

  for i = 0, steps do
    local step_t = i / steps
    local step_angle = ANGLE_MIN + (ANGLE_MAX - ANGLE_MIN) * step_t
    local cos_s, sin_s = math.cos(step_angle), math.sin(step_angle)
    local tick_len = r * 0.15
    local tick_start = r - tick_len - 2
    local color = step_t <= t and active_tick or tick_color
    ImGui.DrawList_AddLine(dl, cx + cos_s * tick_start, cy + sin_s * tick_start,
                           cx + cos_s * (r - 2), cy + sin_s * (r - 2), color, 2)
  end

  ImGui.DrawList_AddCircleFilled(dl, cx, cy, r_inner, inner_color, 16)

  local cos_a, sin_a = math.cos(angle), math.sin(angle)
  local dot_r = r * 0.08
  ImGui.DrawList_AddCircleFilled(dl, cx + cos_a * r_inner, cy + sin_a * r_inner, dot_r, dot_color, 12)
end

local function render_space(ctx, dl, cx, cy, r, angle, t, opts, hovered, active, disabled)
  local arc_color = opts.line_color or Theme.COLORS.ACCENT_PRIMARY
  local inner_color = opts.inner_color or Theme.COLORS.BG_HOVER

  if disabled then
    arc_color = Colors.WithOpacity(Colors.Desaturate(arc_color, 0.5), 0.5)
    inner_color = Colors.WithOpacity(Colors.Desaturate(inner_color, 0.5), 0.5)
  elseif active then
    inner_color = opts.inner_active_color or Colors.AdjustBrightness(inner_color, 0.9)
    arc_color = Colors.AdjustBrightness(arc_color, 1.2)
  elseif hovered then
    inner_color = opts.inner_hover_color or Colors.AdjustBrightness(inner_color, 1.1)
    arc_color = Colors.AdjustBrightness(arc_color, 1.1)
  end

  local r_inner = r * (0.2 + t * 0.15)
  ImGui.DrawList_AddCircleFilled(dl, cx, cy, r_inner, inner_color, 16)

  for i = 1, 3 do
    local arc_r = r * (0.5 + i * 0.15)
    local arc_len = (PI * 0.3) + (t * PI * 0.4)
    local arc_off = angle - arc_len / 2 + (i * PI * 0.2)
    local opacity = 0.3 + (t * 0.4) + (i * 0.1)
    local color = Colors.WithOpacity(arc_color, opacity)
    ImGui.DrawList_PathClear(dl)
    ImGui.DrawList_PathArcTo(dl, cx, cy, arc_r, arc_off, arc_off + arc_len, 24)
    ImGui.DrawList_PathStroke(dl, color, 0, 2)
  end
end

-- ============================================================================
-- MAIN RENDERING
-- ============================================================================

local function render_knob(ctx, dl, x, y, size, r, value, min_val, max_val, opts, hovered, active)
  local cx, cy = x + size / 2, y + size / 2
  local disabled = opts.is_disabled
  local t = (value - min_val) / (max_val - min_val)
  local angle = ANGLE_MIN + (ANGLE_MAX - ANGLE_MIN) * t

  local bg_color = opts.bg_color or Theme.COLORS.BG_BASE
  local border_color = opts.border_color or Theme.COLORS.BORDER_INNER

  if disabled then
    bg_color = Colors.WithOpacity(Colors.Desaturate(bg_color, 0.5), 0.5)
    border_color = Colors.WithOpacity(Colors.Desaturate(border_color, 0.5), 0.5)
  elseif active then
    bg_color = opts.bg_active_color or Colors.AdjustBrightness(bg_color, 0.9)
  elseif hovered then
    bg_color = opts.bg_hover_color or Colors.AdjustBrightness(bg_color, 1.1)
    border_color = opts.border_hover_color or Theme.COLORS.BORDER_HOVER
  end

  local variant = opts.variant or 'tick'
  if variant ~= 'wiper_only' then
    ImGui.DrawList_AddCircleFilled(dl, cx, cy, r, bg_color, 32)
  end

  if variant == 'tick' then
    render_tick(ctx, dl, cx, cy, r, angle, opts, hovered, active, disabled)
  elseif variant == 'dot' then
    render_dot(ctx, dl, cx, cy, r, angle, opts, hovered, active, disabled)
  elseif variant == 'wiper' then
    render_wiper(ctx, dl, cx, cy, r, angle, t, opts, hovered, active, disabled)
  elseif variant == 'wiper_only' then
    render_wiper_only(ctx, dl, cx, cy, r, angle, t, opts, disabled)
  elseif variant == 'wiper_dot' then
    render_wiper_dot(ctx, dl, cx, cy, r, angle, t, opts, hovered, active, disabled)
  elseif variant == 'stepped' then
    render_stepped(ctx, dl, cx, cy, r, angle, t, opts, hovered, active, disabled)
  elseif variant == 'space' then
    render_space(ctx, dl, cx, cy, r, angle, t, opts, hovered, active, disabled)
  else
    render_tick(ctx, dl, cx, cy, r, angle, opts, hovered, active, disabled)
  end

  if variant ~= 'wiper_only' and variant ~= 'space' then
    ImGui.DrawList_AddCircle(dl, cx, cy, r, border_color, 32, 1)
  end

  if opts.show_value and not disabled then
    local text_color = opts.text_color or Theme.COLORS.TEXT_NORMAL
    local value_text = string.format(opts.format, value)
    local text_w = ImGui.CalcTextSize(ctx, value_text)
    local text_h = ImGui.GetTextLineHeight(ctx)
    ImGui.SetCursorScreenPos(ctx, cx - text_w / 2, cy - text_h / 2)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, text_color)
    ImGui.Text(ctx, value_text)
    ImGui.PopStyleColor(ctx)
  end
end

local function render_label(ctx, x, y, size, label, opts)
  if not opts.show_label or not label or label == '' then return 0 end

  local label_color = opts.label_color or Theme.COLORS.TEXT_NORMAL
  local label_w = ImGui.CalcTextSize(ctx, label)
  ImGui.SetCursorScreenPos(ctx, x + (size - label_w) / 2, y + size + 4)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, label_color)
  ImGui.Text(ctx, label)
  ImGui.PopStyleColor(ctx)
  return ImGui.GetTextLineHeight(ctx) + 4
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function M.Draw(ctx, label_or_opts, value, min, max)
  local opts
  if type(label_or_opts) == 'table' then
    opts = label_or_opts
  elseif type(label_or_opts) == 'string' then
    opts = { label = label_or_opts, value = value, min = min, max = max }
  else
    opts = {}
  end

  opts = Base.parse_opts(opts, DEFAULTS)
  local unique_id = Base.resolve_id(ctx, opts, 'knob')
  local x, y = Base.get_position(ctx, opts)
  local dl = Base.get_draw_list(ctx, opts)

  local size = opts.size or 40
  local r = opts.radius or (size / 2 - 2)
  local min_val = opts.min or 0
  local max_val = opts.max or 100
  local default_val = opts.default or min_val
  local current_value = Base.clamp(opts.value or default_val, min_val, max_val)
  local disabled = opts.is_disabled or false
  local changed = false

  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, '##' .. unique_id, size, size)

  local hovered = not disabled and ImGui.IsItemHovered(ctx)
  local active = not disabled and ImGui.IsItemActive(ctx)

  local now = ImGui.GetTime(ctx)
  local locked = (knob_locks[unique_id] or 0) > now

  if hovered and not locked and ImGui.IsMouseDoubleClicked(ctx, 0) then
    current_value = default_val
    changed = true
    knob_locks[unique_id] = now + 0.3
  end

  if not locked and active and not ImGui.IsMouseDoubleClicked(ctx, 0) then
    local _, drag_y = ImGui.GetMouseDragDelta(ctx, 0)
    if drag_y ~= 0 then
      local delta = -drag_y * opts.sensitivity
      local new_value = Base.clamp(current_value + delta * (max_val - min_val), min_val, max_val)
      if math.abs(new_value - current_value) > 1e-6 then
        current_value = new_value
        changed = true
      end
      ImGui.ResetMouseDragDelta(ctx, 0)
    end
  end

  render_knob(ctx, dl, x, y, size, r, current_value, min_val, max_val, opts, hovered, active)
  local label_height = render_label(ctx, x, y, size, opts.label, opts)

  if hovered or active then
    local tooltip_text = opts.tooltip or string.format(opts.format, current_value)
    if ImGui.BeginTooltip(ctx) then
      ImGui.Text(ctx, tooltip_text)
      ImGui.EndTooltip(ctx)
    end
  end

  if changed and opts.on_change then
    opts.on_change(current_value)
  end

  local total_height = size + label_height
  Base.advance_cursor(ctx, x, y, size, total_height, opts.advance)

  return Base.create_result({
    changed = changed,
    value = current_value,
    width = size,
    height = total_height,
    hovered = hovered,
    active = active,
  })
end

-- ============================================================================
-- MODULE EXPORT
-- ============================================================================

return setmetatable(M, {
  __call = function(_, ctx, ...)
    return M.Draw(ctx, ...)
  end
})
