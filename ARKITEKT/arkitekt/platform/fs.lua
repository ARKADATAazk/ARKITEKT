-- @noindex
-- arkitekt/platform/fs.lua
-- Platform-specific filesystem utilities (requires REAPER API)
--
-- This module extends arkitekt.core.fs with REAPER-specific operations.
-- Use arkitekt.core.fs for pure operations, this for REAPER-dependent ones.

local CoreFs = require('arkitekt.core.fs')

local M = {}

-- Re-export all core fs functions
for k, v in pairs(CoreFs) do
  M[k] = v
end

-- ============================================================================
-- DIRECTORY OPERATIONS (Requires REAPER API)
-- ============================================================================

--- Check if a directory exists
--- @param path string Path to check
--- @return boolean exists True if directory exists
function M.dir_exists(path)
  if not path then return false end
  return (reaper.EnumerateFiles(path, 0) or
          reaper.EnumerateSubdirectories(path, 0)) ~= nil
end

--- List files in a directory
--- @param dir string Directory path
--- @param ext string|nil Optional extension filter (e.g., ".png")
--- @return table files Array of full file paths
function M.list_files(dir, ext)
  local out = {}
  if not dir then return out end

  local i = 0
  while true do
    local f = reaper.EnumerateFiles(dir, i)
    if not f then break end
    if not ext or f:lower():sub(-#ext) == ext:lower() then
      out[#out + 1] = M.join(dir, f)
    end
    i = i + 1
  end
  return out
end

--- List subdirectories in a directory
--- @param dir string Directory path
--- @return table dirs Array of full directory paths
function M.list_subdirs(dir)
  local out = {}
  if not dir then return out end

  local j = 0
  while true do
    local s = reaper.EnumerateSubdirectories(dir, j)
    if not s then break end
    out[#out + 1] = M.join(dir, s)
    j = j + 1
  end
  return out
end

--- List files recursively
--- @param dir string Directory path
--- @param ext string|nil Optional extension filter
--- @param out table|nil Accumulator table (internal use)
--- @return table files Array of full file paths
function M.list_files_recursive(dir, ext, out)
  out = out or {}
  out = M.list_files(dir, ext)

  for _, subdir in ipairs(M.list_subdirs(dir)) do
    local sub_files = M.list_files_recursive(subdir, ext, {})
    for _, f in ipairs(sub_files) do
      out[#out + 1] = f
    end
  end

  return out
end

--- Create directory (and parents if needed)
--- @param path string Directory path to create
--- @return boolean success True if directory exists/was created
function M.mkdir(path)
  if not path then return false end
  reaper.RecursiveCreateDirectory(path, 0)
  return M.dir_exists(path)
end

--- Ensure parent directory exists before writing a file
--- @param file_path string Full path to the file
--- @return boolean success True if parent directory exists/was created
function M.ensure_parent_dir(file_path)
  local dir = M.dirname(file_path)
  if dir and dir ~= "" then
    return M.mkdir(dir)
  end
  return true
end

--- Copy a file (ensures parent directory exists)
--- Overrides core.fs.copy_file to create destination directory if needed
--- @param src string Source path
--- @param dst string Destination path
--- @return boolean success True on success
--- @return string|nil error Error message on failure
function M.copy_file(src, dst)
  if not src then return false, "No source path" end
  if not dst then return false, "No destination path" end

  local content = M.read_binary(src)
  if not content then
    return false, "Cannot read source: " .. src
  end

  -- Ensure destination directory exists
  M.ensure_parent_dir(dst)

  return M.write_text(dst, content)
end

return M
