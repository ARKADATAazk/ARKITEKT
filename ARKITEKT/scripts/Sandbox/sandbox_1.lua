-- @noindex
-- ARKITEKT/scripts/Sandbox/sandbox_1.lua
-- Music Flow Node System Demo

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

local Canvas = require('arkitekt.gui.widgets.editors.nodal.canvas')
local Node = require('arkitekt.gui.widgets.editors.nodal.core.node')
local Connection = require('arkitekt.gui.widgets.editors.nodal.core.connection')
local Config = require('arkitekt.gui.widgets.editors.nodal.defaults')

local ImGui = Arkit.ImGui
local hexrgb = Arkit.hexrgb

local StyleOK, Style = pcall(require, 'arkitekt.gui.style.imgui_defaults')
local Colors = require('arkitekt.core.colors')

local function create_mock_music_flow()
  local config = Config.get()
  
  local nodes = {}
  
  local intro = Node.new({
    guid = "node-intro",
    id = "intro",
    name = "Intro (Calm)",
    mirror_mode = "linked",
    template_ref = "template-intro",
    properties = {
      wwise_state = "Combat_Intro_Calm",
      loop_count = 1,
      transition_type = "crossfade",
      transition_duration = 2.0,
    },
    next_section = "node-build",
    triggers = {
      { event = "OnEnemySpotted", target_section = "node-peak", mode = "INCREMENTAL" },
    },
  })
  table.insert(nodes, intro)
  
  local build = Node.new({
    guid = "node-build",
    id = "build",
    name = "Build Up",
    mirror_mode = "linked",
    template_ref = "template-build",
    properties = {
      wwise_state = "Combat_Build",
      loop_count = 2,
      transition_type = "crossfade",
      transition_duration = 1.5,
    },
    next_section = "node-peak",
    triggers = {
      { event = "OnPlayerDeath", target_section = "node-gameover", mode = "IMMEDIATE" },
    },
  })
  table.insert(nodes, build)
  
  local peak = Node.new({
    guid = "node-peak",
    id = "peak",
    name = "Peak (Intense)",
    mirror_mode = "detached",
    template_ref = "template-peak",
    properties = {
      wwise_state = "Combat_Peak_Intense",
      loop_count = 3,
      transition_type = "cut",
      transition_duration = 0.5,
    },
    next_section = "node-boss",
    triggers = {
      { event = "OnBossAppears", target_section = "node-boss", mode = "END_OF_SEGMENT" },
      { event = "OnAllEnemiesDefeated", target_section = "node-victory", mode = "INCREMENTAL" },
    },
  })
  table.insert(nodes, peak)
  
  local boss = Node.new({
    guid = "node-boss",
    id = "boss",
    name = "Boss Fight",
    mirror_mode = "frozen",
    template_ref = "template-boss",
    properties = {
      wwise_state = "Combat_Boss",
      loop_count = 0,
      transition_type = "crossfade",
      transition_duration = 3.0,
    },
    next_section = nil,
    triggers = {
      { event = "OnBossDefeated", target_section = "node-victory", mode = "IMMEDIATE" },
      { event = "OnPlayerDeath", target_section = "node-gameover", mode = "IMMEDIATE" },
    },
  })
  table.insert(nodes, boss)
  
  local victory = Node.new({
    guid = "node-victory",
    id = "victory",
    name = "Victory",
    mirror_mode = "linked",
    template_ref = "template-victory",
    properties = {
      wwise_state = "Victory_Theme",
      loop_count = 1,
      transition_type = "crossfade",
      transition_duration = 2.0,
    },
    next_section = nil,
    triggers = {},
  })
  table.insert(nodes, victory)
  
  local gameover = Node.new({
    guid = "node-gameover",
    id = "gameover",
    name = "Game Over",
    mirror_mode = "linked",
    template_ref = "template-gameover",
    properties = {
      wwise_state = "GameOver_Theme",
      loop_count = 1,
      transition_type = "cut",
      transition_duration = 0.0,
    },
    next_section = nil,
    triggers = {},
  })
  table.insert(nodes, gameover)
  
  local connections = {}
  
  table.insert(connections, Connection.new_trigger("node-intro", "node-peak", "OnEnemySpotted", "INCREMENTAL", config.colors.connection_types.trigger))
  table.insert(connections, Connection.new_trigger("node-build", "node-gameover", "OnPlayerDeath", "IMMEDIATE", config.colors.connection_types.trigger))
  table.insert(connections, Connection.new_trigger("node-peak", "node-boss", "OnBossAppears", "END_OF_SEGMENT", config.colors.connection_types.trigger))
  table.insert(connections, Connection.new_trigger("node-peak", "node-victory", "OnAllEnemiesDefeated", "INCREMENTAL", config.colors.connection_types.trigger))
  table.insert(connections, Connection.new_trigger("node-boss", "node-victory", "OnBossDefeated", "IMMEDIATE", config.colors.connection_types.trigger))
  table.insert(connections, Connection.new_trigger("node-boss", "node-gameover", "OnPlayerDeath", "IMMEDIATE", config.colors.connection_types.trigger))
  
  return nodes, connections
end

local nodes, connections = create_mock_music_flow()
local canvas = Canvas.new({
  nodes = nodes,
  connections = connections,
  container_x = 100,
  container_width = 320,
})

Shell.run({
  title = "Music Flow Node System",
  version = "v0.1.0",
  version_color = hexrgb("#888888FF"),
  style = StyleOK and Style or nil,
  initial_pos = { x = 100, y = 100 },
  initial_size = { w = 1200, h = 800 },
  min_size = { w = 800, h = 600 },
  
  draw = function(ctx, shell_state)
    if ImGui.Button(ctx, "Center View") then
      Canvas.center_on_content(canvas)
    end
    
    ImGui.SameLine(ctx)
    
    if ImGui.Button(ctx, "Reset Zoom") then
      Canvas.reset_viewport(canvas)
    end
    
    ImGui.SameLine(ctx)
    ImGui.Text(ctx, "|")
    ImGui.SameLine(ctx)
    
    local hovered_name = "None"
    if canvas.hovered_node and canvas.hovered_node.name then
      hovered_name = canvas.hovered_node.name
    end
    
    ImGui.Text(ctx, string.format("Nodes: %d | Connections: %d | Hovered: %s | Zoom: %.2f", 
      #canvas.nodes, #canvas.connections, hovered_name, canvas.viewport.scale))
    
    ImGui.SameLine(ctx)
    ImGui.Text(ctx, string.format("| VP: %.0f,%.0f %.0fx%.0f", 
      canvas.viewport.bounds_x or 0, canvas.viewport.bounds_y or 0, 
      canvas.viewport.bounds_w or 0, canvas.viewport.bounds_h or 0))
    
    ImGui.Separator(ctx)
    
    -- Get content region available
    local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)
    
    -- Style the child window
    ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#0A0A0A"))
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 0, 0)
    ImGui.PushStyleColor(ctx, ImGui.Col_Border, hexrgb("#404040"))
    
    -- Create child window that fills available space with no scrollbars
    -- Using WindowFlags_NoScrollbar and WindowFlags_NoScrollWithMouse to prevent scroll interference
    local child_flags = 0  -- or ImGui.ChildFlags_None if available
    local window_flags = ImGui.WindowFlags_NoScrollbar
    if ImGui.WindowFlags_NoScrollWithMouse then
      window_flags = window_flags | ImGui.WindowFlags_NoScrollWithMouse
    end
    
    if ImGui.BeginChild(ctx, "##canvas_area", avail_w, avail_h, child_flags, window_flags) then
      -- Get the actual child window position and size
      local win_x, win_y = ImGui.GetWindowPos(ctx)
      local win_w, win_h = ImGui.GetWindowSize(ctx)
      
      -- Ensure we have valid dimensions
      if win_w > 0 and win_h > 0 then
        -- Pass the window position and size to Canvas.render
        Canvas.render(canvas, ctx, win_x, win_y, win_w, win_h)
      end
      
      ImGui.EndChild(ctx)
    end
    
    ImGui.PopStyleColor(ctx, 2)
    ImGui.PopStyleVar(ctx)
  end,
})