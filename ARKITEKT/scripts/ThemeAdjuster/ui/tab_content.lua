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
local ColorsView = require("ThemeAdjuster.ui.views.colors_view")
local AdditionalView = require("ThemeAdjuster.ui.views.additional_view")
local DebugView = require("ThemeAdjuster.ui.views.debug_view")
local Renderer = require("arkitekt.gui.widgets.media.package_tiles.renderer")

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

  -- Create AdditionalView first (holds shared assignment state)
  local additional_view = AdditionalView.new(State, Config, settings)

  -- Register all views in a table for clean lookup
  self.views = {
    ASSEMBLER = AssemblerView.new(State, Config, settings),
    GLOBAL = GlobalView.new(State, Config, settings),
    TCP = TCPView.new(State, Config, settings, additional_view),
    MCP = MCPView.new(State, Config, settings, additional_view),
    TRANSPORT = TransportView.new(State, Config, settings),
    ENVELOPES = EnvelopeView.new(State, Config, settings),
    COLORS = ColorsView.new(State, Config, settings),
    ADDITIONAL = additional_view,
    DEBUG = DebugView.new(State, Config, settings),
  }

  -- Give AdditionalView a callback to invalidate TCP/MCP caches when assignments change
  additional_view:set_cache_invalidation_callback(function()
    if self.views.TCP and self.views.TCP.refresh_additional_params then
      self.views.TCP:refresh_additional_params()
    end
    if self.views.MCP and self.views.MCP.refresh_additional_params then
      self.views.MCP:refresh_additional_params()
    end
  end)

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
  -- Clear image caches when switching tabs (prevents stale handle errors)
  if self.last_tab_id and self.last_tab_id ~= tab_id then
    -- Clear package renderer cache (for ASSEMBLER tab)
    Renderer.clear_image_cache()

    -- Clear debug view cache if leaving debug tab
    if self.last_tab_id == "DEBUG" and self.views.DEBUG and self.views.DEBUG.image_cache then
      self.views.DEBUG.image_cache:clear()
    end
  end
  self.last_tab_id = tab_id

  -- Registry-based tab routing
  local view = self.views[tab_id]

  if view then
    view:draw(ctx, shell_state)
  else
    ImGui.Text(ctx, "Unknown tab: " .. tostring(tab_id))
  end
end

return M
