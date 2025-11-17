-- @noindex
-- TemplateBrowser/domain/file_ops.lua
-- File system operations for templates and folders

local M = {}

-- Get separator for current OS
local function get_sep()
  return package.config:sub(1,1)
end

-- Remove trailing slash/backslash from path
local function normalize_path(path)
  if not path then return path end
  -- Remove trailing separators
  while path:match("[/\\]$") do
    path = path:sub(1, -2)
  end
  return path
end

-- Rename a template file
function M.rename_template(old_path, new_name)
  local sep = get_sep()
  old_path = normalize_path(old_path)
  local dir = old_path:match("^(.*)[/\\]")
  local new_path = dir .. sep .. new_name .. ".RTrackTemplate"

  local success = os.rename(old_path, new_path)
  if success then
    reaper.ShowConsoleMsg(string.format("Renamed template: %s -> %s\n", old_path, new_path))
    return true, new_path
  else
    reaper.ShowConsoleMsg(string.format("ERROR: Failed to rename template: %s\n", old_path))
    return false, nil
  end
end

-- Rename a folder (directory)
function M.rename_folder(old_path, new_name)
  local sep = get_sep()
  old_path = normalize_path(old_path)
  local parent = old_path:match("^(.*)[/\\]")
  if not parent then
    reaper.ShowConsoleMsg(string.format("ERROR: Cannot determine parent for folder: %s\n", old_path))
    return false, nil
  end

  local new_path = parent .. sep .. new_name

  local success = os.rename(old_path, new_path)
  if success then
    reaper.ShowConsoleMsg(string.format("Renamed folder: %s -> %s\n", old_path, new_path))
    return true, new_path
  else
    reaper.ShowConsoleMsg(string.format("ERROR: Failed to rename folder: %s\n", old_path))
    return false, nil
  end
end

-- Move template to a different folder
function M.move_template(template_path, target_folder_path)
  local sep = get_sep()
  template_path = normalize_path(template_path)
  target_folder_path = normalize_path(target_folder_path)

  local filename = template_path:match("[^/\\]+$")
  local new_path = target_folder_path .. sep .. filename

  local success = os.rename(template_path, new_path)
  if success then
    reaper.ShowConsoleMsg(string.format("Moved template: %s -> %s\n", template_path, new_path))
    return true, new_path
  else
    reaper.ShowConsoleMsg(string.format("ERROR: Failed to move template: %s\n", template_path))
    return false, nil
  end
end

-- Move folder (and all its contents) to a different location
function M.move_folder(folder_path, target_parent_path)
  local sep = get_sep()
  folder_path = normalize_path(folder_path)
  target_parent_path = normalize_path(target_parent_path)

  local folder_name = folder_path:match("[^/\\]+$")
  if not folder_name then
    reaper.ShowConsoleMsg(string.format("ERROR: Cannot determine folder name from: %s\n", folder_path))
    return false, nil
  end

  local new_path = target_parent_path .. sep .. folder_name

  local success = os.rename(folder_path, new_path)
  if success then
    reaper.ShowConsoleMsg(string.format("Moved folder: %s -> %s\n", folder_path, new_path))
    return true, new_path
  else
    reaper.ShowConsoleMsg(string.format("ERROR: Failed to move folder: %s\n", folder_path))
    return false, nil
  end
end

-- Create a new folder
function M.create_folder(parent_path, folder_name)
  local sep = get_sep()
  parent_path = normalize_path(parent_path)
  local new_path = parent_path .. sep .. folder_name

  -- Check if folder already exists (try with trailing slash for directory detection)
  if reaper.file_exists(new_path .. sep) then
    reaper.ShowConsoleMsg(string.format("Folder already exists: %s\n", new_path))
    return false, nil
  end

  -- Try using lfs if available
  local has_lfs, lfs = pcall(require, "lfs")
  if has_lfs then
    lfs.mkdir(new_path)
  else
    -- Fallback: try platform-specific commands
    if sep == "\\" then
      -- Windows
      local cmd = 'cmd /c mkdir "' .. new_path:gsub("/", "\\") .. '" 2>nul'
      os.execute(cmd)
    else
      -- Unix/Mac
      os.execute('mkdir -p "' .. new_path .. '"')
    end
  end

  -- Verify folder was created - try multiple methods
  local exists = false

  -- Debug: Check what we're looking for
  reaper.ShowConsoleMsg(string.format("DEBUG: Checking for folder: '%s'\n", new_path))
  reaper.ShowConsoleMsg(string.format("DEBUG: has_lfs = %s\n", tostring(has_lfs)))

  -- Try with trailing slash
  local check1 = reaper.file_exists(new_path .. sep)
  reaper.ShowConsoleMsg(string.format("DEBUG: file_exists('%s%s') = %s\n", new_path, sep, tostring(check1)))
  if check1 then exists = true end

  -- Try without trailing slash
  local check2 = reaper.file_exists(new_path)
  reaper.ShowConsoleMsg(string.format("DEBUG: file_exists('%s') = %s\n", new_path, tostring(check2)))
  if not exists and check2 then exists = true end

  -- Try with lfs.attributes if available
  if not exists and has_lfs then
    local attrs = lfs.attributes(new_path)
    reaper.ShowConsoleMsg(string.format("DEBUG: lfs.attributes = %s, mode = %s\n",
      tostring(attrs), attrs and tostring(attrs.mode) or "nil"))
    exists = (attrs ~= nil and attrs.mode == "directory")
  end

  if exists then
    reaper.ShowConsoleMsg(string.format("Created folder: %s\n", new_path))
    return true, new_path
  else
    reaper.ShowConsoleMsg(string.format("ERROR: Failed to create folder: %s\n", new_path))
    return false, nil
  end
end

return M
