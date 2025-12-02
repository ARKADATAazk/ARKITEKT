--[[
  @noindex

  MIDI Helix (ARKITEKT Edition)

  Euclidean rhythm generator for REAPER's MIDI Editor.

  Inspired by RobU's original MIDI Ex Machina:
  https://github.com/RobU23/ReaScripts

  This is a reimplementation built on the ARKITEKT framework,
  starting with the Euclidean generator module.

  Original concept: RobU (GPL-3.0)
  ARKITEKT implementation: (GPL-3.0)

  Features:
  - Bjorklund algorithm for Euclidean rhythm patterns
  - Adjustable pulses, steps, and rotation
  - Visual pattern preview
  - Safe MIDI item handling (prevents Ghost/Pooled item hangs)
  - Grid-based timing control
]]

-- ============================================================================
-- LOAD ARKITEKT FRAMEWORK
-- ============================================================================
local Ark = dofile(debug.getinfo(1,'S').source:sub(2):match('(.-ARKITEKT[/\\])') .. 'arkitekt' .. package.config:sub(1,1) .. 'init.lua')

-- DEPENDENCIES
local Shell = require('arkitekt.runtime.shell')
local State = require('scripts.MIDIHelix.app.state')
local EuclideanView = require('scripts.MIDIHelix.ui.euclidean_view')
local Defaults = require('scripts.MIDIHelix.defs.defaults')

-- APP STATE
local app_state = State.new(Ark)

-- Initialize view with Ark namespace
EuclideanView.init(Ark)

-- Main draw function
local function draw(ctx)
  EuclideanView.Draw(ctx)
end

-- Run application
Shell.run({
  title = Defaults.WINDOW.TITLE,
  w = Defaults.WINDOW.WIDTH,
  h = Defaults.WINDOW.HEIGHT,
  draw = draw,
  on_init = function()
    app_state:init()
  end,
})
