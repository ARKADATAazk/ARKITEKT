-- @noindex
-- ReArkitekt/gui/widgets/overlays/batch_rename_modal.lua
-- Modal for batch renaming with wildcard support

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local Style = require('rearkitekt.gui.style.defaults')
local Container = require('rearkitekt.gui.widgets.overlays.overlay.container')
local ColorPickerWindow = require('rearkitekt.gui.widgets.tools.color_picker_window')
local Button = require('rearkitekt.gui.widgets.primitives.button')
local Chip = require('rearkitekt.gui.widgets.data.chip')
local hexrgb = Colors.hexrgb

local M = {}

local BatchRenameModal = {}
BatchRenameModal.__index = BatchRenameModal

-- Wildcard pattern processing
local function apply_pattern(pattern, index)
  -- $n - sequential number starting from 1
  -- $i - index starting from 0
  -- $N - zero-padded 3-digit number (001, 002, etc)
  local result = pattern
  result = result:gsub("%$n", tostring(index))
  result = result:gsub("%$i", tostring(index - 1))
  result = result:gsub("%$N", string.format("%03d", index))
  return result
end

-- Generate preview of renamed items
local function generate_preview(pattern, count)
  local previews = {}
  for i = 1, math.min(count, 5) do  -- Show max 5 previews
    previews[i] = apply_pattern(pattern, i)
  end
  if count > 5 then
    previews[#previews + 1] = "..."
  end
  return previews
end

-- Create new batch rename modal instance
function M.new()
  return setmetatable({
    is_open = false,
    pattern = "",
    preview_items = {},
    on_confirm = nil,
    on_rename_and_recolor = nil,
    on_recolor = nil,
    focus_input = false,
    item_count = 0,
    selected_color = 0xFF5733FF,  -- Default color (RGBA)
    picker_initialized = false,
  }, BatchRenameModal)
end

-- Open the batch rename modal
function BatchRenameModal:open(item_count, on_confirm_callback, opts)
  opts = opts or {}
  self.is_open = true
  self.pattern = ""
  self.preview_items = {}
  self.on_confirm = on_confirm_callback
  self.on_rename_and_recolor = opts.on_rename_and_recolor
  self.on_recolor = opts.on_recolor
  self.selected_color = opts.initial_color or 0xFF5733FF
  self.focus_input = true
  self.item_count = item_count
  self.picker_initialized = false
end

-- Check if modal should be shown
function BatchRenameModal:should_show()
  return self.is_open
end

-- Close the modal
function BatchRenameModal:close()
  self.is_open = false
end

-- Draw modal content (shared between popup and overlay modes)
function BatchRenameModal:draw_content(ctx, count, is_overlay_mode, content_w)
  local modal_w = content_w or 520  -- Use provided content_w or fallback to 520
  local dl = ImGui.GetWindowDrawList(ctx)

  -- Title
  ImGui.TextColored(ctx, hexrgb("#CCCCCCFF"), string.format("Rename %d item%s", count, count > 1 and "s" or ""))
  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- ========================================================================
  -- SECTION 1: Pattern input and color picker side by side
  -- ========================================================================

  local input_width = modal_w * 0.62  -- ~62% for input field
  local picker_size = 137  -- 30% smaller than original 195
  local gap = 12  -- Gap between input and picker

  -- Save cursor position for side-by-side layout
  local start_x, start_y = ImGui.GetCursorScreenPos(ctx)

  -- LEFT: Pattern input field
  ImGui.SetCursorScreenPos(ctx, start_x, start_y)
  ImGui.SetNextItemWidth(ctx, input_width)

  if self.focus_input then
    ImGui.SetKeyboardFocusHere(ctx)
    self.focus_input = false
  end

  -- Apply input field styling
  ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, Style.SEARCH_INPUT_COLORS.bg)
  ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgHovered, Style.SEARCH_INPUT_COLORS.bg_hover)
  ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgActive, Style.SEARCH_INPUT_COLORS.bg_active)
  ImGui.PushStyleColor(ctx, ImGui.Col_Border, Style.SEARCH_INPUT_COLORS.border_outer)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, Style.SEARCH_INPUT_COLORS.text)

  local changed, new_pattern = ImGui.InputTextWithHint(
    ctx,
    "##pattern_input",
    "pattern$wildcard",
    self.pattern,
    ImGui.InputTextFlags_None
  )

  ImGui.PopStyleColor(ctx, 5)

  if changed then
    self.pattern = new_pattern
    self.preview_items = generate_preview(new_pattern, count)
  end

  -- RIGHT: Color picker widget (no label)
  ImGui.SetCursorScreenPos(ctx, start_x + input_width + gap, start_y)

  -- Initialize color picker only once per modal open
  if not self.picker_initialized then
    ColorPickerWindow.show_inline("batch_rename_picker", self.selected_color)
    self.picker_initialized = true
  end

  -- Render the inline color picker
  local color_changed = ColorPickerWindow.render_inline(ctx, "batch_rename_picker", {
    size = picker_size,
    on_change = function(color)
      self.selected_color = color
    end
  })

  -- Move cursor below the taller element (color picker)
  local input_height = 28  -- Approximate input field height
  local next_y = start_y + math.max(input_height, picker_size)
  ImGui.SetCursorScreenPos(ctx, start_x, next_y)

  ImGui.Dummy(ctx, 0, 4)

  -- ========================================================================
  -- SECTION 2: Wildcard chips (clickable)
  -- ========================================================================

  ImGui.TextColored(ctx, hexrgb("#999999FF"), "Wildcards:")
  ImGui.Dummy(ctx, 0, 2)

  local wildcard_chips = {
    {label = "number ($n)", wildcard = "$n"},
    {label = "index ($i)", wildcard = "$i"},
    {label = "padded ($N)", wildcard = "$N"},
  }

  local chip_spacing = 6

  for i, chip_data in ipairs(wildcard_chips) do
    if i > 1 then
      ImGui.SameLine(ctx, 0, chip_spacing)
    end

    local clicked = Chip.draw(ctx, {
      label = chip_data.label,
      style = Chip.STYLE.PILL,
      interactive = true,
      id = "wildcard_" .. i,
      bg_color = hexrgb("#2a2a2a"),
      text_color = hexrgb("#BBBBBB"),
      rounding = 4,
    })

    if clicked then
      self.pattern = self.pattern .. chip_data.wildcard
      self.preview_items = generate_preview(self.pattern, count)
    end
  end

  ImGui.Dummy(ctx, 0, 4)

  -- ========================================================================
  -- SECTION 3: Common name chips (clickable)
  -- ========================================================================

  ImGui.TextColored(ctx, hexrgb("#999999FF"), "Common Names:")
  ImGui.Dummy(ctx, 0, 2)

  local common_names = {"combat", "ambience", "tension"}

  for i, name in ipairs(common_names) do
    if i > 1 then
      ImGui.SameLine(ctx, 0, chip_spacing)
    end

    local clicked = Chip.draw(ctx, {
      label = name,
      style = Chip.STYLE.PILL,
      interactive = true,
      id = "common_name_" .. i,
      bg_color = hexrgb("#2a3a4a"),
      text_color = hexrgb("#AABBCC"),
      rounding = 4,
    })

    if clicked then
      -- Append the name (with separator if pattern is not empty)
      if self.pattern ~= "" and not self.pattern:match("%s$") then
        self.pattern = self.pattern .. "_"
      end
      self.pattern = self.pattern .. name
      self.preview_items = generate_preview(self.pattern, count)
    end
  end

  ImGui.Dummy(ctx, 0, 6)
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 6)

  -- ========================================================================
  -- SECTION 4: Preview
  -- ========================================================================

  if #self.preview_items > 0 then
    ImGui.TextColored(ctx, hexrgb("#999999FF"), "Preview:")
    ImGui.Dummy(ctx, 0, 2)
    ImGui.Indent(ctx, 16)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 0, 3)
    for _, name in ipairs(self.preview_items) do
      ImGui.TextColored(ctx, hexrgb("#DDDDDDFF"), name)
    end
    ImGui.PopStyleVar(ctx, 1)
    ImGui.Unindent(ctx, 16)
  end

  ImGui.Dummy(ctx, 0, 6)
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 6)

  -- ========================================================================
  -- SECTION 5: Action buttons using primitives
  -- ========================================================================

  local button_w = 110
  local button_h = 28
  local spacing = 8
  local total_w = button_w * 4 + spacing * 3
  local button_start_x = start_x + (modal_w - total_w) * 0.5
  local button_y, _ = ImGui.GetCursorScreenPos(ctx)

  local should_close = false
  local can_rename = self.pattern ~= ""

  -- Cancel button
  local _, cancel_clicked = Button.draw(ctx, dl, button_start_x, button_y, button_w, button_h, {
    id = "cancel_btn",
    label = "Cancel",
    height = button_h,
  }, "batch_rename_cancel")

  if cancel_clicked or ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
    should_close = true
  end

  -- Rename button (disabled when no pattern)
  local _, rename_clicked = Button.draw(ctx, dl, button_start_x + button_w + spacing, button_y, button_w, button_h, {
    id = "rename_btn",
    label = "Rename",
    height = button_h,
    is_disabled = not can_rename,
  }, "batch_rename_rename")

  if rename_clicked or (can_rename and ImGui.IsKeyPressed(ctx, ImGui.Key_Enter)) then
    if self.on_confirm then
      self.on_confirm(self.pattern)
    end
    should_close = true
  end

  -- Rename & Recolor button (disabled when no pattern)
  local _, rename_recolor_clicked = Button.draw(ctx, dl, button_start_x + (button_w + spacing) * 2, button_y, button_w, button_h, {
    id = "rename_recolor_btn",
    label = "Rename & Recolor",
    height = button_h,
    is_disabled = not can_rename,
  }, "batch_rename_both")

  if rename_recolor_clicked then
    if self.on_rename_and_recolor then
      self.on_rename_and_recolor(self.pattern, self.selected_color)
    end
    should_close = true
  end

  -- Recolor button (always enabled)
  local _, recolor_clicked = Button.draw(ctx, dl, button_start_x + (button_w + spacing) * 3, button_y, button_w, button_h, {
    id = "recolor_btn",
    label = "Recolor",
    height = button_h,
  }, "batch_rename_recolor")

  if recolor_clicked then
    if self.on_recolor then
      self.on_recolor(self.selected_color)
    end
    should_close = true
  end

  -- Advance cursor past buttons
  ImGui.SetCursorScreenPos(ctx, start_x, button_y + button_h)
  ImGui.Dummy(ctx, 0, 8)  -- Add spacing at bottom

  return should_close
end

-- Draw the modal (supports both popup and overlay modes)
function BatchRenameModal:draw(ctx, item_count, window)
  if not self.is_open then return false end

  local count = item_count or self.item_count

  -- Use overlay mode if window.overlay is available
  if window and window.overlay then
    if not self.overlay_pushed then
      self.overlay_pushed = true

      window.overlay:push({
        id = 'batch-rename-modal',
        close_on_scrim = true,
        esc_to_close = true,
        on_close = function()
          self:close()
          self.overlay_pushed = false
        end,
        render = function(ctx, alpha, bounds)
          Container.render(ctx, alpha, bounds, function(ctx, content_w, content_h, w, h, a, padding)
            local should_close = self:draw_content(ctx, count, true, content_w)

            if should_close then
              window.overlay:pop('batch-rename-modal')
              self:close()
              self.overlay_pushed = false
            end
          end, { width = 0.45, height = 0.65 })
        end
      })
    end

    return self.is_open
  end

  -- Fallback to BeginPopupModal when overlay is not available
  if not self.popup_opened then
    ImGui.OpenPopup(ctx, "Batch Rename##batch_rename_modal")
    self.popup_opened = true
  end

  -- Center modal on screen
  local viewport_w, viewport_h = ImGui.Viewport_GetSize(ImGui.GetWindowViewport(ctx))
  local modal_w, modal_h = 520, 600
  ImGui.SetNextWindowPos(ctx, (viewport_w - modal_w) * 0.5, (viewport_h - modal_h) * 0.5, ImGui.Cond_Appearing)
  ImGui.SetNextWindowSize(ctx, modal_w, modal_h, ImGui.Cond_Appearing)

  -- Modal flags
  local flags = ImGui.WindowFlags_NoCollapse |
                ImGui.WindowFlags_NoResize |
                ImGui.WindowFlags_NoDocking

  -- Apply consistent styling
  ImGui.PushStyleColor(ctx, ImGui.Col_PopupBg, hexrgb("#1A1A1AFF"))
  ImGui.PushStyleColor(ctx, ImGui.Col_Border, hexrgb("#404040FF"))
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 16, 12)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 0, 10)

  -- Begin modal popup
  local visible, open = ImGui.BeginPopupModal(ctx, "Batch Rename##batch_rename_modal", true, flags)

  if visible then
    local should_close = self:draw_content(ctx, count, false)

    if should_close then
      self:close()
      self.popup_opened = false
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.EndPopup(ctx)
  end

  ImGui.PopStyleVar(ctx, 2)
  ImGui.PopStyleColor(ctx, 2)

  if not open then
    self:close()
    self.popup_opened = false
  end

  return self.is_open
end

-- Apply pattern to a list of items (returns new names in order)
function M.apply_pattern_to_items(pattern, count)
  local results = {}
  for i = 1, count do
    results[i] = apply_pattern(pattern, i)
  end
  return results
end

-- Legacy API compatibility (singleton pattern for backward compatibility)
local _legacy_instance = nil

function M.open(item_count, on_confirm_callback, opts)
  if not _legacy_instance then
    _legacy_instance = M.new()
  end
  _legacy_instance:open(item_count, on_confirm_callback, opts)
end

function M.is_open()
  if not _legacy_instance then return false end
  return _legacy_instance:should_show()
end

function M.draw(ctx, item_count, window)
  if not _legacy_instance then return false end
  return _legacy_instance:draw(ctx, item_count, window)
end

return M
