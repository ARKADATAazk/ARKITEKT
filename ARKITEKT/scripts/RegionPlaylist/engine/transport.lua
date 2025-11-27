-- @noindex
-- Arkitekt/features/region_playlist/engine/transport.lua
-- Transport control and seeking logic

local Logger = require('arkitekt.debug.logger')
local Constants = require("RegionPlaylist.defs.constants")

local M = {}
local Transport = {}
Transport.__index = Transport

-- Localize constants
local PLAYBACK = Constants.PLAYBACK

local function _has_sws()
  return (reaper.SNM_GetIntConfigVar ~= nil) and (reaper.SNM_SetIntConfigVar ~= nil)
end

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
  local self = setmetatable({}, Transport)

  self.proj = opts.proj or 0
  self.state = opts.state
  self.fsm = opts.fsm  -- Playback FSM (Phase 1: explicit state machine)

  self.transport_override = (opts.transport_override == true)
  self.loop_playlist = (opts.loop_playlist == true)
  self.follow_viewport = (opts.follow_viewport == true)
  self.shuffle_enabled = false  -- Initialize to false, will be set properly below

  -- Legacy booleans (will be removed in Phase 1.7)
  self.is_playing = false
  self.last_seek_time = 0
  self.seek_throttle = PLAYBACK.SEEK_THROTTLE

  -- Pause state tracking - simpler approach
  self.is_paused = false

  self._playlist_mode = false
  self._old_smoothseek = nil
  self._old_repeat = nil
  self._old_smooth_scroll = nil

  -- Set shuffle mode first if provided
  if opts.shuffle_mode and self.state and self.state.set_shuffle_mode then
    self.state:set_shuffle_mode(opts.shuffle_mode)
  end

  -- Set shuffle after initialization to trigger state sync
  if opts.shuffle_enabled then
    self:set_shuffle_enabled(true)
  end

  return self
end

function Transport:_enter_playlist_mode_if_needed()
  if self._playlist_mode then return end

  -- Save and override SWS settings
  if _has_sws() then
    self._old_smoothseek = reaper.SNM_GetIntConfigVar("smoothseek", -1)
    reaper.SNM_SetIntConfigVar("smoothseek", 3)

    self._old_repeat = reaper.GetSetRepeat(-1)
    if self._old_repeat == 1 then
      reaper.GetSetRepeat(0)
    end
  end

  -- Save and enable continuous scrolling if Follow Viewport is enabled
  -- Command 41817: View: Toggle continuous scrolling during playback
  if self.follow_viewport then
    self._old_smooth_scroll = reaper.GetToggleCommandState(41817)
    if self._old_smooth_scroll == 0 then
      reaper.Main_OnCommand(41817, 0)  -- Enable smooth scroll
    end
  end

  self._playlist_mode = true
end

function Transport:_leave_playlist_mode_if_needed()
  if not self._playlist_mode then return end

  -- Restore SWS settings
  if _has_sws() then
    if self._old_smoothseek ~= nil then
      reaper.SNM_SetIntConfigVar("smoothseek", self._old_smoothseek)
      self._old_smoothseek = nil
    end
    if self._old_repeat == 1 then
      reaper.GetSetRepeat(1)
    end
    self._old_repeat = nil
  end

  -- Restore continuous scrolling to original state
  -- Command 41817: View: Toggle continuous scrolling during playback
  if self._old_smooth_scroll ~= nil then
    local current_state = reaper.GetToggleCommandState(41817)
    if current_state ~= self._old_smooth_scroll then
      reaper.Main_OnCommand(41817, 0)  -- Toggle back to original
    end
    self._old_smooth_scroll = nil
  end

  self._playlist_mode = false
end

function Transport:_seek_to_region(region_num)
  local now = reaper.time_precise()
  if now - self.last_seek_time < self.seek_throttle then
    return false
  end
  
  local cursor_pos = reaper.GetCursorPositionEx(self.proj)
  
  reaper.PreventUIRefresh(1)
  reaper.GoToRegion(self.proj, region_num, false)
  
  if not _is_playing(self.proj) then
    reaper.OnPlayButton()
  end
  
  reaper.SetEditCurPos2(self.proj, cursor_pos, false, false)
  reaper.PreventUIRefresh(-1)
  
  self.last_seek_time = now
  return true
end

function Transport:play()
  -- FSM guard: check if already playing
  if self.fsm and self.fsm:is("playing") then
    return true  -- Already playing, nothing to do
  end

  local rid = self.state:get_current_rid()
  if not rid then
    Logger.warn("TRANSPORT", "play() called but no current RID")
    return false
  end

  local region = self.state:get_region_by_rid(rid)
  if not region then
    Logger.warn("TRANSPORT", "play() called but region RID %d not found", rid)
    return false
  end

  -- FSM guard: try to transition to playing
  if self.fsm then
    -- Update sequence length before attempting play
    self.fsm:set_sequence_length(#self.state.playlist_order)
    local ok = self.fsm:send("play")
    if not ok then
      Logger.warn("TRANSPORT", "FSM blocked play transition")
      return false
    end
  end

  self:_enter_playlist_mode_if_needed()

  -- Detect pause/resume: check FSM state or legacy flag
  local is_resuming = self.fsm and self.fsm:get_previous_state() == "paused" or self.is_paused

  if _is_playing(self.proj) then
    Logger.info("TRANSPORT", "SEEK to region '%s' (RID %d) at %.2fs", region.name or "?", region.rid, region.start)
    local region_num = region.rid
    self:_seek_to_region(region_num)
  else
    if is_resuming then
      -- Resuming from pause - just unpause without seeking
      Logger.info("TRANSPORT", "RESUME playback")
      reaper.OnPlayButton()
      self.is_paused = false  -- Clear pause flag (legacy sync, remove in 1.7)
    else
      -- Starting fresh - seek to region start and reset indices
      Logger.info("TRANSPORT", "PLAY '%s' (RID %d) from %.2fs", region.name or "?", region.rid, region.start)
      reaper.SetEditCurPos2(self.proj, region.start, false, false)
      reaper.OnPlayButton()
      self.state.current_idx = -1
      self.state.next_idx = self.state.playlist_pointer
    end
  end

  -- Legacy sync (remove in 1.7)
  self.is_playing = true
  self.is_paused = false

  self.state:update_bounds()

  return true
end

function Transport:stop()
  Logger.info("TRANSPORT", "STOP - resetting to beginning")

  -- FSM transition
  if self.fsm then
    self.fsm:send("stop")
  end

  reaper.OnStopButton()

  -- Legacy sync (remove in 1.7)
  self.is_playing = false
  self.is_paused = false

  self.state.current_idx = -1
  self.state.next_idx = -1
  self.state.playlist_pointer = 1  -- Reset to beginning for next play

  self:_leave_playlist_mode_if_needed()
end

function Transport:pause()
  Logger.info("TRANSPORT", "PAUSE at idx %d", self.state.playlist_pointer)

  -- FSM transition
  if self.fsm then
    -- Store pause position before transitioning
    self.fsm:set_pause_position(reaper.GetPlayPositionEx(self.proj))
    self.fsm:send("pause")
  end

  -- Pause without resetting playlist state (for resume)
  reaper.OnPauseButton()

  -- Legacy sync (remove in 1.7)
  self.is_playing = false
  self.is_paused = true

  -- Don't reset current_idx, next_idx, or playlist_pointer - keep for resume
  -- Don't leave playlist mode - we might resume
end

function Transport:next()
  if #self.state.playlist_order == 0 then return false end
  if self.state.playlist_pointer >= #self.state.playlist_order then
    Logger.debug("TRANSPORT", "NEXT blocked - at end of playlist")
    return false
  end

  self.state.playlist_pointer = self.state.playlist_pointer + 1
  Logger.info("TRANSPORT", "NEXT -> idx %d/%d", self.state.playlist_pointer, #self.state.playlist_order)

  if _is_playing(self.proj) then
    local rid = self.state:get_current_rid()
    local region = self.state:get_region_by_rid(rid)
    if region then
      return self:_seek_to_region(region.rid)
    end
  else
    return self:play()
  end

  return false
end

function Transport:prev()
  if #self.state.playlist_order == 0 then return false end
  if self.state.playlist_pointer <= 1 then
    Logger.debug("TRANSPORT", "PREV blocked - at start of playlist")
    return false
  end

  self.state.playlist_pointer = self.state.playlist_pointer - 1
  Logger.info("TRANSPORT", "PREV -> idx %d/%d", self.state.playlist_pointer, #self.state.playlist_order)

  if _is_playing(self.proj) then
    local rid = self.state:get_current_rid()
    local region = self.state:get_region_by_rid(rid)
    if region then
      return self:_seek_to_region(region.rid)
    end
  else
    return self:play()
  end

  return false
end

function Transport:poll_transport_sync()
  if not self.transport_override then return end

  -- Use FSM state if available
  local currently_playing = self.fsm and self.fsm:is_active() or self.is_playing
  if currently_playing then return end

  if not _is_playing(self.proj) then return end

  local playpos = _get_play_pos(self.proj)

  for i, rid in ipairs(self.state.playlist_order) do
    local region = self.state:get_region_by_rid(rid)
    if region then
      if playpos >= region.start and playpos < region["end"] then
        self.state.playlist_pointer = i
        self.state.current_idx = i

        -- FSM transition: force to playing when transport override takes over
        if self.fsm then
          self.fsm:set_sequence_length(#self.state.playlist_order)
          self.fsm:force("playing")
        end

        -- Legacy sync (remove in 1.7)
        self.is_playing = true

        local meta = self.state.playlist_metadata[i]
        local should_loop = meta and meta.current_loop < meta.reps

        if should_loop then
          self.state.next_idx = i
        else
          if i < #self.state.playlist_order then
            self.state.next_idx = i + 1
          elseif self.loop_playlist and #self.state.playlist_order > 0 then
            self.state.next_idx = 1
          else
            self.state.next_idx = -1
          end
        end

        self.state:update_bounds()
        self:_enter_playlist_mode_if_needed()
        return
      end
    end
  end
end

function Transport:set_transport_override(enabled)
  self.transport_override = not not enabled
end

function Transport:get_transport_override()
  return self.transport_override
end

function Transport:set_follow_viewport(enabled)
  local was_enabled = self.follow_viewport
  self.follow_viewport = not not enabled

  -- If we're already in playlist mode, update smooth scroll state immediately
  if self._playlist_mode then
    if enabled and not was_enabled then
      -- Enabling: save and enable smooth scroll
      if self._old_smooth_scroll == nil then
        self._old_smooth_scroll = reaper.GetToggleCommandState(41817)
        if self._old_smooth_scroll == 0 then
          reaper.Main_OnCommand(41817, 0)
        end
      end
    elseif not enabled and was_enabled then
      -- Disabling: restore smooth scroll
      if self._old_smooth_scroll ~= nil then
        local current_state = reaper.GetToggleCommandState(41817)
        if current_state ~= self._old_smooth_scroll then
          reaper.Main_OnCommand(41817, 0)
        end
        self._old_smooth_scroll = nil
      end
    end
  end
end

function Transport:get_follow_viewport()
  return self.follow_viewport
end

function Transport:set_shuffle_enabled(enabled)
  self.shuffle_enabled = not not enabled
  Logger.info("TRANSPORT", "Shuffle %s", enabled and "ENABLED" or "DISABLED")
  -- Notify state to reshuffle if needed
  if self.state and self.state.on_shuffle_changed then
    self.state:on_shuffle_changed(enabled)
  end
end

function Transport:get_shuffle_enabled()
  return self.shuffle_enabled
end

function Transport:set_shuffle_mode(mode)
  if self.state and self.state.set_shuffle_mode then
    self.state:set_shuffle_mode(mode)
  end
end

function Transport:get_shuffle_mode()
  if self.state and self.state.get_shuffle_mode then
    return self.state:get_shuffle_mode()
  end
  return "true_shuffle"
end

function Transport:set_loop_playlist(enabled)
  self.loop_playlist = not not enabled
end

function Transport:get_loop_playlist()
  return self.loop_playlist
end

function Transport:check_stopped()
  if not _is_playing(self.proj) then
    -- Use FSM state if available, otherwise legacy flags
    local fsm_playing = self.fsm and self.fsm:is("playing", "transitioning")
    local fsm_paused = self.fsm and self.fsm:is("paused")
    local is_active = fsm_playing or (not self.fsm and self.is_playing)
    local is_paused = fsm_paused or (not self.fsm and self.is_paused)

    -- Don't treat pause as a stop - only clear state if we're not paused
    if is_active and not is_paused then
      -- FSM transition
      if self.fsm then
        self.fsm:send("stop")
      end

      -- Legacy sync (remove in 1.7)
      self.is_playing = false

      self.state.current_idx = -1
      self.state.next_idx = -1
      self:_leave_playlist_mode_if_needed()
      return true
    end
  end
  return false
end

-- =============================================================================
-- FSM BACKWARD COMPATIBILITY SHIMS (Phase 1.3)
-- These methods allow gradual migration to FSM-based state management
-- =============================================================================

--- Get playback state - queries FSM with legacy fallback
--- @return string state Current playback state ("idle", "playing", "paused", "transitioning")
function Transport:get_playback_state()
  if self.fsm then
    return self.fsm:get_state()
  end
  -- Legacy fallback
  if self.is_playing then
    return self.is_paused and "paused" or "playing"
  end
  return "idle"
end

--- Sync FSM state with current boolean flags (dual-write helper)
--- Used during migration to keep FSM in sync with legacy booleans
--- @param target string Target state to sync to
function Transport:_sync_fsm_state(target)
  if self.fsm and self.fsm:get_state() ~= target then
    self.fsm:force(target)
  end
end

--- Check if FSM is in specific state(s)
--- @param ... string State names to check
--- @return boolean is_match True if current state matches any argument
function Transport:is_fsm_state(...)
  if self.fsm then
    return self.fsm:is(...)
  end
  return false
end

--- Check if FSM is active (playing or transitioning)
--- @return boolean is_active True if playback is active
function Transport:is_fsm_active()
  if self.fsm then
    return self.fsm:is_active()
  end
  return self.is_playing
end

M.Transport = Transport
M._is_playing = _is_playing
M._get_play_pos = _get_play_pos
M._has_sws = _has_sws
return M