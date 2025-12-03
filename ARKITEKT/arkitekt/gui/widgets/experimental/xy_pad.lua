-- @noindex
-- arkitekt/gui/widgets/experimental/xy_pad.lua
-- EXPERIMENTAL: XY pad widget for controlling two parameters simultaneously
-- Common in audio apps for LFO rate/depth, filter cutoff/resonance, etc.

local ImGui = require('arkitekt.core.imgui')
local Theme = require('arkitekt.theme')
local Colors = require('arkitekt.core.colors')
local Base = require('arkitekt.gui.widgets.base')

local M = {}

-- ============================================================================
-- DEFAULTS
-- ============================================================================

local DEFAULTS = {
  -- Identity
  id = nil,
  label_x = "X",
  label_y = "Y",

  -- Position (nil = use cursor)
  x = nil,
  y = nil,

  -- Size
  size = 200,       -- Square pad size (can override with width/height)
  width = nil,
  height = nil,

  -- Values (normalized 0-1, remapped to min/max)
  value_x = 0.5,
  value_y = 0.5,
  min_x = 0,
  max_x = 1,
  min_y = 0,
  max_y = 1,
  default_x = nil,  -- Double-click reset value
  default_y = nil,

  -- State
  disabled = false,
  snap_to_grid = false,  -- Snap to grid points
  grid_divisions = 4,    -- Number of grid divisions

  -- Style
  bg_color = nil,
  grid_color = nil,
  crosshair_color = nil,
  handle_color = nil,
  handle_hover_color = nil,
  handle_active_color = nil,
  border_color = nil,
  label_color = nil,

  -- Display
  show_grid = true,
  show_crosshair = true,
  show_labels = true,
  handle_radius = 8,

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

local xy_locks = {}  -- Prevents double-click interference with drag

-- ============================================================================
-- RENDERING
-- ============================================================================

local function render_grid(dl, x, y, w, h, divisions, opts)
  local grid_color = opts.grid_color or Colors.WithOpacity(Theme.COLORS.BORDER_INNER, 0.3)

  -- Vertical lines
  for i = 1, divisions - 1 do
    local line_x = x + (i / divisions) * w
    ImGui.DrawList_AddLine(dl, line_x, y, line_x, y + h, grid_color, 1)
  end

  -- Horizontal lines
  for i = 1, divisions - 1 do
    local line_y = y + (i / divisions) * h
    ImGui.DrawList_AddLine(dl, x, line_y, x + w, line_y, grid_color, 1)
  end

  -- Center crosshair (thicker)
  if divisions % 2 == 0 then
    local center_x = x + w / 2
    local center_y = y + h / 2
    local crosshair_color = Colors.WithOpacity(grid_color, 0.6)
    ImGui.DrawList_AddLine(dl, center_x, y, center_x, y + h, crosshair_color, 2)
    ImGui.DrawList_AddLine(dl, x, center_y, x + w, center_y, crosshair_color, 2)
  end
end

local function render_crosshair(dl, cx, cy, w, h, x, y, opts)
  local crosshair_color = opts.crosshair_color or Colors.WithOpacity(Theme.COLORS.ACCENT_PRIMARY, 0.4)

  -- Vertical line
  ImGui.DrawList_AddLine(dl, cx, y, cx, y + h, crosshair_color, 1)
  -- Horizontal line
  ImGui.DrawList_AddLine(dl, x, cy, x + w, cy, crosshair_color, 1)
end

local function render_handle(dl, cx, cy, radius, hovered, active, disabled, opts)
  local handle_color
  if disabled then
    handle_color = Colors.WithOpacity(Colors.Desaturate(opts.handle_color or Theme.COLORS.ACCENT_PRIMARY, 0.5), 0.5)
  elseif active then
    handle_color = opts.handle_active_color or Colors.AdjustBrightness(Theme.COLORS.ACCENT_PRIMARY, 1.3)
  elseif hovered then
    handle_color = opts.handle_hover_color or Colors.AdjustBrightness(Theme.COLORS.ACCENT_PRIMARY, 1.15)
  else
    handle_color = opts.handle_color or Theme.COLORS.ACCENT_PRIMARY
  end

  -- Shadow
  if not disabled then
    ImGui.DrawList_AddCircleFilled(dl, cx + 1, cy + 1, radius, 0x00000050, 16)
  end

  -- Handle circle
  ImGui.DrawList_AddCircleFilled(dl, cx, cy, radius, handle_color, 16)

  -- Border
  local border_color = Colors.AdjustBrightness(handle_color, 0.7)
  ImGui.DrawList_AddCircle(dl, cx, cy, radius, border_color, 16, 2)
end

local function render_labels(ctx, x, y, w, h, label_x, label_y, opts)
  if not opts.show_labels then return end

  local label_color = opts.label_color or Theme.COLORS.TEXT_DIMMED

  -- X label (bottom center)
  if label_x and label_x ~= "" then
    local label_w = ImGui.CalcTextSize(ctx, label_x)
    ImGui.SetCursorScreenPos(ctx, x + (w - label_w) / 2, y + h + 4)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, label_color)
    ImGui.Text(ctx, label_x)
    ImGui.PopStyleColor(ctx)
  end

  -- Y label (left center, rotated would be nice but not supported)
  if label_y and label_y ~= "" then
    ImGui.SetCursorScreenPos(ctx, x - 20, y + h / 2 - 6)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, label_color)
    ImGui.Text(ctx, label_y)
    ImGui.PopStyleColor(ctx)
  end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Draw an XY pad widget
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result { changed, value_x, value_y, width, height, hovered, active }
function M.draw(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)

  -- Resolve unique ID
  local unique_id = Base.resolve_id(ctx, opts, "xy_pad")

  -- Get position and draw list
  local x, y = Base.get_position(ctx, opts)
  local dl = Base.get_draw_list(ctx, opts)

  -- Get size (square by default)
  local size = opts.size or 200
  local w = opts.width or size
  local h = opts.height or size

  -- Get value ranges
  local min_x, max_x = opts.min_x or 0, opts.max_x or 1
  local min_y, max_y = opts.min_y or 0, opts.max_y or 1
  local default_x = opts.default_x or (min_x + max_x) / 2
  local default_y = opts.default_y or (min_y + max_y) / 2

  -- Current values
  local value_x = Base.clamp(opts.value_x or default_x, min_x, max_x)
  local value_y = Base.clamp(opts.value_y or default_y, min_y, max_y)

  -- State
  local disabled = opts.disabled or false
  local changed = false

  -- Background
  local bg_color = opts.bg_color or Theme.COLORS.BG_BASE
  local border_color = opts.border_color or Theme.COLORS.BORDER_OUTER
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, bg_color)

  -- Grid
  if opts.show_grid then
    render_grid(dl, x, y, w, h, opts.grid_divisions or 4, opts)
  end

  -- Create invisible button for interaction
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, "##" .. unique_id, w, h)

  local hovered = not disabled and ImGui.IsItemHovered(ctx)
  local active = not disabled and ImGui.IsItemActive(ctx)

  -- Check for lock
  local now = ImGui.GetTime(ctx)
  local locked = (xy_locks[unique_id] or 0) > now

  -- Double-click to reset
  if hovered and not locked and ImGui.IsMouseDoubleClicked(ctx, 0) then
    value_x = default_x
    value_y = default_y
    changed = true
    xy_locks[unique_id] = now + 0.3
  end

  -- Drag to adjust
  if not locked and active and not ImGui.IsMouseDoubleClicked(ctx, 0) then
    local mx, my = ImGui.GetMousePos(ctx)

    -- Clamp to pad bounds
    mx = Base.clamp(mx, x, x + w)
    my = Base.clamp(my, y, y + h)

    -- Convert to normalized coordinates (0-1)
    local norm_x = (mx - x) / w
    local norm_y = 1.0 - ((my - y) / h)  -- Invert Y (bottom = 0, top = 1)

    -- Snap to grid if enabled
    if opts.snap_to_grid then
      local divisions = opts.grid_divisions or 4
      norm_x = math.floor(norm_x * divisions + 0.5) / divisions
      norm_y = math.floor(norm_y * divisions + 0.5) / divisions
    end

    -- Convert to value range
    local new_x = min_x + norm_x * (max_x - min_x)
    local new_y = min_y + norm_y * (max_y - min_y)

    if math.abs(new_x - value_x) > 1e-6 or math.abs(new_y - value_y) > 1e-6 then
      value_x = new_x
      value_y = new_y
      changed = true
    end
  end

  -- Calculate handle position
  local norm_x = (value_x - min_x) / (max_x - min_x)
  local norm_y = (value_y - min_y) / (max_y - min_y)
  local handle_x = x + norm_x * w
  local handle_y = y + (1.0 - norm_y) * h  -- Invert Y

  -- Crosshair
  if opts.show_crosshair then
    render_crosshair(dl, handle_x, handle_y, w, h, x, y, opts)
  end

  -- Handle
  local handle_radius = opts.handle_radius or 8
  render_handle(dl, handle_x, handle_y, handle_radius, hovered, active, disabled, opts)

  -- Border
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, border_color, 0, 0, 1)

  -- Labels
  render_labels(ctx, x, y, w, h, opts.label_x, opts.label_y, opts)

  -- Tooltip
  if hovered or active then
    local tooltip_text
    if opts.tooltip then
      tooltip_text = opts.tooltip
    else
      tooltip_text = string.format("%s: %.2f\n%s: %.2f",
        opts.label_x or "X", value_x,
        opts.label_y or "Y", value_y)
    end

    if ImGui.BeginTooltip(ctx) then
      ImGui.Text(ctx, tooltip_text)
      ImGui.EndTooltip(ctx)
    end
  end

  -- Call change callback
  if changed and opts.on_change then
    opts.on_change(value_x, value_y)
  end

  -- Calculate total dimensions (with labels)
  local label_height = opts.show_labels and 20 or 0
  local total_height = h + label_height

  -- Advance cursor
  Base.advance_cursor(ctx, x, y, w, total_height, opts.advance)

  -- Return standardized result
  return Base.create_result({
    changed = changed,
    value_x = value_x,
    value_y = value_y,
    width = w,
    height = total_height,
    hovered = hovered,
    active = active,
  })
end

-- ============================================================================
-- MODULE EXPORT (Callable)
-- ============================================================================

-- Make module callable: Ark.XYPad(ctx, ...) → M.draw(ctx, ...)
return setmetatable(M, {
  __call = function(_, ctx, ...)
    return M.draw(ctx, ...)
  end
})
