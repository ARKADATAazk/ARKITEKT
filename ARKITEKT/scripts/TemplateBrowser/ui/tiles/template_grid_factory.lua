-- @noindex
-- TemplateBrowser/ui/tiles/template_grid_factory.lua
-- Grid factory for template tiles

local Grid = require('rearkitekt.gui.widgets.containers.grid.core')
local Colors = require('rearkitekt.core.colors')
local TemplateTile = require('TemplateBrowser.ui.tiles.template_tile')

local M = {}

function M.create(get_templates, metadata, animator, get_tile_width, on_select, on_double_click, on_right_click)
  return Grid.new({
    id = "template_grid",
    gap = TemplateTile.CONFIG.gap,
    min_col_w = get_tile_width,  -- Use function to get dynamic tile width
    fixed_tile_h = TemplateTile.CONFIG.base_tile_height,

    -- Data source
    get_items = get_templates,

    -- Unique key for each template
    key = function(template)
      return "template_" .. tostring(template.uuid)
    end,

    -- Tile rendering
    render_tile = function(ctx, rect, template, state)
      TemplateTile.render(ctx, rect, template, state, metadata, animator)
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

      -- Drag start (for drag-drop to tracks)
      drag_start = function(item_keys)
        local items = {}
        for _, key in ipairs(item_keys) do
          local uuid = key:match("template_(.+)")  -- Keep as string!
          local templates = get_templates()
          for _, tmpl in ipairs(templates) do
            if tmpl.uuid == uuid then
              table.insert(items, tmpl)
              break
            end
          end
        end
        return items
      end,

      -- Drag-drop payload (for ImGui drag-drop to folders)
      drag_drop_payload = function(key, item)
        -- Return template UUID as payload
        return item.uuid
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

      -- Marquee selection box
      marquee = {
        fill_color = Colors.hexrgb("#FFFFFF") | 0x22,  -- Semi-transparent white
        stroke_color = Colors.hexrgb("#FFFFFF") | 0xAA,
        stroke_thickness = 1,
      },

      -- Drag threshold
      drag = {
        threshold = 6,
      },
    },
  })
end

return M
