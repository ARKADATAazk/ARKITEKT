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

local ark = dofile(debug.getinfo(1,"S").source:sub(2):match("(.-ARKITEKT[/\\])") .. "loader.lua")

-- ============================================================================
-- LOAD MODULES
-- ============================================================================

local Shell = require("arkitekt.app.shell")
local Settings = require("arkitekt.core.settings")
local State = require("WalterBuilder.app.state")
local GUI = require("WalterBuilder.ui.gui")

local hexrgb = ark.Colors.hexrgb

-- ============================================================================
-- INITIALIZE SETTINGS
-- ============================================================================

local data_dir = ark._bootstrap.get_data_dir("WalterBuilder")
local settings = Settings.new(data_dir, "settings.json")

-- Initialize state with settings
State.initialize(settings)

-- Create GUI instance
local gui = GUI.new(State, settings)

-- ============================================================================
-- RUN APPLICATION
-- ============================================================================

Shell.run({
  title        = "WALTER Builder",
  version      = "(0.1.0)",
  draw         = function(ctx, shell_state)
    gui:draw(ctx, shell_state.window, shell_state)
  end,
  settings     = settings,
  initial_pos  = { x = 60, y = 60 },
  initial_size = { w = 1200, h = 700 },
  icon_color   = hexrgb("#FF6B35"),  -- Orange for WALTER
  icon_size    = 18,
  min_size     = { w = 900, h = 500 },
  content_padding = 8,
  fonts        = {},
})
