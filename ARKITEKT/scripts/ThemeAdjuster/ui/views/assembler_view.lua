-- @noindex
-- ThemeAdjuster/ui/views/assembler_view.lua
-- Assembler tab with Panel + package grid

local ImGui = require 'imgui' '0.10'
local TilesContainer = require('rearkitekt.gui.widgets.containers.panel')
local PackageTilesGrid = require('rearkitekt.gui.widgets.media.package_tiles.grid')
local PackageManager = require('ThemeAdjuster.packages.manager')
local Config = require('ThemeAdjuster.core.config')
local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}
local AssemblerView = {}
AssemblerView.__index = AssemblerView

function M.new(State, AppConfig, settings)
  local self = setmetatable({
    State = State,
    Config = AppConfig,
    settings = settings,
    container = nil,
    grid = nil,
    package_model = nil,
    theme_model = nil,
  }, AssemblerView)

  -- Create package model (adapter for the grid)
  self.package_model = self:create_package_model()

  -- Create theme model (for color_from_key)
  self.theme_model = self:create_theme_model()

  -- Create container (Panel) with header
  local container_config = Config.get_assembler_container_config({
    on_demo_toggle = function()
      local new_demo = not State.get_demo_mode()
      State.set_demo_mode(new_demo)
      self.package_model.demo = new_demo
      -- Trigger rescan
      local packages = PackageManager.scan_packages(nil, new_demo)
      State.set_packages(packages)
      self.package_model.index = packages
      -- Reinitialize order
      local order = {}
      for _, pkg in ipairs(packages) do
        order[#order + 1] = pkg.id
      end
      State.set_package_order(order)
      self.package_model.order = order
    end,

    on_search_changed = function(text)
      State.set_search_text(text)
      self.package_model.search = text
    end,

    on_rebuild_cache = function()
      State.set_cache_status("rebuilding")
      -- TODO: Actual cache rebuild
      reaper.defer(function()
        State.set_cache_status("ready")
      end)
    end,

    on_filter_tcp_changed = function(value)
      local filters = State.get_filters()
      filters.TCP = value
      State.set_filters(filters)
      self.package_model.filters = filters
    end,

    on_filter_mcp_changed = function(value)
      local filters = State.get_filters()
      filters.MCP = value
      State.set_filters(filters)
      self.package_model.filters = filters
    end,

    on_filter_transport_changed = function(value)
      local filters = State.get_filters()
      filters.Transport = value
      State.set_filters(filters)
      self.package_model.filters = filters
    end,

    on_filter_global_changed = function(value)
      local filters = State.get_filters()
      filters.Global = value
      State.set_filters(filters)
      self.package_model.filters = filters
    end,
  })

  self.container = TilesContainer.new({
    id = "assembler_container",
    config = container_config,
  })

  -- Create grid
  self.grid = PackageTilesGrid.create(
    self.package_model,
    settings,
    self.theme_model
  )

  return self
end

function AssemblerView:create_theme_model()
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

      -- Simple HSV to RGB
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

function AssemblerView:create_package_model()
  local State = self.State
  local settings = self.settings

  -- Create a tile size proxy that syncs with State
  local tile_size = { value = State.get_tile_size() }
  local model = {
    -- Properties
    index = State.get_packages(),  -- All packages (required by grid)
    active = State.get_active_packages(),
    order = State.get_package_order(),
    excl = {},  -- TODO: Load from state
    pins = {},  -- TODO: Load from state
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

    update_tile_size = function(self, new_size)
      tile_size.value = new_size
      State.set_tile_size(new_size)
    end,
  }

  -- Set up metatable to intercept tile property access
  local mt = {
    __index = function(t, k)
      if k == "tile" then
        return tile_size.value
      end
      return rawget(model, k)
    end,
    __newindex = function(t, k, v)
      if k == "tile" then
        tile_size.value = v
        State.set_tile_size(v)
      else
        rawset(model, k, v)
      end
    end
  }

  return setmetatable(model, mt)
end

function AssemblerView:update(dt)
  -- Update animations
  if self.grid and self.grid.custom_state and self.grid.custom_state.animator then
    self.grid.custom_state.animator:update(dt)
  end
end

function AssemblerView:draw(ctx, shell_state)
  local visible_packages = self.package_model:visible()

  if #visible_packages == 0 then
    ImGui.Text(ctx, 'No packages found.')
    if not self.State.get_demo_mode() then
      ImGui.BulletText(ctx, 'Enable "Demo Mode" to preview the interface.')
    end
    return
  end

  -- Begin container (Panel)
  if self.container:begin_draw(ctx) then
    -- Draw grid inside container
    self.grid:draw(ctx)
  end
  self.container:end_draw(ctx)
end

return M
