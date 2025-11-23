-- @noindex
-- Arkitekt/gui/widgets/displays/status_pad.lua
-- Interactive status tile with a modern, flat design. (ReaImGui 0.9)

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local Draw   = require('arkitekt.gui.draw')
local Colors = require('arkitekt.core.colors')
local TileFX = require('arkitekt.gui.rendering.tile.renderer')
local TileFXConfig = require('arkitekt.gui.rendering.tile.defaults')

local M = {}
local hexrgb = Colors.hexrgb

local DEFAULTS = {
  width = 250,
  height = 40,
  rounding = 5,
  base_color = hexrgb("#41E0A3"),
  icon_box_size   = 18,
  icon_area_width = 45,
  text_padding_x       = 12,
  text_primary_size    = 1.0,
  text_secondary_size  = 1.0,
  text_line_spacing    = 2,
  hover_animation_speed = 10.0,
  icons = {
    check = "check",
    minus = "minus",
    dot   = "dot",
  },
}

local function _measure_text(ctx, text)
  local w, h = ImGui.CalcTextSize(ctx, text or '')
  return w, h
end

local function _draw_text_clipped(ctx, text, x, y, max_w, color)
  Draw.text_clipped(ctx, text, x, y, max_w, color)
end

local StatusPad = {}
StatusPad.__index = StatusPad

function M.new(opts)
  opts = opts or {}
  local pad = setmetatable({
    id             = opts.id or "status_pad",
    width          = opts.width   or DEFAULTS.width,
    height         = opts.height  or DEFAULTS.height,
    rounding       = opts.rounding or DEFAULTS.rounding,
    base_color     = opts.color or DEFAULTS.base_color,
    primary_text   = opts.primary_text or "",
    secondary_text = opts.secondary_text,
    state          = opts.state or false,
    icon_type      = opts.icon_type or "check",
    on_click       = opts.on_click,
    hover_alpha    = 0,
    config         = {},
  }, StatusPad)
  for k, v in pairs(DEFAULTS) do
    if type(v) ~= "table" then
      local user_val = opts.config and opts.config[k]
      pad.config[k] = user_val == nil and v or user_val
    end
  end
  return pad
end

function StatusPad:_draw_icon(ctx, dl, x, y)
  local cfg = self.config
  local icon_box_size = cfg.icon_box_size
  local icon_box_x = x + (cfg.icon_area_width - icon_box_size) / 2
  local icon_box_y = y + (self.height - icon_box_size) / 2
  local ix1, iy1 = icon_box_x, icon_box_y
  local ix2, iy2 = icon_box_x + icon_box_size, icon_box_y + icon_box_size

  ImGui.DrawList_AddRect(dl, ix1, iy1, ix2, iy2, self.base_color, 3, 0, 1.2)

  if self.state then
    local icon_color = self.base_color
    if self.icon_type == "check" then
      local px1, py1 = ix1 + icon_box_size * 0.2, iy1 + icon_box_size * 0.5
      local px2, py2 = ix1 + icon_box_size * 0.45, iy1 + icon_box_size * 0.75
      local px3, py3 = ix1 + icon_box_size * 0.8, iy1 + icon_box_size * 0.25
      ImGui.DrawList_AddLine(dl, px1, py1, px2, py2, icon_color, 1.8)
      ImGui.DrawList_AddLine(dl, px2, py2, px3, py3, icon_color, 1.8)
    elseif self.icon_type == "minus" then
      local mid_y = iy1 + icon_box_size / 2
      ImGui.DrawList_AddLine(dl, ix1 + icon_box_size * 0.2, mid_y, ix2 - icon_box_size * 0.2, mid_y, icon_color, 1.8)
    end
  end
end

function StatusPad:draw(ctx, x, y)
  local dl = ImGui.GetWindowDrawList(ctx)
  local x1, y1 = x, y
  local x2, y2 = x + self.width, y + self.height
  local cfg = self.config

  local mx, my   = ImGui.GetMousePos(ctx)
  local hovered  = Draw.point_in_rect(mx, my, x1, y1, x2, y2)
  local dt = ImGui.GetDeltaTime(ctx)
  local target_alpha = hovered and 1.0 or 0.0
  self.hover_alpha = self.hover_alpha + (target_alpha - self.hover_alpha) * cfg.hover_animation_speed * dt
  self.hover_alpha = math.max(0, math.min(1, self.hover_alpha))

  local fx_config = TileFXConfig.get()
  fx_config.rounding = self.rounding
  fx_config.border_thickness = 1.2
  
  TileFX.render_complete(ctx, dl, x1, y1, x2, y2, self.base_color, fx_config, false, self.hover_alpha)
  
  self:_draw_icon(ctx, dl, x1, y1)

  local text_x = x1 + cfg.icon_area_width
  local available_width = self.width - cfg.icon_area_width - cfg.text_padding_x
  local primary_color   = self.state and hexrgb("#FFFFFF") or hexrgb("#BBBBBB")
  local secondary_color = self.state and hexrgb("#AAAAAA") or hexrgb("#888888")

  if self.secondary_text and self.secondary_text ~= "" then
    local _, primary_h   = _measure_text(ctx, self.primary_text)
    local _, secondary_h = _measure_text(ctx, self.secondary_text)
    local total_h = primary_h + secondary_h + cfg.text_line_spacing
    local text_y  = y1 + (self.height - total_h) / 2
    _draw_text_clipped(ctx, self.primary_text, text_x, text_y, available_width, primary_color)
    _draw_text_clipped(ctx, self.secondary_text, text_x, text_y + primary_h + cfg.text_line_spacing, available_width, secondary_color)
  else
    local _, th  = _measure_text(ctx, self.primary_text)
    local text_y = y1 + (self.height - th) / 2
    _draw_text_clipped(ctx, self.primary_text, text_x, text_y, available_width, primary_color)
  end

  ImGui.SetCursorScreenPos(ctx, x1, y1)
  ImGui.InvisibleButton(ctx, self.id .. "_btn", self.width, self.height)
  if ImGui.IsItemClicked(ctx, 0) and self.on_click then
    self.on_click(not self.state)
  end
end

function StatusPad:set_state(state) self.state = state end
function StatusPad:get_state() return self.state end
function StatusPad:set_primary_text(text) self.primary_text = text end
function StatusPad:set_secondary_text(text) self.secondary_text = text end
function StatusPad:set_color(color) self.base_color = color end

return M