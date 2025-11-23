-- @noindex
-- @description ARK Item Picker Window
-- ItemPicker as a persistent window with TilesContainer panels (like RegionPlaylist)

-- Bootstrap ARKITEKT framework
local ARK = dofile(debug.getinfo(1,"S").source:sub(2):match("(.-ARKITEKT[/\\])") .. "arkitekt/app/init/init.lua").bootstrap()
if not ARK then return end

-- ============================================================================
-- PROFILER INITIALIZATION (Controlled by ARKITEKT/config.lua)
-- ============================================================================
local ProfilerInit = require('arkitekt.debug.profiler_init')
local profiler_enabled = ProfilerInit.init()

if profiler_enabled then
  reaper.ShowConsoleMsg("[ItemPickerWindow] Profiler enabled and initialized\n")
end

-- Load required modules
local Shell = require('arkitekt.app.runtime.shell')
local Colors = require('arkitekt.core.colors')
local Settings = require('arkitekt.core.settings')

local hexrgb = Colors.hexrgb

-- Load ItemPicker core modules (reuse data layer)
local Config = require('ItemPicker.core.config')
local State = require('ItemPicker.core.app_state')
local Controller = require('ItemPicker.core.controller')

-- Load window-specific GUI module
local GUI = require('ItemPickerWindow.ui.gui')

-- Data and service modules
local visualization = require('ItemPicker.services.visualization')
local reaper_interface = require('ItemPicker.data.reaper_api')
local utils = require('ItemPicker.services.utils')

-- Initialize settings
local data_dir = ARK.get_data_dir("ItemPickerWindow")
local settings = Settings.new(data_dir, "settings.json")

-- Initialize state
State.initialize(Config)

-- Initialize domain modules
reaper_interface.init(utils)
visualization.init(utils, SCRIPT_DIRECTORY, Config)

-- Initialize controller
Controller.init(reaper_interface, utils)

-- Create window GUI
local gui = GUI.create(Config, State, Controller, visualization)

-- ============================================================================
-- PROFILER INSTRUMENTATION (After modules loaded)
-- ============================================================================
if profiler_enabled then
  ProfilerInit.attach_locals()
  ProfilerInit.launch_window()
end

-- Run in window mode using Shell (like RegionPlaylist)
Shell.run({
  title = "Item Picker" .. (profiler_enabled and " [Profiling]" or ""),
  version = "1.0.0",
  toggle_button = true,
  draw = function(ctx, shell_state) gui:draw(ctx, shell_state) end,
  settings = settings,
  initial_pos = { x = 120, y = 120 },
  initial_size = { w = 1200, h = 800 },
  min_size = { w = 800, h = 600 },
  icon_color = hexrgb("#4A9EFF"),
  icon_size = 18,
  fonts = {
    icons = 20,
  },
  on_close = function()
    reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_STOPPREVIEW"), 0)
    State.cleanup()
  end,
})
