-- @noindex
-- ARK_NodeEditor.lua - Node editor demonstration
-- Shows visual programming / patching interface

-- ============================================================================
-- LOAD ARKITEKT FRAMEWORK
-- ============================================================================
local Ark = dofile(debug.getinfo(1,"S").source:sub(2):match("(.-ARKITEKT[/\\])") .. "arkitekt" .. package.config:sub(1,1) .. "init.lua")

-- ============================================================================
-- IMPORTS
-- ============================================================================
local Shell = require('arkitekt.runtime.shell')

-- ============================================================================
-- STATE
-- ============================================================================
local state = {
  pan_x = 400,
  pan_y = 300,
  zoom = 1.0,

  -- Example nodes for an audio patch
  nodes = {
    {
      id = "osc",
      label = "Oscillator",
      x = 50,
      y = 50,
      width = 140,
      height = 120,
      inputs = {
        {id = "freq", label = "Frequency", type = "float"},
        {id = "shape", label = "Shape", type = "enum"},
      },
      outputs = {
        {id = "out", label = "Audio Out", type = "audio"},
      },
      is_selected = false,
    },
    {
      id = "filter",
      label = "Low Pass Filter",
      x = 250,
      y = 80,
      width = 140,
      height = 120,
      inputs = {
        {id = "in", label = "Audio In", type = "audio"},
        {id = "cutoff", label = "Cutoff", type = "float"},
        {id = "res", label = "Resonance", type = "float"},
      },
      outputs = {
        {id = "out", label = "Audio Out", type = "audio"},
      },
      is_selected = false,
    },
    {
      id = "output",
      label = "Audio Output",
      x = 450,
      y = 100,
      width = 120,
      height = 80,
      inputs = {
        {id = "in", label = "Audio In", type = "audio"},
      },
      outputs = {},
      is_selected = false,
    },
    {
      id = "lfo",
      label = "LFO",
      x = 50,
      y = 220,
      width = 120,
      height = 100,
      inputs = {
        {id = "rate", label = "Rate", type = "float"},
      },
      outputs = {
        {id = "out", label = "CV Out", type = "cv"},
      },
      is_selected = false,
    },
  },

  -- Example links
  links = {
    {
      id = "link1",
      from_node = "osc",
      from_pin = "out",
      to_node = "filter",
      to_pin = "in",
    },
    {
      id = "link2",
      from_node = "filter",
      from_pin = "out",
      to_node = "output",
      to_pin = "in",
    },
    {
      id = "link3",
      from_node = "lfo",
      from_pin = "out",
      to_node = "filter",
      to_pin = "cutoff",
    },
  },
}

-- ============================================================================
-- GUI
-- ============================================================================
local function draw_gui(ctx)
  local ImGui = Ark.ImGui

  ImGui.Text(ctx, "ARKITEKT Node Editor Demo")
  ImGui.Text(ctx, "Visual Programming / Audio Patching Interface")
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Controls
  ImGui.Text(ctx, "Pan: " .. string.format("%.0f, %.0f", state.pan_x, state.pan_y))
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Reset View") then
    state.pan_x = 400
    state.pan_y = 300
    state.zoom = 1.0
  end

  ImGui.Spacing(ctx)

  -- Node editor
  local result = Ark.Nodes(ctx, {
    width = 800,
    height = 500,
    nodes = state.nodes,
    links = state.links,
    pan_x = state.pan_x,
    pan_y = state.pan_y,
    zoom = state.zoom,
    show_grid = true,
    on_node_move = function(node_id, x, y)
      -- Node position updated automatically
    end,
    on_link_create = function(from_node, from_pin, to_node, to_pin)
      -- Link created automatically
    end,
  })

  -- Update state from result
  if result.changed then
    state.nodes = result.nodes
    state.links = result.links
    state.pan_x = result.pan_x
    state.pan_y = result.pan_y
    state.zoom = result.zoom
  end

  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Text(ctx, "Controls: Drag nodes  |  Drag pins to create links  |  Middle-mouse to pan  |  Scroll to zoom")
  ImGui.Text(ctx, string.format("Nodes: %d  |  Links: %d  |  Zoom: %.1fx", #state.nodes, #state.links, state.zoom))
end

-- ============================================================================
-- SHELL
-- ============================================================================
Shell.run({
  gui = draw_gui,
  window = {
    title = "ARKITEKT Node Editor Demo",
    width = 900,
    height = 700,
  },
})
