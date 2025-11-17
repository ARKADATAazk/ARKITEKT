-- @noindex
-- ThemeAdjuster/ui/gui.lua
-- Main GUI orchestrator with tab system

local ImGui = require 'imgui' '0.10'
local Config = require("ThemeAdjuster.core.config")
local PackageManager = require("ThemeAdjuster.packages.manager")
local TabContent = require("ThemeAdjuster.ui.tab_content")
local Theme = require("ThemeAdjuster.core.theme")

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
  local theme_root = demo_mode and nil or Theme.get_theme_root_path()
  local packages = PackageManager.scan_packages(theme_root, demo_mode)
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

  -- Update window title with current theme name
  local theme_info = Theme.get_theme_info()
  local theme_name = theme_info.theme_name or ""
  if theme_name ~= "" then
    window:set_title("Theme Adjuster [" .. theme_name .. "]")
  else
    window:set_title("Theme Adjuster")
  end

  -- Get active tab from window (menutabs system)
  local active_tab = window:get_active_tab()

  -- Track active tab changes
  if self.current_tab ~= active_tab then
    self.current_tab = active_tab
    self.State.set_active_tab(active_tab)
  end

  -- Draw tab content
  if self.tab_content then
    self.tab_content:draw(ctx, active_tab, shell_state)
  end
end

return M
