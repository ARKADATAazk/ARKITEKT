--[[
  @noindex

  Blocks - Modular component platform for REAPER

  A dockable host for modular UI components (blocks) that combine
  multiple scripts into a single unified interface.

  Current components:
  - Macro Controls: 8 assignable knobs for FX container parameter mapping
  - Drum Rack: 16-pad sampler with per-pad FX chains

  Features:
  - Single defer loop hosts multiple components
  - Modular architecture for adding new blocks
  - Modern, themeable UI with ARKITEKT framework

  License: GPL-3.0
]]

-- ============================================================================
-- LOAD ARKITEKT FRAMEWORK
-- ============================================================================
local Ark = dofile(debug.getinfo(1,'S').source:sub(2):match('(.-ARKITEKT[/\\])') .. 'arkitekt' .. package.config:sub(1,1) .. 'init.lua')

-- ============================================================================
-- IMPORTS
-- ============================================================================
local Shell = require('arkitekt.runtime.shell')
local Settings = require('arkitekt.core.settings')
local State = require('scripts.ProductionPanel.app.state')
local GUI = require('scripts.ProductionPanel.ui.init')
local Defaults = require('scripts.ProductionPanel.config.defaults')
local Colors = require('arkitekt.core.colors')

-- ============================================================================
-- SETTINGS & STATE INITIALIZATION
-- ============================================================================
local data_dir = Ark._bootstrap.get_data_dir('ProductionPanel')
local settings = Settings.new(data_dir, 'settings.json')

State.initialize(settings)

-- ============================================================================
-- RUN APPLICATION
-- ============================================================================
Shell.run({
  title        = Defaults.WINDOW.TITLE,
  version      = 'v0.1.0-proto',
  settings     = settings,
  initial_size = { w = Defaults.WINDOW.WIDTH, h = Defaults.WINDOW.HEIGHT },
  min_size     = { w = Defaults.WINDOW.MIN_WIDTH, h = Defaults.WINDOW.MIN_HEIGHT },
  icon_color   = 0xD94A4AFF,

  draw = function(ctx, shell_state)
    GUI.Draw(ctx, shell_state)
  end,

  on_close = function()
    State.Cleanup()
  end,
})
