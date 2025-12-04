-- @noindex
-- ThemeAdjuster/ui/image_tooltip.lua
-- Centralized image tooltip utility for consistent image preview behavior

local ImGui = require('arkitekt.core.imgui')
local Images = require('arkitekt.core.images')

local M = {}

-- Shared image cache instance (lazy initialized)
local _cache = nil

local function get_cache()
  if not _cache then
    _cache = Images.new({
      budget = 10,      -- Lower budget for tooltips
      max_cache = 50,   -- Reasonable cache size
      no_crop = true,   -- Show full image, not 3-state slice
    })
  end
  return _cache
end

-- Call this once per frame in your main render loop
function M.begin_frame()
  get_cache():begin_frame()
end

-- Configuration
local cfg = {
  max_preview_size = 200,   -- Maximum dimension for preview
  min_preview_size = 64,    -- Minimum dimension for preview
  padding = 8,              -- Padding inside tooltip
  bg_color = 0x1A1A1AFF,    -- Dark background
  border_color = 0x444444FF,-- Border
}

--- Show image tooltip if hovered
--- @param ctx userdata ImGui context
--- @param path string|nil Image file path
--- @param opts table|nil Options: { label, show_path, max_size }
--- @return boolean True if tooltip was shown
function M.show(ctx, path, opts)
  if not path or path == '' then return false end
  if not ImGui.IsItemHovered(ctx) then return false end

  opts = opts or {}
  local label = opts.label
  local show_path = opts.show_path ~= false  -- Default true
  local max_size = opts.max_size or cfg.max_preview_size

  local cache = get_cache()
  local rec = cache:get_validated(path)

  if ImGui.BeginTooltip(ctx) then
    -- Label at top
    if label and label ~= '' then
      ImGui.TextColored(ctx, 0xCCCCCCFF, label)
      ImGui.Separator(ctx)
      ImGui.Dummy(ctx, 0, 4)
    end

    -- Image preview
    if rec and rec.img then
      local src_w, src_h = rec.src_w, rec.src_h

      -- Calculate scaled size maintaining aspect ratio
      local scale = 1
      if src_w > max_size or src_h > max_size then
        scale = math.min(max_size / src_w, max_size / src_h)
      end
      if src_w * scale < cfg.min_preview_size and src_h * scale < cfg.min_preview_size then
        scale = math.max(cfg.min_preview_size / src_w, cfg.min_preview_size / src_h)
      end

      local draw_w = math.max(1, math.floor(src_w * scale))
      local draw_h = math.max(1, math.floor(src_h * scale))

      -- Draw with UV coordinates for proper source rect
      local u0 = rec.src_x / rec.w
      local v0 = rec.src_y / rec.h
      local u1 = (rec.src_x + rec.src_w) / rec.w
      local v1 = (rec.src_y + rec.src_h) / rec.h

      pcall(ImGui.Image, ctx, rec.img, draw_w, draw_h, u0, v0, u1, v1)

      -- Size info
      ImGui.Dummy(ctx, 0, 4)
      ImGui.TextColored(ctx, 0x888888FF, string.format('%dx%d', src_w, src_h))
    else
      -- Loading or failed
      ImGui.TextColored(ctx, 0x666666FF, '(loading...)')
      ImGui.Dummy(ctx, cfg.min_preview_size, cfg.min_preview_size)
    end

    -- Path at bottom (truncated)
    if show_path then
      ImGui.Dummy(ctx, 0, 4)
      local display_path = path
      if #display_path > 50 then
        display_path = '...' .. display_path:sub(-47)
      end
      ImGui.TextColored(ctx, 0x666666FF, display_path)
    end

    ImGui.EndTooltip(ctx)
  end

  return true
end

--- Show image tooltip for a specific screen rect (manual hover check)
--- @param ctx userdata ImGui context
--- @param path string|nil Image file path
--- @param rect table {x1, y1, x2, y2} Screen coordinates
--- @param opts table|nil Options: { label, show_path, max_size }
--- @return boolean True if tooltip was shown
function M.show_for_rect(ctx, path, rect, opts)
  if not path or path == '' then return false end

  local mx, my = ImGui.GetMousePos(ctx)
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]

  if mx < x1 or mx > x2 or my < y1 or my > y2 then
    return false
  end

  opts = opts or {}
  local label = opts.label
  local show_path = opts.show_path ~= false
  local max_size = opts.max_size or cfg.max_preview_size

  local cache = get_cache()
  local rec = cache:get_validated(path)

  if ImGui.BeginTooltip(ctx) then
    -- Label at top
    if label and label ~= '' then
      ImGui.TextColored(ctx, 0xCCCCCCFF, label)
      ImGui.Separator(ctx)
      ImGui.Dummy(ctx, 0, 4)
    end

    -- Image preview
    if rec and rec.img then
      local src_w, src_h = rec.src_w, rec.src_h

      local scale = 1
      if src_w > max_size or src_h > max_size then
        scale = math.min(max_size / src_w, max_size / src_h)
      end
      if src_w * scale < cfg.min_preview_size and src_h * scale < cfg.min_preview_size then
        scale = math.max(cfg.min_preview_size / src_w, cfg.min_preview_size / src_h)
      end

      local draw_w = math.max(1, math.floor(src_w * scale))
      local draw_h = math.max(1, math.floor(src_h * scale))

      local u0 = rec.src_x / rec.w
      local v0 = rec.src_y / rec.h
      local u1 = (rec.src_x + rec.src_w) / rec.w
      local v1 = (rec.src_y + rec.src_h) / rec.h

      pcall(ImGui.Image, ctx, rec.img, draw_w, draw_h, u0, v0, u1, v1)

      ImGui.Dummy(ctx, 0, 4)
      ImGui.TextColored(ctx, 0x888888FF, string.format('%dx%d', src_w, src_h))
    else
      ImGui.TextColored(ctx, 0x666666FF, '(loading...)')
      ImGui.Dummy(ctx, cfg.min_preview_size, cfg.min_preview_size)
    end

    if show_path then
      ImGui.Dummy(ctx, 0, 4)
      local display_path = path
      if #display_path > 50 then
        display_path = '...' .. display_path:sub(-47)
      end
      ImGui.TextColored(ctx, 0x666666FF, display_path)
    end

    ImGui.EndTooltip(ctx)
  end

  return true
end

--- Get the shared image cache (for advanced use)
--- @return table ImageCache instance
function M.get_cache()
  return get_cache()
end

return M
