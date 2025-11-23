-- @noindex
-- Arkitekt/core/images.lua
-- Enterprise-grade image cache with automatic handle validation and lifecycle management
--
-- USAGE GUIDELINES:
-- ================================================================================
--
-- BASIC SETUP:
--   local ImageCache = require('arkitekt.core.images')
--   local cache = ImageCache.new({
--     budget = 20,      -- Max images to load per frame (prevents UI freeze)
--     max_cache = 100,  -- Max total cached images (LRU eviction)
--     no_crop = true,   -- Set true to disable 3-state image slicing
--   })
--
-- FRAME-BASED RENDERING:
--   function MyView:draw(ctx)
--     cache:begin_frame()  -- REQUIRED: Call once per frame before drawing
--
--     -- Draw images...
--     cache:draw_thumb(ctx, image_path, 64)
--     cache:draw_original(ctx, image_path)
--     cache:draw_fit(ctx, image_path, 100, 100)
--   end
--
-- ADVANCED: Direct Record Access (when you need custom rendering)
--   local rec = cache:get_validated(path)  -- Returns validated record or nil
--   if rec and rec.img then
--     -- rec = { img, w, h, src_x, src_y, src_w, src_h }
--     ImGui.Image(ctx, rec.img, w, h)
--   end
--
-- LIFECYCLE MANAGEMENT:
--   - Handles are automatically validated on every access
--   - Invalid handles are detected via pcall(Image_GetSize)
--   - Stale handles are auto-recovered by recreating the image
--   - LRU eviction keeps memory usage bounded
--   - No manual cache:clear() needed on tab switches!
--
-- ERROR HANDLING:
--   - All ImGui calls are pcall-wrapped for safety
--   - Failed images are marked as 'false' to avoid retry spam
--   - Graceful fallback to Dummy widgets on errors
--
-- PERFORMANCE:
--   - Frame budget prevents UI stutter from bulk loading
--   - Validation is lazy (only on access)
--   - LRU eviction prevents unbounded memory growth
--   - Reference counting could be added for advanced use cases
--
-- ================================================================================

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local M = {}

local metadata = nil

local function load_metadata()
  if metadata then return metadata end
  
  local SEP = package.config:sub(1,1)
  local src = debug.getinfo(1,'S').source:sub(2)
  local dir = src:match("(.*"..SEP..")") or ("."..SEP)
  local meta_path = dir:gsub("core"..SEP.."$", "") .. "reaper_img_metadata.json"
  
  local file = io.open(meta_path, "r")
  if not file then
    metadata = { images = {} }
    return metadata
  end
  
  local content = file:read("*a")
  file:close()
  
  local json_ok, json = pcall(require, 'json')
  if json_ok and json and json.decode then
    local result = json.decode(content)
    if result and result.images then
      metadata = result
      return metadata
    end
  end
  
  metadata = { images = {} }
  local images_start = content:match('"images"%s*:%s*{')
  if images_start then
    local start_pos = content:find('"images"%s*:%s*{')
    if start_pos then
      local images_content = content:sub(start_pos)
      for img_name, is_3state_str in images_content:gmatch('"([^"]+)"%s*:%s*{[^}]*"is_3state"%s*:%s*(%a+)') do
        if img_name ~= "_comment" then
          metadata.images[img_name] = { is_3state = (is_3state_str == "true") }
        end
      end
    end
  end
  
  return metadata
end

local function img_flags_noerr()
  -- In ImGui 0.10, flags are values not functions
  return ImGui.ImageFlags_NoErrors or 0
end

local function create_image(path)
  local ok, img = pcall(ImGui.CreateImage, path, img_flags_noerr())
  if ok and img then return img end
  return nil
end

local function destroy_image(img)
  if not img then return end
  -- Safely check if destroy function exists without triggering nil access error
  -- Use rawget to avoid accessing potentially nil fields
  local destroy_fn = rawget(ImGui, 'Image_Destroy') or rawget(ImGui, 'DestroyImage')
  if destroy_fn then
    pcall(destroy_fn, img)
  end
end

local function image_size(img)
  local ok, w, h = pcall(ImGui.Image_GetSize, img)
  if ok and w and h then return w, h end
  return nil, nil
end

-- Helper to remove a path from cache order (LRU tracking)
local function remove_from_cache_order(self, path)
  for i, p in ipairs(self._cache_order) do
    if p == path then
      table.remove(self._cache_order, i)
      break
    end
  end
end

local function get_image_name(path)
  if not path then return nil end
  local name = path:match("[^\\/]+$") or path
  return name:gsub("%.png$", ""):gsub("%.PNG$", "")
end

local function is_three_state_from_metadata(path)
  local meta = load_metadata()
  local name = get_image_name(path)
  if not name then return false end
  local img_meta = meta.images[name]
  return img_meta and img_meta.is_3state == true
end

local Cache = {}
Cache.__index = Cache

function M.new(opts)
  opts = opts or {}
  local self = setmetatable({
    _cache        = {},
    _cache_order  = {},  -- Track insertion order for LRU
    _creates_left = 0,
    _budget       = math.max(0, tonumber(opts.budget or 48)),
    _max_cache    = tonumber(opts.max_cache or 200),  -- Max cached images
    _no_crop      = opts.no_crop == true,
  }, Cache)
  return self
end

function Cache:begin_frame()
  self._creates_left = self._budget
end

-- Evict oldest cached images if over limit
function Cache:evict_if_needed()
  while #self._cache_order > self._max_cache do
    local oldest_path = table.remove(self._cache_order, 1)
    local rec = self._cache[oldest_path]
    if rec and rec.img then
      destroy_image(rec.img)
    end
    self._cache[oldest_path] = nil
  end
end

function Cache:clear()
  for _, rec in pairs(self._cache) do
    if rec and rec.img then destroy_image(rec.img) end
  end
  self._cache = {}
  self._cache_order = {}
  collectgarbage('collect')
end

function Cache:unload(path)
  local rec = self._cache[path]
  if rec and rec.img then destroy_image(rec.img) end
  self._cache[path] = nil
  remove_from_cache_order(self, path)
end

function Cache:set_no_crop(b)
  self._no_crop = not not b
  -- We keep existing records; drawing uses stored src rects.
  -- If you want to refresh to full frames immediately, call :clear() after toggling.
end

local function ensure_record(self, path)
  if not path or path == "" then return nil end

  local rec = self._cache[path]
  if rec == false then return nil end
  if rec and rec.img then return rec end

  if self._creates_left <= 0 then return nil end

  local img = create_image(path)
  if not img then
    self._cache[path] = false
    return nil
  end

  local w, h = image_size(img)
  if not w then
    destroy_image(img)
    self._cache[path] = false
    return nil
  end

  -- Decide source rectangle once on creation
  local src_x, src_y, src_w, src_h
  if self._no_crop then
    -- Show the whole texture (no slicing)
    src_x, src_y, src_w, src_h = 0, 0, w, h
  else
    if is_three_state_from_metadata(path) and w > 0 then
      local frame_w = math.floor(w / 3)
      src_x, src_y, src_w, src_h = 0, 0, frame_w, h
    else
      src_x, src_y, src_w, src_h = 0, 0, w, h
    end
  end
  
  rec = {
    img = img,
    w = w,
    h = h,
    src_x = src_x,
    src_y = src_y,
    src_w = src_w,
    src_h = src_h
  }
  self._cache[path] = rec
  self._creates_left = self._creates_left - 1

  -- Track in LRU order
  table.insert(self._cache_order, path)
  self:evict_if_needed()

  return rec
end

local function validate_record(self, path, rec)
  if not rec or not rec.img then
    return ensure_record(self, path)
  end

  -- Check if userdata is still valid type
  if type(rec.img) ~= "userdata" then
    self._cache[path] = nil
    remove_from_cache_order(self, path)
    return ensure_record(self, path)
  end

  -- First try ValidatePtr if available (ImGui 0.9+)
  local validate_fn = ImGui.ValidatePtr
  if validate_fn then
    local is_valid = false
    local ok = pcall(function()
      is_valid = validate_fn(rec.img, 'ImGui_Image*')
    end)
    if not ok or not is_valid then
      -- Image pointer is invalid, destroy old handle and recreate
      destroy_image(rec.img)
      self._cache[path] = nil
      remove_from_cache_order(self, path)
      return ensure_record(self, path)
    end
  end

  -- Pointer is valid, now verify size
  local ok, w, h = pcall(ImGui.Image_GetSize, rec.img)
  if ok and w and h and w > 0 and h > 0 then
    -- Update dimensions in case they changed
    if rec.w ~= w or rec.h ~= h then
      rec.w, rec.h = w, h
      -- Recalculate source rect if dimensions changed
      if self._no_crop then
        rec.src_x, rec.src_y, rec.src_w, rec.src_h = 0, 0, w, h
      else
        if is_three_state_from_metadata(path) and w > 0 then
          local frame_w = math.floor(w / 3)
          rec.src_x, rec.src_y, rec.src_w, rec.src_h = 0, 0, frame_w, h
        else
          rec.src_x, rec.src_y, rec.src_w, rec.src_h = 0, 0, w, h
        end
      end
    end
    return rec
  end

  -- Image handle exists but GetSize failed, recreate
  destroy_image(rec.img)
  self._cache[path] = nil
  remove_from_cache_order(self, path)
  return ensure_record(self, path)
end

-- ============================================================================
-- PUBLIC API: Use these methods for accessing cached images
-- ============================================================================

-- Public API: Get a validated image record (automatically validates/recreates if stale)
-- Returns: table { img, w, h, src_x, src_y, src_w, src_h } or nil
-- This is the RECOMMENDED way to access cached images for custom rendering
function Cache:get_validated(path)
  if not path or path == "" then return nil end

  local rec = self._cache[path]

  -- Use the internal validate_record function
  rec = validate_record(self, path, rec)

  return rec
end

-- Check if an image is cached (without triggering load)
function Cache:is_cached(path)
  if not path or path == "" then return false end
  local rec = self._cache[path]
  return rec ~= nil and rec ~= false
end

-- Get cache statistics for debugging/monitoring
function Cache:get_stats()
  local valid_count = 0
  local failed_count = 0

  for _, rec in pairs(self._cache) do
    if rec == false then
      failed_count = failed_count + 1
    elseif rec and rec.img then
      valid_count = valid_count + 1
    end
  end

  return {
    valid = valid_count,
    failed = failed_count,
    total = valid_count + failed_count,
    max_cache = self._max_cache,
    budget_remaining = self._creates_left,
  }
end

-- ============================================================================
-- DRAW METHODS: Convenience wrappers around get_validated
-- ============================================================================

function Cache:draw_original(ctx, path)
  if not path or path == "" then
    ImGui.Dummy(ctx, 16, 16)
    return false
  end
  local rec = validate_record(self, path, self._cache[path])
  if not rec or not rec.img then
    ImGui.Dummy(ctx, 16, 16)
    return false
  end
  local u0 = rec.src_x / rec.w
  local v0 = rec.src_y / rec.h
  local u1 = (rec.src_x + rec.src_w) / rec.w
  local v1 = (rec.src_y + rec.src_h) / rec.h
  local ok = pcall(ImGui.Image, ctx, rec.img, rec.src_w, rec.src_h, u0, v0, u1, v1)
  if not ok then
    destroy_image(rec.img)
    self._cache[path] = false
    ImGui.Dummy(ctx, rec.src_w or 16, rec.src_h or 16)
    return false
  end
  return true
end

function Cache:draw_thumb(ctx, path, cell)
  cell = math.max(1, math.floor(tonumber(cell) or 1))
  if not path or path == "" then
    ImGui.Dummy(ctx, cell, cell)
    return false
  end
  local rec = validate_record(self, path, self._cache[path])
  if not rec or not rec.img then
    ImGui.Dummy(ctx, cell, cell)
    return false
  end
  local src_w, src_h = rec.src_w, rec.src_h
  if src_w <= 0 or src_h <= 0 then
    ImGui.Dummy(ctx, cell, cell)
    return false
  end
  local scale = math.min(cell / src_w, cell / src_h)
  local dw = math.max(1, math.floor(src_w * scale))
  local dh = math.max(1, math.floor(src_h * scale))
  local u0 = rec.src_x / rec.w
  local v0 = rec.src_y / rec.h
  local u1 = (rec.src_x + rec.src_w) / rec.w
  local v1 = (rec.src_y + rec.src_h) / rec.h
  local ok = pcall(ImGui.Image, ctx, rec.img, dw, dh, u0, v0, u1, v1)
  if not ok then
    destroy_image(rec.img)
    self._cache[path] = false
    ImGui.Dummy(ctx, cell, cell)
    return false
  end
  return true
end

function Cache:draw_fit(ctx, path, w, h)
  w = math.max(1, math.floor(tonumber(w) or 1))
  h = math.max(1, math.floor(tonumber(h) or 1))
  if not path or path == "" then
    ImGui.Dummy(ctx, w, h)
    return false
  end
  local rec = validate_record(self, path, self._cache[path])
  if not rec then
    ImGui.Dummy(ctx, w, h)
    return false
  end
  local u0 = rec.src_x / rec.w
  local v0 = rec.src_y / rec.h
  local u1 = (rec.src_x + rec.src_w) / rec.w
  local v1 = (rec.src_y + rec.src_h) / rec.h
  local ok = pcall(ImGui.Image, ctx, rec.img, w, h, u0, v0, u1, v1)
  if not ok then
    destroy_image(rec.img)
    self._cache[path] = false
    ImGui.Dummy(ctx, w, h)
    return false
  end
  return true
end

return M
