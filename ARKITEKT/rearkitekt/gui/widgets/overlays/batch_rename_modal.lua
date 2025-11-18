-- @noindex
-- ReArkitekt/gui/widgets/overlays/batch_rename_modal.lua
-- Modal for batch renaming with wildcard support

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local Style = require('rearkitekt.gui.style.defaults')
local ColorPickerWindow = require('rearkitekt.gui.widgets.tools.color_picker_window')
local hexrgb = Colors.hexrgb

local M = {}

-- Modal state
local state = {
  is_open = false,
  pattern = "",
  preview_items = {},
  on_confirm = nil,
  on_rename_and_recolor = nil,
  on_recolor = nil,
  focus_input = false,
  item_count = 0,
  popup_opened = false,
  selected_color = 0xFF5733FF,  -- Default color (RGBA)
  picker_initialized = false,    -- Track if color picker has been initialized
}

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

-- Open the batch rename modal
function M.open(item_count, on_confirm_callback, opts)
  opts = opts or {}
  state.is_open = true
  state.pattern = ""
  state.preview_items = {}
  state.on_confirm = on_confirm_callback
  state.on_rename_and_recolor = opts.on_rename_and_recolor
  state.on_recolor = opts.on_recolor
  state.selected_color = opts.initial_color or 0xFF5733FF
  state.focus_input = true
  state.item_count = item_count
  state.popup_opened = false
  state.picker_initialized = false  -- Reset picker initialization flag
  -- Note: ImGui.OpenPopup will be called in draw() when we have the context
end

-- Check if modal is open
function M.is_open()
  return state.is_open
end

-- Draw the modal
function M.draw(ctx, item_count)
  if not state.is_open then return false end

  -- Open popup once when modal is first opened
  if not state.popup_opened then
    ImGui.OpenPopup(ctx, "Batch Rename##batch_rename_modal")
    state.popup_opened = true
  end

  -- Use item_count from state if not provided as parameter
  local count = item_count or state.item_count

  -- Center modal on screen
  local viewport_w, viewport_h = ImGui.Viewport_GetSize(ImGui.GetWindowViewport(ctx))
  local modal_w, modal_h = 520, 600  -- Increased height for color picker
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
    -- Title
    ImGui.TextColored(ctx, hexrgb("#CCCCCCFF"), string.format("Rename %d item%s", count, count > 1 and "s" or ""))
    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    -- Pattern input label
    ImGui.Text(ctx, "Rename Pattern:")
    ImGui.Dummy(ctx, 0, 4)

    ImGui.SetNextItemWidth(ctx, -1)

    if state.focus_input then
      ImGui.SetKeyboardFocusHere(ctx)
      state.focus_input = false
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
      "combat$n",
      state.pattern,
      ImGui.InputTextFlags_None
    )

    ImGui.PopStyleColor(ctx, 5)

    if changed then
      state.pattern = new_pattern
      state.preview_items = generate_preview(new_pattern, count)
    end

    ImGui.Dummy(ctx, 0, 8)

    -- Wildcard help
    ImGui.TextColored(ctx, hexrgb("#999999FF"), "Wildcards:")
    ImGui.Dummy(ctx, 0, 4)
    ImGui.Indent(ctx, 16)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 0, 6)
    ImGui.TextColored(ctx, hexrgb("#BBBBBBFF"), "$n  —  Sequential number (1, 2, 3...)")
    ImGui.TextColored(ctx, hexrgb("#BBBBBBFF"), "$i  —  Index (0, 1, 2...)")
    ImGui.TextColored(ctx, hexrgb("#BBBBBBFF"), "$N  —  Padded number (001, 002, 003...)")
    ImGui.PopStyleVar(ctx, 1)
    ImGui.Unindent(ctx, 16)

    ImGui.Dummy(ctx, 0, 10)
    ImGui.Separator(ctx)
    ImGui.Dummy(ctx, 0, 10)

    -- Preview
    if #state.preview_items > 0 then
      ImGui.TextColored(ctx, hexrgb("#999999FF"), "Preview:")
      ImGui.Dummy(ctx, 0, 4)
      ImGui.Indent(ctx, 16)
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 0, 4)
      for _, name in ipairs(state.preview_items) do
        ImGui.TextColored(ctx, hexrgb("#DDDDDDFF"), name)
      end
      ImGui.PopStyleVar(ctx, 1)
      ImGui.Unindent(ctx, 16)
    end

    ImGui.Dummy(ctx, 0, 10)
    ImGui.Separator(ctx)
    ImGui.Dummy(ctx, 0, 10)

    -- Color picker section
    ImGui.TextColored(ctx, hexrgb("#999999FF"), "Color:")
    ImGui.Dummy(ctx, 0, 4)

    -- Center the color picker
    local picker_size = 195
    local picker_x = (modal_w - picker_size) * 0.5
    ImGui.SetCursorPosX(ctx, picker_x)

    -- Initialize color picker only once per modal open
    if not state.picker_initialized then
      ColorPickerWindow.show_inline("batch_rename_picker", state.selected_color)
      state.picker_initialized = true
    end

    -- Render the inline color picker
    local color_changed = ColorPickerWindow.render_inline(ctx, "batch_rename_picker", {
      size = picker_size,
      on_change = function(color)
        state.selected_color = color
      end
    })

    -- Spacing before buttons
    ImGui.Dummy(ctx, 0, 10)
    ImGui.Separator(ctx)
    ImGui.Dummy(ctx, 0, 8)

    -- Buttons (4 buttons: Cancel, Rename, Rename & Recolor, Recolor)
    local button_w = 110
    local spacing = 8
    local total_w = button_w * 4 + spacing * 3
    ImGui.SetCursorPosX(ctx, (modal_w - total_w) * 0.5)

    -- Cancel button
    if ImGui.Button(ctx, "Cancel", button_w, 28) or ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
      state.is_open = false
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.SameLine(ctx, 0, spacing)

    -- Rename button (needs pattern)
    local can_rename = state.pattern ~= ""
    if not can_rename then
      ImGui.BeginDisabled(ctx)
    end

    if ImGui.Button(ctx, "Rename", button_w, 28) or (can_rename and ImGui.IsKeyPressed(ctx, ImGui.Key_Enter)) then
      if state.on_confirm then
        state.on_confirm(state.pattern)
      end
      state.is_open = false
      ImGui.CloseCurrentPopup(ctx)
    end

    if not can_rename then
      ImGui.EndDisabled(ctx)
    end

    ImGui.SameLine(ctx, 0, spacing)

    -- Rename and Recolor button (needs pattern)
    if not can_rename then
      ImGui.BeginDisabled(ctx)
    end

    if ImGui.Button(ctx, "Rename & Recolor", button_w, 28) then
      if state.on_rename_and_recolor then
        state.on_rename_and_recolor(state.pattern, state.selected_color)
      end
      state.is_open = false
      ImGui.CloseCurrentPopup(ctx)
    end

    if not can_rename then
      ImGui.EndDisabled(ctx)
    end

    ImGui.SameLine(ctx, 0, spacing)

    -- Recolor button (always enabled)
    if ImGui.Button(ctx, "Recolor", button_w, 28) then
      if state.on_recolor then
        state.on_recolor(state.selected_color)
      end
      state.is_open = false
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.EndPopup(ctx)
  end

  ImGui.PopStyleVar(ctx, 2)
  ImGui.PopStyleColor(ctx, 2)

  if not open then
    state.is_open = false
  end

  return state.is_open
end

-- Apply pattern to a list of items (returns new names in order)
function M.apply_pattern_to_items(pattern, count)
  local results = {}
  for i = 1, count do
    results[i] = apply_pattern(pattern, i)
  end
  return results
end

return M
