-- @noindex
-- ThemeAdjuster/ui/gui.lua
-- Main GUI orchestrator

local ImGui = require 'imgui' '0.10'
local PackagesView = require("ThemeAdjuster.ui.views.packages_view")
local PackageManager = require("ThemeAdjuster.packages.manager")

local M = {}
local GUI = {}
GUI.__index = GUI

function M.create(State, AppConfig, settings)
  local self = setmetatable({
    State = State,
    Config = AppConfig,
    settings = settings,
    packages_view = nil,
    shell_state = nil,
  }, GUI)

  -- Initialize packages view
  self.packages_view = PackagesView.new(State, AppConfig, settings)

  -- Initial package scan
  self:refresh_packages()

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
  -- Update animations, state, etc.
  if self.packages_view and self.packages_view.update then
    self.packages_view:update(0.016)
  end
end

function GUI:draw(ctx, window, shell_state)
  self.shell_state = shell_state

  self:update_state(ctx, window)

  -- Draw packages view
  if self.packages_view then
    self.packages_view:draw(ctx, shell_state)
  end
end

return M
