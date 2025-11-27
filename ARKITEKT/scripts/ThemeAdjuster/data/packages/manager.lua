-- @noindex
-- ThemeAdjuster/data/packages/manager.lua
-- Package discovery, indexing, and management

local M = {}
local JSON = require('arkitekt.core.json')
local Fs = require('arkitekt.core.fs')
local PathValidation = require('arkitekt.core.path_validation')
local Logger = require('arkitekt.debug.logger')
local DemoData = require('ThemeAdjuster.data.packages.demo_data')

-- Logger instance for package scanning
local log = Logger.new("PackageScanner")

-- Import commonly used functions from Fs
local SEP = Fs.SEP
local file_exists = Fs.file_exists
local dir_exists = Fs.dir_exists
local copy_file = Fs.copy_file

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
      preview_path = nil,  -- Path to preview.png if exists
    },
  }

  -- Check for preview.png first
  local preview_path = package_path .. SEP .. "preview.png"
  if file_exists(preview_path) then
    package.meta.preview_path = preview_path
  end

  -- Check for rtconfig files (rtconfig.txt or rtconfig)
  local rtconfig_found = false
  local rtconfig_patterns = {"rtconfig.txt", "rtconfig"}
  for _, rtconfig_name in ipairs(rtconfig_patterns) do
    local rtconfig_path = package_path .. SEP .. rtconfig_name
    if file_exists(rtconfig_path) then
      rtconfig_found = true
      break
    end
  end

  if rtconfig_found then
    table.insert(package.meta.tags, "RTCONFIG")
  end

  -- Try to load manifest.json (optional)
  local manifest_path = package_path .. SEP .. "manifest.json"
  local content = Fs.read_text(manifest_path)
  if content then
    local ok, manifest = pcall(JSON.decode, content)
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

        -- Skip preview.png and manifest files (not theme assets)
        if key ~= "preview" then
          -- Add to assets
          package.assets[key] = {
            path = package_path .. SEP .. file,
            is_strip = false,  -- TODO: Detect multi-frame strips
          }

          -- Add to keys_order
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

function M.scan_packages(theme_root, demo_mode)
  if demo_mode then
    return DemoData.generate()
  end

  log:debug("theme_root = %s", tostring(theme_root))

  if not theme_root or theme_root == "" then
    log:debug("theme_root is nil or empty, returning empty")
    return {}
  end

  local packages_path = theme_root .. SEP .. "Assembler" .. SEP .. "Packages"
  log:debug("packages_path = %s", packages_path)
  local packages = {}

  -- Check if Packages directory exists
  local test_file = reaper.EnumerateSubdirectories(packages_path, 0)
  log:debug("First subdirectory test = %s", tostring(test_file))
  if not test_file then
    -- Directory doesn't exist, return empty
    log:debug("Packages directory does not exist")
    return {}
  end

  -- Enumerate package folders
  local i = 0
  repeat
    local folder = reaper.EnumerateSubdirectories(packages_path, i)
    if folder then
      log:debug("Found package folder: %s", folder)
      local package_path = packages_path .. SEP .. folder
      local package, has_assets = scan_package_folder(package_path, folder)

      log:debug("Package %s has %d assets", folder, #package.keys_order)

      if has_assets then
        table.insert(packages, package)
      end
    end
    i = i + 1
  until not folder

  log:info("Total packages found: %d", #packages)
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
-- APPLY PIPELINE
-- ============================================================================

-- Helper: Get script cache directory (in REAPER Data folder)
local function get_cache_dir()
  local resource_path = reaper.GetResourcePath()
  return resource_path .. SEP .. "Data" .. SEP .. "ARKITEKT" .. SEP .. "ThemeAdjuster" .. SEP .. "cache"
end

-- Helper: Generate theme ID from path (short hash)
local function theme_id_from_path(theme_root)
  if not theme_root then return "unknown" end
  local hash = 0
  for i = 1, #theme_root do
    hash = (hash * 31 + string.byte(theme_root, i)) % 0xFFFFFFFF
  end
  return string.format("%08x", hash)
end

-- Apply resolved map to theme folder
-- Returns: { ok = bool, files_copied = n, files_backed_up = n, errors = {}, backups_dir = path }
function M.apply_to_theme(theme_root, resolved_map, opts)
  opts = opts or {}
  local result = {
    ok = true,
    files_copied = 0,
    files_backed_up = 0,
    errors = {},
    backups_dir = nil,
  }

  if not theme_root or theme_root == "" then
    result.ok = false
    table.insert(result.errors, "No theme root specified")
    return result
  end

  -- Set up backups directory
  local cache_dir = get_cache_dir()
  local theme_id = theme_id_from_path(theme_root)
  local backups_dir = cache_dir .. SEP .. theme_id .. SEP .. "backups"
  result.backups_dir = backups_dir

  -- Track which files we've already backed up (from previous applies)
  local backed_up_files = {}

  -- Process each resolved asset
  for key, asset in pairs(resolved_map) do
    local src_path = asset.path
    local dst_path = theme_root .. SEP .. key .. ".png"

    -- Skip mock paths (demo mode)
    if src_path:match("^%(mock%)") then
      goto continue
    end

    -- Check source exists
    if not file_exists(src_path) then
      table.insert(result.errors, "Source not found: " .. src_path)
      goto continue
    end

    -- Backup original if it exists and hasn't been backed up before
    local backup_path = backups_dir .. SEP .. key .. ".png"
    if file_exists(dst_path) and not file_exists(backup_path) then
      local ok, err = copy_file(dst_path, backup_path)
      if ok then
        result.files_backed_up = result.files_backed_up + 1
        backed_up_files[key] = true
      else
        table.insert(result.errors, "Backup failed for " .. key .. ": " .. (err or "unknown"))
      end
    end

    -- Copy resolved asset to theme
    local ok, err = copy_file(src_path, dst_path)
    if ok then
      result.files_copied = result.files_copied + 1
    else
      result.ok = false
      table.insert(result.errors, "Copy failed for " .. key .. ": " .. (err or "unknown"))
    end

    ::continue::
  end

  return result
end

-- Revert last apply by restoring from backups
-- Returns: { ok = bool, files_restored = n, errors = {} }
function M.revert_last_apply(theme_root)
  local result = {
    ok = true,
    files_restored = 0,
    errors = {},
  }

  if not theme_root or theme_root == "" then
    result.ok = false
    table.insert(result.errors, "No theme root specified")
    return result
  end

  -- Find backups directory
  local cache_dir = get_cache_dir()
  local theme_id = theme_id_from_path(theme_root)
  local backups_dir = cache_dir .. SEP .. theme_id .. SEP .. "backups"

  -- Check if backups exist
  local first_backup = reaper.EnumerateFiles(backups_dir, 0)
  if not first_backup then
    result.ok = false
    table.insert(result.errors, "No backups found")
    return result
  end

  -- Restore all backed up files
  local i = 0
  repeat
    local file = reaper.EnumerateFiles(backups_dir, i)
    if file then
      local backup_path = backups_dir .. SEP .. file
      local dst_path = theme_root .. SEP .. file

      local ok, err = copy_file(backup_path, dst_path)
      if ok then
        result.files_restored = result.files_restored + 1
      else
        result.ok = false
        table.insert(result.errors, "Restore failed for " .. file .. ": " .. (err or "unknown"))
      end
    end
    i = i + 1
  until not file

  return result
end

-- Clear backups for a theme
function M.clear_backups(theme_root)
  if not theme_root then return false end

  local cache_dir = get_cache_dir()
  local theme_id = theme_id_from_path(theme_root)
  local backups_dir = cache_dir .. SEP .. theme_id .. SEP .. "backups"

  -- Remove all files in backups directory
  local i = 0
  repeat
    local file = reaper.EnumerateFiles(backups_dir, i)
    if file then
      os.remove(backups_dir .. SEP .. file)
    end
    i = i + 1
  until not file

  -- Remove the directory itself
  os.remove(backups_dir)
  return true
end

-- Get backup status for a theme
-- Returns: { has_backups = bool, file_count = n, backups_dir = path }
function M.get_backup_status(theme_root)
  if not theme_root then
    return { has_backups = false, file_count = 0, backups_dir = nil }
  end

  local cache_dir = get_cache_dir()
  local theme_id = theme_id_from_path(theme_root)
  local backups_dir = cache_dir .. SEP .. theme_id .. SEP .. "backups"

  local count = 0
  local i = 0
  repeat
    local file = reaper.EnumerateFiles(backups_dir, i)
    if file then count = count + 1 end
    i = i + 1
  until not file

  return {
    has_backups = count > 0,
    file_count = count,
    backups_dir = backups_dir,
  }
end

-- ============================================================================
-- ZIP THEME SUPPORT
-- ============================================================================

-- Helper: Remove directory recursively
local function rm_rf(dir)
  if not dir_exists(dir) then return end
  -- Remove files
  for _, f in ipairs(Fs.list_files(dir)) do
    os.remove(f)
  end
  -- Recursively remove subdirectories
  for _, sd in ipairs(Fs.list_subdirs(dir)) do
    rm_rf(sd)
  end
  os.remove(dir)
end

-- Helper: Copy directory tree
local function copy_tree(src, dst)
  Fs.mkdir(dst)
  -- Copy files
  for _, f in ipairs(Fs.list_files(src)) do
    local name = Fs.basename(f)
    local ok = copy_file(f, Fs.join(dst, name))
    if not ok then return false end
  end
  -- Recursively copy subdirectories
  for _, sd in ipairs(Fs.list_subdirs(src)) do
    local name = Fs.basename(sd)
    local ok = copy_tree(sd, Fs.join(dst, name))
    if not ok then return false end
  end
  return true
end

-- Helper: Create ZIP file
local function try_run(cmd)
  local r = os.execute(cmd)
  return r == true or r == 0
end

local function try_run_hidden_ps(ps_cmd)
  -- Use io.popen with -WindowStyle Hidden to avoid console flash on Windows
  local f = io.popen(ps_cmd, "r")
  if not f then return false end
  f:read("*a")  -- consume any output
  local ok, _, code = f:close()
  -- Lua 5.3: f:close() returns (true, "exit", 0) on success
  return ok == true or code == 0
end

local function make_zip(src_dir, out_zip)
  -- SECURITY: Validate paths before passing to shell commands (using centralized validation)
  local ok, err = PathValidation.is_safe_path(src_dir)
  if not ok then
    reaper.ShowMessageBox("Invalid source directory: " .. err, "Security Error", 0)
    return false
  end

  ok, err = PathValidation.is_safe_path(out_zip)
  if not ok then
    reaper.ShowMessageBox("Invalid output ZIP path: " .. err, "Security Error", 0)
    return false
  end

  local osname = reaper.GetOS() or ""
  if osname:find("Win") then
    -- Use -WindowStyle Hidden to prevent console window flash
    local ps = ([[powershell -WindowStyle Hidden -NoProfile -Command "Set-Location '%s'; if (Test-Path '%s') {Remove-Item '%s' -Force}; Compress-Archive -Path * -DestinationPath '%s' -Force"]])
      :format(src_dir:gsub("'", "''"), out_zip:gsub("'", "''"), out_zip:gsub("'", "''"), out_zip:gsub("'", "''"))
    return try_run_hidden_ps(ps)
  else
    local zip = ([[cd "%s" && rm -f "%s" && zip -qr "%s" *]]):format(src_dir, out_zip, out_zip)
    return try_run(zip)
  end
end

-- Helper: Count PNGs in directory (recursive)
local function count_pngs(dir)
  local n = 0
  local i = 0
  while true do
    local f = reaper.EnumerateFiles(dir, i)
    if not f then break end
    if f:lower():sub(-4) == ".png" then n = n + 1 end
    i = i + 1
  end
  local j = 0
  while true do
    local s = reaper.EnumerateSubdirectories(dir, j)
    if not s then break end
    n = n + count_pngs(dir .. SEP .. s)
    j = j + 1
  end
  return n
end

-- Helper: Find ui_img directory (directory with most PNGs)
local function find_ui_img_dir(root)
  local best, bestN = root, count_pngs(root)
  local j = 0
  while true do
    local s = reaper.EnumerateSubdirectories(root, j)
    if not s then break end
    local d = root .. SEP .. s
    local n = count_pngs(d)
    if n > bestN then best, bestN = d, n end
    j = j + 1
  end
  return best
end

-- Check if a reassembled ZIP already exists
-- Returns: { exists = bool, path = path, version = n }
function M.check_reassembled_exists(themes_dir, theme_name)
  local base_name = (theme_name or "Theme") .. " (Reassembled)"
  local path = themes_dir .. SEP .. base_name .. ".ReaperThemeZip"

  if file_exists(path) then
    return { exists = true, path = path, version = 1 }
  end

  -- Check for versioned files
  local version = 2
  while file_exists(themes_dir .. SEP .. base_name .. " " .. version .. ".ReaperThemeZip") do
    version = version + 1
  end

  if version > 2 then
    return { exists = true, path = themes_dir .. SEP .. base_name .. " " .. (version - 1) .. ".ReaperThemeZip", version = version - 1 }
  end

  return { exists = false, path = nil, version = 0 }
end

-- Apply resolved map to ZIP theme
-- cache_dir: extracted ZIP location
-- themes_dir: ColorThemes directory
-- theme_name: base name for output
-- opts: { overwrite = bool } - if true, overwrite existing; if false, create new version
-- Returns: { ok = bool, files_copied = n, output_path = path, errors = {} }
function M.apply_to_zip_theme(cache_dir, themes_dir, theme_name, resolved_map, opts)
  opts = opts or {}
  local result = {
    ok = true,
    files_copied = 0,
    output_path = nil,
    errors = {},
  }

  if not cache_dir or not dir_exists(cache_dir) then
    result.ok = false
    table.insert(result.errors, "Cache directory not found")
    return result
  end

  -- Set up work directory
  local script_cache = get_cache_dir()
  local work_dir = script_cache .. SEP .. "work_theme"

  -- Clone cache to work directory
  rm_rf(work_dir)
  reaper.RecursiveCreateDirectory(work_dir, 0)
  if not copy_tree(cache_dir, work_dir) then
    result.ok = false
    table.insert(result.errors, "Failed to clone cache to work directory")
    return result
  end

  -- Find ui_img directory in work copy
  local ui_work = find_ui_img_dir(work_dir)

  -- Copy resolved assets
  for key, asset in pairs(resolved_map) do
    local src_path = asset.path
    local dst_path = ui_work .. SEP .. key .. ".png"

    -- Skip mock paths (demo mode)
    if src_path:match("^%(mock%)") then
      goto continue
    end

    -- Check source exists
    if not file_exists(src_path) then
      table.insert(result.errors, "Source not found: " .. src_path)
      goto continue
    end

    -- Copy asset
    local ok, err = copy_file(src_path, dst_path)
    if ok then
      result.files_copied = result.files_copied + 1
    else
      table.insert(result.errors, "Copy failed for " .. key .. ": " .. (err or "unknown"))
    end

    ::continue::
  end

  -- Create output ZIP with version handling
  local base_name = (theme_name or "Theme") .. " (Reassembled)"
  local patched_name = base_name .. ".ReaperThemeZip"
  local final_path = themes_dir .. SEP .. patched_name

  -- Handle existing file based on opts.overwrite
  if file_exists(final_path) then
    if opts.overwrite then
      -- Will overwrite existing file
    else
      -- Create new version
      local version = 2
      while file_exists(themes_dir .. SEP .. base_name .. " " .. version .. ".ReaperThemeZip") do
        version = version + 1
      end
      patched_name = base_name .. " " .. version .. ".ReaperThemeZip"
      final_path = themes_dir .. SEP .. patched_name
    end
  end

  local out_zip = script_cache .. SEP .. patched_name

  if not make_zip(work_dir, out_zip) then
    result.ok = false
    table.insert(result.errors, "ZIP creation failed")
    return result
  end

  -- Move to ColorThemes directory
  local data = Fs.read_text(out_zip)
  if not data then
    result.ok = false
    table.insert(result.errors, "Failed to read created ZIP")
    return result
  end

  os.remove(final_path)
  if not Fs.write_text(final_path, data) then
    result.ok = false
    table.insert(result.errors, "Failed to move ZIP to ColorThemes")
    return result
  end

  result.output_path = final_path

  -- Clean up work directory
  rm_rf(work_dir)
  os.remove(out_zip)

  return result
end

-- Load created ZIP theme in REAPER
function M.load_zip_theme(zip_path)
  if not file_exists(zip_path) then
    return false, "ZIP file not found"
  end
  reaper.OpenColorThemeFile(zip_path)
  reaper.ThemeLayout_RefreshAll()
  return true
end

-- ============================================================================
-- STATE PERSISTENCE (assembler.json per theme)
-- ============================================================================

-- SECURITY FIX: Use safe JSON encoding/decoding instead of unsafe load()
local function encode_json(tbl)
  return JSON.encode(tbl)
end

local function decode_json(str)
  return JSON.decode(str)
end

-- Get path to assembler.json for a theme
function M.get_state_path(theme_root)
  if not theme_root then return nil end
  local cache_dir = get_cache_dir()
  local theme_id = theme_id_from_path(theme_root)
  return cache_dir .. SEP .. theme_id .. SEP .. "assembler.json"
end

-- Save assembler state for a theme
function M.save_state(theme_root, state_data)
  if not theme_root then return false, "No theme root" end

  local state_path = M.get_state_path(theme_root)
  if not state_path then return false, "Cannot determine state path" end

  -- Ensure directory exists
  local state_dir = state_path:match("^(.*)" .. SEP)
  if state_dir then
    reaper.RecursiveCreateDirectory(state_dir, 0)
  end

  -- Build state object
  local state = {
    version = 1,
    active_order = state_data.active_order or {},
    pins = state_data.pins or {},
    exclusions = state_data.exclusions or {},
    last_saved = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  }

  -- Encode and write
  local json = encode_json(state)
  if not Fs.write_text(state_path, json) then
    return false, "Failed to write state file"
  end

  return true
end

-- Load assembler state for a theme
function M.load_state(theme_root)
  if not theme_root then return nil end

  local state_path = M.get_state_path(theme_root)
  if not state_path then return nil end

  local json = Fs.read_text(state_path)
  if not json then return nil end

  local state = decode_json(json)
  if not state then return nil end

  return {
    active_order = state.active_order or {},
    pins = state.pins or {},
    exclusions = state.exclusions or {},
  }
end

-- Delete state file for a theme
function M.delete_state(theme_root)
  if not theme_root then return false end
  local state_path = M.get_state_path(theme_root)
  if state_path then
    os.remove(state_path)
    return true
  end
  return false
end

-- ============================================================================
-- REASSEMBLED FOLDER OUTPUT (with delta tracking)
-- ============================================================================

-- Get path to assembler state inside a reassembled folder
local function get_reassembled_state_path(output_dir)
  return output_dir .. SEP .. ".assembler_state.json"
end

-- Load previous apply state from reassembled folder
local function load_reassembled_state(output_dir)
  local state_path = get_reassembled_state_path(output_dir)
  local json = Fs.read_text(state_path)
  if not json then return nil end
  return decode_json(json)
end

-- Save apply state to reassembled folder
local function save_reassembled_state(output_dir, state)
  local state_path = get_reassembled_state_path(output_dir)
  local json = encode_json(state)
  return Fs.write_text(state_path, json)
end

-- Apply to an unpacked "Reassembled" folder with delta tracking
-- source_dir: base theme source (extracted cache or folder theme)
-- output_dir: where to create/update the reassembled folder
-- resolved_map: { key = { path, provider, ... }, ... }
-- opts: { force_full = bool } - if true, recopy everything
-- Returns: { ok, files_copied, files_skipped, files_removed, output_dir, errors, is_new }
function M.apply_to_reassembled_folder(source_dir, output_dir, resolved_map, opts)
  opts = opts or {}
  local result = {
    ok = true,
    files_copied = 0,
    files_skipped = 0,
    files_removed = 0,
    output_dir = output_dir,
    errors = {},
    is_new = false,
  }

  if not source_dir or not dir_exists(source_dir) then
    result.ok = false
    table.insert(result.errors, "Source directory not found: " .. (source_dir or "nil"))
    return result
  end

  -- Find ui_img in source
  local source_ui_img = find_ui_img_dir(source_dir)
  if not source_ui_img then
    result.ok = false
    table.insert(result.errors, "No ui_img directory found in source")
    return result
  end

  -- Check if output folder exists
  local is_new_folder = not dir_exists(output_dir)
  result.is_new = is_new_folder

  -- Load previous state (if exists)
  local prev_state = nil
  if not is_new_folder and not opts.force_full then
    prev_state = load_reassembled_state(output_dir)
  end

  -- First run or force_full: copy entire base theme
  if is_new_folder or opts.force_full then
    reaper.RecursiveCreateDirectory(output_dir, 0)
    if not copy_tree(source_dir, output_dir) then
      result.ok = false
      table.insert(result.errors, "Failed to copy base theme to output folder")
      return result
    end
  end

  -- Find ui_img in output
  local output_ui_img = find_ui_img_dir(output_dir)
  if not output_ui_img then
    -- Create it if missing
    output_ui_img = output_dir .. SEP .. "ui_img"
    reaper.RecursiveCreateDirectory(output_ui_img, 0)
  end

  -- Build new state
  local new_state = {
    version = 1,
    applied_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    base_theme = source_dir,
    assets = {},  -- key -> { provider, path, hash }
  }

  -- Track what was in previous state for removal detection
  local prev_assets = (prev_state and prev_state.assets) or {}

  -- Process each resolved asset
  for key, asset in pairs(resolved_map) do
    local src_path = asset.path
    local dst_path = output_ui_img .. SEP .. key .. ".png"

    -- Skip mock paths (demo mode)
    if src_path:match("^%(mock%)") then
      goto continue
    end

    -- Check source exists
    if not file_exists(src_path) then
      table.insert(result.errors, "Source not found: " .. src_path)
      goto continue
    end

    -- Check if we need to copy (delta logic)
    local need_copy = true
    if prev_state and prev_assets[key] then
      -- Same provider and path? Skip copy
      if prev_assets[key].provider == asset.provider and prev_assets[key].path == src_path then
        need_copy = false
        result.files_skipped = result.files_skipped + 1
      end
    end

    -- Copy if needed
    if need_copy then
      local ok, err = copy_file(src_path, dst_path)
      if ok then
        result.files_copied = result.files_copied + 1
      else
        table.insert(result.errors, "Copy failed for " .. key .. ": " .. (err or "unknown"))
      end
    end

    -- Record in new state
    new_state.assets[key] = {
      provider = asset.provider,
      path = src_path,
    }

    -- Remove from prev_assets tracking (so we know what was removed)
    prev_assets[key] = nil

    ::continue::
  end

  -- Handle removed assets (keys that were in prev_state but not in new resolved_map)
  -- Restore original from source or remove the override
  for key, _ in pairs(prev_assets) do
    local original_path = source_ui_img .. SEP .. key .. ".png"
    local dst_path = output_ui_img .. SEP .. key .. ".png"

    if file_exists(original_path) then
      -- Restore original
      local ok, err = copy_file(original_path, dst_path)
      if ok then
        result.files_removed = result.files_removed + 1
      else
        table.insert(result.errors, "Failed to restore original for " .. key .. ": " .. (err or "unknown"))
      end
    else
      -- No original, just remove the file
      os.remove(dst_path)
      result.files_removed = result.files_removed + 1
    end
  end

  -- Save new state
  if not save_reassembled_state(output_dir, new_state) then
    table.insert(result.errors, "Warning: Failed to save state file")
  end

  return result
end

-- Get info about an existing reassembled folder
function M.get_reassembled_info(output_dir)
  if not dir_exists(output_dir) then
    return { exists = false }
  end

  local state = load_reassembled_state(output_dir)
  if not state then
    return {
      exists = true,
      has_state = false,
      asset_count = 0,
    }
  end

  local asset_count = 0
  for _ in pairs(state.assets or {}) do
    asset_count = asset_count + 1
  end

  return {
    exists = true,
    has_state = true,
    applied_at = state.applied_at,
    base_theme = state.base_theme,
    asset_count = asset_count,
  }
end

-- Get default output path for reassembled folder
function M.get_default_reassembled_path(themes_dir, theme_name)
  return themes_dir .. SEP .. (theme_name or "Theme") .. "_Reassembled"
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
