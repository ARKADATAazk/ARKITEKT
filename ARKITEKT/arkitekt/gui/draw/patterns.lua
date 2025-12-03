-- @noindex
-- Arkitekt/gui/draw/pattern.lua
-- Generic pattern rendering with optional texture baking for performance
-- Supports dots, grid lines, and diagonal stripes with automatic texture caching

local ImGui = require('arkitekt.core.imgui')

local M = {}

-- Texture cache for baked patterns
local texture_cache = {}
local total_attachments = 0  -- Track total attachments (never decreases)
local MAX_ATTACHMENTS = 64  -- Hard limit on total textures ever created

-- NOTE: ReaImGui DrawList functions expect colors in 0xRRGGBBAA format
-- This matches hexrgb() output - no conversion needed!

-- ============================================================================
-- TEXTURE BAKING: Create tileable pattern textures for performance
-- ============================================================================

-- Generate a unique cache key for a pattern configuration
-- NOTE: Color is NOT part of the key - we use white textures and apply color as tint
local function get_pattern_cache_key(pattern_type, spacing, size)
  return string.format('%s_%d_%.1f', pattern_type, spacing, size)
end


-- Create a WHITE dot pattern texture (color applied as tint when drawing)
local function create_dot_texture(spacing, dot_size)
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

  -- White pixel for pattern, transparent for background
  -- Color will be applied as tint when drawing
  local white_pixel = 0xFFFFFFFF
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
        pixels[idx] = white_pixel
      end
    end
  end

  -- Upload pixels to texture
  ImGui.Image_SetPixels_Array(img, 0, 0, tex_size, tex_size, pixels)

  return img, tex_size
end

-- Create a WHITE grid pattern texture (color applied as tint when drawing)
local function create_grid_texture(spacing, line_thickness)
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

  -- White pixel for pattern, transparent for background
  -- Color will be applied as tint when drawing
  local white_pixel = 0xFFFFFFFF
  local clear_pixel = 0x00000000

  -- Fill with transparent
  for i = 1, tex_size * tex_size do
    pixels[i] = clear_pixel
  end

  -- Draw grid lines at edges (they connect when tiled)
  local thickness = math.max(1, line_thickness // 1)

  -- Horizontal line at top (y=0)
  for py = 0, thickness - 1 do
    for px = 0, tex_size - 1 do
      local idx = py * tex_size + px + 1
      pixels[idx] = white_pixel
    end
  end

  -- Vertical line at left (x=0)
  for py = 0, tex_size - 1 do
    for px = 0, thickness - 1 do
      local idx = py * tex_size + px + 1
      pixels[idx] = white_pixel
    end
  end

  -- Upload pixels to texture
  ImGui.Image_SetPixels_Array(img, 0, 0, tex_size, tex_size, pixels)

  return img, tex_size
end

-- Create a WHITE diagonal stripe pattern texture (color applied as tint when drawing)
local function create_diagonal_stripe_texture(spacing, line_thickness)
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

  -- White pixel for pattern, transparent for background
  -- Color will be applied as tint when drawing
  local white_pixel = 0xFFFFFFFF
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
        pixels[idx] = white_pixel
      end
    end
  end

  -- Upload pixels to texture
  ImGui.Image_SetPixels_Array(img, 0, 0, tex_size, tex_size, pixels)

  return img, tex_size
end

-- Get or create a cached pattern texture (WHITE texture, color applied as tint)
local function get_pattern_texture(ctx, pattern_type, spacing, size)
  local key = get_pattern_cache_key(pattern_type, spacing, size)

  -- Check cache first
  if texture_cache[key] then
    local cached = texture_cache[key]
    -- Validate the texture is still valid
    if ImGui.ValidatePtr and ImGui.ValidatePtr(cached.img, 'ImGui_Image*') then
      return cached.img, cached.size
    else
      -- Invalid, remove from cache (but attachment count stays)
      texture_cache[key] = nil
    end
  end

  -- Don't create new textures if we've hit the limit - fall back to immediate mode
  if total_attachments >= MAX_ATTACHMENTS then
    return nil, nil
  end

  -- Create new WHITE texture (color will be applied as tint when drawing)
  local img, tex_size
  if pattern_type == 'dots' then
    img, tex_size = create_dot_texture(spacing, size)
  elseif pattern_type == 'grid' then
    img, tex_size = create_grid_texture(spacing, size)
  elseif pattern_type == 'diagonal_stripes' then
    img, tex_size = create_diagonal_stripe_texture(spacing, size)
  end

  if img then
    -- Attach to context to prevent garbage collection
    if ctx and ImGui.Attach then
      ImGui.Attach(ctx, img)
      total_attachments = total_attachments + 1
    end
    texture_cache[key] = { img = img, size = tex_size }
  end

  return img, tex_size
end

-- Draw tiled texture pattern with color tint
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

  -- Draw the image tiled with color tint (color is already in 0xRRGGBBAA format)
  -- White texture pixels become the tint color, transparent stays transparent
  ImGui.DrawList_AddImage(dl, img, x1, y1, x2, y2,
    u_offset, v_offset,
    u_offset + u_scale, v_offset + v_scale,
    color)
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

  -- Draw vertical lines (color is already in 0xRRGGBBAA format)
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

  -- Draw dots (color is already in 0xRRGGBBAA format)
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
    local img, tex_size = get_pattern_texture(ctx, 'dots', spacing, dot_size)
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
    local img, tex_size = get_pattern_texture(ctx, 'grid', spacing, line_thickness)
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

  -- Draw diagonal stripes (color is already in 0xRRGGBBAA format)
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
    local img, tex_size = get_pattern_texture(ctx, 'diagonal_stripes', spacing, thickness)
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
function M.Draw(ctx, dl, x1, y1, x2, y2, pattern_cfg)
  if not pattern_cfg or not pattern_cfg.enabled then
    return
  end

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
-- Note: This clears our cache but ImGui attachments persist until context is destroyed
function M.clear_cache()
  texture_cache = {}
  -- Don't reset total_attachments - those ImGui attachments still exist
end

return M
