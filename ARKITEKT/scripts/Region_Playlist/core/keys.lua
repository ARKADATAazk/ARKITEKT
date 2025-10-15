local Keys = {}

local counter = 0

local function normalize_token(value, fallback)
  if value == nil then return fallback end
  local t = tostring(value)
  if t == '' then return fallback end
  return t
end

function Keys.generate_item_key(kind, id)
  counter = counter + 1
  local kind_token = normalize_token(kind, 'it')
  local id_token = normalize_token(id, 'x')
  local timestamp = os.time()
  return string.format('%s_%s_%d_%d', kind_token, id_token, timestamp, counter)
end

return Keys
