-- @noindex
-- arkitekt/core/fs.lua
-- Filesystem utilities for REAPER scripts

local M = {}

-- ============================================================================
-- CONSTANTS
-- ============================================================================

--- Platform path separator ("/" on Unix, "\\" on Windows)
M.SEP = package.config:sub(1,1)

-- ============================================================================
-- PATH UTILITIES
-- ============================================================================

--- Join two path segments with the correct separator
--- @param a string First path segment
--- @param b string Second path segment
--- @return string joined Joined path
function M.join(a, b)
  if not a or a == "" then return b or "" end
  if not b or b == "" then return a end
  local sep = M.SEP
  if a:sub(-1) == sep or a:sub(-1) == "/" or a:sub(-1) == "\\" then
    return a .. b
  end
  return a .. sep .. b
end

--- Get the directory portion of a path
--- @param path string Path to extract directory from
--- @return string dir Directory portion (with trailing separator)
function M.dirname(path)
  if not path then return "" end
  return path:match("^(.*[/\\])") or ""
end

--- Get the filename portion of a path
--- @param path string Path to extract filename from
--- @return string filename Filename portion
function M.basename(path)
  if not path then return "" end
  return path:match("[^/\\]+$") or path
end

--- Get the filename without extension
--- @param path string Path to process
--- @return string name Filename without extension
function M.basename_no_ext(path)
  local name = M.basename(path)
  return name and name:gsub("%.[^%.]*$", "") or ""
end

--- Get the file extension (with dot)
--- @param path string Path to process
--- @return string|nil ext Extension including dot, or nil
function M.extension(path)
  if not path then return nil end
  return path:match("(%.[^./\\]*)$")
end

-- ============================================================================
-- FILE OPERATIONS
-- ============================================================================

--- Check if a file exists (works for files only, not directories)
--- @param path string Path to check
--- @return boolean exists True if file exists and is readable
function M.file_exists(path)
  if not path then return false end
  local f = io.open(path, "rb")
  if f then
    f:close()
    return true
  end
  return false
end

--- Read entire file as text
--- @param path string Path to read
--- @return string|nil content File contents, or nil on error
function M.read_text(path)
  if not path then return nil end
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

--- Read entire file as binary
--- @param path string Path to read
--- @return string|nil content File contents, or nil on error
function M.read_binary(path)
  return M.read_text(path)  -- Same implementation, alias for clarity
end

--- Write text to file
--- @param path string Path to write
--- @param content string Content to write
--- @return boolean success True on success
--- @return string|nil error Error message on failure
function M.write_text(path, content)
  if not path then return false, "No path specified" end
  local f, err = io.open(path, "wb")
  if not f then return false, err end
  local ok, write_err = f:write(content or "")
  f:close()
  if not ok then return false, write_err end
  return true
end

--- Write text to file atomically (write to temp, then rename)
--- @param path string Path to write
--- @param content string Content to write
--- @return boolean success True on success
--- @return string|nil error Error message on failure
function M.write_text_atomic(path, content)
  if not path then return false, "No path specified" end
  local tmp = path .. ".tmp"
  local f, err = io.open(tmp, "wb")
  if not f then
    return false, "Failed to create temp file: " .. (err or "unknown")
  end
  local ok, write_err = f:write(content or "")
  f:close()
  if not ok then
    os.remove(tmp)
    return false, "Failed to write: " .. (write_err or "unknown")
  end
  os.remove(path)  -- Windows-safe replace
  local rename_ok, rename_err = os.rename(tmp, path)
  if not rename_ok then
    return false, "Failed to rename: " .. (rename_err or "unknown")
  end
  return true
end

-- ============================================================================
-- DIRECTORY OPERATIONS
-- ============================================================================

--- Check if a directory exists
--- @param path string Path to check
--- @return boolean exists True if directory exists
function M.dir_exists(path)
  if not path then return false end
  return (reaper.EnumerateFiles(path, 0) or
          reaper.EnumerateSubdirectories(path, 0)) ~= nil
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
--- @return table files Array of full file paths
function M.list_files_recursive(dir, ext)
  local out = M.list_files(dir, ext)

  for _, subdir in ipairs(M.list_subdirs(dir)) do
    local sub_files = M.list_files_recursive(subdir, ext)
    for _, f in ipairs(sub_files) do
      out[#out + 1] = f
    end
  end

  return out
end

--- Copy a file (ensures parent directory exists)
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
