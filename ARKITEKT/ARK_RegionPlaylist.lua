-- @noindex

-- ============================================================================
-- BOOTSTRAP ARKITEKT FRAMEWORK
-- ============================================================================
local ARK = dofile(debug.getinfo(1,"S").source:sub(2):match("(.-ARKITEKT[/\\])") .. "arkitekt/app/bootstrap.lua").init()

-- ============================================================================
-- PROFILER INITIALIZATION (Controlled by ARKITEKT/config.lua)
-- ============================================================================
local ProfilerInit = require('arkitekt.debug.profiler_init')
local ark = require('arkitekt')
local profiler_enabled = ProfilerInit.init()

-- ============================================================================
-- LOAD MODULES
-- ============================================================================

local Shell = require("arkitekt.app.shell")
local Config = require("RegionPlaylist.core.config")
local State = require("RegionPlaylist.core.app_state")
local GUI = require("RegionPlaylist.ui.gui")
local StatusConfig = require("RegionPlaylist.ui.status")
local hexrgb = ark.Colors.hexrgb

-- State needs settings for initialization - Shell will auto-create from app_name
local Settings = require("arkitekt.core.settings")
local data_dir = ARK.get_data_dir("RegionPlaylist")
local settings = Settings.new(data_dir, "settings.json")

State.initialize(settings)

local gui = GUI.create(State, Config, settings)

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
    Logger.warn("TEST", "Failed to load domain tests: %s", tostring(err))
  end

  -- Load integration tests (real REAPER operations)
  ok, err = pcall(function()
    require('RegionPlaylist.tests.integration_tests')
  end)
  if not ok then
    Logger.warn("TEST", "Failed to load integration tests: %s", tostring(err))
  end
end
load_tests()

-- ============================================================================
-- RUN APPLICATION
-- ============================================================================

Shell.run({
  title        = "Region Playlist" .. (profiler_enabled and " [Profiling]" or ""),
  version      = "v0.1.0",
  draw         = function(ctx, shell_state) gui:draw(ctx, shell_state.window, shell_state) end,
  settings     = settings,
  initial_pos  = { x = 120, y = 120 },
  initial_size = { w = 1000, h = 700 },
  icon_color   = hexrgb("#41E0A3"),
  icon_size    = 18,
  min_size     = { w = 700, h = 500 },
  get_status_func = StatusConfig.get_status_func and StatusConfig.get_status_func(State) or nil,
  fonts        = {
    time_display = 20,
    icons = 20,
  },
})
