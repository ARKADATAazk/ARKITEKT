-- @noindex
-- ReArkitekt/gui/widgets/package_tiles/renderer.lua
-- Package tile rendering module with text truncation support

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local Draw = require('rearkitekt.gui.draw')
local MarchingAnts = require('rearkitekt.gui.fx.interactions.marching_ants')
local Colors = require('rearkitekt.core.colors')
local ImageCache = require('rearkitekt.gui.images')

local M = {}
local hexrgb = Colors.hexrgb

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
    max_height = 200,
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

function M.TileRenderer.mosaic(ctx, dl, theme, P, tile_x, tile_y, tile_w)
  if not theme or not theme.color_from_key then return end

  -- Begin frame for image cache
  M._package_image_cache:begin_frame()

  -- Check for preview.png first - display as single full-width image
  if P.meta and P.meta.preview_path then
    local preview_path = P.meta.preview_path
    local preview_drawn = false

    -- Use image cache with validation
    local rec = M._package_image_cache._cache[preview_path]
    if rec then
      -- Validate the cached record
      local validate_record = function(cache, path, record)
        if not record or not record.img then return nil end
        if type(record.img) ~= "userdata" then
          cache._cache[path] = nil
          return nil
        end
        local ok, w, h = pcall(ImGui.Image_GetSize, record.img)
        if ok and w and h and w > 0 and h > 0 then
          record.w, record.h = w, h
          return record
        end
        cache._cache[path] = nil
        return nil
      end
      rec = validate_record(M._package_image_cache, preview_path, rec)
    end

    -- If not cached or invalid, try to load
    if not rec and M._package_image_cache._creates_left > 0 then
      local ok, img = pcall(ImGui.CreateImage, preview_path, ImGui.ImageFlags_NoErrors or 0)
      if ok and img then
        local w, h = pcall(ImGui.Image_GetSize, img)
        if w and h then
          rec = {
            img = img,
            w = w,
            h = h,
            src_x = 0,
            src_y = 0,
            src_w = w,
            src_h = h,
          }
          M._package_image_cache._cache[preview_path] = rec
          M._package_image_cache._creates_left = M._package_image_cache._creates_left - 1
        end
      end
    end

    if rec and rec.img then
      -- Calculate available area for preview (full tile width with padding)
      local preview_w = tile_w - M.CONFIG.mosaic.padding * 2
      local preview_h = M.CONFIG.mosaic.max_size * 1.5  -- Taller than mosaic cells

      -- Calculate aspect-preserving dimensions
      local img_w, img_h = rec.src_w, rec.src_h
      local aspect = img_w / img_h
      local draw_w, draw_h

      if aspect > preview_w / preview_h then
        -- Wider - fit to width
        draw_w = preview_w
        draw_h = preview_w / aspect
      else
        -- Taller - fit to height
        draw_h = preview_h
        draw_w = preview_h * aspect
      end

      -- Center the preview
      local preview_x = tile_x + math.floor((tile_w - draw_w) / 2)
      local preview_y = tile_y + M.CONFIG.mosaic.y_offset

      -- Clip to bounds
      local clip_x1 = tile_x + M.CONFIG.mosaic.padding
      local clip_y1 = preview_y
      local clip_x2 = tile_x + tile_w - M.CONFIG.mosaic.padding
      local clip_y2 = preview_y + preview_h

      ImGui.PushClipRect(ctx, clip_x1, clip_y1, clip_x2, clip_y2, true)
      ImGui.SetCursorScreenPos(ctx, preview_x, preview_y)
      local ok = pcall(ImGui.Image, ctx, rec.img, draw_w, draw_h)
      ImGui.PopClipRect(ctx)

      if ok then
        preview_drawn = true
        -- Draw border around preview area
        Draw.rect(dl, clip_x1, clip_y1, clip_x2, clip_y2,
                  M.CONFIG.mosaic.border_color, M.CONFIG.mosaic.rounding, M.CONFIG.mosaic.border_thickness)
      end
    end

    -- If preview was drawn or attempted, don't show mosaic
    return
  end

  -- No preview.png, fall back to mosaic of 3 images
  local cell_size = math.min(
    M.CONFIG.mosaic.max_size,
    math.floor((tile_w - M.CONFIG.mosaic.padding * 2 - (M.CONFIG.mosaic.count - 1) * M.CONFIG.mosaic.gap) / M.CONFIG.mosaic.count)
  )
  local total_width = cell_size * M.CONFIG.mosaic.count + (M.CONFIG.mosaic.count - 1) * M.CONFIG.mosaic.gap
  local mosaic_x = tile_x + math.floor((tile_w - total_width) / 2)
  local mosaic_y = tile_y + M.CONFIG.mosaic.y_offset

  local preview_keys = P.meta and P.meta.mosaic or { P.keys_order[1], P.keys_order[2], P.keys_order[3] }
  for i = 1, math.min(M.CONFIG.mosaic.count, #preview_keys) do
    local key = preview_keys[i]
    if key then
      local cx = mosaic_x + (i - 1) * (cell_size + M.CONFIG.mosaic.gap)
      local cy = mosaic_y

      -- Try to load and display actual image
      local asset = P.assets and P.assets[key]
      local img_path = asset and asset.path
      local img_drawn = false

      if img_path and not img_path:match("^%(mock%)") then
        -- Use image cache with validation
        local rec = M._package_image_cache._cache[img_path]
        if rec then
          -- Validate the cached record
          local validate_record = function(cache, path, record)
            if not record or not record.img then return nil end
            if type(record.img) ~= "userdata" then
              cache._cache[path] = nil
              return nil
            end
            local ok, w, h = pcall(ImGui.Image_GetSize, record.img)
            if ok and w and h and w > 0 and h > 0 then
              record.w, record.h = w, h
              return record
            end
            cache._cache[path] = nil
            return nil
          end
          rec = validate_record(M._package_image_cache, img_path, rec)
        end

        -- If not cached or invalid, try to load
        if not rec and M._package_image_cache._creates_left > 0 then
          local ok, img = pcall(ImGui.CreateImage, img_path, ImGui.ImageFlags_NoErrors or 0)
          if ok and img then
            local w, h = pcall(ImGui.Image_GetSize, img)
            if w and h then
              rec = {
                img = img,
                w = w,
                h = h,
                src_x = 0,
                src_y = 0,
                src_w = w,
                src_h = h,
              }
              M._package_image_cache._cache[img_path] = rec
              M._package_image_cache._creates_left = M._package_image_cache._creates_left - 1
            end
          end
        end

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

return M