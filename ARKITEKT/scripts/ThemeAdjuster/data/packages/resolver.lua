-- @noindex
-- ThemeAdjuster/data/packages/resolver.lua
-- Package conflict detection and resolution

local M = {}

-- ============================================================================
-- CONFLICT DETECTION
-- ============================================================================

function M.detect_conflicts(packages, active_packages, package_order)
  local conflicts = {}
  local asset_providers = {}

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
  local resolved = {}

  -- Phase 1: Apply packages in order (bottom to top, so later ones win)
  for _, pkg_id in ipairs(package_order) do
    if active_packages[pkg_id] then
      local pkg = nil
      for _, p in ipairs(packages) do
        if p.id == pkg_id then
          pkg = p
          break
        end
      end

      if pkg then
        local pkg_exclusions = exclusions[pkg_id] or {}
        local exclusion_set = {}
        for _, key in ipairs(pkg_exclusions) do
          exclusion_set[key] = true
        end

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
-- SHADOW/OVERRIDE DETECTION
-- ============================================================================

function M.detect_shadowed_keys(packages, active_packages, package_order, exclusions, pins, target_pkg_id)
  local shadowed = {}

  -- Find target package position in order
  local target_pos = nil
  for i, pkg_id in ipairs(package_order) do
    if pkg_id == target_pkg_id then
      target_pos = i
      break
    end
  end

  if not target_pos then return shadowed end

  -- Find target package data
  local target_pkg = nil
  for _, pkg in ipairs(packages) do
    if pkg.id == target_pkg_id then
      target_pkg = pkg
      break
    end
  end

  if not target_pkg then return shadowed end

  -- Get exclusions for target package
  local target_excl = exclusions[target_pkg_id] or {}
  local target_excl_set = {}
  for key, _ in pairs(target_excl) do
    target_excl_set[key] = true
  end

  -- For each key in target package, check if higher-priority package provides it
  for key, _ in pairs(target_pkg.assets or {}) do
    if target_excl_set[key] then
      goto continue
    end

    if pins[key] then
      goto continue
    end

    -- Check packages with HIGHER priority (come AFTER in order array)
    for i = target_pos + 1, #package_order do
      local higher_pkg_id = package_order[i]

      if not active_packages[higher_pkg_id] then
        goto next_pkg
      end

      local higher_pkg = nil
      for _, pkg in ipairs(packages) do
        if pkg.id == higher_pkg_id then
          higher_pkg = pkg
          break
        end
      end

      if not higher_pkg then
        goto next_pkg
      end

      local higher_excl = exclusions[higher_pkg_id] or {}
      if higher_pkg.assets[key] and not higher_excl[key] then
        shadowed[key] = higher_pkg_id
        break
      end

      ::next_pkg::
    end

    ::continue::
  end

  return shadowed
end

return M
