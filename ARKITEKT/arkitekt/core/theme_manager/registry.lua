-- @noindex
-- arkitekt/core/theme_manager/registry.lua
-- Script color and rule registration
--
-- Allows scripts to register their own theme-reactive colors and rules
-- for integration with the theme system.

local Engine = require('arkitekt.core.theme_manager.engine')

local M = {}

-- =============================================================================
-- SCRIPT COLOR REGISTRATION
-- =============================================================================
-- Scripts can register their color modules for display in the debug overlay.

--- Registered script color modules
--- @type table<string, table<string, any>>
M.script_colors = {}

--- Register a script's color table
--- @param script_name string Name of the script (e.g., "RegionPlaylist")
--- @param colors table Color table with key-value pairs
function M.register_colors(script_name, colors)
  if type(script_name) ~= "string" or type(colors) ~= "table" then
    return
  end
  M.script_colors[script_name] = colors
end

--- Unregister a script's colors
--- @param script_name string Name of the script to unregister
function M.unregister_colors(script_name)
  M.script_colors[script_name] = nil
end

--- Get all registered script colors
--- @return table<string, table<string, any>>
function M.get_all_colors()
  return M.script_colors
end

-- =============================================================================
-- SCRIPT RULES REGISTRATION
-- =============================================================================
-- Scripts can register their own theme-reactive rules using the same wrappers.

--- Registered script rule definitions
--- @type table<string, table<string, table>>
M.script_rules = {}

--- Cache for computed script rules
local rules_cache = {}

--- Clear the script rules cache (called when theme changes)
function M.clear_cache()
  rules_cache = {}
end

--- Register a script's theme-reactive rules
--- @param script_name string Name of the script
--- @param rules table Rules table using wrappers
function M.register_rules(script_name, rules)
  if type(script_name) ~= "string" or type(rules) ~= "table" then
    return
  end
  M.script_rules[script_name] = rules
  rules_cache[script_name] = nil  -- Invalidate cache
end

--- Unregister a script's rules
--- @param script_name string Name of the script to unregister
function M.unregister_rules(script_name)
  M.script_rules[script_name] = nil
  rules_cache[script_name] = nil
end

--- Get computed rules for a script (computed for current theme)
--- @param script_name string Name of the script
--- @param current_t number Current interpolation factor
--- @return table|nil Computed rules table, or nil if not registered
function M.get_computed_rules(script_name, current_t)
  local rule_defs = M.script_rules[script_name]
  if not rule_defs then
    return nil
  end

  -- Check cache
  local cached = rules_cache[script_name]
  if cached and cached._t == current_t then
    return cached
  end

  -- Compute rules for current theme
  local computed = { _t = current_t }
  for key, rule in pairs(rule_defs) do
    computed[key] = Engine.compute_rule_value(rule, current_t)
  end

  rules_cache[script_name] = computed
  return computed
end

--- Get all registered script rules (definitions, not computed)
--- @return table<string, table<string, table>>
function M.get_all_rules()
  return M.script_rules
end

return M
