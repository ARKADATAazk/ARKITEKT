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

function Coordinator.new(opts)
  opts = opts or {}
  local self = setmetatable({}, Coordinator)

  self.proj = opts.proj or 0
  self.sequencer = assert(opts.sequencer, 'coordinator requires a sequencer')
  self.events = opts.events or Events.new()
  self.get_playlist_by_id = opts.get_playlist_by_id

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
    on_repeat_cycle = opts.on_repeat_cycle,
    playlist_lookup = self.get_playlist_by_id,
  })

  self.playback = Playback.new(self.engine, {
    on_region_change = wrap_event(self, 'playback.region_change', opts.on_region_change),
    on_playback_start = wrap_event(self, 'playback.start', opts.on_playback_start),
    on_playback_stop = wrap_event(self, 'playback.stop', opts.on_playback_stop),
    on_transition_scheduled = wrap_event(self, 'playback.transition_scheduled', opts.on_transition_scheduled),
  })

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

function Coordinator:set_playlist_lookup(fn)
  self.get_playlist_by_id = fn
  self.engine.playlist_lookup = fn
  if self.sequencer and self.sequencer.set_playlist_lookup then
    self.sequencer:set_playlist_lookup(fn)
  end
  self:invalidate_sequence()
end

function Coordinator:invalidate_sequence()
  if self.sequencer then
    self.sequencer:invalidate()
  end
  if self.events then
    self.events:emit('sequence.invalidated', self.proj)
  end
end

function Coordinator:get_sequence()
  if not self.sequencer then
    return {}
  end
  local sequence = self.sequencer:get_sequence()
  if self.events then
    self.events:emit('sequence.requested', sequence)
  end
  return sequence
end

function Coordinator:set_position_by_key(item_key)
  if not item_key or not self.sequencer then
    return false
  end
  local idx = self.sequencer:find_by_key(item_key)
  if not idx then
    return false
  end
  self.engine:set_playlist_pointer(idx)
  if self.engine.state then
    self.engine.state.playlist_pointer = idx
    self.engine.state.current_idx = idx
    self.engine.state.next_idx = idx
    if self.engine.state.update_bounds then
      self.engine.state:update_bounds()
    end
  end
  if self.events then
    self.events:emit('playback.pointer_changed', item_key, idx)
  end
  return true
end

function Coordinator:play()
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
  self.playback:update()
  if self.events then
    self.events:emit('playback.update')
  end
end

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

function Coordinator:get_state()
  return self.engine:get_state()
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
