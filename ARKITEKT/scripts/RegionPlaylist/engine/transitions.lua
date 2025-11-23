-- @noindex
-- Arkitekt/features/region_playlist/engine/transitions.lua
-- Smooth transition logic between regions - FIXED: Handle same-region repeats with time-based transitions
-- MODIFIED: Integrated Logger for debug output

local Logger = require("arkitekt.debug.logger")

local M = {}
local Transitions = {}
Transitions.__index = Transitions

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
  local self = setmetatable({}, Transitions)
  
  self.proj = opts.proj or 0
  self.state = opts.state
  self.transport = opts.transport
  self.on_repeat_cycle = opts.on_repeat_cycle
  
  return self
end

function Transitions:handle_smooth_transitions()
  if not _is_playing(self.proj) then return end
  if #self.state.playlist_order == 0 then return end
  
  local playpos = _get_play_pos(self.proj)
  
  Logger.debug("TRANSITIONS", "playpos=%.3f curr_idx=%d next_idx=%d curr_bounds=[%.3f-%.3f] next_bounds=[%.3f-%.3f]",
    playpos, self.state.current_idx, self.state.next_idx,
    self.state.current_bounds.start_pos, self.state.current_bounds.end_pos,
    self.state.next_bounds.start_pos, self.state.next_bounds.end_pos)
  
  local curr_rid = self.state.current_idx >= 1 and self.state.playlist_order[self.state.current_idx] or nil
  local next_rid = self.state.next_idx >= 1 and self.state.playlist_order[self.state.next_idx] or nil
  local is_same_region = (curr_rid == next_rid and curr_rid ~= nil)
  
  if self.state.next_idx >= 1 and 
     not is_same_region and
     playpos >= self.state.next_bounds.start_pos and 
     playpos < self.state.next_bounds.end_pos + self.state.boundary_epsilon then
    
    Logger.debug("TRANSITIONS", "Branch 1: In next_bounds (different region)")
    
    local entering_different_region = (self.state.current_idx ~= self.state.next_idx)
    local playhead_went_backward = (playpos < self.state.last_play_pos - 0.1)
    
    if entering_different_region or playhead_went_backward then
      Logger.info("TRANSITIONS", "TRANSITION FIRING: %d -> %d", self.state.current_idx, self.state.next_idx)
      
      self.state.current_idx = self.state.next_idx
      self.state.playlist_pointer = self.state.current_idx
      local rid = self.state.playlist_order[self.state.current_idx]
      local region = self.state:get_region_by_rid(rid)
      if region then
        self.state.current_bounds.start_pos = region.start
        self.state.current_bounds.end_pos = region["end"]
      end
      
      local meta = self.state.playlist_metadata[self.state.current_idx]
      
      if self.on_repeat_cycle and meta and meta.key and meta.loop and meta.total_loops and meta.loop > 1 then
        self.on_repeat_cycle(meta.key, meta.loop, meta.total_loops)
      end
      
      local next_candidate
      if self.state.current_idx < #self.state.playlist_order then
        next_candidate = self.state.current_idx + 1
      elseif self.transport.loop_playlist and #self.state.playlist_order > 0 then
        next_candidate = 1
      else
        next_candidate = -1
      end
      
      if next_candidate >= 1 then
        self.state.next_idx = next_candidate
        local rid = self.state.playlist_order[self.state.next_idx]
        local region = self.state:get_region_by_rid(rid)
        if region then
          self.state.next_bounds.start_pos = region.start
          self.state.next_bounds.end_pos = region["end"]
          self:_queue_next_region_if_near_end(playpos)
        end
      else
        self.state.next_idx = -1
        Logger.info("TRANSITIONS", "No next candidate")
      end
    end
    
  elseif self.state.current_bounds.end_pos > self.state.current_bounds.start_pos and
         playpos >= self.state.current_bounds.start_pos and 
         playpos < self.state.current_bounds.end_pos + self.state.boundary_epsilon then
    
    if is_same_region and self.state.next_idx >= 1 then
      local time_to_end = self.state.current_bounds.end_pos - playpos
      
      if time_to_end <= 0.05 and time_to_end >= -0.01 then
        Logger.info("TRANSITIONS", "TIME-BASED TRANSITION (same region): %d -> %d", self.state.current_idx, self.state.next_idx)
        
        self.state.current_idx = self.state.next_idx
        self.state.playlist_pointer = self.state.current_idx
        
        local meta = self.state.playlist_metadata[self.state.current_idx]
        
        if self.on_repeat_cycle and meta and meta.key and meta.loop and meta.total_loops and meta.loop > 1 then
          self.on_repeat_cycle(meta.key, meta.loop, meta.total_loops)
        end
        
        local next_candidate
        if self.state.current_idx < #self.state.playlist_order then
          next_candidate = self.state.current_idx + 1
        elseif self.transport.loop_playlist and #self.state.playlist_order > 0 then
          next_candidate = 1
        else
          next_candidate = -1
        end
        
        if next_candidate >= 1 then
          self.state.next_idx = next_candidate
          local rid = self.state.playlist_order[self.state.next_idx]
          local region = self.state:get_region_by_rid(rid)
          if region then
            self.state.next_bounds.start_pos = region.start
            self.state.next_bounds.end_pos = region["end"]
          end
        else
          self.state.next_idx = -1
        end
      else
        self:_queue_next_region_if_near_end(playpos)
      end
    else
      self:_queue_next_region_if_near_end(playpos)
    end
    
  else
    Logger.debug("TRANSITIONS", "Branch 3: Out of bounds, syncing")
    local found_idx = self.state:find_index_at_position(playpos)
    Logger.debug("TRANSITIONS", "find_index_at_position(%.3f) returned: %d", playpos, found_idx)
    
    if found_idx >= 1 then
      local was_uninitialized = (self.state.current_idx == -1)
      
      local first_idx_at_pos = found_idx
      Logger.debug("TRANSITIONS", "Checking for earlier entries with same rid as idx %d (rid=%d)", 
        found_idx, self.state.playlist_order[found_idx])
      
      for i = 1, found_idx - 1 do
        local rid = self.state.playlist_order[i]
        Logger.debug("TRANSITIONS", "  idx %d: rid=%d", i, rid)
        if rid == self.state.playlist_order[found_idx] then
          first_idx_at_pos = i
          Logger.debug("TRANSITIONS", "Found earlier match! Using idx %d instead of %d", i, found_idx)
          break
        end
      end
      
      self.state.current_idx = first_idx_at_pos
      self.state.playlist_pointer = first_idx_at_pos
      local rid = self.state.playlist_order[first_idx_at_pos]
      local region = self.state:get_region_by_rid(rid)
      if region then
        self.state.current_bounds.start_pos = region.start
        self.state.current_bounds.end_pos = region["end"]
      end
      
      local next_candidate
      if first_idx_at_pos < #self.state.playlist_order then
        next_candidate = first_idx_at_pos + 1
      elseif self.transport.loop_playlist and #self.state.playlist_order > 0 then
        next_candidate = 1
      else
        next_candidate = -1
      end
      
      if next_candidate >= 1 then
        self.state.next_idx = next_candidate
        local rid_next = self.state.playlist_order[self.state.next_idx]
        local region_next = self.state:get_region_by_rid(rid_next)
        if region_next then
          self.state.next_bounds.start_pos = region_next.start
          self.state.next_bounds.end_pos = region_next["end"]
          
          if was_uninitialized then
            self:_queue_next_region_if_near_end(playpos)
          end
        end
      else
        self.state.next_idx = -1
      end
    elseif #self.state.playlist_order > 0 then
      local first_region = self.state:get_region_by_rid(self.state.playlist_order[1])
      if first_region and playpos < first_region.start then
        self.state.current_idx = -1
        self.state.next_idx = 1
        self.state.next_bounds.start_pos = first_region.start
        self.state.next_bounds.end_pos = first_region["end"]
      end
    end
  end
  
  self.state.last_play_pos = playpos
end

function Transitions:_queue_next_region_if_near_end(playpos)
  local time_to_end = self.state.current_bounds.end_pos - playpos
  
  if time_to_end < 0.5 and time_to_end > 0 and self.state.next_idx >= 1 then
    if not self.state.goto_region_queued or self.state.goto_region_target ~= self.state.next_idx then
      local rid = self.state.playlist_order[self.state.next_idx]
      local region = self.state:get_region_by_rid(rid)
      if region then
        Logger.info("TRANSPORT", "Queuing GoToRegion(%d) - %.2fs to end", region.rid, time_to_end)
        self.transport:_seek_to_region(region.rid)
        self.state.goto_region_queued = true
        self.state.goto_region_target = self.state.next_idx
      end
    end
  elseif time_to_end > 0.5 then
    self.state.goto_region_queued = false
    self.state.goto_region_target = nil
  end
end

M.Transitions = Transitions
return M
