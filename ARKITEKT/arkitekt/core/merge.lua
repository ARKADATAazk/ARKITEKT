-- @noindex
-- arkitekt/core/merge.lua
-- Table merging utilities for configuration management
--
-- Usage:
--   local Merge = require('arkitekt.core.merge')
--   local config = Merge.deepMerge(DEFAULTS, user_opts)

local M = {}

-- ============================================================================
-- DEEP MERGE
-- ============================================================================

--- Deep merge two tables recursively (right wins)
--- Use for nested configs (multiple levels)
--- @param base table Base configuration
--- @param override table Override configuration
--- @return table New table with deeply merged values
function M.deepMerge(base, override)
  -- Handle non-table cases
  if type(base) ~= 'table' then return override end
  if type(override) ~= 'table' then return base end

  local result = {}

  -- Copy base
  for k, v in pairs(base) do
    result[k] = v
  end

  -- Recursively merge override
  for k, v in pairs(override) do
    if type(v) == 'table' and type(result[k]) == 'table' then
      result[k] = M.deepMerge(result[k], v)
    else
      result[k] = v
    end
  end

  return result
end

-- ============================================================================
-- APPLY DEFAULTS
-- ============================================================================

--- Apply defaults to user config (user values win)
--- Supports selective deep merging for specific nested keys
--- @param defaults table Default configuration values
--- @param user_config table User-provided configuration
--- @param deep_keys table|nil Optional set of keys to deep merge {key=true, ...}
--- @return table New table with defaults applied
function M.apply_defaults(defaults, user_config, deep_keys)
  user_config = user_config or {}
  deep_keys = deep_keys or {}

  local result = {}

  -- Apply defaults
  for k, v in pairs(defaults) do
    if deep_keys[k] and type(v) == 'table' and type(user_config[k]) == 'table' then
      -- Deep merge for specified keys (e.g., nested popup config)
      result[k] = M.deepMerge(v, user_config[k])
    else
      -- Shallow: user value wins, fall back to default
      -- Use inverted ternary to handle false values correctly
      result[k] = user_config[k] == nil and v or user_config[k]
    end
  end

  -- Add extra user-provided keys not in defaults
  for k, v in pairs(user_config) do
    if result[k] == nil then
      result[k] = v
    end
  end

  return result
end

-- ============================================================================
-- SAFE MERGE (No Overwrite)
-- ============================================================================

--- Merge supplement into base, but ONLY for keys not already in base
--- Use for context defaults that shouldn't override presets
--- @param base table Base configuration (already has preset applied)
--- @param supplement table Supplemental defaults (e.g., panel context colors)
--- @return table New table with non-conflicting values merged
function M.merge_safe(base, supplement)
  local result = {}

  -- Deep copy helper (2 levels deep to handle options arrays)
  local function deep_copy_value(v)
    if type(v) ~= 'table' then
      return v  -- Primitives and functions copied by reference
    end

    local copy = {}
    for k2, v2 in pairs(v) do
      if type(v2) == 'table' then
        -- Copy nested tables (e.g., options = {{value=x, label=y}, ...})
        local nested = {}
        for k3, v3 in pairs(v2) do
          nested[k3] = v3
        end
        copy[k2] = nested
      else
        copy[k2] = v2
      end
    end
    return copy
  end

  -- Copy base completely (deep copy to prevent reference pollution)
  for k, v in pairs(base or {}) do
    result[k] = deep_copy_value(v)
  end

  -- Add supplement ONLY if key doesn't exist in base
  for k, v in pairs(supplement or {}) do
    if result[k] == nil then
      result[k] = deep_copy_value(v)
    end
  end

  return result
end

return M
