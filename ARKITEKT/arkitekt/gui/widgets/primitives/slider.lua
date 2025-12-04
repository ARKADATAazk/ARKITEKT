-- @noindex
-- arkitekt/gui/widgets/primitives/slider.lua
-- Standardized slider widget with Arkitekt styling
-- Uses unified opts-based API with double-click to reset

local ImGui = require('arkitekt.core.imgui')
local Theme = require('arkitekt.theme')
local Colors = require('arkitekt.core.colors')
local Base = require('arkitekt.gui.widgets.base')

local M = {}

-- ============================================================================
-- HSV COLOR UTILITIES (for gradient sliders)
-- ============================================================================

--- Convert HSV to RGBA u32 color
--- @param h number Hue (0-1)
--- @param s number Saturation (0-1)
--- @param v number Value/brightness (0-1)
--- @param a number|nil Alpha (0-1, default 1)
--- @return number RGBA color as u32
local function hsv_to_rgba(h, s, v, a)
  local i = (h * 6) // 1
  local f = h * 6 - i
  local p = v * (1 - s)
  local q = v * (1 - f * s)
  local t = v * (1 - (1 - f) * s)
  local r, g, b
  i = i % 6
  if     i == 0 then r, g, b = v, t, p
  elseif i == 1 then r, g, b = q, v, p
  elseif i == 2 then r, g, b = p, v, t
  elseif i == 3 then r, g, b = p, q, v
  elseif i == 4 then r, g, b = t, p, v
  else               r, g, b = v, p, q
  end
  local R = (r * 255 + 0.5) // 1
  local G = (g * 255 + 0.5) // 1
  local B = (b * 255 + 0.5) // 1
  local A = math.floor((a or 1) * 255 + 0.5)
  return (R << 24) | (G << 16) | (B << 8) | A
end

-- ============================================================================
-- DEFAULTS
-- ============================================================================

local DEFAULTS = {
  -- Identity
  id = 'slider',

  -- Position (nil = use cursor)
  x = nil,
  y = nil,

  -- Size
  width = 200,
  height = 20,
  grab_width = 13,

  -- Value
  value = 0,
  min = 0,
  max = 100,
  default = nil,  -- Value to reset to on double-click
  step = nil,     -- Step for keyboard control (default: range/100)

  -- State
  is_disabled = false,

  -- Style
  rounding = 0,
  bg_color = nil,
  grab_color = nil,
  grab_hover_color = nil,
  grab_active_color = nil,
  border_color = nil,

  -- Content
  gradient_fn = nil,   -- Custom gradient rendering function
  tooltip_fn = nil,    -- Custom tooltip function
  format = '%.1f',     -- Value format string

  -- Callbacks
  on_change = nil,
  tooltip = nil,

  -- Cursor control
  advance = 'vertical',

  -- Draw list
  draw_list = nil,
}

-- ============================================================================
-- STATE MANAGEMENT
-- ============================================================================

local slider_locks = {}  -- Prevents double-click interference with drag

-- ============================================================================
-- RENDERING HELPERS
-- ============================================================================

local function render_slider_background(dl, x, y, w, h, config, gradient_fn)
  local bg_color = config.bg_color or 0x1A1A1AFF
  local border_color = config.border_color or 0x000000FF

  -- Background
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, bg_color, config.rounding or 0)

  -- Custom gradient if provided
  if gradient_fn then
    gradient_fn(dl, x + 1, y + 1, x + w - 1, y + h - 1, config)
  end

  -- Border
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, border_color, config.rounding or 0, 0, 1)
end

local function render_grab(dl, gx, y, h, grab_w, active, hovered, disabled, config)
  local x_left = Base.snap_pixel(gx - grab_w / 2)
  local x_right = Base.snap_pixel(gx + grab_w / 2)

  -- Determine grab color
  local grab_color
  if disabled then
    grab_color = Colors.WithOpacity(Colors.Desaturate(config.grab_color or 0x383C45FF, 0.5), 0.5)
  elseif active then
    grab_color = config.grab_active_color or 0x585C65FF
  elseif hovered then
    grab_color = config.grab_hover_color or 0x484C55FF
  else
    grab_color = config.grab_color or 0x383C45FF
  end

  -- Shadow
  if not disabled then
    ImGui.DrawList_AddRectFilled(dl, x_left + 1, y + 1, x_right + 1, y + h + 1,
      0x00000050, 0)
  end

  -- Grab body
  ImGui.DrawList_AddRectFilled(dl, x_left, y, x_right, y + h, grab_color, 0)

  -- Border
  ImGui.DrawList_AddRect(dl, x_left, y, x_right, y + h, 0x000000FF, 0, 0, 1)
end

-- ============================================================================
-- PUBLIC API (Standardized)
-- ============================================================================

--- Draw a slider widget
--- Supports both positional and opts-based parameters:
--- - Positional: Ark.Slider(ctx, label, value, min, max)
--- - Opts table: Ark.Slider(ctx, {label = '...', value = 50, min = 0, max = 100, ...})
--- @param ctx userdata ImGui context
--- @param label_or_opts string|table Label string or opts table
--- @param value number|nil Current value (positional only)
--- @param min number|nil Minimum value (positional only)
--- @param max number|nil Maximum value (positional only)
--- @return table Result { changed, value, width, height, hovered, active }
function M.Draw(ctx, label_or_opts, value, min, max)
  -- Hybrid parameter detection
  local opts
  if type(label_or_opts) == 'table' then
    -- Opts table passed directly
    opts = label_or_opts
  elseif type(label_or_opts) == 'string' then
    -- Positional params - map to opts
    opts = {
      label = label_or_opts,
      value = value,
      min = min,
      max = max,
    }
  else
    -- No params or just ctx - empty opts
    opts = {}
  end

  opts = Base.parse_opts(opts, DEFAULTS)

  -- Resolve unique ID
  local unique_id = Base.resolve_id(ctx, opts, 'slider')

  -- Get position and draw list
  local x, y = Base.get_position(ctx, opts)
  local dl = Base.get_draw_list(ctx, opts)

  -- Get size
  local w = opts.width or 200
  local h = opts.height or 20
  local grab_w = opts.grab_width or 13

  -- Get value range
  local min_val = opts.min or 0
  local max_val = opts.max or 100
  local default_val = opts.default or min_val
  local value = Base.clamp(opts.value or default_val, min_val, max_val)

  -- State
  local actx = Base.get_context(ctx)
  local disabled = opts.is_disabled or actx:is_disabled()
  local changed = false

  -- Create invisible button for interaction
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, '##' .. unique_id, w, h)

  local hovered = not disabled and ImGui.IsItemHovered(ctx)
  local active = not disabled and ImGui.IsItemActive(ctx)

  -- Check for lock (prevents double-click drag interference)
  local now = ImGui.GetTime(ctx)
  local locked = (slider_locks[unique_id] or 0) > now

  -- Double-click to reset
  if hovered and not locked and ImGui.IsMouseDoubleClicked(ctx, 0) then
    value = default_val
    changed = true
    slider_locks[unique_id] = now + 0.3
  end

  -- Drag to adjust
  if not locked and active and not ImGui.IsMouseDoubleClicked(ctx, 0) then
    local mx = select(1, ImGui.GetMousePos(ctx))
    local t = Base.clamp((mx - x) / w, 0, 1)
    local new_value = min_val + t * (max_val - min_val)
    if math.abs(new_value - value) > 1e-6 then
      value = new_value
      changed = true
    end
  end

  -- Keyboard control
  if not disabled and (ImGui.IsItemFocused(ctx) or active) then
    local step = opts.step or (max_val - min_val) / 100
    if ImGui.IsKeyPressed(ctx, ImGui.Key_LeftArrow, false) then
      value = Base.clamp(value - step, min_val, max_val)
      changed = true
    end
    if ImGui.IsKeyPressed(ctx, ImGui.Key_RightArrow, false) then
      value = Base.clamp(value + step, min_val, max_val)
      changed = true
    end
  end

  -- Ensure value is clamped
  value = Base.clamp(value, min_val, max_val)

  -- Render slider background
  render_slider_background(dl, x, y, w, h, opts, opts.gradient_fn)

  -- Calculate grab position
  local t = (value - min_val) / (max_val - min_val)
  local gx = Base.clamp(x + t * w, x + grab_w / 2, x + w - grab_w / 2)
  gx = Base.snap_pixel(gx)

  -- Render grab
  render_grab(dl, gx, y, h, grab_w, active, hovered, disabled, opts)

  -- Tooltip
  if hovered then
    local tooltip_text
    if opts.tooltip_fn then
      tooltip_text = opts.tooltip_fn(value)
    elseif opts.tooltip then
      tooltip_text = opts.tooltip
    else
      tooltip_text = string.format(opts.format or '%.1f', value)
    end

    if ImGui.BeginTooltip(ctx) then
      ImGui.Text(ctx, tooltip_text)
      ImGui.EndTooltip(ctx)
    end
  end

  -- Call change callback
  if changed and opts.on_change then
    opts.on_change(value)
  end

  -- Advance cursor
  Base.advance_cursor(ctx, x, y, w, h, opts.advance)

  -- Return standardized result
  return Base.create_result({
    changed = changed,
    value = value,
    width = w,
    height = h,
    hovered = hovered,
    active = active,
  })
end

--- Draw a percentage slider (0-100)
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result
function M.Percent(ctx, opts)
  opts = opts or {}
  opts.min = opts.min or 0
  opts.max = opts.max or 100
  opts.format = opts.format or '%.0f%%'
  opts.tooltip_fn = opts.tooltip_fn or function(v)
    return string.format('%.0f%%', v)
  end
  return M.Draw(ctx, opts)
end

--- Draw an integer slider
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result
function M.Int(ctx, opts)
  opts = opts or {}
  opts.step = opts.step or 1
  opts.format = opts.format or '%.0f'

  local result = M.Draw(ctx, opts)
  result.value = (result.value + 0.5) // 1  -- Round to integer
  return result
end

-- ============================================================================
-- GRADIENT GENERATORS
-- ============================================================================

local GRADIENT_SEGMENTS = 120  -- Number of segments for smooth gradients

--- Create a hue gradient function
--- @param saturation number|nil Saturation 0-100 (default 75)
--- @param brightness number|nil Brightness 0-100 (default 80)
--- @return function Gradient function for slider
local function create_hue_gradient(saturation, brightness)
  local sat = Base.clamp(saturation or 75, 0, 100) / 100.0
  local val = Base.clamp(brightness or 80, 0, 100) / 100.0

  return function(dl, x0, y0, x1, y1)
    local w = x1 - x0
    local seg_w = w / GRADIENT_SEGMENTS

    for i = 0, GRADIENT_SEGMENTS - 1 do
      local t0 = i / GRADIENT_SEGMENTS
      local t1 = (i + 1) / GRADIENT_SEGMENTS
      local c0 = hsv_to_rgba(t0, sat, val, 1)
      local c1 = hsv_to_rgba(t1, sat, val, 1)

      -- Slight desaturation and brightness adjustment for better visibility
      c0 = Colors.Desaturate(c0, 0.10)
      c1 = Colors.Desaturate(c1, 0.10)
      c0 = Colors.AdjustBrightness(c0, 0.88)
      c1 = Colors.AdjustBrightness(c1, 0.88)

      local sx0 = x0 + i * seg_w
      local sx1 = x0 + (i + 1) * seg_w
      ImGui.DrawList_AddRectFilledMultiColor(dl, sx0, y0, sx1, y1, c0, c1, c1, c0)
    end
  end
end

--- Create a saturation gradient function
--- @param base_hue number Base hue in degrees (0-360)
--- @param brightness number|nil Brightness 0-100 (default 80)
--- @return function Gradient function for slider
local function create_saturation_gradient(base_hue, brightness)
  local h = ((base_hue or 210) % 360) / 360.0
  local val = Base.clamp(brightness or 80, 0, 100) / 100.0

  return function(dl, x0, y0, x1, y1)
    local w = x1 - x0
    local seg_w = w / GRADIENT_SEGMENTS

    for i = 0, GRADIENT_SEGMENTS - 1 do
      local t0 = i / GRADIENT_SEGMENTS
      local t1 = (i + 1) / GRADIENT_SEGMENTS
      local c0 = hsv_to_rgba(h, t0, val, 1)
      local c1 = hsv_to_rgba(h, t1, val, 1)

      c0 = Colors.AdjustBrightness(c0, 0.88)
      c1 = Colors.AdjustBrightness(c1, 0.88)

      local sx0 = x0 + i * seg_w
      local sx1 = x0 + (i + 1) * seg_w
      ImGui.DrawList_AddRectFilledMultiColor(dl, sx0, y0, sx1, y1, c0, c1, c1, c0)
    end
  end
end

--- Create a brightness/grayscale gradient function
--- @return function Gradient function for slider
local function create_brightness_gradient()
  return function(dl, x0, y0, x1, y1)
    local w = x1 - x0
    local seg_w = w / GRADIENT_SEGMENTS

    for i = 0, GRADIENT_SEGMENTS - 1 do
      local t0 = i / GRADIENT_SEGMENTS
      local t1 = (i + 1) / GRADIENT_SEGMENTS

      local gray0 = (t0 * 255 + 0.5) // 1
      local gray1 = (t1 * 255 + 0.5) // 1

      local c0 = (gray0 << 24) | (gray0 << 16) | (gray0 << 8) | 0xFF
      local c1 = (gray1 << 24) | (gray1 << 16) | (gray1 << 8) | 0xFF

      c0 = Colors.AdjustBrightness(c0, 0.88)
      c1 = Colors.AdjustBrightness(c1, 0.88)

      local sx0 = x0 + i * seg_w
      local sx1 = x0 + (i + 1) * seg_w
      ImGui.DrawList_AddRectFilledMultiColor(dl, sx0, y0, sx1, y1, c0, c1, c1, c0)
    end
  end
end

-- ============================================================================
-- COLOR SLIDER VARIANTS
-- ============================================================================

--- Draw a hue slider (0-360 degrees)
--- @param ctx userdata ImGui context
--- @param opts table Widget options (value = hue in degrees)
---   - saturation: Gradient saturation 0-100 (default 75)
---   - brightness: Gradient brightness 0-100 (default 80)
--- @return table Result { changed, value (hue 0-360), ... }
function M.Hue(ctx, opts)
  opts = opts or {}
  opts.min = 0
  opts.max = 359.999
  opts.default = opts.default or 180
  opts.gradient_fn = create_hue_gradient(opts.saturation, opts.brightness)
  opts.tooltip_fn = opts.tooltip_fn or function(v)
    return string.format('Hue: %.1f°', v)
  end
  return M.Draw(ctx, opts)
end

--- Draw a saturation slider (0-100%)
--- @param ctx userdata ImGui context
--- @param opts table Widget options (value = saturation 0-100)
---   - base_hue: Hue for gradient in degrees (default 210)
---   - brightness: Gradient brightness 0-100 (default 80)
--- @return table Result { changed, value (saturation 0-100), ... }
function M.Saturation(ctx, opts)
  opts = opts or {}
  opts.min = 0
  opts.max = 100
  opts.default = opts.default or 50
  opts.gradient_fn = create_saturation_gradient(opts.base_hue, opts.brightness)
  opts.tooltip_fn = opts.tooltip_fn or function(v)
    return string.format('Saturation: %.0f%%', v)
  end
  return M.Draw(ctx, opts)
end

--- Draw a brightness slider (0-100%)
--- @param ctx userdata ImGui context
--- @param opts table Widget options (value = brightness 0-100)
--- @return table Result { changed, value (brightness 0-100), ... }
function M.Brightness(ctx, opts)
  opts = opts or {}
  opts.min = 0
  opts.max = 100
  opts.default = opts.default or 50
  opts.gradient_fn = create_brightness_gradient()
  opts.tooltip_fn = opts.tooltip_fn or function(v)
    return string.format('Brightness: %.0f%%', v)
  end
  return M.Draw(ctx, opts)
end

-- Alias for backwards compatibility with hue_slider.draw_gamma
M.Gamma = M.Brightness

-- ============================================================================
-- ALTERNATIVE SIGNATURE API
-- Signature: DrawHue(ctx, id, value, opt) -> changed, new_value
-- ============================================================================

--- Hue slider with positional parameters
--- @param ctx userdata ImGui context
--- @param id string Slider ID
--- @param value number Hue value (0-360)
--- @param opt table|nil Options (w, h, default, saturation, brightness)
--- @return boolean, number changed, new_value
function M.DrawHue(ctx, id, value, opt)
  opt = opt or {}
  local result = M.Hue(ctx, {
    id = id,
    value = value,
    width = opt.w,
    height = opt.h,
    default = opt.default,
    saturation = opt.saturation,
    brightness = opt.brightness,
  })
  return result.changed, result.value
end

--- Saturation slider with positional parameters
--- @param ctx userdata ImGui context
--- @param id string Slider ID
--- @param value number Saturation value (0-100)
--- @param base_hue number|nil Base hue in degrees
--- @param opt table|nil Options (w, h, default, brightness)
--- @return boolean, number changed, new_value
function M.DrawSaturation(ctx, id, value, base_hue, opt)
  opt = opt or {}
  local result = M.Saturation(ctx, {
    id = id,
    value = value,
    base_hue = base_hue,
    width = opt.w,
    height = opt.h,
    default = opt.default,
    brightness = opt.brightness,
  })
  return result.changed, result.value
end

--- Brightness/gamma slider with positional parameters
--- @param ctx userdata ImGui context
--- @param id string Slider ID
--- @param value number Brightness value (0-100)
--- @param opt table|nil Options (w, h, default)
--- @return boolean, number changed, new_value
function M.DrawGamma(ctx, id, value, opt)
  opt = opt or {}
  local result = M.Brightness(ctx, {
    id = id,
    value = value,
    width = opt.w,
    height = opt.h,
    default = opt.default,
  })
  return result.changed, result.value
end

-- ============================================================================
-- MODULE EXPORT (Callable)
-- ============================================================================

-- Make module callable: Ark.Slider(ctx, ...) → M.Draw(ctx, ...)
return setmetatable(M, {
  __call = function(_, ctx, ...)
    local result = M.Draw(ctx, ...)

    -- Detect mode: positional (string label) vs opts (table)
    local first_arg = select(1, ...)
    if type(first_arg) == 'string' then
      -- Positional mode: Return ImGui-compatible tuple (changed, value)
      return result.changed, result.value
    else
      -- Opts mode: Return full result table
      return result
    end
  end
})
