-- @noindex
-- TemplateBrowser/ui/views/convenience_panel/vsts_tab.lua
-- Mini VSTs tab for convenience panel

local ImGui = require 'imgui' '0.10'
local Chip = require('arkitekt.gui.widgets.data.chip')
local Colors = require('arkitekt.core.colors')
local Helpers = require('TemplateBrowser.ui.views.helpers')
local UI = require('TemplateBrowser.ui.ui_constants')

local M = {}

-- Draw mini VSTS content (list of all FX with filtering, no reparse button)
function M.draw(ctx, state, config, width, height)
  -- Get all FX from templates
  local FXParser = require('TemplateBrowser.domain.fx_parser')
  local all_fx = FXParser.get_all_fx(state.templates)

  -- Header with VST count
  ImGui.Text(ctx, string.format("%d VST%s found", #all_fx, #all_fx == 1 and "" or "s"))
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Calculate remaining height for VST list
  local vsts_list_height = height - 36  -- Account for header + separator

  if Helpers.begin_child_compat(ctx, "ConvenienceVSTsList", width - config.PANEL_PADDING * 2, vsts_list_height, false) then
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
