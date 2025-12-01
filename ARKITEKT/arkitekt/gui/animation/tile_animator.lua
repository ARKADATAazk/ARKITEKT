-- @noindex
-- Arkitekt/gui/fx/tile_motion.lua
-- Per-tile animation state for smooth hover/active/selection transitions (refactored)
-- Manages multiple animation tracks per tile using extracted Track class

local Tracks = require('arkitekt.gui.animation.tracks')
local Track = Tracks.Track

local M = {}

-- Snap threshold for considering animation settled
local SNAP_EPSILON = 0.001

local TileAnimator = {}
TileAnimator.__index = TileAnimator

function M.new(default_speed)
  return setmetatable({
    tracks = {},
    default_speed = default_speed or 12.0,
    -- Track which tiles need updating (settled tiles are skipped)
    active_tiles = {},  -- tile_id -> true if any track is animating
  }, TileAnimator)
end

function TileAnimator:track(tile_id, track_name, target, speed)
  speed = speed or self.default_speed

  local tile_tracks = self.tracks[tile_id]
  if not tile_tracks then
    tile_tracks = {}
    self.tracks[tile_id] = tile_tracks
  end

  local t = tile_tracks[track_name]
  if not t then
    t = Track.new(target, speed)
    tile_tracks[track_name] = t
    -- New track starts settled if created at target
  else
    -- OPTIMIZATION: Only update if target changed
    if t.target ~= target then
      t.target = target  -- Direct field access instead of t:to(target)
      -- Mark tile as active since target changed
      self.active_tiles[tile_id] = true
    end
    -- OPTIMIZATION: Only update speed if changed
    if t.speed ~= speed then
      t.speed = speed  -- Direct field access instead of t:set_speed(speed)
    end
  end
end

-- OPTIMIZATION: Combined track + get in one call (reduces lookups from 2 to 1 per track)
-- Returns current value after setting target
function TileAnimator:track_get(tile_id, track_name, target, speed)
  speed = speed or self.default_speed

  local tile_tracks = self.tracks[tile_id]
  if not tile_tracks then
    tile_tracks = {}
    self.tracks[tile_id] = tile_tracks
  end

  local t = tile_tracks[track_name]
  if not t then
    t = Track.new(target, speed)
    tile_tracks[track_name] = t
    return target  -- New track starts at target
  else
    if t.target ~= target then
      t.target = target
      self.active_tiles[tile_id] = true
    end
    if t.speed ~= speed then
      t.speed = speed
    end
    return t.current
  end
end

function TileAnimator:update(dt)
  -- OPTIMIZATION: Only update tiles that are actively animating
  -- With 500 items idle, this reduces updates from ~3000 to ~0
  for tile_id in pairs(self.active_tiles) do
    local tile_tracks = self.tracks[tile_id]
    if tile_tracks then
      local all_settled = true
      for track_name, track in pairs(tile_tracks) do
        track:update(dt)
        -- Check if this track is still animating
        if track:is_animating(SNAP_EPSILON) then
          all_settled = false
        end
      end
      -- Remove from active set if all tracks settled
      if all_settled then
        self.active_tiles[tile_id] = nil
      end
    else
      -- Tile was removed, clean up
      self.active_tiles[tile_id] = nil
    end
  end
end

function TileAnimator:get(tile_id, track_name)
  local tile_tracks = self.tracks[tile_id]
  if not tile_tracks then return 0 end
  local t = tile_tracks[track_name]
  if not t then return 0 end
  return t.current  -- Direct field access instead of t:get()
end

function TileAnimator:clear()
  self.tracks = {}
  self.active_tiles = {}
end

function TileAnimator:remove_tile(tile_id)
  self.tracks[tile_id] = nil
  self.active_tiles[tile_id] = nil
end

return M