-- @noindex
-- arkitekt/gui/widgets/primitives/knob.lua
-- Circular knob widget (rotary control) with ARKITEKT styling
-- Based on cfillion's ReaImGui example: https://github.com/ocornut/imgui/issues/942#issuecomment-268369298

local ImGui = require('arkitekt.platform.imgui')
local Theme = require('arkitekt.core.theme')
local Colors = require('arkitekt.core.colors')
local Base = require('arkitekt.gui.widgets.base')

local M = {}

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local PI = math.pi
local ANGLE_MIN = PI * 0.75    -- 135 degrees (bottom-left)
local ANGLE_MAX = PI * 2.25    -- 225 degrees (bottom-right)

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
  size = 40,           -- Diameter of knob
  radius = nil,        -- Override calculated radius (size/2)

  -- Value
  value = 0,
  min = 0,
  max = 100,
  default = nil,       -- Value to reset to on double-click (defaults to min)
  sensitivity = 0.005, -- Drag sensitivity (pixels to value ratio)

  -- State
  disabled = false,

  -- Style
  variant = "tick",    -- Visual style: "tick", "dot", "wiper", "wiper_only", "wiper_dot", "stepped", "space"
  steps = 10,          -- Number of steps for "stepped" variant
  bg_color = nil,
  bg_hover_color = nil,
  bg_active_color = nil,
  line_color = nil,
  track_color = nil,   -- Arc track color (for wiper variants)
  value_color = nil,   -- Arc value/fill color (for wiper variants)
  inner_color = nil,
  inner_hover_color = nil,
  inner_active_color = nil,
  border_color = nil,
  border_hover_color = nil,
  text_color = nil,
  label_color = nil,

  -- Display
  format = "%.1f",     -- Value format string
  show_value = true,   -- Show value text in center
  show_label = true,   -- Show label below knob

  -- Callbacks
  on_change = nil,
  tooltip = nil,

  -- Cursor control
  advance = "vertical",

  -- Draw list
  draw_list = nil,
}

-- ============================================================================
-- STATE MANAGEMENT
-- ============================================================================

local knob_locks = {}  -- Prevents double-click interference with drag

-- ============================================================================
-- VARIANT RENDERING FUNCTIONS
-- ============================================================================

--- Render tick variant (line indicator from center)
local function render_tick(ctx, dl, center_x, center_y, radius, angle, opts, hovered, active, disabled)
  local line_color = opts.line_color or Theme.COLORS.ACCENT_PRIMARY
  local inner_color = opts.inner_color or Theme.COLORS.BG_HOVER

  if disabled then
    line_color = Colors.with_opacity(Colors.desaturate(line_color, 0.5), 0.5)
    inner_color = Colors.with_opacity(Colors.desaturate(inner_color, 0.5), 0.5)
  elseif active then
    inner_color = opts.inner_active_color or Colors.adjust_brightness(inner_color, 0.9)
  elseif hovered then
    inner_color = opts.inner_hover_color or Colors.adjust_brightness(inner_color, 1.1)
  end

  local angle_cos, angle_sin = math.cos(angle), math.sin(angle)
  local radius_inner = radius * 0.4
  local line_start_x = center_x + angle_cos * radius_inner
  local line_start_y = center_y + angle_sin * radius_inner
  local line_end_x = center_x + angle_cos * (radius - 2)
  local line_end_y = center_y + angle_sin * (radius - 2)

  ImGui.DrawList_AddLine(dl, line_start_x, line_start_y, line_end_x, line_end_y, line_color, 2.0)
  ImGui.DrawList_AddCircleFilled(dl, center_x, center_y, radius_inner, inner_color, 16)
end

--- Render dot variant (indicator dot on perimeter)
local function render_dot(ctx, dl, center_x, center_y, radius, angle, opts, hovered, active, disabled)
  local dot_color = opts.line_color or Theme.COLORS.ACCENT_PRIMARY
  local inner_color = opts.inner_color or Theme.COLORS.BG_HOVER

  if disabled then
    dot_color = Colors.with_opacity(Colors.desaturate(dot_color, 0.5), 0.5)
    inner_color = Colors.with_opacity(Colors.desaturate(inner_color, 0.5), 0.5)
  elseif active then
    inner_color = opts.inner_active_color or Colors.adjust_brightness(inner_color, 0.9)
  elseif hovered then
    inner_color = opts.inner_hover_color or Colors.adjust_brightness(inner_color, 1.1)
  end

  local angle_cos, angle_sin = math.cos(angle), math.sin(angle)
  local radius_inner = radius * 0.4
  local dot_radius = radius * 0.1
  local dot_distance = radius - dot_radius - 2
  local dot_x = center_x + angle_cos * dot_distance
  local dot_y = center_y + angle_sin * dot_distance

  ImGui.DrawList_AddCircleFilled(dl, center_x, center_y, radius_inner, inner_color, 16)
  ImGui.DrawList_AddCircleFilled(dl, dot_x, dot_y, dot_radius, dot_color, 12)
end

--- Render wiper variant (arc fill from min to current value)
local function render_wiper(ctx, dl, center_x, center_y, radius, angle, t, opts, hovered, active, disabled)
  local track_color = opts.track_color or Colors.with_opacity(Theme.COLORS.BG_BASE, 0.3)
  local value_color = opts.value_color or Theme.COLORS.ACCENT_PRIMARY
  local inner_color = opts.inner_color or Theme.COLORS.BG_HOVER

  if disabled then
    track_color = Colors.with_opacity(Colors.desaturate(track_color, 0.5), 0.5)
    value_color = Colors.with_opacity(Colors.desaturate(value_color, 0.5), 0.5)
    inner_color = Colors.with_opacity(Colors.desaturate(inner_color, 0.5), 0.5)
  elseif active then
    inner_color = opts.inner_active_color or Colors.adjust_brightness(inner_color, 0.9)
  elseif hovered then
    inner_color = opts.inner_hover_color or Colors.adjust_brightness(inner_color, 1.1)
  end

  local value_thickness = radius * 0.15
  local radius_inner = radius * 0.4

  -- Track (full arc)
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathArcTo(dl, center_x, center_y, radius - value_thickness/2, ANGLE_MIN, ANGLE_MAX, 32)
  ImGui.DrawList_PathStroke(dl, track_color, 0, value_thickness)

  -- Value arc (from min to current)
  if t > 0.01 then
    ImGui.DrawList_PathClear(dl)
    ImGui.DrawList_PathArcTo(dl, center_x, center_y, radius - value_thickness/2, ANGLE_MIN, angle, 32)
    ImGui.DrawList_PathStroke(dl, value_color, 0, value_thickness)
  end

  ImGui.DrawList_AddCircleFilled(dl, center_x, center_y, radius_inner, inner_color, 16)
end

--- Render wiper_only variant (just the arc, no background circle)
local function render_wiper_only(ctx, dl, center_x, center_y, radius, angle, t, opts, hovered, active, disabled)
  local track_color = opts.track_color or Colors.with_opacity(Theme.COLORS.BG_BASE, 0.3)
  local value_color = opts.value_color or Theme.COLORS.ACCENT_PRIMARY

  if disabled then
    track_color = Colors.with_opacity(Colors.desaturate(track_color, 0.5), 0.5)
    value_color = Colors.with_opacity(Colors.desaturate(value_color, 0.5), 0.5)
  end

  local value_thickness = radius * 0.2

  -- Track (full arc)
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathArcTo(dl, center_x, center_y, radius - value_thickness/2, ANGLE_MIN, ANGLE_MAX, 32)
  ImGui.DrawList_PathStroke(dl, track_color, 0, value_thickness)

  -- Value arc (from min to current)
  if t > 0.01 then
    ImGui.DrawList_PathClear(dl)
    ImGui.DrawList_PathArcTo(dl, center_x, center_y, radius - value_thickness/2, ANGLE_MIN, angle, 32)
    ImGui.DrawList_PathStroke(dl, value_color, 0, value_thickness)
  end
end

--- Render wiper_dot variant (arc fill + dot indicator)
local function render_wiper_dot(ctx, dl, center_x, center_y, radius, angle, t, opts, hovered, active, disabled)
  local track_color = opts.track_color or Colors.with_opacity(Theme.COLORS.BG_BASE, 0.3)
  local value_color = opts.value_color or Theme.COLORS.ACCENT_PRIMARY
  local dot_color = opts.line_color or Theme.COLORS.ACCENT_PRIMARY
  local inner_color = opts.inner_color or Theme.COLORS.BG_HOVER

  if disabled then
    track_color = Colors.with_opacity(Colors.desaturate(track_color, 0.5), 0.5)
    value_color = Colors.with_opacity(Colors.desaturate(value_color, 0.5), 0.5)
    dot_color = Colors.with_opacity(Colors.desaturate(dot_color, 0.5), 0.5)
    inner_color = Colors.with_opacity(Colors.desaturate(inner_color, 0.5), 0.5)
  elseif active then
    inner_color = opts.inner_active_color or Colors.adjust_brightness(inner_color, 0.9)
  elseif hovered then
    inner_color = opts.inner_hover_color or Colors.adjust_brightness(inner_color, 1.1)
  end

  local value_thickness = radius * 0.12
  local radius_inner = radius * 0.35

  -- Track (full arc)
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathArcTo(dl, center_x, center_y, radius - value_thickness/2, ANGLE_MIN, ANGLE_MAX, 32)
  ImGui.DrawList_PathStroke(dl, track_color, 0, value_thickness)

  -- Value arc (from min to current)
  if t > 0.01 then
    ImGui.DrawList_PathClear(dl)
    ImGui.DrawList_PathArcTo(dl, center_x, center_y, radius - value_thickness/2, ANGLE_MIN, angle, 32)
    ImGui.DrawList_PathStroke(dl, value_color, 0, value_thickness)
  end

  -- Center circle
  ImGui.DrawList_AddCircleFilled(dl, center_x, center_y, radius_inner, inner_color, 16)

  -- Dot indicator
  local angle_cos, angle_sin = math.cos(angle), math.sin(angle)
  local dot_radius = radius * 0.08
  local dot_distance = radius - value_thickness - dot_radius - 2
  local dot_x = center_x + angle_cos * dot_distance
  local dot_y = center_y + angle_sin * dot_distance
  ImGui.DrawList_AddCircleFilled(dl, dot_x, dot_y, dot_radius, dot_color, 12)
end

--- Render stepped variant (discrete tick marks around perimeter)
local function render_stepped(ctx, dl, center_x, center_y, radius, angle, t, opts, hovered, active, disabled)
  local tick_color = opts.track_color or Colors.with_opacity(Theme.COLORS.TEXT_NORMAL, 0.3)
  local active_tick_color = opts.value_color or Theme.COLORS.ACCENT_PRIMARY
  local dot_color = opts.line_color or Theme.COLORS.ACCENT_PRIMARY
  local inner_color = opts.inner_color or Theme.COLORS.BG_HOVER

  if disabled then
    tick_color = Colors.with_opacity(Colors.desaturate(tick_color, 0.5), 0.5)
    active_tick_color = Colors.with_opacity(Colors.desaturate(active_tick_color, 0.5), 0.5)
    dot_color = Colors.with_opacity(Colors.desaturate(dot_color, 0.5), 0.5)
    inner_color = Colors.with_opacity(Colors.desaturate(inner_color, 0.5), 0.5)
  elseif active then
    inner_color = opts.inner_active_color or Colors.adjust_brightness(inner_color, 0.9)
  elseif hovered then
    inner_color = opts.inner_hover_color or Colors.adjust_brightness(inner_color, 1.1)
  end

  local steps = opts.steps or 10
  local radius_inner = radius * 0.35

  -- Draw tick marks
  for i = 0, steps do
    local step_t = i / steps
    local step_angle = ANGLE_MIN + (ANGLE_MAX - ANGLE_MIN) * step_t
    local step_cos, step_sin = math.cos(step_angle), math.sin(step_angle)

    local is_active = step_t <= t
    local tick_length = radius * 0.15
    local tick_start = radius - tick_length - 2
    local tick_end = radius - 2

    local x1 = center_x + step_cos * tick_start
    local y1 = center_y + step_sin * tick_start
    local x2 = center_x + step_cos * tick_end
    local y2 = center_y + step_sin * tick_end

    local color = is_active and active_tick_color or tick_color
    ImGui.DrawList_AddLine(dl, x1, y1, x2, y2, color, 2)
  end

  -- Center circle
  ImGui.DrawList_AddCircleFilled(dl, center_x, center_y, radius_inner, inner_color, 16)

  -- Dot indicator
  local angle_cos, angle_sin = math.cos(angle), math.sin(angle)
  local dot_radius = radius * 0.08
  local dot_distance = radius_inner
  local dot_x = center_x + angle_cos * dot_distance
  local dot_y = center_y + angle_sin * dot_distance
  ImGui.DrawList_AddCircleFilled(dl, dot_x, dot_y, dot_radius, dot_color, 12)
end

--- Render space variant (futuristic concentric arcs)
local function render_space(ctx, dl, center_x, center_y, radius, angle, t, opts, hovered, active, disabled)
  local arc_color = opts.line_color or Theme.COLORS.ACCENT_PRIMARY
  local inner_color = opts.inner_color or Theme.COLORS.BG_HOVER

  if disabled then
    arc_color = Colors.with_opacity(Colors.desaturate(arc_color, 0.5), 0.5)
    inner_color = Colors.with_opacity(Colors.desaturate(inner_color, 0.5), 0.5)
  elseif active then
    inner_color = opts.inner_active_color or Colors.adjust_brightness(inner_color, 0.9)
    arc_color = Colors.adjust_brightness(arc_color, 1.2)
  elseif hovered then
    inner_color = opts.inner_hover_color or Colors.adjust_brightness(inner_color, 1.1)
    arc_color = Colors.adjust_brightness(arc_color, 1.1)
  end

  -- Center circle (shrinks based on value)
  local radius_inner = radius * (0.2 + t * 0.15)
  ImGui.DrawList_AddCircleFilled(dl, center_x, center_y, radius_inner, inner_color, 16)

  -- Concentric arcs with angular offset
  local num_arcs = 3
  for i = 1, num_arcs do
    local arc_radius = radius * (0.5 + i * 0.15)
    local arc_thickness = 2
    local arc_length = (PI * 0.3) + (t * PI * 0.4)
    local arc_offset = angle - arc_length / 2 + (i * PI * 0.2)

    local opacity = 0.3 + (t * 0.4) + (i * 0.1)
    local color = Colors.with_opacity(arc_color, opacity)

    ImGui.DrawList_PathClear(dl)
    ImGui.DrawList_PathArcTo(dl, center_x, center_y, arc_radius, arc_offset, arc_offset + arc_length, 24)
    ImGui.DrawList_PathStroke(dl, color, 0, arc_thickness)
  end
end

-- ============================================================================
-- RENDERING
-- ============================================================================

local function render_knob(ctx, dl, x, y, size, radius, value, min_val, max_val, opts, hovered, active)
  local center_x = x + size / 2
  local center_y = y + size / 2
  local disabled = opts.disabled

  -- Calculate angle and normalized value based on value
  local t = (value - min_val) / (max_val - min_val)
  local angle = ANGLE_MIN + (ANGLE_MAX - ANGLE_MIN) * t

  -- Colors for background and border
  local bg_color = opts.bg_color or Theme.COLORS.BG_BASE
  local border_color = opts.border_color or Theme.COLORS.BORDER_INNER

  if disabled then
    bg_color = Colors.with_opacity(Colors.desaturate(bg_color, 0.5), 0.5)
    border_color = Colors.with_opacity(Colors.desaturate(border_color, 0.5), 0.5)
  elseif active then
    bg_color = opts.bg_active_color or Colors.adjust_brightness(bg_color, 0.9)
  elseif hovered then
    bg_color = opts.bg_hover_color or Colors.adjust_brightness(bg_color, 1.1)
    border_color = opts.border_hover_color or Theme.COLORS.BORDER_HOVER
  end

  -- Outer circle (background) - not drawn for wiper_only variant
  local variant = opts.variant or "tick"
  if variant ~= "wiper_only" then
    ImGui.DrawList_AddCircleFilled(dl, center_x, center_y, radius, bg_color, 32)
  end

  -- Dispatch to variant-specific renderer
  if variant == "tick" then
    render_tick(ctx, dl, center_x, center_y, radius, angle, opts, hovered, active, disabled)
  elseif variant == "dot" then
    render_dot(ctx, dl, center_x, center_y, radius, angle, opts, hovered, active, disabled)
  elseif variant == "wiper" then
    render_wiper(ctx, dl, center_x, center_y, radius, angle, t, opts, hovered, active, disabled)
  elseif variant == "wiper_only" then
    render_wiper_only(ctx, dl, center_x, center_y, radius, angle, t, opts, hovered, active, disabled)
  elseif variant == "wiper_dot" then
    render_wiper_dot(ctx, dl, center_x, center_y, radius, angle, t, opts, hovered, active, disabled)
  elseif variant == "stepped" then
    render_stepped(ctx, dl, center_x, center_y, radius, angle, t, opts, hovered, active, disabled)
  elseif variant == "space" then
    render_space(ctx, dl, center_x, center_y, radius, angle, t, opts, hovered, active, disabled)
  else
    -- Fallback to tick
    render_tick(ctx, dl, center_x, center_y, radius, angle, opts, hovered, active, disabled)
  end

  -- Border (drawn for all except wiper_only)
  if variant ~= "wiper_only" and variant ~= "space" then
    ImGui.DrawList_AddCircle(dl, center_x, center_y, radius, border_color, 32, 1)
  end

  -- Value text (centered in knob)
  if opts.show_value and not disabled then
    local text_color = opts.text_color or Theme.COLORS.TEXT_NORMAL
    local value_text = string.format(opts.format, value)
    local text_w, text_h = ImGui.CalcTextSize(ctx, value_text)
    ImGui.SetCursorScreenPos(ctx, center_x - text_w / 2, center_y - text_h / 2)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, text_color)
    ImGui.Text(ctx, value_text)
    ImGui.PopStyleColor(ctx)
  end
end

local function render_label(ctx, x, y, size, label, opts)
  if not opts.show_label or not label or label == "" then
    return 0
  end

  local label_color = opts.label_color or Theme.COLORS.TEXT_NORMAL
  local label_w = ImGui.CalcTextSize(ctx, label)
  local label_x = x + (size - label_w) / 2
  local label_y = y + size + 4

  ImGui.SetCursorScreenPos(ctx, label_x, label_y)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, label_color)
  ImGui.Text(ctx, label)
  ImGui.PopStyleColor(ctx)

  return ImGui.GetTextLineHeight(ctx) + 4
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Draw a circular knob widget
--- Supports both positional and opts-based parameters:
--- - Positional: Ark.Knob(ctx, label, value, min, max)
--- - Opts table: Ark.Knob(ctx, {label = "Volume", value = 50, min = 0, max = 100, ...})
--- @param ctx userdata ImGui context
--- @param label_or_opts string|table Label string or opts table
--- @param value number|nil Current value (positional only)
--- @param min number|nil Minimum value (positional only)
--- @param max number|nil Maximum value (positional only)
--- @return table Result { changed, value, width, height, hovered, active }
function M.draw(ctx, label_or_opts, value, min, max)
  -- Hybrid parameter detection
  local opts
  if type(label_or_opts) == "table" then
    opts = label_or_opts
  elseif type(label_or_opts) == "string" then
    opts = {
      label = label_or_opts,
      value = value,
      min = min,
      max = max,
    }
  else
    opts = {}
  end

  opts = Base.parse_opts(opts, DEFAULTS)

  -- Resolve unique ID
  local unique_id = Base.resolve_id(ctx, opts, "knob")

  -- Get position and draw list
  local x, y = Base.get_position(ctx, opts)
  local dl = Base.get_draw_list(ctx, opts)

  -- Get size
  local size = opts.size or 40
  local radius = opts.radius or (size / 2 - 2)

  -- Get value range
  local min_val = opts.min or 0
  local max_val = opts.max or 100
  local default_val = opts.default or min_val
  local current_value = Base.clamp(opts.value or default_val, min_val, max_val)

  -- State
  local disabled = opts.disabled or false
  local changed = false

  -- Create invisible button for interaction
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, "##" .. unique_id, size, size)

  local hovered = not disabled and ImGui.IsItemHovered(ctx)
  local active = not disabled and ImGui.IsItemActive(ctx)

  -- Check for lock (prevents double-click drag interference)
  local now = ImGui.GetTime(ctx)
  local locked = (knob_locks[unique_id] or 0) > now

  -- Double-click to reset
  if hovered and not locked and ImGui.IsMouseDoubleClicked(ctx, 0) then
    current_value = default_val
    changed = true
    knob_locks[unique_id] = now + 0.3
  end

  -- Vertical drag to adjust
  if not locked and active and not ImGui.IsMouseDoubleClicked(ctx, 0) then
    local _, drag_y = ImGui.GetMouseDragDelta(ctx, 0)
    if drag_y ~= 0 then
      -- Drag down = decrease value (negative drag_y)
      local delta = -drag_y * opts.sensitivity
      local new_value = current_value + delta * (max_val - min_val)
      new_value = Base.clamp(new_value, min_val, max_val)

      if math.abs(new_value - current_value) > 1e-6 then
        current_value = new_value
        changed = true
      end

      ImGui.ResetMouseDragDelta(ctx, 0)
    end
  end

  -- Render knob
  render_knob(ctx, dl, x, y, size, radius, current_value, min_val, max_val, opts, hovered, active)

  -- Render label
  local label_height = render_label(ctx, x, y, size, opts.label, opts)

  -- Tooltip
  if hovered or active then
    local tooltip_text
    if opts.tooltip then
      tooltip_text = opts.tooltip
    else
      tooltip_text = string.format(opts.format, current_value)
    end

    if ImGui.BeginTooltip(ctx) then
      ImGui.Text(ctx, tooltip_text)
      ImGui.EndTooltip(ctx)
    end
  end

  -- Call change callback
  if changed and opts.on_change then
    opts.on_change(current_value)
  end

  -- Calculate total height
  local total_height = size + label_height

  -- Advance cursor
  Base.advance_cursor(ctx, x, y, size, total_height, opts.advance)

  -- Return standardized result
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
-- MODULE EXPORT (Callable)
-- ============================================================================

-- Make module callable: Ark.Knob(ctx, ...) → M.draw(ctx, ...)
return setmetatable(M, {
  __call = function(_, ctx, ...)
    return M.draw(ctx, ...)
  end
})
