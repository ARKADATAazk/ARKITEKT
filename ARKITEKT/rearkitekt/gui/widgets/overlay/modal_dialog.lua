-- @noindex
-- ReArkitekt/gui/widgets/overlay/modal_dialog.lua
-- Unified modal dialog system with consistent styling and behavior
-- NO RELIANCE on ImGui popup defaults - everything custom drawn

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

-- Active modal state
local active_modal = nil

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

-- Helper: Check if mouse clicked outside modal box
local function clicked_outside(ctx, x, y, w, h)
  if ImGui.IsMouseClicked(ctx, 0) then
    local mx, my = ImGui.GetMousePos(ctx)
    if mx < x or mx > x + w or my < y or my > y + h then
      return true
    end
  end
  return false
end

-- ============================================================================
-- MESSAGE DIALOG
-- ============================================================================

function M.show_message(ctx, title, message, opts)
  opts = opts or {}
  local id = opts.id or "##message_dialog"
  local button_label = opts.button_label or "OK"
  local on_close = opts.on_close

  -- Only create modal state once
  if not active_modal or active_modal.id ~= id then
    active_modal = {
      id = id,
      type = "message",
      title = title,
      message = message,
      opts = opts,
    }
  end

  -- Calculate modal size based on current window
  local win_w, win_h = ImGui.GetWindowSize(ctx)
  local win_x, win_y = ImGui.GetWindowPos(ctx)
  local modal_w = math.max(DEFAULTS.min_width, math.min(DEFAULTS.max_width, win_w * (opts.width or 0.45)))
  local modal_h = math.max(DEFAULTS.min_height, math.min(DEFAULTS.max_height, win_h * (opts.height or 0.25)))

  -- Center modal
  local x = win_x + (win_w - modal_w) * 0.5
  local y = win_y + (win_h - modal_h) * 0.5

  local dl = ImGui.GetForegroundDrawList(ctx)

  -- Draw dark scrim over entire window
  ImGui.DrawList_AddRectFilled(dl, win_x, win_y, win_x + win_w, win_y + win_h, DEFAULTS.scrim_color)

  -- Draw modal box
  draw_modal_box(ctx, dl, x, y, modal_w, modal_h, title)

  -- Content area
  local content_y_offset = (title and title ~= "") and (DEFAULTS.title_height + 1) or 1
  local content_y = y + content_y_offset + DEFAULTS.padding_y

  -- Draw message text
  ImGui.SetCursorScreenPos(ctx, x + DEFAULTS.padding_x, content_y)
  ImGui.PushTextWrapPos(ctx, x + modal_w - DEFAULTS.padding_x)
  ImGui.Text(ctx, message)
  ImGui.PopTextWrapPos(ctx)

  -- Button at bottom
  local button_y = y + modal_h - DEFAULTS.button_area_height + 10
  local button_x = x + (modal_w - DEFAULTS.button_width) * 0.5

  Button.draw(ctx, dl, button_x, button_y, DEFAULTS.button_width, 28, {
    label = button_label,
    on_click = function()
      active_modal = nil
      if on_close then on_close() end
    end
  }, id .. "_btn")

  -- Close on ESC or Enter
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) or ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
    active_modal = nil
    if on_close then on_close() end
  end

  -- Close if clicked outside
  if clicked_outside(ctx, x, y, modal_w, modal_h) then
    active_modal = nil
    if on_close then on_close() end
  end

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

  -- Only create modal state once
  if not active_modal or active_modal.id ~= id then
    active_modal = {
      id = id,
      type = "confirm",
      title = title,
      message = message,
      opts = opts,
    }
  end

  -- Calculate modal size
  local win_w, win_h = ImGui.GetWindowSize(ctx)
  local win_x, win_y = ImGui.GetWindowPos(ctx)
  local modal_w = math.max(DEFAULTS.min_width, math.min(DEFAULTS.max_width, win_w * (opts.width or 0.45)))
  local modal_h = math.max(DEFAULTS.min_height, math.min(DEFAULTS.max_height, win_h * (opts.height or 0.25)))

  -- Center modal
  local x = win_x + (win_w - modal_w) * 0.5
  local y = win_y + (win_h - modal_h) * 0.5

  local dl = ImGui.GetForegroundDrawList(ctx)

  -- Draw dark scrim over entire window
  ImGui.DrawList_AddRectFilled(dl, win_x, win_y, win_x + win_w, win_y + win_h, DEFAULTS.scrim_color)

  -- Draw modal box
  draw_modal_box(ctx, dl, x, y, modal_w, modal_h, title)

  -- Content area
  local content_y_offset = (title and title ~= "") and (DEFAULTS.title_height + 1) or 1
  local content_y = y + content_y_offset + DEFAULTS.padding_y

  -- Draw message text
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
      active_modal = nil
      if on_cancel then on_cancel() end
    end
  }, id .. "_cancel")

  -- Confirm button
  Button.draw(ctx, dl, buttons_start_x + DEFAULTS.button_width + DEFAULTS.button_spacing, button_y, DEFAULTS.button_width, 28, {
    label = confirm_label,
    on_click = function()
      active_modal = nil
      if on_confirm then on_confirm() end
    end
  }, id .. "_confirm")

  -- Close on ESC (cancel)
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
    active_modal = nil
    if on_cancel then on_cancel() end
  end

  -- Close on Enter (confirm)
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
    active_modal = nil
    if on_confirm then on_confirm() end
  end

  -- Close if clicked outside (cancel)
  if clicked_outside(ctx, x, y, modal_w, modal_h) then
    active_modal = nil
    if on_cancel then on_cancel() end
  end

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

  -- Only create modal state once
  if not active_modal or active_modal.id ~= id then
    active_modal = {
      id = id,
      type = "input",
      title = title,
      opts = opts,
    }
  end

  -- Calculate modal size
  local win_w, win_h = ImGui.GetWindowSize(ctx)
  local win_x, win_y = ImGui.GetWindowPos(ctx)
  local modal_w = math.max(DEFAULTS.min_width, math.min(DEFAULTS.max_width, win_w * (opts.width or 0.45)))
  local modal_h = math.max(DEFAULTS.min_height, math.min(DEFAULTS.max_height, win_h * (opts.height or 0.3)))

  -- Center modal
  local x = win_x + (win_w - modal_w) * 0.5
  local y = win_y + (win_h - modal_h) * 0.5

  local dl = ImGui.GetForegroundDrawList(ctx)

  -- Draw dark scrim over entire window
  ImGui.DrawList_AddRectFilled(dl, win_x, win_y, win_x + win_w, win_y + win_h, DEFAULTS.scrim_color)

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
    active_modal = nil
    input_state[id] = nil
    if on_cancel then on_cancel() end
  end

  local function do_confirm()
    if state.text and state.text ~= "" then
      local result_text = state.text
      active_modal = nil
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
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) and not is_focused then
    do_confirm()
  end

  -- Close if clicked outside (cancel)
  if clicked_outside(ctx, x, y, modal_w, modal_h) then
    do_cancel()
  end

  return true
end

return M
