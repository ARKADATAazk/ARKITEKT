-- @noindex
-- TemplateBrowser/ui/views/left_panel/tags_tab.lua
-- Tags tab: Full tag management

local ImGui = require 'imgui' '0.10'
local Tags = require('TemplateBrowser.domain.tags')
local Button = require('rearkitekt.gui.widgets.primitives.button')
local Fields = require('rearkitekt.gui.widgets.primitives.fields')
local Chip = require('rearkitekt.gui.widgets.data.chip')
local Helpers = require('TemplateBrowser.ui.views.helpers')
local UI = require('TemplateBrowser.ui.ui_constants')

local M = {}

-- Draw TAGS content (full tag management)
function M.draw(ctx, state, config, width, height)
  -- Header with "+" button
  local header_text = "Tags"

  ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.header_bg)
  ImGui.Text(ctx, header_text)
  ImGui.SameLine(ctx, width - UI.BUTTON.WIDTH_SMALL - config.PANEL_PADDING * 2)

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

    -- Create tag with random color
    local r = math.random(50, 255) / 255.0
    local g = math.random(50, 255) / 255.0
    local b = math.random(50, 255) / 255.0
    local color = (math.floor(r * 255) << 16) | (math.floor(g * 255) << 8) | math.floor(b * 255)

    Tags.create_tag(state.metadata, new_tag_name, color)

    -- Save metadata
    local Persistence = require('TemplateBrowser.domain.persistence')
    Persistence.save_metadata(state.metadata)
  end

  ImGui.PopStyleColor(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- List all tags
  if Helpers.begin_child_compat(ctx, "TagsList", width - config.PANEL_PADDING * 2, height - 30, false) then
    if state.metadata and state.metadata.tags then
      for tag_name, tag_data in pairs(state.metadata.tags) do
        local is_renaming = (state.renaming_item == tag_name and state.renaming_type == "tag")

        ImGui.PushID(ctx, tag_name)

        if is_renaming then
          -- Rename mode
          -- Initialize field with current name
          if Fields.get_text("tag_rename_" .. tag_name) == "" then
            Fields.set_text("tag_rename_" .. tag_name, state.rename_buffer)
          end

          local changed, new_name = Fields.draw_at_cursor(ctx, {
            width = -1,
            height = UI.CHIP.HEIGHT_SMALL,
            text = state.rename_buffer,
          }, "tag_rename_" .. tag_name)

          if changed then
            state.rename_buffer = new_name
          end

          -- Commit on Enter or deactivate
          if ImGui.IsItemDeactivatedAfterEdit(ctx) or ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
            if state.rename_buffer ~= "" and state.rename_buffer ~= tag_name then
              -- Rename tag
              Tags.rename_tag(state.metadata, tag_name, state.rename_buffer)
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
        else
          -- Normal display - draw tag using Chip component (ACTION style)
          local clicked, chip_w, chip_h = Chip.draw(ctx, {
            style = Chip.STYLE.ACTION,
            label = tag_name,
            bg_color = tag_data.color,
            text_color = Colors.auto_text_color(tag_data.color),
            height = UI.CHIP.HEIGHT_DEFAULT,
            padding_h = 8,
            rounding = 2,
            is_selected = false,
            interactive = true,
          })

          -- Double-click to rename
          if ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
            state.renaming_item = tag_name
            state.renaming_type = "tag"
            state.rename_buffer = tag_name
          end
        end

        ImGui.PopID(ctx)
      end
    else
      ImGui.TextDisabled(ctx, "No tags yet")
    end

    ImGui.EndChild(ctx)
  end
end

return M
