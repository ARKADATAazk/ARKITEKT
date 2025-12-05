-- @noindex
-- arkitekt/runtime/chrome/window/fullscreen.lua
-- Fullscreen mode handling for windows

local ImGui = require('arkitekt.core.imgui')
local Constants = require('arkitekt.config.app')
local Timing = require('arkitekt.config.timing')
local Helpers = require('arkitekt.runtime.chrome.window.helpers')

local Draw = nil
do
  local ok, mod = pcall(require, 'arkitekt.gui.draw.primitives')
  if ok then Draw = mod end
end

local Colors = nil
do
  local ok, mod = pcall(require, 'arkitekt.core.colors')
  if ok then Colors = mod end
end

local CloseButton = nil
do
  local ok, mod = pcall(require, 'arkitekt.gui.widgets.primitives.close_button')
  if ok then CloseButton = mod end
end

local M = {}

--- Create fullscreen state from config
--- @param fullscreen_config table Fullscreen configuration
--- @return table state Fullscreen state object
function M.create_state(fullscreen_config)
  local is_fullscreen = fullscreen_config.enabled or false

  return {
    enabled = is_fullscreen,
    use_viewport = fullscreen_config.use_viewport,
    fade_in_duration = fullscreen_config.fade_in_duration or Timing.FADE.normal,
    fade_out_duration = fullscreen_config.fade_out_duration or Timing.FADE.normal,
    scrim_enabled = fullscreen_config.scrim_enabled,
    scrim_color = fullscreen_config.scrim_color or Constants.OVERLAY.SCRIM_COLOR,
    scrim_opacity = fullscreen_config.scrim_opacity or Constants.OVERLAY.SCRIM_OPACITY,
    window_bg_override = fullscreen_config.window_bg_override,
    window_opacity = fullscreen_config.window_opacity,
    alpha = Helpers.create_alpha_tracker(fullscreen_config.fade_in_duration or Timing.FADE.normal),
    close_requested = false,
    is_closing = false,
    show_close_button = fullscreen_config.show_close_button ~= false,
    close_on_background_click = fullscreen_config.close_on_background_click ~= false,
    close_on_background_left_click = fullscreen_config.close_on_background_left_click == true,
    close_button = nil,
    background_clicked = false,
  }
end

--- Build fullscreen-specific ImGui flags
--- @param base_flags number Base window flags
--- @param fullscreen_config table Fullscreen configuration
--- @return number flags Updated flags
function M.build_flags(base_flags, fullscreen_config)
  local flags = base_flags

  if fullscreen_config.hide_titlebar and ImGui.WindowFlags_NoTitleBar then
    flags = flags | ImGui.WindowFlags_NoTitleBar
  end
  if fullscreen_config.no_resize and ImGui.WindowFlags_NoResize then
    flags = flags | ImGui.WindowFlags_NoResize
  end
  if fullscreen_config.no_move and ImGui.WindowFlags_NoMove then
    flags = flags | ImGui.WindowFlags_NoMove
  end
  if fullscreen_config.no_collapse and ImGui.WindowFlags_NoCollapse then
    flags = flags | ImGui.WindowFlags_NoCollapse
  end
  if fullscreen_config.no_scrollbar and ImGui.WindowFlags_NoScrollbar then
    flags = flags | ImGui.WindowFlags_NoScrollbar
  end
  if fullscreen_config.no_scroll_with_mouse and ImGui.WindowFlags_NoScrollWithMouse then
    flags = flags | ImGui.WindowFlags_NoScrollWithMouse
  end
  if ImGui.WindowFlags_NoBackground then
    flags = flags | ImGui.WindowFlags_NoBackground
  end

  return flags
end

--- Create close button for fullscreen mode
--- @param fullscreen_config table Fullscreen configuration
--- @param on_close function Close callback
--- @return table|nil button Close button or nil
function M.create_close_button(fullscreen_config, on_close)
  if not CloseButton then return nil end

  local btn_opts = fullscreen_config.close_button or {}
  return CloseButton.new({
    size = btn_opts.size or Constants.OVERLAY.CLOSE_BUTTON_SIZE,
    margin = btn_opts.margin or Constants.OVERLAY.CLOSE_BUTTON_MARGIN,
    proximity_distance = fullscreen_config.close_button_proximity or Constants.OVERLAY.CLOSE_BUTTON_PROXIMITY,
    bg_color = btn_opts.bg_color or Constants.OVERLAY.CLOSE_BUTTON_BG_COLOR,
    bg_opacity = btn_opts.bg_opacity or Constants.OVERLAY.CLOSE_BUTTON_BG_OPACITY,
    bg_opacity_hover = btn_opts.bg_opacity_hover or Constants.OVERLAY.CLOSE_BUTTON_BG_OPACITY_HOVER,
    icon_color = btn_opts.icon_color or Constants.OVERLAY.CLOSE_BUTTON_ICON_COLOR,
    hover_color = btn_opts.hover_color or Constants.OVERLAY.CLOSE_BUTTON_HOVER_COLOR,
    active_color = btn_opts.active_color or Constants.OVERLAY.CLOSE_BUTTON_ACTIVE_COLOR,
    on_click = on_close,
  })
end

--- Update fullscreen alpha animation
--- @param fullscreen table Fullscreen state
--- @param dt number Delta time
--- @return boolean should_close Whether window should close
function M.update_alpha(fullscreen, dt)
  fullscreen.alpha:update(dt)

  if fullscreen.is_closing and fullscreen.alpha:is_complete() then
    return true
  end
  return false
end

--- Render fullscreen scrim overlay
--- @param ctx userdata ImGui context
--- @param fullscreen table Fullscreen state
--- @param wx number Window X position
--- @param wy number Window Y position
--- @param ww number Window width
--- @param wh number Window height
function M.render_scrim(ctx, fullscreen, wx, wy, ww, wh)
  if not fullscreen.scrim_enabled then return end
  if not Draw or not Colors then return end

  local dl = ImGui.GetWindowDrawList(ctx)

  local alpha_val = fullscreen.alpha:value()
  local scrim_opacity = fullscreen.scrim_opacity * alpha_val
  local scrim_alpha = (255 * scrim_opacity + 0.5) // 1
  local scrim_color = Colors.WithAlpha(fullscreen.scrim_color, scrim_alpha)

  Draw.RectFilled(dl, wx, wy, wx + ww, wy + wh, scrim_color, 0)
end

--- Handle fullscreen background click detection
--- @param ctx userdata ImGui context
--- @param fullscreen table Fullscreen state
--- @param wx number Window X position
--- @param wy number Window Y position
--- @param ww number Window width
--- @param wh number Window height
function M.handle_background_click(ctx, fullscreen, wx, wy, ww, wh)
  if fullscreen.is_closing then return end

  ImGui.SetCursorScreenPos(ctx, wx, wy)
  ImGui.InvisibleButton(ctx, '##fullscreen_background', ww, wh)

  if fullscreen.close_on_background_click and ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right) then
    fullscreen.background_clicked = true
  end

  if fullscreen.close_on_background_left_click and ImGui.IsItemClicked(ctx, ImGui.MouseButton_Left) then
    fullscreen.background_clicked = true
  end
end

--- Update fullscreen close button
--- @param ctx userdata ImGui context
--- @param fullscreen table Fullscreen state
--- @param wx number Window X position
--- @param wy number Window Y position
--- @param ww number Window width
--- @param wh number Window height
--- @param dt number Delta time
function M.update_close_button(ctx, fullscreen, wx, wy, ww, wh, dt)
  if not fullscreen.close_button then return end
  if not fullscreen.close_button.update then return end
  if fullscreen.is_closing then return end

  local bounds = { x = wx, y = wy, w = ww, h = wh }
  fullscreen.close_button:update(ctx, bounds, dt)
end

--- Render fullscreen close button
--- @param ctx userdata ImGui context
--- @param fullscreen table Fullscreen state
--- @param wx number Window X position
--- @param wy number Window Y position
--- @param ww number Window width
--- @param wh number Window height
function M.render_close_button(ctx, fullscreen, wx, wy, ww, wh)
  if not fullscreen.close_button then return end
  if not fullscreen.close_button.render then return end
  if fullscreen.is_closing then return end

  local dl = ImGui.GetWindowDrawList(ctx)
  local bounds = { x = wx, y = wy, w = ww, h = wh, dl = dl }
  fullscreen.close_button:render(ctx, bounds, dl)
end

--- Request close for fullscreen window (starts fade out)
--- @param fullscreen table Fullscreen state
function M.request_close(fullscreen)
  fullscreen.close_requested = true
  fullscreen.is_closing = true
  fullscreen.alpha:set_target(0.0)
end

--- Push fullscreen background color style
--- @param ctx userdata ImGui context
--- @param fullscreen table Fullscreen state
--- @return boolean pushed Whether style was pushed
function M.push_bg_style(ctx, fullscreen)
  if not fullscreen.window_bg_override then return false end
  if not Colors then
    ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg, fullscreen.window_bg_override)
    return true
  end

  local alpha_val = fullscreen.alpha:value()
  local bg_alpha = (255 * alpha_val + 0.5) // 1
  local bg_color = Colors.WithAlpha(fullscreen.window_bg_override, bg_alpha)
  ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg, bg_color)
  return true
end

return M
