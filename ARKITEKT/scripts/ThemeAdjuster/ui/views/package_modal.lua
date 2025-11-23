-- @noindex
-- ThemeAdjuster/ui/views/package_modal.lua
-- Package manifest/micro-manage modal (overlay with visual tile grid)

local ImGui = require 'imgui' '0.10'
local Colors = require('arkitekt.core.colors')
local SearchInput = require('arkitekt.gui.widgets.inputs.search_input')
local Button = require('arkitekt.gui.widgets.primitives.button')
local Constants = require('ThemeAdjuster.defs.constants')
local ImageCache = require('arkitekt.core.images')
local hexrgb = Colors.hexrgb

local M = {}
local PackageModal = {}
PackageModal.__index = PackageModal

-- Platform path separator
local SEP = package.config:sub(1,1)

-- Tile constants - wide rectangles
local TILE_WIDTH = 195
local TILE_HEIGHT = 32
local TILE_SPACING = 4

-- Use shared theme category colors palette
local TC = Constants.THEME_CATEGORY_COLORS

-- Map area names to palette colors
local AREA_COLORS = {
  TCP = TC.tcp_blue,
  MCP = TC.mcp_green,
  Transport = TC.transport_gold,
  Toolbar = TC.toolbar_gold,
  ENVCP = TC.envcp_purple,
  Meter = TC.meter_cyan,
  Global = TC.global_gray,
  Items = TC.items_pink,
  MIDI = TC.midi_teal,
  Docker = TC.docker_brown,
  FX = TC.fx_orange,
  Menu = TC.menu_blue,
  Other = TC.other_slate,
}

-- Image cache for tooltips (uses arkitekt.core.images for proper lifecycle management)
-- See arkitekt/core/images.lua for full documentation
local image_cache = ImageCache.new({
  budget = 10,      -- Max images to load per frame
  max_cache = 100,  -- Max total cached images
  no_crop = true,   -- Don't slice 3-state images
})

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
  -- TCP / Track
  if key:match("^tcp_") or key:match("^track_") then return "TCP"
  -- MCP / Master / Mixer
  elseif key:match("^mcp_") or key:match("^master_") or key:match("^mixer_") then return "MCP"
  -- Transport
  elseif key:match("^transport_") or key:match("^trans_") then return "Transport"
  -- Toolbar
  elseif key:match("^toolbar_") or key:match("^tb_") then return "Toolbar"
  -- ENVCP / Envelope
  elseif key:match("^envcp_") or key:match("^env_") then return "ENVCP"
  -- Meter
  elseif key:match("^meter_") then return "Meter"
  -- Items
  elseif key:match("^item_") or key:match("^mi_") then return "Items"
  -- MIDI
  elseif key:match("^midi_") or key:match("^piano_") then return "MIDI"
  -- Docker
  elseif key:match("^docker_") or key:match("^dock_") then return "Docker"
  -- FX
  elseif key:match("^fx_") or key:match("^vst_") then return "FX"
  -- Menu
  elseif key:match("^menu_") then return "Menu"
  -- Global / General
  elseif key:match("^global_") or key:match("^gen_") or key:match("^generic_") then return "Global"
  else return "Other"
  end
end

-- Parse hex color string to RGBA int
local function parse_hex_color(hex_str)
  if not hex_str then return nil end
  local hex = hex_str:gsub("^#", "")
  if #hex == 6 then
    local r = tonumber(hex:sub(1, 2), 16) or 0
    local g = tonumber(hex:sub(3, 4), 16) or 0
    local b = tonumber(hex:sub(5, 6), 16) or 0
    return (r << 24) | (g << 16) | (b << 8) | 0xFF
  end
  return nil
end

function M.new(State, settings)
  local self = setmetatable({
    State = State,
    settings = settings,

    -- Modal state
    open = false,
    overlay_pushed = false,
    package_id = nil,
    package_data = nil,

    -- UI state
    search_text = "",
    selected_assets = {},  -- {key = true/false}
    view_mode = "grid",    -- "grid" or "tree"
    group_by_area = true,
    status_filter = "all", -- "all", "excluded", "pinned", "pinned_elsewhere"
    collapsed_groups = {}, -- {area = true/false}

    -- Performance caches (populated on show)
    _dpi_cache = {},       -- key -> {has_150, has_200}
    _area_cache = {},      -- key -> area string
    _grouped_cache = nil,  -- cached grouped assets
    _stats_cache = nil,    -- cached stats {total, included, excluded, pinned}
  }, PackageModal)

  return self
end

function PackageModal:show(package_data)
  self.open = true
  self.package_id = package_data.id
  self.package_data = package_data
  self.search_text = ""
  self.selected_assets = {}
  self.overlay_pushed = false
  self.status_filter = "all"
  self.collapsed_groups = {}

  -- Pre-compute caches for performance
  self._dpi_cache = {}
  self._area_cache = {}
  self._grouped_cache = nil
  self._stats_cache = nil

  -- Cache area detection and DPI variants for all keys
  for _, key in ipairs(package_data.keys_order or {}) do
    -- Cache area
    self._area_cache[key] = get_area_from_key(key)

    -- Cache DPI variants
    local asset = package_data.assets and package_data.assets[key]
    local asset_path = asset and asset.path
    local has_150, has_200 = check_dpi_variants(asset_path)
    self._dpi_cache[key] = {has_150 = has_150, has_200 = has_200}
  end

  -- Pre-compute grouped assets
  self._grouped_cache = self:_compute_grouped_assets(package_data.keys_order or {})

  -- Compute initial stats
  self:_compute_stats()
end

-- Compute stats for header display
function PackageModal:_compute_stats()
  local pkg = self.package_data
  if not pkg then return end

  local total = #(pkg.keys_order or {})
  local excluded = 0
  local pinned_here = 0
  local pinned_elsewhere = 0

  local excl = self:get_package_exclusions(pkg.id)
  local pins = self.State.get_package_pins()

  for _, key in ipairs(pkg.keys_order or {}) do
    if excl[key] then
      excluded = excluded + 1
    end
    local pin_owner = pins[key]
    if pin_owner == pkg.id then
      pinned_here = pinned_here + 1
    elseif pin_owner then
      pinned_elsewhere = pinned_elsewhere + 1
    end
  end

  self._stats_cache = {
    total = total,
    included = total - excluded,
    excluded = excluded,
    pinned_here = pinned_here,
    pinned_elsewhere = pinned_elsewhere
  }
end

function PackageModal:close()
  self.open = false
  self.overlay_pushed = false
  self.package_id = nil
  self.package_data = nil
  self.search_text = ""
  self.selected_assets = {}
  self.status_filter = "all"
  self.collapsed_groups = {}
  -- Clear caches
  self._dpi_cache = {}
  self._area_cache = {}
  self._grouped_cache = nil
  self._stats_cache = nil
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
  self:_compute_stats()  -- Refresh stats
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
  self:_compute_stats()  -- Refresh stats
end

-- Check if key passes current status filter
function PackageModal:passes_status_filter(key)
  if self.status_filter == "all" then
    return true
  end

  local pkg = self.package_data
  if not pkg then return true end

  local excl = self:get_package_exclusions(pkg.id)
  local is_excluded = excl[key] or false
  local pinned_to = self:get_pinned_provider(key)
  local is_pinned_here = pinned_to == pkg.id
  local is_pinned_elsewhere = pinned_to and pinned_to ~= pkg.id

  if self.status_filter == "excluded" then
    return is_excluded
  elseif self.status_filter == "pinned" then
    return is_pinned_here
  elseif self.status_filter == "pinned_elsewhere" then
    return is_pinned_elsewhere
  end

  return true
end

-- Pre-compute grouped assets (called once on show)
function PackageModal:_compute_grouped_assets(keys_order)
  local groups = {}
  local group_order = {"TCP", "MCP", "ENVCP", "Items", "MIDI", "Transport", "Toolbar", "Meter", "Docker", "FX", "Menu", "Global", "Other"}

  -- Initialize groups
  for _, area in ipairs(group_order) do
    groups[area] = {}
  end

  -- Categorize keys using cached area
  for _, key in ipairs(keys_order) do
    local area = self._area_cache[key] or get_area_from_key(key)
    table.insert(groups[area], key)
  end

  return {groups = groups, order = group_order}
end

-- Group assets by area (uses cache)
function PackageModal:group_assets_by_area(keys_order)
  if self._grouped_cache then
    return self._grouped_cache.groups, self._grouped_cache.order
  end

  -- Fallback if cache not available
  local groups = {}
  local group_order = {"TCP", "MCP", "ENVCP", "Items", "MIDI", "Transport", "Toolbar", "Meter", "Docker", "FX", "Menu", "Global", "Other"}

  for _, area in ipairs(group_order) do
    groups[area] = {}
  end

  for _, key in ipairs(keys_order) do
    local area = self._area_cache[key] or get_area_from_key(key)
    table.insert(groups[area], key)
  end

  return groups, group_order
end

-- Draw a single asset tile
function PackageModal:draw_asset_tile(ctx, pkg, key)
  local excl = self:get_package_exclusions(pkg.id)
  local included = not excl[key]
  local selected = self.selected_assets[key] or false
  local pinned_to = self:get_pinned_provider(key)
  local is_pinned = pinned_to == pkg.id
  local is_pinned_elsewhere = pinned_to and pinned_to ~= pkg.id

  -- Get asset info
  local asset = pkg.assets and pkg.assets[key]
  local asset_path = asset and asset.path

  -- Use cached DPI variants
  local dpi_info = self._dpi_cache[key] or {}
  local has_150, has_200 = dpi_info.has_150, dpi_info.has_200

  -- Use cached area for tile color
  local area = self._area_cache[key] or "Other"
  local base_color = AREA_COLORS[area] or hexrgb("#444455")

  -- Apply opacity based on included state
  local bg_opacity = included and 0.7 or 0.25
  local r = (base_color >> 24) & 0xFF
  local g = (base_color >> 16) & 0xFF
  local b = (base_color >> 8) & 0xFF
  local bg_color = (r << 24) | (g << 16) | (b << 8) | math.floor(255 * bg_opacity)

  -- Border color based on selection
  local border_color = selected and hexrgb("#4A90E2") or hexrgb("#333344", 0.8)

  -- Draw tile background
  local x1, y1 = ImGui.GetCursorScreenPos(ctx)
  local x2, y2 = x1 + TILE_WIDTH, y1 + TILE_HEIGHT
  local dl = ImGui.GetWindowDrawList(ctx)

  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, bg_color, 3)
  ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, border_color, 3, 0, selected and 2 or 1)

  -- Invisible button for interaction
  ImGui.InvisibleButton(ctx, "##tile_" .. key, TILE_WIDTH, TILE_HEIGHT)

  local clicked = ImGui.IsItemClicked(ctx, ImGui.MouseButton_Left)
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

  -- Right-click context menu for pin options
  if ImGui.BeginPopupContextItem(ctx, "tile_pin_menu_" .. key) then
    -- Show current pin status
    if pinned_to then
      ImGui.TextColored(ctx, hexrgb("#888888"), "Currently pinned to:")
      ImGui.TextColored(ctx, is_pinned and hexrgb("#4AE290") or hexrgb("#E8A54A"), pinned_to)
      ImGui.Separator(ctx)
    end

    -- Pin options
    if is_pinned then
      if ImGui.MenuItem(ctx, "Unpin from this package") then
        self:set_pinned_provider(key, nil)
      end
    else
      if ImGui.MenuItem(ctx, "Pin to this package") then
        self:set_pinned_provider(key, pkg.id)
      end
      if is_pinned_elsewhere then
        if ImGui.MenuItem(ctx, "Override pin (take from " .. pinned_to .. ")") then
          self:set_pinned_provider(key, pkg.id)
        end
      end
    end

    ImGui.EndPopup(ctx)
  end

  -- Draw key name (truncated) - more space for wider tiles
  local display_name = key
  local max_chars = 24
  if #display_name > max_chars then
    display_name = display_name:sub(1, max_chars - 2) .. ".."
  end

  local text_color = included and hexrgb("#FFFFFF") or hexrgb("#666666")
  local text_w, text_h = ImGui.CalcTextSize(ctx, display_name)
  local text_x = x1 + 6  -- Left-aligned with padding
  local text_y = y1 + (TILE_HEIGHT - text_h) * 0.5  -- Vertically centered

  ImGui.DrawList_AddText(dl, text_x, text_y, text_color, display_name)

  -- BADGE SYSTEM for status indicators (right side of tile)

  -- Excluded badge (red circle)
  if not included then
    local badge_x = x2 - 42
    local badge_y = y1 + TILE_HEIGHT * 0.5
    ImGui.DrawList_AddCircleFilled(dl, badge_x, badge_y, 5, hexrgb("#CC3333"))
  end

  -- Pinned elsewhere badge (orange dot)
  if is_pinned_elsewhere then
    local badge_x = x2 - 28
    local badge_y = y1 + TILE_HEIGHT * 0.5
    ImGui.DrawList_AddCircleFilled(dl, badge_x, badge_y, 5, hexrgb("#E8A54A"))
  end

  -- Pinned here badge (green dot)
  if is_pinned then
    local badge_x = x2 - 14
    local badge_y = y1 + TILE_HEIGHT * 0.5
    ImGui.DrawList_AddCircleFilled(dl, badge_x, badge_y, 5, hexrgb("#4AE290"))
  end

  -- DPI badge (top right, smaller text)
  if has_150 or has_200 then
    local dpi_text = has_200 and "2x" or "1.5"
    local dpi_w = ImGui.CalcTextSize(ctx, dpi_text)
    local dpi_x = x2 - dpi_w - 4
    local dpi_y = y1 + 2
    ImGui.DrawList_AddText(dl, dpi_x, dpi_y, hexrgb("#666666"), dpi_text)
  end

  -- Tooltip on hover
  if hovered then
    ImGui.BeginTooltip(ctx)

    -- Show image preview if available (uses arkitekt.gui.images)
    local rec = image_cache:get_validated(asset_path)
    if rec and rec.img then
      local img_w, img_h = rec.src_w, rec.src_h
      if img_w > 0 then
        -- Scale down large images
        local max_size = 200
        if img_w > max_size or img_h > max_size then
          local scale = max_size / math.max(img_w, img_h)
          img_w = math.floor(img_w * scale)
          img_h = math.floor(img_h * scale)
        end
        image_cache:draw_fit(ctx, asset_path, img_w, img_h)
        ImGui.Separator(ctx)
      end
    end

    -- Key name
    ImGui.Text(ctx, key)

    -- Status
    if not included then
      ImGui.TextColored(ctx, hexrgb("#FF6666"), "EXCLUDED")
    end
    if is_pinned then
      ImGui.TextColored(ctx, hexrgb("#4AE290"), "PINNED HERE")
    elseif is_pinned_elsewhere then
      ImGui.TextColored(ctx, hexrgb("#E8A54A"), "Pinned to: " .. pinned_to)
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
    ImGui.TextColored(ctx, hexrgb("#666666"), "Right-click: Pin options")
    ImGui.TextColored(ctx, hexrgb("#666666"), "Shift+Click: Select")

    ImGui.EndTooltip(ctx)
  end
end

-- Draw assets in grid view with virtualization
function PackageModal:draw_grid_view(ctx, pkg)
  local avail_w = ImGui.GetContentRegionAvail(ctx)
  local columns = math.max(1, math.floor(avail_w / (TILE_WIDTH + TILE_SPACING)))

  -- Get scroll info for virtualization
  local scroll_y = ImGui.GetScrollY(ctx)
  local window_h = ImGui.GetWindowHeight(ctx)
  local visible_top = scroll_y
  local visible_bottom = scroll_y + window_h

  -- Constants for virtualization
  local row_height = TILE_HEIGHT + TILE_SPACING
  local header_height = 40  -- Approximate height for group headers

  if self.group_by_area then
    -- Grouped view with virtualization
    local groups, group_order = self:group_assets_by_area(pkg.keys_order or {})

    -- First pass: calculate total height and build render list
    local current_y = 0
    local render_items = {}  -- {type = "header"/"tiles", y = ..., data = ...}

    for _, area in ipairs(group_order) do
      local keys = groups[area]
      if #keys > 0 then
        -- Filter by search and status
        local filtered_keys = {}
        for _, key in ipairs(keys) do
          local matches_search = self.search_text == "" or key:lower():find(self.search_text:lower(), 1, true)
          local matches_status = self:passes_status_filter(key)
          if matches_search and matches_status then
            table.insert(filtered_keys, key)
          end
        end

        if #filtered_keys > 0 then
          local is_collapsed = self.collapsed_groups[area] or false

          -- Header
          table.insert(render_items, {
            type = "header",
            y = current_y,
            height = header_height,
            area = area,
            count = #filtered_keys,
            collapsed = is_collapsed
          })
          current_y = current_y + header_height

          -- Only add rows if not collapsed
          if not is_collapsed then
            -- Calculate rows for this group
            local num_rows = math.ceil(#filtered_keys / columns)
            for row = 0, num_rows - 1 do
              local row_keys = {}
              for col = 0, columns - 1 do
                local idx = row * columns + col + 1
                if idx <= #filtered_keys then
                  table.insert(row_keys, filtered_keys[idx])
                end
              end

              if #row_keys > 0 then
                table.insert(render_items, {
                  type = "row",
                  y = current_y,
                  height = row_height,
                  keys = row_keys
                })
                current_y = current_y + row_height
              end
            end
          end

          -- Spacing after group
          current_y = current_y + 8
        end
      end
    end

    -- Set content height for proper scrolling
    local total_height = current_y

    -- Second pass: render only visible items
    for _, item in ipairs(render_items) do
      local item_top = item.y
      local item_bottom = item.y + item.height

      -- Check if visible (with some buffer for smooth scrolling)
      local buffer = row_height * 2
      if item_bottom >= visible_top - buffer and item_top <= visible_bottom + buffer then
        -- Position cursor
        ImGui.SetCursorPosY(ctx, item_top)

        if item.type == "header" then
          ImGui.Spacing(ctx)
          -- Clickable header for collapse/expand
          local collapse_icon = item.collapsed and "▶" or "▼"
          local header_text = collapse_icon .. " " .. item.area .. " (" .. item.count .. ")"
          if ImGui.Selectable(ctx, header_text, false, ImGui.SelectableFlags_None) then
            self.collapsed_groups[item.area] = not self.collapsed_groups[item.area]
          end
          ImGui.Separator(ctx)
          ImGui.Spacing(ctx)
        elseif item.type == "row" then
          for i, key in ipairs(item.keys) do
            if i > 1 then
              ImGui.SameLine(ctx, 0, TILE_SPACING)
            end
            self:draw_asset_tile(ctx, pkg, key)
          end
        end
      end
    end

    -- Ensure scroll area has correct height
    ImGui.SetCursorPosY(ctx, total_height)
    ImGui.Dummy(ctx, 0, 0)

  else
    -- Flat view with virtualization
    local filtered_keys = {}
    for _, key in ipairs(pkg.keys_order or {}) do
      local matches_search = self.search_text == "" or key:lower():find(self.search_text:lower(), 1, true)
      local matches_status = self:passes_status_filter(key)
      if matches_search and matches_status then
        table.insert(filtered_keys, key)
      end
    end

    local num_rows = math.ceil(#filtered_keys / columns)
    local total_height = num_rows * row_height

    -- Calculate visible row range
    local first_visible_row = math.max(0, math.floor(visible_top / row_height) - 2)
    local last_visible_row = math.min(num_rows - 1, math.ceil(visible_bottom / row_height) + 2)

    -- Render only visible rows
    for row = first_visible_row, last_visible_row do
      local y_pos = row * row_height
      ImGui.SetCursorPosY(ctx, y_pos)

      for col = 0, columns - 1 do
        local idx = row * columns + col + 1
        if idx <= #filtered_keys then
          if col > 0 then
            ImGui.SameLine(ctx, 0, TILE_SPACING)
          end
          self:draw_asset_tile(ctx, pkg, filtered_keys[idx])
        end
      end
    end

    -- Ensure scroll area has correct height
    ImGui.SetCursorPosY(ctx, total_height)
    ImGui.Dummy(ctx, 0, 0)
  end
end

-- Draw modal content
function PackageModal:draw_content(ctx, bounds)
  local pkg = self.package_data
  if not pkg then return true end  -- Close if no package

  -- Reset image cache budget for this frame
  image_cache:begin_frame()

  -- Handle keyboard shortcuts
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
    self.selected_assets = {}  -- Clear selection on Esc
  end
  if ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl) and ImGui.IsKeyPressed(ctx, ImGui.Key_A) then
    -- Ctrl+A: Select all visible
    for _, key in ipairs(pkg.keys_order or {}) do
      local matches_search = self.search_text == "" or key:lower():find(self.search_text:lower(), 1, true)
      local matches_status = self:passes_status_filter(key)
      if matches_search and matches_status then
        self.selected_assets[key] = true
      end
    end
  end

  local dl = ImGui.GetWindowDrawList(ctx)
  local padding = 12
  local content_w = bounds.w - padding * 2
  local start_x = padding

  -- Header with stats
  ImGui.SetCursorPosX(ctx, start_x)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#FFFFFF"))
  ImGui.Text(ctx, "Package: " .. (pkg.meta and pkg.meta.name or pkg.id))
  ImGui.PopStyleColor(ctx)

  if pkg.meta and pkg.meta.version then
    ImGui.SameLine(ctx, 0, 8)
    ImGui.TextColored(ctx, hexrgb("#666666"), "v" .. pkg.meta.version)
  end

  -- Stats display
  local stats = self._stats_cache
  if stats then
    ImGui.SameLine(ctx, 0, 20)
    ImGui.TextColored(ctx, hexrgb("#4AE290"), tostring(stats.included) .. " included")
    ImGui.SameLine(ctx, 0, 8)
    ImGui.TextColored(ctx, hexrgb("#666666"), "/")
    ImGui.SameLine(ctx, 0, 8)
    ImGui.TextColored(ctx, hexrgb("#CC3333"), tostring(stats.excluded) .. " excluded")
    if stats.pinned_here > 0 then
      ImGui.SameLine(ctx, 0, 12)
      ImGui.TextColored(ctx, hexrgb("#4AE290"), tostring(stats.pinned_here) .. " pinned")
    end
    if stats.pinned_elsewhere > 0 then
      ImGui.SameLine(ctx, 0, 8)
      ImGui.TextColored(ctx, hexrgb("#E8A54A"), tostring(stats.pinned_elsewhere) .. " contested")
    end
  end

  ImGui.Dummy(ctx, 0, 4)

  -- Toolbar row
  local toolbar_x, toolbar_y = ImGui.GetCursorScreenPos(ctx)
  toolbar_x = toolbar_x + start_x

  -- Search input using primitive
  local search_w = 220
  local search_h = 26
  SearchInput.set_text("pkg_modal_search", self.search_text)
  SearchInput.draw(ctx, dl, toolbar_x, toolbar_y, search_w, search_h, {
    id = "pkg_modal_search",
    placeholder = "Search assets...",
    on_change = function(text)
      self.search_text = text
    end
  }, "pkg_modal_search")

  -- Buttons after search
  local btn_x = toolbar_x + search_w + 8
  local btn_h = 26

  -- View mode toggle
  local _, grid_clicked = Button.draw(ctx, dl, btn_x, toolbar_y, 50, btn_h, {
    id = "view_mode",
    label = self.view_mode == "grid" and "Grid" or "Tree",
    rounding = 3,
  }, "pkg_modal_view")
  if grid_clicked then
    self.view_mode = self.view_mode == "grid" and "tree" or "grid"
  end
  btn_x = btn_x + 50 + 4

  -- Group toggle
  local _, group_clicked = Button.draw(ctx, dl, btn_x, toolbar_y, 65, btn_h, {
    id = "group_mode",
    label = self.group_by_area and "Grouped" or "Flat",
    rounding = 3,
  }, "pkg_modal_group")
  if group_clicked then
    self.group_by_area = not self.group_by_area
  end
  btn_x = btn_x + 65 + 8

  -- Status filter dropdown
  local filter_labels = {
    all = "All",
    excluded = "Excluded",
    pinned = "Pinned",
    pinned_elsewhere = "Contested"
  }
  local filter_label = "Filter: " .. filter_labels[self.status_filter]
  local _, filter_clicked = Button.draw(ctx, dl, btn_x, toolbar_y, 90, btn_h, {
    id = "status_filter",
    label = filter_label,
    rounding = 3,
  }, "pkg_modal_filter")
  if filter_clicked then
    ImGui.OpenPopup(ctx, "status_filter_popup")
  end

  -- Status filter popup menu
  if ImGui.BeginPopup(ctx, "status_filter_popup") then
    if ImGui.MenuItem(ctx, "All", nil, self.status_filter == "all") then
      self.status_filter = "all"
    end
    if ImGui.MenuItem(ctx, "Excluded", nil, self.status_filter == "excluded") then
      self.status_filter = "excluded"
    end
    if ImGui.MenuItem(ctx, "Pinned Here", nil, self.status_filter == "pinned") then
      self.status_filter = "pinned"
    end
    if ImGui.MenuItem(ctx, "Contested", nil, self.status_filter == "pinned_elsewhere") then
      self.status_filter = "pinned_elsewhere"
    end
    ImGui.EndPopup(ctx)
  end
  btn_x = btn_x + 90 + 12

  -- Selection count display
  local selection_count = 0
  for _, selected in pairs(self.selected_assets) do
    if selected then selection_count = selection_count + 1 end
  end
  if selection_count > 0 then
    ImGui.SetCursorScreenPos(ctx, btn_x, toolbar_y + 5)
    ImGui.TextColored(ctx, hexrgb("#4A90E2"), tostring(selection_count) .. " selected")
    local text_w = ImGui.CalcTextSize(ctx, tostring(selection_count) .. " selected")
    btn_x = btn_x + text_w + 12
  end

  -- Bulk action buttons
  local _, sel_all_clicked = Button.draw(ctx, dl, btn_x, toolbar_y, 65, btn_h, {
    id = "select_all",
    label = "Select All",
    rounding = 3,
  }, "pkg_modal_sel_all")
  if sel_all_clicked then
    for _, key in ipairs(pkg.keys_order or {}) do
      if self.search_text == "" or key:lower():find(self.search_text:lower(), 1, true) then
        self.selected_assets[key] = true
      end
    end
  end
  btn_x = btn_x + 65 + 4

  local _, clear_clicked = Button.draw(ctx, dl, btn_x, toolbar_y, 45, btn_h, {
    id = "clear",
    label = "Clear",
    rounding = 3,
  }, "pkg_modal_clear")
  if clear_clicked then
    self.selected_assets = {}
  end
  btn_x = btn_x + 45 + 4

  local _, inc_clicked = Button.draw(ctx, dl, btn_x, toolbar_y, 35, btn_h, {
    id = "include",
    label = "Inc.",
    rounding = 3,
  }, "pkg_modal_inc")
  if inc_clicked then
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
  btn_x = btn_x + 35 + 4

  local _, exc_clicked = Button.draw(ctx, dl, btn_x, toolbar_y, 35, btn_h, {
    id = "exclude",
    label = "Exc.",
    rounding = 3,
  }, "pkg_modal_exc")
  if exc_clicked then
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
  btn_x = btn_x + 35 + 4

  local _, pin_clicked = Button.draw(ctx, dl, btn_x, toolbar_y, 35, btn_h, {
    id = "pin",
    label = "Pin",
    rounding = 3,
  }, "pkg_modal_pin")
  if pin_clicked then
    local pins = self.State.get_package_pins()
    for key, selected in pairs(self.selected_assets) do
      if selected then
        pins[key] = pkg.id
      end
    end
    self.State.set_package_pins(pins)
  end

  -- Move cursor past toolbar
  ImGui.SetCursorScreenPos(ctx, toolbar_x - start_x, toolbar_y + btn_h + 8)

  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 4)

  -- Asset view in scrollable child - use all remaining space
  ImGui.SetCursorPosX(ctx, start_x)
  local child_h = bounds.h - ImGui.GetCursorPosY(ctx) - 8

  -- Use 0 width to fill remaining space (avoids right padding)
  if ImGui.BeginChild(ctx, "##asset_view", 0, child_h) then
    if self.view_mode == "grid" then
      self:draw_grid_view(ctx, pkg)
    else
      self:draw_grid_view(ctx, pkg)  -- Use grid for both for now
    end
    ImGui.EndChild(ctx)
  end

  -- No close button needed - overlay handles closing
  return false
end

function PackageModal:draw(ctx, window)
  if not self.open or not self.package_data then
    return
  end

  -- Use overlay system if available
  if window and window.overlay and not self.overlay_pushed then
    self.overlay_pushed = true

    window.overlay:push({
      id = 'package-modal',
      close_on_scrim = true,
      esc_to_close = true,
      on_close = function()
        self:close()
      end,
      render = function(render_ctx, alpha, bounds)
        -- Use most of the viewport
        local max_w = 1400
        local max_h = 900
        local min_w = 600
        local min_h = 400

        local modal_w = math.floor(math.max(min_w, math.min(max_w, bounds.w * 0.95)))
        local modal_h = math.floor(math.max(min_h, math.min(max_h, bounds.h * 0.90)))

        -- Center in viewport
        local modal_x = bounds.x + math.floor((bounds.w - modal_w) * 0.5)
        local modal_y = bounds.y + math.floor((bounds.h - modal_h) * 0.5)

        ImGui.SetCursorScreenPos(render_ctx, modal_x, modal_y)

        local modal_bounds = {
          x = modal_x,
          y = modal_y,
          w = modal_w,
          h = modal_h
        }

        local should_close = self:draw_content(render_ctx, modal_bounds)

        if should_close then
          window.overlay:pop('package-modal')
          self:close()
        end
      end
    })
  end
end

return M
