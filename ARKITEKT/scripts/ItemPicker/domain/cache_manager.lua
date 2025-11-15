local M = {}

local function get_current_time()
  return reaper.time_precise()
end

function M.new(max_entries)
  return {
    waveforms = {},
    midi_thumbnails = {},
    waveform_arrays = {},
    access_times = {},
    max_entries = max_entries or 200,
  }
end

function M.get_item_signature(item)
  local take = reaper.GetActiveTake(item)
  if not take then return nil end
  
  local source = reaper.GetMediaItemTake_Source(take)
  local filename = reaper.GetMediaSourceFileName(source)
  local startoffs = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
  local playrate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
  local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  
  return string.format("%s_%.3f_%.3f_%.3f", 
    filename:gsub("[^%w]", "_"), 
    startoffs, 
    playrate,
    length
  )
end

function M.cleanup_old_entries(cache_table, access_times, max_entries)
  local count = 0
  for _ in pairs(cache_table) do count = count + 1 end
  
  if count > max_entries then
    local entries = {}
    for key, time in pairs(access_times) do
      table.insert(entries, {key = key, time = time})
    end
    
    table.sort(entries, function(a, b) return a.time < b.time end)
    
    local to_remove = count - max_entries
    for i = 1, to_remove do
      cache_table[entries[i].key] = nil
      access_times[entries[i].key] = nil
    end
  end
end

function M.get_waveform_data(cache, item)
  local sig = M.get_item_signature(item)
  if not sig then return nil end
  
  if cache.waveforms[sig] then
    cache.access_times[sig] = get_current_time()
    return cache.waveforms[sig]
  end
  
  return nil
end

function M.set_waveform_data(cache, item, data)
  local sig = M.get_item_signature(item)
  if not sig then return end
  
  cache.waveforms[sig] = data
  cache.access_times[sig] = get_current_time()
  
  M.cleanup_old_entries(cache.waveforms, cache.access_times, cache.max_entries)
end

function M.get_waveform_arrays(cache, item, width)
  local sig = M.get_item_signature(item)
  if not sig then return nil end
  
  local key = sig .. "_arrays_" .. math.floor(width)
  
  if cache.waveform_arrays[key] then
    cache.access_times[key] = get_current_time()
    return cache.waveform_arrays[key]
  end
  
  return nil
end

function M.set_waveform_arrays(cache, item, width, top_array, bottom_array)
  local sig = M.get_item_signature(item)
  if not sig then return end
  
  local key = sig .. "_arrays_" .. math.floor(width)
  cache.waveform_arrays[key] = {top = top_array, bottom = bottom_array}
  cache.access_times[key] = get_current_time()
  
  M.cleanup_old_entries(cache.waveform_arrays, cache.access_times, cache.max_entries)
end

-- Cache MIDI thumbnails at fixed max resolution, then scale when displaying
-- This prevents regeneration on every tile resize
local MIDI_CACHE_MAX_WIDTH = 512
local MIDI_CACHE_MAX_HEIGHT = 512

function M.get_midi_thumbnail(cache, item, width, height)
  local sig = M.get_item_signature(item)
  if not sig then return nil end

  -- Always use max resolution for cache key (size-independent)
  local key = sig .. "_midi"

  if cache.midi_thumbnails[key] then
    cache.access_times[key] = get_current_time()
    return cache.midi_thumbnails[key]
  end

  return nil
end

function M.set_midi_thumbnail(cache, item, width, height, data)
  local sig = M.get_item_signature(item)
  if not sig then return end

  -- Always use max resolution for cache key (size-independent)
  local key = sig .. "_midi"
  cache.midi_thumbnails[key] = data
  cache.access_times[key] = get_current_time()

  M.cleanup_old_entries(cache.midi_thumbnails, cache.access_times, cache.max_entries)
end

function M.get_midi_cache_size()
  return MIDI_CACHE_MAX_WIDTH, MIDI_CACHE_MAX_HEIGHT
end

function M.invalidate_item(cache, item)
  local sig = M.get_item_signature(item)
  if not sig then return end
  
  for key in pairs(cache.waveforms) do
    if key:match("^" .. sig) then
      cache.waveforms[key] = nil
      cache.access_times[key] = nil
    end
  end
  
  for key in pairs(cache.waveform_arrays) do
    if key:match("^" .. sig) then
      cache.waveform_arrays[key] = nil
      cache.access_times[key] = nil
    end
  end
  
  for key in pairs(cache.midi_thumbnails) do
    if key:match("^" .. sig) then
      cache.midi_thumbnails[key] = nil
      cache.access_times[key] = nil
    end
  end
end

function M.get_stats(cache)
  local waveform_count = 0
  local midi_count = 0
  local array_count = 0

  for _ in pairs(cache.waveforms) do waveform_count = waveform_count + 1 end
  for _ in pairs(cache.midi_thumbnails) do midi_count = midi_count + 1 end
  for _ in pairs(cache.waveform_arrays) do array_count = array_count + 1 end

  return {
    waveforms = waveform_count,
    midi = midi_count,
    arrays = array_count,
    total = waveform_count + midi_count + array_count
  }
end

-- ============================================================================
-- DISK CACHE FUNCTIONS
-- ============================================================================

-- Get the cache directory path
function M.get_cache_dir()
  local sep = package.config:sub(1,1)
  local cache_dir = reaper.GetResourcePath() .. sep .. "Scripts" .. sep .. "ARKITEKT" .. sep .. "ItemPicker_Cache" .. sep
  return cache_dir
end

-- Get project hash for cache key
function M.get_project_hash(project_path)
  if not project_path or project_path == "" then
    return "unsaved_project"
  end
  -- Create a simple hash from project path
  return project_path:gsub("[^%w]", "_")
end

-- Save MIDI thumbnail to disk
function M.save_midi_thumbnail_to_disk(sig, data)
  local sep = package.config:sub(1,1)
  local cache_dir = M.get_cache_dir()
  local thumb_dir = cache_dir .. "thumbnails" .. sep

  -- Create directory if needed
  reaper.RecursiveCreateDirectory(thumb_dir, 0)

  local file_path = thumb_dir .. sig .. "_midi.lua"
  local file = io.open(file_path, "w")
  if not file then return false end

  -- Serialize MIDI note data (lightweight)
  file:write("return {\n")
  for key, note in pairs(data) do
    file:write(string.format("  [%q] = {x1=%.3f, y1=%.3f, x2=%.3f, y2=%.3f, vel=%d},\n",
      key, note.x1, note.y1, note.x2, note.y2, note.vel or 64))
  end
  file:write("}\n")
  file:close()

  return true
end

-- Save audio waveform to disk
function M.save_waveform_to_disk(sig, data)
  local sep = package.config:sub(1,1)
  local cache_dir = M.get_cache_dir()
  local wave_dir = cache_dir .. "waveforms" .. sep

  -- Create directory if needed
  reaper.RecursiveCreateDirectory(wave_dir, 0)

  local file_path = wave_dir .. sig .. ".lua"
  local file = io.open(file_path, "w")
  if not file then return false end

  -- Serialize waveform data (peak values)
  file:write("return {\n")
  file:write("  peaks = {")
  for i, peak in ipairs(data.peaks or {}) do
    if i > 1 then file:write(",") end
    if i % 20 == 1 then file:write("\n    ") end
    file:write(string.format("%.4f", peak))
  end
  file:write("\n  },\n")
  file:write("  num_channels = " .. (data.num_channels or 1) .. ",\n")
  file:write("}\n")
  file:close()

  return true
end

-- Load MIDI thumbnail from disk
function M.load_midi_thumbnail_from_disk(sig)
  local sep = package.config:sub(1,1)
  local cache_dir = M.get_cache_dir()
  local file_path = cache_dir .. "thumbnails" .. sep .. sig .. "_midi.lua"

  local file = io.open(file_path, "r")
  if not file then return nil end
  file:close()

  -- Load the thumbnail data
  local success, data = pcall(dofile, file_path)
  if success then
    return data
  end

  return nil
end

-- Load audio waveform from disk
function M.load_waveform_from_disk(sig)
  local sep = package.config:sub(1,1)
  local cache_dir = M.get_cache_dir()
  local file_path = cache_dir .. "waveforms" .. sep .. sig .. ".lua"

  local file = io.open(file_path, "r")
  if not file then return nil end
  file:close()

  -- Load the waveform data
  local success, data = pcall(dofile, file_path)
  if success then
    return data
  end

  return nil
end

-- Save project state to disk (metadata only, not thumbnails)
function M.save_project_state_to_disk(state)
  local project_path = reaper.GetProjectPath("")
  if project_path == "" then
    project_path = "unsaved"
  end

  local sep = package.config:sub(1,1)
  local cache_dir = M.get_cache_dir()
  local project_hash = M.get_project_hash(project_path)
  local project_dir = cache_dir .. "projects" .. sep .. project_hash .. sep

  -- Create directory
  reaper.RecursiveCreateDirectory(project_dir, 0)

  local state_file = project_dir .. "state.lua"
  local file = io.open(state_file, "w")
  if not file then return false end

  -- Serialize lightweight state (no thumbnails, just metadata)
  file:write("return {\n")
  file:write("  project_path = " .. string.format("%q", project_path) .. ",\n")
  file:write("  timestamp = " .. reaper.time_precise() .. ",\n")
  file:write("  change_count = " .. reaper.GetProjectStateChangeCount(0) .. ",\n")
  file:write("  sample_indexes = {")
  for i, key in ipairs(state.sample_indexes or {}) do
    file:write(string.format("%q%s", key, i < #state.sample_indexes and ", " or ""))
  end
  file:write("},\n")
  file:write("  midi_indexes = {")
  for i, key in ipairs(state.midi_indexes or {}) do
    file:write(string.format("%q%s", key, i < #state.midi_indexes and ", " or ""))
  end
  file:write("},\n")
  file:write("}\n")
  file:close()

  -- Save timestamp
  local ts_file = io.open(project_dir .. "timestamp.txt", "w")
  if ts_file then
    ts_file:write(tostring(reaper.time_precise()))
    ts_file:close()
  end

  return true
end

-- Load project state from disk
function M.load_project_state_from_disk()
  local project_path = reaper.GetProjectPath("")
  if project_path == "" then
    project_path = "unsaved"
  end

  local sep = package.config:sub(1,1)
  local cache_dir = M.get_cache_dir()
  local project_hash = M.get_project_hash(project_path)
  local state_file = cache_dir .. "projects" .. sep .. project_hash .. sep .. "state.lua"

  local file = io.open(state_file, "r")
  if not file then return nil end
  file:close()

  local success, data = pcall(dofile, state_file)
  if success then
    -- Check if change count matches (project hasn't changed)
    local current_change_count = reaper.GetProjectStateChangeCount(0)
    if data.change_count == current_change_count then
      return data
    end
  end

  return nil
end

-- Enhanced get_midi_thumbnail with disk cache fallback
function M.get_midi_thumbnail_cached(cache, item, width, height)
  -- Try memory cache first
  local cached = M.get_midi_thumbnail(cache, item, width, height)
  if cached then return cached end

  -- Try disk cache
  local sig = M.get_item_signature(item)
  if not sig then return nil end

  local disk_data = M.load_midi_thumbnail_from_disk(sig)
  if disk_data then
    -- Load into memory cache
    local key = sig .. "_midi"
    cache.midi_thumbnails[key] = disk_data
    cache.access_times[key] = get_current_time()
    return disk_data
  end

  return nil
end

-- Enhanced set_midi_thumbnail with disk persistence
function M.set_midi_thumbnail_cached(cache, item, width, height, data)
  -- Save to memory cache
  M.set_midi_thumbnail(cache, item, width, height, data)

  -- Save to disk cache asynchronously (don't block)
  local sig = M.get_item_signature(item)
  if sig then
    M.save_midi_thumbnail_to_disk(sig, data)
  end
end

-- Enhanced get_waveform_data with disk cache fallback
function M.get_waveform_data_cached(cache, item)
  -- Try memory cache first
  local cached = M.get_waveform_data(cache, item)
  if cached then return cached end

  -- Try disk cache
  local sig = M.get_item_signature(item)
  if not sig then return nil end

  local disk_data = M.load_waveform_from_disk(sig)
  if disk_data then
    -- Load into memory cache
    cache.waveforms[sig] = disk_data
    cache.access_times[sig] = get_current_time()
    return disk_data
  end

  return nil
end

-- Enhanced set_waveform_data with disk persistence
function M.set_waveform_data_cached(cache, item, data)
  -- Save to memory cache
  M.set_waveform_data(cache, item, data)

  -- Save to disk cache asynchronously (don't block)
  local sig = M.get_item_signature(item)
  if sig then
    M.save_waveform_to_disk(sig, data)
  end
end

-- ============================================================================
-- CACHE CLEANUP FUNCTIONS
-- ============================================================================

-- Get total cache size on disk (in MB)
function M.get_cache_size_mb()
  local function get_dir_size(dir_path)
    local total_size = 0
    local sep = package.config:sub(1,1)

    -- Simple approach: count .lua files
    local i = 0
    while i < 10000 do  -- Safety limit
      local file_path = dir_path .. i .. ".lua"
      local file = io.open(file_path, "r")
      if not file then break end
      local size = file:seek("end")
      file:close()
      total_size = total_size + size
      i = i + 1
    end

    return total_size
  end

  local cache_dir = M.get_cache_dir()
  local sep = package.config:sub(1,1)

  local total = 0
  -- This is a rough estimate - a full directory scan would be better
  -- but would be too slow

  return total / (1024 * 1024)  -- Convert to MB
end

-- Clean old cache files (keep last N days)
function M.cleanup_old_cache_files(days_to_keep)
  days_to_keep = days_to_keep or 30  -- Default: keep 30 days
  local cutoff_time = reaper.time_precise() - (days_to_keep * 24 * 60 * 60)

  local cache_dir = M.get_cache_dir()
  local sep = package.config:sub(1,1)
  local cleaned = 0

  -- Clean project state directories
  local projects_dir = cache_dir .. "projects" .. sep
  -- Note: REAPER doesn't have directory scanning API
  -- This would need to be implemented with OS-specific commands
  -- For now, we'll just mark this as a manual cleanup operation

  return cleaned
end

-- Clear all cached data (nuclear option)
function M.clear_all_cache()
  local cache_dir = M.get_cache_dir()
  -- Note: Would need OS-specific directory deletion
  -- For safety, we'll just log a warning
  reaper.ShowConsoleMsg("[ItemPicker Cache] Manual cache clear required: " .. cache_dir .. "\n")
  return false
end

-- ============================================================================
-- DAEMON STATUS FUNCTIONS
-- ============================================================================

-- Check if daemon is running
function M.is_daemon_running()
  local sep = package.config:sub(1,1)
  local cache_dir = M.get_cache_dir()
  local state_file = cache_dir .. "daemon_state.lua"

  local file = io.open(state_file, "r")
  if not file then return false end
  file:close()

  local success, data = pcall(dofile, state_file)
  if success and data then
    -- Check if daemon state was updated recently (within last 5 seconds)
    if data.last_update and (reaper.time_precise() - data.last_update) < 5.0 then
      return data.running == true, data
    end
  end

  return false, nil
end

-- Get daemon status info
function M.get_daemon_status()
  local is_running, data = M.is_daemon_running()
  if not is_running or not data then
    return {
      running = false,
      message = "Daemon not running"
    }
  end

  local progress = 0
  if data.thumbnails_total and data.thumbnails_total > 0 then
    progress = math.floor((data.thumbnails_generated or 0) / data.thumbnails_total * 100)
  end

  return {
    running = true,
    progress = progress,
    thumbnails_generated = data.thumbnails_generated or 0,
    thumbnails_total = data.thumbnails_total or 0,
    project_path = data.project_path or "",
    message = string.format("Daemon: %d%% (%d/%d thumbnails)",
      progress, data.thumbnails_generated or 0, data.thumbnails_total or 0)
  }
end

return M