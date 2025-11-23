-- @noindex
-- TemplateBrowser/ui/views/convenience_panel/vsts_tab.lua
-- Mini VSTs tab for convenience panel

local ImGui = require 'imgui' '0.10'
local Chip = require('rearkitekt.gui.widgets.data.chip')
local Colors = require('rearkitekt.core.colors')
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

      -- Draw VST using Chip component (ACTION style, consistent across Template Browser)
      local bg_color = is_selected and Colors.hexrgb("#5A7A9D") or Colors.hexrgb("#3D5A80")
      local clicked, chip_w, chip_h = Chip.draw(ctx, {
        style = Chip.STYLE.ACTION,
        label = fx_name,
        bg_color = bg_color,
        text_color = Colors.hexrgb("#FFFFFF"),
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

      ImGui.PopID(ctx)
    end

    ImGui.EndChild(ctx)
  end
end

return M
