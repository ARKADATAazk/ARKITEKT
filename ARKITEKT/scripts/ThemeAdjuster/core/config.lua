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
        {
          id = "demo_toggle",
          type = "button",
          width = 90,
          spacing_before = 0,
          config = {
            label = "Demo",
            on_click = callbacks.on_demo_toggle,
          },
        },
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
          id = "rebuild_cache",
          type = "button",
          width = 110,
          spacing_before = 0,
          config = {
            label = "Rebuild Cache",
            on_click = callbacks.on_rebuild_cache,
          },
        },
        {
          id = "spacer1",
          type = "separator",
          flex = 1,
          spacing_before = 0,
          config = { show_line = false },
        },
        {
          id = "filter_tcp",
          type = "checkbox",
          width = 50,
          spacing_before = 0,
          config = {
            label = "TCP",
            checked = filters.TCP,
            on_change = callbacks.on_filter_tcp_changed,
          },
        },
        {
          id = "filter_mcp",
          type = "checkbox",
          width = 55,
          spacing_before = 0,
          config = {
            label = "MCP",
            checked = filters.MCP,
            on_change = callbacks.on_filter_mcp_changed,
          },
        },
        {
          id = "filter_transport",
          type = "checkbox",
          width = 85,
          spacing_before = 0,
          config = {
            label = "Transport",
            checked = filters.Transport,
            on_change = callbacks.on_filter_transport_changed,
          },
        },
        {
          id = "filter_global",
          type = "checkbox",
          width = 65,
          spacing_before = 0,
          config = {
            label = "Global",
            checked = filters.Global,
            on_change = callbacks.on_filter_global_changed,
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
