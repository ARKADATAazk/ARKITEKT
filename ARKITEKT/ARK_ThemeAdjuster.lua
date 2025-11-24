-- @noindex
-- ThemeAdjuster v2 - Main Entry Point
-- Refactored to use ARKITEKT framework

-- ============================================================================
-- BOOTSTRAP ARKITEKT FRAMEWORK
-- ============================================================================
local ARK = dofile(debug.getinfo(1,"S").source:sub(2):match("(.-ARKITEKT[/\\])") .. "arkitekt/app/init/init.lua").bootstrap()

-- ============================================================================
-- LOAD MODULES
-- ============================================================================

local Shell = require("arkitekt.app.runtime.shell")
local Config = require("ThemeAdjuster.core.config")
local State = require("ThemeAdjuster.core.state")
local ThemeParams = require("ThemeAdjuster.core.theme_params")
local GUI = require("ThemeAdjuster.ui.gui")
local StatusConfig = require("ThemeAdjuster.ui.status")
local Colors = require("arkitekt.core.colors")
local Settings = require("arkitekt.core.settings")

local hexrgb = Colors.hexrgb

-- ============================================================================
-- INITIALIZE SETTINGS
-- ============================================================================

local data_dir = ARK.get_data_dir("ThemeAdjuster")
local settings = Settings.new(data_dir, "settings.json")

State.initialize(settings)

-- Initialize theme parameter system (CRITICAL - must be before creating views)
ThemeParams.initialize()

local gui = GUI.create(State, Config, settings)

-- ============================================================================
-- RUN APPLICATION
-- ============================================================================

Shell.run({
  title        = "Theme Adjuster",
  version      = "(1.0.0)",
  draw         = function(ctx, shell_state) gui:draw(ctx, shell_state.window, shell_state) end,
  settings     = settings,
  initial_pos  = { x = 80, y = 80 },
  initial_size = { w = 1120, h = 820 },
  icon_color   = hexrgb("#00B88F"),
  icon_size    = 18,
  min_size     = { w = 700, h = 500 },
  get_status_func = StatusConfig.get_status_func and StatusConfig.get_status_func(State) or nil,
  content_padding = 12,
  tabs = {
    items = {
      { id = "GLOBAL", label = "Global" },
      { id = "ASSEMBLER", label = "Assembler" },
      { id = "TCP", label = "TCP" },
      { id = "MCP", label = "MCP" },
      { id = "COLORS", label = "Colors" },
      { id = "ENVELOPES", label = "Envelopes" },
      { id = "TRANSPORT", label = "Transport" },
      { id = "ADDITIONAL", label = "Additional" },
      { id = "DEBUG", label = "Debug" },
    },
    active = State.get_active_tab(),
    style = {
      active_indicator_height = 0,
      spacing_after = 2,
    },
    colors = {
      bg_active   = hexrgb("#242424"),
      bg_clicked  = hexrgb("#2A2A2A"),
      bg_hovered  = hexrgb("#202020"),
      bg_inactive = hexrgb("#1A1A1A"),
      border      = hexrgb("#000000"),
      text_active = hexrgb("#FFFFFF"),
      text_inact  = hexrgb("#BBBBBB"),
    },
  },
  fonts        = {},
})
