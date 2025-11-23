-- @noindex
-- arkitekt/debug/console_window.lua
-- Standalone debug console window using proper ARKITEKT window system

local ark = require('arkitekt')
local Shell = ark.Shell
local Console = ark.Console
local Logger = ark.Logger

local M = {}

local Style = ark.ImGuiStyle
local Colors = ark.Colors
local hexrgb = ark.hexrgb


local window_state = {
  runtime = nil,
  console = nil,
  is_open = false,
}

local function hexrgb(hex)
  if hex:sub(1, 1) == "#" then hex = hex:sub(2) end
  local h = tonumber(hex, 16)
  if not h then return hexrgb("#FFFFFF") end
  return (#hex == 8) and h or ((h << 8) | 0xFF)
end

function M.launch()
  if window_state.is_open and window_state.runtime then
    Logger.info("CONSOLE", "Console window already open")
    return
  end
  
  window_state.console = Console.new()
  window_state.is_open = true
  
  Logger.info("CONSOLE", "Debug console window launched")
  
  window_state.runtime = Shell.run({
    title = "ARKITEKT Debug Console",
    version = "v1.0.0",
    version_color = hexrgb("#888888FF"),
    style = StyleOK and Style or nil,
    initial_pos = { x = 120, y = 120 },
    initial_size = { w = 1000, h = 600 },
    min_size = { w = 600, h = 400 },
    icon_color = hexrgb("#41E0A3FF"),
    icon_size = 18,
    show_icon = false,
    show_status_bar = false,
    show_titlebar = true,
    raw_content = true,
    
    window = {
      content_padding = 0,
    },
    
    draw = function(ctx, shell_state)
      if window_state.console then
        Console.render(window_state.console, ctx)
      end
      return true
    end,
    
    on_close = function()
      window_state.is_open = false
      window_state.runtime = nil
      window_state.console = nil
      Logger.info("CONSOLE", "Debug console window closed")
    end,
  })
end

function M.is_open()
  return window_state.is_open
end

function M.close()
  if window_state.runtime and window_state.runtime.request_close then
    window_state.runtime:request_close()
  end
  window_state.is_open = false
  window_state.runtime = nil
  window_state.console = nil
  Logger.info("CONSOLE", "Debug console window closed programmatically")
end

return M
