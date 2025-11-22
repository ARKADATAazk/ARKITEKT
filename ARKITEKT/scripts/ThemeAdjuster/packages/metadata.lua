-- packages/metadata.lua
-- Utility for loading and querying REAPER image metadata
-- Used for auto-tagging packages and providing tooltips

local M = {}

local json = require("dkjson")

-- Cache
local metadata_cache = nil
local metadata_path = nil

-- Get script path for relative metadata loading
local function get_script_path()
  local info = debug.getinfo(1, "S")
  local script_path = info.source:match("@(.+[\\/])")
  return script_path
end

--- Load metadata from JSON file
-- @return table The parsed metadata or nil on error
function M.load()
  if metadata_cache then
    return metadata_cache
  end

  -- Find metadata path relative to this script
  local script_path = get_script_path()
  if script_path then
    metadata_path = script_path .. "../reaper_img_metadata.json"
  else
    -- Fallback
    metadata_path = reaper.GetResourcePath() .. "/Scripts/ThemeAdjuster/reaper_img_metadata.json"
  end

  local file = io.open(metadata_path, "r")
  if not file then
    return nil
  end

  local content = file:read("*a")
  file:close()

  local data, _, err = json.decode(content)
  if err then
    reaper.ShowConsoleMsg("Metadata parse error: " .. tostring(err) .. "\n")
    return nil
  end

  metadata_cache = data
  return data
end

--- Get metadata for a specific image
-- @param image_name string The image name (without extension)
-- @return table|nil The image metadata or nil if not found
function M.get_image(image_name)
  local data = M.load()
  if not data or not data.images then
    return nil
  end

  -- Strip extension if present
  local name = image_name:match("^(.+)%.[^.]+$") or image_name

  return data.images[name]
end

--- Get the area for an image
-- @param image_name string The image name
-- @return string|nil The area (tcp, mcp, transport, etc.) or nil
function M.get_area(image_name)
  local img = M.get_image(image_name)
  return img and img.area
end

--- Check if image is 3-state
-- @param image_name string The image name
-- @return boolean
function M.is_3state(image_name)
  local img = M.get_image(image_name)
  return img and img.is_3state == true
end

--- Get image kind
-- @param image_name string The image name
-- @return string|nil The kind (sliced-button, bg, knob-stack, etc.)
function M.get_kind(image_name)
  local img = M.get_image(image_name)
  return img and img.kind
end

--- Get fallback image name
-- @param image_name string The image name
-- @return string|nil The fallback image name or nil
function M.get_fallback(image_name)
  local img = M.get_image(image_name)
  return img and img.fallback
end

--- Get all valid areas
-- @return table Array of area names
function M.get_areas()
  local data = M.load()
  if data and data._areas then
    return data._areas
  end
  -- Fallback
  return {"global", "tcp", "mcp", "transport", "toolbar", "meter", "envcp", "item", "midi", "track"}
end

--- Calculate area distribution for a set of images
-- @param image_names table Array of image names
-- @return table {area_name = count, ...}
function M.calculate_area_distribution(image_names)
  local distribution = {}

  for _, name in ipairs(image_names) do
    local area = M.get_area(name)
    if area then
      distribution[area] = (distribution[area] or 0) + 1
    end
  end

  return distribution
end

--- Suggest tags for a package based on its assets
-- Uses thresholds to determine if a tag should be applied
-- @param image_names table Array of image names in the package
-- @param threshold number Minimum percentage (0-1) of assets to trigger a tag (default 0.3)
-- @return table Array of suggested tag names
function M.suggest_tags(image_names, threshold)
  threshold = threshold or 0.3

  local distribution = M.calculate_area_distribution(image_names)
  local total = #image_names

  if total == 0 then
    return {}
  end

  local tags = {}

  -- Map areas to display tags
  local area_to_tag = {
    tcp = "TCP",
    mcp = "MCP",
    transport = "Transport",
    toolbar = "Toolbar",
    meter = "Meter",
    envcp = "EnvCP",
    item = "Items",
    midi = "MIDI",
    track = "Track",
    global = "Global"
  }

  -- Calculate percentages and suggest tags
  for area, count in pairs(distribution) do
    local percentage = count / total
    if percentage >= threshold then
      local tag = area_to_tag[area]
      if tag then
        table.insert(tags, tag)
      end
    end
  end

  -- Sort tags for consistency
  table.sort(tags)

  return tags
end

--- Get primary area for a package (the area with most assets)
-- @param image_names table Array of image names
-- @return string|nil The primary area name
function M.get_primary_area(image_names)
  local distribution = M.calculate_area_distribution(image_names)

  local max_count = 0
  local primary_area = nil

  for area, count in pairs(distribution) do
    if count > max_count then
      max_count = count
      primary_area = area
    end
  end

  return primary_area
end

--- Get tooltip info for an image
-- @param image_name string The image name
-- @return string Formatted tooltip text
function M.get_tooltip(image_name)
  local img = M.get_image(image_name)
  if not img then
    return image_name .. " (unknown)"
  end

  local parts = {image_name}

  if img.description then
    table.insert(parts, img.description)
  end

  local info = {}
  if img.area then
    table.insert(info, "Area: " .. img.area)
  end
  if img.kind then
    table.insert(info, "Type: " .. img.kind)
  end
  if img.is_3state then
    table.insert(info, "3-state")
  end
  if img.has_pink then
    table.insert(info, "Has pink channel")
  end
  if img.fallback then
    table.insert(info, "Fallback: " .. img.fallback)
  end

  if #info > 0 then
    table.insert(parts, table.concat(info, ", "))
  end

  return table.concat(parts, "\n")
end

--- Analyze package and return full analysis
-- @param package table Package with assets field
-- @return table Analysis results
function M.analyze_package(package)
  if not package or not package.assets then
    return nil
  end

  -- Get all asset names
  local image_names = {}
  for key, _ in pairs(package.assets) do
    table.insert(image_names, key)
  end

  local distribution = M.calculate_area_distribution(image_names)
  local suggested_tags = M.suggest_tags(image_names)
  local primary_area = M.get_primary_area(image_names)

  -- Count by kind
  local kinds = {}
  for _, name in ipairs(image_names) do
    local kind = M.get_kind(name)
    if kind then
      kinds[kind] = (kinds[kind] or 0) + 1
    end
  end

  return {
    total_assets = #image_names,
    area_distribution = distribution,
    kind_distribution = kinds,
    suggested_tags = suggested_tags,
    primary_area = primary_area
  }
end

--- Clear the metadata cache (useful for development/testing)
function M.clear_cache()
  metadata_cache = nil
end

return M
