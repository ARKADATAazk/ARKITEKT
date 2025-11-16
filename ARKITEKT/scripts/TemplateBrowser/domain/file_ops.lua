-- @noindex
-- TemplateBrowser/domain/file_ops.lua
-- File system operations for templates and folders

local M = {}

-- Get separator for current OS
local function get_sep()
  return package.config:sub(1,1)
end

-- Rename a template file
function M.rename_template(old_path, new_name)
  local sep = get_sep()
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
  local parent = old_path:match("^(.*)[/\\]")
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
  local folder_name = folder_path:match("[^/\\]+$")
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
  local new_path = parent_path .. sep .. folder_name

  -- Use reaper's directory creation if available, otherwise try os
  local success = false

  -- Try using lfs if available
  local has_lfs, lfs = pcall(require, "lfs")
  if has_lfs then
    success = lfs.mkdir(new_path)
  else
    -- Fallback: try platform-specific commands
    if sep == "\\" then
      -- Windows
      success = os.execute('mkdir "' .. new_path .. '"') == 0
    else
      -- Unix/Mac
      success = os.execute('mkdir -p "' .. new_path .. '"') == 0
    end
  end

  if success then
    reaper.ShowConsoleMsg(string.format("Created folder: %s\n", new_path))
    return true, new_path
  else
    reaper.ShowConsoleMsg(string.format("ERROR: Failed to create folder: %s\n", new_path))
    return false, nil
  end
end

return M
