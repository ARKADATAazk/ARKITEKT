-- @noindex
-- arkitekt/core/tree_expander.lua
-- Generic tree/nested structure expander with loop/repetition support
-- Extracted from RegionPlaylist sequence_expander for broader reuse
-- Useful for: nested playlists, folder hierarchies, command chains, etc.

local M = {}

--- Normalize loop count to valid integer >= 1
--- @param value any Value to normalize
--- @return number loops Normalized loop count (minimum 1)
local function normalize_loops(value)
  local reps = tonumber(value) or 1
  if reps < 1 then
    return 1
  end
  return math.floor(reps)
end

--- Expand a tree structure into a flat sequence
--- @param root any The root node to expand
--- @param config table Configuration
---   - get_children: function(node) -> array Get children of a node
---   - is_leaf: function(node) -> boolean Check if node is a leaf
---   - get_repetitions: function(node) -> number Get repetition count (default: 1)
---   - is_enabled: function(node) -> boolean Check if node is enabled (default: true)
---   - get_key: function(node) -> any Get unique key for node
---   - get_type: function(node) -> string Get node type (for mixed structures)
---   - get_value: function(node) -> any Extract value from leaf node
---   - lookup_child: function(child_id) -> node Lookup child node by ID (for references)
---   - detect_cycles: boolean Enable cycle detection (default: true)
--- @return any[] sequence Flat array of expanded entries
--- @return table range_map Map of node keys to {start_idx, end_idx}
function M.expand(root, config)
  -- Validate config
  if not config.get_children then
    error("tree_expander requires config.get_children function")
  end
  if not config.is_leaf then
    error("tree_expander requires config.is_leaf function")
  end

  -- Set defaults
  config.get_repetitions = config.get_repetitions or function() return 1 end
  config.is_enabled = config.is_enabled or function() return true end
  config.get_key = config.get_key or function(node) return tostring(node) end
  config.get_type = config.get_type or function() return "default" end
  config.get_value = config.get_value or function(node) return node end
  config.detect_cycles = config.detect_cycles ~= false

  local sequence = {}
  local range_map = {}
  local context = {
    stack = {},           -- For cycle detection
    cycle_detected = false,
  }

  --- Recursively expand items
  local function expand_items(items, parent_key)
    if not items then return end

    for _, item in ipairs(items) do
      if not item or not config.is_enabled(item) then
        goto continue
      end

      local item_key = config.get_key(item)
      local reps = normalize_loops(config.get_repetitions(item))

      if config.is_leaf(item) then
        -- Leaf node - add to sequence with repetitions
        local value = config.get_value(item)

        for loop_index = 1, reps do
          table.insert(sequence, {
            value = value,
            key = item_key,
            loop = loop_index,
            total_loops = reps,
            type = config.get_type(item),
          })
        end
      else
        -- Branch node - recursively expand
        -- First check for cycles
        if config.detect_cycles and context.stack[item_key] then
          context.cycle_detected = true
          goto continue
        end

        -- Get children
        local children = config.get_children(item)
        if not children or #children == 0 then
          goto continue
        end

        -- Mark start position
        local start_idx = #sequence + 1

        -- Save current range map state to identify nested ranges
        local map_snapshot = {}
        for k, v in pairs(range_map) do
          map_snapshot[k] = {start_idx = v.start_idx, end_idx = v.end_idx}
        end

        -- Expand children once
        context.stack[item_key] = true
        local child_sequence = {}
        local temp_sequence = sequence
        sequence = child_sequence

        expand_items(children, item_key)

        sequence = temp_sequence
        context.stack[item_key] = nil

        -- Identify new nested ranges
        local new_nested_ranges = {}
        for nested_key, nested_range in pairs(range_map) do
          if not map_snapshot[nested_key] then
            new_nested_ranges[nested_key] = {
              start_idx = nested_range.start_idx,
              end_idx = nested_range.end_idx,
            }
            range_map[nested_key] = nil  -- Will re-add with correct offset
          end
        end

        -- Repeat the expanded children
        for rep = 1, reps do
          local rep_start = #sequence + 1

          for _, entry in ipairs(child_sequence) do
            table.insert(sequence, {
              value = entry.value,
              key = entry.key,
              loop = entry.loop,
              total_loops = entry.total_loops,
              type = entry.type,
            })
          end

          local rep_end = #sequence

          -- Add nested ranges with proper offset
          for nested_key, nested_range in pairs(new_nested_ranges) do
            local offset = rep_start - 1
            local unique_key = (rep > 1) and (nested_key .. "_rep" .. rep) or nested_key
            range_map[unique_key] = {
              start_idx = nested_range.start_idx + offset,
              end_idx = nested_range.end_idx + offset,
            }
          end
        end

        -- Track the range this item occupies
        local end_idx = #sequence
        if item_key and start_idx > 0 and end_idx >= start_idx then
          range_map[item_key] = {
            start_idx = start_idx,
            end_idx = end_idx,
          }
        end
      end

      ::continue::
    end
  end

  -- Start expansion
  if root then
    local root_key = config.get_key(root)
    context.stack[root_key] = true
    local children = config.get_children(root)
    expand_items(children, root_key)
    context.stack[root_key] = nil
  end

  return sequence, range_map, context.cycle_detected
end

--- Expand a simple array with repetitions (no nesting)
--- Convenience function for flat structures
--- @param items any[] Array of items to expand
--- @param get_repetitions? function(item) -> number Get repetition count (default: 1)
--- @param get_key? function(item) -> any Get key (default: tostring)
--- @return any[] sequence Flat array with repetitions
function M.expand_flat(items, get_repetitions, get_key)
  get_repetitions = get_repetitions or function() return 1 end
  get_key = get_key or function(item) return tostring(item) end

  local config = {
    get_children = function() return {} end,
    is_leaf = function() return true end,
    get_repetitions = get_repetitions,
    get_key = get_key,
    get_value = function(item) return item end,
    detect_cycles = false,
  }

  local root = {items = items}
  local root_config = {
    get_children = function() return items end,
    is_leaf = function(item) return true end,
    get_repetitions = get_repetitions,
    get_key = get_key,
    get_value = function(item) return item end,
    detect_cycles = false,
  }

  local sequence = M.expand(root, root_config)
  return sequence
end

--- Calculate total count after expansion (without actually expanding)
--- Useful for progress bars or allocation
--- @param root any The root node
--- @param config table Same config as expand()
--- @return number count Total number of leaf entries after expansion
function M.count_expanded(root, config)
  local count = 0

  local function count_items(items, visited)
    if not items then return end

    for _, item in ipairs(items) do
      if not item or not (config.is_enabled and config.is_enabled(item) or true) then
        goto continue
      end

      local reps = normalize_loops(config.get_repetitions and config.get_repetitions(item) or 1)

      if config.is_leaf(item) then
        count = count + reps
      else
        local item_key = config.get_key and config.get_key(item) or tostring(item)
        if visited[item_key] then
          goto continue
        end

        visited[item_key] = true
        local children = config.get_children(item)

        -- Count children once, then multiply by reps
        local child_count_start = count
        count_items(children, visited)
        local child_count = count - child_count_start

        count = child_count_start + (child_count * reps)
        visited[item_key] = nil
      end

      ::continue::
    end
  end

  if root then
    local visited = {}
    local root_key = config.get_key and config.get_key(root) or tostring(root)
    visited[root_key] = true
    count_items(config.get_children(root), visited)
  end

  return count
end

return M
