-- @noindex
-- WalterBuilder/domain/notification.lua
-- Manages status messages and notifications with timeouts

local Constants = require('WalterBuilder.defs.constants')

local M = {}

--- Create a new notification domain
--- @return table domain The notification domain instance
function M.new(timeouts)
  timeouts = timeouts or Constants.TIMEOUTS

  local domain = {
    -- Current status message
    current_message = nil,
    current_type = nil,
    message_time = 0,

    -- Timeouts
    timeouts = timeouts,

    -- Last update time
    last_time = 0,
  }

  --- Set a status message
  --- @param message string The message to display
  --- @param msg_type string|nil The message type (info, success, warning, error)
  function domain:set_message(message, msg_type)
    self.current_message = message
    self.current_type = msg_type or Constants.STATUS.INFO
    self.message_time = reaper.time_precise()
  end

  --- Clear the current message
  function domain:clear_message()
    self.current_message = nil
    self.current_type = nil
    self.message_time = 0
  end

  --- Get current message and type
  --- @return string|nil message The current message
  --- @return string|nil msg_type The message type
  function domain:get_message()
    return self.current_message, self.current_type
  end

  --- Check if message has expired and clear it
  function domain:update()
    if not self.current_message then return end

    local now = reaper.time_precise()
    local timeout = self.timeouts.status_message

    -- Use longer timeout for errors
    if self.current_type == Constants.STATUS.ERROR then
      timeout = self.timeouts.error_message
    end

    if now - self.message_time > timeout then
      self:clear_message()
    end
  end

  --- Get message color based on type
  --- @return number color The RGBA color for the message
  function domain:get_message_color()
    if not self.current_type then
      return Constants.STATUS_COLORS.info
    end
    return Constants.STATUS_COLORS[self.current_type] or Constants.STATUS_COLORS.info
  end

  --- Check if there's an active message
  --- @return boolean has_message True if there's a message to display
  function domain:has_message()
    return self.current_message ~= nil
  end

  return domain
end

return M
