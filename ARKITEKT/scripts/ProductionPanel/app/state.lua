-- @noindex
-- ProductionPanel/app/state.lua
-- Application state management

local M = {}

-- Private state
local state = {
  initialized = false,
  settings = nil,
}

---Initialize state with settings
---@param settings table Settings instance
function M.initialize(settings)
  if state.initialized then return end

  state.settings = settings

  -- Load saved state
  -- TODO: Load macro mappings, drum kit, etc.

  state.initialized = true
end

---Save current state
function M.save()
  if state.settings then
    -- TODO: Save macro mappings, drum kit, etc.
    state.settings:save()
  end
end

---Cleanup on close
function M.cleanup()
  M.save()
end

return M
