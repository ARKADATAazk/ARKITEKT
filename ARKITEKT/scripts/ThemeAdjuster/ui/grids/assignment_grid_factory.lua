-- @noindex
-- ThemeAdjuster/ui/grids/assignment_grid_factory.lua
-- Assignment grid factory (for TCP, MCP, ENV, TRANS, GLOBAL tabs)

local Grid = require('rearkitekt.gui.widgets.containers.grid.core')
local AssignmentTile = require('ThemeAdjuster.ui.grids.renderers.assignment_tile')
local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

local function create_behaviors(view, tab_id)
  return {
    drag_start = function(item_keys)
      -- When GridBridge exists, let it handle the drag coordination
      if view.bridge then
        return
      end

      -- Fallback: no bridge, handle drag locally (not used in ThemeAdjuster)
    end,

    reorder = function(new_order)
      -- Handle reordering within assignment grid
      view:reorder_assignments(tab_id, new_order)
    end,

    delete = function(item_keys)
      -- Remove parameters from this tab
      for _, key in ipairs(item_keys) do
        local param_name = key:match("^assign_(.+)")
        if param_name then
          view:unassign_param_from_tab(param_name, tab_id)
        end
      end
    end,

    on_select = function(selected_keys)
      -- Optional: Update selection state
    end,
  }
end

local function create_external_drop_handler(view, tab_id)
  return function(insert_index)
    -- This will be handled by GridBridge on_cross_grid_drop
  end
end

local function create_external_drag_check(view, tab_id)
  return function()
    if view.bridge then
      return view.bridge:is_external_drag_for('assign_' .. tab_id)
    end
    return false
  end
end

local function create_render_tile(view, tab_id)
  return function(ctx, rect, item, state)
    AssignmentTile.render(ctx, rect, item, state, view, tab_id)
  end
end

function M.create(view, tab_id, config)
  config = config or {}

  local padding = config.padding or 8

  return Grid.new({
    id = "assign_" .. tab_id,
    gap = 2,  -- Compact spacing
    min_col_w = function() return 600 end,  -- Single column layout
    fixed_tile_h = 28,  -- Slightly smaller for assignment tiles

    get_items = function() return view:get_assignment_items(tab_id) end,
    key = function(item) return "assign_" .. item.param_name end,

    external_drag_check = create_external_drag_check(view, tab_id),
    is_copy_mode_check = function() return false end,

    behaviors = create_behaviors(view, tab_id),

    accept_external_drops = true,
    on_external_drop = create_external_drop_handler(view, tab_id),

    render_tile = create_render_tile(view, tab_id),

    extend_input_area = {
      left = padding,
      right = padding,
      top = padding,
      bottom = padding
    },

    config = {
      drag = { threshold = 6 },
    },
  })
end

return M
