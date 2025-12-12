-- @noindex
-- RegionPlaylist/domain/playback/state.lua
-- Sequence-driven state management for region playlist engine

local Regions = require('arkitekt.reaper.regions')
local Transport = require('arkitekt.reaper.transport')
local Logger = require('arkitekt.debug.logger')

-- Performance: Localize math and table functions for hot loops (region lookup, shuffling)
local max = math.max
local min = math.min
local floor = math.floor
local random = math.random
local insert = table.insert

-- Set to true for verbose sequence building logs
local DEBUG_SEQUENCE = false

local M = {}
local State = {}
State.__index = State

package.loaded['RegionPlaylist.domain.playback.state'] = M

function M.new(opts)
  opts = opts or {}
  local self = setmetatable({}, State)

  self.proj = opts.proj or 0

  self.region_cache = {}
  self.state_change_count = 0

  self.sequence = {}
  self.sequence_lookup_by_key = {}
  self.sequence_version = 0

  self.playlist_order = {}
  self.playlist_metadata = {}
  self.playlist_pointer = 1
  
  self.current_idx = -1
  self.next_idx = -1
  self.current_bounds = {start_pos = 0, end_pos = -1}
  self.next_bounds = {start_pos = 0, end_pos = -1}
  self.last_play_pos = -1

  self.boundary_epsilon = 0.01

  self.goto_region_queued = false
  self.goto_region_target = nil

  self._shuffle_enabled = false
  self._shuffle_mode = 'true_shuffle'  -- 'true_shuffle' or 'random'
  self._shuffle_seed = nil
  self._last_random_index = nil  -- For random mode to avoid consecutive repeats

  self:rescan()

  return self
end

function State:rescan()
  local regions = Regions.scan_project_regions(self.proj)

  self.region_cache = {}
  for _, rgn in ipairs(regions) do
    self.region_cache[rgn.rid] = rgn
  end

  self.state_change_count = Transport.get_project_state_change_count(self.proj)

  if self.sequence and #self.sequence > 0 then
    local sequence_copy = {}
    for _, entry in ipairs(self.sequence) do
      sequence_copy[#sequence_copy + 1] = {
        rid = entry.rid,
        item_key = entry.item_key,
        loop = entry.loop,
        total_loops = entry.total_loops,
        is_infinite = entry.is_infinite,
        ancestry = entry.ancestry,  -- Preserve ancestry for nested playlist tracking
      }
    end
    self:set_sequence(sequence_copy)
  end
end

function State:check_for_changes()
  local current_state = Transport.get_project_state_change_count(self.proj)
  if current_state ~= self.state_change_count then
    self:rescan()
    return true
  end
  return false
end

function State:set_order(new_order)
  local sequence = {}
  for _, entry in ipairs(new_order or {}) do
    if type(entry) == 'table' then
      local rid = entry.rid
      if rid then
        local reps = tonumber(entry.reps) or 1
        reps = max(1, reps // 1)
        local key = entry.key
        for loop_index = 1, reps do
          sequence[#sequence + 1] = {
            rid = rid,
            item_key = key,
            loop = loop_index,
            total_loops = reps,
          }
        end
      end
    elseif entry then
      sequence[#sequence + 1] = {
        rid = entry,
        item_key = nil,
        loop = 1,
        total_loops = 1,
      }
    end
  end

  self:set_sequence(sequence)
end

function State:set_sequence(sequence)
  sequence = sequence or {}

  local previous_pointer_key = nil
  local previous_current = nil
  local previous_next = nil

  if self.playlist_pointer >= 1 and self.playlist_pointer <= #self.sequence then
    previous_pointer_key = self.sequence[self.playlist_pointer].item_key
  end

  if self.current_idx and self.current_idx >= 1 and self.current_idx <= #self.sequence then
    previous_current = self.sequence[self.current_idx]
  end

  if self.next_idx and self.next_idx >= 1 and self.next_idx <= #self.sequence then
    previous_next = self.sequence[self.next_idx]
  end

  self.sequence = {}
  self.playlist_order = {}
  self.playlist_metadata = {}
  self.sequence_lookup_by_key = {}

  if DEBUG_SEQUENCE then Logger.debug('STATE', 'Building sequence from %d entries...', #sequence) end
  for _, entry in ipairs(sequence) do
    local rid = entry.rid
    if rid and self.region_cache[rid] then
      -- Handle infinite loops: total_loops = 0 means infinite
      local is_infinite = entry.is_infinite or (entry.total_loops == 0)
      local total_loops = is_infinite and 0 or max(1, (entry.total_loops or 1) // 1)
      local loop_val = max(1, (entry.loop or 1) // 1)

      local normalized = {
        rid = rid,
        item_key = entry.item_key,
        loop = loop_val,
        total_loops = total_loops,
        is_infinite = is_infinite,
        ancestry = entry.ancestry,  -- Preserve ancestry for nested playlist tracking
      }
      -- For non-infinite, clamp loop to total_loops
      if not is_infinite and normalized.loop > normalized.total_loops then
        normalized.loop = normalized.total_loops
      end

      if DEBUG_SEQUENCE then
        Logger.debug('STATE', '✓ Entry #%d: rid=%d key=%s loop=%d/%d',
          #self.sequence + 1, rid, tostring(entry.item_key), normalized.loop, normalized.total_loops)
      end

      self.sequence[#self.sequence + 1] = normalized
      self.playlist_order[#self.playlist_order + 1] = rid

      self.playlist_metadata[#self.playlist_metadata + 1] = {
        key = normalized.item_key,
        reps = 1,
        current_loop = 1,
        loop = normalized.loop,
        total_loops = normalized.total_loops,
      }

      if normalized.item_key and not self.sequence_lookup_by_key[normalized.item_key] then
        self.sequence_lookup_by_key[normalized.item_key] = #self.sequence
        if DEBUG_SEQUENCE then Logger.debug('STATE', "Lookup: '%s' -> idx %d", normalized.item_key, #self.sequence) end
      end
    else
      Logger.warn('STATE', '✗ DROPPED: rid=%s (not in region_cache) key=%s', tostring(rid), tostring(entry.item_key))
    end
  end
  Logger.info('STATE', 'Sequence built: %d items', #self.sequence)

  -- Apply shuffle if enabled (before resolving pointers)
  if self._shuffle_enabled and #self.sequence > 1 then
    self:_apply_shuffle()
    Logger.info('STATE', 'Shuffle applied to sequence')
  end

  if DEBUG_SEQUENCE then
    Logger.debug('STATE', 'playlist_order:')
    for i, rid in ipairs(self.playlist_order) do
      Logger.debug('STATE', '  [%d] rid=%d', i, rid)
    end
  end

  local function resolve_index_by_entry(entry)
    if not entry then return nil end
    if entry.item_key and self.sequence_lookup_by_key[entry.item_key] then
      return self.sequence_lookup_by_key[entry.item_key]
    end

    for idx, seq_entry in ipairs(self.sequence) do
      if seq_entry.rid == entry.rid and seq_entry.loop == (entry.loop or 1) then
        return idx
      end
    end
    return nil
  end

  local resolved_pointer = previous_pointer_key and self.sequence_lookup_by_key[previous_pointer_key] or nil

  if resolved_pointer then
    self.playlist_pointer = resolved_pointer
  elseif #self.sequence > 0 then
    self.playlist_pointer = self:_clamp(self.playlist_pointer, 1, #self.sequence)
  else
    self.playlist_pointer = 1
  end

  local resolved_current = resolve_index_by_entry(previous_current)
  if resolved_current then
    self.current_idx = resolved_current
  elseif #self.sequence == 0 then
    self.current_idx = -1
  else
    self.current_idx = min(self.current_idx or -1, #self.sequence)
  end

  local resolved_next = resolve_index_by_entry(previous_next)
  if resolved_next then
    self.next_idx = resolved_next
  elseif #self.sequence == 0 then
    self.next_idx = -1
  else
    self.next_idx = min(self.next_idx or -1, #self.sequence)
    if self.next_idx < 1 then
      self.next_idx = (#self.sequence >= 1) and 1 or -1
    end
  end

  if #self.sequence == 0 then
    self.current_idx = -1
    self.next_idx = -1
  end

  self.goto_region_queued = false
  self.goto_region_target = nil

  self.sequence_version = self.sequence_version + 1
  self:update_bounds()
end

function State:get_current_rid()
  if self.playlist_pointer < 1 or self.playlist_pointer > #self.playlist_order then
    return nil
  end
  return self.playlist_order[self.playlist_pointer]
end

function State:get_region_by_rid(rid)
  return self.region_cache[rid]
end

function State:update_bounds()
  if self.current_idx >= 1 and self.current_idx <= #self.playlist_order then
    local rid = self.playlist_order[self.current_idx]
    local region = self:get_region_by_rid(rid)
    if region then
      self.current_bounds.start_pos = region.start
      self.current_bounds.end_pos = region['end']
    end
  else
    self.current_bounds.start_pos = 0
    self.current_bounds.end_pos = -1
  end
  
  if self.next_idx >= 1 and self.next_idx <= #self.playlist_order then
    local rid = self.playlist_order[self.next_idx]
    local region = self:get_region_by_rid(rid)
    if region then
      self.next_bounds.start_pos = region.start
      self.next_bounds.end_pos = region['end']
    end
  else
    self.next_bounds.start_pos = 0
    self.next_bounds.end_pos = -1
  end
end

function State:find_index_at_position(pos, preferred_key)
  if DEBUG_SEQUENCE then Logger.debug('STATE', 'find_index_at_position(%.3f, key=%s) scanning %d entries...', pos, tostring(preferred_key), #self.playlist_order) end

  -- First: try preferred_key if provided (resolves multi-loop ambiguity)
  if preferred_key then
    local idx = self.sequence_lookup_by_key[preferred_key]
    if idx and idx >= 1 and idx <= #self.playlist_order then
      local rid = self.playlist_order[idx]
      local region = self:get_region_by_rid(rid)
      if region then
        local in_bounds = pos >= region.start and pos < region['end'] - 1e-9
        if in_bounds then
          if DEBUG_SEQUENCE then Logger.debug('STATE', 'Preferred key match at idx %d', idx) end
          return idx
        end
      end
    end
  end

  -- Fallback: first matching entry
  for i = 1, #self.playlist_order do
    local rid = self.playlist_order[i]
    local region = self:get_region_by_rid(rid)
    if region then
      local in_bounds = pos >= region.start and pos < region['end'] - 1e-9
      if DEBUG_SEQUENCE then
        Logger.debug('STATE', '  [%d] rid=%d bounds=[%.3f-%.3f] in_bounds=%s',
          i, rid, region.start, region['end'], tostring(in_bounds))
      end
      if in_bounds then
        if DEBUG_SEQUENCE then Logger.debug('STATE', 'Returning idx %d', i) end
        return i
      end
    end
  end
  if DEBUG_SEQUENCE then Logger.debug('STATE', 'No index found, returning -1') end
  return -1
end

function State:get_sequence_entry(index)
  return self.sequence[index]
end

function State:find_index_by_key(key)
  if not key then return nil end
  return self.sequence_lookup_by_key[key]
end

function State:get_current_item_key()
  if self.playlist_pointer >= 1 and self.playlist_pointer <= #self.sequence then
    return self.sequence[self.playlist_pointer].item_key
  end
  return nil
end

function State:get_current_loop_info()
  if self.playlist_pointer >= 1 and self.playlist_pointer <= #self.sequence then
    local entry = self.sequence[self.playlist_pointer]
    return entry.loop or 1, entry.total_loops or 1
  end
  return 1, 1
end

function State:get_sequence_length()
  return #self.sequence
end

function State:_clamp(i, lo, hi)
  if hi < lo then return lo end
  if i < lo then return lo end
  if i > hi then return hi end
  return i
end

function State:get_state_snapshot()
  return {
    proj = self.proj,
    region_cache = self.region_cache,
    playlist_order = self.playlist_order,
    playlist_pointer = self.playlist_pointer,
    current_idx = self.current_idx,
    next_idx = self.next_idx,
    sequence_version = self.sequence_version,
    sequence_length = #self.sequence,
  }
end

-- Shuffle algorithms
function State:_apply_shuffle()
  if #self.sequence <= 1 then return end

  -- Always generate a new seed for each shuffle (new random order every time)
  self._shuffle_seed = (reaper.time_precise() * 1000000) // 1 % 2147483647
  math.randomseed(self._shuffle_seed)

  if self._shuffle_mode == 'true_shuffle' then
    -- Fisher-Yates shuffle - play each item once before reshuffling
    for i = #self.sequence, 2, -1 do
      local j = random(1, i)
      self.sequence[i], self.sequence[j] = self.sequence[j], self.sequence[i]
    end
  elseif self._shuffle_mode == 'random' then
    -- For random mode, we still shuffle but will reshuffle more frequently
    -- This creates a 'pure random' feel where items can play close together
    for i = #self.sequence, 2, -1 do
      local j = random(1, i)
      self.sequence[i], self.sequence[j] = self.sequence[j], self.sequence[i]
    end
  end

  -- Rebuild playlist_order and metadata to match shuffled sequence
  self.playlist_order = {}
  self.playlist_metadata = {}
  self.sequence_lookup_by_key = {}

  for idx, entry in ipairs(self.sequence) do
    self.playlist_order[idx] = entry.rid
    self.playlist_metadata[idx] = {
      key = entry.item_key,
      reps = 1,
      current_loop = 1,
      loop = entry.loop,
      total_loops = entry.total_loops,
    }
    if entry.item_key and not self.sequence_lookup_by_key[entry.item_key] then
      self.sequence_lookup_by_key[entry.item_key] = idx
    end
  end
end

-- Called when shuffle state changes
function State:on_shuffle_changed(enabled)
  self._shuffle_enabled = enabled

  if not enabled then
    -- Clear seed when disabling (will use original order on next set_sequence)
    self._shuffle_seed = nil
  end

  -- Trigger a sequence rebuild with current sequence
  if #self.sequence > 0 then
    local current_sequence = {}
    for _, entry in ipairs(self.sequence) do
      current_sequence[#current_sequence + 1] = {
        rid = entry.rid,
        item_key = entry.item_key,
        loop = entry.loop,
        total_loops = entry.total_loops,
        is_infinite = entry.is_infinite,
        ancestry = entry.ancestry,
      }
    end
    self:set_sequence(current_sequence)
  end
end

-- Shuffle mode getters/setters
function State:get_shuffle_mode()
  return self._shuffle_mode
end

function State:set_shuffle_mode(mode)
  if mode ~= 'true_shuffle' and mode ~= 'random' then
    Logger.warn('STATE', 'Invalid shuffle mode: ' .. tostring(mode))
    return
  end

  self._shuffle_mode = mode

  -- If shuffle is currently enabled, re-shuffle with new mode
  if self._shuffle_enabled and #self.sequence > 0 then
    local current_sequence = {}
    for _, entry in ipairs(self.sequence) do
      current_sequence[#current_sequence + 1] = {
        rid = entry.rid,
        item_key = entry.item_key,
        loop = entry.loop,
        total_loops = entry.total_loops,
        is_infinite = entry.is_infinite,
        ancestry = entry.ancestry,
      }
    end
    self:set_sequence(current_sequence)
  end
end

return M
