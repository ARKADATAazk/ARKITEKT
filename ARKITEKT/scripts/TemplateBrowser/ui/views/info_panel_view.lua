-- @noindex
-- TemplateBrowser/ui/views/info_panel_view.lua
-- Right panel view: Template info & tag assignment

local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local TemplateOps = require('TemplateBrowser.domain.template_ops')
local Tags = require('TemplateBrowser.domain.tags')
local Button = require('rearkitekt.gui.widgets.primitives.button')
local MarkdownField = require('rearkitekt.gui.widgets.primitives.markdown_field')
local Chip = require('rearkitekt.gui.widgets.data.chip')
local Tooltips = require('TemplateBrowser.core.tooltips')
local UI = require('TemplateBrowser.ui.ui_constants')

local M = {}

-- Draw a u-he style section header (dim text, left-aligned)
local function draw_section_header(ctx, title)
  ImGui.Spacing(ctx)
  ImGui.TextDisabled(ctx, title)
  ImGui.Spacing(ctx)
end

-- Draw info & tag assignment panel (right)
local function draw_info_panel(ctx, gui, width, height)
  local state = gui.state

  -- Set container dimensions
  gui.info_container.width = width
  gui.info_container.height = height

  -- Begin panel drawing (includes background, border, header)
  if gui.info_container:begin_draw(ctx) then
    if state.selected_template then
      local tmpl = state.selected_template
      local tmpl_metadata = state.metadata and state.metadata.templates[tmpl.uuid]

      -- Template name (prominent, at top like u-he)
      ImGui.TextWrapped(ctx, tmpl.name)

      -- Location shown as "in [folder]" style
      ImGui.TextDisabled(ctx, "in " .. tmpl.folder)

      -- ========================================
      -- NOTES section
      -- ========================================
      draw_section_header(ctx, "NOTES")

      local notes = (tmpl_metadata and tmpl_metadata.notes) or ""

      -- Initialize markdown field with current notes
      local notes_field_id = "template_notes_" .. tmpl.uuid
      if MarkdownField.get_text(notes_field_id) ~= notes and not MarkdownField.is_editing(notes_field_id) then
        MarkdownField.set_text(notes_field_id, notes)
      end

      local notes_changed, new_notes = MarkdownField.draw_at_cursor(ctx, {
        width = -1,
        height = UI.FIELD.NOTES_HEIGHT,
        text = notes,
        placeholder = "Double-click to add notes...\n\nSupports Markdown:\n**bold** and *italic*\n# Headers\n- Lists\n[links](url)\n\nShift+Enter for line breaks\nEnter to save, Esc to cancel",
      }, notes_field_id)
      Tooltips.show(ctx, ImGui, "notes_field")

      if notes_changed then
        Tags.set_template_notes(state.metadata, tmpl.uuid, new_notes)
        local Persistence = require('TemplateBrowser.domain.persistence')
        Persistence.save_metadata(state.metadata)
      end

      -- ========================================
      -- TAGS section
      -- ========================================
      draw_section_header(ctx, "TAGS")

      if state.metadata and state.metadata.tags then
        local has_tags = false
        for tag_name, tag_data in pairs(state.metadata.tags) do
          has_tags = true
          ImGui.PushID(ctx, tag_name)

          -- Check if this tag is assigned
          local is_assigned = false
          if tmpl_metadata and tmpl_metadata.tags then
            for _, assigned_tag in ipairs(tmpl_metadata.tags) do
              if assigned_tag == tag_name then
                is_assigned = true
                break
              end
            end
          end

          -- Draw tag using Chip component (ACTION style)
          local clicked, chip_w, chip_h = Chip.draw(ctx, {
            style = Chip.STYLE.ACTION,
            label = tag_name,
            bg_color = tag_data.color,
            text_color = Colors.auto_text_color(tag_data.color),
            height = UI.CHIP.HEIGHT_DEFAULT,
            padding_h = 8,
            rounding = 2,
            is_selected = is_assigned,
            interactive = true,
          })

          if clicked then
            -- Toggle tag assignment
            if is_assigned then
              Tags.remove_tag_from_template(state.metadata, tmpl.uuid, tag_name)
            else
              Tags.add_tag_to_template(state.metadata, tmpl.uuid, tag_name)
            end
            local Persistence = require('TemplateBrowser.domain.persistence')
            Persistence.save_metadata(state.metadata)
          end

          ImGui.PopID(ctx)
        end

        if not has_tags then
          ImGui.TextDisabled(ctx, "No tags available")
          ImGui.TextDisabled(ctx, "Create tags in the Tags panel")
        end
      else
        ImGui.TextDisabled(ctx, "No tags available")
      end

      -- ========================================
      -- ACTIONS section
      -- ========================================
      draw_section_header(ctx, "ACTIONS")

      if Button.draw_at_cursor(ctx, {
        label = "Apply to Selected Track",
        width = -1,
        height = UI.BUTTON.HEIGHT_ACTION
      }, "apply_template") then
        reaper.ShowConsoleMsg("Applying template: " .. tmpl.name .. "\n")
        TemplateOps.apply_to_selected_track(tmpl.path, tmpl.uuid, state)
      end
      Tooltips.show(ctx, ImGui, "template_apply")

      ImGui.Dummy(ctx, 0, UI.PADDING.SMALL)

      if Button.draw_at_cursor(ctx, {
        label = "Insert as New Track",
        width = -1,
        height = UI.BUTTON.HEIGHT_ACTION
      }, "insert_template") then
        reaper.ShowConsoleMsg("Inserting template as new track: " .. tmpl.name .. "\n")
        TemplateOps.insert_as_new_track(tmpl.path, tmpl.uuid, state)
      end
      Tooltips.show(ctx, ImGui, "template_insert")

      ImGui.Dummy(ctx, 0, UI.PADDING.SMALL)

      if Button.draw_at_cursor(ctx, {
        label = "Rename (F2)",
        width = -1,
        height = UI.BUTTON.HEIGHT_ACTION
      }, "rename_template") then
        state.renaming_item = tmpl
        state.renaming_type = "template"
        state.rename_buffer = tmpl.name
      end
      Tooltips.show(ctx, ImGui, "template_rename")

    else
      ImGui.TextDisabled(ctx, "Select a template to view details")
    end

    gui.info_container:end_draw(ctx)
  end
end

-- Export the main draw function
M.draw_info_panel = draw_info_panel

return M
