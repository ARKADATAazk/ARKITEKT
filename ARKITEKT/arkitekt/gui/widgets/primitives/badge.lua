-- @noindex
-- Arkitekt/gui/widgets/primitives/badge.lua
-- Modular badge rendering system with consistent styling across the codebase

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Colors = require('arkitekt.core.colors')

local M = {}

-- Default badge configuration (can be overridden per badge)
M.DEFAULTS = {
  padding_x = 5,
  padding_y = 1,
  margin = 6,
  rounding = 3,
  bg = Colors.hexrgb("#14181C"),
  border_alpha = 0x55,
  border_darken = 0.4,
  text_color = Colors.hexrgb("#FFFFFFDD"),
}

---Render a text badge with background and border
---@param ctx userdata ImGui context
---@param dl userdata DrawList
---@param x number X position (top-left)
---@param y number Y position (top-left)
---@param text string Badge text content
---@param base_color number Base tile color (for border derivation)
---@param alpha number Overall alpha multiplier (0-255)
---@param config? table Optional config overrides
---@return number, number, number, number Badge rect (x1, y1, x2, y2)
function M.render_text_badge(ctx, dl, x, y, text, base_color, alpha, config)
  config = config or {}

  -- Merge with defaults
  local cfg = {
    padding_x = config.padding_x or M.DEFAULTS.padding_x,
    padding_y = config.padding_y or M.DEFAULTS.padding_y,
    rounding = config.rounding or M.DEFAULTS.rounding,
    bg = config.bg or M.DEFAULTS.bg,
    border_alpha = config.border_alpha or M.DEFAULTS.border_alpha,
    border_darken = config.border_darken or M.DEFAULTS.border_darken,
    text_color = config.text_color or M.DEFAULTS.text_color,
  }

  -- Calculate dimensions
  local text_w, text_h = ImGui.CalcTextSize(ctx, text)
  local badge_w = text_w + cfg.padding_x * 2
  local badge_h = text_h + cfg.padding_y * 2

  local x2 = x + badge_w
  local y2 = y + badge_h

  -- Background
  local bg_alpha = math.floor((cfg.bg & 0xFF) * (alpha / 255))
  local bg_color = (cfg.bg & 0xFFFFFF00) | bg_alpha
  ImGui.DrawList_AddRectFilled(dl, x, y, x2, y2, bg_color, cfg.rounding)

  -- Border using darker tile color
  local border_color = Colors.adjust_brightness(base_color, cfg.border_darken)
  border_color = Colors.with_alpha(border_color, cfg.border_alpha)
  ImGui.DrawList_AddRect(dl, x, y, x2, y2, border_color, cfg.rounding, 0, 0.5)

  -- Text
  local text_x = x + cfg.padding_x
  local text_y = y + cfg.padding_y
  local text_final = Colors.with_alpha(cfg.text_color, alpha)
  ImGui.DrawList_AddText(dl, text_x, text_y, text_final, text)

  return x, y, x2, y2
end

---Render an icon badge with background and border
---@param ctx userdata ImGui context
---@param dl userdata DrawList
---@param x number X position (top-left)
---@param y number Y position (top-left)
---@param size number Badge size (square)
---@param icon_char string Icon character (e.g., utf8.char(0xF186) for star-fill)
---@param base_color number Base tile color (for border derivation)
---@param alpha number Overall alpha multiplier (0-255)
---@param icon_font? userdata Optional icon font object
---@param icon_font_size? number Optional icon font size
---@param config? table Optional config overrides
---@return number, number, number, number Badge rect (x1, y1, x2, y2)
function M.render_icon_badge(ctx, dl, x, y, size, icon_char, base_color, alpha, icon_font, icon_font_size, config)
  config = config or {}

  -- Merge with defaults
  local cfg = {
    rounding = config.rounding or M.DEFAULTS.rounding,
    bg = config.bg or M.DEFAULTS.bg,
    border_alpha = config.border_alpha or M.DEFAULTS.border_alpha,
    border_darken = config.border_darken or M.DEFAULTS.border_darken,
    icon_color = config.icon_color or Colors.hexrgb("#FFFFFF"),
  }

  local x2 = x + size
  local y2 = y + size

  -- Background
  local bg_alpha = math.floor((cfg.bg & 0xFF) * (alpha / 255))
  local bg_color = (cfg.bg & 0xFFFFFF00) | bg_alpha
  ImGui.DrawList_AddRectFilled(dl, x, y, x2, y2, bg_color, cfg.rounding)

  -- Border using darker tile color
  local border_color = Colors.adjust_brightness(base_color, cfg.border_darken)
  border_color = Colors.with_alpha(border_color, cfg.border_alpha)
  ImGui.DrawList_AddRect(dl, x, y, x2, y2, border_color, cfg.rounding, 0, 0.5)

  -- Icon
  if icon_font then
    ImGui.PushFont(ctx, icon_font, icon_font_size or 14)
  end

  local icon_color = Colors.with_alpha(cfg.icon_color, alpha)
  local icon_w, icon_h = ImGui.CalcTextSize(ctx, icon_char)
  local icon_x = x + (size - icon_w) / 2
  local icon_y = y + (size - icon_h) / 2
  ImGui.DrawList_AddText(dl, icon_x, icon_y, icon_color, icon_char)

  if icon_font then
    ImGui.PopFont(ctx)
  end

  return x, y, x2, y2
end

---Render a clickable badge with text
---Creates an invisible button over the badge for click detection
---@param ctx userdata ImGui context
---@param dl userdata DrawList
---@param x number X position (top-left)
---@param y number Y position (top-left)
---@param text string Badge text content
---@param base_color number Base tile color (for border derivation)
---@param alpha number Overall alpha multiplier (0-255)
---@param unique_id string Unique ID for the button
---@param on_click? function Optional click callback
---@param config? table Optional config overrides
---@return number, number, number, number Badge rect (x1, y1, x2, y2)
function M.render_clickable_text_badge(ctx, dl, x, y, text, base_color, alpha, unique_id, on_click, config)
  local x1, y1, x2, y2 = M.render_text_badge(ctx, dl, x, y, text, base_color, alpha, config)

  -- Create invisible button over badge
  ImGui.SetCursorScreenPos(ctx, x1, y1)
  ImGui.InvisibleButton(ctx, "##badge_" .. unique_id, x2 - x1, y2 - y1)

  -- Handle left-click (increment) and right-click (decrement)
  if on_click then
    if ImGui.IsItemClicked(ctx, 0) then
      on_click(1)  -- Left-click: increment (+1)
    elseif ImGui.IsItemClicked(ctx, 1) then
      on_click(-1)  -- Right-click: decrement (-1)
    end
  end

  return x1, y1, x2, y2
end

---Render a favorite badge (star icon badge) with consistent styling
---@param ctx userdata ImGui context
---@param dl userdata DrawList
---@param x number X position (top-left)
---@param y number Y position (top-left)
---@param size number Badge size (square)
---@param alpha number Overall alpha multiplier (0-255)
---@param is_favorite boolean Whether the item is favorited
---@param icon_font? userdata Optional icon font object (remixicon)
---@param icon_font_size? number Optional icon font size
---@param base_color? number Optional base tile color for border derivation (defaults to neutral gray)
---@param config? table Optional config overrides
---@return number, number, number, number Badge rect (x1, y1, x2, y2)
function M.render_favorite_badge(ctx, dl, x, y, size, alpha, is_favorite, icon_font, icon_font_size, base_color, config)
  if not is_favorite then
    return x, y, x, y  -- Return empty rect if not favorited
  end

  -- Use remixicon star-fill if available, otherwise fallback to Unicode star
  local star_char
  if icon_font then
    -- Remixicon star-fill: U+F186
    star_char = utf8.char(0xF186)
  else
    -- Fallback to Unicode star character
    star_char = "★"  -- U+2605 BLACK STAR
  end

  -- Default base color if not provided
  base_color = base_color or Colors.hexrgb("#555555")

  -- Render using modular badge system
  return M.render_icon_badge(ctx, dl, x, y, size, star_char, base_color, alpha, icon_font, icon_font_size, config)
end

return M
