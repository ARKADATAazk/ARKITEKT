-- @noindex
-- ReArkitekt/ColorPalette/ARK_Color_Palette.lua
-- Entry point for Color Palette script
-- Run once to open, run again to toggle visibility
-- Add to REAPER startup actions for instant availability

-- ============================================================================
-- UNIVERSAL PATH RESOLUTION - Find ARKITEKT root automatically
-- ============================================================================
local sep = package.config:sub(1,1)
local script_path = debug.getinfo(1, "S").source:sub(2)
local script_dir = script_path:match("(.*"..sep..")")

-- Find ARKITEKT root by scanning upward until folder "rearkitekt" exists
local function find_root(path)
  while path and #path > 3 do
    local test = path .. "rearkitekt" .. sep
    local f = io.open(test .. "app" .. sep .. "shell.lua", "r")
    if f then f:close(); return path end
    path = path:match("(.*"..sep..")[^"..sep.."]-"..sep.."$")
  end
end

local root_path = find_root(script_dir)
if not root_path then
  reaper.MB("ARKITEKT root not found! Cannot locate rearkitekt/app/shell.lua", "FATAL ERROR", 0)
  return
end

-- Build module search paths
package.path =
    root_path .. "rearkitekt" .. sep .. "?.lua;" ..
    root_path .. "rearkitekt" .. sep .. "?" .. sep .. "init.lua;" ..
    root_path .. "scripts" .. sep .. "?.lua;" ..
    root_path .. "scripts" .. sep .. "?" .. sep .. "init.lua;" ..
    package.path

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

-- Utility functions
local function dirname(p) return p:match("^(.*)[/\\]") end
local function join(a,b) local s=package.config:sub(1,1); return (a:sub(-1)==s) and (a..b) or (a..s..b) end
local SRC = debug.getinfo(1,"S").source:sub(2)
local HERE = dirname(SRC) or "."

-- Load dependencies
local Shell = require("rearkitekt.app.shell")
local State = require("ColorPalette.app.state")
local GUI = require("ColorPalette.app.gui")
local OverlayManager = require("rearkitekt.gui.widgets.overlays.overlay.manager")

-- Load optional style
local style_ok, Style = pcall(require, "rearkitekt.gui.style.imgui_defaults")

-- Initialize cache directory for settings
local SEP = package.config:sub(1,1)
local cache_dir = reaper.GetResourcePath() .. SEP .. "Scripts" .. SEP .. "ReArkitekt" .. SEP .. "cache" .. SEP .. "ColorPalette"

-- Initialize settings and state
local Settings = require('rearkitekt.core.settings')
local Colors = require('rearkitekt.core.colors')
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