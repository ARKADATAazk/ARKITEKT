-- @noindex
-- Region_Playlist/playback/coordinator.lua
-- Thin façade between app and engine, backed by Sequencer and Events

local Engine = require('Region_Playlist.engine.core')
local Playback = require('Region_Playlist.engine.playback')
local RegionState = require('Region_Playlist.storage.state')
local Events = require('rearkitekt.core.events')

local Coordinator = {}
Coordinator.__index = Coordinator

local function safe(fn)
  if type(fn) ~= 'function' then
    return function() end
  end
  return function(...)
    local ok, _ = pcall(fn, ...)
    if not ok then
      return
    end
  end
end

local function wrap_event(self, event_name, fn)
  local guarded = safe(fn)
  if not self.events then
    return guarded
  end
  return function(...)
    guarded(...)
    self.events:emit(event_name, ...)
  end
end

local function safe_state_call(state, method_name, ...)
  if not state then return nil end
  local method = state[method_name]
  if type(method) ~= 'function' then
    return nil
  end
  local ok, result = pcall(method, state, ...)
  if ok then
    return result
  end
  return nil
end

local function normalize_loop_value(value)
  return math.max(1, math.floor(tonumber(value) or 1))
end

local function normalize_sequence(seq, region_cache)
  local normalized, lookup = {}, {}
  if type(seq) ~= 'table' then return normalized, lookup end
  local has_cache = type(region_cache) == 'table'
  for _, entry in ipairs(seq) do
    if type(entry) == 'table' then
      local rid = tonumber(entry.rid or entry.region_id or entry[1])
      if rid then
        rid = math.floor(rid)
        if rid >= 0 and (not has_cache or region_cache[rid] ~= nil) then
          local loop = normalize_loop_value(entry.loop or entry.loop_index or entry.iteration)
          local total = normalize_loop_value(entry.total_loops or entry.reps or entry.loop_count or entry.total or loop)
          if loop > total then loop = total end
          local key = entry.item_key
          if key ~= nil then key = tostring(key) end
          normalized[#normalized + 1] = { rid = rid, item_key = key, loop = loop, total_loops = total }
          if key ~= nil then lookup[key] = #normalized end
        end
      end
    end
  end
  return normalized, lookup
end

local function engine_state(self)
  return self.engine and self.engine.state or nil
end

function Coordinator.new(opts)
  opts = opts or {}
  local self = setmetatable({}, Coordinator)

  self.proj = opts.proj or 0
  self.sequencer = assert(opts.sequencer, 'coordinator requires a sequencer')
  self.events = opts.events or Events.new()
  self.get_playlist_by_id = opts.get_playlist_by_id
  self._on_repeat_cycle = safe(opts.on_repeat_cycle)

  local settings = RegionState.load_settings(self.proj) or {}
  local qmode = settings.quantize_mode or 'none'
  local follow = settings.follow_playhead or false
  local override = settings.transport_override or false
  local looplist = settings.loop_playlist or false

  self.engine = Engine.new({
    proj = self.proj,
    quantize_mode = qmode,
    follow_playhead = follow,
    transport_override = override,
    loop_playlist = looplist,
    on_repeat_cycle = nil,
    playlist_lookup = self.get_playlist_by_id,
  })

  self.playback = Playback.new(self.engine, {
    on_region_change = wrap_event(self, 'playback.region_change', opts.on_region_change),
    on_playback_start = wrap_event(self, 'playback.start', opts.on_playback_start),
    on_playback_stop = wrap_event(self, 'playback.stop', opts.on_playback_stop),
    on_transition_scheduled = wrap_event(self, 'playback.transition_scheduled', opts.on_transition_scheduled),
  })

  self._sequence_cache = {}
  self._sequence_lookup = {}
  self._sequence_dirty = true
  self._last_known_item_key = nil
  self._last_reported_loop_key = nil
  self._last_reported_loop = nil

  return self
end

function Coordinator:get_events()
  return self.events
end

function Coordinator:on(event, callback)
  if not self.events then
    return false
  end
  return self.events:on(event, callback)
end

function Coordinator:off(event, callback)
  if not self.events then
    return false
  end
  return self.events:off(event, callback)
end

function Coordinator:set_controller(controller)
  self.controller = controller
end

function Coordinator:_remember_current_item_key()
  local state = engine_state(self)
  local key = safe_state_call(state, 'get_current_item_key')
  if key ~= nil then return key end
  if state and state.current_item_key ~= nil then return state.current_item_key end
  return nil
end

function Coordinator:set_playlist_lookup(fn)
  self.get_playlist_by_id = fn
  self.engine.playlist_lookup = fn
  if self.sequencer and self.sequencer.set_playlist_lookup then
    self.sequencer:set_playlist_lookup(fn)
  end
  self:invalidate_sequence()
end

function Coordinator:invalidate_sequence()
  self._last_known_item_key = self:_remember_current_item_key()
  self._sequence_cache = {}
  self._sequence_lookup = {}
  self._sequence_dirty = true
  self._last_reported_loop_key, self._last_reported_loop = nil, nil
  if self.sequencer then
    self.sequencer:invalidate()
  end
  if self.events then
    self.events:emit('sequence.invalidated', self.proj)
  end
end

function Coordinator:_rebuild_sequence()
  if not self.sequencer then
    self._sequence_cache = {}
    self._sequence_lookup = {}
    self._sequence_dirty = false
    return
  end
  local raw_sequence = self.sequencer:get_sequence() or {}
  local state = engine_state(self)
  local normalized, lookup = normalize_sequence(raw_sequence, state and state.region_cache or nil)
  local previous_key = self._last_known_item_key or self:_remember_current_item_key()
  self._sequence_cache = normalized
  self._sequence_lookup = lookup
  self.engine:set_sequence(normalized)
  if previous_key ~= nil then
    local restored = safe_state_call(state, 'find_index_by_key', previous_key)
    if type(restored) == 'number' and restored >= 1 then
      self.engine:set_playlist_pointer(restored)
      if state then
        state.playlist_pointer, state.current_idx, state.next_idx = restored, restored, restored
        safe_state_call(state, 'update_bounds')
      end
    end
  end
  self._last_known_item_key = self:_remember_current_item_key()
  self._last_reported_loop_key, self._last_reported_loop = nil, nil
  self._sequence_dirty = false
end

function Coordinator:_ensure_sequence()
  if self._sequence_dirty then
    self:_rebuild_sequence()
  end
end

function Coordinator:get_sequence()
  self:_ensure_sequence()
  if self.events then
    self.events:emit('sequence.requested', self._sequence_cache)
  end
  return self._sequence_cache
end

function Coordinator:_emit_repeat_cycle_if_needed()
  if not self._on_repeat_cycle then
    return
  end
  local key = self:_remember_current_item_key()
  if key == nil then
    self._last_reported_loop_key, self._last_reported_loop = nil, nil
    return
  end
  local loop, total = self:get_current_loop_info()
  if key ~= self._last_reported_loop_key or loop ~= self._last_reported_loop then
    if total > 1 and loop > 1 then
      self._on_repeat_cycle(key, loop, total)
    end
    self._last_reported_loop_key, self._last_reported_loop = key, loop
  end
end

-- @deprecated: Temporary parity shim for Phase 2.4
-- EXPIRES: 2026-01-31 (remove in Phase 7)
-- DO NOT extend; delegate only.
function Coordinator:set_position_by_key(item_key)
  if item_key == nil then
    return false
  end
  self:_ensure_sequence()
  local key = tostring(item_key)
  local idx = self._sequence_lookup[key]
  if type(idx) ~= 'number' or idx < 1 then
    return false
  end
  self.engine:set_playlist_pointer(idx)
  local state = engine_state(self)
  if state then
    state.playlist_pointer, state.current_idx, state.next_idx = idx, idx, idx
    safe_state_call(state, 'update_bounds')
  end
  self._last_known_item_key = key
  self:_emit_repeat_cycle_if_needed()
  if self.events then
    self.events:emit('playback.pointer_changed', key, idx)
  end
  return true
end

function Coordinator:play()
  self:_ensure_sequence()
  local result = self.engine:play()
  if self.events then
    self.events:emit('playback.play', result)
  end
  return result
end

function Coordinator:stop()
  local result = self.engine:stop()
  if self.events then
    self.events:emit('playback.stop_command', result)
  end
  return result
end

function Coordinator:next()
  local result = self.engine:next()
  if self.events then
    self.events:emit('playback.next', result)
  end
  return result
end

function Coordinator:prev()
  local result = self.engine:prev()
  if self.events then
    self.events:emit('playback.prev', result)
  end
  return result
end

function Coordinator:jump_to_next_quantized(lookahead)
  local result = self.engine:jump_to_next_quantized(lookahead)
  if self.events then
    self.events:emit('playback.jump_to_next_quantized', lookahead, result)
  end
  return result
end

function Coordinator:get_current_rid()
  return self.engine:get_current_rid()
end

function Coordinator:get_progress()
  return self.playback:get_progress()
end

function Coordinator:get_time_remaining()
  return self.playback:get_time_remaining()
end

function Coordinator:update()
  self:_ensure_sequence()
  self.playback:update()
  self:_emit_repeat_cycle_if_needed()
  if self.events then
    self.events:emit('playback.update')
  end
end

-- @deprecated: Temporary parity shim for Phase 2.4
-- EXPIRES: 2026-01-31 (remove in Phase 7)
-- DO NOT extend; delegate only.
function Coordinator:get_regions_for_ui()
  local cache = {}
  local state = self.engine and self.engine.state or nil
  local region_cache = state and state.region_cache or nil
  if not region_cache then
    return cache
  end
  for rid, region in pairs(region_cache) do
    cache[#cache + 1] = {
      rid = rid,
      name = region.name,
      start = region.start,
      ["end"] = region["end"],
      color = region.color,
    }
  end
  return cache
end

-- @deprecated: Temporary parity shim for Phase 2.4
-- EXPIRES: 2026-01-31 (remove in Phase 7)
-- DO NOT extend; delegate only.
function Coordinator:get_state()
  local state = self.engine:get_state()
  return {
    is_playing = state.is_playing,
    playlist_pointer = state.playlist_pointer,
    playlist_order = state.playlist_order,
    quantize_mode = state.quantize_mode,
    context_depth = state.context_depth,
    sequence_length = state.sequence_length,
    current_item_key = state.current_item_key,
    current_loop = state.current_loop,
    total_loops = state.total_loops,
  }
end

-- @deprecated: Temporary parity shim for Phase 2.4
-- EXPIRES: 2026-01-31 (remove in Phase 7)
-- DO NOT extend; delegate only.
function Coordinator:get_current_item_key()
  self:_ensure_sequence()
  local state = engine_state(self)
  local key = safe_state_call(state, 'get_current_item_key')
  if key ~= nil then
    return key
  end
  if state then return state.current_item_key end
  return nil
end

-- @deprecated: Temporary parity shim for Phase 2.4
-- EXPIRES: 2026-01-31 (remove in Phase 7)
-- DO NOT extend; delegate only.
function Coordinator:get_current_loop_info()
  self:_ensure_sequence()
  local state = engine_state(self)
  local loop, total = safe_state_call(state, 'get_current_loop_info')
  if loop ~= nil and total ~= nil then return loop, total end
  return 1, 1
end

function Coordinator:set_quantize_mode(mode)
  self.engine:set_quantize_mode(mode)
  local s = RegionState.load_settings(self.proj) or {}
  s.quantize_mode = mode
  RegionState.save_settings(s, self.proj)
  if self.events then
    self.events:emit('playback.quantize_mode_changed', mode)
  end
end

function Coordinator:set_loop_playlist(enabled)
  self.engine:set_loop_playlist(enabled)
  local s = RegionState.load_settings(self.proj) or {}
  s.loop_playlist = not not enabled
  RegionState.save_settings(s, self.proj)
  if self.events then
    self.events:emit('playback.loop_playlist_changed', not not enabled)
  end
end

function Coordinator:get_loop_playlist()
  return self.engine:get_loop_playlist()
end

local M = {}
function M.new(opts)
  return Coordinator.new(opts)
end

return M
