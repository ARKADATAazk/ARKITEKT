-- @noindex
-- ThemeAdjuster/data/packages/applier.lua
-- Theme application, backup/revert, ZIP support

local M = {}

local Fs = require('arkitekt.core.fs')
local PathValidation = require('arkitekt.core.path_validation')
local JSON = require('arkitekt.core.json')

local SEP = Fs.SEP
local file_exists = Fs.file_exists
local dir_exists = Fs.dir_exists
local copy_file = Fs.copy_file

-- ============================================================================
-- HELPERS
-- ============================================================================

local function get_cache_dir()
  local resource_path = reaper.GetResourcePath()
  return resource_path .. SEP .. 'Data' .. SEP .. 'ARKITEKT' .. SEP .. 'ThemeAdjuster' .. SEP .. 'cache'
end

local function theme_id_from_path(theme_root)
  if not theme_root then return 'unknown' end
  local hash = 0
  for i = 1, #theme_root do
    hash = (hash * 31 + string.byte(theme_root, i)) % 0xFFFFFFFF
  end
  return string.format('%08x', hash)
end

local function get_asset_dir(asset_path)
  return asset_path:match('^(.*)' .. SEP) or '.'
end

-- ============================================================================
-- DPI VARIANT HANDLING
-- ============================================================================

local function copy_dpi_variants(src_dir, dst_dir, key)
  local copied = 0

  -- 1. Check for _hidpi suffix variant (same directory)
  local hidpi_src = src_dir .. SEP .. key .. '_hidpi.png'
  local hidpi_dst = dst_dir .. SEP .. key .. '_hidpi.png'
  if file_exists(hidpi_src) then
    if copy_file(hidpi_src, hidpi_dst) then
      copied = copied + 1
    end
  end

  -- 2. Check for 150/ folder variant
  local src_150 = src_dir .. SEP .. '150' .. SEP .. key .. '.png'
  local dst_150_dir = dst_dir .. SEP .. '150'
  local dst_150 = dst_150_dir .. SEP .. key .. '.png'
  if file_exists(src_150) then
    reaper.RecursiveCreateDirectory(dst_150_dir, 0)
    if copy_file(src_150, dst_150) then
      copied = copied + 1
    end
  end

  -- 3. Check for 200/ folder variant
  local src_200 = src_dir .. SEP .. '200' .. SEP .. key .. '.png'
  local dst_200_dir = dst_dir .. SEP .. '200'
  local dst_200 = dst_200_dir .. SEP .. key .. '.png'
  if file_exists(src_200) then
    reaper.RecursiveCreateDirectory(dst_200_dir, 0)
    if copy_file(src_200, dst_200) then
      copied = copied + 1
    end
  end

  return copied
end

-- ============================================================================
-- DIRECTORY HELPERS
-- ============================================================================

local function rm_rf(dir)
  if not dir_exists(dir) then return end
  for _, f in ipairs(Fs.list_files(dir)) do
    os.remove(f)
  end
  for _, sd in ipairs(Fs.list_subdirs(dir)) do
    rm_rf(sd)
  end
  os.remove(dir)
end

local function copy_tree(src, dst)
  Fs.mkdir(dst)
  for _, f in ipairs(Fs.list_files(src)) do
    local name = Fs.basename(f)
    local ok = copy_file(f, Fs.join(dst, name))
    if not ok then return false end
  end
  for _, sd in ipairs(Fs.list_subdirs(src)) do
    local name = Fs.basename(sd)
    local ok = copy_tree(sd, Fs.join(dst, name))
    if not ok then return false end
  end
  return true
end

-- ============================================================================
-- ZIP HELPERS
-- ============================================================================

local function try_run(cmd)
  local r = os.execute(cmd)
  return r == true or r == 0
end

local function try_run_hidden_ps(ps_cmd)
  local f = io.popen(ps_cmd, 'r')
  if not f then return false end
  f:read('*a')
  local ok, _, code = f:close()
  return ok == true or code == 0
end

local function make_zip(src_dir, out_zip)
  local ok, err = PathValidation.is_safe_path(src_dir)
  if not ok then
    reaper.ShowMessageBox('Invalid source directory: ' .. err, 'Security Error', 0)
    return false
  end

  ok, err = PathValidation.is_safe_path(out_zip)
  if not ok then
    reaper.ShowMessageBox('Invalid output ZIP path: ' .. err, 'Security Error', 0)
    return false
  end

  local osname = reaper.GetOS() or ''
  if osname:find('Win') then
    local ps = ([[powershell -WindowStyle Hidden -NoProfile -Command "Set-Location '%s'; if (Test-Path '%s') {Remove-Item '%s' -Force}; Compress-Archive -Path * -DestinationPath '%s' -Force"]])
      :format(src_dir:gsub("'", "''"), out_zip:gsub("'", "''"), out_zip:gsub("'", "''"), out_zip:gsub("'", "''"))
    return try_run_hidden_ps(ps)
  else
    local zip = ([[cd '%s' && rm -f '%s' && zip -qr '%s' *]]):format(src_dir, out_zip, out_zip)
    return try_run(zip)
  end
end

local function count_pngs(dir)
  local n = 0
  local i = 0
  while true do
    local f = reaper.EnumerateFiles(dir, i)
    if not f then break end
    if f:lower():sub(-4) == '.png' then n = n + 1 end
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

-- ============================================================================
-- APPLY TO FOLDER THEME
-- ============================================================================

function M.apply_to_theme(theme_root, resolved_map, opts)
  opts = opts or {}
  local result = {
    ok = true,
    files_copied = 0,
    files_backed_up = 0,
    errors = {},
    backups_dir = nil,
  }

  if not theme_root or theme_root == '' then
    result.ok = false
    table.insert(result.errors, 'No theme root specified')
    return result
  end

  local cache_dir = get_cache_dir()
  local theme_id = theme_id_from_path(theme_root)
  local backups_dir = cache_dir .. SEP .. theme_id .. SEP .. 'backups'
  result.backups_dir = backups_dir

  local backed_up_files = {}

  for key, asset in pairs(resolved_map) do
    local src_path = asset.path
    local dst_path = theme_root .. SEP .. key .. '.png'

    if src_path:match('^%(mock%)') then
      goto continue
    end

    if not file_exists(src_path) then
      table.insert(result.errors, 'Source not found: ' .. src_path)
      goto continue
    end

    local backup_path = backups_dir .. SEP .. key .. '.png'
    if file_exists(dst_path) and not file_exists(backup_path) then
      local ok, err = copy_file(dst_path, backup_path)
      if ok then
        result.files_backed_up = result.files_backed_up + 1
        backed_up_files[key] = true
      else
        table.insert(result.errors, 'Backup failed for ' .. key .. ': ' .. (err or 'unknown'))
      end
    end

    local ok, err = copy_file(src_path, dst_path)
    if ok then
      result.files_copied = result.files_copied + 1
      local src_dir = get_asset_dir(src_path)
      local dpi_copied = copy_dpi_variants(src_dir, theme_root, key)
      result.files_copied = result.files_copied + dpi_copied
    else
      result.ok = false
      table.insert(result.errors, 'Copy failed for ' .. key .. ': ' .. (err or 'unknown'))
    end

    ::continue::
  end

  return result
end

-- ============================================================================
-- REVERT FROM BACKUP
-- ============================================================================

function M.revert_last_apply(theme_root)
  local result = {
    ok = true,
    files_restored = 0,
    errors = {},
  }

  if not theme_root or theme_root == '' then
    result.ok = false
    table.insert(result.errors, 'No theme root specified')
    return result
  end

  local cache_dir = get_cache_dir()
  local theme_id = theme_id_from_path(theme_root)
  local backups_dir = cache_dir .. SEP .. theme_id .. SEP .. 'backups'

  local first_backup = reaper.EnumerateFiles(backups_dir, 0)
  if not first_backup then
    result.ok = false
    table.insert(result.errors, 'No backups found')
    return result
  end

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
        table.insert(result.errors, 'Restore failed for ' .. file .. ': ' .. (err or 'unknown'))
      end
    end
    i = i + 1
  until not file

  return result
end

function M.clear_backups(theme_root)
  if not theme_root then return false end

  local cache_dir = get_cache_dir()
  local theme_id = theme_id_from_path(theme_root)
  local backups_dir = cache_dir .. SEP .. theme_id .. SEP .. 'backups'

  local i = 0
  repeat
    local file = reaper.EnumerateFiles(backups_dir, i)
    if file then
      os.remove(backups_dir .. SEP .. file)
    end
    i = i + 1
  until not file

  os.remove(backups_dir)
  return true
end

function M.get_backup_status(theme_root)
  if not theme_root then
    return { has_backups = false, file_count = 0, backups_dir = nil }
  end

  local cache_dir = get_cache_dir()
  local theme_id = theme_id_from_path(theme_root)
  local backups_dir = cache_dir .. SEP .. theme_id .. SEP .. 'backups'

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

function M.check_reassembled_exists(themes_dir, theme_name)
  local base_name = (theme_name or 'Theme') .. ' (Reassembled)'
  local path = themes_dir .. SEP .. base_name .. '.ReaperThemeZip'

  if file_exists(path) then
    return { exists = true, path = path, version = 1 }
  end

  local version = 2
  while file_exists(themes_dir .. SEP .. base_name .. ' ' .. version .. '.ReaperThemeZip') do
    version = version + 1
  end

  if version > 2 then
    return { exists = true, path = themes_dir .. SEP .. base_name .. ' ' .. (version - 1) .. '.ReaperThemeZip', version = version - 1 }
  end

  return { exists = false, path = nil, version = 0 }
end

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
    table.insert(result.errors, 'Cache directory not found')
    return result
  end

  local script_cache = get_cache_dir()
  local work_dir = script_cache .. SEP .. 'work_theme'

  rm_rf(work_dir)
  reaper.RecursiveCreateDirectory(work_dir, 0)
  if not copy_tree(cache_dir, work_dir) then
    result.ok = false
    table.insert(result.errors, 'Failed to clone cache to work directory')
    return result
  end

  local ui_work = find_ui_img_dir(work_dir)

  for key, asset in pairs(resolved_map) do
    local src_path = asset.path
    local dst_path = ui_work .. SEP .. key .. '.png'

    if src_path:match('^%(mock%)') then
      goto continue
    end

    if not file_exists(src_path) then
      table.insert(result.errors, 'Source not found: ' .. src_path)
      goto continue
    end

    local ok, err = copy_file(src_path, dst_path)
    if ok then
      result.files_copied = result.files_copied + 1
      local src_dir = get_asset_dir(src_path)
      local dpi_copied = copy_dpi_variants(src_dir, ui_work, key)
      result.files_copied = result.files_copied + dpi_copied
    else
      table.insert(result.errors, 'Copy failed for ' .. key .. ': ' .. (err or 'unknown'))
    end

    ::continue::
  end

  local base_name = (theme_name or 'Theme') .. ' (Reassembled)'
  local patched_name = base_name .. '.ReaperThemeZip'
  local final_path = themes_dir .. SEP .. patched_name

  if file_exists(final_path) then
    if opts.overwrite then
      -- Will overwrite
    else
      local version = 2
      while file_exists(themes_dir .. SEP .. base_name .. ' ' .. version .. '.ReaperThemeZip') do
        version = version + 1
      end
      patched_name = base_name .. ' ' .. version .. '.ReaperThemeZip'
      final_path = themes_dir .. SEP .. patched_name
    end
  end

  local out_zip = script_cache .. SEP .. patched_name

  if not make_zip(work_dir, out_zip) then
    result.ok = false
    table.insert(result.errors, 'ZIP creation failed')
    return result
  end

  local data = Fs.read_text(out_zip)
  if not data then
    result.ok = false
    table.insert(result.errors, 'Failed to read created ZIP')
    return result
  end

  os.remove(final_path)
  if not Fs.write_text(final_path, data) then
    result.ok = false
    table.insert(result.errors, 'Failed to move ZIP to ColorThemes')
    return result
  end

  result.output_path = final_path

  rm_rf(work_dir)
  os.remove(out_zip)

  return result
end

function M.load_zip_theme(zip_path)
  if not file_exists(zip_path) then
    return false, 'ZIP file not found'
  end
  reaper.OpenColorThemeFile(zip_path)
  reaper.ThemeLayout_RefreshAll()
  return true
end

-- ============================================================================
-- REASSEMBLED FOLDER OUTPUT (with delta tracking)
-- ============================================================================

local function get_reassembled_state_path(output_dir)
  return output_dir .. SEP .. '.assembler_state.json'
end

local function load_reassembled_state(output_dir)
  local state_path = get_reassembled_state_path(output_dir)
  local json = Fs.read_text(state_path)
  if not json then return nil end
  return JSON.decode(json)
end

local function save_reassembled_state(output_dir, state)
  local state_path = get_reassembled_state_path(output_dir)
  local json = JSON.encode(state)
  return Fs.write_text(state_path, json)
end

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
    table.insert(result.errors, 'Source directory not found: ' .. (source_dir or 'nil'))
    return result
  end

  local source_ui_img = find_ui_img_dir(source_dir)
  if not source_ui_img then
    result.ok = false
    table.insert(result.errors, 'No ui_img directory found in source')
    return result
  end

  local is_new_folder = not dir_exists(output_dir)
  result.is_new = is_new_folder

  local prev_state = nil
  if not is_new_folder and not opts.force_full then
    prev_state = load_reassembled_state(output_dir)
  end

  if is_new_folder or opts.force_full then
    reaper.RecursiveCreateDirectory(output_dir, 0)
    if not copy_tree(source_dir, output_dir) then
      result.ok = false
      table.insert(result.errors, 'Failed to copy base theme to output folder')
      return result
    end
  end

  local output_ui_img = find_ui_img_dir(output_dir)
  if not output_ui_img then
    output_ui_img = output_dir .. SEP .. 'ui_img'
    reaper.RecursiveCreateDirectory(output_ui_img, 0)
  end

  local new_state = {
    version = 1,
    applied_at = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    base_theme = source_dir,
    assets = {},
  }

  local prev_assets = (prev_state and prev_state.assets) or {}

  for key, asset in pairs(resolved_map) do
    local src_path = asset.path
    local dst_path = output_ui_img .. SEP .. key .. '.png'

    if src_path:match('^%(mock%)') then
      goto continue
    end

    if not file_exists(src_path) then
      table.insert(result.errors, 'Source not found: ' .. src_path)
      goto continue
    end

    local need_copy = true
    if prev_state and prev_assets[key] then
      if prev_assets[key].provider == asset.provider and prev_assets[key].path == src_path then
        need_copy = false
        result.files_skipped = result.files_skipped + 1
      end
    end

    if need_copy then
      local ok, err = copy_file(src_path, dst_path)
      if ok then
        result.files_copied = result.files_copied + 1
        local src_dir = get_asset_dir(src_path)
        local dpi_copied = copy_dpi_variants(src_dir, output_ui_img, key)
        result.files_copied = result.files_copied + dpi_copied
      else
        table.insert(result.errors, 'Copy failed for ' .. key .. ': ' .. (err or 'unknown'))
      end
    end

    new_state.assets[key] = {
      provider = asset.provider,
      path = src_path,
    }

    prev_assets[key] = nil

    ::continue::
  end

  for key, _ in pairs(prev_assets) do
    local original_path = source_ui_img .. SEP .. key .. '.png'
    local dst_path = output_ui_img .. SEP .. key .. '.png'

    if file_exists(original_path) then
      local ok, err = copy_file(original_path, dst_path)
      if ok then
        result.files_removed = result.files_removed + 1
      else
        table.insert(result.errors, 'Failed to restore original for ' .. key .. ': ' .. (err or 'unknown'))
      end
    else
      os.remove(dst_path)
      result.files_removed = result.files_removed + 1
    end
  end

  if not save_reassembled_state(output_dir, new_state) then
    table.insert(result.errors, 'Warning: Failed to save state file')
  end

  return result
end

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

function M.get_default_reassembled_path(themes_dir, theme_name)
  return themes_dir .. SEP .. (theme_name or 'Theme') .. '_Reassembled'
end

-- ============================================================================
-- STATE PERSISTENCE (assembler.json per theme)
-- ============================================================================

function M.get_state_path(theme_root)
  if not theme_root then return nil end
  local cache_dir = get_cache_dir()
  local theme_id = theme_id_from_path(theme_root)
  return cache_dir .. SEP .. theme_id .. SEP .. 'assembler.json'
end

function M.save_state(theme_root, state_data)
  if not theme_root then return false, 'No theme root' end

  local state_path = M.get_state_path(theme_root)
  if not state_path then return false, 'Cannot determine state path' end

  local state_dir = state_path:match('^(.*)' .. SEP)
  if state_dir then
    reaper.RecursiveCreateDirectory(state_dir, 0)
  end

  local state = {
    version = 1,
    active_order = state_data.active_order or {},
    pins = state_data.pins or {},
    exclusions = state_data.exclusions or {},
    last_saved = os.date('!%Y-%m-%dT%H:%M:%SZ'),
  }

  local json = JSON.encode(state)
  if not Fs.write_text(state_path, json) then
    return false, 'Failed to write state file'
  end

  return true
end

function M.load_state(theme_root)
  if not theme_root then return nil end

  local state_path = M.get_state_path(theme_root)
  if not state_path then return nil end

  local json = Fs.read_text(state_path)
  if not json then return nil end

  local state = JSON.decode(json)
  if not state then return nil end

  return {
    active_order = state.active_order or {},
    pins = state.pins or {},
    exclusions = state.exclusions or {},
  }
end

function M.delete_state(theme_root)
  if not theme_root then return false end
  local state_path = M.get_state_path(theme_root)
  if state_path then
    os.remove(state_path)
    return true
  end
  return false
end

return M
