-- @noindex
-- demo3.lua – Status Pads Widget Demo (Reworked)

-- Auto-injected package path setup for relocated script

-- Package path setup for relocated script
local script_path = debug.getinfo(1, "S").source:match("@?(.*)[\\/]") or ""
local root_path = script_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path

-- Ensure root_path ends with a slash
if not root_path:match("[\\/]$") then root_path = root_path .. "/" end

-- Add both module search paths
local arkitekt_path= root_path .. "ARKITEKT/"
local scripts_path = root_path .. "ARKITEKT/scripts/"
package.path = arkitekt_path.. "?.lua;" .. arkitekt_path.. "?/init.lua;" .. 
               scripts_path .. "?.lua;" .. scripts_path .. "?/init.lua;" .. 
               package.path

local script_path = debug.getinfo(1, "S").source:match("@?(.*)[\\/]") or ""
local root_path = script_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path
if not root_path:match("[\\/]$") then root_path = root_path .. "/" end
package.path = root_path .. "?.lua;" .. root_path .. "?/init.lua;" .. package.path

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

-- Path setup (assuming standard Arkitekt structure)
local function dirname(p) return p:match("^(.*)[/\\]") end
local function join(a,b) local s=package.config:sub(1,1); return (a:sub(-1)==s) and (a..b) or (a..s..b) end
local SRC   = debug.getinfo(1,"S").source:sub(2)
local HERE  = dirname(SRC) or "."
local PARENT= dirname(HERE or ".") or "."
local function addpath(p) if p and p~="" and not package.path:find(p,1,true) then package.path = p .. ";" .. package.path end end
addpath(join(PARENT,"?.lua")); addpath(join(PARENT,"?/init.lua"))
addpath(join(HERE,  "?.lua")); addpath(join(HERE,  "?/init.lua"))
addpath(join(HERE,  "Arkitekt/?.lua")); addpath(join(HERE, "Arkitekt/?/init.lua"))

local Shell = require("arkitekt.app.runtime.shell")
local StatusPad = require("arkitekt.gui.widgets.data.status_pad")
local StatusBar = require("arkitekt.app.chrome.status_bar.widget")

local style_ok, Style = pcall(require, "arkitekt.gui.style.imgui_defaults")
local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb


-- Initial states for the pads
local transport_override = true
local follow_playhead = false
local quantize_enabled = true

-- Status bar configuration
local function get_status()
  return {
    color = hexrgb("#41E0A3"),
    text  = "Status Pads Demo  •  Clean Toggle Widgets",
  }
end
local status_bar = StatusBar.new({ height = 28, get_status = get_status })

-- Pad instances
local pads = {}

local function init_pads()
  pads.transport = StatusPad.new({
    id = "transport_pad",
    width = 250, height = 40,
    color = hexrgb("#41E0A3"), -- Teal/Green
    primary_text = "Transport Override",
    state = transport_override,
    icon_type = "check",
    on_click = function(new_state)
      transport_override = new_state
      pads.transport:set_state(new_state)
    end,
  })
  
  pads.follow = StatusPad.new({
    id = "follow_pad",
    width = 250, height = 40,
    color = hexrgb("#5B8DFF"), -- Blue
    primary_text = "Follow Playhead",
    state = follow_playhead,
    icon_type = "check",
    on_click = function(new_state)
      follow_playhead = new_state
      pads.follow:set_state(new_state)
    end,
  })
  
  pads.quantize = StatusPad.new({
    id = "quantize_pad",
    width = 250, height = 52, -- Slightly taller for two lines of text
    color = hexrgb("#FFA94D"), -- Orange
    primary_text = "Quantize",
    secondary_text = quantize_enabled and "Quantized" or "Off",
    state = quantize_enabled,
    icon_type = "minus",
    on_click = function(new_state)
      quantize_enabled = new_state
      pads.quantize:set_state(new_state)
      pads.quantize:set_secondary_text(new_state and "Quantized" or "Off")
    end,
  })
end

init_pads()

-- Main draw loop
local function draw(ctx)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#EEEEEE"))
  
  ImGui.Dummy(ctx, 1, 8)
  ImGui.Text(ctx, "Toggle Controls")
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 1, 10)
  
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#999999"))
  ImGui.TextWrapped(ctx, "These widgets are styled to match the toggle buttons from the reference screenshot. Click any pad to toggle its state.")
  ImGui.PopStyleColor(ctx)
  
  ImGui.Dummy(ctx, 1, 18)
  
  local start_x, start_y = ImGui.GetCursorScreenPos(ctx)
  local gap = 12
  
  -- Draw pads in a vertical stack
  pads.transport:draw(ctx, start_x, start_y)
  pads.follow:draw(ctx, start_x, start_y + 40 + gap)
  pads.quantize:draw(ctx, start_x, start_y + (40 + gap) + (40 + gap))

  ImGui.PopStyleColor(ctx)
end

-- Run the application shell
Shell.run({
  title        = "Arkitekt – Status Pads Demo (Reworked)",
  draw         = draw,
  style        = style_ok and Style or nil,
  initial_pos  = { x = 140, y = 140 },
  initial_size = { w = 320, h = 380 },
  min_size     = { w = 300, h = 350 },
  content_padding = 20,
  status_bar   = status_bar
})