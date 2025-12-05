-- @noindex
-- WALTER Builder - Visual layout editor for REAPER theme configuration
--
-- WALTER (Window Arrangement Logic Template Engine for REAPER) is the system
-- used to define visual layout of track panels, mixer panels, envelope panels,
-- and transport in REAPER themes.
--
-- This tool provides a visual editor for creating and editing WALTER layouts
-- with real-time preview of edge attachment behavior.

-- ============================================================================
-- LOAD ARKITEKT FRAMEWORK
-- ============================================================================

local Ark = dofile(debug.getinfo(1,'S').source:sub(2):match('(.-ARKITEKT[/\\])') .. 'arkitekt' .. package.config:sub(1,1) .. 'init.lua')

-- ============================================================================
-- LOAD APPLICATION
-- ============================================================================

local Shell = require('arkitekt.runtime.shell')
local Settings = require('arkitekt.core.settings')
local State = require('WalterBuilder.app.state')
local Controller = require('WalterBuilder.core.controller')
local GUI = require('WalterBuilder.ui.gui')

-- ============================================================================
-- INITIALIZE SETTINGS AND STATE
-- ============================================================================

local data_dir = Ark._bootstrap.get_data_dir('WalterBuilder')
local settings = Settings.new(data_dir, 'settings.json')

-- Initialize state with settings
State.initialize(settings)

-- Create controller for business logic
local controller = Controller.new(State, settings)

-- Create GUI instance with controller
local gui = GUI.new(State, settings, controller)

-- ============================================================================
-- RUN APPLICATION
-- ============================================================================

Shell.run({
  title        = 'WALTER Builder',
  version      = '(0.1.0)',
  draw         = function(ctx, shell_state)
    gui:draw(ctx, shell_state.window, shell_state)
  end,
  settings     = settings,
  initial_pos  = { x = 60, y = 60 },
  initial_size = { w = 1200, h = 700 },
  icon_color   = 0xFF6B35FF,  -- Orange for WALTER
  icon_size    = 18,
  min_size     = { w = 900, h = 500 },
  content_padding = 8,
  fonts        = {},
})
