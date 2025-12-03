-- @noindex
-- TemplateBrowser/ui/views/info_panel_view.lua
-- Right panel view: Template info & tag assignment

local ImGui = require('arkitekt.core.imgui')
local Ark = require('arkitekt')
local TemplateOps = require('TemplateBrowser.domain.template.operations')
local Tags = require('TemplateBrowser.domain.tags.service')
local Stats = require('TemplateBrowser.domain.template.stats')
local Chip = require('arkitekt.gui.widgets.data.chip')
local ChipList = require('arkitekt.gui.widgets.data.chip_list')
local Tooltips = require('TemplateBrowser.ui.tooltips')
local UI = require('TemplateBrowser.ui.config.constants')

local M = {}
local hexrgb = Ark.Colors.Hexrgb

-- Draw a u-he style section header (dim text, left-aligned)
local function draw_section_header(ctx, title)
  ImGui.Dummy(ctx, 0, 10)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb('#666666'))
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
    -- Get available content width (padding is handled by WindowPadding style)
    local content_w = ImGui.GetContentRegionAvail(ctx)

    if state.selected_template then
      local tmpl = state.selected_template
      local tmpl_metadata = state.metadata and state.metadata.templates[tmpl.uuid]

      -- ========================================
      -- TEMPLATE INFO (top section)
      -- ========================================

      -- Template name (prominent)
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb('#FFFFFF'))
      ImGui.TextWrapped(ctx, tmpl.name)
      ImGui.PopStyleColor(ctx)

      -- Location shown as 'in [folder]' style
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb('#888888'))
      ImGui.Text(ctx, 'in ' .. tmpl.folder)
      ImGui.PopStyleColor(ctx)

      -- ========================================
      -- USAGE STATS section
      -- ========================================
      local usage_history = tmpl_metadata and tmpl_metadata.usage_history
      local usage_count = tmpl_metadata and tmpl_metadata.usage_count or 0

      if usage_count > 0 then
        draw_section_header(ctx, 'USAGE')

        -- Calculate stats
        local stats = Stats.calculate_stats(usage_history)
        local sparkline = Stats.get_daily_sparkline(usage_history, 14)

        -- Draw mini sparkline (14 days of bars)
        local dl = ImGui.GetWindowDrawList(ctx)
        local spark_x, spark_y = ImGui.GetCursorScreenPos(ctx)
        local spark_w = content_w
        local spark_h = 20
        local bar_w = (spark_w - 13) / 14  -- 14 bars with 1px gaps
        local max_val = math.max(1, math.max(table.unpack(sparkline)))

        -- Draw sparkline bars
        for i, count in ipairs(sparkline) do
          local bar_h = (count / max_val) * (spark_h - 2)
          local bar_x = spark_x + (i - 1) * (bar_w + 1)
          local bar_y = spark_y + spark_h - bar_h - 1

          -- Bar color: brighter for higher values
          local intensity = count > 0 and (0.3 + 0.7 * (count / max_val)) or 0.1
          local bar_color = Ark.Colors.WithAlpha(hexrgb('#5588FF'), math.floor(255 * intensity))

          if bar_h > 0 then
            ImGui.DrawList_AddRectFilled(dl, bar_x, bar_y, bar_x + bar_w, spark_y + spark_h - 1, bar_color, 1)
          else
            -- Draw a tiny dot for zero days
            ImGui.DrawList_AddRectFilled(dl, bar_x, spark_y + spark_h - 2, bar_x + bar_w, spark_y + spark_h - 1, hexrgb('#333333'), 0)
          end
        end

        ImGui.Dummy(ctx, spark_w, spark_h + 4)

        -- Stats text
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb('#888888'))

        -- Total and trend
        local trend_icon = Stats.format_trend(stats.trend)
        local trend_text = string.format('%d total', stats.total)
        if trend_icon ~= '' then
          trend_text = trend_text .. '  ' .. trend_icon
        end
        ImGui.Text(ctx, trend_text)

        -- Recent activity
        if stats.last_7_days > 0 then
          ImGui.SameLine(ctx)
          ImGui.Text(ctx, string.format('  %d this week', stats.last_7_days))
        end

        -- Streak
        if stats.streak_days > 1 then
          ImGui.Text(ctx, string.format('🔥 %d day streak', stats.streak_days))
        end

        ImGui.PopStyleColor(ctx)
      end

      -- ========================================
      -- VST/FX LIST section
      -- ========================================
      if tmpl.fx and #tmpl.fx > 0 then
        draw_section_header(ctx, 'FX CHAIN')

        for i, fx_name in ipairs(tmpl.fx) do
          -- Dark grey with 80% transparency
          Chip.Draw(ctx, {
            style = Chip.STYLE.ACTION,
            label = fx_name,
            bg_color = hexrgb('#3A3A3ACC'),
            text_color = hexrgb('#FFFFFF'),
            height = 22,
            padding_h = 8,
            rounding = 2,
            is_interactive = false,
          })
          ImGui.Dummy(ctx, 0, 2)  -- Small spacing between chips
        end
      end

      -- ========================================
      -- NOTES section
      -- ========================================
      draw_section_header(ctx, 'NOTES')

      local notes = (tmpl_metadata and tmpl_metadata.notes) or ''

      -- Initialize markdown field with current notes
      local notes_field_id = 'template_notes_' .. tmpl.uuid
      if Ark.MarkdownField.GetText(notes_field_id) ~= notes and not Ark.MarkdownField.is_editing(notes_field_id) then
        Ark.MarkdownField.SetText(notes_field_id, notes)
      end

      local result = Ark.MarkdownField(ctx, {
        id = notes_field_id,
        width = content_w,
        height = 100,
        text = notes,
        placeholder = 'Double-click to add notes...\n\nMarkdown supported',
      })
      Tooltips.show(ctx, ImGui, 'notes_field')

      if result.changed then
        Tags.set_template_notes(state.metadata, tmpl.uuid, result.value)
        local Persistence = require('TemplateBrowser.data.storage')
        Persistence.save_metadata(state.metadata)
      end

      -- ========================================
      -- TAGS section
      -- ========================================
      draw_section_header(ctx, 'TAGS')

      if state.metadata and state.metadata.tags then
        -- Build items array for chip_list
        local tag_items = {}
        local selected_ids = {}

        for tag_name, tag_data in pairs(state.metadata.tags) do
          tag_items[#tag_items + 1] = {
            id = tag_name,
            label = tag_name,
            color = tag_data.color,
          }

          -- Check if this tag is assigned to the template
          if tmpl_metadata and tmpl_metadata.tags then
            for _, assigned_tag in ipairs(tmpl_metadata.tags) do
              if assigned_tag == tag_name then
                selected_ids[tag_name] = true
                break
              end
            end
          end
        end

        if #tag_items > 0 then
          -- Sort tags alphabetically for consistent display
          table.sort(tag_items, function(a, b) return a.label < b.label end)

          -- Draw tags using justified chip_list (ACTION style)
          -- Unselected tags at 30% opacity (77 = 0.3 * 255)
          local clicked_id = ChipList.Draw(ctx, tag_items, {
            justified = true,
            max_stretch_ratio = 1.5,
            selected_ids = selected_ids,
            style = Chip.STYLE.ACTION,
            chip_height = 22,
            chip_spacing = 6,
            line_spacing = 3,
            rounding = 3,
            padding_h = 6,
            max_width = content_w,
            unselected_alpha = 77,
          })

          if clicked_id then
            -- Toggle tag assignment
            if selected_ids[clicked_id] then
              Tags.remove_tag_from_template(state.metadata, tmpl.uuid, clicked_id)
            else
              Tags.add_tag_to_template(state.metadata, tmpl.uuid, clicked_id)
            end
            local Persistence = require('TemplateBrowser.data.storage')
            Persistence.save_metadata(state.metadata)
          end
        else
          ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb('#555555'))
          ImGui.Text(ctx, 'No tags available')
          ImGui.Text(ctx, 'Create in Tags panel')
          ImGui.PopStyleColor(ctx)
        end
      else
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb('#555555'))
        ImGui.Text(ctx, 'No tags available')
        ImGui.PopStyleColor(ctx)
      end

      -- ========================================
      -- ACTIONS section (at bottom)
      -- ========================================
      draw_section_header(ctx, 'ACTIONS')

      -- Apply to Selected Track (primary action)
      if Ark.Button(ctx, {
        id = 'apply_template',
        label = 'Apply to Track',
        width = content_w,
        height = 28,
        bg_color = hexrgb('#2A5599'),
        bg_hover_color = hexrgb('#3A65A9'),
        bg_active_color = hexrgb('#1A4589'),
      }).clicked then
        TemplateOps.apply_to_selected_track(tmpl.path, tmpl.uuid, state)
      end
      Tooltips.show(ctx, ImGui, 'template_apply')

      ImGui.Dummy(ctx, 0, 4)

      -- Insert as New Track
      if Ark.Button(ctx, {
        id = 'insert_template',
        label = 'Insert as New Track',
        width = content_w,
        height = 24,
      }).clicked then
        TemplateOps.insert_as_new_track(tmpl.path, tmpl.uuid, state)
      end
      Tooltips.show(ctx, ImGui, 'template_insert')

      ImGui.Dummy(ctx, 0, 4)

      -- Rename
      if Ark.Button(ctx, {
        id = 'rename_template',
        label = 'Rename (F2)',
        width = content_w,
        height = 24,
      }).clicked then
        state.renaming_item = tmpl
        state.renaming_type = 'template'
        state.rename_buffer = tmpl.name
      end
      Tooltips.show(ctx, ImGui, 'template_rename')

    else
      -- No template selected
      ImGui.Dummy(ctx, 0, 40)
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb('#555555'))
      local text = 'Select a template'
      local text_w = ImGui.CalcTextSize(ctx, text)
      ImGui.SetCursorPosX(ctx, (content_w - text_w) / 2)
      ImGui.Text(ctx, text)

      local text2 = 'to view details'
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
