-- @noindex
-- ThemeAdjuster/ui/grids/assignment_grid_factory.lua
-- Assignment grid factory (for TCP, MCP, ENV, TRANS, GLOBAL tabs)

local Grid = require('arkitekt.gui.widgets.containers.grid.core')
local AssignmentTile = require('ThemeAdjuster.ui.grids.renderers.assignment_tile')
local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

local function create_behaviors(view, tab_id)
  return {
    drag_start = function(grid, item_keys)
      -- When GridBridge exists, let it handle the drag coordination
      if view.bridge then
        return
      end

      -- Fallback: no bridge, handle drag locally (not used in ThemeAdjuster)
    end,

    reorder = function(grid, new_order)
      -- Handle reordering within assignment grid
      view:reorder_assignments(tab_id, new_order)
    end,

    delete = function(grid, item_keys)
      -- Remove parameters or groups from this tab
      for _, key in ipairs(item_keys) do
        if key:match("^assign_group_") then
          -- This is a group
          local group_id = key:match("^assign_group_(.+)")
          if group_id then
            view:unassign_group_from_tab(group_id, tab_id)
          end
        else
          -- This is a parameter
          local param_name = key:match("^assign_(.+)")
          if param_name then
            view:unassign_param_from_tab(param_name, tab_id)
          end
        end
      end
    end,

    on_select = function(grid, selected_keys)
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

local function create_copy_mode_check(view, tab_id)
  return function()
    if view.bridge then
      return view.bridge:compute_copy_mode('assign_' .. tab_id)
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

  -- Visual feedback configurations
  local dim_config = config.dim_config or {
    fill_color = hexrgb("#00000088"),
    stroke_color = hexrgb("#FFFFFF33"),
    stroke_thickness = 1.5,
    rounding = 3,
  }

  local drop_config = config.drop_config or {
    indicator_color = hexrgb("#5588FFAA"),
    indicator_thickness = 2,
    enabled = true,
  }

  local ghost_config = config.ghost_config or {
    enabled = true,
    opacity = 0.5,
  }

  return Grid.new({
    id = "assign_" .. tab_id,
    gap = 2,  -- Compact spacing
    min_col_w = function() return 600 end,  -- Single column layout
    fixed_tile_h = 28,  -- Slightly smaller for assignment tiles

    get_items = function() return view:get_assignment_items(tab_id) end,
    key = function(item)
      if item.type == "group" then
        return "assign_group_" .. item.group_id
      else
        return "assign_" .. item.param_name
      end
    end,

    external_drag_check = create_external_drag_check(view, tab_id),
    is_copy_mode_check = create_copy_mode_check(view, tab_id),

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
      ghost = ghost_config,
      dim = dim_config,
      drop = drop_config,
      drag = { threshold = 6 },
    },
  })
end

return M
