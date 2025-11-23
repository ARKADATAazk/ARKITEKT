-- @noindex

-- ============================================================================
-- BOOTSTRAP ARKITEKT FRAMEWORK
-- ============================================================================
local ARK = dofile(debug.getinfo(1,"S").source:sub(2):match("(.-ARKITEKT[/\\])") .. "arkitekt/app/init/init.lua").bootstrap()

-- Load arkitekt namespace
local ark = require('arkitekt')

-- ============================================================================
-- PROFILER INITIALIZATION (Controlled by ARKITEKT/config.lua)
-- ============================================================================
local profiler_enabled = ark.ProfilerInit.init()

-- ============================================================================
-- LOAD MODULES
-- ============================================================================

-- Aliases from ark namespace
local Shell = ark.Shell
local Colors = ark.Colors
local Settings = ark.Settings

local Config = require("RegionPlaylist.core.config")
local State = require("RegionPlaylist.core.app_state")
local GUI = require("RegionPlaylist.ui.gui")
local StatusConfig = require("RegionPlaylist.ui.status")

local hexrgb = Colors.hexrgb
local data_dir = ARK.get_data_dir("RegionPlaylist")
local settings = Settings.new(data_dir, "settings.json")

State.initialize(settings)

local gui = GUI.create(State, Config, settings)

-- ============================================================================
-- PROFILER INSTRUMENTATION (After modules loaded)
-- ============================================================================
if profiler_enabled then
  ark.ProfilerInit.attach_locals()
  ark.ProfilerInit.launch_window()
end

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
