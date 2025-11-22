-- @noindex
-- ThemeAdjuster/ui/views/package_modal.lua
-- Package manifest/micro-manage modal (overlay with visual tile grid)

local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local SearchInput = require('rearkitekt.gui.widgets.inputs.search_input')
local Button = require('rearkitekt.gui.widgets.primitives.button')
local Constants = require('ThemeAdjuster.defs.constants')
local hexrgb = Colors.hexrgb

local M = {}
local PackageModal = {}
PackageModal.__index = PackageModal

-- Platform path separator
local SEP = package.config:sub(1,1)

-- Tile constants - wide rectangles
local TILE_WIDTH = 130
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

-- Image cache for tooltips
local image_cache = {}

-- Helper to create/get cached image with proper lifecycle management
local function get_cached_image(ctx, path)
  if not path or path == "" then return nil end
  if path:find("^%(mock%)") then return nil end  -- Demo packages have no real images

  local entry = image_cache[path]

  -- Check if we have a cached entry
  if entry ~= nil then
    if entry == false then
      return nil  -- Previously failed to load
    end

    -- Validate the image is still valid
    local ok, w, h = pcall(ImGui.Image_GetSize, entry)
    if ok and w and w > 0 then
      return entry  -- Image is still valid
    else
      -- Image became invalid, clear it
      pcall(function() ImGui.Image_Free(entry) end)
      image_cache[path] = nil
    end
  end

  -- Try to create new image
  local ok, img = pcall(ImGui.CreateImage, path)
  if ok and img then
    -- Verify it loaded correctly
    local ok2, w, h = pcall(ImGui.Image_GetSize, img)
    if ok2 and w and w > 0 then
      image_cache[path] = img
      return img
    else
      pcall(function() ImGui.Image_Free(img) end)
      image_cache[path] = false
      return nil
    end
  else
    image_cache[path] = false  -- Mark as failed
    return nil
  end
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
end

function PackageModal:close()
  self.open = false
  self.overlay_pushed = false
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
  local group_order = {"TCP", "MCP", "ENVCP", "Items", "MIDI", "Transport", "Toolbar", "Meter", "Docker", "FX", "Menu", "Global", "Other"}

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

  -- Get area color for tile background
  local area = get_area_from_key(key)
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

  -- Draw key name (truncated) - more space for wider tiles
  local display_name = key
  local max_chars = 16
  if #display_name > max_chars then
    display_name = display_name:sub(1, max_chars - 2) .. ".."
  end

  local text_color = included and hexrgb("#FFFFFF") or hexrgb("#666666")
  local text_w, text_h = ImGui.CalcTextSize(ctx, display_name)
  local text_x = x1 + 6  -- Left-aligned with padding
  local text_y = y1 + (TILE_HEIGHT - text_h) * 0.5  -- Vertically centered

  ImGui.DrawList_AddText(dl, text_x, text_y, text_color, display_name)

  -- BADGE SYSTEM for status indicators (right side of tile)

  -- Excluded badge (red circle with X)
  if not included then
    local badge_x = x2 - 28
    local badge_y = y1 + TILE_HEIGHT * 0.5
    ImGui.DrawList_AddCircleFilled(dl, badge_x, badge_y, 5, hexrgb("#CC3333"))
  end

  -- Pinned badge (green dot)
  if is_pinned then
    local badge_x = x2 - 14
    local badge_y = y1 + TILE_HEIGHT * 0.5
    ImGui.DrawList_AddCircleFilled(dl, badge_x, badge_y, 5, hexrgb("#4AE290"))
  end

  -- DPI badge (right side, smaller text)
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

    -- Show image preview if available
    local img = get_cached_image(ctx, asset_path)
    if img then
      local ok, img_w, img_h = pcall(ImGui.Image_GetSize, img)
      if ok and img_w and img_w > 0 then
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
  local avail_w = ImGui.GetContentRegionAvail(ctx)
  local columns = math.max(1, math.floor(avail_w / (TILE_WIDTH + TILE_SPACING)))

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

-- Draw modal content
function PackageModal:draw_content(ctx, bounds)
  local pkg = self.package_data
  if not pkg then return true end  -- Close if no package

  local dl = ImGui.GetWindowDrawList(ctx)
  local padding = 12
  local content_w = bounds.w - padding * 2
  local start_x = padding

  -- Header
  ImGui.SetCursorPosX(ctx, start_x)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#FFFFFF"))
  ImGui.Text(ctx, "Package: " .. (pkg.meta and pkg.meta.name or pkg.id))
  ImGui.PopStyleColor(ctx)

  ImGui.SameLine(ctx, 0, 20)
  ImGui.TextColored(ctx, hexrgb("#AAAAAA"), tostring(#(pkg.keys_order or {})) .. " assets")

  if pkg.meta and pkg.meta.version then
    ImGui.SameLine(ctx, 0, 20)
    ImGui.TextColored(ctx, hexrgb("#666666"), "v" .. pkg.meta.version)
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
  btn_x = btn_x + 65 + 12

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
