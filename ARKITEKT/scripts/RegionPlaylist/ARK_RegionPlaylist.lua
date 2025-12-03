-- @noindex

-- ============================================================================
-- LOAD ARKITEKT FRAMEWORK
-- ============================================================================
local Ark = dofile(debug.getinfo(1,'S').source:sub(2):match('(.-ARKITEKT[/\\])') .. 'arkitekt' .. package.config:sub(1,1) .. 'init.lua')

-- ============================================================================
-- PROFILER INITIALIZATION (Controlled by ARKITEKT/config.lua)
-- ============================================================================
local ProfilerInit = require('arkitekt.debug.profiler_init')
local profiler_enabled = ProfilerInit.init()

-- ============================================================================
-- LOAD APPLICATION
-- ============================================================================

local Shell = require('arkitekt.runtime.shell')
local App = require('RegionPlaylist.app.init')
local hexrgb = Ark.Colors.Hexrgb

-- Register script palette (for Theme Debugger)
require('RegionPlaylist.config.palette')

-- Initialize settings
local Settings = require('arkitekt.core.settings')
local data_dir = Ark._bootstrap.get_data_dir('RegionPlaylist')
local settings = Settings.new(data_dir, 'settings.json')

-- Initialize state and create GUI
App.state.initialize(settings)
local gui = App.ui.create(App.state, App.config, settings)

-- ============================================================================
-- PROFILER INSTRUMENTATION (After modules loaded)
-- ============================================================================
if profiler_enabled then
  ProfilerInit.attach_locals()
  ProfilerInit.launch_window()
end

-- ============================================================================
-- TEST SUITE REGISTRATION (Always loaded for debug console access)
-- ============================================================================
local function load_tests()
  local Logger = require('arkitekt.debug.logger')

  -- Load domain tests (mock-based unit tests)
  local ok, err = pcall(function()
    require('RegionPlaylist.tests.domain_tests')
  end)
  if not ok then
    Logger.warn('TEST', 'Failed to load domain tests: %s', tostring(err))
  end

  -- Load integration tests (real REAPER operations)
  ok, err = pcall(function()
    require('RegionPlaylist.tests.integration_tests')
  end)
  if not ok then
    Logger.warn('TEST', 'Failed to load integration tests: %s', tostring(err))
  end
end
load_tests()

-- ============================================================================
-- RUN APPLICATION
-- ============================================================================

Shell.run({
  title        = 'Region Playlist' .. (profiler_enabled and ' [Profiling]' or ''),
  version      = 'v0.1.0',
  app_name     = 'RegionPlaylist',  -- For per-app theme overrides
  draw         = function(ctx, shell_state) gui:draw(ctx, shell_state.window, shell_state) end,
  settings     = settings,
  initial_pos  = { x = 120, y = 120 },
  initial_size = { w = 1000, h = 700 },
  icon_color   = hexrgb('#41E0A3'),
  icon_size    = 18,
  min_size     = { w = 700, h = 500 },
  get_status_func = App.status.get_status_func and App.status.get_status_func(App.state) or nil,
  fonts        = {
    time_display = 20,
    icons = 20,
  },
})
