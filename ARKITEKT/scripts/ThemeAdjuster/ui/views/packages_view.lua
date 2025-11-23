-- @noindex
-- ThemeAdjuster/ui/views/packages_view.lua
-- Packages grid view with Panel header and ARKITEKT package_tiles

local ImGui = require 'imgui' '0.10'
local Panel = require('arkitekt.gui.widgets.containers.panel')
local PackageTilesGrid = require('arkitekt.gui.widgets.media.package_tiles.grid')
local Button = require('arkitekt.gui.widgets.primitives.button')
local PackageManager = require('ThemeAdjuster.packages.manager')
local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}
local PackagesView = {}
PackagesView.__index = PackagesView

function M.new(State, Config, settings)
  local self = setmetatable({
    State = State,
    Config = Config,
    settings = settings,
    panel = nil,
    grid = nil,
    package_model = nil,
    theme_model = nil,
  }, PackagesView)

  -- Create package model (adapter for the grid)
  self.package_model = self:create_package_model()

  -- Create theme model (for color_from_key)
  self.theme_model = self:create_theme_model()

  -- Create panel with header
  self.panel = Panel.new({
    id = "packages_panel",
    config = {
      header = {
        height = Config.PANEL.header_height,
        show_tabs = false,
        left_buttons = {},
        right_buttons = {},
      },
      content = {
        padding_h = Config.PANEL.padding,
        padding_v = Config.PANEL.padding,
      },
    },
  })

  -- Create grid
  self.grid = PackageTilesGrid.create(
    self.package_model,
    settings,
    self.theme_model
  )

  return self
end

function PackagesView:create_theme_model()
  -- Simple theme model for color generation
  return {
    color_from_key = function(key)
      -- Hash the key to generate a consistent color
      local hash = 0
      for i = 1, #key do
        hash = hash + string.byte(key, i)
      end

      local hue = (hash % 360)
      local sat = 0.6 + (hash % 20) / 100
      local val = 0.5 + (hash % 30) / 100

      -- Simple HSV to RGB (from arkitekt.core.colors)
      local function hsv_to_rgb(h, s, v)
        local c = v * s
        local x = c * (1 - math.abs((h / 60) % 2 - 1))
        local m = v - c

        local r, g, b
        if h < 60 then r, g, b = c, x, 0
        elseif h < 120 then r, g, b = x, c, 0
        elseif h < 180 then r, g, b = 0, c, x
        elseif h < 240 then r, g, b = 0, x, c
        elseif h < 300 then r, g, b = x, 0, c
        else r, g, b = c, 0, x end

        r, g, b = (r + m) * 255, (g + m) * 255, (b + m) * 255

        return ((math.floor(r) << 24) | (math.floor(g) << 16) | (math.floor(b) << 8) | 0xFF)
      end

      return hsv_to_rgb(hue, sat, val)
    end,
  }
end

function PackagesView:create_package_model()
  local State = self.State

  return {
    -- Properties
    index = State.get_packages(),  -- All packages (required by grid)
    active = State.get_active_packages(),
    order = State.get_package_order(),
    excl = {},  -- TODO: Load from state
    pins = {},  -- TODO: Load from state
    tile = State.get_tile_size(),
    demo = State.get_demo_mode(),
    search = State.get_search_text(),
    filters = State.get_filters(),

    -- Methods
    toggle = function(self, pkg_id)
      State.toggle_package(pkg_id)
      self.active = State.get_active_packages()
    end,

    remove = function(self, pkg_id)
      -- TODO: Implement package removal
    end,

    scan = function(self)
      -- Trigger package rescan
      local demo_mode = State.get_demo_mode()
      local packages = PackageManager.scan_packages(nil, demo_mode)
      State.set_packages(packages)
      self.index = packages
    end,

    visible = function(self)
      local packages = State.get_packages()
      local search = State.get_search_text()
      local filters = State.get_filters()
      return PackageManager.filter_packages(packages, search, filters)
    end,

    conflicts = function(self, compute)
      if not compute then return {} end
      local packages = State.get_packages()
      local active = State.get_active_packages()
      local order = State.get_package_order()
      return PackageManager.detect_conflicts(packages, active, order)
    end,
  }
end

function PackagesView:draw_header_content(ctx)
  -- Demo mode checkbox
  local demo = self.State.get_demo_mode()
  local changed, new_demo = ImGui.Checkbox(ctx, 'Demo Mode', demo)
  if changed then
    self.State.set_demo_mode(new_demo)
    self.package_model.demo = new_demo
    local packages = PackageManager.scan_packages(nil, new_demo)
    self.State.set_packages(packages)
  end

  ImGui.SameLine(ctx)

  -- Search input
  ImGui.SetNextItemWidth(ctx, 200)
  local search = self.State.get_search_text()
  local search_changed, new_search = ImGui.InputText(ctx, '##search', search)
  if search_changed then
    self.State.set_search_text(new_search)
    self.package_model.search = new_search
  end

  ImGui.SameLine(ctx)

  -- Tile size slider (modern styled)
  ImGui.Text(ctx, 'Tile Size')
  ImGui.SameLine(ctx)
  ImGui.SetNextItemWidth(ctx, 160)
  local tile_size = self.State.get_tile_size()
  local size_changed, new_size = ImGui.SliderInt(ctx, '##tilesize', tile_size, 160, 420)
  if size_changed then
    self.State.set_tile_size(new_size)
    self.package_model.tile = new_size
  end
  ImGui.SameLine(ctx)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#FFFFFF"))
  ImGui.Text(ctx, string.format('%dpx', tile_size))
  ImGui.PopStyleColor(ctx)

  ImGui.SameLine(ctx)

  -- Area filters
  local filters = self.State.get_filters()
  local filter_changed = false

  local tcp_c, tcp_v = ImGui.Checkbox(ctx, 'TCP', filters.TCP)
  if tcp_c then filters.TCP = tcp_v; filter_changed = true end

  ImGui.SameLine(ctx)
  local mcp_c, mcp_v = ImGui.Checkbox(ctx, 'MCP', filters.MCP)
  if mcp_c then filters.MCP = mcp_v; filter_changed = true end

  ImGui.SameLine(ctx)
  local trans_c, trans_v = ImGui.Checkbox(ctx, 'Transport', filters.Transport)
  if trans_c then filters.Transport = trans_v; filter_changed = true end

  ImGui.SameLine(ctx)
  local glob_c, glob_v = ImGui.Checkbox(ctx, 'Global', filters.Global)
  if glob_c then filters.Global = glob_v; filter_changed = true end

  if filter_changed then
    self.State.set_filters(filters)
    self.package_model.filters = filters
  end

  ImGui.SameLine(ctx)

  -- Rebuild cache button
  if ImGui.Button(ctx, 'Rebuild Cache') then
    -- TODO: Trigger cache rebuild
    self.State.set_cache_status("rebuilding")
    self.package_model:scan()
    -- After rebuild completes:
    -- self.State.set_cache_status("ready")
  end
end

function PackagesView:update(dt)
  -- Update animations
  if self.grid and self.grid.custom_state and self.grid.custom_state.animator then
    self.grid.custom_state.animator:update(dt)
  end
end

function PackagesView:draw(ctx, shell_state)
  -- Draw header with controls
  self:draw_header_content(ctx)

  ImGui.Separator(ctx)

  -- Draw grid
  local visible_packages = self.package_model:visible()

  if #visible_packages == 0 then
    ImGui.Text(ctx, 'No packages found.')
    if not self.State.get_demo_mode() then
      ImGui.BulletText(ctx, 'Enable "Demo Mode" to preview the interface.')
    end
    return
  end

  -- Update grid with current data
  self.grid:draw(ctx)
end

return M
