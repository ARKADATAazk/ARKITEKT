-- @noindex
-- ThemeAdjuster/data/packages/scanner.lua
-- Package discovery and scanning

local M = {}

local JSON = require('arkitekt.core.json')
local Fs = require('arkitekt.core.fs')
local Logger = require('arkitekt.debug.logger')
local DemoData = require('ThemeAdjuster.data.packages.demo_data')

local log = Logger.new('PackageScanner')

local SEP = Fs.SEP
local file_exists = Fs.file_exists

-- ============================================================================
-- PACKAGE FOLDER SCANNING
-- ============================================================================

local function scan_package_folder(package_path, package_id)
  local package = {
    id = package_id,
    path = package_path,
    assets = {},
    keys_order = {},
    meta = {
      name = package_id,
      version = '1.0.0',
      author = '',
      description = '',
      tags = {},
      mosaic = {},
      color = nil,
      preview_path = nil,
    },
  }

  -- Check for preview.png first
  local preview_path = package_path .. SEP .. 'preview.png'
  if file_exists(preview_path) then
    package.meta.preview_path = preview_path
  end

  -- Check for rtconfig files (rtconfig.txt or rtconfig)
  local rtconfig_found = false
  local rtconfig_patterns = {'rtconfig.txt', 'rtconfig'}
  for _, rtconfig_name in ipairs(rtconfig_patterns) do
    local rtconfig_path = package_path .. SEP .. rtconfig_name
    if file_exists(rtconfig_path) then
      rtconfig_found = true
      break
    end
  end

  if rtconfig_found then
    table.insert(package.meta.tags, 'RTCONFIG')
  end

  -- Try to load manifest.json (optional)
  local manifest_path = package_path .. SEP .. 'manifest.json'
  local content = Fs.read_text(manifest_path)
  if content then
    local ok, manifest = pcall(JSON.decode, content)
    if ok and manifest then
      package.meta.name = manifest.name or package_id
      package.meta.version = manifest.version or '1.0.0'
      package.meta.author = manifest.author or ''
      package.meta.description = manifest.description or ''
      package.meta.color = manifest.color
    end
  end

  -- Scan for PNG files
  local i = 0
  repeat
    local file = reaper.EnumerateFiles(package_path, i)
    if file then
      if file:match('%.png$') then
        local key = file:match('^(.+)%.png$')
        if key ~= 'preview' then
          package.assets[key] = {
            path = package_path .. SEP .. file,
            is_strip = false,
          }
          table.insert(package.keys_order, key)
        end
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

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function M.scan_packages(theme_root, demo_mode)
  if demo_mode then
    return DemoData.generate()
  end

  log:debug('theme_root = %s', tostring(theme_root))

  if not theme_root or theme_root == '' then
    log:debug('theme_root is nil or empty, returning empty')
    return {}
  end

  local packages_path = theme_root .. SEP .. 'Assembler' .. SEP .. 'Packages'
  log:debug('packages_path = %s', packages_path)
  local packages = {}

  -- Check if Packages directory exists
  local test_file = reaper.EnumerateSubdirectories(packages_path, 0)
  log:debug('First subdirectory test = %s', tostring(test_file))
  if not test_file then
    log:debug('Packages directory does not exist')
    return {}
  end

  -- Enumerate package folders
  local i = 0
  repeat
    local folder = reaper.EnumerateSubdirectories(packages_path, i)
    if folder then
      log:debug('Found package folder: %s', folder)
      local package_path = packages_path .. SEP .. folder
      local package, has_assets = scan_package_folder(package_path, folder)

      log:debug('Package %s has %d assets', folder, #package.keys_order)

      if has_assets then
        table.insert(packages, package)
      end
    end
    i = i + 1
  until not folder

  log:info('Total packages found: %d', #packages)
  return packages
end

-- ============================================================================
-- FILTERING
-- ============================================================================

function M.filter_packages(packages, search_text, filters)
  if search_text == '' and filters.TCP and filters.MCP and filters.Transport and filters.Global then
    return packages
  end

  local filtered = {}

  for _, pkg in ipairs(packages) do
    local name_match = search_text == '' or
                       string.find(string.lower(pkg.id), string.lower(search_text), 1, true) or
                       (pkg.meta.name and string.find(string.lower(pkg.meta.name), string.lower(search_text), 1, true))

    if name_match then
      local has_matching_asset = false
      for asset_key, _ in pairs(pkg.assets) do
        local area_match = false
        if filters.TCP and string.find(asset_key, '^tcp_') then area_match = true end
        if filters.MCP and string.find(asset_key, '^mcp_') then area_match = true end
        if filters.Transport and string.find(asset_key, '^transport_') then area_match = true end
        if filters.Global and not string.find(asset_key, '^tcp_') and not string.find(asset_key, '^mcp_') and not string.find(asset_key, '^transport_') then
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
