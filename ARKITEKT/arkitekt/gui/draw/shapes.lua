-- @noindex
-- Arkitekt/gui/rendering/shapes.lua
-- Shape rendering utilities for UI elements

local ImGui = require('arkitekt.core.imgui')
local Colors = require('arkitekt.core.colors')
local Badge = require('arkitekt.gui.widgets.primitives.badge')

local M = {}

--- Draw a favorite star indicator using modular badge system
--- Supports two calling conventions:
---   Opts mode:       draw_favorite_star(ctx, dl, x, y, size, alpha, is_favorite, icon_font, icon_font_size, base_color, config)
---   Positional mode: draw_favorite_star(dl, x, y, star_char, icon_w, icon_h, size, cfg)
--- Positional mode is zero-allocation for hot paths (caller must push/pop font and pre-compute cfg)
--- @param ctx_or_dl ImGui context (opts mode) or DrawList (positional mode)
function M.draw_favorite_star(ctx_or_dl, dl_or_x, x_or_y, y_or_char, size_or_icon_w, alpha_or_icon_h, is_favorite_or_size, icon_font_or_cfg, icon_font_size, base_color, config)
  -- Detect calling convention: positional mode if second arg is number
  if type(dl_or_x) == 'number' then
    -- Positional mode (fast, zero allocation)
    -- Args: dl, x, y, star_char, icon_w, icon_h, size, cfg
    -- cfg should have: bg_color, border, icon_color, rounding (all pre-computed with alpha)
    -- Caller must push/pop icon font if using one
    local dl = ctx_or_dl
    local x, y = dl_or_x, x_or_y
    local star_char = y_or_char
    local icon_w, icon_h = size_or_icon_w, alpha_or_icon_h
    local size = is_favorite_or_size
    local cfg = icon_font_or_cfg

    -- Delegate to Badge.Icon positional mode
    return Badge.Icon(dl, x, y, star_char, icon_w, icon_h, size, cfg)
  else
    -- Opts mode (flexible, allocates)
    local ctx, dl = ctx_or_dl, dl_or_x
    local x, y = x_or_y, y_or_char
    local size, alpha = size_or_icon_w, alpha_or_icon_h
    local is_favorite = is_favorite_or_size
    local icon_font = icon_font_or_cfg

    if not is_favorite then
      return  -- Only draw if favorited
    end

    -- Convert alpha from 0.0-1.0 to 0-255 for badge system
    local alpha_255 = (alpha * 255)//1

    -- Use remixicon star-fill if available, otherwise fallback to Unicode star
    local star_char
    if icon_font then
      -- Remixicon star-fill: U+F186
      star_char = utf8.char(0xF186)
    else
      -- Fallback to Unicode star character for cleaner rendering (no aliasing)
      star_char = '★'  -- U+2605 BLACK STAR
    end

    -- Default base color if not provided
    base_color = base_color or 0x555555FF

    -- Render using modular badge system
    Badge.Icon(ctx, {
      draw_list = dl,
      x = x,
      y = y,
      size = size,
      icon = star_char,
      base_color = base_color,
      alpha = alpha_255,
      icon_font = icon_font,
      icon_font_size = icon_font_size,
      rounding = config and config.rounding,
      bg_color = config and config.bg,
      border_alpha = config and config.border_alpha,
      border_darken = config and config.border_darken,
      icon_color = config and config.icon_color,
    })
  end
end

return M
