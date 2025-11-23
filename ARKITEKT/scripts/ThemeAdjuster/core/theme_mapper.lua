-- @noindex
-- ThemeAdjuster/core/theme_mapper.lua
-- JSON-based theme parameter mappings

local ParamDiscovery = require('ThemeAdjuster.core.param_discovery')
local JSON = require('arkitekt.core.json')

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

  if not content or content == "" then
    return nil
  end

  -- Decode JSON using arkitekt JSON library
  local decoded = JSON.decode(content)
  return decoded
end

-- Save JSON file (with pretty formatting)
local function save_json(path, data)
  local file = io.open(path, "w")
  if not file then return false end

  -- Encode to JSON
  local json_str = JSON.encode(data)

  if not json_str then
    file:close()
    return false
  end

  -- Pretty-format the JSON (basic indentation)
  local formatted = M.pretty_format_json(json_str)

  file:write(formatted)
  file:close()

  return true
end

-- Pretty-format JSON with indentation
function M.pretty_format_json(json_str)
  local indent = 0
  local result = {}
  local in_string = false
  local escape_next = false

  for i = 1, #json_str do
    local char = json_str:sub(i, i)

    if escape_next then
      table.insert(result, char)
      escape_next = false
    elseif char == '\\' and in_string then
      table.insert(result, char)
      escape_next = true
    elseif char == '"' then
      table.insert(result, char)
      in_string = not in_string
    elseif not in_string then
      if char == '{' or char == '[' then
        indent = indent + 1
        table.insert(result, char)
        table.insert(result, '\n')
        table.insert(result, string.rep('  ', indent))
      elseif char == '}' or char == ']' then
        indent = indent - 1
        table.insert(result, '\n')
        table.insert(result, string.rep('  ', indent))
        table.insert(result, char)
      elseif char == ',' then
        table.insert(result, char)
        table.insert(result, '\n')
        table.insert(result, string.rep('  ', indent))
      elseif char == ':' then
        table.insert(result, char)
        table.insert(result, ' ')
      elseif char ~= ' ' and char ~= '\n' and char ~= '\t' then
        table.insert(result, char)
      end
    else
      table.insert(result, char)
    end
  end

  return table.concat(result)
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

-- Create mapping structure from discovered parameters
function M.create_mapping_from_params(params)
  local mapping = {
    theme_name = ParamDiscovery.get_current_theme_name(),
    version = "1.0.0",
    created_at = os.date("%Y-%m-%d %H:%M:%S"),
    description = "Auto-generated parameter mappings for Theme Adjuster",
    params = {}
  }

  for _, param in ipairs(params) do
    mapping.params[param.name] = {
      index = param.index,
      display_name = param.name,
      category = param.category or "Uncategorized",
      type = param.type,
      min = param.min,
      max = param.max,
      default = param.default,
      description = param.description or "",
    }
  end

  return mapping
end

-- Export current mappings to JSON
function M.export_mappings(params)
  local themes_dir = ParamDiscovery.get_colorthemes_dir()
  if not themes_dir then
    return false, "Could not find ColorThemes directory"
  end

  local theme_name = M.current_theme_name or ParamDiscovery.get_current_theme_name()
  local json_path = themes_dir .. "/" .. theme_name .. ".json"

  -- Create mapping structure
  local mapping_data = M.create_mapping_from_params(params or {})

  -- Preserve existing assignments if any
  local existing = load_json(json_path)
  if existing and existing.assignments then
    mapping_data.assignments = existing.assignments
  end

  local success = save_json(json_path, mapping_data)

  if success then
    return true, json_path
  else
    return false, "Failed to write JSON file"
  end
end

-- Load current mappings from JSON
function M.load_current_mappings()
  local json_path = M.find_companion_json()
  if not json_path then
    return nil
  end

  return load_json(json_path)
end

-- Save assignments, custom metadata, group filter, parameter link data, templates, group collapsed states, template groups, and template group collapsed states to JSON
function M.save_assignments(assignments, custom_metadata, enabled_groups, param_link_data, templates, group_collapsed_states, template_groups, template_group_collapsed_states)
  local themes_dir = ParamDiscovery.get_colorthemes_dir()
  if not themes_dir then
    return false
  end

  local theme_name = M.current_theme_name or ParamDiscovery.get_current_theme_name()
  local json_path = themes_dir .. "/" .. theme_name .. ".json"

  -- Load existing data or create new
  local data = load_json(json_path) or {
    theme_name = theme_name,
    version = "1.0.0",
    created_at = os.date("%Y-%m-%d %H:%M:%S"),
    description = "Auto-generated parameter mappings for Theme Adjuster",
    params = {},
  }

  -- Update assignments, custom metadata, group filter, parameter link groups, templates, and group collapsed states
  data.assignments = assignments
  data.custom_metadata = custom_metadata or {}
  data.enabled_groups = enabled_groups or {}
  data.parameter_link_data = param_link_data or {}
  data.templates = templates or {}
  data.group_collapsed_states = group_collapsed_states or {}
  data.template_groups = template_groups or {}
  data.template_group_collapsed_states = template_group_collapsed_states or {}

  return save_json(json_path, data)
end

return M
