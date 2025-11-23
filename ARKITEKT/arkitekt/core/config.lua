-- @noindex
-- Arkitekt/core/config.lua
-- Unified configuration management utilities
--
-- Provides standardized merge, defaults, and preset application
-- to prevent config precedence bugs across the codebase.
--
-- Usage:
--   local Config = require('arkitekt.core.config')
--   local final = Config.apply_defaults(DEFAULTS, user_config)

local M = {}

-- ============================================================================
-- SHALLOW MERGE
-- ============================================================================

--- Shallow merge two tables (right wins)
--- Use for flat configs (single level)
--- @param base table Base configuration
--- @param override table Override configuration
--- @return table New table with merged values
function M.merge(base, override)
  local result = {}

  -- Copy base
  for k, v in pairs(base or {}) do
    result[k] = v
  end

  -- Override with user values
  for k, v in pairs(override or {}) do
    result[k] = v
  end

  return result
end

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
  if type(base) ~= "table" then return override end
  if type(override) ~= "table" then return base end

  local result = {}

  -- Copy base
  for k, v in pairs(base) do
    result[k] = v
  end

  -- Recursively merge override
  for k, v in pairs(override) do
    if type(v) == "table" and type(result[k]) == "table" then
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
    if deep_keys[k] and type(v) == "table" and type(user_config[k]) == "table" then
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

--- Merge override into base, but ONLY for keys not already in base
--- Use for context defaults that shouldn't override presets
--- @param base table Base configuration (already has preset applied)
--- @param supplement table Supplemental defaults (e.g., panel context colors)
--- @return table New table with non-conflicting values merged
function M.merge_safe(base, supplement)
  local result = {}

  -- Copy base completely
  for k, v in pairs(base or {}) do
    result[k] = v
  end

  -- Add supplement ONLY if key doesn't exist in base
  for k, v in pairs(supplement or {}) do
    if result[k] == nil then
      result[k] = v
    end
  end

  return result
end

-- ============================================================================
-- PRESET APPLICATION
-- ============================================================================

--- Apply preset by name with proper precedence
--- Precedence order: BASE → PRESET → CONTEXT → USER
--- @param base table Base default configuration
--- @param user_config table User configuration (may include preset_name)
--- @param presets table Table of available presets {name = config, ...}
--- @param context_defaults table|nil Optional context-specific defaults
--- @return table Final merged configuration
function M.apply_preset(base, user_config, presets, context_defaults)
  user_config = user_config or {}
  local config = base

  -- 1. Apply preset if specified (by name or direct table)
  if user_config.preset_name and presets[user_config.preset_name] then
    config = M.merge(config, presets[user_config.preset_name])
  elseif user_config.preset and type(user_config.preset) == "table" then
    config = M.merge(config, user_config.preset)
  end

  -- 2. Apply context defaults (only non-conflicting keys)
  if context_defaults then
    config = M.merge_safe(config, context_defaults)
  end

  -- 3. User config always wins
  config = M.merge(config, user_config)

  return config
end

-- ============================================================================
-- VALIDATION (Optional)
-- ============================================================================

--- Validate config against a schema
--- @param config table Configuration to validate
--- @param schema table Schema definition {key = type_string, ...}
--- @return boolean, string|nil Success, error message
function M.validate(config, schema)
  for key, expected_type in pairs(schema) do
    local value = config[key]

    -- Handle optional keys
    if expected_type:sub(-1) == "?" then
      expected_type = expected_type:sub(1, -2)
      if value == nil then
        goto continue
      end
    end

    -- Check type
    if type(value) ~= expected_type then
      return false, string.format(
        "Invalid config: '%s' expected %s, got %s",
        key, expected_type, type(value)
      )
    end

    ::continue::
  end

  return true
end

-- ============================================================================
-- UTILITY: Freeze (Make Read-Only)
-- ============================================================================

--- Make a table read-only (Lua 5.3+)
--- Use for presets to prevent accidental modification
--- @param t table Table to freeze
--- @return table Read-only proxy table
function M.freeze(t)
  return setmetatable({}, {
    __index = t,
    __newindex = function()
      error("Attempt to modify read-only config")
    end,
    __metatable = false,
  })
end

-- ============================================================================
-- DEBUGGING: Config Diff
-- ============================================================================

--- Compare two configs and return differences
--- Useful for debugging preset application issues
--- @param expected table Expected configuration
--- @param actual table Actual configuration
--- @return table Array of difference descriptions
function M.diff(expected, actual)
  local differences = {}

  -- Check expected keys
  for k, v in pairs(expected) do
    if actual[k] ~= v then
      if type(v) == "number" and type(actual[k]) == "number" then
        -- Format as hex if looks like color
        if v > 0xFFFFFF then
          table.insert(differences, string.format(
            "  %s: expected 0x%08X, got %s",
            k, v, actual[k] and string.format("0x%08X", actual[k]) or "nil"
          ))
        else
          table.insert(differences, string.format(
            "  %s: expected %s, got %s",
            k, tostring(v), tostring(actual[k])
          ))
        end
      else
        table.insert(differences, string.format(
          "  %s: expected %s, got %s",
          k, tostring(v), tostring(actual[k])
        ))
      end
    end
  end

  -- Check for unexpected keys
  for k, v in pairs(actual) do
    if expected[k] == nil then
      table.insert(differences, string.format(
        "  %s: not in expected, got %s",
        k, tostring(v)
      ))
    end
  end

  return differences
end

return M
