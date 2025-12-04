-- @noindex
-- arkitekt/core/path_validation.lua
-- Security utilities for validating and sanitizing file paths
--
-- PURPOSE:
-- This module provides path validation to prevent:
-- - Path traversal attacks (../ sequences)
-- - Command injection via shell metacharacters
-- - Malicious file names
--
-- LAYER PURITY: This is a PURE core module - NO reaper.* or ImGui.* calls allowed

local M = {}

-- ============================================================================
-- VALIDATION FUNCTIONS
-- ============================================================================

--- Validate that a path is safe from security vulnerabilities
--- @param path string|nil Path to validate
--- @return boolean success True if path is safe
--- @return string|nil error Error message if validation failed
function M.is_safe_path(path)
  if not path or path == '' then
    return false, 'Path cannot be empty'
  end

  -- Only allow alphanumeric, spaces, dots, dashes, underscores, parentheses, and path separators
  -- This blocks shell metacharacters: quotes, semicolons, pipes, backticks, $, etc.
  local safe_pattern = '^[%w%s%.%-%_/\\:()]+$'
  if not path:match(safe_pattern) then
    return false, 'Path contains unsafe characters (only alphanumeric, spaces, .-_/\\:() allowed)'
  end

  -- Block directory traversal attempts
  if path:find('%.%.') then
    return false, 'Path cannot contain \'..\''
  end

  return true
end

--- Validate that a filename is safe (no path separators)
--- @param filename string|nil Filename to validate
--- @return boolean success True if filename is safe
--- @return string|nil error Error message if validation failed
function M.is_safe_filename(filename)
  if not filename or filename == '' then
    return false, 'Filename cannot be empty'
  end

  -- Filenames should not contain path separators
  if filename:find('[/\\]') then
    return false, 'Filename cannot contain path separators'
  end

  -- Apply same character restrictions as paths
  local safe_pattern = '^[%w%s%.%-%_()]+$'
  if not filename:match(safe_pattern) then
    return false, 'Filename contains unsafe characters (only alphanumeric, spaces, .-_() allowed)'
  end

  -- Block directory traversal
  if filename:find('%.%.') then
    return false, 'Filename cannot contain \'..\''
  end

  -- Block hidden files that start with dot (optional - can be adjusted)
  if filename:match('^%.') then
    return false, 'Filename cannot start with \'.\''
  end

  return true
end

--- Sanitize a filename by removing/replacing unsafe characters
--- @param filename string Filename to sanitize
--- @return string sanitized Sanitized filename
function M.sanitize_filename(filename)
  if not filename then return 'unnamed' end

  -- Remove path separators
  filename = filename:gsub('[/\\]', '_')

  -- Remove or replace shell metacharacters
  filename = filename:gsub('[;|&$`\'\"<>]', '')

  -- Replace directory traversal attempts
  filename = filename:gsub('%.%.', '__')

  -- Remove leading/trailing dots and spaces
  filename = filename:gsub('^[%s%.]+', '')
  filename = filename:gsub('[%s%.]+$', '')

  -- Ensure we have something left
  if filename == '' then
    filename = 'unnamed'
  end

  return filename
end

--- Validate multiple paths in a single call
--- @param paths table Table of paths to validate
--- @return boolean success True if all paths are safe
--- @return table|nil errors Table of {path, error} for failed validations
function M.validate_paths(paths)
  local errors = {}

  for i, path in ipairs(paths) do
    local ok, err = M.is_safe_path(path)
    if not ok then
      errors[#errors + 1] = {
        index = i,
        path = path,
        error = err
      }
    end
  end

  if #errors > 0 then
    return false, errors
  end

  return true
end

--- Assert that a path is safe - raises error if not
--- Use this for runtime validation in functions that require safe paths
--- @param path string Path to validate
--- @param context string|nil Optional context for error message
--- @return string path Returns the path if valid
function M.assert_safe_path(path, context)
  local ok, err = M.is_safe_path(path)
  if not ok then
    local msg = context and
      string.format('Invalid path in %s: %s', context, err) or
      string.format('Invalid path: %s', err)
    error(msg, 2)
  end
  return path
end

--- Assert that a filename is safe - raises error if not
--- @param filename string Filename to validate
--- @param context string|nil Optional context for error message
--- @return string filename Returns the filename if valid
function M.assert_safe_filename(filename, context)
  local ok, err = M.is_safe_filename(filename)
  if not ok then
    local msg = context and
      string.format('Invalid filename in %s: %s', context, err) or
      string.format('Invalid filename: %s', err)
    error(msg, 2)
  end
  return filename
end

-- ============================================================================
-- PATH NORMALIZATION HELPERS
-- ============================================================================

--- Normalize path separators to current platform
--- @param path string Path to normalize
--- @return string normalized Normalized path
function M.normalize_separators(path)
  if not path then return '' end

  local sep = package.config:sub(1,1)

  -- Convert all separators to platform separator
  if sep == '/' then
    path = path:gsub('\\', '/')
  else
    path = path:gsub('/', '\\')
  end

  return path
end

--- Remove trailing path separator
--- @param path string Path to process
--- @return string path Path without trailing separator
function M.remove_trailing_separator(path)
  if not path then return path end

  -- Remove trailing separators
  while path:match('[/\\]$') do
    path = path:sub(1, -2)
  end

  return path
end

-- ============================================================================
-- SECURITY UTILITIES
-- ============================================================================

--- Check if path contains common malicious patterns
--- This is an additional layer beyond basic validation
--- @param path string Path to check
--- @return boolean is_suspicious True if path looks suspicious
--- @return string|nil reason Reason for suspicion
function M.check_suspicious_patterns(path)
  if not path then return false end

  -- Check for null bytes (common in path traversal attacks)
  if path:find('\0') then
    return true, 'Path contains null byte'
  end

  -- Check for excessive path separators (e.g., ////)
  if path:find('[/\\][/\\][/\\]') then
    return true, 'Path contains excessive separators'
  end

  -- Check for hidden encoding attempts (URL encoding, etc.)
  if path:find('%%') then
    return true, 'Path contains percent encoding'
  end

  -- Check for unicode control characters (U+0000 to U+001F)
  if path:find('[\001-\031]') then
    return true, 'Path contains control characters'
  end

  return false
end

--- Validate and normalize a path in one call
--- @param path string Path to validate and normalize
--- @param opts table|nil Options: {allow_empty=bool, sanitize=bool}
--- @return boolean success True if valid
--- @return string|nil result Normalized path or error message
function M.validate_and_normalize(path, opts)
  opts = opts or {}

  if not path or path == '' then
    if opts.allow_empty then
      return true, ''
    else
      return false, 'Path cannot be empty'
    end
  end

  -- Sanitize if requested
  if opts.sanitize then
    path = M.sanitize_filename(path)
  end

  -- Validate
  local ok, err = M.is_safe_path(path)
  if not ok then
    return false, err
  end

  -- Check for suspicious patterns
  local suspicious, reason = M.check_suspicious_patterns(path)
  if suspicious then
    return false, 'Suspicious path: ' .. (reason or 'unknown')
  end

  -- Normalize
  path = M.normalize_separators(path)
  path = M.remove_trailing_separator(path)

  return true, path
end

return M
