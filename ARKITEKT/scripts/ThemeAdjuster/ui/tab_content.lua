-- @noindex
-- ThemeAdjuster/ui/tab_content.lua
-- Tab content handler - routes tabs to appropriate views

local ImGui = require 'imgui' '0.10'
local AssemblerView = require("ThemeAdjuster.ui.views.assembler_view")
local GlobalView = require("ThemeAdjuster.ui.views.global_view")
local TCPView = require("ThemeAdjuster.ui.views.tcp_view")
local MCPView = require("ThemeAdjuster.ui.views.mcp_view")
local TransportView = require("ThemeAdjuster.ui.views.transport_view")
local EnvelopeView = require("ThemeAdjuster.ui.views.envelope_view")
local DebugView = require("ThemeAdjuster.ui.views.debug_view")
local Renderer = require("rearkitekt.gui.widgets.media.package_tiles.renderer")

local M = {}
local TabContent = {}
TabContent.__index = TabContent

function M.new(State, Config, settings)
  local self = setmetatable({
    State = State,
    Config = Config,
    settings = settings,
    views = {},  -- Tab registry
    last_tab_id = nil,  -- Track tab changes for cache clearing
  }, TabContent)

  -- Register all views in a table for clean lookup
  self.views = {
    ASSEMBLER = AssemblerView.new(State, Config, settings),
    GLOBAL = GlobalView.new(State, Config, settings),
    TCP = TCPView.new(State, Config, settings),
    MCP = MCPView.new(State, Config, settings),
    TRANSPORT = TransportView.new(State, Config, settings),
    ENVELOPES = EnvelopeView.new(State, Config, settings),
    DEBUG = DebugView.new(State, Config, settings),
  }

  return self
end

function TabContent:update(dt)
  -- Update animations for views that support it
  for _, view in pairs(self.views) do
    if view.update then
      view:update(dt)
    end
  end
end

function TabContent:draw(ctx, tab_id, shell_state)
  -- Clear image cache when switching tabs to avoid invalid image handle errors
  if self.last_tab_id and self.last_tab_id ~= tab_id then
    Renderer.clear_image_cache()
  end
  self.last_tab_id = tab_id

  -- Registry-based tab routing
  local view = self.views[tab_id]

  if view then
    view:draw(ctx, shell_state)
  elseif tab_id == "COLORS" then
    ImGui.Text(ctx, "Colors tab - Coming soon")
  else
    ImGui.Text(ctx, "Unknown tab: " .. tostring(tab_id))
  end
end

return M
