-- @noindex
-- TemplateBrowser/ui/views/left_panel/tags_tab.lua
-- Tags tab: Full tag management

local ImGui = require 'imgui' '0.10'
local Colors = require('arkitekt.core.colors')
local Tags = require('TemplateBrowser.domain.tags')
local Button = require('arkitekt.gui.widgets.primitives.button')
local Fields = require('arkitekt.gui.widgets.primitives.fields')
local Chip = require('arkitekt.gui.widgets.data.chip')
local ChipList = require('arkitekt.gui.widgets.data.chip_list')
local Helpers = require('TemplateBrowser.ui.views.helpers')
local UI = require('TemplateBrowser.ui.ui_constants')
local Constants = require('TemplateBrowser.defs.constants')

local M = {}

-- Draw TAGS content (full tag management)
function M.draw(ctx, state, config, width, height)
  -- Header with "+" button
  ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.header_bg)

  -- Position button at the right
  local button_x = width - UI.BUTTON.WIDTH_SMALL - config.PANEL_PADDING * 2
  ImGui.SetCursorPosX(ctx, button_x)

  if Button.draw_at_cursor(ctx, {
    label = "+",
    width = UI.BUTTON.WIDTH_SMALL,
    height = UI.BUTTON.HEIGHT_DEFAULT
  }, "createtag") then
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

  -- List all tags using justified layout
  if Helpers.begin_child_compat(ctx, "TagsList", width - config.PANEL_PADDING * 2, height - 30, false) then
    if state.metadata and state.metadata.tags then
      -- Build sorted list of tags
      local tag_items = {}
      for tag_name, tag_data in pairs(state.metadata.tags) do
        tag_items[#tag_items + 1] = {
          id = tag_name,
          label = tag_name,
          color = tag_data.color,
        }
      end

      -- Sort alphabetically
      table.sort(tag_items, function(a, b) return a.label < b.label end)

      if #tag_items > 0 then
        -- Check if any tag is being renamed
        local renaming_tag = nil
        if state.renaming_type == "tag" then
          renaming_tag = state.renaming_item
        end

        -- Draw tags using justified chip_list (ACTION style)
        -- Unselected tags at 30% opacity (77 = 0.3 * 255)
        local content_w = ImGui.GetContentRegionAvail(ctx)
        local clicked_id, _, right_clicked_id = ChipList.draw(ctx, tag_items, {
          justified = true,
          max_stretch_ratio = 1.5,
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

        -- Handle click - start rename on double-click
        if clicked_id then
          -- Check for double-click
          if ImGui.IsMouseDoubleClicked(ctx, 0) then
            state.renaming_item = clicked_id
            state.renaming_type = "tag"
            state.rename_buffer = clicked_id
          end
        end

        -- Handle right-click - open color picker context menu
        if right_clicked_id then
          state.context_menu_tag = right_clicked_id
        end

        -- Handle rename mode separately (show input field overlay)
        if renaming_tag then
          -- Initialize field with current name
          if Fields.get_text("tag_rename_" .. renaming_tag) == "" then
            Fields.set_text("tag_rename_" .. renaming_tag, state.rename_buffer)
          end

          ImGui.Spacing(ctx)
          ImGui.Text(ctx, "Renaming: " .. renaming_tag)

          local changed, new_name = Fields.draw_at_cursor(ctx, {
            width = -1,
            height = UI.CHIP.HEIGHT_SMALL,
            text = state.rename_buffer,
          }, "tag_rename_" .. renaming_tag)

          if changed then
            state.rename_buffer = new_name
          end

          -- Auto-focus on first frame
          if ImGui.IsWindowAppearing(ctx) then
            ImGui.SetKeyboardFocusHere(ctx, -1)
          end

          -- Commit on Enter or deactivate
          if ImGui.IsItemDeactivatedAfterEdit(ctx) or ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
            if state.rename_buffer ~= "" and state.rename_buffer ~= renaming_tag then
              -- Rename tag
              Tags.rename_tag(state.metadata, renaming_tag, state.rename_buffer)
              local Persistence = require('TemplateBrowser.domain.persistence')
              Persistence.save_metadata(state.metadata)
            end
            state.renaming_item = nil
            state.renaming_type = nil
            state.rename_buffer = ""
          end

          -- Cancel on Escape
          if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
            state.renaming_item = nil
            state.renaming_type = nil
            state.rename_buffer = ""
          end
        end
      end
    else
      ImGui.TextDisabled(ctx, "No tags yet")
    end

    ImGui.EndChild(ctx)
  end
end

return M
