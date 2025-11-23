-- @noindex
-- Arkitekt/gui/widgets/package_tiles/renderer.lua
-- Package tile rendering module with text truncation support

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local Draw = require('arkitekt.gui.draw')
local MarchingAnts = require('arkitekt.gui.fx.interactions.marching_ants')
local Colors = require('arkitekt.core.colors')
local ImageCache = require('arkitekt.core.images')

local M = {}
local hexrgb = Colors.hexrgb

-- Lazy-load metadata module (only when needed)
local Metadata = nil
local function get_metadata()
  if not Metadata then
    -- Get script directory from debug info
    local info = debug.getinfo(1, "S")
    local script_dir = info.source:match("@(.+[\\/])") or ""

    -- Navigate from arkitekt/gui/widgets/media/package_tiles/ to scripts/ThemeAdjuster/packages/
    -- Go up 5 levels (package_tiles -> media -> widgets -> gui -> arkitekt) then into scripts/ThemeAdjuster/packages
    local metadata_path = script_dir .. "../../../../../scripts/ThemeAdjuster/packages/metadata.lua"

    -- Try loading directly
    local chunk, err = loadfile(metadata_path)
    if chunk then
      Metadata = chunk()
    else
      -- Fallback: try require paths
      local paths_to_try = {
        'ThemeAdjuster.packages.metadata',
        'scripts.ThemeAdjuster.packages.metadata',
      }

      for _, path in ipairs(paths_to_try) do
        local ok, mod = pcall(require, path)
        if ok then
          Metadata = mod
          break
        end
      end
    end
  end
  return Metadata
end

-- Shared image cache for package mosaic previews
M._package_image_cache = M._package_image_cache or ImageCache.new({
  budget = 20,      -- Load up to 20 images per frame
  max_cache = 100,  -- Cache up to 100 images
  no_crop = true,   -- Don't slice 3-state images
})

M.CONFIG = {
  tile = {
    rounding = 6,
    hover_shadow = { enabled = true, max_offset = 2, max_alpha = 20 },
    max_height = 220,
  },
  
  colors = {
    bg = { inactive = hexrgb("#1A1A1A"), active = hexrgb("#2D4A37"), hover_tint = hexrgb("#2A2A2A"), hover_influence = 0.4 },
    border = { inactive = hexrgb("#303030"), active = nil, hover = nil, thickness = 0.5 },
    text = { active = hexrgb("#FFFFFF"), inactive = hexrgb("#999999"), secondary = hexrgb("#888888"), conflict = hexrgb("#FFA500") },
    badge = { bg_active = hexrgb("#00000099"), bg_inactive = hexrgb("#00000066"), text = hexrgb("#AAAAAA") },
    footer = { gradient = hexrgb("#00000044") },
  },
  
  selection = {
    ant_speed = 20,
    ant_color = nil,
    ant_dash = 8,
    ant_gap = 6,
    brightness_factor = 1.8,
    saturation_factor = 0.6,
  },
  
  badge = { padding_x = 10, padding_y = 6, rounding = 4, margin = 8 },
  checkbox = { min_size = 12, padding_x = 2, padding_y = 1, margin = 8 },
  footer = { height = 32, padding_x = 10 },

  tags = {
    bottom_offset = 6,       -- Distance from footer
    height = 14,             -- Tag chip height
    padding_x = 4,           -- Horizontal padding inside chip
    gap = 3,                 -- Gap between chips
    margin_x = 10,           -- Margin from tile edges
    rounding = 3,            -- Corner rounding
    max_tags = 10,           -- Maximum tags to show
    -- Full display names
    display = {
      TCP = "TCP",
      MCP = "MCP",
      Transport = "TRANSPORT",
      Toolbar = "TOOLBARS",
      Meter = "GLOBAL",      -- Meter consolidated into Global
      EnvCP = "ENVCP",
      Items = "ITEMS",
      MIDI = "MIDI",
      Track = "TCP",         -- Track consolidated into TCP
      Global = "GLOBAL",
      RTCONFIG = "RTCONFIG",
    },
    -- Color palette matching active assignment tagging system
    colors = {
      TCP = hexrgb("#5A7A9A"),      -- Blue
      MCP = hexrgb("#9A9A5A"),      -- Yellow
      ENVCP = hexrgb("#5A9A8A"),    -- Teal
      TRANSPORT = hexrgb("#9A5A5A"),-- Red
      GLOBAL = hexrgb("#6A6A6A"),   -- Grey
      TOOLBARS = hexrgb("#8A6A5A"), -- Brown/orange
      ITEMS = hexrgb("#7A8A5A"),    -- Olive
      MIDI = hexrgb("#6A5A8A"),     -- Purple
      RTCONFIG = hexrgb("#5AAA5A"), -- Green (important!)
    },
    text_color = hexrgb("#000000"),  -- Black text
  },
  
  mosaic = {
    padding = 15, max_size = 50, gap = 6, count = 3,
    rounding = 3, border_color = hexrgb("#00000088"), border_thickness = 1, y_offset = 45,
  },
  
  animation = { speed_hover = 12.0, speed_active = 8.0 },
  
  truncation = {
    ellipsis = "...",
    min_chars = 3,
  },
}

local function truncate_text(ctx, text, max_width)
  if not text or text == "" then return "" end
  
  local full_w, _ = ImGui.CalcTextSize(ctx, text)
  if full_w <= max_width then return text end
  
  local ellipsis = M.CONFIG.truncation.ellipsis
  local ellipsis_w, _ = ImGui.CalcTextSize(ctx, ellipsis)
  local available = max_width - ellipsis_w
  
  if available <= 0 then return ellipsis end
  
  for i = #text, M.CONFIG.truncation.min_chars, -1 do
    local substr = text:sub(1, i)
    local w, _ = ImGui.CalcTextSize(ctx, substr)
    if w <= available then
      return substr .. ellipsis
    end
  end
  
  return text:sub(1, M.CONFIG.truncation.min_chars) .. ellipsis
end

M.TileRenderer = {}

function M.TileRenderer.background(dl, rect, bg_color, hover_factor)
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  
  if M.CONFIG.tile.hover_shadow.enabled and hover_factor > 0.01 then
    local shadow_alpha = math.floor(hover_factor * M.CONFIG.tile.hover_shadow.max_alpha)
    local shadow_col = (0x000000 << 8) | shadow_alpha
    for i = M.CONFIG.tile.hover_shadow.max_offset, 1, -1 do
      Draw.rect_filled(dl, x1 - i, y1 - i + 2, x2 + i, y2 + i + 2, shadow_col, M.CONFIG.tile.rounding)
    end
  end
  
  Draw.rect_filled(dl, x1, y1, x2, y2, bg_color, M.CONFIG.tile.rounding)
end

function M.TileRenderer.border(dl, rect, base_color, is_selected, is_active, is_hovered)
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  
  if is_selected then
    local ant_color
    if M.CONFIG.selection.ant_color then
      ant_color = M.CONFIG.selection.ant_color
    else
      ant_color = Colors.generate_marching_ants_color(
        base_color,
        M.CONFIG.selection.brightness_factor,
        M.CONFIG.selection.saturation_factor
      )
    end
    
    MarchingAnts.draw(
      dl, x1 + 0.5, y1 + 0.5, x2 - 0.5, y2 - 0.5,
      ant_color, M.CONFIG.colors.border.thickness, M.CONFIG.tile.rounding,
      M.CONFIG.selection.ant_dash, M.CONFIG.selection.ant_gap, M.CONFIG.selection.ant_speed
    )
  else
    local border_color
    
    if is_hovered then
      if M.CONFIG.colors.border.hover then
        border_color = M.CONFIG.colors.border.hover
      else
        border_color = Colors.generate_active_border(base_color, 0.6, 1.8)
      end
    elseif is_active then
      if M.CONFIG.colors.border.active then
        border_color = M.CONFIG.colors.border.active
      else
        border_color = Colors.generate_active_border(base_color, 0.7, 1.6)
      end
    else
      if M.CONFIG.colors.border.inactive then
        border_color = M.CONFIG.colors.border.inactive
      else
        border_color = Colors.generate_border(base_color, 0.2, 0.8)
      end
    end
    
    Draw.rect(dl, x1, y1, x2, y2, border_color, M.CONFIG.tile.rounding, M.CONFIG.colors.border.thickness)
  end
end

function M.TileRenderer.order_badge(ctx, dl, pkg, P, tile_x, tile_y)
  local order_index = 0
  for i, pid in ipairs(pkg.order) do
    if pid == P.id then
      order_index = i
      break
    end
  end
  
  local badge = '#' .. tostring(order_index)
  local bw, bh = ImGui.CalcTextSize(ctx, badge)
  
  local x1 = tile_x + M.CONFIG.badge.margin
  local y1 = tile_y + M.CONFIG.badge.margin
  local x2 = x1 + bw + M.CONFIG.badge.padding_x
  local y2 = y1 + bh + M.CONFIG.badge.padding_y
  
  local is_active = pkg.active[P.id] == true
  local bg = is_active and M.CONFIG.colors.badge.bg_active or M.CONFIG.colors.badge.bg_inactive
  
  Draw.rect_filled(dl, x1, y1, x2, y2, bg, M.CONFIG.badge.rounding)
  Draw.centered_text(ctx, badge, x1, y1, x2, y2, M.CONFIG.colors.badge.text)
  
  ImGui.SetCursorScreenPos(ctx, x1, y1)
  ImGui.InvisibleButton(ctx, '##ordtip-' .. P.id, x2 - x1, y2 - y1)
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "Overwrite priority")
  end
end

function M.TileRenderer.conflicts(ctx, dl, pkg, P, tile_x, tile_y, tile_w)
  local conflicts = pkg:conflicts(true)
  local conf_count = conflicts[P.id] or 0
  if conf_count == 0 then return end

  local text = string.format('%d conflicts', conf_count)
  local tw, th = ImGui.CalcTextSize(ctx, text)
  local x = tile_x + math.floor((tile_w - tw) / 2)
  local y = tile_y + M.CONFIG.badge.margin

  Draw.text(dl, x, y, M.CONFIG.colors.text.conflict, text)

  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, '##conftip-' .. P.id, tw, th)
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "Conflicting Assets in Packages\n(autosolved through Overwrite Priority)")
  end
end

function M.TileRenderer.tags(ctx, dl, P, tile_x, tile_y, tile_w, tile_h)
  -- Start with manual tags from package meta (like RTCONFIG)
  local manual_tags = P.meta and P.meta.tags or {}

  -- Auto-generate area tags from assets using metadata
  local auto_tags = {}
  local metadata = get_metadata()
  if metadata then
    local image_names = {}
    for key, _ in pairs(P.assets or {}) do
      table.insert(image_names, key)
    end
    auto_tags = metadata.suggest_tags(image_names, 0.2) or {}
  end

  -- Combine manual tags (like RTCONFIG) with auto-generated area tags
  local tags = {}
  for _, tag in ipairs(manual_tags) do
    table.insert(tags, tag)
  end
  for _, tag in ipairs(auto_tags) do
    table.insert(tags, tag)
  end

  if #tags == 0 then return end

  -- Convert to display names and deduplicate
  local seen = {}
  local display_tags = {}
  for _, tag in ipairs(tags) do
    local display_name = M.CONFIG.tags.display[tag] or tag
    if not seen[display_name] then
      seen[display_name] = true
      table.insert(display_tags, display_name)
      if #display_tags >= M.CONFIG.tags.max_tags then
        break
      end
    end
  end

  if #display_tags == 0 then return end

  -- Calculate chip widths based on text
  local chip_h = M.CONFIG.tags.height
  local chips = {}
  local total_width = 0

  for _, tag in ipairs(display_tags) do
    local text_w, _ = ImGui.CalcTextSize(ctx, tag)
    local chip_w = text_w + M.CONFIG.tags.padding_x * 2
    table.insert(chips, {text = tag, width = chip_w})
    total_width = total_width + chip_w
  end
  total_width = total_width + (#chips - 1) * M.CONFIG.tags.gap

  -- Position at bottom of tile, above footer
  local footer_y = tile_y + tile_h - M.CONFIG.footer.height
  local y = footer_y - chip_h - M.CONFIG.tags.bottom_offset

  -- Calculate horizontal position (centered)
  local available_start = tile_x + M.CONFIG.tags.margin_x
  local available_end = tile_x + tile_w - M.CONFIG.tags.margin_x
  local available_width = available_end - available_start
  local x = available_start + math.floor((available_width - total_width) / 2)
  x = math.max(x, available_start)  -- Don't go past margin

  for _, chip in ipairs(chips) do
    -- Get tag color
    local bg_color = M.CONFIG.tags.colors[chip.text] or M.CONFIG.tags.colors.GLOBAL

    -- Check if chip fits
    if x + chip.width > available_end then
      break
    end

    -- Draw chip background
    Draw.rect_filled(dl, x, y, x + chip.width, y + chip_h, bg_color, M.CONFIG.tags.rounding)

    -- Draw text centered in chip
    Draw.centered_text(ctx, chip.text, x, y, x + chip.width, y + chip_h, M.CONFIG.tags.text_color)

    -- Move to next chip position
    x = x + chip.width + M.CONFIG.tags.gap
  end
end

function M.TileRenderer.checkbox(ctx, pkg, P, cb_rects, tile_x, tile_y, tile_w, tile_h, settings)
  local order_index = 0
  for i, pid in ipairs(pkg.order) do
    if pid == P.id then
      order_index = i
      break
    end
  end

  local badge = '#' .. tostring(order_index)
  local _, bh = ImGui.CalcTextSize(ctx, badge)
  local size = math.max(M.CONFIG.checkbox.min_size, math.floor(bh + 2))

  local x2 = tile_x + tile_w - M.CONFIG.checkbox.margin
  local y1 = tile_y + M.CONFIG.checkbox.margin
  local x1 = x2 - size
  local y2 = y1 + size

  cb_rects[P.id] = {x1, y1, x2, y2}

  ImGui.SetCursorScreenPos(ctx, x1, y1)
  ImGui.PushID(ctx, 'cb_' .. P.id)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, M.CONFIG.checkbox.padding_x, M.CONFIG.checkbox.padding_y)
  local clicked, checked = ImGui.Checkbox(ctx, '##enable', pkg.active[P.id] == true)
  if clicked then
    pkg.active[P.id] = checked
    if settings then settings:set('pkg_active', pkg.active) end
  end
  ImGui.PopStyleVar(ctx)
  ImGui.PopID(ctx)

  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, pkg.active[P.id] and "Disable package" or "Enable package")
  end
end

function M.TileRenderer.mosaic(ctx, dl, theme, P, tile_x, tile_y, tile_w, tile_h)
  if not theme or not theme.color_from_key then return end

  -- Begin frame for image cache
  M._package_image_cache:begin_frame()

  -- Check for preview.png first - display as single full-width image
  if P.meta and P.meta.preview_path then
    local preview_path = P.meta.preview_path
    local preview_drawn = false

    -- Use public API for validated access (auto-validates and recreates if needed)
    local rec = M._package_image_cache:get_validated(preview_path)

    if rec and rec.img then
      -- Calculate available area for preview (use most of tile height above footer)
      local preview_area_w = tile_w - M.CONFIG.mosaic.padding * 2
      local preview_area_h = tile_h - M.CONFIG.mosaic.y_offset - M.CONFIG.footer.height - M.CONFIG.mosaic.padding

      -- Fill mode: scale image to cover entire area (may crop)
      local img_w, img_h = rec.src_w, rec.src_h
      local aspect = img_w / img_h
      local area_aspect = preview_area_w / preview_area_h
      local draw_w, draw_h

      if aspect > area_aspect then
        -- Image wider than area - fit to height, crop width
        draw_h = preview_area_h
        draw_w = preview_area_h * aspect
      else
        -- Image taller than area - fit to width, crop height
        draw_w = preview_area_w
        draw_h = preview_area_w / aspect
      end

      -- Center the oversized image so it crops evenly
      local clip_x1 = tile_x + M.CONFIG.mosaic.padding
      local clip_y1 = tile_y + M.CONFIG.mosaic.y_offset
      local clip_x2 = clip_x1 + preview_area_w
      local clip_y2 = clip_y1 + preview_area_h

      local preview_x = clip_x1 - math.floor((draw_w - preview_area_w) / 2)
      local preview_y = clip_y1 - math.floor((draw_h - preview_area_h) / 2)

      -- Clip to exact bounds and draw
      ImGui.PushClipRect(ctx, clip_x1, clip_y1, clip_x2, clip_y2, true)
      ImGui.SetCursorScreenPos(ctx, preview_x, preview_y)
      local ok = pcall(ImGui.Image, ctx, rec.img, draw_w, draw_h)
      ImGui.PopClipRect(ctx)

      if ok then
        preview_drawn = true
        -- Draw border around clipped area
        Draw.rect(dl, clip_x1, clip_y1, clip_x2, clip_y2,
                  M.CONFIG.mosaic.border_color, M.CONFIG.mosaic.rounding, M.CONFIG.mosaic.border_thickness)
      end
    end

    -- If preview was drawn or attempted, don't show mosaic
    return
  end

  -- No preview.png, fall back to mosaic of actual number of images (1, 2, or 3)
  local preview_keys = P.meta and P.meta.mosaic or { P.keys_order[1], P.keys_order[2], P.keys_order[3] }
  -- Filter out nil values
  local valid_keys = {}
  for _, key in ipairs(preview_keys) do
    if key then
      table.insert(valid_keys, key)
    end
  end
  local num_images = math.min(M.CONFIG.mosaic.count, #valid_keys)

  if num_images == 0 then return end

  -- Calculate cell size with max constraint (but adapt to actual count for centering)
  local available_w = tile_w - M.CONFIG.mosaic.padding * 2
  local total_gap = (num_images - 1) * M.CONFIG.mosaic.gap
  local cell_size = math.min(
    M.CONFIG.mosaic.max_size,
    math.floor((available_w - total_gap) / num_images)
  )

  local total_width = cell_size * num_images + total_gap
  local mosaic_x = tile_x + math.floor((tile_w - total_width) / 2)
  local mosaic_y = tile_y + M.CONFIG.mosaic.y_offset
  for i = 1, num_images do
    local key = valid_keys[i]
    if key then
      local cx = mosaic_x + (i - 1) * (cell_size + M.CONFIG.mosaic.gap)
      local cy = mosaic_y

      -- Try to load and display actual image
      local asset = P.assets and P.assets[key]
      local img_path = asset and asset.path
      local img_drawn = false

      if img_path and not img_path:match("^%(mock%)") then
        -- Use public API for validated access (auto-validates and recreates if needed)
        local rec = M._package_image_cache:get_validated(img_path)

        if rec and rec.img then
          -- Calculate aspect-preserving dimensions
          local img_w, img_h = rec.src_w, rec.src_h
          local aspect = img_w / img_h
          local draw_w, draw_h

          if aspect > 1 then
            -- Wider than tall - fit to width
            draw_w = cell_size
            draw_h = cell_size / aspect
          else
            -- Taller than wide - fit to height
            draw_h = cell_size
            draw_w = cell_size * aspect
          end

          -- Center or clip if needed
          local img_x = cx + math.floor((cell_size - draw_w) / 2)
          local img_y = cy + math.floor((cell_size - draw_h) / 2)

          -- Clip to cell bounds
          ImGui.PushClipRect(ctx, cx, cy, cx + cell_size, cy + cell_size, true)
          ImGui.SetCursorScreenPos(ctx, img_x, img_y)
          local ok = pcall(ImGui.Image, ctx, rec.img, draw_w, draw_h)
          ImGui.PopClipRect(ctx)

          if ok then
            img_drawn = true
            -- Draw border around cell (not image)
            Draw.rect(dl, cx, cy, cx + cell_size, cy + cell_size,
                      M.CONFIG.mosaic.border_color, M.CONFIG.mosaic.rounding, M.CONFIG.mosaic.border_thickness)
          end
        end
      end

      -- Fallback to colored square if image didn't load
      if not img_drawn then
        local col = theme.color_from_key(key:gsub("%.%w+$", ""))
        Draw.rect_filled(dl, cx, cy, cx + cell_size, cy + cell_size, col, M.CONFIG.mosaic.rounding)
        Draw.rect(dl, cx, cy, cx + cell_size, cy + cell_size,
                  M.CONFIG.mosaic.border_color, M.CONFIG.mosaic.rounding, M.CONFIG.mosaic.border_thickness)

        local label = key:sub(1, 3):upper()
        Draw.centered_text(ctx, label, cx, cy, cx + cell_size, cy + cell_size, hexrgb("#FFFFFF"))
      end
    end
  end
end

function M.TileRenderer.footer(ctx, dl, pkg, P, tile_x, tile_y, tile_w, tile_h)
  local footer_y = tile_y + tile_h - M.CONFIG.footer.height
  Draw.rect_filled(dl, tile_x, footer_y, tile_x + tile_w, tile_y + tile_h, M.CONFIG.colors.footer.gradient, 0)
  
  local name = P.meta and P.meta.name or P.id
  local is_active = pkg.active[P.id] == true
  local name_color = is_active and M.CONFIG.colors.text.active or M.CONFIG.colors.text.inactive
  
  local count = 0
  for _ in pairs(P.assets or {}) do count = count + 1 end
  local count_text = string.format('%d assets', count)
  local count_w, _ = ImGui.CalcTextSize(ctx, count_text)
  
  local name_max_width = tile_w - (M.CONFIG.footer.padding_x * 3) - count_w
  local truncated_name = truncate_text(ctx, name, name_max_width)
  
  Draw.text(dl, tile_x + M.CONFIG.footer.padding_x, footer_y + 6, name_color, truncated_name)
  Draw.text_right(ctx, tile_x + tile_w - M.CONFIG.footer.padding_x, footer_y + 6, M.CONFIG.colors.text.secondary, count_text)
end

-- Clear image cache to avoid invalid image handle errors
-- Called when switching tabs or navigating between views
-- Pattern from debug_view.lua - works reliably for navigation events
function M.clear_image_cache()
  if M._package_image_cache then
    M._package_image_cache:clear()
  end
end

return M