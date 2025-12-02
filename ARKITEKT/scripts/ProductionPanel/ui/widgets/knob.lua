-- @noindex
-- ProductionPanel/ui/widgets/knob.lua
-- Rotary knob widget for macro controls

local M = {}

-- DEPENDENCIES
local Ark = require('arkitekt')
local ImGui = Ark.ImGui
local Colors = Ark.Colors
local Theme = require('arkitekt.core.theme')
local Base = require('arkitekt.gui.widgets.base')

-- CONSTANTS
local PI = math.pi
local TWO_PI = PI * 2
local HALF_PI = PI / 2

-- Angle range for knob (270 degrees)
local MIN_ANGLE = -PI * 0.75  -- -135 degrees
local MAX_ANGLE = PI * 0.75   -- +135 degrees
local ANGLE_RANGE = MAX_ANGLE - MIN_ANGLE

---Draw a rotary knob widget
---@param ctx userdata ImGui context
---@param opts table { id, label, value, min, max, size, color }
---@return table { changed, value, hovered, active }
function M.Draw(ctx, opts)
  opts = opts or {}

  local id = opts.id or 'knob'
  local label = opts.label or 'Knob'
  local value = opts.value or 0.0
  local min_val = opts.min or 0.0
  local max_val = opts.max or 1.0
  local size = opts.size or 64
  local disabled = opts.disabled or false

  -- Colors (read fresh each frame for theme switching)
  local bg_color = opts.bg_color or Theme.COLORS.BG_PANEL
  local track_color = opts.track_color or Theme.COLORS.BG_HOVER
  local value_color = opts.value_color or Theme.COLORS.ACCENT_PRIMARY
  local text_color = opts.text_color or Theme.COLORS.TEXT_NORMAL
  local dot_color = opts.dot_color or Theme.COLORS.TEXT_BRIGHT

  if disabled then
    value_color = Colors.WithOpacity(value_color, 0.4)
    text_color = Colors.WithOpacity(text_color, 0.5)
  end

  -- State
  local changed = false
  local current_value = value

  -- Get cursor position
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local center_x = x + size / 2
  local center_y = y + size / 2
  local radius = size / 2 - 4
  local track_thickness = 3
  local value_thickness = 4

  -- Invisible button for interaction
  ImGui.InvisibleButton(ctx, id, size, size)

  local hovered = ImGui.IsItemHovered(ctx)
  local active = ImGui.IsItemActive(ctx)

  -- Handle dragging
  if active and not disabled then
    local _, drag_y = ImGui.GetMouseDragDelta(ctx, 0)
    if drag_y ~= 0 then
      -- Vertical drag changes value (drag down = decrease)
      local delta = -drag_y * 0.005 -- Sensitivity
      local new_value = current_value + delta * (max_val - min_val)
      new_value = math.max(min_val, math.min(max_val, new_value))

      if new_value ~= current_value then
        current_value = new_value
        changed = true
      end

      ImGui.ResetMouseDragDelta(ctx, 0)
    end
  end

  -- Double-click to reset
  if ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) and not disabled then
    local default_value = opts.default or min_val
    if current_value ~= default_value then
      current_value = default_value
      changed = true
    end
  end

  -- Drawing
  local dl = ImGui.GetWindowDrawList(ctx)

  -- Background circle
  ImGui.DrawList_AddCircleFilled(dl, center_x, center_y, radius, bg_color, 32)

  -- Track arc (background)
  ImGui.DrawList_PathArcTo(dl, center_x, center_y, radius - track_thickness,
    MIN_ANGLE + HALF_PI, MAX_ANGLE + HALF_PI, 32)
  ImGui.DrawList_PathStroke(dl, track_color, 0, track_thickness * 2)

  -- Value arc (foreground)
  local normalized = (current_value - min_val) / (max_val - min_val)
  local value_angle = MIN_ANGLE + (normalized * ANGLE_RANGE)

  if normalized > 0.001 then
    ImGui.DrawList_PathArcTo(dl, center_x, center_y, radius - value_thickness,
      MIN_ANGLE + HALF_PI, value_angle + HALF_PI, 32)
    ImGui.DrawList_PathStroke(dl, value_color, 0, value_thickness * 2)
  end

  -- Position indicator dot
  local dot_radius = 3
  local dot_distance = radius - 12
  local dot_x = center_x + math.cos(value_angle) * dot_distance
  local dot_y = center_y + math.sin(value_angle) * dot_distance
  ImGui.DrawList_AddCircleFilled(dl, dot_x, dot_y, dot_radius, dot_color, 12)

  -- Border circle
  local border_color = hovered and Theme.COLORS.BORDER_HOVER or Theme.COLORS.BORDER_INNER
  ImGui.DrawList_AddCircle(dl, center_x, center_y, radius, border_color, 32, 1)

  -- Label below knob
  if label and label ~= '' then
    ImGui.SetCursorScreenPos(ctx, x, y + size + 4)

    -- Center the label
    local label_w = ImGui.CalcTextSize(ctx, label)
    ImGui.SetCursorScreenPos(ctx, x + (size - label_w) / 2, y + size + 4)

    ImGui.PushStyleColor(ctx, ImGui.Col_Text, text_color)
    ImGui.Text(ctx, label)
    ImGui.PopStyleColor(ctx)
  end

  -- Value text (centered in knob)
  local value_text = string.format('%.2f', current_value)
  local text_w, text_h = ImGui.CalcTextSize(ctx, value_text)
  ImGui.SetCursorScreenPos(ctx, center_x - text_w / 2, center_y - text_h / 2)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, text_color)
  ImGui.Text(ctx, value_text)
  ImGui.PopStyleColor(ctx)

  -- Tooltip
  if hovered and opts.tooltip then
    ImGui.SetTooltip(ctx, opts.tooltip)
  end

  -- Advance cursor (after label)
  local label_height = label and 20 or 0
  local total_height = size + label_height
  ImGui.SetCursorScreenPos(ctx, x, y + total_height)

  -- Return standard result object
  return Base.create_result({
    changed = changed,
    value = current_value,
    width = size,
    height = total_height,
    hovered = hovered,
    active = active,
  })
end

return M
