-- @noindex
-- ThemeAdjuster/ui/grids/templates_grid_factory.lua
-- Templates grid factory

local Grid = require('rearkitekt.gui.widgets.containers.grid.core')
local TemplateTile = require('ThemeAdjuster.ui.grids.renderers.template_tile')
local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

local function create_behaviors(view)
  return {
    drag_start = function(item_keys)
      -- Templates can be dragged to assignment grids
      if view.bridge then
        return
      end
    end,

    reorder = function(new_order)
      -- Reorder templates
      view:reorder_templates(new_order)
    end,

    delete = function(item_keys)
      -- Delete templates
      for _, key in ipairs(item_keys) do
        local template_id = key:match("^template_(.+)")
        if template_id then
          view:delete_template(template_id)
        end
      end
    end,

    on_select = function(selected_keys)
      -- Optional: Update selection state
    end,
  }
end

local function create_external_drop_handler(view)
  return function(insert_index)
    -- This will be handled by GridBridge on_cross_grid_drop
  end
end

local function create_external_drag_check(view)
  return function()
    if view.bridge then
      return view.bridge:is_external_drag_for('templates')
    end
    return false
  end
end

local function create_copy_mode_check(view)
  return function()
    if view.bridge then
      return view.bridge:compute_copy_mode('templates')
    end
    return false
  end
end

local function create_render_tile(view)
  return function(ctx, rect, item, state)
    TemplateTile.render(ctx, rect, item, state, view)
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

  local drop_config = config.drop_config or {
    indicator_color = hexrgb("#7788FFAA"),
    indicator_thickness = 2,
    enabled = true,
  }

  local ghost_config = config.ghost_config or {
    enabled = true,
    opacity = 0.5,
  }

  return Grid.new({
    id = "templates",
    gap = 2,
    min_col_w = function() return 400 end,
    fixed_tile_h = 32,

    get_items = function() return view:get_template_items() end,
    key = function(item) return "template_" .. item.id end,

    external_drag_check = create_external_drag_check(view),
    is_copy_mode_check = create_copy_mode_check(view),

    behaviors = create_behaviors(view),

    accept_external_drops = true,
    on_external_drop = create_external_drop_handler(view),

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
      drop = drop_config,
      drag = { threshold = 6 },
    },
  })
end

return M
