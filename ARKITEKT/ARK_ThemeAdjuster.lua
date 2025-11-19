-- @noindex
-- ThemeAdjuster v2 - Main Entry Point
-- Refactored to use ARKITEKT framework

-- ============================================================================
-- BOOTSTRAP ARKITEKT FRAMEWORK
-- ============================================================================
local Init = require('rearkitekt.app.init')
local ARK = Init.bootstrap()
if not ARK then return end

-- Local references
local SRC = debug.getinfo(1,"S").source:sub(2)
local HERE = ARK.dirname(SRC) or "."

-- ============================================================================
-- LOAD MODULES
-- ============================================================================

local Shell = require("rearkitekt.app.shell")
local Config = require("ThemeAdjuster.core.config")
local State = require("ThemeAdjuster.core.state")
local ThemeParams = require("ThemeAdjuster.core.theme_params")
local GUI = require("ThemeAdjuster.ui.gui")
local StatusConfig = require("ThemeAdjuster.ui.status")
local Colors = require("rearkitekt.core.colors")

local hexrgb = Colors.hexrgb

local SettingsOK, Settings = pcall(require, "rearkitekt.core.settings")
local StyleOK, Style = pcall(require, "rearkitekt.gui.style.imgui_defaults")

-- ============================================================================
-- INITIALIZE SETTINGS
-- ============================================================================

local settings = nil
if SettingsOK and type(Settings.new) == "function" then
  local ok, inst = pcall(Settings.new, ARK.join(HERE, "cache"), "theme_adjuster.json")
  if ok then settings = inst end
end

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
  style        = StyleOK and Style or nil,
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
      active_indicator_height = 0,  -- Remove accent line below active tab
      spacing_after = 2,             -- Reduce spacing below tabs (was 4)
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
