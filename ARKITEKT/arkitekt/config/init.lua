-- @noindex
-- arkitekt/defs/init.lua
-- Aggregates all shared definitions

local M = {}

M.colors = require('arkitekt.config.colors')
M.timing = require('arkitekt.config.timing')
M.typography = require('arkitekt.config.typography')
M.reaper_commands = require('arkitekt.config.reaper_commands')
M.app = require('arkitekt.config.app')

return M
