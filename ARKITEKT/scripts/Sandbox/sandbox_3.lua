-- @noindex
-- ARKITEKT/scripts/Sandbox/sandbox_3.lua
-- Debug Console Test - Mock logging and profiling

local script_path = debug.getinfo(1, "S").source:match("@?(.*)[\\/]") or ""
local root_path = script_path:match("(.*)[\\/][^\\/]+[\\/]?$") or script_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path
if not root_path:match("[\\/]$") then root_path = root_path .. "/" end

local arkitekt_path = root_path .. "ARKITEKT/"
package.path = arkitekt_path .. "?.lua;" .. arkitekt_path .. "?/init.lua;" .. package.path
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path

local Shell = require('arkitekt.app.runtime.shell')
local Arkit = require('arkitekt.arkit')
local Console = require('arkitekt.debug.console')
local Logger = require('arkitekt.debug.logger')

local ImGui = Arkit.ImGui
local hexrgb = Arkit.hexrgb

local StyleOK, Style = pcall(require, 'arkitekt.gui.style.imgui_defaults')
local Colors = require('arkitekt.core.colors')

local console = Console.new()

local mock_state = {
  frame_count = 0,
  simulation_running = true,
  active_tiles = 0,
  hover_item = nil,
  last_profile_time = 0,
}

local function generate_mock_logs()
  local categories = {"ANIM", "PLAYBACK", "SELECTION", "UI", "DND"}
  local messages = {
    "Tile spawn animation started",
    "Region changed from #3 to #7",
    "Multi-select limit reached",
    "Mouse hover detected on tile",
    "Drag operation initiated",
    "Color palette updated",
    "State synchronized",
    "Cache invalidated",
    "Event handler triggered",
    "Resource loaded successfully",
  }
  
  if math.random() < 0.1 then
    local cat = categories[math.random(#categories)]
    local msg = messages[math.random(#messages)]
    
    local roll = math.random()
    if roll < 0.6 then
      Logger.info(cat, msg)
    elseif roll < 0.8 then
      Logger.debug(cat, msg, {x = math.random(100), y = math.random(100)})
    elseif roll < 0.9 then
      Logger.warn(cat, msg)
    else
      Logger.error(cat, msg)
    end
  end
end

local function simulate_profiling()
  local current_time = reaper.time_precise()
  
  if current_time - mock_state.last_profile_time > 0.5 then
    Logger.profile("grid_render", math.random(10, 35) / 10)
    Logger.profile("animation_tick", math.random(5, 15) / 10)
    Logger.profile("dnd_update", math.random(3, 12) / 10)
    Logger.profile("state_update", math.random(1, 5) / 10)
    
    mock_state.last_profile_time = current_time
  end
end

local function simulate_state_changes()
  if mock_state.frame_count % 120 == 0 then
    mock_state.active_tiles = math.random(3, 12)
    Logger.debug("STATE", "Active tiles updated", {count = mock_state.active_tiles})
  end
  
  if mock_state.frame_count % 180 == 0 then
    mock_state.hover_item = math.random(100)
    Logger.debug("UI", "Hover item changed", {id = mock_state.hover_item})
  end
  
  if math.random() < 0.005 then
    Logger.warn("MEMORY", "High memory usage detected", {usage_mb = math.random(200, 500)})
  end
  
  if math.random() < 0.002 then
    Logger.error("NETWORK", "Connection timeout", {attempt = math.random(1, 3)})
  end
end

local function init()
  Logger.info("SYSTEM", "Debug Console Test Started")
  Logger.debug("CONFIG", "Console initialized")
  
  Logger.info("ANIM", "Animation system loaded")
  Logger.info("PLAYBACK", "Playback manager ready")
  Logger.info("UI", "User interface initialized")
  
  Logger.warn("SYSTEM", "This is a test environment")
  Logger.error("TEST", "Simulated error for demonstration")
  
  Logger.profile("startup", 45.7)
end

init()

Shell.run({
  title = "Debug Console Test",
  version = "v0.1.0",
  version_color = hexrgb("#888888FF"),
  style = StyleOK and Style or nil,
  initial_pos = { x = 120, y = 120 },
  initial_size = { w = 900, h = 600 },
  min_size = { w = 600, h = 400 },
  icon_color = hexrgb("#41E0A3"),
  icon_size = 18,
  
  draw = function(ctx, shell_state)
    mock_state.frame_count = mock_state.frame_count + 1
    
    if mock_state.simulation_running then
      generate_mock_logs()
      simulate_profiling()
      simulate_state_changes()
    end
    
    if console.panel and console.panel.filter then
      Console.set_category_filter(console, console.panel.filter.dropdown_value or "All")
    end
    
    if console.panel and console.panel.search then
      Console.set_search(console, console.panel.search.search_text or "")
    end
    
    ImGui.Text(ctx, "Debug Console Test")
    ImGui.Separator(ctx)
    ImGui.Text(ctx, "")
    
    if ImGui.Button(ctx, mock_state.simulation_running and "Pause Simulation" or "Resume Simulation", 150, 24) then
      mock_state.simulation_running = not mock_state.simulation_running
      Logger.info("TEST", mock_state.simulation_running and "Simulation resumed" or "Simulation paused")
    end
    
    ImGui.SameLine(ctx, 0, 8)
    
    if ImGui.Button(ctx, "Generate Burst", 150, 24) then
      for i = 1, 20 do
        generate_mock_logs()
      end
      Logger.info("TEST", "Generated 20 log entries")
    end
    
    ImGui.SameLine(ctx, 0, 8)
    
    if ImGui.Button(ctx, "Simulate Error", 150, 24) then
      Logger.error("TEST", "User triggered test error", {severity = "high"})
    end
    
    ImGui.Text(ctx, "")
    ImGui.Text(ctx, string.format("Frame: %d", mock_state.frame_count))
    ImGui.Text(ctx, string.format("Active Tiles: %d", mock_state.active_tiles))
    ImGui.Text(ctx, string.format("Hover Item: %s", tostring(mock_state.hover_item or "none")))
    
    ImGui.Separator(ctx)
    ImGui.Text(ctx, "")
    
    Console.render(console, ctx)
  end,
})