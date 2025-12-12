-- @noindex
-- arkitekt/gui/widgets/primitives/label_button.lua
-- Simple colored button with a text label
--
-- USAGE:
--   -- Positional mode (ImGui-like, returns boolean)
--   if Ark.LabelButton(ctx, 'combat') then handle_click() end
--
--   -- Opts mode (returns result object)
--   local r = Ark.LabelButton(ctx, {
--     label = 'combat',
--     bg_color = 0xB85C5CFF,
--   })
--   if r.clicked then handle_click() end

local ImGui = require('arkitekt.core.imgui')
local Base = require('arkitekt.gui.widgets.base')
local Draw = require('arkitekt.gui.draw.primitives')
local Colors = require('arkitekt.core.colors')

local M = {}

-- ============================================================================
-- CONSTANTS (cached for performance)
-- ============================================================================

local DEFAULT_BORDER = Colors.WithAlpha(0x000000FF, 100)
local INNER_SHADOW = Colors.WithAlpha(0x000000FF, 60)
local DISABLED_OPACITY = 0.5
local HOVER_BRIGHTNESS = 1.15
local ACTIVE_BRIGHTNESS = 0.85

-- ============================================================================
-- DEFAULTS
-- ============================================================================

local DEFAULTS = {
  id = nil,
  x = nil,
  y = nil,
  width = nil,
  explicit_width = nil,
  height = 24,
  label = '',
  is_disabled = false,
  is_interactive = true,
  rounding = 4,
  padding_h = 8,
  bg_color = 0x5B8FB9FF,
  text_color = 0x1A1A1AFF,
  border_color = nil,
  advance = 'vertical',
}

-- ============================================================================
-- WIDTH CALCULATION
-- ============================================================================

--- Calculate the width of a label button
--- @param ctx userdata ImGui context
--- @param label string Button label
--- @param opts table|nil Options: padding_h
--- @return number width
function M.calculate_width(ctx, label, opts)
  opts = opts or {}
  local padding_h = opts.padding_h or DEFAULTS.padding_h
  local text_w = ImGui.CalcTextSize(ctx, label or '')
  return text_w + padding_h * 2
end

-- ============================================================================
-- RENDERING
-- ============================================================================

--- Draw a label button
--- @param ctx userdata ImGui context
--- @param label_or_opts string|table Label string or opts table
--- @return table Result { clicked, hovered, active, width, height }
function M.Draw(ctx, label_or_opts)
  -- Hybrid parameter detection
  local opts
  if type(label_or_opts) == 'table' then
    opts = label_or_opts
  elseif type(label_or_opts) == 'string' then
    opts = { label = label_or_opts }
  else
    opts = {}
  end

  opts = Base.parse_opts(opts, DEFAULTS)

  -- Resolve unique ID
  local unique_id = Base.resolve_id(ctx, opts, 'label_btn')

  -- Get position and draw list
  local x, y = Base.get_position(ctx, opts)
  local dl = Base.get_draw_list(ctx, opts)

  -- Calculate size (avoid redundant CalcTextSize call)
  local label = opts.label
  local text_w, text_h = ImGui.CalcTextSize(ctx, label)
  local btn_w = opts.explicit_width or opts.width or (text_w + opts.padding_h * 2)
  local btn_h = opts.height

  -- Input handling
  local is_hovered = false
  local is_active = false
  local is_clicked = false

  if opts.is_interactive and not opts.is_disabled then
    ImGui.SetCursorScreenPos(ctx, x, y)
    ImGui.InvisibleButton(ctx, '##' .. unique_id, btn_w, btn_h)
    is_hovered = ImGui.IsItemHovered(ctx)
    is_active = ImGui.IsItemActive(ctx)
    is_clicked = ImGui.IsItemClicked(ctx)
  end

  -- Determine background color based on state
  local bg_color = opts.bg_color
  local draw_bg
  if opts.is_disabled then
    draw_bg = Colors.WithOpacity(bg_color, DISABLED_OPACITY)
  elseif is_active then
    draw_bg = Colors.AdjustBrightness(bg_color, ACTIVE_BRIGHTNESS)
  elseif is_hovered then
    draw_bg = Colors.AdjustBrightness(bg_color, HOVER_BRIGHTNESS)
  else
    draw_bg = bg_color
  end

  -- Draw background
  local rounding = opts.rounding
  ImGui.DrawList_AddRectFilled(dl, x, y, x + btn_w, y + btn_h, draw_bg, rounding)

  -- Draw border
  local border_color = opts.border_color or DEFAULT_BORDER
  ImGui.DrawList_AddRect(dl, x, y, x + btn_w, y + btn_h, border_color, rounding, 0, 1)

  -- Draw inner shadow when active
  if is_active then
    Draw.RectFilled(dl, x, y, x + btn_w, y + 2, INNER_SHADOW, 0)
  end

  -- Draw centered text
  local text_color = opts.is_disabled and Colors.WithOpacity(opts.text_color, DISABLED_OPACITY) or opts.text_color
  local text_x = x + (btn_w - text_w) * 0.5
  local text_y = y + (btn_h - text_h) * 0.5
  Draw.Text(dl, text_x, text_y, text_color, label)

  -- Advance cursor
  Base.advance_cursor(ctx, x, y, btn_w, btn_h, opts.advance)

  return Base.create_result({
    clicked = is_clicked,
    hovered = is_hovered,
    active = is_active,
    width = btn_w,
    height = btn_h,
  })
end

-- ============================================================================
-- MODULE EXPORT (Callable)
-- ============================================================================

return setmetatable(M, {
  __call = function(_, ctx, label_or_opts)
    if type(label_or_opts) == 'table' then
      return M.Draw(ctx, label_or_opts)
    else
      local result = M.Draw(ctx, { label = label_or_opts })
      return result.clicked
    end
  end
})
