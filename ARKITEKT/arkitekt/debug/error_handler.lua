-- @noindex
-- arkitekt/debug/error_handler.lua
-- Simple error handler: xpcall wrapper for full stack traces in REAPER console
--
-- Usage:
--   local ErrorHandler = require('arkitekt.debug.error_handler')
--   ErrorHandler.init()  -- Call early, before any defer loops
--
-- What it does:
--   - Wraps reaper.defer with xpcall
--   - Prints full stack traces to REAPER Console
--   - Configurable via arkitekt.defs.app.ERROR_HANDLER

local M = {}

M.enabled = false
M.original_defer = nil

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local function get_config()
  local ok, AppConfig = pcall(require, 'arkitekt.defs.app')
  if ok and AppConfig and AppConfig.ERROR_HANDLER then
    return AppConfig.ERROR_HANDLER
  end

  -- Default config
  return {
    enabled = true,
    log_to_console = true,
    include_timestamp = true,
  }
end

-- ============================================================================
-- ERROR FORMATTING (For REAPER Console)
-- ============================================================================

local function format_error(err, traceback)
  local config = get_config()
  local parts = {}

  -- Separator
  table.insert(parts, "═══════════════════════════════════════════════════════════════")

  -- Timestamp
  if config.include_timestamp then
    table.insert(parts, "TIME: " .. os.date("%Y-%m-%d %H:%M:%S"))
  end

  -- Error message
  table.insert(parts, "ERROR: " .. tostring(err))

  -- Stack trace
  table.insert(parts, "")
  table.insert(parts, "STACK TRACE:")
  table.insert(parts, traceback)

  -- Separator
  table.insert(parts, "═══════════════════════════════════════════════════════════════")
  table.insert(parts, "")

  return table.concat(parts, "\n")
end

-- ============================================================================
-- ERROR HANDLER
-- ============================================================================

local function error_handler(err)
  local traceback = debug.traceback()
  local config = get_config()

  -- Log to REAPER Console
  if config.log_to_console then
    local formatted = format_error(err, traceback)
    reaper.ShowConsoleMsg(formatted)
  end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function M.init()
  if M.enabled then
    return true
  end

  local config = get_config()

  if not config.enabled then
    return false
  end

  -- Store original defer
  M.original_defer = reaper.defer

  -- Wrap reaper.defer with xpcall
  reaper.defer = function(func)
    return M.original_defer(function()
      xpcall(func, error_handler)
    end)
  end

  M.enabled = true

  if config.log_to_console then
    reaper.ShowConsoleMsg("[ErrorHandler] Enhanced error logging enabled\n")
  end

  return true
end

return M
