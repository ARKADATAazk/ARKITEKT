-- @noindex
-- @about
--   Create a new container from currently selected items.

-- ============================================================================
-- LOAD ARKITEKT FRAMEWORK
-- ============================================================================
local Ark = dofile(debug.getinfo(1,'S').source:sub(2):match('(.-ARKITEKT[/\\])') .. 'arkitekt' .. package.config:sub(1,1) .. 'init.lua')

-- ============================================================================
-- CREATE CONTAINER
-- ============================================================================

local State = require('MediaContainer.app.state')
local Container = require('MediaContainer.domain.container')

-- Initialize state (loads from project)
State.initialize()

-- Create container from selection
local container = Container.create_from_selection()

if container then
  reaper.Undo_OnStateChange('Create Media Container: ' .. container.name)
end
