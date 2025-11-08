-- @noindex
-- ReArkitekt/features/region_playlist/engine/transitions.lua
-- Smooth transition logic between regions - FIXED to delay GoToRegion

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
  
  -- Check if current and next are TRUE duplicates (same item being repeated)
  -- Not just the same region from different playlist items
  local is_true_duplicate = false
  if self.state.current_idx >= 1 and self.state.next_idx >= 1 and 
     self.state.current_idx ~= self.state.next_idx then
    local curr_rid = self.state.playlist_order[self.state.current_idx]
    local next_rid = self.state.playlist_order[self.state.next_idx]
    
    -- Only consider it a duplicate if they share the same item (check metadata)
    local curr_meta = self.state.playlist_metadata[self.state.current_idx]
    local next_meta = self.state.playlist_metadata[self.state.next_idx]
    
    -- DEBUG: Show what we're comparing
    reaper.ShowConsoleMsg(string.format("[TRANS] DEBUG: curr_rid=%d next_rid=%d\n", curr_rid, next_rid))
    if curr_meta then
      reaper.ShowConsoleMsg(string.format("[TRANS] DEBUG: curr_meta.key=%s\n", tostring(curr_meta.key)))
    else
      reaper.ShowConsoleMsg("[TRANS] DEBUG: curr_meta is NIL\n")
    end
    if next_meta then
      reaper.ShowConsoleMsg(string.format("[TRANS] DEBUG: next_meta.key=%s\n", tostring(next_meta.key)))
    else
      reaper.ShowConsoleMsg("[TRANS] DEBUG: next_meta is NIL\n")
    end
    
    if curr_rid == next_rid and curr_meta and next_meta and 
       curr_meta.key == next_meta.key then
      is_true_duplicate = true
      reaper.ShowConsoleMsg(string.format("[TRANS] True duplicate detected (same item key: %s)\n", curr_meta.key))
    elseif curr_rid == next_rid then
      reaper.ShowConsoleMsg("[TRANS] DEBUG: Same RID but different keys - will transition normally\n")
    end
  end
  
  -- Branch 1: In next_bounds region - EXECUTE THE TRANSITION
  if self.state.next_idx >= 1 and 
     playpos >= self.state.next_bounds.start_pos and 
     playpos < self.state.next_bounds.end_pos + self.state.boundary_epsilon then
    
    reaper.ShowConsoleMsg("[TRANS] Branch 1: In next_bounds\n")
    
    local entering_different_region = (self.state.current_idx ~= self.state.next_idx)
    local playhead_went_backward = (playpos < self.state.last_play_pos - 0.1)
    
    -- For true duplicates (same item repeated), force transition when near the end
    local force_transition_for_duplicate = false
    if is_true_duplicate and entering_different_region then
      local time_to_end = self.state.current_bounds.end_pos - playpos
      if time_to_end < 0.1 then
        force_transition_for_duplicate = true
        reaper.ShowConsoleMsg("[TRANS] Forcing transition for true duplicate\n")
      end
    end
    
    if entering_different_region or playhead_went_backward or force_transition_for_duplicate then
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
      
      -- Check if should loop current item
      if meta and meta.current_loop < meta.reps then
        meta.current_loop = meta.current_loop + 1
        
        if self.on_repeat_cycle and meta.key then
          self.on_repeat_cycle(meta.key, meta.current_loop, meta.reps)
        end
        
        self.state.next_idx = self.state.current_idx
        local rid = self.state.playlist_order[self.state.current_idx]
        local region = self.state:get_region_by_rid(rid)
        if region then
          self.state.next_bounds.start_pos = region.start
          self.state.next_bounds.end_pos = region["end"]
          -- Queue GoToRegion only when transition is imminent
          self:_queue_next_region_if_near_end(playpos)
        end
      else
        -- Advance to next item
        if meta then
          meta.current_loop = 1
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
            -- Queue GoToRegion only when transition is imminent
            self:_queue_next_region_if_near_end(playpos)
          end
        else
          self.state.next_idx = -1
          reaper.ShowConsoleMsg("[TRANS] No next candidate\n")
        end
      end
    end
    
  -- Branch 2: In current_bounds region - CHECK IF NEAR END
  elseif self.state.current_bounds.end_pos > self.state.current_bounds.start_pos and
         playpos >= self.state.current_bounds.start_pos and 
         playpos < self.state.current_bounds.end_pos + self.state.boundary_epsilon then
    
    -- Queue GoToRegion only when close to end
    self:_queue_next_region_if_near_end(playpos)
    
  -- Branch 3: Neither - need to sync
  else
    reaper.ShowConsoleMsg("[TRANS] Branch 3: Out of bounds, syncing\n")
    local found_idx = self.state:find_index_at_position(playpos)
    if found_idx >= 1 then
      local was_uninitialized = (self.state.current_idx == -1)
      
      self.state.current_idx = found_idx
      self.state.playlist_pointer = found_idx
      local rid = self.state.playlist_order[found_idx]
      local region = self.state:get_region_by_rid(rid)
      if region then
        self.state.current_bounds.start_pos = region.start
        self.state.current_bounds.end_pos = region["end"]
      end
      
      local meta = self.state.playlist_metadata[found_idx]
      local should_advance = not meta or meta.current_loop >= meta.reps
      
      if should_advance then
        local next_candidate
        if found_idx < #self.state.playlist_order then
          next_candidate = found_idx + 1
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
        end
      else
        self.state.next_idx = found_idx
        self.state.next_bounds.start_pos = region.start
        self.state.next_bounds.end_pos = region["end"]
        if was_uninitialized then
          self:_queue_next_region_if_near_end(playpos)
        end
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
    -- Check if current and next are TRUE duplicates (same item, not just same region)
    local curr_rid = self.state.playlist_order[self.state.current_idx]
    local next_rid = self.state.playlist_order[self.state.next_idx]
    
    local curr_meta = self.state.playlist_metadata[self.state.current_idx]
    local next_meta = self.state.playlist_metadata[self.state.next_idx]
    
    local is_true_duplicate = false
    if curr_rid == next_rid and self.state.current_idx ~= self.state.next_idx and
       curr_meta and next_meta and curr_meta.key == next_meta.key then
      is_true_duplicate = true
    end
    
    if is_true_duplicate then
      -- For true duplicates (same item repeated), don't queue GoToRegion (playhead won't move)
      -- Instead, let the transition happen based on sequence position
      reaper.ShowConsoleMsg(string.format("[TRANS] Skipping GoToRegion for true duplicate (key: %s, idx %d->%d)\n", 
        curr_meta.key, self.state.current_idx, self.state.next_idx))
      self.state.goto_region_queued = true
      self.state.goto_region_target = self.state.next_idx
    elseif not self.state.goto_region_queued or self.state.goto_region_target ~= self.state.next_idx then
      local region = self.state:get_region_by_rid(next_rid)
      if region then
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