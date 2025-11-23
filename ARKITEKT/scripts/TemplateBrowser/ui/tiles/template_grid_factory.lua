-- @noindex
-- TemplateBrowser/ui/tiles/template_grid_factory.lua
-- Grid factory for template tiles

local ImGui = require 'imgui' '0.10'
local Grid = require('arkitekt.gui.widgets.containers.grid.core')
local Colors = require('arkitekt.core.colors')
local TemplateTile = require('TemplateBrowser.ui.tiles.template_tile')
local TemplateTileCompact = require('TemplateBrowser.ui.tiles.template_tile_compact')
local DragDrop = require('arkitekt.gui.systems.drag_drop')
local Constants = require('TemplateBrowser.defs.constants')

local M = {}

function M.create(get_templates, metadata, animator, get_tile_width, get_view_mode, on_select, on_double_click, on_right_click, on_star_click, on_tag_drop, gui)
  local grid = Grid.new({
    id = "template_grid",
    gap = TemplateTile.CONFIG.gap,  -- Initial value for grid mode
    min_col_w = get_tile_width,  -- Use dynamic tile width function
    fixed_tile_h = TemplateTile.CONFIG.base_tile_height,  -- Initial value for grid mode

    -- Data source
    get_items = get_templates,

    -- Unique key for each template
    key = function(template)
      return "template_" .. tostring(template.uuid)
    end,

    -- Tile rendering
    render_tile = function(ctx, rect, template, state)
      local view_mode = get_view_mode and get_view_mode() or "grid"

      -- Add fonts to state for tile rendering (from GUI reference)
      state.fonts = gui and gui.fonts or nil

      -- Use appropriate tile renderer based on view mode
      if view_mode == "list" then
        TemplateTileCompact.render(ctx, rect, template, state, metadata, animator)
      else
        TemplateTile.render(ctx, rect, template, state, metadata, animator)
      end

      -- Handle star click
      if state.star_clicked and on_star_click then
        on_star_click(template)
        state.star_clicked = false  -- Reset flag
      end

      -- Handle drop targets for tags
      if on_tag_drop then
        -- Check if a tag is being dragged (globally)
        local is_tag_dragging = DragDrop.get_active_drag_type() == Constants.DRAG_TYPES.TAG

        if is_tag_dragging then
          -- Get selection state from GUI
          local selected_keys = gui and gui.state and gui.state.selected_template_keys or {}
          local template_key = "template_" .. template.uuid

          -- Check if this template is selected
          local is_selected = false
          for _, key in ipairs(selected_keys) do
            if key == template_key then
              is_selected = true
              break
            end
          end

          -- Check if the hovered template is in our selection
          local hovered_key = DragDrop.get_hovered_drop_target()
          local hovered_is_selected = false
          if hovered_key then
            for _, key in ipairs(selected_keys) do
              if key == hovered_key then
                hovered_is_selected = true
                break
              end
            end
          end

          -- Show active glow if: we're selected AND a selected tile is being hovered
          if is_selected and hovered_is_selected then
            DragDrop.draw_active_target(ctx, rect)
          else
            -- Draw potential target indicator
            DragDrop.draw_potential_target(ctx, rect)
          end
        end

        -- Create invisible button for drop target
        ImGui.SetCursorScreenPos(ctx, rect[1], rect[2])
        ImGui.InvisibleButton(ctx, "##tile_drop_" .. template.uuid, rect[3] - rect[1], rect[4] - rect[2])

        -- Hide default drop target rect (we draw our own glow)
        ImGui.PushStyleColor(ctx, ImGui.Col_DragDropTarget, 0x00000000)

        if ImGui.BeginDragDropTarget(ctx) then
          -- Track this as the hovered template
          local template_key = "template_" .. template.uuid
          DragDrop.set_hovered_drop_target(template_key)

          -- Draw active target highlight when hovering (if not already drawn for selection)
          local selected_keys = gui and gui.state and gui.state.selected_template_keys or {}
          local is_selected = false
          for _, key in ipairs(selected_keys) do
            if key == template_key then
              is_selected = true
              break
            end
          end
          if not is_selected or #selected_keys <= 1 then
            DragDrop.draw_active_target(ctx, rect)
          end

          -- Accept drop with no default rect (we draw our own)
          local payload = DragDrop.accept_drop(ctx, Constants.DRAG_TYPES.TAG, ImGui.DragDropFlags_AcceptNoDrawDefaultRect)
          if payload then
            -- Apply tag to template
            on_tag_drop(template, payload)
          end
          ImGui.EndDragDropTarget(ctx)
        end

        ImGui.PopStyleColor(ctx)
      end
    end,

    -- Behaviors
    behaviors = {
      -- Selection
      on_select = function(grid, selected_keys)
        if on_select then
          on_select(selected_keys)
        end
      end,

      -- Double-click to apply template or rename with Ctrl (receives only key)
      ['double_click'] = function(grid, key)
        if on_double_click then
          -- Look up template by uuid from key (keep as string!)
          local uuid = key:match("template_(.+)")
          local templates = get_templates()
          for _, tmpl in ipairs(templates) do
            if tmpl.uuid == uuid then
              on_double_click(tmpl)
              break
            end
          end
        end
      end,

      -- Right-click context menu (receives key and selected_keys)
      ['click:right'] = function(grid, key, selected_keys)
        if on_right_click then
          -- Look up template by uuid from key (keep as string!)
          local uuid = key:match("template_(.+)")
          local templates = get_templates()
          for _, tmpl in ipairs(templates) do
            if tmpl.uuid == uuid then
              on_right_click(tmpl, selected_keys)
              break
            end
          end
        end
      end,

      -- Drag start (for drag-drop to folders and tracks)
      drag_start = function(grid, item_keys)
        local items = {}
        local uuids = {}

        for _, key in ipairs(item_keys) do
          local uuid = key:match("template_(.+)")  -- Keep as string!
          local templates = get_templates()
          for _, tmpl in ipairs(templates) do
            if tmpl.uuid == uuid then
              table.insert(items, tmpl)
              table.insert(uuids, uuid)
              break
            end
          end
        end

        -- Set ImGui drag-drop payload for external drops (to folders)
        if grid then
          grid.drag_payload_type = "TEMPLATE"
          grid.drag_payload_data = table.concat(uuids, "\n")  -- Multiple UUIDs separated by newline
          grid.drag_label = #items > 1
            and ("Move " .. #items .. " templates")
            or ("Move: " .. items[1].name)
        end

        return items
      end,
    },

    -- Input area extension (easier clicking)
    extend_input_area = {
      left = 6,
      right = 6,
      top = 6,
      bottom = 6,
    },

    -- Configuration
    config = {
      -- Spawn animation when templates appear
      spawn = {
        enabled = true,
        duration = 0.25,
      },

      -- Destroy animation when templates disappear
      destroy = {
        enabled = true,
        duration = 0.2,
      },

      -- Marquee selection box (use ARKITEKT library defaults)
      marquee = {
        fill_color = Colors.hexrgb("#FFFFFF22"),  -- 13% opacity white
        fill_color_add = Colors.hexrgb("#FFFFFF33"),  -- 20% opacity for additive selection
        stroke_color = Colors.hexrgb("#FFFFFF"),  -- Full white stroke
        stroke_thickness = 1,
        rounding = 0,
      },

      -- Drag threshold
      drag = {
        threshold = 6,
      },
    },
  })

  -- Store view mode getter for dynamic updates
  grid._get_view_mode = get_view_mode

  return grid
end

-- Update grid layout properties based on current view mode
function M.update_for_view_mode(grid)
  if not grid._get_view_mode then return end

  local view_mode = grid._get_view_mode()

  if view_mode == "list" then
    grid.gap = 4
    grid.fixed_tile_h = TemplateTileCompact.CONFIG.tile_height
  else
    grid.gap = TemplateTile.CONFIG.gap
    grid.fixed_tile_h = TemplateTile.CONFIG.base_tile_height
  end
end

return M
