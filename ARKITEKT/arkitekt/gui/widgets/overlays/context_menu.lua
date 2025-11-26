-- @noindex
-- Arkitekt/gui/widgets/controls/context_menu.lua
-- Reusable context menu widget

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Colors = require('arkitekt.core.colors')
local Style = require('arkitekt.gui.style')

local M = {}
local hexrgb = Colors.hexrgb

-- Get dynamic defaults from Style.COLORS
local function get_defaults()
  local C = Style.COLORS
  return {
    bg_color = C.BG_BASE,
    border_color = C.BORDER_OUTER,
    item_bg_color = C.BG_TRANSPARENT,
    item_hover_color = C.BG_HOVER,
    item_active_color = C.BG_ACTIVE,
    item_text_color = C.TEXT_NORMAL,
    item_text_hover_color = C.TEXT_BRIGHT,
    item_disabled_color = C.TEXT_DIMMED,
    separator_color = C.BORDER_OUTER,
    checkbox_accent = C.ACCENT_PRIMARY,
    rounding = 2,
    padding = 8,
    item_height = 26,
    item_padding_x = 12,
    border_thickness = 1,
  }
end

-- Legacy static DEFAULTS for backward compatibility
local DEFAULTS = get_defaults()

function M.begin(ctx, id, config)
  config = config or {}
  local defaults = get_defaults()  -- Get fresh colors from Style.COLORS

  local bg_color = config.bg_color or defaults.bg_color
  local border_color = config.border_color or defaults.border_color
  local rounding = config.rounding or defaults.rounding
  local padding = config.padding or defaults.padding
  local border_thickness = config.border_thickness or defaults.border_thickness
  local min_width = config.min_width or 180  -- Minimum width for better appearance

  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, padding, padding)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding, rounding)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_PopupRounding, rounding)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowBorderSize, border_thickness)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowMinSize, min_width, 0)

  ImGui.PushStyleColor(ctx, ImGui.Col_PopupBg, bg_color)
  ImGui.PushStyleColor(ctx, ImGui.Col_Border, border_color)

  local popup_open = ImGui.BeginPopup(ctx, id)

  if not popup_open then
    ImGui.PopStyleColor(ctx, 2)
    ImGui.PopStyleVar(ctx, 5)
  else
    -- Draw subtle shadow/halo effect
    local wx, wy = ImGui.GetWindowPos(ctx)
    local ww, wh = ImGui.GetWindowSize(ctx)
    local bg_dl = ImGui.GetBackgroundDrawList(ctx)

    -- Draw multi-layer shadow for soft glow effect
    local shadow_offset = 3
    local shadow_spread = 6
    ImGui.DrawList_AddRectFilled(
      bg_dl,
      wx + shadow_offset - shadow_spread,
      wy + shadow_offset - shadow_spread,
      wx + ww + shadow_offset + shadow_spread,
      wy + wh + shadow_offset + shadow_spread,
      hexrgb("#00000040"),  -- 25% opacity
      rounding + shadow_spread
    )
    ImGui.DrawList_AddRectFilled(
      bg_dl,
      wx + shadow_offset - shadow_spread/2,
      wy + shadow_offset - shadow_spread/2,
      wx + ww + shadow_offset + shadow_spread/2,
      wy + wh + shadow_offset + shadow_spread/2,
      hexrgb("#00000030"),  -- 19% opacity
      rounding + shadow_spread/2
    )
  end

  return popup_open
end

function M.end_menu(ctx)
  ImGui.EndPopup(ctx)
  ImGui.PopStyleColor(ctx, 2)
  ImGui.PopStyleVar(ctx, 5)
end

function M.item(ctx, label, config)
  config = config or {}
  local defaults = get_defaults()  -- Get fresh colors from Style.COLORS

  local item_height = config.item_height or defaults.item_height
  local item_padding_x = config.item_padding_x or defaults.item_padding_x
  local item_hover_color = config.item_hover_color or defaults.item_hover_color
  local item_text_color = config.item_text_color or defaults.item_text_color
  local item_text_hover_color = config.item_text_hover_color or defaults.item_text_hover_color

  local dl = ImGui.GetWindowDrawList(ctx)
  local item_x, item_y = ImGui.GetCursorScreenPos(ctx)
  local avail_w = ImGui.GetContentRegionAvail(ctx)

  local text_w, text_h = ImGui.CalcTextSize(ctx, label)
  local item_w = math.max(avail_w, text_w + item_padding_x * 2)

  local item_hovered = ImGui.IsMouseHoveringRect(ctx, item_x, item_y, item_x + item_w, item_y + item_height)

  if item_hovered then
    ImGui.DrawList_AddRectFilled(dl, item_x, item_y, item_x + item_w, item_y + item_height, item_hover_color, 2)
  end

  local text_color = item_hovered and item_text_hover_color or item_text_color
  local text_x = item_x + item_padding_x
  local text_y = item_y + (item_height - text_h) * 0.5

  ImGui.DrawList_AddText(dl, text_x, text_y, text_color, label)

  ImGui.InvisibleButton(ctx, label .. "_item", item_w, item_height)

  return ImGui.IsItemClicked(ctx, 0)
end

function M.checkbox_item(ctx, label, checked, config)
  config = config or {}
  local defaults = get_defaults()  -- Get fresh colors from Style.COLORS

  local item_height = config.item_height or defaults.item_height
  local item_padding_x = config.item_padding_x or defaults.item_padding_x
  local item_hover_color = config.item_hover_color or defaults.item_hover_color
  local item_text_color = config.item_text_color or defaults.item_text_color
  local item_text_hover_color = config.item_text_hover_color or defaults.item_text_hover_color

  local dl = ImGui.GetWindowDrawList(ctx)
  local item_x, item_y = ImGui.GetCursorScreenPos(ctx)
  local avail_w = ImGui.GetContentRegionAvail(ctx)

  local checkbox_size = 14
  local checkbox_padding = 8
  local text_w, text_h = ImGui.CalcTextSize(ctx, label)
  local item_w = math.max(avail_w, text_w + item_padding_x * 2 + checkbox_size + checkbox_padding)

  local item_hovered = ImGui.IsMouseHoveringRect(ctx, item_x, item_y, item_x + item_w, item_y + item_height)

  if item_hovered then
    ImGui.DrawList_AddRectFilled(dl, item_x, item_y, item_x + item_w, item_y + item_height, item_hover_color, 2)
  end

  -- Draw checkbox using dynamic accent color
  local checkbox_x = item_x + item_padding_x
  local checkbox_y = item_y + (item_height - checkbox_size) * 0.5
  local accent = defaults.checkbox_accent

  local checkbox_bg = checked and Colors.with_opacity(accent, 0.25) or defaults.item_bg_color
  local checkbox_border = checked and accent or defaults.separator_color

  ImGui.DrawList_AddRectFilled(dl, checkbox_x, checkbox_y, checkbox_x + checkbox_size, checkbox_y + checkbox_size, checkbox_bg, 2)
  ImGui.DrawList_AddRect(dl, checkbox_x, checkbox_y, checkbox_x + checkbox_size, checkbox_y + checkbox_size, checkbox_border, 2, 0, 1)

  -- Draw checkmark if checked
  if checked then
    local check_color = accent
    local check_padding = 3
    -- Draw checkmark using lines
    ImGui.DrawList_AddLine(dl,
      checkbox_x + check_padding,
      checkbox_y + checkbox_size * 0.5,
      checkbox_x + checkbox_size * 0.4,
      checkbox_y + checkbox_size - check_padding,
      check_color, 2)
    ImGui.DrawList_AddLine(dl,
      checkbox_x + checkbox_size * 0.4,
      checkbox_y + checkbox_size - check_padding,
      checkbox_x + checkbox_size - check_padding,
      checkbox_y + check_padding,
      check_color, 2)
  end

  -- Draw label text
  local text_color = item_hovered and item_text_hover_color or item_text_color
  local text_x = checkbox_x + checkbox_size + checkbox_padding
  local text_y = item_y + (item_height - text_h) * 0.5

  ImGui.DrawList_AddText(dl, text_x, text_y, text_color, label)

  ImGui.InvisibleButton(ctx, label .. "_checkbox_item", item_w, item_height)

  return ImGui.IsItemClicked(ctx, 0)
end

function M.separator(ctx, config)
  config = config or {}
  local defaults = get_defaults()
  local separator_color = config.separator_color or defaults.separator_color

  ImGui.Dummy(ctx, 1, 4)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local avail_w = ImGui.GetContentRegionAvail(ctx)

  local dl = ImGui.GetWindowDrawList(ctx)
  -- Enhanced separator with inset from edges
  ImGui.DrawList_AddLine(dl, x + 8, y, x + avail_w - 8, y, separator_color, 1)

  ImGui.Dummy(ctx, 1, 6)
end

-- Submenu support
function M.begin_menu(ctx, label, config)
  config = config or {}
  local defaults = get_defaults()  -- Get fresh colors from Style.COLORS

  local item_height = config.item_height or defaults.item_height
  local item_padding_x = config.item_padding_x or defaults.item_padding_x
  local item_hover_color = config.item_hover_color or defaults.item_hover_color
  local item_text_color = config.item_text_color or defaults.item_text_color
  local item_text_hover_color = config.item_text_hover_color or defaults.item_text_hover_color

  local dl = ImGui.GetWindowDrawList(ctx)
  local item_x, item_y = ImGui.GetCursorScreenPos(ctx)
  local avail_w = ImGui.GetContentRegionAvail(ctx)

  local text_w, text_h = ImGui.CalcTextSize(ctx, label)
  local arrow_text = ">"
  local arrow_w = ImGui.CalcTextSize(ctx, arrow_text)
  local item_w = math.max(avail_w, text_w + arrow_w + item_padding_x * 3)

  local item_hovered = ImGui.IsMouseHoveringRect(ctx, item_x, item_y, item_x + item_w, item_y + item_height)

  if item_hovered then
    ImGui.DrawList_AddRectFilled(dl, item_x, item_y, item_x + item_w, item_y + item_height, item_hover_color, 2)
  end

  local text_color = item_hovered and item_text_hover_color or item_text_color
  local text_x = item_x + item_padding_x
  local text_y = item_y + (item_height - text_h) * 0.5

  ImGui.DrawList_AddText(dl, text_x, text_y, text_color, label)
  ImGui.DrawList_AddText(dl, item_x + item_w - item_padding_x - arrow_w, text_y, text_color, arrow_text)

  ImGui.InvisibleButton(ctx, label .. "_submenu", item_w, item_height)

  -- Open submenu on hover
  if item_hovered then
    ImGui.OpenPopup(ctx, label .. "_submenu_popup")
  end

  -- Style for submenu popup
  local bg_color = config.bg_color or defaults.bg_color
  local border_color = config.border_color or defaults.border_color
  local rounding = config.rounding or defaults.rounding
  local padding = config.padding or defaults.padding

  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, padding, padding)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding, rounding)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_PopupRounding, rounding)
  ImGui.PushStyleColor(ctx, ImGui.Col_PopupBg, bg_color)
  ImGui.PushStyleColor(ctx, ImGui.Col_Border, border_color)

  local submenu_open = ImGui.BeginPopup(ctx, label .. "_submenu_popup")

  if not submenu_open then
    ImGui.PopStyleColor(ctx, 2)
    ImGui.PopStyleVar(ctx, 3)
  end

  return submenu_open
end

function M.end_submenu(ctx)
  ImGui.EndPopup(ctx)
  ImGui.PopStyleColor(ctx, 2)
  ImGui.PopStyleVar(ctx, 3)
end

return M