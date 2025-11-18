-- @noindex
-- ThemeAdjuster/ui/grids/library_grid_factory.lua
-- Parameter library grid factory

local Grid = require('rearkitekt.gui.widgets.containers.grid.core')
local LibraryTile = require('ThemeAdjuster.ui.grids.renderers.library_tile')
local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

local function create_behaviors(view)
  return {
    drag_start = function(item_keys)
      -- When GridBridge exists, let it handle the drag coordination
      if view.bridge then
        return
      end

      -- Fallback: no bridge, handle drag locally (not used in ThemeAdjuster)
    end,

    on_select = function(selected_keys)
      -- Optional: Update selection state
    end,
  }
end

local function create_external_drag_check(view)
  return function()
    if view.bridge then
      return view.bridge:is_external_drag_for('library')
    end
    return false
  end
end

local function create_copy_mode_check(view)
  return function()
    if view.bridge then
      return view.bridge:compute_copy_mode('library')
    end
    return true  -- Library always copies
  end
end

local function create_render_tile(view)
  return function(ctx, rect, param, state)
    LibraryTile.render(ctx, rect, param, state, view)
  end
end

local function create_exclusion_zones(view)
  return function(param, rect)
    -- Return the stored control rectangles for this parameter
    -- This prevents drag detection on interactive controls (sliders, checkboxes, text inputs)
    local rects = view.control_rects[param.index]
    return rects or nil
  end
end

function M.create(view, config)
  config = config or {}

  local padding = config.padding or 8

  -- Visual feedback configurations
  local dim_config = config.dim_config or {
    fill_color = hexrgb("#00000088"),
    stroke_color = hexrgb("#FFFFFF33"),
    stroke_thickness = 1.5,
    rounding = 3,
  }

  local ghost_config = config.ghost_config or {
    enabled = true,
    opacity = 0.5,
  }

  return Grid.new({
    id = "param_library",
    gap = 2,  -- Compact spacing
    min_col_w = function() return 600 end,  -- Single column layout
    fixed_tile_h = 32,  -- Compact tile height

    get_items = function() return view:get_library_items() end,
    key = function(param) return "lib_" .. tostring(param.index) end,

    get_exclusion_zones = create_exclusion_zones(view),

    external_drag_check = create_external_drag_check(view),
    is_copy_mode_check = create_copy_mode_check(view),

    behaviors = create_behaviors(view),

    accept_external_drops = false,  -- Library doesn't accept drops

    render_tile = create_render_tile(view),

    extend_input_area = {
      left = padding,
      right = padding,
      top = padding,
      bottom = padding
    },

    config = {
      ghost = ghost_config,
      dim = dim_config,
      drag = { threshold = 6 },
    },
  })
end

return M
