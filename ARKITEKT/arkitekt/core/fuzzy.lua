-- @noindex
-- arkitekt/core/fuzzy.lua
-- Fuzzy string matching for search functionality

local M = {}

-- Score weights for fuzzy matching
local SCORE = {
  MATCH = 16,           -- Base score for a character match
  CONSECUTIVE = 32,     -- Bonus for consecutive matches
  WORD_START = 24,      -- Bonus for matching at start of a word
  FIRST_CHAR = 16,      -- Bonus for matching first character
  GAP_START = -3,       -- Penalty for starting a gap
  GAP_EXTEND = -1,      -- Penalty for each gap character
}

-- Characters that indicate word boundaries
local WORD_SEPARATORS = {
  [' '] = true, ['-'] = true, ['_'] = true,
  ['.'] = true, ['/'] = true, ['\\'] = true,
  ['('] = true, [')'] = true, [':'] = true,
}

-- Check if character is at a word boundary
local function is_word_start(str, pos)
  if pos == 1 then return true end
  local prev_char = str:sub(pos - 1, pos - 1)
  return WORD_SEPARATORS[prev_char] or false
end

-- Check if character is uppercase after lowercase (camelCase boundary)
local function is_camel_boundary(str, pos)
  if pos == 1 then return false end
  local curr = str:sub(pos, pos)
  local prev = str:sub(pos - 1, pos - 1)
  return curr:match('%u') and prev:match('%l')
end

--- Calculate fuzzy match score between query and target
--- @param query string Search query
--- @param target string String to match against
--- @return number score Score (0 if no match)
--- @return table positions Array of match positions in target
function M.score(query, target)
  if not query or query == '' then
    return 0, {}
  end
  if not target or target == '' then
    return 0, {}
  end

  local query_lower = query:lower()
  local target_lower = target:lower()
  local query_len = #query_lower
  local target_len = #target_lower

  -- Quick check: all query characters must exist in target
  local qi = 1
  for ti = 1, target_len do
    if target_lower:sub(ti, ti) == query_lower:sub(qi, qi) then
      qi = qi + 1
      if qi > query_len then break end
    end
  end
  if qi <= query_len then
    return 0, {}  -- Not all characters found
  end

  -- Greedy matching with scoring
  local positions = {}
  local match_score = 0
  qi = 1
  local prev_match_pos = 0
  local in_gap = false

  for ti = 1, target_len do
    if qi > query_len then break end

    local query_char = query_lower:sub(qi, qi)
    local target_char = target_lower:sub(ti, ti)

    if target_char == query_char then
      -- Match found
      positions[#positions + 1] = ti
      match_score = match_score + SCORE.MATCH

      -- Consecutive match bonus
      if prev_match_pos == ti - 1 then
        match_score = match_score + SCORE.CONSECUTIVE
      end

      -- Word boundary bonus
      if is_word_start(target, ti) or is_camel_boundary(target, ti) then
        match_score = match_score + SCORE.WORD_START
      end

      -- First character bonus
      if qi == 1 then
        match_score = match_score + SCORE.FIRST_CHAR
      end

      prev_match_pos = ti
      in_gap = false
      qi = qi + 1
    else
      -- Gap
      if not in_gap and prev_match_pos > 0 then
        match_score = match_score + SCORE.GAP_START
        in_gap = true
      elseif in_gap then
        match_score = match_score + SCORE.GAP_EXTEND
      end
    end
  end

  -- Ensure all query characters were matched
  if qi <= query_len then
    return 0, {}
  end

  -- Normalize score slightly by query length (longer queries = more potential score)
  match_score = match_score + (query_len * 2)

  return math.max(match_score, 1), positions
end

--- Check if query fuzzy-matches target
--- @param query string Search query
--- @param target string String to match against
--- @return boolean matches True if query matches target
function M.matches(query, target)
  local s = M.score(query, target)
  return s > 0
end

--- Filter and sort a list of items by fuzzy match score
--- @param items table Array of items to filter
--- @param get_text function Function(item) -> string to match against
--- @param query string Search query
--- @return table results Array of {item, score, positions} sorted by score descending
function M.filter(items, get_text, query)
  if not query or query == '' then
    -- No query: return all items with score 0
    local results = {}
    for _, item in ipairs(items) do
      results[#results + 1] = { item = item, score = 0, positions = {} }
    end
    return results
  end

  local results = {}

  for _, item in ipairs(items) do
    local text = get_text(item)
    local s, positions = M.score(query, text)

    if s > 0 then
      results[#results + 1] = {
        item = item,
        score = s,
        positions = positions,
      }
    end
  end

  -- Sort by score descending
  table.sort(results, function(a, b)
    return a.score > b.score
  end)

  return results
end

--- Filter items and return just the items (not scores)
--- @param items table Array of items to filter
--- @param get_text function Function(item) -> string to match against
--- @param query string Search query
--- @return table filtered Array of matching items sorted by score
function M.filter_items(items, get_text, query)
  local results = M.filter(items, get_text, query)
  local filtered = {}
  for _, result in ipairs(results) do
    filtered[#filtered + 1] = result.item
  end
  return filtered
end

return M
