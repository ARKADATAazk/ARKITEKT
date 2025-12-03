-- @noindex
-- core/json.lua - tiny JSON encode/decode (UTF-8, numbers, strings, booleans, nil, arrays, objects)

local M = {}

-- ===== ENCODE =====
local function esc_str(s)
  return s:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\b','\\b'):gsub('\f','\\f')
          :gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t')
end

local function is_array(t)
  local n = 0
  for k,_ in pairs(t) do
    if type(k) ~= 'number' then return false end
    if k > n then n = k end
  end
  for i=1,n do if t[i] == nil then return false end end
  return true
end

local function encode_val(v, pretty, indent, current_indent)
  local tv = type(v)
  if tv == 'string'  then return '"' .. esc_str(v) .. '"'
  elseif tv == 'number' then
    if v ~= v or v == math.huge or v == -math.huge then return 'null' end
    return tostring(v)
  elseif tv == 'boolean' then return v and 'true' or 'false'
  elseif tv == 'nil' then return 'null'
  elseif tv == 'table' then
    if is_array(v) then
      if #v == 0 then return '[]' end
      local out = {}
      if pretty then
        local next_indent = current_indent .. indent
        for i=1,#v do
          out[i] = next_indent .. encode_val(v[i], pretty, indent, next_indent)
        end
        return '[\n' .. table.concat(out, ',\n') .. '\n' .. current_indent .. ']'
      else
        for i=1,#v do out[i] = encode_val(v[i]) end
        return '[' .. table.concat(out, ',') .. ']'
      end
    else
      local out, i = {}, 1
      if pretty then
        -- Sort keys for consistent output
        local sorted_keys = {}
        for k in pairs(v) do sorted_keys[#sorted_keys + 1] = k end
        table.sort(sorted_keys)

        local count = 0
        for _ in pairs(v) do count = count + 1 end
        if count == 0 then return '{}' end

        local next_indent = current_indent .. indent
        for _, k in ipairs(sorted_keys) do
          local val = v[k]
          out[i] = next_indent .. '"' .. esc_str(tostring(k)) .. '": ' .. encode_val(val, pretty, indent, next_indent)
          i = i + 1
        end
        return '{\n' .. table.concat(out, ',\n') .. '\n' .. current_indent .. '}'
      else
        for k,val in pairs(v) do
          out[i] = '"' .. esc_str(tostring(k)) .. '":' .. encode_val(val)
          i = i + 1
        end
        return '{' .. table.concat(out, ',') .. '}'
      end
    end
  else
    return 'null'
  end
end

function M.encode(t, opts)
  opts = opts or {}
  if opts.pretty then
    local indent = opts.indent or '  '
    return encode_val(t, true, indent, '')
  else
    return encode_val(t)
  end
end

-- ===== DECODE =====
-- Lightweight recursive descent parser (good enough for settings)
local function parse_err(msg, s, i) error(('json decode error @%d: %s'):format(i, msg)) end

-- Skip whitespace starting at position i, return new position
local function skip_ws(s, i)
  while true do
    local c = s:sub(i, i)
    if c == ' ' or c == '\n' or c == '\r' or c == '\t' then
      i = i + 1
    else
      return i
    end
  end
end

-- Convert Unicode code point to UTF-8 string
local function codepoint_to_utf8(cp)
  if cp < 0x80 then
    return string.char(cp)
  elseif cp < 0x800 then
    return string.char(0xC0 + cp / 0x40 // 1, 0x80 + (cp % 0x40))
  elseif cp < 0x10000 then
    return string.char(0xE0 + cp / 0x1000 // 1,
                       0x80 + (cp % 0x1000) / 0x40 // 1,
                       0x80 + (cp % 0x40))
  else
    return string.char(0xF0 + cp / 0x40000 // 1,
                       0x80 + (cp % 0x40000) / 0x1000 // 1,
                       0x80 + (cp % 0x1000) / 0x40 // 1,
                       0x80 + (cp % 0x40))
  end
end

local function parse_val(s, i)
  i = skip_ws(s, i)
  local c = s:sub(i,i)
  if c == '"' then -- string
    local j, out = i+1, {}
    while true do
      local ch = s:sub(j,j)
      if ch == '' then parse_err('unterminated string', s, j) end
      if ch == '"' then return table.concat(out), j+1 end
      if ch == '\\' then
        local nx = s:sub(j+1,j+1)
        local map = {['"']='"',['\\']='\\',['/']='/',b='\b',f='\f',n='\n',r='\r',t='\t'}
        if map[nx] then out[#out+1] = map[nx]; j = j + 2
        elseif nx == 'u' then
          -- Parse \uXXXX Unicode escape and convert to UTF-8
          local hex = s:sub(j+2, j+5)
          local cp = tonumber(hex, 16)
          if cp then
            -- Handle surrogate pairs for characters outside BMP
            if cp >= 0xD800 and cp <= 0xDBFF and s:sub(j+6, j+7) == '\\u' then
              local hex2 = s:sub(j+8, j+11)
              local cp2 = tonumber(hex2, 16)
              if cp2 and cp2 >= 0xDC00 and cp2 <= 0xDFFF then
                cp = 0x10000 + (cp - 0xD800) * 0x400 + (cp2 - 0xDC00)
                j = j + 6  -- Extra advance for second surrogate
              end
            end
            out[#out+1] = codepoint_to_utf8(cp)
          else
            out[#out+1] = '?'  -- Invalid hex, use replacement
          end
          j = j + 6
        else parse_err('bad escape', s, j) end
      else
        out[#out+1] = ch; j = j + 1
      end
    end
  elseif c == '{' then
    local obj = {}; i = i + 1
    i = skip_ws(s, i)
    if s:sub(i,i) == '}' then return obj, i+1 end
    while true do
      local key; key, i = parse_val(s, i)
      if type(key) ~= 'string' then parse_err('object key must be string', s, i) end
      i = skip_ws(s, i)
      if s:sub(i,i) ~= ':' then parse_err('colon expected', s, i) end
      i = i + 1
      local val; val, i = parse_val(s, i)
      obj[key] = val
      i = skip_ws(s, i)
      local sep = s:sub(i,i)
      if sep == '}' then return obj, i+1 end
      if sep ~= ',' then parse_err('comma or } expected', s, i) end
      i = i + 1
    end
  elseif c == '[' then
    local arr = {}; i = i + 1
    i = skip_ws(s, i)
    if s:sub(i,i) == ']' then return arr, i+1 end
    local k = 1
    while true do
      local val; val, i = parse_val(s, i)
      arr[k] = val; k = k + 1
      i = skip_ws(s, i)
      local sep = s:sub(i,i)
      if sep == ']' then return arr, i+1 end
      if sep ~= ',' then parse_err('comma or ] expected', s, i) end
      i = i + 1
    end
  elseif s:sub(i,i+3) == 'true' then
    return true, i+4
  elseif s:sub(i,i+4) == 'false' then
    return false, i+5
  elseif s:sub(i,i+3) == 'null' then
    return nil, i+4
  else
    -- Try to parse number
    local j = i
    if s:sub(j,j) == '-' then j = j + 1 end
    if s:sub(j,j) == '0' then
      j = j + 1
    elseif s:sub(j,j):match('[1-9]') then
      while s:sub(j,j):match('%d') do j = j + 1 end
    else
      parse_err('unexpected token', s, i)
    end
    if s:sub(j,j) == '.' then
      j = j + 1
      while s:sub(j,j):match('%d') do j = j + 1 end
    end
    if s:sub(j,j):match('[eE]') then
      j = j + 1
      if s:sub(j,j):match('[+-]') then j = j + 1 end
      while s:sub(j,j):match('%d') do j = j + 1 end
    end
    if j == i then parse_err('unexpected token', s, i) end
    return tonumber(s:sub(i,j-1)), j
  end
end

function M.decode(str)
  if type(str) ~= 'string' or str == '' then return nil end
  local ok, val = pcall(function()
    local v, i = parse_val(str, 1)
    return v
  end)
  return ok and val or nil
end

return M
