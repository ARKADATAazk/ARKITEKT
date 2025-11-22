-- @noindex
-- ThemeAdjuster/core/config.lua
-- Configuration following RegionPlaylist pattern

local Colors = require('rearkitekt.core.colors')
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
        -- Left: Demo button (small)
        {
          id = "demo_toggle",
          type = "button",
          width = 60,
          spacing_before = 0,
          config = {
            label = "Demo",
            on_click = callbacks.on_demo_toggle,
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
