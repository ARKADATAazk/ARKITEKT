-- @noindex
-- @about
--   Copy container at cursor position or containing selected items.

-- ============================================================================
-- LOAD ARKITEKT FRAMEWORK
-- ============================================================================
local Ark = dofile(debug.getinfo(1,'S').source:sub(2):match('(.-ARKITEKT[/\\])') .. 'arkitekt' .. package.config:sub(1,1) .. 'init.lua')

-- ============================================================================
-- COPY CONTAINER
-- ============================================================================

local State = require('MediaContainer.app.state')
local Container = require('MediaContainer.domain.container')

-- Initialize state (loads from project)
State.initialize()

-- Copy container to clipboard
Container.copy_container()
