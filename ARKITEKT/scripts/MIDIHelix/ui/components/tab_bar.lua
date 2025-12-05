-- @noindex
-- MIDIHelix/ui/components/tab_bar.lua
-- Ex Machina-style tab bar with Undo/Redo buttons

local M = {}

-- Dependencies (set during init)
local Ark = nil
local ImGui = nil

-- ============================================================================
-- STATE
-- ============================================================================

local state = {
  initialized = false,
}

-- ============================================================================
-- TAB BUTTON RENDERING
-- ============================================================================

local function draw_tab_button(ctx, dl, x, y, w, h, label, color, is_active, is_enabled, rounding)
  local Colors = Ark.Colors

  -- Determine colors based on state
  local bg_color, text_color, border_color

  if not is_enabled then
    bg_color = 0x303030FF
    text_color = 0x606060FF
    border_color = 0x404040FF
  elseif is_active then
    bg_color = color
    text_color = 0x202020FF
    border_color = Colors.AdjustBrightness(color, 0.7)
  else
    bg_color = 0x404040FF
    text_color = 0xA0A0A0FF
    border_color = 0x505050FF
  end

  -- Invisible button for interaction
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, '##tab_' .. label, w, h)
  local hovered = is_enabled and ImGui.IsItemHovered(ctx)
  local clicked = is_enabled and ImGui.IsItemClicked(ctx)

  -- Hover effect
  if hovered and not is_active then
    bg_color = Colors.AdjustBrightness(bg_color, 1.2)
  end

  -- Draw background and border
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, bg_color, rounding)
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, border_color, rounding, 0, 1)

  -- Draw label (centered)
  local text_w = ImGui.CalcTextSize(ctx, label)
  local text_x = x + (w - text_w) / 2
  local text_y = y + (h - ImGui.GetTextLineHeight(ctx)) / 2
  ImGui.DrawList_AddText(dl, text_x, text_y, text_color, label)

  return clicked
end

local function draw_icon_button(ctx, dl, x, y, w, h, label, rounding, on_click)
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, '##' .. label, w, h)
  local hovered = ImGui.IsItemHovered(ctx)
  local clicked = ImGui.IsItemClicked(ctx)

  local bg_color = hovered and 0x505050FF or 0x404040FF
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, bg_color, rounding)
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, 0x505050FF, rounding, 0, 1)

  local text_w = ImGui.CalcTextSize(ctx, label)
  local text_x = x + (w - text_w) / 2
  local text_y = y + (h - ImGui.GetTextLineHeight(ctx)) / 2
  ImGui.DrawList_AddText(dl, text_x, text_y, 0xA0A0A0FF, label)

  if clicked and on_click then
    on_click()
  end

  return clicked
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Initialize the tab bar component
--- @param ark_instance table Ark instance
function M.init(ark_instance)
  if state.initialized then return end
  Ark = ark_instance
  ImGui = Ark.ImGui
  state.initialized = true
end

--- Draw the tab bar
--- @param ctx userdata ImGui context
--- @param opts table { tabs, current_tab, x, y, width, rounding, on_tab_change, on_undo, on_redo }
--- @return table { clicked_tab = number|nil }
function M.Draw(ctx, opts)
  if not state.initialized then return {} end

  local tabs = opts.tabs or {}
  local current_tab = opts.current_tab or 1
  local x = opts.x or 0
  local y = opts.y or 0
  local width = opts.width or 600
  local rounding = opts.rounding or 4

  -- Layout constants
  local tab_h = 20
  local tab_w = 100
  local tab_spacing = 0
  local undo_btn_w = 40
  local undo_offset = -85
  local redo_offset = -45

  local dl = ImGui.GetWindowDrawList(ctx)
  local tab_x = x + 5
  local clicked_tab = nil

  -- Draw tab buttons
  for i, tab in ipairs(tabs) do
    local is_active = (i == current_tab)
    local clicked = draw_tab_button(
      ctx, dl, tab_x, y, tab_w, tab_h,
      tab.label, tab.color, is_active, tab.enabled, rounding
    )

    if clicked and tab.enabled then
      clicked_tab = i
      if opts.on_tab_change then
        opts.on_tab_change(i, tab)
      end
    end

    tab_x = tab_x + tab_w + tab_spacing
  end

  -- Undo/Redo buttons (right side)
  local undo_x = x + width + undo_offset
  local redo_x = x + width + redo_offset

  draw_icon_button(ctx, dl, undo_x, y, undo_btn_w, tab_h, 'Undo', rounding, opts.on_undo)
  draw_icon_button(ctx, dl, redo_x, y, undo_btn_w, tab_h, 'Redo', rounding, opts.on_redo)

  return { clicked_tab = clicked_tab }
end

return M
