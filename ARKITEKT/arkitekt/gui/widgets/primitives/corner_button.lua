-- @noindex
-- Arkitekt/gui/widgets/controls/corner_button.lua
-- Corner-shaped button control with asymmetric rounding suitable for panel corners

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Style = require('arkitekt.gui.style.defaults')

local M = {}

-- Instance storage for hover animation
local instances = {}

local function get_instance(id)
  local inst = instances[id]
  if not inst then
    inst = { hover_alpha = 0 }
    instances[id] = inst
  end
  return inst
end

-- High-quality rounded rect path (localized to avoid coupling)
local function snap_pixel(v)
  return math.floor(v + 0.5)
end

local function draw_rounded_rect_path(dl, x1, y1, x2, y2, color, filled, rt, rr, rb, rl, thickness)
  x1 = snap_pixel(x1)
  y1 = snap_pixel(y1)
  x2 = snap_pixel(x2)
  y2 = snap_pixel(y2)

  if not filled and thickness == 1 then
    x1 = x1 + 0.5
    y1 = y1 + 0.5
    x2 = x2 - 0.5
    y2 = y2 - 0.5
  end

  local w = x2 - x1
  local h = y2 - y1
  local max_r = math.min(w, h) * 0.5
  rt = math.min(rt or 0, max_r)
  rr = math.min(rr or 0, max_r)
  rb = math.min(rb or 0, max_r)
  rl = math.min(rl or 0, max_r)

  local function segs(r)
    if r <= 0 then return 0 end
    return math.max(4, math.floor(r * 0.6))
  end

  ImGui.DrawList_PathClear(dl)

  if rt > 0 then
    ImGui.DrawList_PathArcTo(dl, x1 + rt, y1 + rt, rt, math.pi, math.pi * 1.5, segs(rt))
  else
    ImGui.DrawList_PathLineTo(dl, x1, y1)
  end

  if rr > 0 then
    ImGui.DrawList_PathArcTo(dl, x2 - rr, y1 + rr, rr, math.pi * 1.5, math.pi * 2.0, segs(rr))
  else
    ImGui.DrawList_PathLineTo(dl, x2, y1)
  end

  if rb > 0 then
    ImGui.DrawList_PathArcTo(dl, x2 - rb, y2 - rb, rb, 0, math.pi * 0.5, segs(rb))
  else
    ImGui.DrawList_PathLineTo(dl, x2, y2)
  end

  if rl > 0 then
    ImGui.DrawList_PathArcTo(dl, x1 + rl, y2 - rl, rl, math.pi * 0.5, math.pi, segs(rl))
  else
    ImGui.DrawList_PathLineTo(dl, x1, y2)
  end

  if filled then
    ImGui.DrawList_PathFillConvex(dl, color)
  else
    ImGui.DrawList_PathStroke(dl, color, ImGui.DrawFlags_Closed, thickness or 1)
  end
end

local function draw_corner_shape(dl, x, y, size, bg, border_inner, border_outer, outer_rounding, inner_rounding, position)
  local rtl, rtr, rbr, rbl = 0, 0, 0, 0
  if position == 'tl' then
    rtl = outer_rounding; rbr = inner_rounding
  elseif position == 'tr' then
    rtr = outer_rounding; rbl = inner_rounding
  elseif position == 'bl' then
    rbl = outer_rounding; rtr = inner_rounding
  elseif position == 'br' then
    rbr = outer_rounding; rtl = inner_rounding
  end

  local itl = math.max(0, rtl - 2)
  local itr = math.max(0, rtr - 2)
  local ibr = math.max(0, rbr - 2)
  local ibl = math.max(0, rbl - 2)

  draw_rounded_rect_path(dl, x, y, x + size, y + size, bg, true, itl, itr, ibr, ibl)
  draw_rounded_rect_path(dl, x + 1, y + 1, x + size - 1, y + size - 1, border_inner, false, itl, itr, ibr, ibl, 1)
  draw_rounded_rect_path(dl, x, y, x + size, y + size, border_outer, false, itl, itr, ibr, ibl, 1)
end

-- API:
-- CornerButton.draw(ctx, dl, x, y, size, config, unique_id, outer_rounding, inner_rounding, position)
function M.draw(ctx, dl, x, y, size, user_config, unique_id, outer_rounding, inner_rounding, position)
  local config = Style.apply_defaults(Style.BUTTON, user_config)
  local inst = get_instance(unique_id)

  local is_blocking = config.is_blocking or false
  local hovered = false
  local active = false

  if not is_blocking then
    hovered = ImGui.IsMouseHoveringRect(ctx, x, y, x + size, y + size)
    active = hovered and ImGui.IsMouseDown(ctx, 0)
  end

  local dt = ImGui.GetDeltaTime(ctx)
  local target = (hovered or active) and 1.0 or 0.0

  -- Reset hover alpha immediately when blocking (don't animate)
  if is_blocking then
    inst.hover_alpha = 0
  else
    inst.hover_alpha = inst.hover_alpha + (target - inst.hover_alpha) * 12.0 * dt
    inst.hover_alpha = math.max(0, math.min(1, inst.hover_alpha))
  end

  local bg = config.bg_color
  local border_inner = config.border_inner_color
  local text = config.text_color

  if active then
    bg = config.bg_active_color or bg
    border_inner = config.border_active_color or border_inner
    text = config.text_active_color or text
  elseif inst.hover_alpha > 0.01 then
    bg = Style.RENDER.lerp_color(config.bg_color, config.bg_hover_color or config.bg_color, inst.hover_alpha)
    border_inner = Style.RENDER.lerp_color(config.border_inner_color, config.border_hover_color or config.border_inner_color, inst.hover_alpha)
    text = Style.RENDER.lerp_color(config.text_color, config.text_hover_color or config.text_color, inst.hover_alpha)
  end

  -- Draw button visuals
  draw_corner_shape(dl, x, y, size, bg, border_inner, config.border_outer_color, outer_rounding, inner_rounding, position)

  -- Support custom draw function or fallback to icon/label text
  if config.custom_draw then
    config.custom_draw(ctx, dl, x, y, size, size, hovered, active, text)
  else
    local label = config.icon or config.label or ''
    if label ~= '' then
      local tw, th = ImGui.CalcTextSize(ctx, label)
      local tx = x + (size - tw) * 0.5
      local ty = y + (size - th) * 0.5
      ImGui.DrawList_AddText(dl, tx, ty, text, label)
    end
  end

  -- Only create interactive button if no modal is blocking
  local clicked = false
  if not is_blocking then
    ImGui.SetCursorScreenPos(ctx, x, y)
    ImGui.InvisibleButton(ctx, '##' .. unique_id, size, size)
    clicked = ImGui.IsItemClicked(ctx, 0)
    if clicked and config.on_click then
      config.on_click()
    end

    -- Only show tooltip if not blocking
    if hovered and config.tooltip then
      ImGui.SetTooltip(ctx, config.tooltip)
    end
  end

  return clicked
end

return M