-- @noindex
-- arkitekt/core/dependency_graph.lua
-- Generic dependency graph with circular reference detection
-- Extracted from RegionPlaylist for reuse with any nested structures
-- Useful for: nested playlists, folder hierarchies, node graphs, etc.

local M = {}
local Graph = {}
Graph.__index = Graph

--- Create a new dependency graph
--- @return table graph The dependency graph object
function M.new()
  local self = setmetatable({
    nodes = {},        -- node_id -> { direct_deps = {}, all_deps = {}, is_disabled_for = {} }
    dirty = true,      -- Whether the graph needs rebuilding
  }, Graph)

  return self
end

--- Add a node with its direct dependencies
--- @param node_id any Unique identifier for this node
--- @param dependencies? any[] Array of node IDs that this node depends on
function Graph:add_node(node_id, dependencies)
  self.nodes[node_id] = {
    direct_deps = dependencies or {},
    all_deps = {},
    is_disabled_for = {},
  }
  self.dirty = true
end

--- Remove a node from the graph
--- @param node_id any The node ID to remove
function Graph:remove_node(node_id)
  self.nodes[node_id] = nil
  self.dirty = true
end

--- Update a node's direct dependencies
--- @param node_id any The node ID to update
--- @param dependencies any[] New array of direct dependencies
function Graph:update_dependencies(node_id, dependencies)
  if not self.nodes[node_id] then
    self:add_node(node_id, dependencies)
  else
    self.nodes[node_id].direct_deps = dependencies
    self.dirty = true
  end
end

--- Clear all nodes from the graph
function Graph:clear()
  self.nodes = {}
  self.dirty = true
end

--- Mark the graph as dirty (needs rebuild)
function Graph:mark_dirty()
  self.dirty = true
end

--- Rebuild the transitive closure and disabled relationships
--- Call this after adding/updating nodes before querying
function Graph:rebuild()
  -- Phase 1: Build transitive closure (all_deps)
  for node_id, node in pairs(self.nodes) do
    local all_deps = {}
    local visited = {}

    local function collect_deps(current_id)
      if visited[current_id] then return end
      visited[current_id] = true

      local current_node = self.nodes[current_id]
      if not current_node then return end

      for _, dep_id in ipairs(current_node.direct_deps) do
        all_deps[dep_id] = true
        collect_deps(dep_id)
      end
    end

    collect_deps(node_id)
    node.all_deps = all_deps
  end

  -- Phase 2: Build disabled relationships
  -- A node is "disabled for" another if adding it would create a cycle
  for target_id, target_node in pairs(self.nodes) do
    target_node.is_disabled_for = {}

    for source_id, source_node in pairs(self.nodes) do
      if target_id ~= source_id then
        -- Target is disabled for source if:
        -- 1. Source depends on target (would create immediate cycle)
        -- 2. Target equals source (self-reference)
        if source_node.all_deps[target_id] or target_id == source_id then
          target_node.is_disabled_for[source_id] = true
        end
      end
    end
  end

  self.dirty = false
end

--- Check if adding source_id to target_id would create a circular reference
--- @param target_id any The node that would receive the dependency
--- @param source_id any The node that would be added as a dependency
--- @return boolean circular True if this would create a cycle
--- @return any[]? path Array of node IDs showing the circular path
function Graph:would_create_cycle(target_id, source_id)
  if self.dirty then
    self:rebuild()
  end

  -- Self-reference is always circular
  if target_id == source_id then
    return true, {target_id}
  end

  -- Check if target is disabled for source
  local target_node = self.nodes[target_id]
  if target_node and target_node.is_disabled_for[source_id] then
    return true, {source_id, target_id}
  end

  -- Check if source already depends on target
  local source_node = self.nodes[source_id]
  if source_node and source_node.all_deps[target_id] then
    -- Try to build a path showing the cycle
    local path = self:_find_path(source_id, target_id)
    if path then
      table.insert(path, target_id)  -- Complete the cycle
      return true, path
    end
    return true, {source_id, "...", target_id}
  end

  return false
end

--- Check if it's safe to add source_id as a dependency of target_id
--- Alias for !would_create_cycle for clearer API
--- @param target_id any The node that would receive the dependency
--- @param source_id any The node to add as a dependency
--- @return boolean safe True if safe to add (no cycle)
function Graph:is_safe_to_add(target_id, source_id)
  local would_cycle = self:would_create_cycle(target_id, source_id)
  return not would_cycle
end

--- Get all direct dependencies of a node
--- @param node_id any The node ID to query
--- @return any[] dependencies Array of direct dependency IDs
function Graph:get_direct_dependencies(node_id)
  local node = self.nodes[node_id]
  if not node then return {} end
  return node.direct_deps
end

--- Get all transitive dependencies of a node (full closure)
--- @param node_id any The node ID to query
--- @return table dependencies Map of all dependency IDs (keys are IDs, values are true)
function Graph:get_all_dependencies(node_id)
  if self.dirty then
    self:rebuild()
  end

  local node = self.nodes[node_id]
  if not node then return {} end
  return node.all_deps
end

--- Get all nodes that depend on this node (reverse lookup)
--- @param node_id any The node ID to query
--- @return any[] dependents Array of node IDs that depend on this node
function Graph:get_dependents(node_id)
  if self.dirty then
    self:rebuild()
  end

  local dependents = {}
  for other_id, other_node in pairs(self.nodes) do
    if other_node.all_deps[node_id] then
      table.insert(dependents, other_id)
    end
  end

  return dependents
end

--- Internal: Find a path from start to target using BFS with parent pointers
--- Uses O(n) memory instead of O(n²) by reconstructing path at the end
--- @param start_id any Starting node
--- @param target_id any Target node
--- @return any[]? path Array of node IDs forming the path, or nil if no path
function Graph:_find_path(start_id, target_id)
  local queue = {start_id}
  local head, tail = 1, 1
  local parent = {[start_id] = start_id}  -- Maps node -> parent (start points to itself)

  while head <= tail do
    local current_id = queue[head]
    head = head + 1

    local node = self.nodes[current_id]
    if not node then goto continue end

    for _, dep_id in ipairs(node.direct_deps) do
      if dep_id == target_id then
        -- Found target - reconstruct path from parent pointers
        local path = {}
        local p = current_id
        while p ~= start_id do
          table.insert(path, 1, p)
          p = parent[p]
        end
        table.insert(path, 1, start_id)
        return path
      end

      if not parent[dep_id] then
        parent[dep_id] = current_id
        tail = tail + 1
        queue[tail] = dep_id
      end
    end

    ::continue::
  end

  return nil
end

--- Get a topological sort of the graph (dependencies before dependents)
--- Returns nil if the graph contains cycles
--- @return any[]? sorted_ids Array of node IDs in topological order, or nil if cyclic
function Graph:topological_sort()
  if self.dirty then
    self:rebuild()
  end

  local sorted = {}
  local visited = {}
  local in_stack = {}

  local function visit(node_id)
    if visited[node_id] then return true end
    if in_stack[node_id] then return false end  -- Cycle detected

    in_stack[node_id] = true
    local node = self.nodes[node_id]

    if node then
      for _, dep_id in ipairs(node.direct_deps) do
        if not visit(dep_id) then
          return false  -- Cycle detected in recursion
        end
      end
    end

    in_stack[node_id] = nil
    visited[node_id] = true
    table.insert(sorted, 1, node_id)  -- Prepend (reverse postorder)
    return true
  end

  for node_id in pairs(self.nodes) do
    if not visited[node_id] then
      if not visit(node_id) then
        return nil  -- Cycle detected
      end
    end
  end

  return sorted
end

--- Check if the graph contains any cycles
--- @return boolean has_cycles True if graph contains cycles
function Graph:has_cycles()
  return self:topological_sort() == nil
end

--- Get statistics about the graph
--- @return table stats { node_count, edge_count, has_cycles }
function Graph:get_stats()
  if self.dirty then
    self:rebuild()
  end

  local edge_count = 0
  for _, node in pairs(self.nodes) do
    edge_count = edge_count + #node.direct_deps
  end

  local node_count = 0
  for _ in pairs(self.nodes) do
    node_count = node_count + 1
  end

  return {
    node_count = node_count,
    edge_count = edge_count,
    has_cycles = self:has_cycles(),
  }
end

return M
