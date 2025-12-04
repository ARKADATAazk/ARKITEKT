-- @noindex
-- arkitekt/gui/widgets/tree/core/rename.lua
-- Inline rename handling for Tree widgets

local ImGui = require('arkitekt.core.imgui')

local M = {}

-- ============================================================================
-- RENAME STATE
-- ============================================================================

--- Start rename mode
--- @param state table Tree state
--- @param node_id string Node to rename
--- @param current_name string Current node name
function M.start(state, node_id, current_name)
  state.editing = node_id
  state.edit_buffer = current_name
  state.edit_focus_set = false
end

--- Cancel rename mode
--- @param state table Tree state
function M.cancel(state)
  state.editing = nil
  state.edit_buffer = ''
  state.edit_focus_set = false
end

--- Commit rename
--- @param state table Tree state
--- @param opts table Tree options
--- @param result table Result object
function M.commit(state, opts, result)
  if state.edit_buffer ~= '' then
    result.renamed = true
    result.renamed_id = state.editing
    result.renamed_value = state.edit_buffer

    if opts.on_rename then
      opts.on_rename(state.editing, state.edit_buffer)
    end
  end

  M.cancel(state)
end

-- ============================================================================
-- RENAME INPUT RENDERING
-- ============================================================================

--- Draw inline rename input
--- @param ctx userdata ImGui context
--- @param state table Tree state
--- @param x number Input X position
--- @param y number Input Y position
--- @param width number Input width
--- @param height number Input height
--- @param opts table Tree options
--- @param result table Result object
--- @return boolean Whether rename is active
function M.draw_input(ctx, state, x, y, width, height, opts, result)
  if not state.editing then return false end

  -- Position input
  ImGui.SetCursorScreenPos(ctx, x, y)

  -- Style
  ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, 0x1A1A1AFF)
  ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgHovered, 0x252525FF)
  ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgActive, 0x2A2A2AFF)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, 2, 1)

  -- Set focus on first frame
  if not state.edit_focus_set then
    ImGui.SetKeyboardFocusHere(ctx, 0)
    state.edit_focus_set = true
  end

  -- Input
  ImGui.SetNextItemWidth(ctx, width)
  local changed, new_text = ImGui.InputText(ctx, '##rename', state.edit_buffer, ImGui.InputTextFlags_AutoSelectAll)

  if changed then
    state.edit_buffer = new_text
  end

  ImGui.PopStyleVar(ctx)
  ImGui.PopStyleColor(ctx, 3)

  -- Handle Enter
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) or ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadEnter) then
    M.commit(state, opts, result)
  end

  -- Handle Escape
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
    M.cancel(state)
  end

  return true
end

-- ============================================================================
-- F2 / DOUBLE-CLICK HANDLING
-- ============================================================================

--- Handle F2 key for rename
--- @param ctx userdata ImGui context
--- @param state table Tree state
--- @param node table Node to rename
--- @param opts table Tree options
function M.handle_f2(ctx, state, node, opts)
  if not state.editing and ImGui.IsKeyPressed(ctx, ImGui.Key_F2) then
    local is_selected = state.selected[node.id]
    if is_selected and opts.renameable ~= false then
      local can_rename = true
      if opts.can_rename then
        can_rename = opts.can_rename(node)
      end
      if can_rename then
        M.start(state, node.id, node.name)
      end
    end
  end
end

--- Handle double-click for rename
--- @param ctx userdata ImGui context
--- @param state table Tree state
--- @param node table Node to rename
--- @param opts table Tree options
--- @param is_hovered boolean Whether node is hovered
function M.handle_double_click(ctx, state, node, opts, is_hovered)
  if is_hovered and ImGui.IsMouseDoubleClicked(ctx, 0) and not state.editing then
    if opts.renameable ~= false then
      local can_rename = true
      if opts.can_rename then
        can_rename = opts.can_rename(node)
      end
      if can_rename then
        M.start(state, node.id, node.name)
      end
    end
  end
end

return M
