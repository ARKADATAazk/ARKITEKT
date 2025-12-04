-- @noindex
-- Arkitekt/app/icon.lua
-- App icon drawing functions (DPI-aware vector graphics and PNG images)

local ImGui = require('arkitekt.core.imgui')

local M = {}

-- Cache for loaded images
local image_cache = {}

-- Find icons directory
local function find_icons_dir()
  local sep = package.config:sub(1,1)

  -- Try to find from package path
  for path in package.path:gmatch('[^;]+') do
    local dir = path:match('(.-)%?')
    if dir then
      local icons_path = dir .. 'arkitekt' .. sep .. 'assets' .. sep .. 'icons' .. sep
      local f = io.open(icons_path .. 'ARKITEKT.png', 'r')
      if f then
        f:close()
        return icons_path
      end
    end
  end

  -- Fallback: use script path (runtime/chrome/icon.lua -> arkitekt/assets/icons/)
  local info = debug.getinfo(1, 'S')
  if info and info.source then
    local src = info.source:match('@?(.+)')
    local this_dir = src:match('(.*'..sep..')') or ('.'..sep)
    -- Go up from runtime/chrome/ to runtime/
    local runtime_dir = this_dir:match('^(.*'..sep..')[^'..sep..']*'..sep..'$') or this_dir
    -- Go up from runtime/ to arkitekt/
    local arkitekt_dir = runtime_dir:match('^(.*'..sep..')[^'..sep..']*'..sep..'$') or runtime_dir
    -- Now add assets/icons/
    return arkitekt_dir .. 'assets' .. sep .. 'icons' .. sep
  end

  return nil
end

-- Load PNG image for icon (selects variant based on DPI)
function M.load_image(ctx, base_name, dpi_scale)
  if not ctx then return nil end

  dpi_scale = dpi_scale or 1.0
  -- Use stable cache key (ctx is always the same context, just use icon name + dpi)
  local cache_key = base_name .. '_' .. tostring(dpi_scale)

  -- Check if cached image exists and is still valid
  if image_cache[cache_key] then
    local cached = image_cache[cache_key]
    if cached.image and type(cached.image) == 'userdata' then
      -- Validate image pointer if ValidatePtr is available
      local validate_fn = ImGui.ValidatePtr
      if validate_fn then
        local is_valid = false
        local ok = pcall(function()
          is_valid = validate_fn(cached.image, 'ImGui_Image*')
        end)
        if ok and is_valid then
          return cached
        else
          -- Image pointer is invalid, clear from cache
          image_cache[cache_key] = nil
        end
      else
        -- No validation available, trust the cache
        return cached
      end
    else
      -- Not userdata anymore, clear from cache
      image_cache[cache_key] = nil
    end
  end

  local icons_dir = find_icons_dir()
  if not icons_dir then return nil end

  -- Select variant based on DPI scale
  local variant_map = {
    [16] = '@16x',
    [8] = '@8x',
    [4] = '@4x',
    [2] = '@2x',
    [1] = '',
  }

  -- Round DPI to nearest supported scale
  local scales = {16, 8, 4, 2, 1}
  local selected_scale = 1
  for _, scale in ipairs(scales) do
    if dpi_scale >= scale then
      selected_scale = scale
      break
    end
  end

  -- Try selected variant first, then fallback to others
  local try_order = {}
  local selected_suffix = variant_map[selected_scale]
  try_order[#try_order + 1] = selected_suffix

  -- Add fallbacks (prefer higher res over lower)
  for _, scale in ipairs(scales) do
    local suffix = variant_map[scale]
    if suffix ~= selected_suffix then
      try_order[#try_order + 1] = suffix
    end
  end

  local filename
  for _, suffix in ipairs(try_order) do
    local try_file = icons_dir .. base_name .. suffix .. '.png'
    local f = io.open(try_file, 'r')
    if f then
      f:close()
      filename = try_file
      break
    end
  end

  if not filename then return nil end

  -- Load image
  local image = ImGui.CreateImage(filename)
  if image then
    ImGui.Attach(ctx, image)
    image_cache[cache_key] = {
      image = image,
    }
    return image_cache[cache_key]
  end

  return nil
end

-- Draw PNG icon at native size (22×22 logical pixels)
-- tint: optional color tint (default: 0xFFFFFFFF white = full color)
function M.draw_png(ctx, x, y, size, image_data, tint)
  if not image_data or not image_data.image then return false end

  -- Validate image pointer before using it
  if type(image_data.image) ~= 'userdata' then return false end

  -- Use ValidatePtr if available (ImGui 0.9+)
  local validate_fn = ImGui.ValidatePtr
  if validate_fn then
    local is_valid = false
    local ok = pcall(function()
      is_valid = validate_fn(image_data.image, 'ImGui_Image*')
    end)
    if not ok or not is_valid then
      return false
    end
  end

  local draw_list = ImGui.GetWindowDrawList(ctx)

  -- Render at native 22×22 size (no DPI scaling - we use DPI-appropriate variants instead)
  local native_size = 22

  -- Draw the image with optional tint (default white = full color)
  ImGui.DrawList_AddImage(
    draw_list,
    image_data.image,
    x, y,
    x + native_size, y + native_size,
    0, 0, 1, 1,  -- UV coordinates
    tint or 0xFFFFFFFF
  )

  return true
end

-- Arkitekt logo v1: Original (smaller circles, simpler)
function M.draw_arkitekt(ctx, x, y, size, color)
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local dpi = ImGui.GetWindowDpiScale(ctx)
  
  -- Scale dimensions
  local s = size * dpi
  local half_s = s * 0.5
  local cx, cy = x + half_s, y + half_s
  
  -- Circle radius
  local r = s * 0.12
  
  -- Define positions (normalized to icon size)
  local top_x, top_y = cx, cy - s * 0.35
  local left_bot_x, left_bot_y = cx - s * 0.35, cy + s * 0.35
  local right_bot_x, right_bot_y = cx + s * 0.35, cy + s * 0.35
  local left_mid_x, left_mid_y = cx - s * 0.45, cy - s * 0.05
  local right_mid_x, right_mid_y = cx + s * 0.45, cy - s * 0.05
  
  -- Draw connecting lines (triangle 'A')
  local thickness = math.max(1.5 * dpi, 1.0)
  ImGui.DrawList_AddLine(draw_list, top_x, top_y, left_bot_x, left_bot_y, color, thickness)
  ImGui.DrawList_AddLine(draw_list, top_x, top_y, right_bot_x, right_bot_y, color, thickness)
  ImGui.DrawList_AddLine(draw_list, left_bot_x, left_bot_y, right_bot_x, right_bot_y, color, thickness)
  
  -- Draw circles at vertices and sides (audio node controls)
  ImGui.DrawList_AddCircleFilled(draw_list, top_x, top_y, r, color)
  ImGui.DrawList_AddCircleFilled(draw_list, left_bot_x, left_bot_y, r, color)
  ImGui.DrawList_AddCircleFilled(draw_list, right_bot_x, right_bot_y, r, color)
  ImGui.DrawList_AddCircleFilled(draw_list, left_mid_x, left_mid_y, r * 0.7, color)
  ImGui.DrawList_AddCircleFilled(draw_list, right_mid_x, right_mid_y, r * 0.7, color)
end

-- Arkitekt logo v2: Refined (larger bulbs, fader-style side controls)
function M.draw_arkitekt_v2(ctx, x, y, size, color)
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local dpi = ImGui.GetWindowDpiScale(ctx)
  
  local s = size * dpi
  local cx, cy = x + s * 0.5, y + s * 0.5
  
  -- Circle sizes
  local r_vertex = s * 0.20   -- Triangle vertex circles
  local r_side = s * 0.18     -- Side fader circles
  
  -- Triangle vertices (tighter triangle)
  local top_x, top_y = cx, cy - s * 0.28
  local left_bot_x, left_bot_y = cx - s * 0.28, cy + s * 0.32
  local right_bot_x, right_bot_y = cx + s * 0.28, cy + s * 0.32
  
  -- Draw thick triangle lines
  local thickness = math.max(3.0 * dpi, 2.5)
  ImGui.DrawList_AddLine(draw_list, top_x, top_y, left_bot_x, left_bot_y, color, thickness)
  ImGui.DrawList_AddLine(draw_list, top_x, top_y, right_bot_x, right_bot_y, color, thickness)
  ImGui.DrawList_AddLine(draw_list, left_bot_x, left_bot_y, right_bot_x, right_bot_y, color, thickness)
  
  -- Main circles at triangle vertices
  ImGui.DrawList_AddCircleFilled(draw_list, top_x, top_y, r_vertex, color)
  ImGui.DrawList_AddCircleFilled(draw_list, left_bot_x, left_bot_y, r_vertex, color)
  ImGui.DrawList_AddCircleFilled(draw_list, right_bot_x, right_bot_y, r_vertex, color)
  
  -- Side fader controls (outside triangle)
  local side_offset = s * 0.50
  local left_fader_x, left_fader_y = cx - side_offset, cy + s * 0.02
  local right_fader_x, right_fader_y = cx + side_offset, cy + s * 0.02
  
  ImGui.DrawList_AddCircleFilled(draw_list, left_fader_x, left_fader_y, r_side, color)
  ImGui.DrawList_AddCircleFilled(draw_list, right_fader_x, right_fader_y, r_side, color)
  
  -- Small squares above side faders
  local sq_size = s * 0.10
  local sq_y = cy - s * 0.25
  ImGui.DrawList_AddRectFilled(draw_list, 
    left_fader_x - sq_size/2, sq_y - sq_size/2,
    left_fader_x + sq_size/2, sq_y + sq_size/2,
    color, sq_size * 0.15)
  ImGui.DrawList_AddRectFilled(draw_list, 
    right_fader_x - sq_size/2, sq_y - sq_size/2,
    right_fader_x + sq_size/2, sq_y + sq_size/2,
    color, sq_size * 0.15)
  
  -- Center horizontal bar (crossfader)
  local bar_w = s * 0.18
  local bar_h = s * 0.08
  local bar_y = cy + s * 0.02
  ImGui.DrawList_AddRectFilled(draw_list,
    cx - bar_w/2, bar_y - bar_h/2,
    cx + bar_w/2, bar_y + bar_h/2,
    color, bar_h * 0.2)
end

-- Alternative: Simple 'A' monogram
function M.draw_simple_a(ctx, x, y, size, color)
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local dpi = ImGui.GetWindowDpiScale(ctx)
  
  local s = size * dpi
  local cx, cy = x + s * 0.5, y + s * 0.5
  
  -- Triangle 'A'
  local top_x, top_y = cx, cy - s * 0.4
  local left_x, left_y = cx - s * 0.35, cy + s * 0.4
  local right_x, right_y = cx + s * 0.35, cy + s * 0.4
  
  local thickness = math.max(2.0 * dpi, 1.5)
  ImGui.DrawList_AddLine(draw_list, top_x, top_y, left_x, left_y, color, thickness)
  ImGui.DrawList_AddLine(draw_list, top_x, top_y, right_x, right_y, color, thickness)
  
  -- Crossbar
  local bar_y = cy + s * 0.1
  ImGui.DrawList_AddLine(draw_list, cx - s * 0.25, bar_y, cx + s * 0.25, bar_y, color, thickness)
end

return M