-- @noindex
-- ItemPicker/ui/components/help_modal.lua
-- Help modal showing keyboard shortcuts and tips

local ImGui = require('arkitekt.core.imgui')
local Ark = require('arkitekt')
local Palette = require('ItemPicker.config.palette')

local M = {}

-- Shortcut categories with their entries
local SHORTCUTS = {
  {
    category = 'General',
    items = {
      { keys = 'Ctrl+F', desc = 'Focus search input' },
      { keys = 'ESC', desc = 'Close ItemPicker' },
      { keys = 'Space', desc = 'Preview hovered item' },
    },
  },
  {
    category = 'Tiles',
    items = {
      { keys = 'Click', desc = 'Select item' },
      { keys = 'Ctrl+Click', desc = 'Add to selection' },
      { keys = 'Delete', desc = 'Disable selected item' },
      { keys = 'Alt+Click', desc = 'Quick disable item' },
      { keys = 'Double-Click', desc = 'Rename item' },
    },
  },
  {
    category = 'Drag & Drop',
    items = {
      { keys = 'Drag', desc = 'Insert item at cursor' },
      { keys = 'Shift+Drop', desc = 'Multi-drop (keep dragging)' },
      { keys = 'Ctrl+Drop', desc = 'Drop and keep window open' },
      { keys = 'Alt+Drag', desc = 'Toggle pooled MIDI copy' },
    },
  },
  {
    category = 'Tile Sizing',
    items = {
      { keys = 'Ctrl+Scroll', desc = 'Resize tile height' },
      { keys = 'Alt+Scroll', desc = 'Resize tile width' },
    },
  },
  {
    category = 'Filters',
    items = {
      { keys = 'Shift+F', desc = 'Toggle favorites filter' },
      { keys = 'Shift+D', desc = 'Toggle disabled filter' },
      { keys = 'Shift+M', desc = 'Toggle muted filter' },
    },
  },
  {
    category = 'Track Filter Modal',
    items = {
      { keys = 'Ctrl+A', desc = 'Select all tracks' },
      { keys = 'Ctrl+D', desc = 'Deselect all tracks' },
      { keys = 'Shift+Click', desc = 'Toggle children with parent' },
    },
  },
}

-- Draw a single shortcut row
local function draw_shortcut_row(ctx, dl, x, y, width, keys, desc, palette)
  local key_width = 100
  local key_color = palette.text_primary or 0xFFFFFFFF
  local desc_color = palette.text_dimmed or 0xAAAAAAFF

  -- Draw key badge
  local key_text_w = ImGui.CalcTextSize(ctx, keys)
  local badge_w = key_text_w + 12
  local badge_h = 18
  local badge_x = x
  local badge_y = y

  -- Badge background
  ImGui.DrawList_AddRectFilled(dl, badge_x, badge_y, badge_x + badge_w, badge_y + badge_h, 0x3A3A3AFF, 3)
  ImGui.DrawList_AddRect(dl, badge_x, badge_y, badge_x + badge_w, badge_y + badge_h, 0x5A5A5AFF, 3, 0, 1)

  -- Key text (centered in badge)
  local text_y = badge_y + (badge_h - ImGui.GetTextLineHeight(ctx)) / 2
  ImGui.DrawList_AddText(dl, badge_x + 6, text_y, key_color, keys)

  -- Description
  local desc_x = x + key_width + 8
  ImGui.DrawList_AddText(dl, desc_x, text_y, desc_color, desc)

  return badge_h + 4  -- Return row height with spacing
end

-- Draw a category header
local function draw_category_header(ctx, dl, x, y, text, palette)
  local header_color = palette.accent or 0x42E896FF
  ImGui.DrawList_AddText(dl, x, y, header_color, text)
  return ImGui.GetTextLineHeight(ctx) + 8  -- Header height with spacing
end

function M.Draw(ctx, state, bounds)
  local palette = Palette.get()

  -- Calculate modal size (tall enough to show all shortcuts without scrolling)
  local modal_width = 420
  local modal_height = 580

  -- Check if modal wants to close
  if Ark.Modal.WantsClose('help_modal') then
    state.show_help_modal = false
  end

  -- Begin modal
  local modal_began = Ark.Modal.Begin(ctx, 'help_modal', state.show_help_modal, {
    title = 'KEYBOARD SHORTCUTS',
    width = modal_width,
    height = modal_height,
    bounds = bounds,
    close_on_escape = true,
    close_on_scrim_click = true,
    close_on_scrim_right_click = true,
    show_close_button = true,
  })
  if not modal_began then
    return false
  end

  local draw_list = ImGui.GetWindowDrawList(ctx)
  local content_w, _ = ImGui.GetContentRegionAvail(ctx)
  local content_x, content_y = ImGui.GetCursorScreenPos(ctx)

  -- Calculate total content height for scrolling
  local total_height = 0
  for _, category in ipairs(SHORTCUTS) do
    total_height = total_height + ImGui.GetTextLineHeight(ctx) + 8  -- Category header
    total_height = total_height + #category.items * 22  -- Items
    total_height = total_height + 12  -- Category spacing
  end

  -- Scrollable area
  local scroll_height = modal_height - 100  -- Reserve space for header and padding
  local scroll_y = state.help_scroll_y or 0
  local max_scroll = math.max(0, total_height - scroll_height)

  -- Handle scrolling
  local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
  local is_over_content = mouse_x >= content_x and mouse_x <= content_x + content_w and
                          mouse_y >= content_y and mouse_y <= content_y + scroll_height

  if is_over_content then
    local wheel_v = ImGui.GetMouseWheel(ctx)
    if wheel_v ~= 0 then
      scroll_y = scroll_y - wheel_v * 40
      scroll_y = math.max(0, math.min(scroll_y, max_scroll))
      state.help_scroll_y = scroll_y
    end
  end

  -- Clip content area
  ImGui.DrawList_PushClipRect(draw_list, content_x, content_y, content_x + content_w, content_y + scroll_height, true)

  -- Draw shortcuts
  local current_y = content_y - scroll_y

  for _, category in ipairs(SHORTCUTS) do
    -- Category header
    current_y = current_y + draw_category_header(ctx, draw_list, content_x, current_y, category.category, palette)

    -- Shortcut items
    for _, item in ipairs(category.items) do
      current_y = current_y + draw_shortcut_row(ctx, draw_list, content_x + 8, current_y, content_w - 16, item.keys, item.desc, palette)
    end

    -- Category spacing
    current_y = current_y + 8
  end

  ImGui.DrawList_PopClipRect(draw_list)

  -- Reserve space
  ImGui.Dummy(ctx, content_w, scroll_height)

  -- Footer with close button
  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  local btn_width = 100
  local btn_x = (content_w - btn_width) / 2
  ImGui.SetCursorPosX(ctx, btn_x)

  if Ark.Button(ctx, { id = 'help_close', label = 'Close', width = btn_width, height = 28 }).clicked then
    state.show_help_modal = false
  end

  Ark.Modal.End(ctx)

  return true
end

return M
