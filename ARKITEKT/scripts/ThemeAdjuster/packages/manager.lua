-- @noindex
-- ThemeAdjuster/packages/manager.lua
-- Package discovery, indexing, and management

local M = {}

-- Platform path separator
local SEP = package.config:sub(1,1)

-- ============================================================================
-- DEMO DATA GENERATOR
-- ============================================================================

local function generate_demo_packages()
  local packages = {}
  local package_names = {
    "CleanLines", "DarkBevel", "FlatModern", "GlassUI",
    "MinimalPro", "NeonGlow", "RetroWave", "SoftGradient"
  }

  local areas = {"tcp", "mcp", "transport", "global"}
  local asset_types = {
    "panel_bg", "mute_on", "mute_off", "solo_on", "solo_off",
    "recarm_on", "recarm_off", "fx_on", "fx_off"
  }

  for i, name in ipairs(package_names) do
    local keys = {}
    local assets = {}

    -- Generate random assets for this package
    local asset_count = math.random(15, 45)
    for j = 1, asset_count do
      local area = areas[math.random(1, #areas)]
      local asset = asset_types[math.random(1, #asset_types)]
      local key = area .. "_" .. asset

      if not assets[key] then
        keys[#keys + 1] = key
        assets[key] = {
          path = string.format("(mock)/%s/%s.png", name, key),
          is_strip = false,
        }
      end
    end

    table.sort(keys)

    packages[i] = {
      id = name,
      path = string.format("(mock)/Assembler/Packages/%s", name),
      assets = assets,
      keys_order = keys,
      meta = {
        name = name,
        version = "1.0.0",
        author = "ARKADATA",
        description = string.format("%s theme package", name),
        tags = {"demo"},
        mosaic = {keys[1], keys[2], keys[3]},
        color = string.format("#%02X%02X%02X",
          math.random(100, 255),
          math.random(100, 255),
          math.random(100, 255)),
      },
    }
  end

  return packages
end

-- ============================================================================
-- PACKAGE SCANNING
-- ============================================================================

local function scan_package_folder(package_path, package_id)
  local package = {
    id = package_id,
    path = package_path,
    assets = {},
    keys_order = {},
    meta = {
      name = package_id,  -- Default to folder name
      version = "1.0.0",
      author = "",
      description = "",
      tags = {},
      mosaic = {},
      color = nil,
    },
  }

  -- Try to load manifest.json (optional)
  local manifest_path = package_path .. SEP .. "manifest.json"
  local manifest_file = io.open(manifest_path, "r")
  if manifest_file then
    local content = manifest_file:read("*all")
    manifest_file:close()

    local ok, manifest = pcall(function()
      -- Simple JSON parse for basic structure
      -- Note: This is a minimal implementation. For production, use a proper JSON library
      local data = {}
      for key, value in string.gmatch(content, '"([^"]+)"%s*:%s*"([^"]+)"') do
        data[key] = value
      end
      return data
    end)

    if ok and manifest then
      package.meta.name = manifest.name or package_id
      package.meta.version = manifest.version or "1.0.0"
      package.meta.author = manifest.author or ""
      package.meta.description = manifest.description or ""
      package.meta.color = manifest.color
    end
  end

  -- Scan for PNG files
  local i = 0
  repeat
    local file = reaper.EnumerateFiles(package_path, i)
    if file then
      -- Check if it's a PNG file
      if file:match("%.png$") then
        -- Extract key (filename without extension)
        local key = file:match("^(.+)%.png$")

        -- Add to assets
        package.assets[key] = {
          path = package_path .. SEP .. file,
          is_strip = false,  -- TODO: Detect multi-frame strips
        }

        -- Add to keys_order
        table.insert(package.keys_order, key)
      end
    end
    i = i + 1
  until not file

  -- Sort keys alphabetically
  table.sort(package.keys_order)

  -- Generate mosaic preview (first 3 keys or from manifest)
  if #package.keys_order > 0 then
    local mosaic_count = math.min(3, #package.keys_order)
    for j = 1, mosaic_count do
      table.insert(package.meta.mosaic, package.keys_order[j])
    end
  end

  return package, #package.keys_order > 0
end

function M.scan_packages(theme_root, demo_mode)
  if demo_mode then
    return generate_demo_packages()
  end

  if not theme_root or theme_root == "" then
    return {}
  end

  local packages_path = theme_root .. SEP .. "Assembler" .. SEP .. "Packages"
  local packages = {}

  -- Check if Packages directory exists
  local test_file = reaper.EnumerateSubdirectories(packages_path, 0)
  if not test_file then
    -- Directory doesn't exist, return empty
    return {}
  end

  -- Enumerate package folders
  local i = 0
  repeat
    local folder = reaper.EnumerateSubdirectories(packages_path, i)
    if folder then
      local package_path = packages_path .. SEP .. folder
      local package, has_assets = scan_package_folder(package_path, folder)

      if has_assets then
        table.insert(packages, package)
      end
    end
    i = i + 1
  until not folder

  return packages
end

-- ============================================================================
-- CONFLICT DETECTION
-- ============================================================================

function M.detect_conflicts(packages, active_packages, package_order)
  local conflicts = {}
  local asset_providers = {}  -- asset_key -> {pkg_id1, pkg_id2, ...}

  -- First pass: collect all providers for each asset
  for _, pkg_id in ipairs(package_order) do
    if active_packages[pkg_id] then
      for _, pkg in ipairs(packages) do
        if pkg.id == pkg_id then
          for asset_key, _ in pairs(pkg.assets) do
            asset_providers[asset_key] = asset_providers[asset_key] or {}
            table.insert(asset_providers[asset_key], pkg_id)
          end
          break
        end
      end
    end
  end

  -- Second pass: identify conflicts (assets with multiple providers)
  for asset_key, providers in pairs(asset_providers) do
    if #providers > 1 then
      -- Count conflicts per package
      for _, pkg_id in ipairs(providers) do
        conflicts[pkg_id] = (conflicts[pkg_id] or 0) + 1
      end
    end
  end

  return conflicts
end

-- ============================================================================
-- PACKAGE RESOLUTION
-- ============================================================================

function M.resolve_packages(packages, active_packages, package_order, exclusions, pins)
  local resolved = {}  -- key -> { path, provider }

  -- Phase 1: Apply packages in order (bottom to top, so later ones win)
  for _, pkg_id in ipairs(package_order) do
    if active_packages[pkg_id] then
      -- Find the package
      local pkg = nil
      for _, p in ipairs(packages) do
        if p.id == pkg_id then
          pkg = p
          break
        end
      end

      if pkg then
        -- Get exclusions for this package
        local pkg_exclusions = exclusions[pkg_id] or {}
        local exclusion_set = {}
        for _, key in ipairs(pkg_exclusions) do
          exclusion_set[key] = true
        end

        -- Add all non-excluded assets from this package
        for key, asset in pairs(pkg.assets) do
          if not exclusion_set[key] then
            resolved[key] = {
              path = asset.path,
              provider = pkg_id,
              is_strip = asset.is_strip or false,
            }
          end
        end
      end
    end
  end

  -- Phase 2: Apply pins (override everything)
  for key, pinned_pkg_id in pairs(pins) do
    -- Find the pinned package
    local pkg = nil
    for _, p in ipairs(packages) do
      if p.id == pinned_pkg_id then
        pkg = p
        break
      end
    end

    if pkg and pkg.assets[key] then
      resolved[key] = {
        path = pkg.assets[key].path,
        provider = pinned_pkg_id,
        is_strip = pkg.assets[key].is_strip or false,
        pinned = true,
      }
    end
  end

  return resolved
end

-- ============================================================================
-- FILTERING
-- ============================================================================

function M.filter_packages(packages, search_text, filters)
  if search_text == "" and filters.TCP and filters.MCP and filters.Transport and filters.Global then
    return packages  -- No filtering needed
  end

  local filtered = {}

  for _, pkg in ipairs(packages) do
    local name_match = search_text == "" or
                       string.find(string.lower(pkg.id), string.lower(search_text), 1, true) or
                       (pkg.meta.name and string.find(string.lower(pkg.meta.name), string.lower(search_text), 1, true))

    if name_match then
      -- Check if package has any assets matching active filters
      local has_matching_asset = false
      for asset_key, _ in pairs(pkg.assets) do
        local area_match = false
        if filters.TCP and string.find(asset_key, "^tcp_") then area_match = true end
        if filters.MCP and string.find(asset_key, "^mcp_") then area_match = true end
        if filters.Transport and string.find(asset_key, "^transport_") then area_match = true end
        if filters.Global and not string.find(asset_key, "^tcp_") and not string.find(asset_key, "^mcp_") and not string.find(asset_key, "^transport_") then
          area_match = true
        end

        if area_match then
          has_matching_asset = true
          break
        end
      end

      if has_matching_asset then
        filtered[#filtered + 1] = pkg
      end
    end
  end

  return filtered
end

return M
