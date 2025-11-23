-- @noindex
-- Arkitekt/gui/widgets/primitives/radio_button.lua
-- Custom radio button primitive with ARKITEKT styling

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Colors = require('arkitekt.core.colors')
local Style = require('arkitekt.gui.style.defaults')

local M = {}
local hexrgb = Colors.hexrgb

---Draw a styled radio button
---@param ctx userdata ImGui context
---@param label string Button label
---@param is_selected boolean Whether this option is selected
---@param opts? table Optional config { id, spacing }
---@return boolean clicked Whether the radio button was clicked
function M.draw(ctx, label, is_selected, opts)
  opts = opts or {}
  local id = opts.id or label
  local spacing = opts.spacing or 12  -- Space between radio circle and label

  local dl = ImGui.GetWindowDrawList(ctx)
  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)

  -- Circle properties (22x22 outer circle)
  local outer_radius = 11  -- 22px diameter
  local center_x = cursor_x + outer_radius
  local center_y = cursor_y + outer_radius

  -- Calculate dimensions
  local text_w, text_h = ImGui.CalcTextSize(ctx, label)
  local total_w = outer_radius * 2 + spacing + text_w
  local total_h = math.max(outer_radius * 2, text_h)

  -- Check hover and active states
  local is_hovered = ImGui.IsMouseHoveringRect(ctx, cursor_x, cursor_y, cursor_x + total_w, cursor_y + total_h)
  local is_active = is_hovered and ImGui.IsMouseDown(ctx, 0)

  -- Colors for button fill (with hover/active lighting)
  local fill_color = Style.COLORS.BG_BASE
  if is_active then
    fill_color = Style.COLORS.BG_ACTIVE
  elseif is_hovered then
    fill_color = Style.COLORS.BG_HOVER
  end

  -- Inner circle slightly darker fill
  local inner_fill = Colors.adjust_brightness(fill_color, 0.85)

  -- Text color
  local text_color = is_hovered and Style.COLORS.TEXT_HOVER or Style.COLORS.TEXT_NORMAL

  -- Draw 22x22 outer circle
  -- Fill
  ImGui.DrawList_AddCircleFilled(dl, center_x, center_y, outer_radius, fill_color)

  -- 1px inner border (lighter)
  ImGui.DrawList_AddCircle(dl, center_x, center_y, outer_radius - 1, Style.COLORS.BORDER_INNER, 0, 1.0)

  -- 1px outer border (black)
  ImGui.DrawList_AddCircle(dl, center_x, center_y, outer_radius, Style.COLORS.BORDER_OUTER, 0, 1.0)

  -- Draw 14x14 inner circle
  local inner_radius = 7  -- 14px diameter

  -- Slightly darker fill
  ImGui.DrawList_AddCircleFilled(dl, center_x, center_y, inner_radius, inner_fill)

  -- Black border (no inner border)
  ImGui.DrawList_AddCircle(dl, center_x, center_y, inner_radius, Style.COLORS.BORDER_OUTER, 0, 1.0)

  -- If selected, draw 10x10 #BBBBBB circle in center
  if is_selected then
    local selected_radius = 5  -- 10px diameter
    ImGui.DrawList_AddCircleFilled(dl, center_x, center_y, selected_radius, hexrgb("#7e7e7e"))
  end

  -- Draw label
  local label_x = cursor_x + outer_radius * 2 + spacing
  local label_y = cursor_y + (total_h - text_h) * 0.5
  ImGui.DrawList_AddText(dl, label_x, label_y, text_color, label)

  -- Invisible button for interaction
  ImGui.SetCursorScreenPos(ctx, cursor_x, cursor_y)
  ImGui.InvisibleButton(ctx, id .. "##radio", total_w, total_h)
  local clicked = ImGui.IsItemClicked(ctx, 0)

  -- Advance cursor
  ImGui.SetCursorScreenPos(ctx, cursor_x, cursor_y + total_h)

  return clicked
end

return M
