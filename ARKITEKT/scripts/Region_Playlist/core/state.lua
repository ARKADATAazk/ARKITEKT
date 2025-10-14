local State = {}

local DEFAULT_STATE = {
  playlists = { active_id = nil, items = {}, sequence_cache = nil },
  playback  = { is_playing = false, loop = false, cursor_pos = 0 },
  regions   = { by_id = {} },
  ui        = { selection = {}, panel_state = {} },
}

local instances = {}

local function deepcopy(v)
  if type(v) ~= 'table' then return v end
  local t = {}
  for k, x in pairs(v) do t[k] = deepcopy(x) end
  return t
end

local function split_path(key_path)
  local out = {}
  if type(key_path) == 'string' then
    for seg in string.gmatch(key_path, "[^%.]+") do out[#out+1] = seg end
  elseif type(key_path) == 'table' then
    for i=1,#key_path do out[i] = key_path[i] end
  else
    error('keyPath must be a string or table')
  end
  if #out == 0 then error('keyPath cannot be empty') end
  return out
end

local Instance = {}
Instance.__index = Instance

local function create_instance(project_id)
  local self = setmetatable({
    _project_id = tonumber(project_id) or 0,
    _state = deepcopy(DEFAULT_STATE),
    _listeners = {},
    _reg = {},
    _next_id = 1,
    _tx = false,
    _pending = {},
  }, Instance)
  return self
end

function Instance:get(key_path)
  local path = split_path(key_path)
  local v = self._state
  for i = 1, #path do
    v = v[path[i]]
    if v == nil then break end
  end
  return deepcopy(v)
end

local function ensure_table(parent, key)
  local v = parent[key]
  if type(v) ~= 'table' then v = {}; parent[key] = v end
  return v
end

function Instance:set(key_path, value)
  local path = split_path(key_path)
  local domain = path[1]
  if #path == 1 then
    if type(value) == 'table' then
      local t = {}; for k,v in pairs(value) do t[k] = deepcopy(v) end
      self._state[domain] = t
    else
      self._state[domain] = value
    end
  else
    local t = self._state
    for i = 1, #path-1 do
      t = ensure_table(t, path[i])
    end
    t[path[#path]] = deepcopy(value)
  end
  if self._tx then
    self._pending[domain] = true
  else
    self:emit(domain..'.changed', deepcopy(self._state[domain]))
  end
end

function Instance:tx(fn)
  if self._tx then error('transaction already in progress') end
  if type(fn) ~= 'function' then error('transaction callback must be a function') end
  self._tx = true; self._pending = {}
  local ok, err = pcall(fn, self)
  self._tx = false
  if not ok then error(err) end
  for domain in pairs(self._pending) do
    self:emit(domain..'.changed', deepcopy(self._state[domain]))
  end
  self._pending = {}
  return true
end

function Instance:on(event, handler)
  if type(event) ~= 'string' then error('event must be a string') end
  if type(handler) ~= 'function' then error('handler must be a function') end
  local id = self._next_id; self._next_id = id + 1
  local list = self._listeners[event]; if not list then list = {}; self._listeners[event] = list end
  list[id] = handler; self._reg[id] = event
  return id
end

function Instance:off(id)
  local ev = self._reg[id]; if not ev then return end
  self._reg[id] = nil
  local list = self._listeners[ev]
  if list then list[id] = nil; if next(list) == nil then self._listeners[ev] = nil end end
end

function Instance:emit(event, payload)
  if self._tx then return end
  local list = self._listeners[event]; if not list then return end
  local snapshot = {}
  for _,h in pairs(list) do snapshot[#snapshot+1] = h end
  for i=1,#snapshot do pcall(snapshot[i], payload) end
end

function State.for_project(project_id)
  local id = tonumber(project_id) or 0
  if not instances[id] then instances[id] = create_instance(id) end
  return instances[id]
end

return State
