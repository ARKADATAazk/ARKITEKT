-- @noindex
-- ThemeAdjuster/core/images.lua
-- Image utility module with proper lifecycle management
--
-- IMPORTANT: ReaImGui images MUST be attached to a context to prevent garbage collection.
-- This module handles that automatically. Always use this module instead of calling
-- ImGui.CreateImage directly.
--
-- Usage:
--   local Images = require('ThemeAdjuster.core.images')
--
--   -- Create a cache instance (typically one per view/modal)
--   local image_cache = Images.new_cache()
--
--   -- In your draw function, get images with automatic context attachment:
--   local img = image_cache:get(ctx, path)
--   if img then
--     local w, h = image_cache:get_size(img)
--     ImGui.Image(ctx, img, w, h)
--   end
--
--   -- Clear cache when closing view (optional, helps with memory)
--   image_cache:clear()

local ImGui = require 'imgui' '0.10'

local M = {}

-- =============================================================================
-- ImageCache class
-- =============================================================================
-- Manages a collection of images with proper lifecycle handling.
-- Images are automatically attached to the ImGui context when created,
-- which prevents them from being garbage collected.

local ImageCache = {}
ImageCache.__index = ImageCache

--- Create a new image cache instance.
-- @return ImageCache A new cache instance
function M.new_cache()
  return setmetatable({
    _cache = {},  -- path -> image handle or false (failed)
  }, ImageCache)
end

--- Get or create an image from a file path.
-- Images are automatically attached to the context for proper lifecycle management.
-- @param ctx The ImGui context (REQUIRED for attachment)
-- @param path The file path to the image
-- @return userdata|nil The image handle, or nil if failed
function ImageCache:get(ctx, path)
  if not ctx then
    error("ImageCache:get() requires ctx parameter - images must be attached to context")
  end
  if not path or path == "" then return nil end
  if path:find("^%(mock%)") then return nil end  -- Skip mock/demo paths

  local entry = self._cache[path]

  -- Check cached entry
  if entry ~= nil then
    if entry == false then
      return nil  -- Previously failed to load
    end

    -- Validate image is still valid
    local ok, w, h = pcall(ImGui.Image_GetSize, entry)
    if ok and w and w > 0 then
      return entry
    else
      -- Image became invalid, clear it
      self._cache[path] = nil
    end
  end

  -- Create new image
  local ok, img = pcall(ImGui.CreateImage, path)
  if ok and img then
    -- CRITICAL: Attach to context to prevent garbage collection
    -- Without this, Lua's GC will collect the image handle between frames
    ImGui.Attach(ctx, img)

    -- Verify it loaded correctly
    local ok2, w, h = pcall(ImGui.Image_GetSize, img)
    if ok2 and w and w > 0 then
      self._cache[path] = img
      return img
    else
      self._cache[path] = false
      return nil
    end
  else
    self._cache[path] = false  -- Mark as permanently failed
    return nil
  end
end

--- Get the size of an image safely.
-- @param img The image handle
-- @return number, number Width and height, or 0, 0 if invalid
function ImageCache:get_size(img)
  if not img then return 0, 0 end
  local ok, w, h = pcall(ImGui.Image_GetSize, img)
  if ok and w and h then
    return w, h
  end
  return 0, 0
end

--- Check if an image is valid and can be used.
-- @param img The image handle
-- @return boolean True if the image is valid
function ImageCache:is_valid(img)
  if not img then return false end
  local ok, w, h = pcall(ImGui.Image_GetSize, img)
  return ok and w and w > 0
end

--- Clear all cached images.
-- Call this when closing a view/modal to free memory.
function ImageCache:clear()
  self._cache = {}
  -- Note: We don't need to explicitly free images - they're attached to
  -- the context and will be cleaned up when the context is destroyed
end

--- Remove a specific image from the cache.
-- @param path The file path of the image to remove
function ImageCache:remove(path)
  self._cache[path] = nil
end

--- Get the number of cached images.
-- @return number The count of cached images (not including failed entries)
function ImageCache:count()
  local n = 0
  for _, v in pairs(self._cache) do
    if v and v ~= false then
      n = n + 1
    end
  end
  return n
end

-- =============================================================================
-- Convenience functions for simple use cases
-- =============================================================================

-- Global cache for simple usage (when you don't need a dedicated cache)
local _global_cache = M.new_cache()

--- Get or create an image using the global cache.
-- For simple use cases where you don't need a dedicated cache instance.
-- @param ctx The ImGui context
-- @param path The file path to the image
-- @return userdata|nil The image handle
function M.get(ctx, path)
  return _global_cache:get(ctx, path)
end

--- Get image size using the global cache.
-- @param img The image handle
-- @return number, number Width and height
function M.get_size(img)
  return _global_cache:get_size(img)
end

--- Clear the global cache.
function M.clear_global()
  _global_cache:clear()
end

return M
