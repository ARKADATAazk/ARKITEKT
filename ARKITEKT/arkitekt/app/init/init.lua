-- @noindex
-- arkitekt/app/init.lua
-- Central initialization - finds and loads bootstrap module
-- This eliminates duplication of the 20-line init_arkitekt() function across all entry points

local M = {}

-- Find and load the ARKITEKT bootstrap module
-- Scans upward from the calling script's location until it finds bootstrap.lua
-- @return ARK context table with framework utilities, or nil on failure
function M.bootstrap()
  local sep = package.config:sub(1,1)

  -- Get the path of the script that called this function (level 2)
  local src = debug.getinfo(2, "S").source:sub(2)
  local dir = src:match("(.*"..sep..")")

  -- Scan upward for bootstrap.lua
  local path = dir
  while path and #path > 3 do
    local bootstrap = path .. "arkitekt" .. sep .. "app" .. sep .. "init" .. sep .. "bootstrap.lua"
    local f = io.open(bootstrap, "r")
    if f then
      f:close()
      -- Load and execute bootstrap with the root path
      return dofile(bootstrap)(path)
    end
    path = path:match("(.*"..sep..")[^"..sep.."]-"..sep.."$")
  end

  -- Bootstrap not found - show error and return nil
  reaper.MB("ARKITEKT bootstrap not found!", "FATAL ERROR", 0)
  return nil
end

return M
