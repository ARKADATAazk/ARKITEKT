-- @noindex
-- RegionPlaylist/domain/dependency.lua
-- Manages playlist dependency graph and circular reference detection

local Logger = require('arkitekt.debug.logger')

local M = {}

-- Set to true for verbose domain logging
local DEBUG_DOMAIN = false

--- Create a new dependency domain
--- @return table domain The dependency domain instance
function M.new()
  local domain = {
    graph = {},      -- Map: playlist_id -> {direct_deps, all_deps, is_disabled_for}
    dirty = true,    -- Flag to rebuild graph on next check
  }

  if DEBUG_DOMAIN then
    Logger.debug("DEPENDENCY", "Domain initialized")
  end

  --- Mark graph as dirty (needs rebuild)
  function domain:mark_dirty()
    self.dirty = true
    if DEBUG_DOMAIN then
      Logger.debug("DEPENDENCY", "Graph marked dirty")
    end
  end

  --- Rebuild dependency graph from playlists
  --- @param playlists table Array of playlist objects
  function domain:rebuild(playlists)
    self.graph = {}

    -- Build direct dependencies
    for _, pl in ipairs(playlists) do
      self.graph[pl.id] = {
        direct_deps = {},
        all_deps = {},
        is_disabled_for = {}
      }

      for _, item in ipairs(pl.items) do
        if item.type == "playlist" and item.playlist_id then
          self.graph[pl.id].direct_deps[#self.graph[pl.id].direct_deps + 1] = item.playlist_id
        end
      end
    end

    -- Build transitive dependencies
    for _, pl in ipairs(playlists) do
      local all_deps = {}
      local visited = {}

      local function collect_deps(pid)
        if visited[pid] then return end
        visited[pid] = true

        local node = self.graph[pid]
        if not node then return end

        for _, dep_id in ipairs(node.direct_deps) do
          all_deps[dep_id] = true
          collect_deps(dep_id)
        end
      end

      collect_deps(pl.id)
      self.graph[pl.id].all_deps = all_deps
    end

    -- Build disabled-for relationships
    for target_id, target_node in pairs(self.graph) do
      for source_id, source_node in pairs(self.graph) do
        if target_id ~= source_id then
          if source_node.all_deps[target_id] or target_id == source_id then
            target_node.is_disabled_for[source_id] = true
          end
        end
      end
    end

    self.dirty = false
    if DEBUG_DOMAIN then
      Logger.debug("DEPENDENCY", "Graph rebuilt: %d playlists", #playlists)
    end
  end

  --- Ensure graph is fresh (rebuild if dirty)
  --- @param playlists table Array of playlist objects
  function domain:ensure_fresh(playlists)
    if self.dirty then
      self:rebuild(playlists)
    end
  end

  --- Check if playlist is draggable to target
  --- @param playlist_id string Source playlist ID
  --- @param target_playlist_id string Target playlist ID
  --- @return boolean draggable True if can be dragged
  function domain:is_draggable_to(playlist_id, target_playlist_id)
    if playlist_id == target_playlist_id then
      return false
    end

    local target_node = self.graph[target_playlist_id]
    if not target_node then
      return true
    end

    if target_node.is_disabled_for[playlist_id] then
      return false
    end

    local playlist_node = self.graph[playlist_id]
    if not playlist_node then
      return true
    end

    if playlist_node.all_deps[target_playlist_id] then
      return false
    end

    return true
  end

  --- Detect circular reference
  --- @param target_playlist_id string Target playlist ID
  --- @param playlist_id_to_add string Playlist ID being added
  --- @return boolean has_cycle True if would create cycle
  --- @return table|nil path Array of IDs in cycle path
  function domain:detect_circular_reference(target_playlist_id, playlist_id_to_add)
    if target_playlist_id == playlist_id_to_add then
      return true, {target_playlist_id}
    end

    local target_node = self.graph[target_playlist_id]
    if target_node and target_node.is_disabled_for[playlist_id_to_add] then
      return true, {playlist_id_to_add, target_playlist_id}
    end

    local playlist_node = self.graph[playlist_id_to_add]
    if playlist_node and playlist_node.all_deps[target_playlist_id] then
      local path = {playlist_id_to_add}

      local function build_path(from_id, to_id, current_path)
        if from_id == to_id then
          return current_path
        end

        local node = self.graph[from_id]
        if not node then return nil end

        for _, dep_id in ipairs(node.direct_deps) do
          if not current_path[dep_id] then
            local new_path = {}
            for k, v in pairs(current_path) do new_path[k] = v end
            new_path[dep_id] = true

            local result = build_path(dep_id, to_id, new_path)
            if result then
              return result
            end
          end
        end

        return nil
      end

      local path_set = {[playlist_id_to_add] = true}
      local full_path_set = build_path(playlist_id_to_add, target_playlist_id, path_set)

      if full_path_set then
        local path_array = {}
        for pid in pairs(full_path_set) do
          path_array[#path_array + 1] = pid
        end
        path_array[#path_array + 1] = target_playlist_id
        return true, path_array
      end

      return true, {playlist_id_to_add, "...", target_playlist_id}
    end

    return false
  end

  return domain
end

return M
