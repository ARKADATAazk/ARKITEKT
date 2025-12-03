-- @noindex
-- arkitekt/gui/widgets/primitives/loading_spinner.lua
-- Loading spinner widget (rotating arc animation)
-- Uses unified opts-based API

local ImGui = require('arkitekt.core.imgui')
local Theme = require('arkitekt.core.theme')
local Colors = require('arkitekt.core.colors')
local Base = require('arkitekt.gui.widgets.base')

local M = {}

-- ============================================================================
-- DEFAULTS
-- ============================================================================

local DEFAULTS = {
  -- Identity
  id = 'loading_spinner',

  -- Position (nil = use cursor)
  x = nil,
  y = nil,

  -- Size
  size = 20,           -- Radius of the spinner
  thickness = 2,       -- Line thickness

  -- Style
  color = nil,         -- nil = use Theme.COLORS.TEXT_NORMAL
  arc_length = 1.5,    -- Length of arc in radians (default 270 degrees)
  speed = 3.0,         -- Rotation speed multiplier

  -- Cursor control
  advance = 'vertical',

  -- Draw list
  draw_list = nil,
}

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Draw a loading spinner widget
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result { width, height }
function M.Draw(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)

  -- Get position and draw list
  local x, y = Base.get_position(ctx, opts)
  local dl = Base.get_draw_list(ctx, opts)

  -- Get parameters
  local size = opts.size or 20
  local thickness = opts.thickness or 2
  local color = opts.color or Theme.COLORS.TEXT_NORMAL
  local arc_length = (opts.arc_length or 1.5) * math.pi  -- Convert to radians
  local speed = opts.speed or 3.0

  -- Calculate center point
  local center_x = x + size
  local center_y = y + size

  -- Get current time for rotation
  local time = reaper.time_precise()
  local rotation = (time * speed) % (math.pi * 2)  -- Rotate continuously

  -- Start and end angles
  local start_angle = rotation - math.pi / 2  -- Start at top
  local end_angle = start_angle + arc_length

  -- Draw the rotating arc
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathArcTo(dl, center_x, center_y, size, start_angle, end_angle, 24)
  ImGui.DrawList_PathStroke(dl, color, 0, thickness)

  -- Total dimensions
  local total_size = size * 2

  -- Advance cursor
  Base.advance_cursor(ctx, x, y, total_size, total_size, opts.advance)

  -- Return standardized result
  return Base.create_result({
    width = total_size,
    height = total_size,
  })
end

--- Draw a loading spinner directly using a draw list (low-level API)
--- Useful for custom rendering contexts like tile renderers
--- @param dl userdata ImGui draw list
--- @param center_x number Center X coordinate
--- @param center_y number Center Y coordinate
--- @param opts table Options: size, thickness, color, arc_length, speed
function M.draw_direct(dl, center_x, center_y, opts)
  opts = opts or {}

  local size = opts.size or 20
  local thickness = opts.thickness or 2
  local color = opts.color or Theme.COLORS.TEXT_NORMAL
  local arc_length = (opts.arc_length or 1.5) * math.pi
  local speed = opts.speed or 3.0

  -- Get current time for rotation
  local time = reaper.time_precise()
  local rotation = (time * speed) % (math.pi * 2)

  -- Start and end angles
  local start_angle = rotation - math.pi / 2
  local end_angle = start_angle + arc_length

  -- Draw the rotating arc
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathArcTo(dl, center_x, center_y, size, start_angle, end_angle, 24)
  ImGui.DrawList_PathStroke(dl, color, 0, thickness)
end

-- ============================================================================
-- MODULE EXPORT (Callable)
-- ============================================================================

-- Make module callable: Ark.LoadingSpinner(ctx, opts) → M.Draw(ctx, opts)
return setmetatable(M, {
  __call = function(_, ctx, opts)
    return M.Draw(ctx, opts)
  end
})
