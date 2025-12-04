-- @noindex
-- arkitekt/gui/widgets/tree/core/selection.lua
-- Selection handling for Tree widgets

local ImGui = require('arkitekt.core.imgui')
local State = require('arkitekt.gui.widgets.tree.core.state')

local M = {}

-- ============================================================================
-- CLICK HANDLING
-- ============================================================================

--- Handle node click for selection
--- @param ctx userdata ImGui context
--- @param state table Tree state
--- @param node_id string Clicked node ID
--- @param opts table Tree options
--- @param result table Result object
function M.handle_click(ctx, state, node_id, opts, result)
  local ctrl = ImGui.GetKeyMods(ctx) & ImGui.Mod_Ctrl ~= 0
  local shift = ImGui.GetKeyMods(ctx) & ImGui.Mod_Shift ~= 0

  result.clicked_id = node_id

  if opts.multi_select ~= false then
    -- Multi-select mode
    if ctrl then
      -- CTRL+click: Toggle individual selection
      State.toggle_selection(state, node_id)
      state.anchor = node_id
      state.focused = node_id
    elseif shift and state.anchor then
      -- SHIFT+click: Range selection from anchor
      State.select_range(state, node_id)
      state.focused = node_id
    else
      -- Normal click: Single selection
      State.set_single_selection(state, node_id)
    end
  else
    -- Single select mode
    State.set_single_selection(state, node_id)
  end

  result.selection_changed = true
  if opts.on_select then
    opts.on_select(node_id, State.get_selected_ids(state))
  end
end

--- Handle click in empty space
--- @param ctx userdata ImGui context
--- @param state table Tree state
--- @param result table Result object
function M.handle_empty_click(ctx, state, result)
  if ImGui.IsMouseClicked(ctx, 0) then
    local mx, my = ImGui.GetMousePos(ctx)
    local bounds = state.tree_bounds

    local in_tree = mx >= bounds.x and mx < bounds.x + bounds.w and
                    my >= bounds.y and my < bounds.y + bounds.h

    if in_tree and not state.hovered then
      State.clear_selection(state)
      result.selection_changed = true
    end
  end
end

-- ============================================================================
-- KEYBOARD SELECTION
-- ============================================================================

--- Handle keyboard selection shortcuts
--- @param ctx userdata ImGui context
--- @param state table Tree state
--- @param nodes table Root nodes
--- @param result table Result object
function M.handle_keyboard(ctx, state, nodes, result)
  local ctrl = ImGui.GetKeyMods(ctx) & ImGui.Mod_Ctrl ~= 0

  -- ESC: Clear selection
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
    State.clear_selection(state)
    result.selection_changed = true
    return
  end

  -- CTRL+A: Select all visible
  if ctrl and ImGui.IsKeyPressed(ctx, ImGui.Key_A) then
    State.select_all(state)
    result.selection_changed = true
    return
  end

  -- CTRL+I: Invert selection
  if ctrl and ImGui.IsKeyPressed(ctx, ImGui.Key_I) then
    State.invert_selection(state)
    result.selection_changed = true
    return
  end
end

return M
