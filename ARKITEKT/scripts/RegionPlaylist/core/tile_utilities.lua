-- @noindex
-- Arkitekt/gui/systems/tile_utilities.lua

local M = {}

function M.format_bar_length(start_time, end_time, proj)
  proj = proj or 0

  -- Rounding tolerance to fix floating-point precision issues
  -- (e.g., 84.0999999 becomes 84.1, displayed as 84.1.00 instead of 84.0.99)
  local ROUNDING_TOLERANCE = 0.005

  local duration = end_time - start_time
  if duration <= 0 then
    return "0.0.00"
  end

  local start_qn = reaper.TimeMap2_timeToQN(proj, start_time)
  local end_qn = reaper.TimeMap2_timeToQN(proj, end_time)
  local total_qn = end_qn - start_qn

  if total_qn <= 0 then
    local bpm = reaper.Master_GetTempo()
    local _, time_sig_num = reaper.GetSetProjectGrid(proj, false)
    if not time_sig_num or time_sig_num == 0 then
      time_sig_num = 4
    end
    local beats_per_second = bpm / 60.0
    total_qn = duration * beats_per_second
  end

  local _, time_sig_num = reaper.TimeMap_GetTimeSigAtTime(proj, start_time)
  if not time_sig_num or time_sig_num == 0 then
    time_sig_num = 4
  end

  -- Apply rounding tolerance: round to nearest 0.01 QN if within tolerance
  local rounded_qn = math.floor(total_qn * 100 + 0.5) / 100
  if math.abs(total_qn - rounded_qn) < ROUNDING_TOLERANCE then
    total_qn = rounded_qn
  end

  local bars = math.floor(total_qn / time_sig_num)
  local remaining_qn = total_qn - (bars * time_sig_num)
  local beats = math.floor(remaining_qn)
  local hundredths = math.floor((remaining_qn - beats) * 100 + 0.5)

  -- Handle edge case where rounding hundredths gives 100
  if hundredths >= 100 then
    hundredths = 0
    beats = beats + 1
    if beats >= time_sig_num then
      beats = 0
      bars = bars + 1
    end
  end

  return string.format("%d.%d.%02d", bars, beats, hundredths)
end

return M