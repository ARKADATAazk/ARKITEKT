-- @noindex
-- WalterBuilder/domain/expression_eval.lua
-- WALTER expression evaluator
--
-- Evaluates WALTER coordinate expressions like:
--   + [10 20] [5 5]           -> addition
--   * scale [300 100]         -> multiplication with scalar
--   ?condition [true] [false] -> conditional
--   h<100 [small] [big]       -> comparison conditional
--   element{0}                -> array indexing
--
-- WALTER uses prefix notation (Polish notation)

local Coordinate = require('WalterBuilder.domain.coordinate')

local M = {}

-- Map @position names to array indices
-- @x or @0 = 1, @y or @1 = 2, @w or @2 = 3, etc. (1-indexed for Lua)
local POSITION_MAP = {
  x = 1, ["0"] = 1,
  y = 2, ["1"] = 2,
  w = 3, ["2"] = 3,
  h = 4, ["3"] = 4,
  ls = 5, ["4"] = 5,
  ts = 6, ["5"] = 6,
  rs = 7, ["6"] = 7,
  bs = 8, ["7"] = 8,
}

-- Create a sparse coordinate array with value at the given position
-- e.g., make_at_position(40, "y") -> {0, 40}
-- e.g., make_at_position(1, "w") -> {0, 0, 1}
local function make_at_position(value, pos_name)
  local pos = POSITION_MAP[pos_name]
  if not pos then return { value } end

  local result = {}
  for i = 1, pos - 1 do
    result[i] = 0
  end
  result[pos] = value
  return result
end

-- Default scalar values for common variables
-- These approximate typical values at 100% DPI and provide reasonable defaults for visualization
M.DEFAULT_SCALARS = {
  -- DPI scaling
  scale = 1.0,

  -- Panel dimensions (set at runtime)
  w = 300,  -- parent width
  h = 90,   -- parent height

  -- Track state (for conditionals) - defaults for visualization
  recarm = 0,
  track_selected = 1,  -- Show as if track is selected
  mixer_visible = 0,
  trackcolor_valid = 0,
  folderstate = 0,
  folderdepth = 0,
  maxfolderdepth = 3,
  supercollapsed = 0,

  -- Common computed values (approximations)
  tcp_padding = 7,
  meter_sec = 50,
  main_sec = 200,
  folder_sec = 20,
  element_h = 20,
  soloFlip_h = 52,

  -- Common conditionals (assume visible/enabled by default)
  is_solo_flipped = 0,
  hide_mute_group = 0,
  hide_fx_group = 0,
  hide_pan_group = 0,
  hide_io_group = 0,
  trackpanmode = 0,

  -- Theme variant
  theme_version = 1,
  theme_variant = 0,

  -- Main font
  main_font = 1,

  -- Version info
  reaper_version = 7,
  os_type = 0,  -- 0=Windows, 1=macOS, 2=Linux
}

-- Tokenize an expression string
local function tokenize(expr)
  local tokens = {}
  local i = 1
  local len = #expr

  while i <= len do
    local c = expr:sub(i, i)

    -- Skip whitespace
    if c:match("%s") then
      i = i + 1

    -- Bracket expression [...]
    elseif c == "[" then
      local j = i + 1
      local depth = 1
      while j <= len and depth > 0 do
        local ch = expr:sub(j, j)
        if ch == "[" then depth = depth + 1
        elseif ch == "]" then depth = depth - 1
        end
        j = j + 1
      end
      tokens[#tokens + 1] = { type = "bracket", value = expr:sub(i, j - 1) }
      i = j

    -- Operators
    elseif c == "+" then
      tokens[#tokens + 1] = { type = "op", value = "+" }
      i = i + 1
    elseif c == "-" and not expr:sub(i + 1, i + 1):match("%d") then
      tokens[#tokens + 1] = { type = "op", value = "-" }
      i = i + 1
    elseif c == "*" then
      tokens[#tokens + 1] = { type = "op", value = "*" }
      i = i + 1
    elseif c == "/" then
      tokens[#tokens + 1] = { type = "op", value = "/" }
      i = i + 1
    elseif c == "?" then
      tokens[#tokens + 1] = { type = "cond", value = "?" }
      i = i + 1
    elseif c == "!" then
      tokens[#tokens + 1] = { type = "not", value = "!" }
      i = i + 1

    -- Comparison operators
    elseif c == "<" and expr:sub(i + 1, i + 1) == "=" then
      tokens[#tokens + 1] = { type = "cmp", value = "<=" }
      i = i + 2
    elseif c == ">" and expr:sub(i + 1, i + 1) == "=" then
      tokens[#tokens + 1] = { type = "cmp", value = ">=" }
      i = i + 2
    elseif c == "=" and expr:sub(i + 1, i + 1) == "=" then
      tokens[#tokens + 1] = { type = "cmp", value = "==" }
      i = i + 2
    elseif c == "!" and expr:sub(i + 1, i + 1) == "=" then
      tokens[#tokens + 1] = { type = "cmp", value = "!=" }
      i = i + 2
    elseif c == "<" then
      tokens[#tokens + 1] = { type = "cmp", value = "<" }
      i = i + 1
    elseif c == ">" then
      tokens[#tokens + 1] = { type = "cmp", value = ">" }
      i = i + 1

    -- Number (including negative), possibly with @position suffix
    elseif c:match("[%d%-]") then
      local j = i
      while j <= len and expr:sub(j, j):match("[%d%.%-]") do
        j = j + 1
      end
      local num_val = tonumber(expr:sub(i, j - 1))

      -- Check for @position suffix (e.g., 40@y, 1@w)
      local at_pos = nil
      if expr:sub(j, j) == "@" then
        local k = j + 1
        while k <= len and expr:sub(k, k):match("[%w]") do
          k = k + 1
        end
        at_pos = expr:sub(j + 1, k - 1)
        j = k
      end

      tokens[#tokens + 1] = { type = "number", value = num_val, at_pos = at_pos }
      i = j

    -- Identifier (variable name, possibly with {index} and/or @position)
    elseif c:match("[%a_]") then
      local j = i
      while j <= len and expr:sub(j, j):match("[%w_.]") do
        j = j + 1
      end
      local name = expr:sub(i, j - 1)

      -- Check for array index {n}
      local index = nil
      if expr:sub(j, j) == "{" then
        local k = j + 1
        while k <= len and expr:sub(k, k) ~= "}" do
          k = k + 1
        end
        index = tonumber(expr:sub(j + 1, k - 1))
        j = k + 1
      end

      -- Check for @position suffix (e.g., recarm@w)
      local at_pos = nil
      if expr:sub(j, j) == "@" then
        local k = j + 1
        while k <= len and expr:sub(k, k):match("[%w]") do
          k = k + 1
        end
        at_pos = expr:sub(j + 1, k - 1)
        j = k
      end

      tokens[#tokens + 1] = { type = "ident", value = name, index = index, at_pos = at_pos }
      i = j

    -- Dot (standalone, used in some contexts)
    elseif c == "." then
      tokens[#tokens + 1] = { type = "dot", value = "." }
      i = i + 1

    -- Backslash (line continuation - skip)
    elseif c == "\\" then
      i = i + 1

    else
      -- Unknown character, skip
      i = i + 1
    end
  end

  return tokens
end

-- Parse a bracket expression into a coordinate array
-- Handles both simple numbers and variable references
-- @param str: The bracket expression string "[x y w h ...]"
-- @param context: The evaluation context for resolving variables
local function parse_bracket(str, context)
  local content = str:match("^%[(.*)%]$")
  if not content then return nil end

  local values = {}

  -- Parse each space-separated token in the bracket
  for token in content:gmatch("%S+") do
    -- Check if it's a number
    local num = tonumber(token)
    if num then
      values[#values + 1] = num
    else
      -- It's a variable reference, possibly with {index}
      local var_name, index_str = token:match("^([%w_.]+){(%d+)}$")
      if var_name then
        -- Variable with index: foo{0}
        local index = tonumber(index_str)
        local var_val = context and context[var_name]
        if type(var_val) == "table" then
          values[#values + 1] = var_val[index + 1] or 0  -- 0-indexed to 1-indexed
        elseif var_val then
          values[#values + 1] = var_val
        else
          values[#values + 1] = M.DEFAULT_SCALARS[var_name] or 0
        end
      else
        -- Simple variable reference
        var_name = token:match("^([%w_.]+)$")
        if var_name then
          local var_val = context and context[var_name]
          if type(var_val) == "table" then
            values[#values + 1] = var_val[1] or 0
          elseif var_val then
            values[#values + 1] = var_val
          else
            values[#values + 1] = M.DEFAULT_SCALARS[var_name] or 0
          end
        else
          -- Unknown token, use 0
          values[#values + 1] = 0
        end
      end
    end
  end

  return values
end

-- Get a scalar value from context
local function get_scalar(name, context, index)
  -- Check context first
  local value = context[name]
  if value == nil then
    value = M.DEFAULT_SCALARS[name]
  end
  if value == nil then
    value = 0  -- Unknown variable defaults to 0
  end

  -- If it's an array and we have an index, get that element
  if type(value) == "table" and index then
    return value[index + 1] or 0  -- Lua 1-indexed, WALTER 0-indexed
  end

  -- If we want an index from a scalar, return the scalar
  if index then
    return value
  end

  return value
end

-- Evaluate a binary operation on two coordinate arrays
local function eval_op(op, a, b)
  -- Ensure both are arrays of same length
  local result = {}
  local len = math.max(#a, #b)

  for i = 1, len do
    local av = a[i] or 0
    local bv = b[i] or 0

    if op == "+" then
      result[i] = av + bv
    elseif op == "-" then
      result[i] = av - bv
    elseif op == "*" then
      result[i] = av * bv
    elseif op == "/" then
      result[i] = bv ~= 0 and av / bv or 0
    end
  end

  return result
end

-- Multiply coordinate array by scalar
local function scale_array(arr, scalar)
  local result = {}
  for i, v in ipairs(arr) do
    result[i] = v * scalar
  end
  return result
end

-- Evaluate comparison
local function eval_cmp(op, a, b)
  if op == "<" then return a < b
  elseif op == ">" then return a > b
  elseif op == "<=" then return a <= b
  elseif op == ">=" then return a >= b
  elseif op == "==" then return a == b
  elseif op == "!=" then return a ~= b
  end
  return false
end

-- Main expression parser/evaluator
-- Returns a coordinate array [x, y, w, h, ls, ts, rs, bs] or nil
local function eval_tokens(tokens, pos, context)
  if pos > #tokens then
    return nil, pos
  end

  local token = tokens[pos]

  -- Bracket expression - direct coordinate (may contain variable references)
  if token.type == "bracket" then
    local values = parse_bracket(token.value, context)
    return values, pos + 1
  end

  -- Number - scalar value, possibly with @position
  if token.type == "number" then
    if token.at_pos then
      -- e.g., 40@y -> {0, 40}
      return make_at_position(token.value, token.at_pos), pos + 1
    end
    return { token.value }, pos + 1
  end

  -- Identifier - variable reference, possibly with @position
  if token.type == "ident" then
    local value = get_scalar(token.value, context, token.index)
    local result
    if type(value) == "table" then
      result = value
    else
      result = { value }
    end

    -- Handle @position suffix (e.g., recarm@w)
    if token.at_pos then
      local scalar = result[1] or 0
      return make_at_position(scalar, token.at_pos), pos + 1
    end

    return result, pos + 1
  end

  -- Binary operator (prefix notation)
  if token.type == "op" then
    local op = token.value

    -- Get first operand
    local a, next_pos = eval_tokens(tokens, pos + 1, context)
    if not a then return nil, next_pos end

    -- Get second operand
    local b
    b, next_pos = eval_tokens(tokens, next_pos, context)
    if not b then return nil, next_pos end

    -- If one is a single scalar, scale the other
    if #a == 1 and #b > 1 then
      return scale_array(b, a[1]), next_pos
    elseif #b == 1 and #a > 1 then
      return scale_array(a, b[1]), next_pos
    end

    return eval_op(op, a, b), next_pos
  end

  -- Conditional: ?var [true] [false] or comparison: a<b [true] [false]
  if token.type == "cond" or token.type == "not" then
    local is_negated = token.type == "not"
    local start_pos = pos + 1

    -- Get the condition variable/expression
    local cond_token = tokens[start_pos]
    if not cond_token then return nil, start_pos end

    local condition = false
    local next_pos = start_pos + 1

    if cond_token.type == "ident" then
      local val = get_scalar(cond_token.value, context, cond_token.index)
      if type(val) == "table" then val = val[1] or 0 end
      condition = val ~= 0
    elseif cond_token.type == "number" then
      condition = cond_token.value ~= 0
    end

    if is_negated then
      condition = not condition
    end

    -- Get true branch
    local true_val, pos_after_true = eval_tokens(tokens, next_pos, context)
    if not true_val then return nil, pos_after_true end

    -- Get false branch
    local false_val, pos_after_false = eval_tokens(tokens, pos_after_true, context)
    if not false_val then
      -- No false branch, use true value or zero
      return condition and true_val or { 0 }, pos_after_true
    end

    return condition and true_val or false_val, pos_after_false
  end

  -- Comparison: ident<value [true] [false]
  if token.type == "ident" then
    local next_token = tokens[pos + 1]
    if next_token and next_token.type == "cmp" then
      local cmp_op = next_token.value
      local lhs = get_scalar(token.value, context, token.index)
      if type(lhs) == "table" then lhs = lhs[1] or 0 end

      local rhs_token = tokens[pos + 2]
      local rhs = 0
      local cmp_end = pos + 3

      if rhs_token then
        if rhs_token.type == "number" then
          rhs = rhs_token.value
        elseif rhs_token.type == "ident" then
          rhs = get_scalar(rhs_token.value, context, rhs_token.index)
          if type(rhs) == "table" then rhs = rhs[1] or 0 end
        end
      end

      local condition = eval_cmp(cmp_op, lhs, rhs)

      -- Get true branch
      local true_val, pos_after_true = eval_tokens(tokens, cmp_end, context)
      if not true_val then return nil, pos_after_true end

      -- Get false branch
      local false_val, pos_after_false = eval_tokens(tokens, pos_after_true, context)
      if not false_val then
        return condition and true_val or { 0 }, pos_after_true
      end

      return condition and true_val or false_val, pos_after_false
    end
  end

  -- Dot means "keep current value" - return nil to indicate no change
  if token.type == "dot" then
    return nil, pos + 1
  end

  -- Unknown token, skip
  return nil, pos + 1
end

-- Main evaluation function
-- @param expr: The expression string
-- @param context: Table of variable values (w, h, scale, etc.)
-- @return: Coordinate array or nil
function M.evaluate(expr, context)
  if not expr or expr == "" then
    return nil
  end

  context = context or {}

  -- Set w and h in context if not provided
  context.w = context.w or M.DEFAULT_SCALARS.w
  context.h = context.h or M.DEFAULT_SCALARS.h

  local tokens = tokenize(expr)
  if #tokens == 0 then
    return nil
  end

  local result, _ = eval_tokens(tokens, 1, context)
  return result
end

-- Convert evaluated result to Coordinate object
function M.to_coordinate(values)
  if not values or #values == 0 then
    return nil
  end

  return Coordinate.new({
    x = values[1] or 0,
    y = values[2] or 0,
    w = values[3] or 0,
    h = values[4] or 0,
    ls = values[5] or 0,
    ts = values[6] or 0,
    rs = values[7] or 0,
    bs = values[8] or 0,
  })
end

-- Convenience: evaluate and return Coordinate
function M.eval_to_coord(expr, context)
  local values = M.evaluate(expr, context)
  return M.to_coordinate(values)
end

return M
