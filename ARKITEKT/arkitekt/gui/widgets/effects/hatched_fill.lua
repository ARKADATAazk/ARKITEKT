-- @noindex
-- arkitekt/gui/widgets/effects/hatched_fill.lua
-- Visual effect: diagonal hatched/striped fill pattern
-- Useful for backgrounds, overlays, progress indicators, stretch zones, etc.

local ImGui = require('arkitekt.platform.imgui')
local Colors = require('arkitekt.core.colors')

local M = {}

-- ============================================================================
-- DIRECTION CONSTANTS
-- ============================================================================

M.DIRECTION = {
  FORWARD = 'forward',       -- Lines go ↘ (top-left to bottom-right)
  BACKWARD = 'backward',     -- Lines go ↙ (top-right to bottom-left)
  BOTH = 'both',             -- Cross-hatch (both directions)
  HORIZONTAL = 'horizontal', -- Horizontal lines
  VERTICAL = 'vertical',     -- Vertical lines
}

-- ============================================================================
-- DEFAULTS
-- ============================================================================

local DEFAULTS = {
  -- Position & size (required)
  x = 0,
  y = 0,
  w = 100,
  h = 100,

  -- Pattern settings
  direction = 'forward',
  spacing = 6,
  thickness = 1,
  angle = 45,  -- Only used for non-standard angles (future)

  -- Colors
  color = 0xFFFFFF60,  -- White with low alpha
  bg_color = nil,      -- Optional background fill

  -- Animation
  offset = 0,          -- Line offset for animation (0 to spacing)
  animate_speed = 0,   -- If > 0, auto-animate (pixels per second)

  -- Rendering
  use_clip = true,     -- Use clip rect (recommended)
  draw_list = nil,     -- Optional draw list override
}

-- ============================================================================
-- ANIMATION STATE
-- ============================================================================

local anim_state = {
  offset = 0,
  last_time = 0,
}

-- ============================================================================
-- DRAWING FUNCTIONS
-- ============================================================================

local function draw_forward_lines(dl, x, y, w, h, spacing, offset, color, thickness)
  -- Lines going ↘ (top-left to bottom-right, slope = 1)
  local total_span = w + h
  local start = (offset % spacing) - spacing
  for i = start, total_span, spacing do
    local x1 = x + i - h
    local y1 = y
    local x2 = x + i
    local y2 = y + h
    ImGui.DrawList_AddLine(dl, x1, y1, x2, y2, color, thickness)
  end
end

local function draw_backward_lines(dl, x, y, w, h, spacing, offset, color, thickness)
  -- Lines going ↙ (top-right to bottom-left, slope = -1)
  local total_span = w + h
  local start = (offset % spacing) - spacing
  for i = start, total_span, spacing do
    local x1 = x + w - i + h
    local y1 = y
    local x2 = x + w - i
    local y2 = y + h
    ImGui.DrawList_AddLine(dl, x1, y1, x2, y2, color, thickness)
  end
end

local function draw_horizontal_lines(dl, x, y, w, h, spacing, offset, color, thickness)
  local start = (offset % spacing)
  for i = start, h, spacing do
    ImGui.DrawList_AddLine(dl, x, y + i, x + w, y + i, color, thickness)
  end
end

local function draw_vertical_lines(dl, x, y, w, h, spacing, offset, color, thickness)
  local start = (offset % spacing)
  for i = start, w, spacing do
    ImGui.DrawList_AddLine(dl, x + i, y, x + i, y + h, color, thickness)
  end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Draw a hatched fill pattern
--- @param ctx userdata ImGui context
--- @param opts table Options: x, y, w, h, direction, spacing, thickness, color, bg_color, offset, use_clip, draw_list
--- @return table Result { width, height }
function M.draw(ctx, opts)
  opts = opts or {}

  -- Merge with defaults
  local x = opts.x or DEFAULTS.x
  local y = opts.y or DEFAULTS.y
  local w = opts.w or DEFAULTS.w
  local h = opts.h or DEFAULTS.h
  local direction = opts.direction or DEFAULTS.direction
  local spacing = opts.spacing or DEFAULTS.spacing
  local thickness = opts.thickness or DEFAULTS.thickness
  local color = opts.color or DEFAULTS.color
  local bg_color = opts.bg_color
  local offset = opts.offset or DEFAULTS.offset
  local use_clip = opts.use_clip ~= false
  local animate_speed = opts.animate_speed or DEFAULTS.animate_speed

  -- Handle auto-animation
  if animate_speed > 0 then
    local current_time = ImGui.GetTime(ctx)
    if anim_state.last_time > 0 then
      local dt = current_time - anim_state.last_time
      anim_state.offset = (anim_state.offset + dt * animate_speed) % spacing
    end
    anim_state.last_time = current_time
    offset = anim_state.offset
  end

  -- Get draw list
  local dl = opts.draw_list or ImGui.GetWindowDrawList(ctx)

  -- Draw background if specified
  if bg_color then
    ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, bg_color)
  end

  -- Push clip rect for clean edges
  if use_clip then
    ImGui.DrawList_PushClipRect(dl, x, y, x + w, y + h, true)
  end

  -- Draw pattern based on direction
  if direction == M.DIRECTION.FORWARD then
    draw_forward_lines(dl, x, y, w, h, spacing, offset, color, thickness)

  elseif direction == M.DIRECTION.BACKWARD then
    draw_backward_lines(dl, x, y, w, h, spacing, offset, color, thickness)

  elseif direction == M.DIRECTION.BOTH then
    draw_forward_lines(dl, x, y, w, h, spacing, offset, color, thickness)
    draw_backward_lines(dl, x, y, w, h, spacing, offset, color, thickness)

  elseif direction == M.DIRECTION.HORIZONTAL then
    draw_horizontal_lines(dl, x, y, w, h, spacing, offset, color, thickness)

  elseif direction == M.DIRECTION.VERTICAL then
    draw_vertical_lines(dl, x, y, w, h, spacing, offset, color, thickness)
  end

  -- Pop clip rect
  if use_clip then
    ImGui.DrawList_PopClipRect(dl)
  end

  return { width = w, height = h }
end

--- Draw hatched fill with glow/overflow effect (the original 'glitch' effect)
--- This intentionally lets lines escape bounds for a cool visual effect
--- @param ctx userdata ImGui context
--- @param opts table Options: x, y, w, h, direction, spacing, thickness, color, overflow, glow_layers
--- @return table Result { width, height }
function M.draw_overflow(ctx, opts)
  opts = opts or {}

  local x = opts.x or DEFAULTS.x
  local y = opts.y or DEFAULTS.y
  local w = opts.w or DEFAULTS.w
  local h = opts.h or DEFAULTS.h
  local direction = opts.direction or DEFAULTS.direction
  local spacing = opts.spacing or DEFAULTS.spacing
  local thickness = opts.thickness or DEFAULTS.thickness
  local color = opts.color or DEFAULTS.color
  local overflow = opts.overflow or 20  -- How far lines extend beyond bounds
  local glow_layers = opts.glow_layers or 3

  local dl = opts.draw_list or ImGui.GetWindowDrawList(ctx)

  -- Draw multiple layers with decreasing alpha for glow effect
  for layer = glow_layers, 1, -1 do
    local layer_overflow = overflow * (layer / glow_layers)
    local layer_alpha = math.floor(((color & 0xFF) / glow_layers) * (glow_layers - layer + 1))
    local layer_color = (color & 0xFFFFFF00) | layer_alpha
    local layer_thickness = thickness + (layer - 1) * 0.5

    local ox = x - layer_overflow
    local oy = y - layer_overflow
    local ow = w + layer_overflow * 2
    local oh = h + layer_overflow * 2

    if direction == M.DIRECTION.FORWARD or direction == M.DIRECTION.BOTH then
      draw_forward_lines(dl, ox, oy, ow, oh, spacing, 0, layer_color, layer_thickness)
    end
    if direction == M.DIRECTION.BACKWARD or direction == M.DIRECTION.BOTH then
      draw_backward_lines(dl, ox, oy, ow, oh, spacing, 0, layer_color, layer_thickness)
    end
  end

  return { width = w, height = h }
end

--- Draw animated 'marching ants' style dashed border
--- @param ctx userdata ImGui context
--- @param opts table Options: x, y, w, h, dash_length, gap_length, color, thickness, speed
--- @return table Result { width, height }
function M.draw_marching_ants(ctx, opts)
  opts = opts or {}

  local x = opts.x or DEFAULTS.x
  local y = opts.y or DEFAULTS.y
  local w = opts.w or DEFAULTS.w
  local h = opts.h or DEFAULTS.h
  local dash = opts.dash_length or 4
  local gap = opts.gap_length or 4
  local color = opts.color or DEFAULTS.color
  local thickness = opts.thickness or 1
  local speed = opts.speed or 30  -- Pixels per second

  local dl = opts.draw_list or ImGui.GetWindowDrawList(ctx)

  -- Calculate offset based on time
  local pattern_length = dash + gap
  local offset = (ImGui.GetTime(ctx) * speed) % pattern_length

  -- Draw top edge
  local i = -offset
  while i < w do
    local start_x = x + math.max(0, i)
    local end_x = x + math.min(w, i + dash)
    if end_x > start_x then
      ImGui.DrawList_AddLine(dl, start_x, y, end_x, y, color, thickness)
    end
    i = i + pattern_length
  end

  -- Draw right edge
  i = -offset
  while i < h do
    local start_y = y + math.max(0, i)
    local end_y = y + math.min(h, i + dash)
    if end_y > start_y then
      ImGui.DrawList_AddLine(dl, x + w, start_y, x + w, end_y, color, thickness)
    end
    i = i + pattern_length
  end

  -- Draw bottom edge (reverse direction)
  i = -offset
  while i < w do
    local start_x = x + w - math.max(0, i) - dash
    local end_x = x + w - math.max(0, i)
    start_x = math.max(x, start_x)
    if end_x > start_x then
      ImGui.DrawList_AddLine(dl, start_x, y + h, end_x, y + h, color, thickness)
    end
    i = i + pattern_length
  end

  -- Draw left edge (reverse direction)
  i = -offset
  while i < h do
    local start_y = y + h - math.max(0, i) - dash
    local end_y = y + h - math.max(0, i)
    start_y = math.max(y, start_y)
    if end_y > start_y then
      ImGui.DrawList_AddLine(dl, x, start_y, x, end_y, color, thickness)
    end
    i = i + pattern_length
  end

  return { width = w, height = h }
end

--- Draw the original 'glitch' effect with curved/exponential pattern
--- This recreates the buggy math that created the cool visual artifact
--- @param ctx userdata ImGui context
--- @param opts table Options: x, y, w, h, spacing, thickness, color, intensity, layers
--- @return table Result { width, height }
function M.draw_glitch(ctx, opts)
  opts = opts or {}

  local x = opts.x or DEFAULTS.x
  local y = opts.y or DEFAULTS.y
  local w = opts.w or DEFAULTS.w
  local h = opts.h or DEFAULTS.h
  local spacing = opts.spacing or DEFAULTS.spacing
  local thickness = opts.thickness or DEFAULTS.thickness
  local color = opts.color or DEFAULTS.color
  local intensity = opts.intensity or 1.0  -- Multiplier for the glitch effect
  local layers = opts.layers or 3
  local show_box = opts.show_box ~= false

  local dl = opts.draw_list or ImGui.GetWindowDrawList(ctx)

  -- Draw multiple layers for depth
  for layer = layers, 1, -1 do
    local layer_mult = layer / layers
    local layer_alpha = math.floor(((color & 0xFF) * layer_mult))
    local layer_color = (color & 0xFFFFFF00) | layer_alpha
    local layer_thickness = thickness + (layers - layer) * 0.3

    -- The original buggy forward diagonal pattern (↘)
    -- The 'bug' was in how endpoints were calculated, creating curved appearance
    for i = -h * intensity, w * intensity, spacing do
      -- Original buggy math that created the cool effect
      local x1 = math.max(x, x + i)
      local y1 = y + math.max(0, -i * layer_mult)
      local x2 = math.min(x + w, x + i + h * intensity)
      local y2 = y + math.min(h, h - i * layer_mult)

      -- Only draw if line has length
      if x2 > x1 then
        ImGui.DrawList_AddLine(dl, x1, y1, x2, y2, layer_color, layer_thickness)
      end
    end

    -- The original buggy backward diagonal pattern (↙)
    for i = -w * intensity, h * intensity, spacing do
      local x1 = x + math.max(0, -i * layer_mult)
      local y1 = math.max(y, y + i)
      local x2 = x + math.min(w, w + i * layer_mult)
      local y2 = math.min(y + h, y + i + w * intensity)

      if y2 > y1 then
        ImGui.DrawList_AddLine(dl, x1, y2, x2, y1, layer_color, layer_thickness)
      end
    end
  end

  -- Optional: draw the bounding box to show where the 'clean' area would be
  if show_box then
    local box_color = (color & 0xFFFFFF00) | 0x40
    ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, box_color, 0, 0, 1)
  end

  return { width = w, height = h }
end

--- Draw corner radial effect (lines emanating from a corner)
--- This recreates the exact visual from the WALTER screenshot
--- @param ctx userdata ImGui context
--- @param opts table Options: x, y, w, h, spacing, color, corner, layers, intensity
--- @return table Result { width, height }
function M.draw_corner_radial(ctx, opts)
  opts = opts or {}

  local x = opts.x or DEFAULTS.x
  local y = opts.y or DEFAULTS.y
  local w = opts.w or DEFAULTS.w
  local h = opts.h or DEFAULTS.h
  local spacing = opts.spacing or DEFAULTS.spacing
  local thickness = opts.thickness or DEFAULTS.thickness
  local color = opts.color or DEFAULTS.color
  local corner = opts.corner or 'bottom_right'  -- 'top_left', 'top_right', 'bottom_left', 'bottom_right'
  local layers = opts.layers or 4
  local intensity = opts.intensity or 1.5

  local dl = opts.draw_list or ImGui.GetWindowDrawList(ctx)

  -- Calculate corner position
  local cx, cy
  if corner == 'top_left' then
    cx, cy = x, y
  elseif corner == 'top_right' then
    cx, cy = x + w, y
  elseif corner == 'bottom_left' then
    cx, cy = x, y + h
  else -- bottom_right (default)
    cx, cy = x + w, y + h
  end

  -- Draw layers from back to front
  for layer = layers, 1, -1 do
    local layer_mult = layer / layers
    local layer_alpha = math.floor(((color & 0xFF) * layer_mult))
    local layer_color = (color & 0xFFFFFF00) | layer_alpha
    local layer_thickness = thickness + (layers - layer) * 0.3

    -- Calculate max distance from corner
    local max_dist = math.sqrt(w * w + h * h) * intensity

    -- Draw lines radiating from corner
    for dist = 0, max_dist, spacing do
      -- The 'buggy' effect comes from how endpoints are calculated
      local t = dist / max_dist

      if corner == 'bottom_right' then
        -- Lines go from bottom-right corner upward and leftward
        local x1 = cx - dist * layer_mult
        local y1 = cy
        local x2 = cx
        local y2 = cy - dist * layer_mult

        -- Also draw crossing lines for the mesh effect
        local x3 = math.max(x, cx - dist)
        local y3 = math.max(y, cy - dist * t * layer_mult)
        local x4 = math.max(x, cx - dist * t * layer_mult)
        local y4 = math.max(y, cy - dist)

        if x1 >= x and y2 >= y then
          ImGui.DrawList_AddLine(dl, x1, y1, x2, y2, layer_color, layer_thickness)
        end
        if x3 >= x and y3 >= y and x4 >= x and y4 >= y then
          ImGui.DrawList_AddLine(dl, x3, y3, x4, y4, layer_color, layer_thickness)
        end

      elseif corner == 'top_left' then
        local x1 = cx + dist * layer_mult
        local y1 = cy
        local x2 = cx
        local y2 = cy + dist * layer_mult

        local x3 = math.min(x + w, cx + dist)
        local y3 = math.min(y + h, cy + dist * t * layer_mult)
        local x4 = math.min(x + w, cx + dist * t * layer_mult)
        local y4 = math.min(y + h, cy + dist)

        if x1 <= x + w and y2 <= y + h then
          ImGui.DrawList_AddLine(dl, x1, y1, x2, y2, layer_color, layer_thickness)
        end
        if x3 <= x + w and y3 <= y + h and x4 <= x + w and y4 <= y + h then
          ImGui.DrawList_AddLine(dl, x3, y3, x4, y4, layer_color, layer_thickness)
        end

      elseif corner == 'top_right' then
        local x1 = cx - dist * layer_mult
        local y1 = cy
        local x2 = cx
        local y2 = cy + dist * layer_mult

        if x1 >= x and y2 <= y + h then
          ImGui.DrawList_AddLine(dl, x1, y1, x2, y2, layer_color, layer_thickness)
        end

      elseif corner == 'bottom_left' then
        local x1 = cx + dist * layer_mult
        local y1 = cy
        local x2 = cx
        local y2 = cy - dist * layer_mult

        if x1 <= x + w and y2 >= y then
          ImGui.DrawList_AddLine(dl, x1, y1, x2, y2, layer_color, layer_thickness)
        end
      end
    end
  end

  return { width = w, height = h }
end

--- Draw exponential curve pattern (variation of the glitch)
--- Creates a more pronounced curved/radial effect
--- @param ctx userdata ImGui context
--- @param opts table Options: x, y, w, h, spacing, color, curve_factor, layers
--- @return table Result { width, height }
function M.draw_curved(ctx, opts)
  opts = opts or {}

  local x = opts.x or DEFAULTS.x
  local y = opts.y or DEFAULTS.y
  local w = opts.w or DEFAULTS.w
  local h = opts.h or DEFAULTS.h
  local spacing = opts.spacing or 8
  local thickness = opts.thickness or 1
  local color = opts.color or DEFAULTS.color
  local curve_factor = opts.curve_factor or 2.0  -- How much curve (1=linear, 2+=exponential)
  local layers = opts.layers or 4
  local direction = opts.direction or 'both'  -- 'forward', 'backward', 'both'

  local dl = opts.draw_list or ImGui.GetWindowDrawList(ctx)

  for layer = layers, 1, -1 do
    local layer_mult = layer / layers
    local layer_alpha = math.floor(((color & 0xFF) * layer_mult))
    local layer_color = (color & 0xFFFFFF00) | layer_alpha

    local num_lines = math.floor((w + h) / spacing)

    for i = 0, num_lines do
      local t = i / num_lines  -- 0 to 1

      -- Apply exponential curve to the interpolation
      local curved_t = t ^ curve_factor

      if direction == 'forward' or direction == 'both' then
        -- Forward diagonal with curve
        local x1 = x + (w * curved_t) * layer_mult
        local y1 = y
        local x2 = x + w
        local y2 = y + (h * (1 - curved_t)) * layer_mult + h * (1 - layer_mult)

        ImGui.DrawList_AddLine(dl, x1, y1, x2, y2, layer_color, thickness)
      end

      if direction == 'backward' or direction == 'both' then
        -- Backward diagonal with curve
        local x1 = x
        local y1 = y + (h * curved_t) * layer_mult
        local x2 = x + (w * (1 - curved_t)) * layer_mult + w * (1 - layer_mult)
        local y2 = y + h

        ImGui.DrawList_AddLine(dl, x1, y1, x2, y2, layer_color, thickness)
      end
    end
  end

  return { width = w, height = h }
end

--- Helper to create color with alpha
--- @param base_color number Base color (RGBA)
--- @param alpha number Alpha value (0-255 or 0-1)
--- @return number Color with new alpha
function M.with_alpha(base_color, alpha)
  if alpha <= 1 then
    alpha = math.floor(alpha * 255)
  end
  return (base_color & 0xFFFFFF00) | (alpha & 0xFF)
end

return M
