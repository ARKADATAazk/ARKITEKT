-- @noindex
-- ReArkitekt/gui/widgets/primitives/spinner.lua
-- Spinner widget (dropdown/stepper for cycling through values)

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

-- Draw a spinner widget
-- @param ctx: ImGui context
-- @param id: Unique identifier
-- @param current_index: Currently selected index (1-based)
-- @param values: Array of values to cycle through
-- @param opts: Optional table {
--   w: width (default 200),
--   label_w: label width (default 120),
--   button_w: arrow button width (default 20),
-- }
-- @return changed (boolean), new_index (number)
function M.draw(ctx, id, current_index, values, opts)
  opts = opts or {}

  local total_w = opts.w or 200
  local label_w = opts.label_w or 120
  local button_w = opts.button_w or 20

  current_index = current_index or 1
  current_index = math.max(1, math.min(current_index, #values))

  local changed = false
  local new_index = current_index

  -- Left arrow button
  ImGui.PushID(ctx, id .. "_left")
  if ImGui.Button(ctx, "<", button_w, 0) then
    new_index = new_index - 1
    if new_index < 1 then new_index = #values end
    changed = true
  end
  ImGui.PopID(ctx)

  ImGui.SameLine(ctx, 0, 4)

  -- Value display (clickable for dropdown)
  ImGui.PushID(ctx, id .. "_combo")
  ImGui.SetNextItemWidth(ctx, total_w - button_w * 2 - 8)

  -- Convert values to display strings
  local display_items = {}
  for i, v in ipairs(values) do
    display_items[i] = tostring(v)
  end
  local items_str = table.concat(display_items, "\0") .. "\0"

  local combo_changed, new_combo_index = ImGui.Combo(ctx, "##value", current_index - 1, items_str)
  if combo_changed then
    new_index = new_combo_index + 1
    changed = true
  end
  ImGui.PopID(ctx)

  ImGui.SameLine(ctx, 0, 4)

  -- Right arrow button
  ImGui.PushID(ctx, id .. "_right")
  if ImGui.Button(ctx, ">", button_w, 0) then
    new_index = new_index + 1
    if new_index > #values then new_index = 1 end
    changed = true
  end
  ImGui.PopID(ctx)

  return changed, new_index
end

return M
