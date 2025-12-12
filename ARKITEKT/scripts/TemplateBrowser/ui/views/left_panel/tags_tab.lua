-- @noindex
-- TemplateBrowser/ui/views/left_panel/tags_tab.lua
-- Tags tab: Full tag management

local ImGui = require('arkitekt.core.imgui')
local Ark = require('arkitekt')
local Tags = require('TemplateBrowser.domain.tags.service')
local Chip = require('arkitekt.gui.widgets.data.chip')
local ChipList = require('arkitekt.gui.widgets.data.chip_list')
local Helpers = require('TemplateBrowser.ui.views.helpers')
local UI = require('TemplateBrowser.ui.config.constants')
local Constants = require('TemplateBrowser.config.constants')

local M = {}

-- Draw TAGS content (full tag management)
function M.Draw(ctx, state, config, width, height)
  -- Header with '+' button (right-aligned)
  ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.header_bg)

  -- Push button to far right using Dummy + SameLine
  local spacer_width = width - UI.BUTTON.WIDTH_SMALL - UI.PADDING.PANEL_INNER * 2
  ImGui.Dummy(ctx, spacer_width, 1)
  ImGui.SameLine(ctx)

  if Ark.Button(ctx, {
    id = 'createtag',
    label = '+',
    width = UI.BUTTON.WIDTH_SMALL,
    height = UI.BUTTON.HEIGHT_DEFAULT
  }).clicked then
    -- Create new tag - prompt for name
    local tag_num = 1
    local new_tag_name = 'Tag ' .. tag_num

    -- Find unique name
    if state.metadata and state.metadata.tags then
      while state.metadata.tags[new_tag_name] do
        tag_num = tag_num + 1
        new_tag_name = 'Tag ' .. tag_num
      end
    end

    -- Create tag with default color (dark grey)
    Tags.create_tag(state.metadata, new_tag_name)

    -- Save metadata
    local Persistence = require('TemplateBrowser.data.storage')
    Persistence.save_metadata(state.metadata)
  end

  ImGui.PopStyleColor(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- List all tags using justified layout
  if Helpers.begin_child_compat(ctx, 'TagsList', width - UI.PADDING.PANEL_INNER * 2, height - 30, false) then
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
        if state.renaming_type == 'tag' then
          renaming_tag = state.renaming_item
        end

        -- Draw tags using justified chip_list (ACTION style)
        -- Unselected tags at 30% opacity (77 = 0.3 * 255)
        local content_w = ImGui.GetContentRegionAvail(ctx)
        local clicked_id, _, right_clicked_id = ChipList.Draw(ctx, tag_items, {
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
            state.renaming_type = 'tag'
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
          if Ark.InputText.GetText('tag_rename_' .. renaming_tag) == '' then
            Ark.InputText.SetText('tag_rename_' .. renaming_tag, state.rename_buffer)
          end

          ImGui.Spacing(ctx)
          ImGui.Text(ctx, 'Renaming: ' .. renaming_tag)

          local result = Ark.InputText(ctx, {
            id = 'tag_rename_' .. renaming_tag,
            width = -1,
            height = UI.CHIP.HEIGHT_SMALL,
            text = state.rename_buffer,
          })

          if result.changed then
            state.rename_buffer = result.value
          end

          -- Auto-focus on first frame
          if ImGui.IsWindowAppearing(ctx) then
            ImGui.SetKeyboardFocusHere(ctx, -1)
          end

          -- Commit on Enter or deactivate
          if ImGui.IsItemDeactivatedAfterEdit(ctx) or ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
            if state.rename_buffer ~= '' and state.rename_buffer ~= renaming_tag then
              -- Rename tag
              Tags.rename_tag(state.metadata, renaming_tag, state.rename_buffer)
              local Persistence = require('TemplateBrowser.data.storage')
              Persistence.save_metadata(state.metadata)
            end
            state.renaming_item = nil
            state.renaming_type = nil
            state.rename_buffer = ''
          end

          -- Cancel on Escape
          if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
            state.renaming_item = nil
            state.renaming_type = nil
            state.rename_buffer = ''
          end
        end
      end
    else
      ImGui.TextDisabled(ctx, 'No tags yet')
    end

    ImGui.EndChild(ctx)
  end
end

return M
