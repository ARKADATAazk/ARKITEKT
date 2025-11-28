--[[
  @noindex

  MIDI Ex Machina (ARKITEKT Edition)

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

-- Bootstrap ARKITEKT
local ARK
do
  local sep = package.config:sub(1,1)
  local src = debug.getinfo(1, "S").source:sub(2)
  local path = src:match("(.*"..sep..")")
  while path and #path > 3 do
    local init = path .. "arkitekt" .. sep .. "app" .. sep .. "init" .. sep .. "init.lua"
    local f = io.open(init, "r")
    if f then
      f:close()
      ARK = dofile(init).bootstrap()
      break
    end
    path = path:match("(.*"..sep..")[^"..sep.."]-"..sep.."$")
  end
  if not ARK then
    reaper.MB("ARKITEKT framework not found!", "FATAL ERROR", 0)
    return
  end
end

-- DEPENDENCIES
local Shell = require('arkitekt.app.runtime.shell')
local State = require('scripts.MIDIExMachina.app.state')
local EuclideanView = require('scripts.MIDIExMachina.ui.euclidean_view')
local Defaults = require('scripts.MIDIExMachina.defs.defaults')

-- APP STATE
local app_state = State.new(ARK)

-- Initialize view with Ark namespace
EuclideanView.init(ARK)

-- Main draw function
local function draw(ctx)
  EuclideanView.draw(ctx)
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
