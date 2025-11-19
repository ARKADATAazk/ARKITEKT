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

-- Get the TrackTemplates root directory
local function get_templates_root()
  local resource_path = reaper.GetResourcePath()
  local sep = get_sep()
  return resource_path .. sep .. "TrackTemplates"
end

-- Get or create the archive directory
local function get_archive_dir()
  local root = get_templates_root()
  local sep = get_sep()
  local archive_path = root .. sep .. ".archive"

  -- Ensure archive directory exists
  if reaper.RecursiveCreateDirectory then
    reaper.RecursiveCreateDirectory(archive_path, 0)
  end

  return archive_path
end

-- Generate a unique filename if conflict exists
-- e.g., "Template.RTrackTemplate" -> "Template (2).RTrackTemplate"
local function generate_unique_name(base_path, base_name, extension)
  local sep = get_sep()
  local test_path = base_path .. sep .. base_name .. extension
  local counter = 2

  -- Check if file exists
  local file = io.open(test_path, "r")
  if not file then
    return base_name .. extension  -- No conflict, return original name
  end
  file:close()

  -- Find unique name by appending (2), (3), etc.
  while true do
    local new_name = string.format("%s (%d)%s", base_name, counter, extension)
    test_path = base_path .. sep .. new_name

    file = io.open(test_path, "r")
    if not file then
      return new_name  -- Found unique name
    end
    file:close()

    counter = counter + 1
    if counter > 999 then
      -- Safety limit
      return string.format("%s (%d)%s", base_name, os.time(), extension)
    end
  end
end

-- Check if a file exists at the target location
-- Returns: exists (bool), existing_file_path (string or nil)
function M.check_template_conflict(template_name, target_folder_path)
  local sep = get_sep()
  target_folder_path = normalize_path(target_folder_path)

  -- Ensure .RTrackTemplate extension
  local filename = template_name
  if not filename:match("%.RTrackTemplate$") then
    filename = filename .. ".RTrackTemplate"
  end

  local target_path = target_folder_path .. sep .. filename

  -- Check if file exists
  local file = io.open(target_path, "r")
  if file then
    file:close()
    return true, target_path
  end

  return false, nil
end

-- Move a file to archive with timestamp
-- Returns: success (bool), archive_path (string or nil)
function M.archive_file(file_path)
  local sep = get_sep()
  file_path = normalize_path(file_path)

  local filename = file_path:match("[^/\\]+$")
  if not filename then
    reaper.ShowConsoleMsg(string.format("ERROR: Cannot determine filename from: %s\n", file_path))
    return false, nil
  end

  local archive_dir = get_archive_dir()
  local timestamp = os.date("%Y%m%d_%H%M%S")

  -- Extract name and extension
  local name, ext = filename:match("^(.*)(%..+)$")
  if not name then
    name = filename
    ext = ""
  end

  -- Create base archived filename with timestamp
  local base_archive_name = string.format("%s_archived_%s", name, timestamp)

  -- Generate unique name to avoid conflicts in archive folder
  local archive_name = generate_unique_name(archive_dir, base_archive_name, ext)
  local archive_path = archive_dir .. sep .. archive_name

  -- Move file to archive
  local success = os.rename(file_path, archive_path)
  if success then
    reaper.ShowConsoleMsg(string.format("Archived: %s -> %s\n", file_path, archive_path))
    return true, archive_path
  else
    reaper.ShowConsoleMsg(string.format("ERROR: Failed to archive: %s\n", file_path))
    return false, nil
  end
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

-- Move template to a different folder with conflict resolution
-- conflict_mode: nil (no conflict), "overwrite", "keep_both", "cancel"
-- Returns: success (bool), new_path (string or nil), conflict_detected (bool)
function M.move_template(template_path, target_folder_path, conflict_mode)
  local sep = get_sep()
  template_path = normalize_path(template_path)
  target_folder_path = normalize_path(target_folder_path)

  local filename = template_path:match("[^/\\]+$")
  if not filename then
    reaper.ShowConsoleMsg(string.format("ERROR: Cannot determine filename from: %s\n", template_path))
    return false, nil, false
  end

  local new_path = target_folder_path .. sep .. filename

  -- Check for conflict
  local file = io.open(new_path, "r")
  local has_conflict = (file ~= nil)
  if file then file:close() end

  -- If conflict detected and no resolution mode specified, return for user decision
  if has_conflict and not conflict_mode then
    return false, nil, true  -- Signal conflict detected
  end

  -- Handle conflict resolution
  if has_conflict then
    if conflict_mode == "cancel" then
      reaper.ShowConsoleMsg("Move cancelled by user\n")
      return false, nil, false
    elseif conflict_mode == "overwrite" then
      -- Archive existing file before overwrite
      local archive_success = M.archive_file(new_path)
      if not archive_success then
        reaper.ShowConsoleMsg(string.format("ERROR: Failed to archive existing file: %s\n", new_path))
        return false, nil, false
      end
      reaper.ShowConsoleMsg(string.format("Archived existing file before overwrite: %s\n", new_path))
    elseif conflict_mode == "keep_both" then
      -- Generate unique name for incoming file
      local name, ext = filename:match("^(.*)(%..+)$")
      if not name then
        name = filename
        ext = ""
      end

      local unique_filename = generate_unique_name(target_folder_path, name, ext)
      new_path = target_folder_path .. sep .. unique_filename
      reaper.ShowConsoleMsg(string.format("Keeping both files, renaming to: %s\n", unique_filename))
    end
  end

  -- Perform the move
  local success = os.rename(template_path, new_path)
  if success then
    reaper.ShowConsoleMsg(string.format("Moved template: %s -> %s\n", template_path, new_path))
    return true, new_path, false
  else
    reaper.ShowConsoleMsg(string.format("ERROR: Failed to move template: %s\n", template_path))
    return false, nil, false
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

  -- Use REAPER's native directory creation function
  if reaper.RecursiveCreateDirectory then
    local success = reaper.RecursiveCreateDirectory(new_path, 0)
    if success then
      reaper.ShowConsoleMsg(string.format("Created folder: %s\n", new_path))
      return true, new_path
    else
      reaper.ShowConsoleMsg(string.format("ERROR: Failed to create folder: %s\n", new_path))
      return false, nil
    end
  else
    -- Fallback for older REAPER versions
    reaper.ShowConsoleMsg("ERROR: RecursiveCreateDirectory not available\n")
    return false, nil
  end
end

-- Delete template (archives instead of permanent deletion)
-- Returns: success (bool), archive_path (string or nil)
function M.delete_template(template_path)
  return M.archive_file(template_path)
end

-- Delete folder (archives instead of permanent deletion)
-- Note: Folder archiving moves the entire folder with its contents
-- Returns: success (bool), archive_path (string or nil)
function M.delete_folder(folder_path)
  local sep = get_sep()
  folder_path = normalize_path(folder_path)

  local folder_name = folder_path:match("[^/\\]+$")
  if not folder_name then
    reaper.ShowConsoleMsg(string.format("ERROR: Cannot determine folder name from: %s\n", folder_path))
    return false, nil
  end

  local archive_dir = get_archive_dir()
  local timestamp = os.date("%Y%m%d_%H%M%S")

  -- Create base archived folder name with timestamp
  local base_archive_name = string.format("%s_archived_%s", folder_name, timestamp)

  -- Generate unique name to avoid conflicts in archive folder
  -- For folders, we don't have an extension, so pass empty string
  local archive_name = generate_unique_name(archive_dir, base_archive_name, "")
  local archive_path = archive_dir .. sep .. archive_name

  -- Move entire folder to archive
  local success = os.rename(folder_path, archive_path)
  if success then
    reaper.ShowConsoleMsg(string.format("Archived folder: %s -> %s\n", folder_path, archive_path))
    return true, archive_path
  else
    reaper.ShowConsoleMsg(string.format("ERROR: Failed to archive folder: %s\n", folder_path))
    return false, nil
  end
end

-- Get archive directory path (for UI display)
function M.get_archive_path()
  return get_archive_dir()
end

return M
