-- @description Media Container - Paste
-- @version 0.1.0
-- @author ARKITEKT
-- @about
--   Paste container from clipboard at cursor position.
--   Creates a linked copy that mirrors changes.

-- ============================================================================
-- BOOTSTRAP ARKITEKT FRAMEWORK
-- ============================================================================
local ARK
do
  local sep = package.config:sub(1,1)
  local src = debug.getinfo(1, "S").source:sub(2)
  local path = src:match("(.*"..sep..")")
  while path and #path > 3 do
    local init = path .. "arkitekt" .. sep .. "app" .. sep .. "init" .. sep .. "init.lua"
    local f = io.open(init, "r")
    if f then
      f:close()
      local Init = dofile(init)
      ARK = Init.bootstrap()
      break
    end
    path = path:match("(.*"..sep..")[^"..sep.."]-"..sep.."$")
  end
  if not ARK then
    reaper.MB("ARKITEKT framework not found!", "FATAL ERROR", 0)
    return
  end
end

-- ============================================================================
-- PASTE CONTAINER
-- ============================================================================

local MediaContainer = require("MediaContainer.init")

-- Initialize state (loads from project)
MediaContainer.initialize()

-- Paste container at cursor
local container = MediaContainer.paste_container()

if container then
  reaper.Undo_OnStateChange("Paste Media Container: " .. container.name)
end
