-- @noindex
-- ThemeAdjuster/packages/manager.lua
-- Package discovery, indexing, and management

local M = {}

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

function M.scan_packages(theme_root, demo_mode)
  if demo_mode then
    return generate_demo_packages()
  end

  -- TODO: Real package scanning from theme_root/Assembler/Packages/
  -- For now, return empty
  return {}
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
