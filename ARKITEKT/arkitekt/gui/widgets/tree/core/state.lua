-- @noindex
-- arkitekt/gui/widgets/tree/core/state.lua
-- Hidden state management for Tree widgets (ID-keyed, auto-cleanup)

local Config = require('arkitekt.gui.widgets.tree.config')
local HeightStabilizer = require('arkitekt.gui.layout.height_stabilizer')

local M = {}

-- ============================================================================
-- STATE STORAGE
-- ============================================================================

-- Strong tables required - weak tables cause flickering due to inter-frame GC
local tree_states = {}
local access_times = {}
local last_cleanup_time = 0

-- ============================================================================
-- STATE STRUCTURE
-- ============================================================================

local function create_initial_state()
  return {
    -- Expansion
    open = {},  -- { [node_id] = true, ... }

    -- Selection
    selected = {},  -- { [node_id] = true, ... }
    focused = nil,  -- Currently focused node ID
    anchor = nil,  -- Anchor for shift-selection

    -- Navigation
    flat_list = {},  -- Flattened visible nodes for keyboard nav
    scroll_y = 0,
    total_content_height = 0,

    -- Height stabilization (prevents scrollbar flicker)
    height_stabilizer = HeightStabilizer.new({
      stable_frames_required = 2,
      height_hysteresis = 8,  -- Tighter tolerance for tree rows
    }),

    -- Hover
    hovered = nil,

    -- Inline rename
    editing = nil,  -- Node ID being edited
    edit_buffer = '',
    edit_focus_set = false,

    -- Type-to-search
    type_buffer = '',
    type_timeout = 0,

    -- Drag & drop
    drag_active = false,
    drag_node_id = nil,
    drag_node_ids = {},  -- All nodes being dragged (multi-drag)
    drag_is_copy = false,
    drag_start_x = 0,
    drag_start_y = 0,
    drop_target_id = nil,
    drop_position = nil,  -- 'before', 'into', 'after'

    -- Clipboard
    clipboard = {},
    clipboard_mode = nil,  -- 'cut' or 'copy'

    -- Context menu
    context_menu_open = false,
    context_menu_x = 0,
    context_menu_y = 0,

    -- TreeTable columns (if applicable)
    sort_column = nil,
    sort_ascending = true,
    resizing_column = nil,
    resize_start_x = 0,
    resize_start_width = 0,

    -- Bounds for click detection
    tree_bounds = { x = 0, y = 0, w = 0, h = 0 },
  }
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Get or create state for a tree instance
--- @param id string Tree widget ID
--- @return table State object
function M.get(id)
  if not tree_states[id] then
    tree_states[id] = create_initial_state()
  end
  access_times[id] = reaper.time_precise()
  return tree_states[id]
end

--- Check if state exists for an ID
--- @param id string Tree widget ID
--- @return boolean
function M.exists(id)
  return tree_states[id] ~= nil
end

--- Reset state for a tree instance
--- @param id string Tree widget ID
function M.reset(id)
  tree_states[id] = create_initial_state()
  access_times[id] = reaper.time_precise()
end

--- Remove state for a tree instance
--- @param id string Tree widget ID
function M.remove(id)
  tree_states[id] = nil
  access_times[id] = nil
end

--- Cleanup stale states (call periodically)
function M.cleanup()
  local cfg = Config.DEFAULTS
  local now = reaper.time_precise()

  if now - last_cleanup_time < cfg.cleanup_interval then
    return
  end
  last_cleanup_time = now

  for id, last_access in pairs(access_times) do
    if now - last_access > cfg.stale_threshold then
      tree_states[id] = nil
      access_times[id] = nil
    end
  end
end

-- ============================================================================
-- SELECTION HELPERS
-- ============================================================================

--- Check if a node is selected
--- @param state table State object
--- @param node_id string Node ID
--- @return boolean
function M.is_selected(state, node_id)
  return state.selected[node_id] == true
end

--- Set single selection
--- @param state table State object
--- @param node_id string Node ID
function M.set_single_selection(state, node_id)
  state.selected = { [node_id] = true }
  state.anchor = node_id
  state.focused = node_id
end

--- Toggle selection
--- @param state table State object
--- @param node_id string Node ID
function M.toggle_selection(state, node_id)
  if state.selected[node_id] then
    state.selected[node_id] = nil
  else
    state.selected[node_id] = true
  end
end

--- Clear selection
--- @param state table State object
function M.clear_selection(state)
  state.selected = {}
  state.anchor = nil
end

--- Select range between anchor and target
--- @param state table State object
--- @param target_id string Target node ID
function M.select_range(state, target_id)
  if not state.anchor then
    M.set_single_selection(state, target_id)
    return
  end

  local from_idx, to_idx
  for i, item in ipairs(state.flat_list) do
    if item.id == state.anchor then from_idx = i end
    if item.id == target_id then to_idx = i end
  end

  if from_idx and to_idx then
    if from_idx > to_idx then
      from_idx, to_idx = to_idx, from_idx
    end
    state.selected = {}
    for i = from_idx, to_idx do
      state.selected[state.flat_list[i].id] = true
    end
  end
end

--- Select all visible nodes
--- @param state table State object
function M.select_all(state)
  state.selected = {}
  for _, item in ipairs(state.flat_list) do
    state.selected[item.id] = true
  end
end

--- Invert selection
--- @param state table State object
function M.invert_selection(state)
  local new_selection = {}
  for _, item in ipairs(state.flat_list) do
    if not state.selected[item.id] then
      new_selection[item.id] = true
    end
  end
  state.selected = new_selection
end

--- Get count of selected nodes
--- @param state table State object
--- @return number
function M.get_selection_count(state)
  local count = 0
  for _ in pairs(state.selected) do
    count = count + 1
  end
  return count
end

--- Get array of selected node IDs
--- @param state table State object
--- @return table Array of node IDs
function M.get_selected_ids(state)
  local ids = {}
  for id in pairs(state.selected) do
    ids[#ids + 1] = id
  end
  return ids
end

-- ============================================================================
-- EXPANSION HELPERS
-- ============================================================================

--- Check if a node is open
--- @param state table State object
--- @param node_id string Node ID
--- @return boolean
function M.is_open(state, node_id)
  return state.open[node_id] == true
end

--- Toggle node expansion
--- @param state table State object
--- @param node_id string Node ID
function M.toggle_open(state, node_id)
  state.open[node_id] = not state.open[node_id]
end

--- Expand all nodes recursively
--- @param state table State object
--- @param nodes table Root nodes
function M.expand_all(state, nodes)
  local function expand(ns)
    for _, node in ipairs(ns) do
      state.open[node.id] = true
      if node.children and #node.children > 0 then
        expand(node.children)
      end
    end
  end
  expand(nodes)
end

--- Collapse all nodes
--- @param state table State object
function M.collapse_all(state)
  state.open = {}
end

return M
