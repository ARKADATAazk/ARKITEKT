-- @noindex
-- ReArkitekt/gui/widgets/primitives/spinner.lua
-- Modern spinner widget with custom rendering to match ARKITEKT design language

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local Style = require('rearkitekt.gui.style.defaults')

local hexrgb = Colors.hexrgb

local M = {}

-- Draw a triangular arrow icon
local function draw_arrow(dl, x, y, w, h, color, direction)
  local cx = x + w / 2
  local cy = y + h / 2
  local size = math.min(w, h) * 0.35

  if direction == "left" then
    local x1, y1 = cx + size * 0.4, cy - size * 0.6
    local x2, y2 = cx + size * 0.4, cy + size * 0.6
    local x3, y3 = cx - size * 0.6, cy
    ImGui.DrawList_AddTriangleFilled(dl, x1, y1, x2, y2, x3, y3, color)
  else -- right
    local x1, y1 = cx - size * 0.4, cy - size * 0.6
    local x2, y2 = cx - size * 0.4, cy + size * 0.6
    local x3, y3 = cx + size * 0.6, cy
    ImGui.DrawList_AddTriangleFilled(dl, x1, y1, x2, y2, x3, y3, color)
  end
end

-- Draw a custom spinner button with modern styling
local function draw_spinner_button(ctx, id, x, y, w, h, direction)
  local dl = ImGui.GetWindowDrawList(ctx)

  -- Invisible button for interaction
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, id, w, h)

  local hovered = ImGui.IsItemHovered(ctx)
  local active = ImGui.IsItemActive(ctx)
  local clicked = ImGui.IsItemClicked(ctx, 0)

  -- Get state colors
  local bg_color = active and Style.COLORS.BG_ACTIVE or (hovered and Style.COLORS.BG_HOVER or Style.COLORS.BG_BASE)
  local border_inner = hovered and Style.COLORS.BORDER_HOVER or Style.COLORS.BORDER_INNER
  local border_outer = Style.COLORS.BORDER_OUTER
  local arrow_color = hovered and Style.COLORS.TEXT_HOVER or Style.COLORS.TEXT_NORMAL

  -- Background
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, bg_color, 0)

  -- Inner border (highlight)
  ImGui.DrawList_AddRect(dl, x + 1, y + 1, x + w - 1, y + h - 1, border_inner, 0, 0, 1)

  -- Outer border (black)
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, border_outer, 0, 0, 1)

  -- Arrow icon
  draw_arrow(dl, x, y, w, h, arrow_color, direction)

  return clicked
end

-- Draw value display area
local function draw_value_display(ctx, dl, x, y, w, h, text, hovered, active)
  local bg_color = active and Style.COLORS.BG_ACTIVE or (hovered and Style.COLORS.BG_HOVER or Style.COLORS.BG_BASE)
  local border_inner = hovered and Style.COLORS.BORDER_HOVER or Style.COLORS.BORDER_INNER
  local border_outer = Style.COLORS.BORDER_OUTER
  local text_color = hovered and Style.COLORS.TEXT_HOVER or Style.COLORS.TEXT_NORMAL

  -- Background
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, bg_color, 0)

  -- Inner border
  ImGui.DrawList_AddRect(dl, x + 1, y + 1, x + w - 1, y + h - 1, border_inner, 0, 0, 1)

  -- Outer border
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, border_outer, 0, 0, 1)

  -- Text (centered)
  local text_w, text_h = ImGui.CalcTextSize(ctx, text)
  local text_x = x + (w - text_w) / 2
  local text_y = y + (h - text_h) / 2

  ImGui.DrawList_AddText(dl, text_x, text_y, text_color, text)
end

-- Draw modern spinner widget with custom rendering
-- @param ctx: ImGui context
-- @param id: Unique identifier
-- @param current_index: Currently selected index (1-based)
-- @param values: Array of values to cycle through
-- @param opts: Optional table {
--   w: total width (default 200),
--   h: height (default 24),
--   button_w: arrow button width (default 24),
--   spacing: gap between elements (default 2),
-- }
-- @return changed (boolean), new_index (number)
function M.draw(ctx, id, current_index, values, opts)
  opts = opts or {}

  local total_w = opts.w or 200
  local h = opts.h or 24
  local button_w = opts.button_w or 24
  local spacing = opts.spacing or 2

  current_index = current_index or 1
  current_index = math.max(1, math.min(current_index, #values))

  local changed = false
  local new_index = current_index

  local x, y = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)

  -- Calculate widths
  local value_w = total_w - (button_w * 2) - (spacing * 2)
  local left_x = x
  local value_x = x + button_w + spacing
  local right_x = x + button_w + spacing + value_w + spacing

  -- Left arrow button
  if draw_spinner_button(ctx, id .. "_left", left_x, y, button_w, h, "left") then
    new_index = new_index - 1
    if new_index < 1 then new_index = #values end
    changed = true
  end

  -- Value display with dropdown
  ImGui.SetCursorScreenPos(ctx, value_x, y)
  ImGui.InvisibleButton(ctx, id .. "_value", value_w, h)

  local value_hovered = ImGui.IsItemHovered(ctx)
  local value_active = ImGui.IsItemActive(ctx)
  local value_clicked = ImGui.IsItemClicked(ctx, 0)

  local current_text = tostring(values[current_index] or "")
  draw_value_display(ctx, dl, value_x, y, value_w, h, current_text, value_hovered, value_active)

  -- Popup dropdown on click
  if value_clicked then
    ImGui.OpenPopup(ctx, id .. "_popup")
  end

  -- Dropdown popup
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 4, 4)
  ImGui.PushStyleColor(ctx, ImGui.Col_PopupBg, Style.DROPDOWN_COLORS.popup_bg)
  ImGui.PushStyleColor(ctx, ImGui.Col_Border, Style.DROPDOWN_COLORS.popup_border)

  if ImGui.BeginPopup(ctx, id .. "_popup") then
    for i, value in ipairs(values) do
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
  if draw_spinner_button(ctx, id .. "_right", right_x, y, button_w, h, "right") then
    new_index = new_index + 1
    if new_index > #values then new_index = 1 end
    changed = true
  end

  -- Advance cursor
  ImGui.SetCursorScreenPos(ctx, x, y + h)

  return changed, new_index
end

return M
