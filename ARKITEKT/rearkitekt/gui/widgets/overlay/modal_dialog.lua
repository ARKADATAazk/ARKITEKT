-- @noindex
-- ReArkitekt/gui/widgets/overlay/modal_dialog.lua
-- Unified modal dialog system with consistent styling and behavior

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local Sheet = require('rearkitekt.gui.widgets.overlay.sheet')
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
  close_on_scrim = true, -- Close when clicking outside
  esc_to_close = true,   -- Close on ESC key
  bg_color = Colors.with_alpha(hexrgb("#141414"), 0xF0),
  button_width = 120,
  button_spacing = 10,
}

-- Modal state manager
local ModalDialog = {}
ModalDialog.__index = ModalDialog

function M.new(config)
  config = config or {}
  return setmetatable({
    is_open = false,
    config = config,
    result = nil,
  }, ModalDialog)
end

-- Open modal with overlay system (preferred)
function ModalDialog:open_overlay(window, id, opts)
  if self.is_open then return end

  opts = opts or {}
  local width = opts.width or DEFAULTS.width
  local height = opts.height or DEFAULTS.height
  local title = opts.title or ""
  local content_fn = opts.content_fn
  local on_close = opts.on_close

  self.is_open = true
  self.result = nil

  window.overlay:push({
    id = id,
    close_on_scrim = opts.close_on_scrim ~= false and DEFAULTS.close_on_scrim,
    esc_to_close = opts.esc_to_close ~= false and DEFAULTS.esc_to_close,
    on_close = function()
      self.is_open = false
      if on_close then on_close() end
    end,
    render = function(ctx, alpha, bounds)
      Sheet.render(ctx, alpha, bounds, function(ctx, w, h, a)
        if content_fn then
          content_fn(ctx, w, h, a)
        end
      end, {
        title = title,
        width = width,
        height = height
      })
    end
  })
end

-- Close overlay modal
function ModalDialog:close_overlay(window, id)
  if not self.is_open then return end
  window.overlay:pop(id)
  self.is_open = false
end

-- Open modal with popup fallback (when no overlay available)
function ModalDialog:open_popup(ctx, id, opts)
  if not self.is_open then
    ImGui.OpenPopup(ctx, id)
    self.is_open = true
    self.result = nil
  end
end

-- Draw popup modal content (fallback mode)
function ModalDialog:draw_popup(ctx, id, opts)
  opts = opts or {}

  local width = opts.width or DEFAULTS.width
  local height = opts.height or DEFAULTS.height
  local min_width = opts.min_width or DEFAULTS.min_width
  local min_height = opts.min_height or DEFAULTS.min_height
  local max_width = opts.max_width or DEFAULTS.max_width
  local max_height = opts.max_height or DEFAULTS.max_height
  local bg_color = opts.bg_color or DEFAULTS.bg_color
  local content_fn = opts.content_fn
  local on_close = opts.on_close

  -- Calculate size based on window
  local win_w, win_h = ImGui.GetWindowSize(ctx)
  local modal_w = math.max(min_width, math.min(max_width, win_w * width))
  local modal_h = math.max(min_height, math.min(max_height, win_h * height))

  -- Center on script window
  local win_x, win_y = ImGui.GetWindowPos(ctx)
  ImGui.SetNextWindowPos(ctx,
    win_x + (win_w - modal_w) * 0.5,
    win_y + (win_h - modal_h) * 0.5,
    ImGui.Cond_Always)

  ImGui.SetNextWindowSize(ctx, modal_w, modal_h, ImGui.Cond_Always)
  ImGui.PushStyleColor(ctx, ImGui.Col_PopupBg, bg_color)

  local visible = ImGui.BeginPopupModal(ctx, id, true, ImGui.WindowFlags_NoTitleBar | ImGui.WindowFlags_NoResize)

  if not visible then
    ImGui.PopStyleColor(ctx, 1)
    self.is_open = false
    if on_close then on_close() end
    return false
  end

  if content_fn then
    content_fn(ctx, modal_w, modal_h, 1.0)
  end

  ImGui.EndPopup(ctx)
  ImGui.PopStyleColor(ctx, 1)

  return true
end

-- Close popup modal
function ModalDialog:close_popup(ctx)
  if not self.is_open then return end
  ImGui.CloseCurrentPopup(ctx)
  self.is_open = false
end

-- Helper: Draw centered button at bottom
function M.draw_bottom_button(ctx, label, button_width, on_click)
  button_width = button_width or DEFAULTS.button_width

  local avail_w = ImGui.GetContentRegionAvail(ctx)
  local cursor_x = (avail_w - button_width) * 0.5

  ImGui.SetCursorPosX(ctx, cursor_x)

  if ImGui.Button(ctx, label, button_width, 0) then
    if on_click then on_click() end
    return true
  end

  return false
end

-- Helper: Draw multiple buttons at bottom
function M.draw_bottom_buttons(ctx, buttons)
  local button_width = DEFAULTS.button_width
  local button_spacing = DEFAULTS.button_spacing
  local total_width = (#buttons * button_width) + ((#buttons - 1) * button_spacing)

  local avail_w = ImGui.GetContentRegionAvail(ctx)
  local start_x = (avail_w - total_width) * 0.5

  ImGui.SetCursorPosX(ctx, start_x)

  local clicked = nil
  for i, button in ipairs(buttons) do
    if i > 1 then
      ImGui.SameLine(ctx, 0, button_spacing)
    end

    if ImGui.Button(ctx, button.label, button_width, 0) then
      clicked = i
      if button.on_click then
        button.on_click()
      end
    end
  end

  return clicked
end

-- Helper: Simple message dialog
function M.show_message(ctx, window, title, message, opts)
  opts = opts or {}
  local id = opts.id or "##message_dialog"
  local button_label = opts.button_label or "OK"
  local on_close = opts.on_close

  local modal = M.new()

  local content_fn = function(ctx, w, h, alpha)
    local padding = 20

    -- Message text
    ImGui.SetCursorPos(ctx, padding, padding)
    ImGui.PushTextWrapPos(ctx, w - padding * 2)
    ImGui.Text(ctx, message)
    ImGui.PopTextWrapPos(ctx)

    -- Bottom button
    ImGui.SetCursorPosY(ctx, h - 40)
    if M.draw_bottom_button(ctx, button_label, DEFAULTS.button_width, function()
      if window and window.overlay then
        modal:close_overlay(window, id)
      else
        modal:close_popup(ctx)
      end
      if on_close then on_close() end
    end) then
      -- Button clicked
    end
  end

  if window and window.overlay then
    modal:open_overlay(window, id, {
      title = title,
      width = opts.width or 0.4,
      height = opts.height or 0.25,
      content_fn = content_fn,
      on_close = on_close,
    })
  else
    modal:open_popup(ctx, id, opts)
    modal:draw_popup(ctx, id, {
      width = opts.width or 0.4,
      height = opts.height or 0.25,
      content_fn = content_fn,
      on_close = on_close,
    })
  end

  return modal
end

-- Helper: Confirmation dialog
function M.show_confirm(ctx, window, title, message, opts)
  opts = opts or {}
  local id = opts.id or "##confirm_dialog"
  local confirm_label = opts.confirm_label or "OK"
  local cancel_label = opts.cancel_label or "Cancel"
  local on_confirm = opts.on_confirm
  local on_cancel = opts.on_cancel

  local modal = M.new()

  local content_fn = function(ctx, w, h, alpha)
    local padding = 20

    -- Message text
    ImGui.SetCursorPos(ctx, padding, padding)
    ImGui.PushTextWrapPos(ctx, w - padding * 2)
    ImGui.Text(ctx, message)
    ImGui.PopTextWrapPos(ctx)

    -- Bottom buttons
    ImGui.SetCursorPosY(ctx, h - 40)
    local clicked = M.draw_bottom_buttons(ctx, {
      {
        label = cancel_label,
        on_click = function()
          if window and window.overlay then
            modal:close_overlay(window, id)
          else
            modal:close_popup(ctx)
          end
          if on_cancel then on_cancel() end
        end
      },
      {
        label = confirm_label,
        on_click = function()
          if window and window.overlay then
            modal:close_overlay(window, id)
          else
            modal:close_popup(ctx)
          end
          if on_confirm then on_confirm() end
        end
      }
    })
  end

  if window and window.overlay then
    modal:open_overlay(window, id, {
      title = title,
      width = opts.width or 0.4,
      height = opts.height or 0.25,
      content_fn = content_fn,
    })
  else
    modal:open_popup(ctx, id, opts)
    modal:draw_popup(ctx, id, {
      width = opts.width or 0.4,
      height = opts.height or 0.25,
      content_fn = content_fn,
    })
  end

  return modal
end

return M
