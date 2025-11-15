-- @noindex
-- ReArkitekt/gui/widgets/overlay/modal_dialog.lua
-- Unified modal dialog system with consistent styling and behavior

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local Button = require('rearkitekt.gui.widgets.controls.button')
local Style = require('rearkitekt.gui.style.defaults')
local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

-- Default modal configuration
local DEFAULTS = {
  width = 0.5,           -- Percentage of window width
  height = 0.3,          -- Percentage of window height
  min_width = 400,       -- Minimum pixel width
  min_height = 150,      -- Minimum pixel height
  max_width = 800,       -- Maximum pixel width
  max_height = 600,      -- Maximum pixel height

  -- Modal box styling (square, no gradients, double borders)
  bg_color = hexrgb("#1A1A1AFF"),         -- Dark background
  border_outer = hexrgb("#000000DD"),     -- Black outer border
  border_inner = hexrgb("#404040FF"),     -- Gray inner border

  -- Title styling
  title_bg = hexrgb("#1E1E1EFF"),         -- Title bar background
  title_text = hexrgb("#CCCCCCFF"),       -- Title text color
  title_height = 32,                      -- Title bar height

  -- Content padding
  padding_x = 16,
  padding_y = 12,

  -- Button area
  button_area_height = 50,
  button_width = 120,
  button_spacing = 10,

  -- Scrim (dark overlay behind modal)
  scrim_color = hexrgb("#00000099"),  -- Semi-transparent black
}

-- Helper: Draw simple square modal box with double borders
local function draw_modal_box(ctx, dl, x, y, width, height, title)
  -- Draw background
  ImGui.DrawList_AddRectFilled(
    dl, x, y, x + width, y + height,
    DEFAULTS.bg_color, 0
  )

  -- Draw inner border
  ImGui.DrawList_AddRect(
    dl, x + 1, y + 1, x + width - 1, y + height - 1,
    DEFAULTS.border_inner, 0, 0, 1
  )

  -- Draw outer border
  ImGui.DrawList_AddRect(
    dl, x, y, x + width, y + height,
    DEFAULTS.border_outer, 0, 0, 1
  )

  -- Draw title bar if title provided
  if title and title ~= "" then
    ImGui.DrawList_AddRectFilled(
      dl, x + 1, y + 1, x + width - 1, y + DEFAULTS.title_height,
      DEFAULTS.title_bg, 0
    )

    -- Draw title separator line
    ImGui.DrawList_AddLine(
      dl, x + 1, y + DEFAULTS.title_height,
      x + width - 1, y + DEFAULTS.title_height,
      DEFAULTS.border_inner, 1
    )

    -- Draw title text
    local title_x = x + DEFAULTS.padding_x
    local title_y = y + (DEFAULTS.title_height - ImGui.GetTextLineHeight(ctx)) * 0.5
    ImGui.DrawList_AddText(dl, title_x, title_y, DEFAULTS.title_text, title)
  end
end

-- Helper: Draw text input field (similar pattern to search_input)
local function draw_text_input(ctx, x, y, width, height, unique_id, text, placeholder)
  local is_hovered = ImGui.IsMouseHoveringRect(ctx, x, y, x + width, y + height)
  local is_focused = false

  -- Draw field background and borders
  local bg_color = Style.SEARCH_INPUT_COLORS.bg
  local border_inner = Style.SEARCH_INPUT_COLORS.border_inner
  local border_outer = Style.SEARCH_INPUT_COLORS.border_outer

  local dl = ImGui.GetWindowDrawList(ctx)

  -- Background
  ImGui.DrawList_AddRectFilled(dl, x, y, x + width, y + height, bg_color, 0)

  -- Inner border
  ImGui.DrawList_AddRect(dl, x + 1, y + 1, x + width - 1, y + height - 1, border_inner, 0, 0, 1)

  -- Outer border
  ImGui.DrawList_AddRect(dl, x, y, x + width, y + height, border_outer, 0, 0, 1)

  -- Draw input field
  ImGui.SetCursorScreenPos(ctx, x + 8, y + (height - ImGui.GetTextLineHeight(ctx)) * 0.5 - 2)
  ImGui.PushItemWidth(ctx, width - 16)

  ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, hexrgb("#00000000"))
  ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgHovered, hexrgb("#00000000"))
  ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgActive, hexrgb("#00000000"))
  ImGui.PushStyleColor(ctx, ImGui.Col_Border, hexrgb("#00000000"))
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, Style.SEARCH_INPUT_COLORS.text)

  local changed, new_text = ImGui.InputTextWithHint(
    ctx,
    "##" .. unique_id,
    placeholder or "",
    text,
    ImGui.InputTextFlags_None
  )

  is_focused = ImGui.IsItemActive(ctx)

  ImGui.PopStyleColor(ctx, 5)
  ImGui.PopItemWidth(ctx)

  return changed, new_text, is_focused
end

-- ============================================================================
-- MESSAGE DIALOG
-- ============================================================================

function M.show_message(ctx, title, message, opts)
  opts = opts or {}
  local id = opts.id or "##message_dialog"
  local button_label = opts.button_label or "OK"
  local on_close = opts.on_close

  -- Calculate modal size
  local win_w, win_h = ImGui.GetWindowSize(ctx)
  local modal_w = math.max(DEFAULTS.min_width, math.min(DEFAULTS.max_width, win_w * (opts.width or 0.45)))
  local modal_h = math.max(DEFAULTS.min_height, math.min(DEFAULTS.max_height, win_h * (opts.height or 0.25)))

  -- Center on script window
  local win_x, win_y = ImGui.GetWindowPos(ctx)
  ImGui.SetNextWindowPos(ctx,
    win_x + (win_w - modal_w) * 0.5,
    win_y + (win_h - modal_h) * 0.5,
    ImGui.Cond_Appearing)

  ImGui.SetNextWindowSize(ctx, modal_w, modal_h, ImGui.Cond_Appearing)

  -- Kill ALL white colors - make everything dark or transparent
  ImGui.PushStyleColor(ctx, ImGui.Col_PopupBg, hexrgb("#00000000"))
  ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg, hexrgb("#00000000"))
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#00000000"))
  ImGui.PushStyleColor(ctx, ImGui.Col_TitleBg, hexrgb("#00000000"))
  ImGui.PushStyleColor(ctx, ImGui.Col_TitleBgActive, hexrgb("#00000000"))
  ImGui.PushStyleColor(ctx, ImGui.Col_TitleBgCollapsed, hexrgb("#00000000"))
  ImGui.PushStyleColor(ctx, ImGui.Col_Border, hexrgb("#00000000"))
  ImGui.PushStyleColor(ctx, ImGui.Col_ModalWindowDimBg, DEFAULTS.scrim_color)  -- THIS WAS THE WHITE OVERLAY
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 0, 0)

  local visible = ImGui.BeginPopupModal(ctx, id, true, ImGui.WindowFlags_NoTitleBar | ImGui.WindowFlags_NoResize)

  if not visible then
    ImGui.PopStyleVar(ctx, 1)
    ImGui.PopStyleColor(ctx, 8)
    return false
  end

  local dl = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetWindowPos(ctx)

  -- Draw modal box
  draw_modal_box(ctx, dl, x, y, modal_w, modal_h, title)

  -- Content area
  local content_y_offset = (title and title ~= "") and (DEFAULTS.title_height + 1) or 1
  local content_y = y + content_y_offset + DEFAULTS.padding_y
  local content_h = modal_h - content_y_offset - DEFAULTS.button_area_height - DEFAULTS.padding_y

  ImGui.SetCursorScreenPos(ctx, x + DEFAULTS.padding_x, content_y)
  ImGui.PushTextWrapPos(ctx, x + modal_w - DEFAULTS.padding_x)
  ImGui.Text(ctx, message)
  ImGui.PopTextWrapPos(ctx)

  -- Button at bottom
  local button_y = y + modal_h - DEFAULTS.button_area_height + 10
  local button_x = x + (modal_w - DEFAULTS.button_width) * 0.5

  local clicked = Button.draw(ctx, dl, button_x, button_y, DEFAULTS.button_width, 28, {
    label = button_label,
    on_click = function()
      ImGui.CloseCurrentPopup(ctx)
      if on_close then on_close() end
    end
  }, id .. "_btn")

  -- Close on ESC or Enter
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) or ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
    ImGui.CloseCurrentPopup(ctx)
    if on_close then on_close() end
  end

  ImGui.EndPopup(ctx)
  ImGui.PopStyleVar(ctx, 1)
  ImGui.PopStyleColor(ctx, 8)

  return true
end

-- ============================================================================
-- CONFIRMATION DIALOG
-- ============================================================================

function M.show_confirm(ctx, title, message, opts)
  opts = opts or {}
  local id = opts.id or "##confirm_dialog"
  local confirm_label = opts.confirm_label or "OK"
  local cancel_label = opts.cancel_label or "Cancel"
  local on_confirm = opts.on_confirm
  local on_cancel = opts.on_cancel

  -- Calculate modal size
  local win_w, win_h = ImGui.GetWindowSize(ctx)
  local modal_w = math.max(DEFAULTS.min_width, math.min(DEFAULTS.max_width, win_w * (opts.width or 0.45)))
  local modal_h = math.max(DEFAULTS.min_height, math.min(DEFAULTS.max_height, win_h * (opts.height or 0.25)))

  -- Center on script window
  local win_x, win_y = ImGui.GetWindowPos(ctx)
  ImGui.SetNextWindowPos(ctx,
    win_x + (win_w - modal_w) * 0.5,
    win_y + (win_h - modal_h) * 0.5,
    ImGui.Cond_Appearing)

  ImGui.SetNextWindowSize(ctx, modal_w, modal_h, ImGui.Cond_Appearing)

  -- Kill ALL white colors - make everything dark or transparent
  ImGui.PushStyleColor(ctx, ImGui.Col_PopupBg, hexrgb("#00000000"))
  ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg, hexrgb("#00000000"))
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#00000000"))
  ImGui.PushStyleColor(ctx, ImGui.Col_TitleBg, hexrgb("#00000000"))
  ImGui.PushStyleColor(ctx, ImGui.Col_TitleBgActive, hexrgb("#00000000"))
  ImGui.PushStyleColor(ctx, ImGui.Col_TitleBgCollapsed, hexrgb("#00000000"))
  ImGui.PushStyleColor(ctx, ImGui.Col_Border, hexrgb("#00000000"))
  ImGui.PushStyleColor(ctx, ImGui.Col_ModalWindowDimBg, DEFAULTS.scrim_color)  -- THIS WAS THE WHITE OVERLAY
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 0, 0)

  local visible = ImGui.BeginPopupModal(ctx, id, true, ImGui.WindowFlags_NoTitleBar | ImGui.WindowFlags_NoResize)

  if not visible then
    ImGui.PopStyleVar(ctx, 1)
    ImGui.PopStyleColor(ctx, 8)
    return false
  end

  local dl = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetWindowPos(ctx)

  -- Draw modal box
  draw_modal_box(ctx, dl, x, y, modal_w, modal_h, title)

  -- Content area
  local content_y_offset = (title and title ~= "") and (DEFAULTS.title_height + 1) or 1
  local content_y = y + content_y_offset + DEFAULTS.padding_y
  local content_h = modal_h - content_y_offset - DEFAULTS.button_area_height - DEFAULTS.padding_y

  ImGui.SetCursorScreenPos(ctx, x + DEFAULTS.padding_x, content_y)
  ImGui.PushTextWrapPos(ctx, x + modal_w - DEFAULTS.padding_x)
  ImGui.Text(ctx, message)
  ImGui.PopTextWrapPos(ctx)

  -- Buttons at bottom
  local total_buttons_width = DEFAULTS.button_width * 2 + DEFAULTS.button_spacing
  local buttons_start_x = x + (modal_w - total_buttons_width) * 0.5
  local button_y = y + modal_h - DEFAULTS.button_area_height + 10

  -- Cancel button
  Button.draw(ctx, dl, buttons_start_x, button_y, DEFAULTS.button_width, 28, {
    label = cancel_label,
    on_click = function()
      ImGui.CloseCurrentPopup(ctx)
      if on_cancel then on_cancel() end
    end
  }, id .. "_cancel")

  -- Confirm button
  Button.draw(ctx, dl, buttons_start_x + DEFAULTS.button_width + DEFAULTS.button_spacing, button_y, DEFAULTS.button_width, 28, {
    label = confirm_label,
    on_click = function()
      ImGui.CloseCurrentPopup(ctx)
      if on_confirm then on_confirm() end
    end
  }, id .. "_confirm")

  -- Close on ESC (cancel)
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
    ImGui.CloseCurrentPopup(ctx)
    if on_cancel then on_cancel() end
  end

  -- Close on Enter (confirm)
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
    ImGui.CloseCurrentPopup(ctx)
    if on_confirm then on_confirm() end
  end

  ImGui.EndPopup(ctx)
  ImGui.PopStyleVar(ctx, 1)
  ImGui.PopStyleColor(ctx, 8)

  return true
end

-- ============================================================================
-- TEXT INPUT DIALOG
-- ============================================================================

-- State storage for text input dialogs
local input_state = {}

function M.show_input(ctx, title, initial_text, opts)
  opts = opts or {}
  local id = opts.id or "##input_dialog"
  local placeholder = opts.placeholder or ""
  local confirm_label = opts.confirm_label or "OK"
  local cancel_label = opts.cancel_label or "Cancel"
  local on_confirm = opts.on_confirm
  local on_cancel = opts.on_cancel

  -- Initialize state
  if not input_state[id] then
    input_state[id] = {
      text = initial_text or "",
      first_frame = true,
    }
  end

  local state = input_state[id]

  -- Calculate modal size
  local win_w, win_h = ImGui.GetWindowSize(ctx)
  local modal_w = math.max(DEFAULTS.min_width, math.min(DEFAULTS.max_width, win_w * (opts.width or 0.45)))
  local modal_h = math.max(DEFAULTS.min_height, math.min(DEFAULTS.max_height, win_h * (opts.height or 0.3)))

  -- Center on script window
  local win_x, win_y = ImGui.GetWindowPos(ctx)
  ImGui.SetNextWindowPos(ctx,
    win_x + (win_w - modal_w) * 0.5,
    win_y + (win_h - modal_h) * 0.5,
    ImGui.Cond_Appearing)

  ImGui.SetNextWindowSize(ctx, modal_w, modal_h, ImGui.Cond_Appearing)

  -- Make background transparent (we draw our own)
  ImGui.PushStyleColor(ctx, ImGui.Col_PopupBg, hexrgb("#00000000"))
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 0, 0)

  local visible = ImGui.BeginPopupModal(ctx, id, true, ImGui.WindowFlags_NoTitleBar | ImGui.WindowFlags_NoResize)

  if not visible then
    ImGui.PopStyleVar(ctx, 1)
    ImGui.PopStyleColor(ctx, 1)
    -- Clean up state when modal closes
    input_state[id] = nil
    return false
  end

  local dl = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetWindowPos(ctx)

  -- Draw dark scrim over entire script window
  local script_win_x, script_win_y = ImGui.GetWindowPos(ctx)
  local script_win_w, script_win_h = ImGui.GetWindowSize(ctx)
  ImGui.DrawList_AddRectFilled(dl, script_win_x, script_win_y, script_win_x + script_win_w, script_win_y + script_win_h, DEFAULTS.scrim_color)

  -- Draw modal box
  draw_modal_box(ctx, dl, x, y, modal_w, modal_h, title)

  -- Content area
  local content_y_offset = (title and title ~= "") and (DEFAULTS.title_height + 1) or 1
  local content_y = y + content_y_offset + DEFAULTS.padding_y + 10

  -- Draw text input
  local input_w = modal_w - DEFAULTS.padding_x * 2
  local input_h = 28

  local changed, new_text, is_focused = draw_text_input(
    ctx, x + DEFAULTS.padding_x, content_y, input_w, input_h,
    id .. "_input", state.text, placeholder
  )

  if changed then
    state.text = new_text
  end

  -- Auto-focus on first frame
  if state.first_frame then
    ImGui.SetKeyboardFocusHere(ctx, -1)
    state.first_frame = false
  end

  -- Buttons at bottom
  local total_buttons_width = DEFAULTS.button_width * 2 + DEFAULTS.button_spacing
  local buttons_start_x = x + (modal_w - total_buttons_width) * 0.5
  local button_y = y + modal_h - DEFAULTS.button_area_height + 10

  local function do_cancel()
    ImGui.CloseCurrentPopup(ctx)
    input_state[id] = nil
    if on_cancel then on_cancel() end
  end

  local function do_confirm()
    if state.text and state.text ~= "" then
      ImGui.CloseCurrentPopup(ctx)
      local result_text = state.text
      input_state[id] = nil
      if on_confirm then on_confirm(result_text) end
    end
  end

  -- Cancel button
  Button.draw(ctx, dl, buttons_start_x, button_y, DEFAULTS.button_width, 28, {
    label = cancel_label,
    on_click = do_cancel
  }, id .. "_cancel")

  -- Confirm button
  Button.draw(ctx, dl, buttons_start_x + DEFAULTS.button_width + DEFAULTS.button_spacing, button_y, DEFAULTS.button_width, 28, {
    label = confirm_label,
    on_click = do_confirm
  }, id .. "_confirm")

  -- Close on ESC (cancel)
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
    do_cancel()
  end

  -- Close on Enter (confirm)
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
    do_confirm()
  end

  ImGui.EndPopup(ctx)
  ImGui.PopStyleVar(ctx, 1)
  ImGui.PopStyleColor(ctx, 8)

  return true
end

return M
