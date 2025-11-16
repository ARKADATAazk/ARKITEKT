-- @noindex
-- TemplateBrowser/domain/persistence.lua
-- JSON persistence for tags, notes, and UUIDs

local M = {}

-- Get REAPER's data directory
local function get_data_dir()
  local resource_path = reaper.GetResourcePath()
  local sep = package.config:sub(1,1)
  local data_dir = resource_path .. sep .. "Data" .. sep .. "ARKITEKT" .. sep .. "TemplateBrowser"

  -- Create directory if it doesn't exist
  local has_lfs, lfs = pcall(require, "lfs")
  if has_lfs then
    lfs.mkdir(resource_path .. sep .. "Data")
    lfs.mkdir(resource_path .. sep .. "Data" .. sep .. "ARKITEKT")
    lfs.mkdir(data_dir)
  end

  return data_dir
end

-- Generate a UUID
local function generate_uuid()
  local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
  return string.gsub(template, '[xy]', function (c)
    local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
    return string.format('%x', v)
  end)
end

M.generate_uuid = generate_uuid

-- Simple JSON encoder
local function json_encode(data)
  if type(data) == "table" then
    local is_array = #data > 0
    local parts = {}

    if is_array then
      for i, v in ipairs(data) do
        table.insert(parts, json_encode(v))
      end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      for k, v in pairs(data) do
        table.insert(parts, '"' .. k .. '":' .. json_encode(v))
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  elseif type(data) == "string" then
    -- Basic escaping
    data = data:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n')
    return '"' .. data .. '"'
  elseif type(data) == "number" then
    return tostring(data)
  elseif type(data) == "boolean" then
    return data and "true" or "false"
  else
    return "null"
  end
end

-- Simple JSON decoder
local function json_decode(str)
  if not str or str == "" then return nil end

  -- Try using built-in JSON if available
  local has_json, json = pcall(require, "json")
  if has_json and json.decode then
    local ok, result = pcall(json.decode, str)
    if ok then return result end
  end

  -- Fallback: basic manual parsing (only for simple cases)
  -- This is a very basic implementation, good enough for our needs
  str = str:gsub("^%s*", ""):gsub("%s*$", "")

  if str:sub(1,1) == "{" then
    local result = {}
    -- Very basic object parsing
    for key, value in str:gmatch('"([^"]+)"%s*:%s*"([^"]*)"') do
      result[key] = value
    end
    for key, value in str:gmatch('"([^"]+)"%s*:%s*([%d%.]+)') do
      result[key] = tonumber(value)
    end
    for key in str:gmatch('"([^"]+)"%s*:%s*%[') do
      result[key] = {}
    end
    return result
  end

  return {}
end

-- Save data to JSON file
function M.save_json(filename, data)
  local data_dir = get_data_dir()
  local sep = package.config:sub(1,1)
  local filepath = data_dir .. sep .. filename

  local file = io.open(filepath, "w")
  if not file then
    reaper.ShowConsoleMsg("ERROR: Failed to save: " .. filepath .. "\n")
    return false
  end

  local json_str = json_encode(data)
  file:write(json_str)
  file:close()

  reaper.ShowConsoleMsg("Saved: " .. filepath .. "\n")
  return true
end

-- Load data from JSON file
function M.load_json(filename)
  local data_dir = get_data_dir()
  local sep = package.config:sub(1,1)
  local filepath = data_dir .. sep .. filename

  local file = io.open(filepath, "r")
  if not file then
    reaper.ShowConsoleMsg("No existing data: " .. filepath .. "\n")
    return nil
  end

  local content = file:read("*all")
  file:close()

  local data = json_decode(content)
  reaper.ShowConsoleMsg("Loaded: " .. filepath .. "\n")
  return data
end

-- Data structure for template metadata
-- {
--   templates = {
--     [uuid] = {
--       uuid = "...",
--       name = "Template Name",
--       path = "relative/path",
--       tags = {"tag1", "tag2"},
--       notes = "Some notes",
--       last_seen = timestamp
--     }
--   },
--   folders = {
--     [uuid] = {
--       uuid = "...",
--       name = "Folder Name",
--       path = "relative/path",
--       tags = {"tag1"},
--       last_seen = timestamp
--     }
--   },
--   tags = {
--     "tag1" = {
--       name = "Tag Name",
--       color = 0xFF0000FF,
--       created = timestamp
--     }
--   }
-- }

-- Load template metadata
function M.load_metadata()
  return M.load_json("metadata.json") or {
    templates = {},
    folders = {},
    tags = {}
  }
end

-- Save template metadata
function M.save_metadata(metadata)
  return M.save_json("metadata.json", metadata)
end

-- Find template by UUID or fallback to name
function M.find_template(metadata, uuid, name, path)
  -- Try UUID first
  if uuid and metadata.templates[uuid] then
    return metadata.templates[uuid]
  end

  -- Fallback: search by name and path
  for _, tmpl in pairs(metadata.templates) do
    if tmpl.name == name and tmpl.path == path then
      return tmpl
    end
  end

  return nil
end

-- Find folder by UUID or fallback to name
function M.find_folder(metadata, uuid, name, path)
  -- Try UUID first
  if uuid and metadata.folders[uuid] then
    return metadata.folders[uuid]
  end

  -- Fallback: search by name and path
  for _, fld in pairs(metadata.folders) do
    if fld.name == name and fld.path == path then
      return fld
    end
  end

  return nil
end

return M
