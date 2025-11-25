-- @noindex
-- arkitekt/core/shuffle.lua
-- Generic shuffle algorithms with different modes
-- Extracted from RegionPlaylist engine_state for reuse

local M = {}

--- Fisher-Yates shuffle algorithm (in-place)
--- This is a true shuffle - each item appears exactly once before reshuffling
--- WARNING: Using seed sets global math.randomseed(), affecting all random generation.
--- For isolated randomness, use ShuffleManager which generates fresh seeds per shuffle.
--- @param array table Array to shuffle (modified in-place)
--- @param seed? number Optional seed for reproducibility (affects global state!)
--- @return table array The shuffled array (same reference)
function M.fisher_yates(array, seed)
  if #array <= 1 then return array end

  -- Set seed if provided (WARNING: this is global state)
  if seed then
    math.randomseed(seed)
  end

  -- Fisher-Yates algorithm
  for i = #array, 2, -1 do
    local j = math.random(1, i)
    array[i], array[j] = array[j], array[i]
  end

  return array
end

--- Fisher-Yates shuffle that returns a new array (non-destructive)
--- @param array table Array to shuffle (original not modified)
--- @param seed? number Optional seed for reproducibility
--- @return table shuffled New shuffled array
function M.fisher_yates_copy(array, seed)
  local copy = {}
  for i, v in ipairs(array) do
    copy[i] = v
  end
  return M.fisher_yates(copy, seed)
end

--- Generate a random seed based on current time
--- Useful for creating non-reproducible shuffles
--- @return number seed Random seed value
function M.generate_seed()
  return math.floor(reaper.time_precise() * 1000000) % 2147483647
end

--- Shuffle with automatic seed generation
--- @param array table Array to shuffle (modified in-place)
--- @return table array The shuffled array
function M.shuffle(array)
  return M.fisher_yates(array, M.generate_seed())
end

--- Shuffle Mode Manager
--- Provides stateful shuffling with different modes
local ShuffleManager = {}
ShuffleManager.__index = ShuffleManager

--- Create a new shuffle manager
--- @param array table Initial array to manage
--- @param opts? table Options
---   - mode: string "true_shuffle" or "random" (default: "true_shuffle")
---   - auto_reshuffle: boolean Auto reshuffle when exhausted (default: true)
--- @return table manager The shuffle manager
function M.new_manager(array, opts)
  opts = opts or {}

  local self = setmetatable({
    original = array,
    shuffled = {},
    current_index = 1,
    mode = opts.mode or "true_shuffle",
    auto_reshuffle = opts.auto_reshuffle ~= false,
    seed = nil,
    last_item = nil,
  }, ShuffleManager)

  self:reshuffle()
  return self
end

--- Reshuffle the array
function ShuffleManager:reshuffle()
  -- Copy original array
  self.shuffled = {}
  for i, v in ipairs(self.original) do
    self.shuffled[i] = v
  end

  -- Generate new seed for each shuffle
  self.seed = M.generate_seed()

  if self.mode == "true_shuffle" then
    -- Fisher-Yates: play each item once before reshuffling
    M.fisher_yates(self.shuffled, self.seed)
  elseif self.mode == "random" then
    -- Pure random: can repeat items, but try to avoid consecutive repeats
    M.fisher_yates(self.shuffled, self.seed)

    -- If first item is same as last item from previous shuffle, swap it
    if self.last_item and self.shuffled[1] == self.last_item and #self.shuffled > 1 then
      local swap_index = math.random(2, #self.shuffled)
      self.shuffled[1], self.shuffled[swap_index] = self.shuffled[swap_index], self.shuffled[1]
    end
  end

  self.current_index = 1
end

--- Get next item in shuffle
--- @return any? item Next item, or nil if exhausted and no auto_reshuffle
function ShuffleManager:next()
  if self.current_index > #self.shuffled then
    if self.auto_reshuffle then
      self:reshuffle()
    else
      return nil
    end
  end

  local item = self.shuffled[self.current_index]
  self.current_index = self.current_index + 1

  -- For random mode, remember last item
  if self.current_index > #self.shuffled then
    self.last_item = item
  end

  return item
end

--- Peek at next item without advancing
--- @return any? item Next item or nil
function ShuffleManager:peek()
  if self.current_index > #self.shuffled then
    return nil
  end
  return self.shuffled[self.current_index]
end

--- Check if there are more items before reshuffle
--- @return boolean has_more True if more items available
function ShuffleManager:has_more()
  return self.current_index <= #self.shuffled
end

--- Get current position
--- @return number index Current index in shuffled array
function ShuffleManager:get_position()
  return self.current_index
end

--- Get total count
--- @return number count Total items in shuffle
function ShuffleManager:get_count()
  return #self.shuffled
end

--- Reset to beginning of current shuffle
function ShuffleManager:reset()
  self.current_index = 1
end

--- Change shuffle mode
--- @param mode string "true_shuffle" or "random"
function ShuffleManager:set_mode(mode)
  if mode ~= "true_shuffle" and mode ~= "random" then
    error("Invalid shuffle mode: " .. tostring(mode))
  end
  self.mode = mode
  self:reshuffle()
end

--- Get current mode
--- @return string mode Current shuffle mode
function ShuffleManager:get_mode()
  return self.mode
end

--- Update the original array and reshuffle
--- @param new_array table New array to shuffle
function ShuffleManager:set_array(new_array)
  self.original = new_array
  self:reshuffle()
end

--- Get a copy of the current shuffled array
--- @return table shuffled Copy of current shuffle order
function ShuffleManager:get_shuffled()
  local copy = {}
  for i, v in ipairs(self.shuffled) do
    copy[i] = v
  end
  return copy
end

--- Weighted shuffle - items with higher weights are more likely to appear
--- @param items table Array of items
--- @param weights table Array of weights (same length as items)
--- @param count? number Number of items to sample (default: #items)
--- @param seed? number Optional seed (WARNING: affects global math.randomseed!)
--- @return table sampled Array of sampled items
function M.weighted_shuffle(items, weights, count, seed)
  if #items ~= #weights then
    error("Items and weights must have same length")
  end

  if #items == 0 then return {} end

  count = count or #items

  -- WARNING: this affects global random state
  if seed then
    math.randomseed(seed)
  end

  -- Simple weighted sampling (not optimal but works for small arrays)
  local total_weight = 0
  for _, w in ipairs(weights) do
    total_weight = total_weight + w
  end

  local sampled = {}
  local remaining_items = {}
  local remaining_weights = {}

  for i, item in ipairs(items) do
    remaining_items[i] = item
    remaining_weights[i] = weights[i]
  end

  for _ = 1, count do
    if #remaining_items == 0 then break end

    -- Pick random weighted item
    local rand = math.random() * total_weight
    local sum = 0
    local selected_index = 1

    for i, w in ipairs(remaining_weights) do
      sum = sum + w
      if rand <= sum then
        selected_index = i
        break
      end
    end

    table.insert(sampled, remaining_items[selected_index])

    -- Remove selected item
    total_weight = total_weight - remaining_weights[selected_index]
    table.remove(remaining_items, selected_index)
    table.remove(remaining_weights, selected_index)
  end

  return sampled
end

return M
