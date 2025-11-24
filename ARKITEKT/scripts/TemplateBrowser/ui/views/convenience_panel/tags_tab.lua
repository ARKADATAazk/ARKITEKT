-- @noindex
-- TemplateBrowser/ui/views/convenience_panel/tags_tab.lua
-- Mini tags tab for convenience panel

local ImGui = require 'imgui' '0.10'
local Colors = require('arkitekt.core.colors')
local Tags = require('TemplateBrowser.domain.tags')
local Button = require('arkitekt.gui.widgets.primitives.button')
local Chip = require('arkitekt.gui.widgets.data.chip')
local ChipList = require('arkitekt.gui.widgets.data.chip_list')
local Helpers = require('TemplateBrowser.ui.views.helpers')
local UI = require('TemplateBrowser.ui.ui_constants')
local Constants = require('TemplateBrowser.defs.constants')

local M = {}

-- Draw mini tags list with filtering
function M.draw(ctx, state, config, width, height)
  if not Helpers.begin_child_compat(ctx, "ConvenienceTags", width, height, false) then
    return
  end

  -- Header with "+" button
  ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.header_bg)

  -- Position button at the right
  local button_x = width - UI.BUTTON.WIDTH_SMALL - 8
  ImGui.SetCursorPosX(ctx, button_x)

  if Button.draw_at_cursor(ctx, {
    label = "+",
    width = UI.BUTTON.WIDTH_SMALL,
    height = UI.BUTTON.HEIGHT_DEFAULT
  }, "createtag_conv") then
    -- Create new tag - prompt for name
    local tag_num = 1
    local new_tag_name = "Tag " .. tag_num

    -- Find unique name
    if state.metadata and state.metadata.tags then
      while state.metadata.tags[new_tag_name] do
        tag_num = tag_num + 1
        new_tag_name = "Tag " .. tag_num
      end
    end

    -- Create tag with default color (dark grey)
    Tags.create_tag(state.metadata, new_tag_name)

    -- Save metadata
    local Persistence = require('TemplateBrowser.domain.persistence')
    Persistence.save_metadata(state.metadata)
  end

  ImGui.PopStyleColor(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Calculate remaining height for tags list
  local tags_list_height = height - UI.HEADER.DEFAULT - UI.PADDING.SEPARATOR_SPACING

  -- List all tags with filtering (scrollable) using justified layout
  if Helpers.begin_child_compat(ctx, "ConvenienceTagsList", 0, tags_list_height, false) then
    if state.metadata and state.metadata.tags then
      -- Build sorted list of tags
      local tag_items = {}
      local selected_ids = {}

      for tag_name, tag_data in pairs(state.metadata.tags) do
        tag_items[#tag_items + 1] = {
          id = tag_name,
          label = tag_name,
          color = tag_data.color,
        }

        if state.filter_tags[tag_name] then
          selected_ids[tag_name] = true
        end
      end

      -- Sort alphabetically
      table.sort(tag_items, function(a, b) return a.label < b.label end)

      if #tag_items > 0 then
        -- Draw tags using justified chip_list (ACTION style)
        -- Unselected tags at 30% opacity (77 = 0.3 * 255)
        local content_w = ImGui.GetContentRegionAvail(ctx)
        local clicked_id, _, right_clicked_id = ChipList.draw(ctx, tag_items, {
          justified = true,
          max_stretch_ratio = 1.5,
          selected_ids = selected_ids,
          style = Chip.STYLE.ACTION,
          chip_height = UI.CHIP.HEIGHT_DEFAULT,
          chip_spacing = 6,
          line_spacing = 3,
          rounding = 2,
          padding_h = 8,
          max_width = content_w,
          unselected_alpha = 77,
          drag_type = Constants.DRAG_TYPES.TAG,
        })

        if clicked_id then
          -- Toggle tag filter
          if state.filter_tags[clicked_id] then
            state.filter_tags[clicked_id] = nil
          else
            state.filter_tags[clicked_id] = true
          end

          -- Re-filter templates
          local Scanner = require('TemplateBrowser.domain.scanner')
          Scanner.filter_templates(state)
        end

        -- Handle right-click - open color picker context menu
        if right_clicked_id then
          state.context_menu_tag = right_clicked_id
        end
      end
    else
      ImGui.TextDisabled(ctx, "No tags yet")
    end

    ImGui.EndChild(ctx)  -- End ConvenienceTagsList
  end

  ImGui.EndChild(ctx)  -- End ConvenienceTags
end

return M
