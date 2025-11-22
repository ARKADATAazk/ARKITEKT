-- @noindex
-- @description ARK Item Picker Window
-- ItemPicker as a persistent window (doesn't close on drag-drop)

-- ============================================================================
-- BOOTSTRAP ARKITEKT FRAMEWORK
-- ============================================================================
local ARK
do
  local sep = package.config:sub(1,1)
  local src = debug.getinfo(1, "S").source:sub(2)
  local path = src:match("(.*"..sep..")")
  while path and #path > 3 do
    local init = path .. "rearkitekt" .. sep .. "app" .. sep .. "init" .. sep .. "init.lua"
    local f = io.open(init, "r")
    if f then
      f:close()
      local Init = dofile(init)
      ARK = Init.bootstrap()
      break
    end
    path = path:match("(.*"..sep..")[^"..sep.."]-"..sep.."$")
  end
  if not ARK then
    reaper.MB("ARKITEKT framework not found!", "FATAL ERROR", 0)
    return
  end
end

-- ============================================================================
-- PROFILER INITIALIZATION (Controlled by ARKITEKT/config.lua)
-- ============================================================================
local ProfilerInit = require('rearkitekt.debug.profiler_init')
local profiler_enabled = ProfilerInit.init()

if profiler_enabled then
  reaper.ShowConsoleMsg("[ItemPickerWindow] Profiler enabled and initialized\n")
end

-- Load required modules
local ImGui = ARK.ImGui
local Shell = require('rearkitekt.app.runtime.shell')
local Fonts = require('rearkitekt.app.assets.fonts')

-- Load new refactored modules
local Config = require('ItemPicker.core.config')
local State = require('ItemPicker.core.app_state')
local Controller = require('ItemPicker.core.controller')
local GUI = require('ItemPicker.ui.main_window')

-- Data and service modules
local visualization = require('ItemPicker.services.visualization')
local reaper_interface = require('ItemPicker.data.reaper_api')
local utils = require('ItemPicker.services.utils')
local drag_handler = require('ItemPicker.ui.components.drag_handler')

local function SetButtonState(set)
  local is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
  reaper.SetToggleCommandState(sec, cmd, set or 0)
  reaper.RefreshToolbar2(sec, cmd)
end

-- Initialize state
State.initialize(Config)

-- Enable persistent mode (window doesn't close on drop)
State.persistent_mode = true

-- Initialize domain modules
reaper_interface.init(utils)
visualization.init(utils, SCRIPT_DIRECTORY, Config)

-- Initialize controller
Controller.init(reaper_interface, utils)

-- Create GUI
local gui = GUI.new(Config, State, Controller, visualization, drag_handler)

-- ============================================================================
-- PROFILER INSTRUMENTATION (After modules loaded)
-- ============================================================================
if profiler_enabled then
  ProfilerInit.attach_locals()
  ProfilerInit.launch_window()
end

local function cleanup()
  SetButtonState()
  reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_STOPPREVIEW"), 0)
  State.cleanup()
end

SetButtonState(1)

-- Run in window mode using Shell
Shell.run({
  title = "Item Picker" .. (profiler_enabled and " [Profiling]" or ""),
  version = "1.0.0",

  show_titlebar = true,
  show_status_bar = false,

  initial_size = { w = 1200, h = 800 },
  min_size = { w = 800, h = 600 },

  fonts = {
    default = 14,
    title = 24,
    monospace = 14,
  },

  draw = function(ctx, shell_state)
    -- Show ImGui debug window when profiling
    if profiler_enabled then
      ImGui.ShowMetricsWindow(ctx, true)
    end

    gui:draw(ctx, shell_state)
  end,

  on_close = function()
    cleanup()
  end,
})
