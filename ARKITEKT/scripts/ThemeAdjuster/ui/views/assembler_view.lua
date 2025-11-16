-- @noindex
-- ThemeAdjuster/ui/views/assembler_view.lua
-- Assembler tab with Panel + package grid

local ImGui = require 'imgui' '0.10'
local TilesContainer = require('rearkitekt.gui.widgets.containers.panel')
local PackageTilesGrid = require('rearkitekt.gui.widgets.media.package_tiles.grid')
local PackageManager = require('ThemeAdjuster.packages.manager')
local Config = require('ThemeAdjuster.core.config')
local Theme = require('ThemeAdjuster.core.theme')
local Colors = require('rearkitekt.core.colors')
local PackageModal = require('ThemeAdjuster.ui.views.package_modal')
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
    package_modal = nil,

    -- ZIP linking state
    selected_zip_index = 0,
    available_zips = {},
  }, AssemblerView)

  -- Create package modal
  self.package_modal = PackageModal.new(State, settings)

  -- Create package model (adapter for the grid)
  self.package_model = self:create_package_model()

  -- Create theme model (for color_from_key)
  self.theme_model = self:create_theme_model()

  -- Create container (Panel) with header and footer
  -- Get current filter values for checkbox initialization
  local filters = State.get_filters()

  local container_config = Config.get_assembler_container_config({
    on_demo_toggle = function()
      local new_demo = not State.get_demo_mode()
      State.set_demo_mode(new_demo)
      self.package_model.demo = new_demo
      -- Trigger rescan
      local theme_root = nil
      if not new_demo then
        local Theme = require('ThemeAdjuster.core.theme')
        local theme_info = Theme.get_theme_info()
        if theme_info.theme_path then
          reaper.ShowConsoleMsg("[AssemblerView] Original theme_path = " .. tostring(theme_info.theme_path) .. "\n")
          -- Extract directory from theme path
          theme_root = theme_info.theme_path
          -- If path ends with a theme file, strip it to get directory
          if theme_root:match("%.ReaperTheme") or theme_root:match("%.ReaperThemeZip") then
            reaper.ShowConsoleMsg("[AssemblerView] Detected theme file, stripping filename\n")
            theme_root = theme_root:match("^(.*)[\\/][^\\/]+$") or theme_root
          else
            reaper.ShowConsoleMsg("[AssemblerView] Not a theme file, using path as-is\n")
          end
          -- Remove trailing separator if present
          theme_root = theme_root:gsub("[\\/]+$", "")
          reaper.ShowConsoleMsg("[AssemblerView] Final theme_root = " .. tostring(theme_root) .. "\n")
        end
      end
      local packages = PackageManager.scan_packages(theme_root, new_demo)
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

    on_filter_changed = function(filter_key, new_checked)
      local filters = State.get_filters()
      -- Map dropdown values to filter keys
      local filter_map = {
        tcp = "TCP",
        mcp = "MCP",
        transport = "Transport",
        global = "Global",
      }
      local filter_name = filter_map[filter_key]
      if filter_name then
        filters[filter_name] = new_checked
        State.set_filters(filters)
        self.package_model.filters = filters
      end
    end,
  }, filters)

  -- Add footer with ZIP linking status (left) and Rebuild Cache (right)
  container_config.footer = {
    enabled = true,
    height = 32,
    bg_color = hexrgb("#1E1E1E"),
    border_color = hexrgb("#000000"),
    elements = {
      -- Left: ZIP status (flex to take remaining space)
      {
        id = "zip_status",
        type = "custom",
        flex = 1,
        spacing_before = 0,
        config = {
          on_draw = function(ctx, dl, x, y, width, height, state)
            self:draw_zip_status(ctx, dl, x, y, width, height)
          end,
        },
      },
      -- Right: Rebuild Cache button
      {
        id = "rebuild_cache",
        type = "button",
        width = 110,
        spacing_before = 0,
        config = {
          label = "Rebuild Cache",
          on_click = function()
            State.set_cache_status("rebuilding")
            -- TODO: Actual cache rebuild
            reaper.defer(function()
              State.set_cache_status("ready")
            end)
          end,
        },
      },
    },
  }

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

  -- Override double-click behavior to open modal
  self.grid.grid.behaviors.double_click = function(key)
    -- Find the package data for this key
    local packages = State.get_packages()
    for _, pkg in ipairs(packages) do
      if pkg.id == key then
        self.package_modal:show(pkg)
        break
      end
    end
  end

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
      local theme_root = nil
      if not demo_mode then
        local Theme = require('ThemeAdjuster.core.theme')
        local theme_info = Theme.get_theme_info()
        if theme_info.theme_path then
          theme_root = theme_info.theme_path
          -- If path ends with a theme file, strip it to get directory
          if theme_root:match("%.ReaperTheme[Zip]*$") then
            theme_root = theme_root:match("^(.*)[\\/][^\\/]+$") or theme_root
          end
          -- Remove trailing separator if present
          theme_root = theme_root:gsub("[\\/]+$", "")
        end
      end
      local packages = PackageManager.scan_packages(theme_root, demo_mode)
      State.set_packages(packages)
      self.index = packages
    end,

    visible = function(self)
      local packages = State.get_packages()
      local search = State.get_search_text()
      local filters = State.get_filters()
      local filtered = PackageManager.filter_packages(packages, search, filters)

      -- Sort by order array (for drag/drop reordering)
      -- Use self.order which is updated directly by grid reorder behavior
      table.sort(filtered, function(a, b)
        local idx_a, idx_b = 999, 999
        for i, id in ipairs(self.order) do
          if id == a.id then idx_a = i end
          if id == b.id then idx_b = i end
        end
        return idx_a < idx_b
      end)

      return filtered
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

function AssemblerView:draw_zip_status(ctx, dl, x, y, width, height)
  local status, dir, zip_name = Theme.get_status()
  local info = Theme.get_theme_info()

  -- Position cursor for content (with padding)
  ImGui.SetCursorScreenPos(ctx, x + 12, y + 6)

  -- Show status on the left
  if status == "needs-link" then
    -- Red "NOT LINKED" text
    ImGui.TextColored(ctx, hexrgb("#E04141"), "NOT LINKED")
    ImGui.SameLine(ctx)
    ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + 8)

    -- ZIP dropdown
    if #self.available_zips == 0 then
      self.available_zips = Theme.list_theme_zips()
    end

    if #self.available_zips > 0 then
      -- Create display list (just filenames)
      local zip_names = {}
      for _, zip_path in ipairs(self.available_zips) do
        local name = zip_path:match("[^\\/]+$") or zip_path
        table.insert(zip_names, name)
      end

      ImGui.SetNextItemWidth(ctx, 300)
      local changed, new_index = ImGui.Combo(ctx, "##zip_picker", self.selected_zip_index, table.concat(zip_names, "\0") .. "\0")

      if changed and new_index > 0 then
        self.selected_zip_index = new_index
        local selected_zip = self.available_zips[new_index]
        if selected_zip then
          -- Build cache from selected ZIP
          local img_dir, err = Theme.build_cache_from_zip(info.theme_name, selected_zip)
          if img_dir then
            -- Trigger package rescan
            local packages = PackageManager.scan_packages(nil, self.State.get_demo_mode())
            self.State.set_packages(packages)
            self.package_model.index = packages
          end
        end
      end

      ImGui.SameLine(ctx)
      ImGui.TextDisabled(ctx, "Select ZIP to link theme")
    else
      ImGui.TextDisabled(ctx, "No .ReaperThemeZip files found in ColorThemes")
    end

  elseif status == "linked-ready" or status == "zip-ready" then
    ImGui.TextColored(ctx, hexrgb("#41E0A3"), "LINKED")
    if zip_name then
      ImGui.SameLine(ctx)
      ImGui.TextDisabled(ctx, "→ " .. zip_name)
    end

  elseif status == "direct" then
    ImGui.TextColored(ctx, hexrgb("#41E0A3"), "DIRECT")
    if dir then
      ImGui.SameLine(ctx)
      ImGui.TextDisabled(ctx, "→ " .. (dir:match("[^\\/]+$") or dir))
    end

  elseif status == "linked-needs-build" then
    ImGui.TextColored(ctx, hexrgb("#E0B341"), "BUILD NEEDED")
    if zip_name then
      ImGui.SameLine(ctx)
      ImGui.TextDisabled(ctx, "→ " .. zip_name)
    end
  end
end

function AssemblerView:draw(ctx, shell_state)
  local visible_packages = self.package_model:visible()

  -- Begin container (Panel) - always draw to show header/footer
  if self.container:begin_draw(ctx) then
    -- Draw content inside container
    if #visible_packages == 0 then
      -- Show empty state message
      ImGui.Text(ctx, 'No packages found.')
      if not self.State.get_demo_mode() then
        ImGui.BulletText(ctx, 'Enable "Demo Mode" to preview the interface.')
      end
    else
      -- Draw grid
      self.grid:draw(ctx)
    end
  end
  self.container:end_draw(ctx)

  -- Draw package modal (outside panel, as overlay)
  if self.package_modal then
    self.package_modal:draw(ctx)
  end
end

return M
