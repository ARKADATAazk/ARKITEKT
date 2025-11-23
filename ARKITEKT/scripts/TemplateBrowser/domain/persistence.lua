-- @noindex
-- TemplateBrowser/domain/persistence.lua
-- JSON persistence for tags, notes, and UUIDs

local M = {}

-- Get REAPER's data directory
local function get_data_dir()
  local resource_path = reaper.GetResourcePath()
  local sep = package.config:sub(1,1)
  local data_dir = resource_path .. sep .. "Data" .. sep .. "ARKITEKT" .. sep .. "TemplateBrowser"

  -- Create directory if it doesn't exist using REAPER's API
  if reaper.RecursiveCreateDirectory then
    reaper.RecursiveCreateDirectory(data_dir, 0)
  end

  return data_dir
end

-- Log to file for debugging
local log_file_handle = nil
function M.log(message)
  if not log_file_handle then
    local data_dir = get_data_dir()
    local sep = package.config:sub(1,1)
    local log_path = data_dir .. sep .. "debug.log"
    log_file_handle = io.open(log_path, "w")  -- Overwrite on first open
    if log_file_handle then
      log_file_handle:write("=== TemplateBrowser Debug Log ===\n")
      log_file_handle:write(os.date("%Y-%m-%d %H:%M:%S") .. "\n\n")
    end
  end

  if log_file_handle then
    log_file_handle:write(message .. "\n")
    log_file_handle:flush()  -- Ensure it's written immediately
  end

  -- Also log to console
  reaper.ShowConsoleMsg(message .. "\n")
end

function M.close_log()
  if log_file_handle then
    log_file_handle:close()
    log_file_handle = nil
  end
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

-- Simple JSON encoder with pretty printing
local function json_encode(data, indent, current_indent)
  indent = indent or "  "  -- Default to 2 spaces
  current_indent = current_indent or ""

  if type(data) == "table" then
    local is_array = #data > 0
    local parts = {}
    local next_indent = current_indent .. indent

    if is_array then
      -- Array formatting
      if #data == 0 then
        return "[]"
      end
      for i, v in ipairs(data) do
        table.insert(parts, next_indent .. json_encode(v, indent, next_indent))
      end
      return "[\n" .. table.concat(parts, ",\n") .. "\n" .. current_indent .. "]"
    else
      -- Object formatting
      local count = 0
      for _ in pairs(data) do count = count + 1 end
      if count == 0 then
        return "{}"
      end

      -- Sort keys for consistent output
      local sorted_keys = {}
      for k in pairs(data) do
        table.insert(sorted_keys, k)
      end
      table.sort(sorted_keys)

      for _, k in ipairs(sorted_keys) do
        local v = data[k]
        table.insert(parts, next_indent .. '"' .. k .. '": ' .. json_encode(v, indent, next_indent))
      end
      return "{\n" .. table.concat(parts, ",\n") .. "\n" .. current_indent .. "}"
    end
  elseif type(data) == "string" then
    -- Basic escaping
    data = data:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
    return '"' .. data .. '"'
  elseif type(data) == "number" then
    return tostring(data)
  elseif type(data) == "boolean" then
    return data and "true" or "false"
  else
    return "null"
  end
end

-- Simple but functional JSON decoder
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
      -- Object
      pos = pos + 1
      local obj = {}
      skip_whitespace()

      if str:sub(pos, pos) == "}" then
        pos = pos + 1
        return obj
      end

      while true do
        skip_whitespace()

        -- Read key
        if str:sub(pos, pos) ~= '"' then break end
        pos = pos + 1
        local key_start = pos
        while pos <= #str and str:sub(pos, pos) ~= '"' do
          if str:sub(pos, pos) == '\\' then pos = pos + 1 end
          pos = pos + 1
        end
        local key = str:sub(key_start, pos - 1)
        pos = pos + 1

        skip_whitespace()
        if str:sub(pos, pos) ~= ":" then break end
        pos = pos + 1

        -- Read value
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

    elseif char == "[" then
      -- Array
      pos = pos + 1
      local arr = {}
      skip_whitespace()

      if str:sub(pos, pos) == "]" then
        pos = pos + 1
        return arr
      end

      while true do
        table.insert(arr, decode_value())
        skip_whitespace()
        char = str:sub(pos, pos)
        if char == "]" then
          pos = pos + 1
          return arr
        elseif char == "," then
          pos = pos + 1
        else
          break
        end
      end

      return arr

    elseif char == '"' then
      -- String
      pos = pos + 1
      local str_start = pos
      while pos <= #str do
        if str:sub(pos, pos) == '"' then
          local value = str:sub(str_start, pos - 1)
          -- Unescape
          value = value:gsub('\\(.)', function(c)
            if c == 'n' then return '\n'
            elseif c == 'r' then return '\r'
            elseif c == 't' then return '\t'
            else return c end
          end)
          pos = pos + 1
          return value
        elseif str:sub(pos, pos) == '\\' then
          pos = pos + 2
        else
          pos = pos + 1
        end
      end
      return ""

    elseif char == "t" and str:sub(pos, pos + 3) == "true" then
      pos = pos + 4
      return true

    elseif char == "f" and str:sub(pos, pos + 4) == "false" then
      pos = pos + 5
      return false

    elseif char == "n" and str:sub(pos, pos + 3) == "null" then
      pos = pos + 4
      return nil

    else
      -- Number
      local num_start = pos
      if char == "-" then pos = pos + 1 end
      while pos <= #str and str:sub(pos, pos):match("[%d%.]") do
        pos = pos + 1
      end
      local num_str = str:sub(num_start, pos - 1)
      return tonumber(num_str)
    end
  end

  local ok, result = pcall(decode_value)
  if ok then
    return result
  else
    M.log("ERROR: JSON decode failed: " .. tostring(result))
    return {}
  end
end

-- Save data to JSON file
function M.save_json(filename, data)
  local data_dir = get_data_dir()
  local sep = package.config:sub(1,1)
  local filepath = data_dir .. sep .. filename

  -- Ensure directory exists
  if reaper.RecursiveCreateDirectory then
    local success = reaper.RecursiveCreateDirectory(data_dir, 0)
    if not success then
      reaper.ShowConsoleMsg("ERROR: Failed to create directory: " .. data_dir .. "\n")
    end
  end

  local file, err = io.open(filepath, "w")
  if not file then
    reaper.ShowConsoleMsg("ERROR: Failed to open file for writing: " .. filepath .. "\n")
    if err then
      reaper.ShowConsoleMsg("ERROR: " .. err .. "\n")
    end
    return false
  end

  local json_str = json_encode(data)
  local write_ok, write_err = file:write(json_str)
  if not write_ok then
    reaper.ShowConsoleMsg("ERROR: Failed to write data: " .. tostring(write_err) .. "\n")
    file:close()
    return false
  end

  file:close()

  reaper.ShowConsoleMsg("Saved metadata: " .. filepath .. "\n")
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
--   virtual_folders = {
--     [uuid] = {
--       id = "uuid",
--       name = "Virtual Folder Name",
--       parent_id = "__VIRTUAL_ROOT__" or parent virtual folder uuid,
--       template_refs = {"template-uuid-1", "template-uuid-2"},
--       color = "#FF5733" (optional),
--       created = timestamp
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
  local data = M.load_json("metadata.json")

  -- Ensure structure exists
  if not data then
    data = {}
  end

  if not data.templates then
    data.templates = {}
  end

  if not data.folders then
    data.folders = {}
  end

  if not data.virtual_folders then
    data.virtual_folders = {}
  end

  if not data.tags then
    data.tags = {}
  end

  -- Ensure Favorites virtual folder exists (non-deletable)
  local favorites_id = "__FAVORITES__"
  if not data.virtual_folders[favorites_id] then
    data.virtual_folders[favorites_id] = {
      id = favorites_id,
      name = "Favorites",
      parent_id = "__VIRTUAL_ROOT__",
      template_refs = {},
      is_system = true,  -- Mark as non-deletable system folder
      created = os.time(),
    }
    reaper.ShowConsoleMsg("Created default Favorites virtual folder\n")
  elseif not data.virtual_folders[favorites_id].is_system then
    -- Mark existing Favorites as system folder
    data.virtual_folders[favorites_id].is_system = true
  end

  return data
end

-- Save template metadata
function M.save_metadata(metadata)
  if not metadata then
    reaper.ShowConsoleMsg("ERROR: Cannot save nil metadata\n")
    return false
  end

  -- Ensure structure exists before saving
  if not metadata.templates then
    metadata.templates = {}
  end

  if not metadata.folders then
    metadata.folders = {}
  end

  if not metadata.virtual_folders then
    metadata.virtual_folders = {}
  end

  if not metadata.tags then
    metadata.tags = {}
  end

  return M.save_json("metadata.json", metadata)
end

-- Find template by UUID or fallback to name
function M.find_template(metadata, uuid, name, path)
  -- Ensure metadata has templates table
  if not metadata or not metadata.templates then
    return nil
  end

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

  -- Debug: log first failed lookup
  if not M._logged_first_miss then
    M._logged_first_miss = true
    M.log("DEBUG find_template: Looking for name='" .. tostring(name) .. "', path='" .. tostring(path) .. "'")

    -- Show first 5 templates from metadata for comparison
    local count = 0
    for _, tmpl in pairs(metadata.templates) do
      if count < 5 then
        M.log("  Metadata has: name='" .. tostring(tmpl.name) .. "', path='" .. tostring(tmpl.path) .. "'")
        count = count + 1
      else
        break
      end
    end
  end

  return nil
end

-- Find folder by UUID or fallback to name
function M.find_folder(metadata, uuid, name, path)
  -- Ensure metadata has folders table
  if not metadata or not metadata.folders then
    return nil
  end

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

-- Find virtual folder by ID
function M.find_virtual_folder(metadata, id)
  if not metadata or not metadata.virtual_folders then
    return nil
  end

  return metadata.virtual_folders[id]
end

return M
