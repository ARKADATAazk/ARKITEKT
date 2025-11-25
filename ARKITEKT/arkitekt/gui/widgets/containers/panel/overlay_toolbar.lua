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
    current = initial,     -- Current visibility (0.0 - 1.0)
    target = initial,      -- Target visibility
    is_hovering = false,
    is_expanded = false,   -- For button trigger mode
    slide_offset = 0,      -- Current slide offset (pixels) for edge slide
    slide_target = 0,      -- Target slide offset
    width_scale = 1.0,     -- Current width scale (1.0 = normal, 1.3 = 30% wider)
    width_scale_target = 1.0,  -- Target width scale
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

  -- Lerp slide offset for edge slide animation
  local slide_speed = 0.25
  anim_state.slide_offset = anim_state.slide_offset + (anim_state.slide_target - anim_state.slide_offset) * slide_speed

  -- Snap when very close
  if math.abs(anim_state.slide_target - anim_state.slide_offset) < 0.5 then
    anim_state.slide_offset = anim_state.slide_target
  end

  -- Lerp width scale for hover expansion
  local width_scale_speed = 0.2
  anim_state.width_scale = anim_state.width_scale + (anim_state.width_scale_target - anim_state.width_scale) * width_scale_speed

  -- Snap when very close
  if math.abs(anim_state.width_scale_target - anim_state.width_scale) < 0.01 then
    anim_state.width_scale = anim_state.width_scale_target
  end
end

--- Update hover state and target visibility
--- @param anim_state table Animation state
--- @param config table Overlay toolbar configuration
--- @param is_hovering boolean Whether mouse is over overlay area
--- @param button_clicked boolean|nil Whether toggle button was clicked (button mode only)
function M.update_hover_state(anim_state, config, is_hovering, button_clicked)
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
  elseif auto_hide_cfg.trigger == "button" then
    -- Toggle on button click
    if button_clicked then
      anim_state.is_expanded = not anim_state.is_expanded
    end
    local visible_amount = auto_hide_cfg.visible_amount or 0.2
    anim_state.target = anim_state.is_expanded and 1.0 or visible_amount
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
--- @param slide_offset number Current slide offset in pixels (for edge slide animation)
--- @param width_scale number Width scale multiplier (1.0 = normal, 1.3 = 30% wider)
--- @return table {x, y, w, h} Overlay bounds
function M.calculate_bounds(position, panel_bounds, regular_toolbar_bounds, config, visibility, slide_offset, width_scale)
  local x1, y1, x2, y2 = table.unpack(panel_bounds)
  local orientation = get_orientation(position)

  -- Apply width scale (default 1.0)
  width_scale = width_scale or 1.0

  local size = orientation == "horizontal" and (config.height or 40) or (config.width or 200)
  size = size * width_scale  -- Apply width/height scaling
  local visible_size = size * visibility

  -- Check if overlay should extend from panel edge (ignore regular toolbar)
  local extend_from_edge = config.extend_from_edge or false

  -- Apply slide offset for edge animations (default 0)
  slide_offset = slide_offset or 0

  if position == "top" then
    local start_y = (not extend_from_edge and regular_toolbar_bounds) and regular_toolbar_bounds.y2 or y1
    return {
      x = x1,
      y = start_y,
      w = x2 - x1,
      h = visible_size
    }
  elseif position == "bottom" then
    local end_y = (not extend_from_edge and regular_toolbar_bounds) and regular_toolbar_bounds.y1 or y2
    return {
      x = x1,
      y = end_y - visible_size,
      w = x2 - x1,
      h = visible_size
    }
  elseif position == "left" then
    local start_x = (not extend_from_edge and regular_toolbar_bounds) and regular_toolbar_bounds.x2 or x1
    local content_y1 = regular_toolbar_bounds and regular_toolbar_bounds.content_y1 or y1
    local content_y2 = regular_toolbar_bounds and regular_toolbar_bounds.content_y2 or y2

    -- Apply edge slide: buttons start clipped outside edge, slide right on hover
    local edge_slide_distance = config.edge_slide_distance or 0
    local base_x = start_x - edge_slide_distance  -- Start clipped outside

    return {
      x = base_x + slide_offset,  -- Apply slide offset
      y = content_y1,
      w = visible_size,
      h = content_y2 - content_y1
    }
  else -- right
    local end_x = (not extend_from_edge and regular_toolbar_bounds) and regular_toolbar_bounds.x1 or x2
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

--- Draw toggle button for button-triggered overlays
--- @param ctx userdata ImGui context
--- @param dl userdata ImGui draw list
--- @param bounds table {x, y, w, h}
--- @param position string Position ("top", "bottom", "left", "right")
--- @param anim_state table Animation state
--- @param panel_id string Panel ID
--- @return boolean True if button was clicked
local function draw_toggle_button(ctx, dl, bounds, position, anim_state, panel_id)
  local btn_size = 20
  local btn_x, btn_y

  -- Position button based on orientation
  if position == "left" then
    btn_x = bounds.x + bounds.w - btn_size - 2
    btn_y = bounds.y + (bounds.h - btn_size) * 0.5
  elseif position == "right" then
    btn_x = bounds.x + 2
    btn_y = bounds.y + (bounds.h - btn_size) * 0.5
  elseif position == "top" then
    btn_x = bounds.x + (bounds.w - btn_size) * 0.5
    btn_y = bounds.y + bounds.h - btn_size - 2
  else -- bottom
    btn_x = bounds.x + (bounds.w - btn_size) * 0.5
    btn_y = bounds.y + 2
  end

  -- Simple invisible button for click detection
  ImGui.SetCursorScreenPos(ctx, btn_x, btn_y)
  local clicked = ImGui.InvisibleButton(ctx, panel_id .. "_overlay_toggle", btn_size, btn_size)

  -- Draw arrow indicator
  local mx, my = ImGui.GetMousePos(ctx)
  local is_hovering = mx >= btn_x and mx <= btn_x + btn_size and my >= btn_y and my <= btn_y + btn_size
  local color = is_hovering and 0xFFFFFFFF or 0xAAAAAAFF

  local arrow_icon = anim_state.is_expanded and "<" or ">"
  if position == "right" then
    arrow_icon = anim_state.is_expanded and ">" or "<"
  elseif position == "top" then
    arrow_icon = anim_state.is_expanded and "^" or "v"
  elseif position == "bottom" then
    arrow_icon = anim_state.is_expanded and "v" or "^"
  end

  -- Draw button background
  local btn_bg = is_hovering and 0x444444FF or 0x333333FF
  ImGui.DrawList_AddRectFilled(dl, btn_x, btn_y, btn_x + btn_size, btn_y + btn_size, btn_bg, 3)

  -- Draw arrow text centered
  local text_w, text_h = ImGui.CalcTextSize(ctx, arrow_icon)
  local text_x = btn_x + (btn_size - text_w) * 0.5
  local text_y = btn_y + (btn_size - text_h) * 0.5
  ImGui.DrawList_AddText(dl, text_x, text_y, color, arrow_icon)

  return clicked
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

  -- Calculate bounds with slide offset and width scale
  local bounds = M.calculate_bounds(position, panel_bounds, regular_toolbar_bounds, config, anim_state.current, anim_state.slide_offset, anim_state.width_scale)

  local auto_hide_cfg = config.auto_hide or {}
  local button_clicked = false

  -- Draw toggle button for button-triggered overlays
  if auto_hide_cfg.trigger == "button" then
    button_clicked = draw_toggle_button(ctx, dl, bounds, position, anim_state, panel_id)
  end

  -- Update hover state (and handle button clicks)
  local is_hovering = is_mouse_hovering(ctx, bounds)
  M.update_hover_state(anim_state, config, is_hovering, button_clicked)

  -- Update edge slide animation (for left position)
  if position == "left" and config.edge_slide_distance and config.edge_slide_distance > 0 then
    local mx, my = ImGui.GetMousePos(ctx)
    local x1, y1, x2, y2 = table.unpack(panel_bounds)

    -- Calculate actual button area (not full panel height)
    local button_count = config.elements and #config.elements or 0
    local button_height = 40  -- Standard button height from sidebars layout
    local buttons_total_height = button_count * button_height

    -- Center buttons vertically in available space
    local available_height = bounds.h
    local button_area_y = bounds.y + (available_height - buttons_total_height) / 2

    -- Add vertical padding for easier targeting
    local vertical_padding = 30
    local hover_zone_y1 = button_area_y - vertical_padding
    local hover_zone_y2 = button_area_y + buttons_total_height + vertical_padding

    -- Horizontal hover zone extends from panel edge
    local hover_zone_width = 50
    local hover_zone_x1 = x1
    local hover_zone_x2 = x1 + hover_zone_width

    -- Check if mouse is in the constrained hover zone
    local is_in_hover_zone = mx >= hover_zone_x1 and mx <= hover_zone_x2 and
                             my >= hover_zone_y1 and my <= hover_zone_y2

    -- Update slide target and width scale on hover
    anim_state.slide_target = is_in_hover_zone and config.edge_slide_distance or 0
    anim_state.width_scale_target = is_in_hover_zone and 1.3 or 1.0  -- 30% wider when hovering
  end

  -- Draw background
  draw_background(dl, bounds, config, rounding)

  -- Add clipping to constrain overlay within panel bounds
  local x1, y1, x2, y2 = table.unpack(panel_bounds)
  ImGui.DrawList_PushClipRect(dl, x1, y1, x2, y2, true)

  -- Draw elements using existing toolbar element renderers (render if any visibility)
  if config.elements and #config.elements > 0 and anim_state.current > 0.01 then
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

  -- Pop clip rect after rendering
  ImGui.DrawList_PopClipRect(dl)
end

return M
