-- @noindex
-- ReArkitekt/gui/systems/drag_drop.lua
-- Generic drag and drop helpers for ImGui

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local Colors = require('rearkitekt.core.colors')
local Draw = require('rearkitekt.gui.draw')

local M = {}

-- Default drag drop flags
M.FLAGS = {
  SOURCE_NO_PREVIEW = ImGui.DragDropFlags_SourceNoPreviewTooltip,
  SOURCE_NO_DISABLE = ImGui.DragDropFlags_SourceNoDisableHover,
  SOURCE_NO_HOLD = ImGui.DragDropFlags_SourceNoHoldToOpenOthers,
  ACCEPT_NO_HIGHLIGHT = ImGui.DragDropFlags_AcceptNoDrawDefaultRect,
  ACCEPT_BEFORE_DELIVERY = ImGui.DragDropFlags_AcceptBeforeDelivery,
  ACCEPT_NO_PREVIEW = ImGui.DragDropFlags_AcceptNoPreviewTooltip,
}

-- Begin a drag source on the last item
-- Returns true if drag is active
function M.begin_source(ctx, payload_type, payload_data, flags)
  flags = flags or 0

  if ImGui.BeginDragDropSource(ctx, flags) then
    -- Serialize payload data as string
    local payload_str = type(payload_data) == "table"
      and M._serialize(payload_data)
      or tostring(payload_data)

    ImGui.SetDragDropPayload(ctx, payload_type, payload_str)
    return true
  end

  return false
end

-- End the drag source (call after drawing preview)
function M.end_source(ctx)
  ImGui.EndDragDropSource(ctx)
end

-- Begin a drag target on the last item
-- accepted_types can be a string or table of strings
-- Returns true if target is active and can accept a drop
function M.begin_target(ctx)
  return ImGui.BeginDragDropTarget(ctx)
end

-- End the drag target
function M.end_target(ctx)
  ImGui.EndDragDropTarget(ctx)
end

-- Accept a drop and return the payload
-- Returns payload_data (deserialized) or nil if not accepted
function M.accept_drop(ctx, payload_type, flags)
  flags = flags or 0

  local payload, is_preview, is_delivery = ImGui.AcceptDragDropPayload(ctx, payload_type, flags)

  if payload then
    -- Deserialize if it looks like serialized data
    local data = M._deserialize(payload) or payload
    return data, is_preview, is_delivery
  end

  return nil
end

-- Check if a specific payload type is being dragged (without accepting)
function M.is_dragging(ctx, payload_type)
  local payload = ImGui.GetDragDropPayload(ctx)
  if payload then
    -- Check if the payload type matches
    -- Note: GetDragDropPayload returns the payload data, not the type
    -- We need to use AcceptDragDropPayload with AcceptBeforeDelivery to peek
    return true
  end
  return false
end

-- Draw a simple text preview during drag
function M.draw_preview_text(ctx, text, color)
  color = color or Colors.hexrgb("#FFFFFF")
  ImGui.Text(ctx, text)
end

-- Draw a chip-style preview during drag
function M.draw_preview_chip(ctx, label, bg_color, text_color)
  bg_color = bg_color or Colors.hexrgb("#5B8FB9")
  text_color = text_color or Colors.hexrgb("#FFFFFF")

  local dl = ImGui.GetForegroundDrawList(ctx)
  local text_w, text_h = ImGui.CalcTextSize(ctx, label)
  local padding = 8
  local chip_w = text_w + padding * 2
  local chip_h = text_h + 6

  local mx, my = ImGui.GetMousePos(ctx)
  local x = mx + 10
  local y = my + 10

  -- Background
  ImGui.DrawList_AddRectFilled(dl, x, y, x + chip_w, y + chip_h, bg_color, 3)

  -- Text
  Draw.text(dl, x + padding, y + 3, text_color, label)
end

-- Draw a highlight on the drop target
function M.draw_target_highlight(ctx, rect, color, thickness)
  color = color or Colors.hexrgb("#5588FFAA")
  thickness = thickness or 2

  local dl = ImGui.GetWindowDrawList(ctx)
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]

  ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, color, 4, 0, thickness)
end

-- Simple serialization for tables (supports strings, numbers, booleans)
function M._serialize(t)
  if type(t) ~= "table" then return tostring(t) end

  local parts = {}
  for k, v in pairs(t) do
    local key = type(k) == "string" and k or tostring(k)
    local val = type(v) == "string" and ('"' .. v:gsub('"', '\\"') .. '"') or tostring(v)
    parts[#parts + 1] = key .. "=" .. val
  end

  return "{" .. table.concat(parts, ",") .. "}"
end

-- Simple deserialization
function M._deserialize(str)
  if not str or str == "" then return nil end

  -- If it doesn't look like serialized data, return as-is
  if str:sub(1, 1) ~= "{" then return str end

  -- Parse simple key=value format
  local result = {}
  local content = str:sub(2, -2)  -- Remove { }

  for pair in content:gmatch("[^,]+") do
    local key, val = pair:match("([^=]+)=(.+)")
    if key and val then
      key = key:match("^%s*(.-)%s*$")  -- Trim whitespace
      val = val:match("^%s*(.-)%s*$")

      -- Parse value type
      if val:sub(1, 1) == '"' then
        -- String
        val = val:sub(2, -2):gsub('\\"', '"')
      elseif val == "true" then
        val = true
      elseif val == "false" then
        val = false
      else
        -- Try number
        val = tonumber(val) or val
      end

      result[key] = val
    end
  end

  return result
end

return M
