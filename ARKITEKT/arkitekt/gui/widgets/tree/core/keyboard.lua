-- @noindex
-- arkitekt/gui/widgets/tree/core/keyboard.lua
-- Keyboard navigation and type-to-search for Tree widgets

local ImGui = require('arkitekt.core.imgui')
local State = require('arkitekt.gui.widgets.tree.core.state')

local M = {}

-- ============================================================================
-- ARROW KEY NAVIGATION
-- ============================================================================

--- Handle arrow key navigation
--- @param ctx userdata ImGui context
--- @param state table Tree state
--- @param cfg table Configuration
--- @param bounds table Tree bounds { x, y, w, h }
--- @param result table Result object
function M.handle_arrows(ctx, state, cfg, bounds, result)
  if not state.focused or #state.flat_list == 0 then return end

  local shift = ImGui.GetKeyMods(ctx) & ImGui.Mod_Shift ~= 0

  -- Find focused index
  local focused_idx = nil
  for i, item in ipairs(state.flat_list) do
    if item.id == state.focused then
      focused_idx = i
      break
    end
  end

  if not focused_idx then return end

  local new_idx = nil

  -- Home: Jump to first item
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Home) then
    new_idx = 1
  -- End: Jump to last item
  elseif ImGui.IsKeyPressed(ctx, ImGui.Key_End) then
    new_idx = #state.flat_list
  -- Page Up: Jump up ~10 items
  elseif ImGui.IsKeyPressed(ctx, ImGui.Key_PageUp) then
    new_idx = math.max(1, focused_idx - 10)
  -- Page Down: Jump down ~10 items
  elseif ImGui.IsKeyPressed(ctx, ImGui.Key_PageDown) then
    new_idx = math.min(#state.flat_list, focused_idx + 10)
  -- Up arrow
  elseif ImGui.IsKeyPressed(ctx, ImGui.Key_UpArrow) then
    new_idx = math.max(1, focused_idx - 1)
  -- Down arrow
  elseif ImGui.IsKeyPressed(ctx, ImGui.Key_DownArrow) then
    new_idx = math.min(#state.flat_list, focused_idx + 1)
  -- Left arrow: collapse or go to parent
  elseif ImGui.IsKeyPressed(ctx, ImGui.Key_LeftArrow) then
    local focused_item = state.flat_list[focused_idx]
    if state.open[focused_item.id] then
      state.open[focused_item.id] = false
      result.expand_changed = true
    elseif focused_item.parent_id then
      -- Find parent in flat list
      for i, item in ipairs(state.flat_list) do
        if item.id == focused_item.parent_id then
          new_idx = i
          break
        end
      end
    end
  -- Right arrow: expand or go to first child
  elseif ImGui.IsKeyPressed(ctx, ImGui.Key_RightArrow) then
    local focused_item = state.flat_list[focused_idx]
    local has_children = focused_item.node.children and #focused_item.node.children > 0
    if has_children then
      if not state.open[focused_item.id] then
        state.open[focused_item.id] = true
        result.expand_changed = true
      elseif focused_idx < #state.flat_list then
        new_idx = focused_idx + 1
      end
    end
  end

  -- Apply navigation
  if new_idx and new_idx ~= focused_idx then
    local new_id = state.flat_list[new_idx].id

    if shift and state.anchor then
      -- SHIFT+arrow: Range selection
      State.select_range(state, new_id)
      state.focused = new_id
    else
      -- Normal arrow: Move selection
      State.set_single_selection(state, new_id)
    end

    result.selection_changed = true

    -- Auto-scroll to keep focused item visible
    M.scroll_to_item(state, cfg, bounds, new_idx)
  end
end

--- Scroll to make an item visible
--- @param state table Tree state
--- @param cfg table Configuration
--- @param bounds table Tree bounds
--- @param item_idx number Item index in flat_list
function M.scroll_to_item(state, cfg, bounds, item_idx)
  local item_info = state.flat_list[item_idx]
  if not item_info then return end

  local item_screen_y = item_info.y_pos
  local visible_top = bounds.y + cfg.padding_top
  local visible_bottom = bounds.y + bounds.h - cfg.padding_bottom

  if item_screen_y < visible_top then
    state.scroll_y = state.scroll_y - (visible_top - item_screen_y)
  elseif item_screen_y + item_info.height > visible_bottom then
    state.scroll_y = state.scroll_y + (item_screen_y + item_info.height - visible_bottom)
  end

  state.scroll_y = math.max(0, state.scroll_y)
end

-- ============================================================================
-- EXPAND/COLLAPSE SHORTCUTS
-- ============================================================================

--- Handle expand/collapse shortcuts
--- @param ctx userdata ImGui context
--- @param state table Tree state
--- @param nodes table Root nodes
--- @param result table Result object
function M.handle_expand_shortcuts(ctx, state, nodes, result)
  local ctrl = ImGui.GetKeyMods(ctx) & ImGui.Mod_Ctrl ~= 0

  -- CTRL+8 (*): Expand all
  if ctrl and ImGui.IsKeyPressed(ctx, ImGui.Key_8) then
    State.expand_all(state, nodes)
    result.expand_changed = true
    return
  end

  -- CTRL+9: Collapse all
  if ctrl and ImGui.IsKeyPressed(ctx, ImGui.Key_9) then
    State.collapse_all(state)
    result.expand_changed = true
    return
  end
end

-- ============================================================================
-- TYPE-TO-SEARCH
-- ============================================================================

--- Handle type-to-search navigation
--- @param ctx userdata ImGui context
--- @param state table Tree state
--- @param cfg table Configuration
--- @param bounds table Tree bounds
--- @param result table Result object
function M.handle_type_search(ctx, state, cfg, bounds, result)
  local current_time = reaper.time_precise()

  -- Clear buffer if timeout exceeded
  if state.type_timeout > 0 and current_time > state.type_timeout then
    state.type_buffer = ''
    state.type_timeout = 0
  end

  -- Only capture when no modifiers (except shift for case)
  local mods = ImGui.GetKeyMods(ctx)
  local no_modifiers = mods & ImGui.Mod_Ctrl == 0 and mods & ImGui.Mod_Alt == 0

  if not no_modifiers then return end

  local char_captured = false
  local shift_held = mods & ImGui.Mod_Shift ~= 0

  -- Check letter keys A-Z
  local letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  for i = 1, #letters do
    local letter = letters:sub(i, i)
    local key = ImGui['Key_' .. letter]
    if key and ImGui.IsKeyPressed(ctx, key) then
      state.type_buffer = state.type_buffer .. (shift_held and letter or letter:lower())
      state.type_timeout = current_time + cfg.type_search_timeout
      char_captured = true
      break
    end
  end

  -- Check number keys 0-9
  if not char_captured then
    local numbers = '0123456789'
    for i = 1, #numbers do
      local num = numbers:sub(i, i)
      local key = ImGui['Key_' .. num]
      if key and ImGui.IsKeyPressed(ctx, key) then
        state.type_buffer = state.type_buffer .. num
        state.type_timeout = current_time + cfg.type_search_timeout
        char_captured = true
        break
      end
    end
  end

  -- Check common punctuation
  if not char_captured then
    local punct_keys = {
      { ImGui.Key_Space, ' ' },
      { ImGui.Key_Minus, '-' },
      { ImGui.Key_Period, '.' },
      { ImGui.Key_Slash, '/' },
      { ImGui.Key_Apostrophe, '_' },
    }
    for _, pair in ipairs(punct_keys) do
      if ImGui.IsKeyPressed(ctx, pair[1]) then
        state.type_buffer = state.type_buffer .. pair[2]
        state.type_timeout = current_time + cfg.type_search_timeout
        char_captured = true
        break
      end
    end
  end

  -- Search for matching item
  if char_captured and state.type_buffer ~= '' and #state.flat_list > 0 then
    local search_term = state.type_buffer:lower()
    local found_idx = nil

    -- First: find item that starts with search term
    for i, item in ipairs(state.flat_list) do
      local item_name = item.node.name:lower()
      if item_name:sub(1, #search_term) == search_term then
        found_idx = i
        break
      end
    end

    -- Fallback: find item containing search term
    if not found_idx then
      for i, item in ipairs(state.flat_list) do
        local item_name = item.node.name:lower()
        if item_name:find(search_term, 1, true) then
          found_idx = i
          break
        end
      end
    end

    -- Jump to found item
    if found_idx then
      State.set_single_selection(state, state.flat_list[found_idx].id)
      M.scroll_to_item(state, cfg, bounds, found_idx)
      result.selection_changed = true
    end
  end
end

-- ============================================================================
-- DELETE KEY
-- ============================================================================

--- Handle delete key
--- @param ctx userdata ImGui context
--- @param state table Tree state
--- @param opts table Tree options
--- @param result table Result object
function M.handle_delete(ctx, state, opts, result)
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Delete) then
    local selected_ids = State.get_selected_ids(state)
    if #selected_ids > 0 and opts.on_delete then
      opts.on_delete(selected_ids)
      result.deleted = true
      result.deleted_ids = selected_ids
    end
  end
end

return M
