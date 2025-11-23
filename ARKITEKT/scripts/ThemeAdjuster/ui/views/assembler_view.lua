-- @noindex
-- ThemeAdjuster/ui/views/assembler_view.lua
-- Assembler tab with Panel + package grid

local ImGui = require 'imgui' '0.10'
local TilesContainer = require('arkitekt.gui.widgets.containers.panel')
local PackageTilesGrid = require('arkitekt.gui.widgets.media.package_tiles.grid')
local PackageManager = require('ThemeAdjuster.packages.manager')
local Config = require('ThemeAdjuster.core.config')
local Theme = require('ThemeAdjuster.core.theme')
local Colors = require('arkitekt.core.colors')
local PackageModal = require('ThemeAdjuster.ui.views.package_modal')
local Dropdown = require('arkitekt.gui.widgets.inputs.dropdown')
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

    -- Apply state
    last_apply_result = nil,
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
    on_config_select = function(tab_id)
      -- Save current model state before switching
      self:sync_model_to_state()

      if State.switch_configuration(tab_id) then
        self:refresh_tabs()  -- Update active tab visual
        self:refresh_package_model()
      end
    end,

    on_config_add = function(tab_id)
      -- Generate name if not provided
      if not tab_id or tab_id == "" then
        local configs = State.get_configurations()
        local base_name = "Config"
        local counter = 1
        tab_id = base_name .. " " .. counter
        while configs.items[tab_id] do
          counter = counter + 1
          tab_id = base_name .. " " .. counter
        end
      end

      if State.add_configuration(tab_id, true) then  -- Clone from current
        State.switch_configuration(tab_id)
        self:refresh_tabs()
        self:refresh_package_model()
      end
    end,

    on_config_delete = function(tab_id)
      if State.delete_configuration(tab_id) then
        self:refresh_tabs()
        self:refresh_package_model()
      end
    end,

    on_config_rename = function(old_id, new_id)
      if State.rename_configuration(old_id, new_id) then
        self:refresh_tabs()
      end
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

  -- Add footer with ZIP linking status (left) and action buttons (right)
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
      -- Revert button
      {
        id = "revert",
        type = "button",
        width = 70,
        spacing_before = 8,
        config = {
          label = "Revert",
          on_click = function()
            self:do_revert()
          end,
        },
      },
      -- Apply button
      {
        id = "apply",
        type = "button",
        width = 70,
        spacing_before = 8,
        config = {
          label = "Apply",
          on_click = function()
            self:do_apply()
          end,
        },
      },
    },
  }

  self.container = TilesContainer.new({
    id = "assembler_container",
    config = container_config,
  })

  -- Set initial configuration tabs
  self:refresh_tabs()

  -- Create grid
  self.grid = PackageTilesGrid.create(
    self.package_model,
    settings,
    self.theme_model
  )

  -- Override double-click behavior to open modal
  self.grid.grid.behaviors.double_click = function(grid, key)
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
    excl = State.get_package_exclusions(),
    pins = State.get_package_pins(),
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
      local theme_root = demo_mode and nil or Theme.get_theme_root_path()
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

function AssemblerView:refresh_tabs()
  local State = self.State
  local configs = State.get_configurations()
  local active_name = State.get_active_configuration_name()

  -- Build tab items from configurations
  local tab_items = {}
  for name, _ in pairs(configs.items) do
    table.insert(tab_items, {
      id = name,
      label = name,
    })
  end

  -- Sort alphabetically but keep Default first
  table.sort(tab_items, function(a, b)
    if a.id == "Default" then return true end
    if b.id == "Default" then return false end
    return a.id < b.id
  end)

  -- Set tabs on container
  if self.container and self.container.set_tabs then
    self.container:set_tabs(tab_items, active_name)
  end
end

function AssemblerView:refresh_package_model()
  local State = self.State

  -- Update package model with current configuration's data
  self.package_model.active = State.get_active_packages()
  self.package_model.order = State.get_package_order()
  self.package_model.excl = State.get_package_exclusions()
  self.package_model.pins = State.get_package_pins()
end

function AssemblerView:sync_model_to_state()
  local State = self.State

  -- Sync model changes back to current configuration
  State.set_active_packages(self.package_model.active)
  State.set_package_order(self.package_model.order)
  State.set_package_exclusions(self.package_model.excl)
  State.set_package_pins(self.package_model.pins)
end

function AssemblerView:update(dt)
  -- Update animations
  if self.grid and self.grid.custom_state and self.grid.custom_state.animator then
    self.grid.custom_state.animator:update(dt)
  end
end

function AssemblerView:do_apply()
  local State = self.State

  -- Check if in demo mode
  if State.get_demo_mode() then
    reaper.ShowMessageBox("Cannot apply in Demo Mode.\nDisable Demo Mode and link a real theme first.", "Apply", 0)
    return
  end

  -- Get theme status and info
  local status, cache_dir, zip_name = Theme.get_status()
  local info = Theme.get_theme_info()

  -- Determine apply mode
  local is_zip_mode = (status == "linked-ready" or status == "zip-ready")
  local is_direct_mode = (status == "direct")

  if not is_zip_mode and not is_direct_mode then
    reaper.ShowMessageBox("Theme not ready.\nLink a ZIP or use a folder theme.", "Apply Error", 0)
    return
  end

  -- Get resolved map from current state
  local resolved = PackageManager.resolve_packages(
    State.get_packages(),
    State.get_active_packages(),
    State.get_package_order(),
    State.get_package_exclusions(),
    State.get_package_pins()
  )

  -- Count active assets
  local active_count = 0
  for _ in pairs(resolved) do active_count = active_count + 1 end

  if active_count == 0 then
    reaper.ShowMessageBox("No assets to apply.\nActivate some packages first.", "Apply", 0)
    return
  end

  local result

  if is_direct_mode then
    -- Folder theme: apply directly with backups
    local theme_root = Theme.get_theme_root_path()
    if not theme_root then
      reaper.ShowMessageBox("No theme root found.", "Apply Error", 0)
      return
    end

    -- Confirm apply
    local confirm = reaper.ShowMessageBox(
      string.format("Apply %d assets to folder theme?\n\nTheme: %s\n\nOriginal files will be backed up.", active_count, theme_root),
      "Confirm Apply",
      4  -- Yes/No
    )

    if confirm ~= 6 then return end

    -- Do the apply
    result = PackageManager.apply_to_theme(theme_root, resolved)
    self.last_apply_result = result

    -- Show result
    if result.ok then
      local msg = string.format(
        "Apply completed!\n\nFiles copied: %d\nFiles backed up: %d",
        result.files_copied,
        result.files_backed_up
      )
      if #result.errors > 0 then
        msg = msg .. string.format("\nWarnings: %d", #result.errors)
      end
      reaper.ShowMessageBox(msg, "Apply Complete", 0)

      -- Refresh REAPER theme
      Theme.reload_theme_in_reaper()
    else
      local msg = string.format(
        "Apply failed!\n\nFiles copied: %d\nErrors: %d\n\n%s",
        result.files_copied,
        #result.errors,
        table.concat(result.errors, "\n")
      )
      reaper.ShowMessageBox(msg, "Apply Error", 0)
    end

  else
    -- ZIP theme: create patched ZIP
    if not cache_dir then
      reaper.ShowMessageBox("Cache directory not found.\nRebuild cache first.", "Apply Error", 0)
      return
    end

    local output_name = (info.theme_name or "Theme") .. " (Reassembled).ReaperThemeZip"
    local overwrite = false

    -- Check if file already exists
    local existing = PackageManager.check_reassembled_exists(info.themes_dir, info.theme_name)
    if existing.exists then
      -- Prompt for overwrite vs new version
      local overwrite_confirm = reaper.ShowMessageBox(
        string.format("A reassembled ZIP already exists:\n%s\n\nOverwrite it?\n\nYes = Overwrite\nNo = Create new version", existing.path:match("[^\\/]+$")),
        "File Exists",
        3  -- Yes/No/Cancel
      )

      if overwrite_confirm == 2 then return end  -- Cancel
      overwrite = (overwrite_confirm == 6)  -- Yes = overwrite
    end

    -- Confirm apply
    local action_text = overwrite and "overwrite existing" or "create new"
    local confirm = reaper.ShowMessageBox(
      string.format("Apply %d assets and %s ZIP?\n\nLoad theme after creation?", active_count, action_text),
      "Confirm Apply (ZIP)",
      3  -- Yes/No/Cancel
    )

    if confirm == 2 then return end  -- Cancel
    local load_after = (confirm == 6)  -- Yes

    -- Do the apply
    result = PackageManager.apply_to_zip_theme(cache_dir, info.themes_dir, info.theme_name, resolved, { overwrite = overwrite })
    self.last_apply_result = result

    -- Show result
    if result.ok then
      local msg = string.format(
        "ZIP created!\n\nFiles copied: %d\nOutput: %s",
        result.files_copied,
        result.output_path
      )
      if #result.errors > 0 then
        msg = msg .. string.format("\nWarnings: %d", #result.errors)
      end
      reaper.ShowMessageBox(msg, "Apply Complete", 0)

      -- Load theme if requested
      if load_after and result.output_path then
        PackageManager.load_zip_theme(result.output_path)
      end
    else
      local msg = string.format(
        "ZIP creation failed!\n\nFiles copied: %d\nErrors: %d\n\n%s",
        result.files_copied,
        #result.errors,
        table.concat(result.errors, "\n")
      )
      reaper.ShowMessageBox(msg, "Apply Error", 0)
    end
  end
end

function AssemblerView:do_revert()
  local State = self.State

  -- Check if in demo mode
  if State.get_demo_mode() then
    reaper.ShowMessageBox("Cannot revert in Demo Mode.", "Revert", 0)
    return
  end

  -- Get theme root
  local theme_root = Theme.get_theme_root_path()
  if not theme_root then
    reaper.ShowMessageBox("No theme loaded or theme root not found.", "Revert Error", 0)
    return
  end

  -- Check if backups exist
  local backup_status = PackageManager.get_backup_status(theme_root)
  if not backup_status.has_backups then
    reaper.ShowMessageBox("No backups found.\nNothing to revert.", "Revert", 0)
    return
  end

  -- Confirm revert
  local confirm = reaper.ShowMessageBox(
    string.format("Revert %d files from backup?\n\nThis will restore original theme files.", backup_status.file_count),
    "Confirm Revert",
    4  -- Yes/No
  )

  if confirm ~= 6 then  -- 6 = Yes
    return
  end

  -- Do the revert
  local result = PackageManager.revert_last_apply(theme_root)

  -- Show result
  if result.ok then
    reaper.ShowMessageBox(
      string.format("Revert completed!\n\nFiles restored: %d", result.files_restored),
      "Revert Complete",
      0
    )

    -- Refresh REAPER theme
    Theme.reload_theme_in_reaper()
  else
    local msg = string.format(
      "Revert failed!\n\nFiles restored: %d\nErrors: %d\n\n%s",
      result.files_restored,
      #result.errors,
      table.concat(result.errors, "\n")
    )
    reaper.ShowMessageBox(msg, "Revert Error", 0)
  end
end

function AssemblerView:draw_zip_status(ctx, dl, x, y, width, height)
  local status, dir, zip_name = Theme.get_status()
  local info = Theme.get_theme_info()

  -- Position cursor for content (with padding)
  ImGui.SetCursorScreenPos(ctx, x + 12, y + 6)

  -- Determine if we're in ZIP mode (show dropdown) or direct mode
  local is_zip_mode = (status == "needs-link" or status == "linked-ready" or
                       status == "zip-ready" or status == "linked-needs-build")

  -- Show status indicator
  if status == "needs-link" then
    ImGui.TextColored(ctx, hexrgb("#E04141"), "NOT LINKED")
  elseif status == "linked-ready" or status == "zip-ready" then
    ImGui.TextColored(ctx, hexrgb("#41E0A3"), "ZIP")
  elseif status == "linked-needs-build" then
    ImGui.TextColored(ctx, hexrgb("#E0B341"), "BUILD NEEDED")
  elseif status == "direct" then
    ImGui.TextColored(ctx, hexrgb("#41E0A3"), "DIRECT")
  end

  -- Show inline ZIP picker for ZIP modes
  if is_zip_mode then
    -- Lazy-load available ZIPs
    if #self.available_zips == 0 then
      self.available_zips = Theme.list_theme_zips()
    end

    if #self.available_zips > 0 then
      -- Build dropdown options
      local options = {}
      local current_value = nil

      for i, zip_path in ipairs(self.available_zips) do
        local name = zip_path:match("[^\\/]+$") or zip_path
        table.insert(options, {
          value = zip_path,
          label = name,
        })

        -- If this ZIP is currently linked, select it
        if zip_name and name == zip_name then
          current_value = zip_path
        end
      end

      -- Set current value before drawing
      if current_value then
        Dropdown.set_value("zip_picker_state", current_value)
      end

      -- Position for dropdown (on same line after status)
      ImGui.SameLine(ctx)
      local cursor_x = ImGui.GetCursorPosX(ctx) + 8
      ImGui.SetCursorPosX(ctx, cursor_x)
      local screen_x, screen_y = ImGui.GetCursorScreenPos(ctx)

      -- Draw dropdown using arkitekt widget
      local dropdown_width = 220
      local dropdown_height = 20
      local _, changed = Dropdown.draw(ctx, dl, screen_x, screen_y, dropdown_width, dropdown_height, {
        id = "zip_picker",
        options = options,
        on_change = function(selected_zip)
          if selected_zip then
            -- Build cache from selected ZIP
            local img_dir, err = Theme.build_cache_from_zip(info.theme_name, selected_zip)
            if img_dir then
              -- Trigger package rescan
              local packages = PackageManager.scan_packages(nil, self.State.get_demo_mode())
              self.State.set_packages(packages)
              self.package_model.index = packages

              -- Refresh grid
              if self.grid then
                self:refresh_package_model()
              end
            end
          end
        end,
      }, "zip_picker_state")

      -- Advance cursor past dropdown
      ImGui.SetCursorPosX(ctx, cursor_x + dropdown_width)

      -- Show arrow and theme name for linked states
      if status == "linked-ready" or status == "zip-ready" or status == "linked-needs-build" then
        ImGui.SameLine(ctx)
        ImGui.TextDisabled(ctx, "→ " .. info.theme_name)
      end
    else
      ImGui.SameLine(ctx)
      ImGui.TextDisabled(ctx, "No .ReaperThemeZip files found")
    end

  elseif status == "direct" then
    -- Direct mode: show theme folder
    if dir then
      ImGui.SameLine(ctx)
      ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + 8)
      ImGui.TextDisabled(ctx, "→ " .. (dir:match("[^\\/]+$") or info.theme_name))
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
    local window = shell_state and shell_state.window
    self.package_modal:draw(ctx, window)
  end
end

return M
