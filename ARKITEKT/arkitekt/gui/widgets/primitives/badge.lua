-- @noindex
-- arkitekt/gui/widgets/primitives/badge.lua
-- Standardized badge rendering system with consistent styling
-- Uses unified opts-based API

local ImGui = require('arkitekt.core.imgui')
local Colors = require('arkitekt.core.colors')
local Base = require('arkitekt.gui.widgets.base')

local M = {}

-- PERF: Localize functions for hot paths
local DrawList_AddRectFilled = ImGui.DrawList_AddRectFilled
local DrawList_AddRect = ImGui.DrawList_AddRect
local DrawList_AddText = ImGui.DrawList_AddText
local CalcTextSize = ImGui.CalcTextSize
local Colors_AdjustBrightness = Colors.AdjustBrightness
local Colors_WithAlpha = Colors.WithAlpha
local floor = math.floor

-- ============================================================================
-- DEFAULTS
-- ============================================================================

M.DEFAULTS = {
  -- Position
  x = 0,
  y = 0,

  -- Size
  size = 18,  -- For icon badges

  -- Content
  text = '',
  icon = nil,

  -- Colors
  base_color = 0x555555FF,  -- For border derivation
  alpha = 255,
  bg_color = 0x14181CFF,
  text_color = 0xFFFFFFDD,
  icon_color = 0xFFFFFFFF,

  -- Style
  padding_x = 5,
  padding_y = 1,
  rounding = 3,
  border_alpha = 0x55,
  border_darken = 0.4,

  -- Font
  icon_font = nil,
  icon_font_size = 14,

  -- Interaction
  id = nil,
  on_click = nil,

  -- Draw list
  draw_list = nil,
}

-- ============================================================================
-- INTERNAL HELPERS
-- ============================================================================

-- PERF: Reusable result table (avoid allocation per call)
-- Only use for non-concurrent calls (single-threaded Lua is fine)
local _result = {
  x1 = 0, y1 = 0, x2 = 0, y2 = 0, width = 0, height = 0,
  left_clicked = false, right_clicked = false, clicked = false,  -- For Clickable
}

-- NOTE: merge_config removed - opts already has metatable fallback to DEFAULTS
-- from Base.parse_opts, so opts.padding_x falls back to M.DEFAULTS.padding_x

-- ============================================================================
-- PUBLIC API (Standardized)
-- ============================================================================

--- Render a text badge
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result { x1, y1, x2, y2, width, height } (reused table - don't store reference!)
function M.Text(ctx, opts)
  -- PERF: parse_opts sets metatable so opts.X falls back to M.DEFAULTS.X
  opts = Base.parse_opts(opts, M.DEFAULTS)

  local dl = opts.draw_list or ImGui.GetWindowDrawList(ctx)
  local x, y = opts.x, opts.y
  local text = opts.text or ''
  local base_color = opts.base_color
  local alpha = opts.alpha or 255

  -- PERF: Read config directly from opts (metatable fallback, no allocation)
  local padding_x = opts.padding_x
  local padding_y = opts.padding_y
  local rounding = opts.rounding
  local bg_color = opts.bg_color
  local border_alpha = opts.border_alpha
  local border_darken = opts.border_darken
  local text_color = opts.text_color

  -- Calculate dimensions
  local text_w, text_h = CalcTextSize(ctx, text)
  local badge_w = text_w + padding_x * 2
  local badge_h = text_h + padding_y * 2

  local x2 = x + badge_w
  local y2 = y + badge_h

  -- Background
  local bg_a = floor((bg_color & 0xFF) * (alpha / 255))
  local bg = (bg_color & 0xFFFFFF00) | bg_a
  DrawList_AddRectFilled(dl, x, y, x2, y2, bg, rounding)

  -- Border using darker tile color
  local border_color = Colors_AdjustBrightness(base_color, border_darken)
  border_color = Colors_WithAlpha(border_color, border_alpha)
  DrawList_AddRect(dl, x, y, x2, y2, border_color, rounding, 0, 0.5)

  -- Text
  local text_x = x + padding_x
  local text_y = y + padding_y
  local text_final = (text_color & 0xFFFFFF00) | alpha
  DrawList_AddText(dl, text_x, text_y, text_final, text)

  -- PERF: Reuse result table (caller must not store reference)
  _result.x1 = x
  _result.y1 = y
  _result.x2 = x2
  _result.y2 = y2
  _result.width = badge_w
  _result.height = badge_h
  return _result
end

--- Render an icon badge
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result { x1, y1, x2, y2, width, height } (reused table - don't store reference!)
function M.Icon(ctx, opts)
  opts = Base.parse_opts(opts, M.DEFAULTS)

  local dl = opts.draw_list or ImGui.GetWindowDrawList(ctx)
  local x, y = opts.x, opts.y
  local size = opts.size or 18
  local icon_char = opts.icon or ''
  local base_color = opts.base_color
  local alpha = opts.alpha or 255

  -- PERF: Read config directly from opts (metatable fallback, no allocation)
  local rounding = opts.rounding
  local bg_color = opts.bg_color
  local border_alpha = opts.border_alpha
  local border_darken = opts.border_darken
  local icon_color = opts.icon_color

  local x2 = x + size
  local y2 = y + size

  -- Background
  local bg_a = floor((bg_color & 0xFF) * (alpha / 255))
  local bg = (bg_color & 0xFFFFFF00) | bg_a
  DrawList_AddRectFilled(dl, x, y, x2, y2, bg, rounding)

  -- Border using darker tile color
  local border_c = Colors_AdjustBrightness(base_color, border_darken)
  border_c = Colors_WithAlpha(border_c, border_alpha)
  DrawList_AddRect(dl, x, y, x2, y2, border_c, rounding, 0, 0.5)

  -- Icon
  if opts.icon_font then
    ImGui.PushFont(ctx, opts.icon_font, opts.icon_font_size or 14)
  end

  local icon_c = (icon_color & 0xFFFFFF00) | alpha
  local icon_w, icon_h = CalcTextSize(ctx, icon_char)
  local icon_x = x + (size - icon_w) / 2
  local icon_y = y + (size - icon_h) / 2
  DrawList_AddText(dl, icon_x, icon_y, icon_c, icon_char)

  if opts.icon_font then
    ImGui.PopFont(ctx)
  end

  -- PERF: Reuse result table (caller must not store reference)
  _result.x1 = x
  _result.y1 = y
  _result.x2 = x2
  _result.y2 = y2
  _result.width = size
  _result.height = size
  return _result
end

--- Render a clickable text badge
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result { x1, y1, x2, y2, width, height, left_clicked, right_clicked } (reused table!)
function M.Clickable(ctx, opts)
  opts = Base.parse_opts(opts, M.DEFAULTS)

  -- Render the text badge first (result is _result, reused)
  local result = M.Text(ctx, opts)

  -- Create invisible button over badge
  local unique_id = opts.id or 'badge'
  ImGui.SetCursorScreenPos(ctx, result.x1, result.y1)
  ImGui.InvisibleButton(ctx, '##badge_' .. unique_id, result.width, result.height)

  -- Handle clicks
  local left_clicked = ImGui.IsItemClicked(ctx, 0)
  local right_clicked = ImGui.IsItemClicked(ctx, 1)

  if opts.on_click then
    if left_clicked then
      opts.on_click(1)  -- Left-click: increment (+1)
    elseif right_clicked then
      opts.on_click(-1)  -- Right-click: decrement (-1)
    end
  end

  -- Set click fields on reused result table
  _result.left_clicked = left_clicked
  _result.right_clicked = right_clicked
  _result.clicked = left_clicked

  return _result
end

--- Render a favorite badge (star icon)
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result { x1, y1, x2, y2, width, height } (reused table!)
function M.Favorite(ctx, opts)
  opts = Base.parse_opts(opts, M.DEFAULTS)

  -- Return empty result if not favorited (reuse _result to avoid allocation)
  if not opts.is_favorite then
    _result.x1 = opts.x
    _result.y1 = opts.y
    _result.x2 = opts.x
    _result.y2 = opts.y
    _result.width = 0
    _result.height = 0
    return _result
  end

  -- Use remixicon star-fill if available, otherwise fallback to Unicode star
  local star_char
  if opts.icon_font then
    star_char = utf8.char(0xF186)  -- Remixicon star-fill
  else
    star_char = '★'  -- U+2605 BLACK STAR
  end

  opts.icon = star_char
  return M.Icon(ctx, opts)
end

-- ============================================================================
-- FAST PATH API (for hot loops - no allocations, no opts parsing)
-- ============================================================================

--- Draw a text badge directly without opts parsing or table allocations
--- PERF: Use this in hot paths (tile rendering) instead of M.Text
--- @param dl userdata Draw list
--- @param x number X position
--- @param y number Y position
--- @param text string Badge text
--- @param text_w number Pre-computed text width (from CalcTextSize)
--- @param text_h number Pre-computed text height (from CalcTextSize)
--- @param base_color number Base color for border derivation
--- @param alpha number Alpha (0-255)
--- @param cfg table Config with: padding_x, padding_y, rounding, bg_color, border_alpha, border_darken, text_color
--- @return number, number, number, number x1, y1, x2, y2 (badge bounds)
function M.TextDirect(dl, x, y, text, text_w, text_h, base_color, alpha, cfg)
  local badge_w = text_w + cfg.padding_x * 2
  local badge_h = text_h + cfg.padding_y * 2
  local x2 = x + badge_w
  local y2 = y + badge_h

  -- Background
  local bg_alpha = floor((cfg.bg_color & 0xFF) * (alpha / 255))
  local bg_color = (cfg.bg_color & 0xFFFFFF00) | bg_alpha
  DrawList_AddRectFilled(dl, x, y, x2, y2, bg_color, cfg.rounding)

  -- Border using darker base color
  local border_color = Colors_AdjustBrightness(base_color, cfg.border_darken)
  border_color = Colors_WithAlpha(border_color, cfg.border_alpha)
  DrawList_AddRect(dl, x, y, x2, y2, border_color, cfg.rounding, 0, 0.5)

  -- Text
  local text_x = x + cfg.padding_x
  local text_y = y + cfg.padding_y
  local text_final = (cfg.text_color & 0xFFFFFF00) | alpha
  DrawList_AddText(dl, text_x, text_y, text_final, text)

  return x, y, x2, y2
end

-- ============================================================================
-- MODULE EXPORT (Callable)
-- ============================================================================

-- Make module callable: Ark.Badge(ctx, opts) → M.Text(ctx, opts)
-- Default to text badge as it's the most common variant
return setmetatable(M, {
  __call = function(_, ctx, opts)
    return M.Text(ctx, opts)
  end
})
