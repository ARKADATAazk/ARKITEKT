-- @noindex
-- DrumBlocks/domain/waveform_cache.lua
-- Waveform peak caching - computes peaks from audio files
-- Supports multi-resolution async computation

local M = {}

-- Debug flags
local DEBUG = false          -- Set true to enable console logging
local DEBUG_VERBOSE = false  -- Set true to log every frame (very noisy)
local function log(msg)
  if DEBUG then reaper.ShowConsoleMsg(msg) end
end
local function log_verbose(msg)
  if DEBUG and DEBUG_VERBOSE then reaper.ShowConsoleMsg(msg) end
end

-- ============================================================================
-- CONSTANTS
-- ============================================================================

-- Resolution tiers (must be in ascending order)
M.TIERS = {
  mini = 24,      -- Pad grid thumbnails
  low = 256,      -- Small displays / zoomed out
  medium = 1024,  -- Default editor view
  high = 8192,    -- Zoomed in / large displays (editor always uses this)
}

-- Tier names in order for iteration
M.TIER_ORDER = { 'mini', 'low', 'medium', 'high' }

-- Length-adaptive defaults
M.PEAKS_PER_SECOND = 1000 -- Target peaks per second for length-adaptive resolution

-- Calculate adaptive resolution based on sample duration
local function calcAdaptiveResolution(duration_seconds)
  local target = duration_seconds * M.PEAKS_PER_SECOND
  return math.max(M.TIERS.low, math.min(M.TIERS.high, math.floor(target)))
end

-- Get appropriate tier for display width (legacy, for pad grid)
local function getTierForWidth(display_width)
  if display_width <= 64 then return 'mini' end
  if display_width <= 300 then return 'low' end
  if display_width <= 1200 then return 'medium' end
  return 'high'
end

-- Get tier for waveform editor - always use highest resolution
-- The rendering code downsamples via interpolation as needed
-- This avoids visual jumps when zooming - just smooth downsampling from high-res data
local function getTierForEditor(visible_duration)
  return 'high'
end

-- ============================================================================
-- CACHE
-- ============================================================================

-- Cache structure: cache[filepath] = { mini = {...}, low = {...}, medium = {...}, high = {...}, duration = n }
local cache = {}

-- Map pad/layer to filepath for lookup
local pad_to_file = {}  -- pad_to_file[pad_index][layer] = filepath

-- ============================================================================
-- ASYNC COMPUTATION QUEUE
-- ============================================================================

local async_queue = {}      -- { {filepath, tier, callback}, ... }
local async_active = false  -- Is async processing running?
local async_current = nil   -- Current computation in progress

-- Process one async computation step
local function asyncTick()
  -- If we have a current job, it's done (computation is synchronous per-tick)
  if async_current then
    async_current = nil
  end

  -- Get next job from queue
  if #async_queue == 0 then
    async_active = false
    log('[WaveformCache] Async queue empty, stopping\n')
    return
  end

  local job = table.remove(async_queue, 1)
  local filepath, tier, callback = job.filepath, job.tier, job.callback

  -- Skip if already cached
  if cache[filepath] and cache[filepath][tier] then
    log('[WaveformCache] Async skip (already cached): ' .. tier .. ' for ' .. filepath .. '\n')
    if callback then callback(cache[filepath][tier]) end
    reaper.defer(asyncTick)
    return
  end

  async_current = job
  local resolution = M.TIERS[tier]

  log('[WaveformCache] Async computing: ' .. tier .. ' (' .. resolution .. ' peaks) for ' .. filepath .. '\n')

  -- Compute peaks (this is the potentially slow part)
  local peaks = M._computePeaksSimple(filepath, resolution)

  if peaks then
    -- Store in cache
    if not cache[filepath] then
      cache[filepath] = {}
    end
    cache[filepath][tier] = peaks
    log('[WaveformCache] Async complete: ' .. tier .. ' for ' .. filepath .. '\n')

    if callback then callback(peaks) end
  else
    log('[WaveformCache] Async failed: ' .. tier .. ' for ' .. filepath .. '\n')
    if callback then callback(nil) end
  end

  -- Continue processing queue
  reaper.defer(asyncTick)
end

-- Start async processing if not already running
local function startAsync()
  if async_active then return end
  async_active = true
  log('[WaveformCache] Starting async processing\n')
  reaper.defer(asyncTick)
end

-- Queue async computation
local function queueAsync(filepath, tier, callback, priority)
  log(string.format('[WaveformCache] queueAsync: tier=%s priority=%s file=%s\n',
    tier, tostring(priority), filepath))

  -- Check if already queued
  for _, job in ipairs(async_queue) do
    if job.filepath == filepath and job.tier == tier then
      log('[WaveformCache] queueAsync: already queued, skipping\n')
      -- Already queued, just add callback
      if callback and job.callback then
        local orig = job.callback
        job.callback = function(peaks) orig(peaks); callback(peaks) end
      elseif callback then
        job.callback = callback
      end
      return
    end
  end

  local job = { filepath = filepath, tier = tier, callback = callback }

  if priority then
    table.insert(async_queue, 1, job)  -- High priority: front of queue
  else
    table.insert(async_queue, job)     -- Normal: back of queue
  end

  log(string.format('[WaveformCache] queueAsync: added to queue, length=%d\n', #async_queue))
  startAsync()
end

-- ============================================================================
-- PEAK COMPUTATION FROM AUDIO FILE
-- ============================================================================

-- Read audio file and compute peaks at given resolution
-- Returns array: [max1..maxN, min1..minN] where N = resolution
local function computePeaksFromFile(filepath, resolution)
  if not filepath or filepath == '' then return nil end

  -- Check file exists
  local file = io.open(filepath, 'rb')
  if not file then
    log('[WaveformCache] File not found: ' .. filepath .. '\n')
    return nil
  end
  file:close()

  -- Use REAPER's PCM_Source to read audio
  local source = reaper.PCM_Source_CreateFromFile(filepath)
  if not source then
    log('[WaveformCache] Could not create PCM source for: ' .. filepath .. '\n')
    return nil
  end

  local num_channels, sample_rate = reaper.GetMediaSourceNumChannels(source), reaper.GetMediaSourceSampleRate(source)
  local length = reaper.GetMediaSourceLength(source)

  if num_channels == 0 or sample_rate == 0 or length <= 0 then
    reaper.PCM_Source_Destroy(source)
    log('[WaveformCache] Invalid audio source: ' .. filepath .. '\n')
    return nil
  end

  local total_samples = math.floor(length * sample_rate)
  local samples_per_peak = math.max(1, math.floor(total_samples / resolution))

  log('[WaveformCache] Computing peaks: ' .. filepath .. ' (' .. total_samples .. ' samples, ' .. resolution .. ' peaks)\n')

  -- Create accessor for reading samples
  local accessor = reaper.CreateTakeAudioAccessor(nil)
  if not accessor then
    -- Try alternative method - create a temp take
    reaper.PCM_Source_Destroy(source)
    log('[WaveformCache] Could not create audio accessor\n')
    return nil
  end

  -- Actually, REAPER's audio accessor needs a take, not a raw source
  -- Let's use a simpler approach: read peaks directly via GetMediaSourcePeaks if available
  reaper.PCM_Source_Destroy(source)

  -- Alternative: Use reaper.PCM_Source_GetPeaks (if available) or compute manually
  -- For now, return nil and let UI show empty waveform
  return nil
end

-- Clamp sample value to prevent waveform overflow (matches ItemPicker)
local function sampleLimit(val)
  if val > 1 then return 1 end
  if val < -1 then return -1 end
  return val
end

-- Compute peaks from audio file using REAPER's peak system
-- Output format matches ItemPicker: [max1..maxN, min1..minN]
local function computePeaksSimple(filepath, resolution)
  if not filepath or filepath == '' then return nil end

  -- Check file exists
  if not reaper.file_exists(filepath) then
    log('[WaveformCache] File not found: ' .. filepath .. '\n')
    return nil
  end

  -- Create PCM source
  local source = reaper.PCM_Source_CreateFromFile(filepath)
  if not source then
    log('[WaveformCache] Could not create PCM source\n')
    return nil
  end

  local length = reaper.GetMediaSourceLength(source)
  local num_channels = reaper.GetMediaSourceNumChannels(source)
  local sample_rate = reaper.GetMediaSourceSampleRate(source)

  if length <= 0 or num_channels <= 0 then
    log(string.format('[WaveformCache] Invalid source: length=%.2f ch=%d\n', length or 0, num_channels or 0))
    reaper.PCM_Source_Destroy(source)
    return nil
  end

  -- Limit channels to 2 (like ItemPicker)
  local orig_channels = num_channels
  num_channels = math.min(num_channels, 2)

  -- Force peak building if needed (for files dragged without preview)
  local build_ret = reaper.PCM_Source_BuildPeaks(source, 0)
  if build_ret ~= 0 then
    log('[WaveformCache] Building peaks...\n')
    -- Build peaks (mode 1 returns remaining %, 0 when done)
    local iterations = 0
    while reaper.PCM_Source_BuildPeaks(source, 1) ~= 0 and iterations < 1000 do
      iterations = iterations + 1
    end
    -- Finalize
    reaper.PCM_Source_BuildPeaks(source, 2)
    log('[WaveformCache] Peaks built\n')
  end

  -- Buffer size: resolution * 2 * channels (max+min per channel per position)
  local buf = reaper.new_array(resolution * 2 * num_channels)
  local peak_rate = resolution / length  -- peaks per second

  log(string.format('[WaveformCache] GetPeaks: len=%.2fs sr=%d ch=%d->%d peak_rate=%.2f res=%d\n',
    length, sample_rate or 0, orig_channels, num_channels, peak_rate, resolution))

  local ret = reaper.PCM_Source_GetPeaks(source, peak_rate, 0, num_channels, resolution, 0, buf)
  reaper.PCM_Source_Destroy(source)

  if ret <= 0 then
    log(string.format('[WaveformCache] PCM_Source_GetPeaks failed (ret=%d)\n', ret))
    return nil
  end

  local buf_table = buf.table()
  local peaks = {}

  -- PCM_Source_GetPeaks buffer format (same as GetMediaItemTake_Peaks):
  -- First half: all MAX values (interleaved L/R for stereo)
  -- Second half: all MIN values (interleaved L/R for stereo)
  -- Total size: resolution * 2 * num_channels

  local half = resolution * num_channels  -- Where min values start

  if num_channels == 2 then
    -- Stereo: combine L+R channels
    for i = 1, resolution do
      local max_idx = (i - 1) * 2  -- L/R interleaved in first half
      local min_idx = half + (i - 1) * 2  -- L/R interleaved in second half

      local l_max = buf_table[max_idx + 1] or 0
      local r_max = buf_table[max_idx + 2] or 0
      local l_min = buf_table[min_idx + 1] or 0
      local r_min = buf_table[min_idx + 2] or 0

      -- Combine channels: use max of both for max, min of both for min
      peaks[i] = sampleLimit(math.max(l_max, r_max))
      peaks[resolution + i] = sampleLimit(math.min(l_min, r_min))
    end
  else
    -- Mono: first half = max, second half = min
    for i = 1, resolution do
      peaks[i] = sampleLimit(buf_table[i] or 0)
      peaks[resolution + i] = sampleLimit(buf_table[half + i] or 0)
    end
  end

  log(string.format('[WaveformCache] Computed %d peaks, ch=%d, first=[%.3f,%.3f] last=[%.3f,%.3f]\n',
    resolution, num_channels, peaks[1] or 0, peaks[resolution + 1] or 0,
    peaks[resolution] or 0, peaks[resolution * 2] or 0))
  return peaks
end

-- Expose for async system
M._computePeaksSimple = computePeaksSimple

-- ============================================================================
-- PUBLIC API
-- ============================================================================

-- Extract mini peaks from audio file and cache them (lightweight, for pad grid)
-- Returns true if successful
function M.extractAndCache(pad_index, layer, filepath)
  layer = layer or 0

  log(string.format('[WaveformCache] extractAndCache: pad=%s layer=%d file=%s\n',
    tostring(pad_index), layer, tostring(filepath)))

  if not filepath or filepath == '' then
    log('[WaveformCache] extractAndCache: No filepath provided\n')
    return false
  end

  -- Map pad/layer to filepath first (even if peaks fail)
  if not pad_to_file[pad_index] then
    pad_to_file[pad_index] = {}
  end
  pad_to_file[pad_index][layer] = filepath
  log(string.format('[WaveformCache] extractAndCache: registered pad_to_file[%s][%d] = %s\n',
    tostring(pad_index), layer, filepath))

  -- Check if already cached
  if cache[filepath] and cache[filepath].mini then
    log('[WaveformCache] Cache hit for pad=' .. pad_index .. ' file=' .. filepath .. '\n')
    return true
  end

  log('[WaveformCache] Extracting mini peaks for pad=' .. pad_index .. ' layer=' .. layer .. ' file=' .. filepath .. '\n')

  -- Compute only mini resolution (lightweight for pad grid)
  -- Higher resolutions computed lazily/async when needed
  local mini = computePeaksSimple(filepath, M.TIERS.mini)

  if not mini then
    log('[WaveformCache] Failed to compute peaks\n')
    return false
  end

  -- Cache by filepath
  if not cache[filepath] then
    cache[filepath] = {}
  end
  cache[filepath].mini = mini

  return true
end

-- Request peaks for a specific tier (async if not cached)
-- Returns immediately with best available, triggers async computation if needed
-- callback(peaks) called when requested tier is ready
function M.requestTier(filepath, tier, callback)
  if not filepath or filepath == '' then
    log_verbose('[WaveformCache] requestTier: no filepath\n')
    return nil
  end

  tier = tier or 'medium'
  local entry = cache[filepath]

  -- If requested tier is cached, return it (silent - happens every frame)
  if entry and entry[tier] then
    if callback then callback(entry[tier]) end
    return entry[tier]
  end

  -- Cache miss - log this (important)
  local cached_tiers = {}
  if entry then
    for _, t in ipairs(M.TIER_ORDER) do
      if entry[t] then cached_tiers[#cached_tiers + 1] = t end
    end
  end
  log(string.format('[WaveformCache] requestTier MISS: tier=%s cached=[%s] file=%s\n',
    tier, table.concat(cached_tiers, ','), filepath))

  -- Queue async computation for requested tier
  queueAsync(filepath, tier, callback, true)  -- Priority queue

  -- Return best available tier (lower resolution)
  if entry then
    for i = #M.TIER_ORDER, 1, -1 do
      local t = M.TIER_ORDER[i]
      if entry[t] then
        log(string.format('[WaveformCache] requestTier: returning fallback tier=%s\n', t))
        return entry[t]
      end
    end
  end

  log('[WaveformCache] requestTier: no fallback available, returning nil\n')
  return nil
end

-- Request peaks for display width (auto-selects appropriate tier)
-- Returns best available, triggers async for better resolution if needed
function M.requestForWidth(filepath, display_width, callback)
  local tier = getTierForWidth(display_width)
  log_verbose(string.format('[WaveformCache] requestForWidth: width=%.0f -> tier=%s\n', display_width, tier))
  return M.requestTier(filepath, tier, callback)
end

-- Ensure full resolution peaks are cached (call when editor opens)
-- Now uses 'medium' tier by default, or calculates based on duration
-- Returns true if already cached, false if queued for async
function M.ensureFullResolution(pad_index, layer, callback)
  layer = layer or 0

  local filepath = pad_to_file[pad_index] and pad_to_file[pad_index][layer]
  if not filepath then return false end

  -- Check if medium already computed (good default for editor)
  if cache[filepath] and cache[filepath].medium then
    if callback then callback(cache[filepath].medium) end
    return true
  end

  -- Queue medium tier computation
  queueAsync(filepath, 'medium', callback, true)

  -- Also queue high if not present (for zoom)
  if not (cache[filepath] and cache[filepath].high) then
    queueAsync(filepath, 'high', nil, false)  -- Lower priority
  end

  return false  -- Not yet cached, will be computed async
end

-- Get peaks for a pad/layer
-- tier: 'mini', 'low', 'medium', 'high', or 'full' (alias for medium)
function M.getPeaks(pad_index, layer, tier)
  tier = tier or 'mini'
  layer = layer or 0

  -- 'full' is legacy alias for 'medium'
  if tier == 'full' then tier = 'medium' end

  -- Look up filepath for this pad/layer
  local filepath = pad_to_file[pad_index] and pad_to_file[pad_index][layer]
  if not filepath then
    return nil
  end

  -- Get from cache
  local entry = cache[filepath]
  if entry and entry[tier] then
    return entry[tier]
  end

  return nil
end

-- Get best available peaks for display (with async upgrade)
-- Returns peaks immediately, triggers async computation for better resolution
function M.getPeaksForDisplay(pad_index, layer, display_width, callback)
  layer = layer or 0
  display_width = display_width or 200

  local filepath = pad_to_file[pad_index] and pad_to_file[pad_index][layer]
  log_verbose(string.format('[WaveformCache] getPeaksForDisplay: pad=%s layer=%d width=%.0f filepath=%s\n',
    tostring(pad_index), layer, display_width, tostring(filepath)))

  if not filepath then
    log_verbose('[WaveformCache] getPeaksForDisplay: no filepath mapped for this pad/layer\n')
    return nil
  end

  return M.requestForWidth(filepath, display_width, callback)
end

-- Get peaks for waveform editor with duration-based tier selection
-- visible_duration: seconds of audio currently visible
-- Returns best available peaks, triggers async for better resolution if needed
function M.getPeaksForEditor(pad_index, layer, visible_duration, callback)
  layer = layer or 0
  visible_duration = visible_duration or 1

  local filepath = pad_to_file[pad_index] and pad_to_file[pad_index][layer]
  if not filepath then return nil end

  local tier = getTierForEditor(visible_duration)
  log_verbose(string.format('[WaveformCache] getPeaksForEditor: visible=%.2fs -> tier=%s\n',
    visible_duration, tier))

  return M.requestTier(filepath, tier, callback)
end

-- Get peaks directly by filepath
function M.getPeaksByPath(filepath, tier)
  tier = tier or 'mini'
  if tier == 'full' then tier = 'medium' end

  local entry = cache[filepath]
  if entry and entry[tier] then
    return entry[tier]
  end
  return nil
end

-- Get best available peaks by filepath
function M.getBestPeaksByPath(filepath)
  local entry = cache[filepath]
  if not entry then return nil end

  -- Return highest available resolution
  for i = #M.TIER_ORDER, 1, -1 do
    local tier = M.TIER_ORDER[i]
    if entry[tier] then
      return entry[tier], tier
    end
  end
  return nil
end

-- Get filepath for a pad/layer
function M.getFilepath(pad_index, layer)
  layer = layer or 0
  return pad_to_file[pad_index] and pad_to_file[pad_index][layer]
end

-- Check if peaks are cached for a pad/layer
function M.hasPeaks(pad_index, layer)
  layer = layer or 0
  local filepath = pad_to_file[pad_index] and pad_to_file[pad_index][layer]
  if not filepath then return false end
  local entry = cache[filepath]
  return entry ~= nil and entry.mini ~= nil
end

-- Clear cache for specific pad/layer
function M.clearPeaks(pad_index, layer)
  if not pad_to_file[pad_index] then return end

  if layer then
    local filepath = pad_to_file[pad_index][layer]
    if filepath then
      cache[filepath] = nil
    end
    pad_to_file[pad_index][layer] = nil
  else
    -- Clear all layers for this pad
    for l, filepath in pairs(pad_to_file[pad_index]) do
      if filepath then
        cache[filepath] = nil
      end
    end
    pad_to_file[pad_index] = nil
  end
end

-- Clear entire cache
function M.clearAll()
  cache = {}
  pad_to_file = {}
  async_queue = {}
  async_current = nil
end

-- Check if async computation is in progress
function M.isProcessing()
  return async_active
end

-- Get async queue length
function M.getQueueLength()
  return #async_queue
end

-- Cancel pending async computations for a filepath
function M.cancelAsync(filepath)
  for i = #async_queue, 1, -1 do
    if async_queue[i].filepath == filepath then
      table.remove(async_queue, i)
    end
  end
end

-- Invalidate and recompute peaks
function M.invalidate(pad_index, layer)
  local filepath = pad_to_file[pad_index] and pad_to_file[pad_index][layer]
  M.clearPeaks(pad_index, layer)
  if filepath then
    return M.extractAndCache(pad_index, layer, filepath)
  end
  return false
end

-- ============================================================================
-- LEGACY/COMPAT - These don't do anything now but keep API compatible
-- ============================================================================

function M.setVST(track, fx)
  -- No longer needed - peaks computed from files directly
end

function M.clearVST()
  -- No longer needed
end

function M.hasVST()
  return true  -- Always "ready" since we compute locally
end

-- Get sample duration - need to compute from file
function M.getSampleDuration(pad_index, layer)
  layer = layer or 0
  local filepath = pad_to_file[pad_index] and pad_to_file[pad_index][layer]
  if not filepath then return 0 end

  local source = reaper.PCM_Source_CreateFromFile(filepath)
  if not source then return 0 end

  local length = reaper.GetMediaSourceLength(source)
  reaper.PCM_Source_Destroy(source)

  return length or 0
end

M.getPadDuration = M.getSampleDuration

return M
