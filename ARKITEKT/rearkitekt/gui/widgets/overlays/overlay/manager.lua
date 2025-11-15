-- @noindex
-- ReArkitekt/gui/widgets/overlay/manager.lua
-- Modal overlay stack + scrim + focus/escape handling
-- Now supports both parent-window and viewport-level overlays
-- Enhanced with easing curves and close button support

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local Draw   = require('rearkitekt.gui.draw')
local Colors = require('rearkitekt.core.colors')
local Style  = require('rearkitekt.gui.style.imgui_defaults')
local OverlayConfig = require('rearkitekt.gui.widgets.overlays.overlay.defaults')

local M = {}
M.__index = M
local hexrgb = Colors.hexrgb

-- ============================================================================
-- SECTION 1: Easing Curves Support
-- ============================================================================

local Easing = nil
do
  local ok, mod = pcall(require, 'rearkitekt.gui.fx.animation.easing')
  if ok then Easing = mod end
end

-- ============================================================================
-- SECTION 2: Alpha Tracker (supports both speed-based and curve-based)
-- ============================================================================

local function clamp(val, min, max)
  return math.max(min, math.min(max, val))
end

local function apply_curve(t, curve_name)
  t = clamp(t, 0.0, 1.0)
  if not Easing or not curve_name then return t end
  local easing_func = Easing[curve_name]
  if easing_func then return easing_func(t) end
  return t
end

local function create_alpha_tracker(opts)
  opts = opts or {}

  -- Support both old speed-based API and new curve-based API
  local mode = opts.mode or (opts.speed and 'speed' or 'curve')

  local tracker = {
    current = 0.0,
    target = 0.0,
    mode = mode,

    -- Speed-based mode (exponential smoothing)
    speed = opts.speed or 8.0,

    -- Curve-based mode (time-based easing)
    duration = opts.duration or 0.3,
    curve_type = opts.curve_type or 'smootherstep',
    elapsed = 0.0,
  }

  function tracker:set_target(t)
    self.target = clamp(t, 0.0, 1.0)
    if self.mode == 'curve' then
      self.elapsed = 0.0
    end
  end

  function tracker:update(dt)
    if math.abs(self.target - self.current) < 0.001 then
      self.current = self.target
      return
    end

    if self.mode == 'speed' then
      -- Exponential smoothing (original behavior)
      local diff = self.target - self.current
      if math.abs(diff) < 0.005 then
        self.current = self.target
      else
        local alpha = 1.0 - math.exp(-self.speed * dt)
        self.current = self.current + diff * alpha
      end
    else
      -- Time-based easing curves
      self.elapsed = self.elapsed + dt
      local t = clamp(self.elapsed / self.duration, 0.0, 1.0)
      local curved = apply_curve(t, self.curve_type)
      self.current = self.current + (self.target - self.current) * curved
      if self.elapsed >= self.duration then
        self.current = self.target
      end
    end
  end

  function tracker:value()
    return clamp(self.current, 0.0, 1.0)
  end

  function tracker:is_complete()
    return math.abs(self.target - self.current) < 0.001
  end

  return tracker
end

-- ============================================================================
-- SECTION 3: Manager Implementation
-- ============================================================================

function M.new()
  local self = setmetatable({}, M)
  self.stack = {}
  self.titlebar_height = 0
  self.statusbar_height = 0
  self.is_docked = false
  self.last_frame_time = nil
  return self
end

function M:set_ui_bounds(titlebar_h, statusbar_h, docked)
  self.titlebar_height = titlebar_h or 0
  self.statusbar_height = statusbar_h or 0
  self.is_docked = docked or false
end

function M:push(opts)
  assert(opts and opts.id and opts.render, "overlay requires id + render()")

  -- Create alpha tracker with specified animation mode
  local alpha_opts = {}
  if opts.fade_curve then
    alpha_opts.mode = 'curve'
    alpha_opts.duration = opts.fade_duration or 0.3
    alpha_opts.curve_type = opts.fade_curve
  else
    alpha_opts.mode = 'speed'
    alpha_opts.speed = opts.fade_speed or 12
  end

  local overlay = {
    id = opts.id,
    render = opts.render,
    on_close = opts.on_close,
    close_on_scrim = (opts.close_on_scrim ~= false),
    esc_to_close = (opts.esc_to_close ~= false),
    use_viewport = (opts.use_viewport == true),

    -- Close button support
    show_close_button = (opts.show_close_button == true),
    close_button_size = opts.close_button_size or 32,
    close_button_margin = opts.close_button_margin or 16,
    close_button_proximity = opts.close_button_proximity or 150,
    close_button_color = opts.close_button_color or hexrgb("#FFFFFFFF"),
    close_button_hover_color = opts.close_button_hover_color or hexrgb("#FF4444FF"),
    close_button_bg_color = opts.close_button_bg_color or hexrgb("#000000FF"),
    close_button_bg_opacity = opts.close_button_bg_opacity or 0.6,
    close_button_bg_opacity_hover = opts.close_button_bg_opacity_hover or 0.8,
    close_button_hovered = false,
    close_button_alpha = 0.0,

    -- Background click support
    close_on_background_click = (opts.close_on_background_click == true),
    close_on_background_right_click = (opts.close_on_background_right_click == true),
    content_padding = opts.content_padding or 0,

    alpha = create_alpha_tracker(alpha_opts),
  }

  table.insert(self.stack, overlay)
end

function M:pop(id)
  if #self.stack == 0 then return end
  local top = self.stack[#self.stack]
  if not id or id == top.id then
    if top.on_close then pcall(top.on_close) end
    table.remove(self.stack)
  else
    for i=#self.stack,1,-1 do
      if self.stack[i].id == id then
        local it = table.remove(self.stack, i)
        if it.on_close then pcall(it.on_close) end
        break
      end
    end
  end
end

function M:is_active()
  return #self.stack > 0
end

function M:render(ctx, dt)
  if #self.stack == 0 then return end

  -- Calculate dt if not provided
  if not dt then
    local current_time = reaper.time_precise()
    dt = self.last_frame_time and clamp(current_time - self.last_frame_time, 0.001, 0.1) or 1/60
    self.last_frame_time = current_time
  end

  for i,ov in ipairs(self.stack) do
    local target = (i == #self.stack) and 1.0 or 0.6
    ov.alpha:set_target(target)
    ov.alpha:update(dt)
  end

  local top = self.stack[#self.stack]
  local alpha_val = top.alpha:value()

  local x, y, w, h

  if top.use_viewport then
    -- Use full REAPER viewport (entire screen)
    local viewport = ImGui.GetMainViewport(ctx)
    x, y = ImGui.Viewport_GetPos(viewport)
    w, h = ImGui.Viewport_GetSize(viewport)
  else
    -- Use parent window bounds with UI offset adjustments
    local parent_x, parent_y = ImGui.GetWindowPos(ctx)
    local parent_w, parent_h = ImGui.GetWindowSize(ctx)

    local offset_y = 0
    local adjusted_h = parent_h

    if not self.is_docked then
      offset_y = self.titlebar_height
      adjusted_h = parent_h - self.titlebar_height - self.statusbar_height + 4
    end

    x = parent_x
    y = parent_y + offset_y
    w = parent_w
    h = adjusted_h
  end

  ImGui.SetNextWindowPos(ctx, x, y)
  ImGui.SetNextWindowSize(ctx, w, h)

  local window_flags = ImGui.WindowFlags_NoTitleBar
                     | ImGui.WindowFlags_NoResize
                     | ImGui.WindowFlags_NoMove
                     | ImGui.WindowFlags_NoScrollbar
                     | ImGui.WindowFlags_NoScrollWithMouse
                     | ImGui.WindowFlags_NoCollapse
                     | ImGui.WindowFlags_NoNavFocus
                     | ImGui.WindowFlags_NoDocking
                     | ImGui.WindowFlags_NoBackground

  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 0, 0)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowBorderSize, 0)
  ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg, hexrgb("#00000000"))
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#00000000"))

  Style.PushMyStyle(ctx)

  local visible = ImGui.Begin(ctx, "##modal_overlay_" .. top.id, true, window_flags)

  if visible then
    local dl = ImGui.GetWindowDrawList(ctx)

    local config = OverlayConfig.get()
    local scrim_opacity = math.floor(255 * config.scrim.opacity * alpha_val)
    local scrim_color = Colors.with_alpha(config.scrim.color, scrim_opacity)
    Draw.rect_filled(dl, x, y, x+w, y+h, scrim_color, 0)

    -- Check for escape key
    if top.esc_to_close and ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
      self:pop()
    else
      -- Render close button if enabled
      if top.show_close_button and alpha_val > 0.1 then
        self:draw_close_button(ctx, top, x, y, w, h, dt)
      end

      -- Render content
      top.render(ctx, alpha_val, {x=x, y=y, w=w, h=h, dl=dl})

      -- Handle scrim clicks (check if click is outside content area)
      if top.close_on_scrim and not ImGui.IsAnyItemHovered(ctx) then
        if ImGui.IsMouseClicked(ctx, ImGui.MouseButton_Left) or
           ImGui.IsMouseClicked(ctx, ImGui.MouseButton_Right) then
          self:pop()
        end
      end

      -- Handle background clicks
      if top.close_on_background_click or top.close_on_background_right_click then
        local mouse_x, mouse_y = ImGui.GetMousePos(ctx)

        -- Check if over close button
        local over_close_btn = false
        if top.show_close_button then
          local btn_x = x + w - top.close_button_size - top.close_button_margin
          local btn_y = y + top.close_button_margin
          over_close_btn = mouse_x >= btn_x and mouse_x <= btn_x + top.close_button_size and
                          mouse_y >= btn_y and mouse_y <= btn_y + top.close_button_size
        end

        if not over_close_btn then
          local content_x = x + top.content_padding
          local content_y = y + top.content_padding + 100
          local content_w = w - (top.content_padding * 2)
          local content_h = h - (top.content_padding * 2) - 100

          local over_content = mouse_x >= content_x and mouse_x <= content_x + content_w and
                              mouse_y >= content_y and mouse_y <= content_y + content_h

          if not over_content and not ImGui.IsAnyItemHovered(ctx) then
            if (top.close_on_background_click and ImGui.IsMouseClicked(ctx, ImGui.MouseButton_Left)) or
               (top.close_on_background_right_click and ImGui.IsMouseClicked(ctx, ImGui.MouseButton_Right)) then
              self:pop()
            end
          end
        end
      end
    end
  end

  ImGui.End(ctx)

  Style.PopMyStyle(ctx)
  ImGui.PopStyleColor(ctx, 2)
  ImGui.PopStyleVar(ctx, 2)
end

-- ============================================================================
-- SECTION 4: Close Button Rendering
-- ============================================================================

function M:draw_close_button(ctx, overlay, vp_x, vp_y, vp_w, vp_h, dt)
  local btn_x = vp_x + vp_w - overlay.close_button_size - overlay.close_button_margin
  local btn_y = vp_y + overlay.close_button_margin

  local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
  local dist = math.sqrt((mouse_x - (btn_x + overlay.close_button_size/2))^2 +
                        (mouse_y - (btn_y + overlay.close_button_size/2))^2)
  local in_proximity = dist < overlay.close_button_proximity

  local target_alpha = in_proximity and 1.0 or 0.3
  overlay.close_button_alpha = overlay.close_button_alpha +
                               (target_alpha - overlay.close_button_alpha) *
                               (1.0 - math.exp(-10.0 * dt))

  ImGui.SetCursorScreenPos(ctx, btn_x, btn_y)
  ImGui.InvisibleButton(ctx, "##overlay_close_btn_" .. overlay.id,
                        overlay.close_button_size, overlay.close_button_size)
  overlay.close_button_hovered = ImGui.IsItemHovered(ctx)

  if ImGui.IsItemClicked(ctx) then
    self:pop(overlay.id)
  end

  local dl = ImGui.GetForegroundDrawList(ctx)
  local alpha_val = overlay.alpha:value() * overlay.close_button_alpha

  local bg_opacity = overlay.close_button_hovered and
                    overlay.close_button_bg_opacity_hover or
                    overlay.close_button_bg_opacity
  local bg_alpha = bg_opacity * alpha_val
  local bg_color = (overlay.close_button_bg_color & hexrgb("#FFFFFF00")) |
                   math.floor(255 * bg_alpha + 0.5)
  ImGui.DrawList_AddRectFilled(dl, btn_x, btn_y,
                               btn_x + overlay.close_button_size,
                               btn_y + overlay.close_button_size,
                               bg_color, overlay.close_button_size/2)

  local icon_color = overlay.close_button_hovered and
                    overlay.close_button_hover_color or
                    overlay.close_button_color
  icon_color = (icon_color & hexrgb("#FFFFFF00")) | math.floor(255 * alpha_val + 0.5)

  local padding = overlay.close_button_size * 0.3
  local x1, y1 = btn_x + padding, btn_y + padding
  local x2, y2 = btn_x + overlay.close_button_size - padding,
                btn_y + overlay.close_button_size - padding
  ImGui.DrawList_AddLine(dl, x1, y1, x2, y2, icon_color, 2)
  ImGui.DrawList_AddLine(dl, x2, y1, x1, y2, icon_color, 2)
end

return M
