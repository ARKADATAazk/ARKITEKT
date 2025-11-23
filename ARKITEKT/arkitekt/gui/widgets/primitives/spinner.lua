-- @noindex
-- arkitekt/gui/widgets/primitives/spinner.lua
-- Standardized spinner widget with Arkitekt styling
-- Uses unified opts-based API

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Colors = require('arkitekt.core.colors')
local Style = require('arkitekt.gui.style.defaults')
local Base = require('arkitekt.gui.widgets.base')

local hexrgb = Colors.hexrgb

local M = {}

-- ============================================================================
-- DEFAULTS
-- ============================================================================

local DEFAULTS = {
  -- Identity
  id = "spinner",

  -- Position (nil = use cursor)
  x = nil,
  y = nil,

  -- Size
  width = 200,
  height = 24,
  button_width = 24,
  spacing = 2,

  -- State
  value = 1,         -- Current index (1-based)
  options = {},      -- Array of values to cycle through
  disabled = false,

  -- Callbacks
  on_change = nil,

  -- Cursor control
  advance = "vertical",

  -- Draw list
  draw_list = nil,
}

-- ============================================================================
-- INTERNAL RENDERING
-- ============================================================================

local function draw_arrow(dl, x, y, w, h, color, direction)
  local cx = math.floor(x + w / 2 + 0.5)
  local cy = math.floor(y + h / 2 + 0.5)
  local size = math.floor(math.min(w, h) * 0.35 + 0.5)

  if direction == "left" then
    local x1 = math.floor(cx + size * 0.4 + 0.5)
    local y1 = math.floor(cy - size * 0.6 + 0.5)
    local x2 = math.floor(cx + size * 0.4 + 0.5)
    local y2 = math.floor(cy + size * 0.6 + 0.5)
    local x3 = math.floor(cx - size * 0.6 + 0.5)
    local y3 = cy
    ImGui.DrawList_AddTriangleFilled(dl, x1, y1, x2, y2, x3, y3, color)
  else
    local x1 = math.floor(cx - size * 0.4 + 0.5)
    local y1 = math.floor(cy - size * 0.6 + 0.5)
    local x2 = math.floor(cx - size * 0.4 + 0.5)
    local y2 = math.floor(cy + size * 0.6 + 0.5)
    local x3 = math.floor(cx + size * 0.6 + 0.5)
    local y3 = cy
    ImGui.DrawList_AddTriangleFilled(dl, x1, y1, x2, y2, x3, y3, color)
  end
end

local function draw_spinner_button(ctx, id, x, y, w, h, direction, disabled)
  local dl = ImGui.GetWindowDrawList(ctx)

  x = math.floor(x + 0.5)
  y = math.floor(y + 0.5)
  w = math.floor(w + 0.5)
  h = math.floor(h + 0.5)

  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, id, w, h)

  local hovered = not disabled and ImGui.IsItemHovered(ctx)
  local active = not disabled and ImGui.IsItemActive(ctx)
  local clicked = not disabled and ImGui.IsItemClicked(ctx, 0)

  -- Get state colors
  local bg_color, border_inner, border_outer, arrow_color

  if disabled then
    bg_color = Colors.with_alpha(Style.COLORS.BG_BASE, 0x80)
    border_inner = Colors.with_alpha(Style.COLORS.BORDER_INNER, 0x80)
    border_outer = Colors.with_alpha(Style.COLORS.BORDER_OUTER, 0x80)
    arrow_color = Colors.with_alpha(Style.COLORS.TEXT_NORMAL, 0x80)
  elseif active then
    bg_color = Style.COLORS.BG_ACTIVE
    border_inner = Style.COLORS.BORDER_HOVER
    border_outer = Style.COLORS.BORDER_OUTER
    arrow_color = Style.COLORS.TEXT_HOVER
  elseif hovered then
    bg_color = Style.COLORS.BG_HOVER
    border_inner = Style.COLORS.BORDER_HOVER
    border_outer = Style.COLORS.BORDER_OUTER
    arrow_color = Style.COLORS.TEXT_HOVER
  else
    bg_color = Style.COLORS.BG_BASE
    border_inner = Style.COLORS.BORDER_INNER
    border_outer = Style.COLORS.BORDER_OUTER
    arrow_color = Style.COLORS.TEXT_NORMAL
  end

  -- Background
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, bg_color, 0)

  -- Borders
  ImGui.DrawList_AddRect(dl, x + 1, y + 1, x + w - 1, y + h - 1, border_inner, 0, 0, 1)
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, border_outer, 0, 0, 1)

  -- Arrow
  draw_arrow(dl, x, y, w, h, arrow_color, direction)

  return clicked
end

local function draw_value_display(ctx, dl, x, y, w, h, text, hovered, active, disabled)
  x = math.floor(x + 0.5)
  y = math.floor(y + 0.5)
  w = math.floor(w + 0.5)
  h = math.floor(h + 0.5)

  local bg_color, border_inner, border_outer, text_color

  if disabled then
    bg_color = Colors.with_alpha(Style.COLORS.BG_BASE, 0x80)
    border_inner = Colors.with_alpha(Style.COLORS.BORDER_INNER, 0x80)
    border_outer = Colors.with_alpha(Style.COLORS.BORDER_OUTER, 0x80)
    text_color = Colors.with_alpha(Style.COLORS.TEXT_NORMAL, 0x80)
  elseif active then
    bg_color = Style.COLORS.BG_ACTIVE
    border_inner = Style.COLORS.BORDER_HOVER
    border_outer = Style.COLORS.BORDER_OUTER
    text_color = Style.COLORS.TEXT_HOVER
  elseif hovered then
    bg_color = Style.COLORS.BG_HOVER
    border_inner = Style.COLORS.BORDER_HOVER
    border_outer = Style.COLORS.BORDER_OUTER
    text_color = Style.COLORS.TEXT_HOVER
  else
    bg_color = Style.COLORS.BG_BASE
    border_inner = Style.COLORS.BORDER_INNER
    border_outer = Style.COLORS.BORDER_OUTER
    text_color = Style.COLORS.TEXT_NORMAL
  end

  -- Background
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, bg_color, 0)

  -- Borders
  ImGui.DrawList_AddRect(dl, x + 1, y + 1, x + w - 1, y + h - 1, border_inner, 0, 0, 1)
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, border_outer, 0, 0, 1)

  -- Text (centered with truncation)
  local text_w, text_h = ImGui.CalcTextSize(ctx, text)
  local max_text_w = w - 12

  if text_w > max_text_w then
    local est_chars = math.floor((max_text_w / text_w) * #text * 0.9)
    est_chars = math.max(1, math.min(est_chars, #text - 3))
    text = text:sub(1, est_chars) .. "..."
    text_w = ImGui.CalcTextSize(ctx, text)

    while text_w > max_text_w and est_chars > 1 do
      est_chars = est_chars - 1
      text = text:sub(1, est_chars) .. "..."
      text_w = ImGui.CalcTextSize(ctx, text)
    end
  end

  local text_x = math.floor(x + (w - text_w) / 2 + 0.5)
  local text_y = math.floor(y + (h - text_h) / 2 + 0.5)

  ImGui.DrawList_AddText(dl, text_x, text_y, text_color, text)
end

-- ============================================================================
-- PUBLIC API (Standardized)
-- ============================================================================

--- Draw a spinner widget
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result { changed, value, width, height }
function M.draw(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)

  -- Resolve unique ID
  local unique_id = Base.resolve_id(opts, "spinner")

  -- Get position and draw list
  local x, y = Base.get_position(ctx, opts)
  local dl = Base.get_draw_list(ctx, opts)

  -- Get size
  local total_w = opts.width or 200
  local h = opts.height or 24
  local button_w = opts.button_width or 24
  local spacing = opts.spacing or 2

  -- Get state
  local current_index = opts.value or 1
  local options = opts.options or {}
  local disabled = opts.disabled or false

  current_index = math.max(1, math.min(current_index, #options))

  local changed = false
  local new_index = current_index

  -- Round starting position
  x = math.floor(x + 0.5)
  y = math.floor(y + 0.5)

  -- Calculate layout
  local value_w = math.floor(total_w - (button_w * 2) - (spacing * 2) + 0.5)
  local left_x = x
  local value_x = x + button_w + spacing
  local right_x = x + button_w + spacing + value_w + spacing

  -- Left arrow button
  if draw_spinner_button(ctx, unique_id .. "_left", left_x, y, button_w, h, "left", disabled) then
    new_index = new_index - 1
    if new_index < 1 then new_index = #options end
    changed = true
  end

  -- Value display with dropdown
  ImGui.SetCursorScreenPos(ctx, value_x, y)
  ImGui.InvisibleButton(ctx, unique_id .. "_value", value_w, h)

  local value_hovered = not disabled and ImGui.IsItemHovered(ctx)
  local value_active = not disabled and ImGui.IsItemActive(ctx)
  local value_clicked = not disabled and ImGui.IsItemClicked(ctx, 0)

  local current_text = tostring(options[current_index] or "")
  draw_value_display(ctx, dl, value_x, y, value_w, h, current_text, value_hovered, value_active, disabled)

  -- Popup dropdown
  if value_clicked then
    ImGui.OpenPopup(ctx, unique_id .. "_popup")
  end

  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 4, 4)
  ImGui.PushStyleColor(ctx, ImGui.Col_PopupBg, Style.DROPDOWN_COLORS.popup_bg)
  ImGui.PushStyleColor(ctx, ImGui.Col_Border, Style.DROPDOWN_COLORS.popup_border)

  if ImGui.BeginPopup(ctx, unique_id .. "_popup") then
    for i, value in ipairs(options) do
      local is_selected = (i == current_index)
      local item_text = tostring(value)

      if is_selected then
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, Style.DROPDOWN_COLORS.item_text_selected)
      end

      if ImGui.Selectable(ctx, item_text, is_selected) then
        new_index = i
        changed = true
      end

      if is_selected then
        ImGui.PopStyleColor(ctx)
      end
    end
    ImGui.EndPopup(ctx)
  end

  ImGui.PopStyleColor(ctx, 2)
  ImGui.PopStyleVar(ctx, 1)

  -- Right arrow button
  if draw_spinner_button(ctx, unique_id .. "_right", right_x, y, button_w, h, "right", disabled) then
    new_index = new_index + 1
    if new_index > #options then new_index = 1 end
    changed = true
  end

  -- Call change callback
  if changed and opts.on_change then
    opts.on_change(new_index, options[new_index])
  end

  -- Advance cursor
  Base.advance_cursor(ctx, x, y, total_w, h, opts.advance)

  -- Return standardized result
  return Base.create_result({
    changed = changed,
    value = new_index,
    width = total_w,
    height = h,
  })
end

return M
