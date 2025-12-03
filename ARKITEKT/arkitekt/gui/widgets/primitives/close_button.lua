-- @noindex
-- arkitekt/gui/widgets/primitives/close_button.lua
-- Floating close button that appears on hover with proximity-based fade

local ImGui = require('arkitekt.core.imgui')
local Base = require('arkitekt.gui.widgets.base')
local Draw = require('arkitekt.gui.draw.primitives')
local Colors = require('arkitekt.core.colors')

local M = {}
-- ============================================================================
-- DEFAULTS
-- ============================================================================

local DEFAULTS = {
  -- Identity
  id = 'close_button',

  -- Position (required - where to place the button)
  x = nil,        -- Container left edge
  y = nil,        -- Container top edge
  width = nil,    -- Container width (button placed at right edge)
  height = nil,   -- Container height (not used, button at top)

  -- Size
  size = 32,
  margin = 16,
  proximity_distance = 150,

  -- Colors
  bg_color = nil,            -- nil = use default #000000
  bg_opacity = 0.6,
  bg_opacity_hover = 0.8,
  icon_color = nil,          -- nil = use default #FFFFFF
  icon_opacity = 0.8,
  hover_color = nil,         -- nil = use default #FF4444
  active_color = nil,        -- nil = use default #FF0000

  -- Callbacks
  on_click = nil,

  -- Cursor control
  advance = 'none',
}

-- ============================================================================
-- INSTANCE MANAGEMENT
-- ============================================================================

local instances = Base.create_instance_registry()

local function create_alpha_tracker(speed)
  return {
    current = 0.0,
    target = 0.0,
    speed = speed or 12.0,
    set_target = function(self, t)
      self.target = t
    end,
    update = function(self, dt)
      local diff = self.target - self.current
      if math.abs(diff) < 0.005 then
        self.current = self.target
      else
        local alpha = 1.0 - math.exp(-self.speed * dt)
        self.current = self.current + diff * alpha
      end
    end,
    value = function(self)
      return math.max(0.0, math.min(1.0, self.current))
    end
  }
end

local CloseButton = {}
CloseButton.__index = CloseButton

function CloseButton.new(id)
  return setmetatable({
    id = id,
    alpha = create_alpha_tracker(12.0),
    hover_alpha = create_alpha_tracker(16.0),
  }, CloseButton)
end

-- ============================================================================
-- RENDERING
-- ============================================================================

local function render_close_button(ctx, config, instance)
  local dt = ImGui.GetDeltaTime(ctx)

  -- Get bounds from config
  local bounds_x = config.x or 0
  local bounds_y = config.y or 0
  local bounds_w = config.width or 200
  local size = config.size
  local margin = config.margin
  local proximity_distance = config.proximity_distance

  -- Calculate button position (top-right of bounds)
  local button_x = bounds_x + bounds_w - margin - size
  local button_y = bounds_y + margin

  -- Calculate mouse proximity
  local mx, my = ImGui.GetMousePos(ctx)
  local dx = mx - (button_x + size / 2)
  local dy = my - (button_y + size / 2)
  local distance = math.sqrt(dx * dx + dy * dy)

  -- Update proximity alpha
  if distance < proximity_distance then
    instance.alpha:set_target(1.0)
  else
    instance.alpha:set_target(0.0)
  end
  instance.alpha:update(dt)
  instance.hover_alpha:update(dt)

  local alpha = instance.alpha:value()
  if alpha < 0.01 then
    return false, false  -- Not visible, not clicked
  end

  -- Check hover (only when sufficiently visible)
  local is_hovered = false
  local clicked = false

  if alpha > 0.8 then
    ImGui.SetCursorScreenPos(ctx, button_x, button_y)
    if ImGui.InvisibleButton(ctx, '##' .. instance.id, size, size) then
      clicked = true
    end
    is_hovered = ImGui.IsItemHovered(ctx)
  end

  -- Update hover alpha
  if is_hovered then
    instance.hover_alpha:set_target(1.0)
  else
    instance.hover_alpha:set_target(0.0)
  end
  local hover_alpha = instance.hover_alpha:value()

  -- Get colors with defaults
  local bg_color = config.bg_color or 0x000000FF
  local icon_color = config.icon_color or 0xFFFFFFFF
  local hover_color = config.hover_color or 0xFF4444FF
  local active_color = config.active_color or 0xFF0000FF

  -- Calculate final colors
  local bg_opacity = config.bg_opacity + (config.bg_opacity_hover - config.bg_opacity) * hover_alpha
  local final_bg = Colors.WithAlpha(bg_color, (255 * bg_opacity * alpha) // 1)

  local final_icon = icon_color
  if hover_alpha > 0.5 then
    final_icon = hover_color
  end
  if ImGui.IsMouseDown(ctx, ImGui.MouseButton_Left) and is_hovered then
    final_icon = active_color
  end
  final_icon = Colors.WithAlpha(final_icon, (255 * config.icon_opacity * alpha) // 1)

  -- Draw button
  local dl = ImGui.GetWindowDrawList(ctx)
  local corner_radius = size / 2

  Draw.RectFilled(dl, button_x, button_y, button_x + size, button_y + size, final_bg, corner_radius)

  -- Draw X icon
  local center_x = button_x + size / 2
  local center_y = button_y + size / 2
  local cross_size = size * 0.35
  local thickness = 2.0

  Draw.Line(dl,
    center_x - cross_size, center_y - cross_size,
    center_x + cross_size, center_y + cross_size,
    final_icon, thickness)
  Draw.Line(dl,
    center_x + cross_size, center_y - cross_size,
    center_x - cross_size, center_y + cross_size,
    final_icon, thickness)

  return is_hovered, clicked
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Draw a close button widget
--- Appears in top-right corner of specified bounds, fades in on proximity
--- @param ctx userdata ImGui context
--- @param opts table Options: x, y, width (bounds), size, margin, on_click, colors
--- @return table Result { clicked, hovered, visible }
function M.Draw(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)

  -- Resolve unique ID
  local unique_id = Base.resolve_id(ctx, opts, 'close_button')

  -- Get or create instance
  local instance = Base.get_or_create_instance(instances, unique_id, CloseButton.new, ctx)

  -- Render
  local is_hovered, clicked = render_close_button(ctx, opts, instance)

  -- Handle callback
  if clicked and opts.on_click then
    opts.on_click()
  end

  -- Return result
  return Base.create_result({
    clicked = clicked,
    hovered = is_hovered,
    visible = instance.alpha:value() > 0.01,
  })
end

--- Create a close button instance for advanced use (manual update/render control)
--- @param opts table Configuration options
--- @return table Close button instance with :update() and :render() methods
function M.new(opts)
  opts = opts or {}

  local button = {
    size = opts.size or DEFAULTS.size,
    margin = opts.margin or DEFAULTS.margin,
    proximity_distance = opts.proximity_distance or DEFAULTS.proximity_distance,

    bg_color = opts.bg_color or 0x000000FF,
    bg_opacity = opts.bg_opacity or DEFAULTS.bg_opacity,
    bg_opacity_hover = opts.bg_opacity_hover or DEFAULTS.bg_opacity_hover,

    icon_color = opts.icon_color or 0xFFFFFFFF,
    icon_opacity = opts.icon_opacity or DEFAULTS.icon_opacity,

    hover_color = opts.hover_color or 0xFF4444FF,
    active_color = opts.active_color or 0xFF0000FF,

    alpha = create_alpha_tracker(12.0),
    hover_alpha = create_alpha_tracker(16.0),

    on_click = opts.on_click,
  }

  function button:update(ctx, bounds, dt)
    dt = dt or (1/60)

    local mx, my = ImGui.GetMousePos(ctx)
    local button_x = bounds.x + bounds.w - self.margin - self.size
    local button_y = bounds.y + self.margin

    local dx = mx - (button_x + self.size/2)
    local dy = my - (button_y + self.size/2)
    local distance = math.sqrt(dx * dx + dy * dy)

    if distance < self.proximity_distance then
      self.alpha:set_target(1.0)
    else
      self.alpha:set_target(0.0)
    end

    self.alpha:update(dt)
    self.hover_alpha:update(dt)
  end

  function button:render(ctx, bounds, dl)
    local alpha = self.alpha:value()
    if alpha < 0.01 then return false end

    local button_x = bounds.x + bounds.w - self.margin - self.size
    local button_y = bounds.y + self.margin

    ImGui.SetCursorScreenPos(ctx, button_x, button_y)

    local is_hovered = false
    local clicked = false

    if alpha > 0.8 then
      if ImGui.InvisibleButton(ctx, '##close_button', self.size, self.size) then
        clicked = true
      end
      is_hovered = ImGui.IsItemHovered(ctx)
    end

    if is_hovered then
      self.hover_alpha:set_target(1.0)
    else
      self.hover_alpha:set_target(0.0)
    end

    local hover_alpha = self.hover_alpha:value()

    local bg_opacity = self.bg_opacity + (self.bg_opacity_hover - self.bg_opacity) * hover_alpha
    local bg_color = Colors.WithAlpha(self.bg_color, (255 * bg_opacity * alpha) // 1)

    local corner_radius = self.size / 2
    Draw.RectFilled(dl, button_x, button_y, button_x + self.size, button_y + self.size, bg_color, corner_radius)

    local icon_color = self.icon_color
    if hover_alpha > 0.5 then
      icon_color = self.hover_color
    end
    if ImGui.IsMouseDown(ctx, ImGui.MouseButton_Left) and is_hovered then
      icon_color = self.active_color
    end

    local final_icon_color = Colors.WithAlpha(icon_color, (255 * self.icon_opacity * alpha) // 1)

    local center_x = button_x + self.size / 2
    local center_y = button_y + self.size / 2
    local cross_size = self.size * 0.35
    local thickness = 2.0

    Draw.Line(dl,
      center_x - cross_size, center_y - cross_size,
      center_x + cross_size, center_y + cross_size,
      final_icon_color, thickness)
    Draw.Line(dl,
      center_x + cross_size, center_y - cross_size,
      center_x - cross_size, center_y + cross_size,
      final_icon_color, thickness)

    if clicked and self.on_click then
      self.on_click()
    end

    return clicked
  end

  return button
end

-- ============================================================================
-- MODULE EXPORT (Callable)
-- ============================================================================

return setmetatable(M, {
  __call = function(_, ctx, opts)
    return M.Draw(ctx, opts)
  end
})
