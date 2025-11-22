-- @noindex
-- ThemeAdjuster/ui/views/package_modal.lua
-- Package manifest/micro-manage modal (overlay with visual tile grid)

local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}
local PackageModal = {}
PackageModal.__index = PackageModal

-- Platform path separator
local SEP = package.config:sub(1,1)

-- Tile constants
local TILE_SIZE = 80
local TILE_PADDING = 6
local TILE_SPACING = 8

-- Image cache for tooltips
local image_cache = {}

-- Helper to create/get cached image
local function get_cached_image(path)
  if not path or path == "" then return nil end
  if path:find("^%(mock%)") then return nil end  -- Demo packages have no real images

  if image_cache[path] == nil then
    local ok, img = pcall(ImGui.CreateImage, path)
    if ok and img then
      image_cache[path] = img
    else
      image_cache[path] = false  -- Mark as failed
    end
  end

  return image_cache[path] or nil
end

-- Helper to check if DPI variant exists
local function check_dpi_variants(base_path)
  if not base_path or base_path:find("^%(mock%)") then
    return false, false
  end

  -- Remove .png extension
  local base = base_path:gsub("%.png$", ""):gsub("%.PNG$", "")

  -- Check for 150% and 200% variants
  local has_150 = false
  local has_200 = false

  local file_150 = io.open(base .. "_150.png", "r")
  if file_150 then
    file_150:close()
    has_150 = true
  end

  local file_200 = io.open(base .. "_200.png", "r")
  if file_200 then
    file_200:close()
    has_200 = true
  end

  return has_150, has_200
end

-- Helper to extract area from key (tcp_, mcp_, transport_, etc.)
local function get_area_from_key(key)
  if key:match("^tcp_") then return "TCP"
  elseif key:match("^mcp_") then return "MCP"
  elseif key:match("^transport_") then return "Transport"
  elseif key:match("^global_") or key:match("^gen_") then return "Global"
  elseif key:match("^envcp_") then return "ENVCP"
  elseif key:match("^meter_") then return "Meter"
  else return "Other"
  end
end

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
    view_mode = "grid",    -- "grid" or "tree"
    group_by_area = true,
  }, PackageModal)

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

function PackageModal:get_package_exclusions(pkg_id)
  local all_exclusions = self.State.get_package_exclusions()
  if not all_exclusions[pkg_id] then
    all_exclusions[pkg_id] = {}
  end
  return all_exclusions[pkg_id]
end

function PackageModal:is_asset_included(pkg_id, key)
  local excl = self:get_package_exclusions(pkg_id)
  return not excl[key]
end

function PackageModal:toggle_asset_inclusion(pkg_id, key)
  local all_exclusions = self.State.get_package_exclusions()
  if not all_exclusions[pkg_id] then
    all_exclusions[pkg_id] = {}
  end

  if all_exclusions[pkg_id][key] then
    all_exclusions[pkg_id][key] = nil  -- Include
  else
    all_exclusions[pkg_id][key] = true  -- Exclude
  end

  self.State.set_package_exclusions(all_exclusions)
end

function PackageModal:get_pinned_provider(key)
  local pins = self.State.get_package_pins()
  return pins[key]
end

function PackageModal:set_pinned_provider(key, pkg_id)
  local pins = self.State.get_package_pins()
  if pkg_id then
    pins[key] = pkg_id
  else
    pins[key] = nil
  end
  self.State.set_package_pins(pins)
end

-- Group assets by area
function PackageModal:group_assets_by_area(keys_order)
  local groups = {}
  local group_order = {"TCP", "MCP", "Transport", "ENVCP", "Meter", "Global", "Other"}

  -- Initialize groups
  for _, area in ipairs(group_order) do
    groups[area] = {}
  end

  -- Categorize keys
  for _, key in ipairs(keys_order) do
    local area = get_area_from_key(key)
    table.insert(groups[area], key)
  end

  return groups, group_order
end

function PackageModal:draw_toolbar(ctx)
  -- Search
  ImGui.SetNextItemWidth(ctx, 220)
  local changed, new_text = ImGui.InputTextWithHint(ctx, "##search", "Search assets...", self.search_text)
  if changed then
    self.search_text = new_text
  end

  ImGui.SameLine(ctx)

  -- View mode toggle
  if ImGui.Button(ctx, self.view_mode == "grid" and "Grid" or "Tree", 60) then
    self.view_mode = self.view_mode == "grid" and "tree" or "grid"
  end

  ImGui.SameLine(ctx)

  -- Group toggle
  if ImGui.Button(ctx, self.group_by_area and "Grouped" or "Flat") then
    self.group_by_area = not self.group_by_area
  end
end

function PackageModal:draw_bulk_actions(ctx, pkg)
  -- Select all visible
  if ImGui.Button(ctx, "Select All", 80, 0) then
    for _, key in ipairs(pkg.keys_order or {}) do
      if self.search_text == "" or key:lower():find(self.search_text:lower(), 1, true) then
        self.selected_assets[key] = true
      end
    end
  end

  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Clear", 60, 0) then
    self.selected_assets = {}
  end

  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Include Sel.", 80, 0) then
    local all_exclusions = self.State.get_package_exclusions()
    if not all_exclusions[pkg.id] then
      all_exclusions[pkg.id] = {}
    end
    for key, selected in pairs(self.selected_assets) do
      if selected then
        all_exclusions[pkg.id][key] = nil
      end
    end
    self.State.set_package_exclusions(all_exclusions)
  end

  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Exclude Sel.", 80, 0) then
    local all_exclusions = self.State.get_package_exclusions()
    if not all_exclusions[pkg.id] then
      all_exclusions[pkg.id] = {}
    end
    for key, selected in pairs(self.selected_assets) do
      if selected then
        all_exclusions[pkg.id][key] = true
      end
    end
    self.State.set_package_exclusions(all_exclusions)
  end

  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Pin Sel.", 65, 0) then
    local pins = self.State.get_package_pins()
    for key, selected in pairs(self.selected_assets) do
      if selected then
        pins[key] = pkg.id
      end
    end
    self.State.set_package_pins(pins)
  end
end

-- Draw a single asset tile
function PackageModal:draw_asset_tile(ctx, pkg, key)
  local excl = self:get_package_exclusions(pkg.id)
  local included = not excl[key]
  local selected = self.selected_assets[key] or false
  local pinned_to = self:get_pinned_provider(key)
  local is_pinned = pinned_to == pkg.id

  -- Get asset info
  local asset = pkg.assets and pkg.assets[key]
  local asset_path = asset and asset.path

  -- Check DPI variants
  local has_150, has_200 = check_dpi_variants(asset_path)

  -- Tile colors
  local bg_color
  if selected then
    bg_color = hexrgb("#4A90E2", 0.4)  -- Blue for selected
  elseif not included then
    bg_color = hexrgb("#AA3333", 0.3)  -- Red for excluded
  elseif is_pinned then
    bg_color = hexrgb("#4AE290", 0.3)  -- Green for pinned
  else
    bg_color = hexrgb("#333340", 0.8)  -- Default
  end

  local border_color = selected and hexrgb("#4A90E2") or hexrgb("#555566")

  -- Draw tile background
  local x1, y1 = ImGui.GetCursorScreenPos(ctx)
  local x2, y2 = x1 + TILE_SIZE, y1 + TILE_SIZE
  local dl = ImGui.GetWindowDrawList(ctx)

  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, bg_color, 4)
  ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, border_color, 4, 0, 1)

  -- Invisible button for interaction
  ImGui.InvisibleButton(ctx, "##tile_" .. key, TILE_SIZE, TILE_SIZE)

  local clicked = ImGui.IsItemClicked(ctx, ImGui.MouseButton_Left)
  local right_clicked = ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right)
  local hovered = ImGui.IsItemHovered(ctx)

  -- Handle click
  if clicked then
    -- Shift+click for multi-select
    if ImGui.IsKeyDown(ctx, ImGui.Mod_Shift) then
      self.selected_assets[key] = not selected
    else
      -- Toggle include/exclude
      self:toggle_asset_inclusion(pkg.id, key)
    end
  end

  -- Right-click for pin
  if right_clicked then
    if is_pinned then
      self:set_pinned_provider(key, nil)  -- Unpin
    else
      self:set_pinned_provider(key, pkg.id)  -- Pin to this package
    end
  end

  -- Draw key name (truncated)
  local display_name = key
  if #display_name > 10 then
    display_name = display_name:sub(1, 8) .. ".."
  end

  local text_color = included and hexrgb("#FFFFFF") or hexrgb("#888888")
  local text_w = ImGui.CalcTextSize(ctx, display_name)
  local text_x = x1 + (TILE_SIZE - text_w) * 0.5
  local text_y = y2 - 16

  ImGui.DrawList_AddText(dl, text_x, text_y, text_color, display_name)

  -- Draw status indicators (top-right corner)
  local indicator_y = y1 + 4
  local indicator_x = x2 - 8

  -- Pinned indicator
  if is_pinned then
    ImGui.DrawList_AddCircleFilled(dl, indicator_x, indicator_y, 4, hexrgb("#4AE290"))
    indicator_x = indicator_x - 10
  end

  -- DPI indicators (bottom-left)
  if has_150 or has_200 then
    local dpi_x = x1 + 4
    local dpi_y = y1 + 4
    local dpi_text = ""
    if has_150 then dpi_text = "1.5x" end
    if has_200 then dpi_text = dpi_text .. (has_150 and " 2x" or "2x") end
    ImGui.DrawList_AddText(dl, dpi_x, dpi_y, hexrgb("#888888"), dpi_text)
  end

  -- Tooltip on hover
  if hovered then
    ImGui.BeginTooltip(ctx)

    -- Show image preview if available
    local img = get_cached_image(asset_path)
    if img then
      local img_w, img_h = ImGui.Image_GetSize(img)
      -- Scale down large images
      local max_size = 200
      if img_w > max_size or img_h > max_size then
        local scale = max_size / math.max(img_w, img_h)
        img_w = img_w * scale
        img_h = img_h * scale
      end
      ImGui.Image(ctx, img, img_w, img_h)
      ImGui.Separator(ctx)
    end

    -- Key name
    ImGui.Text(ctx, key)

    -- Status
    if not included then
      ImGui.TextColored(ctx, hexrgb("#FF6666"), "EXCLUDED")
    end
    if is_pinned then
      ImGui.TextColored(ctx, hexrgb("#4AE290"), "PINNED")
    end

    -- DPI info
    if has_150 or has_200 then
      local dpi_str = "DPI: 100%"
      if has_150 then dpi_str = dpi_str .. ", 150%" end
      if has_200 then dpi_str = dpi_str .. ", 200%" end
      ImGui.TextColored(ctx, hexrgb("#AAAAAA"), dpi_str)
    end

    -- Help text
    ImGui.Spacing(ctx)
    ImGui.TextColored(ctx, hexrgb("#666666"), "Click: Toggle include/exclude")
    ImGui.TextColored(ctx, hexrgb("#666666"), "Right-click: Toggle pin")
    ImGui.TextColored(ctx, hexrgb("#666666"), "Shift+Click: Select")

    ImGui.EndTooltip(ctx)
  end
end

-- Draw assets in grid view
function PackageModal:draw_grid_view(ctx, pkg)
  local excl = self:get_package_exclusions(pkg.id)
  local avail_w = ImGui.GetContentRegionAvail(ctx)
  local columns = math.max(1, math.floor(avail_w / (TILE_SIZE + TILE_SPACING)))

  if self.group_by_area then
    -- Grouped view
    local groups, group_order = self:group_assets_by_area(pkg.keys_order or {})

    for _, area in ipairs(group_order) do
      local keys = groups[area]
      if #keys > 0 then
        -- Filter by search
        local filtered_keys = {}
        for _, key in ipairs(keys) do
          if self.search_text == "" or key:lower():find(self.search_text:lower(), 1, true) then
            table.insert(filtered_keys, key)
          end
        end

        if #filtered_keys > 0 then
          -- Group header
          ImGui.Spacing(ctx)
          ImGui.TextColored(ctx, hexrgb("#888888"), area .. " (" .. #filtered_keys .. ")")
          ImGui.Separator(ctx)
          ImGui.Spacing(ctx)

          -- Draw tiles
          local col = 0
          for _, key in ipairs(filtered_keys) do
            if col > 0 then
              ImGui.SameLine(ctx, 0, TILE_SPACING)
            end

            self:draw_asset_tile(ctx, pkg, key)

            col = col + 1
            if col >= columns then
              col = 0
            end
          end

          ImGui.Spacing(ctx)
        end
      end
    end
  else
    -- Flat view
    local col = 0
    for _, key in ipairs(pkg.keys_order or {}) do
      -- Filter by search
      if self.search_text == "" or key:lower():find(self.search_text:lower(), 1, true) then
        if col > 0 then
          ImGui.SameLine(ctx, 0, TILE_SPACING)
        end

        self:draw_asset_tile(ctx, pkg, key)

        col = col + 1
        if col >= columns then
          col = 0
        end
      end
    end
  end
end

-- Draw assets in tree view (table format)
function PackageModal:draw_tree_view(ctx, pkg)
  local excl = self:get_package_exclusions(pkg.id)
  local packages = self.State.get_packages()

  -- Table flags
  local table_flags = ImGui.TableFlags_Borders |
                      ImGui.TableFlags_RowBg |
                      ImGui.TableFlags_ScrollY |
                      ImGui.TableFlags_Resizable

  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)

  if ImGui.BeginTable(ctx, "asset_table", 5, table_flags, avail_w, avail_h) then
    ImGui.TableSetupScrollFreeze(ctx, 0, 1)
    ImGui.TableSetupColumn(ctx, "Sel", ImGui.TableColumnFlags_WidthFixed, 30)
    ImGui.TableSetupColumn(ctx, "Inc", ImGui.TableColumnFlags_WidthFixed, 30)
    ImGui.TableSetupColumn(ctx, "Key", ImGui.TableColumnFlags_WidthStretch)
    ImGui.TableSetupColumn(ctx, "DPI", ImGui.TableColumnFlags_WidthFixed, 60)
    ImGui.TableSetupColumn(ctx, "Pin", ImGui.TableColumnFlags_WidthFixed, 120)
    ImGui.TableHeadersRow(ctx)

    -- Group if enabled
    local keys_to_render
    if self.group_by_area then
      local groups, group_order = self:group_assets_by_area(pkg.keys_order or {})
      keys_to_render = {}
      for _, area in ipairs(group_order) do
        for _, key in ipairs(groups[area]) do
          table.insert(keys_to_render, {key = key, area = area})
        end
      end
    else
      keys_to_render = {}
      for _, key in ipairs(pkg.keys_order or {}) do
        table.insert(keys_to_render, {key = key, area = nil})
      end
    end

    local last_area = nil

    -- Render rows
    for _, item in ipairs(keys_to_render) do
      local key = item.key
      local area = item.area

      -- Filter by search
      if self.search_text == "" or key:lower():find(self.search_text:lower(), 1, true) then
        -- Area separator in grouped mode
        if self.group_by_area and area ~= last_area then
          ImGui.TableNextRow(ctx)
          ImGui.TableSetColumnIndex(ctx, 0)
          ImGui.TableSetBgColor(ctx, ImGui.TableBgTarget_RowBg0, hexrgb("#252530"))
          ImGui.Dummy(ctx, 1, 1)
          ImGui.TableSetColumnIndex(ctx, 2)
          ImGui.TextColored(ctx, hexrgb("#888888"), "— " .. area .. " —")
          last_area = area
        end

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

        -- Column 2: Key name with tooltip
        ImGui.TableSetColumnIndex(ctx, 2)
        ImGui.Text(ctx, key)

        -- Tooltip with image preview
        if ImGui.IsItemHovered(ctx) then
          local asset = pkg.assets and pkg.assets[key]
          local asset_path = asset and asset.path
          local img = get_cached_image(asset_path)

          if img then
            ImGui.BeginTooltip(ctx)
            local img_w, img_h = ImGui.Image_GetSize(img)
            local max_size = 200
            if img_w > max_size or img_h > max_size then
              local scale = max_size / math.max(img_w, img_h)
              img_w = img_w * scale
              img_h = img_h * scale
            end
            ImGui.Image(ctx, img, img_w, img_h)
            ImGui.EndTooltip(ctx)
          end
        end

        -- Column 3: DPI versions
        ImGui.TableSetColumnIndex(ctx, 3)
        local asset = pkg.assets and pkg.assets[key]
        local asset_path = asset and asset.path
        local has_150, has_200 = check_dpi_variants(asset_path)
        local dpi_str = ""
        if has_150 then dpi_str = "1.5x " end
        if has_200 then dpi_str = dpi_str .. "2x" end
        ImGui.TextColored(ctx, hexrgb("#888888"), dpi_str)

        -- Column 4: Pinned provider dropdown
        ImGui.TableSetColumnIndex(ctx, 4)
        local current_pin = self:get_pinned_provider(key) or ""
        local preview = current_pin == "" and "(none)" or current_pin

        ImGui.SetNextItemWidth(ctx, -1)
        if ImGui.BeginCombo(ctx, "##pin_" .. key, preview) then
          -- None option
          if ImGui.Selectable(ctx, "(none)", current_pin == "") then
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

  -- Open popup if not already open
  if not ImGui.IsPopupOpen(ctx, "##package_modal") then
    ImGui.OpenPopup(ctx, "##package_modal")
  end

  local pkg = self.package_data

  -- Modal window
  ImGui.SetNextWindowSize(ctx, 900, 650, ImGui.Cond_FirstUseEver)
  local visible = ImGui.BeginPopupModal(ctx, "##package_modal", true, ImGui.WindowFlags_NoTitleBar)

  if not visible then
    self.open = false
    self:close()
    return
  end

  -- Header
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#FFFFFF"))
  ImGui.Text(ctx, "Package: " .. (pkg.meta and pkg.meta.name or pkg.id))
  ImGui.PopStyleColor(ctx)

  ImGui.SameLine(ctx, 0, 20)
  ImGui.TextColored(ctx, hexrgb("#AAAAAA"), "Path:")
  ImGui.SameLine(ctx)
  ImGui.Text(ctx, pkg.path or "(demo package)")

  if pkg.meta then
    ImGui.SameLine(ctx, 0, 20)
    ImGui.TextColored(ctx, hexrgb("#AAAAAA"), "v" .. (pkg.meta.version or "?"))
  end

  ImGui.SameLine(ctx, -80)
  if ImGui.Button(ctx, "Close", 70, 0) then
    ImGui.CloseCurrentPopup(ctx)
    self:close()
  end

  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Toolbar
  self:draw_toolbar(ctx)

  ImGui.Spacing(ctx)

  -- Bulk actions
  self:draw_bulk_actions(ctx, pkg)

  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Asset view
  if ImGui.BeginChild(ctx, "##asset_view", 0, -1) then
    if self.view_mode == "grid" then
      self:draw_grid_view(ctx, pkg)
    else
      self:draw_tree_view(ctx, pkg)
    end
    ImGui.EndChild(ctx)
  end

  ImGui.EndPopup(ctx)
end

return M
