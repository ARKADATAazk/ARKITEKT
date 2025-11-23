-- @noindex
-- Arkitekt/gui/widgets/nodal/systems/viewport.lua
-- Viewport controller with pan/zoom for node canvas

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local M = {}

function M.new(opts)
  opts = opts or {}
  
  return {
    offset_x = opts.offset_x or 0,
    offset_y = opts.offset_y or 0,
    
    scale = opts.scale or 1.0,
    min_scale = opts.min_scale or 0.25,
    max_scale = opts.max_scale or 2.0,
    zoom_speed = opts.zoom_speed or 0.1,
    
    -- Scroll settings
    scroll_speed = opts.scroll_speed or 30,  -- Pixels per wheel tick
    enable_wheel_scroll = opts.enable_wheel_scroll ~= false,  -- Default true
    
    is_panning = false,
    pan_start_x = 0,
    pan_start_y = 0,
    pan_start_offset_x = 0,
    pan_start_offset_y = 0,
    
    bounds_x = 0,
    bounds_y = 0,
    bounds_w = 0,
    bounds_h = 0,
  }
end

function M.set_bounds(viewport, x, y, w, h)
  viewport.bounds_x = x or 0
  viewport.bounds_y = y or 0
  viewport.bounds_w = w or 0
  viewport.bounds_h = h or 0
end

function M.screen_to_world(viewport, screen_x, screen_y)
  if not viewport.scale or viewport.scale == 0 then
    viewport.scale = 1.0
  end
  
  local world_x = (screen_x - viewport.bounds_x - viewport.offset_x) / viewport.scale
  local world_y = (screen_y - viewport.bounds_y - viewport.offset_y) / viewport.scale
  return world_x, world_y
end

function M.world_to_screen(viewport, world_x, world_y)
  if not viewport.scale or viewport.scale == 0 then
    viewport.scale = 1.0
  end
  
  local screen_x = world_x * viewport.scale + viewport.offset_x + viewport.bounds_x
  local screen_y = world_y * viewport.scale + viewport.offset_y + viewport.bounds_y
  return screen_x, screen_y
end

function M.handle_zoom(viewport, ctx, mx, my)
  if not mx or not my then
    return false
  end
  
  local ctrl = ImGui.IsKeyDown(ctx, ImGui.Key_LeftCtrl) or ImGui.IsKeyDown(ctx, ImGui.Key_RightCtrl)
  
  if not ctrl then
    return false
  end
  
  local wheel = ImGui.GetMouseWheel(ctx)
  if wheel == 0 then
    return false
  end
  
  local world_x, world_y = M.screen_to_world(viewport, mx, my)
  
  local old_scale = viewport.scale
  local new_scale = old_scale + (wheel * viewport.zoom_speed)
  new_scale = math.max(viewport.min_scale, math.min(viewport.max_scale, new_scale))
  
  viewport.scale = new_scale
  
  local new_screen_x, new_screen_y = M.world_to_screen(viewport, world_x, world_y)
  
  viewport.offset_x = viewport.offset_x + (mx - new_screen_x)
  viewport.offset_y = viewport.offset_y + (my - new_screen_y)
  
  return true
end



function M.handle_wheel_scroll(viewport, ctx)
  if not viewport.enable_wheel_scroll then
    return false
  end
  
  local ctrl = ImGui.IsKeyDown(ctx, ImGui.Key_LeftCtrl) or ImGui.IsKeyDown(ctx, ImGui.Key_RightCtrl)
  
  -- Don't handle wheel scroll if Ctrl is pressed (that's for zoom)
  if ctrl then
    return false
  end
  
  local wheel_v = ImGui.GetMouseWheel(ctx)
  
  if wheel_v == 0 then
    return false
  end
  
  -- Shift key modifies scroll direction (vertical becomes horizontal)
  local shift = ImGui.IsKeyDown(ctx, ImGui.Key_LeftShift) or ImGui.IsKeyDown(ctx, ImGui.Key_RightShift)
  
  if shift then
    -- Shift+wheel scrolls horizontally
    viewport.offset_x = viewport.offset_x + (wheel_v * viewport.scroll_speed)
  else
    -- Normal wheel scrolls vertically
    viewport.offset_y = viewport.offset_y + (wheel_v * viewport.scroll_speed)
  end
  
  return wheel_v ~= 0
end




function M.handle_pan(viewport, ctx)
  local middle_mouse = ImGui.IsMouseDown(ctx, 2)
  local space = ImGui.IsKeyDown(ctx, ImGui.Key_Space)
  local left_mouse = ImGui.IsMouseDown(ctx, 0)
  
  local should_pan = middle_mouse or (space and left_mouse)
  
  if should_pan and not viewport.is_panning then
    local mx, my = ImGui.GetMousePos(ctx)
    if not mx or not my then
      return false
    end
    
    viewport.is_panning = true
    viewport.pan_start_x = mx
    viewport.pan_start_y = my
    viewport.pan_start_offset_x = viewport.offset_x
    viewport.pan_start_offset_y = viewport.offset_y
    return true
  end
  
  if viewport.is_panning then
    if should_pan then
      local mx, my = ImGui.GetMousePos(ctx)
      if not mx or not my then
        return true
      end
      
      local dx = mx - viewport.pan_start_x
      local dy = my - viewport.pan_start_y
      
      viewport.offset_x = viewport.pan_start_offset_x + dx
      viewport.offset_y = viewport.pan_start_offset_y + dy
      return true
    else
      viewport.is_panning = false
    end
  end
  
  return false
end

function M.is_point_in_viewport(viewport, x, y)
  if not x or not y then
    return false
  end
  
  if not viewport.bounds_x or not viewport.bounds_y or 
     not viewport.bounds_w or not viewport.bounds_h then
    return false
  end
  
  return x >= viewport.bounds_x and 
         x <= viewport.bounds_x + viewport.bounds_w and
         y >= viewport.bounds_y and 
         y <= viewport.bounds_y + viewport.bounds_h
end

function M.update(viewport, ctx)
  local mx, my = ImGui.GetMousePos(ctx)
  
  if not mx or not my then
    return false
  end
  
  if not M.is_point_in_viewport(viewport, mx, my) then
    return false
  end
  
  -- Handle zoom first (Ctrl+wheel)
  local handled_zoom = M.handle_zoom(viewport, ctx, mx, my)
  if handled_zoom then
    return true
  end
  
  -- Handle wheel scrolling (plain wheel or shift+wheel)
  local handled_scroll = M.handle_wheel_scroll(viewport, ctx)
  if handled_scroll then
    return true
  end
  
  -- Handle panning (middle mouse or space+left mouse)
  local handled_pan = M.handle_pan(viewport, ctx)
  if handled_pan then
    return true
  end
  
  return false
end

function M.get_visible_world_bounds(viewport)
  if not viewport.bounds_x or not viewport.bounds_y or 
     not viewport.bounds_w or not viewport.bounds_h then
    return 0, 0, 0, 0
  end
  
  local world_x1, world_y1 = M.screen_to_world(viewport, viewport.bounds_x, viewport.bounds_y)
  local world_x2, world_y2 = M.screen_to_world(viewport, 
    viewport.bounds_x + viewport.bounds_w, 
    viewport.bounds_y + viewport.bounds_h)
  
  return world_x1, world_y1, world_x2 - world_x1, world_y2 - world_y1
end

function M.reset(viewport)
  viewport.offset_x = 0
  viewport.offset_y = 0
  viewport.scale = 1.0
  viewport.is_panning = false
end

function M.center_on_point(viewport, world_x, world_y)
  if not viewport.bounds_x or not viewport.bounds_y or 
     not viewport.bounds_w or not viewport.bounds_h then
    return
  end
  
  local center_screen_x = viewport.bounds_x + viewport.bounds_w / 2
  local center_screen_y = viewport.bounds_y + viewport.bounds_h / 2
  
  local screen_x, screen_y = M.world_to_screen(viewport, world_x, world_y)
  
  viewport.offset_x = viewport.offset_x + (center_screen_x - screen_x)
  viewport.offset_y = viewport.offset_y + (center_screen_y - screen_y)
end

return M