local SequenceExpander = require("Region_Playlist.app.sequence_expander")
local StateStore = require("Region_Playlist.core.state")

local Sequencer = {}
Sequencer.__index = Sequencer

local function state_for(self)
  return StateStore.for_project(self.proj or 0)
end

local function ensure_bucket(map, key)
  local bucket = map[key]
  if not bucket then
    bucket = {}
    map[key] = bucket
  end
  return bucket
end

function Sequencer.new(opts)
  opts = opts or {}
  local self = setmetatable({
    proj = opts.proj or 0,
    get_playlist_by_id = opts.get_playlist_by_id,
    _cache_sequence = {},
    _lookup = {},
    _dirty = true,
    _active_playlist_id = nil,
  }, Sequencer)
  return self
end

function Sequencer:set_playlist_lookup(fn)
  if self.get_playlist_by_id ~= fn then
    self.get_playlist_by_id = fn
    self:invalidate()
  end
end

function Sequencer:invalidate()
  self._cache_sequence = {}
  self._lookup = {}
  self._dirty = true
  self._active_playlist_id = nil
end

function Sequencer:_resolve_active_playlist_id(state)
  if not state then
    return nil
  end
  return state:get("playlists.active_id")
end

function Sequencer:_fetch_playlist(playlist_id)
  if playlist_id == nil then
    return nil
  end
  local getter = self.get_playlist_by_id
  if type(getter) ~= "function" then
    return nil
  end
  return getter(playlist_id)
end

function Sequencer:_rebuild(playlist_id)
  local playlist = self:_fetch_playlist(playlist_id)
  local sequence = {}

  if playlist then
    sequence = SequenceExpander.expand_playlist(playlist, self.get_playlist_by_id) or {}
  end

  local lookup = {}
  for index, entry in ipairs(sequence) do
    local key = entry and entry.item_key
    if key ~= nil then
      local bucket = ensure_bucket(lookup, key)
      bucket[#bucket + 1] = index
    end
  end

  self._cache_sequence = sequence
  self._lookup = lookup
  self._active_playlist_id = playlist_id
  self._dirty = false
end

function Sequencer:get_sequence()
  local state = state_for(self)
  local playlist_id = self:_resolve_active_playlist_id(state)

  if self._dirty or playlist_id ~= self._active_playlist_id then
    self:_rebuild(playlist_id)
  end

  return self._cache_sequence
end

function Sequencer:find_by_key(key)
  if key == nil then
    return nil
  end

  local sequence = self:get_sequence()
  local matches = self._lookup[key]
  if not matches or #matches == 0 then
    return nil
  end

  local first_index = matches[1]
  return sequence[first_index], first_index
end

local M = {}

function M.new(opts)
  return Sequencer.new(opts)
end

M.Sequencer = Sequencer

return M
