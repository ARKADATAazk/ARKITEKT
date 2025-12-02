-- @noindex
-- TemplateBrowser/ui/views/left_panel/vsts_tab.lua
-- VSTs tab: List of all FX with filtering

local Logger = require('arkitekt.debug.logger')
local ImGui = require('arkitekt.platform.imgui')
local Ark = require('arkitekt')
local Chip = require('arkitekt.gui.widgets.data.chip')
local Helpers = require('TemplateBrowser.ui.views.helpers')
local UI = require('TemplateBrowser.ui.config.constants')

local M = {}

-- Draw VSTS content (list of all FX with filtering)
function M.Draw(ctx, state, config, width, height)
  -- Get all FX from templates
  local FXParser = require('TemplateBrowser.domain.fx.parser')
  local all_fx = FXParser.get_all_fx(state.templates)

  -- Header with VST count and Force Reparse button
  ImGui.Text(ctx, string.format('%d VST%s found', #all_fx, #all_fx == 1 and '' or 's'))

  ImGui.SameLine(ctx, width - UI.BUTTON.WIDTH_MEDIUM - config.PANEL_PADDING * 2)

  -- Force Reparse button (two-click confirmation)
  local button_label = 'Force Reparse All'
  local button_config = {
    label = button_label,
    width = UI.BUTTON.WIDTH_MEDIUM,
    height = UI.BUTTON.HEIGHT_DEFAULT
  }

  if state.reparse_armed then
    button_label = 'CONFIRM REPARSE?'
    button_config = {
      label = button_label,
      width = UI.BUTTON.WIDTH_MEDIUM,
      height = UI.BUTTON.HEIGHT_DEFAULT,
      bg_color = Ark.Colors.Hexrgb('#CC3333')
    }
  end

  if Ark.Button(ctx, { label = button_label, width = button_config.width, height = button_config.height, bg_color = button_config.bg_color }).clicked then
    if state.reparse_armed then
      -- Second click - execute reparse
      Logger.info('VSTSTAB', 'Force reparsing all templates...')

      -- Clear file_size from all templates in metadata to force re-parse
      if state.metadata and state.metadata.templates then
        for uuid, tmpl in pairs(state.metadata.templates) do
          tmpl.file_size = nil
        end
      end

      -- Save metadata and trigger rescan
      local Persistence = require('TemplateBrowser.data.storage')
      Persistence.save_metadata(state.metadata)

      -- Trigger rescan which will re-parse everything
      local Scanner = require('TemplateBrowser.domain.template.scanner')
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

  if Helpers.begin_child_compat(ctx, 'VSTsList', width - config.PANEL_PADDING * 2, height - 60, false) then
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
        bg_color = is_selected and vst_color or Ark.Colors.WithOpacity(vst_color, 0.8)
      else
        bg_color = is_selected and Ark.Colors.Hexrgb('#4A4A4ACC') or Ark.Colors.Hexrgb('#3A3A3ACC')
      end

      local clicked, chip_w, chip_h = Chip.Draw(ctx, {
        style = Chip.STYLE.ACTION,
        label = fx_name,
        bg_color = bg_color,
        text_color = vst_color and Ark.Colors.AutoTextColor(vst_color) or Ark.Colors.Hexrgb('#FFFFFF'),
        height = 22,
        padding_h = 8,
        rounding = 2,
        is_interactive = true,
      })

      if clicked then
        -- Toggle FX filter
        if is_selected then
          state.filter_fx[fx_name] = nil
        else
          state.filter_fx[fx_name] = true
        end

        -- Re-filter templates
        local Scanner = require('TemplateBrowser.domain.template.scanner')
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
