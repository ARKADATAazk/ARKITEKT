-- @noindex
-- WalterBuilder/domain/theme_connector.lua
-- Connects to REAPER's theme system to find and load rtconfig
--
-- Uses REAPER API to:
-- - Find current theme path
-- - Locate rtconfig.txt
-- - Get theme layout parameters
-- - Trigger theme refresh

local RtconfigParser = require('WalterBuilder.domain.rtconfig_parser')

local M = {}

local SEP = package.config:sub(1,1)

-- Join path components
local function join(a, b)
  if not a or a == "" then return b end
  if not b or b == "" then return a end
  local last = a:sub(-1)
  if last == SEP or last == "/" or last == "\\" then
    return a .. b
  end
  return a .. SEP .. b
end

-- Check if file exists
local function file_exists(path)
  local f = io.open(path, "rb")
  if f then
    f:close()
    return true
  end
  return false
end

-- Check if directory exists
local function dir_exists(path)
  return path and (reaper.EnumerateFiles(path, 0) or reaper.EnumerateSubdirectories(path, 0)) ~= nil
end

-- Get basename without extension
local function basename_no_ext(path)
  if not path then return nil end
  local name = path:match("[^\\/]+$") or path
  return name:gsub("%.%w+$", "")
end

-- Get directory from path
local function dirname(path)
  return path and path:match("^(.*[\\/])") or ""
end

-- Get current theme info
function M.get_theme_info()
  local info = {
    resource_path = nil,
    themes_dir = nil,
    theme_path = nil,
    theme_name = nil,
    theme_ext = nil,
    theme_root = nil,  -- Directory containing theme files
    rtconfig_path = nil,
    has_rtconfig = false,
  }

  -- Get REAPER resource path
  info.resource_path = reaper.GetResourcePath()
  info.themes_dir = join(info.resource_path, "ColorThemes")

  -- Get current theme file
  info.theme_path = reaper.GetLastColorThemeFile()
  if not info.theme_path then
    return info
  end

  info.theme_name = basename_no_ext(info.theme_path)
  info.theme_ext = info.theme_path:match("%.([%w]+)$")

  -- Determine theme root directory
  -- For .ReaperTheme files, the root is usually the same directory or theme_name folder
  -- For .ReaperThemeZip, it's more complex (need to extract)
  if info.theme_ext and info.theme_ext:lower() == "reapertheme" then
    -- Check if there's a matching directory for the theme
    local theme_dir = info.theme_path:gsub("%.ReaperTheme$", "")
    if dir_exists(theme_dir) then
      info.theme_root = theme_dir
    else
      -- Theme files might be in the same directory as .ReaperTheme
      info.theme_root = dirname(info.theme_path)
    end
  elseif info.theme_ext and info.theme_ext:lower() == "reaperthemezip" then
    -- For zip themes, would need extraction - return nil for now
    info.theme_root = nil
  end

  -- Look for rtconfig.txt
  if info.theme_root then
    local rtconfig = join(info.theme_root, "rtconfig.txt")
    if file_exists(rtconfig) then
      info.rtconfig_path = rtconfig
      info.has_rtconfig = true
    end
  end

  return info
end

-- Try BR_GetCurrentTheme if available (SWS extension)
function M.get_theme_info_br()
  if reaper.BR_GetCurrentTheme then
    local theme_path, theme_name = reaper.BR_GetCurrentTheme()
    return {
      path = theme_path,
      name = theme_name,
    }
  end
  return nil
end

-- Load rtconfig from current theme
function M.load_current_rtconfig()
  local info = M.get_theme_info()

  if not info.has_rtconfig then
    return nil, "No rtconfig.txt found for current theme"
  end

  local parsed, err = RtconfigParser.parse_file(info.rtconfig_path)
  if not parsed then
    return nil, err
  end

  return {
    info = info,
    parsed = parsed,
    summary = RtconfigParser.get_summary(parsed),
  }
end

-- Load rtconfig from specific path
function M.load_rtconfig(path)
  if not file_exists(path) then
    return nil, "File not found: " .. path
  end

  local parsed, err = RtconfigParser.parse_file(path)
  if not parsed then
    return nil, err
  end

  return {
    path = path,
    parsed = parsed,
    summary = RtconfigParser.get_summary(parsed),
  }
end

-- Get all theme layout parameters from REAPER
function M.get_layout_parameters()
  local params = {}
  local i = 0

  while true do
    local retval, desc, value, defValue, minValue, maxValue = reaper.ThemeLayout_GetParameter(i)
    if not retval or retval == "" then
      break
    end

    params[#params + 1] = {
      index = i,
      name = retval,
      description = desc or "",
      value = value,
      default = defValue,
      min = minValue,
      max = maxValue,
    }

    i = i + 1
  end

  return params
end

-- Refresh all theme layouts
function M.refresh_layouts()
  reaper.ThemeLayout_RefreshAll()
end

-- Set a layout parameter (for live preview)
function M.set_layout_parameter(index, value, persist)
  return reaper.ThemeLayout_SetParameter(index, value, persist or false)
end

-- Get available layouts for a section
function M.get_available_layouts(section)
  -- This would require parsing the rtconfig to find Layout definitions
  -- For now, return common layout names
  return { "A", "B", "C" }
end

-- Set layout override for a section
function M.set_layout(section, layout)
  return reaper.ThemeLayout_SetLayout(section, layout)
end

return M
