-- @noindex
-- rearkitekt/debug/console_window.lua
-- Standalone console window launcher

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Console = require('rearkitekt.debug.console')
local Logger = require('rearkitekt.debug.logger')

local M = {}

local window_state = {
  ctx = nil,
  console = nil,
  is_open = false,
}

local function draw_loop()
  local ctx = window_state.ctx
  if not ctx then return end
  
  ImGui.SetNextWindowSize(ctx, 1000, 600, ImGui.Cond_FirstUseEver)
  
  local visible, open = ImGui.Begin(ctx, 'ARKITEKT Debug Console', true)
  
  if visible then
    Console.render(window_state.console, ctx)
    ImGui.End(ctx)
  end
  
  if open then
    reaper.defer(draw_loop)
  else
    -- Window closed by user
    window_state.is_open = false
    if window_state.ctx then
      Logger.info("CONSOLE", "Debug console window closed")
      window_state.ctx = nil
      window_state.console = nil
    end
  end
end

function M.launch()
  if window_state.is_open and window_state.ctx then
    Logger.info("CONSOLE", "Console window already open")
    return
  end
  
  window_state.ctx = ImGui.CreateContext('ARKITEKT Debug Console')
  window_state.console = Console.new()
  window_state.is_open = true
  
  Logger.info("CONSOLE", "Debug console window launched")
  
  draw_loop()
end

function M.is_open()
  return window_state.is_open
end

function M.close()
  if window_state.ctx then
    window_state.is_open = false
    window_state.ctx = nil
    window_state.console = nil
    Logger.info("CONSOLE", "Debug console window closed programmatically")
  end
end

return M