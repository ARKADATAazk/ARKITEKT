local Compat = {}
local MODE = rawget(_G, 'ARK_COMPAT_MODE') or 'warn'
local hits, warned = {}, {}

local function canonicalize_sequence(sequence)
  return sequence
end

local function emit_warning(name)
  warned[name] = true
  local logger = rawget(_G, 'ARK_COMPAT_LOGGER')
  if type(logger) == 'function' then
    logger(name)
    return
  end
  local host = rawget(_G, 'reaper')
  local show = host and host.ShowConsoleMsg
  if type(show) == 'function' then
    show('[COMPAT] '..name..'\n')
  end
end

local function wrap(name, fn)
  return function(...)
    hits[name] = (hits[name] or 0) + 1
    if MODE == 'error' then
      error('[COMPAT] '..name, 2)
    end
    if MODE == 'warn' and not warned[name] then
      emit_warning(name)
    end
    if type(fn) == 'function' then
      return fn(...)
    end
  end
end

function Compat.install()
  local ok_state, State = pcall(require, 'Region_Playlist.core.state')
  if ok_state and type(State) == 'table' then
    if State.region_index == nil then
      State.region_index = wrap('state.region_index', function(self)
        if type(self) ~= 'table' then
          return nil
        end
        local selection = rawget(self, 'selection')
        if type(selection) == 'table' then
          local active = rawget(selection, 'active') or selection
          if type(active) == 'table' then
            return active.index
          end
        end
        return nil
      end)
    end

    if rawget(State, 'bridge') == nil then
      rawset(State, 'bridge', wrap('state.bridge', function(self)
        if type(self) ~= 'table' then
          return nil
        end
        local playback = rawget(self, 'playback')
        if type(playback) == 'table' then
          return rawget(playback, 'coordinator')
        end
        return nil
      end))
    end
  end

  local ok_tiles, TilesCoordinator = pcall(require, 'Region_Playlist.widgets.region_tiles.coordinator')
  if ok_tiles and type(TilesCoordinator) == 'table' then
    local ok_new, NewCoordinator = pcall(require, 'Region_Playlist.playback.coordinator')
    if not TilesCoordinator.get_transport_override and ok_new and type(NewCoordinator) == 'table' then
      if type(NewCoordinator.get_transport_override) == 'function' then
        TilesCoordinator.get_transport_override = wrap('coordinator.get_transport_override', function(self, ...)
          return NewCoordinator.get_transport_override(self, ...)
        end)
      end
    end
  end
end

function Compat.report()
  return hits
end

function Compat.canonicalize_sequence(sequence)
  return canonicalize_sequence(sequence)
end

return Compat
