-- @noindex
-- ThemeAdjuster/ui/tab_content.lua
-- Tab content handler - routes tabs to appropriate views

local ImGui = require 'imgui' '0.10'
local AssemblerView = require("ThemeAdjuster.ui.views.assembler_view")
local GlobalView = require("ThemeAdjuster.ui.views.global_view")
local TCPView = require("ThemeAdjuster.ui.views.tcp_view")
local MCPView = require("ThemeAdjuster.ui.views.mcp_view")
local TransportView = require("ThemeAdjuster.ui.views.transport_view")
local DebugView = require("ThemeAdjuster.ui.views.debug_view")

local M = {}
local TabContent = {}
TabContent.__index = TabContent

function M.new(State, Config, settings)
  local self = setmetatable({
    State = State,
    Config = Config,
    settings = settings,
    assembler_view = nil,
    global_view = nil,
    tcp_view = nil,
    mcp_view = nil,
    transport_view = nil,
    debug_view = nil,
  }, TabContent)

  -- Create assembler view (package grid with Panel)
  self.assembler_view = AssemblerView.new(State, Config, settings)

  -- Create global view (color controls)
  self.global_view = GlobalView.new(State, Config, settings)

  -- Create TCP view (track control panel)
  self.tcp_view = TCPView.new(State, Config, settings)

  -- Create MCP view (mixer control panel)
  self.mcp_view = MCPView.new(State, Config, settings)

  -- Create transport view (transport bar)
  self.transport_view = TransportView.new(State, Config, settings)

  -- Create debug view (theme info + image browser)
  self.debug_view = DebugView.new(State, Config, settings)

  return self
end

function TabContent:update(dt)
  -- Update animations for active views
  if self.assembler_view and self.assembler_view.update then
    self.assembler_view:update(dt)
  end
  if self.debug_view and self.debug_view.update then
    self.debug_view:update(dt)
  end
end

function TabContent:draw(ctx, tab_id, shell_state)
  if tab_id == "ASSEMBLER" then
    if self.assembler_view then
      self.assembler_view:draw(ctx, shell_state)
    end
  elseif tab_id == "GLOBAL" then
    if self.global_view then
      self.global_view:draw(ctx, shell_state)
    end
  elseif tab_id == "TCP" then
    if self.tcp_view then
      self.tcp_view:draw(ctx, shell_state)
    end
  elseif tab_id == "MCP" then
    if self.mcp_view then
      self.mcp_view:draw(ctx, shell_state)
    end
  elseif tab_id == "COLORS" then
    ImGui.Text(ctx, "Colors tab - Coming soon")
  elseif tab_id == "ENVELOPES" then
    ImGui.Text(ctx, "Envelopes tab - Coming soon")
  elseif tab_id == "TRANSPORT" then
    if self.transport_view then
      self.transport_view:draw(ctx, shell_state)
    end
  elseif tab_id == "DEBUG" then
    if self.debug_view then
      self.debug_view:draw(ctx, shell_state)
    end
  else
    ImGui.Text(ctx, "Unknown tab: " .. tostring(tab_id))
  end
end

return M
