-- @noindex
-- ThemeAdjuster/ui/views/package_modal.lua
-- Package manifest/micro-manage modal

local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}
local PackageModal = {}
PackageModal.__index = PackageModal

function M.new(State, settings)
  local self = setmetatable({
    State = State,
    settings = settings,

    -- Modal state
    open = false,
    package_id = nil,
    package_data = nil,

    -- UI state
    search_text = "",
    selected_assets = {},  -- {key = true/false}

    -- Settings
    exclusions = {},  -- {pkg_id = {key = true}}
    pins = {},        -- {key = pkg_id}
  }, PackageModal)

  -- Load settings
  if settings then
    self.exclusions = settings:get('pkg_exclusions', {})
    self.pins = settings:get('pkg_pins', {})
  end

  return self
end

function PackageModal:show(package_data)
  self.open = true
  self.package_id = package_data.id
  self.package_data = package_data
  self.search_text = ""
  self.selected_assets = {}
end

function PackageModal:close()
  self.open = false
  self.package_id = nil
  self.package_data = nil
  self.search_text = ""
  self.selected_assets = {}
end

function PackageModal:save_settings()
  if self.settings then
    self.settings:set('pkg_exclusions', self.exclusions)
    self.settings:set('pkg_pins', self.pins)
  end
end

function PackageModal:get_package_exclusions(pkg_id)
  if not self.exclusions[pkg_id] then
    self.exclusions[pkg_id] = {}
  end
  return self.exclusions[pkg_id]
end

function PackageModal:is_asset_included(pkg_id, key)
  local excl = self.get_package_exclusions(self, pkg_id)
  return not excl[key]
end

function PackageModal:toggle_asset_inclusion(pkg_id, key)
  local excl = self:get_package_exclusions(pkg_id)
  if excl[key] then
    excl[key] = nil  -- Include
  else
    excl[key] = true  -- Exclude
  end
  self:save_settings()
end

function PackageModal:get_pinned_provider(key)
  return self.pins[key]
end

function PackageModal:set_pinned_provider(key, pkg_id)
  if pkg_id then
    self.pins[key] = pkg_id
  else
    self.pins[key] = nil
  end
  self:save_settings()
end

function PackageModal:draw_toolbar(ctx)
  -- Search
  ImGui.SetNextItemWidth(ctx, 220)
  local changed, new_text = ImGui.InputTextWithHint(ctx, "##search", "Search assets...", self.search_text)
  if changed then
    self.search_text = new_text
  end

  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Close") then
    self:close()
  end
end

function PackageModal:draw_bulk_actions(ctx, pkg)
  -- Select all visible
  if ImGui.Button(ctx, "Select All") then
    for _, key in ipairs(pkg.keys_order or {}) do
      if self.search_text == "" or key:lower():find(self.search_text:lower(), 1, true) then
        self.selected_assets[key] = true
      end
    end
  end

  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Clear Selection") then
    self.selected_assets = {}
  end

  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Include Selected") then
    local excl = self:get_package_exclusions(pkg.id)
    for key, selected in pairs(self.selected_assets) do
      if selected then
        excl[key] = nil
      end
    end
    self:save_settings()
  end

  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Exclude Selected") then
    local excl = self:get_package_exclusions(pkg.id)
    for key, selected in pairs(self.selected_assets) do
      if selected then
        excl[key] = true
      end
    end
    self:save_settings()
  end

  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Pin Selected to Package") then
    for key, selected in pairs(self.selected_assets) do
      if selected then
        self:set_pinned_provider(key, pkg.id)
      end
    end
  end
end

function PackageModal:draw_asset_table(ctx, pkg)
  local excl = self:get_package_exclusions(pkg.id)
  local packages = self.State.get_packages()

  -- Table flags
  local table_flags = ImGui.TableFlags_Borders |
                      ImGui.TableFlags_RowBg |
                      ImGui.TableFlags_ScrollY |
                      ImGui.TableFlags_Resizable

  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)

  if ImGui.BeginTable(ctx, "asset_table", 4, table_flags, avail_w, avail_h) then
    ImGui.TableSetupScrollFreeze(ctx, 0, 1)
    ImGui.TableSetupColumn(ctx, "Sel", ImGui.TableColumnFlags_WidthFixed, 40)
    ImGui.TableSetupColumn(ctx, "Include", ImGui.TableColumnFlags_WidthFixed, 70)
    ImGui.TableSetupColumn(ctx, "Key", ImGui.TableColumnFlags_WidthStretch)
    ImGui.TableSetupColumn(ctx, "Pinned Provider", ImGui.TableColumnFlags_WidthFixed, 180)
    ImGui.TableHeadersRow(ctx)

    -- Render rows
    for _, key in ipairs(pkg.keys_order or {}) do
      -- Filter by search
      if self.search_text == "" or key:lower():find(self.search_text:lower(), 1, true) then
        ImGui.TableNextRow(ctx)

        -- Column 0: Select checkbox
        ImGui.TableSetColumnIndex(ctx, 0)
        local selected = self.selected_assets[key] or false
        local changed_sel, new_sel = ImGui.Checkbox(ctx, "##sel_" .. key, selected)
        if changed_sel then
          self.selected_assets[key] = new_sel
        end

        -- Column 1: Include checkbox
        ImGui.TableSetColumnIndex(ctx, 1)
        local included = not excl[key]
        local changed_inc, new_inc = ImGui.Checkbox(ctx, "##inc_" .. key, included)
        if changed_inc then
          self:toggle_asset_inclusion(pkg.id, key)
        end

        -- Column 2: Key name
        ImGui.TableSetColumnIndex(ctx, 2)
        ImGui.Text(ctx, key)

        -- Column 3: Pinned provider dropdown
        ImGui.TableSetColumnIndex(ctx, 3)
        local current_pin = self:get_pinned_provider(key) or "(none)"
        local preview = current_pin

        ImGui.SetNextItemWidth(ctx, -1)
        if ImGui.BeginCombo(ctx, "##pin_" .. key, preview) then
          -- None option
          if ImGui.Selectable(ctx, "(none)", current_pin == "(none)") then
            self:set_pinned_provider(key, nil)
          end

          -- Package options (only packages that have this asset)
          for _, other_pkg in ipairs(packages) do
            if other_pkg.assets and other_pkg.assets[key] then
              local is_selected = (current_pin == other_pkg.id)
              if ImGui.Selectable(ctx, other_pkg.id, is_selected) then
                self:set_pinned_provider(key, other_pkg.id)
              end
            end
          end

          ImGui.EndCombo(ctx)
        end
      end
    end

    ImGui.EndTable(ctx)
  end
end

function PackageModal:draw(ctx)
  if not self.open or not self.package_data then
    return
  end

  local pkg = self.package_data
  local title = string.format("Package Manager: %s##pkg_modal", pkg.meta and pkg.meta.name or pkg.id)

  -- Modal window
  ImGui.SetNextWindowSize(ctx, 800, 600, ImGui.Cond_FirstUseEver)
  local visible, open = ImGui.Begin(ctx, title, true)

  if not open then
    self:close()
  end

  if visible then
    -- Package info
    ImGui.TextColored(ctx, hexrgb("#AAAAAA"), "Path:")
    ImGui.SameLine(ctx)
    ImGui.Text(ctx, pkg.path or "(demo package)")

    if pkg.meta then
      ImGui.SameLine(ctx, 0, 20)
      ImGui.TextColored(ctx, hexrgb("#AAAAAA"), "Version:")
      ImGui.SameLine(ctx)
      ImGui.Text(ctx, pkg.meta.version or "?")
    end

    ImGui.Separator(ctx)

    -- Toolbar
    self:draw_toolbar(ctx)

    ImGui.Spacing(ctx)

    -- Bulk actions
    self:draw_bulk_actions(ctx, pkg)

    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    -- Asset table
    self:draw_asset_table(ctx, pkg)

    ImGui.End(ctx)
  end
end

return M
