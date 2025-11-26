-- @noindex
-- arkitekt/core/lookup.lua
-- Helper utilities for building bidirectional lookup tables
-- Provides O(1) reverse lookups for option arrays and constant tables

local M = {}

--- Build reverse lookup from array of objects
--- Maps one field to another for fast O(1) lookups
--- @param array table Array of objects with key/value fields
--- @param key_field string Field name to use as key in reverse table
--- @param value_field string Field name to use as value in reverse table
--- @return table Table mapping key_field values to value_field values
--- @usage
---   local options = {{ value = "4bar", label = "4 Bars" }, ...}
---   local by_label = Lookup.build_reverse_lookup(options, "label", "value")
---   local value = by_label["4 Bars"]  -- "4bar"
function M.build_reverse_lookup(array, key_field, value_field)
  if not array or type(array) ~= "table" then
    error("build_reverse_lookup: array parameter must be a table", 2)
  end
  if not key_field or type(key_field) ~= "string" then
    error("build_reverse_lookup: key_field must be a string", 2)
  end
  if not value_field or type(value_field) ~= "string" then
    error("build_reverse_lookup: value_field must be a string", 2)
  end

  local reverse = {}
  for _, item in ipairs(array) do
    if type(item) == "table" and item[key_field] ~= nil then
      reverse[item[key_field]] = item[value_field]
    end
  end
  return reverse
end

--- Build index lookup (key_field → entire object)
--- Maps a field value to the complete object for fast access
--- @param array table Array of objects
--- @param key_field string Field name to use as key
--- @return table Table mapping key_field values to complete objects
--- @usage
---   local options = {{ value = "4bar", label = "4 Bars", data = {...} }, ...}
---   local by_value = Lookup.build_index(options, "value")
---   local obj = by_value["4bar"]  -- { value = "4bar", label = "4 Bars", data = {...} }
function M.build_index(array, key_field)
  if not array or type(array) ~= "table" then
    error("build_index: array parameter must be a table", 2)
  end
  if not key_field or type(key_field) ~= "string" then
    error("build_index: key_field must be a string", 2)
  end

  local index = {}
  for _, item in ipairs(array) do
    if type(item) == "table" and item[key_field] ~= nil then
      index[item[key_field]] = item
    end
  end
  return index
end

--- Build bidirectional lookup (both directions)
--- Creates two tables for lookups in both directions
--- @param array table Array of objects
--- @param key1 string First field name
--- @param key2 string Second field name
--- @return table, table Forward lookup (key1 → key2) and reverse (key2 → key1)
--- @usage
---   local options = {{ value = "4bar", label = "4 Bars" }, ...}
---   local label_to_value, value_to_label = Lookup.build_bidirectional(options, "label", "value")
---   local value = label_to_value["4 Bars"]  -- "4bar"
---   local label = value_to_label["4bar"]    -- "4 Bars"
function M.build_bidirectional(array, key1, key2)
  if not array or type(array) ~= "table" then
    error("build_bidirectional: array parameter must be a table", 2)
  end
  if not key1 or type(key1) ~= "string" then
    error("build_bidirectional: key1 must be a string", 2)
  end
  if not key2 or type(key2) ~= "string" then
    error("build_bidirectional: key2 must be a string", 2)
  end

  local forward = {}
  local reverse = {}
  for _, item in ipairs(array) do
    if type(item) == "table" and item[key1] ~= nil and item[key2] ~= nil then
      forward[item[key1]] = item[key2]
      reverse[item[key2]] = item[key1]
    end
  end
  return forward, reverse
end

--- Build lookup from flat key-value table
--- Useful for simple constant mappings
--- @param tbl table Key-value pairs
--- @return table Reverse lookup (value → key)
--- @usage
---   local modes = { REGIONS = "regions", PLAYLISTS = "playlists" }
---   local reverse = Lookup.build_reverse(modes)
---   local key = reverse["regions"]  -- "REGIONS"
function M.build_reverse(tbl)
  if not tbl or type(tbl) ~= "table" then
    error("build_reverse: tbl parameter must be a table", 2)
  end

  local reverse = {}
  for k, v in pairs(tbl) do
    reverse[v] = k
  end
  return reverse
end

return M
