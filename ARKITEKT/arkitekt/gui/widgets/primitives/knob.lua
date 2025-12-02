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
  bg_color = nil,
  bg_hover_color = nil,
  bg_active_color = nil,
  line_color = nil,
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
-- RENDERING
-- ============================================================================

local function render_knob(ctx, dl, x, y, size, radius, value, min_val, max_val, opts, hovered, active)
  local center_x = x + size / 2
  local center_y = y + size / 2
  local disabled = opts.disabled

  -- Calculate angle based on value
  local t = (value - min_val) / (max_val - min_val)
  local angle = ANGLE_MIN + (ANGLE_MAX - ANGLE_MIN) * t
  local angle_cos, angle_sin = math.cos(angle), math.sin(angle)

  -- Colors
  local bg_color = opts.bg_color or Theme.COLORS.BG_BASE
  local inner_color = opts.inner_color or Theme.COLORS.BG_HOVER
  local line_color = opts.line_color or Theme.COLORS.ACCENT_PRIMARY
  local border_color = opts.border_color or Theme.COLORS.BORDER_INNER

  if disabled then
    bg_color = Colors.with_opacity(Colors.desaturate(bg_color, 0.5), 0.5)
    inner_color = Colors.with_opacity(Colors.desaturate(inner_color, 0.5), 0.5)
    line_color = Colors.with_opacity(Colors.desaturate(line_color, 0.5), 0.5)
    border_color = Colors.with_opacity(Colors.desaturate(border_color, 0.5), 0.5)
  elseif active then
    bg_color = opts.bg_active_color or Colors.adjust_brightness(bg_color, 0.9)
    inner_color = opts.inner_active_color or Colors.adjust_brightness(inner_color, 0.9)
  elseif hovered then
    bg_color = opts.bg_hover_color or Colors.adjust_brightness(bg_color, 1.1)
    inner_color = opts.inner_hover_color or Colors.adjust_brightness(inner_color, 1.1)
    border_color = opts.border_hover_color or Theme.COLORS.BORDER_HOVER
  end

  -- Outer circle (background)
  ImGui.DrawList_AddCircleFilled(dl, center_x, center_y, radius, bg_color, 32)

  -- Value indicator line
  local radius_inner = radius * 0.4
  local line_start_x = center_x + angle_cos * radius_inner
  local line_start_y = center_y + angle_sin * radius_inner
  local line_end_x = center_x + angle_cos * (radius - 2)
  local line_end_y = center_y + angle_sin * (radius - 2)
  ImGui.DrawList_AddLine(dl, line_start_x, line_start_y, line_end_x, line_end_y, line_color, 2.0)

  -- Inner circle (center)
  ImGui.DrawList_AddCircleFilled(dl, center_x, center_y, radius_inner, inner_color, 16)

  -- Border
  ImGui.DrawList_AddCircle(dl, center_x, center_y, radius, border_color, 32, 1)

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
