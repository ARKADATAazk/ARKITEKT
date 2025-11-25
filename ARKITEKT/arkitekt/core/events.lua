-- @noindex
-- arkitekt/core/events.lua
-- Generic event bus for decoupled pub/sub communication
--
-- Usage:
--   local Events = require("arkitekt.core.events")
--   local bus = Events.new()
--
--   -- Subscribe
--   bus:on("user.clicked", function(data) print(data.x, data.y) end)
--
--   -- Emit
--   bus:emit("user.clicked", { x = 100, y = 200 })

local M = {}

--- Create a new event bus instance
--- @param options table Optional configuration { debug = false, max_history = 100 }
--- @return table bus Event bus instance
function M.new(options)
  options = options or {}

  local bus = {
    listeners = {},              -- Map: event_name -> array of listener objects
    debug = options.debug or false,
    max_history = options.max_history or 100,
    history = {},                -- Recent events (for debugging)
  }

  --- Subscribe to an event
  --- @param event_name string Event name (e.g., "playlist.changed")
  --- @param callback function Function to call when event fires
  --- @param priority number Optional priority (higher = earlier execution, default 0)
  --- @return function unsubscribe Function to remove this listener
  function bus:on(event_name, callback, priority)
    if type(event_name) ~= "string" then
      error("Event name must be a string")
    end
    if type(callback) ~= "function" then
      error("Callback must be a function")
    end

    priority = priority or 0

    if not self.listeners[event_name] then
      self.listeners[event_name] = {}
    end

    local listener = {
      callback = callback,
      priority = priority,
      id = #self.listeners[event_name] + 1
    }

    table.insert(self.listeners[event_name], listener)

    -- Sort by priority (higher first)
    table.sort(self.listeners[event_name], function(a, b)
      return a.priority > b.priority
    end)

    if self.debug then
      reaper.ShowConsoleMsg(string.format("[EVENTS] Subscribed to '%s' (priority: %d)\n", event_name, priority))
    end

    -- Return unsubscribe function
    local listener_id = listener.id
    return function()
      if not self.listeners[event_name] then return end

      for i, l in ipairs(self.listeners[event_name]) do
        if l.id == listener_id then
          table.remove(self.listeners[event_name], i)
          if self.debug then
            reaper.ShowConsoleMsg(string.format("[EVENTS] Unsubscribed from '%s'\n", event_name))
          end
          break
        end
      end
    end
  end

  --- Subscribe to an event (fires only once, then auto-unsubscribes)
  --- @param event_name string Event name
  --- @param callback function Function to call once
  function bus:once(event_name, callback)
    local unsubscribe
    unsubscribe = self:on(event_name, function(data)
      callback(data)
      unsubscribe()  -- Remove self after firing
    end)
    return unsubscribe
  end

  --- Emit an event (call all listeners)
  --- @param event_name string Event name
  --- @param data table Optional data to pass to listeners
  function bus:emit(event_name, data)
    -- Store in history
    table.insert(self.history, 1, {
      event = event_name,
      data = data,
      timestamp = reaper.time_precise()
    })

    if #self.history > self.max_history then
      table.remove(self.history)
    end

    if self.debug then
      reaper.ShowConsoleMsg(string.format("[EVENTS] Emitting '%s'\n", event_name))
    end

    -- Call specific listeners
    local callbacks = self.listeners[event_name]
    if callbacks then
      for _, listener in ipairs(callbacks) do
        local ok, err = pcall(listener.callback, data)
        if not ok then
          reaper.ShowConsoleMsg(string.format("[EVENTS] Error in listener for '%s': %s\n", event_name, tostring(err)))
        end
      end
    end

    -- Call wildcard listeners (subscribed to "*")
    local wildcard_callbacks = self.listeners["*"]
    if wildcard_callbacks then
      for _, listener in ipairs(wildcard_callbacks) do
        local ok, err = pcall(listener.callback, event_name, data)
        if not ok then
          reaper.ShowConsoleMsg(string.format("[EVENTS] Error in wildcard listener for '%s': %s\n", event_name, tostring(err)))
        end
      end
    end
  end

  --- Remove all listeners for an event
  --- @param event_name string Event name
  function bus:off(event_name)
    self.listeners[event_name] = nil
    if self.debug then
      reaper.ShowConsoleMsg(string.format("[EVENTS] Removed all listeners for '%s'\n", event_name))
    end
  end

  --- Remove all listeners (useful for cleanup)
  function bus:clear()
    self.listeners = {}
    if self.debug then
      reaper.ShowConsoleMsg("[EVENTS] Cleared all listeners\n")
    end
  end

  --- Get event history
  --- @param count number Optional max number of events to return
  --- @return table history Array of recent events
  function bus:get_history(count)
    count = count or #self.history
    local result = {}
    for i = 1, math.min(count, #self.history) do
      result[i] = self.history[i]
    end
    return result
  end

  --- Print event history (for debugging)
  --- @param count number Optional max number of events to print
  function bus:print_history(count)
    count = count or 10
    reaper.ShowConsoleMsg(string.format("\n[EVENTS] Last %d events:\n", count))
    for i = 1, math.min(count, #self.history) do
      local event = self.history[i]
      reaper.ShowConsoleMsg(string.format("  [%.3f] %s\n", event.timestamp, event.event))
    end
  end

  --- Get listener count for an event
  --- @param event_name string Event name (or "*" for all)
  --- @return number count Number of listeners
  function bus:listener_count(event_name)
    if event_name == "*" then
      local total = 0
      for _, listeners in pairs(self.listeners) do
        total = total + #listeners
      end
      return total
    end

    local listeners = self.listeners[event_name]
    return listeners and #listeners or 0
  end

  --- Enable/disable debug mode
  --- @param enabled boolean Debug mode enabled
  function bus:set_debug(enabled)
    self.debug = enabled
    if enabled then
      reaper.ShowConsoleMsg("[EVENTS] Debug mode enabled\n")
    end
  end

  return bus
end

return M
