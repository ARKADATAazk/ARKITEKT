-- @noindex
-- MIDIHelix/app/state.lua
-- Application state management

local M = {}

function M.new(Ark)
  local self = {
    Ark = Ark,
    current_view = "euclidean",  -- For future expansion
  }

  return setmetatable(self, { __index = M })
end

--- Initialize app state
function M:init()
  -- Future: load settings, initialize modules
end

--- Get current active view
function M:get_current_view()
  return self.current_view
end

return M
