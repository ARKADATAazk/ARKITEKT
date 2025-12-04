-- @noindex
-- arkitekt/core/notification.lua
-- Manages timed status messages with automatic timeouts
-- Integrates with arkitekt/runtime/chrome/status_bar.lua via get_status() callback

local Theme = require('arkitekt.theme')
local M = {}

-- ============================================================================
-- CONSTANTS
-- ============================================================================

-- Message types
M.TYPE = {
  INFO = 'info',
  SUCCESS = 'success',
  WARNING = 'warning',
  ERROR = 'error',
}

-- Default colors by message type (fallbacks if Theme.COLORS unavailable)
M.DEFAULT_COLORS = {
  info = 0xCCCCCCFF,
  success = 0x41E0A3FF,
  warning = 0xE0B341FF,
  error = 0xE04141FF,
}

-- Get theme-aware color for message type (called each frame for live theme updates)
local function get_theme_color(msg_type)
  local C = Theme.COLORS
  if not C then return M.DEFAULT_COLORS[msg_type] end

  if msg_type == 'info' then
    return C.TEXT_DIMMED or M.DEFAULT_COLORS.info
  elseif msg_type == 'success' then
    return C.ACCENT_SUCCESS or M.DEFAULT_COLORS.success
  elseif msg_type == 'warning' then
    return C.ACCENT_WARNING or M.DEFAULT_COLORS.warning
  elseif msg_type == 'error' then
    return C.ACCENT_DANGER or M.DEFAULT_COLORS.error
  end
  return M.DEFAULT_COLORS.info
end

-- Default timeouts (seconds) by message type
M.DEFAULT_TIMEOUTS = {
  info = 3.0,
  success = 3.0,
  warning = 5.0,
  error = 8.0,
}

-- ============================================================================
-- API
-- ============================================================================

--- Create a new notification manager
--- @param opts table|nil Optional configuration
---   - timeouts: table - Per-type timeout overrides {info=3, success=3, warning=5, error=8}
---   - colors: table - Per-type color overrides {info=0xCCCCCCFF, success=0x41E0A3FF, ...}
--- @return table notification The notification manager instance
function M.new(opts)
  opts = opts or {}

  local self = {
    -- Current status message
    current_message = nil,
    current_type = nil,
    message_time = 0,

    -- Configuration
    timeouts = {},
    colors = {},
  }

  -- Merge timeouts with defaults
  for type_name, default_timeout in pairs(M.DEFAULT_TIMEOUTS) do
    self.timeouts[type_name] = (opts.timeouts and opts.timeouts[type_name]) or default_timeout
  end

  -- Store only custom color overrides (theme colors used as fallback)
  if opts.colors then
    for type_name, color in pairs(opts.colors) do
      self.colors[type_name] = color
    end
  end

  --- Show a status message
  --- @param message string The message to display
  --- @param msg_type string|nil Message type (info, success, warning, error). Defaults to info.
  function self:show(message, msg_type)
    self.current_message = message
    self.current_type = msg_type or M.TYPE.INFO
    self.message_time = reaper.time_precise()
  end

  --- Convenience: Show info message
  --- @param message string The message to display
  function self:info(message)
    self:show(message, M.TYPE.INFO)
  end

  --- Convenience: Show success message
  --- @param message string The message to display
  function self:success(message)
    self:show(message, M.TYPE.SUCCESS)
  end

  --- Convenience: Show warning message
  --- @param message string The message to display
  function self:warning(message)
    self:show(message, M.TYPE.WARNING)
  end

  --- Convenience: Show error message
  --- @param message string The message to display
  function self:error(message)
    self:show(message, M.TYPE.ERROR)
  end

  --- Clear the current message
  function self:clear()
    self.current_message = nil
    self.current_type = nil
    self.message_time = 0
  end

  --- Get current message and type
  --- @return string|nil message The current message
  --- @return string|nil msg_type The message type
  function self:get()
    return self.current_message, self.current_type
  end

  --- Check if there's an active message
  --- @return boolean has_message True if there's a message to display
  function self:has_message()
    return self.current_message ~= nil
  end

  --- Get message color based on current type (theme-aware, fetched each frame)
  --- Custom colors passed via opts.colors take priority over theme colors
  --- @return number|nil color The RGBA color for the message, or nil if no message
  function self:get_color()
    if not self.current_type then
      return nil
    end
    -- Custom override takes priority, otherwise use theme-aware color
    return self.colors[self.current_type] or get_theme_color(self.current_type)
  end

  --- Update: Check if message has expired and auto-clear
  --- Call this every frame (or from your main loop)
  function self:update()
    if not self.current_message then return end

    local now = reaper.time_precise()
    local timeout = self.timeouts[self.current_type] or self.timeouts[M.TYPE.INFO]

    if now - self.message_time > timeout then
      self:clear()
    end
  end

  --- Get status for status_bar integration
  --- Returns {text, color} format expected by status_bar.lua
  --- @return table|nil status {text='...', color=0xRRGGBBAA} or nil if no message
  function self:get_status()
    if not self.current_message then
      return nil
    end

    return {
      text = self.current_message,
      color = self:get_color(),
    }
  end

  return self
end

-- ============================================================================
-- USAGE EXAMPLES
-- ============================================================================

--[[
-- Basic usage:
local Notification = require('arkitekt.core.notification')
local notif = Notification.new()

function main_loop()
  notif:update()  -- Auto-clear expired messages

  -- ... your code ...

  -- Show messages:
  notif:success('File saved successfully')
  notif:warning('No items selected')
  notif:error('Failed to load file')
  notif:info('Processing...')
end

-- Status bar integration:
local StatusBar = require('arkitekt.runtime.chrome.status_bar')
local notif = Notification.new()

local status_bar = StatusBar.new({
  get_status = function()
    return notif:get_status()
  end,
})

function main_loop()
  notif:update()
  status_bar.draw(ctx)
end

-- Custom timeouts and colors:
local notif = Notification.new({
  timeouts = {
    info = 2.0,    -- Quick dismiss for info
    success = 2.0,
    warning = 7.0, -- Longer for warnings
    error = 10.0,  -- Much longer for errors
  },
  colors = {
    error = 0xFF0000FF,  -- Bright red for errors
  }
})
]]

return M
