-- @noindex
-- RegionPlaylist/ui/state/notification.lua
-- Manages status bar notifications and timed messages

local M = {}

--- Create a new notification domain
--- @param timeouts table Timeout configuration {circular_dependency_error, state_change_notification}
--- @return table domain The notification domain instance
function M.new(timeouts)
  local domain = {
    -- Circular dependency errors (auto-clear)
    circular_dependency_error = nil,
    circular_dependency_error_timestamp = nil,
    circular_dependency_error_timeout = timeouts and timeouts.circular_dependency_error or 5.0,

    -- State change notifications (auto-clear)
    state_change_notification = nil,
    state_change_notification_timestamp = nil,
    state_change_notification_timeout = timeouts and timeouts.state_change_notification or 3.0,

    -- Selection info (persistent until changed)
    selection_info = { region_count = 0, playlist_count = 0 },

    -- Transport override state tracking
    last_override_state = false,
  }

  --- Get circular dependency error (auto-clears after timeout)
  --- @return string|nil error_msg The current error message, or nil if cleared/expired
  function domain:get_circular_dependency_error()
    -- Auto-clear error after timeout
    if self.circular_dependency_error and self.circular_dependency_error_timestamp then
      local current_time = reaper.time_precise()
      if (current_time - self.circular_dependency_error_timestamp) >= self.circular_dependency_error_timeout then
        self.circular_dependency_error = nil
        self.circular_dependency_error_timestamp = nil
      end
    end
    return self.circular_dependency_error
  end

  --- Set circular dependency error with timestamp
  --- @param error_msg string The error message to display
  function domain:set_circular_dependency_error(error_msg)
    self.circular_dependency_error = error_msg
    self.circular_dependency_error_timestamp = reaper.time_precise()
  end

  --- Clear circular dependency error immediately
  function domain:clear_circular_dependency_error()
    self.circular_dependency_error = nil
    self.circular_dependency_error_timestamp = nil
  end

  --- Get state change notification (auto-clears after timeout)
  --- @return string|nil notification The current notification, or nil if cleared/expired
  function domain:get_state_change_notification()
    -- Auto-clear notification after timeout
    if self.state_change_notification and self.state_change_notification_timestamp then
      local current_time = reaper.time_precise()
      if (current_time - self.state_change_notification_timestamp) >= self.state_change_notification_timeout then
        self.state_change_notification = nil
        self.state_change_notification_timestamp = nil
      end
    end
    return self.state_change_notification
  end

  --- Set state change notification with timestamp
  --- @param message string The notification message to display
  function domain:set_state_change_notification(message)
    self.state_change_notification = message
    self.state_change_notification_timestamp = reaper.time_precise()
  end

  --- Clear state change notification immediately
  function domain:clear_state_change_notification()
    self.state_change_notification = nil
    self.state_change_notification_timestamp = nil
  end

  --- Get selection info
  --- @return table selection_info {region_count, playlist_count}
  function domain:get_selection_info()
    return self.selection_info
  end

  --- Set selection info
  --- @param info table {region_count, playlist_count}
  function domain:set_selection_info(info)
    self.selection_info = info or { region_count = 0, playlist_count = 0 }
  end

  --- Check if transport override state changed and show notification
  --- @param current_override_state boolean Current override state
  function domain:check_override_state_change(current_override_state)
    if current_override_state ~= self.last_override_state then
      self.last_override_state = current_override_state
      if current_override_state then
        self:set_state_change_notification('Override: Transport will take over when hitting a region')
      else
        self:set_state_change_notification('Override disabled')
      end
    end
  end

  return domain
end

return M
