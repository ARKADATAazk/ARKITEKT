-- @noindex
-- rearkitekt/core/theme_storage.lua
-- JSON persistence for theme preferences

local M = {}

-- Get REAPER's data directory for global ARKITEKT settings
local function get_data_dir()
  local resource_path = reaper.GetResourcePath()
  local sep = package.config:sub(1,1)
  local data_dir = resource_path .. sep .. "Data" .. sep .. "ARKITEKT" .. sep .. "Global"

  -- Create directory if it doesn't exist
  if reaper.RecursiveCreateDirectory then
    reaper.RecursiveCreateDirectory(data_dir, 0)
  end

  return data_dir
end

-- Simple JSON encoder (minimal, just for settings)
local function json_encode(data)
  if type(data) == "table" then
    local parts = {}
    for k, v in pairs(data) do
      table.insert(parts, '"' .. k .. '": ' .. json_encode(v))
    end
    return "{\n  " .. table.concat(parts, ",\n  ") .. "\n}"
  elseif type(data) == "string" then
    return '"' .. data .. '"'
  elseif type(data) == "boolean" then
    return data and "true" or "false"
  else
    return tostring(data)
  end
end

-- Simple JSON decoder
local function json_decode(str)
  if not str or str == "" then return nil end

  local pos = 1

  local function skip_whitespace()
    while pos <= #str and str:sub(pos, pos):match("%s") do
      pos = pos + 1
    end
  end

  local function decode_value()
    skip_whitespace()
    local char = str:sub(pos, pos)

    if char == "{" then
      pos = pos + 1
      local obj = {}
      skip_whitespace()

      if str:sub(pos, pos) == "}" then
        pos = pos + 1
        return obj
      end

      while true do
        skip_whitespace()
        if str:sub(pos, pos) ~= '"' then break end
        pos = pos + 1
        local key_start = pos
        while pos <= #str and str:sub(pos, pos) ~= '"' do
          pos = pos + 1
        end
        local key = str:sub(key_start, pos - 1)
        pos = pos + 1

        skip_whitespace()
        if str:sub(pos, pos) ~= ":" then break end
        pos = pos + 1

        obj[key] = decode_value()

        skip_whitespace()
        char = str:sub(pos, pos)
        if char == "}" then
          pos = pos + 1
          return obj
        elseif char == "," then
          pos = pos + 1
        else
          break
        end
      end
      return obj

    elseif char == '"' then
      pos = pos + 1
      local str_start = pos
      while pos <= #str and str:sub(pos, pos) ~= '"' do
        pos = pos + 1
      end
      local value = str:sub(str_start, pos - 1)
      pos = pos + 1
      return value

    elseif char == "t" and str:sub(pos, pos + 3) == "true" then
      pos = pos + 4
      return true

    elseif char == "f" and str:sub(pos, pos + 4) == "false" then
      pos = pos + 5
      return false
    end

    return nil
  end

  local ok, result = pcall(decode_value)
  return ok and result or nil
end

-- Load settings from JSON
local function load_settings()
  local data_dir = get_data_dir()
  local sep = package.config:sub(1,1)
  local filepath = data_dir .. sep .. "settings.json"

  local file = io.open(filepath, "r")
  if not file then
    return {}
  end

  local content = file:read("*all")
  file:close()

  return json_decode(content) or {}
end

-- Save settings to JSON
local function save_settings(settings)
  local data_dir = get_data_dir()
  local sep = package.config:sub(1,1)
  local filepath = data_dir .. sep .. "settings.json"

  local file = io.open(filepath, "w")
  if not file then
    return false
  end

  file:write(json_encode(settings))
  file:close()
  return true
end

-- Get current theme preference
function M.get_theme()
  local settings = load_settings()
  return settings.theme or "default"
end

-- Set theme preference
function M.set_theme(theme_name)
  local settings = load_settings()
  settings.theme = theme_name
  return save_settings(settings)
end

return M
