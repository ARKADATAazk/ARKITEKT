-- @noindex
-- @about
--   Create a new container from currently selected items.

-- ============================================================================
-- BOOTSTRAP ARKITEKT FRAMEWORK
-- ============================================================================
do
  local sep = package.config:sub(1,1)
  local src = debug.getinfo(1, "S").source:sub(2)
  local path = src:match("(.*"..sep..")")
  while path and #path > 3 do
    local bootstrap = path .. "arkitekt" .. sep .. "app" .. sep .. "bootstrap.lua"
    local f = io.open(bootstrap, "r")
    if f then
      f:close()
      package.path = path .. "?.lua;" .. path .. "?" .. sep .. "init.lua;" .. package.path
      package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
      break
    end
    path = path:match("(.*"..sep..")[^"..sep.."]-"..sep.."$")
  end
end

-- ============================================================================
-- CREATE CONTAINER
-- ============================================================================

local MediaContainer = require("MediaContainer.init")

-- Initialize state (loads from project)
MediaContainer.initialize()

-- Create container from selection
local container = MediaContainer.create_container()

if container then
  reaper.Undo_OnStateChange("Create Media Container: " .. container.name)
end
