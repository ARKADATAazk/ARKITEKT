-- @noindex
-- ReArkitekt/gui/widgets/primitives/radio_button.lua
-- Custom radio button primitive with ARKITEKT styling

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')

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

  -- Radio circle properties
  local circle_radius = 7
  local circle_center_x = cursor_x + circle_radius
  local circle_center_y = cursor_y + circle_radius + 2  -- Vertically center with text

  -- Calculate dimensions
  local text_w, text_h = ImGui.CalcTextSize(ctx, label)
  local total_w = circle_radius * 2 + spacing + text_w
  local total_h = math.max(circle_radius * 2 + 4, text_h)

  -- Check hover
  local is_hovered = ImGui.IsMouseHoveringRect(ctx, cursor_x, cursor_y, cursor_x + total_w, cursor_y + total_h)

  -- Colors
  local outer_color = is_selected and hexrgb("#5C7CB8") or (is_hovered and hexrgb("#666666") or hexrgb("#555555"))
  local inner_color = hexrgb("#5C7CB8")
  local text_color = is_hovered and hexrgb("#FFFFFF") or hexrgb("#CCCCCC")

  -- Draw outer circle
  ImGui.DrawList_AddCircle(dl, circle_center_x, circle_center_y, circle_radius, outer_color, 0, 1.5)

  -- Draw inner filled circle if selected
  if is_selected then
    ImGui.DrawList_AddCircleFilled(dl, circle_center_x, circle_center_y, circle_radius - 3, inner_color)
  end

  -- Draw label
  local label_x = cursor_x + circle_radius * 2 + spacing
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
