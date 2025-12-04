-- @noindex
-- arkitekt/gui/widgets/experimental/transport.lua
-- EXPERIMENTAL: Transport controls for play/stop/record/loop
-- Common transport buttons for media players and audio applications

local ImGui = require('arkitekt.core.imgui')
local Theme = require('arkitekt.theme')
local Colors = require('arkitekt.core.colors')
local Base = require('arkitekt.gui.widgets.base')

local M = {}

-- ============================================================================
-- CONSTANTS
-- ============================================================================

-- Transport states
M.STATE_STOPPED = 0
M.STATE_PLAYING = 1
M.STATE_PAUSED = 2
M.STATE_RECORDING = 3

-- Performance: Cache ImGui functions
local DrawList_AddTriangleFilled = ImGui.DrawList_AddTriangleFilled
local DrawList_AddRectFilled = ImGui.DrawList_AddRectFilled
local DrawList_AddCircleFilled = ImGui.DrawList_AddCircleFilled

-- ============================================================================
-- DEFAULTS
-- ============================================================================

local DEFAULTS = {
  -- Identity
  id = nil,

  -- Position (nil = use cursor)
  x = nil,
  y = nil,

  -- Button configuration
  buttons = nil,           -- Array of button types: {"play", "stop", "record", "loop", "rewind", "forward"}
                          -- nil = default set {"play", "stop", "record"}

  -- State
  state = M.STATE_STOPPED, -- Current playback state
  is_loop_enabled = false, -- Loop button state
  disabled = false,

  -- Style
  button_size = 32,        -- Button diameter
  button_spacing = 4,      -- Spacing between buttons
  icon_scale = 0.5,        -- Icon size relative to button (0-1)

  -- Colors
  color_normal = nil,      -- Normal button color
  color_active = nil,      -- Active button color (playing/recording)
  color_hover = nil,       -- Hover state color
  color_disabled = nil,    -- Disabled button color
  bg_color = nil,          -- Background color (optional)

  -- Specific button colors
  color_play = nil,        -- Play button active color (green)
  color_record = nil,      -- Record button active color (red)
  color_loop = nil,        -- Loop button active color (blue)

  -- Callbacks
  on_play = nil,           -- function() - called when play is pressed
  on_stop = nil,           -- function() - called when stop is pressed
  on_pause = nil,          -- function() - called when pause is pressed
  on_record = nil,         -- function() - called when record is pressed
  on_loop = nil,           -- function(enabled) - called when loop is toggled
  on_rewind = nil,         -- function() - called when rewind is pressed
  on_forward = nil,        -- function() - called when forward is pressed

  -- Cursor control
  advance = "vertical",

  -- Draw list
  draw_list = nil,
}

-- Default button set
local DEFAULT_BUTTONS = {"play", "stop", "record"}

-- ============================================================================
-- ICON RENDERING
-- ============================================================================

--- Draw play icon (triangle)
local function draw_play_icon(dl, cx, cy, size, color)
  local offset = size / 6  -- Shift right slightly
  local h = size * 0.7
  local w = h * 0.866  -- Equilateral triangle ratio

  local x1 = cx - w/3 + offset
  local y1 = cy - h/2
  local x2 = cx - w/3 + offset
  local y2 = cy + h/2
  local x3 = cx + w * 2/3 + offset
  local y3 = cy

  DrawList_AddTriangleFilled(dl, x1, y1, x2, y2, x3, y3, color)
end

--- Draw stop icon (square)
local function draw_stop_icon(dl, cx, cy, size, color)
  local s = size * 0.6
  local x1 = cx - s/2
  local y1 = cy - s/2
  local x2 = cx + s/2
  local y2 = cy + s/2

  DrawList_AddRectFilled(dl, x1, y1, x2, y2, color, 0)
end

--- Draw pause icon (two bars)
local function draw_pause_icon(dl, cx, cy, size, color)
  local bar_width = size * 0.2
  local bar_height = size * 0.7
  local gap = size * 0.15

  local x1 = cx - gap - bar_width
  local y1 = cy - bar_height/2
  DrawList_AddRectFilled(dl, x1, y1, x1 + bar_width, y1 + bar_height, color, 0)

  local x2 = cx + gap
  DrawList_AddRectFilled(dl, x2, y1, x2 + bar_width, y1 + bar_height, color, 0)
end

--- Draw record icon (circle)
local function draw_record_icon(dl, cx, cy, size, color)
  local radius = size * 0.35
  DrawList_AddCircleFilled(dl, cx, cy, radius, color, 16)
end

--- Draw loop icon (circular arrow approximation)
local function draw_loop_icon(dl, cx, cy, size, color)
  -- Simplified loop: two curved lines forming a circle
  -- Using rectangles to approximate circular arrows
  local radius = size * 0.35
  local thickness = size * 0.15

  -- Top arc
  DrawList_AddRectFilled(dl, cx - radius, cy - radius, cx + radius, cy - radius + thickness, color, thickness/2)
  -- Bottom arc
  DrawList_AddRectFilled(dl, cx - radius, cy + radius - thickness, cx + radius, cy + radius, color, thickness/2)
  -- Left side
  DrawList_AddRectFilled(dl, cx - radius, cy - radius, cx - radius + thickness, cy, color, 0)
  -- Right side
  DrawList_AddRectFilled(dl, cx + radius - thickness, cy, cx + radius, cy + radius, color, 0)
end

--- Draw rewind icon (double left triangle)
local function draw_rewind_icon(dl, cx, cy, size, color)
  local h = size * 0.6
  local w = h * 0.6
  local gap = size * 0.1

  -- Right triangle
  local x1 = cx + gap
  local y1 = cy - h/2
  local x2 = cx + gap
  local y2 = cy + h/2
  local x3 = cx + gap - w
  local y3 = cy
  DrawList_AddTriangleFilled(dl, x1, y1, x2, y2, x3, y3, color)

  -- Left triangle
  x1 = cx - gap
  x2 = cx - gap
  x3 = cx - gap - w
  DrawList_AddTriangleFilled(dl, x1, y1, x2, y2, x3, y3, color)
end

--- Draw forward icon (double right triangle)
local function draw_forward_icon(dl, cx, cy, size, color)
  local h = size * 0.6
  local w = h * 0.6
  local gap = size * 0.1

  -- Left triangle
  local x1 = cx - gap
  local y1 = cy - h/2
  local x2 = cx - gap
  local y2 = cy + h/2
  local x3 = cx - gap + w
  local y3 = cy
  DrawList_AddTriangleFilled(dl, x1, y1, x2, y2, x3, y3, color)

  -- Right triangle
  x1 = cx + gap
  x2 = cx + gap
  x3 = cx + gap + w
  DrawList_AddTriangleFilled(dl, x1, y1, x2, y2, x3, y3, color)
end

-- ============================================================================
-- BUTTON RENDERING
-- ============================================================================

--- Render single transport button
local function render_button(ctx, dl, button_type, x, y, size, opts, unique_id)
  local cx = x + size / 2
  local cy = y + size / 2
  local radius = size / 2

  -- Determine button state
  local is_active = false
  local is_toggled = false

  if button_type == "play" then
    is_active = (opts.state == M.STATE_PLAYING)
  elseif button_type == "record" then
    is_active = (opts.state == M.STATE_RECORDING)
  elseif button_type == "loop" then
    is_toggled = opts.is_loop_enabled
  end

  -- Get button background color
  local bg_color
  if is_active then
    if button_type == "play" then
      bg_color = opts.color_play or 0x33DD55FF
    elseif button_type == "record" then
      bg_color = opts.color_record or 0xDD3333FF
    else
      bg_color = opts.color_active or Theme.COLORS.ACCENT_PRIMARY
    end
  elseif is_toggled then
    bg_color = opts.color_loop or 0x3366DDFF
  else
    bg_color = opts.color_normal or Colors.WithOpacity(Theme.COLORS.BG_BASE, 0.5)
  end

  -- Draw button background (circle)
  DrawList_AddCircleFilled(dl, cx, cy, radius, bg_color, 24)

  -- Interaction
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, "##" .. unique_id .. "_" .. button_type, size, size)

  local hovered = ImGui.IsItemHovered(ctx)
  local clicked = ImGui.IsItemClicked(ctx, ImGui.MouseButton_Left)

  -- Hover highlight
  if hovered and not opts.disabled then
    local hover_color = opts.color_hover or Colors.WithOpacity(Theme.COLORS.TEXT_NORMAL, 0.1)
    DrawList_AddCircleFilled(dl, cx, cy, radius, hover_color, 24)
  end

  -- Draw icon
  local icon_size = size * (opts.icon_scale or 0.5)
  local icon_color = Theme.COLORS.TEXT_NORMAL or 0xFFFFFFFF

  if button_type == "play" then
    if opts.state == M.STATE_PAUSED then
      draw_play_icon(dl, cx, cy, icon_size, icon_color)
    else
      draw_play_icon(dl, cx, cy, icon_size, icon_color)
    end
  elseif button_type == "stop" then
    draw_stop_icon(dl, cx, cy, icon_size, icon_color)
  elseif button_type == "pause" then
    draw_pause_icon(dl, cx, cy, icon_size, icon_color)
  elseif button_type == "record" then
    draw_record_icon(dl, cx, cy, icon_size, icon_color)
  elseif button_type == "loop" then
    draw_loop_icon(dl, cx, cy, icon_size, icon_color)
  elseif button_type == "rewind" then
    draw_rewind_icon(dl, cx, cy, icon_size, icon_color)
  elseif button_type == "forward" then
    draw_forward_icon(dl, cx, cy, icon_size, icon_color)
  end

  -- Handle clicks
  if clicked and not opts.disabled then
    if button_type == "play" and opts.on_play then
      opts.on_play()
    elseif button_type == "stop" and opts.on_stop then
      opts.on_stop()
    elseif button_type == "pause" and opts.on_pause then
      opts.on_pause()
    elseif button_type == "record" and opts.on_record then
      opts.on_record()
    elseif button_type == "loop" and opts.on_loop then
      opts.on_loop(not opts.is_loop_enabled)
    elseif button_type == "rewind" and opts.on_rewind then
      opts.on_rewind()
    elseif button_type == "forward" and opts.on_forward then
      opts.on_forward()
    end
  end

  return clicked
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Draw transport controls
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result { clicked, button_type, width, height }
function M.draw(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)

  -- Resolve unique ID
  local unique_id = Base.resolve_id(ctx, opts, "transport")

  -- Get button set
  local buttons = opts.buttons or DEFAULT_BUTTONS

  -- Get position and draw list
  local x, y = Base.get_position(ctx, opts)
  local dl = Base.get_draw_list(ctx, opts)

  -- Get size
  local button_size = opts.button_size or 32
  local button_spacing = opts.button_spacing or 4
  local total_width = (#buttons * button_size) + ((#buttons - 1) * button_spacing)
  local total_height = button_size

  -- Background (optional)
  if opts.bg_color then
    ImGui.DrawList_AddRectFilled(dl, x, y, x + total_width, y + total_height, opts.bg_color, 4)
  end

  -- Render buttons
  local clicked = false
  local clicked_button = nil

  for i, button_type in ipairs(buttons) do
    local button_x = x + (i - 1) * (button_size + button_spacing)
    local button_clicked = render_button(ctx, dl, button_type, button_x, y, button_size, opts, unique_id)

    if button_clicked then
      clicked = true
      clicked_button = button_type
    end
  end

  -- Advance cursor
  Base.advance_cursor(ctx, x, y, total_width, total_height, opts.advance)

  -- Return standardized result
  return Base.create_result({
    clicked = clicked,
    button = clicked_button,
    width = total_width,
    height = total_height,
  })
end

-- ============================================================================
-- CONVENIENCE CONSTRUCTORS
-- ============================================================================

--- Standard transport (play, stop, record)
function M.standard(ctx, opts)
  opts = opts or {}
  opts.buttons = {"play", "stop", "record"}
  return M.draw(ctx, opts)
end

--- Full transport (all buttons)
function M.full(ctx, opts)
  opts = opts or {}
  opts.buttons = {"rewind", "stop", "play", "record", "forward", "loop"}
  return M.draw(ctx, opts)
end

--- Minimal transport (play, stop)
function M.minimal(ctx, opts)
  opts = opts or {}
  opts.buttons = {"play", "stop"}
  return M.draw(ctx, opts)
end

-- ============================================================================
-- MODULE EXPORT (Callable)
-- ============================================================================

-- Make module callable: Ark.Transport(ctx, ...) → M.draw(ctx, ...)
return setmetatable(M, {
  __call = function(_, ctx, ...)
    return M.draw(ctx, ...)
  end
})
