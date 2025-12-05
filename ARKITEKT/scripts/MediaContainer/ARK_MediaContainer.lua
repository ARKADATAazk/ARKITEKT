-- @noindex
-- @about
--   Create linked containers that mirror changes across all copies.
--   Perfect for glitch percussion and repetitive patterns.

-- ============================================================================
-- LOAD ARKITEKT FRAMEWORK
-- ============================================================================
local Ark = dofile(debug.getinfo(1,'S').source:sub(2):match('(.-ARKITEKT[/\\])') .. 'arkitekt' .. package.config:sub(1,1) .. 'init.lua')

-- ============================================================================
-- LOAD APPLICATION
-- ============================================================================

local Shell = require('arkitekt.runtime.shell')
local Settings = require('arkitekt.core.settings')
local App = require('MediaContainer.app.init')

-- Initialize settings
local data_dir = Ark._bootstrap.get_data_dir('MediaContainer')
local settings = Settings.new(data_dir, 'settings.json')

-- Initialize state with settings
App.state.initialize(settings)

-- Create GUI with proper options pattern
local gui = App.ui.new({
  state = App.state,
  config = App.config,
  settings = settings,
})

-- ============================================================================
-- RUN APPLICATION
-- ============================================================================

Shell.run({
  title        = 'Media Container',
  version      = 'v0.1.0',
  app_name     = 'MediaContainer',
  draw         = function(ctx, shell_state) gui:draw(ctx, shell_state) end,
  settings     = settings,
  initial_pos  = { x = 100, y = 100 },
  initial_size = { w = 300, h = 300 },
  icon_color   = 0xFF9933FF,
  icon_size    = 18,
  min_size     = { w = 280, h = 200 },
})
