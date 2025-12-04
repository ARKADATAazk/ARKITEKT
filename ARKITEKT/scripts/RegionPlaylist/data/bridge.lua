-- @noindex
-- RegionPlaylist/data/bridge.lua
-- App ↔ Engine Coordination Bridge
--
-- PURPOSE:
-- Decouples the UI layer (app/state, ui/) from the playback engine (domain/playback).
-- When playlists are edited in the UI, the Bridge invalidates its cached sequence
-- and lazily rebuilds on next playback request.
--
-- RESPONSIBILITIES:
--   1. Lazy Sequence Expansion - Flattens nested playlists into linear sequence
--   2. Cache Invalidation - Rebuilds when playlists change
--   3. Engine Wrapping - Provides simplified API to UI (play, stop, seek)
--   4. State Coordination - Keeps UI and engine synchronized
--
-- PATTERN: Facade + Lazy Evaluation
-- - Facade: Hides engine complexity from UI
-- - Lazy: Only expands playlists when needed (on play, on get_sequence)
--
-- WHY IT EXISTS:
-- - UI mutates playlists frequently (add, remove, reorder, change loops)
-- - Engine needs flat array: [{rid, key, loops}, {rid, key, loops}, ...]
-- - Rebuilding sequence on every UI change is expensive
-- - Solution: Invalidate cache, rebuild lazily when engine needs it
--
-- SEQUENCE EXPANSION:
-- Nested playlists are recursively flattened into array of {rid, key, loops}.
-- Example:
--   Active Playlist:
--     Region 1 (2 reps)
--     Nested Playlist A (3 reps)
--       Region 2 (1 rep)
--       Region 3 (2 reps)
--
--   Expanded Sequence:
--     [Region 1, Region 1,
--      Region 2, Region 3, Region 3,
--      Region 2, Region 3, Region 3,
--      Region 2, Region 3, Region 3]
--
-- CACHE INVALIDATION:
-- When controller.commit() is called after playlist edit:
--   1. controller:_commit()
--   2. bridge:invalidate_sequence()
--   3. Sets sequence_stale = true
--   4. [User clicks play]
--   5. bridge:play() checks sequence_stale
--   6. If stale: rebuild via expander.expand(playlists)
--   7. Cache sequence for subsequent frames
--
-- FLOW DIAGRAM:
-- UI edits playlist
--   → controller.add_item(rid, index)
--   → controller:_commit()
--   → bridge:invalidate_sequence()
--   → [User clicks play]
--   → bridge:play()
--   → if sequence_stale then rebuild_sequence()
--   → engine.play(sequence)
--   → Per frame: engine.update()
--   → UI polls bridge:get_current_key()
--
-- SEE ALSO:
--   - domain/playback/expander.lua (sequence expansion algorithm)
--   - domain/playback/controller.lua (playback engine)
--   - app/controller.lua (calls invalidate_sequence on commits)

local Engine = require('RegionPlaylist.domain.playback.controller')
local Playback = require('RegionPlaylist.domain.playback.loop')
local RegionState = require('RegionPlaylist.data.storage')
local SequenceExpander = require('RegionPlaylist.domain.playback.expander')
local Logger = require('arkitekt.debug.logger')
local Callbacks = require('arkitekt.core.callbacks')

-- Set to true for verbose sequence building debug logs
local DEBUG_BRIDGE = false

-- Performance: Localize math functions for hot path (30% faster in loops)
local max = math.max
local min = math.min

-- Performance: Cache module to avoid repeated require() lookups in hot functions
local Transport = require('arkitekt.reaper.transport')

local M = {}

package.loaded['RegionPlaylist.data.bridge'] = M

-- Use framework callback wrapper instead of local implementation
local safe_call = Callbacks.safe_call

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
    sequence_dirty = true,
    sequence_lookup = {},
    ancestry_entries = {},   -- key -> {idx1, idx2, ...} for O(1) progress lookup
    ancestry_durations = {}, -- key -> total_duration (pre-computed)
    _last_known_item_key = nil,
    _last_reported_loop_key = nil,
    _last_reported_loop = nil,
    _playing_playlist_id = nil,  -- Track which playlist is currently being played
  }

  bridge.engine = Engine.new({
    proj = bridge.proj,
    quantize_mode = saved_settings.quantize_mode or 'measure',
    follow_playhead = saved_settings.follow_playhead or false,
    transport_override = saved_settings.transport_override or false,
    loop_playlist = saved_settings.loop_playlist or false,
    follow_viewport = saved_settings.follow_viewport or false,
    shuffle_enabled = saved_settings.shuffle_enabled or false,
    shuffle_mode = saved_settings.shuffle_mode or 'true_shuffle',
    on_repeat_cycle = nil,
    playlist_lookup = opts.get_playlist_by_id,
  })

  -- Save defaults only if settings were empty (first run only)
  local needs_save = false

  if saved_settings.quantize_mode == nil then
    saved_settings.quantize_mode = 'measure'
    needs_save = true
  end

  if saved_settings.shuffle_enabled == nil then
    saved_settings.shuffle_enabled = false
    needs_save = true
  end

  if saved_settings.shuffle_mode == nil then
    saved_settings.shuffle_mode = 'true_shuffle'
    needs_save = true
  end

  if needs_save then
    RegionState.save_settings(saved_settings, bridge.proj)
  end

  bridge.playback = Playback.new(bridge.engine, {
    on_region_change = opts.on_region_change,
    on_playback_start = opts.on_playback_start,
    on_playback_stop = opts.on_playback_stop,
    on_transition_scheduled = opts.on_transition_scheduled,
  })

  -- Resolve active playlist using waterfall pattern (first match wins)
  local function resolve_active_playlist()
    -- Primary: Direct accessor (set during initialization)
    local playlist = safe_call(bridge.get_active_playlist)
    if playlist then return playlist end

    -- Secondary: Via controller state accessor
    local ctrl_state = bridge.controller and bridge.controller.state
    if ctrl_state and ctrl_state.get_active_playlist then
      playlist = safe_call(ctrl_state.get_active_playlist)
      if playlist then return playlist end
    end

    -- Tertiary: Look up by ID (combine both ID sources)
    local playlist_id = safe_call(bridge.get_active_playlist_id)
                     or (ctrl_state and ctrl_state.active_playlist)
    if playlist_id and bridge.get_playlist_by_id then
      return bridge.get_playlist_by_id(playlist_id)
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
    local active_playlist_id = safe_call(bridge.get_active_playlist_id)
    local is_playing = bridge.engine and bridge.engine:get_is_playing()

    -- Don't rebuild sequence if we're currently playing
    -- This prevents the transport from switching playlists when user changes tabs during playback
    if is_playing and bridge._playing_playlist_id then
      if DEBUG_BRIDGE then
        Logger.debug('BRIDGE', 'Skipping sequence rebuild - currently playing playlist %s (active: %s)',
          tostring(bridge._playing_playlist_id), tostring(active_playlist_id))
      end
      bridge.sequence_dirty = false
      return
    end

    local sequence = {}

    if playlist then
      sequence = SequenceExpander.expand_playlist(playlist, bridge.get_playlist_by_id)
    end

    bridge.sequence_lookup = {}

    -- Build lookup before set_sequence (shuffle may reorder)
    for idx, entry in ipairs(sequence) do
      if entry.item_key and not bridge.sequence_lookup[entry.item_key] then
        bridge.sequence_lookup[entry.item_key] = idx
        if DEBUG_BRIDGE then Logger.debug('BRIDGE', "Mapping key '%s' -> idx %d", entry.item_key, idx) end
      end
    end

    if DEBUG_BRIDGE then
      Logger.debug('BRIDGE', 'Final sequence_lookup built with %d entries',
        (function() local count = 0; for _ in pairs(bridge.sequence_lookup) do count = count + 1 end; return count end)())
    end

    local previous_key = bridge._last_known_item_key or bridge.engine.state:get_current_item_key()

    bridge.engine:set_sequence(sequence)

    -- Rebuild lookups from engine's sequence (may be shuffled)
    bridge.sequence_lookup = {}
    bridge.ancestry_entries = {}
    bridge.ancestry_durations = {}
    local state_sequence = bridge.engine.state.sequence
    local region_cache = bridge.engine.state.region_cache

    for idx, entry in ipairs(state_sequence) do
      -- Key -> first index lookup
      if entry.item_key and not bridge.sequence_lookup[entry.item_key] then
        bridge.sequence_lookup[entry.item_key] = idx
      end
      -- Ancestry -> indices lookup (for O(1) progress calculation)
      -- Also accumulate duration per ancestry key
      if entry.ancestry then
        local region = region_cache[entry.rid]
        local duration = region and (region['end'] - region.start) or 0
        for _, ancestor in ipairs(entry.ancestry) do
          if ancestor.key then
            if not bridge.ancestry_entries[ancestor.key] then
              bridge.ancestry_entries[ancestor.key] = {}
              bridge.ancestry_durations[ancestor.key] = 0
            end
            local entries = bridge.ancestry_entries[ancestor.key]
            entries[#entries + 1] = idx
            bridge.ancestry_durations[ancestor.key] = bridge.ancestry_durations[ancestor.key] + duration
          end
        end
      end
    end

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
    bridge.sequence_dirty = false

    -- Remember which playlist we're playing
    if not is_playing then
      bridge._playing_playlist_id = active_playlist_id
    end
  end

  function bridge:invalidate_sequence()
    self._last_known_item_key = self:get_current_item_key()
    self.sequence_dirty = true
    self.sequence_lookup = {}
    self.ancestry_entries = {}
    self.ancestry_durations = {}
  end

  function bridge:_ensure_sequence()
    if self.sequence_dirty then
      rebuild_sequence()
    end
  end

  function bridge:get_sequence()
    self:_ensure_sequence()
    return self.engine.state.sequence
  end

  function bridge:get_regions_for_ui()
    local regions = {}
    for rid, rgn in pairs(self.engine.state.region_cache) do
      regions[#regions + 1] = {
        rid = rid,
        name = rgn.name,
        start = rgn.start,
        ['end'] = rgn['end'],
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
    -- Remember which playlist we're playing when playback starts
    self._playing_playlist_id = safe_call(self.get_active_playlist_id)
    Logger.info('BRIDGE', "PLAY playlist '%s' (%d items)", tostring(self._playing_playlist_id), #self.engine.state.sequence)

    -- If we're starting after a stop (not resuming from pause), force reset to beginning
    -- This must happen AFTER _ensure_sequence() so it overrides sequence restoration
    if not self.engine.transport.is_paused and
       self.engine.state.current_idx == -1 and
       self.engine.state.next_idx == -1 then
      self.engine.state.playlist_pointer = 1
    end

    return self.engine:play()
  end

  function bridge:stop()
    Logger.info('BRIDGE', "STOP - clearing playlist '%s'", tostring(self._playing_playlist_id))
    -- Clear the playing playlist ID when stopping
    -- This allows the sequence to be rebuilt for a different playlist on next play
    self._playing_playlist_id = nil
    -- Clear the last known position so rebuild_sequence doesn't restore it
    self._last_known_item_key = nil
    return self.engine:stop()
  end

  function bridge:pause()
    return self.engine:pause()
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

  function bridge:set_shuffle_enabled(enabled)
    self.engine:set_shuffle_enabled(enabled)
    self:invalidate_sequence()  -- Sequence order changes with shuffle
    local settings = RegionState.load_settings(self.proj)
    settings.shuffle_enabled = enabled
    RegionState.save_settings(settings, self.proj)
  end

  function bridge:get_shuffle_enabled()
    return self.engine:get_shuffle_enabled()
  end

  function bridge:set_shuffle_mode(mode)
    self.engine:set_shuffle_mode(mode)
    self:invalidate_sequence()  -- Sequence order changes with shuffle mode
    local settings = RegionState.load_settings(self.proj)
    settings.shuffle_mode = mode
    RegionState.save_settings(settings, self.proj)
  end

  function bridge:get_shuffle_mode()
    return self.engine:get_shuffle_mode()
  end

  function bridge:set_follow_playhead(enabled)
    self.engine:set_follow_playhead(enabled)
    local settings = RegionState.load_settings(self.proj)
    settings.follow_playhead = enabled
    RegionState.save_settings(settings, self.proj)
  end

  function bridge:get_follow_playhead()
    return self.engine.follow_playhead
  end

  function bridge:set_transport_override(enabled)
    self.engine:set_transport_override(enabled)
    local settings = RegionState.load_settings(self.proj)
    settings.transport_override = enabled
    RegionState.save_settings(settings, self.proj)
  end

  function bridge:get_transport_override()
    return self.engine:get_transport_override()
  end

  function bridge:set_follow_viewport(enabled)
    self.engine:set_follow_viewport(enabled)
    local settings = RegionState.load_settings(self.proj)
    settings.follow_viewport = enabled
    RegionState.save_settings(settings, self.proj)
  end

  function bridge:get_follow_viewport()
    return self.engine:get_follow_viewport()
  end

  function bridge:get_playing_playlist_id()
    -- Return the ID of the playlist that is currently playing
    -- Returns nil if not playing or no playlist is locked
    return self._playing_playlist_id
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

  function bridge:get_current_playlist_key()
    if not self.engine:get_is_playing() then return nil end

    self:_ensure_sequence()
    local current_pointer = self.engine.state and self.engine.state.playlist_pointer or -1
    if current_pointer < 1 or current_pointer > #self.engine.state.sequence then return nil end

    local current_entry = self.engine.state.sequence[current_pointer]
    if not current_entry or not current_entry.ancestry then return nil end

    -- Return the innermost (deepest) playlist key from ancestry
    local ancestry = current_entry.ancestry
    if #ancestry > 0 then
      return ancestry[#ancestry].key
    end

    return nil
  end

  -- Check if a playlist item contains the current playback position
  -- Uses ancestry tracking: playlist_key is active if it appears in current entry's ancestry
  function bridge:is_playlist_active(playlist_key)
    if not self.engine:get_is_playing() then return false end
    if not playlist_key then return false end

    self:_ensure_sequence()
    local current_pointer = self.engine.state and self.engine.state.playlist_pointer or -1
    if current_pointer < 1 or current_pointer > #self.engine.state.sequence then return false end

    local current_entry = self.engine.state.sequence[current_pointer]
    if not current_entry then return false end

    -- Use SequenceExpander helper to check ancestry
    return SequenceExpander.ancestry_contains(current_entry.ancestry, playlist_key)
  end

  -- Get progress through a playlist item (0.0 to 1.0)
  -- Uses pre-computed ancestry_entries and ancestry_durations for efficiency
  function bridge:get_playlist_progress(playlist_key)
    if not self.engine:get_is_playing() then return nil end
    if not playlist_key then return nil end

    self:_ensure_sequence()
    local entry_indices = self.ancestry_entries[playlist_key]
    if not entry_indices or #entry_indices == 0 then return nil end

    local total_duration = self.ancestry_durations[playlist_key] or 0
    if total_duration <= 0 then return 0 end

    local current_pointer = self.engine.state and self.engine.state.playlist_pointer or -1
    if current_pointer < 1 then return nil end

    local playpos = Transport.get_play_position(self.proj)
    local sequence = self.engine.state.sequence
    local region_cache = self.engine.state.region_cache

    local elapsed_duration = 0

    -- Iterate only entries belonging to this playlist (pre-computed)
    for _, idx in ipairs(entry_indices) do
      if idx > current_pointer then
        break  -- Indices are sorted, no need to check further
      end
      local entry = sequence[idx]
      if entry then
        local region = region_cache[entry.rid]
        if region then
          if idx == current_pointer then
            -- Currently playing this entry
            local clamped_pos = max(region.start, min(playpos, region['end']))
            elapsed_duration = elapsed_duration + (clamped_pos - region.start)
            break  -- Found current, done
          else
            -- This entry has already played (idx < current_pointer)
            elapsed_duration = elapsed_duration + (region['end'] - region.start)
          end
        end
      end
    end

    return max(0, min(1, elapsed_duration / total_duration))
  end

  -- Get time remaining in a playlist item (in seconds)
  -- Uses pre-computed ancestry_entries lookup and early termination
  function bridge:get_playlist_time_remaining(playlist_key)
    if not self.engine:get_is_playing() then return nil end
    if not playlist_key then return nil end

    self:_ensure_sequence()
    local entry_indices = self.ancestry_entries[playlist_key]
    if not entry_indices or #entry_indices == 0 then return nil end

    local current_pointer = self.engine.state and self.engine.state.playlist_pointer or -1
    if current_pointer < 1 then return nil end

    local playpos = Transport.get_play_position(self.proj)
    local sequence = self.engine.state.sequence
    local region_cache = self.engine.state.region_cache

    local remaining = 0

    -- Iterate only entries belonging to this playlist (pre-computed)
    -- Indices are sorted, so skip entries before current_pointer
    for _, idx in ipairs(entry_indices) do
      if idx >= current_pointer then
        local entry = sequence[idx]
        if entry then
          local region = region_cache[entry.rid]
          if region then
            if idx == current_pointer then
              -- Currently playing this entry
              remaining = remaining + max(0, region['end'] - playpos)
            else
              -- This entry hasn't played yet (idx > current_pointer)
              remaining = remaining + (region['end'] - region.start)
            end
          end
        end
      end
    end

    return remaining
  end

  return bridge
end

return M
