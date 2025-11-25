-- @noindex
-- panel/overlay_toolbar.lua
-- Overlay toolbar system - floating toolbars with auto-hide and animations
-- All 4 sides supported: top, bottom, left, right

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

-- Delegate to existing renderers for element drawing
local Header = require('arkitekt.gui.widgets.containers.panel.header')
local Sidebars = require('arkitekt.gui.widgets.containers.panel.sidebars')

local M = {}

-- ============================================================================
-- ANIMATION STATE
-- ============================================================================

--- Create animation state for an overlay toolbar
--- @param position string Position ("top", "bottom", "left", "right")
--- @param config table Overlay toolbar configuration
--- @return table Animation state
function M.create_animation_state(position, config)
  local auto_hide_cfg = config.auto_hide or {}
  local visible_amount = auto_hide_cfg.visible_amount or 0.2

  -- Start hidden (showing only visible_amount)
  local initial = auto_hide_cfg.enabled and visible_amount or 1.0

  return {
    position = position,
    current = initial,  -- Current visibility (0.0 - 1.0)
    target = initial,   -- Target visibility
    is_hovering = false,
  }
end

--- Update animation state (lerp toward target)
--- @param anim_state table Animation state
--- @param config table Overlay toolbar configuration
--- @param dt number Delta time
function M.update_animation(anim_state, config, dt)
  local auto_hide_cfg = config.auto_hide or {}
  if not auto_hide_cfg.enabled then
    anim_state.current = 1.0
    anim_state.target = 1.0
    return
  end

  -- Lerp toward target
  local speed = auto_hide_cfg.animation_speed or 0.15
  anim_state.current = anim_state.current + (anim_state.target - anim_state.current) * speed

  -- Snap when very close (prevent jitter)
  if math.abs(anim_state.target - anim_state.current) < 0.001 then
    anim_state.current = anim_state.target
  end
end

--- Update hover state and target visibility
--- @param anim_state table Animation state
--- @param config table Overlay toolbar configuration
--- @param is_hovering boolean Whether mouse is over overlay area
function M.update_hover_state(anim_state, config, is_hovering)
  local auto_hide_cfg = config.auto_hide or {}

  if not auto_hide_cfg.enabled then
    anim_state.target = 1.0
    return
  end

  anim_state.is_hovering = is_hovering

  if auto_hide_cfg.trigger == "always_visible" then
    anim_state.target = 1.0
  elseif auto_hide_cfg.trigger == "hover" then
    local visible_amount = auto_hide_cfg.visible_amount or 0.2
    anim_state.target = is_hovering and 1.0 or visible_amount
  end
end

-- ============================================================================
-- POSITION CALCULATION
-- ============================================================================

--- Get orientation for a position
--- @param position string Position ("top", "bottom", "left", "right")
--- @return string "horizontal" or "vertical"
local function get_orientation(position)
  return (position == "top" or position == "bottom") and "horizontal" or "vertical"
end

--- Calculate overlay bounds based on regular toolbar presence
--- @param position string Position ("top", "bottom", "left", "right")
--- @param panel_bounds table {x1, y1, x2, y2} Panel bounds
--- @param regular_toolbar_bounds table|nil Regular toolbar bounds on same side (if exists)
--- @param config table Overlay toolbar configuration
--- @param visibility number Current visibility (0.0 - 1.0)
--- @return table {x, y, w, h} Overlay bounds
function M.calculate_bounds(position, panel_bounds, regular_toolbar_bounds, config, visibility)
  local x1, y1, x2, y2 = table.unpack(panel_bounds)
  local orientation = get_orientation(position)

  local size = orientation == "horizontal" and (config.height or 40) or (config.width or 200)
  local visible_size = size * visibility

  if position == "top" then
    local start_y = regular_toolbar_bounds and regular_toolbar_bounds.y2 or y1
    return {
      x = x1,
      y = start_y,
      w = x2 - x1,
      h = visible_size
    }
  elseif position == "bottom" then
    local end_y = regular_toolbar_bounds and regular_toolbar_bounds.y1 or y2
    return {
      x = x1,
      y = end_y - visible_size,
      w = x2 - x1,
      h = visible_size
    }
  elseif position == "left" then
    local start_x = regular_toolbar_bounds and regular_toolbar_bounds.x2 or x1
    local content_y1 = regular_toolbar_bounds and regular_toolbar_bounds.content_y1 or y1
    local content_y2 = regular_toolbar_bounds and regular_toolbar_bounds.content_y2 or y2
    return {
      x = start_x,
      y = content_y1,
      w = visible_size,
      h = content_y2 - content_y1
    }
  else -- right
    local end_x = regular_toolbar_bounds and regular_toolbar_bounds.x1 or x2
    local content_y1 = regular_toolbar_bounds and regular_toolbar_bounds.content_y1 or y1
    local content_y2 = regular_toolbar_bounds and regular_toolbar_bounds.content_y2 or y2
    return {
      x = end_x - visible_size,
      y = content_y1,
      w = visible_size,
      h = content_y2 - content_y1
    }
  end
end

-- ============================================================================
-- RENDERING
-- ============================================================================

--- Check if mouse is hovering over overlay area
--- @param ctx userdata ImGui context
--- @param bounds table {x, y, w, h}
--- @return boolean True if hovering
local function is_mouse_hovering(ctx, bounds)
  local mx, my = ImGui.GetMousePos(ctx)
  return mx >= bounds.x and mx <= bounds.x + bounds.w and
         my >= bounds.y and my <= bounds.y + bounds.h
end

--- Draw overlay toolbar background
--- @param dl userdata ImGui draw list
--- @param bounds table {x, y, w, h}
--- @param config table Overlay toolbar configuration
--- @param rounding number Corner rounding
local function draw_background(dl, bounds, config, rounding)
  if not config.bg_color then
    return  -- No backdrop by default
  end

  ImGui.DrawList_AddRectFilled(
    dl, bounds.x, bounds.y, bounds.x + bounds.w, bounds.y + bounds.h,
    config.bg_color,
    rounding
  )
end

--- Draw overlay toolbar
--- @param ctx userdata ImGui context
--- @param dl userdata ImGui draw list
--- @param panel_bounds table {x1, y1, x2, y2}
--- @param regular_toolbar_bounds table|nil Regular toolbar bounds on same side
--- @param config table Overlay toolbar configuration
--- @param anim_state table Animation state
--- @param panel_state table Panel state
--- @param panel_id string Panel ID
--- @param position string Position ("top", "bottom", "left", "right")
--- @param rounding number Corner rounding
function M.draw(ctx, dl, panel_bounds, regular_toolbar_bounds, config, anim_state, panel_state, panel_id, position, rounding)
  if not config or not config.enabled then
    return
  end

  -- Calculate bounds
  local bounds = M.calculate_bounds(position, panel_bounds, regular_toolbar_bounds, config, anim_state.current)

  -- Update hover state
  local is_hovering = is_mouse_hovering(ctx, bounds)
  M.update_hover_state(anim_state, config, is_hovering)

  -- Draw background
  draw_background(dl, bounds, config, rounding)

  -- Draw elements using existing toolbar element renderers
  if config.elements and #config.elements > 0 then
    local orientation = get_orientation(position)

    if orientation == "horizontal" then
      -- Use Header renderer for horizontal overlay toolbars (top/bottom)
      Header.draw_elements(ctx, dl, bounds.x, bounds.y, bounds.w, bounds.h, panel_state, config, position)
    else
      -- Use Sidebars renderer for vertical overlay toolbars (left/right)
      local side = (position == "left") and "left" or "right"
      Sidebars.draw(ctx, dl, bounds.x, bounds.y, bounds.w, bounds.h, config, panel_id, side)
    end
  end
end

return M
