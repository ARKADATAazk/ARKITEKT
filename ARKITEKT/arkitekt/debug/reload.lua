-- @noindex
-- arkitekt/debug/reload.lua
-- Hot reload module for development-time code reloading

local M = {}

--- Reload modules matching patterns by clearing them from package.loaded
--- @param patterns string[] Lua patterns to match against package.loaded keys
--- @param on_reload? function Callback after clearing, before re-require
--- @return number count Number of modules cleared
--- @return string[] cleared List of cleared module names
function M.reload(patterns, on_reload)
  local cleared = {}

  for key in pairs(package.loaded) do
    for _, pattern in ipairs(patterns) do
      if key:match(pattern) then
        package.loaded[key] = nil
        cleared[#cleared + 1] = key
        break
      end
    end
  end

  -- Sort for consistent output
  table.sort(cleared)

  if on_reload then
    on_reload(cleared)
  end

  return #cleared, cleared
end

--- Get default reload patterns for an app
--- Targets UI layers that are safe to reload
--- @param app_name string e.g., 'ItemPicker'
--- @return string[] patterns
function M.default_patterns(app_name)
  -- Escape any special pattern characters in app name
  local safe_name = app_name:gsub('([%^%$%(%)%%%.%[%]%*%+%-%?])', '%%%1')

  -- Reload ALL modules for this app (simpler, catches everything)
  return {
    '^' .. safe_name .. '%.',  -- Matches AppName.anything
  }
end

--- Reload all arkitekt GUI widgets (for framework development)
--- @return number count Number of modules cleared
function M.reload_arkitekt_widgets()
  return M.reload({
    '^arkitekt%.gui%.widgets',
    '^arkitekt%.gui%.draw',
    '^arkitekt%.gui%.renderers',
  })
end

--- Get list of currently loaded modules matching pattern
--- Useful for debugging what will be reloaded
--- @param pattern string Lua pattern
--- @return string[] modules
function M.list_loaded(pattern)
  local matches = {}
  for key in pairs(package.loaded) do
    if key:match(pattern) then
      matches[#matches + 1] = key
    end
  end
  table.sort(matches)
  return matches
end

return M
