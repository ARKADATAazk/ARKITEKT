-- @noindex
-- ThemeAdjuster/app/init.lua
-- Application initialization and bootstrap module

local Settings = require('arkitekt.core.settings')
local State = require('ThemeAdjuster.app.state')
local ThemeParams = require('ThemeAdjuster.domain.theme.params')
local Logger = require('arkitekt.debug.logger')

local log = Logger.new('ThemeAdjuster.Init')

local M = {}

-- Module state
local _initialized = false
local _settings = nil

-- Initialize the application with optional ark bootstrap reference
function M.initialize(ark_bootstrap)
  if _initialized then
    log:debug('Already initialized, skipping')
    return _settings
  end

  log:info('Initializing ThemeAdjuster')

  -- Get data directory for settings
  local data_dir
  if ark_bootstrap and ark_bootstrap.get_data_dir then
    data_dir = ark_bootstrap.get_data_dir('ThemeAdjuster')
  else
    -- Fallback: use script directory
    local sep = package.config:sub(1,1)
    local src = debug.getinfo(1, 'S').source:sub(2)
    local path = src:match('(.*' .. sep .. ')')
    data_dir = path .. 'data'
  end

  -- Create settings instance
  _settings = Settings.new(data_dir, 'settings.json')

  -- Initialize state with settings
  State.initialize(_settings)

  -- Initialize theme parameter system (CRITICAL - must be before creating views)
  ThemeParams.initialize()

  _initialized = true
  log:info('Initialization complete')

  return _settings
end

-- Get settings instance (initializes if needed)
function M.get_settings()
  if not _initialized then
    error('ThemeAdjuster not initialized. Call initialize() first.')
  end
  return _settings
end

-- Check if initialized
function M.is_initialized()
  return _initialized
end

-- Reset for testing (clears initialization state)
function M.reset()
  _initialized = false
  _settings = nil
end

return M
