-- @noindex
-- ReArkitekt/features/region_playlist/engine/transitions.lua
-- Smooth transition logic between regions - FIXED: Handle same-region repeats with time-based transitions

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
  
  reaper.ShowConsoleMsg(string.format("[TRANS] playpos=%.3f curr_idx=%d next_idx=%d curr_bounds=[%.3f-%.3f] next_bounds=[%.3f-%.3f]\n",
    playpos, self.state.current_idx, self.state.next_idx,
    self.state.current_bounds.start_pos, self.state.current_bounds.end_pos,
    self.state.next_bounds.start_pos, self.state.next_bounds.end_pos))
  
  -- Check if current and next are the same physical region (repeating)
  local curr_rid = self.state.current_idx >= 1 and self.state.playlist_order[self.state.current_idx] or nil
  local next_rid = self.state.next_idx >= 1 and self.state.playlist_order[self.state.next_idx] or nil
  local is_same_region = (curr_rid == next_rid and curr_rid ~= nil)
  
  -- Branch 1: In next_bounds region - EXECUTE THE TRANSITION
  -- BUT: Skip this if current and next are the same region (use time-based instead)
  if self.state.next_idx >= 1 and 
     not is_same_region and
     playpos >= self.state.next_bounds.start_pos and 
     playpos < self.state.next_bounds.end_pos + self.state.boundary_epsilon then
    
    reaper.ShowConsoleMsg("[TRANS] Branch 1: In next_bounds (different region)\n")
    
    local entering_different_region = (self.state.current_idx ~= self.state.next_idx)
    local playhead_went_backward = (playpos < self.state.last_play_pos - 0.1)
    
    if entering_different_region or playhead_went_backward then
      reaper.ShowConsoleMsg(string.format("[TRANS] TRANSITION FIRING: %d -> %d\n", 
        self.state.current_idx, self.state.next_idx))
      
      self.state.current_idx = self.state.next_idx
      self.state.playlist_pointer = self.state.current_idx
      local rid = self.state.playlist_order[self.state.current_idx]
      local region = self.state:get_region_by_rid(rid)
      if region then
        self.state.current_bounds.start_pos = region.start
        self.state.current_bounds.end_pos = region["end"]
      end
      
      local meta = self.state.playlist_metadata[self.state.current_idx]
      
      -- Fire repeat cycle callback for UI updates
      if self.on_repeat_cycle and meta and meta.key and meta.loop and meta.total_loops and meta.loop > 1 then
        self.on_repeat_cycle(meta.key, meta.loop, meta.total_loops)
      end
      
      -- Always advance to next sequence entry (repeats are already in sequence)
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
          -- Queue GoToRegion only when transition is imminent
          self:_queue_next_region_if_near_end(playpos)
        end
      else
        self.state.next_idx = -1
        reaper.ShowConsoleMsg("[TRANS] No next candidate\n")
      end
    end
    
  -- Branch 2: In current_bounds region - CHECK IF NEAR END or handle same-region repeats
  elseif self.state.current_bounds.end_pos > self.state.current_bounds.start_pos and
         playpos >= self.state.current_bounds.start_pos and 
         playpos < self.state.current_bounds.end_pos + self.state.boundary_epsilon then
    
    -- For same-region repeats, use time-based transition at the end
    if is_same_region and self.state.next_idx >= 1 then
      local time_to_end = self.state.current_bounds.end_pos - playpos
      
      -- Transition when we're very close to the end (within 0.05 seconds)
      if time_to_end <= 0.05 and time_to_end >= -0.01 then
        reaper.ShowConsoleMsg(string.format("[TRANS] TIME-BASED TRANSITION (same region): %d -> %d\n", 
          self.state.current_idx, self.state.next_idx))
        
        self.state.current_idx = self.state.next_idx
        self.state.playlist_pointer = self.state.current_idx
        
        local meta = self.state.playlist_metadata[self.state.current_idx]
        
        -- Fire repeat cycle callback for UI updates
        if self.on_repeat_cycle and meta and meta.key and meta.loop and meta.total_loops and meta.loop > 1 then
          self.on_repeat_cycle(meta.key, meta.loop, meta.total_loops)
        end
        
        -- Advance to next entry
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
        -- Queue GoToRegion only when close to end
        self:_queue_next_region_if_near_end(playpos)
      end
    else
      -- Normal case: different region, just queue GoToRegion
      self:_queue_next_region_if_near_end(playpos)
    end
    
  -- Branch 3: Neither - need to sync
  else
    reaper.ShowConsoleMsg("[TRANS] Branch 3: Out of bounds, syncing\n")
    local found_idx = self.state:find_index_at_position(playpos)
    reaper.ShowConsoleMsg(string.format("[TRANS] find_index_at_position(%.3f) returned: %d\n", playpos, found_idx))
    
    if found_idx >= 1 then
      local was_uninitialized = (self.state.current_idx == -1)
      
      -- Find the FIRST entry at this position (in case of repeats)
      local first_idx_at_pos = found_idx
      reaper.ShowConsoleMsg(string.format("[TRANS] Checking for earlier entries with same rid as idx %d (rid=%d)\n", 
        found_idx, self.state.playlist_order[found_idx]))
      
      for i = 1, found_idx - 1 do
        local rid = self.state.playlist_order[i]
        reaper.ShowConsoleMsg(string.format("[TRANS]   idx %d: rid=%d\n", i, rid))
        if rid == self.state.playlist_order[found_idx] then
          first_idx_at_pos = i
          reaper.ShowConsoleMsg(string.format("[TRANS] Found earlier match! Using idx %d instead of %d\n", i, found_idx))
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
      
      -- Always advance to next entry (no looping within transitions)
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
  -- Only queue GoToRegion when within 0.5 seconds of current region end
  local time_to_end = self.state.current_bounds.end_pos - playpos
  
  if time_to_end < 0.5 and time_to_end > 0 and self.state.next_idx >= 1 then
    if not self.state.goto_region_queued or self.state.goto_region_target ~= self.state.next_idx then
      local rid = self.state.playlist_order[self.state.next_idx]
      local region = self.state:get_region_by_rid(rid)
      if region then
        -- CRITICAL: ALWAYS queue GoToRegion, even for same-region repeats
        -- The playhead must jump back to the start of the region
        reaper.ShowConsoleMsg(string.format("[TRANS] Queuing GoToRegion(%d) - %.2fs to end\n", region.rid, time_to_end))
        self.transport:_seek_to_region(region.rid)
        self.state.goto_region_queued = true
        self.state.goto_region_target = self.state.next_idx
      end
    end
  elseif time_to_end > 0.5 then
    -- Reset if we're far from end (allows quantize to work)
    self.state.goto_region_queued = false
    self.state.goto_region_target = nil
  end
end

M.Transitions = Transitions
return M
