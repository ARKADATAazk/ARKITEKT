-- @noindex
-- ThemeAdjuster/ui/grids/templates_grid_factory.lua
-- Templates grid factory

local Grid = require('arkitekt.gui.widgets.containers.grid.core')
local TemplateTile = require('ThemeAdjuster.ui.grids.renderers.template_tile')
local TemplateGroupConfig = require('ThemeAdjuster.ui.grids.renderers.template_group_config')
local TileGroup = require('arkitekt.gui.widgets.containers.tile_group')
local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

-- State for inline group renaming
M._group_rename_state = M._group_rename_state or {}

local function create_behaviors(view)
  return {
    drag_start = function(grid, item_keys)
      -- Templates and groups can be dragged to assignment grids
      if view.bridge then
        return
      end
    end,

    reorder = function(grid, new_order)
      -- Reorder templates
      view:reorder_templates(new_order)
    end,

    delete = function(grid, item_keys)
      -- Delete templates or groups
      for _, key in ipairs(item_keys) do
        if key:match("^template_group_header_") then
          -- Delete group
          local group_id = key:match("^template_group_header_(.+)")
          if group_id then
            view:delete_template_group(group_id)
          end
        else
          -- Delete template
          local template_id = key:match("^template_(.+)")
          if template_id then
            view:delete_template(template_id)
          end
        end
      end
    end,

    on_select = function(grid, selected_keys)
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
  return function(ctx, rect, item, state, grid)
    -- Check if this is a group header
    if TileGroup.is_group_header(item) then
      local ImGui = require 'imgui' '0.10'
      local group_id = item.__group_id
      local group_ref = item.__group_ref

      -- Check if this group is being renamed
      local is_renaming = M._group_rename_state[group_id]

      if is_renaming then
        -- Render rename input
        local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
        ImGui.SetCursorScreenPos(ctx, x1 + 8, y1 + 6)
        ImGui.SetNextItemWidth(ctx, (x2 - x1) - 16)

        -- Initialize rename buffer if not set
        if not M._group_rename_state[group_id].buffer then
          M._group_rename_state[group_id].buffer = group_ref.name or ""
          M._group_rename_state[group_id].set_focus = true
        end

        -- Set focus on first frame
        if M._group_rename_state[group_id].set_focus then
          ImGui.SetKeyboardFocusHere(ctx)
          M._group_rename_state[group_id].set_focus = false
        end

        local flags = ImGui.InputTextFlags_EnterReturnsTrue
        local rv, new_name = ImGui.InputText(ctx, "##group_rename_" .. group_id, M._group_rename_state[group_id].buffer, flags)

        -- Check if we should finish renaming
        local should_finish = rv  -- Enter was pressed
        if not should_finish and ImGui.IsItemDeactivated(ctx) then
          -- Lost focus, finish renaming
          should_finish = true
        end

        if should_finish then
          -- Save the new name to the actual group object
          if new_name and new_name ~= "" then
            -- Find and update the actual group object in view.template_groups
            for _, g in ipairs(view.template_groups) do
              if g.id == group_id then
                g.name = new_name
                break
              end
            end
            view:save_templates()
          end
          -- Exit rename mode
          M._group_rename_state[group_id] = nil
        else
          -- Update buffer
          M._group_rename_state[group_id].buffer = new_name
        end
      else
        -- Render group header normally
        local clicked = TileGroup.render_header(ctx, rect, item, state)
        if clicked then
          -- Toggle group collapse state
          TileGroup.toggle_group(item)

          -- Persist the collapsed state
          view.template_group_collapsed_states[group_id] = group_ref.collapsed
          view:save_templates()
        end

        -- Add invisible button for interactions
        local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
        ImGui.SetCursorScreenPos(ctx, x1, y1)
        ImGui.InvisibleButton(ctx, "##group_header_interact_" .. group_id, x2 - x1, y2 - y1)

        -- Double-click to rename
        if ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
          M._group_rename_state[group_id] = { buffer = nil, set_focus = true }
        end

        -- Right-click context menu for group
        if ImGui.BeginPopupContextItem(ctx, "group_context_" .. group_id) then
          if ImGui.MenuItem(ctx, "Rename") then
            M._group_rename_state[group_id] = { buffer = nil, set_focus = true }
          end

          ImGui.Separator(ctx)

          if ImGui.MenuItem(ctx, "Configure Group...") then
            TemplateGroupConfig.open_config(group_id, view)
          end

          ImGui.Separator(ctx)

          if ImGui.MenuItem(ctx, "Delete Group") then
            view:delete_template_group(group_id)
          end

          ImGui.EndPopup(ctx)
        end
      end
    else
      -- Render regular template tile (extract original item if wrapped)
      local template_item = TileGroup.get_original_item(item)
      local indent = TileGroup.get_indent(item)

      -- Apply indent to rect if needed
      if indent > 0 then
        rect = {rect[1] + indent, rect[2], rect[3], rect[4]}
      end

      TemplateTile.render(ctx, rect, template_item, state, view)
    end
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
    key = function(item)
      -- Handle group headers
      if TileGroup.is_group_header(item) then
        return "template_group_header_" .. item.__group_id
      end

      -- Handle regular or grouped template items
      local template_item = TileGroup.get_original_item(item)
      return "template_" .. template_item.id
    end,

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
