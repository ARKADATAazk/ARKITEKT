-- @noindex
-- TemplateBrowser main launcher with overlay support
-- Three-panel UI: Folders | Templates | Tags

-- ============================================================================
-- LOAD ARKITEKT FRAMEWORK
-- ============================================================================
local Ark = dofile(debug.getinfo(1,"S").source:sub(2):match("(.-ARKITEKT[/\\])") .. "arkitekt" .. package.config:sub(1,1) .. "init.lua")

-- Load required modules
local Shell = require('arkitekt.app.shell')

-- Load TemplateBrowser modules (using canonical paths)
local Config = require('TemplateBrowser.app.config')
local State = require('TemplateBrowser.app.state')
local GUI = require('TemplateBrowser.ui.init')
local Scanner = require('TemplateBrowser.domain.template.scanner')
local Constants = require('TemplateBrowser.defs.constants')

local hexrgb = Ark.Colors.hexrgb

-- Initialize state
State.initialize(Config)

-- Create GUI instance (scanner will run after window opens)
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
    -- Run incremental scanner
    if not State.scan_complete then
      if not State.scan_in_progress then
        -- Initialize scan on first frame
        State.scan_in_progress = true
        Scanner.scan_init(State)
      else
        -- Continue scanning
        local complete = Scanner.scan_batch(State, Constants.SCANNER.BATCH_SIZE)
        if complete then
          State.scan_complete = true
          State.scan_in_progress = false
        end
      end
    end

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
