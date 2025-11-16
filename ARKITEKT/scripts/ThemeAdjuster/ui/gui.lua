-- @noindex
-- ThemeAdjuster/ui/gui.lua
-- Main GUI orchestrator with tab system

local ImGui = require 'imgui' '0.10'
local Config = require("ThemeAdjuster.core.config")
local PackageManager = require("ThemeAdjuster.packages.manager")
local TabContent = require("ThemeAdjuster.ui.tab_content")

local M = {}
local GUI = {}
GUI.__index = GUI

function M.create(State, AppConfig, settings)
  local self = setmetatable({
    State = State,
    Config = AppConfig,
    settings = settings,
    tab_content = nil,
    current_tab = State.get_active_tab(),
  }, GUI)

  -- Initialize packages
  self:refresh_packages()

  -- Create tab content handler
  self.tab_content = TabContent.new(State, AppConfig, settings)

  return self
end

function GUI:refresh_packages()
  local demo_mode = self.State.get_demo_mode()
  local packages = PackageManager.scan_packages(nil, demo_mode)
  self.State.set_packages(packages)

  -- Initialize order if empty
  local order = self.State.get_package_order()
  if #order == 0 then
    for _, pkg in ipairs(packages) do
      order[#order + 1] = pkg.id
    end
    self.State.set_package_order(order)
  end
end

function GUI:update_state(ctx, window)
  -- Update animations
  if self.tab_content and self.tab_content.update then
    self.tab_content:update(0.016)
  end
end

function GUI:draw(ctx, window, shell_state)
  self:update_state(ctx, window)

  -- Draw tab bar
  if ImGui.BeginTabBar(ctx, 'main_tabs') then
    for _, tab_def in ipairs(Config.TABS) do
      if ImGui.BeginTabItem(ctx, tab_def.label) then
        -- Track active tab
        if self.current_tab ~= tab_def.id then
          self.current_tab = tab_def.id
          self.State.set_active_tab(tab_def.id)
        end

        -- Draw tab content
        if self.tab_content then
          self.tab_content:draw(ctx, tab_def.id, shell_state)
        end

        ImGui.EndTabItem(ctx)
      end
    end
    ImGui.EndTabBar(ctx)
  end
end

return M
