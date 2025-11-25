-- @noindex
-- TemplateBrowser main launcher with overlay support
-- Three-panel UI: Folders | Templates | Tags

-- ============================================================================
-- BOOTSTRAP ARKITEKT FRAMEWORK
-- ============================================================================
local ARK = dofile(debug.getinfo(1,"S").source:sub(2):match("(.-ARKITEKT[/\\])") .. "arkitekt/app/bootstrap.lua").init()

-- Load required modules
local Shell = require('arkitekt.app.shell')
local Colors = require('arkitekt.core.colors')

-- Load TemplateBrowser modules
local Config = require('TemplateBrowser.core.config')
local State = require('TemplateBrowser.core.state')
local GUI = require('TemplateBrowser.ui.gui')
local Scanner = require('TemplateBrowser.domain.scanner')

local hexrgb = ARK.Colors.hexrgb

-- Initialize state
State.initialize(Config)

-- Initialize scanner and load templates
Scanner.scan_templates(State)

-- Create GUI instance
local gui = GUI.new(Config, State, Scanner)

-- Run in overlay mode
Shell.run({
  mode = "overlay",
  title = "Template Browser",
  toggle_button = true,

  overlay = {
    close_on_scrim = false,
    close_on_background_right_click = false,
  },

  draw = function(ctx, state)
    if gui and gui.draw then
      gui:draw(ctx, {
        fonts = state.fonts,
        overlay_state = state.overlay,
        overlay = { alpha = { value = function() return state.overlay.alpha end } },
        is_overlay_mode = true,
      })
    end
  end,

  on_close = function()
    State.cleanup()
  end,
})
