-- @noindex
-- arkitekt/reaper/project_state.lua
-- Simplified project ExtState persistence with automatic JSON encoding/decoding
-- Extracted from RegionPlaylist for reuse across scripts

local JSON = require('arkitekt.core.json')
local Logger = require('arkitekt.debug.logger')

local M = {}

--- Creates a new project state storage manager
--- @param section string The ExtState section name (e.g., "ARK_MYAPP")
--- @param proj? number Project number (default: 0 = current project)
--- @return table Storage manager with save/load methods
function M.new(section, proj)
  if not section or section == "" then
    error("ProjectState requires a non-empty section name")
  end

  local storage = {
    section = section,
    proj = proj or 0,
  }

  --- Save data to project ExtState with automatic JSON encoding
  --- @param key string The key to store under
  --- @param data any The data to save (will be JSON encoded)
  function storage:save(key, data)
    local json_str = JSON.encode(data)
    reaper.SetProjExtState(self.proj, self.section, key, json_str)
  end

  --- Load data from project ExtState with automatic JSON decoding
  --- @param key string The key to load from
  --- @param default? any Default value if key doesn't exist (default: nil)
  --- @return any The loaded data, or default if not found
  function storage:load(key, default)
    local ok, json_str = reaper.GetProjExtState(self.proj, self.section, key)
    if ok ~= 1 or not json_str or json_str == "" then
      return default
    end

    local success, data = pcall(JSON.decode, json_str)
    if not success then
      return default
    end

    return data or default
  end

  --- Check if a key exists in project ExtState
  --- @param key string The key to check
  --- @return boolean True if key exists and has non-empty value
  function storage:exists(key)
    local ok, value = reaper.GetProjExtState(self.proj, self.section, key)
    return ok == 1 and value and value ~= ""
  end

  --- Delete a specific key from project ExtState
  --- @param key string The key to delete
  function storage:delete(key)
    reaper.SetProjExtState(self.proj, self.section, key, "")
  end

  --- Clear all keys in this section
  function storage:clear_all()
    -- REAPER doesn't provide a way to enumerate keys, so we can't truly clear all
    -- Instead, we document common keys and let the caller specify them
    -- Or we could use a manifest key that tracks all keys used
    Logger.warn("STORAGE", "ProjectState.clear_all() requires manual key specification")
  end

  --- Get the section name
  --- @return string The ExtState section name
  function storage:get_section()
    return self.section
  end

  --- Get the project number
  --- @return number The project number
  function storage:get_project()
    return self.proj
  end

  return storage
end

--- Convenience function: Save directly without creating storage object
--- @param section string ExtState section name
--- @param key string Key to save under
--- @param data any Data to save
--- @param proj? number Project number (default: 0)
function M.save(section, key, data, proj)
  local storage = M.new(section, proj)
  storage:save(key, data)
end

--- Convenience function: Load directly without creating storage object
--- @param section string ExtState section name
--- @param key string Key to load from
--- @param default? any Default value if not found
--- @param proj? number Project number (default: 0)
--- @return any The loaded data or default
function M.load(section, key, default, proj)
  local storage = M.new(section, proj)
  return storage:load(key, default)
end

--- Convenience function: Check if key exists
--- @param section string ExtState section name
--- @param key string Key to check
--- @param proj? number Project number (default: 0)
--- @return boolean True if key exists
function M.exists(section, key, proj)
  local storage = M.new(section, proj)
  return storage:exists(key)
end

return M
