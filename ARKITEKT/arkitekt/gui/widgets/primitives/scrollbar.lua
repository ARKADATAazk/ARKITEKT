-- @noindex
-- arkitekt/gui/widgets/primitives/scrollbar.lua
-- Custom scrollbar with smooth animations

local ImGui = require('arkitekt.core.imgui')
local Colors = require('arkitekt.core.colors')
local Base = require('arkitekt.gui.widgets.base')

local M = {}

-- ============================================================================
-- DEFAULTS
-- ============================================================================

local DEFAULTS = {
  id = 'scrollbar',
  x = nil,
  y = nil,
  height = nil,
  width = 12,
  padding = 2,
  min_thumb_height = 30,
  scroll_pos = 0,
  content_height = 0,
  visible_height = 0,
  track_color = 0x00000000,
  track_hover_color = 0x0F0F0FFF,
  thumb_color = 0x282828FF,
  thumb_hover_color = 0x323232FF,
  thumb_active_color = 0x3C3C3CFF,
  thumb_rounding = 4,
  track_rounding = 0,
  fade_speed = 10.0,
  auto_hide = false,
  auto_hide_delay = 1.0,
  on_scroll = nil,
  advance = 'none',
}

-- ============================================================================
-- INSTANCE MANAGEMENT
-- ============================================================================

local instances = Base.create_instance_registry()

local function create_instance(id)
  return {
    is_dragging = false,
    drag_start_y = 0,
    drag_start_scroll = 0,
    hover_alpha = 1.0,
    last_interaction = 0,
  }
end

-- ============================================================================
-- HELPERS
-- ============================================================================

local function get_max_scroll(content_h, visible_h)
  return math.max(0, content_h - visible_h)
end

local function is_scrollable(content_h, visible_h)
  return content_h > visible_h
end

local function get_thumb_height(visible_h, content_h, min_thumb)
  if not is_scrollable(content_h, visible_h) then return 0 end
  local ratio = visible_h / content_h
  return math.max(min_thumb, visible_h * ratio)
end

local function get_thumb_position(scroll_pos, content_h, visible_h, track_h, min_thumb)
  if not is_scrollable(content_h, visible_h) then return 0 end
  local max_scroll = get_max_scroll(content_h, visible_h)
  if max_scroll <= 0 then return 0 end
  local thumb_h = get_thumb_height(visible_h, content_h, min_thumb)
  local available = track_h - thumb_h
  return (scroll_pos / max_scroll) * available
end

local function apply_alpha(color, alpha)
  local a = color & 0xFF
  local new_a = (a * alpha) // 1
  return (color & 0xFFFFFF00) | new_a
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function M.Draw(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)

  local content_h = opts.content_height
  local visible_h = opts.visible_height
  if not is_scrollable(content_h, visible_h) then
    return Base.create_result({ scroll_pos = opts.scroll_pos, scrollable = false })
  end

  local unique_id = Base.resolve_id(ctx, opts, 'scrollbar')
  local inst = Base.get_or_create_instance(instances, unique_id, create_instance, ctx)
  local x, y = Base.get_position(ctx, opts)
  local height = opts.height or visible_h
  local width = opts.width
  local padding = opts.padding

  local scroll_pos = math.max(0, math.min(opts.scroll_pos, get_max_scroll(content_h, visible_h)))
  local new_scroll = scroll_pos

  -- Auto-hide logic
  local now = reaper.time_precise()
  local dt = ImGui.GetDeltaTime(ctx)

  if opts.auto_hide then
    local time_since = now - inst.last_interaction
    local target = (time_since > opts.auto_hide_delay and not inst.is_dragging) and 0.0 or 1.0
    inst.hover_alpha = inst.hover_alpha + (target - inst.hover_alpha) * opts.fade_speed * dt
    inst.hover_alpha = math.max(0.0, math.min(1.0, inst.hover_alpha))

    if inst.hover_alpha < 0.01 then
      return Base.create_result({ scroll_pos = scroll_pos, scrollable = true })
    end
  end

  local dl = ImGui.GetWindowDrawList(ctx)
  local track_x = x + padding
  local track_y = y
  local track_w = width - padding * 2
  local track_h = height

  local mx, my = ImGui.GetMousePos(ctx)
  local is_track_hovered = mx >= track_x and mx < track_x + track_w and
                           my >= track_y and my < track_y + track_h

  local thumb_h = get_thumb_height(visible_h, content_h, opts.min_thumb_height)
  local thumb_y = track_y + get_thumb_position(scroll_pos, content_h, visible_h, track_h, opts.min_thumb_height)
  local is_thumb_hovered = mx >= track_x and mx < track_x + track_w and
                           my >= thumb_y and my < thumb_y + thumb_h

  if is_track_hovered or is_thumb_hovered or inst.is_dragging then
    inst.last_interaction = now
  end

  -- Draw track
  local track_color = is_track_hovered and opts.track_hover_color or opts.track_color
  track_color = apply_alpha(track_color, inst.hover_alpha)
  if (track_color & 0xFF) > 0 then
    ImGui.DrawList_AddRectFilled(dl, track_x, track_y, track_x + track_w, track_y + track_h,
                                  track_color, opts.track_rounding)
  end

  -- Draw thumb
  local thumb_color = opts.thumb_color
  if inst.is_dragging then
    thumb_color = opts.thumb_active_color
  elseif is_thumb_hovered then
    thumb_color = opts.thumb_hover_color
  end
  thumb_color = apply_alpha(thumb_color, inst.hover_alpha)
  ImGui.DrawList_AddRectFilled(dl, track_x, thumb_y, track_x + track_w, thumb_y + thumb_h,
                                thumb_color, opts.thumb_rounding)

  -- Interaction
  ImGui.SetCursorScreenPos(ctx, track_x, track_y)
  ImGui.InvisibleButton(ctx, '##' .. unique_id, track_w, track_h)

  if ImGui.IsItemActive(ctx) then
    if not inst.is_dragging then
      inst.is_dragging = true
      inst.drag_start_y = my
      inst.drag_start_scroll = scroll_pos

      local click_in_thumb = my >= thumb_y and my < thumb_y + thumb_h
      if not click_in_thumb then
        local click_ratio = (my - track_y) / track_h
        new_scroll = click_ratio * content_h - visible_h * 0.5
        new_scroll = math.max(0, math.min(new_scroll, get_max_scroll(content_h, visible_h)))
      end
    else
      local delta_y = my - inst.drag_start_y
      local max_scroll = get_max_scroll(content_h, visible_h)
      local available = track_h - thumb_h
      if available > 0 then
        local scroll_delta = (delta_y / available) * max_scroll
        new_scroll = inst.drag_start_scroll + scroll_delta
        new_scroll = math.max(0, math.min(new_scroll, max_scroll))
      end
    end
  elseif inst.is_dragging and not ImGui.IsMouseDown(ctx, 0) then
    inst.is_dragging = false
  end

  if is_track_hovered then
    ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand)
  end

  -- Callback
  if new_scroll ~= scroll_pos and opts.on_scroll then
    opts.on_scroll(new_scroll)
  end

  Base.advance_cursor(ctx, x, y, width, height, opts.advance)

  return Base.create_result({
    scroll_pos = new_scroll,
    scrollable = true,
    dragging = inst.is_dragging,
    width = width,
    height = height,
  })
end

--- Handle mouse wheel scrolling
function M.HandleWheel(ctx, opts, wheel_delta, scroll_speed)
  opts = Base.parse_opts(opts, DEFAULTS)
  if not is_scrollable(opts.content_height, opts.visible_height) then
    return false, opts.scroll_pos
  end

  if wheel_delta ~= 0 then
    local delta = -wheel_delta * (scroll_speed or 50)
    local new_scroll = opts.scroll_pos + delta
    new_scroll = math.max(0, math.min(new_scroll, get_max_scroll(opts.content_height, opts.visible_height)))

    if opts.on_scroll then
      opts.on_scroll(new_scroll)
    end
    return true, new_scroll
  end
  return false, opts.scroll_pos
end

-- ============================================================================
-- FACTORY PATTERN (for panel/scrolling.lua compatibility)
-- ============================================================================

function M.new(opts)
  opts = opts or {}
  local scrollbar = {
    id = opts.id or 'scrollbar',
    config = {
      width = opts.width or DEFAULTS.width,
      padding = opts.padding or DEFAULTS.padding,
      min_thumb_height = opts.min_thumb_height or DEFAULTS.min_thumb_height,
      track_color = opts.track_color or DEFAULTS.track_color,
      track_hover_color = opts.track_hover_color or DEFAULTS.track_hover_color,
      thumb_color = opts.thumb_color or DEFAULTS.thumb_color,
      thumb_hover_color = opts.thumb_hover_color or DEFAULTS.thumb_hover_color,
      thumb_active_color = opts.thumb_active_color or DEFAULTS.thumb_active_color,
      thumb_rounding = opts.thumb_rounding or DEFAULTS.thumb_rounding,
      track_rounding = opts.track_rounding or DEFAULTS.track_rounding,
      fade_speed = opts.fade_speed or DEFAULTS.fade_speed,
      auto_hide = opts.auto_hide or DEFAULTS.auto_hide,
      auto_hide_delay = opts.auto_hide_delay or DEFAULTS.auto_hide_delay,
    },
    scroll_pos = 0,
    content_height = 0,
    visible_height = 0,
    is_dragging = false,
    drag_start_y = 0,
    drag_start_scroll = 0,
    hover_alpha = 1.0,
    last_interaction = 0,
    on_scroll = opts.on_scroll,
  }

  function scrollbar:set_content_height(h) self.content_height = h end
  function scrollbar:set_visible_height(h) self.visible_height = h end
  function scrollbar:set_scroll_pos(pos)
    self.scroll_pos = math.max(0, math.min(pos, self:get_max_scroll()))
  end
  function scrollbar:get_scroll_pos() return self.scroll_pos end
  function scrollbar:get_max_scroll() return math.max(0, self.content_height - self.visible_height) end
  function scrollbar:is_scrollable() return self.content_height > self.visible_height end

  function scrollbar:update(dt)
    if self.config.auto_hide then
      local now = reaper.time_precise()
      local time_since = now - self.last_interaction
      local target = (time_since > self.config.auto_hide_delay and not self.is_dragging) and 0.0 or 1.0
      self.hover_alpha = self.hover_alpha + (target - self.hover_alpha) * self.config.fade_speed * dt
      self.hover_alpha = math.max(0.0, math.min(1.0, self.hover_alpha))
    end
  end

  function scrollbar:draw(ctx, x, y, height)
    local result = M.Draw(ctx, {
      id = self.id,
      x = x,
      y = y,
      height = height,
      width = self.config.width,
      scroll_pos = self.scroll_pos,
      content_height = self.content_height,
      visible_height = self.visible_height,
      on_scroll = function(pos)
        self.scroll_pos = pos
        if self.on_scroll then self.on_scroll(pos) end
      end,
    })
    self.scroll_pos = result.scroll_pos
    self.is_dragging = result.dragging
  end

  function scrollbar:handle_wheel(ctx, wheel_delta, scroll_speed)
    if not self:is_scrollable() or wheel_delta == 0 then return false end
    local delta = -wheel_delta * (scroll_speed or 50)
    self:set_scroll_pos(self.scroll_pos + delta)
    self.last_interaction = reaper.time_precise()
    if self.on_scroll then self.on_scroll(self.scroll_pos) end
    return true
  end

  return scrollbar
end

-- ============================================================================
-- MODULE EXPORT
-- ============================================================================

return setmetatable(M, {
  __call = function(_, ctx, opts)
    return M.Draw(ctx, opts)
  end
})
