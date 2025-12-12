-- @noindex
-- DrumBlocks/domain/transient_detector.lua
-- Transient detection algorithms for audio slicing

local M = {}

-- ============================================================================
-- ENERGY-BASED TRANSIENT DETECTION
-- ============================================================================

-- Detect transients from peak data using energy rise detection
-- @param peaks table Flat array in format [max1..maxN, min1..minN] (ARKITEKT waveform cache format)
-- @param opts table Options:
--   threshold: float (0-1) - sensitivity, lower = more transients (default 0.3)
--   min_distance: int - minimum samples between transients (default 10)
--   min_distance_normalized: float - minimum normalized distance (0-1), overrides min_distance if set
--   lookback: int - samples to average for baseline energy (default 3)
--   db_threshold: float - minimum dB level for transient (-60 to 0, default -60)
-- @return table Array of {index, position, strength, energy_db}
function M.detect_from_peaks(peaks, opts)
  opts = opts or {}
  local threshold = opts.threshold or 0.3
  local min_distance = opts.min_distance or 10
  local lookback = opts.lookback or 3
  local db_threshold = opts.db_threshold or -60

  if not peaks or #peaks < 4 then
    return {}
  end

  -- Peaks format: [max1..maxN, min1..minN]
  local num_peaks = #peaks // 2

  -- If min_distance_normalized is provided, convert to sample distance
  if opts.min_distance_normalized then
    min_distance = math.max(1, math.floor(opts.min_distance_normalized * num_peaks))
  end

  -- Convert dB threshold to linear amplitude
  local linear_threshold = 10 ^ (db_threshold / 20)

  local transients = {}
  local last_transient_idx = -min_distance

  -- Calculate energy for each peak
  local energies = {}
  local peak_amplitudes = {}
  for i = 1, num_peaks do
    -- peaks[i] = max value, peaks[num_peaks + i] = min value
    local max_val = peaks[i] or 0
    local min_val = peaks[num_peaks + i] or 0
    -- Energy = absolute sum of min and max (captures full amplitude)
    energies[i] = math.abs(min_val) + math.abs(max_val)
    -- Peak amplitude for dB check
    peak_amplitudes[i] = math.max(math.abs(max_val), math.abs(min_val))
  end

  -- Find energy rises
  for i = lookback + 1, num_peaks do
    -- Calculate average energy over lookback window
    local baseline = 0
    for j = i - lookback, i - 1 do
      baseline = baseline + energies[j]
    end
    baseline = baseline / lookback

    -- Calculate rise from baseline to current
    local current = energies[i]
    local rise = current - baseline

    -- Normalize rise relative to max possible (2.0 for normalized audio)
    local normalized_rise = rise / 2.0

    -- Check amplitude against dB threshold
    local amplitude = peak_amplitudes[i]
    local passes_db = amplitude >= linear_threshold

    -- Check if this is a transient
    if normalized_rise > threshold and (i - last_transient_idx) >= min_distance and passes_db then
      -- Calculate dB for reporting
      local energy_db = amplitude > 0 and (20 * math.log(amplitude) / math.log(10)) or -math.huge

      transients[#transients + 1] = {
        index = i,
        position = (i - 1) / (num_peaks - 1),  -- Normalized 0-1
        strength = normalized_rise,
        energy_db = energy_db,
      }
      last_transient_idx = i
    end
  end

  return transients
end

-- ============================================================================
-- GRID-BASED SLICING
-- ============================================================================

-- Generate slice points based on musical grid
-- @param duration float Sample duration in seconds
-- @param bpm float Tempo in beats per minute
-- @param division int Subdivision (1=whole, 2=half, 4=quarter, 8=eighth, 16=sixteenth)
-- @param offset float Optional start offset in seconds (default 0)
-- @return table Array of {position} normalized 0-1
function M.slice_by_grid(duration, bpm, division, offset)
  if not duration or duration <= 0 or not bpm or bpm <= 0 then
    return {}
  end

  offset = offset or 0
  division = division or 4  -- Default to quarter notes

  local beat_duration = 60.0 / bpm
  local slice_duration = beat_duration * (4.0 / division)  -- 4/division for musical divisions

  local slices = {}
  local pos = offset

  while pos < duration do
    if pos >= 0 then
      slices[#slices + 1] = {
        position = pos / duration,
        grid_aligned = true,
      }
    end
    pos = pos + slice_duration
  end

  return slices
end

-- ============================================================================
-- SLICE GENERATION FROM TRANSIENTS
-- ============================================================================

-- Convert transient points to slice regions
-- @param transients table Array of {position} from detection
-- @param opts table Options:
--   include_start: bool - include slice from 0 to first transient (default true)
--   include_end: bool - extend last slice to 1.0 (default true)
--   pre_roll: float - offset slice start before transient (0-0.1, default 0.005 = 0.5%)
--                     This captures the attack onset before the detected peak
-- @return table Array of {start, stop, transient_strength}
function M.transients_to_slices(transients, opts)
  opts = opts or {}
  local include_start = opts.include_start ~= false
  local include_end = opts.include_end ~= false
  local pre_roll = opts.pre_roll or 0.005  -- Default 0.5% pre-roll

  if not transients or #transients == 0 then
    -- No transients = one slice covering entire sample
    return {{ start = 0, stop = 1, transient_strength = 0 }}
  end

  local slices = {}

  -- Sort transients by position
  local sorted = {}
  for i, t in ipairs(transients) do
    sorted[i] = t
  end
  table.sort(sorted, function(a, b) return a.position < b.position end)

  -- Apply pre-roll to transient positions (shift back to capture attack)
  local adjusted = {}
  for i, t in ipairs(sorted) do
    adjusted[i] = {
      position = math.max(0, t.position - pre_roll),
      strength = t.strength,
      original_position = t.position,
    }
  end

  -- First slice: from start to first adjusted transient
  if include_start and adjusted[1].position > 0.001 then
    slices[#slices + 1] = {
      start = 0,
      stop = adjusted[1].position,
      transient_strength = 0,
    }
  end

  -- Middle slices: between adjusted transients
  for i = 1, #adjusted do
    local slice_start = adjusted[i].position
    local slice_stop

    if i < #adjusted then
      slice_stop = adjusted[i + 1].position
    elseif include_end then
      slice_stop = 1.0
    else
      slice_stop = slice_start + 0.01  -- Minimal slice
    end

    slices[#slices + 1] = {
      start = slice_start,
      stop = slice_stop,
      transient_strength = adjusted[i].strength or 0,
    }
  end

  return slices
end

-- ============================================================================
-- BPM DETECTION HELPERS
-- ============================================================================

-- Parse BPM from filename
-- Matches patterns like: "120bpm", "120_bpm", "120-bpm", "bpm120", "tempo120"
-- @param filename string
-- @return number|nil BPM if found
function M.parse_bpm_from_filename(filename)
  if not filename then return nil end

  local name = filename:lower()

  -- Pattern: number followed by "bpm"
  local bpm = name:match('(%d+)%s*bpm')
  if bpm then return tonumber(bpm) end

  -- Pattern: "bpm" followed by number
  bpm = name:match('bpm%s*(%d+)')
  if bpm then return tonumber(bpm) end

  -- Pattern: "tempo" followed by number
  bpm = name:match('tempo%s*(%d+)')
  if bpm then return tonumber(bpm) end

  -- Pattern: number in common BPM range with separator (e.g., "drum_loop_120_")
  -- Be more conservative here to avoid false positives
  bpm = name:match('[_%-](%d%d%d?)[_%-]')
  if bpm then
    local n = tonumber(bpm)
    if n and n >= 60 and n <= 200 then
      return n
    end
  end

  return nil
end

-- Estimate BPM from transient spacing
-- @param transients table Array of {position}
-- @param duration float Sample duration in seconds
-- @param opts table Options:
--   min_bpm: float (default 60)
--   max_bpm: float (default 200)
-- @return number|nil Estimated BPM
function M.estimate_bpm_from_transients(transients, duration, opts)
  opts = opts or {}
  local min_bpm = opts.min_bpm or 60
  local max_bpm = opts.max_bpm or 200

  if not transients or #transients < 2 or not duration or duration <= 0 then
    return nil
  end

  -- Calculate intervals between consecutive transients
  local intervals = {}
  for i = 2, #transients do
    local interval = (transients[i].position - transients[i-1].position) * duration
    if interval > 0 then
      intervals[#intervals + 1] = interval
    end
  end

  if #intervals == 0 then return nil end

  -- Find most common interval (simple histogram approach)
  -- Quantize to 10ms buckets
  local buckets = {}
  for _, interval in ipairs(intervals) do
    local bucket = math.floor(interval * 100 + 0.5)  -- 10ms resolution
    buckets[bucket] = (buckets[bucket] or 0) + 1
  end

  -- Find most common bucket
  local best_bucket, best_count = nil, 0
  for bucket, count in pairs(buckets) do
    if count > best_count then
      best_bucket = bucket
      best_count = count
    end
  end

  if not best_bucket then return nil end

  -- Convert interval back to BPM
  local interval_sec = best_bucket / 100
  local bpm = 60 / interval_sec

  -- Adjust to fit within expected range (could be half or double time)
  while bpm < min_bpm and bpm * 2 <= max_bpm do
    bpm = bpm * 2
  end
  while bpm > max_bpm and bpm / 2 >= min_bpm do
    bpm = bpm / 2
  end

  if bpm >= min_bpm and bpm <= max_bpm then
    return math.floor(bpm + 0.5)
  end

  return nil
end

-- ============================================================================
-- UTILITY
-- ============================================================================

-- Merge nearby slices
-- @param slices table Array of {start, stop}
-- @param min_duration float Minimum slice duration (normalized)
-- @return table Merged slices
function M.merge_short_slices(slices, min_duration)
  min_duration = min_duration or 0.05

  if not slices or #slices < 2 then
    return slices
  end

  local merged = {}
  local current = { start = slices[1].start, stop = slices[1].stop }

  for i = 2, #slices do
    local slice = slices[i]
    local current_duration = current.stop - current.start

    if current_duration < min_duration then
      -- Extend current slice to include next
      current.stop = slice.stop
    else
      -- Save current and start new
      merged[#merged + 1] = current
      current = { start = slice.start, stop = slice.stop }
    end
  end

  -- Don't forget last slice
  merged[#merged + 1] = current

  return merged
end

-- Adjust slice boundaries to zero crossings (if peak data available)
-- This helps reduce clicks at slice boundaries
-- @param slices table Array of {start, stop}
-- @param peaks table Flat array in format [max1..maxN, min1..minN]
-- @param search_range int Samples to search for zero crossing (default 5)
-- @return table Adjusted slices
function M.snap_to_zero_crossings(slices, peaks, search_range)
  search_range = search_range or 5

  if not slices or not peaks or #peaks < 4 then
    return slices
  end

  local num_peaks = #peaks // 2

  local function find_zero_crossing(pos)
    local idx = math.floor(pos * (num_peaks - 1)) + 1
    local best_idx = idx
    local best_energy = math.huge

    for offset = -search_range, search_range do
      local check_idx = idx + offset
      if check_idx >= 1 and check_idx <= num_peaks then
        local max_val = peaks[check_idx] or 0
        local min_val = peaks[num_peaks + check_idx] or 0
        local energy = math.abs(min_val) + math.abs(max_val)
        if energy < best_energy then
          best_energy = energy
          best_idx = check_idx
        end
      end
    end

    return (best_idx - 1) / (num_peaks - 1)
  end

  local adjusted = {}
  for i, slice in ipairs(slices) do
    adjusted[i] = {
      start = find_zero_crossing(slice.start),
      stop = slice.stop,  -- Only adjust start points
      transient_strength = slice.transient_strength,
    }
  end

  return adjusted
end

return M
