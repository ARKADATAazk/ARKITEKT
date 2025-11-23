-- @noindex
-- ReArkitekt/gui/widgets/tiles_container/background.lua
-- Background pattern rendering with optional texture baking for performance

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local M = {}

-- Texture cache for baked patterns
local texture_cache = {}
local cache_order = {}  -- Track insertion order for LRU eviction
local MAX_CACHE_SIZE = 32  -- Limit to prevent attachment overflow

-- ============================================================================
-- TEXTURE BAKING: Create tileable pattern textures for performance
-- ============================================================================

-- Normalize color to reduce cache variations (round to nearest 16 for each channel)
local function normalize_color(color)
  local r = (color >> 24) & 0xFF
  local g = (color >> 16) & 0xFF
  local b = (color >> 8) & 0xFF
  local a = color & 0xFF
  -- Round to nearest 16 to reduce unique combinations
  r = math.floor(r / 16 + 0.5) * 16
  g = math.floor(g / 16 + 0.5) * 16
  b = math.floor(b / 16 + 0.5) * 16
  a = math.floor(a / 16 + 0.5) * 16
  -- Clamp to 255
  r = math.min(255, r)
  g = math.min(255, g)
  b = math.min(255, b)
  a = math.min(255, a)
  return (r << 24) | (g << 16) | (b << 8) | a
end

-- Generate a unique cache key for a pattern configuration
local function get_pattern_cache_key(pattern_type, spacing, size, color)
  -- Normalize color first to reduce variations
  local norm_color = normalize_color(color)
  local r = (norm_color >> 24) & 0xFF
  local g = (norm_color >> 16) & 0xFF
  local b = (norm_color >> 8) & 0xFF
  local a = norm_color & 0xFF
  return string.format("%s_%d_%.1f_%d_%d_%d_%d", pattern_type, spacing, size, r, g, b, a), norm_color
end

-- Evict oldest cache entry
local function evict_oldest()
  if #cache_order > 0 then
    local oldest_key = table.remove(cache_order, 1)
    texture_cache[oldest_key] = nil
  end
end

-- Create a baked dot pattern texture
local function create_dot_texture(spacing, dot_size, color)
  -- Texture size matches spacing for perfect tiling
  local tex_size = spacing

  -- Check if CreateImageFromSize is available (ImGui 0.10+)
  if not ImGui.CreateImageFromSize then
    return nil
  end

  -- Create blank texture
  local img = ImGui.CreateImageFromSize(tex_size, tex_size)
  if not img then return nil end

  -- Create pixel array (RGBA format, 4 bytes per pixel)
  local pixels = reaper.new_array(tex_size * tex_size)

  -- Extract color components (color is 0xRRGGBBAA)
  local r = (color >> 24) & 0xFF
  local g = (color >> 16) & 0xFF
  local b = (color >> 8) & 0xFF
  local a = color & 0xFF

  -- Pack as 0xRRGGBBAA (native RGBA format)
  local dot_pixel = r * 0x1000000 + g * 0x10000 + b * 0x100 + a
  local clear_pixel = 0x00000000

  -- Fill with transparent, then draw dots
  for i = 1, tex_size * tex_size do
    pixels[i] = clear_pixel
  end

  -- Draw dot in center of texture (it will tile)
  local half_size = dot_size * 0.5
  local center_x = tex_size / 2
  local center_y = tex_size / 2

  -- Simple circle rasterization
  for py = 0, tex_size - 1 do
    for px = 0, tex_size - 1 do
      local dx = px - center_x + 0.5
      local dy = py - center_y + 0.5
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist <= half_size then
        local idx = py * tex_size + px + 1
        pixels[idx] = dot_pixel
      end
    end
  end

  -- Upload pixels to texture
  ImGui.Image_SetPixels_Array(img, 0, 0, tex_size, tex_size, pixels)

  return img, tex_size
end

-- Create a baked grid pattern texture
local function create_grid_texture(spacing, line_thickness, color)
  -- Texture size matches spacing for perfect tiling
  local tex_size = spacing

  -- Check if CreateImageFromSize is available (ImGui 0.10+)
  if not ImGui.CreateImageFromSize then
    return nil
  end

  -- Create blank texture
  local img = ImGui.CreateImageFromSize(tex_size, tex_size)
  if not img then return nil end

  -- Create pixel array
  local pixels = reaper.new_array(tex_size * tex_size)

  -- Extract color components (color is 0xRRGGBBAA)
  local r = (color >> 24) & 0xFF
  local g = (color >> 16) & 0xFF
  local b = (color >> 8) & 0xFF
  local a = color & 0xFF

  -- Pack as 0xRRGGBBAA (native RGBA format)
  local line_pixel = r * 0x1000000 + g * 0x10000 + b * 0x100 + a
  local clear_pixel = 0x00000000

  -- Fill with transparent
  for i = 1, tex_size * tex_size do
    pixels[i] = clear_pixel
  end

  -- Draw grid lines at edges (they connect when tiled)
  local thickness = math.max(1, math.floor(line_thickness))

  -- Horizontal line at top (y=0)
  for py = 0, thickness - 1 do
    for px = 0, tex_size - 1 do
      local idx = py * tex_size + px + 1
      pixels[idx] = line_pixel
    end
  end

  -- Vertical line at left (x=0)
  for py = 0, tex_size - 1 do
    for px = 0, thickness - 1 do
      local idx = py * tex_size + px + 1
      pixels[idx] = line_pixel
    end
  end

  -- Upload pixels to texture
  ImGui.Image_SetPixels_Array(img, 0, 0, tex_size, tex_size, pixels)

  return img, tex_size
end

-- Create a baked diagonal stripe pattern texture (45-degree lines)
local function create_diagonal_stripe_texture(spacing, line_thickness, color)
  -- Texture size matches spacing for perfect tiling
  local tex_size = spacing

  -- Check if CreateImageFromSize is available (ImGui 0.10+)
  if not ImGui.CreateImageFromSize then
    return nil
  end

  -- Create blank texture
  local img = ImGui.CreateImageFromSize(tex_size, tex_size)
  if not img then return nil end

  -- Create pixel array
  local pixels = reaper.new_array(tex_size * tex_size)

  -- Extract color components (color is 0xRRGGBBAA)
  local r = (color >> 24) & 0xFF
  local g = (color >> 16) & 0xFF
  local b = (color >> 8) & 0xFF
  local a = color & 0xFF

  -- Pack as 0xRRGGBBAA (native RGBA format)
  local line_pixel = r * 0x1000000 + g * 0x10000 + b * 0x100 + a
  local clear_pixel = 0x00000000

  -- Fill with transparent
  for i = 1, tex_size * tex_size do
    pixels[i] = clear_pixel
  end

  -- Draw diagonal line from top-left to bottom-right
  -- For tiling, we draw lines that wrap around
  local half_thick = line_thickness * 0.5

  for py = 0, tex_size - 1 do
    for px = 0, tex_size - 1 do
      -- Distance from the diagonal line y = x (in tile coordinates)
      -- For a 45-degree line, distance = |x - y| / sqrt(2)
      local dist = math.abs(px - py) / 1.414

      -- Also check wrapped diagonal (for seamless tiling)
      local wrapped_dist = math.abs(px - py + tex_size) / 1.414
      local wrapped_dist2 = math.abs(px - py - tex_size) / 1.414

      local min_dist = math.min(dist, wrapped_dist, wrapped_dist2)

      if min_dist <= half_thick then
        local idx = py * tex_size + px + 1
        pixels[idx] = line_pixel
      end
    end
  end

  -- Upload pixels to texture
  ImGui.Image_SetPixels_Array(img, 0, 0, tex_size, tex_size, pixels)

  return img, tex_size
end

-- Get or create a cached pattern texture
local function get_pattern_texture(ctx, pattern_type, spacing, size, color)
  local key, norm_color = get_pattern_cache_key(pattern_type, spacing, size, color)

  if texture_cache[key] then
    local cached = texture_cache[key]
    -- Validate the texture is still valid
    if ImGui.ValidatePtr and ImGui.ValidatePtr(cached.img, 'ImGui_Image*') then
      -- Move to end of cache_order for LRU
      for i, k in ipairs(cache_order) do
        if k == key then
          table.remove(cache_order, i)
          break
        end
      end
      table.insert(cache_order, key)
      return cached.img, cached.size
    else
      -- Invalid, remove from cache and cache_order
      texture_cache[key] = nil
      for i, k in ipairs(cache_order) do
        if k == key then
          table.remove(cache_order, i)
          break
        end
      end
    end
  end

  -- Evict if cache is full
  while #cache_order >= MAX_CACHE_SIZE do
    evict_oldest()
  end

  -- Create new texture using normalized color
  local img, tex_size
  if pattern_type == 'dots' then
    img, tex_size = create_dot_texture(spacing, size, norm_color)
  elseif pattern_type == 'grid' then
    img, tex_size = create_grid_texture(spacing, size, norm_color)
  elseif pattern_type == 'diagonal_stripes' then
    img, tex_size = create_diagonal_stripe_texture(spacing, size, norm_color)
  end

  if img then
    -- Attach to context to prevent garbage collection
    if ctx and ImGui.Attach then
      ImGui.Attach(ctx, img)
    end
    texture_cache[key] = { img = img, size = tex_size }
    table.insert(cache_order, key)
  end

  return img, tex_size
end

-- Draw tiled texture pattern
local function draw_tiled_texture(dl, x1, y1, x2, y2, img, tex_size, color, offset_x, offset_y)
  offset_x = offset_x or 0
  offset_y = offset_y or 0

  local width = x2 - x1
  local height = y2 - y1

  -- Calculate UV coordinates for tiling
  -- UV beyond 0-1 will tile the texture
  local u_offset = (offset_x % tex_size) / tex_size
  local v_offset = (offset_y % tex_size) / tex_size
  local u_scale = width / tex_size
  local v_scale = height / tex_size

  -- Draw the image tiled
  -- Note: We use white color (0xFFFFFFFF) to preserve texture colors
  ImGui.DrawList_AddImage(dl, img, x1, y1, x2, y2,
    u_offset, v_offset,
    u_offset + u_scale, v_offset + v_scale,
    0xFFFFFFFF)
end

-- ============================================================================
-- LEGACY: Immediate mode pattern drawing (fallback)
-- ============================================================================

local function draw_grid_pattern(dl, x1, y1, x2, y2, spacing, color, thickness, offset_x, offset_y)
  offset_x = offset_x or 0
  offset_y = offset_y or 0

  -- Calculate the starting position by finding the first line that would be visible
  -- We need to account for the offset and wrap it within the spacing
  local start_x = x1 - ((x1 - offset_x) % spacing)
  local start_y = y1 - ((y1 - offset_y) % spacing)

  -- Draw vertical lines
  local x = start_x
  while x <= x2 do
    ImGui.DrawList_AddLine(dl, x, y1, x, y2, color, thickness)
    x = x + spacing
  end

  -- Draw horizontal lines
  local y = start_y
  while y <= y2 do
    ImGui.DrawList_AddLine(dl, x1, y, x2, y, color, thickness)
    y = y + spacing
  end
end

local function draw_dot_pattern(dl, x1, y1, x2, y2, spacing, color, dot_size, offset_x, offset_y)
  offset_x = offset_x or 0
  offset_y = offset_y or 0

  local half_size = dot_size * 0.5

  -- Calculate the starting position using modulo to wrap within spacing
  local start_x = x1 - ((x1 - offset_x) % spacing)
  local start_y = y1 - ((y1 - offset_y) % spacing)

  -- Draw dots
  local x = start_x
  while x <= x2 do
    local y = start_y
    while y <= y2 do
      ImGui.DrawList_AddCircleFilled(dl, x, y, half_size, color)
      y = y + spacing
    end
    x = x + spacing
  end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

-- Helper to draw dots with automatic texture baking
local function draw_dots_auto(ctx, dl, x1, y1, x2, y2, spacing, color, dot_size, offset_x, offset_y, use_texture)
  -- Default to using textures for performance (set use_texture=false to disable)
  if use_texture ~= false then
    local img, tex_size = get_pattern_texture(ctx, 'dots', spacing, dot_size, color)
    if img then
      draw_tiled_texture(dl, x1, y1, x2, y2, img, tex_size, color, offset_x, offset_y)
      return
    end
  end
  -- Fallback to immediate mode
  draw_dot_pattern(dl, x1, y1, x2, y2, spacing, color, dot_size, offset_x, offset_y)
end

-- Helper to draw grid with automatic texture baking
local function draw_grid_auto(ctx, dl, x1, y1, x2, y2, spacing, color, line_thickness, offset_x, offset_y, use_texture)
  -- Default to using textures for performance (set use_texture=false to disable)
  if use_texture ~= false then
    local img, tex_size = get_pattern_texture(ctx, 'grid', spacing, line_thickness, color)
    if img then
      draw_tiled_texture(dl, x1, y1, x2, y2, img, tex_size, color, offset_x, offset_y)
      return
    end
  end
  -- Fallback to immediate mode
  draw_grid_pattern(dl, x1, y1, x2, y2, spacing, color, line_thickness, offset_x, offset_y)
end

-- Fallback immediate mode diagonal stripe drawing
local function draw_diagonal_stripe_pattern(dl, x1, y1, x2, y2, spacing, color, thickness)
  local width = x2 - x1
  local height = y2 - y1
  local start_offset = -height
  local end_offset = width

  for offset = start_offset, end_offset, spacing do
    local line_x1 = x1 + offset
    local line_y1 = y1
    local line_x2 = x1 + offset + height
    local line_y2 = y2
    ImGui.DrawList_AddLine(dl, line_x1, line_y1, line_x2, line_y2, color, thickness)
  end
end

-- Public API: Draw diagonal stripes with automatic texture baking
-- This is a high-performance replacement for line-by-line stripe drawing
function M.draw_diagonal_stripes(ctx, dl, x1, y1, x2, y2, spacing, color, thickness, use_texture)
  ImGui.DrawList_PushClipRect(dl, x1, y1, x2, y2, true)

  -- Default to using textures for performance
  if use_texture ~= false then
    local img, tex_size = get_pattern_texture(ctx, 'diagonal_stripes', spacing, thickness, color)
    if img then
      draw_tiled_texture(dl, x1, y1, x2, y2, img, tex_size, color, 0, 0)
      ImGui.DrawList_PopClipRect(dl)
      return
    end
  end

  -- Fallback to immediate mode
  draw_diagonal_stripe_pattern(dl, x1, y1, x2, y2, spacing, color, thickness)
  ImGui.DrawList_PopClipRect(dl)
end

-- Draw pattern with automatic texture baking for dot patterns
-- Set pattern_cfg.use_texture = false to disable texture baking
function M.draw(ctx, dl, x1, y1, x2, y2, pattern_cfg)
  if not pattern_cfg or not pattern_cfg.enabled then return end

  ImGui.DrawList_PushClipRect(dl, x1, y1, x2, y2, true)

  if pattern_cfg.secondary and pattern_cfg.secondary.enabled then
    local sec = pattern_cfg.secondary
    if sec.type == 'grid' then
      draw_grid_auto(ctx, dl, x1, y1, x2, y2, sec.spacing, sec.color, sec.line_thickness, sec.offset_x, sec.offset_y, pattern_cfg.use_texture)
    elseif sec.type == 'dots' then
      draw_dots_auto(ctx, dl, x1, y1, x2, y2, sec.spacing, sec.color, sec.dot_size, sec.offset_x, sec.offset_y, pattern_cfg.use_texture)
    end
  end

  if pattern_cfg.primary then
    local pri = pattern_cfg.primary
    if pri.type == 'grid' then
      draw_grid_auto(ctx, dl, x1, y1, x2, y2, pri.spacing, pri.color, pri.line_thickness, pri.offset_x, pri.offset_y, pattern_cfg.use_texture)
    elseif pri.type == 'dots' then
      draw_dots_auto(ctx, dl, x1, y1, x2, y2, pri.spacing, pri.color, pri.dot_size, pri.offset_x, pri.offset_y, pattern_cfg.use_texture)
    end
  end

  ImGui.DrawList_PopClipRect(dl)
end

-- Clear cached textures (call on shutdown or when patterns change)
function M.clear_cache()
  for key, cached in pairs(texture_cache) do
    if cached.img and ImGui.ValidatePtr and ImGui.ValidatePtr(cached.img, 'ImGui_Image*') then
      -- Note: ImGui handles cleanup automatically, but we clear our references
    end
  end
  texture_cache = {}
  cache_order = {}
end

return M
