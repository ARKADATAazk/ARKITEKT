-- @noindex
-- ItemPicker main launcher with clean overlay support

-- ============================================================================
-- LOAD ARKITEKT FRAMEWORK
-- ============================================================================
local ark = dofile(debug.getinfo(1,"S").source:sub(2):match("(.-ARKITEKT[/\\])") .. "loader.lua")

-- ============================================================================
-- PROFILER INITIALIZATION (Controlled by ARKITEKT/config.lua)
-- ============================================================================
local ProfilerInit = require('arkitekt.debug.profiler_init')
local profiler_enabled = ProfilerInit.init()

if profiler_enabled then
  reaper.ShowConsoleMsg("[ItemPicker] ✓ Profiler enabled and initialized\n")
else
  reaper.ShowConsoleMsg("[ItemPicker] ✗ Profiler disabled or not found\n")
  reaper.ShowConsoleMsg("[ItemPicker]   To enable: Set PROFILER_ENABLED=true in arkitekt/app/app_defaults.lua\n")
  reaper.ShowConsoleMsg("[ItemPicker]   Install profiler: ReaPack > Browse > Search 'cfillion Lua profiler'\n")
end

-- Load required modules
local Shell = require('arkitekt.app.shell')

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

-- Run in overlay mode with passthrough for drag handling
Shell.run({
  mode = "overlay",
  title = "Item Picker" .. (profiler_enabled and " [Profiling]" or ""),
  toggle_button = true,
  app_name = "item_picker",

  fonts = {
    title_size = 24,
    monospace_size = 14,
  },

  overlay = {
    esc_to_close = false,  -- GUI handles ESC for special behavior
    -- When dragging, bypass overlay chrome and render directly to full viewport
    should_passthrough = function() return State.dragging end,
  },

  draw = function(ctx, state)
    -- Show ImGui debug window when profiling
    if profiler_enabled then
      ARK.ImGui.ShowMetricsWindow(ctx, true)
    end

    -- Check if should close after drop
    if State.should_close_after_drop then
      -- Signal to close
      return false
    end

    if gui and gui.draw then
      gui:draw(ctx, {
        fonts = state.fonts,
        overlay_state = state.overlay or {},
        overlay = { alpha = { value = function() return state.overlay and state.overlay.alpha or 1.0 end } },
        is_overlay_mode = true,
      })
    end

    return true
  end,

  on_close = cleanup,
})
