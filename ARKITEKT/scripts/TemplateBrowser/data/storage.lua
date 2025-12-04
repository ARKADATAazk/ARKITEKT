-- @noindex
-- TemplateBrowser/data/storage.lua
-- JSON persistence for tags, notes, and UUIDs

local Logger = require('arkitekt.debug.logger')
local UUID = require('arkitekt.core.uuid')
local JSON = require('arkitekt.core.json')

local M = {}

-- Get REAPER's data directory
local function get_data_dir()
  local resource_path = reaper.GetResourcePath()
  local sep = package.config:sub(1,1)
  local data_dir = resource_path .. sep .. 'Data' .. sep .. 'ARKITEKT' .. sep .. 'TemplateBrowser'

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
    local log_path = data_dir .. sep .. 'debug.log'
    log_file_handle = io.open(log_path, 'w')  -- Overwrite on first open
    if log_file_handle then
      log_file_handle:write('=== TemplateBrowser Debug Log ===\n')
      log_file_handle:write(os.date('%Y-%m-%d %H:%M:%S') .. '\n\n')
    end
  end

  if log_file_handle then
    log_file_handle:write(message .. '\n')
    log_file_handle:flush()  -- Ensure it's written immediately
  end

  -- Also log to Logger
  Logger.debug('STORAGE', '%s', message)
end

function M.close_log()
  if log_file_handle then
    log_file_handle:close()
    log_file_handle = nil
  end
end

M.generate_uuid = UUID.generate

-- Save data to JSON file
function M.save_json(filename, data)
  local data_dir = get_data_dir()
  local sep = package.config:sub(1,1)
  local filepath = data_dir .. sep .. filename

  -- Ensure directory exists
  if reaper.RecursiveCreateDirectory then
    reaper.RecursiveCreateDirectory(data_dir, 0)
  end

  local file, err = io.open(filepath, 'w')
  if not file then
    Logger.error('STORAGE', 'Cannot write to: %s (%s)', filepath, tostring(err))
    return false
  end

  local json_str = JSON.encode(data, {pretty = true})
  local write_ok, write_err = file:write(json_str)
  if not write_ok then
    Logger.error('STORAGE', 'Write failed: %s', tostring(write_err))
    file:close()
    return false
  end

  file:close()
  return true
end

-- Load data from JSON file
function M.load_json(filename)
  local data_dir = get_data_dir()
  local sep = package.config:sub(1,1)
  local filepath = data_dir .. sep .. filename

  local file = io.open(filepath, 'r')
  if not file then
    return nil  -- No file is normal on first run
  end

  local content = file:read('*all')
  file:close()

  if not content or content == '' then
    return nil
  end

  local data = JSON.decode(content)
  if data then
    return data
  end

  -- JSON decode failed - file might be corrupted, delete and start fresh
  Logger.warn('STORAGE', 'JSON decode failed, deleting corrupt file: %s', filepath)
  os.remove(filepath)

  return nil
end

-- Data structure for template metadata
-- {
--   templates = {
--     [uuid] = {
--       uuid = '...',
--       name = 'Template Name',
--       path = 'relative/path',
--       tags = {'tag1', 'tag2'},
--       notes = 'Some notes',
--       last_seen = timestamp
--     }
--   },
--   folders = {
--     [uuid] = {
--       uuid = '...',
--       name = 'Folder Name',
--       path = 'relative/path',
--       tags = {'tag1'},
--       last_seen = timestamp
--     }
--   },
--   virtual_folders = {
--     [uuid] = {
--       id = 'uuid',
--       name = 'Virtual Folder Name',
--       parent_id = '__VIRTUAL_ROOT__' or parent virtual folder uuid,
--       template_refs = {'template-uuid-1', 'template-uuid-2'},
--       color = '#FF5733' (optional),
--       created = timestamp
--     }
--   },
--   tags = {
--     'tag1' = {
--       name = 'Tag Name',
--       color = 0xFF0000FF,
--       created = timestamp
--     }
--   }
-- }

-- Load template metadata
function M.load_metadata()
  local data = M.load_json('metadata.json')

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
  local favorites_id = '__FAVORITES__'
  if not data.virtual_folders[favorites_id] then
    data.virtual_folders[favorites_id] = {
      id = favorites_id,
      name = 'Favorites',
      parent_id = '__VIRTUAL_ROOT__',
      template_refs = {},
      is_system = true,  -- Mark as non-deletable system folder
      created = os.time(),
    }
    Logger.debug('STORAGE', 'Created default Favorites virtual folder')
  elseif not data.virtual_folders[favorites_id].is_system then
    -- Mark existing Favorites as system folder
    data.virtual_folders[favorites_id].is_system = true
  end

  return data
end

-- Save template metadata
function M.save_metadata(metadata)
  if not metadata then
    Logger.error('STORAGE', 'Cannot save nil metadata')
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

  return M.save_json('metadata.json', metadata)
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

-- Layout state persistence
-- Stores splitter positions and other UI layout preferences

function M.load_layout()
  return M.load_json('layout.json')
end

function M.save_layout(layout)
  if not layout then
    Logger.error('STORAGE', 'Cannot save nil layout')
    return false
  end
  return M.save_json('layout.json', layout)
end

return M
