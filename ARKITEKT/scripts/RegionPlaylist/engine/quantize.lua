-- @noindex
-- Arkitekt/features/region_playlist/engine/quantize.lua
-- Quantized transitions using trigger region hack
-- MODIFIED: Integrated Logger for debug output

local Logger = require("arkitekt.debug.logger")

-- Performance: Use VM operations instead of C function calls
-- floor(x) = x//1 (5-10% faster in loops)
-- ceil(n) = (n + 1 - n%1) (faster alternative)

local M = {}
local Quantize = {}
Quantize.__index = Quantize

local TRIGGER_REGION_NAME = "__TRANSITION_TRIGGER"

local function _is_playing(proj)
  proj = proj or 0
  local st = reaper.GetPlayStateEx(proj)
  return (st & 1) == 1
end

local function _get_play_pos(proj)
  return reaper.GetPlayPositionEx(proj or 0)
end

function M.new(opts)
  opts = opts or {}
  local self = setmetatable({}, Quantize)
  
  self.proj = opts.proj or 0
  self.state = opts.state
  self.transport = opts.transport
  
  self.quantize_mode = "measure"
  self.min_lookahead = 0.25
  self.max_lookahead = 3.0
  
  self.trigger_region = {
    rid = nil,
    marker_idx = nil,
    idle_position = 9999,
    is_active = false,
    target_rid = nil,
    fire_position = nil,
    last_playpos = nil,
  }
  
  return self
end

function Quantize:_ensure_trigger_region()
  local idx, num_markers = 0, reaper.CountProjectMarkers(self.proj)
  
  while idx < num_markers do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(idx)
    if retval > 0 then
      if isrgn and name == TRIGGER_REGION_NAME then
        self.trigger_region.rid = markrgnindexnumber
        self.trigger_region.marker_idx = idx
        return true
      end
    end
    idx = idx + 1
  end
  
  local color = 0
  local new_idx = reaper.AddProjectMarker2(
    self.proj,
    true,
    self.trigger_region.idle_position,
    self.trigger_region.idle_position + 1,
    TRIGGER_REGION_NAME,
    -1,
    color
  )
  
  if new_idx >= 0 then
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(new_idx)
    if retval > 0 then
      self.trigger_region.rid = markrgnindexnumber
      self.trigger_region.marker_idx = new_idx
      return true
    end
  end
  
  return false
end

function Quantize:_reposition_trigger_region(start_pos, end_pos)
  self:_ensure_trigger_region()
  
  if not self.trigger_region.marker_idx then
    return false
  end
  
  local retval = reaper.SetProjectMarkerByIndex2(
    self.proj,
    self.trigger_region.marker_idx,
    true,
    start_pos,
    end_pos,
    self.trigger_region.rid,
    TRIGGER_REGION_NAME,
    0,
    0
  )
  
  Logger.debug("QUANTIZE", "Moved trigger: [%.3f - %.3f] retval=%s", start_pos, end_pos, tostring(retval))
  
  return retval
end

function Quantize:_calculate_next_quantize_point(playpos, skip_count)
  skip_count = skip_count or 0
  
  if self.quantize_mode == "measure" then
    local retval, measures, cml, fullbeats, cdenom = reaper.TimeMap2_timeToBeats(self.proj, playpos)
    local next_measure_num = measures//1 + 1 + skip_count
    local next_time = reaper.TimeMap2_beatsToTime(self.proj, 0, next_measure_num)
    
    Logger.debug("QUANTIZE", "Mode=measure, skip=%d -> measure=%d (%.3fs)", skip_count, next_measure_num, next_time)
    
    return next_time
  elseif self.quantize_mode == "2bar" then
    local retval, measures, cml, fullbeats, cdenom = reaper.TimeMap2_timeToBeats(self.proj, playpos)

    -- Simply add 2 bars from current position (skip * 2 for additional cycles)
    local target_measure = measures + 2 + (skip_count * 2)
    local next_time = reaper.TimeMap2_beatsToTime(self.proj, 0, target_measure)

    Logger.debug("QUANTIZE", "Mode=2bar, current=%.3f -> target=%.3f (%.3fs)",
      measures, target_measure, next_time)

    return next_time
  elseif self.quantize_mode == "4bar" then
    local retval, measures, cml, fullbeats, cdenom = reaper.TimeMap2_timeToBeats(self.proj, playpos)

    -- Simply add 4 bars from current position (skip * 4 for additional cycles)
    local target_measure = measures + 4 + (skip_count * 4)
    local next_time = reaper.TimeMap2_beatsToTime(self.proj, 0, target_measure)

    Logger.debug("QUANTIZE", "Mode=4bar, current=%.3f -> target=%.3f (%.3fs)",
      measures, target_measure, next_time)

    return next_time
  elseif self.quantize_mode == "beat" then
    -- Quantize to next beat (1.0 grid division)
    local retval, measures, cml, fullbeats, cdenom = reaper.TimeMap2_timeToBeats(self.proj, playpos)
    local next_beat = fullbeats//1 + 1 + skip_count
    local next_time = reaper.TimeMap2_QNToTime(self.proj, next_beat)
    
    Logger.debug("QUANTIZE", "Mode=beat, skip=%d -> beat=%d (%.3fs)", skip_count, next_beat, next_time)
    
    return next_time
  else
    local grid_div = tonumber(self.quantize_mode)
    if not grid_div or grid_div <= 0 then
      return nil
    end
    
    local retval, measures, cml, fullbeats, cdenom = reaper.TimeMap2_timeToBeats(self.proj, playpos)
    local beat_in_measure = fullbeats - (measures//1 * cml)

    -- Use VM operation for ceil: -(-n//1)
    local next_beat_in_measure = -(-((beat_in_measure / grid_div))//1) * grid_div

    local target_measure = measures//1
    if next_beat_in_measure >= cml then
      target_measure = target_measure + 1
      next_beat_in_measure = 0
    end
    
    local total_skip = skip_count
    while total_skip > 0 do
      next_beat_in_measure = next_beat_in_measure + grid_div
      if next_beat_in_measure >= cml then
        target_measure = target_measure + 1
        next_beat_in_measure = next_beat_in_measure - cml
      end
      total_skip = total_skip - 1
    end
    
    local target_qn = (target_measure * cml) + next_beat_in_measure
    local next_time = reaper.TimeMap2_QNToTime(self.proj, target_qn)
    
    Logger.debug("QUANTIZE", "Mode=grid(%.4f), skip=%d -> m=%d b=%.3f qn=%.3f (%.3fs)", 
      grid_div, skip_count, target_measure, next_beat_in_measure, target_qn, next_time)
    
    return next_time
  end
end

function Quantize:set_quantize_mode(mode)
  self.quantize_mode = mode
end

function Quantize:get_quantize_mode()
  return self.quantize_mode
end

function Quantize:jump_to_next_quantized(lookahead)
  lookahead = lookahead or 0.05
  
  Logger.debug("QUANTIZE", "jump_to_next_quantized called")
  
  if not self.transport.is_playing then
    Logger.debug("QUANTIZE", "Not playing, fallback to next()")
    return self.transport:next()
  end
  
  if not self:_ensure_trigger_region() then
    Logger.warn("QUANTIZE", "Failed to ensure trigger region")
    return self.transport:next()
  end
  
  local playpos = _get_play_pos(self.proj)
  
  local next_quantize = self:_calculate_next_quantize_point(playpos, 0)
  
  if not next_quantize then
    Logger.warn("QUANTIZE", "Failed to calculate quantize point")
    return self.transport:next()
  end
  
  Logger.debug("QUANTIZE", "playpos=%.3f next_quantize=%.3f lookahead=%.3f", playpos, next_quantize, lookahead)
  
  local skip_count = 0
  while next_quantize - playpos < lookahead do
    skip_count = skip_count + 1
    next_quantize = self:_calculate_next_quantize_point(playpos, skip_count)
    
    if not next_quantize then
      Logger.warn("QUANTIZE", "Failed to calculate next quantize point")
      return self.transport:next()
    end
    
    if skip_count > 100 then
      Logger.error("QUANTIZE", "Too many skips, fallback to next()")
      return self.transport:next()
    end
  end
  
  if skip_count > 0 then
    Logger.debug("QUANTIZE", "Skipped %d grid points to: %.3f (safety margin: %.3fs)", 
      skip_count, next_quantize, next_quantize - playpos)
  end
  
  if self.state.current_bounds.end_pos > 0 and 
     next_quantize >= self.state.current_bounds.end_pos - 0.6 then
    Logger.debug("QUANTIZE", "Too close to region end, natural transition will happen")
    return
  end
  
  if self.state.next_idx < 1 or self.state.next_idx > #self.state.playlist_order then
    Logger.warn("QUANTIZE", "No valid next_idx")
    return false
  end
  
  local trigger_start = self.state.current_bounds.start_pos - 0.1
  local trigger_end = next_quantize
  
  if not self:_reposition_trigger_region(trigger_start, trigger_end) then
    Logger.error("QUANTIZE", "Failed to reposition trigger region")
    return false
  end
  
  local cursor_pos = reaper.GetCursorPositionEx(self.proj)
  
  Logger.debug("QUANTIZE", "Calling UpdateTimeline")
  reaper.UpdateTimeline()
  
  local target_region = self.state:get_region_by_rid(self.state.playlist_order[self.state.next_idx])
  if target_region then
    Logger.debug("QUANTIZE", "Queuing GoToRegion(%d)", target_region.rid)
    reaper.GoToRegion(self.proj, target_region.rid, false)
  end
  
  reaper.SetEditCurPos2(self.proj, cursor_pos, false, false)
  
  self.trigger_region.is_active = true
  self.trigger_region.target_rid = self.state.playlist_order[self.state.next_idx]
  self.trigger_region.fire_position = next_quantize
  self.trigger_region.last_playpos = playpos
  
  return true
end

function Quantize:update()
  if not self.trigger_region.is_active then
    return
  end
  
  if not self.transport.is_playing then
    Logger.debug("QUANTIZE", "update: Playback stopped, cleanup")
    self:_cleanup_trigger()
    return
  end
  
  local playpos = _get_play_pos(self.proj)
  
  if self.trigger_region.last_playpos and playpos < self.trigger_region.last_playpos - 0.2 then
    Logger.debug("QUANTIZE", "Backward seek detected, cleanup")
    self:_cleanup_trigger()
    return
  end
  
  self.trigger_region.last_playpos = playpos
  
  if self.trigger_region.target_rid then
    local target_region = self.state:get_region_by_rid(self.trigger_region.target_rid)
    if target_region then
      if playpos >= target_region.start and playpos < target_region["end"] then
        Logger.debug("QUANTIZE", "Entered target region rid=%d, cleanup", self.trigger_region.target_rid)
        self:_cleanup_trigger()
        return
      end
    end
  end
  
  if playpos >= self.trigger_region.fire_position and playpos < self.trigger_region.fire_position + 0.1 then
    Logger.info("QUANTIZE", "FIRING NOW: playpos=%.3f fire_pos=%.3f", playpos, self.trigger_region.fire_position)
    
    if self.trigger_region.target_rid then
      self.transport:_seek_to_region(self.trigger_region.target_rid)
    end
    
    self:_cleanup_trigger()
  elseif playpos >= self.trigger_region.fire_position + 0.1 then
    Logger.warn("QUANTIZE", "Missed trigger window, cleanup")
    self:_cleanup_trigger()
  end
end

function Quantize:_cleanup_trigger()
  if self.trigger_region.marker_idx then
    self:_reposition_trigger_region(
      self.trigger_region.idle_position,
      self.trigger_region.idle_position + 1
    )
  end
  
  self.trigger_region.is_active = false
  self.trigger_region.target_rid = nil
  self.trigger_region.fire_position = nil
  self.trigger_region.last_playpos = nil
end

M.Quantize = Quantize
return M
