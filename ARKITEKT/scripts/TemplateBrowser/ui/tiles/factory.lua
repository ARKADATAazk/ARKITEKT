-- @noindex
-- TemplateBrowser/ui/tiles/factory.lua
-- Grid opts factory for template tiles

local ImGui = require('arkitekt.platform.imgui')
local Ark = require('arkitekt')
local TemplateTile = require('TemplateBrowser.ui.tiles.tile')
local TemplateTileCompact = require('TemplateBrowser.ui.tiles.tile_compact')
local DragDrop = require('arkitekt.gui.interaction.drag_drop')
local Constants = require('TemplateBrowser.defs.constants')
local Tooltips = require('TemplateBrowser.ui.tooltips')

local M = {}

--- Create grid opts for template grid
--- @param deps table Dependencies { get_templates, metadata, animator, get_tile_width, get_view_mode, callbacks, gui }
--- @return table Grid opts to pass to Ark.Grid()
function M.create_opts(deps)
  local get_templates = deps.get_templates
  local metadata = deps.metadata
  local animator = deps.animator
  local get_tile_width = deps.get_tile_width
  local get_view_mode = deps.get_view_mode
  local on_select = deps.on_select
  local on_double_click = deps.on_double_click
  local on_right_click = deps.on_right_click
  local on_star_click = deps.on_star_click
  local on_tag_drop = deps.on_tag_drop
  local gui = deps.gui
  local id = deps.id or "template_grid"

  -- Determine layout based on view mode
  local view_mode = get_view_mode and get_view_mode() or "grid"
  local gap, fixed_tile_h
  if view_mode == "list" then
    gap = 4
    fixed_tile_h = TemplateTileCompact.CONFIG.tile_height
  else
    gap = TemplateTile.CONFIG.gap
    fixed_tile_h = TemplateTile.CONFIG.base_tile_height
  end

  return {
    id = id,
    gap = gap,
    min_col_w = get_tile_width,
    fixed_tile_h = fixed_tile_h,

    -- Data source
    items = get_templates(),

    -- Unique key for each template
    key = function(template)
      return "template_" .. tostring(template.uuid)
    end,

    -- Tile rendering
    render_item = function(ctx, rect, template, state)
      local current_view_mode = get_view_mode and get_view_mode() or "grid"

      -- Add fonts to state for tile rendering (from GUI reference)
      state.fonts = gui and gui.fonts or nil

      -- Use appropriate tile renderer based on view mode
      if current_view_mode == "list" then
        TemplateTileCompact.render(ctx, rect, template, state, metadata, animator)
      else
        TemplateTile.render(ctx, rect, template, state, metadata, animator)
      end

      -- Handle star click
      if state.star_clicked and on_star_click then
        on_star_click(template)
        state.star_clicked = false
      end

      -- Show track tree tooltip on hover (with delay)
      if state.hover then
        ImGui.SetCursorScreenPos(ctx, rect[1], rect[2])
        ImGui.InvisibleButton(ctx, "##tooltip_" .. template.uuid, rect[3] - rect[1], rect[4] - rect[2])
        Tooltips.show_template_info(ctx, ImGui, template, metadata)
      end

      -- Handle drop targets for tags
      if on_tag_drop then
        local is_tag_dragging = DragDrop.get_active_drag_type() == Constants.DRAG_TYPES.TAG

        if is_tag_dragging then
          local selected_keys = gui and gui.state and gui.state.selected_template_keys or {}
          local template_key = "template_" .. template.uuid

          local is_selected = false
          for _, key in ipairs(selected_keys) do
            if key == template_key then
              is_selected = true
              break
            end
          end

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

          if is_selected and hovered_is_selected then
            DragDrop.draw_active_target(ctx, rect)
          else
            DragDrop.draw_potential_target(ctx, rect)
          end
        end

        ImGui.SetCursorScreenPos(ctx, rect[1], rect[2])
        ImGui.InvisibleButton(ctx, "##tile_drop_" .. template.uuid, rect[3] - rect[1], rect[4] - rect[2])

        ImGui.PushStyleColor(ctx, ImGui.Col_DragDropTarget, 0x00000000)

        if ImGui.BeginDragDropTarget(ctx) then
          local template_key = "template_" .. template.uuid
          DragDrop.set_hovered_drop_target(template_key)

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

          local payload = DragDrop.accept_drop(ctx, Constants.DRAG_TYPES.TAG, ImGui.DragDropFlags_AcceptNoDrawDefaultRect)
          if payload then
            on_tag_drop(template, payload)
          end
          ImGui.EndDragDropTarget(ctx)
        end

        ImGui.PopStyleColor(ctx)
      end
    end,

    -- Behaviors
    behaviors = {
      on_select = function(grid, selected_keys)
        if on_select then
          on_select(selected_keys)
        end
      end,

      ['double_click'] = function(grid, key)
        if on_double_click then
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

      ['click:right'] = function(grid, key, selected_keys)
        if on_right_click then
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

      drag_start = function(grid, item_keys)
        local items = {}
        local uuids = {}

        for _, key in ipairs(item_keys) do
          local uuid = key:match("template_(.+)")
          local templates = get_templates()
          for _, tmpl in ipairs(templates) do
            if tmpl.uuid == uuid then
              items[#items + 1] = tmpl
              uuids[#uuids + 1] = uuid
              break
            end
          end
        end

        if grid then
          grid.drag_payload_type = "TEMPLATE"
          grid.drag_payload_data = table.concat(uuids, "\n")
          grid.drag_label = #items > 1
            and ("Move " .. #items .. " templates")
            or ("Move: " .. items[1].name)
        end

        return items
      end,
    },

    extend_input_area = {
      left = 6,
      right = 6,
      top = 6,
      bottom = 6,
    },

    config = {
      spawn = {
        enabled = true,
        duration = 0.25,
      },
      destroy = {
        enabled = true,
        duration = 0.2,
      },
      marquee = {
        fill_color = Ark.Colors.hexrgb("#FFFFFF22"),
        fill_color_add = Ark.Colors.hexrgb("#FFFFFF33"),
        stroke_color = Ark.Colors.hexrgb("#FFFFFF"),
        stroke_thickness = 1,
        rounding = 0,
      },
      drag = {
        threshold = 6,
      },
    },
  }
end

return M
