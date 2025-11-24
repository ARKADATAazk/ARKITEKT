-- @noindex
-- arkitekt/debug/error_handler.lua
-- Enhanced error handling with xpcall wrapper for better stack traces
--
-- Usage:
--   local ErrorHandler = require('arkitekt.debug.error_handler')
--   ErrorHandler.init()  -- Call early, before any defer loops
--
-- Features:
--   - Full stack traces (no REAPER truncation)
--   - Configurable via arkitekt.defs.app
--   - Error counting and statistics
--   - Optional UI notifications
--   - Can be disabled for production builds

local M = {}

M.enabled = false
M.original_defer = nil
M.error_count = 0
M.last_error = nil
M.errors = {}  -- Recent errors (max 10)

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
    show_in_ui = false,
    max_stored_errors = 10,
    include_timestamp = true,
    halt_on_error = false,  -- Set true for strict debugging
  }
end

-- ============================================================================
-- ERROR FORMATTING
-- ============================================================================

local function format_timestamp()
  return os.date("%Y-%m-%d %H:%M:%S")
end

local function format_error(err, traceback)
  local config = get_config()
  local parts = {}

  -- Separator
  table.insert(parts, "═══════════════════════════════════════════════════════════════")

  -- Timestamp
  if config.include_timestamp then
    table.insert(parts, "TIME: " .. format_timestamp())
  end

  -- Error count
  table.insert(parts, "ERROR #" .. (M.error_count + 1))

  -- Error message
  table.insert(parts, "MESSAGE: " .. tostring(err))

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
-- ERROR STORAGE
-- ============================================================================

local function store_error(err, traceback)
  local config = get_config()

  M.error_count = M.error_count + 1
  M.last_error = {
    message = tostring(err),
    traceback = traceback,
    timestamp = os.time(),
  }

  -- Store in recent errors list (FIFO, max 10)
  table.insert(M.errors, 1, M.last_error)
  if #M.errors > config.max_stored_errors then
    table.remove(M.errors)
  end
end

-- ============================================================================
-- ERROR HANDLER
-- ============================================================================

local function error_handler(err)
  local traceback = debug.traceback()
  local config = get_config()

  -- Store error
  store_error(err, traceback)

  -- Log to console
  if config.log_to_console then
    local formatted = format_error(err, traceback)
    reaper.ShowConsoleMsg(formatted)
  end

  -- Halt on error (for strict debugging)
  if config.halt_on_error then
    error(err, 0)
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

-- ============================================================================
-- STATUS API
-- ============================================================================

function M.get_error_count()
  return M.error_count
end

function M.get_last_error()
  return M.last_error
end

function M.get_recent_errors()
  return M.errors
end

function M.clear_errors()
  M.error_count = 0
  M.last_error = nil
  M.errors = {}
end

-- ============================================================================
-- UI INTEGRATION (Optional)
-- ============================================================================

-- Returns status text for status bar
function M.get_status_text()
  if M.error_count == 0 then
    return nil
  end

  if M.error_count == 1 then
    return "⚠ 1 error"
  else
    return "⚠ " .. M.error_count .. " errors"
  end
end

-- Returns formatted error summary for tooltip/UI
function M.get_error_summary()
  if M.error_count == 0 then
    return "No errors"
  end

  local lines = {
    "Recent Errors (" .. M.error_count .. " total):",
    "",
  }

  for i, err in ipairs(M.errors) do
    if i > 5 then break end  -- Show max 5 in summary
    local time_str = os.date("%H:%M:%S", err.timestamp)
    table.insert(lines, string.format("[%s] %s", time_str, err.message))
  end

  return table.concat(lines, "\n")
end

return M
