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
local hexrgb = Colors.hexrgb

-- Draw a u-he style section header (dim text, left-aligned)
local function draw_section_header(ctx, title)
  ImGui.Dummy(ctx, 0, 10)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#666666"))
  ImGui.Text(ctx, title)
  ImGui.PopStyleColor(ctx)
  ImGui.Dummy(ctx, 0, 4)
end

-- Draw info & tag assignment panel (right)
local function draw_info_panel(ctx, gui, width, height)
  local state = gui.state

  -- Set container dimensions
  gui.info_container.width = width
  gui.info_container.height = height

  -- Begin panel drawing (includes background, border, header)
  if gui.info_container:begin_draw(ctx) then
    -- Get available content width
    local content_w = ImGui.GetContentRegionAvail(ctx)

    if state.selected_template then
      local tmpl = state.selected_template
      local tmpl_metadata = state.metadata and state.metadata.templates[tmpl.uuid]

      -- ========================================
      -- TEMPLATE INFO (top section)
      -- ========================================

      -- Template name (prominent)
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#FFFFFF"))
      ImGui.TextWrapped(ctx, tmpl.name)
      ImGui.PopStyleColor(ctx)

      -- Location shown as "in [folder]" style
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#888888"))
      ImGui.Text(ctx, "in " .. tmpl.folder)
      ImGui.PopStyleColor(ctx)

      -- ========================================
      -- VST/FX LIST section
      -- ========================================
      if tmpl.fx and #tmpl.fx > 0 then
        draw_section_header(ctx, "FX CHAIN")

        for i, fx_name in ipairs(tmpl.fx) do
          Chip.draw(ctx, {
            style = Chip.STYLE.ACTION,
            label = fx_name,
            bg_color = hexrgb("#35504C"),
            text_color = hexrgb("#FFFFFF"),
            border_color = hexrgb("#181818"),
            height = 22,
            padding_h = 8,
            rounding = 2,
            interactive = false,
          })
          ImGui.Dummy(ctx, 0, 2)  -- Small spacing between chips
        end
      end

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
        width = content_w,
        height = 100,
        text = notes,
        placeholder = "Double-click to add notes...\n\nMarkdown supported",
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
        local tag_count = 0

        -- Count tags first
        for _ in pairs(state.metadata.tags) do
          tag_count = tag_count + 1
        end

        if tag_count > 0 then
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
              height = 22,
              padding_h = 6,
              rounding = 3,
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
        end

        if not has_tags or tag_count == 0 then
          ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#555555"))
          ImGui.Text(ctx, "No tags available")
          ImGui.Text(ctx, "Create in Tags panel")
          ImGui.PopStyleColor(ctx)
        end
      else
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#555555"))
        ImGui.Text(ctx, "No tags available")
        ImGui.PopStyleColor(ctx)
      end

      -- ========================================
      -- ACTIONS section (at bottom)
      -- ========================================
      draw_section_header(ctx, "ACTIONS")

      -- Apply to Selected Track (primary action)
      if Button.draw_at_cursor(ctx, {
        label = "Apply to Track",
        width = content_w,
        height = 28,
        bg_color = hexrgb("#2A5599"),
        bg_hover_color = hexrgb("#3A65A9"),
        bg_active_color = hexrgb("#1A4589"),
      }, "apply_template") then
        TemplateOps.apply_to_selected_track(tmpl.path, tmpl.uuid, state)
      end
      Tooltips.show(ctx, ImGui, "template_apply")

      ImGui.Dummy(ctx, 0, 4)

      -- Insert as New Track
      if Button.draw_at_cursor(ctx, {
        label = "Insert as New Track",
        width = content_w,
        height = 24,
      }, "insert_template") then
        TemplateOps.insert_as_new_track(tmpl.path, tmpl.uuid, state)
      end
      Tooltips.show(ctx, ImGui, "template_insert")

      ImGui.Dummy(ctx, 0, 4)

      -- Rename
      if Button.draw_at_cursor(ctx, {
        label = "Rename (F2)",
        width = content_w,
        height = 24,
      }, "rename_template") then
        state.renaming_item = tmpl
        state.renaming_type = "template"
        state.rename_buffer = tmpl.name
      end
      Tooltips.show(ctx, ImGui, "template_rename")

    else
      -- No template selected
      ImGui.Dummy(ctx, 0, 40)
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#555555"))
      local text = "Select a template"
      local text_w = ImGui.CalcTextSize(ctx, text)
      ImGui.SetCursorPosX(ctx, (content_w - text_w) / 2)
      ImGui.Text(ctx, text)

      local text2 = "to view details"
      local text2_w = ImGui.CalcTextSize(ctx, text2)
      ImGui.SetCursorPosX(ctx, (content_w - text2_w) / 2)
      ImGui.Text(ctx, text2)
      ImGui.PopStyleColor(ctx)
    end

    gui.info_container:end_draw(ctx)
  end
end

-- Export the main draw function
M.draw_info_panel = draw_info_panel

return M
