-- @noindex
-- Blocks/app/loader.lua
-- Component loader - discovers and loads block components

local M = {}

-- Get blocks directory path (relative to this script)
local function get_blocks_dir()
  local info = debug.getinfo(1, 'S')
  local script_path = info.source:sub(2) -- Remove '@' prefix
  local dir = script_path:match('(.-)[/\\][^/\\]+$') -- Get parent dir (app/)
  local blocks_dir = dir:match('(.-)[/\\][^/\\]+$') -- Get parent dir (Blocks/)
  local sep = package.config:sub(1, 1)
  return blocks_dir .. sep .. 'blocks' .. sep
end

---Check if a file exists
---@param path string File path
---@return boolean
local function file_exists(path)
  local f = io.open(path, 'r')
  if f then
    f:close()
    return true
  end
  return false
end

---Check if a path is a directory (by checking for init.lua)
---@param path string Directory path
---@return boolean
local function is_block_dir(path)
  local sep = package.config:sub(1, 1)
  return file_exists(path .. sep .. 'init.lua')
end

---Discover available block components
---@return table[] Array of block info: { name, path, init_path }
function M.discover()
  local blocks_dir = get_blocks_dir()
  local blocks = {}
  local sep = package.config:sub(1, 1)

  -- Use reaper.EnumerateSubdirectories to scan blocks/ folder
  local idx = 0
  while true do
    local folder = reaper.EnumerateSubdirectories(blocks_dir, idx)
    if not folder then break end

    local block_path = blocks_dir .. folder
    local init_path = block_path .. sep .. 'init.lua'

    if file_exists(init_path) then
      table.insert(blocks, {
        name = folder,
        path = block_path,
        init_path = init_path,
      })
    end

    idx = idx + 1
  end

  return blocks
end

---Load a block component
---@param block_info table Block info from discover()
---@return table|nil Component handle with draw() method, or nil on error
function M.load(block_info)
  if not block_info or not block_info.init_path then
    return nil, 'Invalid block info'
  end

  if not file_exists(block_info.init_path) then
    return nil, 'Block init.lua not found: ' .. block_info.init_path
  end

  -- CRITICAL: Set the host flag BEFORE loading
  -- (Shell.run checks this flag to return component handle instead of running defer)
  _G.ARKITEKT_BLOCKS_HOST = true

  -- Load the component (dofile returns what the script returns)
  local ok, result = pcall(dofile, block_info.init_path)

  if not ok then
    return nil, 'Failed to load block: ' .. tostring(result)
  end

  -- Validate the component has a draw method
  if type(result) ~= 'table' or type(result.draw) ~= 'function' then
    return nil, 'Block did not return valid component handle (missing draw function)'
  end

  -- Add metadata from block_info
  result.block_name = block_info.name
  result.block_path = block_info.path

  return result
end

---Load a block by name
---@param name string Block folder name
---@return table|nil Component handle or nil on error
function M.load_by_name(name)
  local blocks = M.discover()

  for _, block in ipairs(blocks) do
    if block.name == name then
      return M.load(block)
    end
  end

  return nil, 'Block not found: ' .. name
end

return M
