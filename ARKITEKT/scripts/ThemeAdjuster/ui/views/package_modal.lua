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
local TILE_SIZE = 56
local TILE_SPACING = 6

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
  if key:match("^tcp_") then return "TCP"
  elseif key:match("^mcp_") then return "MCP"
  elseif key:match("^transport_") then return "Transport"
  elseif key:match("^global_") or key:match("^gen_") then return "Global"
  elseif key:match("^envcp_") then return "ENVCP"
  elseif key:match("^meter_") then return "Meter"
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

  -- Get package color for tile background
  local pkg_color = parse_hex_color(pkg.meta and pkg.meta.color)
  local base_color = pkg_color or hexrgb("#444455")

  -- Apply opacity based on included state
  local bg_opacity = included and 0.6 or 0.2
  local r = (base_color >> 24) & 0xFF
  local g = (base_color >> 16) & 0xFF
  local b = (base_color >> 8) & 0xFF
  local bg_color = (r << 24) | (g << 16) | (b << 8) | math.floor(255 * bg_opacity)

  -- Border color based on selection
  local border_color = selected and hexrgb("#4A90E2") or hexrgb("#333344", 0.8)

  -- Draw tile background
  local x1, y1 = ImGui.GetCursorScreenPos(ctx)
  local x2, y2 = x1 + TILE_SIZE, y1 + TILE_SIZE
  local dl = ImGui.GetWindowDrawList(ctx)

  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, bg_color, 3)
  ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, border_color, 3, 0, selected and 2 or 1)

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
  if #display_name > 8 then
    display_name = display_name:sub(1, 6) .. ".."
  end

  local text_color = included and hexrgb("#FFFFFF") or hexrgb("#666666")
  local text_w = ImGui.CalcTextSize(ctx, display_name)
  local text_x = x1 + (TILE_SIZE - text_w) * 0.5
  local text_y = y2 - 12

  ImGui.DrawList_AddText(dl, text_x, text_y, text_color, display_name)

  -- BADGE SYSTEM for status indicators

  -- Excluded badge (red X in top-left)
  if not included then
    local badge_x = x1 + 3
    local badge_y = y1 + 3
    ImGui.DrawList_AddCircleFilled(dl, badge_x + 5, badge_y + 5, 6, hexrgb("#CC3333"))
    ImGui.DrawList_AddText(dl, badge_x + 2, badge_y, hexrgb("#FFFFFF"), "X")
  end

  -- Pinned badge (green dot in top-right)
  if is_pinned then
    local badge_x = x2 - 8
    local badge_y = y1 + 4
    ImGui.DrawList_AddCircleFilled(dl, badge_x, badge_y + 4, 5, hexrgb("#4AE290"))
  end

  -- DPI badge (bottom-left corner)
  if has_150 or has_200 then
    local dpi_x = x1 + 2
    local dpi_y = y1 + 2
    local dpi_text = has_200 and "2x" or "1.5"
    ImGui.DrawList_AddText(dl, dpi_x, dpi_y, hexrgb("#888888"), dpi_text)
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

-- Draw modal content
function PackageModal:draw_content(ctx, bounds)
  local pkg = self.package_data
  if not pkg then return true end  -- Close if no package

  local content_w = bounds.w - 80
  local start_x = 40

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

  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Toolbar
  ImGui.SetCursorPosX(ctx, start_x)

  -- Search
  ImGui.SetNextItemWidth(ctx, 200)
  local changed, new_text = ImGui.InputTextWithHint(ctx, "##search", "Search assets...", self.search_text)
  if changed then
    self.search_text = new_text
  end

  ImGui.SameLine(ctx)

  -- View mode toggle
  if ImGui.Button(ctx, self.view_mode == "grid" and "Grid" or "Tree", 50) then
    self.view_mode = self.view_mode == "grid" and "tree" or "grid"
  end

  ImGui.SameLine(ctx)

  -- Group toggle
  if ImGui.Button(ctx, self.group_by_area and "Grouped" or "Flat", 60) then
    self.group_by_area = not self.group_by_area
  end

  ImGui.Spacing(ctx)

  -- Bulk actions
  ImGui.SetCursorPosX(ctx, start_x)

  if ImGui.Button(ctx, "Select All", 70, 0) then
    for _, key in ipairs(pkg.keys_order or {}) do
      if self.search_text == "" or key:lower():find(self.search_text:lower(), 1, true) then
        self.selected_assets[key] = true
      end
    end
  end

  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Clear", 50, 0) then
    self.selected_assets = {}
  end

  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Inc.", 35, 0) then
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
  if ImGui.Button(ctx, "Exc.", 35, 0) then
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
  if ImGui.Button(ctx, "Pin", 35, 0) then
    local pins = self.State.get_package_pins()
    for key, selected in pairs(self.selected_assets) do
      if selected then
        pins[key] = pkg.id
      end
    end
    self.State.set_package_pins(pins)
  end

  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Asset view in scrollable child
  ImGui.SetCursorPosX(ctx, start_x)
  local child_h = bounds.h - ImGui.GetCursorPosY(ctx) - 60

  if ImGui.BeginChild(ctx, "##asset_view", content_w, child_h) then
    if self.view_mode == "grid" then
      self:draw_grid_view(ctx, pkg)
    else
      self:draw_grid_view(ctx, pkg)  -- Use grid for both for now
    end
    ImGui.EndChild(ctx)
  end

  -- Close button
  ImGui.Spacing(ctx)
  ImGui.SetCursorPosX(ctx, start_x + (content_w - 100) * 0.5)
  local should_close = ImGui.Button(ctx, "Close", 100, 28)

  -- Also close on Escape
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
    should_close = true
  end

  return should_close
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
        -- Responsive sizing
        local max_w = 900
        local max_h = 700
        local min_w = 600
        local min_h = 400

        local modal_w = math.floor(math.max(min_w, math.min(max_w, bounds.w * 0.85)))
        local modal_h = math.floor(math.max(min_h, math.min(max_h, bounds.h * 0.85)))

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
