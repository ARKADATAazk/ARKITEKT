-- @noindex
-- ThemeAdjuster/core/param_discovery.lua
-- Auto-discovery of theme parameters via REAPER API

local M = {}

-- Discover all available theme parameters
function M.discover_all_params()
  local params = {}
  local i = 0

  -- Scan positive indices (layout parameters)
  while true do
    local ok, name, desc, value, default, min, max =
      pcall(reaper.ThemeLayout_GetParameter, i)

    if not ok or name == nil then break end

    table.insert(params, {
      index = i,
      name = name,
      description = desc or name,
      value = value or 0,
      default = default or 0,
      min = min or 0,
      max = max or 1,
      type = M.infer_control_type(min or 0, max or 1),
      category = M.infer_category(name),
      scope = M.infer_scope(desc or ""),
    })

    i = i + 1
  end

  return params
end

-- Infer the appropriate control type based on min/max range
function M.infer_control_type(min, max)
  if min == 0 and max == 1 then
    return "toggle"  -- Boolean toggle
  elseif (max - min) <= 10 and (max - min) > 0 then
    return "spinner"  -- Discrete options (like A/B/C or small ranges)
  elseif max > min then
    return "slider"  -- Continuous range
  else
    return "value"  -- Static value display
  end
end

-- Infer which page/category this parameter belongs to
function M.infer_category(param_name)
  -- Extract prefix (e.g., "tcp_" from "tcp_LabelSize")
  local prefix = param_name:match("^([^_]+)_")

  if prefix == "tcp" then
    return "Track Panel"
  elseif prefix == "mcp" then
    return "Mixer Panel"
  elseif prefix == "envcp" then
    return "Envelope Panel"
  elseif prefix == "trans" then
    return "Transport"
  elseif prefix == "glb" then
    return "Global"
  else
    return "Uncategorized"
  end
end

-- Infer scope from description (Global/Per-layout)
function M.infer_scope(description)
  -- REAPER uses "Layout A", "Layout B", etc. in descriptions for per-layout params
  if description:match("Layout [ABC]") then
    return "per_layout"
  else
    return "global"
  end
end

-- Filter to only unknown parameters (not in ThemeParams.KNOWN_PARAMS)
function M.filter_unknown_params(all_params, known_params)
  local unknown = {}

  for _, param in ipairs(all_params) do
    if not known_params[param.name] then
      table.insert(unknown, param)
    end
  end

  return unknown
end

-- Group parameters by category
function M.group_by_category(params)
  local grouped = {}

  for _, param in ipairs(params) do
    local category = param.category or "Uncategorized"

    if not grouped[category] then
      grouped[category] = {}
    end

    table.insert(grouped[category], param)
  end

  return grouped
end

-- Get current theme name from REAPER
function M.get_current_theme_name()
  local theme_path = reaper.GetLastColorThemeFile()

  if not theme_path or theme_path == "" then
    return "Unknown"
  end

  -- Extract theme name from path
  -- "C:/REAPER/ColorThemes/MyTheme.ReaperThemeZip" → "MyTheme"
  local theme_name = theme_path:match("([^/\\]+)%.ReaperTheme[Zz]?[Ii]?[Pp]?$")

  return theme_name or "Unknown"
end

-- Get ColorThemes directory path
function M.get_colorthemes_dir()
  local theme_path = reaper.GetLastColorThemeFile()

  if not theme_path or theme_path == "" then
    return nil
  end

  -- Extract directory: "C:/REAPER/ColorThemes/MyTheme.ReaperThemeZip" → "C:/REAPER/ColorThemes"
  local dir = theme_path:match("(.+)[/\\][^/\\]+$")

  return dir
end

-- Detect if a parameter is a group header
function M.is_group_header(param)
  local desc = param.description or ""
  local name = param.name or ""

  -- Primary detection: description ends with "Parameters" or "Parameter"
  if desc:match("Parameters?%s*$") then
    return true
  end

  -- Secondary detection: name patterns
  if name:match("Param$") or
     name == "defaultV6" or
     name == "reaperV6Def" or
     name:match("^user_notice") then
    return true
  end

  -- Tertiary detection: separator lines (dashes or empty)
  if desc:match("^%-+") or (desc:match("^%s*$") and param.max == 1) then
    return true
  end

  return false
end

-- Organize parameters into groups based on group headers
function M.organize_into_groups(params)
  local groups = {}
  local current_group = {
    name = "ungrouped",
    display_name = "Ungrouped Parameters",
    header_index = nil,
    params = {}
  }

  for _, param in ipairs(params) do
    if M.is_group_header(param) then
      -- Save current group if it has parameters
      if #current_group.params > 0 then
        table.insert(groups, current_group)
      end

      -- Start new group
      current_group = {
        name = param.name,
        display_name = param.description or param.name,
        header_index = param.index,
        params = {}
      }
    else
      -- Add parameter to current group
      table.insert(current_group.params, param)
    end
  end

  -- Add final group
  if #current_group.params > 0 then
    table.insert(groups, current_group)
  end

  return groups
end

-- Get default disabled groups (V6 Parameters and notice lines)
function M.get_default_disabled_groups()
  return {
    reaperV6Def = true,  -- V6 Parameters
    user_notice = true,  -- Notice lines
    user_notice_line = true,
  }
end

return M
