-- @description DrumBlocks - Drum Rack for REAPER
-- @author ARKITEKT
-- @version 0.1.0
-- @about
--   128-pad drum rack powered by BlockSampler VST.
--   Drag samples, hot-swap, kit presets.

-- ============================================================================
-- LOAD ARKITEKT FRAMEWORK
-- ============================================================================
local Ark = dofile(debug.getinfo(1,'S').source:sub(2):match('(.-ARKITEKT[/\\])') .. 'arkitekt' .. package.config:sub(1,1) .. 'init.lua')

local ImGui = Ark.ImGui
local SRC = debug.getinfo(1,'S').source:sub(2)
local HERE = Ark._bootstrap.dirname(SRC) or '.'

-- Load dependencies
local Shell = require('arkitekt.runtime.shell')
local State = require('DrumBlocks.app.state')
local GUI = require('DrumBlocks.app.gui')

-- Load optional style
local style_ok, Style = pcall(require, 'arkitekt.gui.style.imgui')

-- Initialize cache directory for settings
local SEP = package.config:sub(1,1)
local cache_dir = reaper.GetResourcePath() .. SEP .. 'Scripts' .. SEP .. 'Arkitekt' .. SEP .. 'cache' .. SEP .. 'DrumBlocks'

-- Initialize settings
local Settings = require('arkitekt.core.settings')
local settings = Settings.open(cache_dir, 'settings.json')

-- Initialize state
State.initialize(settings)

-- Create GUI instance
local gui = GUI.create(State, settings)

-- Main draw function
local function draw(ctx, shell_state)
  return gui:draw(ctx)
end

-- Run application
Shell.run({
  title = 'DrumBlocks',
  draw = draw,
  style = style_ok and Style or nil,
  settings = settings,
  initial_pos = { x = 100, y = 100 },
  initial_size = { w = 800, h = 500 },
  min_size = { w = 600, h = 400 },

  on_close = function()
    State.save()
  end,
})
