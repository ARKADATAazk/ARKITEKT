-- @noindex
-- ThemeAdjuster v2 - Main Entry Point
-- Refactored to use ARKITEKT framework

-- ============================================================================
-- LOAD ARKITEKT FRAMEWORK
-- ============================================================================
local Ark = dofile(debug.getinfo(1,'S').source:sub(2):match('(.-ARKITEKT[/\\])') .. 'arkitekt' .. package.config:sub(1,1) .. 'init.lua')

-- ============================================================================
-- LOAD MODULES
-- ============================================================================

local Shell = require('arkitekt.runtime.shell')
local Config = require('ThemeAdjuster.app.config')
local State = require('ThemeAdjuster.app.state')
local ThemeParams = require('ThemeAdjuster.domain.theme.params')
local GUI = require('ThemeAdjuster.ui.gui')
local StatusConfig = require('ThemeAdjuster.ui.status')
local Settings = require('arkitekt.core.settings')

-- ============================================================================
-- INITIALIZE SETTINGS
-- ============================================================================

local data_dir = Ark._bootstrap.get_data_dir('ThemeAdjuster')
local settings = Settings.new(data_dir, 'settings.json')

State.initialize(settings)

-- Initialize theme parameter system (CRITICAL - must be before creating views)
ThemeParams.initialize()

local gui = GUI.create(State, Config, settings)

-- ============================================================================
-- RUN APPLICATION
-- ============================================================================

Shell.run({
  title        = 'Theme Adjuster',
  version      = '(1.0.0)',
  draw         = function(ctx, shell_state) gui:draw(ctx, shell_state.window, shell_state) end,
  settings     = settings,
  initial_pos  = { x = 80, y = 80 },
  initial_size = { w = 1120, h = 820 },
  icon_color   = 0x00B88FFF,
  icon_size    = 18,
  min_size     = { w = 700, h = 500 },
  get_status_func = StatusConfig.get_status_func and StatusConfig.get_status_func(State) or nil,
  content_padding = 12,
  tabs = {
    items = {
      { id = 'GLOBAL', label = 'Global' },
      { id = 'ASSEMBLER', label = 'Assembler' },
      { id = 'TCP', label = 'TCP' },
      { id = 'MCP', label = 'MCP' },
      { id = 'COLORS', label = 'Colors' },
      { id = 'ENVELOPES', label = 'Envelopes' },
      { id = 'TRANSPORT', label = 'Transport' },
      { id = 'ADDITIONAL', label = 'Additional' },
      { id = 'DEBUG', label = 'Debug' },
    },
    active = State.get_active_tab(),
    style = {
      active_indicator_height = 0,
      spacing_after = 2,
    },
    colors = {
      bg_active   = 0x242424FF,
      bg_clicked  = 0x2A2A2AFF,
      bg_hovered  = 0x202020FF,
      bg_inactive = 0x1A1A1AFF,
      border      = 0x000000FF,
      text_active = 0xFFFFFFFF,
      text_inact  = 0xBBBBBBFF,
    },
  },
  fonts        = {},
})
