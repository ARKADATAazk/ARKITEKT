-- @noindex
-- Region_Playlist/engine/coordinator_bridge.lua
-- Sequence-driven coordinator bridge that lazily expands playlists on demand

local Engine = require("Region_Playlist.engine.core")
local Playback = require("Region_Playlist.engine.playback")
local RegionState = require("Region_Playlist.storage.state")
local SequenceExpander = require("Region_Playlist.app.sequence_expander")

local M = {}

package.loaded["Region_Playlist.engine.coordinator_bridge"] = M

local function safe_call(fn)
  if not fn then return nil end
  local ok, result = pcall(fn)
  if ok then return result end
  return nil
end

function M.create(opts)
  opts = opts or {}

  local saved_settings = RegionState.load_settings(opts.proj or 0)

  local bridge = {
    proj = opts.proj or 0,
    controller = nil,
    get_playlist_by_id = opts.get_playlist_by_id,
    get_active_playlist = opts.get_active_playlist,
    get_active_playlist_id = opts.get_active_playlist_id,
    on_repeat_cycle = opts.on_repeat_cycle,
    sequence_cache = {},
    sequence_cache_dirty = true,
    sequence_lookup = {},
    _last_known_item_key = nil,
    _last_reported_loop_key = nil,
    _last_reported_loop = nil,
  }

  bridge.engine = Engine.new({
    proj = bridge.proj,
    quantize_mode = saved_settings.quantize_mode or "none",
    follow_playhead = saved_settings.follow_playhead or false,
    transport_override = saved_settings.transport_override or false,
    loop_playlist = saved_settings.loop_playlist or false,
    on_repeat_cycle = nil,
    playlist_lookup = opts.get_playlist_by_id,
  })

  bridge.playback = Playback.new(bridge.engine, {
    on_region_change = opts.on_region_change,
    on_playback_start = opts.on_playback_start,
    on_playback_stop = opts.on_playback_stop,
    on_transition_scheduled = opts.on_transition_scheduled,
  })

  local function resolve_active_playlist()
    local playlist = safe_call(bridge.get_active_playlist)
    if playlist then return playlist end

    if bridge.controller and bridge.controller.state and bridge.controller.state.get_active_playlist then
      playlist = safe_call(function()
        return bridge.controller.state.get_active_playlist()
      end)
      if playlist then return playlist end
    end

    if bridge.get_active_playlist_id and bridge.get_playlist_by_id then
      local playlist_id = safe_call(bridge.get_active_playlist_id)
      if playlist_id then
        return bridge.get_playlist_by_id(playlist_id)
      end
    end

    if bridge.controller and bridge.controller.state and bridge.controller.state.state then
      local active_id = bridge.controller.state.state.active_playlist
      if active_id and bridge.get_playlist_by_id then
        return bridge.get_playlist_by_id(active_id)
      end
    end

    return nil
  end

  function bridge:set_controller(controller)
    self.controller = controller
  end

  function bridge:set_playlist_lookup(fn)
    self.get_playlist_by_id = fn
    self.engine.playlist_lookup = fn
    self:invalidate_sequence()
  end

  local function rebuild_sequence()
    local playlist = resolve_active_playlist()
    local sequence = {}

    if playlist then
      sequence = SequenceExpander.expand_playlist(playlist, bridge.get_playlist_by_id)
    end

    bridge.sequence_cache = sequence
    bridge.sequence_lookup = {}
    for idx, entry in ipairs(sequence) do
      if entry.item_key then
        bridge.sequence_lookup[entry.item_key] = idx
      end
    end

    local previous_key = bridge._last_known_item_key or bridge.engine.state:get_current_item_key()

    bridge.engine:set_sequence(sequence)

    if previous_key then
      local restored = bridge.engine.state:find_index_by_key(previous_key)
      if restored then
        bridge.engine:set_playlist_pointer(restored)
        bridge.engine.state.current_idx = restored
        bridge.engine.state.next_idx = restored
        bridge.engine.state:update_bounds()
      end
    end

    bridge._last_known_item_key = bridge.engine.state:get_current_item_key()
    bridge._last_reported_loop_key = nil
    bridge._last_reported_loop = nil
    bridge.sequence_cache_dirty = false
  end

  function bridge:invalidate_sequence()
    self._last_known_item_key = self:get_current_item_key()
    self.sequence_cache_dirty = true
    self.sequence_cache = {}
    self.sequence_lookup = {}
  end

  function bridge:_ensure_sequence()
    if self.sequence_cache_dirty then
      rebuild_sequence()
    end
  end

  function bridge:get_sequence()
    self:_ensure_sequence()
    return self.sequence_cache
  end

  function bridge:get_regions_for_ui()
    local regions = {}
    for rid, rgn in pairs(self.engine.state.region_cache) do
      regions[#regions + 1] = {
        rid = rid,
        name = rgn.name,
        start = rgn.start,
        ["end"] = rgn["end"],
        color = rgn.color,
      }
    end
    return regions
  end

  function bridge:get_current_rid()
    return self.engine:get_current_rid()
  end

  function bridge:get_progress()
    return self.playback:get_progress()
  end

  function bridge:get_time_remaining()
    return self.playback:get_time_remaining()
  end

  function bridge:_emit_repeat_cycle_if_needed()
    if not self.on_repeat_cycle then return end

    local key = self:get_current_item_key()
    if not key then
      self._last_reported_loop_key = nil
      self._last_reported_loop = nil
      return
    end

    local loop, total = self:get_current_loop_info()
    if key ~= self._last_reported_loop_key or loop ~= self._last_reported_loop then
      if total > 1 and loop > 1 then
        self.on_repeat_cycle(key, loop, total)
      end
      self._last_reported_loop_key = key
      self._last_reported_loop = loop
    end
  end

  function bridge:update()
    self:_ensure_sequence()
    self.playback:update()
    self:_emit_repeat_cycle_if_needed()
  end

  function bridge:play()
    self:_ensure_sequence()
    return self.engine:play()
  end

  function bridge:stop()
    return self.engine:stop()
  end

  function bridge:next()
    return self.engine:next()
  end

  function bridge:prev()
    return self.engine:prev()
  end

  function bridge:jump_to_next_quantized(lookahead)
    return self.engine:jump_to_next_quantized(lookahead)
  end

  function bridge:set_quantize_mode(mode)
    self.engine:set_quantize_mode(mode)
    local settings = RegionState.load_settings(self.proj)
    settings.quantize_mode = mode
    RegionState.save_settings(settings, self.proj)
  end

  function bridge:set_loop_playlist(enabled)
    self.engine:set_loop_playlist(enabled)
    local settings = RegionState.load_settings(self.proj)
    settings.loop_playlist = enabled
    RegionState.save_settings(settings, self.proj)
  end

  function bridge:get_loop_playlist()
    return self.engine:get_loop_playlist()
  end

  function bridge:get_state()
    local engine_state = self.engine:get_state()
    return {
      is_playing = engine_state.is_playing,
      playlist_pointer = engine_state.playlist_pointer,
      playlist_order = engine_state.playlist_order,
      quantize_mode = engine_state.quantize_mode,
      context_depth = engine_state.context_depth,
      sequence_length = engine_state.sequence_length,
      current_item_key = engine_state.current_item_key,
      current_loop = engine_state.current_loop,
      total_loops = engine_state.total_loops,
    }
  end

  function bridge:get_current_item_key()
    self:_ensure_sequence()
    return self.engine.state:get_current_item_key()
  end

  function bridge:get_current_loop_info()
    self:_ensure_sequence()
    return self.engine.state:get_current_loop_info()
  end

  function bridge:set_position_by_key(item_key)
    if not item_key then return false end
    self:_ensure_sequence()

    local idx = self.sequence_lookup[item_key]
    if not idx then return false end

    self.engine:set_playlist_pointer(idx)
    if self.engine.state then
      self.engine.state.playlist_pointer = idx
      self.engine.state.current_idx = idx
      self.engine.state.next_idx = idx
      self.engine.state:update_bounds()
    end

    self._last_known_item_key = item_key
    self:_emit_repeat_cycle_if_needed()
    return true
  end

  return bridge
end

return M
