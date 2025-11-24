-- @noindex
-- ThemeAdjuster/ui/main_panel.lua
-- Top-level panel with tab_strip (alternative to Shell menutabs)

local TilesContainer = require('arkitekt.gui.widgets.containers.panel')
local Config = require('ThemeAdjuster.core.config')

local M = {}

function M.create_main_panel(State, callbacks)
  -- Create tab config
  local tab_items = {}
  for _, tab_def in ipairs(Config.TABS) do
    table.insert(tab_items, {
      id = tab_def.id,
      label = tab_def.label,
    })
  end

  local tab_config = {
    spacing = 0,
    min_width = 60,
    max_width = 150,
    padding_x = 8,
    chip_radius = 4,
    on_change = callbacks.on_tab_change,
    on_tab_reorder = nil,  -- No reordering for main tabs
  }

  -- Create panel config with tab_strip
  local panel_config = {
    header = {
      enabled = true,
      height = 24,
      elements = {
        {
          id = "tabs",
          type = "tab_strip",
          flex = 1,
          spacing_before = 0,
          config = tab_config,
        },
      },
    },
  }

  local panel = TilesContainer.new({
    id = "main_panel",
    config = panel_config,
  })

  -- Set tabs
  panel:set_tabs(tab_items, State.get_active_tab())

  return panel
end

return M
