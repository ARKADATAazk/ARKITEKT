-- @noindex
-- @about
--   Paste container from clipboard at cursor position.
--   Creates a linked copy that mirrors changes.

-- ============================================================================
-- LOAD ARKITEKT FRAMEWORK
-- ============================================================================
local Ark = dofile(debug.getinfo(1,'S').source:sub(2):match('(.-ARKITEKT[/\\])') .. 'arkitekt' .. package.config:sub(1,1) .. 'init.lua')

-- ============================================================================
-- PASTE CONTAINER
-- ============================================================================

local State = require('MediaContainer.app.state')
local Container = require('MediaContainer.domain.container')

-- Initialize state (loads from project)
State.initialize()

-- Paste container at cursor
local container = Container.paste_container()

if container then
  reaper.Undo_OnStateChange('Paste Media Container: ' .. container.name)
end
