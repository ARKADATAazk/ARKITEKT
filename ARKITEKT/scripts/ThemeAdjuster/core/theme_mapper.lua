-- @noindex
-- ThemeAdjuster/core/theme_mapper.lua
-- JSON-based theme parameter mappings

local ParamDiscovery = require('ThemeAdjuster.core.param_discovery')

local M = {}

-- Current loaded mappings
M.current_mappings = nil
M.current_theme_name = nil

-- Check if file exists
local function file_exists(path)
  local file = io.open(path, "r")
  if file then
    file:close()
    return true
  end
  return false
end

-- Load JSON file
local function load_json(path)
  local file = io.open(path, "r")
  if not file then return nil end

  local content = file:read("*all")
  file:close()

  -- Simple JSON decode (we'll need a proper JSON library)
  -- For now, return nil - will implement after testing basic structure
  -- TODO: Integrate JSON library
  return nil
end

-- Save JSON file
local function save_json(path, data)
  local file = io.open(path, "w")
  if not file then return false end

  -- Simple JSON encode
  -- TODO: Integrate JSON library
  file:write("{}")
  file:close()

  return true
end

-- Find companion JSON file in ColorThemes directory
function M.find_companion_json()
  local themes_dir = ParamDiscovery.get_colorthemes_dir()
  if not themes_dir then return nil end

  local theme_name = ParamDiscovery.get_current_theme_name()
  if not theme_name or theme_name == "Unknown" then return nil end

  -- Look for matching JSON: MyTheme.json
  local json_path = themes_dir .. "/" .. theme_name .. ".json"

  if file_exists(json_path) then
    return json_path
  end

  return nil
end

-- Load theme mappings (with priority chain)
function M.load_theme_mappings()
  M.current_theme_name = ParamDiscovery.get_current_theme_name()

  -- Priority 1: Companion JSON in ColorThemes/ (filename matching)
  local companion_json = M.find_companion_json()
  if companion_json then
    local mappings = load_json(companion_json)
    if mappings then
      M.current_mappings = mappings
      return mappings
    end
  end

  -- Priority 2: Auto-discover (no mappings found)
  M.current_mappings = {}
  return M.current_mappings
end

-- Get all parameters for a specific page
function M.get_params_for_page(page_name)
  if not M.current_mappings then
    M.load_theme_mappings()
  end

  return M.current_mappings[page_name] or {}
end

-- Assign a parameter to a page with metadata
function M.assign_param(param_name, page_name, metadata)
  if not M.current_mappings then
    M.current_mappings = {}
  end

  if not M.current_mappings[page_name] then
    M.current_mappings[page_name] = {}
  end

  M.current_mappings[page_name][param_name] = {
    display_name = metadata.display_name or param_name,
    color = metadata.color or "#FFFFFF",
    category = metadata.category or "Uncategorized",
    tooltip = metadata.tooltip or "",
    index = metadata.index,
  }
end

-- Get mapping for a specific parameter
function M.get_mapping(param_name)
  if not M.current_mappings then
    return nil
  end

  -- Search all pages for this parameter
  for page_name, params in pairs(M.current_mappings) do
    if params[param_name] then
      local mapping = params[param_name]
      mapping.assigned_page = page_name
      return mapping
    end
  end

  return nil
end

-- Export current mappings to JSON
function M.export_mappings()
  local themes_dir = ParamDiscovery.get_colorthemes_dir()
  if not themes_dir then
    return false, "Could not find ColorThemes directory"
  end

  local theme_name = M.current_theme_name or ParamDiscovery.get_current_theme_name()
  local json_path = themes_dir .. "/" .. theme_name .. ".json"

  local success = save_json(json_path, M.current_mappings)

  if success then
    return true, json_path
  else
    return false, "Failed to write JSON file"
  end
end

return M
