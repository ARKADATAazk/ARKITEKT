-- @noindex
-- arkitekt/gui/widgets/experimental/encoder.lua
-- EXPERIMENTAL: Rotary encoder with endless rotation (no bounds)
-- Tracks relative changes rather than absolute values, useful for tempo, shuttle, parameter offsets

local ImGui = require('arkitekt.platform.imgui')
local Theme = require('arkitekt.core.theme')
local Colors = require('arkitekt.core.colors')
local Base = require('arkitekt.gui.widgets.base')

local M = {}

-- ============================================================================
-- CONSTANTS
-- ============================================================================

-- Visual angle range (how far the indicator can rotate visually)
local VISUAL_RANGE = math.pi * 1.5  -- 270 degrees

-- Performance: Cache ImGui functions
local DrawList_AddCircleFilled = ImGui.DrawList_AddCircleFilled
local DrawList_AddCircle = ImGui.DrawList_AddCircle
local DrawList_PathArcTo = ImGui.DrawList_PathArcTo
local DrawList_PathStroke = ImGui.DrawList_PathStroke
local IsMouseDragging = ImGui.IsMouseDragging
local GetMouseDelta = ImGui.GetMouseDelta
local IsItemActive = ImGui.IsItemActive
local IsItemHovered = ImGui.IsItemHovered

-- ============================================================================
-- DEFAULTS
-- ============================================================================

local DEFAULTS = {
  -- Identity
  id = nil,

  -- Position (nil = use cursor)
  x = nil,
  y = nil,

  -- Size
  size = 60,

  -- Delta tracking (output)
  delta = 0,            -- Accumulated delta since last frame (read this to get changes)

  -- Visual state
  angle = 0,            -- Current visual angle for indicator (radians, wraps around)

  -- Sensitivity
  sensitivity = 0.01,   -- Rotation speed multiplier (higher = faster)

  -- State
  disabled = false,

  -- Style
  color_track = nil,    -- Track (outer ring) color
  color_indicator = nil, -- Indicator dot color
  color_center = nil,   -- Center circle color
  line_width = 3,       -- Track line width
  indicator_size = 0.2, -- Indicator dot size (relative to radius)

  -- Labels
  label = nil,          -- Label text (shown below)
  value_display = nil,  -- Custom value display function(delta) -> string

  -- Callbacks
  on_change = nil,      -- function(delta) - called when value changes

  -- Cursor control
  advance = "vertical",

  -- Draw list
  draw_list = nil,
}

-- ============================================================================
-- RENDERING
-- ============================================================================

--- Draw encoder visualization
local function render_encoder(ctx, dl, cx, cy, radius, angle, opts)
  local track_color = opts.color_track or Colors.with_opacity(Theme.COLORS.BG_BASE, 0.5)
  local indicator_color = opts.color_indicator or Theme.COLORS.ACCENT_PRIMARY
  local center_color = opts.color_center or Colors.with_opacity(Theme.COLORS.BG_BASE, 0.8)
  local line_width = opts.line_width or 3

  -- Draw track (full circle)
  DrawList_AddCircle(dl, cx, cy, radius, track_color, 32, line_width)

  -- Draw center circle
  local center_radius = radius * 0.3
  DrawList_AddCircleFilled(dl, cx, cy, center_radius, center_color, 24)

  -- Draw indicator (position marker)
  local indicator_radius = radius * (opts.indicator_size or 0.2)
  local indicator_distance = radius - indicator_radius - line_width
  local indicator_x = cx + math.cos(angle) * indicator_distance
  local indicator_y = cy + math.sin(angle) * indicator_distance
  DrawList_AddCircleFilled(dl, indicator_x, indicator_y, indicator_radius, indicator_color, 16)
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Draw a rotary encoder widget
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result { changed, delta, angle, width, height }
function M.draw(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)

  -- Resolve unique ID
  local unique_id = Base.resolve_id(ctx, opts, "encoder")

  -- Get position and draw list
  local x, y = Base.get_position(ctx, opts)
  local dl = Base.get_draw_list(ctx, opts)

  -- Get size
  local size = opts.size or 60
  local radius = size / 2

  local cx = x + radius
  local cy = y + radius

  -- Create invisible button for interaction
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, "##" .. unique_id, size, size)

  local hovered = IsItemHovered(ctx)
  local active = IsItemActive(ctx)
  local changed = false
  local delta = 0

  -- Handle dragging
  if active and not opts.disabled then
    if IsMouseDragging(ctx, ImGui.MouseButton_Left, 0) then
      local mouse_dx, mouse_dy = GetMouseDelta(ctx)

      -- Vertical drag changes value (like Knob)
      local drag_delta = -mouse_dy * (opts.sensitivity or 0.01)

      if math.abs(drag_delta) > 0 then
        delta = drag_delta
        opts.angle = (opts.angle + drag_delta) % (2 * math.pi)  -- Wrap around
        changed = true

        -- Fire callback
        if opts.on_change then
          opts.on_change(delta)
        end
      end
    end
  end

  -- Render encoder
  render_encoder(ctx, dl, cx, cy, radius, opts.angle, opts)

  -- Hover effect (subtle outer glow)
  if hovered and not opts.disabled then
    local hover_color = Colors.with_opacity(Theme.COLORS.TEXT_NORMAL, 0.15)
    DrawList_AddCircle(dl, cx, cy, radius + 2, hover_color, 32, 2)
  end

  -- Label (below encoder)
  if opts.label then
    local label_y = y + size + 4
    ImGui.SetCursorScreenPos(ctx, x, label_y)
    ImGui.Text(ctx, opts.label)
  end

  -- Value display (shows delta if non-zero)
  if opts.value_display and delta ~= 0 then
    local display_text = opts.value_display(delta)
    local text_w, _ = ImGui.CalcTextSize(ctx, display_text)
    local display_y = y + size + (opts.label and 20 or 4)
    ImGui.SetCursorScreenPos(ctx, x + (size - text_w) / 2, display_y)
    ImGui.Text(ctx, display_text)
  end

  -- Advance cursor
  local total_height = size
  if opts.label then total_height = total_height + 20 end
  if opts.value_display then total_height = total_height + 16 end

  Base.advance_cursor(ctx, x, y, size, total_height, opts.advance)

  -- Return standardized result
  return Base.create_result({
    changed = changed,
    delta = delta,
    angle = opts.angle,
    width = size,
    height = total_height,
  })
end

-- ============================================================================
-- CONVENIENCE CONSTRUCTORS
-- ============================================================================

--- Tempo encoder (shows BPM changes)
function M.tempo(ctx, opts)
  opts = opts or {}
  opts.label = opts.label or "Tempo"
  opts.value_display = opts.value_display or function(delta)
    return string.format("%+.1f BPM", delta * 100)  -- Scale delta to BPM range
  end
  opts.sensitivity = opts.sensitivity or 0.005
  return M.draw(ctx, opts)
end

--- Fine adjustment encoder (low sensitivity)
function M.fine(ctx, opts)
  opts = opts or {}
  opts.sensitivity = 0.002
  opts.label = opts.label or "Fine"
  return M.draw(ctx, opts)
end

--- Coarse adjustment encoder (high sensitivity)
function M.coarse(ctx, opts)
  opts = opts or {}
  opts.sensitivity = 0.05
  opts.label = opts.label or "Coarse"
  return M.draw(ctx, opts)
end

-- ============================================================================
-- MODULE EXPORT (Callable)
-- ============================================================================

-- Make module callable: Ark.Encoder(ctx, ...) → M.draw(ctx, ...)
return setmetatable(M, {
  __call = function(_, ctx, ...)
    return M.draw(ctx, ...)
  end
})
