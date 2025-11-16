-- @noindex
-- ThemeAdjuster/core/config.lua
-- Configuration following RegionPlaylist pattern

local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

-- Assembler container config
function M.get_assembler_container_config(callbacks, filters)
  filters = filters or M.DEFAULT_FILTERS

  return {
    header = {
      enabled = true,
      height = 32,
      elements = {
        -- Left: Demo button
        {
          id = "demo_toggle",
          type = "button",
          align = "left",
          width = 90,
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
        -- Right: Search, Filters, Rebuild Cache
        {
          id = "search",
          type = "search_field",
          align = "right",
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
          align = "right",
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
        {
          id = "rebuild_cache",
          type = "button",
          align = "right",
          width = 110,
          spacing_before = 0,
          config = {
            label = "Rebuild Cache",
            on_click = callbacks.on_rebuild_cache,
          },
        },
      },
    },
  }
end

-- Package grid config
M.PACKAGE_GRID = {
  min_col_width = 220,
  max_tile_height = 200,
  gap = 12,
  base_tile_height = 200,
}

-- Tab definitions
M.TABS = {
  { id = "GLOBAL", label = "Global" },
  { id = "ASSEMBLER", label = "Assembler" },
  { id = "TCP", label = "TCP" },
  { id = "MCP", label = "MCP" },
  { id = "COLORS", label = "Colors" },
  { id = "ENVELOPES", label = "Envelopes" },
  { id = "TRANSPORT", label = "Transport" },
  { id = "DEBUG", label = "Debug" },
}

M.DEFAULT_FILTERS = {
  TCP = true,
  MCP = true,
  Transport = true,
  Global = true,
}

M.DEMO = {
  enabled = true,
  package_count = 8,
}

return M
