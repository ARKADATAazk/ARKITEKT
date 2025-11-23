-- @noindex
-- ThemeAdjuster/defs/defaults.lua
-- Default configuration values

local M = {}

-- ============================================================================
-- DEFAULT FILTERS
-- ============================================================================
M.FILTERS = {
  TCP = true,
  MCP = true,
  Transport = true,
  Global = true,
}

-- ============================================================================
-- DEMO MODE
-- ============================================================================
M.DEMO = {
  enabled = true,
  package_count = 8,
}

-- ============================================================================
-- FILTER OPTIONS
-- ============================================================================
M.FILTER_OPTIONS = {
  { value = "tcp", label = "TCP", key = "TCP" },
  { value = "mcp", label = "MCP", key = "MCP" },
  { value = "transport", label = "Transport", key = "Transport" },
  { value = "global", label = "Global", key = "Global" },
}

return M
