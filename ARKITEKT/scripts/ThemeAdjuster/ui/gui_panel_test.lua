-- @noindex
-- ThemeAdjuster/ui/gui_panel_test.lua
-- Test version using Panel tab_strip instead of Shell menutabs

local ImGui = require 'imgui' '0.10'
local Config = require("ThemeAdjuster.core.config")
local PackageManager = require("ThemeAdjuster.packages.manager")
local TabContent = require("ThemeAdjuster.ui.tab_content")
local MainPanel = require("ThemeAdjuster.ui.main_panel")

local M = {}
local GUI = {}
GUI.__index = GUI

function M.create(State, AppConfig, settings)
  local self = setmetatable({
    State = State,
    Config = AppConfig,
    settings = settings,
    tab_content = nil,
    main_panel = nil,
    current_tab = State.get_active_tab(),
  }, GUI)

  -- Initialize packages
  self:refresh_packages()

  -- Create main panel with tab_strip
  self.main_panel = MainPanel.create_main_panel(State, {
    on_tab_change = function(tab_id, tab_index)
      State.set_active_tab(tab_id)
      self.current_tab = tab_id
    end,
  })

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

  -- Get active tab from main panel
  local active_tab = self.main_panel:get_active_tab_id() or self.current_tab

  -- Track active tab changes
  if self.current_tab ~= active_tab then
    self.current_tab = active_tab
    self.State.set_active_tab(active_tab)
  end

  -- Draw main panel (with tab_strip header)
  if self.main_panel:begin_draw(ctx) then
    -- Draw tab content inside panel
    if self.tab_content then
      self.tab_content:draw(ctx, active_tab, shell_state)
    end
  end
  self.main_panel:end_draw(ctx)
end

return M
