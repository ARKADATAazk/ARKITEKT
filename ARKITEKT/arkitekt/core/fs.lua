-- @noindex
-- arkitekt/core/fs.lua
-- Pure filesystem utilities (no reaper.* or ImGui.* dependencies)
--
-- LAYER PURITY: This is a PURE core module - NO reaper.* or ImGui.* calls allowed
-- For directory existence checks, use reaper.EnumerateFiles/EnumerateSubdirectories
-- in your app/domain layer.

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
-- FILE OPERATIONS (Pure - uses io.open only)
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

--- Copy a file
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

  return M.write_text(dst, content)
end

-- ============================================================================
-- DIRECTORY EXISTENCE (Platform Note)
-- ============================================================================

-- NOTE: Checking directory existence requires platform-specific APIs.
-- In REAPER scripts, use:
--   local function dir_exists(path)
--     return path and (reaper.EnumerateFiles(path, 0) or
--                      reaper.EnumerateSubdirectories(path, 0)) ~= nil
--   end
--
-- This module intentionally does NOT provide dir_exists to maintain purity.

return M
