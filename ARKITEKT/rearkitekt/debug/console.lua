-- @noindex
-- rearkitekt/debug/console.lua
-- Visual debug console widget - Public API
--
-- This is a thin wrapper. Implementation details in _console_widget.lua

local ConsoleWidget = require('rearkitekt.debug._console_widget')

local M = {}

--- Create a new debug console instance
-- @param config table Optional configuration
-- @return console Console instance
function M.new(config)
  return ConsoleWidget.new(config)
end

--- Render the console UI
-- This should be called every frame inside your draw loop
-- @param console Console instance
-- @param ctx ImGui context
function M.render(console, ctx)
  if not console or not ctx then
    error("Console.render() requires console instance and ImGui context")
  end
  console:render(ctx)
end

--- Set the log level filter
-- @param console Console instance
-- @param category string One of: "All", "INFO", "DEBUG", "WARN", "ERROR", "PROFILE"
function M.set_filter(console, category)
  if not console then
    error("Console.set_filter() requires console instance")
  end
  local valid = {All=true, INFO=true, DEBUG=true, WARN=true, ERROR=true, PROFILE=true}
  if not valid[category] then
    error("Invalid filter category: " .. tostring(category))
  end
  console.filter_category = category
end

--- Get the current filter
-- @param console Console instance
-- @return string Current filter category
function M.get_filter(console)
  if not console then
    error("Console.get_filter() requires console instance")
  end
  return console.filter_category
end

--- Set the search text filter
-- @param console Console instance
-- @param text string Search query (empty string to clear)
function M.set_search(console, text)
  if not console then
    error("Console.set_search() requires console instance")
  end
  console.search_text = text or ""
end

--- Get the current search text
-- @param console Console instance
-- @return string Current search query
function M.get_search(console)
  if not console then
    error("Console.get_search() requires console instance")
  end
  return console.search_text
end

--- Pause log updates (logs still accumulate but aren't displayed)
-- @param console Console instance
function M.pause(console)
  if not console then
    error("Console.pause() requires console instance")
  end
  console.paused = true
end

--- Resume log updates
-- @param console Console instance
function M.resume(console)
  if not console then
    error("Console.resume() requires console instance")
  end
  console.paused = false
end

--- Toggle pause state
-- @param console Console instance
function M.toggle_pause(console)
  if not console then
    error("Console.toggle_pause() requires console instance")
  end
  console.paused = not console.paused
end

--- Check if console is paused
-- @param console Console instance
-- @return boolean True if paused
function M.is_paused(console)
  if not console then
    error("Console.is_paused() requires console instance")
  end
  return console.paused
end

--- Get current FPS
-- @param console Console instance
-- @return number Current frames per second
function M.get_fps(console)
  if not console then
    error("Console.get_fps() requires console instance")
  end
  return console.fps
end

--- Get current frame time in milliseconds
-- @param console Console instance
-- @return number Frame time in ms
function M.get_frame_time(console)
  if not console then
    error("Console.get_frame_time() requires console instance")
  end
  return console.frame_time_ms
end

return M