-- @noindex
-- arkitekt/debug/console.lua
-- Visual debug console widget - Public API
-- Now with ColoredTextView for native selection support

local ConsoleWidget = require('arkitekt.debug._console_widget')

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
-- @param level string One of: "All", "INFO", "DEBUG", "WARN", "ERROR", "PROFILE"
function M.set_level_filter(console, level)
  if not console then
    error("Console.set_level_filter() requires console instance")
  end
  local valid = {All=true, INFO=true, DEBUG=true, WARN=true, ERROR=true, PROFILE=true}
  if not valid[level] then
    error("Invalid filter level: " .. tostring(level))
  end
  console.filter_category = level
  console:update_text_view()
end

--- Get the current level filter
-- @param console Console instance
-- @return string Current filter level
function M.get_level_filter(console)
  if not console then
    error("Console.get_level_filter() requires console instance")
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
  console:update_text_view()
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

--- Copy current selection to clipboard
-- @param console Console instance
-- @return boolean True if selection was copied
function M.copy_selection(console)
  if not console then
    error("Console.copy_selection() requires console instance")
  end
  return console.text_view:copy()
end

--- Select all text
-- @param console Console instance
function M.select_all(console)
  if not console then
    error("Console.select_all() requires console instance")
  end
  console.text_view:select_all()
end

--- Check if there is a selection
-- @param console Console instance
-- @return boolean True if text is selected
function M.has_selection(console)
  if not console then
    error("Console.has_selection() requires console instance")
  end
  return console.text_view:has_selection()
end

--- Get selected text
-- @param console Console instance
-- @return string Selected text or empty string
function M.get_selected_text(console)
  if not console then
    error("Console.get_selected_text() requires console instance")
  end
  return console.text_view:get_selected_text()
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