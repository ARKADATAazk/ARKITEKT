-- @noindex
-- TemplateBrowser/ui/views/info_panel_view.lua
-- Right panel view: Template info & tag assignment

local ImGui = require 'imgui' '0.10'
local TemplateOps = require('TemplateBrowser.domain.template_ops')
local Tags = require('TemplateBrowser.domain.tags')
local Button = require('rearkitekt.gui.widgets.primitives.button')
local MarkdownField = require('rearkitekt.gui.widgets.primitives.markdown_field')
local Chip = require('rearkitekt.gui.widgets.data.chip')
local Tooltips = require('TemplateBrowser.core.tooltips')

local M = {}

-- ImGui compatibility for BeginChild
local function BeginChildCompat(ctx, id, w, h, want_border, window_flags)
  local child_flags = want_border and 1 or 0
  return ImGui.BeginChild(ctx, id, w, h, child_flags, window_flags or 0)
end

-- Draw info & tag assignment panel (right)
local function draw_info_panel(ctx, state, config, width, height)
  -- Outer border container (non-scrollable)
  if not BeginChildCompat(ctx, "InfoPanel", width, height, true) then
    return
  end

  -- Header (stays at top)
  ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.COLORS.header_bg)
  ImGui.SeparatorText(ctx, "Info & Tags")
  ImGui.PopStyleColor(ctx)

  ImGui.Spacing(ctx)

  -- Scrollable content region
  local header_height = 30  -- SeparatorText + spacing
  local content_height = height - header_height

  if BeginChildCompat(ctx, "InfoPanelContent", 0, content_height, false) then
    if state.selected_template then
    local tmpl = state.selected_template
    local tmpl_metadata = state.metadata and state.metadata.templates[tmpl.uuid]

    -- Template info
    ImGui.Text(ctx, "Name:")
    ImGui.Indent(ctx, 10)
    ImGui.TextWrapped(ctx, tmpl.name)
    ImGui.Unindent(ctx, 10)

    ImGui.Spacing(ctx)
    ImGui.Text(ctx, "Location:")
    ImGui.Indent(ctx, 10)
    ImGui.TextWrapped(ctx, tmpl.folder)
    ImGui.Unindent(ctx, 10)

    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    -- Actions
    if Button.draw_at_cursor(ctx, { label = "Apply to Selected Track", width = -1, height = 28 }, "apply_template") then
      reaper.ShowConsoleMsg("Applying template: " .. tmpl.name .. "\n")
      TemplateOps.apply_to_selected_track(tmpl.path, tmpl.uuid, state)
    end
    Tooltips.show(ctx, ImGui, "template_apply")

    ImGui.Dummy(ctx, 0, 4)

    if Button.draw_at_cursor(ctx, { label = "Insert as New Track", width = -1, height = 28 }, "insert_template") then
      reaper.ShowConsoleMsg("Inserting template as new track: " .. tmpl.name .. "\n")
      TemplateOps.insert_as_new_track(tmpl.path, tmpl.uuid, state)
    end
    Tooltips.show(ctx, ImGui, "template_insert")

    ImGui.Dummy(ctx, 0, 4)

    if Button.draw_at_cursor(ctx, { label = "Rename (F2)", width = -1, height = 28 }, "rename_template") then
      state.renaming_item = tmpl
      state.renaming_type = "template"
      state.rename_buffer = tmpl.name
    end
    Tooltips.show(ctx, ImGui, "template_rename")

    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    -- Notes (Markdown field with view/edit modes)
    ImGui.Text(ctx, "Notes:")
    Tooltips.show(ctx, ImGui, "notes_field")
    ImGui.Spacing(ctx)

    local notes = (tmpl_metadata and tmpl_metadata.notes) or ""

    -- Initialize markdown field with current notes
    local notes_field_id = "template_notes_" .. tmpl.uuid
    if MarkdownField.get_text(notes_field_id) ~= notes and not MarkdownField.is_editing(notes_field_id) then
      MarkdownField.set_text(notes_field_id, notes)
    end

    local notes_changed, new_notes = MarkdownField.draw_at_cursor(ctx, {
      width = -1,
      height = 200,  -- Taller for better markdown viewing
      text = notes,
      placeholder = "Double-click to add notes...\n\nSupports Markdown:\n• **bold** and *italic*\n• # Headers\n• - Lists\n• [links](url)\n\nShift+Enter for line breaks\nEnter to save, Esc to cancel",
    }, notes_field_id)

    if notes_changed then
      Tags.set_template_notes(state.metadata, tmpl.uuid, new_notes)
      local Persistence = require('TemplateBrowser.domain.persistence')
      Persistence.save_metadata(state.metadata)
    end

    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    -- Tag Assignment
    ImGui.Text(ctx, "Tags:")
    ImGui.Spacing(ctx)

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

        -- Draw tag using Chip component (PILL style)
        local clicked, chip_w, chip_h = Chip.draw(ctx, {
          style = Chip.STYLE.PILL,
          label = tag_name,
          color = tag_data.color,
          height = 24,
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

    else
      ImGui.TextDisabled(ctx, "Select a template to view details")
    end

    ImGui.EndChild(ctx)  -- End InfoPanelContent
  end

  ImGui.EndChild(ctx)  -- End InfoPanel
end

-- Export the main draw function
M.draw_info_panel = draw_info_panel

return M
