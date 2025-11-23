-- @noindex
-- ThemeAdjuster/core/config.lua
-- Configuration following RegionPlaylist pattern

local Colors = require('arkitekt.core.colors')
local Constants = require('ThemeAdjuster.defs.constants')
local Defaults = require('ThemeAdjuster.defs.defaults')
local Strings = require('ThemeAdjuster.defs.strings')
local hexrgb = Colors.hexrgb

local M = {}

-- Re-export constants for backward compatibility
M.PACKAGE_GRID = Constants.PACKAGE_GRID
M.TABS = Constants.TABS
M.DEFAULT_FILTERS = Defaults.FILTERS
M.DEMO = Defaults.DEMO

-- Assembler container config
function M.get_assembler_container_config(callbacks, filters)
  filters = filters or M.DEFAULT_FILTERS

  return {
    header = {
      enabled = true,
      height = 32,
      elements = {
        -- Left: Configuration tab_strip
        {
          id = "config_tabs",
          type = "tab_strip",
          width = 300,
          spacing_before = 0,
          config = {
            spacing = 0,
            min_width = 60,
            max_width = 120,
            padding_x = 8,
            chip_radius = 4,
            on_tab_change = callbacks.on_config_select,
            on_tab_delete = callbacks.on_config_delete,
            on_tab_create = callbacks.on_config_add,
            on_tab_rename = callbacks.on_config_rename,
          },
        },
        -- Center: Empty spacer
        {
          id = "spacer1",
          type = "separator",
          flex = 1,
          spacing_before = 0,
          config = { show_line = false },
        },
        -- Right: Search, Filters
        {
          id = "search",
          type = "search_field",
          width = 200,
          spacing_before = 0,
          config = {
            placeholder = "Search packages...",
            on_change = callbacks.on_search_changed,
          },
        },
        {
          id = "filters",
          type = "dropdown_field",
          width = 80,
          spacing_before = 0,
          config = {
            tooltip = "Filter Packages",
            current_value = nil,
            options = {
              { value = nil, label = "Filters" },
              {
                value = "tcp",
                label = "TCP",
                checkbox = true,
                checked = filters.TCP,
              },
              {
                value = "mcp",
                label = "MCP",
                checkbox = true,
                checked = filters.MCP,
              },
              {
                value = "transport",
                label = "Transport",
                checkbox = true,
                checked = filters.Transport,
              },
              {
                value = "global",
                label = "Global",
                checkbox = true,
                checked = filters.Global,
              },
            },
            on_checkbox_change = callbacks.on_filter_changed,
          },
        },
      },
    },
  }
end

return M
