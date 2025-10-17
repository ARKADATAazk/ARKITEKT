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

function M.get_midi_thumbnail(cache, item, width, height)
  local sig = M.get_item_signature(item)
  if not sig then return nil end
  
  local key = sig .. "_" .. width .. "_" .. height
  
  if cache.midi_thumbnails[key] then
    cache.access_times[key] = get_current_time()
    return cache.midi_thumbnails[key]
  end
  
  return nil
end

function M.set_midi_thumbnail(cache, item, width, height, data)
  local sig = M.get_item_signature(item)
  if not sig then return end
  
  local key = sig .. "_" .. width .. "_" .. height
  cache.midi_thumbnails[key] = data
  cache.access_times[key] = get_current_time()
  
  M.cleanup_old_entries(cache.midi_thumbnails, cache.access_times, cache.max_entries)
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

return M