-- @noindex
-- arkitekt/gui/widgets/primitives/badge.lua
-- Standardized badge rendering system with consistent styling

local ImGui = require('arkitekt.core.imgui')
local Colors = require('arkitekt.core.colors')
local Base = require('arkitekt.gui.widgets.base')

local M = {}

-- ============================================================================
-- DEFAULTS
-- ============================================================================

local DEFAULTS = {
  x = 0,
  y = 0,
  size = 18,
  text = '',
  icon = nil,
  base_color = 0x555555FF,
  alpha = 255,
  bg_color = 0x14181CFF,
  text_color = 0xFFFFFFDD,
  icon_color = 0xFFFFFFFF,
  padding_x = 5,
  padding_y = 1,
  rounding = 3,
  border_alpha = 0x55,
  border_darken = 0.4,
  icon_font = nil,
  icon_font_size = 14,
  id = nil,
  on_click = nil,
  draw_list = nil,
  is_favorite = false,
}

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function M.Text(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)

  local dl = Base.get_draw_list(ctx, opts)
  local x, y = opts.x, opts.y
  local text = opts.text or ''
  local alpha = opts.alpha or 255

  local text_w, text_h = ImGui.CalcTextSize(ctx, text)
  local w = text_w + opts.padding_x * 2
  local h = text_h + opts.padding_y * 2
  local x2, y2 = x + w, y + h

  -- Background
  local bg_alpha = math.floor((opts.bg_color & 0xFF) * (alpha / 255))
  local bg = (opts.bg_color & 0xFFFFFF00) | bg_alpha
  ImGui.DrawList_AddRectFilled(dl, x, y, x2, y2, bg, opts.rounding)

  -- Border
  local border = Colors.AdjustBrightness(opts.base_color, opts.border_darken)
  border = Colors.WithAlpha(border, opts.border_alpha)
  ImGui.DrawList_AddRect(dl, x, y, x2, y2, border, opts.rounding, 0, 0.5)

  -- Text
  local text_color = Colors.WithAlpha(opts.text_color, alpha)
  ImGui.DrawList_AddText(dl, x + opts.padding_x, y + opts.padding_y, text_color, text)

  return Base.create_result({ x1 = x, y1 = y, x2 = x2, y2 = y2, width = w, height = h })
end

function M.Icon(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)

  local dl = Base.get_draw_list(ctx, opts)
  local x, y = opts.x, opts.y
  local size = opts.size or 18
  local icon_char = opts.icon or ''
  local alpha = opts.alpha or 255
  local x2, y2 = x + size, y + size

  -- Background
  local bg_alpha = math.floor((opts.bg_color & 0xFF) * (alpha / 255))
  local bg = (opts.bg_color & 0xFFFFFF00) | bg_alpha
  ImGui.DrawList_AddRectFilled(dl, x, y, x2, y2, bg, opts.rounding)

  -- Border
  local border = Colors.AdjustBrightness(opts.base_color, opts.border_darken)
  border = Colors.WithAlpha(border, opts.border_alpha)
  ImGui.DrawList_AddRect(dl, x, y, x2, y2, border, opts.rounding, 0, 0.5)

  -- Icon
  if opts.icon_font then
    ImGui.PushFont(ctx, opts.icon_font, opts.icon_font_size or 14)
  end

  local icon_color = Colors.WithAlpha(opts.icon_color, alpha)
  local icon_w, icon_h = ImGui.CalcTextSize(ctx, icon_char)
  ImGui.DrawList_AddText(dl, x + (size - icon_w) / 2, y + (size - icon_h) / 2, icon_color, icon_char)

  if opts.icon_font then
    ImGui.PopFont(ctx)
  end

  return Base.create_result({ x1 = x, y1 = y, x2 = x2, y2 = y2, width = size, height = size })
end

function M.Clickable(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)

  local result = M.Text(ctx, opts)

  local unique_id = opts.id or 'badge'
  ImGui.SetCursorScreenPos(ctx, result.x1, result.y1)
  ImGui.InvisibleButton(ctx, '##badge_' .. unique_id, result.width, result.height)

  local left_clicked = ImGui.IsItemClicked(ctx, 0)
  local right_clicked = ImGui.IsItemClicked(ctx, 1)

  if opts.on_click then
    if left_clicked then opts.on_click(1)
    elseif right_clicked then opts.on_click(-1)
    end
  end

  return Base.create_result({
    x1 = result.x1, y1 = result.y1, x2 = result.x2, y2 = result.y2,
    width = result.width, height = result.height,
    clicked = left_clicked, right_clicked = right_clicked,
  })
end

function M.Favorite(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)

  if not opts.is_favorite then
    return Base.create_result({ x1 = opts.x, y1 = opts.y, x2 = opts.x, y2 = opts.y, width = 0, height = 0 })
  end

  local star_char = opts.icon_font and utf8.char(0xF186) or '★'
  opts.icon = star_char
  return M.Icon(ctx, opts)
end

-- ============================================================================
-- MODULE EXPORT
-- ============================================================================

return setmetatable(M, {
  __call = function(_, ctx, opts)
    return M.Text(ctx, opts)
  end
})
