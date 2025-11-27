-- @noindex
-- WalterBuilder/ui/panels/properties_panel.lua
-- Properties panel for editing selected element coordinates

local ImGui = require 'imgui' '0.10'
local ark = require('arkitekt')
local Coordinate = require('WalterBuilder.domain.coordinate')
local Simulator = require('WalterBuilder.domain.simulator')
local Colors = require('WalterBuilder.defs.colors')

local hexrgb = ark.Colors.hexrgb

local M = {}
local Panel = {}
Panel.__index = Panel

function M.new(opts)
  opts = opts or {}

  local self = setmetatable({
    -- Currently edited element
    element = nil,

    -- Callback when values change
    on_change = opts.on_change,

    -- Callback to delete element
    on_delete = opts.on_delete,

    -- Show advanced options
    show_advanced = false,
  }, Panel)

  return self
end

-- Set the element to edit
function Panel:set_element(element)
  self.element = element
end

-- Draw a coordinate input row
function Panel:draw_coord_input(ctx, label, value, min_val, max_val, step, id_suffix)
  ImGui.AlignTextToFramePadding(ctx)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
  ImGui.Text(ctx, label)
  ImGui.PopStyleColor(ctx)

  ImGui.SameLine(ctx, 45)
  ImGui.SetNextItemWidth(ctx, 80)

  local changed, new_val = ImGui.DragDouble(ctx, "##" .. id_suffix, value, step, min_val, max_val, "%.1f")

  return changed, new_val
end

-- Draw attachment toggle button
function Panel:draw_attachment_toggle(ctx, label, value, id_suffix)
  local is_attached = value > 0

  local bg_color = is_attached and hexrgb("#2A4A2A") or hexrgb("#2A2A2A")
  local text_color = is_attached and hexrgb("#88CC88") or hexrgb("#888888")

  ImGui.PushStyleColor(ctx, ImGui.Col_Button, bg_color)
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, hexrgb("#3A3A3A"))
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, text_color)

  local clicked = ImGui.Button(ctx, label .. "##" .. id_suffix, 50, 24)

  ImGui.PopStyleColor(ctx, 3)

  if clicked then
    return true, is_attached and 0 or 1
  end

  return false, value
end

-- Draw the behavior explanation
function Panel:draw_behavior_info(ctx, element)
  local behavior = Simulator.classify_behavior(element)

  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
  ImGui.Text(ctx, "Behavior:")
  ImGui.PopStyleColor(ctx)

  ImGui.SameLine(ctx)

  -- Get appropriate color
  local h_behav = element:get_horizontal_behavior()
  local v_behav = element:get_vertical_behavior()
  local color = Colors.get_behavior_color(h_behav, v_behav)

  ImGui.ColorButton(ctx, "##behav_color", color, ImGui.ColorEditFlags_NoTooltip, 14, 14)
  ImGui.SameLine(ctx, 0, 6)

  ImGui.Text(ctx, behavior.description)
end

-- Draw position/size section
function Panel:draw_position_section(ctx)
  local element = self.element
  local c = element.coords
  local changed = false

  ImGui.PushFont(ctx, nil)  -- Use default font
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#FFFFFF"))
  ImGui.Text(ctx, "Position & Size")
  ImGui.PopStyleColor(ctx)
  ImGui.PopFont(ctx)

  ImGui.Dummy(ctx, 0, 4)

  -- X position
  local x_changed, new_x = self:draw_coord_input(ctx, "X", c.x, -500, 500, 1, "pos_x")
  if x_changed then c.x = new_x; changed = true end

  -- Y position
  local y_changed, new_y = self:draw_coord_input(ctx, "Y", c.y, -500, 500, 1, "pos_y")
  if y_changed then c.y = new_y; changed = true end

  ImGui.Dummy(ctx, 0, 4)

  -- Width
  local w_changed, new_w = self:draw_coord_input(ctx, "W", c.w, 0, 500, 1, "size_w")
  if w_changed then c.w = new_w; changed = true end

  -- Height
  local h_changed, new_h = self:draw_coord_input(ctx, "H", c.h, 0, 500, 1, "size_h")
  if h_changed then c.h = new_h; changed = true end

  return changed
end

-- Draw attachment section
function Panel:draw_attachment_section(ctx)
  local element = self.element
  local c = element.coords
  local changed = false

  ImGui.Dummy(ctx, 0, 8)

  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#FFFFFF"))
  ImGui.Text(ctx, "Edge Attachments")
  ImGui.PopStyleColor(ctx)

  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#888888"))
  ImGui.Text(ctx, "Control how edges respond to parent resize")
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 4)

  -- Visual attachment editor (grid of toggles)
  --       [TOP]
  -- [LEFT]     [RIGHT]
  --      [BOTTOM]

  local avail_w = ImGui.GetContentRegionAvail(ctx)
  local center_x = avail_w / 2

  -- Top toggle
  ImGui.SetCursorPosX(ctx, center_x - 25)
  local ts_changed, new_ts = self:draw_attachment_toggle(ctx, "Top", c.ts, "attach_ts")
  if ts_changed then c.ts = new_ts; changed = true end

  -- Left and Right toggles
  local ls_changed, new_ls = self:draw_attachment_toggle(ctx, "Left", c.ls, "attach_ls")
  if ls_changed then c.ls = new_ls; changed = true end

  ImGui.SameLine(ctx, center_x + 10)
  local rs_changed, new_rs = self:draw_attachment_toggle(ctx, "Right", c.rs, "attach_rs")
  if rs_changed then c.rs = new_rs; changed = true end

  -- Bottom toggle
  ImGui.SetCursorPosX(ctx, center_x - 25)
  local bs_changed, new_bs = self:draw_attachment_toggle(ctx, "Bot", c.bs, "attach_bs")
  if bs_changed then c.bs = new_bs; changed = true end

  -- Advanced: precise values
  if self.show_advanced then
    ImGui.Dummy(ctx, 0, 8)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#888888"))
    ImGui.Text(ctx, "Precise values (0.0 - 1.0):")
    ImGui.PopStyleColor(ctx)

    local ls_val_changed, ls_val = self:draw_coord_input(ctx, "LS", c.ls, 0, 1, 0.1, "attach_ls_val")
    if ls_val_changed then c.ls = ls_val; changed = true end

    local ts_val_changed, ts_val = self:draw_coord_input(ctx, "TS", c.ts, 0, 1, 0.1, "attach_ts_val")
    if ts_val_changed then c.ts = ts_val; changed = true end

    local rs_val_changed, rs_val = self:draw_coord_input(ctx, "RS", c.rs, 0, 1, 0.1, "attach_rs_val")
    if rs_val_changed then c.rs = rs_val; changed = true end

    local bs_val_changed, bs_val = self:draw_coord_input(ctx, "BS", c.bs, 0, 1, 0.1, "attach_bs_val")
    if bs_val_changed then c.bs = bs_val; changed = true end
  end

  return changed
end

-- Draw preset buttons for common attachment patterns
function Panel:draw_attachment_presets(ctx)
  local element = self.element
  local c = element.coords
  local changed = false

  ImGui.Dummy(ctx, 0, 8)

  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#888888"))
  ImGui.Text(ctx, "Quick presets:")
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 2)

  -- Fixed (all zero)
  if ImGui.Button(ctx, "Fixed##preset", 60, 22) then
    c.ls, c.ts, c.rs, c.bs = 0, 0, 0, 0
    changed = true
  end
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "Fixed position and size")
  end

  ImGui.SameLine(ctx, 0, 4)

  -- Stretch H (ls=0, rs=1)
  if ImGui.Button(ctx, "StretchH##preset", 60, 22) then
    c.ls, c.rs = 0, 1
    changed = true
  end
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "Stretch horizontally with parent")
  end

  ImGui.SameLine(ctx, 0, 4)

  -- Stretch V (ts=0, bs=1)
  if ImGui.Button(ctx, "StretchV##preset", 60, 22) then
    c.ts, c.bs = 0, 1
    changed = true
  end
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "Stretch vertically with parent")
  end

  -- Anchor Right
  if ImGui.Button(ctx, "AnchorR##preset", 60, 22) then
    c.ls, c.rs = 1, 1
    changed = true
  end
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "Anchor to right edge")
  end

  ImGui.SameLine(ctx, 0, 4)

  -- Anchor Bottom
  if ImGui.Button(ctx, "AnchorB##preset", 60, 22) then
    c.ts, c.bs = 1, 1
    changed = true
  end
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "Anchor to bottom edge")
  end

  ImGui.SameLine(ctx, 0, 4)

  -- Fill (stretch both)
  if ImGui.Button(ctx, "Fill##preset", 60, 22) then
    c.ls, c.ts, c.rs, c.bs = 0, 0, 1, 1
    changed = true
  end
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "Fill parent (stretch both ways)")
  end

  return changed
end

-- Main draw function
function Panel:draw(ctx)
  local result = nil

  if not self.element then
    -- No element selected
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#666666"))
    ImGui.Text(ctx, "No element selected")
    ImGui.Dummy(ctx, 0, 8)
    ImGui.Text(ctx, "Select an element from the canvas")
    ImGui.Text(ctx, "or add one from the Elements panel")
    ImGui.PopStyleColor(ctx)
    return nil
  end

  local element = self.element
  local changed = false

  -- Element header
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#00AAFF"))
  ImGui.Text(ctx, element.id)
  ImGui.PopStyleColor(ctx)

  if element.name and element.name ~= element.id then
    ImGui.SameLine(ctx)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#888888"))
    ImGui.Text(ctx, "(" .. element.name .. ")")
    ImGui.PopStyleColor(ctx)
  end

  ImGui.Dummy(ctx, 0, 4)

  -- Behavior info
  self:draw_behavior_info(ctx, element)

  ImGui.Dummy(ctx, 0, 8)
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 8)

  -- Position/Size section
  if self:draw_position_section(ctx) then
    changed = true
  end

  ImGui.Dummy(ctx, 0, 4)
  ImGui.Separator(ctx)

  -- Attachment section
  if self:draw_attachment_section(ctx) then
    changed = true
  end

  -- Presets
  if self:draw_attachment_presets(ctx) then
    changed = true
  end

  ImGui.Dummy(ctx, 0, 8)
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 4)

  -- Advanced toggle
  local _, show_adv = ImGui.Checkbox(ctx, "Show advanced options", self.show_advanced)
  self.show_advanced = show_adv

  -- Delete button
  ImGui.Dummy(ctx, 0, 8)

  ImGui.PushStyleColor(ctx, ImGui.Col_Button, hexrgb("#4A2A2A"))
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, hexrgb("#5A3A3A"))
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, hexrgb("#6A4A4A"))

  if ImGui.Button(ctx, "Remove from Layout", -1, 26) then
    if self.on_delete then
      result = { type = "delete", element = element }
    end
  end

  ImGui.PopStyleColor(ctx, 3)

  -- Notify of changes
  if changed and self.on_change then
    self.on_change(element)
    result = { type = "change", element = element }
  end

  return result
end

return M
