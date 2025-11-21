-- @noindex
-- TemplateBrowser/ui/tiles/template_grid_factory.lua
-- Grid factory for template tiles

local Grid = require('rearkitekt.gui.widgets.containers.grid.core')
local Colors = require('rearkitekt.core.colors')
local TemplateTile = require('TemplateBrowser.ui.tiles.template_tile')
local TemplateTileCompact = require('TemplateBrowser.ui.tiles.template_tile_compact')

local M = {}

function M.create(get_templates, metadata, animator, get_tile_width, get_view_mode, on_select, on_double_click, on_right_click, on_star_click)
  return Grid.new({
    id = "template_grid",
    gap = function()
      local view_mode = get_view_mode and get_view_mode() or "grid"
      return view_mode == "list" and 4 or TemplateTile.CONFIG.gap
    end,
    min_col_w = function()
      local view_mode = get_view_mode and get_view_mode() or "grid"
      -- In list mode, tiles take full width (return a large value to force 1 column)
      return view_mode == "list" and 9999 or get_tile_width()
    end,
    fixed_tile_h = function()
      local view_mode = get_view_mode and get_view_mode() or "grid"
      return view_mode == "list" and TemplateTileCompact.CONFIG.tile_height or TemplateTile.CONFIG.base_tile_height
    end,

    -- Data source
    get_items = get_templates,

    -- Unique key for each template
    key = function(template)
      return "template_" .. tostring(template.uuid)
    end,

    -- Tile rendering
    render_tile = function(ctx, rect, template, state)
      local view_mode = get_view_mode and get_view_mode() or "grid"

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
    end,

    -- Behaviors
    behaviors = {
      -- Selection
      on_select = function(selected_keys)
        if on_select then
          on_select(selected_keys)
        end
      end,

      -- Double-click to apply template or rename with Ctrl (receives only key)
      double_click = function(key)
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
      right_click = function(key, selected_keys)
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
      drag_start = function(item_keys, grid)
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
end

return M
