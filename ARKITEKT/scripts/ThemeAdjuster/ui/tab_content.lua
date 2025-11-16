-- @noindex
-- ThemeAdjuster/ui/tab_content.lua
-- Tab content handler - routes tabs to appropriate views

local ImGui = require 'imgui' '0.10'
local AssemblerView = require("ThemeAdjuster.ui.views.assembler_view")

local M = {}
local TabContent = {}
TabContent.__index = TabContent

function M.new(State, Config, settings)
  local self = setmetatable({
    State = State,
    Config = Config,
    settings = settings,
    assembler_view = nil,
  }, TabContent)

  -- Create assembler view (package grid with Panel)
  self.assembler_view = AssemblerView.new(State, Config, settings)

  return self
end

function TabContent:update(dt)
  -- Update animations for active views
  if self.assembler_view and self.assembler_view.update then
    self.assembler_view:update(dt)
  end
end

function TabContent:draw(ctx, tab_id, shell_state)
  if tab_id == "ASSEMBLER" then
    if self.assembler_view then
      self.assembler_view:draw(ctx, shell_state)
    end
  elseif tab_id == "GLOBAL" then
    ImGui.Text(ctx, "Global tab - Coming soon")
  elseif tab_id == "TCP" then
    ImGui.Text(ctx, "TCP tab - Coming soon")
  elseif tab_id == "MCP" then
    ImGui.Text(ctx, "MCP tab - Coming soon")
  elseif tab_id == "COLORS" then
    ImGui.Text(ctx, "Colors tab - Coming soon")
  elseif tab_id == "ENVELOPES" then
    ImGui.Text(ctx, "Envelopes tab - Coming soon")
  elseif tab_id == "TRANSPORT" then
    ImGui.Text(ctx, "Transport tab - Coming soon")
  elseif tab_id == "DEBUG" then
    ImGui.Text(ctx, "Debug tab - Coming soon")
    ImGui.Separator(ctx)
    ImGui.Text(ctx, string.format("Active tab: %s", self.State.get_active_tab()))
    ImGui.Text(ctx, string.format("Demo mode: %s", tostring(self.State.get_demo_mode())))
    ImGui.Text(ctx, string.format("Packages: %d", #self.State.get_packages()))
  else
    ImGui.Text(ctx, "Unknown tab: " .. tostring(tab_id))
  end
end

return M
