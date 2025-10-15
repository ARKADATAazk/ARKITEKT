local C = {}
local hits = {}
local warned = {}
local MODE = rawget(_G, 'ARK_COMPAT_MODE') or 'warn'

local function canonicalize_sequence(sequence)
  return sequence
end

local function emit_warning(name)
  if MODE ~= 'warn' then
    return
  end
  warned[name] = true
  local logger = rawget(_G, 'ARK_COMPAT_LOGGER')
  if type(logger) == 'function' then
    logger(name)
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

function C.install(registry)
  if type(registry) ~= 'table' then
    return
  end
  for name, fn in pairs(registry) do
    registry[name] = wrap(name, fn)
  end
end

function C.report()
  return hits
end

function C.canonicalize_sequence(sequence)
  return canonicalize_sequence(sequence)
end

return C
