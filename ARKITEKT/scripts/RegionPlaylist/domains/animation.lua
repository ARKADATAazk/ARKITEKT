-- @noindex
-- RegionPlaylist/domains/animation.lua
-- Manages UI animation queues (spawn, select, destroy)

local M = {}

--- Create a new animation domain
--- @return table domain The animation domain instance
function M.new()
  local domain = {
    pending_spawn = {},
    pending_select = {},
    pending_destroy = {},
  }

  --- Queue an item for spawn animation
  --- @param key string Item key
  function domain:queue_spawn(key)
    self.pending_spawn[#self.pending_spawn + 1] = key
  end

  --- Queue an item for select animation
  --- @param key string Item key
  function domain:queue_select(key)
    self.pending_select[#self.pending_select + 1] = key
  end

  --- Queue an item for destroy animation
  --- @param key string Item key
  function domain:queue_destroy(key)
    self.pending_destroy[#self.pending_destroy + 1] = key
  end

  --- Get pending spawn queue
  --- @return table Array of keys pending spawn animation
  function domain:get_pending_spawn()
    return self.pending_spawn
  end

  --- Get pending select queue
  --- @return table Array of keys pending select animation
  function domain:get_pending_select()
    return self.pending_select
  end

  --- Get pending destroy queue
  --- @return table Array of keys pending destroy animation
  function domain:get_pending_destroy()
    return self.pending_destroy
  end

  --- Clear all pending animations
  function domain:clear_all()
    self.pending_spawn = {}
    self.pending_select = {}
    self.pending_destroy = {}
  end

  return domain
end

return M
