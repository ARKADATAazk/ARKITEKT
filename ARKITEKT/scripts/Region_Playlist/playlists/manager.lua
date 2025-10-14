local Base = require('rearkitekt.patterns.controller')

local M = setmetatable({}, { __index = Base })
M.__index = M

function M.new(state)
  local self = setmetatable({}, M)
  self.state = state
  return self
end

function M:create_playlist(name)
  return self:with_undo(function()
    -- TODO: implement playlist creation
  end)
end

function M:delete_playlist(id)
  return self:with_undo(function()
    -- TODO: implement playlist deletion
  end)
end

function M:add_item(pid, item)
  return self:with_undo(function()
    -- TODO: implement adding an item to a playlist
  end)
end

function M:reorder_items(pid, order)
  return self:with_undo(function()
    -- TODO: implement reordering playlist items
  end)
end

return M
