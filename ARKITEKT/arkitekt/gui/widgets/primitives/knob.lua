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
  label_uppercase = false,
  label_font = nil,
  label_font_size = 10,
  format = '%.1f',
  format_func = nil,  -- Custom format function: format_func(value) -> string
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

-- Cursor lock state for knob dragging
local drag_state = {}  -- drag_state[id] = { start_x, start_y, dragging }

-- Check if JS_Mouse API is available
local has_js_mouse = reaper.JS_Mouse_SetPosition ~= nil

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

-- Serum-style knob with dual rings (value + modulation) - clean minimal design
local function render_serum(ctx, dl, cx, cy, r, angle, t, opts, hovered, active, disabled)
  local value_color = opts.value_color or 0x44CCFFFF  -- Cyan default
  local mod_color = opts.mod_color or 0x505050FF     -- Grey for modulation arc
  local accent_color = opts.accent_color             -- Optional dot color

  -- Knob body gradient: top #464646, bottom #2F2F2F
  local body_top = 0x464646FF
  local body_bottom = 0x2F2F2FFF
  local inner_glow = 0xFFFFFF1A      -- 10% white inner glow
  local track_inner = 0x151515FF     -- Inner ring track (almost black)
  local track_outer = 0x2A2A2AFF     -- Outer ring track (dark grey)
  local pointer_color = 0xD8D8D8FF   -- White-ish pointer

  if disabled then
    value_color = Colors.WithOpacity(Colors.Desaturate(value_color, 0.7), 0.4)
    mod_color = Colors.WithOpacity(mod_color, 0.4)
    body_top = 0x363636FF
    body_bottom = 0x252525FF
    pointer_color = 0x606060FF
  elseif active then
    body_top = 0x4E4E4EFF
    body_bottom = 0x373737FF
  elseif hovered then
    body_top = 0x4A4A4AFF
    body_bottom = 0x333333FF
  end

  -- Ring dimensions - thin and clean
  local ring_thickness = 3
  local ring_gap = 1
  local outer_radius = r - ring_thickness / 2
  local inner_radius = r - ring_thickness - ring_gap - ring_thickness / 2
  local body_radius = r - ring_thickness - ring_gap - ring_thickness - ring_gap

  -- Modulation value (optional)
  local mod_value = opts.mod_value or 0
  local mod_t = (mod_value - (opts.min or 0)) / ((opts.max or 1) - (opts.min or 0))
  mod_t = math.max(0, math.min(1, mod_t))
  local mod_angle = ANGLE_MIN + (ANGLE_MAX - ANGLE_MIN) * mod_t

  -- === OUTER RING (Modulation) ===
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathArcTo(dl, cx, cy, outer_radius, ANGLE_MIN, ANGLE_MAX, 32)
  ImGui.DrawList_PathStroke(dl, track_outer, 0, ring_thickness)

  if mod_t > 0.01 and opts.mod_value then
    ImGui.DrawList_PathClear(dl)
    ImGui.DrawList_PathArcTo(dl, cx, cy, outer_radius, ANGLE_MIN, mod_angle, 32)
    ImGui.DrawList_PathStroke(dl, mod_color, 0, ring_thickness)
  end

  -- === INNER RING (Value) ===
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathArcTo(dl, cx, cy, inner_radius, ANGLE_MIN, ANGLE_MAX, 32)
  ImGui.DrawList_PathStroke(dl, track_inner, 0, ring_thickness)

  if t > 0.01 then
    ImGui.DrawList_PathClear(dl)
    ImGui.DrawList_PathArcTo(dl, cx, cy, inner_radius, ANGLE_MIN, angle, 32)
    ImGui.DrawList_PathStroke(dl, value_color, 0, ring_thickness)
  end

  -- === KNOB BODY with radial gradient (edge lighter, center darker) ===
  -- Base fill with edge color (lighter)
  ImGui.DrawList_AddCircleFilled(dl, cx, cy, body_radius, body_top, 32)

  -- Concentric circles getting darker toward center
  local steps = 8
  local top_r = (body_top >> 24) & 0xFF
  local top_g = (body_top >> 16) & 0xFF
  local top_b = (body_top >> 8) & 0xFF
  local bot_r = (body_bottom >> 24) & 0xFF
  local bot_g = (body_bottom >> 16) & 0xFF
  local bot_b = (body_bottom >> 8) & 0xFF
  for i = 1, steps do
    local t = i / steps
    local r_circle = body_radius * (1 - t * 0.7)
    local cr = math.floor(top_r + (bot_r - top_r) * t)
    local cg = math.floor(top_g + (bot_g - top_g) * t)
    local cb = math.floor(top_b + (bot_b - top_b) * t)
    local color = (cr << 24) | (cg << 16) | (cb << 8) | 0xFF
    ImGui.DrawList_AddCircleFilled(dl, cx, cy, r_circle, color, 32)
  end

  -- === INNER GLOW (10% white at edge) ===
  ImGui.DrawList_AddCircle(dl, cx, cy, body_radius - 0.5, inner_glow, 32, 1)

  -- === ACCENT DOT (optional) ===
  if accent_color then
    local dot_radius = 2
    local dot_dist = body_radius * 0.5
    ImGui.DrawList_AddCircleFilled(dl, cx, cy - dot_dist, dot_radius, accent_color, 12)
  end

  -- === POINTER LINE - reaches to edge ===
  local cos_a, sin_a = math.cos(angle), math.sin(angle)
  local line_start = 1
  local line_end = body_radius  -- Full reach to edge

  -- Half-pixel offset for centered 2px line
  local x1 = cx + cos_a * line_start - 0.5
  local y1 = cy + sin_a * line_start - 0.5
  local x2 = cx + cos_a * line_end - 0.5
  local y2 = cy + sin_a * line_end - 0.5

  ImGui.DrawList_AddLine(dl, x1, y1, x2, y2, pointer_color, 2)
end

-- Modern dark knob with colored value arc
local function render_modern(ctx, dl, cx, cy, r, angle, t, opts, hovered, active, disabled)
  local value_color = opts.value_color or Theme.COLORS.ACCENT_PRIMARY

  -- Simple dark palette
  local body_color = 0x2A2A2AFF
  local body_border = 0x3A3A3AFF
  local track_color = 0x1A1A1AFF
  local indicator_color = 0xCCCCCCFF

  if disabled then
    value_color = Colors.WithOpacity(Colors.Desaturate(value_color, 0.7), 0.4)
    body_color = 0x222222FF
    indicator_color = 0x555555FF
  elseif active then
    body_color = 0x333333FF
  elseif hovered then
    body_color = 0x303030FF
  end

  local arc_thickness = r * 0.14
  local arc_radius = r - arc_thickness / 2
  local body_radius = r - arc_thickness - 2

  -- === VALUE ARC TRACK (background) ===
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathArcTo(dl, cx, cy, arc_radius, ANGLE_MIN, ANGLE_MAX, 32)
  ImGui.DrawList_PathStroke(dl, track_color, 0, arc_thickness)

  -- === VALUE ARC (colored portion) ===
  if t > 0.01 then
    ImGui.DrawList_PathClear(dl)
    ImGui.DrawList_PathArcTo(dl, cx, cy, arc_radius, ANGLE_MIN, angle, 32)
    ImGui.DrawList_PathStroke(dl, value_color, 0, arc_thickness)
  end

  -- === KNOB BODY ===
  ImGui.DrawList_AddCircleFilled(dl, cx, cy, body_radius, body_color, 32)
  ImGui.DrawList_AddCircle(dl, cx, cy, body_radius, body_border, 32, 1)

  -- === POSITION INDICATOR LINE ===
  local cos_a, sin_a = math.cos(angle), math.sin(angle)
  local line_start = body_radius * 0.25
  local line_end = body_radius * 0.75

  ImGui.DrawList_AddLine(dl,
    cx + cos_a * line_start, cy + sin_a * line_start,
    cx + cos_a * line_end, cy + sin_a * line_end,
    indicator_color, 2)
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

  -- Modern/Serum variants handle all their own rendering
  if variant == 'modern' then
    render_modern(ctx, dl, cx, cy, r, angle, t, opts, hovered, active, disabled)
    return
  elseif variant == 'serum' then
    render_serum(ctx, dl, cx, cy, r, angle, t, opts, hovered, active, disabled)
    return
  end

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
    local value_text
    if opts.format_func then
      value_text = opts.format_func(value)
    else
      value_text = string.format(opts.format, value)
    end
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
  local display_label = opts.label_uppercase and string.upper(label) or label

  -- Push font if provided
  if opts.label_font then
    ImGui.PushFont(ctx, opts.label_font, opts.label_font_size or 10)
  end

  local label_w = ImGui.CalcTextSize(ctx, display_label)
  ImGui.SetCursorScreenPos(ctx, x + (size - label_w) / 2, y + size + 4)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, label_color)
  ImGui.Text(ctx, display_label)
  ImGui.PopStyleColor(ctx)

  if opts.label_font then
    ImGui.PopFont(ctx)
  end

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
  local actx = Base.get_context(ctx)
  local disabled = opts.is_disabled or actx:is_disabled()
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

    -- Cursor hide: store start position when drag begins, hide cursor
    if has_js_mouse and not drag_state[unique_id] then
      local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
      drag_state[unique_id] = { start_x = mouse_x, start_y = mouse_y }
    end

    -- Hide cursor during drag
    ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_None)

    if drag_y ~= 0 then
      -- Ctrl/Shift for fine-tuning (10x more precise)
      local mods = ImGui.GetKeyMods(ctx)
      local fine_tune = (mods & ImGui.Mod_Ctrl) ~= 0 or (mods & ImGui.Mod_Shift) ~= 0
      local sensitivity = fine_tune and (opts.sensitivity * 0.1) or opts.sensitivity
      local delta = -drag_y * sensitivity
      local new_value = Base.clamp(current_value + delta * (max_val - min_val), min_val, max_val)
      if math.abs(new_value - current_value) > 1e-6 then
        current_value = new_value
        changed = true
      end
      ImGui.ResetMouseDragDelta(ctx, 0)
    end
  else
    -- Drag ended: restore cursor position and clear state
    if drag_state[unique_id] then
      local ds = drag_state[unique_id]
      if has_js_mouse then
        reaper.JS_Mouse_SetPosition(math.floor(ds.start_x), math.floor(ds.start_y))
      end
      drag_state[unique_id] = nil
    end
  end

  render_knob(ctx, dl, x, y, size, r, current_value, min_val, max_val, opts, hovered, active)
  local label_height = render_label(ctx, x, y, size, opts.label, opts)

  if hovered or active then
    local tooltip_text = opts.tooltip
    if not tooltip_text then
      if opts.format_func then
        tooltip_text = opts.format_func(current_value)
      else
        tooltip_text = string.format(opts.format, current_value)
      end
    end
    -- Lock tooltip position near knob during drag (cursor is hidden/moving)
    if active and drag_state[unique_id] then
      local tooltip_x = x + size + 8
      local tooltip_y = y + size / 2 - 10
      ImGui.SetNextWindowPos(ctx, tooltip_x, tooltip_y)
    end
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
