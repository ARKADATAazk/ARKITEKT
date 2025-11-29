-- @noindex
-- WalterBuilder/ui/canvas/element_renderer.lua
-- Renders individual elements with attachment visualization

local ImGui = require('arkitekt.platform.imgui')
local Colors = require('WalterBuilder.defs.colors')
local Simulator = require('WalterBuilder.domain.simulator')

local M = {}
local Renderer = {}
Renderer.__index = Renderer

function M.new()
  return setmetatable({
    -- Cache for category colors
    category_colors = {},
  }, Renderer)
end

-- Get color for element based on behavior
function Renderer:get_element_color(sim_result, opts)
  local h_behav = sim_result.h_behavior
  local v_behav = sim_result.v_behavior

  if opts.selected then
    return Colors.CANVAS.SELECTED_FILL, Colors.CANVAS.SELECTED_BORDER
  end

  -- Get behavior-based color
  local fill_color = Colors.get_behavior_color_alpha(h_behav, v_behav)
  local border_color = Colors.get_behavior_color(h_behav, v_behav)

  return fill_color, border_color
end

-- Draw attachment indicators (arrows/lines showing stretch direction)
function Renderer:draw_attachment_indicators(ctx, dl, canvas_x, canvas_y, sim_result, rect)
  local element = sim_result.element
  local c = element.coords

  local cx = canvas_x + rect.x + rect.w / 2
  local cy = canvas_y + rect.y + rect.h / 2

  local arrow_len = 8
  local arrow_color = 0xFFFFFF80

  -- Horizontal stretch indicator
  if c.ls ~= c.rs then
    -- Element stretches horizontally
    local left = canvas_x + rect.x
    local right = canvas_x + rect.x + rect.w

    -- Left arrow (if right edge moves)
    if c.rs > 0 and c.ls == 0 then
      ImGui.DrawList_AddLine(dl, right - arrow_len, cy, right, cy, arrow_color, 2)
      ImGui.DrawList_AddLine(dl, right - 4, cy - 4, right, cy, arrow_color, 2)
      ImGui.DrawList_AddLine(dl, right - 4, cy + 4, right, cy, arrow_color, 2)
    end

    -- Right arrow (if left edge moves)
    if c.ls > 0 and c.rs == 0 then
      ImGui.DrawList_AddLine(dl, left, cy, left + arrow_len, cy, arrow_color, 2)
      ImGui.DrawList_AddLine(dl, left + 4, cy - 4, left, cy, arrow_color, 2)
      ImGui.DrawList_AddLine(dl, left + 4, cy + 4, left, cy, arrow_color, 2)
    end

    -- Both arrows (stretch both ways)
    if c.ls > 0 and c.rs > 0 and c.ls ~= c.rs then
      -- Double-headed arrow
      ImGui.DrawList_AddLine(dl, left + 4, cy, right - 4, cy, arrow_color, 2)
      ImGui.DrawList_AddLine(dl, left + 8, cy - 4, left + 4, cy, arrow_color, 2)
      ImGui.DrawList_AddLine(dl, left + 8, cy + 4, left + 4, cy, arrow_color, 2)
      ImGui.DrawList_AddLine(dl, right - 8, cy - 4, right - 4, cy, arrow_color, 2)
      ImGui.DrawList_AddLine(dl, right - 8, cy + 4, right - 4, cy, arrow_color, 2)
    end
  end

  -- Vertical stretch indicator
  if c.ts ~= c.bs then
    local top = canvas_y + rect.y
    local bottom = canvas_y + rect.y + rect.h

    -- Down arrow (if bottom edge moves)
    if c.bs > 0 and c.ts == 0 then
      ImGui.DrawList_AddLine(dl, cx, bottom - arrow_len, cx, bottom, arrow_color, 2)
      ImGui.DrawList_AddLine(dl, cx - 4, bottom - 4, cx, bottom, arrow_color, 2)
      ImGui.DrawList_AddLine(dl, cx + 4, bottom - 4, cx, bottom, arrow_color, 2)
    end

    -- Up arrow (if top edge moves)
    if c.ts > 0 and c.bs == 0 then
      ImGui.DrawList_AddLine(dl, cx, top, cx, top + arrow_len, arrow_color, 2)
      ImGui.DrawList_AddLine(dl, cx - 4, top + 4, cx, top, arrow_color, 2)
      ImGui.DrawList_AddLine(dl, cx + 4, top + 4, cx, top, arrow_color, 2)
    end
  end

  -- Movement indicator (if element moves without stretching)
  if c.ls == c.rs and c.ls > 0 then
    -- Horizontal movement - draw offset indicator
    local indicator_y = canvas_y + rect.y - 3
    ImGui.DrawList_AddLine(dl, canvas_x + rect.x, indicator_y,
      canvas_x + rect.x + rect.w, indicator_y, 0xF5A62380, 2)
  end

  if c.ts == c.bs and c.ts > 0 then
    -- Vertical movement - draw offset indicator
    local indicator_x = canvas_x + rect.x - 3
    ImGui.DrawList_AddLine(dl, indicator_x, canvas_y + rect.y,
      indicator_x, canvas_y + rect.y + rect.h, 0xF5A62380, 2)
  end
end

-- Draw edge attachment markers
function Renderer:draw_edge_markers(ctx, dl, canvas_x, canvas_y, sim_result, rect)
  local element = sim_result.element
  local c = element.coords

  local marker_size = 4
  local attached_color = Colors.ATTACHMENT.EDGE_ATTACHED
  local fixed_color = Colors.ATTACHMENT.EDGE_FIXED

  -- Left edge
  local left_color = c.ls > 0 and attached_color or fixed_color
  ImGui.DrawList_AddCircleFilled(dl,
    canvas_x + rect.x,
    canvas_y + rect.y + rect.h / 2,
    marker_size, left_color)

  -- Right edge
  local right_color = c.rs > 0 and attached_color or fixed_color
  ImGui.DrawList_AddCircleFilled(dl,
    canvas_x + rect.x + rect.w,
    canvas_y + rect.y + rect.h / 2,
    marker_size, right_color)

  -- Top edge
  local top_color = c.ts > 0 and attached_color or fixed_color
  ImGui.DrawList_AddCircleFilled(dl,
    canvas_x + rect.x + rect.w / 2,
    canvas_y + rect.y,
    marker_size, top_color)

  -- Bottom edge
  local bottom_color = c.bs > 0 and attached_color or fixed_color
  ImGui.DrawList_AddCircleFilled(dl,
    canvas_x + rect.x + rect.w / 2,
    canvas_y + rect.y + rect.h,
    marker_size, bottom_color)
end

-- Draw a hatched pattern for stretch areas (uses clip rect for proper bounds)
function Renderer:draw_stretch_pattern(ctx, dl, x, y, w, h, direction, color)
  local spacing = 6
  local line_color = (color & 0xFFFFFF00) | 0x60  -- Reduce alpha

  -- Use clip rect to ensure lines stay within bounds
  ImGui.DrawList_PushClipRect(dl, x, y, x + w, y + h, true)

  if direction == "horizontal" or direction == "both" then
    -- Diagonal lines from top-left to bottom-right (↘)
    local total_span = w + h
    for offset = 0, total_span, spacing do
      local x1 = x + offset - h
      local y1 = y
      local x2 = x + offset
      local y2 = y + h
      ImGui.DrawList_AddLine(dl, x1, y1, x2, y2, line_color, 1)
    end
  end

  if direction == "vertical" then
    -- Diagonal lines from top-right to bottom-left (↙)
    local total_span = w + h
    for offset = 0, total_span, spacing do
      local x1 = x + w - offset + h
      local y1 = y
      local x2 = x + w - offset
      local y2 = y + h
      ImGui.DrawList_AddLine(dl, x1, y1, x2, y2, line_color, 1)
    end
  end

  ImGui.DrawList_PopClipRect(dl)
end

-- Main element draw function
function Renderer:draw_element(ctx, dl, canvas_x, canvas_y, sim_result, opts)
  opts = opts or {}

  local rect = sim_result.rect
  local element = sim_result.element

  -- Skip if element has no size
  if rect.w <= 0 or rect.h <= 0 then return end

  -- Get colors
  local fill_color, border_color = self:get_element_color(sim_result, opts)

  -- Adjust for hover
  if opts.hovered and not opts.selected then
    border_color = Colors.CANVAS.HOVER_BORDER
  end

  local x1 = canvas_x + rect.x
  local y1 = canvas_y + rect.y
  local x2 = x1 + rect.w
  local y2 = y1 + rect.h

  -- Draw fill
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, fill_color, 2)

  -- Draw stretch pattern if showing attachments
  if opts.show_attachments then
    local h_stretch = sim_result.h_behavior == "stretch_end" or sim_result.h_behavior == "stretch_start"
    local v_stretch = sim_result.v_behavior == "stretch_end" or sim_result.v_behavior == "stretch_start"

    if h_stretch and v_stretch then
      self:draw_stretch_pattern(ctx, dl, x1, y1, rect.w, rect.h, "both", border_color)
    elseif h_stretch then
      self:draw_stretch_pattern(ctx, dl, x1, y1, rect.w, rect.h, "horizontal", border_color)
    elseif v_stretch then
      self:draw_stretch_pattern(ctx, dl, x1, y1, rect.w, rect.h, "vertical", border_color)
    end
  end

  -- Draw border
  local border_thickness = opts.selected and 2 or 1
  ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, border_color, 2, 0, border_thickness)

  -- Draw element name and ID (if big enough)
  if rect.w > 30 and rect.h > 14 then
    local name = element.name or element.id
    -- Truncate name if needed
    local max_chars = math.floor((rect.w - 6) / 6)  -- Approximate char width
    if #name > max_chars then
      name = name:sub(1, max_chars - 2) .. ".."
    end

    ImGui.DrawList_AddText(dl, x1 + 3, y1 + 2, Colors.TEXT.BRIGHT, name)

    -- Show ID below name if there's room (for elements with different name/id)
    if rect.h > 26 and element.id and element.name ~= element.id then
      local id_display = element.id
      -- Extract short ID (e.g., "tcp.mute" -> "mute")
      local short_id = id_display:match("%.([^%.]+)$") or id_display
      if #short_id > max_chars then
        short_id = short_id:sub(1, max_chars - 2) .. ".."
      end
      ImGui.DrawList_AddText(dl, x1 + 3, y1 + 14, Colors.TEXT.DIM, short_id)
    end
  elseif rect.w > 16 and rect.h > 10 then
    -- For smaller elements, show abbreviated ID
    local short = (element.id or "?"):match("%.([^%.]+)$") or (element.id or "?")
    local abbrev = short:sub(1, 3):upper()
    ImGui.DrawList_AddText(dl, x1 + 2, y1 + 1, Colors.TEXT.DIM, abbrev)
  end

  -- Draw attachment indicators if enabled
  if opts.show_attachments then
    self:draw_attachment_indicators(ctx, dl, canvas_x, canvas_y, sim_result, rect)
  end

  -- Draw modified indicator (small orange triangle in top-right corner)
  if opts.modified then
    local marker_size = 8
    ImGui.DrawList_AddTriangleFilled(dl,
      x2 - marker_size, y1,
      x2, y1,
      x2, y1 + marker_size,
      0xFF8800FF)  -- Orange
  end
end

-- Draw legend explaining colors
function Renderer:draw_legend(ctx)
  ImGui.Text(ctx, "Legend:")

  ImGui.SameLine(ctx, 0, 10)
  ImGui.ColorButton(ctx, "##fixed", Colors.ATTACHMENT.FIXED, ImGui.ColorEditFlags_NoTooltip, 12, 12)
  ImGui.SameLine(ctx, 0, 4)
  ImGui.Text(ctx, "Fixed")

  ImGui.SameLine(ctx, 0, 10)
  ImGui.ColorButton(ctx, "##stretch_h", Colors.ATTACHMENT.STRETCH_H, ImGui.ColorEditFlags_NoTooltip, 12, 12)
  ImGui.SameLine(ctx, 0, 4)
  ImGui.Text(ctx, "Stretch H")

  ImGui.SameLine(ctx, 0, 10)
  ImGui.ColorButton(ctx, "##stretch_v", Colors.ATTACHMENT.STRETCH_V, ImGui.ColorEditFlags_NoTooltip, 12, 12)
  ImGui.SameLine(ctx, 0, 4)
  ImGui.Text(ctx, "Stretch V")

  ImGui.SameLine(ctx, 0, 10)
  ImGui.ColorButton(ctx, "##move", Colors.ATTACHMENT.MOVE, ImGui.ColorEditFlags_NoTooltip, 12, 12)
  ImGui.SameLine(ctx, 0, 4)
  ImGui.Text(ctx, "Move")
end

return M
