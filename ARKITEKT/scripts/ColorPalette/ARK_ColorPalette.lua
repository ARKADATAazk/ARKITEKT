-- @noindex
-- Arkitekt/ColorPalette/ARK_Color_Palette.lua
-- Entry point for Color Palette script
-- Run once to open, run again to toggle visibility
-- Add to REAPER startup actions for instant availability

-- ============================================================================
-- BOOTSTRAP ARKITEKT FRAMEWORK
-- ============================================================================
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
      local Init = dofile(init)
      ARK = Init.bootstrap()
      break
    end
    path = path:match("(.*"..sep..")[^"..sep.."]-"..sep.."$")
  end
  if not ARK then
    reaper.MB("ARKITEKT framework not found!", "FATAL ERROR", 0)
    return
  end
end

local ImGui = ARK.ImGui
local SRC = debug.getinfo(1,"S").source:sub(2)
local HERE = ARK.dirname(SRC) or "."

-- Load dependencies
local Shell = require("arkitekt.app.runtime.shell")
local State = require("ColorPalette.app.state")
local GUI = require("ColorPalette.app.gui")
local OverlayManager = require("arkitekt.gui.widgets.overlays.overlay.manager")

-- Load optional style
local style_ok, Style = pcall(require, "arkitekt.gui.style.imgui_defaults")

-- Initialize cache directory for settings
local SEP = package.config:sub(1,1)
local cache_dir = reaper.GetResourcePath() .. SEP .. "Scripts" .. SEP .. "Arkitekt" .. SEP .. "cache" .. SEP .. "ColorPalette"

-- Initialize settings and state
local Settings = require('arkitekt.core.settings')
local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb

local settings = Settings.open(cache_dir, 'settings.json')

State.initialize(settings)

-- Create overlay manager
local overlay = OverlayManager.new()

-- Create GUI instance
local gui = GUI.create(State, settings, overlay)

-- Main draw function
local function draw(ctx, shell_state)
  return gui:draw(ctx)
end

-- Run application
-- ImGui in REAPER handles show/hide automatically:
-- - Running script while window is open toggles visibility
-- - Clicking X button hides (doesn't terminate)
-- - Script stays alive in background
Shell.run({
  title = "Color Palette",
  draw = draw,
  style = style_ok and Style or nil,
  settings = settings,
  initial_pos = { x = 140, y = 140 },
  initial_size = { w = 600, h = 320 },
  min_size = { w = 480, h = 240 },
  content_padding = 0,
  show_status_bar = false,
  show_titlebar = false,
  raw_content = true,
  
  -- Make window frameless
  flags = ImGui.WindowFlags_NoBackground,
  bg_color_floating = hexrgb("#00000000"),
  bg_color_docked = hexrgb("#00000000"),
  
  -- Pass overlay manager to window
  overlay = overlay,
  
  on_close = function()
    State.save()
  end,
})