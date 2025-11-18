-- @noindex
-- ReArkitekt/gui/widgets/overlays/batch_rename_modal.lua
-- Modal for batch renaming with wildcard support

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

-- Modal state
local state = {
  is_open = false,
  pattern = "",
  preview_items = {},
  on_confirm = nil,
  focus_input = false,
  item_count = 0,
  popup_opened = false,
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
function M.open(item_count, on_confirm_callback)
  state.is_open = true
  state.pattern = ""
  state.preview_items = {}
  state.on_confirm = on_confirm_callback
  state.focus_input = true
  state.item_count = item_count
  state.popup_opened = false
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
  local modal_w, modal_h = 400, 280
  ImGui.SetNextWindowPos(ctx, (viewport_w - modal_w) * 0.5, (viewport_h - modal_h) * 0.5, ImGui.Cond_Appearing)
  ImGui.SetNextWindowSize(ctx, modal_w, modal_h, ImGui.Cond_Appearing)

  -- Modal flags
  local flags = ImGui.WindowFlags_NoCollapse |
                ImGui.WindowFlags_NoResize |
                ImGui.WindowFlags_NoDocking

  -- Begin modal popup
  local visible, open = ImGui.BeginPopupModal(ctx, "Batch Rename##batch_rename_modal", true, flags)

  if visible then
    -- Title
    ImGui.TextColored(ctx, hexrgb("#FFFFFFFF"), string.format("Rename %d item%s", count, count > 1 and "s" or ""))
    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    -- Pattern input
    ImGui.Text(ctx, "Rename Pattern:")
    ImGui.SetNextItemWidth(ctx, -1)

    if state.focus_input then
      ImGui.SetKeyboardFocusHere(ctx)
      state.focus_input = false
    end

    local changed, new_pattern = ImGui.InputTextWithHint(
      ctx,
      "##pattern_input",
      "combat$n",
      state.pattern,
      ImGui.InputTextFlags_None
    )

    if changed then
      state.pattern = new_pattern
      state.preview_items = generate_preview(new_pattern, count)
    end

    ImGui.Spacing(ctx)

    -- Wildcard help
    ImGui.TextColored(ctx, hexrgb("#888888FF"), "Wildcards:")
    ImGui.Indent(ctx, 20)
    ImGui.TextColored(ctx, hexrgb("#AAAAААFF"), "$n  -  Sequential number (1, 2, 3...)")
    ImGui.TextColored(ctx, hexrgb("#AAAAAAFF"), "$i  -  Index (0, 1, 2...)")
    ImGui.TextColored(ctx, hexrgb("#AAAAAAFF"), "$N  -  Padded number (001, 002, 003...)")
    ImGui.Unindent(ctx, 20)

    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    -- Preview
    if #state.preview_items > 0 then
      ImGui.TextColored(ctx, hexrgb("#888888FF"), "Preview:")
      ImGui.Indent(ctx, 20)
      for _, name in ipairs(state.preview_items) do
        ImGui.TextColored(ctx, hexrgb("#CCCCCCFF"), name)
      end
      ImGui.Unindent(ctx, 20)
    end

    -- Spacing before buttons
    ImGui.Spacing(ctx)
    ImGui.Spacing(ctx)

    -- Buttons
    local button_w = 100
    local spacing = 10
    local total_w = button_w * 2 + spacing
    ImGui.SetCursorPosX(ctx, (modal_w - total_w) * 0.5)

    -- Confirm button
    local can_confirm = state.pattern ~= ""
    if not can_confirm then
      ImGui.BeginDisabled(ctx)
    end

    if ImGui.Button(ctx, "Rename", button_w, 30) or (can_confirm and ImGui.IsKeyPressed(ctx, ImGui.Key_Enter)) then
      if state.on_confirm then
        state.on_confirm(state.pattern)
      end
      state.is_open = false
      ImGui.CloseCurrentPopup(ctx)
    end

    if not can_confirm then
      ImGui.EndDisabled(ctx)
    end

    ImGui.SameLine(ctx, 0, spacing)

    -- Cancel button
    if ImGui.Button(ctx, "Cancel", button_w, 30) or ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
      state.is_open = false
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.EndPopup(ctx)
  end

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
