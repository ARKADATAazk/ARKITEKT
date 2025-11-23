-- @noindex
-- TemplateBrowser/ui/views/left_panel/vsts_tab.lua
-- VSTs tab: List of all FX with filtering

local ImGui = require 'imgui' '0.10'
local Button = require('arkitekt.gui.widgets.primitives.button')
local Chip = require('arkitekt.gui.widgets.data.chip')
local Colors = require('arkitekt.core.colors')
local Helpers = require('TemplateBrowser.ui.views.helpers')
local UI = require('TemplateBrowser.ui.ui_constants')

local M = {}

-- Draw VSTS content (list of all FX with filtering)
function M.draw(ctx, state, config, width, height)
  -- Get all FX from templates
  local FXParser = require('TemplateBrowser.domain.fx_parser')
  local all_fx = FXParser.get_all_fx(state.templates)

  -- Header with VST count and Force Reparse button
  ImGui.Text(ctx, string.format("%d VST%s found", #all_fx, #all_fx == 1 and "" or "s"))

  ImGui.SameLine(ctx, width - UI.BUTTON.WIDTH_MEDIUM - config.PANEL_PADDING * 2)

  -- Force Reparse button (two-click confirmation)
  local button_label = "Force Reparse All"
  local button_config = {
    label = button_label,
    width = UI.BUTTON.WIDTH_MEDIUM,
    height = UI.BUTTON.HEIGHT_DEFAULT
  }

  if state.reparse_armed then
    button_label = "CONFIRM REPARSE?"
    button_config = {
      label = button_label,
      width = UI.BUTTON.WIDTH_MEDIUM,
      height = UI.BUTTON.HEIGHT_DEFAULT,
      bg_color = Colors.hexrgb("#CC3333")
    }
  end

  if Button.draw_at_cursor(ctx, button_config, "force_reparse") then
    if state.reparse_armed then
      -- Second click - execute reparse
      reaper.ShowConsoleMsg("Force reparsing all templates...\n")

      -- Clear file_size from all templates in metadata to force re-parse
      if state.metadata and state.metadata.templates then
        for uuid, tmpl in pairs(state.metadata.templates) do
          tmpl.file_size = nil
        end
      end

      -- Save metadata and trigger rescan
      local Persistence = require('TemplateBrowser.domain.persistence')
      Persistence.save_metadata(state.metadata)

      -- Trigger rescan which will re-parse everything
      local Scanner = require('TemplateBrowser.domain.scanner')
      Scanner.scan_templates(state)

      state.reparse_armed = false
    else
      -- First click - arm the button
      state.reparse_armed = true
    end
  end

  -- Auto-disarm after hovering away
  if state.reparse_armed and not ImGui.IsItemHovered(ctx) then
    state.reparse_armed = false
  end

  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  if Helpers.begin_child_compat(ctx, "VSTsList", width - config.PANEL_PADDING * 2, height - 60, false) then
    for _, fx_name in ipairs(all_fx) do
      ImGui.PushID(ctx, fx_name)

      local is_selected = state.filter_fx[fx_name] or false

      -- Get stored VST color from metadata
      local vst_color = nil
      if state.metadata and state.metadata.vsts and state.metadata.vsts[fx_name] then
        vst_color = state.metadata.vsts[fx_name].color
      end

      -- Draw VST using Chip component (ACTION style, consistent across Template Browser)
      -- Use stored color or default dark grey with 80% transparency
      local bg_color
      if vst_color then
        bg_color = is_selected and vst_color or Colors.with_alpha(vst_color, 0xCC)
      else
        bg_color = is_selected and Colors.hexrgb("#4A4A4ACC") or Colors.hexrgb("#3A3A3ACC")
      end

      local clicked, chip_w, chip_h = Chip.draw(ctx, {
        style = Chip.STYLE.ACTION,
        label = fx_name,
        bg_color = bg_color,
        text_color = vst_color and Colors.auto_text_color(vst_color) or Colors.hexrgb("#FFFFFF"),
        height = 22,
        padding_h = 8,
        rounding = 2,
        interactive = true,
      })

      if clicked then
        -- Toggle FX filter
        if is_selected then
          state.filter_fx[fx_name] = nil
        else
          state.filter_fx[fx_name] = true
        end

        -- Re-filter templates
        local Scanner = require('TemplateBrowser.domain.scanner')
        Scanner.filter_templates(state)
      end

      -- Handle right-click - open color picker context menu
      if ImGui.IsItemClicked(ctx, 1) then
        state.context_menu_vst = fx_name
      end

      ImGui.PopID(ctx)
    end

    ImGui.EndChild(ctx)
  end
end

return M
